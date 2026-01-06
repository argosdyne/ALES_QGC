/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick                  2.4
import QtPositioning            5.2
import QtQuick.Layouts          1.2
import QtQuick.Controls         1.4
import QtQuick.Dialogs          1.2
import QtGraphicalEffects       1.0

import QGroundControl                   1.0
import QGroundControl.ScreenTools       1.0
import QGroundControl.Controls          1.0
import QGroundControl.Palette           1.0
import QGroundControl.Vehicle           1.0
import QGroundControl.Controllers       1.0
import QGroundControl.FactSystem        1.0
import QGroundControl.FactControls      1.0
Item {    
    implicitHeight: content.implicitHeight    
    visible:    (_mavlinkCamera || _videoStreamAvailable || _simpleCameraAvailable) && multiVehiclePanelSelector.showSingleVehiclePanel
    property real   _margins:                                   ScreenTools.defaultFontPixelHeight / 2
    property var    _activeVehicle:                             QGroundControl.multiVehicleManager.activeVehicle

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

    property bool   _hasZoom:                                   _mavlinkCamera && _mavlinkCamera.hasZoom
    // The following properties relate to a mavlink protocol camera
    property var    _mavlinkCameraManager:                      _activeVehicle ? _activeVehicle.cameraManager : null
    property int    _mavlinkCameraManagerCurCameraIndex:        _mavlinkCameraManager ? _mavlinkCameraManager.currentCamera : -1
    property bool   _noMavlinkCameras:                          _mavlinkCameraManager ? _mavlinkCameraManager.cameras.count === 0 : true
    property var    _mavlinkCamera:                             !_noMavlinkCameras ? (_mavlinkCameraManager.cameras.get(_mavlinkCameraManagerCurCameraIndex) && _mavlinkCameraManager.cameras.get(_mavlinkCameraManagerCurCameraIndex).paramComplete ? _mavlinkCameraManager.cameras.get(_mavlinkCameraManagerCurCameraIndex) : null) : null
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

    // The following settings and functions unify between a mavlink camera and a simple video stream for simple access

    property bool   _anyVideoStreamAvailable:                   _videoStreamManager.hasVideo
    property string _cameraName:                                _mavlinkCamera ? _mavlinkCameraName : ""
    property bool   _showModeIndicator:                         _mavlinkCamera ? _mavlinkCameraHasModes : _videoStreamManager.hasVideo
    property bool   _modeIndicatorPhotoMode:                    _mavlinkCamera ? _mavlinkCameraInPhotoMode : _videoStreamInPhotoMode || _onlySimpleCameraAvailable
    property bool   _allowsPhotoWhileRecording:                  _mavlinkCamera ? _mavlinkCameraAllowsPhotoWhileRecording : _videoStreamAllowsPhotoWhileRecording
    property bool   _switchToPhotoModeAllowed:                  !_modeIndicatorPhotoMode && (_mavlinkCamera ? !_mavlinkCameraIsShooting : true)
    property bool   _switchToVideoModeAllowed:                  _modeIndicatorPhotoMode && (_mavlinkCamera ? !_mavlinkCameraIsShooting : true)
    property bool   _videoIsRecording:                          _mavlinkCamera ? _mavlinkCameraIsShooting : _videoStreamRecording
    property bool   _canShootInCurrentMode:                     _mavlinkCamera ? _mavlinkCameraCanShoot : _videoStreamCanShoot || _simpleCameraAvailable
    property bool   _isShootingInCurrentMode:                   _mavlinkCamera ? _mavlinkCameraIsShooting : _videoStreamIsShootingInCurrentMode || _simpleCameraIsShootingInCurrentMode

    //----------------------------------------------------------------------------------------------- Functions
    function setCameraMode(photoMode) {
        console.log("Switching Camera Mode: ", photoMode ? "Photo" : "Video")
        _videoStreamInPhotoMode = photoMode

        if (_mavlinkCamera){
            if (_mavlinkCameraInPhotoMode) {
                _mavlinkCamera.setVideoMode()
            } else {
                _mavlinkCamera.setPhotoMode()
            }
        }
        console.warn("No camera available to switch mode!")

    }
    function toggleShooting() {
        console.log("toggleShooting", _anyVideoStreamAvailable)        

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
                _mavlinkCamera.toggleVideo()
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

    Timer {
        id:             simplePhotoCaptureTimer
        interval:       500
        onTriggered:    _simplePhotoCaptureIsIdle = true
    }

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
                    onClicked: _mavlinkCamera ? _mavlinkCamera.centerGimbal() : null
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
                    enabled: _switchToVideoModeAllowed
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
                    enabled: _switchToPhotoModeAllowed
                    onClicked: setCameraMode(true)
                }
            }
        }

        // ───────────────────────────────
        // 3. Photo & Recording Button
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            color: Qt.rgba(0,0,0,0)
            width: ScreenTools.defaultFontPixelWidth * 10
            height: width
            radius: width * 0.5
            border.color: qgcPal.buttonText
            border.width: 3

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * (_isShootingInCurrentMode ? 0.5 : 0.75)
                height: width
                radius: _isShootingInCurrentMode ? 0 : width * 0.5
                color: _canShootInCurrentMode ? qgcPal.colorRed : qgcPal.colorGrey
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
            text:               (_mavlinkCameraInVideoMode && _mavlinkCamera.videoStatus === QGCCameraControl.VIDEO_CAPTURE_STATUS_RUNNING) ? _mavlinkCamera.recordTimeStr : "00:00:00"
            font.pointSize:     ScreenTools.largeFontPointSize
            font.bold:          true
            visible:            _mavlinkCameraInVideoMode && _mavlinkCamera.capturesVideo
        }

        // ───────────────────────────────
        // 5. Zoom in / Zoom Out Button
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: ScreenTools.defaultFontPixelWidth * 18
            height: width / 3
            color: qgcPal.windowShadeLight
            radius: height * 0.5
            visible: _showModeIndicator

            //Zoom in
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.height * 0.8
                height: parent.height * 0.8
                color: zoomIn.pressed ? "black" : "gray"
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
                    id: zoomIn
                    anchors.fill: parent
                    enabled: _hasZoom
                    onClicked: _mavlinkCamera.stepZoom(1)
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
                    text: "x" + (_hasZoom && _mavlinkCamera
                                 ? _mavlinkCamera.zoomLevel.toFixed(0)
                                 : 1)
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
                color: zoomOut.pressed ? "black" : "gray"
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
                    id: zoomOut
                    anchors.fill: parent
                    enabled: _hasZoom
                    onClicked: _mavlinkCamera.stepZoom(-1)
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
                        updateValueWhileDragging:   true
                        visible:                    _mavlinkCameraHasThermalVideoStream && _mavlinkCamera.thermalMode === QGCCameraControl.THERMAL_BLEND
                        onValueChanged:             _mavlinkCamera.thermalOpacity = value
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
                            QGCSlider {
                                Layout.fillWidth:           true
                                maximumValue:               parent._fact.max
                                minimumValue:               parent._fact.min
                                stepSize:                   parent._fact.increment
                                visible:                    parent._isSlider
                                updateValueWhileDragging:   false
                                property bool initialized:  false

                                onValueChanged: {
                                    if (!initialized) {
                                        return
                                    }
                                    parent._fact.value = value
                                }

                                Component.onCompleted: {
                                    value = parent._fact.value
                                    initialized = true
                                }
                            }
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
