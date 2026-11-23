/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick                  2.12
import QtQuick.Controls         2.4
import QtQuick.Dialogs          1.3
import QtQuick.Layouts          1.12

import QtLocation               5.3
import QtPositioning            5.3
import QtQuick.Window           2.2
import QtQml.Models             2.1
import QtGraphicalEffects       1.12

import QGroundControl               1.0
import QGroundControl.Controllers   1.0
import QGroundControl.Controls      1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FlightDisplay 1.0
import QGroundControl.FlightMap     1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Vehicle       1.0

Item {
    id: _root

    // AQGC Simple UI: the classic fly widget layers are removed (2026-11-18); map, video, PiP and the guided
    // controller stay. simpleMode is always true now (MainRootWindow), kept for the Simple sizes below.
    property bool simpleMode: true

    // These should only be used by MainRootWindow
    property var planController:    _planController
    property var guidedController:  _guidedController

    PlanMasterController {
        id:                     _planController
        flyView:                true
        Component.onCompleted:  start()
    }

    property bool   _mainWindowIsMap:       mapControl.pipState.state === mapControl.pipState.fullState

    // AQGC Simple UI: S49 "Show map instead" swaps the PiP back to the map
    function simpleShowMap() { if (!_mainWindowIsMap) _pipOverlay._swapPip() }
    readonly property var simpleMap: mapControl     // S30 map controls
    property bool   _isFullWindowItemDark:  _mainWindowIsMap ? mapControl.isSatelliteMap : true
    property var    _activeVehicle:         globals.activeVehicle ? globals.activeVehicle : QGroundControl.multiVehicleManager.activeVehicle
    property var    _missionController:     _planController.missionController
    property var    _geoFenceController:    _planController.geoFenceController
    property var    _rallyPointController:  _planController.rallyPointController
    property real   _margins:               ScreenTools.defaultFontPixelWidth / 2
    property var    _guidedController:      guidedActionsController
    property var    _guidedActionList:      guidedActionList
    property var    _guidedValueSlider:     guidedValueSlider
    property real   _toolsMargin:           ScreenTools.defaultFontPixelWidth * 0.75
    property rect   _centerViewport:        Qt.rect(0, 0, width, height)
    property real   _rightPanelWidth:       ScreenTools.defaultFontPixelWidth * 30
    property var    _mapControl:            mapControl

    property real   _fullItemZorder:    0
    property real   _pipItemZorder:     QGroundControl.zOrderWidgets

    property double _ar:                QGroundControl.videoManager.aspectRatio
    property bool   _showGrid:          QGroundControl.settingsManager.videoSettings.gridLines.rawValue > 0
    property var    _dynamicCameras:    globals.activeVehicle ? globals.activeVehicle.cameraManager : null
    property bool   _connected:         globals.activeVehicle ? !globals.activeVehicle.communicationLost : false
    property int    _curCameraIndex:    _dynamicCameras ? _dynamicCameras.currentCamera : 0
    property bool   _isCamera:          _dynamicCameras ? _dynamicCameras.cameras.count > 0 : false
    property var    _camera:            _isCamera ? _dynamicCameras.cameras.get(_curCameraIndex) : null

    // Font sizes for the C++ message layout (CustomQmlInterface); was set by the removed custom fly overlay
    Component.onCompleted: {
        if (typeof CustomQmlInterface !== "undefined") {
            CustomQmlInterface.defaultFontPixelWidth  = Qt.binding(function() { return ScreenTools.defaultFontPixelWidth })
            CustomQmlInterface.defaultFontPixelHeight = Qt.binding(function() { return ScreenTools.defaultFontPixelHeight })
        }
    }

    QGCToolInsets {
        id:                     _toolInsets
        leftEdgeBottomInset:    _pipOverlay.visible ? _pipOverlay.x + _pipOverlay.width : 0
        bottomEdgeLeftInset:    _pipOverlay.visible ? parent.height - _pipOverlay.y : 0
    }

    GuidedActionsController {
        id:                 guidedActionsController
        missionController:  _missionController
        actionList:         _guidedActionList
        guidedValueSlider:     _guidedValueSlider
    }

    // The guided controller keeps its confirmation state in a GuidedActionConfirm (confirmDialog). It used to sit in the
    // classic telemetry bar of the hidden widget layer; it stays hidden here so the controller behaves as before
    // (the Simple screens confirm actions themselves and call executeAction).
    Item {
        visible: false
        GuidedActionConfirm {
            guidedController:   _guidedController
            guidedValueSlider:  _guidedValueSlider
        }
    }

    /*GuidedActionConfirm {
        id:                         guidedActionConfirm
        anchors.margins:            _margins
        anchors.bottom:             parent.bottom
        anchors.horizontalCenter:   parent.horizontalCenter
        z:                          QGroundControl.zOrderTopMost
        guidedController:           _guidedController
        guidedValueSlider:             _guidedValueSlider
    }*/

    GuidedActionList {
        id:                         guidedActionList
        anchors.margins:            _margins
        anchors.bottom:             parent.bottom
        anchors.horizontalCenter:   parent.horizontalCenter
        z:                          QGroundControl.zOrderTopMost
        guidedController:           _guidedController
    }

    //-- Guided value slider (e.g. altitude)
    GuidedValueSlider {
        id:                 guidedValueSlider
        anchors.margins:    _toolsMargin
        anchors.right:      parent.right
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        z:                  QGroundControl.zOrderTopMost
        radius:             ScreenTools.defaultFontPixelWidth / 2
        width:              ScreenTools.defaultFontPixelWidth * 10
        color:              qgcPal.window
        visible:            false
    }

    FlyViewMap {
        id:                     mapControl
        planMasterController:   _planController
        rightPanelWidth:        ScreenTools.defaultFontPixelHeight * 9
        pipMode:                !_mainWindowIsMap
        toolInsets:             _toolInsets
        mapName:                "FlightDisplayView"
        // Simple UI: rounded PiP corners (Figma S04)
        layer.enabled:          simpleMode && pipState.state === pipState.pipState
        layer.effect:           OpacityMask { maskSource: Rectangle { width: mapControl.width; height: mapControl.height; radius: _pipOverlay.simpleRadius } }
    }

    FlyViewVideo {
        id: videoControl
        layer.enabled:          simpleMode && pipState.state === pipState.pipState
        layer.effect:           OpacityMask { maskSource: Rectangle { width: videoControl.width; height: videoControl.height; radius: _pipOverlay.simpleRadius } }
    }

    FlyViewFPVVideo {
        id: fpvVideoControl
        visible: !QGroundControl.settingsManager.videoSettings.disableFPVVideo.value &&
                 !QGroundControl.videoManager.fullScreen  &&
                 (fpvVideoControl.pipState.state === fpvVideoControl.pipState.pipState ? _pipOverlay._shown : true)
    }

    FPVOverlay {
        id: _fpvOverlay
        // Simple UI: telemetry is bottom-left and the main PiP bottom-right (Figma S04),
        // so the FPV overlay starts in the free space between them (x 950-1472 on 1920 x 1080)
        x: simpleMode ? Math.round(950 * _simpleScale + (522 * _simpleScale - width) / 2) : parent.width - _toolsMargin - width
        y: parent.height - (simpleMode ? Math.round(24 * _simpleScale) : _toolsMargin) - height
        z: _pipItemZorder + 1
        pipOverlay: _pipOverlay
        item1: fpvVideoControl
        item2: QGroundControl.videoManager.hasVideo ? videoControl : null
        show: true //mapControl.isFlyView
    }

    // AQGC Simple UI: Figma S04 PiP bottom-right (right 24, bottom 24, 400 x 226 on a 1920 x 1080 screen)
    readonly property real _simpleScale: Math.min(width / 1920, height / 1080)

    PipView {
        id:                     _pipOverlay
        anchors.left:           simpleMode ? undefined : parent.left
        anchors.right:          simpleMode ? parent.right : undefined
        anchors.bottom:         parent.bottom
        anchors.margins:        _toolsMargin
        anchors.rightMargin:    simpleMode ? Math.round(24 * _simpleScale) : _toolsMargin
        anchors.bottomMargin:   simpleMode ? Math.round(24 * _simpleScale) : _toolsMargin
        _pipSize:               simpleMode ? Math.round(400 * _simpleScale) : parent.width * 0.2
        simpleStyle:            simpleMode
        simpleRadius:           Math.round(16 * _simpleScale)
        simpleBorder:           Math.max(1, Math.round(3 * _simpleScale))
        simpleLabelHeight:      Math.round(40 * _simpleScale)
        simpleFontSize:         Math.max(1, Math.round(22 * _simpleScale))
        simpleItem1Label:       qsTr("Map")
        simpleItem2Label:       qsTr("Camera")
        simpleItem1Icon:        "qrc:/simple/icons/map.svg"
        simpleItem2Icon:        "qrc:/simple/icons/camera.svg"
        item1IsFullSettingsKey: "MainFlyWindowIsMap"
        item1:                  mapControl
        //item2:                  QGroundControl.videoManager.hasVideo ? videoControl : null
        z:                      _pipItemZorder
        show:                   !QGroundControl.videoManager.fullScreen &&
                                    (videoControl.pipState.state === videoControl.pipState.pipState ||
                                     mapControl.pipState.state === mapControl.pipState.pipState ||
                                     fpvVideoControl.pipState.state === fpvVideoControl.pipState.pipState)
        Component.onCompleted: {
            item2 = (QGroundControl.videoManager.hasVideo ? videoControl :
                                                            (!QGroundControl.settingsManager.videoSettings.disableFPVVideo.value ? fpvVideoControl : null))
        }
        Connections {
            target: QGroundControl.videoManager
            function onHasVideoChanged() {
                if(QGroundControl.videoManager.hasVideo) {
                    if(_pipOverlay.item2 === fpvVideoControl) {
                        fpvVideoControl.pipState.state = fpvVideoControl.pipState.fpvState
                    }
                    _pipOverlay.item2 = videoControl
                } else {
                    if(_pipOverlay.item2 === videoControl) {
                        _pipOverlay.item2 = (!QGroundControl.settingsManager.videoSettings.disableFPVVideo.value ? fpvVideoControl : null)
                    }
                }
            }
        }
        Connections {
            target: QGroundControl.settingsManager.videoSettings.disableFPVVideo
            function onValueChanged(value) {
                if(value && _pipOverlay.item2 === fpvVideoControl) {
                    _pipOverlay.item2 = (QGroundControl.videoManager.hasVideo ? videoControl : null)
                }
            }
        }
    }

    // S98 On-screen sticks (Settings › Fly screen › On-screen sticks): two 280 px pads at y 600, left x 180 (throttle /
    // yaw), right ends at x 1360 (pitch / roll) on 1920 x 1080 — clear of the action buttons, telemetry bar, map
    // controls, PiP and camera rail. Same VirtualJoystick as the classic widget layer had.
    Loader {
        id:         virtualJoystick
        x:          Math.round(180 * _simpleScale)
        y:          Math.round(600 * _simpleScale)
        width:      Math.round(1180 * _simpleScale)
        height:     Math.round(280 * _simpleScale)
        z:          QGroundControl.zOrderWidgets
        readonly property bool _enabled: QGroundControl.settingsManager.appSettings.virtualJoystick.rawValue
                                         && !(_activeVehicle ? _activeVehicle.usingHighLatencyLink : false)
        active:     _enabled
        visible:    _enabled && !QGroundControl.videoManager.fullScreen
        source:     "qrc:/qml/VirtualJoystick.qml"
        property bool autoCenterThrottle: QGroundControl.settingsManager.appSettings.virtualJoystickAutoCenterThrottle.rawValue
    }

    // QGCPipOverlay {
    //     id:                     _pipOverlay
    //     anchors.left:           parent.left
    //     anchors.bottom:         parent.bottom
    //     anchors.margins:        _toolsMargin
    //     item1IsFullSettingsKey: "MainFlyWindowIsMap"
    //     item1:                  mapControl
    //     item2:                  QGroundControl.videoManager.hasVideo ? videoControl : null
    //     fullZOrder:             _fullItemZorder
    //     pipZOrder:              _pipItemZorder
    //     show:                   !QGroundControl.videoManager.fullScreen &&
    //                                 (videoControl.pipState.state === videoControl.pipState.pipState || mapControl.pipState.state === mapControl.pipState.pipState)
    // }

    // Loader {
    //     anchors.fill: parent
    //     z: _fullItemZorder + 2
    //     visible: !_mainWindowIsMap
    //     source: "qrc:/qml/CodevCameraVisual.qml"
    // }
}
