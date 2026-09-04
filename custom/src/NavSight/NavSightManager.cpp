#include "NavSightManager.h"

#include "MAVLinkProtocol.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"
#include "VehicleLinkManager.h"

#include <QQmlEngine>
#include <QtQml>
#include <QLoggingCategory>

#include <cmath>

Q_LOGGING_CATEGORY(NavSightManagerLog, "qgc.custom.navsight")

NavSightManager::NavSightManager(QGCApplication* app, QGCToolbox* toolbox)
    : QGCTool(app, toolbox)
{
    _heartbeatWatchdog.setInterval(250);
    _heartbeatWatchdog.setSingleShot(false);
    connect(&_heartbeatWatchdog, &QTimer::timeout,
            this, &NavSightManager::_checkHeartbeatTimeout);

    _updateLocationAckTimer.setInterval(kUpdateLocationAckTimeoutMs);
    _updateLocationAckTimer.setSingleShot(true);
    connect(&_updateLocationAckTimer, &QTimer::timeout,
            this, &NavSightManager::_updateLocationAckTimeout);

    _ekfSourceAckTimer.setInterval(kEkfSourceAckTimeoutMs);
    _ekfSourceAckTimer.setSingleShot(true);
    connect(&_ekfSourceAckTimer, &QTimer::timeout,
            this, &NavSightManager::_ekfSourceAckTimeout);
}

void NavSightManager::setToolbox(QGCToolbox* toolbox)
{
    QGCTool::setToolbox(toolbox);

    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
    qmlRegisterUncreatableType<NavSightManager>("CustomQuickInterface", 1, 0,
                                                 "NavSightManager", "Reference only");

    MultiVehicleManager* vehicleManager = _toolbox->multiVehicleManager();
    connect(_toolbox->mavlinkProtocol(), &MAVLinkProtocol::messageReceived,
            this, &NavSightManager::_rawMavlinkMessageReceived);
    _setActiveVehicle(vehicleManager->activeVehicle());
    connect(vehicleManager, &MultiVehicleManager::activeVehicleChanged,
            this, &NavSightManager::_setActiveVehicle);
    _heartbeatWatchdog.start();
}

void NavSightManager::_setActiveVehicle(Vehicle* vehicle)
{
    qCInfo(NavSightManagerLog) << "Active vehicle changed:" << (vehicle ? QString::number(vehicle->id()) : QStringLiteral("none"));

    if (_updateLocationInProgress) {
        _finishUpdateLocation(QStringLiteral("NavSight location request cancelled: active vehicle changed"));
    }
    if (_ekfSourceChangeInProgress) {
        qCWarning(NavSightManagerLog) << "EKF source selection cancelled: active vehicle changed";
        _finishEkfSourceSet();
    }

    if (_vehicle) {
        disconnect(_vehicle, &Vehicle::mavlinkMessageReceived,
                   this, &NavSightManager::_mavlinkMessageReceived);
    }

    _vehicle = vehicle;
    _activeEkfSourceSet = 0;
    _pendingEkfSourceSet = 0;
    _ekfSourceChangeInProgress = false;
    _navSightLocationSource = QStringLiteral("N/A");
    emit ekfSourceStateChanged();
    _setOffline();

    if (_vehicle) {
        connect(_vehicle, &Vehicle::mavlinkMessageReceived,
                this, &NavSightManager::_mavlinkMessageReceived);
    }
}

QString NavSightManager::_mavlinkString(const char* text, int textLength)
{
    QByteArray bytes(text, textLength);
    const int nullIndex = bytes.indexOf('\0');
    if (nullIndex >= 0) {
        bytes.truncate(nullIndex);
    }
    return QString::fromLatin1(bytes).trimmed();
}

void NavSightManager::_mavlinkMessageReceived(const mavlink_message_t& message)
{
    // EKF source selection is a command to the Flight Controller, not NavSight.
    if (message.msgid == MAVLINK_MSG_ID_COMMAND_ACK && _vehicle &&
        message.sysid == _vehicle->id() && message.compid == MAV_COMP_ID_AUTOPILOT1) {
        mavlink_command_ack_t ack{};
        mavlink_msg_command_ack_decode(&message, &ack);

        if (ack.command == MAV_CMD_SET_EKF_SOURCE_SET) {
            if (!_ekfSourceChangeInProgress) {
                qCDebug(NavSightManagerLog) << "Ignoring FC EKF source ACK with no pending request"
                                            << "result=" << ack.result;
                return;
            }

            const int requestedSourceSet = _pendingEkfSourceSet;
            if (ack.result == MAV_RESULT_ACCEPTED) {
                _activeEkfSourceSet = requestedSourceSet;
                _navSightLocationSource = _ekfSourceSetName(requestedSourceSet);
                _navSightDeadReckoningActive = requestedSourceSet == 3;
                _navSightGpsActive = requestedSourceSet == 1;
                _navSightVisualNavigationActive = requestedSourceSet == 2;
                emit navSightStatusChanged();
                qCInfo(NavSightManagerLog) << "FC EKF source set accepted: sourceSet="
                                           << requestedSourceSet << "source=" << _navSightLocationSource;
            } else {
                qCWarning(NavSightManagerLog) << "FC rejected EKF source set: sourceSet="
                                              << requestedSourceSet << "result=" << ack.result;
            }
            _finishEkfSourceSet();
            return;
        }
    }

}

void NavSightManager::_rawMavlinkMessageReceived(LinkInterface* link, mavlink_message_t message)
{
    if (message.sysid != kDefaultSystemId || message.compid != kDefaultComponentId ||
        !_vehicle || !_vehicle->vehicleLinkManager()->containsLink(link)) {
        return;
    }

    _handleNavSightMessage(message);
}

void NavSightManager::_handleNavSightMessage(const mavlink_message_t& message)
{
    if (message.msgid == MAVLINK_MSG_ID_COMMAND_ACK) {
        mavlink_command_ack_t ack{};
        mavlink_msg_command_ack_decode(&message, &ack);

        if (!_updateLocationInProgress || ack.command != 44444) {
            qCDebug(NavSightManagerLog) << "Ignoring NavSight COMMAND_ACK command="
                                        << ack.command << "result=" << ack.result;
            return;
        }

        if (ack.result == MAV_RESULT_ACCEPTED) {
            qCInfo(NavSightManagerLog) << "NavSight COMMAND_ACK accepted: source=10/192 command=" << ack.command << "result=" << ack.result;
            _finishUpdateLocation(QStringLiteral("NavSight location updated"));
        } else if (ack.result == MAV_RESULT_TEMPORARILY_REJECTED ||
                   ack.result == kNavSightTemporaryRejectedResult) {
            const QString status = _navSightStatusText.isEmpty()
                ? QStringLiteral("No current NavSight status") : _navSightStatusText;
            qCWarning(NavSightManagerLog) << "NavSight UPDATE_LOCATION temporarily rejected"
                                           << "result=" << ack.result << "status=" << status;
            _finishUpdateLocation(QStringLiteral("NavSight location rejected. %1. Retry after resolving NavSight status.").arg(status));
        } else {
            qCWarning(NavSightManagerLog) << "NavSight UPDATE_LOCATION ACK result not handled; waiting for timeout"
                                           << ack.result;
        }
        return;
    }

    if (message.msgid == MAVLINK_MSG_ID_HEARTBEAT) {
        mavlink_heartbeat_t heartbeat{};
        mavlink_msg_heartbeat_decode(&message, &heartbeat);

        _navSightOnline = true;
        _navSightStatusBitmask = heartbeat.custom_mode;
        _initialLocationAccepted = (heartbeat.custom_mode & kWaitingForStartMissionMask) == 0;
        _lastHeartbeatTimer.restart();
        emit navSightStatusChanged();
        qCInfo(NavSightManagerLog).nospace()
            << "NavSight HEARTBEAT: source=" << message.sysid << '/' << message.compid
            << " type=" << heartbeat.type << " autopilot=" << heartbeat.autopilot
            << " base_mode=0x" << Qt::hex << heartbeat.base_mode
            << " custom_mode=0x" << heartbeat.custom_mode << Qt::dec
            << " system_status=" << heartbeat.system_status
            << " initialLocationAccepted=" << _initialLocationAccepted;
        return;
    }

    if (message.msgid == MAVLINK_MSG_ID_NAMED_VALUE_FLOAT) {
        mavlink_named_value_float_t namedValue{};
        mavlink_msg_named_value_float_decode(&message, &namedValue);
        if (_mavlinkString(namedValue.name, MAVLINK_MSG_NAMED_VALUE_FLOAT_FIELD_NAME_LEN) == QStringLiteral("CONF")) {
            if (std::isfinite(namedValue.value) && namedValue.value >= 0.0f && namedValue.value <= 4.0f) {
                _navSightConfidence = namedValue.value;
                _navSightConfidenceValid = true;
                qCInfo(NavSightManagerLog) << "NavSight CONF accepted:" << namedValue.value;
            } else {
                _navSightConfidence = 0.0;
                _navSightConfidenceValid = false;
                qCWarning(NavSightManagerLog) << "Ignoring invalid NavSight CONF=" << namedValue.value;
            }
            emit navSightStatusChanged();
        }
        return;
    }

    if (message.msgid == MAVLINK_MSG_ID_STATUSTEXT) {
        mavlink_statustext_t statusText{};
        mavlink_msg_statustext_decode(&message, &statusText);
        _navSightStatusText = _mavlinkString(statusText.text, MAVLINK_MSG_STATUSTEXT_FIELD_TEXT_LEN);
        if (!_lastUpdateLocationResult.isEmpty()) {
            _lastUpdateLocationResult.clear();
            emit updateLocationStateChanged();
        }
        emit navSightStatusChanged();
        qCInfo(NavSightManagerLog) << "NavSight STATUSTEXT:" << _navSightStatusText;
    }
}
void NavSightManager::_checkHeartbeatTimeout()
{
    if (_navSightOnline && _lastHeartbeatTimer.isValid() &&
        _lastHeartbeatTimer.elapsed() > kHeartbeatTimeoutMs) {
        qCWarning(NavSightManagerLog) << "NavSight HEARTBEAT timeout after" << kHeartbeatTimeoutMs << "ms";
        _setOffline();
    }
}

void NavSightManager::_setOffline()
{
    _lastHeartbeatTimer.invalidate();
    _navSightOnline = false;
    _navSightConfidence = 0.0;
    _navSightConfidenceValid = false;
    _navSightStatusText.clear();
    _navSightStatusBitmask = 0;
    _navSightDeadReckoningActive = false;
    _navSightGpsActive = false;
    _navSightVisualNavigationActive = false;
    _initialLocationAccepted = false;
    emit navSightStatusChanged();
}
void NavSightManager::_setUpdateLocationResult(const QString& result)
{
    _lastUpdateLocationResult = result;
    qCInfo(NavSightManagerLog) << "UPDATE_LOCATION state:" << result
                               << "pending=" << _updateLocationInProgress
                               << "retry=" << _updateLocationRetryCount;
    emit updateLocationStateChanged();
}

bool NavSightManager::_queuePendingUpdateLocation()
{
    if (!_vehicle) {
        return false;
    }

    SharedLinkInterfacePtr link = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (!link) {
        return false;
    }

    mavlink_command_long_t command{};
    command.target_system = static_cast<uint8_t>(kDefaultSystemId);
    command.target_component = static_cast<uint8_t>(kDefaultComponentId);
    command.command = 44444; // NavSight UPDATE_LOCATION
    command.confirmation = 0;
    command.param1 = static_cast<float>(_pendingLatitude);
    command.param2 = static_cast<float>(_pendingLongitude);
    command.param3 = 0.0f;
    command.param4 = 0.0f;
    command.param5 = 0.0f;
    command.param6 = 0.0f;
    command.param7 = 0.0f;

    mavlink_message_t message{};
    MAVLinkProtocol* mavlinkProtocol = _toolbox->mavlinkProtocol();
    mavlink_msg_command_long_encode(mavlinkProtocol->getSystemId(), mavlinkProtocol->getComponentId(),
                                    &message, &command);
    _vehicle->sendMessageOnLinkThreadSafe(link.get(), message);
    _updateLocationAckTimer.start();

    emit updateLocationSent(_pendingLatitude, _pendingLongitude);
    qCInfo(NavSightManagerLog).nospace()
        << "NavSight UPDATE_LOCATION queued: msgid=" << message.msgid
        << " source=" << mavlinkProtocol->getSystemId() << '/' << mavlinkProtocol->getComponentId()
        << " target=" << static_cast<int>(command.target_system) << '/' << static_cast<int>(command.target_component)
        << " command=" << command.command << " confirmation=" << static_cast<int>(command.confirmation)
        << " primaryLink=\"" << _vehicle->vehicleLinkManager()->primaryLinkName() << '\"'
        << " retry=" << _updateLocationRetryCount
        << " params=[" << command.param1 << ", " << command.param2 << ", "
        << command.param3 << ", " << command.param4 << ", " << command.param5 << ", "
        << command.param6 << ", " << command.param7 << ']';
    return true;
}

void NavSightManager::_finishUpdateLocation(const QString& result)
{
    _updateLocationAckTimer.stop();
    _updateLocationInProgress = false;
    _updateLocationRetryCount = 0;
    _setUpdateLocationResult(result);
}

void NavSightManager::_updateLocationAckTimeout()
{
    if (!_updateLocationInProgress) {
        return;
    }

    if (_updateLocationRetryCount < kMaxUpdateLocationRetries) {
        ++_updateLocationRetryCount;
        _setUpdateLocationResult(QStringLiteral("No NavSight ACK; retrying location update (%1/%2)")
                                     .arg(_updateLocationRetryCount).arg(kMaxUpdateLocationRetries));
        if (_queuePendingUpdateLocation()) {
            return;
        }
        _finishUpdateLocation(QStringLiteral("No primary telemetry link for NavSight retry"));
        return;
    }

    qCWarning(NavSightManagerLog) << "NavSight UPDATE_LOCATION timed out after retries";
    _finishUpdateLocation(QStringLiteral("No NavSight response"));
}

QString NavSightManager::_ekfSourceSetName(int sourceSet)
{
    switch (sourceSet) {
    case 1:
        return QStringLiteral("GPS");
    case 2:
        return QStringLiteral("VIS");
    case 3:
        return QStringLiteral("DR");
    default:
        return QStringLiteral("N/A");
    }
}

void NavSightManager::_finishEkfSourceSet()
{
    _ekfSourceAckTimer.stop();
    _pendingEkfSourceSet = 0;
    _ekfSourceChangeInProgress = false;
    emit ekfSourceStateChanged();
}

void NavSightManager::_ekfSourceAckTimeout()
{
    if (!_ekfSourceChangeInProgress) {
        return;
    }

    qCWarning(NavSightManagerLog) << "FC EKF source set timed out: sourceSet=" << _pendingEkfSourceSet;
    _finishEkfSourceSet();
}

bool NavSightManager::setEkfSourceSet(int sourceSet)
{
    if (sourceSet < 1 || sourceSet > 3) {
        qCWarning(NavSightManagerLog) << "EKF source set rejected locally: invalid sourceSet=" << sourceSet;
        return false;
    }
    if (_ekfSourceChangeInProgress) {
        qCWarning(NavSightManagerLog) << "EKF source set rejected locally: request already pending";
        return false;
    }
    if (!_vehicle) {
        qCWarning(NavSightManagerLog) << "EKF source set rejected locally: no active vehicle";
        return false;
    }

    SharedLinkInterfacePtr link = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (!link) {
        qCWarning(NavSightManagerLog) << "EKF source set rejected locally: no primary telemetry link";
        return false;
    }

    mavlink_command_long_t command{};
    command.target_system = static_cast<uint8_t>(_vehicle->id());
    command.target_component = MAV_COMP_ID_AUTOPILOT1;
    command.command = MAV_CMD_SET_EKF_SOURCE_SET;
    command.confirmation = 0;
    command.param1 = static_cast<float>(sourceSet);

    mavlink_message_t message{};
    MAVLinkProtocol* mavlinkProtocol = _toolbox->mavlinkProtocol();
    mavlink_msg_command_long_encode(mavlinkProtocol->getSystemId(), mavlinkProtocol->getComponentId(),
                                    &message, &command);

    _pendingEkfSourceSet = sourceSet;
    _ekfSourceChangeInProgress = true;
    emit ekfSourceStateChanged();
    _vehicle->sendMessageOnLinkThreadSafe(link.get(), message);
    _ekfSourceAckTimer.start();

    qCInfo(NavSightManagerLog).nospace()
        << "FC EKF source set queued: msgid=" << message.msgid
        << " source=" << mavlinkProtocol->getSystemId() << '/' << mavlinkProtocol->getComponentId()
        << " target=" << static_cast<int>(command.target_system) << '/' << static_cast<int>(command.target_component)
        << " command=" << command.command << " sourceSet=" << sourceSet
        << " primaryLink=\"" << _vehicle->vehicleLinkManager()->primaryLinkName() << '\"';
    return true;
}
bool NavSightManager::sendUpdateLocation(double latitude, double longitude)
{
    if (_updateLocationInProgress) {
        _setUpdateLocationResult(QStringLiteral("UPDATE_LOCATION already pending"));
        return false;
    }

    if (!_vehicle) {
        qCWarning(NavSightManagerLog) << "UPDATE_LOCATION rejected locally: no active vehicle";
        _setUpdateLocationResult(QStringLiteral("No active vehicle"));
        return false;
    }

    qCInfo(NavSightManagerLog).nospace()
        << "UPDATE_LOCATION requested: latitude=" << latitude << " longitude=" << longitude
        << " vehicle=" << _vehicle->id() << " flying=" << _vehicle->flying()
        << " initialLocationAccepted=" << _initialLocationAccepted
        << " primaryLink=\"" << _vehicle->vehicleLinkManager()->primaryLinkName() << '\"';

    if (_vehicle->flying() && !_initialLocationAccepted) {
        qCWarning(NavSightManagerLog) << "UPDATE_LOCATION rejected locally: initial location not accepted while flying";
        _setUpdateLocationResult(QStringLiteral("Initial NavSight location must be set on the ground before takeoff"));
        return false;
    }
    if (!std::isfinite(latitude) || !std::isfinite(longitude) ||
        latitude < -90.0 || latitude > 90.0 || longitude < -180.0 || longitude > 180.0) {
        _setUpdateLocationResult(QStringLiteral("Invalid location"));
        return false;
    }
    if (!_vehicle->vehicleLinkManager()->primaryLink().lock()) {
        _setUpdateLocationResult(QStringLiteral("No primary telemetry link"));
        return false;
    }

    _pendingLatitude = latitude;
    _pendingLongitude = longitude;
    _updateLocationRetryCount = 0;
    _updateLocationInProgress = true;
    _setUpdateLocationResult(QStringLiteral("Sending NavSight location..."));

    if (!_queuePendingUpdateLocation()) {
        _finishUpdateLocation(QStringLiteral("No primary telemetry link"));
        return false;
    }

    _setUpdateLocationResult(QStringLiteral("UPDATE_LOCATION sent; awaiting ACK"));
    return true;
}