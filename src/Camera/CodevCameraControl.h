#pragma once

#include "CustomCameraControl.h"

Q_DECLARE_LOGGING_CATEGORY(CodevCameraLog)
Q_DECLARE_LOGGING_CATEGORY(CodevCameraVerboseLog)

//-----------------------------------------------------------------------------
class CodevCameraControl : public CustomCameraControl
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
        uint16_t size;
        struct {
            uint16_t type;
            uint16_t count;
        } objects[30];
    } DetectStatsPacket;
    typedef struct {
        int32_t type;
        int32_t image_count;
        uint8_t ids[60];
        uint8_t oks[60];
    } CalibrateFeedback;
public:
    CodevCameraControl(const mavlink_camera_information_t* info, Vehicle* vehicle, int compID, QObject* parent = nullptr, LinkInterface* link = nullptr);
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
    Q_PROPERTY(QStringList detectStats READ detectStats NOTIFY detectStatsChanged)

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
    QStringList detectStats() { return _detectStats; }

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

    Q_INVOKABLE void shutterHalfPress(bool down = false);

    // Override from CustomCameraControl
    void startTracking(QPointF point, double radius) final;
    void startTracking(QRectF rec) final;
    void stopTracking() final;
    QString visualQML() const final { return QString("qrc:/custom/qml/CodevCameraVisual.qml"); }
    void handleImageCaptured(const mavlink_camera_image_captured_t& ic) final;
    void setZoomLevel(qreal level) final;
    void gimbalControlInImage(QPointF point) final;
    int photoIndex() final;

    // Override from MavlinkCameraControl
    QStringList activeSettings() final;
    void handleCaptureStatus(const mavlink_camera_capture_status_t& capStatus) final;
    void stepZoom(int direction) final;
    bool trackingImageStatus() final {
        return _trackingImageStatus.tracking_status != 2;
    }
    void handleTrackingImageStatus(const mavlink_camera_tracking_image_status_t *tis) final;
    QGCVideoStreamInfo* currentStreamInstance() final;
    QGCVideoStreamInfo* thermalStreamInstance() final;

signals:
    void nvStatusChanged();
    void thermometryDataChanged();
    void spotMeteringAreaChanged();
    void spotFocusAreaChanged();
    void dZoomInMaxChanged();
    void busyInSetupChanged();
    void detectStatsChanged();

protected slots:
    void _parametersReady();
    void _dZoomInMaxChange();
    void _handleThermometryData(QVariant data);
    void _handleNVStatus(QVariant data);
    void _handleDetectObjects(QVariant data);
    void _handleDetectStats(QVariant data);
    void _factoryCalibrateChanged(QVariant data);
    void _handlefactoryCalibrateData(QVariant data);
    void _requestJSONTransfor(QVariant data);
    void _downloadJSONFinished();
    void _paramSlefChanged();

protected:
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
    QStringList _detectStats;

    Fact* _dZoomFact{nullptr};
    Fact* _zoomModeFact{nullptr};
    Fact* _aiSourceFact{nullptr};

    bool _busy_in_detect_setup{false};
    bool _busy_in_track_setup{false};

    bool _is_factory_calibate{false};
    QGCVideoStreamInfo* _factory_stream_info{nullptr};
    int _factory_calibate_image_index{0};
};
