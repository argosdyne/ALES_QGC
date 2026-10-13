import QtQuick 2.12
import QtQuick.Controls 2.4
import QGroundControl 1.0
import QGroundControl.Controls 1.0
import QGroundControl.Palette 1.0
import QGroundControl.ScreenTools 1.0

Rectangle {
    id: root
    width: 500
    height: 670
    radius: 4
    color: qgcPal.window
    border.color: qgcPal.text
    border.width: 1

    property var vehicle: globals.activeVehicle ? globals.activeVehicle : QGroundControl.multiVehicleManager.activeVehicle
    property var controller: vehicle ? vehicle.nextVisionController : null
    property int rcSystemValue: controller ? controller.rcTargetSystem : 100
    property int rcComponentValue: controller ? controller.rcTargetComponent : 0
    property int pitchChannelValue: controller ? controller.pitchChannel : 9
    property int yawChannelValue: controller ? controller.yawChannel : 10
    property int zoomChannelValue: controller ? controller.zoomChannel : 11
    property int sensorChannelValue: controller ? controller.sensorChannel : 12
    property real _pitchRate: 0
    property real _yawRate: 0
    property real _zoomRate: 0
    property real _sensorRate: 0
    property real _buttonWidth: 112
    property real _buttonHeight: 48
    property real _smallButtonWidth: 92
    property bool _hasController: controller !== null
    property bool _ready: false

    function applyRcConfig() {
        if (!controller || !_ready) {
            return
        }
        controller.setRcTarget(rcSystemValue, rcComponentValue)
        controller.setRcChannels(pitchChannelValue, yawChannelValue, zoomChannelValue, sensorChannelValue)
    }

    function setRcIp(ipAddress) {
        if (!controller) {
            return
        }
        controller.setRcIpAddress(ipAddress)
    }

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, value))
    }

    function changeRcSystem(delta) {
        rcSystemValue = clamp(rcSystemValue + delta, 1, 255)
        applyRcConfig()
    }

    function changeRcComponent(delta) {
        rcComponentValue = clamp(rcComponentValue + delta, 0, 255)
        applyRcConfig()
    }

    function changePitchChannel(delta) {
        pitchChannelValue = clamp(pitchChannelValue + delta, 1, 18)
        applyRcConfig()
    }

    function changeYawChannel(delta) {
        yawChannelValue = clamp(yawChannelValue + delta, 1, 18)
        applyRcConfig()
    }

    function changeZoomChannel(delta) {
        zoomChannelValue = clamp(zoomChannelValue + delta, 1, 18)
        applyRcConfig()
    }

    function changeSensorChannel(delta) {
        sensorChannelValue = clamp(sensorChannelValue + delta, 1, 18)
        applyRcConfig()
    }

    function sendControl(pitch, yaw, zoom, sensor) {
        if (!controller) {
            return
        }
        applyRcConfig()
        _pitchRate = pitch
        _yawRate = yaw
        _zoomRate = zoom
        _sensorRate = sensor
        controller.sendRcOverride(_pitchRate, _yawRate, _zoomRate, _sensorRate)
        rcTimer.restart()
    }

    function stopControl() {
        rcTimer.stop()
        _pitchRate = 0
        _yawRate = 0
        _zoomRate = 0
        _sensorRate = 0
        if (controller) {
            applyRcConfig()
            controller.stopRcOverride()
        }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    Component.onCompleted: {
        _ready = true
        applyRcConfig()
    }

    Timer {
        id: rcTimer
        interval: 100
        repeat: true
        onTriggered: {
            if (controller) {
                controller.sendRcOverride(_pitchRate, _yawRate, _zoomRate, _sensorRate)
            }
        }
    }

    Timer {
        id: pulseStopTimer
        interval: 350
        repeat: false
        onTriggered: root.stopControl()
    }

    Column {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelHeight * 0.7

        Row {
            width: parent.width
            height: root._buttonHeight
            spacing: ScreenTools.defaultFontPixelWidth

            QGCLabel {
                width: parent.width - rtspButton.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: controller && controller.connected ? qsTr("DragonEye2 MAVLink") : qsTr("DragonEye2 RC UDP")
                font.bold: true
                elide: Text.ElideRight
            }

            QGCButton {
                id: rtspButton
                width: root._smallButtonWidth
                height: root._buttonHeight
                text: qsTr("RTSP")
                enabled: root._hasController
                onClicked: controller.configureVideoStream()
            }
        }

        QGCLabel {
            width: parent.width
            text: controller ? qsTr("%1:%2  target %3:%4")
                               .arg(controller.rcIpAddress)
                               .arg(controller.rcPort)
                               .arg(rcSystemValue)
                               .arg(rcComponentValue)
                             : qsTr("No active vehicle")
            font.pointSize: ScreenTools.smallFontPointSize
            elide: Text.ElideRight
        }

        Row {
            width: parent.width
            height: root._buttonHeight
            spacing: ScreenTools.defaultFontPixelWidth

            QGCLabel {
                width: parent.width - rcIp28Button.width - rcIp138Button.width - (parent.spacing * 2)
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("RC IP")
                font.bold: true
            }

            QGCButton {
                id: rcIp28Button
                width: 104
                height: root._buttonHeight
                text: qsTr(".28")
                enabled: root._hasController
                onClicked: root.setRcIp("192.168.2.28")
            }

            QGCButton {
                id: rcIp138Button
                width: 104
                height: root._buttonHeight
                text: qsTr(".138")
                enabled: root._hasController
                onClicked: root.setRcIp("192.168.2.138")
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: qgcPal.text
            opacity: 0.35
        }

        QGCLabel {
            text: qsTr("RC Mapping")
            font.bold: true
        }

        Grid {
            width: parent.width
            columns: 2
            rowSpacing: ScreenTools.defaultFontPixelHeight * 0.45
            columnSpacing: ScreenTools.defaultFontPixelWidth

            Row {
                width: (parent.width - ScreenTools.defaultFontPixelWidth) / 2
                height: root._buttonHeight
                spacing: 4

                QGCLabel { width: 76; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Sys") }
                QGCButton { width: 38; height: root._buttonHeight; text: qsTr("-"); enabled: root._hasController; onClicked: root.changeRcSystem(-1) }
                Rectangle {
                    width: 62
                    height: root._buttonHeight
                    color: qgcPal.windowShade
                    border.color: qgcPal.text
                    QGCLabel { anchors.centerIn: parent; text: root.rcSystemValue }
                }
                QGCButton { width: 38; height: root._buttonHeight; text: qsTr("+"); enabled: root._hasController; onClicked: root.changeRcSystem(1) }
            }

            Row {
                width: (parent.width - ScreenTools.defaultFontPixelWidth) / 2
                height: root._buttonHeight
                spacing: 4

                QGCLabel { width: 76; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Comp") }
                QGCButton { width: 38; height: root._buttonHeight; text: qsTr("-"); enabled: root._hasController; onClicked: root.changeRcComponent(-1) }
                Rectangle {
                    width: 62
                    height: root._buttonHeight
                    color: qgcPal.windowShade
                    border.color: qgcPal.text
                    QGCLabel { anchors.centerIn: parent; text: root.rcComponentValue }
                }
                QGCButton { width: 38; height: root._buttonHeight; text: qsTr("+"); enabled: root._hasController; onClicked: root.changeRcComponent(1) }
            }

            Row {
                width: (parent.width - ScreenTools.defaultFontPixelWidth) / 2
                height: root._buttonHeight
                spacing: 4

                QGCLabel { width: 76; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Pitch") }
                QGCButton { width: 38; height: root._buttonHeight; text: qsTr("-"); enabled: root._hasController; onClicked: root.changePitchChannel(-1) }
                Rectangle {
                    width: 62
                    height: root._buttonHeight
                    color: qgcPal.windowShade
                    border.color: qgcPal.text
                    QGCLabel { anchors.centerIn: parent; text: root.pitchChannelValue }
                }
                QGCButton { width: 38; height: root._buttonHeight; text: qsTr("+"); enabled: root._hasController; onClicked: root.changePitchChannel(1) }
            }

            Row {
                width: (parent.width - ScreenTools.defaultFontPixelWidth) / 2
                height: root._buttonHeight
                spacing: 4

                QGCLabel { width: 76; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Yaw") }
                QGCButton { width: 38; height: root._buttonHeight; text: qsTr("-"); enabled: root._hasController; onClicked: root.changeYawChannel(-1) }
                Rectangle {
                    width: 62
                    height: root._buttonHeight
                    color: qgcPal.windowShade
                    border.color: qgcPal.text
                    QGCLabel { anchors.centerIn: parent; text: root.yawChannelValue }
                }
                QGCButton { width: 38; height: root._buttonHeight; text: qsTr("+"); enabled: root._hasController; onClicked: root.changeYawChannel(1) }
            }

            Row {
                width: (parent.width - ScreenTools.defaultFontPixelWidth) / 2
                height: root._buttonHeight
                spacing: 4

                QGCLabel { width: 76; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Zoom") }
                QGCButton { width: 38; height: root._buttonHeight; text: qsTr("-"); enabled: root._hasController; onClicked: root.changeZoomChannel(-1) }
                Rectangle {
                    width: 62
                    height: root._buttonHeight
                    color: qgcPal.windowShade
                    border.color: qgcPal.text
                    QGCLabel { anchors.centerIn: parent; text: root.zoomChannelValue }
                }
                QGCButton { width: 38; height: root._buttonHeight; text: qsTr("+"); enabled: root._hasController; onClicked: root.changeZoomChannel(1) }
            }

            Row {
                width: (parent.width - ScreenTools.defaultFontPixelWidth) / 2
                height: root._buttonHeight
                spacing: 4

                QGCLabel { width: 76; anchors.verticalCenter: parent.verticalCenter; text: qsTr("EO/IR") }
                QGCButton { width: 38; height: root._buttonHeight; text: qsTr("-"); enabled: root._hasController; onClicked: root.changeSensorChannel(-1) }
                Rectangle {
                    width: 62
                    height: root._buttonHeight
                    color: qgcPal.windowShade
                    border.color: qgcPal.text
                    QGCLabel { anchors.centerIn: parent; text: root.sensorChannelValue }
                }
                QGCButton { width: 38; height: root._buttonHeight; text: qsTr("+"); enabled: root._hasController; onClicked: root.changeSensorChannel(1) }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: qgcPal.text
            opacity: 0.35
        }

        QGCLabel {
            text: qsTr("Gimbal")
            font.bold: true
        }

        Grid {
            columns: 3
            spacing: ScreenTools.defaultFontPixelWidth
            width: (root._buttonWidth * 3) + (spacing * 2)
            anchors.horizontalCenter: parent.horizontalCenter

            Item { width: root._buttonWidth; height: root._buttonHeight }
            QGCButton {
                width: root._buttonWidth
                height: root._buttonHeight
                text: qsTr("UP")
                enabled: root._hasController
                onPressedChanged: pressed ? root.sendControl(0.45, 0, 0, 0) : root.stopControl()
            }
            Item { width: root._buttonWidth; height: root._buttonHeight }

            QGCButton {
                width: root._buttonWidth
                height: root._buttonHeight
                text: qsTr("LEFT")
                enabled: root._hasController
                onPressedChanged: pressed ? root.sendControl(0, -0.45, 0, 0) : root.stopControl()
            }
            QGCButton {
                width: root._buttonWidth
                height: root._buttonHeight
                text: qsTr("CENTER")
                enabled: root._hasController
                onClicked: {
                    root.applyRcConfig()
                    controller.stopRcOverride()
                }
            }
            QGCButton {
                width: root._buttonWidth
                height: root._buttonHeight
                text: qsTr("RIGHT")
                enabled: root._hasController
                onPressedChanged: pressed ? root.sendControl(0, 0.45, 0, 0) : root.stopControl()
            }

            Item { width: root._buttonWidth; height: root._buttonHeight }
            QGCButton {
                width: root._buttonWidth
                height: root._buttonHeight
                text: qsTr("DOWN")
                enabled: root._hasController
                onPressedChanged: pressed ? root.sendControl(-0.45, 0, 0, 0) : root.stopControl()
            }
            Item { width: root._buttonWidth; height: root._buttonHeight }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: qgcPal.text
            opacity: 0.35
        }

        QGCLabel {
            text: qsTr("Camera")
            font.bold: true
        }

        Row {
            spacing: ScreenTools.defaultFontPixelWidth
            anchors.horizontalCenter: parent.horizontalCenter

            QGCButton {
                width: root._buttonWidth
                height: root._buttonHeight
                text: qsTr("ZOOM -")
                enabled: root._hasController
                onPressedChanged: pressed ? root.sendControl(0, 0, -0.45, 0) : root.stopControl()
            }
            QGCButton {
                width: root._buttonWidth
                height: root._buttonHeight
                text: qsTr("ZOOM +")
                enabled: root._hasController
                onPressedChanged: pressed ? root.sendControl(0, 0, 0.45, 0) : root.stopControl()
            }
        }

        Row {
            spacing: ScreenTools.defaultFontPixelWidth
            anchors.horizontalCenter: parent.horizontalCenter

            QGCButton {
                width: root._smallButtonWidth
                height: root._buttonHeight
                text: qsTr("EO")
                enabled: root._hasController
                onClicked: {
                    root.sendControl(0, 0, 0, -0.6)
                    pulseStopTimer.restart()
                }
            }
            QGCButton {
                width: root._smallButtonWidth
                height: root._buttonHeight
                text: qsTr("IR")
                enabled: root._hasController
                onClicked: {
                    root.sendControl(0, 0, 0, 0.6)
                    pulseStopTimer.restart()
                }
            }
            QGCButton {
                width: root._smallButtonWidth
                height: root._buttonHeight
                text: qsTr("STOP")
                enabled: root._hasController
                onClicked: root.stopControl()
            }
        }
    }
}
