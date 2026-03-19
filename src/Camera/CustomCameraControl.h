#pragma once

#include "VehicleCameraControl.h"
#include "MAVLinkProtocol.h"
#include "QGCLoggingCategory.h"
#include "Vehicle.h"
#include "QmlObjectListModel.h"
#include "QGCMapEngine.h"

#include <QSize>
#include <QPoint>
#include <QSoundEffect>
#include <QGeoCoordinate>
#include <QQmlEngine>

Q_DECLARE_LOGGING_CATEGORY(CustomCameraLog)
Q_DECLARE_LOGGING_CATEGORY(CustomCameraVerboseLog)

class CustomStorageInfo : public QObject
{
    Q_OBJECT
public:
    CustomStorageInfo(const mavlink_storage_information_t& st, QObject* parent = nullptr)
        : QObject(parent)
        , _type(st.type)
        , _usage(st.storage_usage)
        , _status(st.status)
        , _available_capacity(st.available_capacity)
        , _name(st.name)
        , _storage_info(st)
    {
    }

    Q_PROPERTY(int type READ type NOTIFY infoChanged)
    Q_PROPERTY(int usage READ usage NOTIFY infoChanged)
    Q_PROPERTY(int status READ status NOTIFY infoChanged)
    Q_PROPERTY(QString name READ name NOTIFY infoChanged)

    int type() const { return _type; }
    int usage() const { return _usage; }
    int status() const { return _status; }
    QString name() const { return _name; }

    Q_INVOKABLE QString available_capacity(MavlinkCameraControl::CameraMode camera_mode) {
        if(_type == STORAGE_TYPE_OTHER) {
            if(camera_mode == MavlinkCameraControl::CAM_MODE_PHOTO) {
                return QString("%1 No.").arg(static_cast<quint64>(_available_capacity), 6, 10, QChar('0'));
            } else {
                return QTime(0, 0).addSecs(static_cast<int>(_available_capacity)).toString("hh:mm:ss") + " Time.";
            }
        } else {
            return QGCMapEngine::storageFreeSizeToString(static_cast<quint64>(_available_capacity));
        }
    }

    void update(const mavlink_storage_information_t& st)
    {
        _type = st.type;
        _usage = st.storage_usage;
        _status = st.status;
        _available_capacity = st.available_capacity;
        _name = st.name;
        _storage_info = st;
    }

    mavlink_storage_information_t get_storage_info() { return _storage_info; }

signals:
    void infoChanged();

private:
    int _type;
    int _usage;
    int _status;
    float _available_capacity;
    QString _name;
    mavlink_storage_information_t _storage_info;
};

//-----------------------------------------------------------------------------
class CustomCameraControl : public VehicleCameraControl
{
    Q_OBJECT
public:
    Q_PROPERTY(QString visualQML READ visualQML CONSTANT)
    Q_PROPERTY(bool hasTrackingPoint     READ hasTrackingPoint     NOTIFY infoChanged)
    Q_PROPERTY(bool hasTrackingRectangle READ hasTrackingRectangle NOTIFY infoChanged)
    Q_PROPERTY(bool hasTrackingGeoStatus READ hasTrackingGeoStatus NOTIFY infoChanged)
    Q_PROPERTY(int photoIndex READ photoIndex NOTIFY photoIndexChanged)

    Q_PROPERTY(qreal gimbalRoll          READ gimbalRoll           NOTIFY gimbalAttitudeChanged)
    Q_PROPERTY(qreal gimbalPitch         READ gimbalPitch          NOTIFY gimbalAttitudeChanged)
    Q_PROPERTY(qreal gimbalYaw           READ gimbalYaw            NOTIFY gimbalAttitudeChanged)
    Q_PROPERTY(qreal gimbalYawAbsolute   READ gimbalYawAbsolute    NOTIFY gimbalAttitudeChanged)
    qreal gimbalRoll       () const{ return static_cast<qreal>(_curGimbalRoll);}
    qreal gimbalPitch      () const{ return static_cast<qreal>(_curGimbalPitch); }
    qreal gimbalYaw        () const{ return static_cast<qreal>(_curGimbalYaw); }
    qreal gimbalYawAbsolute() const{ return static_cast<qreal>(_curGimbalYawAbsolute); }

    Q_PROPERTY(bool supportFormat READ supportFormat CONSTANT)
    Q_PROPERTY(bool supportReset  READ supportReset CONSTANT)
    Q_PROPERTY(bool supportLapse  READ supportLapse CONSTANT)
    virtual bool supportFormat() const { return true; }
    virtual bool supportReset() const { return true; }
    virtual bool supportLapse() const { return true; }

    Q_PROPERTY(QGeoCoordinate targetCoordinate READ targetCoordinate NOTIFY targetCoordinateChanged)
    Q_PROPERTY(float targetDistance READ targetDistance NOTIFY targetDistanceChanged)
    QGeoCoordinate targetCoordinate() { return _targetCoordinate; }
    float targetDistance() { return _targetDistance; }

    Q_PROPERTY(QmlObjectListModel* storageInfos READ storageInfos CONSTANT)
    QmlObjectListModel* storageInfos() { return &_storageInfos; }

    CustomCameraControl(const mavlink_camera_information_t* info, Vehicle* vehicle, int compID, QObject* parent = nullptr, LinkInterface* link = nullptr);

    LinkInterface* link() { return _link; }
    QString cacheDefile() { return _cacheFile; }
    void get_mavlink_camera_info(mavlink_camera_information_t& info);

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

    void handleGimbalOrientation(const mavlink_mount_orientation_t& o);
    void handleTrackingGeoStatus(const mavlink_camera_tracking_geo_status_t& tracking_geo_status);
    void handleBrigePing(const mavlink_ping_t& ping);
    void handleRCChannels(const mavlink_rc_channels_t& rc);
    void handleCommandAck(const mavlink_command_ack_t& ack);
    virtual void handleImageCaptured (const mavlink_camera_image_captured_t&) {}
    bool hasTrackingPoint() { return _info.flags & CAMERA_CAP_FLAGS_HAS_TRACKING_POINT; }
    bool hasTrackingRectangle() { return _info.flags & CAMERA_CAP_FLAGS_HAS_TRACKING_RECTANGLE; }
    bool hasTrackingGeoStatus() { return _info.flags & CAMERA_CAP_FLAGS_HAS_TRACKING_GEO_STATUS; }
    virtual int photoIndex() { return _photoIndex; }
    Q_INVOKABLE void centerGimbal();
    Q_INVOKABLE virtual void gimbalControlInImage(QPointF) {}

    virtual QString visualQML() const { return QString("qrc:/custom/qml/CustomCameraVisual.qml"); }

    // Override from VehicleCameraControl
    bool takePhoto() override;
    bool stopTakePhoto() override;
    bool startVideoRecording() override;
    bool stopVideoRecording() override;
    void resetSettings() override;
    void formatCard(int id = 1) override;
    void setCameraModeVideo() override;
    void setCameraModePhoto() override;
    void startZoom(int direction) override;
    void stopZoom() override;
    void setZoomLevel(qreal level) override;
    void startTracking(QPointF point, double radius) override;
    void startTracking(QRectF rec) override;
    void stopTracking() override;
    void _requestStreamInfo(uint8_t streamID) override;
    void _requestStreamStatus(uint8_t streamID) override;
    void _requestCameraSettings() override;
    void _requestCaptureStatus() override;
    void _requestStorageInfo() override;

    QString storageFreeStr() override;
    void handleVideoInfo(const mavlink_video_stream_information_t *vi) override;
    void handleStorageInfo(const mavlink_storage_information_t& st) override;

signals:
    void playCameraSound(int loop);
    void playVideoSound(int loop);
    void playErrorSound(int loop);
    void photoIndexChanged();
    void targetCoordinateChanged(QGeoCoordinate coordinate);
    void targetDistanceChanged(float distance);
    void gimbalAttitudeChanged();

protected slots:
    void        _sendMavCommandAgain();
    void        _mavCommandResult   (int vehicleId, int component, int command, int result, bool noReponseFromVehicle) override;
    void        _vehicleParametersReady(bool ready);
    void        _buttonTakePhoto();
    void        _buttonToggleVideo();

protected:
    void    _setCameraMode(CameraMode mode) final;
    void    _sendNextQueuedMavCommand();
    bool    _isTakingPhotoTimelapse();
    bool    _needSendCaptureAndRecordBystyle();

    QSoundEffect _cameraSound;
    QSoundEffect _videoSound;
    QSoundEffect _errorSound;

    MAVLinkProtocol* _pMavlink;

    QmlObjectListModel _storageInfos;
    int _photoIndex = 0;
    int _channel_id = 0;

    QGeoCoordinate _targetCoordinate;
    float _targetDistance;

    float _curGimbalRoll = 0.0f;
    float _curGimbalPitch = 0.0f;
    float _curGimbalYaw = 0.0f;
    float _curGimbalYawAbsolute = 0.0f;
};
