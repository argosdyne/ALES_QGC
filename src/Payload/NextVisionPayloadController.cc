#include "NextVisionPayloadController.h"

#include <limits>

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
        channel = std::numeric_limits<uint16_t>::max(); // 0xFFFF = ignore
    }
    _channels[0] = kCenter; // CH1 pan/yaw
    _channels[1] = kCenter; // CH2 tilt/pitch
    _channels[2] = kCenter; // CH3 zoom in/stop/out
    _channels[3] = kCenter; // CH4 stow/OBS/pilot preset
    _channels[4] = kCenter; // CH5 snapshot
    _channels[5] = kCenter; // CH6 record

    _txTimer = new QTimer(this);
    _txTimer->setInterval(40); // ~25 Hz base tick
    connect(_txTimer, &QTimer::timeout, this, &NextVisionPayloadController::_tick);
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
    _txTimer->start();
    _beginConnecting(); // "connected" only once the autopilot actually answers (see _handleMavlinkMessage)
}

void NextVisionPayloadController::gimbalMove(int pan, int tilt)
{
    pan  = qBound(-1, pan, 1);
    tilt = qBound(-1, tilt, 1);
    _channels[0] = _clampPwm(kCenter + pan  * _offset); // CH1 pan  (RIGHT = high)
    _channels[1] = _clampPwm(kCenter - tilt * _offset); // CH2 tilt (UP = low on this rig)
    // The ~25 Hz tick streams this setpoint; don't send here or the idle-settle count is disturbed.
}

void NextVisionPayloadController::gimbalAxis(double pan, double tilt)
{
    pan  = qBound(-1.0, pan,  1.0);
    tilt = qBound(-1.0, tilt, 1.0);
    _channels[0] = _clampPwm(kCenter + static_cast<int>(pan  * _offset)); // proportional pan
    _channels[1] = _clampPwm(kCenter - static_cast<int>(tilt * _offset)); // proportional tilt
}

void NextVisionPayloadController::gimbalHome()
{
    // Stow/OBS/Pilot is configured on CH4. The working rig maps Pilot/Home to low.
    // Hold Pilot long enough to trigger the move, then return to OBS.
    _pulseChannel(3, kPwmMin, 3000, kCenter);
}

void NextVisionPayloadController::zoomIn()
{
    _channels[2] = kPwmMax; // CH3 zoom-in
}

void NextVisionPayloadController::zoomOut()
{
    _channels[2] = kPwmMin; // CH3 zoom-out
}

void NextVisionPayloadController::stopZoom()
{
    _channels[2] = kCenter; // CH3 zoom stop
}

void NextVisionPayloadController::captureImage()
{
    _pulseChannel(4, kPwmMax, 500, kCenter); // CH5 snapshot pulse
}

void NextVisionPayloadController::startRecording()
{
    _channels[5] = kPwmMax; // CH6 record high, held until stopRecording
}

void NextVisionPayloadController::stopRecording()
{
    _pulseChannel(5, kPwmMin, 500, kCenter); // CH6 stop pulse, then neutral
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
    uint16_t ch1 = _channels[0];
    uint16_t ch2 = _channels[1];

    // Idle-hold: once the sticks are centered, stream a brief neutral (1500) to halt any
    // residual slew, then STOP overriding (0xFFFF) so the gimbal holds via its own
    // stabilisation. A constant 1500 jitters; 0 would release to the RC radio and fight.
    if (ch1 == kCenter && ch2 == kCenter) {
        if (_idleSettle < kIdleSettleTicks) {
            ++_idleSettle;
        } else {
            ch1 = 0xFFFF;
            ch2 = 0xFFFF;
        }
    } else {
        _idleSettle = 0;
    }

    mavlink_message_t message;
    // CH1 = pan/yaw, CH2 = tilt/pitch, CH3 = zoom, CH4 = home preset,
    // CH5 = snapshot, CH6 = record; CH7-8 ignored (0xFFFF); CH9-18 unused (0 = ignore).
    mavlink_msg_rc_channels_override_pack(_senderSysId,
                                          _senderCompId,
                                          &message,
                                          _targetSysId,
                                          _targetCompId,
                                          ch1,    ch2,    _channels[2], _channels[3],
                                          _channels[4], _channels[5], 0xFFFF, 0xFFFF,
                                          0,      0,      0,      0,
                                          0,      0,      0,      0,
                                          0,      0);
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
    // Latch the autopilot target from its heartbeat (ignore our own echoes).
    if (message.msgid == MAVLINK_MSG_ID_HEARTBEAT && message.compid != _senderCompId) {
        _targetSysId  = message.sysid;
        _targetCompId = message.compid;
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
