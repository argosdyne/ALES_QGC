/// @file NextVisionPayloadController.h
/// @brief NextVision DragonEye2 pan/tilt control via RC_CHANNELS_OVERRIDE.
///
/// The DragonEye2 gimbal sits behind an ArduPilot flight controller reached over
/// UDP (default 192.168.2.28:10038). Pan/tilt are driven with RC_CHANNELS_OVERRIDE:
///   CH10 = roll/pan/yaw, CH9 = pitch/tilt, 1500 center, 1500 +/- offset.
///   CH6 = stow/OBS/pilot reset, CH11 = zoom in/stop/out, CH12 = snapshot,
///   CH13 = record.
///
/// Critical protocol details (from the working NextVisionGimbalMaui app):
///  - Sender system id MUST match the rig's ArduPilot SYSID_MYGCS. aq2apm45.param sets it to
///    255 (the QGC default), so we send as 255; a mismatched id is silently ignored.
///  - The override must be streamed continuously (~25 Hz) or ArduPilot times it out.
///  - HEARTBEAT ~1 Hz and REQUEST_DATA_STREAM ~0.5 Hz keep the link/telemetry alive.

#pragma once

#include "PayloadController.h"

#include <QPointer>

class QTimer;
class Vehicle;

class NextVisionPayloadController : public PayloadController
{
    Q_OBJECT

    Q_PROPERTY(int speedOffset READ speedOffset WRITE setSpeedOffset NOTIFY speedChanged)
    Q_PROPERTY(double pitch READ pitch NOTIFY attitudeChanged)
    Q_PROPERTY(double yaw   READ yaw   NOTIFY attitudeChanged)
    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(bool vehicleControlAvailable READ vehicleControlAvailable NOTIFY vehicleControlAvailableChanged)

public:
    explicit NextVisionPayloadController(QObject* parent = nullptr);

    QString displayName() const override { return QStringLiteral("NextVision"); }

    int  speedOffset() const { return _offset; }
    void setSpeedOffset(int offset);
    double pitch() const { return _pitch; }
    double yaw()   const { return _yaw; }
    bool recording() const { return _recording; }
    bool vehicleControlAvailable() const { return _vehicleControlAvailable; }

    void setVehicle(Vehicle* vehicle);
    void setVehicleControlEnabled(bool enabled);

    void connectPayload() override;
    void disconnectPayload() override;
    void gimbalMove(int pan, int tilt) override;
    void gimbalAxis(double pan, double tilt) override;   // proportional (joystick)
    void gimbalHome() override;
    void zoomIn() override;
    void zoomOut() override;
    void stopZoom() override;
    Q_INVOKABLE void stepZoom(int direction);
    void captureImage() override;
    void startRecording() override;
    void stopRecording() override;

signals:
    void speedChanged();
    void attitudeChanged();
    void zoomStepTriggered(int direction);
    void photoCaptureTriggered();
    void recordingChanged();
    void vehicleControlAvailableChanged();

protected:
    void _handleMavlinkMessage(const mavlink_message_t& message) override;
    void _onIpChanged() override;

private slots:
    void _tick();
    void _updateTransport();

private:
    void _sendRcOverride();
    void _sendHeartbeat();
    void _sendRequestDataStream();
    uint16_t _clampPwm(int pwm) const;
    void _pulseChannel(int channelIndex, uint16_t value, int durationMs, uint16_t restoreValue);
    void _clearAllChannels();
    void _clearAuxiliaryChannels();
    bool _useVehicleTransport() const;

    QTimer* _txTimer = nullptr;
    QTimer* _zoomStepTimer = nullptr;
    int      _zoomStepDirection = 0;
    bool     _recording = false;
    quint32 _tickCount = 0;
    QPointer<Vehicle> _vehicle;
    bool _vehicleControlEnabled = false;
    bool _vehicleControlAvailable = false;
    bool _directTransportStarted = false;

    uint16_t _channels[18];
    int      _offset = 400;              // PWM deflection from center (50..500)
    static constexpr int  kCenter = 1500;
    static constexpr int  kPwmMin = 1000;
    static constexpr int  kPwmMax = 2000;
    static constexpr int  kZoomPwmMin = 1050;
    static constexpr int  kZoomPwmMax = 1950;
    // Keep both directions symmetric. The earlier shorter zoom-out pulse was
    // calibrated while RC overrides were intermittently sent to the wrong
    // MAVLink component, so xN -> x1 did not return the lens to the same FOV.
    static constexpr int  kZoomInStepDurationMs  = 800;
    static constexpr int  kZoomOutStepDurationMs = 800;
    static constexpr uint16_t kIgnore = 0xFFFF;
    static constexpr int  kPanChannelIndex      = 9;  // CH10 Roll / pan-yaw
    static constexpr int  kTiltChannelIndex     = 8;  // CH9 Pitch / tilt
    static constexpr int  kZoomControlChannelIndex = 10; // CH11 Zoom-In/Stop/Zoom-Out
    static constexpr int  kSnapshotChannelIndex    = 11; // CH12 Snapshot
    static constexpr int  kRecordChannelIndex      = 12; // CH13 Record
    static constexpr int  kHomeModeChannelIndex    = 5;  // CH6 Stow/OBS/Pilot

    // ArduPilot target; learned from HEARTBEAT, defaults to 1/1.
    uint8_t _targetSysId  = 1;
    uint8_t _targetCompId = 1;

    // Idle-hold: after the sticks center, stream a brief neutral (1500) to halt residual
    // slew, then stop overriding (0xFFFF) so the gimbal holds via its own stabilisation.
    int _idleSettle = 0;
    static constexpr int kIdleSettleTicks = 12;

    // Live attitude decoded from the autopilot ATTITUDE(#30) message (degrees).
    double _pitch = 0.0;
    double _yaw   = 0.0;

    static constexpr quint16 kPort = 10038;
    static const char* kDefaultIp;
};
