// rhythm.h
#pragma once

#include <QObject>
#include <QUdpSocket>
#include <QHostAddress>
#include <QTimer>
#include <QGCApplication.h>

// Include MAVLink headers
// Make sure these paths match your project structure
#include "common/mavlink.h"

struct DetectedObject {
    int16_t x;
    int16_t y;
    int16_t width;
    int16_t height;
    int16_t score;
    int16_t type;
};

struct DetectContent {
    uint16_t index;
    uint16_t size;
    uint16_t total;
    QVector<DetectedObject> objects;
};

// Define Zoom Types
#define ZOOM_TYPE_STEP        0   // Small in/out step
#define ZOOM_TYPE_CONTINUOUS  1   // Continuous zoom
#define ZOOM_TYPE_RANGE       2   // Set zoom to specific multiple (e.g., 5x)

class Rhythm : public QObject
{
    Q_OBJECT
    // Add this property to expose detection results to QML

public:
    explicit Rhythm(QObject *parent = nullptr);
    ~Rhythm();

    // Setup function to be called from QML
    Q_INVOKABLE bool setup(const QString& cameraIp, int port);
    Q_INVOKABLE bool checkConnection();
    Q_INVOKABLE void closeConnection();
    Q_INVOKABLE bool takePicture();
    Q_INVOKABLE bool controlGimbal(float pitch, float yaw, float roll);

    // Video recording control
    Q_INVOKABLE bool setCameraMode(int mode);
    Q_INVOKABLE bool startVideo();
    Q_INVOKABLE bool stopVideo();
    Q_INVOKABLE void requestParameter(const QString &paramId);
    Q_INVOKABLE void requestAllParameters();
    Q_INVOKABLE void setParameter(const QString &paramId, const QString &paramValue, int paramType);
    Q_INVOKABLE void startTracking(const QString& track_algo);

    // New functions to start detection and get detection status
    Q_INVOKABLE void startDetection(const QString &detection_algo);
    Q_INVOKABLE void getDetectionStatus();
    Q_INVOKABLE void startDetectionAndTracking(const QString& detection_algo, const QString& track_algo);

    // Add a method to check recording state (without property or notification)
    Q_INVOKABLE bool isRecording() const  { return m_isRecording; }

    // Camera connection status
    Q_PROPERTY(bool connected READ connected NOTIFY connectionStatusChanged)
    bool connected() const { return m_connected; }

    Q_INVOKABLE bool isConnected() const { return m_connected; }

    Q_INVOKABLE bool trackPoint(float x, float y, float radius);
    Q_INVOKABLE bool stopTracking();
    bool isTracking() const { return m_isTracking; }
    Q_PROPERTY(bool isTracking READ isTracking NOTIFY trackingStateChanged)
    Q_PROPERTY(QVariantMap trackingData READ trackingData NOTIFY trackingDataChanged)

    QVariantMap trackingData() const { return m_trackingData; }
    Q_INVOKABLE bool zoomRangeLevel(float zoomLevel);
    Q_INVOKABLE void setVideoResolution(int resolution);
    Q_INVOKABLE void setVideoBitrate(float bitrate);

signals:
    void connectionStatusChanged();
    void cameraError(const QString& errorMsg);
    void heartbeatReceived();
    void imageCaptured(int imageIndex, const QString& imageFileName);
    // void parameterReceived(QString paramId, QString paramValue); // Signal for QML
    void parameterReceived(const QString &paramId, const QString &paramValue);
    void parameterSetAckReceived(QString paramId, QString paramValue, bool success); // Signal for QML
    void detectionResultsReceived(const QString& jsonResults);
    void trackingStateChanged();
    void trackingDataChanged();
    void trackingResultsReceived(const QString& jsonResults);

private slots:
    void processPendingDatagrams();
    void sendHeartbeat();
    void checkConnectionTimeout();
    void handleMavlinkMessage(const mavlink_message_t &msg); // Slot for processing responses

private:
    // MAVLink message handling
    void handleHeartbeat(const mavlink_message_t& message);
    void handleImageCaptured(const mavlink_message_t& message);

    // Helper to send MAVLink message
    void sendMavlinkMessage(const mavlink_message_t& message);
    void processMavlinkResponse(const mavlink_message_t &msg);
    DetectContent parseDetectionData(const uint8_t* data, size_t length);

    QUdpSocket* m_udpSocket;
    QHostAddress m_cameraAddress;
    int m_cameraPort;
    bool m_connected;
    QTimer m_heartbeatTimer;
    QTimer m_connectionTimer;
    qint64 m_lastHeartbeatTime;

    // MAVLink system and component IDs
    uint8_t m_systemId;         // Local system ID
    uint8_t m_componentId;      // Local component ID
    uint8_t m_targetSystemId;   // Camera system ID
    uint8_t m_targetComponentId; // Camera component ID
    uint8_t m_targetGComponentId; // Gimbal component ID

    // Camera information
    bool m_hasCameraInfo;
    bool m_isRecording = false;  // Track recording state
    bool m_isTracking = false;
    QVariantMap m_trackingData;
    float currentZoomLevel = 1.0f;  // Start at 1x zoom

};
