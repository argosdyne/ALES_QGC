#include "QGCApplication.h"
#include "CustomCameraControl.h"
#include "QGCCameraIO.h"
#include "QGCCameraManager.h"
#include "CustomPlugin.h"
#include "VideoManager.h"
#include <tuple>
#include "ParameterManager.h"

QGC_LOGGING_CATEGORY(CustomCameraLog, "CustomCameraLog")
QGC_LOGGING_CATEGORY(CustomCameraVerboseLog, "CustomCameraVerboseLog")

//-----------------------------------------------------------------------------
CustomCameraControl::CustomCameraControl(const mavlink_camera_information_t *info, Vehicle* vehicle, int compID, QObject* parent, LinkInterface* link)
    : VehicleCameraControl(info, vehicle, compID, parent, link)
    , _pMavlink(qgcApp()->toolbox()->mavlinkProtocol())
    , _targetDistance(static_cast<float>(qQNaN()))
{
    _mavCommandAckTimer.setSingleShot(true);
    _mavCommandAckTimer.setInterval(_mavCommandAckTimeoutMSecs);
    connect(&_mavCommandAckTimer, &QTimer::timeout, this, &CustomCameraControl::_sendMavCommandAgain);
    if(_vehicle->parameterManager()->parametersReady()) {
        _vehicleParametersReady(true);
    } else {
        connect(vehicle->parameterManager(), &ParameterManager::parametersReadyChanged, this, &CustomCameraControl::_vehicleParametersReady);
    }

    _cameraSound.setSource(QUrl::fromUserInput("qrc:/audio/camera.wav"));
    _cameraSound.setLoopCount(1);
    _cameraSound.setVolume(0.9);
    connect(this, &CustomCameraControl::playCameraSound, this, [this](int loop) {
        if(_cameraSound.isPlaying()) return;
        _cameraSound.setLoopCount(loop);
        _cameraSound.play();
    });
    _videoSound.setSource(QUrl::fromUserInput("qrc:/audio/beep.wav"));
    _videoSound.setVolume(0.9);
    connect(this, &CustomCameraControl::playVideoSound, this, [this](int loop) {
        if(_videoSound.isPlaying()) return;
        _videoSound.setLoopCount(loop);
        _videoSound.play();
    });
    _errorSound.setSource(QUrl::fromUserInput("qrc:/audio/boop.wav"));
    _errorSound.setVolume(0.9);
    connect(this, &CustomCameraControl::playErrorSound, this, [this](int loop) {
        if(_errorSound.isPlaying()) return;
        _errorSound.setLoopCount(loop);
        _errorSound.play();
    });
}

void CustomCameraControl::_vehicleParametersReady(bool ready)
{
    if(ready) {
        disconnect(_vehicle->parameterManager(), &ParameterManager::parametersReadyChanged, this, &CustomCameraControl::_vehicleParametersReady);
        if(_needSendCaptureAndRecordBystyle()) {
            qCDebug(CustomCameraLog) << "Capture and Start/Stop video recording bystyle.";
            CustomPlugin* plugin = qobject_cast<CustomPlugin*>(qgcApp()->toolbox()->corePlugin());
            connect(plugin->qmlInterface(), &CustomQmlInterface::cameraCapture, this, [this](bool pressed) {
                if(pressed) {
                    _buttonTakePhoto();
                }
            });
            connect(plugin->qmlInterface(), &CustomQmlInterface::cameraToggleRecord, this, [this](bool pressed) {
                if(pressed) {
                    _buttonToggleVideo();
                }
            });
            // connect(plugin, &CustomPlugin::onGimbalResetButtonPressed, this, [this](bool pressed) {
            //     if(pressed) {
            //         _vehicle->sendMavCommand(
            //                 _compID,                                // Target component
            //                 MAV_CMD_DO_MOUNT_CONTROL,           // Command id
            //                 false,
            //                 0,0,0,0,0,0,1);
            //     }
            // });
        }
    }
}

void CustomCameraControl::get_mavlink_camera_info(mavlink_camera_information_t &info)
{
    memcpy(&info, &_info, sizeof(mavlink_camera_information_t));
}

void CustomCameraControl::sendMavCommand(MAV_CMD command, float param1, float param2, float param3, float param4, float param5, float param6, float param7)
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

    _mavCommandQueue.append(entry);

    if (_mavCommandQueue.count() == 1) {
        _mavCommandRetryCount = 0;
        _sendMavCommandAgain();
    }
}

void CustomCameraControl::sendMavCommandWithTarget(MAV_CMD command, int target_component, float param1, float param2, float param3, float param4, float param5, float param6, float param7)
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

    _mavCommandQueue.append(entry);

    if (_mavCommandQueue.count() == 1) {
        _mavCommandRetryCount = 0;
        _sendMavCommandAgain();
    }
}

void CustomCameraControl::_sendMavCommandAgain()
{
    if(!_mavCommandQueue.size()) {
        qWarning(CustomCameraLog) << "Command resend with no commands in queue";
        _mavCommandAckTimer.stop();
        return;
    }

    MavCommandQueueEntry_t& queuedCommand = _mavCommandQueue[0];

    if (_mavCommandRetryCount++ > _mavCommandMaxRetryCount) {
        qCDebug(CustomCameraLog) << "_sendMavCommandAgain sending failed" << queuedCommand.command;
        _mavCommandQueue.removeFirst();
        _sendNextQueuedMavCommand();
        CustomCameraControl::_mavCommandResult(_vehicle->id(), compID(), queuedCommand.command, MAV_RESULT_CANCELLED, true);
        return;
    }

    _mavCommandAckTimer.start();

    qCDebug(CustomCameraLog) << "_sendMavCommandAgain sending" << queuedCommand.command;

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

void CustomCameraControl::_sendNextQueuedMavCommand()
{
    if (_mavCommandQueue.count()) {
        _mavCommandRetryCount = 0;
        _sendMavCommandAgain();
    }
}

void CustomCameraControl::handleGimbalOrientation(const mavlink_mount_orientation_t& o)
{
    _curGimbalRoll = o.roll;
    _curGimbalPitch = o.pitch;
    _curGimbalYaw = o.yaw;
    _curGimbalYawAbsolute = o.yaw_absolute;

    emit gimbalAttitudeChanged();
}

void CustomCameraControl::handleTrackingGeoStatus(const mavlink_camera_tracking_geo_status_t& tracking_geo_status)
{
    qCDebug(CustomCameraLog) << "handleCameraTrackingGeoStatus" << tracking_geo_status.tracking_status << tracking_geo_status.lat << tracking_geo_status.lon;
    if(tracking_geo_status.tracking_status == CAMERA_TRACKING_STATUS_FLAGS_ACTIVE) {
        _targetCoordinate.setAltitude(static_cast<double>(tracking_geo_status.alt));
        _targetCoordinate.setLatitude(static_cast<double>(tracking_geo_status.lat / 1e7));
        _targetCoordinate.setLongitude(static_cast<double>(tracking_geo_status.lon / 1e7));
        emit targetCoordinateChanged(_targetCoordinate);
    } else if(!_targetCoordinate.isValid()) {
        _targetCoordinate = QGeoCoordinate();
        emit targetCoordinateChanged(_targetCoordinate);
    }
    _targetDistance = tracking_geo_status.dist;
    emit targetDistanceChanged(_targetDistance);
}

void CustomCameraControl::handleBrigePing(const mavlink_ping_t& ping)
{
    int channel = ((ping.seq >> 8) & 0xff);
    if(channel > 0) {
        if(_channel_id != channel) {
            for(int i = 0; i < _streams.count(); i++) {
                if(_streams[i]) {
                    QGCVideoStreamInfo* pStream = qobject_cast<QGCVideoStreamInfo*>(_streams[i]);
                    if(pStream) {
                        pStream->enable_localhost(channel != 1);
                    }
                }
            }
            emit _vehicle->cameraManager()->streamChanged();
            _channel_id = channel;
        }
    }
}

void CustomCameraControl::handleRCChannels(const mavlink_rc_channels_t& rc)
{
    static uint16_t rc_zoom_value = 0;
    if(rc_zoom_value != rc.chan11_raw) {
        rc_zoom_value = rc.chan11_raw;
        _requestCameraSettings();
    }
}

void CustomCameraControl::handleCommandAck(const mavlink_command_ack_t& ack)
{
    qCDebug(CustomCameraLog) << QStringLiteral("_handleCommandAck command(%1) result(%2)").arg(ack.command).arg(ack.result);

    if (_mavCommandQueue.count() && ack.command == _mavCommandQueue[0].command) {
        _mavCommandAckTimer.stop();
        _mavCommandQueue.removeFirst();
        _sendNextQueuedMavCommand();
    } else if(ack.result == MAV_RESULT_ACCEPTED) {
        switch(ack.command) {
        case MAV_CMD_VIDEO_START_CAPTURE:
            setCameraModeVideo();
            _setVideoStatus(VIDEO_CAPTURE_STATUS_RUNNING);
            _captureStatusTimer.start(1000);
            break;
        case MAV_CMD_VIDEO_STOP_CAPTURE:
            setCameraModeVideo();
            _setVideoStatus(VIDEO_CAPTURE_STATUS_STOPPED);
            _captureStatusTimer.start(1000);
            break;
        case MAV_CMD_IMAGE_START_CAPTURE:
            if(_video_status != VIDEO_CAPTURE_STATUS_RUNNING) {
                setCameraModePhoto();
            }
            _captureStatusTimer.start(200);
            break;
        }
    }
    CustomCameraControl::_mavCommandResult(_vehicle->id(), compID(), ack.command, ack.result, false);
}

void CustomCameraControl::_buttonTakePhoto()
{
    //-- Do we have storage (in kb) and is camera idle?
    if(photoCaptureMode() == PHOTO_CAPTURE_TIMELAPSE && photoCaptureStatus() != PHOTO_CAPTURE_IDLE) {
        stopTakePhoto();
        return;
    }
    if(photoCaptureMode() == PHOTO_CAPTURE_SINGLE && photoCaptureStatus() != PHOTO_CAPTURE_IDLE) {
        return;
    }
    if(storageTotal() == 0 || storageFree() < 50) {
        //-- Undefined camera state
    } else {
        if(cameraMode() == CAM_MODE_VIDEO) {
            //-- Can camera capture images in video mode?
            if(!photosInVideoMode()) {
                //-- Can't take photos while video is being recorded
                if(videoCaptureStatus() != VIDEO_CAPTURE_STATUS_STOPPED) {
                } else {
                    setCameraModePhoto();
                    QTimer::singleShot(2500, this, &CustomCameraControl::takePhoto);
                }
            } else {
                if(videoCaptureStatus() == VIDEO_CAPTURE_STATUS_STOPPED) {
                    setCameraModePhoto();
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

void CustomCameraControl::_buttonToggleVideo()
{
    if(videoCaptureStatus() == VIDEO_CAPTURE_STATUS_RUNNING) {
        toggleVideoRecording();
        return;
    }
    //-- Do we have storage (in kb) and is camera idle?
    if(storageTotal() == 0 || storageFree() < 250) {
        //-- Undefined camera state
    } else {
        //-- If already in video mode, simply toggle on/off
        if(cameraMode() == CAM_MODE_VIDEO) {
            toggleVideoRecording();
        } else {
            //-- Must switch to video mode first
            if(photosInVideoMode()) {
                setCameraModeVideo();
                toggleVideoRecording();
            } else if(photoCaptureStatus() == PHOTO_CAPTURE_IDLE) {
                setCameraModeVideo();
                QTimer::singleShot(2500, this, &CustomCameraControl::toggleVideoRecording);
            }
        }
    }
}

bool CustomCameraControl::_isTakingPhotoTimelapse()
{
    if (photoCaptureMode() == PHOTO_CAPTURE_TIMELAPSE
        && (photoCaptureStatus() == PHOTO_CAPTURE_INTERVAL_IDLE || photoCaptureStatus() == PHOTO_CAPTURE_INTERVAL_IN_PROGRESS)) {
        return true;
    }
    return false;
}

bool CustomCameraControl::_needSendCaptureAndRecordBystyle()
{
    if(std::tuple(_vehicle->firmwareCustomMajorVersion(), _vehicle->firmwareCustomMajorVersion(), _vehicle->firmwareCustomPatchVersion()) > std::tuple(1, 1, 30)) {
        if(_vehicle->parameterManager()->parameterExists(_vehicle->defaultComponentId(), "SYS_GIMBAL_TYPE")) {
            Fact* fact = _vehicle->parameterManager()->getParameter(_vehicle->defaultComponentId(), "SYS_GIMBAL_TYPE");
            if(fact) return (fact->rawValue().toInt() == 0);
        }
    }
    return false;
}

//-----------------------------------------------------------------------------
void
CustomCameraControl::startTracking(QPointF point, double radius)
{
    qCDebug(CustomCameraLog) << "startTracking Point" << point.x() << point.y() << radius << hasTrackingPoint();
    if(hasTrackingPoint() && _vehicle) {
        sendMavCommand(
            MAV_CMD_CAMERA_TRACK_POINT,             // Command id
            static_cast<float>(point.x()),          // Point X
            static_cast<float>(point.y()),          // Point Y
            static_cast<float>(radius));            // Radius
        sendMavCommand(
            MAV_CMD_SET_MESSAGE_INTERVAL,           // Command id
            MAVLINK_MSG_ID_CAMERA_TRACKING_GEO_STATUS,
            500000);
    }
}

//-----------------------------------------------------------------------------
void
CustomCameraControl::startTracking(QRectF rec)
{
    qCDebug(CustomCameraLog) << "startTracking Rectangle" << rec.x() << rec.y() << (rec.x() + rec.width()) << (rec.y() + rec.height()) << hasTrackingRectangle();
    if(hasTrackingRectangle() && _vehicle) {
        sendMavCommand(
            MAV_CMD_CAMERA_TRACK_RECTANGLE,               // Command id
            static_cast<float>(rec.x()),                  // Point1 X
            static_cast<float>(rec.y()),                  // Point1 Y
            static_cast<float>(rec.x() + rec.width()),    // Point2 X
            static_cast<float>(rec.y() + rec.height()));  // Point2 Y
        sendMavCommand(
            MAV_CMD_SET_MESSAGE_INTERVAL,           // Command id
            MAVLINK_MSG_ID_CAMERA_TRACKING_GEO_STATUS,
            500000);
    }
}

//-----------------------------------------------------------------------------
void
CustomCameraControl::stopTracking()
{
    qCDebug(CustomCameraLog) << "stopTracking";
    if((hasTrackingPoint() || hasTrackingRectangle()) && _vehicle) {
        sendMavCommand(MAV_CMD_CAMERA_STOP_TRACKING);
        sendMavCommand(
            MAV_CMD_SET_MESSAGE_INTERVAL,           // Command id
            MAVLINK_MSG_ID_CAMERA_TRACKING_GEO_STATUS,
            -1);
    }
}

//-----------------------------------------------------------------------------
void
CustomCameraControl::centerGimbal()
{
    sendMavCommandWithTarget(
        MAV_CMD_DO_MOUNT_CONTROL,           // Command id
        MAV_COMP_ID_GIMBAL,                 // Target id
        0,0,0,0,0,0,1);
}

//-----------------------------------------------------------------------------
void
CustomCameraControl::resetSettings()
{
    static Fact* gridLines = qgcApp()->toolbox()->settingsManager()->videoSettings()->gridLines();
    if(gridLines->metaData()->defaultValueAvailable())
        gridLines->setRawValue(gridLines->metaData()->rawDefaultValue());
    setThermalMode(THERMAL_BLEND);
    setThermalOpacity(85);
    VehicleCameraControl::setPhotoCaptureMode(PHOTO_CAPTURE_SINGLE);
    setPhotoLapse(5.0);
    setPhotoLapseCount(0);
    if(!_resetting) {
        qCDebug(CustomCameraLog) << "resetSettings()";
        _resetting = true;
        sendMavCommand(
            MAV_CMD_RESET_CAMERA_SETTINGS,          // Command id
            1);                                     // Do Reset
    }
}

//-----------------------------------------------------------------------------
void
CustomCameraControl::formatCard(int id)
{
    if(!_resetting) {
        qCDebug(CustomCameraLog) << "formatCard()";
        sendMavCommand(
            MAV_CMD_STORAGE_FORMAT,                 // Command id
            id,                                     // Storage ID (1 for first, 2 for second, etc.)
            1);                                     // Do Format
    }
}

//-----------------------------------------------------------------------------
void
CustomCameraControl::setCameraModeVideo()
{
    if(!_resetting && hasModes()) {
        qCDebug(CustomCameraLog) << "setVideoMode()";
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

//-----------------------------------------------------------------------------
void
CustomCameraControl::setCameraModePhoto()
{
    if(!_resetting && hasModes()) {
        qCDebug(CustomCameraLog) << "setPhotoMode()";
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

void CustomCameraControl::_setCameraMode(CameraMode mode)
{
    if(_cameraMode != mode) {
        _cameraMode = mode;
        emit cameraModeChanged();
        //-- Update stream status
        _streamStatusTimer.start(1000);
        emit storageFreeChanged();
    }
}

//-----------------------------------------------------------------------------
void
CustomCameraControl::startZoom(int direction)
{
    qCDebug(CustomCameraLog) << "startZoom()" << direction;
    if(hasZoom()) {
        sendMavCommand(
            MAV_CMD_SET_CAMERA_ZOOM,                // Command id
            ZOOM_TYPE_CONTINUOUS,                   // Zoom type
            direction);                             // Direction (-1 wide, 1 tele)
    }
}

//-----------------------------------------------------------------------------
void
CustomCameraControl::stopZoom()
{
    qCDebug(CustomCameraLog) << "stopZoom()";
    if(hasZoom()) {
        sendMavCommand(
            MAV_CMD_SET_CAMERA_ZOOM,                // Command id
            ZOOM_TYPE_CONTINUOUS,                   // Zoom type
            0);                                     // Direction (-1 wide, 1 tele)
    }
}

//-----------------------------------------------------------------------------
void
CustomCameraControl::setZoomLevel(qreal level)
{
    qCDebug(CustomCameraLog) << "setZoomLevel()" << level;
    if(hasZoom()) {
        //-- Limit
        level = std::min(std::max(level, 0.0), 100.0);
        sendMavCommand(
            MAV_CMD_SET_CAMERA_ZOOM,                // Command id
            ZOOM_TYPE_RANGE,                        // Zoom type
            static_cast<float>(level));             // Level
    }
}

//-----------------------------------------------------------------------------
void
CustomCameraControl::handleVideoInfo(const mavlink_video_stream_information_t* vi)
{
    bool isNewStream = false;
    qCDebug(CustomCameraLog) << "handleVideoInfo:" << vi->stream_id << vi->uri;
    _expectedCount = vi->count;
    if(!_findStream(vi->stream_id, false)) {
        isNewStream = true;
        qCDebug(CustomCameraLog) << "Create stream handler for stream ID:" << vi->stream_id;
        QGCVideoStreamInfo* pStream = new QGCVideoStreamInfo(this, vi);
        pStream->enable_localhost(_channel_id > 1);
        QQmlEngine::setObjectOwnership(pStream, QQmlEngine::CppOwnership);
        _streams.append(pStream);
        //-- Thermal is handled separately and not listed
        if(!pStream->isThermal()) {
            _streamLabels.append(pStream->name());
            emit streamsChanged();
            emit streamLabelsChanged();
        } else {
            emit thermalStreamChanged();
        }
    }
    //-- Check for missing count
    if(_streams.count() < _expectedCount) {
        _streamInfoTimer.start(1000);
    } else {
        //-- Done
        qCDebug(CustomCameraLog) << "All stream handlers done";
        _streamInfoTimer.stop();
        if(isNewStream) {
            emit autoStreamChanged();
            emit _vehicle->cameraManager()->streamChanged();
        }
    }
}

//-----------------------------------------------------------------------------
QString
CustomCameraControl::storageFreeStr()
{
    for(int i = 0; i < _storageInfos.count(); i++) {
        auto storage = _storageInfos.value<CustomStorageInfo*>(i);
        if(_cameraMode == CAM_MODE_PHOTO && (storage->usage() & STORAGE_USAGE_FLAG_PHOTO)) {
            return storage->available_capacity(_cameraMode);
        } else if(_cameraMode == CAM_MODE_VIDEO && (storage->usage() & STORAGE_USAGE_FLAG_VIDEO)) {
            return storage->available_capacity(_cameraMode);
        }
    }
    return VehicleCameraControl::storageFreeStr();
}

//-----------------------------------------------------------------------------
void
CustomCameraControl::handleStorageInfo(const mavlink_storage_information_t& st)
{
    if(_storageInfos.count() == (st.storage_id - 1)) {
        _storageInfos.append(new CustomStorageInfo(st, &_storageInfos));
    } else if(st.storage_id > 0 && st.storage_id <= _storageInfos.count()) {
        _storageInfos.value<CustomStorageInfo*>(st.storage_id - 1)->update(st);
    }
    if(!(st.storage_usage & STORAGE_USAGE_FLAG_SET)) {
        VehicleCameraControl::handleStorageInfo(st);
    } else if(_cameraMode == CAM_MODE_PHOTO && (st.storage_usage & STORAGE_USAGE_FLAG_PHOTO)) {
        VehicleCameraControl::handleStorageInfo(st);
    } else if(_cameraMode == CAM_MODE_VIDEO && (st.storage_usage & STORAGE_USAGE_FLAG_VIDEO)) {
        VehicleCameraControl::handleStorageInfo(st);
    } else {
        bool updated = false;
        for(int i = 0; i < _storageInfos.count(); i++) {
            auto storage = _storageInfos.value<CustomStorageInfo*>(i);
            if(_cameraMode == CAM_MODE_PHOTO && (storage->usage() & STORAGE_USAGE_FLAG_PHOTO)) {
                VehicleCameraControl::handleStorageInfo(storage->get_storage_info());
                updated = true;
                break;
            } else if(_cameraMode == CAM_MODE_VIDEO && (storage->usage() & STORAGE_USAGE_FLAG_VIDEO)) {
                VehicleCameraControl::handleStorageInfo(storage->get_storage_info());
                updated = true;
                break;
            }
        }
        if(!updated) {
            VehicleCameraControl::handleStorageInfo(st);
        }
    }
}

//-----------------------------------------------------------------------------
void
CustomCameraControl::_mavCommandResult(int vehicleId, int component, int command, int result, bool noReponseFromVehicle)
{
    //-- Is this ours?
    if(_vehicle->id() != vehicleId || compID() != component) {
        return;
    }
    if(!noReponseFromVehicle && result == MAV_RESULT_IN_PROGRESS) {
        //-- Do Nothing
        qCDebug(CustomCameraLog) << "In progress response for" << command;
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
                QTimer::singleShot(2000, this, &CustomCameraControl::_requestAllParameters);
                QTimer::singleShot(2500, this, &CustomCameraControl::_requestCameraSettings);
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
                qCDebug(CustomCameraLog) << "No response for" << command;
            } else if (result == MAV_RESULT_TEMPORARILY_REJECTED) {
                qCDebug(CustomCameraLog) << "Command temporarily rejected for" << command;
            } else {
                qCDebug(CustomCameraLog) << "Command failed for" << command;
            }
            switch(command) {
            case MAV_CMD_IMAGE_START_CAPTURE:
            case MAV_CMD_IMAGE_STOP_CAPTURE:
                if(++_captureInfoRetries < 1) {
                    _captureStatusTimer.start(1000);
                } else {
                    qCDebug(CustomCameraLog) << "Giving up start/stop image capture";
                    _setPhotoStatus(PHOTO_CAPTURE_IDLE);
                }
                break;
            case MAV_CMD_REQUEST_CAMERA_CAPTURE_STATUS:
                if(++_captureInfoRetries < 1) {
                    _captureStatusTimer.start(200);
                } else {
                    _setPhotoStatus(PHOTO_CAPTURE_IDLE);
                    qCDebug(CustomCameraLog) << "Giving up requesting capture status";
                }
                break;
            case MAV_CMD_REQUEST_STORAGE_INFORMATION:
                if(++_storageInfoRetries < 3) {
                    QTimer::singleShot(500, this, &CustomCameraControl::_requestStorageInfo);
                } else {
                    qCDebug(CustomCameraLog) << "Giving up requesting storage status";
                }
                break;
            }
        } else {
            qCDebug(CustomCameraLog) << "Bad response for" << command << result;
        }
    }
}

bool CustomCameraControl::takePhoto()
{
    qCDebug(CustomCameraLog) << "takePhoto()";
    //-- Check if camera can capture photos or if it can capture it while in Video Mode
    if(!capturesPhotos()) {
        qCWarning(CustomCameraLog) << "Camera does not handle image capture";
        return false;
    }
    if(cameraMode() == CAM_MODE_VIDEO && !photosInVideoMode()) {
        qCWarning(CustomCameraLog) << "Camera does not handle image capture while in video mode";
        return false;
    }
    if(photoCaptureStatus() != PHOTO_CAPTURE_IDLE) {
        qCWarning(CustomCameraLog) << "Camera not idle";
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

bool CustomCameraControl::stopTakePhoto()
{
    if(!_resetting) {
        qCDebug(CustomCameraLog) << "stopTakePhoto()";
        if(photoCaptureStatus() == PHOTO_CAPTURE_IDLE || (photoCaptureStatus() != PHOTO_CAPTURE_INTERVAL_IDLE && photoCaptureStatus() != PHOTO_CAPTURE_INTERVAL_IN_PROGRESS)) {
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

bool CustomCameraControl::startVideoRecording()
{
    if(!_resetting) {
        qCDebug(CustomCameraLog) << "startVideo()";
        //-- Check if camera can capture videos or if it can capture it while in Photo Mode
        if(!capturesVideo() || (cameraMode() == CAM_MODE_PHOTO && !videoInPhotoMode())) {
            return false;
        }
        if(videoCaptureStatus() != VIDEO_CAPTURE_STATUS_RUNNING) {
            sendMavCommand(
                MAV_CMD_VIDEO_START_CAPTURE,                // Command id
                0,                                          // Reserved (Set to 0)
                0);                                         // CAMERA_CAPTURE_STATUS Frequency
            return true;
        }
    }
    return false;
}

bool CustomCameraControl::stopVideoRecording()
{
    if(!_resetting) {
        qCDebug(CustomCameraLog) << "stopVideo()";
        if(videoCaptureStatus() == VIDEO_CAPTURE_STATUS_RUNNING) {
            sendMavCommand(
                MAV_CMD_VIDEO_STOP_CAPTURE,                 // Command id
                0);                                         // Reserved (Set to 0)
            return true;
        }
    }
    return false;
}

void CustomCameraControl::_requestStreamInfo(uint8_t streamID)
{
    qCDebug(CustomCameraLog) << "Requesting video stream info for:" << streamID;
    sendMavCommand(
        MAV_CMD_REQUEST_VIDEO_STREAM_INFORMATION,           // Command id
        streamID);                                          // Stream ID
}

void CustomCameraControl::_requestStreamStatus(uint8_t streamID)
{
    qCDebug(CustomCameraLog) << "Requesting video stream status for:" << streamID;
    sendMavCommand(
        MAV_CMD_REQUEST_VIDEO_STREAM_STATUS,                // Command id
        streamID);                                          // Stream ID
    _streamStatusTimer.start(1000);                         // Wait up to a second for it
}

void CustomCameraControl::_requestCaptureStatus()
{
    qCDebug(CustomCameraLog) << "_requestCaptureStatus()";
    sendMavCommand(
        MAV_CMD_REQUEST_CAMERA_CAPTURE_STATUS,  // command id
        1);                                     // Do Request
}

void CustomCameraControl::_requestCameraSettings()
{
    qCDebug(CustomCameraLog) << "_requestCameraSettings()";
    sendMavCommand(
        MAV_CMD_REQUEST_CAMERA_SETTINGS,        // command id
        1);                                     // Do Request
}

void CustomCameraControl::_requestStorageInfo()
{
    qCDebug(CustomCameraLog) << "_requestStorageInfo()";
    sendMavCommand(
        MAV_CMD_REQUEST_STORAGE_INFORMATION,    // command id
        0,                                      // Storage ID (0 for all, 1 for first, 2 for second, etc.)
        1);                                     // Do Request
}
