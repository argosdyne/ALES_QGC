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

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0

Rectangle {
    id:             root
    color:          qgcPal.window
    anchors.fill:   parent

    readonly property real _margins: ScreenTools.defaultFontPixelHeight

    property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var joystick: joystickManager.activeJoystick
    property bool hasAnyJoystick: joystickManager.joysticks.length > 0
    property real rollValue: 0
    property real pitchValue: 0
    property real yawValue: 0
    property real throttleValue: 0
    property real rollRawValue: 0
    property real pitchRawValue: 0
    property real yawRawValue: 0
    property real throttleRawValue: 0
    property real centerOffset: 0.0
    property real leftXUnit: 0
    property real leftYUnit: 0
    property real rightXUnit: 0
    property real rightYUnit: 0
    property real leftX: 0
    property real leftY: 0
    property real rightX: 0
    property real rightY: 0
    property int lastAxisIndex: -1
    property int lastAxisValue: 0
    property int lastButtonIndex: -1
    property int lastButtonState: 0

    function _tryAutoEnableJoystickInput() {
        if (activeVehicle && joystick && !activeVehicle.joystickEnabled) {
            activeVehicle.joystickEnabled = true
        }
    }

    function _formatAxis(v) {
        return Number(v).toFixed(3)
    }

    function _toUnitFromQgcAxis(v) {
        return Number(v) / 32767.0
    }

    function _formatStick(v) {
        return Number(v).toFixed(2)
    }

    function _resetLiveValues() {
        rollValue = 0
        pitchValue = 0
        yawValue = 0
        throttleValue = 0
        rollRawValue = 0
        pitchRawValue = 0
        yawRawValue = 0
        throttleRawValue = 0
        leftXUnit = 0
        leftYUnit = 0
        rightXUnit = 0
        rightYUnit = 0
        leftX = 0
        leftY = 0
        rightX = 0
        rightY = 0
        lastAxisIndex = -1
        lastAxisValue = 0
        lastButtonIndex = -1
        lastButtonState = 0
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

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
            if (index === 0) {
                root.leftXUnit = root._toUnitFromQgcAxis(value)
                root.leftX = root.leftXUnit + root.centerOffset
                root.yawRawValue = root.leftX
            } else if (index === 1) {
                root.leftYUnit = root._toUnitFromQgcAxis(value)
                root.leftY = root.leftYUnit + root.centerOffset
                root.throttleRawValue = root.leftY
            } else if (index === 2) {
                root.rightXUnit = root._toUnitFromQgcAxis(value)
                root.rightX = root.rightXUnit + root.centerOffset
                root.rollRawValue = root.rightX
            } else if (index === 3) {
                root.rightYUnit = root._toUnitFromQgcAxis(value)
                root.rightY = root.rightYUnit + root.centerOffset
                root.pitchRawValue = root.rightY
            }
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
            root._tryAutoEnableJoystickInput()
        }
    }

    onActiveVehicleChanged: _tryAutoEnableJoystickInput()
    onJoystickChanged: _tryAutoEnableJoystickInput()

    QGCFlickable {
        anchors.fill:   parent
        contentWidth:   column.width  + (_margins * 2)
        contentHeight:  column.height + (_margins * 2)
        clip:           true

        ColumnLayout {
            id:                 column
            anchors.margins:    _margins
            anchors.left:       parent.left
            anchors.top:        parent.top
            spacing:            ScreenTools.defaultFontPixelHeight

            QGCLabel {
                text:           qsTr("Joystick Monitor")
                font.family:    ScreenTools.demiboldFontFamily
            }

            Rectangle {
                Layout.fillWidth:   true
                Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 50
                color:              qgcPal.windowShade
                radius:             ScreenTools.defaultFontPixelHeight * 0.5
                border.color:       qgcPal.text
                border.width:       1

                ColumnLayout {
                    anchors.fill:       parent
                    anchors.margins:    _margins
                    spacing:            ScreenTools.defaultFontPixelHeight * 0.5

                    GridLayout {
                        columns: 2
                        columnSpacing: ScreenTools.defaultFontPixelWidth
                        rowSpacing: ScreenTools.defaultFontPixelHeight * 0.3
                        Layout.fillWidth: true

                        QGCLabel { text: qsTr("Connected:") }
                        QGCLabel { text: hasAnyJoystick ? qsTr("Yes") : qsTr("No") }

                        QGCLabel { text: qsTr("Enabled:") }
                        QGCLabel { text: joystick ? qsTr("Yes") : qsTr("No") }

                        QGCLabel { text: qsTr("Device:") }
                        QGCLabel {
                            text: joystick ? joystick.name : qsTr("N/A")
                            wrapMode: Text.WrapAnywhere
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        color: Qt.rgba(0, 0, 0, 0)
                        border.color: qgcPal.text
                        border.width: 1
                        radius: ScreenTools.defaultFontPixelHeight * 0.5
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 8

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * 0.5
                            spacing: ScreenTools.defaultFontPixelWidth * 2

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Rectangle {
                                    id: leftStickCircle
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width, parent.height) * 0.85
                                    height: width
                                    radius: width / 2
                                    color: Qt.rgba(0, 0, 0, 0)
                                    border.color: qgcPal.text
                                    border.width: 1

                                    Rectangle {
                                        width: ScreenTools.defaultFontPixelHeight * 0.45
                                        height: width
                                        radius: width / 2
                                        color: "#00d26a"
                                        x: (leftStickCircle.width - width) / 2 + (root.leftXUnit * (leftStickCircle.width - width) / 2)
                                        y: (leftStickCircle.height - height) / 2 + (-root.leftYUnit * (leftStickCircle.height - height) / 2)
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Rectangle {
                                    id: rightStickCircle
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width, parent.height) * 0.85
                                    height: width
                                    radius: width / 2
                                    color: Qt.rgba(0, 0, 0, 0)
                                    border.color: qgcPal.text
                                    border.width: 1

                                    Rectangle {
                                        width: ScreenTools.defaultFontPixelHeight * 0.45
                                        height: width
                                        radius: width / 2
                                        color: "#00d26a"
                                        x: (rightStickCircle.width - width) / 2 + (root.rightXUnit * (rightStickCircle.width - width) / 2)
                                        y: (rightStickCircle.height - height) / 2 + (-root.rightYUnit * (rightStickCircle.height - height) / 2)
                                    }
                                }
                            }
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
                        columnSpacing: ScreenTools.defaultFontPixelWidth
                        rowSpacing: ScreenTools.defaultFontPixelHeight * 0.3
                        Layout.fillWidth: true

                        QGCLabel { text: qsTr("Left Stick:") }
                        QGCLabel { text: "X=" + root._formatStick(root.leftX) + ", Y=" + root._formatStick(root.leftY) }

                        QGCLabel { text: qsTr("Right Stick:") }
                        QGCLabel { text: "X=" + root._formatStick(root.rightX) + ", Y=" + root._formatStick(root.rightY) }

                        QGCLabel { text: qsTr("Roll (Mapped):") }
                        QGCLabel { text: root._formatAxis(root.rollValue) }

                        QGCLabel { text: qsTr("Pitch (Mapped):") }
                        QGCLabel { text: root._formatAxis(root.pitchValue) }

                        QGCLabel { text: qsTr("Yaw (Mapped):") }
                        QGCLabel { text: root._formatAxis(root.yawValue) }

                        QGCLabel { text: qsTr("Throttle (Mapped):") }
                        QGCLabel { text: root._formatAxis(root.throttleValue) }

                        QGCLabel { text: qsTr("Roll (Raw):") }
                        QGCLabel { text: root._formatAxis(root.rollRawValue) }

                        QGCLabel { text: qsTr("Pitch (Raw):") }
                        QGCLabel { text: root._formatAxis(root.pitchRawValue) }

                        QGCLabel { text: qsTr("Yaw (Raw):") }
                        QGCLabel { text: root._formatAxis(root.yawRawValue) }

                        QGCLabel { text: qsTr("Throttle (Raw):") }
                        QGCLabel { text: root._formatAxis(root.throttleRawValue) }
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
                        rowSpacing: ScreenTools.defaultFontPixelHeight * 0.3
                        Layout.fillWidth: true

                        QGCLabel { text: qsTr("Last raw axis:") }
                        QGCLabel {
                            text: root.lastAxisIndex >= 0
                                ? ("#" + root.lastAxisIndex + " = " + root.lastAxisValue)
                                : qsTr("N/A")
                            wrapMode: Text.WrapAnywhere
                            Layout.fillWidth: true
                        }

                        QGCLabel { text: qsTr("Last button:") }
                        QGCLabel {
                            text: root.lastButtonIndex >= 0
                                ? ("#" + root.lastButtonIndex + " = " + (root.lastButtonState ? qsTr("Pressed") : qsTr("Released")))
                                : qsTr("N/A")
                            wrapMode: Text.WrapAnywhere
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
