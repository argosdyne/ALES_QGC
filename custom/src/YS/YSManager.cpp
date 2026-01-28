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

        if (name == QStringLiteral("YS_STA_00")) {
            _updateStatus(b0, b1, b2, b3, _scnErr, _intErr, _camErr);
        } else if (name == QStringLiteral("YS_STA_01")) {
            _updateStatus(_insInfo, _scnInfo, _genInfo, _insErr, b0, b1, b2);
        } else if (name == QStringLiteral("SCN_SEN")) {
            _setParameterValue(ParamScannerHighSensitivity, static_cast<int>(value));
        } else if (name == QStringLiteral("SCN_PAT")) {
            _setParameterValue(ParamScannerPattern, static_cast<int>(value));
        } else if (name == QStringLiteral("ECAM_EN")) {
            _setParameterValue(ParamEmbeddedCameraEnable, static_cast<int>(value));
        } else if (name == QStringLiteral("ECAM_HEI")) {
            _setParameterValue(ParamEmbCamInitHeight, static_cast<int>(value));
        } else if (name == QStringLiteral("ECAM_TRIG")) {
            _setParameterValue(ParamEmbCamTriggerMode, static_cast<int>(value));
        }
        _lastReceivedMessage = QStringLiteral("NAMED_VALUE_INT %1 value=0x%2").arg(name).arg(value, 8, 16, QChar('0')).toUpper();
        emit messageChanged();
        return;
    }

    if (message.msgid == MAVLINK_MSG_ID_COMMAND_ACK) {
        mavlink_command_ack_t ack{};
        mavlink_msg_command_ack_decode(&message, &ack);
        _lastReceivedMessage = QStringLiteral("COMMAND_ACK cmd=%1 result=%2 (%3)")
                                   .arg(ack.command)
                                   .arg(ack.result)
                                   .arg(_mavResultToString(ack.result));
        emit messageChanged();
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
    if (!_statusValid) {
        _statusValid = true;
        emit statusValidChanged();
    }
    emit statusChanged();
}

void YSManager::_setParameterValue(int paramIndex, int value)
{
    switch (paramIndex) {
    case ParamScannerHighSensitivity:
        _scannerHighSensitivity = value;
        break;
    case ParamScannerPattern:
        _scannerPattern = value;
        break;
    case ParamEmbeddedCameraEnable:
        _embeddedCamera = value;
        break;
    case ParamEmbCamInitHeight:
        _embCamInitHeight = value;
        break;
    case ParamEmbCamTriggerMode:
        _embCamTriggerMode = value;
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
    if (_lastStatusMs < 0) {
        if (_statusValid) {
            _statusValid = false;
            emit statusValidChanged();
        }
        return;
    }

    const qint64 nowMs = _statusTimer.elapsed();
    const bool validNow = (nowMs - _lastStatusMs) <= kStatusTimeoutMs;
    if (validNow != _statusValid) {
        _statusValid = validNow;
        emit statusValidChanged();
    }
}

void YSManager::_sendCommand(MAV_CMD command, float param1, float param2)
{
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
    _lastSentMessage = QStringLiteral("CMD_LONG cmd=%1 p1=%2 p2=%3 | hex=%4")
                           .arg(command)
                           .arg(param1)
                           .arg(param2)
                           .arg(hex);
    emit messageChanged();

    if (_vehicle) {
        _vehicle->sendMavCommand(kYellowScanCompId, command, false /* showError */, param1, param2);
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
    _lastSentMessage = QStringLiteral("NAMED_VALUE_INT %1 value=%2 | hex=%3")
                           .arg(QString::fromLatin1(name))
                           .arg(value)
                           .arg(hex);
    emit messageChanged();

    if (_vehicle) {
        SharedLinkInterfacePtr sharedLink = _vehicle->vehicleLinkManager()->primaryLink().lock();
        if (sharedLink) {
            _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), msg);
        }
    }
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


void YSManager::setParameter(int paramIndex, int value)
{
    _setParameterValue(paramIndex, value);
    _sendCommand(MAV_CMD_DO_SET_PARAMETER, static_cast<float>(paramIndex), static_cast<float>(value));
}

void YSManager::requestParameter(int paramIndex)
{
    _pendingParamIndex = paramIndex;
    _sendCommand(MAV_CMD_DO_GET_PARAMETER, static_cast<float>(paramIndex));
}

void YSManager::requestStatus(void)
{
    _pendingParamIndex = -1;
    _sendNamedValueInt("YS_STA_00", 0);
    _sendNamedValueInt("YS_STA_01", 0);
    _checkStatusTimeout();
}
