#include "NextVisionPayloadController.h"

#include <limits>

#include <QTimer>

const char* NextVisionPayloadController::kDefaultIp = "192.168.2.28";

NextVisionPayloadController::NextVisionPayloadController(QObject* parent)
    : PayloadController(parent)
{
    _senderSysId  = 1;                          // MUST match ArduPilot SYSID_MYGCS
    _senderCompId = MAV_COMP_ID_MISSIONPLANNER; // 190

    _ip            = QString::fromLatin1(kDefaultIp);
    _targetAddress = QHostAddress(_ip);
    _targetPort    = kPort;
    _rtspUrl       = QStringLiteral("rtsp://%1:554/video0").arg(_ip);

    for (uint16_t& channel : _channels) {
        channel = std::numeric_limits<uint16_t>::max(); // 0xFFFF = ignore
    }
    _channels[0] = kCenter;
    _channels[1] = kCenter;

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
    setConnecting(false);
    setConnected(true);
}

void NextVisionPayloadController::gimbalMove(int pan, int tilt)
{
    pan  = qBound(-1, pan, 1);
    tilt = qBound(-1, tilt, 1);
    _channels[0] = _clampPwm(kCenter + pan  * _offset); // CH1 pan  (RIGHT = high)
    _channels[1] = _clampPwm(kCenter + tilt * _offset); // CH2 tilt (UP    = high)
    _sendRcOverride(); // send immediately; the tx timer keeps streaming it
}

uint16_t NextVisionPayloadController::_clampPwm(int pwm) const
{
    return static_cast<uint16_t>(qBound(kPwmMin, pwm, kPwmMax));
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
    mavlink_message_t message;
    mavlink_msg_rc_channels_override_pack(_senderSysId,
                                          _senderCompId,
                                          &message,
                                          _targetSysId,
                                          _targetCompId,
                                          _channels[0],  _channels[1],  _channels[2],  _channels[3],
                                          _channels[4],  _channels[5],  _channels[6],  _channels[7],
                                          _channels[8],  _channels[9],  _channels[10], _channels[11],
                                          _channels[12], _channels[13], _channels[14], _channels[15],
                                          _channels[16], _channels[17]);
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
        setConnected(true);
    }
}
