/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


import QtQuick                          2.11
import QtQuick.Controls                 2.4

import QGroundControl                   1.0
import QGroundControl.FlightDisplay     1.0
import QGroundControl.FlightMap         1.0
import QGroundControl.ScreenTools       1.0
import QGroundControl.Controls          1.0
import QGroundControl.Palette           1.0
import QGroundControl.Vehicle           1.0
import QGroundControl.Controllers       1.0

Item {
    id:     root
    clip:   true

    property bool useSmallFont: true

    property double _ar:                QGroundControl.videoManager.aspectRatio
    property bool   _showGrid:          QGroundControl.settingsManager.videoSettings.gridLines.rawValue > 0
    property var    _dynamicCameras:    globals.activeVehicle ? globals.activeVehicle.cameraManager : null
    property bool   _connected:         globals.activeVehicle ? !globals.activeVehicle.communicationLost : false
    property int    _curCameraIndex:    _dynamicCameras ? _dynamicCameras.currentCamera : 0
    property bool   _isCamera:          _dynamicCameras ? _dynamicCameras.cameras.count > 0 : false
    property var    _camera:            _isCamera ? _dynamicCameras.cameras.get(_curCameraIndex) : null
    property bool   _hasZoom:           _camera && _camera.hasZoom
    property int    _fitMode:           QGroundControl.settingsManager.videoSettings.videoFit.rawValue

    property double _thermalHeightFactor: 0.85 //-- TODO

    // Keep the GL video surface alive across brief decode gaps (e.g. camera mode switch).
    property bool _hasDecodedOnce: false
    property bool _showVideoFrame: false

    Timer {
        id:             decodingHoldTimer
        interval:       2500
        onTriggered: {
            _showVideoFrame = QGroundControl.videoManager.decoding
            if (!_showVideoFrame) {
                _hasDecodedOnce = false
            }
        }
    }

    Connections {
        target: QGroundControl.videoManager
        function onDecodingChanged() {
            if (QGroundControl.videoManager.decoding) {
                _hasDecodedOnce = true
                _showVideoFrame = true
                decodingHoldTimer.stop()
            } else if (_hasDecodedOnce) {
                decodingHoldTimer.restart()
            } else {
                _showVideoFrame = false
            }
        }
    }

    Component.onCompleted: {
        if (QGroundControl.videoManager.decoding) {
            _hasDecodedOnce = true
            _showVideoFrame = true
        }
    }

    Rectangle {
        id:             noVideo
        anchors.fill:   parent
        color:          Qt.rgba(0,0,0,0.75)
        z:              2
        visible:        !_showVideoFrame
        QGCLabel {
            text:               QGroundControl.settingsManager.videoSettings.streamEnabled.rawValue ? qsTr("WAITING FOR VIDEO") : qsTr("VIDEO DISABLED")
            font.family:        ScreenTools.demiboldFontFamily
            color:              "white"
            font.pointSize:     useSmallFont ? ScreenTools.smallFontPointSize : ScreenTools.largeFontPointSize
            anchors.centerIn:   parent
        }
    }
    Rectangle {
        anchors.fill:   parent
        color:          "black"
        z:              1
        function getWidth() {
            //-- Fit Width or Stretch
            if(_fitMode === 0 || _fitMode === 2) {
                return parent.width
            }
            //-- Fit Height
            return _ar != 0.0 ? parent.height * _ar : parent.width
        }
        function getHeight() {
            //-- Fit Height or Stretch
            if(_fitMode === 1 || _fitMode === 2) {
                return parent.height
            }
            //-- Fit Width
            return _ar != 0.0 ? parent.width * (1 / _ar) : parent.height
        }
        Component {
            id: videoBackgroundComponent
            QGCVideoBackground {
                id:             videoContent
                objectName:     "videoContent"
                property int gridZ: videoContent.item.z + 1

                Connections {
                    target: QGroundControl.videoManager
                    function onImageFileChanged() {
                        videoContent.grabToImage(function(result) {
                            if (!result.saveToFile(QGroundControl.videoManager.imageFile)) {
                                console.error('Error capturing video frame');
                            }
                        });
                    }
                }
                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    height: parent.height
                    width:  1
                    x:      parent.width * 0.33
                    z:      parent.gridZ
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen
                }
                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    height: parent.height
                    width:  1
                    x:      parent.width * 0.66
                    z:      parent.gridZ
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen
                }
                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    width:  parent.width
                    height: 1
                    y:      parent.height * 0.33
                    z:      parent.gridZ
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen
                }
                Rectangle {
                    color:  Qt.rgba(1,1,1,0.5)
                    width:  parent.width
                    height: 1
                    y:      parent.height * 0.66
                    z:      parent.gridZ
                    visible: _showGrid && !QGroundControl.videoManager.fullScreen
                }
            }
        }
        Loader {
            // GStreamer is causing crashes on Lenovo laptop OpenGL Intel drivers. In order to workaround this
            // we don't load a QGCVideoBackground object when video is disabled. This prevents any video rendering
            // code from running. Setting QGCVideoBackground.receiver = null does not work to prevent any
            // video OpenGL from being generated. Hence the Loader to completely remove it.
            id:                 videoContentLoader
            height:             parent.getHeight()
            width:              parent.getWidth()
            anchors.centerIn:   parent
            visible:            _showVideoFrame
            sourceComponent:    videoBackgroundComponent

            property bool videoDisabled: QGroundControl.settingsManager.videoSettings.videoSource.rawValue === QGroundControl.settingsManager.videoSettings.disabledVideoSource
        }

        //-- Thermal Image
        Item {
            id:                 thermalItem
            width:              height * QGroundControl.videoManager.thermalAspectRatio
            height:             _camera ? (_camera.thermalMode === QGCCameraControl.THERMAL_FULL ? parent.height : (_camera.thermalMode === QGCCameraControl.THERMAL_PIP ? ScreenTools.defaultFontPixelHeight * 12 : parent.height * _thermalHeightFactor)) : 0
            anchors.centerIn:   parent
            visible:            QGroundControl.videoManager.hasThermal && _camera.thermalMode !== QGCCameraControl.THERMAL_OFF
            function pipOrNot() {
                if(_camera) {
                    if(_camera.thermalMode === QGCCameraControl.THERMAL_PIP) {
                        anchors.centerIn    = undefined
                        anchors.top         = parent.top
                        anchors.topMargin   = mainWindow.header.height + (ScreenTools.defaultFontPixelHeight * 0.5)
                        anchors.left        = parent.left
                        anchors.leftMargin  = ScreenTools.defaultFontPixelWidth * 12
                    } else {
                        anchors.top         = undefined
                        anchors.topMargin   = undefined
                        anchors.left        = undefined
                        anchors.leftMargin  = undefined
                        anchors.centerIn    = parent
                    }
                }
            }
            Connections {
                target:                 _camera
                function onThermalModeChanged() { thermalItem.pipOrNot() }
            }
            onVisibleChanged: {
                thermalItem.pipOrNot()
            }
            QGCVideoBackground {
                id:             thermalVideo
                objectName:     "thermalVideo"
                anchors.fill:   parent
                receiver:       QGroundControl.videoManager.thermalVideoReceiver
                opacity:        _camera ? (_camera.thermalMode === QGCCameraControl.THERMAL_BLEND ? _camera.thermalOpacity / 100 : 1.0) : 0
            }
        }
    }

    QGCLabel {
        text: qsTr("Double-click to exit full screen")
        font.pointSize: ScreenTools.largeFontPointSize
        visible: QGroundControl.videoManager.fullScreen && flyViewVideoMouseArea.containsMouse
        anchors.centerIn: parent
    }

    MouseArea {
        id: flyViewVideoMouseArea
        anchors.fill:       parent
        enabled:            pipState.state === pipState.fullState
        property int _pressCount: 0
        Timer {
            id: doubleTimer
            interval: 300
            onTriggered: parent._pressCount = 0
        }
        onClicked: {
            flyViewVideoMouseArea._pressCount++
            doubleTimer.restart()
            if (flyViewVideoMouseArea._pressCount === 2) {
                QGroundControl.videoManager.fullScreen = !QGroundControl.videoManager.fullScreen
            }
        }
    }

    Loader {
        anchors.fill: parent
        visible: pipState.state === pipState.fullState && !QGroundControl.videoManager.fullScreen
        source: _camera && _camera.paramComplete ? _camera.visualQML : ""
    }

    Repeater {
        model: QGroundControl.corePlugin.dynamicRepcManager.replicas
        delegate: Loader {
            height: videoContentLoader.height
            width: videoContentLoader.width
            anchors.centerIn: parent
            active: object.ready
            source: object.videoOverlyQml
        }
    }
}
