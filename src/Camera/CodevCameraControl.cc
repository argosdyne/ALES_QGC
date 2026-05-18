#include "CodevCameraControl.h"
#include "QGCCameraIO.h"
#include "QGCCameraManager.h"
#include <QTimeZone>
#include <QNetworkProxy>
#include <QNetworkReply>
#include <QNetworkAccessManager>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDateTime>
#include <algorithm>
#include <cmath>
#include <algorithm>
#include <cmath>
#include "TargetObject.h"
#include "QGCApplication.h"
#include "QGCCorePlugin.h"
#include "VideoManager.h"
#include "SettingsManager.h"
#include "GimbalController.h"
#include <QCoreApplication>

static const char *kIR_TEMP_POINT = "IR_TEMP_POINT";
static const char *kIR_TEMP_RECT = "IR_TEMP_RECT";
static const char *kIR_TEMP_DATA = "IR_TEMP_DATA";
static const char *kNV_STATUS = "NV_STATUS";
static const char *kEO_SPOTAE = "EO_SPOTAE";
static const char *kEO_SPOTFOCUS = "EO_SPOTFOCUS";
static const char *kEO_DZOOM = "EO_DZOOM";
static const char *kAI_SOURCE = "AI_SOURCE";
static const char *kEO_ZOOM_MODE = "EO_ZOOM_MODE";
static const char *kTIME_ZONE = "TIME_ZONE";
static const char *kTRACK_ALGORITHM = "TRACK_ALGORITHM";
static const char *kDETECT_OBJECTS = "DETECT_OBJECTS";
static const char *kTRACK_PLUGINS = "TRACK_PLUGINS";
static const char *kDETECT_PLUGINS = "DETECT_PLUGINS";
static const char *kSMART_SELECT = "SMART_SELECT";
static const char *kAI_RESOLUTION = "AI_RESOLUTION";
static const char *kFACTORY_CALI = "FACTORY_CALI";
// static const char *kFACTORY_DATA = "FACTORY_DATA";
static const char *kJSON_TR_REQ = "JSON_TR_REQ";
static const char *kCALIBRATE_FLAGS = "CALIBRATE_FLAGS";

static constexpr qint64 kTrackingInvalidStopDelayMs = 10000;
static constexpr float kTrackingSmallBoxArea = 0.002f;
static constexpr float kTrackingCenterMargin = 0.35f;
static constexpr float kTrackingCenterMax = 0.65f;
static constexpr uint16_t kRcGimbalCenter = 1500;
static constexpr uint16_t kRcGimbalDeadzone = 50;
static constexpr uint16_t kRcGimbalMinValid = 900;
static constexpr uint16_t kRcGimbalMaxValid = 2100;
static constexpr uint16_t kRcGimbalChangeThreshold = 20;
static constexpr qint64 kRcCameraSettingsRequestMinIntervalMs = 1000;
static constexpr qint64 kRcGimbalCommandMinIntervalMs = 50;
static constexpr float kRcGimbalMaxPitchRateDegS = 3.0f;
static constexpr float kRcGimbalMaxYawRateDegS = 30.0f;

QGC_LOGGING_CATEGORY(CodevCameraLog, "CodevCameraLog")
QGC_LOGGING_CATEGORY(CodevCameraVerboseLog, "CodevCameraVerboseLog")

static QStringList detected_labels_database = {
    "person", "car", "bus", "truck", "bike", "train", "boat", "aeroplane",
    "bicycle", "motorcycle", "airplane", "traffic light", "fire hydrant", "stop sign", "parking meter", "bench",
    "bird", "cat", "dog", "horse", "sheep", "cow", "elephant", "bear",
    "zebra", "giraffe", "backpack", "umbrella", "handbag", "tie", "suitcase", "frisbee",
    "skis", "snowboard", "sports ball", "kite", "baseball bat", "baseball glove", "skateboard", "surfboard",
    "tennis racket", "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl",
    "banana", "apple", "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza",
    "donut", "cake", "chair", "couch", "potted plant", "bed", "dining table", "toilet",
    "tv", "laptop", "mouse", "remote", "keyboard", "cell phone", "microwave", "oven",
    "toaster", "sink", "refrigerator", "book", "clock", "vase", "scissors", "teddy bear",
    "hair drier", "toothbrush"
};

static QString _translateCameraSettingText(const QString& sourceText)
{
    const QByteArray sourceUtf8 = sourceText.toUtf8();
    return QCoreApplication::translate("CodevCameraControl", sourceUtf8.constData());
}

static QStringList _translateCameraSettingList(const QStringList& sourceList)
{
    QStringList translated;
    translated.reserve(sourceList.size());
    for (const QString& s : sourceList) {
        translated << _translateCameraSettingText(s);
    }
    return translated;
}

static bool _isValidRcGimbalPwm(uint16_t raw)
{
    return raw >= kRcGimbalMinValid && raw <= kRcGimbalMaxValid && raw != 0xFFFF;
}

static bool _isR3CameraModel(const QString& modelName)
{
    return modelName.contains(QStringLiteral("R3"), Qt::CaseInsensitive)
            || modelName.contains(QStringLiteral("RHYTHM"), Qt::CaseInsensitive);
}

static float _rcPwmToGimbalRate(uint16_t raw, float maxRateDegS)
{
    if (!_isValidRcGimbalPwm(raw)) {
        return 0.0f;
    }

    const int delta = static_cast<int>(raw) - static_cast<int>(kRcGimbalCenter);
    if (qAbs(delta) <= kRcGimbalDeadzone) {
        return 0.0f;
    }

    const float signedRange = delta > 0
            ? static_cast<float>(kRcGimbalMaxValid - kRcGimbalCenter)
            : static_cast<float>(kRcGimbalCenter - kRcGimbalMinValid);
    return qBound(-maxRateDegS,
                  (static_cast<float>(delta) / signedRange) * maxRateDegS,
                  maxRateDegS);
}

CodevCameraControl::CodevCameraControl(const mavlink_camera_information_t *info, Vehicle* vehicle, int compID, LinkInterface* link, QObject* parent)
    : QGCCameraControl(info, vehicle, compID, link, parent)
    , _pMavlink(qgcApp()->toolbox()->mavlinkProtocol())
{
    _mavCommandAckTimer.setSingleShot(true);
    _mavCommandAckTimer.setInterval(_mavCommandAckTimeoutMSecs);
    connect(&_mavCommandAckTimer, &QTimer::timeout, this, &CodevCameraControl::_sendMavCommandAgain);

    connect(this, &CodevCameraControl::parametersReady, this, &CodevCameraControl::_parametersReady);
    memset(&_tempPacket, 0, sizeof(_tempPacket));
    memset(&_nvStatusPacket, 0, sizeof(_nvStatusPacket));
    _resetTempPacket.setSingleShot(true);
    _resetTempPacket.setInterval(1000);
    connect(&_resetTempPacket, &QTimer::timeout, [this]() {
        memset(&_tempPacket, 0, sizeof(_tempPacket));
    });
    _resetNVStatusPacket.setSingleShot(true);
    _resetNVStatusPacket.setInterval(5000);
    connect(&_resetNVStatusPacket, &QTimer::timeout, [this]() {
        memset(&_nvStatusPacket, 0, sizeof(_nvStatusPacket));
    });
    _trackingImageStatus.tracking_status = 2;
    _resetDetectObjectsPacket.setSingleShot(true);
    _resetDetectObjectsPacket.setInterval(1000);
    connect(&_resetDetectObjectsPacket, &QTimer::timeout, [this]() {
        _targetObjects.clearAndDeleteContents();
    });
    connect(_vehicle, &Vehicle::mavlinkMessageReceived, this, &CodevCameraControl::_handleVehicleMavlinkMessage);

}

bool CodevCameraControl::_sendGimbalManagerPitchYaw(float pitch, float yaw, uint32_t flags, const char* sourceTag)
{
    if (!_vehicle->px4Firmware()) {
        return false;
    }

    GimbalController* gimbalController = _vehicle->gimbalController();
    Gimbal* activeGimbal = gimbalController ? gimbalController->activeGimbal() : nullptr;
    if (!activeGimbal) {
        qCInfo(CodevCameraLog) << "[CameraFlow]"
                << sourceTag
                << "px4 gimbal manager unavailable"
                << "cameraCompId" << _compID;
        return false;
    }

    const uint managerCompId = activeGimbal->managerCompid()->rawValue().toUInt();
    const uint deviceId = activeGimbal->deviceId()->rawValue().toUInt();
    if (managerCompId == 0 || deviceId == 0) {
        qCInfo(CodevCameraLog) << "[CameraFlow]"
                << sourceTag
                << "px4 gimbal manager incomplete"
                << "cameraCompId" << _compID
                << "managerCompId" << managerCompId
                << "deviceId" << deviceId;
        return false;
    }

    qCInfo(CodevCameraLog) << "[CameraFlow]"
            << sourceTag
            << "using gimbal manager"
            << "cameraCompId" << _compID
            << "targetCompId" << managerCompId
            << "deviceId" << deviceId
            << "command" << MAV_CMD_DO_GIMBAL_MANAGER_PITCHYAW
            << "pitch" << pitch
            << "yaw" << yaw
            << "flags" << flags;
    sendMavCommandWithTarget(
        MAV_CMD_DO_GIMBAL_MANAGER_PITCHYAW,
        static_cast<int>(managerCompId),
        pitch,
        yaw,
        NAN,
        NAN,
        static_cast<float>(flags),
        0.0f,
        static_cast<float>(deviceId));
    return true;
}

bool CodevCameraControl::_sendGimbalManagerPitchYawRate(float pitchRate, float yawRate, uint32_t flags, const char* sourceTag)
{
    if (!_vehicle->px4Firmware()) {
        return false;
    }

    GimbalController* gimbalController = _vehicle->gimbalController();
    Gimbal* activeGimbal = gimbalController ? gimbalController->activeGimbal() : nullptr;
    uint managerCompId = 0;
    uint deviceId = 0;
    float pitchParam = NAN;
    float yawParam = NAN;
    float pitchRateParam = pitchRate;
    float yawRateParam = yawRate;

    if (activeGimbal) {
        managerCompId = activeGimbal->managerCompid()->rawValue().toUInt();
        deviceId = activeGimbal->deviceId()->rawValue().toUInt();

        // Some gimbals ignore rate params. Use small angle increments, same model as QGC click-drag.
        pitchParam = activeGimbal->absolutePitch()->rawValue().toFloat() + (pitchRate * 0.1f);
        yawParam = activeGimbal->bodyYaw()->rawValue().toFloat() + (yawRate * 0.1f);
        pitchRateParam = NAN;
        yawRateParam = NAN;
    }

    if (managerCompId == 0 || deviceId == 0) {
        qCInfo(CodevCameraLog) << "[RCFlow]"
                << sourceTag
                << "px4 gimbal manager unavailable, fallback to gimbal component"
                << "cameraCompId" << _compID
                << "managerCompId" << managerCompId
                << "deviceId" << deviceId;
        managerCompId = MAV_COMP_ID_GIMBAL;
        deviceId = 1;
    }

    qCInfo(CodevCameraLog) << "[RCFlow]"
            << sourceTag
            << "send gimbal manager rc command"
            << "cameraCompId" << _compID
            << "targetCompId" << managerCompId
            << "deviceId" << deviceId
            << "command" << MAV_CMD_DO_GIMBAL_MANAGER_PITCHYAW
            << "pitch" << pitchParam
            << "yaw" << yawParam
            << "pitchRate" << pitchRate
            << "yawRate" << yawRate
            << "flags" << flags
            << "queueSize" << _mavCommandQueue.count();

    mavlink_message_t msg;
    mavlink_command_long_t cmd;
    memset(&cmd, 0, sizeof(cmd));
    cmd.target_system = _vehicle->id();
    cmd.target_component = static_cast<uint8_t>(managerCompId);
    cmd.command = MAV_CMD_DO_GIMBAL_MANAGER_PITCHYAW;
    cmd.confirmation = 0;
    cmd.param1 = pitchParam;
    cmd.param2 = yawParam;
    cmd.param3 = pitchRateParam;
    cmd.param4 = yawRateParam;
    cmd.param5 = static_cast<float>(flags);
    cmd.param6 = 0.0f;
    cmd.param7 = static_cast<float>(deviceId);
    mavlink_msg_command_long_encode(_pMavlink->getSystemId(),
                                    _pMavlink->getComponentId(),
                                    &msg,
                                    &cmd);
    _vehicle->sendMessageOnLinkThreadSafe(_link, msg);
    return true;
}

void CodevCameraControl::_sendR3RcChannels(const mavlink_rc_channels_t& rc, const char* sourceTag)
{
    mavlink_rc_channels_t outbound = rc;
    outbound.time_boot_ms = static_cast<uint32_t>(QGC::groundTimeMilliseconds());
    if (outbound.chancount < 18) {
        outbound.chancount = 18;
    }
    if (outbound.chan11_raw == 0) {
        outbound.chan11_raw = kRcGimbalCenter;
    }
    if (outbound.chan15_raw == 0) {
        outbound.chan15_raw = kRcGimbalCenter;
    }
    outbound.rssi = rc.rssi == 0 ? 255 : rc.rssi;

    qCInfo(CodevCameraLog) << "[RCFlow]"
            << sourceTag
            << "forward rc channels to R3"
            << "cameraCompId" << _compID
            << "sourceSysId" << _vehicle->id()
            << "sourceCompId" << MAV_COMP_ID_AUTOPILOT1
            << "message" << MAVLINK_MSG_ID_RC_CHANNELS
            << "ch9Pitch" << outbound.chan9_raw
            << "ch10Yaw" << outbound.chan10_raw
            << "ch11Zoom" << outbound.chan11_raw
            << "ch15Center" << outbound.chan15_raw
            << "chancount" << outbound.chancount
            << "queueSize" << _mavCommandQueue.count();

    mavlink_message_t msg;
    mavlink_msg_rc_channels_encode(static_cast<uint8_t>(_vehicle->id()),
                                   MAV_COMP_ID_AUTOPILOT1,
                                   &msg,
                                   &outbound);
    _vehicle->sendMessageOnLinkThreadSafe(_link, msg);
}

void CodevCameraControl::_sendLegacyMountControl(float pitch, float yaw, const char* sourceTag)
{
    qCInfo(CodevCameraLog) << "[RCFlow]"
            << sourceTag
            << "send legacy mount control"
            << "cameraCompId" << _compID
            << "targetCompId" << MAV_COMP_ID_GIMBAL
            << "command" << MAV_CMD_DO_MOUNT_CONTROL
            << "pitch" << pitch
            << "roll" << 0.0f
            << "yaw" << yaw
            << "mode" << MAV_MOUNT_MODE_MAVLINK_TARGETING;

    mavlink_message_t msg;
    mavlink_command_long_t cmd;
    memset(&cmd, 0, sizeof(cmd));
    cmd.target_system = _vehicle->id();
    cmd.target_component = MAV_COMP_ID_GIMBAL;
    cmd.command = MAV_CMD_DO_MOUNT_CONTROL;
    cmd.confirmation = 0;
    cmd.param1 = pitch;
    cmd.param2 = 0.0f;
    cmd.param3 = yaw;
    cmd.param4 = 0.0f;
    cmd.param5 = 0.0f;
    cmd.param6 = 0.0f;
    cmd.param7 = MAV_MOUNT_MODE_MAVLINK_TARGETING;
    mavlink_msg_command_long_encode(_pMavlink->getSystemId(),
                                    _pMavlink->getComponentId(),
                                    &msg,
                                    &cmd);
    _vehicle->sendMessageOnLinkThreadSafe(_link, msg);
}

void CodevCameraControl::centerGimbal()
{
    _logControlState("centerGimbal");
    const uint32_t gimbalManagerFlags = GIMBAL_MANAGER_FLAGS_ROLL_LOCK
        | GIMBAL_MANAGER_FLAGS_PITCH_LOCK
        | GIMBAL_MANAGER_FLAGS_YAW_IN_VEHICLE_FRAME;

    if (_sendGimbalManagerPitchYaw(0.0f, 0.0f, gimbalManagerFlags, "centerGimbal")) {
        return;
    }

    qCInfo(CodevCameraLog) << "[CameraFlow]"
            << "centerGimbal"
            << "using legacy mount control"
            << "cameraCompId" << _compID
            << "targetCompId" << MAV_COMP_ID_GIMBAL
            << "command" << MAV_CMD_DO_MOUNT_CONTROL;
    sendMavCommandWithTarget(
        MAV_CMD_DO_MOUNT_CONTROL,           // Command id
        MAV_COMP_ID_GIMBAL,                 // Target id
        0,0,0,0,0,0,1);
}

void CodevCameraControl::setSpotTempPoint(float x, float y)
{
    // thermometry point
    Fact* fact = getFact(kIR_TEMP_POINT);
    if(fact) {
        float value[2] = { x, y };
        QByteArray array;
        array.append((char*)&value, sizeof(value));
        fact->forceSetRawValue(QVariant(array));
    }
}

void CodevCameraControl::setAreaTempRect(float x1, float y1, float x2, float y2)
{
    Fact* fact = getFact(kIR_TEMP_RECT);
    if(fact) {
        float value[4] = { x1, y1, x2, y2 };
        QByteArray array;
        array.append((char*)&value, sizeof(value));
        fact->forceSetRawValue(QVariant(array));
    }
}

QPointF CodevCameraControl::spotMeteringArea()
{
    Fact* fact = getFact(kEO_SPOTAE);
    if(fact) {
        uint value = fact->rawValue().toUInt();
        qreal x = ((value >> 8) & 0xff) / 100.0;
        qreal y = ((value) & 0xff) / 100.0;
        return QPointF(x, y);
    } else {
        return QPointF();
    }
}

void CodevCameraControl::setSpotMetering(float x, float y)
{
    Fact* fact = getFact(kEO_SPOTAE);
    if(fact) {
        if(x == 0.0f && y == 0.0f) {
            fact->forceSetRawValue(0);
        } else {
            int point = (static_cast<int>(x * 100) << 8) | static_cast<int>(y * 100);
            uint value = static_cast<uint>((1 << 16) | point);
            fact->forceSetRawValue(value);
        }
    }
}

QPointF CodevCameraControl::spotFocusArea()
{
    Fact* fact = getFact(kEO_SPOTFOCUS);
    if(fact) {
        uint value = fact->rawValue().toUInt();
        qreal x = ((value >> 8) & 0xff) / 100.0;
        qreal y = ((value) & 0xff) / 100.0;
        return QPointF(x, y);
    } else {
        return QPointF();
    }
}

void CodevCameraControl::setSpotFocus(float x, float y)
{
    Fact* fact = getFact(kEO_SPOTFOCUS);
    if(fact) {
        if(x == 0.0f && y == 0.0f) {
            fact->forceSetRawValue(0);
        } else {
            int point = (static_cast<int>(x * 100) << 8) | static_cast<int>(y * 100);
            uint value = static_cast<uint>((1 << 16) | point);
            fact->forceSetRawValue(value);
        }
    }
}

void CodevCameraControl::initTracker()
{
    Fact* fact = getFact(kTRACK_ALGORITHM);
    if(fact) {
        _trackingImageStatus.tracking_status = 2;
        fact->setEnumIndex(1);
    }
}

void CodevCameraControl::deinitTracker()
{
    Fact* fact = getFact(kTRACK_ALGORITHM);
    if(fact) {
        fact->setEnumIndex(0);
    }
}

void CodevCameraControl::gimbalControlInImage(QPointF point)
{
    if(point.x() == 0.0 && point.x() == 0.0) return;
    _logControlState("gimbalControlInImage");
    float dzoom = 1.0f;
    Fact* fact = getFact(kEO_DZOOM);
    if(fact) dzoom = fact->rawValue().toFloat();

    const uint32_t gimbalManagerFlags = GIMBAL_MANAGER_FLAGS_ROLL_LOCK
        | GIMBAL_MANAGER_FLAGS_PITCH_LOCK
        | GIMBAL_MANAGER_FLAGS_YAW_IN_VEHICLE_FRAME;

    if (_sendGimbalManagerPitchYaw(static_cast<float>(point.y()), static_cast<float>(point.x()), gimbalManagerFlags, "gimbalControlInImage")) {
        return;
    }

    qCInfo(CodevCameraLog) << "[CameraFlow]"
            << "gimbalControlInImage"
            << "using legacy mount control"
            << "cameraCompId" << _compID
            << "targetCompId" << MAV_COMP_ID_GIMBAL
            << "command" << MAV_CMD_DO_MOUNT_CONTROL
            << "point" << point
            << "zoomLevel" << _zoomLevel
            << "dzoom" << dzoom;
    sendMavCommandWithTarget(
        MAV_CMD_DO_MOUNT_CONTROL,
        MAV_COMP_ID_GIMBAL,
        static_cast<float>(point.y()),  // Pitch 0 - 90
        0,                              // Roll (not used)
        static_cast<float>(point.x()),  // Yaw -180 - 180
        0,                              // Altitude (not used)
        static_cast<float>(_zoomLevel), // Latitude (not used)
        dzoom,                          // Longitude (not used)
        -1);                            // Custom offset Roll,Pitch,Yaw
}

void CodevCameraControl::setVideoMode()
{
    if(!_resetting && hasModes()) {
        qCDebug(CodevCameraLog) << "setVideoMode()";
        //-- Does it have a mode parameter?
        Fact* pMode = mode();
        if(pMode) {
            if(cameraMode() != CAM_MODE_VIDEO) {
                pMode->setRawValue(CAM_MODE_VIDEO);
                _setCameraMode(CAM_MODE_VIDEO);
            }
        } else {
            //-- Use MAVLink Command
            if(_cameraMode != CAM_MODE_VIDEO) {
                //-- Use basic MAVLink message
                sendMavCommand(
                    MAV_CMD_SET_CAMERA_MODE,                // Command id
                    0,                                      // Reserved (Set to 0)
                    CAM_MODE_VIDEO);                        // Camera mode (0: photo, 1: video)
                _setCameraMode(CAM_MODE_VIDEO);
            }
        }
    }
}

void CodevCameraControl::setPhotoMode()
{
    if(!_resetting && hasModes()) {
        qCDebug(CodevCameraLog) << "setPhotoMode()";
        //-- Does it have a mode parameter?
        Fact* pMode = mode();
        if(pMode) {
            if(cameraMode() != CAM_MODE_PHOTO) {
                pMode->setRawValue(CAM_MODE_PHOTO);
                _setCameraMode(CAM_MODE_PHOTO);
            }
        } else {
            //-- Use MAVLink Command
            if(_cameraMode != CAM_MODE_PHOTO) {
                //-- Use basic MAVLink message
                sendMavCommand(
                    MAV_CMD_SET_CAMERA_MODE,                // Command id
                    0,                                      // Reserved (Set to 0)
                    CAM_MODE_PHOTO);                        // Camera mode (0: photo, 1: video)
                _setCameraMode(CAM_MODE_PHOTO);
            }
        }
    }
}

bool CodevCameraControl::takePhoto()
{
    qCDebug(CodevCameraLog) << "takePhoto()";
    //-- Check if camera can capture photos or if it can capture it while in Video Mode
    if(!capturesPhotos()) {
        qCWarning(CodevCameraLog) << "Camera does not handle image capture";
        return false;
    }
    if(cameraMode() == CAM_MODE_VIDEO && !photosInVideoMode()) {
        qCWarning(CodevCameraLog) << "Camera does not handle image capture while in video mode";
        return false;
    }
    if(photoStatus() != PHOTO_CAPTURE_IDLE) {
        qCWarning(CodevCameraLog) << "Camera not idle";
        return false;
    }
    if(!_resetting) {
        if(capturesPhotos()) {
            sendMavCommand(
                MAV_CMD_IMAGE_START_CAPTURE,                                                // Command id
                0,                                                                          // Reserved (Set to 0)
                static_cast<float>(_photoMode == PHOTO_CAPTURE_SINGLE ? 0 : _photoLapse),   // Duration between two consecutive pictures (in seconds--ignored if single image)
                _photoMode == PHOTO_CAPTURE_SINGLE ? 1 : _photoLapseCount,                  // Number of images to capture total - 0 for unlimited capture
                static_cast<float>(_photoIndex+1));
            _setPhotoStatus(PHOTO_CAPTURE_IN_PROGRESS);
            _captureInfoRetries = 0;
            //-- Capture local image as well
            if(qgcApp()->toolbox()->videoManager()) {
                qgcApp()->toolbox()->videoManager()->grabImage();
            }
            return true;
        }
    }
    return false;
}

bool CodevCameraControl::stopTakePhoto()
{
    if(!_resetting) {
        qCDebug(CodevCameraLog) << "stopTakePhoto()";
        if(photoStatus() == PHOTO_CAPTURE_IDLE || (photoStatus() != PHOTO_CAPTURE_INTERVAL_IDLE && photoStatus() != PHOTO_CAPTURE_INTERVAL_IN_PROGRESS)) {
            return false;
        }
        if(capturesPhotos()) {
            sendMavCommand(
                MAV_CMD_IMAGE_STOP_CAPTURE,                                 // Command id
                0);                                                         // Reserved (Set to 0)
            _setPhotoStatus(PHOTO_CAPTURE_IDLE);
            _captureInfoRetries = 0;
            return true;
        }
    }
    return false;
}

bool CodevCameraControl::startVideo()
{
    if(!_resetting) {
        qCDebug(CodevCameraLog) << "startVideo()";
        //-- Check if camera can capture videos or if it can capture it while in Photo Mode
        if(!capturesVideo() || (cameraMode() == CAM_MODE_PHOTO && !videoInPhotoMode())) {
            return false;
        }
        if(videoStatus() != VIDEO_CAPTURE_STATUS_RUNNING) {
            sendMavCommand(
                MAV_CMD_VIDEO_START_CAPTURE,                // Command id
                0,                                          // Reserved (Set to 0)
                0);                                         // CAMERA_CAPTURE_STATUS Frequency
            return true;
        }
    }
    return false;
}

bool CodevCameraControl::stopVideo()
{
    if(!_resetting) {
        qCDebug(CodevCameraLog) << "stopVideo()";
        if(videoStatus() == VIDEO_CAPTURE_STATUS_RUNNING) {
            sendMavCommand(
                MAV_CMD_VIDEO_STOP_CAPTURE,                 // Command id
                0);                                         // Reserved (Set to 0)
            return true;
        }
    }
    return false;
}

void CodevCameraControl::resetSettings()
{
    static Fact* gridLines = qgcApp()->toolbox()->settingsManager()->videoSettings()->gridLines();
    if(gridLines->metaData()->defaultValueAvailable())
        gridLines->setRawValue(gridLines->metaData()->rawDefaultValue());
    setThermalMode(THERMAL_BLEND);
    setThermalOpacity(85);
    QGCCameraControl::setPhotoMode(PHOTO_CAPTURE_SINGLE);
    setPhotoLapse(5.0);
    setPhotoLapseCount(0);
    if(!_resetting) {
        qCDebug(CodevCameraLog) << "resetSettings()";
        _resetting = true;
        sendMavCommand(
            MAV_CMD_RESET_CAMERA_SETTINGS,          // Command id
            1);                                     // Do Reset
    }
}

void CodevCameraControl::formatCard(int id)
{
    if(!_resetting) {
        qCDebug(CodevCameraLog) << "formatCard()";
        sendMavCommand(
            MAV_CMD_STORAGE_FORMAT,                 // Command id
            id,                                     // Storage ID (1 for first, 2 for second, etc.)
            1);                                     // Do Format
    }
}

void CodevCameraControl::startZoom(int direction)
{
    qCDebug(CodevCameraLog) << "startZoom()" << direction;
    if(hasZoom()) {
        sendMavCommand(
            MAV_CMD_SET_CAMERA_ZOOM,                // Command id
            ZOOM_TYPE_CONTINUOUS,                   // Zoom type
            direction);                             // Direction (-1 wide, 1 tele)
    }
}

void CodevCameraControl::stopZoom()
{
    qCDebug(CodevCameraLog) << "stopZoom()";
    if(hasZoom()) {
        sendMavCommand(
            MAV_CMD_SET_CAMERA_ZOOM,                // Command id
            ZOOM_TYPE_CONTINUOUS,                   // Zoom type
            0);                                     // Direction (-1 wide, 1 tele)
    }
}

void CodevCameraControl::startTracking(QPointF point, double radius)
{
    qCDebug(CodevCameraLog) << "startTracking Point" << point.x() << point.y() << radius << hasTrackingPoint();
    if(hasTrackingPoint() && _vehicle) {
        auto enforceTrackingDefaults = [this]() {
            Fact* smartSelect = getFact(kSMART_SELECT);
            if (smartSelect) {
                const QString current = smartSelect->rawValueString().trimmed();
                if (current.compare(QStringLiteral("None"), Qt::CaseInsensitive) == 0) {
                    smartSelect->setRawValue(QStringLiteral("Yolov8"));
                }
            }

            Fact* trackAlgorithm = getFact(kTRACK_ALGORITHM);
            if (trackAlgorithm) {
                const QString current = trackAlgorithm->rawValueString().trimmed();
                if (current.compare(QStringLiteral("None"), Qt::CaseInsensitive) == 0) {
                    trackAlgorithm->setRawValue(QStringLiteral("Nano"));
                }
            }
        };
        enforceTrackingDefaults();

        float offset_x = 0.0f;
        float offset_y = 0.0f;
        if(_dZoomFact) {
            float dzoom = _dZoomFact->rawValue().toFloat();
            if(dzoom > 1.0f) {
                offset_x = (1.0f - 1.0f / dzoom) / 2.0f;
                offset_y = (1.0f - 1.0f / dzoom) / 2.0f;
            }
            if(offset_x != 0.0f && offset_y != 0.0f) {
                point.setX(point.x() * (1.0f - offset_x * 2.0f) + offset_x);
                point.setY(point.y() * (1.0f - offset_y * 2.0f) + offset_y);
            }
        }
        sendMavCommand(
            MAV_CMD_CAMERA_TRACK_POINT,             // Command id
            static_cast<float>(point.x()),          // Point X
            static_cast<float>(point.y()),          // Point Y
            static_cast<float>(radius));            // Radius
    }
}

void CodevCameraControl::startTracking(QRectF rec)
{
    qCDebug(CodevCameraLog) << "startTracking Rectangle" << rec.x() << rec.y() << (rec.x() + rec.width()) << (rec.y() + rec.height()) << hasTrackingRectangle();
    if(hasTrackingRectangle() && _vehicle) {
        auto enforceTrackingDefaults = [this]() {
            Fact* smartSelect = getFact(kSMART_SELECT);
            if (smartSelect) {
                const QString current = smartSelect->rawValueString().trimmed();
                if (current.compare(QStringLiteral("None"), Qt::CaseInsensitive) == 0) {
                    smartSelect->setRawValue(QStringLiteral("Yolov8"));
                }
            }

            Fact* trackAlgorithm = getFact(kTRACK_ALGORITHM);
            if (trackAlgorithm) {
                const QString current = trackAlgorithm->rawValueString().trimmed();
                if (current.compare(QStringLiteral("None"), Qt::CaseInsensitive) == 0) {
                    trackAlgorithm->setRawValue(QStringLiteral("Nano"));
                }
            }
        };
        enforceTrackingDefaults();

        float offset_x = 0.0f;
        float offset_y = 0.0f;
        if(_dZoomFact) {
            float dzoom = _dZoomFact->rawValue().toFloat();
            if(dzoom > 1.0f) {
                offset_x = (1.0f - 1.0f / dzoom) / 2.0f;
                offset_y = (1.0f - 1.0f / dzoom) / 2.0f;
            }
            if(offset_x != 0.0f && offset_y != 0.0f) {
                double x2 = rec.x() + rec.width();
                double y2 = rec.y() + rec.height();
                x2 = x2 * (1.0f - offset_x * 2.0f) + offset_x;
                y2 = y2 * (1.0f - offset_y * 2.0f) + offset_y;
                rec.setX(rec.x() * (1.0f - offset_x * 2.0f) + offset_x);
                rec.setY(rec.y() * (1.0f - offset_y * 2.0f) + offset_y);
                rec.setWidth(x2 - rec.x());
                rec.setHeight(y2 - rec.y());
            }
        }
        sendMavCommand(
            MAV_CMD_CAMERA_TRACK_RECTANGLE,               // Command id
            static_cast<float>(rec.x()),                  // Point1 X
            static_cast<float>(rec.y()),                  // Point1 Y
            static_cast<float>(rec.x() + rec.width()),    // Point2 X
            static_cast<float>(rec.y() + rec.height()),   // Point2 Y
            1);
    }
}

void CodevCameraControl::stopTracking()
{
    qCDebug(CodevCameraLog) << "stopTracking";
    if((hasTrackingPoint() || hasTrackingRectangle()) && _vehicle) {
        sendMavCommand(MAV_CMD_CAMERA_STOP_TRACKING);
    }
}

void CodevCameraControl::setZoomLevel(qreal level)
{
    if(hasZoom()) {
        if(abs(level - 1.0) < 0.01) stepZoom(0);
        level = std::min(std::max(level, 0.0), 100.0);
        sendMavCommand(
            MAV_CMD_SET_CAMERA_ZOOM,                // Command id
            ZOOM_TYPE_RANGE,                        // Zoom type
            static_cast<float>(level));             // Level
    }
}

// void CodevCameraControl::stepZoom(int direction)
// {
//     qCDebug(CodevCameraLog) << "DZoom()" << direction;
//     // Fact* fact = getFact(kEO_DZOOM);
//     // if(fact) {
//     //     qInfo() << "stepZoom direction = " << direction;
//     //     if(direction > 0) {
//     //         double value = fact->cookedValue().toDouble() + fact->cookedIncrement();
//     //         if(value - fact->cookedMax().toDouble() > 0.01) {
//     //             value = fact->cookedMax().toDouble();
//     //         }
//     //         fact->setRawValue(static_cast<float>(value));
//     //     } else if(direction < 0) {
//     //         double value = fact->cookedValue().toDouble() - fact->cookedIncrement();
//     //         if(value - fact->cookedMin().toDouble() < 0.01) {
//     //             value = fact->cookedMin().toDouble();
//     //         }
//     //         fact->setRawValue(static_cast<float>(value));
//     //     } else {
//     //         fact->setRawValue(1.0f);
//     //     }
//     // }
//     qInfo() << "Direction = " << direction;
//     // if(hasZoom()) {
//     //     sendMavCommand(
//     //         MAV_CMD_SET_CAMERA_ZOOM,                // Command id
//     //         ZOOM_TYPE_STEP,                   // Zoom type
//     //         direction);                             // Direction (-1 wide, 1 tele)
//     // }

//     float newLevel = _zoomLevel + direction;
//     qInfo() << "newLevel = " << newLevel;
//     sendMavCommand(
//         MAV_CMD_SET_CAMERA_ZOOM,
//         ZOOM_TYPE_RANGE,
//         newLevel
//         );


// }

void CodevCameraControl::stepZoom(int direction)
{
    if (!_vehicle || !hasZoom() || direction == 0) {
        return;
    }

    // 현재 디지털 줌 값
    const double dMin = _dZoomFact ? _dZoomFact->cookedMin().toDouble() : 1.0;
    const double dMax = _dZoomFact ? _dZoomFact->cookedMax().toDouble() : 1.0;
    const double dInc = _dZoomFact ? _dZoomFact->cookedIncrement() : 0.2;
    double dNow = _dZoomFact ? _dZoomFact->cookedValue().toDouble() : 1.0;

    const bool atOpticalMax = ( _zoomLevel >= 29.5 ); 
    float newLevel = _zoomLevel;
    if (direction > 0) {
        // 줌인
        if (!atOpticalMax) {
            // 1) 광학 줌 구간: RANGE 증가

            if (_zoomLevel <= 1.1 && _opticalRange > 2.0f) {
                _opticalRange = 1.0f;
            }

            qCDebug(CodevCameraLog) << "Zoom in optical Range = " << _opticalRange;
            _opticalRange = std::min(100.0f, newLevel + direction);

            sendMavCommand(
                MAV_CMD_SET_CAMERA_ZOOM,
                ZOOM_TYPE_RANGE,
                _opticalRange);
        } else {
            // 2) 광학 최대 이후: 디지털 줌 증가
            if (_dZoomFact) {
                double next = std::min(dMax, dNow + dInc);
                _dZoomFact->setRawValue(static_cast<float>(next));
            } else {
                qCWarning(CodevCameraLog) << "No kEO_DZOOM fact; cannot digital zoom";
            }
        }
    } else {
        // 줌아웃
        if (_dZoomFact && dNow > (dMin + 1e-6)) {
            // 1) 디지털이 남아 있으면 디지털부터 감소
            double next = std::max(dMin, dNow - dInc);
            _dZoomFact->setRawValue(static_cast<float>(next));
        } else {
            // 2) 디지털이 1.0이면 광학 RANGE 감소
            qCDebug(CodevCameraLog) << "Zoom out optical Range = " << _opticalRange;
            _opticalRange = std::max(0.0f, newLevel + direction); //Direction = -1

            sendMavCommand(
                MAV_CMD_SET_CAMERA_ZOOM,
                ZOOM_TYPE_RANGE,
                _opticalRange);
        }
    }
}

QStringList CodevCameraControl::activeSettings()
{
    QStringList settings = _activeSettings;
    QStringList removedSettings;
    if(!_hasTrack) {
        settings.removeOne(kTRACK_ALGORITHM);
        removedSettings << kTRACK_ALGORITHM;
    }
    if(!_hasDetect) {
        settings.removeOne(kSMART_SELECT);
        removedSettings << kSMART_SELECT;
    }
    settings.removeOne(kFACTORY_CALI);
    removedSettings << kFACTORY_CALI;
    qCDebug(CodevCameraLog) << "[CodevCamera]"
            << "activeSettings() compId" << compID()
            << "paramComplete" << paramComplete()
            << "base" << _activeSettings
            << "removed" << removedSettings
            << "track" << _hasTrack
            << "detect" << _hasDetect
            << "result" << settings;
    return settings;
}

void CodevCameraControl::_parametersReady()
{

    qCDebug(CodevCameraLog) << "[CodevCamera]"
            << "_parametersReady compId" << compID()
            << "paramComplete" << paramComplete()
            << "initial active settings" << _activeSettings;
    _logControlState("_parametersReady before setup");
    disconnect(this, &CodevCameraControl::parametersReady, this, &CodevCameraControl::_parametersReady);

    // nvidia system status
    Fact* fact = getFact(kNV_STATUS);
    if(fact) {
        connect(fact, &Fact::rawValueChanged, this, &CodevCameraControl::_handleNVStatus);
    }

    // thermometry data
    fact = getFact(kIR_TEMP_DATA);
    if(fact) {
        connect(fact, &Fact::rawValueChanged, this, &CodevCameraControl::_handleThermometryData);
    }

    // spot metering area
    fact = getFact(kEO_SPOTAE);
    if(fact) {
        connect(fact, &Fact::rawValueChanged, this, &CodevCameraControl::spotMeteringAreaChanged);
    }

    // spot focus area
    fact = getFact(kEO_SPOTFOCUS);
    if(fact) {
        connect(fact, &Fact::rawValueChanged, this, &CodevCameraControl::spotFocusAreaChanged);
    }

    // time zones
    fact = getFact(kTIME_ZONE);
    if(fact) {
        QByteArray value = QTimeZone::systemTimeZone().id();
        if (value.size() < 128) {
            value.append(128 - value.size(), 0);
        }
        fact->setRawValue(QVariant(value));
    }

    // zoom mode
    fact = getFact(kEO_ZOOM_MODE);
    if(fact) {
        _zoomModeFact = fact;
    }

    // dzoom
    fact = getFact(kEO_DZOOM);
    if (fact) {
        _dZoomFact = fact;
        _dZoomInMaxChange();
        connect(this, &CodevCameraControl::zoomLevelChanged, this, &CodevCameraControl::_dZoomInMaxChange);
    }

    // ai source
    fact = getFact(kAI_SOURCE);
    if(fact) {
        _aiSourceFact = fact;
    }

    // detect objects
    fact = getFact(kDETECT_OBJECTS);
    if(fact) {
        connect(fact, &Fact::rawValueChanged, this, &CodevCameraControl::_handleDetectObjects);
    }

    // detect plugins
    fact = getFact(kDETECT_PLUGINS);
    if(fact) {
        Fact* detect = getFact(kSMART_SELECT);
        if(detect) {
            FactMetaData* meta = detect->metaData();
            QString value = fact->rawValueString().remove(QChar('\0'));
            QStringList plugins = value.trimmed().split(',');
            plugins.push_front("None");
            if(plugins.size() && meta) {
                QVariantList values;
                for(QString v : plugins) {
                    values.append(v);
                }
                meta->setEnumInfo(plugins, values);
                _hasDetect = true;
            }
        }
    }

    // track plugins
    fact = getFact(kTRACK_PLUGINS);
    if(fact) {
        Fact* track = getFact(kTRACK_ALGORITHM);
        if(track) {
            QStringList exclusions;
            exclusions << kSMART_SELECT << kAI_RESOLUTION;
            if(_aiSourceFact) exclusions << kAI_SOURCE;
            FactMetaData* meta = track->metaData();
            QString value = fact->rawValueString().remove(QChar('\0'));
            QStringList plugins = value.trimmed().split(',');
            plugins.push_front("None");
            if(plugins.size() && meta) {
                QVariantList values;
                for(QString v : plugins) {
                    values.append(v);
                    _originalOptNames[kTRACK_ALGORITHM] << v;
                    _originalOptValues[kTRACK_ALGORITHM] << v;
                    if(v != "None") {
                        QGCCameraOptionExclusion* pExc = new QGCCameraOptionExclusion(this, kTRACK_ALGORITHM, v, exclusions);
                        QQmlEngine::setObjectOwnership(pExc, QQmlEngine::CppOwnership);
                        _valueExclusions.append(pExc);
                    }
                }
                meta->setEnumInfo(plugins, values);
                _hasTrack = true;
            }
            if(track->cookedValue().toString() != "None") {
                _activeSettings.removeOne(kSMART_SELECT);
                _activeSettings.removeOne(kAI_RESOLUTION);
                if(_aiSourceFact) _activeSettings.removeOne(kAI_SOURCE);
            }
        }
    }

    qCDebug(CodevCameraLog) << "[CodevCamera]"
            << "_parametersReady compId" << compID()
            << "paramComplete" << paramComplete()
            << "hasTrack" << _hasTrack
            << "hasDetect" << _hasDetect
            << "active settings after custom setup" << _activeSettings
            << "returned active settings" << activeSettings();
    _logControlState("_parametersReady after setup");

    // json transfor request
    fact = getFact(kJSON_TR_REQ);
    if(fact) {
        _requestJSONTransfor(fact->rawValue());
        connect(fact, &Fact::rawValueChanged, this, &CodevCameraControl::_requestJSONTransfor);
    }

    // camera calibrate flags
    fact = getFact(kCALIBRATE_FLAGS);
    if(fact) {
        factChanged(fact);
        connect(fact, &Fact::rawValueChanged, this, &CodevCameraControl::_paramSlefChanged);
    }

    for (const QString& factName : activeSettings()) {
        _localizeFactMetaData(getFact(factName));
    }
    // Translate option range lists and original option names so dynamic enum updates stay localized.
    for (auto it = _originalOptNames.begin(); it != _originalOptNames.end(); ++it) {
        it.value() = _translateCameraSettingList(it.value());
    }
    for (QGCCameraOptionRange* range : _optionRanges) {
        if (range) {
            range->optNames = _translateCameraSettingList(range->optNames);
        }
    }
}

QString CodevCameraControl::_factValueForLog(const char* factName) const
{
    Fact* fact = const_cast<CodevCameraControl*>(this)->getFact(factName);
    if (!fact) {
        return QStringLiteral("<missing>");
    }

    QString value = fact->rawValueString().trimmed();
    value.remove(QChar('\0'));
    if (value.isEmpty()) {
        value = fact->rawValue().toString();
    }
    return value;
}

void CodevCameraControl::_logControlState(const char* sourceTag) const
{
    qCInfo(CodevCameraLog) << "[CameraFlow]"
            << sourceTag
            << "state"
            << "cameraCompId" << _compID
            << "model" << _modelName
            << "yawMode" << _factValueForLog("YAW_MODE")
            << "gbSpeed" << _factValueForLog("GB_SPEED")
            << "yawSmooth" << _factValueForLog("YAW_SMOOTH")
            << "landingMode" << _factValueForLog("LANDING_MODE")
            << "landModeSwitch" << _factValueForLog("LANDMODE_SWITCH")
            << "aiSource" << _factValueForLog("AI_SOURCE")
            << "eoDZoom" << _factValueForLog("EO_DZOOM")
            << "eoZoomMode" << _factValueForLog("EO_ZOOM_MODE")
            << "trackAlgorithm" << _factValueForLog("TRACK_ALGORITHM")
            << "smartSelect" << _factValueForLog("SMART_SELECT");
}

bool CodevCameraControl::_consumeQueuedCommandAck(int ackCompId, const mavlink_command_ack_t& ack, const char* sourceTag)
{
    if (!_mavCommandQueue.count()) {
        return false;
    }

    const MavCommandQueueEntry_t& queuedCommand = _mavCommandQueue[0];
    if (queuedCommand.command != ack.command || queuedCommand.component != ackCompId) {
        return false;
    }

    qCInfo(CodevCameraLog) << "[CameraFlow]"
            << sourceTag
            << "matched queued ack"
            << "cameraCompId" << _compID
            << "ackCompId" << ackCompId
            << "command" << ack.command
            << "result" << ack.result
            << "queueSizeBefore" << _mavCommandQueue.count();

    _mavCommandAckTimer.stop();
    _mavCommandQueue.removeFirst();
    _sendNextQueuedMavCommand();
    return true;
}

void CodevCameraControl::_handleVehicleMavlinkMessage(const mavlink_message_t& message, LinkInterface* link)
{
    Q_UNUSED(link);

    if (message.sysid != _vehicle->id() || message.msgid != MAVLINK_MSG_ID_COMMAND_ACK) {
        return;
    }

    mavlink_command_ack_t ack;
    mavlink_msg_command_ack_decode(&message, &ack);

    if (_consumeQueuedCommandAck(message.compid, ack, "rawAck")) {
        _mavCommandResult(_vehicle->id(), compID(), ack.command, ack.result, false);
    }
}

void CodevCameraControl::_localizeFactMetaData(Fact* fact)
{
    if (!fact) {
        return;
    }

    FactMetaData* meta = fact->metaData();
    if (!meta) {
        return;
    }

    const QString shortDescription = meta->shortDescription();
    if (!shortDescription.isEmpty()) {
        meta->setShortDescription(_translateCameraSettingText(shortDescription));
    }

    const QString longDescription = meta->longDescription();
    if (!longDescription.isEmpty()) {
        meta->setLongDescription(_translateCameraSettingText(longDescription));
    }

    const QStringList enumStrings = meta->enumStrings();
    if (!enumStrings.isEmpty()) {
        meta->setEnumInfo(_translateCameraSettingList(enumStrings), meta->enumValues());
    }
}

void CodevCameraControl::_paramSlefChanged()
{
    Fact* fact = qobject_cast<Fact*>(sender());
    if(fact) {
        factChanged(fact);
    }
}

void CodevCameraControl::_requestJSONTransfor(QVariant data)
{
    //QString url = data.toString();

    QString url = "http://192.168.2.119:6666/json/fffea4215538";

    qCDebug(CodevCameraLog) << "Request json:" << url;
    if(url.isEmpty()) return;
    if(!_netManager) {
        _netManager = new QNetworkAccessManager(this);
    }
    QNetworkProxy savedProxy = _netManager->proxy();
    QNetworkProxy tempProxy;
    tempProxy.setType(QNetworkProxy::DefaultProxy);
    _netManager->setProxy(tempProxy);
    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, true);
    QSslConfiguration conf = request.sslConfiguration();
    conf.setPeerVerifyMode(QSslSocket::VerifyNone);
    request.setSslConfiguration(conf);
    QNetworkReply* reply = _netManager->get(request);
    connect(reply, &QNetworkReply::finished,  this, &CodevCameraControl::_downloadJSONFinished);
    _netManager->setProxy(savedProxy);
}

void CodevCameraControl::_downloadJSONFinished()
{
    QNetworkReply* reply = qobject_cast<QNetworkReply*>(sender());
    if(!reply) {
        return;
    }
    int err = reply->error();
    int http_code = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    QByteArray data = reply->readAll();
    if(err == QNetworkReply::NoError && http_code == 200) {
        QJsonDocument jsonDocument = QJsonDocument::fromJson(data);
        if (jsonDocument.isNull()) {
            qCWarning(CodevCameraLog) << "Failed to parse Camera JSON";
            return;
        }
        QJsonObject jsonObject = jsonDocument.object();
        if(jsonObject.contains("AI_CONFIG.yaml")) {
            QStringList labelList;
            if(!jsonObject["AI_CONFIG.yaml"].isNull() && jsonObject["AI_CONFIG.yaml"].isObject()) {
                QJsonObject configObject = jsonObject["AI_CONFIG.yaml"].toObject();
                for (const QString& key : configObject.keys()) {
                    if(key.endsWith(".labels")) {
                        if(configObject[key].isArray()) {
                            QJsonArray labels = configObject[key].toArray();
                            for (int i = 0; i< labels.count(); i++) {
                                QJsonValue jsonValue = labels.at(i);
                                if(jsonValue.isString()) {
                                    labelList.append(jsonValue.toString());
                                }
                            }
                        }
                        break;
                    }
                }
            }
            _targetObjectLabels.clear();
            _targetObjectLabels.append(labelList);
        }
    } else {
        data.clear();
        qCWarning(CodevCameraLog) << QString("Camera Json (%1) download error: %2 status: %3").arg(
            reply->url().toDisplayString(),
            reply->errorString(),
            reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toString()
            );
    }
}

void CodevCameraControl::_dZoomInMaxChange()
{
    double max_zoom = 29.5;
    if(_zoomModeFact && _zoomModeFact->rawValue().toInt() == 2) {
        max_zoom = 239.5;
    }
    if(_zoomLevel >= max_zoom) {
        if(!_dZoomInMax) {
            _dZoomInMax = true;
            emit dZoomInMaxChanged();
        }
    } else {
        if(_dZoomInMax) {
            _dZoomInMax = false;
            emit dZoomInMaxChanged();
        }
    }
}

void CodevCameraControl::_handleThermometryData(QVariant data)
{
    _resetTempPacket.stop();
    memcpy(&_tempPacket, data.toByteArray().data(), sizeof(_tempPacket));
    emit thermometryDataChanged();
    _resetTempPacket.start();
}

void CodevCameraControl::_handleNVStatus(QVariant data)
{
    _resetNVStatusPacket.stop();
    memcpy(&_nvStatusPacket, data.toByteArray().data(), sizeof(_nvStatusPacket));
    emit nvStatusChanged();
    _resetNVStatusPacket.start();
}

void CodevCameraControl::_handleDetectObjects(QVariant data)
{
    QStringList labels_database;
    if(_targetObjectLabels.size() > 0) {
        labels_database.append(_targetObjectLabels);
    } else {
        labels_database.append(detected_labels_database);
    }
    float offset_x = 0.0f;
    float offset_y = 0.0f;
    if(_dZoomFact && (_aiSourceFact == nullptr || _aiSourceFact->enumIndex() == 0)) {
        float dzoom = _dZoomFact->rawValue().toFloat();
        if(dzoom > 1.0f) {
            offset_x = (1.0f - 1.0f / dzoom) / 2.0f;
            offset_y = (1.0f - 1.0f / dzoom) / 2.0f;
        }
    }
    _resetDetectObjectsPacket.stop();
    DetectObjectsPacket _packet;
    memcpy(&_packet, data.toByteArray().data(), sizeof(_packet));
    QObjectList swaplist;
    for(int i = 0; i < _packet.size; i++) {
        if(_packet.objects[i].type >= labels_database.size()) continue;
        float x1 = _packet.objects[i].x / 10000.0f;
        float y1 = _packet.objects[i].y / 10000.0f;
        float x2 = (_packet.objects[i].x + _packet.objects[i].width) / 10000.0f;
        float y2 = (_packet.objects[i].y + _packet.objects[i].height) / 10000.0f;
        if(offset_x != 0.0f && offset_y != 0.0f) {
            x1 = (x1 - offset_x) / (1.0f - offset_x * 2.0f);
            y1 = (y1 - offset_y) / (1.0f - offset_y * 2.0f);
            x2 = (x2 - offset_x) / (1.0f - offset_x * 2.0f);
            y2 = (y2 - offset_y) / (1.0f - offset_y * 2.0f);
        }
        QString objectId = labels_database.size() > _packet.objects[i].type ? labels_database[_packet.objects[i].type]: "none";
        TargetObject* p = new TargetObject(x1, y1, x2, y2, objectId, _packet.objects[i].score / 10000.0f);
        p->setObjectName("");
        swaplist.append(p);
    }
    QObjectList oldlist = _targetObjects.swapObjectList(swaplist);
    foreach(QObject *obj, oldlist) {
        obj->deleteLater();
    }
    _resetDetectObjectsPacket.start();
}

void CodevCameraControl::handleTrackingImageStatus(const mavlink_camera_tracking_image_status_t *tis)
{
    mavlink_camera_tracking_image_status_t tracking_image_status;
    memcpy(&tracking_image_status, tis, sizeof(tracking_image_status));
    // qInfo() << "Tracking image status:"
    //         << "status" << tracking_image_status.tracking_status
    //         << "mode" << tracking_image_status.tracking_mode
    //         << "point" << tracking_image_status.point_x << tracking_image_status.point_y
    //         << "rect" << tracking_image_status.rec_top_x << tracking_image_status.rec_top_y
    //         << tracking_image_status.rec_bottom_x << tracking_image_status.rec_bottom_y;

    const bool wasTrackingActive = (_trackingImageStatus.tracking_status == CAMERA_TRACKING_STATUS_FLAGS_ACTIVE);
    bool changed = false;
    if(tracking_image_status.tracking_status == 255) {
        if(!_busy_in_detect_setup) {
            _busy_in_detect_setup = true;
            changed = true;
        }
        if(_busy_in_track_setup) {
            _busy_in_track_setup = false;
            changed = true;
        }
    } else if(tracking_image_status.tracking_status == 254) {
        if(_busy_in_detect_setup) {
            _busy_in_detect_setup = false;
            changed = true;
        }
        if(!_busy_in_track_setup) {
            _busy_in_track_setup = true;
            changed = true;
        }
    } else if(tracking_image_status.tracking_status == 1) {
        if(_trackingImageStatus.tracking_mode == 2) {
            float offset_x = 0.0f;
            float offset_y = 0.0f;
            if(_dZoomFact) {
                float dzoom = _dZoomFact->rawValue().toFloat();
                if(dzoom > 1.0f) {
                    offset_x = (1.0f - 1.0f / dzoom) / 2.0f;
                    offset_y = (1.0f - 1.0f / dzoom) / 2.0f;
                }
                if(offset_x != 0.0f && offset_y != 0.0f) {
                    tracking_image_status.rec_top_x = (tracking_image_status.rec_top_x - offset_x) / (1.0f - offset_x * 2.0f);
                    tracking_image_status.rec_top_y = (tracking_image_status.rec_top_y - offset_y) / (1.0f - offset_y * 2.0f);
                    tracking_image_status.rec_bottom_x = (tracking_image_status.rec_bottom_x - offset_x) / (1.0f - offset_x * 2.0f);
                    tracking_image_status.rec_bottom_y = (tracking_image_status.rec_bottom_y - offset_y) / (1.0f - offset_y * 2.0f);
                }
            }
            const float left = tracking_image_status.rec_top_x;
            const float top = tracking_image_status.rec_top_y;
            const float right = tracking_image_status.rec_bottom_x;
            const float bottom = tracking_image_status.rec_bottom_y;
            const bool outOfRange = left < 0.0f || left > 1.0f
                || top < 0.0f || top > 1.0f
                || right < 0.0f || right > 1.0f
                || bottom < 0.0f || bottom > 1.0f;
            const bool invalidRect = right <= left || bottom <= top;
            const float width = right - left;
            const float height = bottom - top;
            const float area = width * height;
            const float centerX = (left + right) * 0.5f;
            const float centerY = (top + bottom) * 0.5f;
            const bool boxTooSmall = area < kTrackingSmallBoxArea;
            const bool outsideCenter30 = centerX < kTrackingCenterMargin || centerX > kTrackingCenterMax
                || centerY < kTrackingCenterMargin || centerY > kTrackingCenterMax;
            const bool shouldDelayStop = outOfRange || invalidRect || (boxTooSmall && outsideCenter30);
            if (shouldDelayStop) {
                const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
                if (_trackingInvalidStartMs < 0) {
                    _trackingInvalidStartMs = nowMs;
                } else if (nowMs - _trackingInvalidStartMs >= kTrackingInvalidStopDelayMs) {
                    qCWarning(CodevCameraLog) << "Tracking rect invalid/undesired for too long, stopping tracking"
                               << "rect" << left << top << right << bottom;
                    setTrackingEnabled(false);
                    stopTracking();
                    centerGimbal();
                    tracking_image_status.tracking_status = 0;
                    tracking_image_status.rec_top_x = 0.0f;
                    tracking_image_status.rec_top_y = 0.0f;
                    tracking_image_status.rec_bottom_x = 0.0f;
                    tracking_image_status.rec_bottom_y = 0.0f;
                    _trackingInvalidStartMs = -1;
                }
            } else {
                _trackingInvalidStartMs = -1;
            }
        }
        if(_busy_in_detect_setup) {
            _busy_in_detect_setup = false;
            changed = true;
        }
        if(_busy_in_track_setup) {
            _busy_in_track_setup = false;
            changed = true;
        }
    } else if(tracking_image_status.tracking_status == 0) {
        if(wasTrackingActive) {
            centerGimbal();
        }
        if(_busy_in_detect_setup) {
            _busy_in_detect_setup = false;
            changed = true;
        }
        if(_busy_in_track_setup) {
            _busy_in_track_setup = false;
            changed = true;
        }
    }
    if(changed) emit busyInSetupChanged();
    if(tracking_image_status.tracking_status < 3) {
        QGCCameraControl::handleTrackingImageStatus(&tracking_image_status);
    }
}

void CodevCameraControl::handleRCChannels(const mavlink_rc_channels_t& rc)
{
    static uint16_t rc_zoom_value = 0;
    if(rc_zoom_value != rc.chan11_raw) {
        rc_zoom_value = rc.chan11_raw;
        if (!_rcCameraSettingsRequestTimer.isValid()
                || _rcCameraSettingsRequestTimer.elapsed() >= kRcCameraSettingsRequestMinIntervalMs) {
            _requestCameraSettings();
            _rcCameraSettingsRequestTimer.restart();
        }
    }

    if (!_vehicle || !_vehicle->px4Firmware()) {
        static QElapsedTimer skipDirectControlLogTimer;
        if (!skipDirectControlLogTimer.isValid() || skipDirectControlLogTimer.elapsed() >= 1000) {
            qCInfo(CodevCameraLog) << "[RCFlow]"
                    << "skip Codev direct rc gimbal control"
                    << "reason" << "non_px4_vehicle"
                    << "cameraCompId" << _compID
                    << "vehicleId" << (_vehicle ? _vehicle->id() : -1);
            skipDirectControlLogTimer.restart();
        }
        return;
    }

    if (!_isR3CameraModel(modelName())) {
        static QElapsedTimer skipNonR3LogTimer;
        if (!skipNonR3LogTimer.isValid() || skipNonR3LogTimer.elapsed() >= 1000) {
            qCInfo(CodevCameraLog) << "[RCFlow]"
                    << "skip native R3 rc forwarding"
                    << "reason" << "non_r3_camera"
                    << "cameraCompId" << _compID
                    << "model" << modelName()
                    << "vendor" << vendor();
            skipNonR3LogTimer.restart();
        }
        return;
    }

    const uint16_t pitchRaw = rc.chan9_raw;
    const uint16_t yawRaw = rc.chan10_raw;
    const uint16_t zoomRaw = rc.chan11_raw;
    const uint16_t centerRaw = rc.chan15_raw;
    if (!_isValidRcGimbalPwm(pitchRaw) || !_isValidRcGimbalPwm(yawRaw)) {
        return;
    }

    const float pitchRate = _rcPwmToGimbalRate(pitchRaw, kRcGimbalMaxPitchRateDegS);
    const float yawRate = _rcPwmToGimbalRate(yawRaw, kRcGimbalMaxYawRateDegS);
    const bool centered = qFuzzyIsNull(pitchRate) && qFuzzyIsNull(yawRate);

    const bool firstCommand = !_rcGimbalCommandTimer.isValid();
    if (firstCommand) {
        _rcGimbalCommandTimer.start();
    }

    const bool rawChanged =
            qAbs(static_cast<int>(pitchRaw) - static_cast<int>(_lastRcGimbalPitchRaw)) >= kRcGimbalChangeThreshold ||
            qAbs(static_cast<int>(yawRaw) - static_cast<int>(_lastRcGimbalYawRaw)) >= kRcGimbalChangeThreshold ||
            qAbs(static_cast<int>(zoomRaw) - static_cast<int>(_lastRcGimbalZoomRaw)) >= kRcGimbalChangeThreshold ||
            qAbs(static_cast<int>(centerRaw) - static_cast<int>(_lastRcGimbalCenterRaw)) >= kRcGimbalChangeThreshold;
    const bool centerTransition = centered != _lastRcGimbalWasCentered;
    const qint64 elapsedMs = firstCommand ? kRcGimbalCommandMinIntervalMs : _rcGimbalCommandTimer.elapsed();
    const bool refreshHeldCommand = !centered && elapsedMs >= kRcGimbalCommandMinIntervalMs;

    if (!firstCommand && !rawChanged && !centerTransition && !refreshHeldCommand) {
        return;
    }

    if (!firstCommand && elapsedMs < kRcGimbalCommandMinIntervalMs) {
        return;
    }

    qCInfo(CodevCameraLog) << "[RCFlow]"
            << "Codev aviator rc gimbal native R3 RC"
            << "cameraCompId" << _compID
            << "ch9Pitch" << pitchRaw
            << "ch10Yaw" << yawRaw
            << "ch11Zoom" << zoomRaw
            << "ch15Center" << centerRaw
            << "pitchRate" << pitchRate
            << "yawRate" << yawRate
            << "elapsedMs" << elapsedMs
            << "rawChanged" << rawChanged
            << "centerTransition" << centerTransition
            << "centered" << centered
            << "queueSize" << _mavCommandQueue.count();

    _sendR3RcChannels(rc, "aviatorRC-native");
    _lastRcGimbalPitchRaw = pitchRaw;
    _lastRcGimbalYawRaw = yawRaw;
    _lastRcGimbalZoomRaw = zoomRaw;
    _lastRcGimbalCenterRaw = centerRaw;
    _lastRcGimbalWasCentered = centered;
    _rcGimbalCommandTimer.restart();

}

void CodevCameraControl::handleCommandAck(const mavlink_command_ack_t& ack)
{
    const int queuedTarget = _mavCommandQueue.count() ? _mavCommandQueue[0].component : -1;
    qCInfo(CodevCameraLog) << "[CameraFlow]"
            << "Codev handleCommandAck"
            << "compId" << compID()
            << "command" << ack.command
            << "result" << ack.result
            << "queueSize" << _mavCommandQueue.count()
            << "queuedTarget" << queuedTarget;
    if (_consumeQueuedCommandAck(compID(), ack, "cameraAck")) {
        // Queue handled by direct camera component ACK.
    } else if(ack.result == MAV_RESULT_ACCEPTED) {
        switch(ack.command) {
            case MAV_CMD_VIDEO_START_CAPTURE:
                setVideoMode();
                _setVideoStatus(VIDEO_CAPTURE_STATUS_RUNNING);
                _captureStatusTimer.start(1000);
                break;
            case MAV_CMD_VIDEO_STOP_CAPTURE:
                setVideoMode();
                _setVideoStatus(VIDEO_CAPTURE_STATUS_STOPPED);
                _captureStatusTimer.start(1000);
                break;
            case MAV_CMD_IMAGE_START_CAPTURE:
                if(_video_status != VIDEO_CAPTURE_STATUS_RUNNING) {
                    setPhotoMode();
                }
                _captureStatusTimer.start(200);
                break;
        }
    }
    _mavCommandResult(_vehicle->id(), compID(), ack.command, ack.result, false);
}

void CodevCameraControl::handleImageCaptured(const mavlink_camera_image_captured_t& ic)
{
    qCDebug(CodevCameraLog) << "handleImageCaptured:" << ic.image_index;
    if(ic.image_index > _photoIndex) {
        _photoIndex = ic.image_index;
        emit photoIndexChanged();
    }
}

void CodevCameraControl::handleCaptureStatus(const mavlink_camera_capture_status_t& cap)
{
    QGCCameraControl::handleCaptureStatus(cap);
    _photoIndex = cap.image_count;
    emit photoIndexChanged();
}

void CodevCameraControl::sendMavCommand(MAV_CMD command, float param1, float param2, float param3, float param4, float param5, float param6, float param7)
{
    MavCommandQueueEntry_t entry;

    entry.component = _compID;
    entry.command = command;
    entry.rgParam[0] = static_cast<double>(param1);
    entry.rgParam[1] = static_cast<double>(param2);
    entry.rgParam[2] = static_cast<double>(param3);
    entry.rgParam[3] = static_cast<double>(param4);
    entry.rgParam[4] = static_cast<double>(param5);
    entry.rgParam[5] = static_cast<double>(param6);
    entry.rgParam[6] = static_cast<double>(param7);

    qCInfo(CodevCameraLog) << "[CameraFlow]"
            << "queue camera command"
            << "cameraCompId" << _compID
            << "targetCompId" << entry.component
            << "command" << command
            << "params"
            << param1 << param2 << param3 << param4 << param5 << param6 << param7;
    _mavCommandQueue.append(entry);

    if (_mavCommandQueue.count() == 1) {
        _mavCommandRetryCount = 0;
        _sendMavCommandAgain();
    }
}

void CodevCameraControl::sendMavCommandWithTarget(MAV_CMD command, int target_component, float param1, float param2, float param3, float param4, float param5, float param6, float param7)
{
    MavCommandQueueEntry_t entry;

    entry.component = target_component;
    entry.command = command;
    entry.rgParam[0] = static_cast<double>(param1);
    entry.rgParam[1] = static_cast<double>(param2);
    entry.rgParam[2] = static_cast<double>(param3);
    entry.rgParam[3] = static_cast<double>(param4);
    entry.rgParam[4] = static_cast<double>(param5);
    entry.rgParam[5] = static_cast<double>(param6);
    entry.rgParam[6] = static_cast<double>(param7);

    qCInfo(CodevCameraLog) << "[CameraFlow]"
            << "queue targeted command"
            << "cameraCompId" << _compID
            << "targetCompId" << target_component
            << "command" << command
            << "params"
            << param1 << param2 << param3 << param4 << param5 << param6 << param7;
    _mavCommandQueue.append(entry);

    if (_mavCommandQueue.count() == 1) {
        _mavCommandRetryCount = 0;
        _sendMavCommandAgain();
    }
}

void CodevCameraControl::_sendMavCommandAgain()
{
    if(!_mavCommandQueue.size()) {
        qWarning(CodevCameraLog) << "Command resend with no commands in queue";
        _mavCommandAckTimer.stop();
        return;
    }

    MavCommandQueueEntry_t& queuedCommand = _mavCommandQueue[0];

    if (_mavCommandRetryCount++ > _mavCommandMaxRetryCount) {
        const MAV_CMD failedCommand = queuedCommand.command;
        qCDebug(CodevCameraLog) << "_sendMavCommandAgain sending failed" << failedCommand;
        _mavCommandQueue.removeFirst();
        _sendNextQueuedMavCommand();
        _mavCommandResult(_vehicle->id(), compID(), failedCommand, MAV_RESULT_CANCELLED, true);
        return;
    }

    _mavCommandAckTimer.start();

    qCInfo(CodevCameraLog) << "[CameraFlow]"
            << "_sendMavCommandAgain sending"
            << "cameraCompId" << _compID
            << "targetCompId" << queuedCommand.component
            << "command" << queuedCommand.command
            << "retry" << _mavCommandRetryCount
            << "queueSize" << _mavCommandQueue.count();

    mavlink_message_t       msg;
    mavlink_command_long_t  cmd;

    memset(&cmd, 0, sizeof(cmd));
    cmd.target_system =     _vehicle->id();
    cmd.target_component =  queuedCommand.component;
    cmd.command =           queuedCommand.command;
    cmd.confirmation =      0;
    cmd.param1 =            queuedCommand.rgParam[0];
    cmd.param2 =            queuedCommand.rgParam[1];
    cmd.param3 =            queuedCommand.rgParam[2];
    cmd.param4 =            queuedCommand.rgParam[3];
    cmd.param5 =            queuedCommand.rgParam[4];
    cmd.param6 =            queuedCommand.rgParam[5];
    cmd.param7 =            queuedCommand.rgParam[6];
    mavlink_msg_command_long_encode(_pMavlink->getSystemId(),
                                    _pMavlink->getComponentId(),
                                    &msg,
                                    &cmd);

    _vehicle->sendMessageOnLinkThreadSafe(_link, msg);
}

void CodevCameraControl::_mavCommandResult(int vehicleId, int component, int command, int result, bool noReponseFromVehicle)
{
    //-- Is this ours?
    if(_vehicle->id() != vehicleId || compID() != component) {
        qCInfo(CodevCameraLog) << "[CameraFlow]"
                << "Codev _mavCommandResult ignored"
                << "cameraCompId" << _compID
                << "vehicleId" << vehicleId
                << "component" << component
                << "command" << command
                << "result" << result
                << "noResponse" << noReponseFromVehicle;
        return;
    }
    qCInfo(CodevCameraLog) << "[CameraFlow]"
            << "Codev _mavCommandResult"
            << "cameraCompId" << _compID
            << "component" << component
            << "command" << command
            << "result" << result
            << "noResponse" << noReponseFromVehicle;
    if(!noReponseFromVehicle && result == MAV_RESULT_IN_PROGRESS) {
        //-- Do Nothing
        qCDebug(CodevCameraLog) << "In progress response for" << command;
    }else if(!noReponseFromVehicle && result == MAV_RESULT_ACCEPTED) {
        switch(command) {
            case MAV_CMD_STORAGE_FORMAT:
                _vehicle->cameraTriggerPoints()->clearAndDeleteContents();
                break;
            case MAV_CMD_RESET_CAMERA_SETTINGS:
                _resetting = false;
                if(isBasic()) {
                    _requestCameraSettings();
                } else {
                    QTimer::singleShot(2000, this, &CodevCameraControl::_requestAllParameters);
                    QTimer::singleShot(2500, this, &CodevCameraControl::_requestCameraSettings);
                }
                break;
            case MAV_CMD_VIDEO_START_CAPTURE:
                _setVideoStatus(VIDEO_CAPTURE_STATUS_RUNNING);
                _captureStatusTimer.start(1000);
                break;
            case MAV_CMD_VIDEO_STOP_CAPTURE:
                _setVideoStatus(VIDEO_CAPTURE_STATUS_STOPPED);
                _captureStatusTimer.start(1000);
                break;
            case MAV_CMD_REQUEST_CAMERA_CAPTURE_STATUS:
                _captureInfoRetries = 0;
                break;
            case MAV_CMD_REQUEST_STORAGE_INFORMATION:
                _storageInfoRetries = 0;
                break;
            case MAV_CMD_IMAGE_START_CAPTURE:
                _captureStatusTimer.start(200);
                break;
            case MAV_CMD_SET_CAMERA_ZOOM:
                _requestCameraSettings();
                break;
        }
    } else {
        if(noReponseFromVehicle || result == MAV_RESULT_TEMPORARILY_REJECTED || result == MAV_RESULT_FAILED) {
            if(noReponseFromVehicle) {
                qCDebug(CodevCameraLog) << "No response for" << command;
            } else if (result == MAV_RESULT_TEMPORARILY_REJECTED) {
                qCDebug(CodevCameraLog) << "Command temporarily rejected for" << command;
            } else {
                qCDebug(CodevCameraLog) << "Command failed for" << command;
            }
            switch(command) {
                case MAV_CMD_IMAGE_START_CAPTURE:
                case MAV_CMD_IMAGE_STOP_CAPTURE:
                    if(++_captureInfoRetries < 1) {
                        _captureStatusTimer.start(1000);
                    } else {
                        qCDebug(CodevCameraLog) << "Giving up start/stop image capture";
                        _setPhotoStatus(PHOTO_CAPTURE_IDLE);
                    }
                    break;
                case MAV_CMD_REQUEST_CAMERA_CAPTURE_STATUS:
                    if(++_captureInfoRetries < 1) {
                        _captureStatusTimer.start(200);
                    } else {
                        _setPhotoStatus(PHOTO_CAPTURE_IDLE);
                        qCDebug(CodevCameraLog) << "Giving up requesting capture status";
                    }
                    break;
                case MAV_CMD_REQUEST_STORAGE_INFORMATION:
                    if(++_storageInfoRetries < 3) {
                        QTimer::singleShot(500, this, &CodevCameraControl::_requestStorageInfo);
                    } else {
                        qCDebug(CodevCameraLog) << "Giving up requesting storage status";
                    }
                    break;
            }
        } else {
            qCDebug(CodevCameraLog) << "Bad response for" << command << result;
        }
    }
}

void CodevCameraControl::_sendNextQueuedMavCommand()
{
    if (_mavCommandQueue.count()) {
        _mavCommandRetryCount = 0;
        _sendMavCommandAgain();
    }
}

void CodevCameraControl::_requestStreamInfo(uint8_t streamID)
{
    qCDebug(CodevCameraLog) << "Requesting video stream info for:" << streamID;
    if (streamID == 0) {
        // Some Codev firmware builds do not reliably answer the wildcard request.
        // Probe the first two streams directly so EO and thermal are both discovered after restart.
        _expectedCount = qMax(_expectedCount, 2);
        sendMavCommand(
            MAV_CMD_REQUEST_VIDEO_STREAM_INFORMATION,
            1);
        sendMavCommand(
            MAV_CMD_REQUEST_VIDEO_STREAM_INFORMATION,
            2);
        return;
    }
    sendMavCommand(
        MAV_CMD_REQUEST_VIDEO_STREAM_INFORMATION,           // Command id
        streamID);                                          // Stream ID
}

void CodevCameraControl::_requestStreamStatus(uint8_t streamID)
{
    qCDebug(CodevCameraLog) << "Requesting video stream status for:" << streamID;
    sendMavCommand(
        MAV_CMD_REQUEST_VIDEO_STREAM_STATUS,                // Command id
        streamID);                                          // Stream ID
    _streamStatusTimer.start(1000);                         // Wait up to a second for it
}

void CodevCameraControl::_requestCaptureStatus()
{
    qCDebug(CodevCameraLog) << "_requestCaptureStatus()";
    sendMavCommand(
        MAV_CMD_REQUEST_CAMERA_CAPTURE_STATUS,  // command id
        1);                                     // Do Request
}

void CodevCameraControl::_requestCameraSettings()
{
    qCDebug(CodevCameraLog) << "_requestCameraSettings()";
    sendMavCommand(
            MAV_CMD_REQUEST_CAMERA_SETTINGS,        // command id
            1);                                     // Do Request
}

void CodevCameraControl::_requestStorageInfo()
{
    qCDebug(CodevCameraLog) << "_requestStorageInfo()";
    sendMavCommand(
            MAV_CMD_REQUEST_STORAGE_INFORMATION,    // command id
            0,                                      // Storage ID (0 for all, 1 for first, 2 for second, etc.)
            1);                                     // Do Request
}

bool CodevCameraControl::_isTakingPhotoTimelapse()
{
    if (photoMode() == PHOTO_CAPTURE_TIMELAPSE
        && (photoStatus() == PHOTO_CAPTURE_INTERVAL_IDLE || photoStatus() == PHOTO_CAPTURE_INTERVAL_IN_PROGRESS)) {
        return true;
    }
    return false;
}

void CodevCameraControl::buttonTakePhoto()
{
    //-- Do we have storage (in kb) and is camera idle?
    if(photoMode() == PHOTO_CAPTURE_TIMELAPSE && photoStatus() != PHOTO_CAPTURE_IDLE) {
        stopTakePhoto();
        return;
    }
    if(photoMode() == PHOTO_CAPTURE_SINGLE && photoStatus() != PHOTO_CAPTURE_IDLE) {
        return;
    }
    if(storageTotal() == 0 || storageFree() < 50) {
        //-- Undefined camera state
    } else {
        if(cameraMode() == CAM_MODE_VIDEO) {
            //-- Can camera capture images in video mode?
            if(!photosInVideoMode()) {
                //-- Can't take photos while video is being recorded
                if(videoStatus() != VIDEO_CAPTURE_STATUS_STOPPED) {
                } else {
                    setPhotoMode();
                    QTimer::singleShot(2500, this, &CodevCameraControl::takePhoto);
                }
            } else {
                if(videoStatus() == VIDEO_CAPTURE_STATUS_STOPPED) {
                    setPhotoMode();
                }
                if(_isTakingPhotoTimelapse()) {
                    stopTakePhoto();
                } else {
                    takePhoto();
                }
            }
        } else if(cameraMode() == CAM_MODE_PHOTO) {
            if(_isTakingPhotoTimelapse()) {
                stopTakePhoto();
            } else {
                takePhoto();
            }
        } else {
            //-- Undefined camera state
        }
    }
}

void CodevCameraControl::buttonToggleVideo()
{
    if(videoStatus() == VIDEO_CAPTURE_STATUS_RUNNING) {
        toggleVideo();
        return;
    }
    //-- Do we have storage (in kb) and is camera idle?
    if(storageTotal() == 0 || storageFree() < 250) {
        //-- Undefined camera state
    } else {
        //-- If already in video mode, simply toggle on/off
        if(cameraMode() == CAM_MODE_VIDEO) {
            toggleVideo();
        } else {
            //-- Must switch to video mode first
            if(photosInVideoMode()) {
                setVideoMode();
                toggleVideo();
            } else if(photoStatus() == PHOTO_CAPTURE_IDLE) {
                setVideoMode();
                QTimer::singleShot(2500, this, &CodevCameraControl::toggleVideo);
            }
        }
    }
}
