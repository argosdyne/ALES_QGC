/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.3
import QtQuick.Controls 1.2
import QtQuick.Layouts  1.2

import QGroundControl             1.0
import QGroundControl.Controls    1.0
import QGroundControl.ScreenTools 1.0
import QGroundControl.Palette     1.0

Rectangle {
    id: root
    color: qgcPal.window
    anchors.fill: parent
    anchors.margins: ScreenTools.defaultFontPixelWidth

    property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property var joystick: joystickManager.activeJoystick
    property bool hasAnyJoystick: joystickManager.joysticks.length > 0

    property real rollValue: 0
    property real pitchValue: 0
    property real yawValue: 0
    property real throttleValue: 0
    property real centerOffset: 0.25
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

    property real _margins: ScreenTools.defaultFontPixelWidth
    property real _panelWidth: root.width * 0.8

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
        leftX = 0
        leftY = 0
        rightX = 0
        rightY = 0
        lastAxisIndex = -1
        lastAxisValue = 0
        lastButtonIndex = -1
        lastButtonState = 0
    }

    QGCPalette { id: qgcPal }

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
                root.leftX = root._toUnitFromQgcAxis(value) + root.centerOffset
            } else if (index === 1) {
                root.leftY = root._toUnitFromQgcAxis(value) + root.centerOffset
            } else if (index === 2) {
                root.rightX = root._toUnitFromQgcAxis(value) + root.centerOffset
            } else if (index === 3) {
                root.rightY = root._toUnitFromQgcAxis(value) + root.centerOffset
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
        anchors.fill: parent
        clip: true
        contentHeight: outerItem.height
        contentWidth: outerItem.width

        Item {
            id: outerItem
            width: Math.max(root.width, settingsColumn.width)
            height: settingsColumn.height + (root._margins * 2)

            ColumnLayout {
                id: settingsColumn
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root._margins

                QGCLabel {
                    text: qsTr("Joystick Monitor")
                    font.family: ScreenTools.demiboldFontFamily
                }

                Rectangle {
                    Layout.preferredWidth: root._panelWidth
                    Layout.fillWidth: true
                    Layout.preferredHeight: statusGrid.implicitHeight + (root._margins * 2)
                    color: qgcPal.windowShade

                    GridLayout {
                        id: statusGrid
                        anchors.fill: parent
                        anchors.margins: root._margins
                        columns: 2
                        columnSpacing: ScreenTools.defaultFontPixelWidth
                        rowSpacing: ScreenTools.defaultFontPixelHeight * 0.3

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

                        QGCLabel { text: qsTr("Axis count:") }
                        QGCLabel { text: joystick ? joystick.axisCount : 0 }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: root._panelWidth
                    Layout.fillWidth: true
                    Layout.preferredHeight: axisGrid.implicitHeight + (root._margins * 2)
                    color: qgcPal.windowShade

                    GridLayout {
                        id: axisGrid
                        anchors.fill: parent
                        anchors.margins: root._margins
                        columns: 2
                        columnSpacing: ScreenTools.defaultFontPixelWidth
                        rowSpacing: ScreenTools.defaultFontPixelHeight * 0.3

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
                    }
                }

                Rectangle {
                    Layout.preferredWidth: root._panelWidth
                    Layout.fillWidth: true
                    Layout.preferredHeight: rawGrid.implicitHeight + (root._margins * 2)
                    color: qgcPal.windowShade

                    GridLayout {
                        id: rawGrid
                        anchors.fill: parent
                        anchors.margins: root._margins
                        columns: 2
                        columnSpacing: ScreenTools.defaultFontPixelWidth
                        rowSpacing: ScreenTools.defaultFontPixelHeight * 0.3

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
