#pragma once

#include "QGCCameraControl.h"
#include "QGCMapEngine.h"
#include <QElapsedTimer>
#include <QTime>
#include <QTimer>

Q_DECLARE_LOGGING_CATEGORY(CodevCameraLog)
Q_DECLARE_LOGGING_CATEGORY(CodevCameraVerboseLog)

class CodevStorageInfo : public QObject
{
    Q_OBJECT
public:
    CodevStorageInfo(const mavlink_storage_information_t& st, QObject* parent = nullptr)
        : QObject(parent)
        , _type(st.type)
        , _usage(st.storage_usage)
        , _status(st.status)
        , _availableCapacity(st.available_capacity)
        , _name(st.name)
        , _storageInfo(st)
    {
    }

    int type() const { return _type; }
    int usage() const { return _usage; }
    int status() const { return _status; }
    const mavlink_storage_information_t& storageInfo() const { return _storageInfo; }

    QString availableCapacityStr(QGCCameraControl::CameraMode cameraMode) const
    {
        if (_type == STORAGE_TYPE_OTHER) {
            if (cameraMode == QGCCameraControl::CAM_MODE_PHOTO) {
                return QString("%1 No.").arg(static_cast<quint64>(_availableCapacity), 6, 10, QChar('0'));
            }
            return QTime(0, 0).addSecs(static_cast<int>(_availableCapacity)).toString("hh:mm:ss") + QStringLiteral(" Time.");
        }
        return QGCMapEngine::storageFreeSizeToString(static_cast<quint64>(_availableCapacity));
    }

    void update(const mavlink_storage_information_t& st)
    {
        _type = st.type;
        _usage = st.storage_usage;
        _status = st.status;
        _availableCapacity = st.available_capacity;
        _name = st.name;
        _storageInfo = st;
    }

private:
    int _type;
    int _usage;
    int _status;
    float _availableCapacity;
    QString _name;
    mavlink_storage_information_t _storageInfo;
};

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
    void handleSettings(const mavlink_camera_settings_t& settings) final;
    void handleCommandAck(const mavlink_command_ack_t& ack) final;
    void handleImageCaptured(const mavlink_camera_image_captured_t& ic) final;
    void handleCaptureStatus(const mavlink_camera_capture_status_t& capStatus) final;
    void handleStorageInfo(const mavlink_storage_information_t& st) final;
    QString storageFreeStr() override;
    void _localizeFactMetaData(Fact* fact);

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

protected:
    void _clearCameraDefinitionState() override;
    void _setCameraMode(CameraMode mode) override;

private:
    void _applyStorageForCurrentMode();
    void _applyStorageInfoToDisplay(const mavlink_storage_information_t& st);
    void _handleThermometryData(QVariant data);
    void _handleNVStatus(QVariant data);
    void _handleDetectObjects(QVariant data);
    void _requestJSONTransfor(QVariant data);
    void _downloadJSONFinished();
    void _paramSlefChanged();
    void _handleVehicleMavlinkMessage(const mavlink_message_t& message, LinkInterface* link);
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
    bool _sendGimbalManagerPitchYaw(float pitch, float yaw, uint32_t flags, const char* sourceTag);
    bool _sendGimbalManagerPitchYawRate(float pitchRate, float yawRate, uint32_t flags, const char* sourceTag);
    void _sendR3RcChannels(const mavlink_rc_channels_t& rc, const char* sourceTag);
    void _sendLegacyMountControl(float pitch, float yaw, const char* sourceTag);

    bool _isTakingPhotoTimelapse();
    void _sendNextQueuedMavCommand();
    bool _consumeQueuedCommandAck(int ackCompId, const mavlink_command_ack_t& ack, const char* sourceTag);
    void _logControlState(const char* sourceTag) const;
    QString _factValueForLog(const char* factName) const;

    enum class PendingRcAction {
        None,
        TakePhoto,
        ToggleVideo,
    };

    void _beginModeSwitch(CameraMode targetMode);
    void _sendModeSwitchToCamera(CameraMode targetMode);
    void _forceModeSwitchToCamera(CameraMode targetMode);
    void _scheduleCoalescedModeSwitch(CameraMode targetMode);
    void _flushCoalescedModeSwitch();
    void _armModeSwitchRecovery(CameraMode targetMode);
    void _disarmModeSwitchRecovery();
    void _retryModeSwitchRecovery(const char* reason);
    void _executeModeSwitchNudge(const char* reason);
    void _onModeSwitchNudgeReturn();
    void _scheduleVideoPipelineRestart(const char* reason);
    void _restartVideoPipeline();
    void _checkModeSwitchRecovery();
    void _onProactiveModeRetry();
    void _onVideoDecodingChanged();
    void _requestAllStoragePools();
    void _refreshStorageAndCaptureStatus();
    void _scheduleStorageRefreshAfterModeSwitch();
    void _stopStorageRefreshAfterModeSwitch();
    bool _isModeSwitchSettling() const;
    bool _shouldRejectStaleModeReport(CameraMode reported) const;
    bool _hasModeStoragePool(CameraMode mode);
    bool _isCurrentModeStorageReady();
    void _syncPhotoPoolFromCaptureStatus(float availableCapacity);
    bool _hasKnownInsufficientPhotoStorage() const;
    bool _hasKnownInsufficientVideoStorage() const;
    void _startPendingRcAction(PendingRcAction action);
    void _cancelPendingRcAction();
    void _completePendingRcAction();
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
    qint64 _trackingInvalidStartMs{-1};
    QElapsedTimer _rcGimbalCommandTimer;
    QElapsedTimer _rcCameraSettingsRequestTimer;
    quint16 _lastRcGimbalPitchRaw{1500};
    quint16 _lastRcGimbalYawRaw{1500};
    quint16 _lastRcGimbalZoomRaw{1500};
    quint16 _lastRcGimbalCenterRaw{1500};
    bool _lastRcGimbalWasCentered{true};

    bool _modeSwitchPending{false};
    CameraMode _pendingCameraMode{CAM_MODE_PHOTO};
    QTimer _modeSwitchTimer;
    QTimer _modeSwitchCommandTimer;
    QElapsedTimer _modeSwitchDebounce;
    QElapsedTimer _modeSwitchGraceTimer;
    CameraMode _coalescedModeTarget{CAM_MODE_UNDEFINED};
    CameraMode _userIntentMode{CAM_MODE_UNDEFINED};
    QElapsedTimer _userIntentTimer;

    PendingRcAction _pendingRcAction{PendingRcAction::None};
    QTimer _rcActionFallbackTimer;
    QTimer _storageRefreshTimer;
    QTimer _modeSwitchRecoveryTimer;
    QTimer _modeSwitchProactiveRetryTimer;
    QTimer _modeSwitchNudgeReturnTimer;
    QTimer _videoPipelineRestartTimer;
    int _storageRefreshAttempts{0};
    QmlObjectListModel _storageInfos;
    CameraMode _modeSwitchRecoveryTarget{CAM_MODE_UNDEFINED};
    bool _modeSwitchRecoveryActive{false};
    bool _modeSwitchRecoveryRetried{false};
    bool _decodingAtRecoveryArm{false};
    bool _modeSwitchNudgeInProgress{false};
    bool _decodingDroppedDuringRecovery{false};
    CameraMode _lastReportedCameraMode{CAM_MODE_UNDEFINED};

private:
    float _opticalRange = 1.0f;          // 0..100, 우리가 제어하는 광학 줌 위치
    float _opticalStep  = 1.0f;          // 한 번 누를 때 RANGE 증가량(튜닝)
    float _digitalStep  = 0.2f;
    float _maxOpticalX  = 30.0f;         // 광학 최대 배율(당신 케이스)
    

};
