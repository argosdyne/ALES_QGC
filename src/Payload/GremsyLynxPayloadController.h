/// @file GremsyLynxPayloadController.h
/// @brief Gremsy Lynx payload control over a direct MAVLink/UDP link.
///
/// The Gremsy payload is reached DIRECTLY over UDP (default 192.168.2.240:14566),
/// bypassing the vehicle autopilot. Motion is commanded with GIMBAL_DEVICE_SET_ATTITUDE
/// in angular-velocity (speed) mode. This mirrors the working GremsyPayloadApp /
/// Gremsy PayloadSDK behaviour (heartbeat ~1 Hz, speed setpoints in rad/s).

#pragma once

#include "PayloadController.h"
#include <QRectF>

class QTimer;

class GremsyLynxPayloadController : public PayloadController
{
    Q_OBJECT

    Q_PROPERTY(double pitch READ pitch NOTIFY attitudeChanged)
    Q_PROPERTY(double roll  READ roll  NOTIFY attitudeChanged)
    Q_PROPERTY(double yaw   READ yaw   NOTIFY attitudeChanged)
    Q_PROPERTY(double zoomLevel READ zoomLevel NOTIFY zoomLevelChanged)
    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(bool trackingActive READ trackingActive NOTIFY trackingChanged)
    Q_PROPERTY(QRectF trackingImageRect READ trackingImageRect NOTIFY trackingChanged)
    Q_PROPERTY(bool objectDetectionEnabled READ objectDetectionEnabled NOTIFY objectDetectionChanged)
    Q_PROPERTY(double speedDegPerSec READ speedDegPerSec WRITE setSpeedDegPerSec NOTIFY speedChanged)

public:
    explicit GremsyLynxPayloadController(QObject* parent = nullptr);

    QString displayName() const override { return QStringLiteral("Gremsy Lynx"); }

    double pitch() const { return _pitch; }
    double roll()  const { return _roll; }
    double yaw()   const { return _yaw; }
    double zoomLevel() const { return _zoomLevel; }
    bool recording() const { return _recording; }
    bool trackingActive() const { return _trackingActive; }
    QRectF trackingImageRect() const { return _trackingImageRect; }
    bool objectDetectionEnabled() const { return _objectDetectionEnabled; }
    double speedDegPerSec() const { return _speedDegS; }
    void   setSpeedDegPerSec(double speed);

    void connectPayload() override;
    void gimbalMove(int pan, int tilt) override;
    void gimbalAxis(double pan, double tilt) override;   // proportional (joystick)
    void gimbalHome() override;
    void zoomIn() override;
    void zoomOut() override;
    void stopZoom() override;
    Q_INVOKABLE void stepZoom(int direction);
    Q_INVOKABLE void stepThermalZoom();
    void captureImage() override;
    void startRecording() override;
    void stopRecording() override;
    Q_INVOKABLE void toggleRecording();
    Q_INVOKABLE void startTrackingPoint(double x, double y, double radius = 0.05);
    Q_INVOKABLE void startTrackingRectangle(double x1, double y1, double x2, double y2);
    Q_INVOKABLE void stopTracking();
    Q_INVOKABLE void setObjectDetectionEnabled(bool enable);
    Q_INVOKABLE void toggleObjectDetection();

signals:
    void attitudeChanged();
    void zoomLevelChanged();
    void photoCaptureTriggered();
    void recordingChanged();
    void trackingChanged();
    void objectDetectionChanged();
    void speedChanged();

protected:
    void _handleMavlinkMessage(const mavlink_message_t& message) override;
    void _onIpChanged() override;

private slots:
    void _sendHeartbeat();
    void _sendControl();
    void _updateZoomDisplay();
    void _retryStopRecordingForPhoto();

private:
    void _sendGimbalSpeed(float pitchDegS, float rollDegS, float yawDegS);
    void _sendCameraZoom(float direction);
    void _sendCameraCommand(MAV_CMD command,
                            float param1 = 0.0f, float param2 = 0.0f, float param3 = 0.0f,
                            float param4 = 0.0f, float param5 = 0.0f, float param6 = 0.0f,
                            float param7 = 0.0f);
    void _sendPayloadCommand(MAV_CMD command,
                             float param1 = 0.0f, float param2 = 0.0f, float param3 = 0.0f,
                             float param4 = 0.0f, float param5 = 0.0f, float param6 = 0.0f,
                             float param7 = 0.0f);
    void _sendCameraParamUInt32(const char* paramId, uint32_t value);
    void _startRecordingCommandGuard(bool targetRecording);
    void _sendPendingPhotoCapture();
    void _setGimbalMode(uint32_t mode);
    void _setTrackingState(bool active, const QRectF& rect = QRectF());
    void _requestTrackingStatus(bool enable);
    void _sendTrackingMode(bool enable);
    void _sendTrackingPosition(float x, float y, float width, float height);
    void _updateTrackingParam(int index, float value);
    void _updateTrackingRect();

    QTimer* _heartbeatTimer = nullptr;
    QTimer* _controlTimer   = nullptr;
    QTimer* _zoomDisplayTimer = nullptr;
    QTimer* _photoAfterStopTimer = nullptr;

    // Current commanded speed (deg/s) resent continuously for robustness.
    float _cmdPitchDegS = 0.0f;
    float _cmdYawDegS   = 0.0f;
    double _speedDegS   = 70.0; // deg/s at full deflection (Gremsy only)

    // Learned targets (defaults per Gremsy PayloadSDK).
    uint8_t  _gimbalSysId  = 1;
    uint8_t  _gimbalCompId = MAV_COMP_ID_GIMBAL;   // 154
    uint8_t  _cameraCompId = MAV_COMP_ID_CAMERA;   // 100 (Camera 1 in Gremsy settings)
    uint8_t  _payloadSysId = 1;
    uint8_t  _payloadCompId = MAV_COMP_ID_USER2;   // 26 (fixed by Gremsy PayloadSDK)
    uint16_t _deviceFlags  = GIMBAL_DEVICE_FLAGS_ROLL_LOCK | GIMBAL_DEVICE_FLAGS_PITCH_LOCK;
    uint32_t _gimbalMode   = 2; // PAYLOAD_CAMERA_GIMBAL_MODE_FOLLOW
    quint32  _gimbalHomeGeneration = 0;

    double _pitch = 0.0;
    double _roll  = 0.0;
    double _yaw   = 0.0;
    double _zoomLevel = 1.0;
    float  _zoomDirection = 0.0f;
    uint32_t _thermalZoomValue = 0;
    bool   _recording = false;
    bool   _recordingCommandBlocked = false;
    bool   _recordingStatusSettling = false;
    bool   _recordingCommandTarget = false;
    bool   _cameraReportsRecording = false;
    bool   _photoCapturePending = false;
    int    _photoStopRetryCount = 0;
    quint32 _recordingCommandGeneration = 0;
    bool   _trackingActive = false;
    bool   _trackingRequested = false;
    QRectF _trackingImageRect;
    qint64 _trackingCommandGuardUntilMs = 0;
    float _trackingX = 0.0f;
    float _trackingY = 0.0f;
    float _trackingWidth = 0.0f;
    float _trackingHeight = 0.0f;
    bool _objectDetectionEnabled = false;

    static constexpr quint16 kTargetPort = 14566;
    static constexpr int kRecordingCommandGuardMs = 500;
    static constexpr int kRecordingStatusSettleMs = 2500;
    static constexpr int kPhotoStopRetryMs = 1200;
    static constexpr int kPhotoStopMaxRetries = 4;
    static constexpr int kTrackingCommandGuardMs = 2000;
    static constexpr float kTrackingCanvasWidth = 1920.0f;
    static constexpr float kTrackingCanvasHeight = 1080.0f;
    static constexpr float kTrackingPointSize = 128.0f;
    static constexpr double kMinZoomLevel = 1.0;
    static constexpr double kMaxZoomLevel = 10.0;
    static const char* kDefaultIp;
};
