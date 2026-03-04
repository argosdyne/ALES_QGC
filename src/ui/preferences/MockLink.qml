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

    readonly property real _margins: ScreenTools.defaultFontPixelHeight * 0.6

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
    property real leftXAutoOffset: 0.0
    property real leftYAutoOffset: 0.0
    property real rightXAutoOffset: 0.0
    property real rightYAutoOffset: 0.0
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

    function _applyAutoCenter(unitValue, offsetPropName) {
        const rawUnit = Number(unitValue)
        let offset = Number(root[offsetPropName])
        let centered = rawUnit + offset

        // Learn center bias only when axis is already near center.
        if (Math.abs(centered) < 0.35) {
            offset = (offset * 0.98) + ((-rawUnit) * 0.02)
            root[offsetPropName] = offset
            centered = rawUnit + offset
        }

        if (Math.abs(centered) < 0.02) {
            centered = 0
        }
        return Math.max(-1, Math.min(1, centered))
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
        leftXAutoOffset = 0
        leftYAutoOffset = 0
        rightXAutoOffset = 0
        rightYAutoOffset = 0
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
                root.leftXUnit = root._applyAutoCenter(root._toUnitFromQgcAxis(value), "leftXAutoOffset")
                root.leftX = root.leftXUnit + root.centerOffset
                root.yawRawValue = root.leftX
            } else if (index === 1) {
                root.leftYUnit = root._applyAutoCenter(root._toUnitFromQgcAxis(value), "leftYAutoOffset")
                root.leftY = root.leftYUnit + root.centerOffset
                root.throttleRawValue = root.leftY
            } else if (index === 2) {
                root.rightXUnit = root._applyAutoCenter(root._toUnitFromQgcAxis(value), "rightXAutoOffset")
                root.rightX = root.rightXUnit + root.centerOffset
                root.rollRawValue = root.rightX
            } else if (index === 3) {
                root.rightYUnit = root._applyAutoCenter(root._toUnitFromQgcAxis(value), "rightYAutoOffset")
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: _margins
        spacing: _margins

        QGCLabel {
            text: qsTr("Joystick Monitor")
            font.family: ScreenTools.demiboldFontFamily
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: qgcPal.windowShade
            radius: ScreenTools.defaultFontPixelHeight * 0.4
            border.color: qgcPal.text
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: _margins
                spacing: ScreenTools.defaultFontPixelWidth

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: _margins

                        QGCLabel { text: qsTr("Sticks") }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 10
                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 12
                            color: Qt.rgba(0, 0, 0, 0)
                            border.color: qgcPal.text
                            border.width: 1
                            radius: ScreenTools.defaultFontPixelHeight * 0.4

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: _margins
                                spacing: ScreenTools.defaultFontPixelWidth

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
                                            width: ScreenTools.defaultFontPixelHeight * 0.40
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
                                            width: ScreenTools.defaultFontPixelHeight * 0.40
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

                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.right: parent.right
                        spacing: ScreenTools.defaultFontPixelHeight * 0.2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth
                            QGCLabel { text: qsTr("Connected:") }
                            QGCLabel { text: hasAnyJoystick ? qsTr("Yes") : qsTr("No") }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth
                            QGCLabel { text: qsTr("Enabled:") }
                            QGCLabel { text: joystick ? qsTr("Yes") : qsTr("No") }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth
                            QGCLabel { text: qsTr("Device:") }
                            QGCLabel {
                                text: joystick ? joystick.name : qsTr("N/A")
                                wrapMode: Text.WrapAnywhere
                                Layout.fillWidth: true
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth
                            QGCLabel { text: qsTr("Roll:") }
                            QGCLabel { text: root._formatAxis(root.rollValue) }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth
                            QGCLabel { text: qsTr("Throttle:") }
                            QGCLabel { text: root._formatAxis(root.throttleValue) }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth
                            QGCLabel { text: qsTr("Left X/Y:") }
                            QGCLabel { text: "X=" + root._formatStick(root.leftX) + ", Y=" + root._formatStick(root.leftY) }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth
                            QGCLabel { text: qsTr("Right X/Y:") }
                            QGCLabel { text: "X=" + root._formatStick(root.rightX) + ", Y=" + root._formatStick(root.rightY) }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth
                            QGCLabel { text: qsTr("Pitch:") }
                            QGCLabel { text: root._formatAxis(root.pitchValue) }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth
                            QGCLabel { text: qsTr("Yaw:") }
                            QGCLabel { text: root._formatAxis(root.yawValue) }
                        }
                    }
                }
            }
        }
    }
}
