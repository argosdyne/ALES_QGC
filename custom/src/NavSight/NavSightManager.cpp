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
}

void NavSightManager::setToolbox(QGCToolbox* toolbox)
{
    QGCTool::setToolbox(toolbox);

    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
    qmlRegisterUncreatableType<NavSightManager>("CustomQuickInterface", 1, 0,
                                                 "NavSightManager", "Reference only");

    MultiVehicleManager* vehicleManager = _toolbox->multiVehicleManager();
    _setActiveVehicle(vehicleManager->activeVehicle());
    connect(vehicleManager, &MultiVehicleManager::activeVehicleChanged,
            this, &NavSightManager::_setActiveVehicle);
    _heartbeatWatchdog.start();
}

void NavSightManager::_setActiveVehicle(Vehicle* vehicle)
{
    if (_vehicle) {
        disconnect(_vehicle, &Vehicle::mavlinkMessageReceived,
                   this, &NavSightManager::_mavlinkMessageReceived);
    }

    _vehicle = vehicle;
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
    if (message.sysid != kDefaultSystemId || message.compid != kDefaultComponentId) {
        return;
    }

    if (message.msgid == MAVLINK_MSG_ID_HEARTBEAT) {
        mavlink_heartbeat_t heartbeat{};
        mavlink_msg_heartbeat_decode(&message, &heartbeat);

        _navSightOnline = true;
        _navSightStatusBitmask = heartbeat.custom_mode;
        _lastHeartbeatTimer.restart();
        emit navSightStatusChanged();
        qCDebug(NavSightManagerLog) << "NavSight HEARTBEAT custom_mode="
                                    << Qt::hex << heartbeat.custom_mode;
        return;
    }

    if (message.msgid == MAVLINK_MSG_ID_NAMED_VALUE_FLOAT) {
        mavlink_named_value_float_t namedValue{};
        mavlink_msg_named_value_float_decode(&message, &namedValue);
        if (_mavlinkString(namedValue.name, MAVLINK_MSG_NAMED_VALUE_FLOAT_FIELD_NAME_LEN) == QStringLiteral("CONF")) {
            _navSightConfidence = namedValue.value;
            _navSightConfidenceValid = true;
            emit navSightStatusChanged();
            qCDebug(NavSightManagerLog) << "NavSight CONF=" << namedValue.value;
        }
        return;
    }

    if (message.msgid == MAVLINK_MSG_ID_STATUSTEXT) {
        mavlink_statustext_t statusText{};
        mavlink_msg_statustext_decode(&message, &statusText);
        _navSightStatusText = _mavlinkString(statusText.text, MAVLINK_MSG_STATUSTEXT_FIELD_TEXT_LEN);
        emit navSightStatusChanged();
        qCDebug(NavSightManagerLog) << "NavSight STATUSTEXT=" << _navSightStatusText;
    }
}

void NavSightManager::_checkHeartbeatTimeout()
{
    if (kUiPreviewEnabled) {
        return;
    }
    if (_navSightOnline && _lastHeartbeatTimer.isValid() &&
        _lastHeartbeatTimer.elapsed() > kHeartbeatTimeoutMs) {
        qCDebug(NavSightManagerLog) << "NavSight heartbeat timed out";
        _setOffline();
    }
}

void NavSightManager::_setOffline()
{
    _lastHeartbeatTimer.invalidate();

    // Keep the UI test fixture visible while the temporary preview mode is
    // enabled. _setActiveVehicle calls this when QGC creates/replaces the
    // active Vehicle, which otherwise overwrites the preview values.
    if (kUiPreviewEnabled) {
        _navSightOnline = true;
        _navSightConfidence = 3.2;
        _navSightConfidenceValid = true;
        _navSightStatusText = QStringLiteral("WAITING_FOR_START_MISSION");
        _navSightStatusBitmask = 0;
        _navSightDeadReckoningActive = false;
        _navSightGpsActive = true;
        _navSightVisualNavigationActive = true;
        _navSightLocationSource = QStringLiteral("GPS");
        emit navSightStatusChanged();
        return;
    }

    _navSightOnline = false;
    _navSightConfidence = 0.0;
    _navSightConfidenceValid = false;
    _navSightStatusText.clear();
    _navSightStatusBitmask = 0;
    _navSightDeadReckoningActive = false;
    _navSightGpsActive = false;
    _navSightVisualNavigationActive = false;
    _navSightLocationSource = QStringLiteral("N/A");
    emit navSightStatusChanged();
}

void NavSightManager::_setUpdateLocationResult(const QString& result)
{
    _lastUpdateLocationResult = result;
    emit updateLocationStateChanged();
}

bool NavSightManager::sendUpdateLocation(double latitude, double longitude)
{
    _updateLocationInProgress = true;
    emit updateLocationStateChanged();

    if (!_vehicle) {
        _updateLocationInProgress = false;
        _setUpdateLocationResult(QStringLiteral("No active vehicle"));
        return false;
    }
    if (!std::isfinite(latitude) || !std::isfinite(longitude) ||
        latitude < -90.0 || latitude > 90.0 || longitude < -180.0 || longitude > 180.0) {
        _updateLocationInProgress = false;
        _setUpdateLocationResult(QStringLiteral("Invalid location"));
        return false;
    }

    SharedLinkInterfacePtr link = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (!link) {
        _updateLocationInProgress = false;
        _setUpdateLocationResult(QStringLiteral("No primary telemetry link"));
        return false;
    }

    mavlink_command_long_t command{};
    command.target_system = static_cast<uint8_t>(kDefaultSystemId);
    command.target_component = static_cast<uint8_t>(kDefaultComponentId);
    command.command = 44444; // NavSight UPDATE_LOCATION
    command.confirmation = 0;
    command.param1 = static_cast<float>(latitude);
    command.param2 = static_cast<float>(longitude);

    mavlink_message_t message{};
    MAVLinkProtocol* mavlinkProtocol = _toolbox->mavlinkProtocol();
    mavlink_msg_command_long_encode(mavlinkProtocol->getSystemId(), mavlinkProtocol->getComponentId(),
                                    &message, &command);
    _vehicle->sendMessageOnLinkThreadSafe(link.get(), message);

    _updateLocationInProgress = false;
    _setUpdateLocationResult(QStringLiteral("UPDATE_LOCATION sent; awaiting ACK"));
    emit updateLocationSent(latitude, longitude);
    qCDebug(NavSightManagerLog) << "NavSight UPDATE_LOCATION sent" << latitude << longitude;
    return true;
}