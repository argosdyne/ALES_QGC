#include "GremsyLynxPayloadController.h"

#include <cmath>
#include <cstring>
#include <limits>

#include <QTimer>
#include <QtMath>

const char* GremsyLynxPayloadController::kDefaultIp = "192.168.2.240";

GremsyLynxPayloadController::GremsyLynxPayloadController(QObject* parent)
    : PayloadController(parent)
{
    _senderSysId  = 1;
    _senderCompId = MAV_COMP_ID_ONBOARD_COMPUTER; // 191 (sender id is not gated by the payload)

    _ip            = QString::fromLatin1(kDefaultIp);
    _targetAddress = QHostAddress(_ip);
    _targetPort    = kTargetPort;
    _rtspUrl       = QStringLiteral("rtsp://%1:8554/payload").arg(_ip);

    _heartbeatTimer = new QTimer(this);
    _heartbeatTimer->setInterval(1000);
    connect(_heartbeatTimer, &QTimer::timeout, this, &GremsyLynxPayloadController::_sendHeartbeat);

    _controlTimer = new QTimer(this);
    _controlTimer->setInterval(100); // 10 Hz resend of the current speed setpoint
    connect(_controlTimer, &QTimer::timeout, this, &GremsyLynxPayloadController::_sendControl);
}

void GremsyLynxPayloadController::_onIpChanged()
{
    _targetAddress = QHostAddress(_ip);
    setRtspUrl(QStringLiteral("rtsp://%1:8554/payload").arg(_ip));
}

void GremsyLynxPayloadController::setSpeedDegPerSec(double speed)
{
    speed = qBound(1.0, speed, 90.0);
    if (qFuzzyCompare(_speedDegS, speed)) {
        return;
    }
    _speedDegS = speed;
    emit speedChanged();
}

void GremsyLynxPayloadController::connectPayload()
{
    setConnecting(true);
    _targetAddress = QHostAddress(_ip);
    _targetPort    = kTargetPort;
    _openSocket();
    _sendHeartbeat();
    _heartbeatTimer->start();
    _controlTimer->start();
    setConnecting(false);
    setConnected(true);
}

void GremsyLynxPayloadController::gimbalMove(int pan, int tilt)
{
    pan  = qBound(-1, pan, 1);
    tilt = qBound(-1, tilt, 1);
    _cmdPitchDegS = static_cast<float>(tilt * _speedDegS); // UP = +pitch
    _cmdYawDegS   = static_cast<float>(pan  * _speedDegS); // RIGHT = +yaw
    _sendControl();
}

void GremsyLynxPayloadController::gimbalHome()
{
    _cmdPitchDegS = 0.0f;
    _cmdYawDegS   = 0.0f;
    _setGimbalMode(4 /* PAYLOAD_CAMERA_GIMBAL_MODE_RESET */);
}

void GremsyLynxPayloadController::_sendHeartbeat()
{
    mavlink_message_t message;
    mavlink_msg_heartbeat_pack(_senderSysId,
                               _senderCompId,
                               &message,
                               MAV_TYPE_ONBOARD_CONTROLLER,
                               MAV_AUTOPILOT_INVALID,
                               0,
                               0,
                               MAV_STATE_ACTIVE);
    _sendMessage(message);
}

void GremsyLynxPayloadController::_sendControl()
{
    _sendGimbalSpeed(_cmdPitchDegS, 0.0f, _cmdYawDegS);
}

void GremsyLynxPayloadController::_sendGimbalSpeed(float pitchDegS, float rollDegS, float yawDegS)
{
    const float nan = std::numeric_limits<float>::quiet_NaN();
    const float q[4] = { nan, nan, nan, nan };

    mavlink_message_t message;
    // angular_velocity axis order per Gremsy PayloadSDK: x=roll, y=pitch, z=yaw (rad/s).
    mavlink_msg_gimbal_device_set_attitude_pack(_senderSysId,
                                                _senderCompId,
                                                &message,
                                                _gimbalSysId,
                                                _gimbalCompId,
                                                _deviceFlags,
                                                q,
                                                qDegreesToRadians(rollDegS),
                                                qDegreesToRadians(pitchDegS),
                                                qDegreesToRadians(yawDegS));
    _sendMessage(message);
}

void GremsyLynxPayloadController::_setGimbalMode(uint32_t mode)
{
    mavlink_param_ext_set_t param;
    memset(&param, 0, sizeof(param));
    param.target_system    = _gimbalSysId;
    param.target_component = _cameraCompId;
    strncpy(param.param_id, "GB_MODE", sizeof(param.param_id));
    memcpy(param.param_value, &mode, sizeof(mode));
    param.param_type = MAV_PARAM_EXT_TYPE_UINT32;

    mavlink_message_t message;
    mavlink_msg_param_ext_set_encode(_senderSysId, _senderCompId, &message, &param);
    _sendMessage(message);
}

void GremsyLynxPayloadController::_handleMavlinkMessage(const mavlink_message_t& message)
{
    // Learn the actual gimbal / camera component ids from what the payload emits.
    const bool fromGimbal = message.compid >= MAV_COMP_ID_GIMBAL && message.compid <= MAV_COMP_ID_GIMBAL6;
    const bool fromCamera = message.compid >= MAV_COMP_ID_CAMERA && message.compid <= MAV_COMP_ID_CAMERA6;
    if (fromGimbal) {
        _gimbalSysId  = message.sysid;
        _gimbalCompId = message.compid;
    }
    if (fromCamera) {
        _cameraCompId = message.compid;
    }
    if (fromGimbal || fromCamera) {
        setConnected(true);
    }

    if (message.msgid == MAVLINK_MSG_ID_GIMBAL_DEVICE_ATTITUDE_STATUS) {
        mavlink_gimbal_device_attitude_status_t status;
        mavlink_msg_gimbal_device_attitude_status_decode(&message, &status);
        _deviceFlags = status.flags; // mirror the device's current operating flags

        float roll = 0.0f, pitch = 0.0f, yaw = 0.0f;
        mavlink_quaternion_to_euler(status.q, &roll, &pitch, &yaw);
        _roll  = qRadiansToDegrees(static_cast<double>(roll));
        _pitch = qRadiansToDegrees(static_cast<double>(pitch));
        _yaw   = qRadiansToDegrees(static_cast<double>(yaw));
        emit attitudeChanged();
    }
}
