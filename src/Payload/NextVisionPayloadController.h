/// @file NextVisionPayloadController.h
/// @brief NextVision DragonEye2 pan/tilt control via RC_CHANNELS_OVERRIDE.
///
/// The DragonEye2 gimbal sits behind an ArduPilot flight controller reached over
/// UDP (default 192.168.2.28:10038). Pan/tilt are driven with RC_CHANNELS_OVERRIDE:
///   CH1 = pan/yaw, CH2 = tilt/pitch, 1500 center, 1500 +/- offset.
///
/// Critical protocol details (from the working NextVisionGimbalMaui app):
///  - Sender system id MUST be 1 (ArduPilot SYSID_MYGCS gate); 255 is silently ignored.
///  - The override must be streamed continuously (~25 Hz) or ArduPilot times it out.
///  - HEARTBEAT ~1 Hz and REQUEST_DATA_STREAM ~0.5 Hz keep the link/telemetry alive.

#pragma once

#include "PayloadController.h"

class QTimer;

class NextVisionPayloadController : public PayloadController
{
    Q_OBJECT

    Q_PROPERTY(int speedOffset READ speedOffset WRITE setSpeedOffset NOTIFY speedChanged)

public:
    explicit NextVisionPayloadController(QObject* parent = nullptr);

    QString displayName() const override { return QStringLiteral("NextVision"); }

    int  speedOffset() const { return _offset; }
    void setSpeedOffset(int offset);

    void connectPayload() override;
    void gimbalMove(int pan, int tilt) override;

signals:
    void speedChanged();

protected:
    void _handleMavlinkMessage(const mavlink_message_t& message) override;
    void _onIpChanged() override;

private slots:
    void _tick();

private:
    void _sendRcOverride();
    void _sendHeartbeat();
    void _sendRequestDataStream();
    uint16_t _clampPwm(int pwm) const;

    QTimer* _txTimer = nullptr;
    quint32 _tickCount = 0;

    uint16_t _channels[18];
    int      _offset = 400;              // PWM deflection from center (50..500)
    static constexpr int  kCenter = 1500;
    static constexpr int  kPwmMin = 1000;
    static constexpr int  kPwmMax = 2000;

    // ArduPilot target; learned from HEARTBEAT, defaults to 1/1.
    uint8_t _targetSysId  = 1;
    uint8_t _targetCompId = 1;

    static constexpr quint16 kPort = 10038;
    static const char* kDefaultIp;
};
