#include "CodevCameraControl.h"
#include "QGCApplication.h"
#include "QGCCameraIO.h"
#include "VideoManager.h"

static constexpr int kModeSwitchGraceMs = 8000;
static constexpr int kStorageRefreshInitialDelayMs = 800;
static constexpr int kPhotoAfterModeSwitchDelayMs = 2000;

void CodevCameraControl::_requestAllStoragePools()
{
    if (!_vehicle) {
        return;
    }
    _vehicle->sendMavCommand(
        _compID,
        MAV_CMD_REQUEST_MESSAGE,
        false,
        MAVLINK_MSG_ID_STORAGE_INFORMATION,
        0);
    for (int storageId = 1; storageId <= 2; storageId++) {
        QTimer::singleShot(300 * storageId, this, [this, storageId]() {
            if (_vehicle) {
                _vehicle->sendMavCommand(
                    _compID,
                    MAV_CMD_REQUEST_STORAGE_INFORMATION,
                    false,
                    static_cast<float>(storageId),
                    1);
            }
        });
    }
    QTimer::singleShot(900, this, [this]() {
        if (_vehicle) {
            _vehicle->sendMavCommand(
                _compID,
                MAV_CMD_REQUEST_CAMERA_CAPTURE_STATUS,
                false,
                1);
        }
    });
}

void CodevCameraControl::_refreshStorageAndCaptureStatus()
{
    _requestAllStoragePools();
}

void CodevCameraControl::_scheduleStorageRefreshAfterModeSwitch()
{
    _storageRefreshAttempts = 0;
    _storageRefreshTimer.stop();
    _storageRefreshTimer.start(kStorageRefreshInitialDelayMs);
}

void CodevCameraControl::_stopStorageRefreshAfterModeSwitch()
{
    _storageRefreshTimer.stop();
    _storageRefreshAttempts = 0;
}

bool CodevCameraControl::_hasModeStoragePool(CameraMode mode)
{
    const uint8_t usageFlag = (mode == CAM_MODE_PHOTO) ? STORAGE_USAGE_FLAG_PHOTO : STORAGE_USAGE_FLAG_VIDEO;
    for (int i = 0; i < _storageInfos.count(); i++) {
        const auto* storage = _storageInfos.value<CodevStorageInfo*>(i);
        if (storage && (storage->usage() & usageFlag)) {
            return true;
        }
    }
    return false;
}

bool CodevCameraControl::_isCurrentModeStorageReady()
{
    const uint8_t usageFlag = (cameraMode() == CAM_MODE_PHOTO) ? STORAGE_USAGE_FLAG_PHOTO : STORAGE_USAGE_FLAG_VIDEO;
    for (int i = 0; i < _storageInfos.count(); i++) {
        const auto* storage = _storageInfos.value<CodevStorageInfo*>(i);
        if (storage && (storage->usage() & usageFlag) && storage->storageInfo().available_capacity > 0) {
            return true;
        }
    }
    return _storageFree >= 50;
}

bool CodevCameraControl::_syncCurrentModePoolFromCaptureStatus(float availableCapacity)
{
    if (availableCapacity <= 0) {
        return false;
    }

    const uint8_t usageFlag = (cameraMode() == CAM_MODE_PHOTO) ? STORAGE_USAGE_FLAG_PHOTO
                            : (cameraMode() == CAM_MODE_VIDEO) ? STORAGE_USAGE_FLAG_VIDEO
                            : 0;
    if (!usageFlag) {
        return false;
    }

    for (int i = 0; i < _storageInfos.count(); i++) {
        auto* storage = _storageInfos.value<CodevStorageInfo*>(i);
        if (!storage || !(storage->usage() & usageFlag)) {
            continue;
        }
        mavlink_storage_information_t st = storage->storageInfo();
        if (st.available_capacity == availableCapacity) {
            return false;
        }
        st.available_capacity = availableCapacity;
        if (st.status != STORAGE_STATUS_READY) {
            st.status = STORAGE_STATUS_READY;
        }
        storage->update(st);
        return true;
    }
    return false;
}

bool CodevCameraControl::_hasKnownInsufficientPhotoStorage() const
{
    if (_storageFree == 0) {
        return false;
    }
    return _storageFree < 50;
}

bool CodevCameraControl::_hasKnownInsufficientVideoStorage() const
{
    if (_storageFree == 0) {
        return false;
    }
    return _storageFree < 250;
}

bool CodevCameraControl::_isModeSwitchSettling() const
{
    return _modeSwitchPending
            || (_modeSwitchGraceTimer.isValid() && _modeSwitchGraceTimer.elapsed() < kModeSwitchGraceMs);
}

void CodevCameraControl::_sendModeSwitchToCamera(CameraMode targetMode)
{
    Fact* pMode = mode();
    if (pMode) {
        pMode->setRawValue(targetMode);
    } else {
        sendMavCommand(
            MAV_CMD_SET_CAMERA_MODE,
            0,
            targetMode);
    }
    _pendingCameraMode = targetMode;
}

void CodevCameraControl::_forceModeSwitchToCamera(CameraMode targetMode)
{
    qCDebug(CodevCameraLog) << "Force mode switch to camera"
                            << targetMode
                            << "reported" << _lastReportedCameraMode
                            << "uiMode" << cameraMode();
    sendMavCommand(
        MAV_CMD_SET_CAMERA_MODE,
        0,
        targetMode);
    Fact* pMode = mode();
    if (pMode) {
        if (_paramIO.contains(kCAM_MODE) && _paramIO[kCAM_MODE]) {
            if (pMode->rawValue().toInt() == static_cast<int>(targetMode)) {
                _paramIO[kCAM_MODE]->sendParameter();
            } else {
                pMode->setRawValue(targetMode);
            }
        } else {
            pMode->setRawValue(targetMode);
        }
    }
    _pendingCameraMode = targetMode;
}

void CodevCameraControl::_scheduleVideoPipelineRestart(const char* reason)
{
    qCDebug(CodevCameraLog) << "Schedule video pipeline restart" << reason;
    _videoPipelineRestartTimer.start();
}

void CodevCameraControl::_restartVideoPipeline()
{
    if (videoStatus() == VIDEO_CAPTURE_STATUS_RUNNING) {
        return;
    }

    VideoManager* videoManager = qgcApp()->toolbox()->videoManager();
    if (!videoManager || !videoManager->hasVideo()) {
        return;
    }
    if (videoManager->recording()) {
        return;
    }

    qCDebug(CodevCameraLog) << "Restarting video pipeline (RTSP/GStreamer reset)";
    videoManager->restartVideo(0);
}

void CodevCameraControl::_armModeSwitchRecovery(CameraMode targetMode)
{
    if (videoStatus() == VIDEO_CAPTURE_STATUS_RUNNING) {
        return;
    }

    VideoManager* videoManager = qgcApp()->toolbox()->videoManager();
    _modeSwitchRecoveryTarget = targetMode;
    _modeSwitchRecoveryActive = true;
    _modeSwitchRecoveryRetried = false;
    _decodingDroppedDuringRecovery = false;
    _modeSwitchNudgeInProgress = false;
    _modeSwitchNudgeReturnTimer.stop();
    _modeSwitchRecoveryTimer.start();
    _modeSwitchProactiveRetryTimer.start();
    _decodingAtRecoveryArm = videoManager ? videoManager->decoding() : false;
    qCDebug(CodevCameraLog) << "Armed mode switch recovery for mode" << targetMode
                            << "decodingAtArm" << _decodingAtRecoveryArm;
}

void CodevCameraControl::_disarmModeSwitchRecovery()
{
    _modeSwitchRecoveryActive = false;
    _modeSwitchRecoveryTarget = CAM_MODE_UNDEFINED;
    _modeSwitchNudgeInProgress = false;
    _modeSwitchRecoveryTimer.stop();
    _modeSwitchProactiveRetryTimer.stop();
    _modeSwitchNudgeReturnTimer.stop();
}

void CodevCameraControl::_executeModeSwitchNudge(const char* reason)
{
    if (_modeSwitchRecoveryTarget != CAM_MODE_PHOTO
            && _modeSwitchRecoveryTarget != CAM_MODE_VIDEO) {
        return;
    }

    const CameraMode targetMode = _modeSwitchRecoveryTarget;
    const CameraMode reportedMode = _lastReportedCameraMode;
    const CameraMode oppositeOfTarget = (targetMode == CAM_MODE_VIDEO) ? CAM_MODE_PHOTO : CAM_MODE_VIDEO;

    _modeSwitchNudgeReturnTimer.stop();

    if (reportedMode == CAM_MODE_PHOTO || reportedMode == CAM_MODE_VIDEO) {
        if (reportedMode != targetMode) {
            qCDebug(CodevCameraLog) << "Mode switch catch-up"
                                    << "reason" << reason
                                    << "reported" << reportedMode
                                    << "target" << targetMode;
            _forceModeSwitchToCamera(targetMode);
            _setCameraMode(targetMode);
            _scheduleVideoPipelineRestart("mode_catch_up");
            return;
        }
    }

    _modeSwitchNudgeInProgress = true;
    qCDebug(CodevCameraLog) << "Mode switch nudge"
                            << "reason" << reason
                            << "target" << targetMode
                            << "reported" << reportedMode
                            << "via" << oppositeOfTarget;
    _forceModeSwitchToCamera(oppositeOfTarget);
    _modeSwitchNudgeReturnTimer.start();
}

void CodevCameraControl::_onModeSwitchNudgeReturn()
{
    if (!_modeSwitchNudgeInProgress) {
        return;
    }
    if (_modeSwitchRecoveryTarget != CAM_MODE_PHOTO
            && _modeSwitchRecoveryTarget != CAM_MODE_VIDEO) {
        _modeSwitchNudgeInProgress = false;
        return;
    }

    const CameraMode targetMode = _modeSwitchRecoveryTarget;
    qCDebug(CodevCameraLog) << "Mode switch nudge return to" << targetMode;
    _forceModeSwitchToCamera(targetMode);
    _setCameraMode(targetMode);
    _modeSwitchNudgeInProgress = false;
    _scheduleVideoPipelineRestart("mode_nudge");
    _disarmModeSwitchRecovery();
}

void CodevCameraControl::_retryModeSwitchRecovery(const char* reason)
{
    if (!_modeSwitchRecoveryActive || _modeSwitchRecoveryRetried) {
        return;
    }
    if (videoStatus() == VIDEO_CAPTURE_STATUS_RUNNING) {
        _disarmModeSwitchRecovery();
        return;
    }

    _modeSwitchRecoveryRetried = true;
    _executeModeSwitchNudge(reason);
}

void CodevCameraControl::_checkModeSwitchRecovery()
{
    if (_modeSwitchRecoveryActive && !_modeSwitchRecoveryRetried && !_modeSwitchNudgeInProgress) {
        VideoManager* videoManager = qgcApp()->toolbox()->videoManager();
        const bool decoding = videoManager ? videoManager->decoding() : false;
        const bool modeMismatch = cameraMode() != _modeSwitchRecoveryTarget;
        if (!decoding || modeMismatch) {
            _retryModeSwitchRecovery(modeMismatch ? "mode_mismatch_timeout" : "decoding_lost_timeout");
        }
    }
    if (!_modeSwitchNudgeInProgress) {
        _disarmModeSwitchRecovery();
    }
}

void CodevCameraControl::_onProactiveModeRetry()
{
    if (!_modeSwitchRecoveryActive || _modeSwitchRecoveryRetried) {
        return;
    }
    if (videoStatus() == VIDEO_CAPTURE_STATUS_RUNNING) {
        _disarmModeSwitchRecovery();
        return;
    }
    if (cameraMode() != _modeSwitchRecoveryTarget) {
        _retryModeSwitchRecovery("proactive_mode_mismatch");
        return;
    }

    VideoManager* videoManager = qgcApp()->toolbox()->videoManager();
    const bool decoding = videoManager ? videoManager->decoding() : false;
    if (!decoding || _decodingDroppedDuringRecovery) {
        _retryModeSwitchRecovery("proactive_unstable");
        return;
    }

    qCDebug(CodevCameraLog) << "Mode switch stable at proactive check, disarming recovery";
    _disarmModeSwitchRecovery();
}

void CodevCameraControl::_onVideoDecodingChanged()
{
    if (!_modeSwitchRecoveryActive || _modeSwitchRecoveryRetried) {
        return;
    }
    if (videoStatus() == VIDEO_CAPTURE_STATUS_RUNNING) {
        _disarmModeSwitchRecovery();
        return;
    }

    VideoManager* videoManager = qgcApp()->toolbox()->videoManager();
    if (!videoManager) {
        return;
    }
    if (videoManager->decoding()) {
        return;
    }

    _decodingDroppedDuringRecovery = true;
    if (_decodingAtRecoveryArm) {
        _retryModeSwitchRecovery("decoding_lost");
    }
}

void CodevCameraControl::_scheduleCoalescedModeSwitch(CameraMode targetMode)
{
    _coalescedModeTarget = targetMode;
    if (_pendingRcAction != PendingRcAction::None) {
        _modeSwitchCommandTimer.stop();
        _sendModeSwitchToCamera(targetMode);
        _coalescedModeTarget = CAM_MODE_UNDEFINED;
        return;
    }
    _modeSwitchCommandTimer.start();
}

void CodevCameraControl::_flushCoalescedModeSwitch()
{
    if (_coalescedModeTarget == CAM_MODE_UNDEFINED) {
        return;
    }
    const CameraMode targetMode = _coalescedModeTarget;
    _coalescedModeTarget = CAM_MODE_UNDEFINED;
    if (cameraMode() != targetMode) {
        return;
    }
    _sendModeSwitchToCamera(targetMode);
}

void CodevCameraControl::_beginModeSwitch(CameraMode targetMode)
{
    _pendingCameraMode = targetMode;
    _markUserModeIntent(targetMode);
    _modeSwitchPending = true;
    _modeSwitchTimer.start();
    _modeSwitchDebounce.start();
    _modeSwitchGraceTimer.start();
}

void CodevCameraControl::_startPendingRcAction(PendingRcAction action)
{
    _rcActionFallbackTimer.stop();
    _pendingRcAction = action;
    _rcActionFallbackTimer.start();
}

void CodevCameraControl::_cancelPendingRcAction()
{
    _rcActionFallbackTimer.stop();
    _pendingRcAction = PendingRcAction::None;
}

void CodevCameraControl::_completePendingRcAction()
{
    _rcActionFallbackTimer.stop();
    const PendingRcAction action = _pendingRcAction;
    _pendingRcAction = PendingRcAction::None;

    switch (action) {
    case PendingRcAction::TakePhoto:
        if (cameraMode() != CAM_MODE_PHOTO) {
            return;
        }
        _refreshStorageAndCaptureStatus();
        QTimer::singleShot(kPhotoAfterModeSwitchDelayMs, this, [this]() {
            if (cameraMode() == CAM_MODE_PHOTO && photoStatus() == PHOTO_CAPTURE_IDLE) {
                takePhoto();
            }
        });
        break;
    case PendingRcAction::ToggleVideo:
        if (cameraMode() != CAM_MODE_VIDEO) {
            return;
        }
        toggleVideo();
        break;
    case PendingRcAction::None:
        break;
    }
}

void CodevCameraControl::_setCameraMode(CameraMode mode)
{
    const CameraMode prevMode = _cameraMode;
    QGCCameraControl::_setCameraMode(mode);
    if (prevMode != mode) {
        _applyStorageForCurrentMode();
        emit storageFreeChanged();
        emit storageTotalChanged();
        if (mode == CAM_MODE_PHOTO || mode == CAM_MODE_VIDEO) {
            _scheduleStorageRefreshAfterModeSwitch();
        }
    }
}

void CodevCameraControl::_applyStorageInfoToDisplay(const mavlink_storage_information_t& st)
{
    mavlink_storage_information_t sanitized = st;
    if (static_cast<uint32_t>(sanitized.total_capacity) == UINT32_MAX) {
        sanitized.total_capacity = 0;
    }
    QGCCameraControl::handleStorageInfo(sanitized);
}

void CodevCameraControl::_applyStorageForCurrentMode()
{
    for (int i = 0; i < _storageInfos.count(); i++) {
        auto* storage = _storageInfos.value<CodevStorageInfo*>(i);
        if (!storage) {
            continue;
        }
        if (cameraMode() == CAM_MODE_PHOTO && (storage->usage() & STORAGE_USAGE_FLAG_PHOTO)) {
            _applyStorageInfoToDisplay(storage->storageInfo());
            return;
        }
        if (cameraMode() == CAM_MODE_VIDEO && (storage->usage() & STORAGE_USAGE_FLAG_VIDEO)) {
            _applyStorageInfoToDisplay(storage->storageInfo());
            return;
        }
    }
}

QString CodevCameraControl::storageFreeStr()
{
    for (int i = 0; i < _storageInfos.count(); i++) {
        auto* storage = _storageInfos.value<CodevStorageInfo*>(i);
        if (!storage) {
            continue;
        }
        if (cameraMode() == CAM_MODE_PHOTO && (storage->usage() & STORAGE_USAGE_FLAG_PHOTO)) {
            return storage->availableCapacityStr(CAM_MODE_PHOTO);
        }
        if (cameraMode() == CAM_MODE_VIDEO && (storage->usage() & STORAGE_USAGE_FLAG_VIDEO)) {
            return storage->availableCapacityStr(CAM_MODE_VIDEO);
        }
    }
    return QGCCameraControl::storageFreeStr();
}

void CodevCameraControl::handleStorageInfo(const mavlink_storage_information_t& st)
{
    qCDebug(CodevCameraLog) << "handleStorageInfo:"
                            << "storage_id" << st.storage_id
                            << "storage_usage" << st.storage_usage
                            << "available" << st.available_capacity
                            << "total" << st.total_capacity
                            << "status" << st.status;

    if (_storageInfos.count() == static_cast<int>(st.storage_id - 1)) {
        _storageInfos.append(new CodevStorageInfo(st, this));
    } else if (st.storage_id > 0 && st.storage_id <= static_cast<uint8_t>(_storageInfos.count())) {
        _storageInfos.value<CodevStorageInfo*>(st.storage_id - 1)->update(st);
    }

    if (!(st.storage_usage & STORAGE_USAGE_FLAG_SET)) {
        _applyStorageInfoToDisplay(st);
    } else if (cameraMode() == CAM_MODE_PHOTO && (st.storage_usage & STORAGE_USAGE_FLAG_PHOTO)) {
        _applyStorageInfoToDisplay(st);
    } else if (cameraMode() == CAM_MODE_VIDEO && (st.storage_usage & STORAGE_USAGE_FLAG_VIDEO)) {
        _applyStorageInfoToDisplay(st);
    } else {
        _applyStorageForCurrentMode();
    }

    if (st.status == STORAGE_STATUS_READY
            && st.available_capacity > 0
            && ((cameraMode() == CAM_MODE_PHOTO && (st.storage_usage & STORAGE_USAGE_FLAG_PHOTO))
                || (cameraMode() == CAM_MODE_VIDEO && (st.storage_usage & STORAGE_USAGE_FLAG_VIDEO))
                || !(st.storage_usage & STORAGE_USAGE_FLAG_SET))) {
        _stopStorageRefreshAfterModeSwitch();
    }
    emit storageFreeChanged();
}
