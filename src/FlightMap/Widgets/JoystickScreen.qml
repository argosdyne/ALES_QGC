/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.11
import QtQuick.Layouts  1.11

import QGroundControl             1.0
import QGroundControl.Controls    1.0
import QGroundControl.ScreenTools 1.0
import QGroundControl.Palette     1.0

Item {
    id: root

    implicitHeight: content.implicitHeight

    property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var joystick: joystickManager.activeJoystick

    property real rollValue: 0
    property real pitchValue: 0
    property real yawValue: 0
    property real throttleValue: 0

    property int lastAxisIndex: -1
    property int lastAxisValue: 0
    property int lastButtonIndex: -1
    property int lastButtonState: 0

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

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

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
        id: panel
        anchors.fill: parent
        color: qgcPal.window
        radius: ScreenTools.defaultFontPixelHeight * 0.5
        border.color: qgcPal.text
        border.width: 1

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.75
            spacing: ScreenTools.defaultFontPixelHeight * 0.4

            QGCLabel {
                text: qsTr("Joystick")
                font.family: ScreenTools.demiboldFontFamily
                Layout.alignment: Qt.AlignHCenter
            }

            GridLayout {
                columns: 2
                Layout.fillWidth: true
                columnSpacing: ScreenTools.defaultFontPixelWidth
                rowSpacing: ScreenTools.defaultFontPixelHeight * 0.3

                QGCLabel { text: qsTr("Connected:") }
                QGCLabel { text: joystick ? qsTr("Yes") : qsTr("No") }

                QGCLabel { text: qsTr("Enabled:") }
                QGCLabel { text: (activeVehicle && activeVehicle.joystickEnabled) ? qsTr("Yes") : qsTr("No") }

                QGCLabel { text: qsTr("Device:") }
                QGCLabel {
                    text: joystick ? joystick.name : qsTr("N/A")
                    wrapMode: QGCLabel.WrapAnywhere
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: qgcPal.text
                opacity: 0.25
            }

            GridLayout {
                columns: 2
                Layout.fillWidth: true
                columnSpacing: ScreenTools.defaultFontPixelWidth
                rowSpacing: ScreenTools.defaultFontPixelHeight * 0.3

                QGCLabel { text: qsTr("Roll:") }
                QGCLabel { text: root._formatAxis(root.rollValue) }

                QGCLabel { text: qsTr("Pitch:") }
                QGCLabel { text: root._formatAxis(root.pitchValue) }

                QGCLabel { text: qsTr("Yaw:") }
                QGCLabel { text: root._formatAxis(root.yawValue) }

                QGCLabel { text: qsTr("Throttle:") }
                QGCLabel { text: root._formatAxis(root.throttleValue) }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: qgcPal.text
                opacity: 0.25
            }

            GridLayout {
                columns: 2
                Layout.fillWidth: true
                columnSpacing: ScreenTools.defaultFontPixelWidth

                QGCLabel { text: qsTr("Axis:") }
                QGCLabel {
                    text: root.lastAxisIndex >= 0
                        ? ("#" + root.lastAxisIndex + " = " + root.lastAxisValue)
                        : qsTr("N/A")
                    wrapMode: QGCLabel.WrapAnywhere
                    Layout.fillWidth: true
                }

                QGCLabel { text: qsTr("Button:") }
                QGCLabel {
                    text: root.lastButtonIndex >= 0
                        ? ("#" + root.lastButtonIndex + " = " + (root.lastButtonState ? qsTr("Pressed") : qsTr("Released")))
                        : qsTr("N/A")
                    wrapMode: QGCLabel.WrapAnywhere
                    Layout.fillWidth: true
                }
            }
        }
    }
}
