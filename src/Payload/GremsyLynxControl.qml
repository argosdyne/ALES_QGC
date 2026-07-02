import QtQuick                     2.12
import QtQuick.Controls            2.4

import QGroundControl              1.0
import QGroundControl.Controls     1.0
import QGroundControl.Palette      1.0
import QGroundControl.ScreenTools  1.0
import QGroundControl.Payload      1.0

// Self-contained Gremsy Lynx control panel. It owns its own payload controller
// (direct UDP/MAVLink to the payload) and does NOT depend on the active vehicle.
Rectangle {
    id:             root
    width:          ScreenTools.defaultFontPixelWidth * 34
    height:         content.height + (ScreenTools.defaultFontPixelHeight * 1.6)
    radius:         4
    color:          qgcPal.window
    border.color:   qgcPal.text
    border.width:   1

    property var vehicle: null   // accepted from the FlyView loader; intentionally unused

    property bool _up:    false
    property bool _down:  false
    property bool _left:  false
    property bool _right: false

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    GremsyLynxPayloadController { id: payload }

    function _apply() {
        payload.gimbalMove((_right ? 1 : 0) - (_left ? 1 : 0),
                           (_up ? 1 : 0) - (_down ? 1 : 0))
    }

    Component.onCompleted:  payload.connectPayload()
    Component.onDestruction: payload.disconnectPayload()
    onVisibleChanged: {
        if (!visible) {
            _up = _down = _left = _right = false
            payload.gimbalStop()
        }
    }

    Column {
        id:                 content
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        parent.top
        anchors.margins:    ScreenTools.defaultFontPixelHeight * 0.8
        spacing:            ScreenTools.defaultFontPixelHeight * 0.7

        QGCLabel {
            width:                  parent.width
            text:                   qsTr("Gremsy Lynx")
            font.bold:              true
            horizontalAlignment:    Text.AlignHCenter
        }

        Row {
            spacing: ScreenTools.defaultFontPixelWidth
            width:   parent.width

            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("IP")
            }
            QGCTextField {
                id:     ipField
                width:  ScreenTools.defaultFontPixelWidth * 16
                text:   payload.ip
                onEditingFinished: payload.ip = text
            }
            QGCButton {
                text:       payload.connected ? qsTr("Reconnect") : qsTr("Connect")
                onClicked:  { payload.disconnectPayload(); payload.connectPayload() }
            }
        }

        QGCLabel {
            width:                  parent.width
            horizontalAlignment:    Text.AlignHCenter
            text:                   payload.connected ? qsTr("Connected  •  P %1°  Y %2°")
                                        .arg(payload.pitch.toFixed(0)).arg(payload.yaw.toFixed(0))
                                                      : qsTr("Not connected")
            color:                  payload.connected ? qgcPal.colorGreen : qgcPal.colorGrey
        }

        Grid {
            id:                         directionGrid
            columns:                    3
            spacing:                    ScreenTools.defaultFontPixelWidth
            anchors.horizontalCenter:   parent.horizontalCenter

            property real buttonWidth:  ScreenTools.defaultFontPixelWidth * 9
            property real buttonHeight: ScreenTools.defaultFontPixelHeight * 2.8

            Item  { width: directionGrid.buttonWidth; height: directionGrid.buttonHeight }
            QGCButton {
                width: directionGrid.buttonWidth; height: directionGrid.buttonHeight
                text: qsTr("UP")
                onPressedChanged: { root._up = pressed; root._apply() }
            }
            Item  { width: directionGrid.buttonWidth; height: directionGrid.buttonHeight }

            QGCButton {
                width: directionGrid.buttonWidth; height: directionGrid.buttonHeight
                text: qsTr("LEFT")
                onPressedChanged: { root._left = pressed; root._apply() }
            }
            QGCButton {
                width: directionGrid.buttonWidth; height: directionGrid.buttonHeight
                text: qsTr("HOME")
                onClicked: payload.gimbalHome()
            }
            QGCButton {
                width: directionGrid.buttonWidth; height: directionGrid.buttonHeight
                text: qsTr("RIGHT")
                onPressedChanged: { root._right = pressed; root._apply() }
            }

            Item  { width: directionGrid.buttonWidth; height: directionGrid.buttonHeight }
            QGCButton {
                width: directionGrid.buttonWidth; height: directionGrid.buttonHeight
                text: qsTr("DOWN")
                onPressedChanged: { root._down = pressed; root._apply() }
            }
            Item  { width: directionGrid.buttonWidth; height: directionGrid.buttonHeight }
        }
    }
}
