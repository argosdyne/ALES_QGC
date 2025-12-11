#pragma once

#include "QGCCameraControl.h"

Q_DECLARE_LOGGING_CATEGORY(CodevCameraLog)
Q_DECLARE_LOGGING_CATEGORY(CodevCameraVerboseLog)

//-----------------------------------------------------------------------------
class CodevCameraControl : public QGCCameraControl
{
    Q_OBJECT
    typedef struct {
        float temperature;
        float cpu_usage_percent;
        float raw_usage_percent;
    } NVStatusPacket;
    typedef struct {
        int type;
        float min_temp;
        float max_temp;
        float ave_temp;
        float min_x;
        float min_y;
        float max_x;
        float max_y;
        float x1;
        float y1;
        float x2;
        float y2;
    }ThermometryPacket;
    typedef struct {
        uint16_t x;
        uint16_t y;
        uint16_t width;
        uint16_t height;
        uint16_t score;
        uint16_t type;
    } DetectObject;
    typedef struct {
        uint16_t index;
        uint16_t size;
        uint16_t total;
        DetectObject objects[10];
    } DetectObjectsPacket;
    typedef struct {
        int32_t type;
        int32_t image_count;
        uint8_t ids[60];
        uint8_t oks[60];
    } CalibrateFeedback;
public:
    CodevCameraControl(const mavlink_camera_information_t* info, Vehicle* vehicle, int compID, LinkInterface* link, QObject* parent = nullptr);
    Q_PROPERTY(bool busyInDetectSetup READ busyInDetectSetup NOTIFY busyInSetupChanged)
    Q_PROPERTY(bool busyInTrackSetup READ busyInTrackSetup NOTIFY busyInSetupChanged)
    Q_PROPERTY(float trackScore READ trackScore NOTIFY trackingImageStatusChanged)
    Q_PROPERTY(float boardTemp READ boardTemp NOTIFY nvStatusChanged)
    Q_PROPERTY(float cpuUsage READ cpuUsage NOTIFY nvStatusChanged)
    Q_PROPERTY(float memUsage READ memUsage NOTIFY nvStatusChanged)
    Q_PROPERTY(int tempType READ tempType NOTIFY thermometryDataChanged)
    Q_PROPERTY(float minTempX READ minTempX NOTIFY thermometryDataChanged)
    Q_PROPERTY(float minTempY READ minTempY NOTIFY thermometryDataChanged)
    Q_PROPERTY(float minTemp READ minTemp NOTIFY thermometryDataChanged)
    Q_PROPERTY(float maxTempX READ maxTempX NOTIFY thermometryDataChanged)
    Q_PROPERTY(float maxTempY READ maxTempY NOTIFY thermometryDataChanged)
    Q_PROPERTY(float maxTemp READ maxTemp NOTIFY thermometryDataChanged)
    Q_PROPERTY(float rectTempX1 READ rectTempX1 NOTIFY thermometryDataChanged)
    Q_PROPERTY(float rectTempY1 READ rectTempY1 NOTIFY thermometryDataChanged)
    Q_PROPERTY(float rectTempX2 READ rectTempX2 NOTIFY thermometryDataChanged)
    Q_PROPERTY(float rectTempY2 READ rectTempY2 NOTIFY thermometryDataChanged)
    Q_PROPERTY(QmlObjectListModel* targetObjects READ targetObjects CONSTANT)

    bool busyInDetectSetup() { return _busy_in_detect_setup; }
    bool busyInTrackSetup() { return _busy_in_track_setup; }
    float trackScore() { return _trackingImageStatus.radius * 100; }
    float boardTemp() { return _nvStatusPacket.temperature; }
    float cpuUsage() { return _nvStatusPacket.cpu_usage_percent; }
    float memUsage() { return _nvStatusPacket.raw_usage_percent; }
    int tempType() { return _tempPacket.type; }
    float minTempX() { return _tempPacket.min_x; }
    float minTempY() { return _tempPacket.min_y; }
    float minTemp() { return _tempPacket.min_temp; }
    float maxTempX() { return _tempPacket.max_x; }
    float maxTempY() { return _tempPacket.max_y; }
    float maxTemp() { return _tempPacket.max_temp; }
    float rectTempX1() { return _tempPacket.x1; }
    float rectTempY1() { return _tempPacket.y1; }
    float rectTempX2() { return _tempPacket.x2; }
    float rectTempY2() { return _tempPacket.y2; }
    QmlObjectListModel* targetObjects() { return &_targetObjects; }
    bool hasTrackingPoint() { return _info.flags & CAMERA_CAP_FLAGS_HAS_TRACKING_POINT; }
    bool hasTrackingRectangle() { return _info.flags & CAMERA_CAP_FLAGS_HAS_TRACKING_RECTANGLE; }
    bool hasTrackingGeoStatus() { return _info.flags & CAMERA_CAP_FLAGS_HAS_TRACKING_GEO_STATUS; }
    Q_INVOKABLE void centerGimbal();

    Q_INVOKABLE void setSpotTempPoint(float x, float y);
    Q_INVOKABLE void setAreaTempRect(float x1, float y1, float x2, float y2);

    Q_PROPERTY(QPointF spotMeteringArea READ spotMeteringArea NOTIFY spotMeteringAreaChanged)
    Q_PROPERTY(QPointF spotFocusArea READ spotFocusArea NOTIFY spotFocusAreaChanged)

    QPointF spotMeteringArea();
    QPointF spotFocusArea();

    Q_PROPERTY(bool dZoomInMax READ dZoomInMax NOTIFY dZoomInMaxChanged)
    bool dZoomInMax() { return _dZoomInMax; }

    Q_INVOKABLE void setSpotMetering(float x, float y);
    Q_INVOKABLE void setSpotFocus(float x, float y);
    Q_INVOKABLE void initTracker();
    Q_INVOKABLE void deinitTracker();
    Q_INVOKABLE void gimbalControlInImage(QPointF point);
    Q_INVOKABLE void buttonTakePhoto();
    Q_INVOKABLE void buttonToggleVideo();

    // Override from QGCCameraControl
    void setVideoMode() final;
    void setPhotoMode() final;
    bool takePhoto() final;
    bool stopTakePhoto() final;
    bool startVideo() final;
    bool stopVideo() final;
    void resetSettings() final;
    void formatCard(int id = 1) final;
    void startZoom(int direction) final;
    void stopZoom() final;
    void startTracking(QPointF point, double radius) final;
    void startTracking(QRectF rec) final;
    void stopTracking() final;
    QString extraControlsQml() const final { return QString("qrc:/qml/CodevCameraVisual.qml"); }
    void setZoomLevel(qreal level) final;
    QStringList activeSettings() final;
    void stepZoom(int direction) final;
    bool trackingImageStatus() final {
        return _trackingImageStatus.tracking_status != 2;
    }
    void handleTrackingImageStatus(const mavlink_camera_tracking_image_status_t *tis) final;
    void handleRCChannels(const mavlink_rc_channels_t& rc) final;
    void handleCommandAck(const mavlink_command_ack_t& ack) final;
    void handleImageCaptured(const mavlink_camera_image_captured_t& ic) final;
    void handleCaptureStatus(const mavlink_camera_capture_status_t& capStatus) final;

    // sendMavCommander
    typedef struct {
        int         component;
        MAV_CMD     command;
        MAV_FRAME   frame;
        double      rgParam[7];
    } MavCommandQueueEntry_t;
    QList<MavCommandQueueEntry_t>   _mavCommandQueue;
    QTimer                          _mavCommandAckTimer;
    int                             _mavCommandRetryCount;
    static const int                _mavCommandMaxRetryCount = 3;
    static const int                _mavCommandAckTimeoutMSecs = 1000;
    void sendMavCommand(MAV_CMD command, float param1 = 0.0f, float param2 = 0.0f, float param3 = 0.0f, float param4 = 0.0f, float param5 = 0.0f, float param6 = 0.0f, float param7 = 0.0f);
    void sendMavCommandWithTarget(MAV_CMD command, int target_component, float param1 = 0.0f, float param2 = 0.0f, float param3 = 0.0f, float param4 = 0.0f, float param5 = 0.0f, float param6 = 0.0f, float param7 = 0.0f);

signals:
    void nvStatusChanged();
    void thermometryDataChanged();
    void spotMeteringAreaChanged();
    void spotFocusAreaChanged();
    void dZoomInMaxChanged();
    void busyInSetupChanged();

protected slots:
    void _parametersReady();
    void _dZoomInMaxChange();
    void _handleThermometryData(QVariant data);
    void _handleNVStatus(QVariant data);
    void _handleDetectObjects(QVariant data);
    void _requestJSONTransfor(QVariant data);
    void _downloadJSONFinished();
    void _paramSlefChanged();
    // sendMavCommander
    void _sendMavCommandAgain();
    void _mavCommandResult(int vehicleId, int component, int command, int result, bool noReponseFromVehicle) override;

    void _requestCameraSettings() final;
    void _requestCaptureStatus() final;
    void _requestStorageInfo() final;

protected:
    void _requestStreamInfo(uint8_t streamID) final;
    void _requestStreamStatus(uint8_t streamID) final;
    void _requestThermometryData();

    bool _isTakingPhotoTimelapse();
    void _sendNextQueuedMavCommand();
    MAVLinkProtocol* _pMavlink;

    bool _hasTrack{false};
    bool _hasDetect{false};
    bool _dZoomInMax{false};
    NVStatusPacket _nvStatusPacket;
    QTimer _resetNVStatusPacket;
    ThermometryPacket _tempPacket;
    QTimer _resetTempPacket;
    QTimer _resetDetectObjectsPacket;
    QmlObjectListModel _targetObjects;
    QStringList _targetObjectLabels;

    Fact* _dZoomFact{nullptr};
    Fact* _zoomModeFact{nullptr};
    Fact* _aiSourceFact{nullptr};

    bool _busy_in_detect_setup{false};
    bool _busy_in_track_setup{false};
};
