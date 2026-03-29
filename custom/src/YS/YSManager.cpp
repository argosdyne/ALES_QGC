#include "YSManager.h"

#include "QGCApplication.h"
#include "MAVLinkProtocol.h"
#include "QGCMAVLink.h"
#include "VehicleLinkManager.h"

#include <QQmlEngine>
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
}

void YSManager::_setActiveVehicle(Vehicle* vehicle)
{
    if (_vehicle) {
        disconnect(_vehicle, &Vehicle::mavlinkMessageReceived, this, &YSManager::_mavlinkReceived);
    }
    _vehicle = vehicle;
    if (_vehicle) {
        connect(_vehicle, &Vehicle::mavlinkMessageReceived, this, &YSManager::_mavlinkReceived);
    }
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
        _lastReceivedMessage = QStringLiteral("NAMED_VALUE_INT %1 value=0x%2").arg(name).arg(value, 8, 16, QChar('0')).toUpper();
        emit messageChanged();

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

            if (ack.command == MAV_CMD_USER_1 && ack.result == MAV_RESULT_ACCEPTED) {
                const bool startRequested = _lastCommand == MAV_CMD_USER_1 && _lastCommandParam1 > 0.5f;
                if (startRequested) {
                    _genInfo |= kGenInfoAcqRunning;
                } else {
                    _genInfo &= static_cast<quint8>(~kGenInfoAcqRunning);
                }
                _lastStatusMs = _statusTimer.elapsed();
                if (!_statusValid) {
                    _statusValid = true;
                    emit statusValidChanged();
                }
                emit statusChanged();
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
    _insInfo = insInfo;
    _scnInfo = scnInfo;
    _genInfo = genInfo;
    _insErr = insErr;
    _scnErr = scnErr;
    _intErr = intErr;
    _camErr = camErr;
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

    if (_awaitingFreshStatus && _statusValid) {
        _statusValid = false;
        emit statusValidChanged();
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
        kYellowScanCompId,
        &msg,
        kYellowScanSysId,
        kYellowScanCompId,
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
        kYellowScanCompId,
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
    _sendCommand(MAV_CMD_USER_1, 1.0f);
}

void YSManager::stopAcquisition(void)
{
    _sendCommand(MAV_CMD_USER_1, 0.0f);
}

void YSManager::powerOff(void)
{
    _sendCommand(MAV_CMD_USER_2);
}

void YSManager::applyMockStatusSample(void)
{
    // Sample payload from user log (Get Status reply bytes 5..11):
    // INS infos=0x06, Scanner infos=0x02, General infos=0x01,
    // INS errors=0x20, Scanner/Internal/Camera errors=0x00.
    _lastReceivedMessage = QStringLiteral("MOCK YS_STA_00 value=0x20010206");
    emit messageChanged();
    _updateStatus(0x06, 0x02, 0x01, 0x20, 0x00, 0x00, 0x00);
}

void YSManager::applyMockStartAcquisition(void)
{
    // Simulates ACK for MAV_CMD_USER_1 start (param1=1.0f, result=ACCEPTED).
    // MAVLink frame from log: FD 20 ... 00 00 80 3F (param1=1.0f) cmd=31010
    _lastCommand = MAV_CMD_USER_1;
    _lastCommandParam1 = 1.0f;
    _lastReceivedMessage = QStringLiteral("MOCK COMMAND_ACK cmd=31010 result=0 (ACCEPTED) [START]");
    emit messageChanged();
    _genInfo |= kGenInfoAcqRunning;
    _lastStatusMs = _statusTimer.elapsed();
    if (!_statusValid) {
        _statusValid = true;
        emit statusValidChanged();
    }
    emit statusChanged();
}

void YSManager::applyMockStopAcquisition(void)
{
    // Simulates ACK for MAV_CMD_USER_1 stop (param1=0.0f, result=ACCEPTED).
    // MAVLink frame from log: FD 20 ... 00 00 00 00 (param1=0.0f) cmd=31010
    _lastCommand = MAV_CMD_USER_1;
    _lastCommandParam1 = 0.0f;
    _lastReceivedMessage = QStringLiteral("MOCK COMMAND_ACK cmd=31010 result=0 (ACCEPTED) [STOP]");
    emit messageChanged();
    _genInfo &= static_cast<quint8>(~kGenInfoAcqRunning);
    _lastStatusMs = _statusTimer.elapsed();
    if (!_statusValid) {
        _statusValid = true;
        emit statusValidChanged();
    }
    emit statusChanged();
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

void YSManager::requestStatus(void)
{
    if (_statusValid) {
        _statusValid = false;
        emit statusValidChanged();
    }
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

void YSManager::_startNextStatus(void)
{
    if (_pendingStatusQueue.isEmpty()) {
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
