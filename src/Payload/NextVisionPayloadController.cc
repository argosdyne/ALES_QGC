#include "NextVisionPayloadController.h"

#include <cstring>

#include <QTimer>

const char* NextVisionPayloadController::kDefaultIp = "192.168.2.28";

NextVisionPayloadController::NextVisionPayloadController(QObject* parent)
    : PayloadController(parent)
{
    _senderSysId  = 255;                        // MUST match ArduPilot SYSID_MYGCS (aq2apm45.param = 255 = QGC default)
    _senderCompId = MAV_COMP_ID_MISSIONPLANNER; // 190

    _ip            = QString::fromLatin1(kDefaultIp);
    _targetAddress = QHostAddress(_ip);
    _targetPort    = kPort;
    _rtspUrl       = QStringLiteral("rtsp://%1:554/video0").arg(_ip);

    for (uint16_t& channel : _channels) {
        channel = kIgnore; // 0xFFFF = ignore
    }
    _channels[kPanChannelIndex]  = kCenter; // CH10 roll / pan-yaw
    _channels[kTiltChannelIndex] = kCenter; // CH9 pitch / tilt
    _channels[kHomeModeChannelIndex] = kCenter; // CH6 OBS idle, owned by app UI

    _txTimer = new QTimer(this);
    _txTimer->setInterval(40); // ~25 Hz base tick
    connect(_txTimer, &QTimer::timeout, this, &NextVisionPayloadController::_tick);

    // UI taps can arrive faster than one calibrated zoom pulse. Additional
    // same-direction taps extend the active pulse instead of being delayed.
    _zoomStepTimer = new QTimer(this);
    _zoomStepTimer->setSingleShot(true);
    connect(_zoomStepTimer, &QTimer::timeout, this, &NextVisionPayloadController::stopZoom);
}

void NextVisionPayloadController::_onIpChanged()
{
    _targetAddress = QHostAddress(_ip);
    setRtspUrl(QStringLiteral("rtsp://%1:554/video0").arg(_ip));
}

void NextVisionPayloadController::setSpeedOffset(int offset)
{
    offset = qBound(50, offset, 500);
    if (_offset == offset) {
        return;
    }
    _offset = offset;
    emit speedChanged();
}

void NextVisionPayloadController::connectPayload()
{
    setConnecting(true);
    _targetAddress = QHostAddress(_ip);
    _targetPort    = kPort;
    _openSocket(kPort); // bind local port == remote port (telemetry symmetry)
    _tickCount = 0;
    _channels[kHomeModeChannelIndex] = kCenter; // CH6 OBS idle on app start/reconnect
    _txTimer->start();
    _beginConnecting(); // "connected" only once the autopilot actually answers (see _handleMavlinkMessage)
}

void NextVisionPayloadController::gimbalMove(int pan, int tilt)
{
    pan  = qBound(-1, pan, 1);
    tilt = qBound(-1, tilt, 1);
    _clearAuxiliaryChannels();
    _channels[kPanChannelIndex]  = _clampPwm(kCenter + pan  * _offset); // CH10 roll/pan (RIGHT = high)
    _channels[kTiltChannelIndex] = _clampPwm(kCenter - tilt * _offset); // CH9 pitch/tilt (UP = low on this rig)
    // The ~25 Hz tick streams this setpoint; don't send here or the idle-settle count is disturbed.
}

void NextVisionPayloadController::gimbalAxis(double pan, double tilt)
{
    pan  = qBound(-1.0, pan,  1.0);
    tilt = qBound(-1.0, tilt, 1.0);
    _clearAuxiliaryChannels();
    _channels[kPanChannelIndex]  = _clampPwm(kCenter + static_cast<int>(pan  * _offset)); // proportional pan
    _channels[kTiltChannelIndex] = _clampPwm(kCenter - static_cast<int>(tilt * _offset)); // proportional tilt
}

void NextVisionPayloadController::gimbalHome()
{
    _clearAllChannels();
    _channels[kHomeModeChannelIndex] = kPwmMax; // CH6 high = Pilot/reset position
    _sendRcOverride();
    QTimer::singleShot(800, this, [this]() {
        if (_channels[kHomeModeChannelIndex] == kPwmMax) {
            _channels[kHomeModeChannelIndex] = kCenter; // CH6 center = OBS
            _sendRcOverride();
        }
    });
}

void NextVisionPayloadController::zoomIn()
{
    _zoomStepTimer->stop();
    _zoomStepDirection = 0;
    _clearAllChannels();
    _channels[kZoomControlChannelIndex] = kZoomPwmMax; // CH11 high = zoom-in
}

void NextVisionPayloadController::zoomOut()
{
    _zoomStepTimer->stop();
    _zoomStepDirection = 0;
    _clearAllChannels();
    _channels[kZoomControlChannelIndex] = kZoomPwmMin; // CH11 low = zoom-out
}

void NextVisionPayloadController::stopZoom()
{
    _zoomStepTimer->stop();
    _zoomStepDirection = 0;
    _clearAllChannels();
    _pulseChannel(kZoomControlChannelIndex, kCenter, 300, kIgnore); // CH11 center = zoom-stop
}

void NextVisionPayloadController::stepZoom(int direction)
{
    if (direction == 0) {
        return;
    }

    direction = direction > 0 ? 1 : -1;
    const int stepDuration = direction > 0 ? kZoomInStepDurationMs : kZoomOutStepDurationMs;
    int commandDuration = stepDuration;
    if (_zoomStepTimer->isActive() && _zoomStepDirection == direction) {
        commandDuration += qMax(0, _zoomStepTimer->remainingTime());
    }

    _zoomStepTimer->stop();
    _clearAllChannels();
    _channels[kZoomControlChannelIndex] = direction > 0 ? kZoomPwmMax : kZoomPwmMin;
    _sendRcOverride();
    _zoomStepDirection = direction;
    _zoomStepTimer->start(commandDuration);
    emit zoomStepTriggered(direction);
}

void NextVisionPayloadController::captureImage()
{
    // DragonEye does not report a capture state. Notify QML immediately so
    // touch and physical-button captures still get the standard short square
    // shutter feedback.
    emit photoCaptureTriggered();
    _clearAllChannels();
    _pulseChannel(kSnapshotChannelIndex, kPwmMax, 500, kIgnore); // CH12 snapshot pulse
}

void NextVisionPayloadController::startRecording()
{
    if (_recording) {
        return;
    }

    _recording = true;
    _channels[kRecordChannelIndex] = kPwmMax;
    _sendRcOverride();
    emit recordingChanged();
}

void NextVisionPayloadController::stopRecording()
{
    if (!_recording) {
        return;
    }

    _recording = false;
    _channels[kRecordChannelIndex] = kIgnore;
    _sendRcOverride();
    emit recordingChanged();
}

uint16_t NextVisionPayloadController::_clampPwm(int pwm) const
{
    return static_cast<uint16_t>(qBound(kPwmMin, pwm, kPwmMax));
}

void NextVisionPayloadController::_pulseChannel(int channelIndex, uint16_t value, int durationMs, uint16_t restoreValue)
{
    if (channelIndex < 0 || channelIndex >= 18) {
        return;
    }

    _channels[channelIndex] = value;
    QTimer::singleShot(durationMs, this, [this, channelIndex, value, restoreValue]() {
        if (_channels[channelIndex] == value) {
            _channels[channelIndex] = restoreValue;
        }
    });
}

void NextVisionPayloadController::_clearAllChannels()
{
    const bool keepObsMode = _channels[kHomeModeChannelIndex] == kCenter;

    for (uint16_t& channel : _channels) {
        channel = kIgnore;
    }
    if (keepObsMode) {
        _channels[kHomeModeChannelIndex] = kCenter;
    }
    if (_recording) {
        _channels[kRecordChannelIndex] = kPwmMax;
    }
}

void NextVisionPayloadController::_clearAuxiliaryChannels()
{
    // Joystick/gimbal updates may arrive while a queued zoom step is being
    // transmitted. Do not cut CH11 halfway through that calibrated pulse.
    if (!_zoomStepTimer->isActive()) {
        _channels[kZoomControlChannelIndex] = kIgnore;
    }
    _channels[kSnapshotChannelIndex] = kIgnore;
}

void NextVisionPayloadController::_tick()
{
    if (_tickCount % 25 == 0) {          // ~1 Hz
        _sendHeartbeat();
    }
    if (_tickCount % 50 == 0) {          // ~0.5 Hz
        _sendRequestDataStream();
    }
    _sendRcOverride();                   // every tick (~25 Hz)
    ++_tickCount;
}

void NextVisionPayloadController::_sendRcOverride()
{
    uint16_t overrideChannels[18];
    memcpy(overrideChannels, _channels, sizeof(overrideChannels));

    uint16_t panChannel = overrideChannels[kPanChannelIndex];
    uint16_t tiltChannel = overrideChannels[kTiltChannelIndex];

    // Idle-hold: once the sticks are centered, stream a brief neutral (1500) to halt any
    // residual slew, then STOP overriding (0xFFFF) so the gimbal holds via its own
    // stabilisation. A constant 1500 jitters; 0 would release to the RC radio and fight.
    if (panChannel == kCenter && tiltChannel == kCenter) {
        if (_idleSettle < kIdleSettleTicks) {
            ++_idleSettle;
        } else {
            panChannel = kIgnore;
            tiltChannel = kIgnore;
        }
    } else {
        _idleSettle = 0;
    }
    overrideChannels[kPanChannelIndex] = panChannel;
    overrideChannels[kTiltChannelIndex] = tiltChannel;

    mavlink_message_t message;
    // DragonEye2 mapping:
    // CH10 = roll/pan-yaw, CH9 = pitch/tilt, CH11 = zoom in/stop/out,
    // CH6 = stow/OBS/pilot reset, CH12 = snapshot and CH13 = record.
    // CH14/CH15 stay ignored because they are assigned externally.
    mavlink_msg_rc_channels_override_pack(_senderSysId,
                                          _senderCompId,
                                          &message,
                                          _targetSysId,
                                          _targetCompId,
                                          overrideChannels[0],
                                          overrideChannels[1],
                                          overrideChannels[2],
                                          overrideChannels[3],
                                          overrideChannels[4],
                                          overrideChannels[5],
                                          overrideChannels[6],
                                          overrideChannels[7],
                                          overrideChannels[8],
                                          overrideChannels[9],
                                          overrideChannels[10],
                                          overrideChannels[11],
                                          overrideChannels[12],
                                          overrideChannels[13],
                                          overrideChannels[14],
                                          overrideChannels[15],
                                          overrideChannels[16],
                                          overrideChannels[17]);
    _sendMessage(message);
}

void NextVisionPayloadController::_sendHeartbeat()
{
    mavlink_message_t message;
    mavlink_msg_heartbeat_pack(_senderSysId,
                               _senderCompId,
                               &message,
                               MAV_TYPE_GCS,
                               MAV_AUTOPILOT_INVALID,
                               0,
                               0,
                               MAV_STATE_ACTIVE);
    _sendMessage(message);
}

void NextVisionPayloadController::_sendRequestDataStream()
{
    mavlink_message_t message;
    mavlink_msg_request_data_stream_pack(_senderSysId,
                                         _senderCompId,
                                         &message,
                                         _targetSysId,
                                         _targetCompId,
                                         0,   // MAV_DATA_STREAM_ALL
                                         5,   // 5 Hz
                                         1);  // start
    _sendMessage(message);
}

void NextVisionPayloadController::_handleMavlinkMessage(const mavlink_message_t& message)
{
    // Port 10038 carries heartbeats from several MAVLink components. Only the
    // autopilot component accepts RC_CHANNELS_OVERRIDE; following every
    // heartbeat makes target_component oscillate (for example, 1 <-> 236) and
    // causes otherwise valid zoom/gimbal packets to be intermittently ignored.
    if (message.msgid == MAVLINK_MSG_ID_HEARTBEAT &&
            message.sysid != _senderSysId &&
            message.compid == MAV_COMP_ID_AUTOPILOT1) {
        _targetSysId  = message.sysid;
        _targetCompId = MAV_COMP_ID_AUTOPILOT1;
        _noteLinkActivity();
    } else if (message.msgid == MAVLINK_MSG_ID_ATTITUDE) {
        // ATTITUDE(#30): yaw tracks the gimbal LOS azimuth, pitch the elevation.
        _noteLinkActivity();
        mavlink_attitude_t att;
        mavlink_msg_attitude_decode(&message, &att);
        static const double kRadToDeg = 57.29577951308232;
        _pitch = att.pitch * kRadToDeg;
        _yaw   = att.yaw   * kRadToDeg;
        emit attitudeChanged();
    }
}
