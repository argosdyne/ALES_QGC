#pragma once

#include <QObject>
#include <QHostAddress>
#include <QString>
#include <QTimer>

#include "QGCMAVLink.h"

class LinkInterface;
class QUdpSocket;
class Vehicle;

class NextVisionController : public QObject
{
    Q_OBJECT

public:
    explicit NextVisionController(Vehicle* vehicle, QObject* parent = nullptr);

    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(int targetSystem READ targetSystem NOTIFY targetChanged)
    Q_PROPERTY(int cameraComponent READ cameraComponent NOTIFY targetChanged)
    Q_PROPERTY(int gimbalComponent READ gimbalComponent NOTIFY targetChanged)
    Q_PROPERTY(QString ipAddress READ ipAddress CONSTANT)
    Q_PROPERTY(QString rtspUrl READ rtspUrl CONSTANT)
    Q_PROPERTY(QString rcIpAddress READ rcIpAddress NOTIFY rcSettingsChanged)
    Q_PROPERTY(int rcPort READ rcPort CONSTANT)
    Q_PROPERTY(int rcTargetSystem READ rcTargetSystem NOTIFY rcSettingsChanged)
    Q_PROPERTY(int rcTargetComponent READ rcTargetComponent NOTIFY rcSettingsChanged)
    Q_PROPERTY(int pitchChannel READ pitchChannel NOTIFY rcSettingsChanged)
    Q_PROPERTY(int yawChannel READ yawChannel NOTIFY rcSettingsChanged)
    Q_PROPERTY(int zoomChannel READ zoomChannel NOTIFY rcSettingsChanged)
    Q_PROPERTY(int sensorChannel READ sensorChannel NOTIFY rcSettingsChanged)
    Q_PROPERTY(QString sensorMode READ sensorMode NOTIFY sensorModeChanged)

    bool connected() const { return _connected; }
    int targetSystem() const { return _targetSystem; }
    int cameraComponent() const { return _cameraComponent; }
    int gimbalComponent() const { return _gimbalComponent; }
    QString ipAddress() const;
    QString rtspUrl() const;
    QString rcIpAddress() const { return _rcAddress.toString(); }
    int rcPort() const { return _dragonEyeRcPort; }
    int rcTargetSystem() const { return _rcTargetSystem; }
    int rcTargetComponent() const { return _rcTargetComponent; }
    int pitchChannel() const { return _pitchChannel; }
    int yawChannel() const { return _yawChannel; }
    int zoomChannel() const { return _zoomChannel; }
    int sensorChannel() const { return _sensorChannel; }
    QString sensorMode() const { return _sensorMode; }

    Q_INVOKABLE void configureVideoStream();
    Q_INVOKABLE void setRcIpAddress(const QString& ipAddress);
    Q_INVOKABLE void setRcTarget(int systemId, int componentId);
    Q_INVOKABLE void setRcChannels(int pitchChannel, int yawChannel, int zoomChannel, int sensorChannel);
    Q_INVOKABLE void sendRcOverride(float pitch, float yaw, float zoom, float sensor);
    Q_INVOKABLE void stopRcOverride();

    Q_INVOKABLE void setAngle(float pitchDeg, float yawDeg);
    Q_INVOKABLE void setRate(float pitchRate, float yawRate);
    Q_INVOKABLE void centerGimbal();

    Q_INVOKABLE void zoomIn();
    Q_INVOKABLE void zoomOut();
    Q_INVOKABLE void stopZoom();
    Q_INVOKABLE void setZoom(double level);

    Q_INVOKABLE void selectEo();
    Q_INVOKABLE void selectIr();

    Q_INVOKABLE void takePhoto();
    Q_INVOKABLE void startRecording();
    Q_INVOKABLE void stopRecording();

signals:
    void connectedChanged();
    void targetChanged();
    void rcSettingsChanged();
    void sensorModeChanged();
    void commandFailed(QString command, QString reason);

private slots:
    void _mavlinkMessageReceived(const mavlink_message_t& message, LinkInterface* link);
    void _connectionTimeout();

private:
    void _setConnected(bool connected);
    void _discoverComponent(const mavlink_message_t& message);
    void _sendCameraCommand(MAV_CMD command,
                            float param1 = 0.0f,
                            float param2 = 0.0f,
                            float param3 = 0.0f,
                            float param4 = 0.0f,
                            float param5 = 0.0f,
                            float param6 = 0.0f,
                            float param7 = 0.0f);
    void _sendGimbalAngleCommand(float pitchDeg, float yawDeg);
    void _sendGimbalRateCommand(float pitchRateDegS, float yawRateDegS);
    bool _ensureRcSocket();
    void _sendRcOverrideChannels(const uint16_t channels[18]);
    uint16_t _axisToPwm(float axis) const;
    void _setRcChannel(uint16_t channels[18], int channel, uint16_t value) const;
    int _bestCameraComponent() const;

    Vehicle* _vehicle = nullptr;
    bool _connected = false;
    int _targetSystem = 0;
    int _cameraComponent = MAV_COMP_ID_CAMERA;
    int _gimbalComponent = MAV_COMP_ID_GIMBAL;
    int _rcTargetSystem = 100;
    int _rcTargetComponent = 0;
    int _pitchChannel = 9;
    int _yawChannel = 10;
    int _zoomChannel = 11;
    int _sensorChannel = 12;
    bool _cameraComponentDiscovered = false;
    bool _gimbalComponentDiscovered = false;
    QString _sensorMode = QStringLiteral("EO");
    QTimer _timeoutTimer;
    QUdpSocket* _rcSocket = nullptr;
    QHostAddress _rcAddress;

    static const char* _dragonEyeIp;
    static const char* _dragonEyeRtspUrl;
    static const char* _dragonEyeRcIp;
    static const int _dragonEyeRcPort = 10038;
};
