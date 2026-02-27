/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.11
import QtQuick.Controls 2.4
import QtQuick.Layouts  1.11

import QGroundControl             1.0
import QGroundControl.Controls    1.0
import QGroundControl.ScreenTools 1.0
import QGroundControl.Palette     1.0

Item {
    id: root

    signal closeRequested()

    property var joystick: joystickManager.activeJoystick
    property real rollValue: 0
    property real pitchValue: 0
    property real yawValue: 0
    property real throttleValue: 0
    property int lastAxisIndex: -1
    property int lastAxisValue: 0
    property int lastButtonIndex: -1
    property int lastButtonState: 0

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    function _formatAxis(v) {
        return Number(v).toFixed(3)
    }

    function _resetLiveValues() {
        rollValue = 0
        pitchValue = 0
        yawValue = 0
        throttleValue = 0
        lastAxisIndex = -1
        lastAxisValue = 0
        lastButtonIndex = -1
        lastButtonState = 0
    }

    Connections {
        target: joystick
        ignoreUnknownSignals: true

        function onAxisValues(roll, pitch, yaw, throttle) {
            root.rollValue = roll
            root.pitchValue = pitch
            root.yawValue = yaw
            root.throttleValue = throttle
        }

        function onRawAxisValueChanged(index, value) {
            root.lastAxisIndex = index
            root.lastAxisValue = value
        }

        function onRawButtonPressedChanged(index, pressed) {
            root.lastButtonIndex = index
            root.lastButtonState = pressed
        }
    }

    Connections {
        target: joystickManager

        function onActiveJoystickChanged() {
            root._resetLiveValues()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.72)
    }

    Rectangle {
        id: panel
        width: Math.min(parent.width * 0.9, ScreenTools.defaultFontPixelWidth * 70)
        radius: ScreenTools.defaultFontPixelHeight * 0.5
        color: qgcPal.window
        border.color: qgcPal.text
        anchors.centerIn: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: ScreenTools.defaultFontPixelHeight
            spacing: ScreenTools.defaultFontPixelHeight * 0.8

            QGCLabel {
                text: qsTr("Joystick Startup Monitor")
                font.family: ScreenTools.demiboldFontFamily
                font.pointSize: ScreenTools.mediumFontPointSize
                Layout.alignment: Qt.AlignHCenter
            }

            GridLayout {
                columns: 2
                columnSpacing: ScreenTools.defaultFontPixelWidth
                rowSpacing: ScreenTools.defaultFontPixelHeight * 0.35
                Layout.fillWidth: true

                QGCLabel { text: qsTr("Connected:") }
                QGCLabel {
                    text: joystick ? qsTr("Yes") : qsTr("No")
                    color: joystick ? qgcPal.text : qgcPal.warningText
                }

                QGCLabel { text: qsTr("Enabled:") }
                QGCLabel {
                    text: (globals.activeVehicle && globals.activeVehicle.joystickEnabled) ? qsTr("Yes") : qsTr("No")
                    color: (globals.activeVehicle && globals.activeVehicle.joystickEnabled) ? qgcPal.text : qgcPal.warningText
                }

                QGCLabel { text: qsTr("Device:") }
                QGCLabel {
                    text: joystick ? joystick.name : qsTr("No active joystick")
                    wrapMode: QGCLabel.WrapAnywhere
                    Layout.fillWidth: true
                }

                QGCLabel { text: qsTr("Axis count:") }
                QGCLabel { text: joystick ? joystick.axisCount : 0 }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: qgcPal.text
                opacity: 0.25
            }

            GridLayout {
                columns: 2
                columnSpacing: ScreenTools.defaultFontPixelWidth
                rowSpacing: ScreenTools.defaultFontPixelHeight * 0.35
                Layout.fillWidth: true

                QGCLabel { text: qsTr("Roll:") }
                QGCLabel { text: root._formatAxis(root.rollValue) }

                QGCLabel { text: qsTr("Pitch:") }
                QGCLabel { text: root._formatAxis(root.pitchValue) }

                QGCLabel { text: qsTr("Yaw:") }
                QGCLabel { text: root._formatAxis(root.yawValue) }

                QGCLabel { text: qsTr("Throttle:") }
                QGCLabel { text: root._formatAxis(root.throttleValue) }

                QGCLabel { text: qsTr("Last raw axis:") }
                QGCLabel {
                    text: root.lastAxisIndex >= 0
                        ? ("#" + root.lastAxisIndex + " = " + root.lastAxisValue)
                        : qsTr("N/A")
                }

                QGCLabel { text: qsTr("Last button:") }
                QGCLabel {
                    text: root.lastButtonIndex >= 0
                        ? ("#" + root.lastButtonIndex + " = " + (root.lastButtonState ? qsTr("Pressed") : qsTr("Released")))
                        : qsTr("N/A")
                }
            }

            QGCLabel {
                Layout.fillWidth: true
                wrapMode: QGCLabel.WordWrap
                text: qsTr("Move the joystick to verify real-time input before entering Fly View.")
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: ScreenTools.defaultFontPixelWidth

                QGCButton {
                    text: qsTr("Close")
                    onClicked: root.closeRequested()
                }
            }
        }
    }
}
