#include "GremsyLynxPayloadController.h"

#include <cmath>
#include <cstring>
#include <limits>

#include <QTimer>
#include <QDebug>
#include <QDateTime>
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
    _trackingCommandGuardUntilMs = 0;
    _trackingRequested = false;
    _setTrackingState(false);
    _objectDetectionEnabled = false;
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
    if (_trackingActive && (pan != 0 || tilt != 0)) {
        stopTracking();
    }
    if (_gimbalMode == 4 && (pan != 0 || tilt != 0)) {
        ++_gimbalHomeGeneration;
        _gimbalMode = 2; // Resume FOLLOW when the operator moves after HOME.
        _setGimbalMode(_gimbalMode);
    }
    _cmdPitchDegS = static_cast<float>(tilt * _speedDegS); // UP = +pitch
    _cmdYawDegS   = static_cast<float>(pan  * _speedDegS); // RIGHT = +yaw
    _sendControl();
}

void GremsyLynxPayloadController::gimbalAxis(double pan, double tilt)
{
    pan  = qBound(-1.0, pan,  1.0);
    tilt = qBound(-1.0, tilt, 1.0);
    if (_trackingActive && (!qFuzzyIsNull(pan) || !qFuzzyIsNull(tilt))) {
        stopTracking();
    }
    if (_gimbalMode == 4 && (!qFuzzyIsNull(pan) || !qFuzzyIsNull(tilt))) {
        ++_gimbalHomeGeneration;
        _gimbalMode = 2; // Resume FOLLOW when the operator moves after HOME.
        _setGimbalMode(_gimbalMode);
    }
    _cmdPitchDegS = static_cast<float>(tilt * _speedDegS); // proportional pitch
    _cmdYawDegS   = static_cast<float>(pan  * _speedDegS); // proportional yaw
    _sendControl();
}

void GremsyLynxPayloadController::gimbalHome()
{
    if (_trackingActive) {
        stopTracking();
    }
    _cmdPitchDegS = 0.0f;
    _cmdYawDegS   = 0.0f;
    _gimbalMode = 4; // PAYLOAD_CAMERA_GIMBAL_MODE_RESET
    _setGimbalMode(_gimbalMode);
    _sendControl();

    // HOME is an action, not a mode to hold forever. Keeping NEUTRAL active
    // continuously fights the original APM/RC control path and makes motion slow.
    const quint32 generation = ++_gimbalHomeGeneration;
    QTimer::singleShot(1000, this, [this, generation]() {
        if (_gimbalHomeGeneration != generation || _gimbalMode != 4) {
            return;
        }
        _gimbalMode = 2; // PAYLOAD_CAMERA_GIMBAL_MODE_FOLLOW
        _setGimbalMode(_gimbalMode);
        _sendControl();
    });
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

void GremsyLynxPayloadController::stepThermalZoom()
{
    // Lynx/MB1 uses eight discrete levels: 0=x1, ... 7=x8.
    // This is intentionally independent of the gimbal control timer.
    _thermalZoomValue = (_thermalZoomValue + 1U) % 8U;
    _sendCameraParamUInt32("C_T_ZOOM", _thermalZoomValue);
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

void GremsyLynxPayloadController::startTrackingPoint(double x, double y, double radius)
{
    if (_objectDetectionEnabled) {
        setObjectDetectionEnabled(false);
    }
    x = qBound(0.0, x, 1.0);
    y = qBound(0.0, y, 1.0);
    radius = qBound(0.01, radius, 0.5);

    _cmdPitchDegS = 0.0f;
    _cmdYawDegS = 0.0f;
    _sendControl();

    const QRectF rect(qMax(0.0, x - radius),
                      qMax(0.0, y - radius),
                      qMin(1.0, x + radius) - qMax(0.0, x - radius),
                      qMin(1.0, y + radius) - qMax(0.0, y - radius));
    _trackingRequested = true;
    _trackingCommandGuardUntilMs = QDateTime::currentMSecsSinceEpoch() + kTrackingCommandGuardMs;
    _setTrackingState(true, rect);
    _requestTrackingStatus(true);
    _sendCameraParamUInt32("C_SOURCE", 1U); // PayloadSDK tracking runs on EO.
    _sendCameraParamUInt32("TRACK_MODE", 0U); // Object tracking, not object detection.
    _sendTrackingMode(true);
    _sendTrackingPosition(static_cast<float>(x) * kTrackingCanvasWidth,
                          static_cast<float>(y) * kTrackingCanvasHeight,
                          kTrackingPointSize,
                          kTrackingPointSize);
}

void GremsyLynxPayloadController::startTrackingRectangle(double x1, double y1, double x2, double y2)
{
    if (_objectDetectionEnabled) {
        setObjectDetectionEnabled(false);
    }
    const double left = qBound(0.0, qMin(x1, x2), 1.0);
    const double top = qBound(0.0, qMin(y1, y2), 1.0);
    const double right = qBound(0.0, qMax(x1, x2), 1.0);
    const double bottom = qBound(0.0, qMax(y1, y2), 1.0);
    if (right - left < 0.01 || bottom - top < 0.01) {
        return;
    }

    _cmdPitchDegS = 0.0f;
    _cmdYawDegS = 0.0f;
    _sendControl();

    const QRectF rect(left, top, right - left, bottom - top);
    _trackingRequested = true;
    _trackingCommandGuardUntilMs = QDateTime::currentMSecsSinceEpoch() + kTrackingCommandGuardMs;
    _setTrackingState(true, rect);
    _requestTrackingStatus(true);
    _sendCameraParamUInt32("C_SOURCE", 1U); // PayloadSDK tracking runs on EO.
    _sendCameraParamUInt32("TRACK_MODE", 0U); // Object tracking, not object detection.
    _sendTrackingMode(true);
    _sendTrackingPosition(static_cast<float>((left + right) * 0.5) * kTrackingCanvasWidth,
                          static_cast<float>((top + bottom) * 0.5) * kTrackingCanvasHeight,
                          static_cast<float>(right - left) * kTrackingCanvasWidth,
                          static_cast<float>(bottom - top) * kTrackingCanvasHeight);
}

void GremsyLynxPayloadController::stopTracking()
{
    _trackingRequested = false;
    _trackingCommandGuardUntilMs = 0;
    _sendTrackingMode(false);
    _requestTrackingStatus(false);
    _setTrackingState(false);
    _sendControl();
}

void GremsyLynxPayloadController::setObjectDetectionEnabled(bool enable)
{
    if (_objectDetectionEnabled == enable) {
        return;
    }

    if (enable && (_trackingRequested || _trackingActive)) {
        stopTracking();
    }

    _objectDetectionEnabled = enable;
    if (enable) {
        // PayloadSDK enables onboard detection by selecting EO and setting
        // TRACK_MODE=1. The payload renders detections into the video stream.
        _sendCameraParamUInt32("C_SOURCE", 1U);
        _sendCameraParamUInt32("TRACK_MODE", 1U);
    } else {
        _sendCameraParamUInt32("TRACK_MODE", 0U);
    }
    emit objectDetectionChanged();
}

void GremsyLynxPayloadController::toggleObjectDetection()
{
    setObjectDetectionEnabled(!_objectDetectionEnabled);
}

void GremsyLynxPayloadController::_setTrackingState(bool active, const QRectF& rect)
{
    const QRectF nextRect = active ? rect : QRectF();
    if (_trackingActive == active && _trackingImageRect == nextRect) {
        return;
    }
    _trackingActive = active;
    _trackingImageRect = nextRect;
    emit trackingChanged();
}

void GremsyLynxPayloadController::_requestTrackingStatus(bool enable)
{
    // Gremsy's MAV_CMD_SET_MESSAGE_INTERVAL param1 is its payload-parameter
    // index, not a MAVLink message id. A zero interval stops the stream.
    constexpr int firstTrackingParam = 3; // TRK_POS_X
    constexpr int lastTrackingParam = 7;  // TRK_STATUS
    const float intervalUs = enable ? 100000.0f : 0.0f;
    for (int index = firstTrackingParam; index <= lastTrackingParam; ++index) {
        _sendPayloadCommand(MAV_CMD_SET_MESSAGE_INTERVAL,
                            static_cast<float>(index), intervalUs,
                            0.0f, 0.0f, 0.0f, 0.0f, 1.0f);
    }
}

void GremsyLynxPayloadController::_sendTrackingMode(bool enable)
{
    // Gremsy custom command: group 4, operation 0, mode 0=stop / 1=active.
    _sendPayloadCommand(MAV_CMD_USER_4,
                        4.0f, 0.0f, 0.0f, enable ? 1.0f : 0.0f);
}

void GremsyLynxPayloadController::_sendTrackingPosition(float x, float y, float width, float height)
{
    // Coordinates are referenced to Gremsy's fixed 1920x1080 tracking canvas.
    _sendPayloadCommand(MAV_CMD_USER_4,
                        4.0f, 0.0f, 1.0f, x, y, width, height);
}

void GremsyLynxPayloadController::_updateTrackingParam(int index, float value)
{
    if (!qIsFinite(value)) {
        return;
    }

    switch (index) {
    case 3: _trackingX = value; break;
    case 4: _trackingY = value; break;
    case 5: _trackingWidth = value; break;
    case 6: _trackingHeight = value; break;
    case 7: {
        const int rawStatus = static_cast<int>(value);
        const int mode = (rawStatus >> 8) & 0xff;
        const int status = rawStatus & 0xff; // 0=idle, 1=tracked, 2=lost
        if (_trackingRequested && mode == 1 && status != 2) {
            _trackingCommandGuardUntilMs = 0;
            _setTrackingState(true, _trackingImageRect);
            _updateTrackingRect();
        } else if (QDateTime::currentMSecsSinceEpoch() >= _trackingCommandGuardUntilMs) {
            _setTrackingState(false);
        }
        return;
    }
    default:
        return;
    }

    _updateTrackingRect();
}

void GremsyLynxPayloadController::_updateTrackingRect()
{
    if (!_trackingActive || _trackingWidth <= 0.0f || _trackingHeight <= 0.0f) {
        return;
    }

    // The command uses the requested centre, while PayloadSDK feedback uses
    // the tracked box's top-left coordinate.
    const double width = qBound(0.0, static_cast<double>(_trackingWidth / kTrackingCanvasWidth), 1.0);
    const double height = qBound(0.0, static_cast<double>(_trackingHeight / kTrackingCanvasHeight), 1.0);
    const double left = qBound(0.0, static_cast<double>(_trackingX / kTrackingCanvasWidth), 1.0);
    const double top = qBound(0.0, static_cast<double>(_trackingY / kTrackingCanvasHeight), 1.0);
    _setTrackingState(true, QRectF(left,
                                   top,
                                   qMin(width, 1.0 - left),
                                   qMin(height, 1.0 - top)));
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
    _sendMessage(message);
}

void GremsyLynxPayloadController::_sendPayloadCommand(MAV_CMD command,
                                                       float param1, float param2, float param3,
                                                       float param4, float param5, float param6,
                                                       float param7)
{
    mavlink_message_t message;
    mavlink_msg_command_long_pack(_senderSysId,
                                  _senderCompId,
                                  &message,
                                  _payloadSysId,
                                  _payloadCompId,
                                  command,
                                  command == MAV_CMD_USER_4 ? 1 : 0,
                                  param1,
                                  param2,
                                  param3,
                                  param4,
                                  param5,
                                  param6,
                                  param7);
    _sendMessage(message);
}

void GremsyLynxPayloadController::_sendControl()
{
    // While tracking, the camera/gimbal firmware owns the pointing loop. A
    // continuous zero-speed command here would fight that loop at 10 Hz.
    if (_trackingActive) {
        return;
    }
    _sendGimbalSpeed(_cmdPitchDegS, 0.0f, _cmdYawDegS);
}

void GremsyLynxPayloadController::_sendGimbalSpeed(float pitchDegS, float rollDegS, float yawDegS)
{
    const float nan = std::numeric_limits<float>::quiet_NaN();
    const float q[4] = { nan, nan, nan, nan };

    uint16_t flags = _deviceFlags;
    if (_gimbalMode == 4) {
        flags |= GIMBAL_DEVICE_FLAGS_NEUTRAL;
    } else {
        flags &= static_cast<uint16_t>(~(GIMBAL_DEVICE_FLAGS_NEUTRAL | GIMBAL_DEVICE_FLAGS_RETRACT));
        if (_gimbalMode == 2) {
            flags &= static_cast<uint16_t>(~GIMBAL_DEVICE_FLAGS_YAW_LOCK);
        }
    }

    mavlink_message_t message;
    // angular_velocity axis order per Gremsy PayloadSDK: x=roll, y=pitch, z=yaw (rad/s).
    mavlink_msg_gimbal_device_set_attitude_pack(_senderSysId,
                                                _senderCompId,
                                                &message,
                                                _gimbalSysId,
                                                _gimbalCompId,
                                                flags,
                                                q,
                                                qDegreesToRadians(rollDegS),
                                                qDegreesToRadians(pitchDegS),
                                                qDegreesToRadians(yawDegS));
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
    const bool fromPayload = message.compid == MAV_COMP_ID_USER2;
    if (fromPayload) {
        _payloadSysId = message.sysid;
        _payloadCompId = message.compid;
    }
    if (fromGimbal || fromCamera || fromPayload) {
        _noteLinkActivity();
    }

    if (fromPayload && message.msgid == MAVLINK_MSG_ID_PARAM_VALUE) {
        mavlink_param_value_t value;
        mavlink_msg_param_value_decode(&message, &value);
        _updateTrackingParam(value.param_index, value.param_value);
    }

    if (fromPayload && message.msgid == MAVLINK_MSG_ID_DEBUG) {
        mavlink_debug_t value;
        mavlink_msg_debug_decode(&message, &value);
        _updateTrackingParam(value.ind, value.value);
    }

    if (fromCamera && message.msgid == MAVLINK_MSG_ID_PARAM_EXT_VALUE) {
        mavlink_param_ext_value_t value;
        mavlink_msg_param_ext_value_decode(&message, &value);
        const QByteArray paramId(value.param_id,
                                 static_cast<int>(strnlen(value.param_id, sizeof(value.param_id))));
        if (paramId == QByteArrayLiteral("C_T_ZOOM") &&
                value.param_type == MAV_PARAM_EXT_TYPE_UINT32) {
            uint32_t thermalZoom = 0;
            memcpy(&thermalZoom, value.param_value, sizeof(thermalZoom));
            _thermalZoomValue = qMin(thermalZoom, 7U);
        }
    }

    if (fromCamera && message.msgid == MAVLINK_MSG_ID_PARAM_EXT_ACK) {
        mavlink_param_ext_ack_t ack;
        mavlink_msg_param_ext_ack_decode(&message, &ack);
        const QByteArray paramId(ack.param_id,
                                 static_cast<int>(strnlen(ack.param_id, sizeof(ack.param_id))));
        if (ack.param_result == PARAM_ACK_ACCEPTED &&
                paramId == QByteArrayLiteral("C_T_ZOOM") &&
                ack.param_type == MAV_PARAM_EXT_TYPE_UINT32) {
            uint32_t thermalZoom = 0;
            memcpy(&thermalZoom, ack.param_value, sizeof(thermalZoom));
            _thermalZoomValue = qMin(thermalZoom, 7U);
        }
        if (paramId == QByteArrayLiteral("TRACK_MODE") &&
                _objectDetectionEnabled &&
                ack.param_result != PARAM_ACK_ACCEPTED &&
                ack.param_result != PARAM_ACK_IN_PROGRESS) {
            _objectDetectionEnabled = false;
            emit objectDetectionChanged();
        }
    }

    if (message.msgid == MAVLINK_MSG_ID_COMMAND_ACK) {
        mavlink_command_ack_t ack;
        mavlink_msg_command_ack_decode(&message, &ack);
        if (ack.command == MAV_CMD_IMAGE_START_CAPTURE ||
                ack.command == MAV_CMD_VIDEO_START_CAPTURE ||
                ack.command == MAV_CMD_VIDEO_STOP_CAPTURE ||
                ack.command == MAV_CMD_SET_CAMERA_ZOOM ||
                ack.command == MAV_CMD_USER_4) {
            const bool accepted = ack.result == MAV_RESULT_ACCEPTED ||
                                  ack.result == MAV_RESULT_IN_PROGRESS;
            if (!accepted && ack.command == MAV_CMD_VIDEO_START_CAPTURE && _recording) {
                _recording = false;
                emit recordingChanged();
            } else if (!accepted && ack.command == MAV_CMD_VIDEO_STOP_CAPTURE && !_recording) {
                _recording = true;
                emit recordingChanged();
            } else if (!accepted && ack.command == MAV_CMD_USER_4) {
                _trackingRequested = false;
                _trackingCommandGuardUntilMs = 0;
                _setTrackingState(false);
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
