#include "NavSightManager.h"

#include "MAVLinkProtocol.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"
#include "ParameterManager.h"
#include "Fact.h"
#include "SettingsManager.h"
#include "FlyViewSettings.h"
#include "LinkInterface.h"
#include "VehicleLinkManager.h"

#include <QQmlEngine>
#include <QtQml>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QLoggingCategory>
#include <QtMath>

#include <cmath>
#include <cstring>

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

    _outputSignalCommandTimer.setInterval(kOutputSignalCommandTimeoutMs);
    _outputSignalCommandTimer.setSingleShot(true);
    connect(&_outputSignalCommandTimer, &QTimer::timeout,
            this, &NavSightManager::_outputSignalCommandTimeout);

    _schemaFtpTimer.setInterval(kSchemaFtpTimeoutMs);
    _schemaFtpTimer.setSingleShot(true);
    connect(&_schemaFtpTimer, &QTimer::timeout,
            this, &NavSightManager::_schemaFtpTimeout);

    _schemaRetryTimer.setInterval(kSchemaRetryDelayMs);
    _schemaRetryTimer.setSingleShot(true);
    connect(&_schemaRetryTimer, &QTimer::timeout,
            this, &NavSightManager::_schemaRetryTimeout);
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
    Fact* navSightFeatureSetting = _toolbox->settingsManager()->flyViewSettings()->enableNavSight();
    _navSightFeatureSettingConnection = connect(navSightFeatureSetting, &Fact::rawValueChanged,
                                                 this, [this](QVariant enabled) {
        if (!enabled.toBool()) {
            _clearGpsComparisonTrajectory();
        }
    });
    Fact* gpsComparisonTrailSetting = _toolbox->settingsManager()->flyViewSettings()->showNavSightGpsComparisonTrail();
    _gpsComparisonSettingConnection = connect(gpsComparisonTrailSetting, &Fact::rawValueChanged,
                                               this, [this](QVariant enabled) {
        if (!enabled.toBool()) {
            _clearGpsComparisonTrajectory();
        }
    });
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
    if (_outputSignalCommandInProgress) {
        _finishOutputSignalCommand(QStringLiteral("NavSight output request cancelled: active vehicle changed"));
    }

    if (_vehicle) {
        disconnect(_vehicle, &Vehicle::mavlinkMessageReceived,
                   this, &NavSightManager::_mavlinkMessageReceived);
    }

    disconnect(_externalNavParametersReadyConnection);
    disconnect(_vehicleArmedConnection);
    _disconnectExternalNavFactSignals();
    _vehicle = vehicle;
    _activeEkfSourceSet = 0;
    _pendingEkfSourceSet = 0;
    _ekfSourceChangeInProgress = false;
    _navSightLocationSource = QStringLiteral("N/A");
    _clearGpsComparisonTrajectory();
    emit ekfSourceStateChanged();
    _setOffline();

    if (_vehicle) {
        connect(_vehicle, &Vehicle::mavlinkMessageReceived,
                this, &NavSightManager::_mavlinkMessageReceived);

        _vehicleArmedConnection = connect(_vehicle, &Vehicle::armedChanged, this, [this](bool armed) {
            // Match QGC's primary trajectory lifecycle: begin a fresh
            // comparison trail for each armed flight, but retain it after
            // disarm so the operator can review the completed path.
            if (armed) {
                _clearGpsComparisonTrajectory();
            }
        });

        ParameterManager* parameterManager = _vehicle->parameterManager();
        _externalNavParametersReadyConnection = connect(parameterManager, &ParameterManager::parametersReadyChanged,
                                                         this, [this]() {
            _refreshExternalNavPositionSourceConfigured();
        });
    }

    _refreshExternalNavPositionSourceConfigured();
}

void NavSightManager::_disconnectExternalNavFactSignals()
{
    for (const QMetaObject::Connection& connection : _externalNavFactConnections) {
        disconnect(connection);
    }
    _externalNavFactConnections.clear();
}

void NavSightManager::_refreshExternalNavPositionSourceConfigured()
{
    _disconnectExternalNavFactSignals();

    bool visualNavigationConfigured = false;
    bool deadReckoningConfigured = false;
    if (_vehicle) {
        ParameterManager* parameterManager = _vehicle->parameterManager();
        if (parameterManager->parametersReady()) {
            for (int sourceSet = 2; sourceSet <= 3; ++sourceSet) {
                const QString parameterName = QStringLiteral("EK3_SRC%1_POSXY").arg(sourceSet);
                if (!parameterManager->parameterExists(MAV_COMP_ID_AUTOPILOT1, parameterName)) {
                    continue;
                }

                Fact* fact = parameterManager->getParameter(MAV_COMP_ID_AUTOPILOT1, parameterName);
                _externalNavFactConnections.append(connect(fact, &Fact::rawValueChanged,
                                                          this, [this]() {
                    _refreshExternalNavPositionSourceConfigured();
                }));
                if (sourceSet == 2) {
                    visualNavigationConfigured = fact->rawValue().toInt() == 6;
                } else {
                    deadReckoningConfigured = fact->rawValue().toInt() == 6;
                }
            }
        }
    }

    if (_visualNavigationSourceConfigured != visualNavigationConfigured ||
        _deadReckoningSourceConfigured != deadReckoningConfigured) {
        _visualNavigationSourceConfigured = visualNavigationConfigured;
        _deadReckoningSourceConfigured = deadReckoningConfigured;
        emit externalNavConfigurationChanged();
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

quint32 NavSightManager::_lowStatusWord(const QByteArray& statusBytes)
{
    quint32 statusWord = 0;
    const int byteCount = qMin(statusBytes.size(), static_cast<int>(sizeof(statusWord)));
    for (int byte = 0; byte < byteCount; ++byte) {
        statusWord |= quint32(static_cast<uint8_t>(statusBytes.at(byte))) << (byte * 8);
    }
    return statusWord;
}

NavSightManager::NavSightStatusSeverity NavSightManager::_statusSeverity(const QStringList& statusNames)
{
    // The downloadable schema has names but no severity metadata. Keep this
    // deliberately conservative and independent of any fixed bit position.
    if (statusNames.contains(QStringLiteral("BAD_PARAMS")) ||
        statusNames.contains(QStringLiteral("REBOOT_FC")) ||
        statusNames.contains(QStringLiteral("BAD_MAVLINK_BAUDRATE"))) {
        return NavSightStatusSeverityCritical;
    }
    if (statusNames.size() == 1 &&
        (statusNames.first() == QStringLiteral("NAVIGATION_OK") ||
         statusNames.first() == QStringLiteral("READY_FOR_TAKEOFF"))) {
        return NavSightStatusSeverityNormal;
    }
    return statusNames.isEmpty() ? NavSightStatusSeverityNone : NavSightStatusSeverityWarning;
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
                const bool enteringVisualNavigation = requestedSourceSet == 2 && _activeEkfSourceSet != 2;
                _activeEkfSourceSet = requestedSourceSet;
                _navSightLocationSource = _ekfSourceSetName(requestedSourceSet);
                _navSightDeadReckoningActive = requestedSourceSet == 3;
                _navSightGpsActive = requestedSourceSet == 1;
                _navSightVisualNavigationActive = requestedSourceSet == 2;
                if (enteringVisualNavigation) {
                    _clearGpsComparisonTrajectory();
                }
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

    // GPS_RAW_INT is independent of FC GLOBAL_POSITION_INT. Capture it only
    // for a VIS flight so it can be shown as a comparison path alongside the
    // standard FC/EKF trajectory. Ignore NavSight component-192 traffic even
    // when NavSight shares the vehicle system id.
    if (message.msgid == MAVLINK_MSG_ID_GPS_RAW_INT && _vehicle &&
        message.sysid == _vehicle->id() && message.compid != kDefaultComponentId) {
        mavlink_gps_raw_int_t gpsRawInt{};
        mavlink_msg_gps_raw_int_decode(&message, &gpsRawInt);
        _appendGpsComparisonPoint(gpsRawInt);
    }

}

void NavSightManager::_appendGpsComparisonPoint(const mavlink_gps_raw_int_t& gpsRawInt)
{
    const bool comparisonTrailEnabled = _toolbox && _toolbox->settingsManager() &&
        _toolbox->settingsManager()->flyViewSettings()->enableNavSight()->rawValue().toBool() &&
        _toolbox->settingsManager()->flyViewSettings()->showNavSightGpsComparisonTrail()->rawValue().toBool();
    if (!_vehicle || !_vehicle->armed() || _activeEkfSourceSet != 2 ||
        gpsRawInt.fix_type < GPS_FIX_TYPE_3D_FIX || !comparisonTrailEnabled) {
        return;
    }

    const QGeoCoordinate coordinate(gpsRawInt.lat * 1e-7, gpsRawInt.lon * 1e-7, gpsRawInt.alt * 1e-3);
    if (!coordinate.isValid()) {
        return;
    }

    bool trajectoryChanged = false;
    if (!_lastGpsComparisonPoint.isValid()) {
        _gpsComparisonTrajectory.append(QVariant::fromValue(coordinate));
        _lastGpsComparisonPoint = coordinate;
        trajectoryChanged = true;
    } else {
        const double distance = _lastGpsComparisonPoint.distanceTo(coordinate);
        if (distance <= 2.0) {
            return;
        }

        const double azimuth = _lastGpsComparisonPoint.azimuthTo(coordinate);
        if (!_gpsComparisonAzimuthValid || qAbs(azimuth - _lastGpsComparisonAzimuth) > 1.5) {
            _gpsComparisonTrajectory.append(QVariant::fromValue(coordinate));
            _lastGpsComparisonAzimuth = azimuth;
            _gpsComparisonAzimuthValid = true;
        } else {
            _gpsComparisonTrajectory[_gpsComparisonTrajectory.count() - 1] = QVariant::fromValue(coordinate);
        }
        _lastGpsComparisonPoint = coordinate;
        trajectoryChanged = true;
    }

    if (trajectoryChanged) {
        // A bounded trail prevents long-running flights from degrading map performance.
        static constexpr int kMaxGpsComparisonPoints = 2000;
        if (_gpsComparisonTrajectory.count() > kMaxGpsComparisonPoints) {
            _gpsComparisonTrajectory.removeFirst();
        }
        emit gpsComparisonTrajectoryChanged();
    }
}

void NavSightManager::_clearGpsComparisonTrajectory()
{
    if (_gpsComparisonTrajectory.isEmpty() && !_lastGpsComparisonPoint.isValid()) {
        return;
    }

    _gpsComparisonTrajectory.clear();
    _lastGpsComparisonPoint = QGeoCoordinate();
    _gpsComparisonAzimuthValid = false;
    emit gpsComparisonTrajectoryChanged();
}

void NavSightManager::_rawMavlinkMessageReceived(LinkInterface* link, mavlink_message_t message)
{
    if (!_vehicle || !_vehicle->vehicleLinkManager()->containsLink(link) ||
        message.compid != kDefaultComponentId) {
        return;
    }

    // NavSight v1.2.X may use a configurable sysid, including the FC's sysid.
    // Component 192 is its stable identity. Only a HEARTBEAT may establish or
    // replace the address; every following NavSight message must match it.
    if (message.msgid == MAVLINK_MSG_ID_HEARTBEAT) {
        _setNavSightSystemId(message.sysid);
    } else if (_navSightSystemId == 0 || message.sysid != _navSightSystemId) {
        qCDebug(NavSightManagerLog).nospace()
            << "Ignoring NavSight message from undiscovered/mismatched source="
            << message.sysid << '/' << message.compid
            << " discoveredSystemId=" << _navSightSystemId
            << " msgid=" << message.msgid;
        return;
    }

    _navSightLink = link;
    if (message.msgid == MAVLINK_MSG_ID_FILE_TRANSFER_PROTOCOL) {
        _handleSchemaFtpMessage(message);
        return;
    }
    _handleNavSightMessage(message);
}

void NavSightManager::_handleNavSightMessage(const mavlink_message_t& message)
{
    if (message.msgid == MAVLINK_MSG_ID_COMMAND_ACK) {
        mavlink_command_ack_t ack{};
        mavlink_msg_command_ack_decode(&message, &ack);

        if (_updateLocationInProgress && ack.command == kUpdateLocationCommand) {
            if (ack.result == MAV_RESULT_ACCEPTED) {
                qCInfo(NavSightManagerLog).nospace()
                    << "NavSight COMMAND_ACK accepted: source=" << message.sysid << '/' << message.compid
                    << " command=" << ack.command << " result=" << ack.result;
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

        if (_outputSignalCommandInProgress && ack.command == kToggleOutputSignalCommand) {
            qCInfo(NavSightManagerLog).nospace()
                << "NavSight TOGGLE_OUTPUT_SIGNAL ACK: source=" << message.sysid << '/' << message.compid
                << " command=" << ack.command << " result=" << ack.result;
            if (ack.result != MAV_RESULT_ACCEPTED) {
                _finishOutputSignalCommand(QStringLiteral("NavSight output command rejected (result %1)").arg(ack.result));
                return;
            }

            _outputSignalAckReceived = true;
            _setOutputSignalResult(QStringLiteral("NavSight accepted output command; waiting for DATA64 confirmation"));
            if ((_requestedOutputEnabled && _navSightOutputState == NavSightOutputStateEnabled) ||
                (!_requestedOutputEnabled && _navSightOutputState == NavSightOutputStateDisabled)) {
                _finishOutputSignalCommand(_requestedOutputEnabled
                    ? QStringLiteral("NavSight output resumed")
                    : QStringLiteral("NavSight output stopped"));
            } else {
                _outputSignalCommandTimer.start();
            }
            return;
        }

        qCDebug(NavSightManagerLog) << "Ignoring NavSight COMMAND_ACK command="
                                    << ack.command << "result=" << ack.result;
        return;
    }

    if (message.msgid == MAVLINK_MSG_ID_HEARTBEAT) {
        mavlink_heartbeat_t heartbeat{};
        mavlink_msg_heartbeat_decode(&message, &heartbeat);

        _navSightOnline = true;
        _lastHeartbeatTimer.restart();
        emit navSightStatusChanged();
        qCInfo(NavSightManagerLog).nospace()
            << "NavSight HEARTBEAT: source=" << message.sysid << '/' << message.compid
            << " type=" << heartbeat.type << " autopilot=" << heartbeat.autopilot
            << " base_mode=0x" << Qt::hex << heartbeat.base_mode
            << " custom_mode=0x" << heartbeat.custom_mode << Qt::dec
            << " system_status=" << heartbeat.system_status
            << " statusSource=" << static_cast<int>(_navSightStatusSource)
            << " status=" << _navSightStatusText
            << " initialLocationAccepted=" << _initialLocationAccepted;
        return;
    }

    if (message.msgid == MAVLINK_MSG_ID_DATA64) {
        mavlink_data64_t data64{};
        mavlink_msg_data64_decode(&message, &data64);

        if (!_statusSchema.valid) {
            if (!_schemaRequested && !_schemaRejected) {
                _startStatusSchemaDownload();
            }
            return;
        }
        _applyData64Status(data64);
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
        _navSightDiagnosticText = _mavlinkString(statusText.text, MAVLINK_MSG_STATUSTEXT_FIELD_TEXT_LEN);
        if (_statusTextFallbackActive) {
            _applyStatusText(_navSightDiagnosticText);
        } else {
            emit navSightStatusChanged();
        }
        qCInfo(NavSightManagerLog) << "NavSight diagnostic STATUSTEXT:" << _navSightDiagnosticText;
        return;
    }

    if (message.msgid == MAVLINK_MSG_ID_VISION_POSITION_ESTIMATE) {
        mavlink_vision_position_estimate_t estimate{};
        mavlink_msg_vision_position_estimate_decode(&message, &estimate);
        if (_lastVisionPositionEstimateUsec != 0 && estimate.usec < _lastVisionPositionEstimateUsec &&
            _navSightStatusSource == NavSightStatusSource::Data64) {
            qCInfo(NavSightManagerLog) << "NavSight restart detected from VISION_POSITION_ESTIMATE; accepting STATUSTEXT until next DATA64";
            _navSightStatusSource = NavSightStatusSource::StatusText;
            _hasData64Status = false;
            _statusTextFallbackActive = true;
            if (!_navSightDiagnosticText.isEmpty()) {
                _applyStatusText(_navSightDiagnosticText);
            }
        }
        _lastVisionPositionEstimateUsec = estimate.usec;
    }
}
void NavSightManager::_checkHeartbeatTimeout()
{
    _checkStatusTimeout();
    if (_navSightOnline && _lastHeartbeatTimer.isValid() &&
        _lastHeartbeatTimer.elapsed() > kHeartbeatTimeoutMs) {
        qCWarning(NavSightManagerLog) << "NavSight HEARTBEAT timeout after" << kHeartbeatTimeoutMs << "ms";
        _setOffline();
    }
}

void NavSightManager::_setOffline()
{
    if (_outputSignalCommandInProgress) {
        _finishOutputSignalCommand(QStringLiteral("NavSight output request cancelled: NavSight went offline"));
    }
    _lastHeartbeatTimer.invalidate();
    _resetStatusSchemaState();
    _navSightLink = nullptr;
    _navSightOnline = false;
    _navSightConfidence = 0.0;
    _navSightConfidenceValid = false;
    _navSightStatusText.clear();
    _navSightActiveStatuses.clear();
    _navSightDiagnosticText.clear();
    _navSightStatusBitmask = 0;
    _navSightOutputState = NavSightOutputStateUnknown;
    _navSightStatusSeverity = NavSightStatusSeverityNone;
    _navSightDeadReckoningActive = false;
    _navSightGpsActive = false;
    _navSightVisualNavigationActive = false;
    _initialLocationAccepted = false;
    _setNavSightSystemId(0);
    emit navSightStatusChanged();
    emit outputSignalCommandStateChanged();
}

void NavSightManager::_setNavSightSystemId(int systemId)
{
    if (_navSightSystemId == systemId) {
        return;
    }

    const int previousSystemId = _navSightSystemId;
    if (previousSystemId != 0 && previousSystemId != systemId) {
        qCInfo(NavSightManagerLog) << "NavSight sysid changed; resetting DATA64 schema state"
                                   << previousSystemId << "->" << systemId;
        _resetStatusSchemaState();
        if (_updateLocationInProgress) {
            _finishUpdateLocation(QStringLiteral("NavSight location request cancelled: NavSight address changed"));
        }
        if (_outputSignalCommandInProgress) {
            _finishOutputSignalCommand(QStringLiteral("NavSight output request cancelled: NavSight address changed"));
        }
    }
    _navSightSystemId = systemId;
    emit navSightAddressChanged();

    if (systemId == 0) {
        qCInfo(NavSightManagerLog) << "NavSight address cleared; waiting for component 192 HEARTBEAT";
    } else {
        qCInfo(NavSightManagerLog).nospace()
            << "NavSight address discovered: " << systemId << '/' << kDefaultComponentId
            << " (previous sysid=" << previousSystemId << ")";
    }
}

void NavSightManager::_resetStatusSchemaState()
{
    _schemaFtpTimer.stop();
    _schemaRetryTimer.stop();
    _statusSchema = NavSightStatusSchema{};
    _schemaFtpState = SchemaFtpState::Idle;
    _schemaDownloadData.clear();
    _schemaDownloadReceived.clear();
    _schemaReadOffset = 0;
    _schemaFtpSession = 0;
    _schemaExpectedSequence = 0;
    _schemaRetryCount = 0;
    _schemaRequested = false;
    _schemaRejected = false;
    _hasData64Status = false;
    _navSightStatusSource = NavSightStatusSource::None;
    _statusTextFallbackActive = true;
    _lastStatusTimer.invalidate();
    _lastVisionPositionEstimateUsec = 0;
    _navSightOutputState = NavSightOutputStateUnknown;
}

void NavSightManager::_startStatusSchemaDownload()
{
    if (!_vehicle || !_navSightLink || _navSightSystemId == 0 ||
        !_vehicle->vehicleLinkManager()->containsLink(_navSightLink)) {
        qCWarning(NavSightManagerLog) << "NavSight schema download deferred: no active NavSight link/address";
        return;
    }

    _schemaRequested = true;
    _schemaFtpState = SchemaFtpState::Opening;
    _schemaDownloadData.clear();
    _schemaDownloadReceived.clear();
    _schemaReadOffset = 0;
    _schemaFtpSession = 0;
    _schemaExpectedSequence = 0;
    qCInfo(NavSightManagerLog).nospace()
        << "NavSight schema download started: target=" << _navSightSystemId << '/' << kDefaultComponentId
        << " path=/navsight_status.json";
    _sendSchemaFtpRequest(kFtpOpenFileRO, 0, 0, 0, QByteArrayLiteral("/navsight_status.json"));
}

void NavSightManager::_sendSchemaFtpRequest(uint8_t opcode, uint8_t session, uint32_t offset, uint8_t size, const QByteArray& data)
{
    if (!_vehicle || !_navSightLink || !_vehicle->vehicleLinkManager()->containsLink(_navSightLink)) {
        _handleSchemaFtpFailure(QStringLiteral("NavSight link unavailable"));
        return;
    }

    MavlinkFTP::Request request{};
    request.hdr.seqNumber = static_cast<uint16_t>(_schemaExpectedSequence + 1);
    _schemaExpectedSequence = static_cast<uint16_t>(_schemaExpectedSequence + 2);
    request.hdr.session = session;
    request.hdr.opcode = opcode;
    request.hdr.size = size == 0 && !data.isEmpty()
        ? static_cast<uint8_t>(qMin(data.size(), static_cast<int>(sizeof(request.data)))) : size;
    request.hdr.offset = offset;
    if (!data.isEmpty()) {
        std::memcpy(request.data, data.constData(), request.hdr.size);
    }

    MAVLinkProtocol* protocol = _toolbox->mavlinkProtocol();
    mavlink_message_t message{};
    mavlink_msg_file_transfer_protocol_pack_chan(protocol->getSystemId(), protocol->getComponentId(),
                                                 _navSightLink->mavlinkChannel(), &message,
                                                 0, static_cast<uint8_t>(_navSightSystemId),
                                                 static_cast<uint8_t>(kDefaultComponentId),
                                                 reinterpret_cast<uint8_t*>(&request));
    _vehicle->sendMessageOnLinkThreadSafe(_navSightLink, message);
    _schemaFtpTimer.start();

    qCInfo(NavSightManagerLog).nospace()
        << "NavSight schema FTP tx: opcode=" << static_cast<int>(opcode)
        << " seq=" << request.hdr.seqNumber << " session=" << static_cast<int>(session)
        << " offset=" << offset << " size=" << static_cast<int>(request.hdr.size)
        << " target=" << _navSightSystemId << '/' << kDefaultComponentId;
}

void NavSightManager::_handleSchemaFtpFailure(const QString& error)
{
    _schemaFtpTimer.stop();
    _schemaFtpState = SchemaFtpState::Idle;
    qCWarning(NavSightManagerLog) << "NavSight schema FTP failed:" << error
                                  << "retry=" << _schemaRetryCount << '/' << kMaxSchemaRetries;
    if (_schemaRetryCount < kMaxSchemaRetries) {
        ++_schemaRetryCount;
        _schemaRetryTimer.start();
    } else {
        // The next DATA64 starts a fresh round, as specified by NavSight.
        _schemaRequested = false;
    }
}

void NavSightManager::_schemaFtpTimeout()
{
    _handleSchemaFtpFailure(QStringLiteral("request timed out"));
}

void NavSightManager::_schemaRetryTimeout()
{
    if (_schemaRequested && !_statusSchema.valid && !_schemaRejected) {
        _startStatusSchemaDownload();
    }
}

void NavSightManager::_handleSchemaFtpMessage(const mavlink_message_t& message)
{
    if (_schemaFtpState == SchemaFtpState::Idle) {
        return;
    }

    mavlink_file_transfer_protocol_t ftp{};
    mavlink_msg_file_transfer_protocol_decode(&message, &ftp);
    if (ftp.target_system != _toolbox->mavlinkProtocol()->getSystemId()) {
        return;
    }

    const auto* request = reinterpret_cast<const MavlinkFTP::Request*>(ftp.payload);
    const uint8_t opcode = request->hdr.opcode;
    const uint8_t requestedOpcode = request->hdr.req_opcode;
    const bool isNak = opcode == kFtpNak;
    const bool isAck = opcode == kFtpAck;
    if (!isAck && !isNak) {
        return;
    }

    const auto sendTerminate = [this]() {
        _schemaFtpState = SchemaFtpState::Terminating;
        _sendSchemaFtpRequest(kFtpTerminateSession, _schemaFtpSession, 0, 0);
    };
    const auto firstMissingOffset = [this]() -> int {
        for (int index = 0; index < _schemaDownloadReceived.size(); ++index) {
            if (!_schemaDownloadReceived.testBit(index)) {
                return index;
            }
        }
        return -1;
    };

    if (_schemaFtpState == SchemaFtpState::Bursting && requestedOpcode == kFtpBurstReadFile) {
        if (request->hdr.session != _schemaFtpSession) {
            return;
        }
        if (isNak) {
            if (request->hdr.size > 0 && request->data[0] == kFtpErrUnknownCommand) {
                qCInfo(NavSightManagerLog) << "NavSight schema FTP: BurstRead unsupported; falling back to ReadFile";
                _schemaFtpState = SchemaFtpState::Reading;
                _schemaReadOffset = 0;
                _sendSchemaFtpRequest(kFtpReadFile, _schemaFtpSession, _schemaReadOffset, kFtpPayloadSize);
            } else {
                _handleSchemaFtpFailure(QStringLiteral("BurstReadFile NAK"));
            }
            return;
        }

        const uint32_t offset = request->hdr.offset;
        const uint32_t size = request->hdr.size;
        if (offset <= static_cast<uint32_t>(_schemaDownloadData.size()) &&
            size <= static_cast<uint32_t>(_schemaDownloadData.size()) - offset) {
            std::memcpy(_schemaDownloadData.data() + offset, request->data, size);
            for (uint32_t index = 0; index < size; ++index) {
                _schemaDownloadReceived.setBit(static_cast<int>(offset + index));
            }
        } else {
            _handleSchemaFtpFailure(QStringLiteral("BurstReadFile offset/size outside schema file"));
            return;
        }
        _schemaFtpTimer.start();
        if (request->hdr.burstComplete != 0) {
            const int missingOffset = firstMissingOffset();
            if (missingOffset < 0) {
                sendTerminate();
            } else {
                _sendSchemaFtpRequest(kFtpBurstReadFile, _schemaFtpSession,
                                      static_cast<uint32_t>(missingOffset), kFtpPayloadSize);
            }
        }
        return;
    }

    if (request->hdr.seqNumber != _schemaExpectedSequence) {
        qCDebug(NavSightManagerLog) << "Ignoring NavSight schema FTP reply with unexpected sequence"
                                    << request->hdr.seqNumber << "expected" << _schemaExpectedSequence;
        return;
    }

    if (_schemaFtpState == SchemaFtpState::Opening && requestedOpcode == kFtpOpenFileRO) {
        if (isNak || request->hdr.size < sizeof(uint32_t)) {
            _handleSchemaFtpFailure(QStringLiteral("OpenFileRO failed"));
            return;
        }
        uint32_t fileSize = 0;
        std::memcpy(&fileSize, request->data, sizeof(fileSize));
        if (fileSize > kMaxSchemaSizeBytes) {
            _handleSchemaFtpFailure(QStringLiteral("schema file exceeds size limit"));
            return;
        }
        _schemaFtpSession = request->hdr.session;
        _schemaDownloadData = QByteArray(static_cast<int>(fileSize), '\0');
        _schemaDownloadReceived = QBitArray(static_cast<int>(fileSize), false);
        _schemaFtpState = SchemaFtpState::Bursting;
        _sendSchemaFtpRequest(kFtpBurstReadFile, _schemaFtpSession, 0, kFtpPayloadSize);
        return;
    }

    if (_schemaFtpState == SchemaFtpState::Reading && requestedOpcode == kFtpReadFile) {
        if (isNak) {
            _handleSchemaFtpFailure(QStringLiteral("ReadFile NAK"));
            return;
        }
        const uint32_t offset = request->hdr.offset;
        const uint32_t size = request->hdr.size;
        if (request->hdr.session != _schemaFtpSession || offset != _schemaReadOffset ||
            offset > static_cast<uint32_t>(_schemaDownloadData.size()) ||
            size > static_cast<uint32_t>(_schemaDownloadData.size()) - offset) {
            _handleSchemaFtpFailure(QStringLiteral("ReadFile offset/session mismatch"));
            return;
        }
        std::memcpy(_schemaDownloadData.data() + offset, request->data, size);
        for (uint32_t index = 0; index < size; ++index) {
            _schemaDownloadReceived.setBit(static_cast<int>(offset + index));
        }
        _schemaReadOffset += size;
        if (size < kFtpPayloadSize || _schemaReadOffset >= static_cast<uint32_t>(_schemaDownloadData.size())) {
            sendTerminate();
        } else {
            _sendSchemaFtpRequest(kFtpReadFile, _schemaFtpSession, _schemaReadOffset, kFtpPayloadSize);
        }
        return;
    }

    if (_schemaFtpState == SchemaFtpState::Terminating && requestedOpcode == kFtpTerminateSession) {
        if (isNak) {
            _handleSchemaFtpFailure(QStringLiteral("TerminateSession NAK"));
            return;
        }
        QString error;
        if (!_parseStatusSchema(_schemaDownloadData, &error)) {
            qCWarning(NavSightManagerLog) << "NavSight status schema rejected:" << error;
            _schemaRejected = true;
            _schemaRequested = false;
            _finishStatusSchemaDownload();
            return;
        }
        _schemaRequested = false;
        _schemaRetryCount = 0;
        _finishStatusSchemaDownload();
        qCInfo(NavSightManagerLog).nospace()
            << "NavSight status schema loaded: type=" << _statusSchema.data64Type
            << " payloadLen=" << _statusSchema.payloadLength
            << " bitCount=" << _statusSchema.bitCount
            << " flags=" << _statusSchema.flags.size();
        return;
    }
}

void NavSightManager::_finishStatusSchemaDownload()
{
    _schemaFtpTimer.stop();
    _schemaFtpState = SchemaFtpState::Idle;
    _schemaDownloadData.clear();
    _schemaDownloadReceived.clear();
    _schemaReadOffset = 0;
    _schemaFtpSession = 0;
}

bool NavSightManager::_parseStatusSchema(const QByteArray& json, QString* error)
{
    QJsonParseError parseError{};
    const QJsonDocument document = QJsonDocument::fromJson(json, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        *error = QStringLiteral("invalid JSON");
        return false;
    }

    const QJsonObject root = document.object();
    if (!root.value(QStringLiteral("message")).isString() ||
        root.value(QStringLiteral("message")).toString() != QStringLiteral("DATA64")) {
        *error = QStringLiteral("message must be DATA64");
        return false;
    }
    const QJsonValue byteOrder = root.value(QStringLiteral("byte_order"));
    if (!byteOrder.isUndefined() && (!byteOrder.isString() || byteOrder.toString() != QStringLiteral("little endian"))) {
        *error = QStringLiteral("byte_order must be little endian");
        return false;
    }

    const auto integerOr = [&root](const QString& key, int fallback) {
        const QJsonValue value = root.value(key);
        if (!value.isDouble()) {
            return fallback;
        }
        const double number = value.toDouble();
        return std::isfinite(number) && std::floor(number) == number ? static_cast<int>(number) : fallback;
    };

    NavSightStatusSchema schema;
    schema.data64Type = static_cast<uint8_t>(integerOr(QStringLiteral("data64_type"), 0));
    schema.payloadLength = qBound(1, integerOr(QStringLiteral("payload_len"), 16), 64);
    schema.bitCount = qBound(1, integerOr(QStringLiteral("bit_count"), schema.payloadLength * 8), schema.payloadLength * 8);

    const QJsonValue flagsValue = root.value(QStringLiteral("flags"));
    if (!flagsValue.isObject()) {
        *error = QStringLiteral("flags must be an object");
        return false;
    }
    const QJsonObject flags = flagsValue.toObject();
    for (auto iterator = flags.constBegin(); iterator != flags.constEnd(); ++iterator) {
        const QString key = iterator.key();
        bool decimalKey = !key.isEmpty();
        for (const QChar character : key) {
            if (!character.isDigit()) {
                decimalKey = false;
                break;
            }
        }
        bool indexOk = false;
        const int bit = key.toInt(&indexOk, 10);
        if (!decimalKey || !indexOk || bit < 0 || bit >= schema.bitCount || !iterator.value().isString()) {
            continue;
        }
        schema.flags.insert(bit, iterator.value().toString());
    }
    if (schema.flags.isEmpty()) {
        *error = QStringLiteral("flags has no usable entries");
        return false;
    }

    schema.valid = true;
    _statusSchema = schema;
    return true;
}

void NavSightManager::_applyStatusText(const QString& text)
{
    _navSightStatusSource = NavSightStatusSource::StatusText;
    _hasData64Status = false;
    _navSightStatusText = text;
    _navSightActiveStatuses.clear();
    _navSightStatusBitmask = 0;
    _navSightStatusSeverity = text.isEmpty() ? NavSightStatusSeverityNone : NavSightStatusSeverityWarning;
    _lastStatusTimer.restart();
    emit navSightStatusChanged();
}

void NavSightManager::_applyData64Status(const mavlink_data64_t& data64)
{
    if (data64.type != _statusSchema.data64Type) {
        qCDebug(NavSightManagerLog) << "Ignoring NavSight DATA64 with schema-mismatched type=" << data64.type;
        return;
    }

    // MAVLink 2 may trim trailing zeroes. mavlink_msg_data64_decode zero-fills
    // the 64-byte array, so the schema payload length is always safe to read.
    const QByteArray bytes(reinterpret_cast<const char*>(data64.data), _statusSchema.payloadLength);
    QStringList activeStatuses;
    for (int bit = 0; bit < _statusSchema.bitCount; ++bit) {
        if ((static_cast<uint8_t>(bytes.at(bit / 8)) & (uint8_t{1} << (bit % 8))) == 0) {
            continue;
        }
        const QString name = _statusSchema.flags.value(bit, QStringLiteral("BIT_%1").arg(bit));
        if (name != QStringLiteral("RESERVED")) {
            activeStatuses.append(name);
        }
    }

    _hasData64Status = true;
    _navSightStatusSource = NavSightStatusSource::Data64;
    _statusTextFallbackActive = false;
    _navSightStatusBitmask = _lowStatusWord(bytes);
    _navSightActiveStatuses = activeStatuses;
    _navSightStatusText = activeStatuses.join(QLatin1Char('|'));
    _navSightStatusSeverity = _statusSeverity(activeStatuses);
    _initialLocationAccepted = activeStatuses.contains(QStringLiteral("READY_FOR_TAKEOFF")) ||
                               !activeStatuses.contains(QStringLiteral("WAITING_FOR_START"));
    _lastStatusTimer.restart();
    _updateOutputStateFromData64();
    emit navSightStatusChanged();
    qCInfo(NavSightManagerLog).nospace()
        << "NavSight DATA64 status accepted: type=" << data64.type
        << " payloadLen=" << _statusSchema.payloadLength
        << " status=" << _navSightStatusText;
}

void NavSightManager::_checkStatusTimeout()
{
    if (_navSightStatusSource != NavSightStatusSource::None && _lastStatusTimer.isValid() &&
        _lastStatusTimer.elapsed() > kStatusStaleTimeoutMs) {
        qCWarning(NavSightManagerLog) << "NavSight status stale after" << kStatusStaleTimeoutMs << "ms";
        _navSightStatusSource = NavSightStatusSource::None;
        _hasData64Status = false;
        _navSightStatusText = QStringLiteral("NO STATUS");
        _navSightActiveStatuses.clear();
        _navSightStatusBitmask = 0;
        _navSightStatusSeverity = NavSightStatusSeverityNone;
        _navSightOutputState = NavSightOutputStateUnknown;
        emit navSightStatusChanged();
        emit outputSignalCommandStateChanged();
    }
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
    if (!_vehicle || _navSightSystemId == 0) {
        return false;
    }

    SharedLinkInterfacePtr link = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (!link) {
        return false;
    }

    mavlink_command_long_t command{};
    command.target_system = static_cast<uint8_t>(_navSightSystemId);
    command.target_component = static_cast<uint8_t>(kDefaultComponentId);
    command.command = kUpdateLocationCommand;
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

void NavSightManager::_setOutputSignalResult(const QString& result)
{
    _lastOutputSignalResult = result;
    qCInfo(NavSightManagerLog) << "TOGGLE_OUTPUT_SIGNAL state:" << result
                               << "pending=" << _outputSignalCommandInProgress
                               << "retry=" << _outputSignalRetryCount;
    emit outputSignalCommandStateChanged();
}

bool NavSightManager::_queuePendingOutputSignalCommand()
{
    if (!_vehicle || _navSightSystemId == 0) {
        return false;
    }

    SharedLinkInterfacePtr link = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (!link) {
        return false;
    }

    mavlink_command_long_t command{};
    command.target_system = static_cast<uint8_t>(_navSightSystemId);
    command.target_component = static_cast<uint8_t>(kDefaultComponentId);
    command.command = kToggleOutputSignalCommand;
    command.confirmation = 0;
    // This is a level command, not a literal toggle: 0 resumes output and
    // any non-zero value stops visual-navigation output to the FC.
    command.param1 = _requestedOutputEnabled ? 0.0f : 1.0f;

    mavlink_message_t message{};
    MAVLinkProtocol* mavlinkProtocol = _toolbox->mavlinkProtocol();
    mavlink_msg_command_long_encode(mavlinkProtocol->getSystemId(), mavlinkProtocol->getComponentId(),
                                    &message, &command);
    _vehicle->sendMessageOnLinkThreadSafe(link.get(), message);
    _outputSignalCommandTimer.start();

    qCInfo(NavSightManagerLog).nospace()
        << "NavSight TOGGLE_OUTPUT_SIGNAL queued: msgid=" << message.msgid
        << " source=" << mavlinkProtocol->getSystemId() << '/' << mavlinkProtocol->getComponentId()
        << " target=" << static_cast<int>(command.target_system) << '/' << static_cast<int>(command.target_component)
        << " command=" << command.command << " confirmation=" << static_cast<int>(command.confirmation)
        << " param1=" << command.param1
        << " action=" << (_requestedOutputEnabled ? "resume" : "stop")
        << " primaryLink=\"" << _vehicle->vehicleLinkManager()->primaryLinkName() << '\"'
        << " retry=" << _outputSignalRetryCount;
    return true;
}

void NavSightManager::_finishOutputSignalCommand(const QString& result)
{
    _outputSignalCommandTimer.stop();
    _outputSignalCommandInProgress = false;
    _outputSignalAckReceived = false;
    _outputSignalRetryCount = 0;
    _setOutputSignalResult(result);
}

void NavSightManager::_updateOutputStateFromData64()
{
    const bool hasOutputFlag = _statusSchema.flags.values().contains(QStringLiteral("USER_DISABLED_OUTPUT"));
    const NavSightOutputState newState = !hasOutputFlag
        ? NavSightOutputStateUnknown
        : (_navSightActiveStatuses.contains(QStringLiteral("USER_DISABLED_OUTPUT"))
           ? NavSightOutputStateDisabled : NavSightOutputStateEnabled);
    if (_navSightOutputState != newState) {
        _navSightOutputState = newState;
        emit outputSignalCommandStateChanged();
        qCInfo(NavSightManagerLog) << "NavSight output state from DATA64:"
                                   << (newState == NavSightOutputStateEnabled ? "enabled"
                                       : (newState == NavSightOutputStateDisabled ? "disabled" : "unknown"));
    }

    if (_outputSignalCommandInProgress && _outputSignalAckReceived &&
        ((_requestedOutputEnabled && newState == NavSightOutputStateEnabled) ||
         (!_requestedOutputEnabled && newState == NavSightOutputStateDisabled))) {
        _finishOutputSignalCommand(_requestedOutputEnabled
            ? QStringLiteral("NavSight output resumed")
            : QStringLiteral("NavSight output stopped"));
    }
}

void NavSightManager::_outputSignalCommandTimeout()
{
    if (!_outputSignalCommandInProgress) {
        return;
    }

    if (_outputSignalAckReceived) {
        qCWarning(NavSightManagerLog) << "NavSight output command ACK received but DATA64 confirmation timed out";
        _finishOutputSignalCommand(QStringLiteral("NavSight accepted output command, but DATA64 confirmation timed out"));
        return;
    }

    if (_outputSignalRetryCount < kMaxOutputSignalRetries) {
        ++_outputSignalRetryCount;
        _setOutputSignalResult(QStringLiteral("No NavSight output ACK; retrying (%1/%2)")
                                   .arg(_outputSignalRetryCount).arg(kMaxOutputSignalRetries));
        if (_queuePendingOutputSignalCommand()) {
            return;
        }
        _finishOutputSignalCommand(QStringLiteral("No primary telemetry link for NavSight output retry"));
        return;
    }

    qCWarning(NavSightManagerLog) << "NavSight output command timed out after retries";
    _finishOutputSignalCommand(QStringLiteral("No NavSight response for output command"));
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
    if ((sourceSet == 2 && !_visualNavigationSourceConfigured) ||
        (sourceSet == 3 && !_deadReckoningSourceConfigured)) {
        qCWarning(NavSightManagerLog) << "EKF source set rejected locally: VIS/DR requires an EK3_SRCx_POSXY configured for ExternalNav";
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

    // Do not use sysid 10 as a send fallback. Version 1.2.X permits a
    // configurable NavSight sysid and ignores broadcast commands, so an
    // address learned from the component-192 heartbeat is required.
    if (!_navSightOnline || _navSightSystemId == 0) {
        qCWarning(NavSightManagerLog) << "UPDATE_LOCATION rejected locally: NavSight address has not been discovered";
        _setUpdateLocationResult(QStringLiteral("Waiting for NavSight heartbeat"));
        return false;
    }

    qCInfo(NavSightManagerLog).nospace()
        << "UPDATE_LOCATION requested: latitude=" << latitude << " longitude=" << longitude
        << " vehicle=" << _vehicle->id() << " flying=" << _vehicle->flying()
        << " navSightTarget=" << _navSightSystemId << '/' << kDefaultComponentId
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

bool NavSightManager::setNavSightOutputEnabled(bool enabled)
{
    if (_outputSignalCommandInProgress) {
        _setOutputSignalResult(QStringLiteral("NavSight output command already pending"));
        return false;
    }
    if (!_vehicle) {
        qCWarning(NavSightManagerLog) << "NavSight output command rejected locally: no active vehicle";
        _setOutputSignalResult(QStringLiteral("No active vehicle"));
        return false;
    }
    if (!_navSightOnline || _navSightSystemId == 0) {
        qCWarning(NavSightManagerLog) << "NavSight output command rejected locally: address has not been discovered";
        _setOutputSignalResult(QStringLiteral("Waiting for NavSight heartbeat"));
        return false;
    }
    if (!_vehicle->vehicleLinkManager()->primaryLink().lock()) {
        qCWarning(NavSightManagerLog) << "NavSight output command rejected locally: no primary telemetry link";
        _setOutputSignalResult(QStringLiteral("No primary telemetry link"));
        return false;
    }

    if ((enabled && _navSightOutputState == NavSightOutputStateEnabled) ||
        (!enabled && _navSightOutputState == NavSightOutputStateDisabled)) {
        _setOutputSignalResult(enabled
            ? QStringLiteral("NavSight output is already enabled")
            : QStringLiteral("NavSight output is already stopped"));
        return true;
    }

    _requestedOutputEnabled = enabled;
    _outputSignalAckReceived = false;
    _outputSignalRetryCount = 0;
    _outputSignalCommandInProgress = true;
    _setOutputSignalResult(enabled
        ? QStringLiteral("Resuming NavSight output...")
        : QStringLiteral("Stopping NavSight output..."));

    if (!_queuePendingOutputSignalCommand()) {
        _finishOutputSignalCommand(QStringLiteral("No primary telemetry link"));
        return false;
    }

    _setOutputSignalResult(enabled
        ? QStringLiteral("Resume output command sent; awaiting ACK")
        : QStringLiteral("Stop output command sent; awaiting ACK"));
    return true;
}
