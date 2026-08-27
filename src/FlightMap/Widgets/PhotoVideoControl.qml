/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick                  2.11
import QtPositioning            5.2
import QtQuick.Layouts          1.2
import QtQuick.Controls         1.4
import QtQuick.Dialogs          1.2
import QtGraphicalEffects       1.0
import QtQuick.Window           2.11

import QGroundControl                   1.0
import QGroundControl.ScreenTools       1.0
import QGroundControl.Controls          1.0
import QGroundControl.Palette           1.0
import QGroundControl.Payload           1.0
import QGroundControl.Vehicle           1.0
import QGroundControl.Controllers       1.0
import QGroundControl.FactSystem        1.0
import QGroundControl.FactControls      1.0
import QGroundControl.FlightDisplay     1.0
import QGroundControl.FlightMap         1.0



Item {    
    implicitHeight: content.implicitHeight    
    visible:    (_mavlinkCamera || _videoStreamAvailable || _simpleCameraAvailable) && multiVehiclePanelSelector.showSingleVehiclePanel
    property real   _margins:                                   ScreenTools.defaultFontPixelHeight / 2
    property var    _activeVehicle:                             QGroundControl.multiVehicleManager.activeVehicle
    property var    _activePayload:                             PayloadManager.active
    property bool   _usePayload:                                _activePayload && _activePayload.connected
    property bool   _payloadRecording:                          false
    property bool   _isGremsyPayload:                           _usePayload && PayloadManager.activeType === 0 && PayloadManager.gremsy
    property bool   _payloadRecordingEffective:                 _isGremsyPayload
                                                                    ? PayloadManager.gremsy.recording
                                                                    : _payloadRecording
    property bool   _gremsyPhotoFeedback:                       false
    property bool   _nextVisionPhotoFeedback:                   false
    property int    _gremsyRecordingSeconds:                    0
    property double _gremsyRecordingStartedMs:                  0
    property bool   _gremsyCaptureButtonActive:                 _isGremsyPayload && (_gremsyPhotoFeedback || _payloadRecordingEffective)
    property bool   _captureButtonActive:                       _isShootingInCurrentMode || _gremsyCaptureButtonActive || (_isNextVisionPayload && _nextVisionPhotoFeedback)

    function _centerGimbal() {
        if (_activePayload) {
            _activePayload.gimbalHome()
        } else if (_mavlinkCamera) {
            _mavlinkCamera.centerGimbal()
        }
    }

    function _formatElapsedTime(totalSeconds) {
        var hours = Math.floor(totalSeconds / 3600)
        var minutes = Math.floor((totalSeconds % 3600) / 60)
        var seconds = totalSeconds % 60
        function pad(value) { return value < 10 ? "0" + value : String(value) }
        return pad(hours) + ":" + pad(minutes) + ":" + pad(seconds)
    }

    function _syncGremsyRecordingUi() {
        if (!_isGremsyPayload || !PayloadManager.gremsy.recording) {
            gremsyRecordingTimer.stop()
            _gremsyRecordingStartedMs = 0
            _gremsyRecordingSeconds = 0
            return
        }

        if (_gremsyRecordingStartedMs === 0) {
            _gremsyRecordingStartedMs = Date.now()
        }
        _gremsyRecordingSeconds = Math.floor((Date.now() - _gremsyRecordingStartedMs) / 1000)
        gremsyRecordingTimer.start()
    }

    // The following properties relate to a simple camera
    property var    _flyViewSettings:                           QGroundControl.settingsManager.flyViewSettings
    property bool   _simpleCameraAvailable:                     !_mavlinkCamera && _activeVehicle && _flyViewSettings.showSimpleCameraControl.rawValue
    property bool   _onlySimpleCameraAvailable:                 !_anyVideoStreamAvailable && _simpleCameraAvailable
    property bool   _simpleCameraIsShootingInCurrentMode:       _onlySimpleCameraAvailable && !_simplePhotoCaptureIsIdle

    // The following properties relate to a simple video stream
    property bool   _videoStreamAvailable:                      _videoStreamManager.hasVideo
    property var    _videoStreamSettings:                       QGroundControl.settingsManager.videoSettings
    property var    _videoStreamManager:                        QGroundControl.videoManager
    property bool   _videoStreamAllowsPhotoWhileRecording:      true
    property bool   _videoStreamIsStreaming:                    _videoStreamManager.streaming
    property bool   _simplePhotoCaptureIsIdle:             true
    property bool   _videoStreamRecording:                      _videoStreamManager.recording
    property bool   _videoStreamCanShoot:                       _videoStreamIsStreaming
    property bool   _videoStreamIsShootingInCurrentMode:        _videoStreamInPhotoMode ? !_simplePhotoCaptureIsIdle : _videoStreamRecording
    property bool   _videoStreamInPhotoMode:                    false    

    property real zoomLevel: 1.0  // Start at 1x
    property real maxZoom: 30.0
    property real minZoom: 1.0
    property real zoomStep: 1.0
    property bool _zoomUiOverride: false
    property int _zoomUiPressedDirection: 0

    property bool   _hasZoom:                                   (_mavlinkCamera && _mavlinkCamera.hasZoom) || _usePayload
    // The following properties relate to a mavlink protocol camera
    property var    _mavlinkCameraManager:                      _activeVehicle ? _activeVehicle.cameraManager : null
    property int    _mavlinkCameraManagerCurCameraIndex:        _mavlinkCameraManager ? _mavlinkCameraManager.currentCamera : -1
    property bool   _noMavlinkCameras:                          _mavlinkCameraManager ? _mavlinkCameraManager.cameras.count === 0 : true
    property var    _mavlinkCamera:                             _mavlinkCameraManager ? _mavlinkCameraManager.currentCameraInstance : null
    property bool   _multipleMavlinkCameras:                    _mavlinkCameraManager ? _mavlinkCameraManager.cameras.count > 1 : false
    property string _mavlinkCameraName:                         _mavlinkCamera && _multipleMavlinkCameras ? _mavlinkCamera.modelName : ""
    property bool   _noMavlinkCameraStreams:                    _mavlinkCamera ? _mavlinkCamera.streamLabels.length : true
    property bool   _multipleMavlinkCameraStreams:              _mavlinkCamera ? _mavlinkCamera.streamLabels.length > 1 : false
    property int    _mavlinCameraCurStreamIndex:                _mavlinkCamera ? _mavlinkCamera.currentStream : -1
    property bool   _mavlinkCameraHasThermalVideoStream:        _mavlinkCamera ? _mavlinkCamera.thermalStreamInstance : false
    property bool   _mavlinkCameraModeUndefined:                _mavlinkCamera ? _mavlinkCamera.cameraMode === QGCCameraControl.CAM_MODE_UNDEFINED : true
    property bool   _mavlinkCameraInVideoMode:                  _mavlinkCamera ? _mavlinkCamera.cameraMode === QGCCameraControl.CAM_MODE_VIDEO : false
    property bool   _mavlinkCameraInPhotoMode:                  _mavlinkCamera ? _mavlinkCamera.cameraMode === QGCCameraControl.CAM_MODE_PHOTO : false
    property bool   _mavlinkCameraElapsedMode:                  _mavlinkCamera && _mavlinkCamera.cameraMode === QGCCameraControl.CAM_MODE_PHOTO && _mavlinkCamera.photoMode === QGCCameraControl.PHOTO_CAPTURE_TIMELAPSE
    property bool   _mavlinkCameraHasModes:                     _mavlinkCamera && _mavlinkCamera.hasModes
    property bool   _mavlinkCameraVideoIsRecording:             _mavlinkCamera && _mavlinkCamera.videoStatus === QGCCameraControl.VIDEO_CAPTURE_STATUS_RUNNING
    property bool   _mavlinkCameraPhotoCaptureIsIdle:           _mavlinkCamera && (_mavlinkCamera.photoStatus === QGCCameraControl.PHOTO_CAPTURE_IDLE || _mavlinkCamera.photoStatus >= QGCCameraControl.PHOTO_CAPTURE_LAST)
    property bool   _mavlinkCameraStorageReady:                 _mavlinkCamera && _mavlinkCamera.storageStatus === QGCCameraControl.STORAGE_READY
    property bool   _mavlinkCameraBatteryReady:                 _mavlinkCamera && _mavlinkCamera.batteryRemaining >= 0
    property bool   _mavlinkCameraStorageSupported:             _mavlinkCamera && _mavlinkCamera.storageStatus !== QGCCameraControl.STORAGE_NOT_SUPPORTED
    property bool   _mavlinkCameraAllowsPhotoWhileRecording:    false
    property bool   _mavlinkCameraCanShoot:                     (!_mavlinkCameraModeUndefined && ((_mavlinkCameraStorageReady && _mavlinkCamera.storageFree > 0) || !_mavlinkCameraStorageSupported)) || _videoStreamManager.streaming
    property bool   _mavlinkCameraIsShooting:                   ((_mavlinkCameraInVideoMode && _mavlinkCameraVideoIsRecording) || (_mavlinkCameraInPhotoMode && !_mavlinkCameraPhotoCaptureIsIdle)) || _videoStreamManager.recording
    property bool   _isNextVisionPayload:                       PayloadManager.activeType === 1 && PayloadManager.nextvision
    property bool   _nextVisionRecording:                       _isNextVisionPayload && PayloadManager.nextvision.recording
    property bool   _vehicleVideoCaptureRunning:                _activeVehicle && _activeVehicle.videoCaptureRunning
    property bool   _vehicleVideoCaptureAvailable:              _activeVehicle && !_modeIndicatorPhotoMode

    // The following settings and functions unify between a mavlink camera and a simple video stream for simple access

    property bool   _anyVideoStreamAvailable:                   _videoStreamManager.hasVideo
    property string _cameraName:                                _mavlinkCamera ? _mavlinkCameraName : ""
    property bool   _showModeIndicator:                         _mavlinkCamera ? _mavlinkCameraHasModes : _videoStreamManager.hasVideo
    property bool   _modeIndicatorPhotoMode:                    _isGremsyPayload
                                                                    ? _videoStreamInPhotoMode
                                                                    : (_mavlinkCamera ? _mavlinkCameraInPhotoMode : _videoStreamInPhotoMode || _onlySimpleCameraAvailable)
    property bool   _allowsPhotoWhileRecording:                  _mavlinkCamera ? _mavlinkCameraAllowsPhotoWhileRecording : _videoStreamAllowsPhotoWhileRecording
    property bool   _switchToPhotoModeAllowed:                  !_modeIndicatorPhotoMode && (_isGremsyPayload ? true : (_mavlinkCamera ? !_mavlinkCameraIsShooting : true))
    property bool   _switchToVideoModeAllowed:                  _modeIndicatorPhotoMode && (_isGremsyPayload ? true : (_mavlinkCamera ? !_mavlinkCameraIsShooting : true))
    property bool   _videoIsRecording:                          _nextVisionRecording || _vehicleVideoCaptureRunning || (_usePayload ? _payloadRecordingEffective : (_mavlinkCamera ? _mavlinkCameraIsShooting : _videoStreamRecording))
    property bool   _canShootInCurrentMode:                     _vehicleVideoCaptureAvailable || (_mavlinkCamera ? _mavlinkCameraCanShoot : _videoStreamCanShoot || _simpleCameraAvailable)
    property bool   _isShootingInCurrentMode:                   _nextVisionRecording || _vehicleVideoCaptureRunning || (_usePayload ? (!_videoStreamInPhotoMode && _payloadRecordingEffective) : (_mavlinkCamera ? _mavlinkCameraIsShooting : _videoStreamIsShootingInCurrentMode || _simpleCameraIsShootingInCurrentMode))

    property Fact _dZoom: (_mavlinkCamera && _mavlinkCamera.paramComplete) ? _mavlinkCamera.getFact("EO_DZOOM") : null
    // Debounce rapid zoom taps: the camera's stepZoom() computes its next
    // absolute target from _zoomLevel, which only updates after a CAMERA_SETTINGS
    // round-trip. A tap arriving mid-roundtrip reads an intermediate value and
    // commands +1 on top of it, producing a 2–3× overshoot.
    property real _zoomLastMs: 0

    // FlyDynamics3-style: button mode flips based on which territory the next
    // step would be. In optical territory the button is press-to-zoom (firmware
    // continuous zoom on press, stop on release — no timer). In digital
    // territory the button is tap-only (each tap = one EO_DZOOM step via
    // CodevCameraControl::stepZoom).
    //   - zoom-in optical territory:  zoomLevel < 29.5
    //   - zoom-out optical territory: digital fact at min (==1.0)
    property real _opticalMaxThreshold: 29.5
    property bool _zoomInActive: false
    property bool _zoomOutActive: false
    // Optical hold → CONTINUOUS (phase machine). Digital → tap step only.
    property bool _zoomInCanContinuous:  _mavlinkCamera ? _mavlinkCamera.zoomLevel < _opticalMaxThreshold : false
    property bool _digitalZoomActive:    _dZoom ? _dZoom.value > 1.01 : false
    property bool _zoomOutCanContinuous: _mavlinkCamera
            && !_digitalZoomActive
            && _mavlinkCamera.zoomLevel > 1.01


    //----------------------------------------------------------------------------------------------- Functions
    function setCameraMode(photoMode) {
        _videoStreamInPhotoMode = photoMode

        // Use the requested mode — do NOT toggle from current state.
        // Toggle-from-current (regressed in R3 zoom patch) causes flicker,
        // rollback, and eventually stuck photo/video controls on Sony/Codev.
        if (_mavlinkCamera) {
            if (photoMode) {
                _mavlinkCamera.setPhotoMode()
            } else {
                _mavlinkCamera.setVideoMode()
            }
            return
        }
    }

    function _stepCameraZoom(direction) {
        if (!_mavlinkCamera || !_mavlinkCamera.hasZoom) {
            return
        }
        if (typeof _mavlinkCamera.stepZoomFromUi === "function") {
            _mavlinkCamera.stepZoomFromUi(direction)
        } else if (typeof _mavlinkCamera.stepZoom === "function") {
            _mavlinkCamera.stepZoom(direction)
        }
    }

    function _startCameraZoom(direction) {
        if (!_mavlinkCamera || !_mavlinkCamera.hasZoom) {
            return
        }
        if (typeof _mavlinkCamera.startZoomFromUi === "function") {
            _mavlinkCamera.startZoomFromUi(direction)
        } else if (typeof _mavlinkCamera.startZoom === "function") {
            _mavlinkCamera.startZoom(direction)
        }
    }

    function _updateUiZoomLevel(direction) {
        var current = Number(getZoomValue())
        if (isNaN(current)) {
            current = zoomLevel
        }
        zoomLevel = Math.max(minZoom, Math.min(maxZoom, current + (direction * zoomStep)))
        _zoomUiOverride = true
    }

    function _beginNextVisionZoom(zoomIn) {
        var direction = zoomIn ? 1 : -1
        nextVisionZoomUiTimer.stop()
        nextVisionZoomMinPulseTimer.stop()
        _zoomUiPressedDirection = direction
        _updateUiZoomLevel(direction)

        if (PayloadManager.nextvision) {
            if (zoomIn) {
                PayloadManager.nextvision.zoomIn()
            } else {
                PayloadManager.nextvision.zoomOut()
            }
        }
        // A short tap still produces one complete zoom step. Holding the
        // button keeps the RC zoom command active until release.
        nextVisionZoomMinPulseTimer.restart()
    }

    function _endNextVisionZoom(zoomIn) {
        var direction = zoomIn ? 1 : -1
        if (_zoomUiPressedDirection !== direction) {
            return
        }
        _zoomUiPressedDirection = 0
        nextVisionZoomUiTimer.stop()
        if (!nextVisionZoomMinPulseTimer.running && PayloadManager.nextvision) {
            PayloadManager.nextvision.stopZoom()
        }
    }

    function _toggleMavlinkVideo() {
        if (!_mavlinkCamera) {
            return
        }
        if (typeof _mavlinkCamera.buttonToggleVideo === "function") {
            _mavlinkCamera.buttonToggleVideo()
        } else {
            _mavlinkCamera.toggleVideo()
        }
    }


    function toggleShooting() {
        // Gremsy is controlled directly over its payload MAVLink socket. Keep
        // it out of Vehicle/QGCCameraManager so one action sends one command.
        if (_usePayload && PayloadManager.activeType === 0 && !_videoStreamInPhotoMode) {
            if (PayloadManager.gremsy.recording) {
                PayloadManager.gremsy.stopRecording()
            } else {
                PayloadManager.gremsy.startRecording()
            }
            return
        }

        if (_usePayload && PayloadManager.activeType === 1 && !_videoStreamInPhotoMode) {
            if (PayloadManager.nextvision.recording) {
                PayloadManager.nextvision.stopRecording()
            } else {
                PayloadManager.nextvision.startRecording()
            }
            return
        }

        if (!_modeIndicatorPhotoMode && _activeVehicle && typeof _activeVehicle.toggleVideoCapture === "function") {
            _activeVehicle.toggleVideoCapture()
            return
        }

        if (_usePayload) {
            if (_videoStreamInPhotoMode) {
                _activePayload.captureImage()
                _simplePhotoCaptureIsIdle = false
                simplePhotoCaptureTimer.start()
            } else {
                if (_payloadRecording) {
                    _activePayload.stopRecording()
                    _payloadRecording = false
                } else {
                    _activePayload.startRecording()
                    _payloadRecording = true
                }
            }
            return
        }

        // // This whole mavlinkCameraCaptureVideoOrPhotos stuff is to work around some strange qml boolean testing
        // behavior which wasn't working correctly. This should work:
        //    if (_mavlinkCamera && (_mavlinkCamera.capturesVideo || _mavlinkCamera.capturesPhotos) ) {
        // but it doesn't for some strange reason. Hence all the stuff below...
        var mavlinkCameraCaptureVideoOrPhotos = false
        if (_mavlinkCamera) {
            if (_mavlinkCamera.capturesVideo || _mavlinkCamera.capturesPhotos) {
                mavlinkCameraCaptureVideoOrPhotos = true
            }
        }

        if (mavlinkCameraCaptureVideoOrPhotos) {
            if(_mavlinkCameraInVideoMode) {
                _toggleMavlinkVideo()
            } else {
                if(_mavlinkCameraInPhotoMode && !_mavlinkCameraPhotoCaptureIsIdle && _mavlinkCameraElapsedMode) {
                    _mavlinkCamera.stopTakePhoto()
                } else {
                    _mavlinkCamera.takePhoto()
                }
            }
        } else if (_onlySimpleCameraAvailable || (_simpleCameraAvailable && _anyVideoStreamAvailable && _videoStreamInPhotoMode && !videoGrabRadio.checked)) {
            _simplePhotoCaptureIsIdle = false
            _activeVehicle.triggerSimpleCamera()
            simplePhotoCaptureTimer.start()
        } else if (_anyVideoStreamAvailable) {
            if (_videoStreamInPhotoMode) {
                _simplePhotoCaptureIsIdle = false
                _videoStreamManager.grabImage()
                simplePhotoCaptureTimer.start()
            } else {
                if (_videoStreamManager.recording) {
                    _videoStreamManager.stopRecording()
                } else {
                    _videoStreamManager.startRecording()
                }
            }
        }
    }

    function getZoomValue() {
        if (_isNextVisionPayload && _usePayload && _zoomUiOverride) {
            return String(Math.round(zoomLevel))
        }
        if (_usePayload && PayloadManager.activeType === 0 && PayloadManager.gremsy) {
            return String(Math.round(PayloadManager.gremsy.zoomLevel))
        }
        if (!_hasZoom || !_mavlinkCamera) {
            return "1"
        }
        if (typeof _mavlinkCamera.displayZoomLevel !== "undefined") {
            return String(Math.round(_mavlinkCamera.displayZoomLevel))
        }
        if (isNaN(_mavlinkCamera.zoomLevel)) {
            return "1"
        }

        var optical = _mavlinkCamera.zoomLevel
        var digital = (_dZoom ? _dZoom.value : 1.0)
        return String(Math.round(optical * digital))
    }

    Timer {
        id:             simplePhotoCaptureTimer
        interval:       500
        onTriggered:    _simplePhotoCaptureIsIdle = true
    }

    Timer {
        id:             nextVisionZoomMinPulseTimer
        interval:       800
        repeat:         false
        onTriggered: {
            if (_zoomUiPressedDirection === 0) {
                if (PayloadManager.nextvision) {
                    PayloadManager.nextvision.stopZoom()
                }
            } else {
                nextVisionZoomUiTimer.restart()
            }
        }
    }

    Timer {
        id:             nextVisionZoomUiTimer
        interval:       800
        repeat:         true
        onTriggered: {
            if (_zoomUiPressedDirection !== 0) {
                _updateUiZoomLevel(_zoomUiPressedDirection)
            }
        }
    }

    Timer {
        id:             gremsyPhotoFeedbackTimer
        interval:       650
        repeat:         false
        onTriggered:    _gremsyPhotoFeedback = false
    }

    Timer {
        id:             nextVisionPhotoFeedbackTimer
        interval:       650
        repeat:         false
        onTriggered:    _nextVisionPhotoFeedback = false
    }

    Timer {
        id:             gremsyRecordingTimer
        interval:       1000
        repeat:         true
        onTriggered: {
            if (_gremsyRecordingStartedMs > 0) {
                _gremsyRecordingSeconds = Math.floor((Date.now() - _gremsyRecordingStartedMs) / 1000)
            }
        }
    }

    Connections {
        target: PayloadManager
        onActiveTypeChanged: {
            if (PayloadManager.activeType !== 1) {
                nextVisionZoomMinPulseTimer.stop()
                nextVisionZoomUiTimer.stop()
                nextVisionPhotoFeedbackTimer.stop()
                _nextVisionPhotoFeedback = false
                _zoomUiPressedDirection = 0
                _zoomUiOverride = false
                if (PayloadManager.nextvision) {
                    PayloadManager.nextvision.stopZoom()
                }
            }
            _syncGremsyRecordingUi()
        }
    }

    Connections {
        target: PayloadManager.nextvision
        ignoreUnknownSignals: true

        onZoomStepTriggered: {
            if (_isNextVisionPayload) {
                // Physical C1/C2 uses the controller's direction-calibrated pulse.
                // Mirror the same one-level UI change as a tap on +/-.
                _updateUiZoomLevel(direction)
            }
        }

        onPhotoCaptureTriggered: {
            if (_isNextVisionPayload) {
                setCameraMode(true)
                _nextVisionPhotoFeedback = true
                nextVisionPhotoFeedbackTimer.restart()
            }
        }
    }

    Connections {
        target: CustomQmlInterface
        ignoreUnknownSignals: true

        onCameraToggleRecord: {
            if (start && _isNextVisionPayload) {
                // A physical Record key must select the same Video mode/icon
                // as tapping the Video side of the camera panel.
                setCameraMode(false)
            }
        }
    }

    Connections {
        target: PayloadManager.gremsy
        ignoreUnknownSignals: true

        onPhotoCaptureTriggered: {
            if (_isGremsyPayload) {
                // A physical photo button must select the same UI mode as
                // tapping Photo in the panel. The capture command has already
                // been sent directly to Gremsy by the controller.
                _videoStreamInPhotoMode = true
                _gremsyPhotoFeedback = true
                gremsyPhotoFeedbackTimer.restart()
            }
        }

        onRecordingChanged: {
            if (_isGremsyPayload && PayloadManager.gremsy.recording && _modeIndicatorPhotoMode) {
                // A physical record button can start Gremsy recording while
                // the panel is still showing Photo mode. Keep the UI mode in
                // sync with that recording action.
                setCameraMode(false)
            }
            _syncGremsyRecordingUi()
        }
        onConnectedChanged: _syncGremsyRecordingUi()
    }

    Component.onCompleted: _syncGremsyRecordingUi()

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    ColumnLayout {
        id: content
        anchors.fill: parent
        spacing: ScreenTools.defaultFontPixelHeight * 0.5
        // ───────────────────────────────
        // 1. Reset & Setting Button
        RowLayout {
            spacing: ScreenTools.defaultFontPixelWidth * 6
            Layout.alignment: Qt.AlignHCenter

            //Gimbal reset
            Rectangle {
                height: ScreenTools.defaultFontPixelHeight * 2
                width: height
                radius: width
                color: "gray"
                // QGCMouseArea enlarges its hit box on Android. For Gremsy the
                // enlarged area overlapped the Photo/Video switch below and a
                // Video tap could therefore send GB_MODE=4 (gimbal reset).
                clip: _isGremsyPayload

                QGCColoredImage {
                    anchors.centerIn: parent
                    source: "/res/reset.svg"
                    mipmap: true
                    height: ScreenTools.defaultFontPixelHeight
                    width: height
                    sourceSize.height: height
                    color: qgcPal.text
                    fillMode: Image.PreserveAspectFit
                    visible: !_onlySimpleCameraAvailable
                }
                QGCMouseArea {
                    fillItem: parent
                    onClicked: _centerGimbal()
                }
            }
            //Camera Settings
            Rectangle {
                height: ScreenTools.defaultFontPixelHeight * 2
                width: height
                radius: width
                color: "gray"

                QGCColoredImage {
                    anchors.centerIn: parent
                    source: "/res/cameraSetting.svg"
                    mipmap: true
                    height: ScreenTools.defaultFontPixelHeight
                    width: height
                    sourceSize.height: height
                    color: qgcPal.text
                    fillMode: Image.PreserveAspectFit
                    visible: !_onlySimpleCameraAvailable
                }
                QGCMouseArea {
                    fillItem: parent
                    onClicked: settingsDialogComponent.createObject(mainWindow).open()
                }
            }
        }
        // ───────────────────────────────
        // 2. Photo/Video Switch Button
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: ScreenTools.defaultFontPixelWidth * 16
            height: width / 2.5
            color: qgcPal.windowShadeLight
            radius: height * 0.5
            visible: _showModeIndicator

            //Video Mode
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.height * 0.8
                height: parent.height * 0.8
                color: _modeIndicatorPhotoMode ? qgcPal.windowShadeLight : qgcPal.window
                radius: height * 0.5
                anchors.left: parent.left
                anchors.margins: ScreenTools.defaultFontPixelWidth

                QGCColoredImage {
                    height: parent.height * 0.5
                    width: height
                    anchors.centerIn: parent
                    source: "/qmlimages/camera_video.svg"
                    fillMode: Image.PreserveAspectFit
                    sourceSize.height: height
                    color: _modeIndicatorPhotoMode ? qgcPal.text : qgcPal.colorGreen
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !_isGremsyPayload && _switchToVideoModeAllowed
                    onClicked: setCameraMode(false)
                }
            }

            //Photo Mode
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.height * 0.8
                height: parent.height * 0.8
                color: _modeIndicatorPhotoMode ? qgcPal.window : qgcPal.windowShadeLight
                radius: height * 0.5
                anchors.right: parent.right
                anchors.margins: ScreenTools.defaultFontPixelWidth

                QGCColoredImage {
                    height: parent.height * 0.5
                    width: height
                    anchors.centerIn: parent
                    source: "/qmlimages/camera_photo.svg"
                    fillMode: Image.PreserveAspectFit
                    sourceSize.height: height
                    color: _modeIndicatorPhotoMode ? qgcPal.colorGreen : qgcPal.text
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !_isGremsyPayload && _switchToPhotoModeAllowed
                    onClicked: setCameraMode(true)
                }
            }

            // Gremsy: make each complete half of the switch touchable. The
            // original hit target was only the small circular icon, which is
            // difficult to operate on the Android controller display.
            MouseArea {
                z: 10
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * 0.5
                enabled: _isGremsyPayload && _switchToVideoModeAllowed
                preventStealing: true
                onClicked: setCameraMode(false)
            }

            MouseArea {
                z: 10
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * 0.5
                enabled: _isGremsyPayload && _switchToPhotoModeAllowed
                preventStealing: true
                onClicked: setCameraMode(true)
            }
        }

        // ───────────────────────────────
        // 3. Photo & Recording Button
        Rectangle {
            id: captureButton
            Layout.alignment: Qt.AlignHCenter
            color: Qt.rgba(0,0,0,0)
            width: ScreenTools.defaultFontPixelWidth * 10
            height: width
            radius: width * 0.5
            border.color: qgcPal.buttonText
            border.width: 3

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * (_captureButtonActive ? 0.5 : 0.75)
                height: width
                radius: _captureButtonActive ? 0 : width * 0.5
                color: _canShootInCurrentMode ? qgcPal.colorRed : qgcPal.colorGrey

                Behavior on width { NumberAnimation { duration: 100 } }
                Behavior on radius { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            MouseArea {
                anchors.fill: parent
                enabled: _canShootInCurrentMode
                onClicked: toggleShooting()
            }
        }

        // ───────────────────────────────
        // 4. Recording Time(only for recording)
        QGCLabel {
            Layout.alignment:   Qt.AlignHCenter
            text:               _isGremsyPayload
                                    ? (_payloadRecordingEffective
                                       ? _formatElapsedTime(_gremsyRecordingSeconds)
                                       : "00:00:00")
                                    : ((_mavlinkCameraInVideoMode && _mavlinkCamera.videoStatus === QGCCameraControl.VIDEO_CAPTURE_STATUS_RUNNING)
                                       ? _mavlinkCamera.recordTimeStr
                                       : "00:00:00")
            color:              (_isGremsyPayload && _payloadRecordingEffective) ? qgcPal.colorRed : qgcPal.text
            font.pointSize:     ScreenTools.largeFontPointSize
            font.bold:          true
            visible:            _isGremsyPayload
                                    ? !_modeIndicatorPhotoMode
                                    : (_mavlinkCameraInVideoMode && _mavlinkCamera.capturesVideo)
        }

        // ───────────────────────────────
        // 5. Zoom in / Zoom Out Button
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: ScreenTools.defaultFontPixelWidth * 18
            height: width / 3
            color: qgcPal.windowShadeLight
            radius: height * 0.5
            visible: _hasZoom

            //Zoom in
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.height * 0.8
                height: parent.height * 0.8
                color: (zoomInNextVision.pressed || zoomInStandard.pressed) ? "black" : "gray"
                radius: height * 0.5
                anchors.left: parent.left
                anchors.margins: ScreenTools.defaultFontPixelWidth

                QGCColoredImage {
                    height: parent.height * 0.5
                    width: height
                    anchors.centerIn: parent
                    source: "/res/ZoomIn.svg"
                    fillMode: Image.PreserveAspectFit
                    sourceSize.height: height
                    color: "white"
                }
                MouseArea {
                    id: zoomInNextVision
                    anchors.fill: parent
                    visible: _isNextVisionPayload && _usePayload
                    enabled: visible && _hasZoom
                    preventStealing: true
                    onPressed: _beginNextVisionZoom(true)
                    onReleased: _endNextVisionZoom(true)
                    onCanceled: _endNextVisionZoom(true)
                }
                MouseArea {
                    id: zoomInStandard
                    anchors.fill: parent
                    visible: !(_isNextVisionPayload && _usePayload)
                    enabled: visible && _hasZoom
                    preventStealing: true
                    onPressed: {
                        // Preserve the original behavior for every non-NextVision camera.
                        if (_usePayload) {
                            if (_isGremsyPayload) {
                                PayloadManager.gremsy.stepZoom(1)
                            } else {
                                _activePayload.zoomIn()
                                _zoomInActive = true
                            }
                        } else if (_mavlinkCamera && _mavlinkCamera.hasZoom) {
                            if (_zoomInCanContinuous) {
                                _startCameraZoom(1)
                                _zoomInActive = true
                            } else {
                                _stepCameraZoom(1)
                            }
                        }
                    }
                    onReleased: {
                        if (_zoomInActive && _usePayload) {
                            _activePayload.stopZoom()
                            _zoomInActive = false
                        } else if (_zoomInActive && _mavlinkCamera) {
                            _mavlinkCamera.stopZoom()
                            _zoomInActive = false
                        }
                    }
                    onCanceled: {
                        if (_zoomInActive && _usePayload) {
                            _activePayload.stopZoom()
                            _zoomInActive = false
                        } else if (_zoomInActive && _mavlinkCamera) {
                            _mavlinkCamera.stopZoom()
                            _zoomInActive = false
                        }
                    }
                }
            }

            //Zoom Value
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.height * 0.8
                height: parent.height * 0.8
                color: "black"
                radius: 5
                anchors.centerIn: parent

                Label {
                    anchors.centerIn: parent
                    text: "x" + getZoomValue()

                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            //Zoom out
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.height * 0.8
                height: parent.height * 0.8
                color: (zoomOutNextVision.pressed || zoomOutStandard.pressed) ? "black" : "gray"
                radius: height * 0.5
                anchors.right: parent.right
                anchors.margins: ScreenTools.defaultFontPixelWidth

                QGCColoredImage {
                    height: parent.height * 0.5
                    width: height
                    anchors.centerIn: parent
                    source: "/res/ZoomOut.svg"
                    fillMode: Image.PreserveAspectFit
                    sourceSize.height: height
                    color: "white"
                }
                MouseArea {
                    id: zoomOutNextVision
                    anchors.fill: parent
                    visible: _isNextVisionPayload && _usePayload
                    enabled: visible && _hasZoom
                    preventStealing: true
                    onPressed: _beginNextVisionZoom(false)
                    onReleased: _endNextVisionZoom(false)
                    onCanceled: _endNextVisionZoom(false)
                }
                MouseArea {
                    id: zoomOutStandard
                    anchors.fill: parent
                    visible: !(_isNextVisionPayload && _usePayload)
                    enabled: visible && _hasZoom
                    preventStealing: true
                    onPressed: {
                        // Preserve the original behavior for every non-NextVision camera.
                        if (_usePayload) {
                            if (_isGremsyPayload) {
                                PayloadManager.gremsy.stepZoom(-1)
                            } else {
                                _activePayload.zoomOut()
                                _zoomOutActive = true
                            }
                        } else if (_mavlinkCamera && _mavlinkCamera.hasZoom) {
                            if (_digitalZoomActive) {
                                _stepCameraZoom(-1)
                            } else if (_zoomOutCanContinuous) {
                                _startCameraZoom(-1)
                                _zoomOutActive = true
                            } else {
                                _stepCameraZoom(-1)
                            }
                        }
                    }
                    onReleased: {
                        if (_zoomOutActive && _usePayload) {
                            _activePayload.stopZoom()
                            _zoomOutActive = false
                        } else if (_zoomOutActive && _mavlinkCamera) {
                            _mavlinkCamera.stopZoom()
                            _zoomOutActive = false
                        }
                    }
                    onCanceled: {
                        if (_zoomOutActive && _usePayload) {
                            _activePayload.stopZoom()
                            _zoomOutActive = false
                        } else if (_zoomOutActive && _mavlinkCamera) {
                            _mavlinkCamera.stopZoom()
                            _zoomOutActive = false
                        }
                    }
                }
            }
        }

        // ───────────────────────────────
        // 6. Separator Line
        Rectangle {
            color: "lightgray"
            height: 1
            Layout.fillWidth: true
        }

        // ───────────────────────────────
        // 7. Gimbal Yaw, Pitch Text
        GridLayout {
            // DragonEye's ATTITUDE packets describe the intermediary
            // autopilot, not a reliable gimbal line-of-sight angle.
            visible: !_isNextVisionPayload
            columns: 2
            columnSpacing: ScreenTools.defaultFontPixelWidth
            rowSpacing: ScreenTools.defaultFontPixelHeight / 2
            Layout.fillWidth: true

            QGCLabel {
                text: qsTr("Gimbal Pitch")
                //wrapMode: Text.WordWrap
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: ScreenTools.defaultFontPixelHeight
                font.bold: true
            }

            QGCLabel {
                text: qsTr("Gimbal Yaw")
                //wrapMode: Text.WordWrap
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: ScreenTools.defaultFontPixelHeight
                font.bold: true
            }

            QGCLabel {
                //text: (_activeVehicle && _activeVehicle.gimbalData ? _activeVehicle.gimbalPitch.toFixed(0) : "0") + "°"
                text: {
                    var pitch = (_activeVehicle && _activeVehicle.gimbalData)
                            ? _activeVehicle.gimbalPitch
                            : 0
                    pitch = Math.abs(pitch) < 0.5 ? 0 : pitch
                    return pitch.toFixed(0) + "°"
                }
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: ScreenTools.defaultFontPixelHeight
                font.bold: true
            }

            QGCLabel {
                //text: (_activeVehicle && _activeVehicle.gimbalData ? _activeVehicle.gimbalYaw.toFixed(0) : "0") + "°"
                text: {
                    var yaw = (_activeVehicle && _activeVehicle.gimbalData)
                            ? _activeVehicle.gimbalYaw
                            : 0
                    yaw = Math.abs(yaw) < 0.5 ? 0 : yaw
                    return yaw.toFixed(0) + "°"
                }
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: ScreenTools.defaultFontPixelHeight
                font.bold: true
            }
        }

        // ───────────────────────────────
        // 8. Separator Line
        Rectangle {
            visible: !_isNextVisionPayload
            color: "lightgray"
            height: 1
            Layout.fillWidth: true
        }

        // ───────────────────────────────
        // 9. SD card Storage
        RowLayout {
            spacing: ScreenTools.defaultFontPixelWidth
            Layout.alignment: Qt.AlignHCenter
            Image {
                source: "/res/SDCard.svg"
                width: ScreenTools.defaultFontPixelWidth * 2
                height: ScreenTools.defaultFontPixelWidth * 2
                visible:            _mavlinkCameraStorageReady
            }

            QGCLabel {
                text:_mavlinkCamera ? qsTr("Free Space: ") + _mavlinkCamera.storageFreeStr : ""
                font.pointSize:     ScreenTools.defaultFontPointSize * 1.2
                visible:            _mavlinkCameraStorageReady
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    Component {
        id: settingsDialogComponent

        QGCPopupDialog {
            id:         settingsDialog            
            title: (_mavlinkCamera && _mavlinkCamera.firmwareVersion) ? qsTr("Settings") + " v" + _mavlinkCamera.firmwareVersion : qsTr("Settings")
            buttons:    StandardButton.Close

            // Nano tracker can runaway on very close targets — warn the operator
            // only when the tracking algorithm is actively switched to "Nano".
            property var _trackAlgorithmFact: _mavlinkCamera ? _mavlinkCamera.getFact("TRACK_ALGORITHM") : null

            Connections {
                target: settingsDialog._trackAlgorithmFact
                ignoreUnknownSignals: true
                function onValueChanged() {
                    if (settingsDialog._trackAlgorithmFact
                            && settingsDialog._trackAlgorithmFact.value === "Nano") {
                        nanoRunawayWarning.open()
                    }
                }
            }

            MessageDialog {
                id:                 nanoRunawayWarning
                title:              qsTr("Tracking Algorithm")
                text:               qsTr("If the target is close, camera runaway may occur.")
                standardButtons:    StandardButton.Ok
                onAccepted:         nanoRunawayWarning.close()
            }

            ColumnLayout {
                spacing: _margins

                GridLayout {
                    id:     gridLayout
                    flow:   GridLayout.TopToBottom
                    rows:   dynamicRows + (_mavlinkCamera ? _mavlinkCamera.activeSettings.length : 0)

                    property int dynamicRows: 10

                    // First column
                    QGCLabel {
                        text:               qsTr("Camera")
                        visible:            _multipleMavlinkCameras
                        onVisibleChanged:   gridLayout.dynamicRows += visible ? 1 : -1
                    }

                    QGCLabel {
                        text:               qsTr("Video Stream")
                        visible:            _multipleMavlinkCameraStreams
                        onVisibleChanged:   gridLayout.dynamicRows += visible ? 1 : -1
                    }

                    QGCLabel {
                        text:               qsTr("Thermal View Mode")
                        visible:            _mavlinkCameraHasThermalVideoStream
                        onVisibleChanged:   gridLayout.dynamicRows += visible ? 1 : -1
                    }

                    QGCLabel {
                        text:               qsTr("Blend Opacity")
                        visible:            _mavlinkCameraHasThermalVideoStream && _mavlinkCamera.thermalMode === QGCCameraControl.THERMAL_BLEND
                        onVisibleChanged:   gridLayout.dynamicRows += visible ? 1 : -1
                    }

                    // Mavlink Camera Protocol active settings
                    Repeater {
                        model: _mavlinkCamera ? _mavlinkCamera.activeSettings : []

                        QGCLabel {
                            text: _mavlinkCamera.getFact(modelData).shortDescription
                        }
                    }

                    QGCLabel {
                        text:               qsTr("Photo Mode")
                        visible:            _mavlinkCameraHasModes
                        onVisibleChanged:   gridLayout.dynamicRows += visible ? 1 : -1
                    }

                    QGCLabel {
                        text:               qsTr("Photo Interval (seconds)")
                        visible:            _mavlinkCameraInPhotoMode && _mavlinkCamera.photoMode === QGCCameraControl.PHOTO_CAPTURE_TIMELAPSE
                        onVisibleChanged:   gridLayout.dynamicRows += visible ? 1 : -1
                    }

                    QGCLabel {
                        text:               qsTr("Video Grid Lines")
                        visible:            _anyVideoStreamAvailable
                        onVisibleChanged:   gridLayout.dynamicRows += visible ? 1 : -1
                    }

                    QGCLabel {
                        text:               qsTr("Video Screen Fit")
                        visible:            _anyVideoStreamAvailable
                        onVisibleChanged:   gridLayout.dynamicRows += visible ? 1 : -1
                    }

                    QGCLabel {
                        text:               qsTr("Reset Camera Defaults")
                        visible:            _mavlinkCamera
                        onVisibleChanged:   gridLayout.dynamicRows += visible ? 1 : -1
                    }

                    QGCLabel {
                        text:               qsTr("Storage")
                        visible:            _mavlinkCameraStorageSupported
                        onVisibleChanged:   gridLayout.dynamicRows += visible ? 1 : -1
                    }

                    // Second column
                    QGCComboBox {
                        Layout.fillWidth:   true
                        sizeToContents:     true
                        model:              _mavlinkCameraManager ? _mavlinkCameraManager.cameraLabels : []
                        currentIndex:       _mavlinkCameraManagerCurCameraIndex
                        visible:            _multipleMavlinkCameras
                        onActivated:        _mavlinkCameraManager.currentCamera = index
                    }

                    QGCComboBox {
                        Layout.fillWidth:   true
                        sizeToContents:     true
                        model:              _mavlinkCamera ? _mavlinkCamera.streamLabels : []
                        currentIndex:       _mavlinCameraCurStreamIndex
                        visible:            _multipleMavlinkCameraStreams
                        onActivated:        _mavlinkCamera.currentStream = index
                    }

                    QGCComboBox {
                        Layout.fillWidth:   true
                        sizeToContents:     true
                        model:              [ qsTr("Off"), qsTr("Blend"), qsTr("Full"), qsTr("Picture In Picture") ]
                        currentIndex:       _mavlinkCamera ? _mavlinkCamera.thermalMode : -1
                        visible:            _mavlinkCameraHasThermalVideoStream
                        onActivated:        _mavlinkCamera.thermalMode = index
                    }

                    QGCSlider {
                        Layout.fillWidth:           true
                        maximumValue:               100
                        minimumValue:               0
                        value:                      _mavlinkCamera ? _mavlinkCamera.thermalOpacity : 0
                        displayValue:               true
                        updateValueWhileDragging:   true
                        visible:                    _mavlinkCameraHasThermalVideoStream && _mavlinkCamera.thermalMode === QGCCameraControl.THERMAL_BLEND
                        onPressedChanged: {
                            if (!pressed && _mavlinkCamera && Math.abs(_mavlinkCamera.thermalOpacity - value) > 0.1) {
                                _mavlinkCamera.thermalOpacity = value
                            }
                        }
                    }

                    // Mavlink Camera Protocol active settings
                    Repeater {
                        model: _mavlinkCamera ? _mavlinkCamera.activeSettings : []

                        RowLayout {
                            Layout.fillWidth:   true
                            spacing:            ScreenTools.defaultFontPixelWidth

                            property var    _fact:      _mavlinkCamera.getFact(modelData)
                            property bool   _isBool:    _fact.typeIsBool
                            property bool   _isCombo:   !_isBool && _fact.enumStrings.length > 0
                            property bool   _isSlider:  _fact && !isNaN(_fact.increment)
                            property bool   _isEdit:    !_isBool && !_isSlider && _fact.enumStrings.length < 1

                            FactComboBox {
                                Layout.fillWidth:   true
                                sizeToContents:     true
                                fact:               parent._fact
                                indexModel:         false
                                visible:            parent._isCombo
                            }
                            FactTextField {
                                Layout.fillWidth:   true
                                fact:               parent._fact
                                visible:            parent._isEdit
                                readOnly:           fact.readOnly
                                selectByMouse:      !fact.readOnly
                                activeFocusOnPress: !fact.readOnly
                            }
                            FactSpinBox {
                                Layout.fillWidth:   true
                                fact:               parent._fact
                                visible:            parent._isSlider
                            }

                            // QGCSlider {
                            //     Layout.fillWidth:           true
                            //     maximumValue:               parent._fact.max
                            //     minimumValue:               parent._fact.min
                            //     stepSize:                   parent._fact.increment
                            //     displayValue:               true
                            //     visible:                    parent._isSlider
                            //     updateValueWhileDragging:   false
                            //     property bool initialized:  false

                            //     onValueChanged: {
                            //         if (!initialized) {
                            //             return
                            //         }
                            //         parent._fact.value = value
                            //     }

                            //     Component.onCompleted: {
                            //         value = parent._fact.value
                            //         initialized = true
                            //     }
                            // }
                            QGCSwitch {
                                checked:        parent._fact ? parent._fact.value : false
                                visible:        parent._isBool
                                onClicked:      parent._fact.value = checked ? 1 : 0
                            }
                        }
                    }

                    QGCComboBox {
                        Layout.fillWidth:   true
                        sizeToContents:     true
                        model:              [ qsTr("Single"), qsTr("Time Lapse") ]
                        currentIndex:       _mavlinkCamera ? _mavlinkCamera.photoMode : 0
                        visible:            _mavlinkCameraHasModes
                        onActivated:        _mavlinkCamera.photoMode = index
                    }
                    // 6 slider
                    QGCSlider {
                        Layout.fillWidth:           true
                        maximumValue:               60
                        minimumValue:               1
                        stepSize:                   1
                        value:                      _mavlinkCamera ? _mavlinkCamera.photoLapse : 5
                        displayValue:               true
                        updateValueWhileDragging:   true
                        visible:                    _mavlinkCameraInPhotoMode && _mavlinkCamera.photoMode === QGCCameraControl.PHOTO_CAPTURE_TIMELAPSE
                        onValueChanged: {
                            if (_mavlinkCamera) {
                                _mavlinkCamera.photoLapse = value
                            }
                        }
                    }
                    // 7 switch button
                    QGCSwitch {
                        checked:            _videoStreamSettings.gridLines.rawValue
                        visible:            _anyVideoStreamAvailable
                        onClicked:          _videoStreamSettings.gridLines.rawValue = checked ? 1 : 0
                    }
                    // 8 combobox
                    FactComboBox {
                        Layout.fillWidth:   true
                        sizeToContents:     true
                        fact:               _videoStreamSettings.videoFit
                        indexModel:         false
                        visible:            _anyVideoStreamAvailable
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Reset")
                        visible:            _mavlinkCamera
                        onClicked:          resetPrompt.open()
                        MessageDialog {
                            id:                 resetPrompt
                            title:              qsTr("Reset Camera to Factory Settings")
                            text:               qsTr("Confirm resetting all settings?")
                            standardButtons:    StandardButton.Yes | StandardButton.No
                            onNo: resetPrompt.close()
                            onYes: {
                                _mavlinkCamera.resetSettings()
                                resetPrompt.close()
                            }
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Format")
                        visible:            _mavlinkCameraStorageSupported
                        onClicked:          formatPrompt.open()
                        MessageDialog {
                            id:                 formatPrompt
                            title:              qsTr("Format Camera Storage")
                            text:               qsTr("Confirm erasing all files?")
                            standardButtons:    StandardButton.Yes | StandardButton.No
                            onNo: formatPrompt.close()
                            onYes: {
                                _mavlinkCamera.formatCard()
                                formatPrompt.close()
                            }
                        }
                    }    
                  }
            }
        }
    }
}
