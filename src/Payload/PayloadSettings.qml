import QtQuick                     2.12
import QtQuick.Controls            2.4
import QtQuick.Layouts            1.12

import QGroundControl              1.0
import QGroundControl.Controls     1.0
import QGroundControl.Palette      1.0
import QGroundControl.ScreenTools  1.0
import QGroundControl.Payload      1.0

// Application Settings > Payload tab. Add / configure / test a payload.
// Payloads connect directly over their own network (independent of any vehicle),
// so this page can drive them on the bench without an aircraft connected.
Rectangle {
    id:                 _root
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    // The two registered payload controllers. Only the selected one is connected.
    GremsyLynxPayloadController { id: gremsy }
    NextVisionPayloadController { id: nextvision }

    property var  payload: typeCombo.currentIndex === 0 ? gremsy : nextvision
    property real _fieldWidth: ScreenTools.defaultFontPixelWidth * 28
    property real _labelWidth: ScreenTools.defaultFontPixelWidth * 12

    property bool _up:    false
    property bool _down:  false
    property bool _left:  false
    property bool _right: false

    function _apply() {
        payload.gimbalMove((_right ? 1 : 0) - (_left ? 1 : 0),
                           (_up ? 1 : 0) - (_down ? 1 : 0))
    }

    Component.onDestruction: {
        gremsy.disconnectPayload()
        nextvision.disconnectPayload()
    }

    QGCFlickable {
        clip:           true
        anchors.fill:   parent
        contentHeight:  col.height
        contentWidth:   col.width

        Column {
            id:         col
            width:      _root.width - ScreenTools.defaultFontPixelWidth * 2
            spacing:    ScreenTools.defaultFontPixelHeight

            QGCLabel {
                text:           qsTr("Payload")
                font.pointSize: ScreenTools.largeFontPointSize
            }

            QGCLabel {
                width:      parent.width
                wrapMode:   Text.WordWrap
                color:      qgcPal.text
                text:       qsTr("Select a payload type and its IP address, then Connect. The payload is reached directly over its own network — no vehicle connection is required.")
            }

            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth
                QGCLabel { text: qsTr("Payload type"); Layout.preferredWidth: _root._labelWidth }
                QGCComboBox {
                    id:                     typeCombo
                    Layout.preferredWidth:  _root._fieldWidth
                    model:                  [ qsTr("Gremsy Lynx"), qsTr("NextVision DragonEye2") ]
                    onActivated: {
                        gremsy.disconnectPayload()
                        nextvision.disconnectPayload()
                        _root._up = _root._down = _root._left = _root._right = false
                    }
                }
            }

            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth
                QGCLabel { text: qsTr("IP address"); Layout.preferredWidth: _root._labelWidth }
                QGCTextField {
                    id:                     ipField
                    Layout.preferredWidth:  _root._fieldWidth
                    text:                   _root.payload.ip
                    onEditingFinished:      _root.payload.ip = text
                }
            }

            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth
                QGCButton {
                    text:       _root.payload.connected ? qsTr("Disconnect") : qsTr("Connect")
                    onClicked:  _root.payload.connected ? _root.payload.disconnectPayload()
                                                        : _root.payload.connectPayload()
                }
                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:  _root.payload.connected ? qsTr("Connected") : qsTr("Not connected")
                    color: _root.payload.connected ? qgcPal.colorGreen : qgcPal.colorGrey
                }
            }

            QGCLabel {
                width:      parent.width
                wrapMode:   Text.WordWrap
                color:      qgcPal.colorGrey
                text:       qsTr("RTSP: ") + _root.payload.rtspUrl
            }

            Rectangle { width: parent.width; height: 1; color: qgcPal.text; opacity: 0.3 }

            QGCLabel { text: qsTr("Gimbal control"); font.bold: true }

            Grid {
                id:         dpad
                columns:    3
                spacing:    ScreenTools.defaultFontPixelWidth
                enabled:    _root.payload.connected

                property real bw: ScreenTools.defaultFontPixelWidth * 12
                property real bh: ScreenTools.defaultFontPixelHeight * 3

                Item      { width: dpad.bw; height: dpad.bh }
                QGCButton {
                    width: dpad.bw; height: dpad.bh; text: qsTr("UP")
                    onPressedChanged: { _root._up = pressed; _root._apply() }
                }
                Item      { width: dpad.bw; height: dpad.bh }

                QGCButton {
                    width: dpad.bw; height: dpad.bh; text: qsTr("LEFT")
                    onPressedChanged: { _root._left = pressed; _root._apply() }
                }
                QGCButton {
                    width: dpad.bw; height: dpad.bh; text: qsTr("STOP")
                    onClicked: { _root._up = _root._down = _root._left = _root._right = false; _root.payload.gimbalStop() }
                }
                QGCButton {
                    width: dpad.bw; height: dpad.bh; text: qsTr("RIGHT")
                    onPressedChanged: { _root._right = pressed; _root._apply() }
                }

                Item      { width: dpad.bw; height: dpad.bh }
                QGCButton {
                    width: dpad.bw; height: dpad.bh; text: qsTr("DOWN")
                    onPressedChanged: { _root._down = pressed; _root._apply() }
                }
                Item      { width: dpad.bw; height: dpad.bh }
            }
        }
    }
}
