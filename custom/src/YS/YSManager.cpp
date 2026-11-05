#include "YSManager.h"

#include "QGCApplication.h"
#include "MAVLinkProtocol.h"
#include "QGCMAVLink.h"
#include "VehicleLinkManager.h"
#include "CustomPlugin.h"
#include "CustomSettings.h"

#include <QQmlEngine>
#include <QTime>
#include <cstring>

#ifndef MAV_CMD_DO_GET_PARAMETER
// YellowScan custom get-parameter command.
#define MAV_CMD_DO_GET_PARAMETER static_cast<MAV_CMD>(31013) // MAV_CMD_USER_4
#endif

YSManager::YSManager(QGCApplication* app, QGCToolbox* toolbox)
    : QGCTool(app, toolbox)
{
    _statusPollTimer.setInterval(500);
    _statusPollTimer.setSingleShot(false);
    connect(&_statusPollTimer, &QTimer::timeout, this, &YSManager::_checkStatusTimeout);

    _powerStatusResetTimer.setSingleShot(true);
    _powerStatusResetTimer.setInterval(static_cast<int>(10000));
    connect(&_powerStatusResetTimer, &QTimer::timeout, this, &YSManager::_restorePowerStatus);

    _testTimer.setSingleShot(true);
    _testTimer.setInterval(kTestTimeoutMs);
    connect(&_testTimer, &QTimer::timeout, this, &YSManager::_testTimeout);

    // YS-03: Get Status poll + LiDAR state refresh
    _getStatusPollTimer.setInterval(kStatusPollIntervalMs);
    _getStatusPollTimer.setSingleShot(false);
    connect(&_getStatusPollTimer, &QTimer::timeout, this, &YSManager::_statusPollTick);
    connect(this, &YSManager::statusChanged,      this, &YSManager::_refreshLidarState);
    connect(this, &YSManager::statusValidChanged, this, &YSManager::_refreshLidarState);

    _commandTimer.start();
    _statusRequestTimer.start();
    _paramRequestTimer.start();
}

void YSManager::setToolbox(QGCToolbox* toolbox)
{
    QGCTool::setToolbox(toolbox);

    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
    qmlRegisterUncreatableType<YSManager>("CustomQuickInterface", 1, 0, "YSManager", "Reference only");

    MultiVehicleManager* manager = _toolbox->multiVehicleManager();
    _setActiveVehicle(manager->activeVehicle());
    connect(manager, &MultiVehicleManager::activeVehicleChanged, this, &YSManager::_setActiveVehicle);

    _statusTimer.start();
    _statusPollTimer.start();
    _getStatusPollTimer.start();
}

void YSManager::_setActiveVehicle(Vehicle* vehicle)
{
    if (_vehicle) {
        disconnect(_vehicle, &Vehicle::mavlinkMessageReceived, this, &YSManager::_mavlinkReceived);
        disconnect(_vehicle->vehicleLinkManager(), &VehicleLinkManager::communicationLostChanged, this, &YSManager::_refreshLidarState);
    }
    _vehicle = vehicle;
    if (_vehicle) {
        connect(_vehicle, &Vehicle::mavlinkMessageReceived, this, &YSManager::_mavlinkReceived);
        connect(_vehicle->vehicleLinkManager(), &VehicleLinkManager::communicationLostChanged, this, &YSManager::_refreshLidarState);
    }
    // States tied to the previous vehicle no longer apply
    _poweredOff = false;
    _acqTransition = AcqNone;
    _refreshLidarState();
}

void YSManager::_mavlinkReceived(const mavlink_message_t& message)
{
    if (message.msgid == MAVLINK_MSG_ID_NAMED_VALUE_INT) {
        mavlink_named_value_int_t named{};
        mavlink_msg_named_value_int_decode(&message, &named);
        char nameBuf[MAVLINK_MSG_NAMED_VALUE_INT_FIELD_NAME_LEN + 1] = {};
        strncpy(nameBuf, named.name, MAVLINK_MSG_NAMED_VALUE_INT_FIELD_NAME_LEN);
        const QString name = QString::fromLatin1(nameBuf);

        const uint32_t value = static_cast<uint32_t>(named.value);
        const quint8 b0 = static_cast<quint8>(value & 0xFF);
        const quint8 b1 = static_cast<quint8>((value >> 8) & 0xFF);
        const quint8 b2 = static_cast<quint8>((value >> 16) & 0xFF);
        const quint8 b3 = static_cast<quint8>((value >> 24) & 0xFF);

        int paramIndex = -1;
        if (name == QStringLiteral("YS_STA_00")) {
            _updateStatus(b0, b1, b2, b3, _scnErr, _intErr, _camErr);
        } else if (name == QStringLiteral("YS_STA_01")) {
            _updateStatus(_insInfo, _scnInfo, _genInfo, _insErr, b0, b1, b2);
        } else if (name == QStringLiteral("SCN_SEN") || name == QStringLiteral("PAR1")) {
            paramIndex = ParamScannerHighSensitivity;
            _setParameterValue(paramIndex, static_cast<float>(value));
        } else if (name == QStringLiteral("SCN_PAT") || name == QStringLiteral("PAR2")) {
            paramIndex = ParamScannerPattern;
            _setParameterValue(paramIndex, static_cast<float>(value));
        } else if (name == QStringLiteral("ECAM_EN") || name == QStringLiteral("PAR3")) {
            paramIndex = ParamEmbeddedCameraEnable;
            _setParameterValue(paramIndex, static_cast<float>(value));
        } else if (name == QStringLiteral("ECAM_HEI") || name == QStringLiteral("PAR4")) {
            paramIndex = ParamEmbCamInitHeight;
            _setParameterValue(paramIndex, static_cast<float>(value));
        } else if (name == QStringLiteral("ECAM_TRIG") || name == QStringLiteral("PAR5")) {
            paramIndex = ParamEmbCamTriggerMode;
            _setParameterValue(paramIndex, static_cast<float>(value));
        } else if (name == QStringLiteral("ECAM_TRIV") || name == QStringLiteral("PAR6")) {
            paramIndex = ParamEmbCamTriggerValue;
            _setParameterValue(paramIndex, static_cast<float>(value));
        } else {
            return;
        }
        if (paramIndex >= 0) {
            // Value really came from the LiDAR (not just the local copy written by setParameter)
            _paramReceived[paramIndex] = true;
            emit parameterChanged();
        }
        _lastReceivedMessage = QStringLiteral("NAMED_VALUE_INT %1 value=0x%2").arg(name).arg(value, 8, 16, QChar('0')).toUpper();
        emit messageChanged();

        if (_testState == TestRunning) {
            if (name == QStringLiteral("YS_STA_00")) {
                _testGotSta00 = true;
            } else if (name == QStringLiteral("YS_STA_01")) {
                _testGotSta01 = true;
            }
            if (_testGotSta00 && _testGotSta01) {
                _finishTest(TestOk, QString());
            }
        }

        if (_pendingStatus && (name == QStringLiteral("YS_STA_00") || name == QStringLiteral("YS_STA_01"))) {
            if (!_pendingStatusQueue.isEmpty() && _pendingStatusQueue.first() == name) {
                _pendingStatusQueue.removeFirst();
            } else {
                _pendingStatusQueue.removeAll(name);
            }
            _pendingStatus = false;
            _startNextStatus();
        }

        if (_pendingOp == PendingGet && paramIndex >= 0 && paramIndex == _pendingParamIndex) {
            _pendingOp = PendingNone;
            _pendingParamIndex = -1;
            _startNextGet();
            if (_pendingOp == PendingNone) {
                _startNextSet();
            }
        }
        return;
    }

    if (message.msgid == MAVLINK_MSG_ID_COMMAND_LONG) {
        mavlink_command_long_t cmd{};
        mavlink_msg_command_long_decode(&message, &cmd);
        const bool isYellowScanCmd =
            (cmd.command == MAV_CMD_USER_1) ||
            (cmd.command == MAV_CMD_USER_2) ||
            (cmd.command == MAV_CMD_DO_SET_PARAMETER) ||
            (cmd.command == MAV_CMD_DO_GET_PARAMETER);
        if (isYellowScanCmd) {
            _lastReceivedMessage = QStringLiteral("COMMAND_LONG cmd=%1 p1=%2 p2=%3")
                                       .arg(cmd.command)
                                       .arg(cmd.param1)
                                       .arg(cmd.param2);
            emit messageChanged();
        }
        return;
    }

    if (message.msgid == MAVLINK_MSG_ID_COMMAND_ACK) {
        mavlink_command_ack_t ack{};
        mavlink_msg_command_ack_decode(&message, &ack);
        const bool isYellowScanAck =
            (ack.command == MAV_CMD_USER_1) ||
            (ack.command == MAV_CMD_USER_2) ||
            (ack.command == MAV_CMD_DO_SET_PARAMETER) ||
            (ack.command == MAV_CMD_DO_GET_PARAMETER);
        if (isYellowScanAck) {
            _lastReceivedMessage = QStringLiteral("COMMAND_ACK cmd=%1 result=%2 (%3)")
                                       .arg(ack.command)
                                       .arg(ack.result)
                                       .arg(_mavResultToString(ack.result));
            emit messageChanged();

            if (ack.command == MAV_CMD_USER_1) {
                // Any reply ends STARTING / STOPPING
                _acqTransition = AcqNone;
            }
            if (ack.command == MAV_CMD_USER_2 && ack.result == MAV_RESULT_ACCEPTED) {
                _poweredOff = true;
            }

            if (ack.command == MAV_CMD_USER_1 && ack.result == MAV_RESULT_ACCEPTED) {
                const bool startRequested = _lastCommand == MAV_CMD_USER_1 && _lastCommandParam1 > 0.5f;
                if (startRequested) {
                    kGenInfoAcqRunning = true;
                } else {
                    kGenInfoAcqRunning = false;
                }
                _lastStatusMs = _statusTimer.elapsed();
                if (!_statusValid) {
                    _statusValid = true;
                    emit statusValidChanged();
                }
                emit statusChanged();
            }

            if (ack.command == MAV_CMD_USER_2) {
                kGenInfoAcqRunning = false;
                _awaitingFreshStatus = false;
                _lastStatusMs = -1;
                if (_statusValid) {
                    _statusValid = false;
                    emit statusValidChanged();
                }
                emit statusChanged();
            }

            if (ack.command == MAV_CMD_USER_1 && ack.result != MAV_RESULT_ACCEPTED) {
                _refreshLidarState();
            }

            if (_pendingOp == PendingGet && ack.command == MAV_CMD_DO_GET_PARAMETER) {
                _pendingOp = PendingNone;
                _pendingParamIndex = -1;
                _startNextGet();
                if (_pendingOp == PendingNone) {
                    _startNextSet();
                }
            }
            if (_pendingOp == PendingSet && ack.command == MAV_CMD_DO_SET_PARAMETER) {
                _setParamSetFailed(_pendingParamIndex, ack.result != MAV_RESULT_ACCEPTED);
                _pendingOp = PendingNone;
                _pendingParamIndex = -1;
                _startNextSet();
            }
        }
        return;
    }
}

void YSManager::_updateStatus(quint8 insInfo, quint8 scnInfo, quint8 genInfo,
                              quint8 insErr, quint8 scnErr, quint8 intErr, quint8 camErr)
{
    if(!_pwrStatus) {
        return;
    }
    _insInfo = insInfo & 0x1F; // Mask to 5 bits as INS info only has 5 info flags.;
    _scnInfo = scnInfo & 0x1F; // Mask to 5 bits as scanner info only has 5 info flags.
    _genInfo = genInfo & 0x0F; // Mask to 4 bits as general info only has 4 info flags.;
    _insErr = insErr & 0x3F; // Mask to 6 bits as INS error only has 6 error flags.;
    _scnErr = scnErr & 0x1F; // Mask to 5 bits as scanner error only has 5 error flags.
    _intErr = intErr & 0x03; // Mask to 2 bits as internal error only has 2 error flags.;
    _camErr = camErr & 0x07; // Mask to 3 bits as camera error only has 3 error flags.;
    _poweredOff = false;    // LiDAR answered, so it is on again
    _lastStatusMs = _statusTimer.elapsed();
    _awaitingFreshStatus = false;
    if (!_statusValid) {
        _statusValid = true;
        emit statusValidChanged();
    }
    emit statusChanged();
}

void YSManager::_setParameterValue(int paramIndex, float value)
{
    switch (paramIndex) {
    case ParamScannerHighSensitivity:
        _scannerHighSensitivity = static_cast<int>(value);
        break;
    case ParamScannerPattern:
        _scannerPattern = static_cast<int>(value);
        break;
    case ParamEmbeddedCameraEnable:
        _embeddedCamera = static_cast<int>(value);
        break;
    case ParamEmbCamInitHeight:
        _embCamInitHeight = value;
        break;
    case ParamEmbCamTriggerMode:
        _embCamTriggerMode = static_cast<int>(value);
        break;
    case ParamEmbCamTriggerValue:
        _embCamTriggerValue = value;
        break;
    default:
        return;
    }

    emit parameterChanged();
}

void YSManager::_restorePowerStatus(void)
{
    _pwrStatus = true;
}

void YSManager::_checkStatusTimeout(void)
{
    if (_pendingOp == PendingGet) {
        const qint64 nowMs = _paramRequestTimer.elapsed();
        if ((nowMs - _lastParamRequestMs) >= kParamResponseTimeoutMs) {
            _pendingOp = PendingNone;
            _pendingParamIndex = -1;
            _startNextGet();
            if (_pendingOp == PendingNone) {
                _startNextSet();
            }
        }
    } else if (_pendingOp == PendingSet) {
        const qint64 nowMs = _paramRequestTimer.elapsed();
        if ((nowMs - _lastSetRequestMs) >= kSetResponseTimeoutMs) {
            _pendingOp = PendingNone;
            _pendingParamIndex = -1;
            _startNextSet();
        }
    }

    if (_pendingStatus && !_pendingStatusQueue.isEmpty()) {
        const qint64 nowMs = _statusRequestTimer.elapsed();
        if ((nowMs - _lastStatusRequestMs) >= kStatusResponseTimeoutMs) {
            _pendingStatus = false;
            _pendingStatusQueue.removeFirst();
            _startNextStatus();
        }
    }

    if (_lastStatusMs < 0 && _statusValid) {
        _statusValid = false;
        emit statusValidChanged();
        return;
    }

   if (_statusValid) {
        const qint64 nowMs = _statusTimer.elapsed();
        if (_lastStatusMs >= 0 && (nowMs - _lastStatusMs) > kStatusTimeoutMs) {
            _statusValid = false;
            emit statusValidChanged();
        }
   }
}

void YSManager::_sendCommand(MAV_CMD command, float param1, float param2)
{
    if (_shouldDebounceCommand(command, param1, param2)) {
        return;
    }
    _lastReceivedMessage.clear();
    mavlink_message_t msg{};
    mavlink_msg_command_long_pack(
        kYellowScanSysId,
        _compId(),
        &msg,
        kYellowScanSysId,
        _compId(),
        static_cast<uint16_t>(command),
        0,
        param1,
        param2,
        0.0f,
        0.0f,
        0.0f,
        0.0f,
        0.0f);

    const QString hex = _formatMavlinkHex(msg);
    _updateSentMessage(QStringLiteral("CMD_LONG cmd=%1 p1=%2 p2=%3 | hex=%4")
                           .arg(command)
                           .arg(param1)
                           .arg(param2)
                           .arg(hex));

    if (_vehicle) {
        SharedLinkInterfacePtr sharedLink = _vehicle->vehicleLinkManager()->primaryLink().lock();
        if (sharedLink) {
            _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), msg);
        }
    }
}

void YSManager::_sendNamedValueInt(const char* name, int32_t value)
{
    _lastReceivedMessage.clear();
    mavlink_message_t msg{};
    mavlink_msg_named_value_int_pack(
        kYellowScanSysId,
        _compId(),
        &msg,
        0,
        name,
        value);

    const QString hex = _formatMavlinkHex(msg);
    _updateSentMessage(QStringLiteral("NAMED_VALUE_INT %1 value=%2 | hex=%3")
                           .arg(QString::fromLatin1(name))
                           .arg(value)
                           .arg(hex));

    if (_vehicle) {
        SharedLinkInterfacePtr sharedLink = _vehicle->vehicleLinkManager()->primaryLink().lock();
        if (sharedLink) {
            _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), msg);
        }
    }
}

bool YSManager::_shouldDebounceCommand(MAV_CMD command, float param1, float param2)
{
    const qint64 nowMs = _commandTimer.elapsed();
    const bool sameCommand = (command == _lastCommand) &&
                             qFuzzyCompare(param1, _lastCommandParam1) &&
                             qFuzzyCompare(param2, _lastCommandParam2);
    const bool tooSoon = (nowMs - _lastCommandMs) < 150;
    if (sameCommand && tooSoon) {
        return true;
    }

    _lastCommand = command;
    _lastCommandParam1 = param1;
    _lastCommandParam2 = param2;
    _lastCommandMs = nowMs;
    return false;
}

void YSManager::_updateSentMessage(const QString& message)
{
    const qint64 nowMs = _commandTimer.elapsed();
    const bool append = (nowMs - _lastSentMs) < 300;
    if (append && !_lastSentMessage.isEmpty()) {
        _lastSentMessage.append("\n");
        _lastSentMessage.append(message);
    } else {
        _lastSentMessage = message;
    }
    _lastSentMs = nowMs;
    emit messageChanged();
}

QString YSManager::_formatMavlinkHex(const mavlink_message_t& message) const
{
    uint8_t buffer[MAVLINK_MAX_PACKET_LEN]{};
    const uint16_t len = mavlink_msg_to_send_buffer(buffer, &message);
    QStringList bytes;
    bytes.reserve(len);
    for (uint16_t i = 0; i < len; ++i) {
        bytes.append(QStringLiteral("%1").arg(buffer[i], 2, 16, QChar('0')).toUpper());
    }
    return bytes.join(' ');
}

QString YSManager::_mavResultToString(uint8_t result) const
{
    switch (result) {
    case MAV_RESULT_ACCEPTED:
        return QStringLiteral("ACCEPTED");
    case MAV_RESULT_TEMPORARILY_REJECTED:
        return QStringLiteral("TEMPORARILY_REJECTED");
    case MAV_RESULT_DENIED:
        return QStringLiteral("DENIED");
    case MAV_RESULT_UNSUPPORTED:
        return QStringLiteral("UNSUPPORTED");
    case MAV_RESULT_FAILED:
        return QStringLiteral("FAILED");
    case MAV_RESULT_IN_PROGRESS:
        return QStringLiteral("IN_PROGRESS");
    case MAV_RESULT_CANCELLED:
        return QStringLiteral("CANCELLED");
    default:
        return QStringLiteral("UNKNOWN");
    }
}

void YSManager::startAcquisition(void)
{
    _acqTransition = AcqStarting;
    _acqTransitionTimer.start();
    _refreshLidarState();
    if (_pendingStatus) {
        _hasPendingControlCommand = true;
        _pendingControlCommand    = MAV_CMD_USER_1;
        _pendingControlParam1     = 1.0f;
        _pendingControlParam2     = 0.0f;
        return;
    }
    _sendCommand(MAV_CMD_USER_1, 1.0f);
}

void YSManager::stopAcquisition(void)
{
    _acqTransition = AcqStopping;
    _acqTransitionTimer.start();
    _refreshLidarState();
    if (_pendingStatus) {
        _hasPendingControlCommand = true;
        _pendingControlCommand    = MAV_CMD_USER_1;
        _pendingControlParam1     = 0.0f;
        _pendingControlParam2     = 0.0f;
        return;
    }
    _sendCommand(MAV_CMD_USER_1, 0.0f);
}

void YSManager::powerOff(void)
{
    _pwrStatus = false;
    _powerStatusResetTimer.start();
    if (_pendingStatus) {
        _hasPendingControlCommand = true;
        _pendingControlCommand    = MAV_CMD_USER_2;
        _pendingControlParam1     = 0.0f;
        _pendingControlParam2     = 0.0f;
        return;
    }
    _sendCommand(MAV_CMD_USER_2);
}


void YSManager::setParameter(int paramIndex, float value)
{
    // If a get/status sequence is in progress, stop it so set can run immediately.
    if (_pendingOp == PendingGet) {
        _pendingOp = PendingNone;
        _pendingParamIndex = -1;
    }
    _pendingGetQueue.clear();
    _pendingStatusQueue.clear();
    _pendingStatus = false;
    _setParameterValue(paramIndex, value);
    _enqueueSetParameter(paramIndex, value);
}

void YSManager::requestParameter(int paramIndex)
{
    _enqueueGetParameter(paramIndex);
}

uint8_t YSManager::_compId(void) const
{
    CustomPlugin* plugin = qobject_cast<CustomPlugin*>(qgcApp()->toolbox()->corePlugin());
    if (plugin && plugin->settings()) {
        const uint compId = plugin->settings()->ysMavCompId()->rawValue().toUInt();
        if (compId > 0 && compId <= 255) {
            return static_cast<uint8_t>(compId);
        }
    }
    return kYellowScanDefaultCompId;
}

void YSManager::testConnection(void)
{
    if (_testState == TestRunning) {
        return;
    }
    if (!_vehicle) {
        _finishTest(TestFailed, tr("No vehicle connected"));
        return;
    }

    _testGotSta00 = false;
    _testGotSta01 = false;
    _testState = TestRunning;
    _testMessage = tr("Waiting for Get Status reply...");
    emit testChanged();

    _testTimer.start();
    requestStatus();
}

void YSManager::_testTimeout(void)
{
    if (_testState != TestRunning) {
        return;
    }
    if (_testGotSta00 || _testGotSta01) {
        _finishTest(TestFailed, tr("Partial reply (%1 missing)").arg(_testGotSta00 ? QStringLiteral("YS_STA_01") : QStringLiteral("YS_STA_00")));
    } else {
        _finishTest(TestFailed, tr("No reply from LiDAR (compid %1)").arg(_compId()));
    }
}

void YSManager::_finishTest(TestState state, const QString& message)
{
    _testTimer.stop();
    _testState = state;

    const QString timeStr = QTime::currentTime().toString(QStringLiteral("HH:mm:ss"));
    const QString sep = QStringLiteral(" ") + QChar(0x00B7) + QStringLiteral(" ");
    if (state == TestOk) {
        QStringList parts;
        parts << tr("Get Status OK");
        parts << (insNotLocked() ? tr("INS not locked") : tr("INS locked"));
        parts << (noUsb() ? tr("No USB") : (usbFull() ? tr("USB full") : tr("USB present")));
        if (scannerNotReady()) {
            parts << tr("Scanner not ready");
        }
        if (_insErr || _scnErr || _intErr || _camErr) {
            parts << tr("Error flags set");
        }
        parts << timeStr;
        _testMessage = parts.join(sep);
    } else {
        _testMessage = message + sep + timeStr;
    }
    emit testChanged();
}

void YSManager::requestStatus(void)
{
    _awaitingFreshStatus = true;
    _pendingParamIndex = -1;
    _enqueueStatusRequest("YS_STA_00");
    _enqueueStatusRequest("YS_STA_01");
    _checkStatusTimeout();
}

void YSManager::_enqueueGetParameter(int paramIndex)
{
    _pendingGetQueue.append(paramIndex);
    if (_pendingOp == PendingNone) {
        _startNextGet();
    }
}

void YSManager::_enqueueStatusRequest(const char* name)
{
    _pendingStatusQueue.append(QString::fromLatin1(name));
    if (!_pendingStatus) {
        _startNextStatus();
    }
}

void YSManager::_flushPendingControlCommand(void)
{
    if (!_hasPendingControlCommand) {
        return;
    }
    _hasPendingControlCommand = false;
    _sendCommand(_pendingControlCommand, _pendingControlParam1, _pendingControlParam2);
}

void YSManager::_startNextStatus(void)
{
    if (_pendingStatusQueue.isEmpty()) {
        _flushPendingControlCommand();
        return;
    }
    _pendingStatus = true;
    const QString name = _pendingStatusQueue.first();
    _lastStatusRequestMs = _statusRequestTimer.elapsed();
    _sendNamedValueInt(name.toLatin1().constData(), 0);
}

void YSManager::_enqueueSetParameter(int paramIndex, float value)
{
    _pendingSetQueue.append(qMakePair(paramIndex, value));
    if (_pendingOp == PendingNone) {
        _startNextSet();
    }
}

void YSManager::_startNextGet(void)
{
    if (_pendingGetQueue.isEmpty()) {
        return;
    }
    _pendingOp = PendingGet;
    _pendingParamIndex = _pendingGetQueue.takeFirst();
    _lastParamRequestMs = _paramRequestTimer.elapsed();
    _sendCommand(MAV_CMD_DO_GET_PARAMETER, static_cast<float>(_pendingParamIndex));
}

void YSManager::_startNextSet(void)
{
    if (_pendingSetQueue.isEmpty()) {
        return;
    }
    _pendingOp = PendingSet;
    const auto item = _pendingSetQueue.takeFirst();
    _pendingParamIndex = item.first;
    _pendingSetValue = item.second;
    _setParamSetFailed(_pendingParamIndex, false);
    _lastSetRequestMs = _paramRequestTimer.elapsed();
    _sendCommand(MAV_CMD_DO_SET_PARAMETER, static_cast<float>(_pendingParamIndex), static_cast<float>(_pendingSetValue));
}

void YSManager::_setParamSetFailed(int paramIndex, bool failed)
{
    if (paramIndex < 0 || paramIndex > ParamEmbCamTriggerValue) {
        return;
    }
    if (_paramSetFailed[paramIndex] == failed) {
        return;
    }
    _paramSetFailed[paramIndex] = failed;
    emit paramSetFailedChanged();
}

//-----------------------------------------------------------------------------
// YS-03 Status monitoring and pre-check

bool YSManager::_ysEnabled(void) const
{
    CustomPlugin* plugin = qobject_cast<CustomPlugin*>(qgcApp()->toolbox()->corePlugin());
    return plugin && plugin->settings() && plugin->settings()->ysEnable()->rawValue().toBool();
}

bool YSManager::_cameraInstalled(void) const
{
    // ysCamera: 0 = None
    CustomPlugin* plugin = qobject_cast<CustomPlugin*>(qgcApp()->toolbox()->corePlugin());
    return plugin && plugin->settings() && plugin->settings()->ysCamera()->rawValue().toUInt() != 0;
}

int YSManager::usbState(void) const
{
    if (!_statusValid) {
        return UsbUnknown;
    }
    if (noUsb()) {
        return UsbMissing;
    }
    return usbFull() ? UsbFull : UsbOk;
}

int YSManager::recordingSeconds(void) const
{
    return (kGenInfoAcqRunning && _recordingTimer.isValid()) ? static_cast<int>(_recordingTimer.elapsed() / 1000) : 0;
}

void YSManager::requestCameraParameters(void)
{
    requestParameter(ParamEmbeddedCameraEnable);
    requestParameter(ParamEmbCamInitHeight);
    requestParameter(ParamEmbCamTriggerMode);
    requestParameter(ParamEmbCamTriggerValue);
}

bool YSManager::cameraParamsKnown(void) const
{
    return _paramReceived[ParamEmbeddedCameraEnable] &&
           _paramReceived[ParamEmbCamInitHeight] &&
           _paramReceived[ParamEmbCamTriggerMode] &&
           _paramReceived[ParamEmbCamTriggerValue];
}

void YSManager::_statusPollTick(void)
{
    if (_acqTransition != AcqNone && _acqTransitionTimer.elapsed() > kAcqCommandAckTimeoutMs) {
        _acqTransition = AcqNone;
    }

    // 1 Hz Get Status. Only start a new cycle when the previous one is finished so the queue cannot
    // grow while the LiDAR is not answering. Status replies are matched by name, so this runs
    // independently of param get/set (requestStatus() is not used here: it resets _pendingParamIndex).
    const bool linkUp = _vehicle && !_vehicle->vehicleLinkManager()->communicationLost();
    if (_ysEnabled() && linkUp &&
            !_pendingStatus && _pendingStatusQueue.isEmpty() &&
            _testState != TestRunning) {
        _enqueueStatusRequest("YS_STA_00");
        _enqueueStatusRequest("YS_STA_01");
    }

    _refreshLidarState();
}

YSManager::LidarState YSManager::_computeLidarState(void) const
{
    if (!_ysEnabled()) {
        return StateDisabled;
    }
    if (!_vehicle || _vehicle->vehicleLinkManager()->communicationLost()) {
        return StateNoLink;
    }
    if (_poweredOff) {
        return StatePoweredOff;
    }
    if (_acqTransition == AcqStarting) {
        return StateStarting;
    }
    if (_acqTransition == AcqStopping) {
        return StateStopping;
    }
    if (!_statusValid) {
        return StateNoResponse;
    }
    // Acquisition running: existing flag set from the Start / Stop COMMAND_ACK
    if (kGenInfoAcqRunning) {
        return StateRecording;
    }
    return _unmetPreCheckCount > 0 ? StateNotReady : StateReady;
}

void YSManager::_rebuildPreChecks(void)
{
    const QString sep = QStringLiteral(" ") + QChar(0x00B7) + QStringLiteral(" ");
    auto hex = [](quint8 v) { return QStringLiteral("0x") + QStringLiteral("%1").arg(v, 2, 16, QChar('0')).toUpper(); };
    auto row = [](const QString& name, PreCheckState state, const QString& detail) {
        QVariantMap m;
        m[QStringLiteral("name")]   = name;
        m[QStringLiteral("state")]  = static_cast<int>(state);
        m[QStringLiteral("detail")] = detail;
        return m;
    };

    QVariantList list;
    int unmet = 0;
    const QString noData = QStringLiteral("--");

    // Uses the existing YSManager status decoding (insNotLocked, scannerNotReady, timeNotSet, noUsb, usbFull, error bytes)
    if (!_statusValid) {
        list << row(tr("INS / GNSS"),   PreCheckUnknown, noData);
        list << row(tr("Scanner"),      PreCheckUnknown, noData);
        list << row(tr("System time"),  PreCheckUnknown, noData);
        list << row(tr("USB stick"),    PreCheckUnknown, noData);
        list << row(tr("Camera"),       _cameraInstalled() ? PreCheckUnknown : PreCheckNotUsed,
                                        _cameraInstalled() ? noData : tr("Not used"));
        list << row(tr("Temperature"),  PreCheckUnknown, noData);
    } else {
        // INS / GNSS: lock + INS error flags (time-not-set bit is reported on its own row)
        const quint8 insErrFlags = static_cast<quint8>((_insErr & ~kInsInfoTimeNotSet) | (_insInfo & 0x01));
        if (insErrFlags) {
            list << row(tr("INS / GNSS"), PreCheckFail, tr("Error %1").arg(hex(insErrFlags)));
        } else if (insNotLocked()) {
            list << row(tr("INS / GNSS"), PreCheckFail, tr("Not locked"));
        } else {
            list << row(tr("INS / GNSS"), PreCheckOk, tr("Locked"));
        }

        // Scanner: ready + scanner error flags
        const quint8 scnErrFlags = scnErr();
        if (scnErrFlags) {
            list << row(tr("Scanner"), PreCheckFail, tr("Error %1").arg(hex(scnErrFlags)));
        } else if (scannerNotReady()) {
            list << row(tr("Scanner"), PreCheckFail, tr("Not ready"));
        } else {
            list << row(tr("Scanner"), PreCheckOk, tr("Ready"));
        }

        // System time
        list << row(tr("System time"), timeNotSet() ? PreCheckFail : PreCheckOk, timeNotSet() ? tr("Not set") : tr("Set"));

        // USB stick
        if (noUsb()) {
            list << row(tr("USB stick"), PreCheckFail, tr("Not present"));
        } else if (usbFull()) {
            list << row(tr("USB stick"), PreCheckFail, tr("Present") + sep + tr("full"));
        } else {
            list << row(tr("USB stick"), PreCheckOk, tr("Present") + sep + tr("space OK"));
        }

        // Camera: only checked when a camera is installed (LiDAR Setup > Connection > Camera)
        if (!_cameraInstalled()) {
            list << row(tr("Camera"), PreCheckNotUsed, tr("Not used"));
        } else if (_camErr) {
            list << row(tr("Camera"), PreCheckFail, tr("Error %1").arg(hex(_camErr)));
        } else {
            list << row(tr("Camera"), PreCheckOk, tr("No error"));
        }

        // Temperature: the existing status decoding has no temperature flag - row stays Unknown and is not counted as unmet
        list << row(tr("Temperature"), PreCheckUnknown, tr("Not decoded"));
    }

    for (const QVariant& v : list) {
        if (v.toMap().value(QStringLiteral("state")).toInt() == PreCheckFail) {
            unmet++;
        }
    }

    _preChecks = list;
    _unmetPreCheckCount = unmet;
}

void YSManager::_refreshLidarState(void)
{
    if (kGenInfoAcqRunning && !_wasRecording) {
        _recordingTimer.start();
    }
    _wasRecording = kGenInfoAcqRunning;

    const QVariantList oldPreChecks = _preChecks;
    const int  oldUnmet         = _unmetPreCheckCount;
    const int  oldState         = _lidarState;
    const bool oldInternalError = internalError();
    const int  oldUsb           = usbState();

    _rebuildPreChecks();
    _lidarState = _computeLidarState();

    // Alarm row timestamp = when the alarm content last changed
    if (_alarmSinceTime.isEmpty() || oldUnmet != _unmetPreCheckCount || oldInternalError != internalError()) {
        _alarmSinceTime = QTime::currentTime().toString(QStringLiteral("HH:mm:ss"));
    }

    if (oldPreChecks != _preChecks || oldUnmet != _unmetPreCheckCount || oldState != _lidarState ||
            oldInternalError != internalError() || oldUsb != usbState()) {
        emit lidarStateChanged();
    }

    const int secs = recordingSeconds();
    if (secs != _lastRecordingSeconds) {
        _lastRecordingSeconds = secs;
        emit recordingSecondsChanged();
    }
}