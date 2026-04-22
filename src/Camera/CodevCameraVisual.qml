import QtQuick          2.12
import QtPositioning    5.3
import QtQuick.Layouts  1.11
import QtQuick.Controls 2.4

import QGroundControl                   1.0
import QGroundControl.FlightDisplay     1.0
import QGroundControl.ScreenTools       1.0
import QGroundControl.Controls          1.0
import QGroundControl.Palette           1.0
import QGroundControl.Vehicle           1.0
import QGroundControl.Controllers       1.0
import QGroundControl.FactSystem        1.0
import QGroundControl.FactControls      1.0

import CustomQmlInterface 1.0

Item {
    clip: true
    property Fact _pseudocolor: _camera ? _camera.getFact("IR_PALETTE") : null
    property Fact _thermometry: _camera ? _camera.getFact("IR_THERMOMETRY") : null
    property Fact _irZoom: _camera ? _camera.getFact("IR_ZOOM") : null
    property Fact _spotAE: _camera ? _camera.getFact("EO_SPOTAE") : null
    property Fact _spotFocus: _camera ? _camera.getFact("EO_SPOTFOCUS") : null
    property Fact _dZoom: _camera ? _camera.getFact("EO_DZOOM") : null
    property Fact _tofEN: _camera ? _camera.getFact("TOF_EN") : null
    property Fact _nvStatus: _camera ? _camera.getFact("NV_STATUS") : null
    property Fact _nvDebug: _camera ? _camera.getFact("NV_DEBUG") : null
    property Fact _trackAlg: _camera ? _camera.getFact("TRACK_ALGORITHM") : null
    property Fact _smartSelect: _camera ? _camera.getFact("SMART_SELECT") : null
    property Fact _factoryCali: _camera ? _camera.getFact("FACTORY_CALI") : null
    property Fact _aiSource: _camera ? _camera.getFact("AI_SOURCE") : null
    property bool spotMeteringEnable: false
    property bool spotFocusEnable: false
    property bool aiInThermal: !(!_aiSource || _aiSource.enumIndex === 0)
    property var aiParentItem: aiInThermal ? thermalOverlayItem : videoContentOverlayItem

    property string _cameraModelUpper: _camera ? ((_camera.modelName || "").toUpperCase()) : ""
    property string _cameraVendorUpper: _camera ? ((_camera.vendor || "").toUpperCase()) : ""
    property bool _isSonyIR1: _camera && (
                                  _cameraVendorUpper.indexOf("SONY") !== -1 ||
                                  _cameraModelUpper.indexOf("SONY") !== -1 ||
                                  _cameraModelUpper.indexOf("IR1") !== -1 ||
                                  _cameraModelUpper.indexOf("IR-1") !== -1 ||
                                  _cameraModelUpper.indexOf("IR_1") !== -1 ||
                                  _cameraModelUpper.indexOf("IR 1") !== -1 ||
                                  _cameraModelUpper.indexOf("LR1") !== -1)

    property bool _hasLaserRangefinder: !_isSonyIR1 && !!_tofEN && (!_tofEN.readOnly || !!_tofEN.value || (_camera && _camera.targetDistance > 0))

    function _ensureTrackingDefaults() {
        if (_smartSelect && _smartSelect.value === "None") {
            _smartSelect.value = "Yolov8"
        }
        if (_trackAlg && _trackAlg.value === "None") {
            _trackAlg.value = "Nano"
        }
    }

    Component.onCompleted: {
        console.log("CodevCameraVisual load")
        console.log("aiInThermal = ", aiInThermal)
    }

    Connections {
        id: aviatorConnections
        target: AVIATORInterface

        Component.onCompleted: {
            console.log("QGroundControl.aviatorInterface =", AVIATORInterface)
        }

        function thermalZoomTigger(start) {
            if(start && _irZoom) {
                var v = _irZoom.value + _irZoom.increment
                if(v > (_irZoom.max + 0.01)) {
                    v = _irZoom.min
                }
                if(v > _irZoom.max) {
                    _irZoom.value = _irZoom.max
                } else {
                    _irZoom.value = v
                }
                irZoomChangedAnimator.restart()
            }
        }
        function irSwitchTigger(start) {
            if(start && QGroundControl.videoManager.hasThermal) {
                var v = _camera.thermalMode + 1
                if(v > QGCCameraControl.THERMAL_PIP) {
                    v = 0
                }
                _camera.thermalMode = v
            }
        }
        function gimbalResetTigger(start) {
            if(start) {
                _camera.centerGimbal()
            }
        }
        function buttonTakePhoto(start) {
            if(start) {
                _camera.buttonTakePhoto()
            }
        }
        function buttonToggleVideo(start) {
            if(start) {
                _camera.buttonToggleVideo()
            }
        }
        function onButtonPressed(type, pressed) {
            console.log("use onButtonPressed Function", type)
            if(type === AVIATORInterface.AVIATOR_FUNCTION_THERMAL_ZOOM) {
                thermalZoomTigger(pressed)
            } else if(type === AVIATORInterface.AVIATOR_FUNCTION_IR_SWITCH) {
                irSwitchTigger(pressed)
            } else if(type === AVIATORInterface.AVIATOR_FUNCTION_GIMBAL_RESET) {
                gimbalResetTigger(pressed)
            } else if(type === AVIATORInterface.AVIATOR_FUNCTION_CAMERA_CAPTURE) {
                buttonTakePhoto(pressed)
            } else if(type === AVIATORInterface.AVIATOR_FUNCTION_CAMERA_TOGGLE_RECORD) {
                buttonToggleVideo(pressed)
            }
        }
    }

    TargetObjectRectangles {
        x: aiParentItem.x
        y: aiParentItem.y
        width: aiParentItem.width
        height: aiParentItem.height
        visible: aiParentItem.visible
        model: _camera ? _camera.targetObjects : 0
    }

    Rectangle {
        color:              "transparent"
        border.color:       "red"
        border.width:       3
        visible:            _camera.trackingImageRect.width > 0.01 || isNaN(_camera.trackingImageRect.bottom)
        x: aiParentItem.x + _camera.trackingImageRect.x * aiParentItem.width
        y: aiParentItem.y + _camera.trackingImageRect.y * aiParentItem.height
        width: _camera.trackingImageRect.width * aiParentItem.width
        height: !isNaN(_camera.trackingImageRect.bottom) ? _camera.trackingImageRect.height * aiParentItem.height : width
        radius: !isNaN(_camera.trackingImageRect.bottom) ? 0 : (width / 2)
    }

    // MouseArea {
    //     id: trackingClickArea
    //     anchors.fill: parent
    //     z: 1
    //     hoverEnabled: true
    //     acceptedButtons: Qt.AllButtons
    //     enabled: true
    //     // cursorShape: Qt.CrossCursor

    //     onClicked: {
    //         var normX = mouse.x / width
    //         var normY = mouse.y / height
    //         var radius = 0.1

    //         console.log("Starting tracking at:", normX.toFixed(3), normY.toFixed(3))

    //         // Start tracking using the globally available camera        
    //         // Exit tracking mode    
    //     }
    // }


    Item {
        id: videoContentOverlayItem
        x: videoContentLoader.x
        y: videoContentLoader.y
        width: videoContentLoader.width
        height: videoContentLoader.height

        QGCColoredImage {
            anchors.centerIn: parent
            width:              ScreenTools.defaultFontPixelWidth * 4
            height:             width
            sourceSize.height:  width
            fillMode:           Image.PreserveAspectFit
            color:              qgcPal.colorGreen
            source:             "qrc:/qmlimages/cross_hair.svg"
            visible:            _tofEN && _tofEN.value
        }

        AreaFrame {
            width: parent.width / 15
            height: parent.height / 15
            x: _camera.spotMeteringArea.x * parent.width - width / 2
            y: _camera.spotMeteringArea.y * parent.height - height / 2
            color: qgcPal.colorOrange
            icon: "qrc:/qmlimages/sun.svg"
            visible: _camera.spotMeteringArea.x !== 0 || _camera.spotMeteringArea.y !== 0
        }

        TouchSelectArea {
            anchors.fill: parent
            enabled: parent.visible
            enableRectangle: trackRadioButton.checked && !aiInThermal
            enablePoint: spotAERadioButton.checked || (trackRadioButton.checked && !aiInThermal)
            onTouchWithPointed: (x,y) => {
                if(spotAERadioButton.checked) {
                    _camera.setSpotMetering(x, y)
                } else if(_trackAlg && _trackAlg.value !== "None" && _smartSelect && _smartSelect.value !== "None") {
                    var point = Qt.point(x, y)
                    _ensureTrackingDefaults()
                    _camera.startTracking(point, 1.0)
                    _camera.trackingEnabled = true
                }
            }
            onTouchWithRectangled: (x1,y1,x2,y2) => {
                var rec = Qt.rect(x1, y1, x2 - x1, y2 - y1)
                _ensureTrackingDefaults()
                _camera.startTracking(rec)
                _camera.trackingEnabled = true
            }
            onTouchDoubleClicked: {
                QGroundControl.videoManager.fullScreen = !QGroundControl.videoManager.fullScreen
            }
            onTouchPressAndHold: (x,y) => {
                if(!ScreenTools.isMobile) {
                    var point = Qt.point(x, y)
                    _camera.gimbalControlInImage(point)
                }
            }
        }
    }

    DeadMouseArea {
        x: thermalItem.x
        y: thermalItem.y
        width: thermalItem.width
        height: thermalItem.height
        enabled: thermalItem.visible
    }

    Rectangle {
        id: irZoomBackground
        anchors.centerIn: thermalOverlayItem
        radius: 4
        width: ScreenTools.defaultFontPixelWidth * 8
        height: ScreenTools.defaultFontPixelHeight + ScreenTools.defaultFontPixelWidth * 3
        color: qgcPal.window
        opacity: 0
        QGCLabel {
            anchors.centerIn: parent
            text: _irZoom ? "x" + _irZoom.value.toFixed(1) : "x1.0"
            font.bold: true
            font.pointSize: ScreenTools.mediumFontPointSize
        }
        OpacityAnimator {
            id: irZoomChangedAnimator
            target: irZoomBackground
            from: 1
            to: 0
            duration: 1500
            running: false
        }
    }

    Item {
        id: thermalOverlayItem
        x: thermalItem.x
        y: thermalItem.y
        width: thermalItem.width
        height: thermalItem.height
        clip: true
        visible: thermalItem.visible

        Rectangle {
            id: minTempRect
            x: _camera ? (_camera.minTempX * parent.width - width / 2) : 0
            y: _camera ? (_camera.minTempY * parent.height - height / 2)  : 0
            width: ScreenTools.defaultFontPixelWidth
            radius: width / 2
            height: width
            color: _camera.tempType !== 2 ? qgcPal.colorBlue : qgcPal.colorGreen
            border.width: 1
            border.color: "white"
            visible: _thermometry && _thermometry.value

            QGCLabel {
                property bool useRight: _camera.minTempX < 0.67
                text: _camera ? _camera.minTemp.toFixed(1) : ""
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: useRight ? parent.right : undefined
                anchors.right: useRight ? undefined : parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.5
                visible: text.length !== 0
                style: Text.Outline; styleColor: qgcPal.window
            }
        }
        Rectangle {
            id: maxTempRect
            x: _camera ? (_camera.maxTempX * parent.width - width / 2) : 0
            y: _camera ? (_camera.maxTempY * parent.height - height / 2) : 0
            width: ScreenTools.defaultFontPixelWidth
            radius: width / 2
            height: width
            color: qgcPal.colorOrange
            border.width: 1
            border.color: "white"
            visible: _thermometry && _thermometry.value && _camera.tempType !== 2

            QGCLabel {
                property bool useRight: _camera.maxTempX < 0.67
                text: _camera ? _camera.maxTemp.toFixed(1) : ""
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: useRight ? parent.right : undefined
                anchors.right: useRight ? undefined : parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.5
                visible: text.length !== 0
                style: Text.Outline; styleColor: qgcPal.window
            }
        }
        Rectangle {
            x: _camera.rectTempX1 * parent.width
            y: _camera.rectTempY1 * parent.height
            width: (_camera.rectTempX2 - _camera.rectTempX1) * parent.width
            height: (_camera.rectTempY2 - _camera.rectTempY1) * parent.height
            color: "transparent"
            border.width: 1
            border.color: "white"
            visible: _thermometry && _thermometry.value && _camera.tempType === 4
        }

        TouchSelectArea {
            anchors.fill: parent
            enabled: parent.visible && (_thermometry && _thermometry.value || trackRadioButton.checked && aiInThermal)
            onTouchWithPointed: (x,y) => {
                if(_thermometry && _thermometry.value) {
                    _camera.setSpotTempPoint(x, y)
                                        console.log("setSpotTemp Point = ", x, y)                                        
                } else if(aiInThermal) {
                    var point = Qt.point(x, y)
                    _ensureTrackingDefaults()
                    _camera.startTracking(point, 1.0)
                    _camera.trackingEnabled = true
                }
            }
            onTouchWithRectangled: (x1,y1,x2,y2) => {
                if(_thermometry && _thermometry.value) {
                    _camera.setAreaTempRect(x1,y1,x2,y2)
                } else if(aiInThermal) {
                   var rec = Qt.rect(x1, y1, x2 - x1, y2 - y1)
                   _ensureTrackingDefaults()
                   _camera.startTracking(rec)
                   _camera.trackingEnabled = true
                }
            }
        }
    }

    Rectangle {
        visible: irToolsPanel.visible
        width: irToolsPanel.width + ScreenTools.defaultFontPixelWidth
        height: irToolsPanel.height + ScreenTools.defaultFontPixelWidth * 2
        anchors.centerIn: irToolsPanel
        color: Qt.rgba(qgcPal.window.r, qgcPal.window.g, qgcPal.window.b, 0.75)
        radius: 4
        DeadMouseArea {
            anchors.fill: parent
        }
    }

    RowLayout {
        id: irToolsPanel
        anchors.bottom: parent.bottom
        anchors.bottomMargin: ScreenTools.defaultFontPixelWidth * 1.5
        anchors.right: parent.right
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth
        visible: _factoryCali ? !_factoryCali.value : true

        PseudocolorBar {
            id: pseudocolorBar
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            Layout.fillHeight: true
            width: ScreenTools.defaultFontPixelHeight * 6
            orientation: Gradient.Horizontal
            visible: thermalItem.visible && !!_pseudocolor
            Component.onCompleted: if(_pseudocolor) setPseudocolorBarIndex(_pseudocolor.enumIndex)
            Connections {
                target: _pseudocolor
                function onValueChanged() {
                    pseudocolorBar.setPseudocolorBarIndex(_pseudocolor.enumIndex)
                }
            }
            onVisibleChanged: {
                console.log("[THERMAL_UI]",
                            "pseudocolorBar.visibleChanged",
                            "visible=", visible,
                            "thermalItemVisible=", thermalItem.visible,
                            "hasPseudocolor=", !!_pseudocolor)
                if(visible && _pseudocolor) {
                    setPseudocolorBarIndex(_pseudocolor.enumIndex)
                } else {
                    checked = false
                    pseudocolorPopup.close()
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if(!pseudocolorBar.checked) {
                        pseudocolorBar.checked = true
                        pseudocolorPopup.open()
                    } else {
                        pseudocolorPopup.close()
                    }
                }
            }
        }

        ToolRadioButton {
            Layout.alignment:  Qt.AlignVCenter | Qt.AlignHCenter
            checked: _thermometry ? _thermometry.value : false
            visible: thermalItem.visible && !!_thermometry
            enabled: !!_thermometry
            source: {
                if(!checked) {
                    return "qrc:/qmlimages/thermometry.svg"
                }
                if(_camera.tempType === 2) {
                    return "qrc:/qmlimages/spot_thermometry.svg"
                } else if(_camera.tempType === 4) {
                    return "qrc:/qmlimages/area_thermometry.svg"
                } else {
                    return "qrc:/qmlimages/thermometry.svg"
                }
            }
            onClicked: {
                if (_thermometry) {
                    _thermometry.value = !_thermometry.value
                }
            }
        }

        ToolRadioButton {
            Layout.alignment:  Qt.AlignVCenter | Qt.AlignHCenter
            checked: _tofEN ? _tofEN.value : false
            visible: _hasLaserRangefinder
            source: "qrc:/qmlimages/rangefinder.svg"
            onClicked: {
                _tofEN.value = !_tofEN.value
            }
        }

        ToolRadioButton {
            id: spotAERadioButton
            Layout.alignment:  Qt.AlignVCenter | Qt.AlignHCenter
            checked: _camera.spotMeteringArea.x !== 0 || _camera.spotMeteringArea.y !== 0 || spotMeteringEnable
            visible: _spotAE
            source: "qrc:/qmlimages/sun.svg"
            onClicked: {
                if(checked) {
                    spotMeteringEnable = false
                    _camera.setSpotMetering(0, 0)
                } else {
                    spotMeteringEnable = true
                }
            }
        }

        ToolRadioButton {
            id: trackRadioButton
            Layout.alignment:  Qt.AlignVCenter | Qt.AlignHCenter
            checked: _trackAlg ? _trackAlg.value !== "None" : false
            visible: _trackAlg && !_camera.busyInDetectSetup && !_camera.busyInTrackSetup
            color: checked && enabled ? (_camera.trackingEnabled ? qgcPal.buttonHighlight : qgcPal.colorOrange) : "transparent"
            source: _smartSelect && _smartSelect.value !== "None" ? "qrc:/qmlimages/smartSelect.svg" : "qrc:/qmlimages/focus.svg"
            onClicked: {
                if(_camera.trackingEnabled) {
                    _camera.trackingEnabled = false
                    _camera.stopTracking()
                } else {
                    if(!checked) {
                        _camera.initTracker()
                    } else {
                        _camera.deinitTracker()
                    }
                }
            }
            onCheckedChanged: {
                if(checked) {
                    trackRadioButton.enabled = Qt.binding(function() { return _camera.trackingImageStatus })
                } else {
                    _camera.trackingEnabled = false
                }
            }

            Timer {
                id: trakerTimer
                interval: 30000
                running: trackRadioButton.checked
                repeat: false
                onTriggered: {
                    trackRadioButton.enabled = true
                }
            }
        }

        // QGCBusyIndicator {
        //     Layout.fillHeight: true
        //     Layout.preferredWidth: height
        //     Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
        //     //running: _camera.busyInDetectSetup || _camera.busyInTrackSetup
        //     firstColor: qgcPal.text
        //     secondColor: qgcPal.windowShade
        //     pointColor: qgcPal.windowShade
        // }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: -2
        anchors.horizontalCenter: parent.horizontalCenter
        width: rfToolRow.width + ScreenTools.defaultFontPixelWidth * 2
        height: rfToolRow.height + ScreenTools.defaultFontPixelWidth
        opacity: rfToolRow.visible ? 1 : 0
        radius: 2
        color: Qt.rgba(qgcPal.window.r, qgcPal.window.g, qgcPal.window.b, 0.75)
        DeadMouseArea {
            anchors.fill: parent
        }
        Row {
            id: rfToolRow
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1
            spacing: ScreenTools.defaultFontPixelWidth * 0.5
            visible: (_tofEN && _tofEN.value) || (_nvDebug && _nvDebug.value && _nvStatus && _nvStatus.value) || _camera.trackingEnabled
            QGCLabel {
                text: qsTr("RF:")
                visible: (_tofEN && _tofEN.value)
            }
            QGCLabel {
                text: _camera.targetDistance.toFixed(1) + " m"
                horizontalAlignment: Text.AlignRight
                width: ScreenTools.defaultFontPixelWidth * 6
                visible: (_tofEN && _tofEN.value)
            }
            QGCLabel {
                text: visible ? _camera.targetCoordinate.latitude.toFixed(7) + "," + _camera.targetCoordinate.longitude.toFixed(7) + "," + _camera.targetCoordinate.altitude.toFixed(1) : ""
                visible: _camera.targetCoordinate && _camera.targetCoordinate.isValid && (_tofEN && _tofEN.value)
            }
            QGCLabel {
                text: qsTr("TrackScore:")
                visible: _camera.trackingEnabled
            }
            QGCLabel {
                text: _camera.trackScore.toFixed(2)
                horizontalAlignment: Text.AlignRight
                width: ScreenTools.defaultFontPixelWidth * 5
                visible: _camera.trackingEnabled
            }
            QGCLabel {
                text: qsTr("Temp:")
                visible: _nvDebug && _nvDebug.value && _nvStatus && _nvStatus.value
            }
            QGCLabel {
                text: _camera.boardTemp.toFixed(1) + "°C"
                horizontalAlignment: Text.AlignRight
                visible: _nvDebug && _nvDebug.value && _nvStatus && _nvStatus.value
            }
            QGCLabel {
                text: qsTr("CPU:")
                visible: _nvDebug && _nvDebug.value && _nvStatus && _nvStatus.value
            }
            QGCLabel {
                text: _camera.cpuUsage.toFixed(1) + "%"
                horizontalAlignment: Text.AlignRight
                visible: _nvDebug && _nvDebug.value && _nvStatus && _nvStatus.value
            }
            QGCLabel {
                text: qsTr("MEM:")
                visible: _nvDebug && _nvDebug.value && _nvStatus && _nvStatus.value
            }
            QGCLabel {
                text: _camera.memUsage.toFixed(1) + "%"
                horizontalAlignment: Text.AlignRight
                visible: _nvDebug && _nvDebug.value && _nvStatus && _nvStatus.value
            }
        }
    }

    Popup {
        id: pseudocolorPopup
        modal: false
        focus: true
        padding: ScreenTools.defaultFontPixelWidth
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Qt.rgba(qgcPal.window.r, qgcPal.window.g, qgcPal.window.b, 0.9)
            radius: ScreenTools.defaultFontPixelWidth * 0.5
            border.color: qgcPal.windowShade
            border.width: 1
        }

        GridLayout {
            columns: 4
            rowSpacing: ScreenTools.defaultFontPixelWidth * 0.5
            columnSpacing: ScreenTools.defaultFontPixelWidth * 0.5

            Repeater {
                model: _pseudocolor ? _pseudocolor.enumValues : null

                Rectangle {
                    width: pseudocolorImage.width + ScreenTools.defaultFontPixelWidth * 2
                    height: pseudocolorImage.height + pseudocolorNameLabel.height + ScreenTools.defaultFontPixelWidth
                    radius: 2
                    color: _pseudocolor.enumIndex === index ? qgcPal.buttonHighlight : "transparent"

                    Image {
                        id: pseudocolorImage
                        anchors.top:        parent.top
                        anchors.left:       parent.left
                        anchors.margins:    ScreenTools.defaultFontPixelWidth
                        width:              ScreenTools.defaultFontPixelWidth * 12
                        source:             "qrc:/R3Palette/" + modelData
                        sourceSize.width:   width
                        fillMode:           Image.PreserveAspectFit
                        mipmap:             true
                    }

                    QGCLabel {
                        id:                     pseudocolorNameLabel
                        anchors.top:            pseudocolorImage.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        text:                   _pseudocolor.enumStrings[index]
                        color:                  _pseudocolor.enumIndex === index ? qgcPal.buttonHighlightText : qgcPal.buttonText
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            _pseudocolor.enumIndex = index
                            pseudocolorPopup.close()
                        }
                    }
                }
            }
        }

        function _positionPopup() {
            if (!mainWindow || !mainWindow.contentItem) {
                return
            }
            var margin = ScreenTools.defaultFontPixelWidth
            var origin = mainWindow.contentItem.mapFromItem(pseudocolorBar, 0, 0)
            var xPos = origin.x + (pseudocolorBar.width / 2) - (pseudocolorPopup.width / 2)
            xPos = Math.max(margin, Math.min(xPos, mainWindow.width - pseudocolorPopup.width - margin))
            var yAbove = origin.y - pseudocolorPopup.height - margin
            var yBelow = origin.y + pseudocolorBar.height + margin
            var yPos = yAbove >= margin ? yAbove : yBelow
            yPos = Math.max(margin, Math.min(yPos, mainWindow.height - pseudocolorPopup.height - margin))
            pseudocolorPopup.x = Math.round(xPos)
            pseudocolorPopup.y = Math.round(yPos)
        }

        onOpened: Qt.callLater(_positionPopup)
        onClosed: pseudocolorBar.checked = false
        onWidthChanged: if (visible) Qt.callLater(_positionPopup)
        onHeightChanged: if (visible) Qt.callLater(_positionPopup)
    }
}
