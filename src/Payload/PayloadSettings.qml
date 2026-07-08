import QtQuick                     2.12
import QtQuick.Controls            2.4
import QtQuick.Layouts            1.12

import QGroundControl              1.0
import QGroundControl.Controls     1.0
import QGroundControl.Palette      1.0
import QGroundControl.ScreenTools  1.0
import QGroundControl.Payload      1.0

// Application Settings > Payload tab. Add / configure / test a payload.
// The controllers live in the PayloadManager singleton (app lifetime), so a connected
// payload keeps streaming and the USB joystick keeps controlling it after you leave this page.
Rectangle {
    id:                 _root
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    property var  payload: PayloadManager.activeType === 0 ? PayloadManager.gremsy : PayloadManager.nextvision
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

    // Safety net: if the page is destroyed while a d-pad button is held, halt that motion
    // (but keep the payload connected — the joystick keeps driving it from other screens).
    Component.onDestruction: {
        if (payload && (_up || _down || _left || _right)) {
            payload.gimbalStop()
        }
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
                text:       qsTr("Select a payload type and its IP address, then Connect.")
            }

            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth
                QGCLabel { text: qsTr("Payload type"); Layout.preferredWidth: _root._labelWidth }
                QGCComboBox {
                    id:                     typeCombo
                    Layout.preferredWidth:  _root._fieldWidth
                    model:                  [ qsTr("Gremsy Lynx"), qsTr("NextVision DragonEye2") ]
                    currentIndex:           PayloadManager.activeType
                    onActivated: {
                        PayloadManager.activeType = currentIndex
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
                    property bool active: _root.payload.connected || _root.payload.connecting
                    text:       active ? qsTr("Disconnect") : qsTr("Connect")
                    onClicked:  active ? _root.payload.disconnectPayload()
                                       : _root.payload.connectPayload()
                }
                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:  _root.payload.connected  ? qsTr("Connected")
                         : _root.payload.connecting ? qsTr("Connecting…")
                         : _root.payload.linkFailed ? qsTr("Cannot connect")
                         :                            qsTr("Not connected")
                    color: _root.payload.connected  ? qgcPal.colorGreen
                         : _root.payload.linkFailed ? qgcPal.colorRed
                         :                            qgcPal.colorGrey
                }
            }

            QGCLabel {
                width:      parent.width
                wrapMode:   Text.WordWrap
                color:      qgcPal.colorGrey
                text:       qsTr("RTSP: ") + _root.payload.rtspUrl
            }

            QGCLabel {
                visible: _root.payload.connected
                color:   qgcPal.text
                text:    qsTr("Attitude   Pitch %1°   Yaw %2°")
                            .arg(_root.payload.pitch.toFixed(0))
                            .arg(_root.payload.yaw.toFixed(0))
            }

        Rectangle { visible: false; width: parent.width; height: 1; color: qgcPal.text; opacity: 0.3 }

            QGCLabel { text: qsTr("Gimbal control  (also controllable by USB joystick from any screen)"); font.bold: true; visible: false }

            Grid {
                id:         dpad
                visible:    false
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

            Rectangle { width: parent.width; height: 1; color: qgcPal.text; opacity: 0.3; visible: false }

            QGCLabel { text: qsTr("Camera control"); font.bold: true; visible: false }

            RowLayout {
                visible: false
                spacing: ScreenTools.defaultFontPixelWidth
                enabled: _root.payload.connected

                QGCButton {
                    text: qsTr("Home")
                    onClicked: _root.payload.gimbalHome()
                }
                QGCButton {
                    text: qsTr("Zoom In")
                    onPressedChanged: pressed ? _root.payload.zoomIn() : _root.payload.stopZoom()
                }
                QGCButton {
                    text: qsTr("Zoom Out")
                    onPressedChanged: pressed ? _root.payload.zoomOut() : _root.payload.stopZoom()
                }
                QGCButton {
                    text: qsTr("Snapshot")
                    onClicked: _root.payload.captureImage()
                }
            }

            RowLayout {
                visible: false
                spacing: ScreenTools.defaultFontPixelWidth
                enabled: _root.payload.connected

                QGCButton {
                    text: qsTr("Record")
                    onClicked: _root.payload.startRecording()
                }
                QGCButton {
                    text: qsTr("Stop Record")
                    onClicked: _root.payload.stopRecording()
                }
            }
        }
    }
}
