/// @file GremsyLynxPayloadController.h
/// @brief Gremsy Lynx payload control over a direct MAVLink/UDP link.
///
/// The Gremsy payload is reached DIRECTLY over UDP (default 192.168.2.240:14566),
/// bypassing the vehicle autopilot. Motion is commanded with GIMBAL_DEVICE_SET_ATTITUDE
/// in angular-velocity (speed) mode. This mirrors the working GremsyPayloadApp /
/// Gremsy PayloadSDK behaviour (heartbeat ~1 Hz, speed setpoints in rad/s).

#pragma once

#include "PayloadController.h"

class QTimer;

class GremsyLynxPayloadController : public PayloadController
{
    Q_OBJECT

    Q_PROPERTY(double pitch READ pitch NOTIFY attitudeChanged)
    Q_PROPERTY(double roll  READ roll  NOTIFY attitudeChanged)
    Q_PROPERTY(double yaw   READ yaw   NOTIFY attitudeChanged)
    Q_PROPERTY(double speedDegPerSec READ speedDegPerSec WRITE setSpeedDegPerSec NOTIFY speedChanged)

public:
    explicit GremsyLynxPayloadController(QObject* parent = nullptr);

    QString displayName() const override { return QStringLiteral("Gremsy Lynx"); }

    double pitch() const { return _pitch; }
    double roll()  const { return _roll; }
    double yaw()   const { return _yaw; }
    double speedDegPerSec() const { return _speedDegS; }
    void   setSpeedDegPerSec(double speed);

    void connectPayload() override;
    void gimbalMove(int pan, int tilt) override;
    void gimbalAxis(double pan, double tilt) override;   // proportional (joystick)
    void gimbalHome() override;

signals:
    void attitudeChanged();
    void speedChanged();

protected:
    void _handleMavlinkMessage(const mavlink_message_t& message) override;
    void _onIpChanged() override;

private slots:
    void _sendHeartbeat();
    void _sendControl();

private:
    void _sendGimbalSpeed(float pitchDegS, float rollDegS, float yawDegS);
    void _setGimbalMode(uint32_t mode);

    QTimer* _heartbeatTimer = nullptr;
    QTimer* _controlTimer   = nullptr;

    // Current commanded speed (deg/s) resent continuously for robustness.
    float _cmdPitchDegS = 0.0f;
    float _cmdYawDegS   = 0.0f;
    double _speedDegS   = 50.0; // deg/s at full deflection (d-pad step / joystick scale)

    // Learned targets (defaults per Gremsy PayloadSDK).
    uint8_t  _gimbalSysId  = 1;
    uint8_t  _gimbalCompId = MAV_COMP_ID_GIMBAL;   // 154
    uint8_t  _cameraCompId = MAV_COMP_ID_CAMERA2;  // 101 (for GB_MODE param)
    uint16_t _deviceFlags  = GIMBAL_DEVICE_FLAGS_ROLL_LOCK | GIMBAL_DEVICE_FLAGS_PITCH_LOCK;

    double _pitch = 0.0;
    double _roll  = 0.0;
    double _yaw   = 0.0;

    static constexpr quint16 kTargetPort = 14566;
    static const char* kDefaultIp;
};
