import QtQuick 2.12
import QtQuick.Controls 2.4
import QGroundControl 1.0
import QGroundControl.Controls 1.0
import QGroundControl.Palette 1.0
import QGroundControl.ScreenTools 1.0

Rectangle {
    id: root
    width: ScreenTools.defaultFontPixelWidth * 34
    height: content.height + (ScreenTools.defaultFontPixelHeight * 1.6)
    radius: 4
    color: qgcPal.window
    border.color: qgcPal.text
    border.width: 1

    property var vehicle: globals.activeVehicle ? globals.activeVehicle : QGroundControl.multiVehicleManager.activeVehicle
    property real rate: 1.0
    property real _pitchRate: 0
    property real _yawRate: 0

    function sendRate(pitchRate, yawRate) {
        if (!vehicle) {
            return
        }
        _pitchRate = pitchRate
        _yawRate = yawRate
        vehicle.sendGremsyGimbalRate(_pitchRate, _yawRate)
        repeatTimer.restart()
    }

    function stopRate() {
        repeatTimer.stop()
        _pitchRate = 0
        _yawRate = 0
        if (vehicle) {
            vehicle.stopGremsyGimbal()
        }
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    Component.onDestruction: stopRate()
    onVisibleChanged: if (!visible) stopRate()

    Timer {
        id: repeatTimer
        interval: 100
        repeat: true
        onTriggered: {
            if (vehicle) {
                vehicle.sendGremsyGimbalRate(root._pitchRate, root._yawRate)
            }
        }
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: ScreenTools.defaultFontPixelHeight * 0.8
        spacing: ScreenTools.defaultFontPixelHeight * 0.7

        QGCLabel {
            width: parent.width
            text: qsTr("Gremsy Lynx")
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        Grid {
            id: directionGrid
            columns: 3
            spacing: ScreenTools.defaultFontPixelWidth
            anchors.horizontalCenter: parent.horizontalCenter

            property real buttonWidth: ScreenTools.defaultFontPixelWidth * 9
            property real buttonHeight: ScreenTools.defaultFontPixelHeight * 2.8

            Item {
                width: directionGrid.buttonWidth
                height: directionGrid.buttonHeight
            }

            QGCButton {
                width: directionGrid.buttonWidth
                height: directionGrid.buttonHeight
                text: qsTr("UP")
                enabled: root.vehicle !== null
                onPressedChanged: pressed ? root.sendRate(root.rate, 0) : root.stopRate()
            }

            Item {
                width: directionGrid.buttonWidth
                height: directionGrid.buttonHeight
            }

            QGCButton {
                width: directionGrid.buttonWidth
                height: directionGrid.buttonHeight
                text: qsTr("LEFT")
                enabled: root.vehicle !== null
                onPressedChanged: pressed ? root.sendRate(0, -root.rate) : root.stopRate()
            }

            Item {
                width: directionGrid.buttonWidth
                height: directionGrid.buttonHeight
            }

            QGCButton {
                width: directionGrid.buttonWidth
                height: directionGrid.buttonHeight
                text: qsTr("RIGHT")
                enabled: root.vehicle !== null
                onPressedChanged: pressed ? root.sendRate(0, root.rate) : root.stopRate()
            }

            Item {
                width: directionGrid.buttonWidth
                height: directionGrid.buttonHeight
            }

            QGCButton {
                width: directionGrid.buttonWidth
                height: directionGrid.buttonHeight
                text: qsTr("DOWN")
                enabled: root.vehicle !== null
                onPressedChanged: pressed ? root.sendRate(-root.rate, 0) : root.stopRate()
            }

            Item {
                width: directionGrid.buttonWidth
                height: directionGrid.buttonHeight
            }
        }
    }
}
