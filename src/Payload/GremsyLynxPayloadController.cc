#include "GremsyLynxPayloadController.h"

#include <cmath>
#include <cstring>
#include <limits>

#include <QTimer>
#include <QDebug>
#include <QtMath>

const char* GremsyLynxPayloadController::kDefaultIp = "192.168.2.240";
constexpr double GremsyLynxPayloadController::kMinZoomLevel;
constexpr double GremsyLynxPayloadController::kMaxZoomLevel;

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

    _zoomDisplayTimer = new QTimer(this);
    _zoomDisplayTimer->setInterval(1000);
    connect(_zoomDisplayTimer, &QTimer::timeout, this, &GremsyLynxPayloadController::_updateZoomDisplay);

    _photoAfterStopTimer = new QTimer(this);
    _photoAfterStopTimer->setInterval(kPhotoStopRetryMs);
    connect(_photoAfterStopTimer, &QTimer::timeout, this, &GremsyLynxPayloadController::_retryStopRecordingForPhoto);
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
    ++_recordingCommandGeneration;
    _recordingCommandBlocked = false;
    _recordingStatusSettling = false;
    _cameraReportsRecording = false;
    _photoCapturePending = false;
    _photoStopRetryCount = 0;
    _photoAfterStopTimer->stop();
    if (_recording) {
        _recording = false;
        emit recordingChanged();
    }
    setConnecting(true);
    _targetAddress = QHostAddress(_ip);
    _targetPort    = kTargetPort;
    _openSocket();
    _sendHeartbeat();
    _heartbeatTimer->start();
    _controlTimer->start();
    _beginConnecting(); // "connected" only once the payload actually answers (see _handleMavlinkMessage)
}

void GremsyLynxPayloadController::gimbalMove(int pan, int tilt)
{
    pan  = qBound(-1, pan, 1);
    tilt = qBound(-1, tilt, 1);
    _cmdPitchDegS = static_cast<float>(tilt * _speedDegS); // UP = +pitch
    _cmdYawDegS   = static_cast<float>(pan  * _speedDegS); // RIGHT = +yaw
    _sendControl();
}

void GremsyLynxPayloadController::gimbalAxis(double pan, double tilt)
{
    pan  = qBound(-1.0, pan,  1.0);
    tilt = qBound(-1.0, tilt, 1.0);
    _cmdPitchDegS = static_cast<float>(tilt * _speedDegS); // proportional pitch
    _cmdYawDegS   = static_cast<float>(pan  * _speedDegS); // proportional yaw
    _sendControl();
}

void GremsyLynxPayloadController::gimbalHome()
{
    _cmdPitchDegS = 0.0f;
    _cmdYawDegS   = 0.0f;
    _setGimbalMode(4 /* PAYLOAD_CAMERA_GIMBAL_MODE_RESET */);
}

void GremsyLynxPayloadController::zoomIn()
{
    _sendCameraZoom(1.0f);
}

void GremsyLynxPayloadController::zoomOut()
{
    _sendCameraZoom(-1.0f);
}

void GremsyLynxPayloadController::stopZoom()
{
    _sendCameraZoom(0.0f);
}

void GremsyLynxPayloadController::stepZoom(int direction)
{
    direction = qBound(-1, direction, 1);
    if (direction == 0) {
        return;
    }

    const double nextZoom = qBound(kMinZoomLevel,
                                   _zoomLevel + static_cast<double>(direction),
                                   kMaxZoomLevel);
    if (qFuzzyCompare(_zoomLevel, nextZoom)) {
        return;
    }

    // MB1/Lynx defines C_V_ZOOM as an absolute discrete EO zoom index:
    // 0=x1, 1=x2, ... 9=x10. Unlike MAV_CMD RANGE/STEP, this maps the UI label
    // directly to the camera's real digital zoom level without timing drift.
    _sendCameraParamUInt32("C_V_ZOOM", static_cast<uint32_t>(nextZoom - 1.0));
    _zoomLevel = nextZoom;
    emit zoomLevelChanged();
}

void GremsyLynxPayloadController::captureImage()
{
    // This is UI feedback for both touch and physical-button capture paths.
    // It also selects Photo mode before a queued capture is sent.
    emit photoCaptureTriggered();

    if (_recording || _cameraReportsRecording) {
        _photoCapturePending = true;
        _photoStopRetryCount = 0;
        _startRecordingCommandGuard(false);
        _sendCameraCommand(MAV_CMD_VIDEO_STOP_CAPTURE, 0.0f);
        if (_recording) {
            _recording = false;
            emit recordingChanged();
        }
        _photoAfterStopTimer->start();
        return;
    }

    // Match Gremsy PayloadSDK: all capture parameters are zero.
    _sendCameraCommand(MAV_CMD_IMAGE_START_CAPTURE);
}

void GremsyLynxPayloadController::startRecording()
{
    if (_recording || _recordingCommandBlocked) {
        return;
    }
    _photoCapturePending = false;
    _photoAfterStopTimer->stop();
    _startRecordingCommandGuard(true);
    // Stream id 0, status reporting frequency 0 (camera default).
    _sendCameraCommand(MAV_CMD_VIDEO_START_CAPTURE, 0.0f, 0.0f);
    _recording = true;
    emit recordingChanged();
}

void GremsyLynxPayloadController::stopRecording()
{
    if (!_recording || _recordingCommandBlocked) {
        return;
    }
    _startRecordingCommandGuard(false);
    _sendCameraCommand(MAV_CMD_VIDEO_STOP_CAPTURE, 0.0f);
    _recording = false;
    emit recordingChanged();
}

void GremsyLynxPayloadController::toggleRecording()
{
    if (_recordingCommandBlocked) {
        return;
    }
    if (_recording) {
        stopRecording();
    } else {
        startRecording();
    }
}

void GremsyLynxPayloadController::_startRecordingCommandGuard(bool targetRecording)
{
    const quint32 generation = ++_recordingCommandGeneration;
    _recordingCommandTarget = targetRecording;
    _recordingCommandBlocked = true;
    _recordingStatusSettling = true;
    QTimer::singleShot(kRecordingCommandGuardMs, this, [this, generation]() {
        if (_recordingCommandGeneration == generation) {
            _recordingCommandBlocked = false;
        }
    });
    QTimer::singleShot(kRecordingStatusSettleMs, this, [this, generation]() {
        if (_recordingCommandGeneration == generation) {
            _recordingStatusSettling = false;
        }
    });
}

void GremsyLynxPayloadController::_retryStopRecordingForPhoto()
{
    if (!_photoCapturePending) {
        _photoAfterStopTimer->stop();
        return;
    }

    if (!_cameraReportsRecording || _photoStopRetryCount >= kPhotoStopMaxRetries) {
        _sendPendingPhotoCapture();
        return;
    }

    ++_photoStopRetryCount;
    _sendCameraCommand(MAV_CMD_VIDEO_STOP_CAPTURE, 0.0f);
}

void GremsyLynxPayloadController::_sendPendingPhotoCapture()
{
    if (!_photoCapturePending) {
        return;
    }

    _photoCapturePending = false;
    _photoStopRetryCount = 0;
    _photoAfterStopTimer->stop();
    _sendCameraCommand(MAV_CMD_IMAGE_START_CAPTURE);
}

void GremsyLynxPayloadController::_updateZoomDisplay()
{
    if (qFuzzyIsNull(_zoomDirection)) {
        _zoomDisplayTimer->stop();
        return;
    }

    const double nextZoom = qBound(kMinZoomLevel, _zoomLevel + _zoomDirection, kMaxZoomLevel);
    if (qFuzzyCompare(_zoomLevel, nextZoom)) {
        return;
    }

    _zoomLevel = nextZoom;
    emit zoomLevelChanged();
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

void GremsyLynxPayloadController::_sendCameraZoom(float direction)
{
    direction = qBound(-1.0f, direction, 1.0f);
    _zoomDirection = direction;

    if (qFuzzyIsNull(_zoomDirection)) {
        _zoomDisplayTimer->stop();
    } else {
        _updateZoomDisplay();
        _zoomDisplayTimer->start();
    }

    _sendCameraCommand(MAV_CMD_SET_CAMERA_ZOOM, ZOOM_TYPE_CONTINUOUS, direction);
}

void GremsyLynxPayloadController::_sendCameraCommand(MAV_CMD command,
                                                     float param1, float param2, float param3,
                                                     float param4, float param5, float param6,
                                                     float param7)
{
    mavlink_message_t message;
    mavlink_msg_command_long_pack(_senderSysId,
                                  _senderCompId,
                                  &message,
                                  _gimbalSysId,
                                  _cameraCompId,
                                  command,
                                  1, // Gremsy PayloadSDK requires confirmation=1 for camera COMMAND_LONG
                                  param1,
                                  param2,
                                  param3,
                                  param4,
                                  param5,
                                  param6,
                                  param7);
    qInfo() << "[GremsyCamera] send command" << command
            << "target" << _gimbalSysId << _cameraCompId;
    _sendMessage(message);
}

void GremsyLynxPayloadController::_setGimbalMode(uint32_t mode)
{
    _sendCameraParamUInt32("GB_MODE", mode);
}

void GremsyLynxPayloadController::_sendCameraParamUInt32(const char* paramId, uint32_t value)
{
    mavlink_param_ext_set_t param;
    memset(&param, 0, sizeof(param));
    param.target_system    = _gimbalSysId;
    param.target_component = _cameraCompId;
    strncpy(param.param_id, paramId, sizeof(param.param_id));
    memcpy(param.param_value, &value, sizeof(value));
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
        _noteLinkActivity();
    }

    if (message.msgid == MAVLINK_MSG_ID_COMMAND_ACK) {
        mavlink_command_ack_t ack;
        mavlink_msg_command_ack_decode(&message, &ack);
        if (ack.command == MAV_CMD_IMAGE_START_CAPTURE ||
                ack.command == MAV_CMD_VIDEO_START_CAPTURE ||
                ack.command == MAV_CMD_VIDEO_STOP_CAPTURE ||
                ack.command == MAV_CMD_SET_CAMERA_ZOOM) {
            qInfo() << "[GremsyCamera] command ack" << ack.command
                    << "result" << ack.result
                    << "from" << message.sysid << message.compid;

            const bool accepted = ack.result == MAV_RESULT_ACCEPTED ||
                                  ack.result == MAV_RESULT_IN_PROGRESS;
            if (!accepted && ack.command == MAV_CMD_VIDEO_START_CAPTURE && _recording) {
                _recording = false;
                emit recordingChanged();
            } else if (!accepted && ack.command == MAV_CMD_VIDEO_STOP_CAPTURE && !_recording) {
                _recording = true;
                emit recordingChanged();
            }
        }
    }

    if (message.msgid == MAVLINK_MSG_ID_CAMERA_CAPTURE_STATUS) {
        mavlink_camera_capture_status_t status;
        mavlink_msg_camera_capture_status_decode(&message, &status);
        const bool recording = status.video_status == 1;
        _cameraReportsRecording = recording;

        if (!recording && _photoCapturePending) {
            _sendPendingPhotoCapture();
        }

        // Gremsy can keep publishing the previous capture status for roughly
        // two seconds after acknowledging Start/Stop. Do not let that stale
        // status undo the requested UI state while the command settles.
        if (_recordingStatusSettling && recording != _recordingCommandTarget) {
            return;
        }
        if (_recording != recording) {
            _recording = recording;
            emit recordingChanged();
        }
        qInfo() << "[GremsyCamera] capture status image" << status.image_status
                << "video" << status.video_status;
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
