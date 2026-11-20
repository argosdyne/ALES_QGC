/****************************************************************************
 * AQGC Simple UI — Settings › Devices › USB gamepad (Advanced mode; Figma S95 169:45278, 2026-11-18).
 * Replaces the classic Vehicle Setup › Joystick page: choose the gamepad, use it for this drone
 * (vehicle.joystickEnabled, needs a calibration), live axes and buttons, calibration sheet
 * (JoystickConfigController, created only while the sheet is open), stick layout, throttle mode, button actions.
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import QGroundControl.Controllers 1.0
import "."

Column {
    id: gp
    signal backRequested()
    spacing: SimpleTheme.px(16)

    readonly property var  _jm:   typeof joystickManager !== "undefined" ? joystickManager : null
    readonly property var  _joy:  _jm ? _jm.activeJoystick : null
    readonly property var  _veh:  QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool _buttonsOnly: !!_joy && _joy.axisCount === 0
    readonly property bool _calOk: !!_joy && (_joy.calibrated || _buttonsOnly)
    property var  axes: []             // raw axis values, -32768..32767
    property var  pressed: ({})        // button index → true
    property int  rev: 0

    Connections {
        target: gp._joy
        ignoreUnknownSignals: true
        function onRawAxisValueChanged(index, value) {
            var a = gp.axes.slice(); while (a.length <= index) a.push(0); a[index] = value; gp.axes = a
        }
        function onRawButtonPressedChanged(index, isPressed) {
            var p = gp.pressed; p[index] = !!isPressed; gp.pressed = p; gp.rev++
        }
    }

    Row {
        spacing: SimpleTheme.px(20)
        SButton { designHeight: 64; textSize: 24; icon: "back"; text: qsTr("Devices"); onClicked: gp.backRequested() }
        SText { text: qsTr("USB gamepad"); size: 40; bold: true; anchors.verticalCenter: parent.verticalCenter }
    }
    SText {
        width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
        text: qsTr("Fly with a USB or Bluetooth gamepad instead of the on-screen sticks. The radio controller stays the main control.")
    }

    SNotice {
        visible: !gp._joy
        width: parent.width; level: "info"
        text: qsTr("No gamepad found. Plug one in by USB or pair it by Bluetooth.")
    }

    // ------------------------------------------------ Gamepad card
    Rectangle {
        visible: !!gp._joy
        width: parent.width; height: gCol.height + SimpleTheme.px(44)
        radius: SimpleTheme.px(20); color: SimpleTheme.surfaceRaised
        Column {
            id: gCol
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: SimpleTheme.px(22); anchors.leftMargin: SimpleTheme.px(28)
            spacing: SimpleTheme.px(16)
            Item {
                width: parent.width; height: SimpleTheme.px(48)
                SText { anchors.verticalCenter: parent.verticalCenter; width: parent.width - calChip.width - SimpleTheme.px(20); elide: Text.ElideRight
                        text: gp._joy ? gp._joy.name : ""; size: 30; medium: true }
                SStatusChip { id: calChip; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                              text: gp._buttonsOnly ? qsTr("Buttons only") : gp._calOk ? qsTr("Calibrated") : qsTr("Not calibrated")
                              level: gp._calOk ? "ok" : "warn" }
            }
            Row {
                visible: !!gp._jm && gp._jm.joystickNames.length > 1
                spacing: SimpleTheme.px(16)
                SText { text: qsTr("Gamepad"); size: 24; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                SComboBox {
                    designWidth: 520
                    model: gp._jm ? gp._jm.joystickNames : []
                    currentIndex: gp._jm ? Math.max(0, gp._jm.joystickNames.indexOf(gp._jm.activeJoystickName)) : 0
                    onActivated: gp._jm.activeJoystickName = gp._jm.joystickNames[index]
                }
            }
            Row {
                spacing: SimpleTheme.px(16)
                SToggle {
                    id: useToggle
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: gp._calOk && !!gp._veh ? 1 : 0.4
                    checked: !!gp._veh && gp._veh.joystickEnabled && gp._calOk
                    onToggled: {
                        if (gp._calOk && gp._veh) {
                            gp._veh.joystickEnabled = checked
                            gp._veh.saveJoystickSettings()
                            if (checked) QGroundControl.settingsManager.appSettings.virtualJoystick.rawValue = false
                        }
                    }
                }
                SText { anchors.verticalCenter: parent.verticalCenter; size: 24; medium: true; text: qsTr("Use the gamepad for this drone") }
                SText { anchors.verticalCenter: parent.verticalCenter; size: 22; color: SimpleTheme.textSecondary
                        text: !gp._veh ? qsTr("· connect a drone first") : !gp._calOk ? qsTr("· calibrate first") : qsTr("· turns the on-screen sticks off") }
            }

            // live axes
            Column {
                visible: !gp._buttonsOnly
                width: parent.width
                spacing: SimpleTheme.px(8)
                SText { text: qsTr("Axes (move the sticks)"); size: 22; medium: true; color: SimpleTheme.textSecondary }
                Repeater {
                    model: gp._joy ? Math.min(gp._joy.axisCount, 8) : 0
                    Row {
                        spacing: SimpleTheme.px(12)
                        SText { width: SimpleTheme.px(90); text: qsTr("Axis %1").arg(index + 1); size: 20; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle {
                            width: SimpleTheme.px(520); height: SimpleTheme.px(16); radius: height / 2; color: SimpleTheme.bgBase
                            anchors.verticalCenter: parent.verticalCenter
                            readonly property real v: index < gp.axes.length ? gp.axes[index] / 32768 : 0
                            Rectangle { width: SimpleTheme.px(2); height: parent.height; color: SimpleTheme.line; x: parent.width / 2 }
                            Rectangle {
                                height: parent.height; radius: height / 2; color: SimpleTheme.ok
                                width: Math.max(SimpleTheme.px(6), Math.abs(parent.v) * parent.width / 2)
                                x: parent.v >= 0 ? parent.width / 2 : parent.width / 2 - width
                            }
                        }
                    }
                }
            }
            Flow {
                width: parent.width
                spacing: SimpleTheme.px(16)
                SButton { visible: !gp._buttonsOnly; designHeight: 64; textSize: 24; kind: gp._calOk ? "secondary" : "primary"
                          text: qsTr("Calibrate sticks…"); enabled_: !gp._veh || !gp._veh.armed; onClicked: if (enabled_) calSheet.open() }
                Row {
                    visible: !gp._buttonsOnly
                    spacing: SimpleTheme.px(12)
                    SText { text: qsTr("Throttle"); size: 24; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                    SSegmented {
                        designWidth: 460
                        model: [qsTr("Centre = hover"), qsTr("Full range")]
                        currentIndex: gp._joy ? Math.min(1, Math.max(0, gp._joy.throttleMode)) : 0
                        onActivated: { gp._joy.throttleMode = index; currentIndex = Qt.binding(function() { return gp._joy ? Math.min(1, Math.max(0, gp._joy.throttleMode)) : 0 }) }
                    }
                }
            }
        }
    }

    // ------------------------------------------------ Buttons card
    Rectangle {
        visible: !!gp._joy && gp._joy.totalButtonCount > 0
        width: parent.width; height: bCol.height + SimpleTheme.px(44)
        radius: SimpleTheme.px(20); color: SimpleTheme.surfaceRaised
        Column {
            id: bCol
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: SimpleTheme.px(22); anchors.leftMargin: SimpleTheme.px(28)
            spacing: SimpleTheme.px(14)
            SText { text: qsTr("Buttons"); size: 30; medium: true }
            SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                    text: qsTr("Press a button to find it in the list. Actions are sent only while the gamepad is in use.") }
            Flow {
                width: parent.width
                spacing: SimpleTheme.px(14)
                Repeater {
                    model: gp._joy ? Math.min(gp._joy.totalButtonCount, 32) : 0
                    Rectangle {
                        readonly property int  btn: index
                        readonly property bool down: (gp.rev, !!gp.pressed[btn])
                        width: SimpleTheme.px(600); height: SimpleTheme.px(76); radius: SimpleTheme.px(14)
                        color: down ? SimpleTheme.withAlpha(SimpleTheme.ok, 0.25) : SimpleTheme.bgBase
                        Rectangle {
                            x: SimpleTheme.px(12); anchors.verticalCenter: parent.verticalCenter
                            width: SimpleTheme.px(52); height: SimpleTheme.px(44); radius: SimpleTheme.px(10)
                            color: parent.down ? SimpleTheme.ok : SimpleTheme.surfaceControl
                            SText { anchors.centerIn: parent; text: String(index + 1); size: 22; bold: true
                                    color: parent.parent.down ? SimpleTheme.bgBase : SimpleTheme.textPrimary }
                        }
                        SComboBox {
                            x: SimpleTheme.px(80); anchors.verticalCenter: parent.verticalCenter
                            designWidth: 500
                            model: gp._joy ? gp._joy.assignableActionTitles : []
                            onActivated: gp._joy.setButtonAction(parent.btn, textAt(index))
                            Component.onCompleted: currentIndex = gp._joy ? Math.max(0, find(gp._joy.buttonActions[parent.btn])) : 0
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------ Calibration sheet (classic JoystickConfigController)
    SSheet {
        id: calSheet
        designWidth: 1000
        title: qsTr("Calibrate gamepad sticks")
        subtitle: qsTr("Choose the stick layout, press Start and move the sticks as shown. Keep the gamepad still between steps.")
        onClosed: { if (calLoader.item && calLoader.item.calibrating) calLoader.item.cancelButtonClicked() }
        Loader {
            id: calLoader
            active: calSheet.visible
            sourceComponent: Component { JoystickConfigController { Component.onCompleted: start() } }
        }
        readonly property var ctl: calLoader.item
        Row {
            spacing: SimpleTheme.px(16)
            SText { text: qsTr("Stick layout"); size: 24; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            SSegmented {
                designWidth: 520
                model: [qsTr("Mode 1"), qsTr("Mode 2"), qsTr("Mode 3"), qsTr("Mode 4")]
                currentIndex: calSheet.ctl ? calSheet.ctl.transmitterMode - 1 : 1
                enabled: !!calSheet.ctl && !calSheet.ctl.calibrating
                opacity: enabled ? 1 : 0.5
                onActivated: { calSheet.ctl.transmitterMode = index + 1; currentIndex = Qt.binding(function() { return calSheet.ctl ? calSheet.ctl.transmitterMode - 1 : 1 }) }
            }
        }
        Row {
            spacing: SimpleTheme.px(60)
            anchors.horizontalCenter: parent.horizontalCenter
            Repeater {
                model: 2
                Column {
                    spacing: SimpleTheme.px(8)
                    Rectangle {
                        readonly property var pos: calSheet.ctl ? calSheet.ctl.stickPositions : []
                        width: SimpleTheme.px(220); height: width; radius: SimpleTheme.px(24); color: SimpleTheme.bgBase
                        Rectangle { width: parent.width; height: SimpleTheme.px(2); y: parent.height / 2; color: SimpleTheme.line }
                        Rectangle { width: SimpleTheme.px(2); height: parent.height; x: parent.width / 2; color: SimpleTheme.line }
                        Rectangle {
                            visible: parent.pos.length === 4
                            width: SimpleTheme.px(40); height: width; radius: width / 2; color: SimpleTheme.ok
                            x: visible ? parent.width * parent.pos[index * 2] - width / 2 : 0
                            y: visible ? parent.height * parent.pos[index * 2 + 1] - height / 2 : 0
                        }
                    }
                    SText { anchors.horizontalCenter: parent.horizontalCenter; text: index === 0 ? qsTr("Left stick") : qsTr("Right stick"); size: 20; color: SimpleTheme.textSecondary }
                }
            }
        }
        SText {
            width: parent.width; wrapMode: Text.WordWrap; size: 26; medium: true; horizontalAlignment: Text.AlignHCenter
            text: calSheet.ctl && calSheet.ctl.statusText !== "" ? calSheet.ctl.statusText : qsTr("Press Start.")
        }
        Item {
            width: parent.width; height: SimpleTheme.px(72)
            SButton { designHeight: 72; textSize: 24; text: calSheet.ctl && calSheet.ctl.calibrating ? qsTr("Cancel") : qsTr("Close")
                      onClicked: { if (calSheet.ctl && calSheet.ctl.calibrating) calSheet.ctl.cancelButtonClicked(); else calSheet.close() } }
            Row {
                anchors.right: parent.right
                spacing: SimpleTheme.px(14)
                SButton { visible: !!calSheet.ctl && calSheet.ctl.calibrating; designHeight: 72; textSize: 24; text: qsTr("Skip")
                          enabled_: !!calSheet.ctl && calSheet.ctl.skipEnabled; onClicked: if (enabled_) calSheet.ctl.skipButtonClicked() }
                SButton { designHeight: 72; textSize: 24; kind: "primary"
                          text: calSheet.ctl && calSheet.ctl.calibrating ? qsTr("Next") : qsTr("Start")
                          enabled_: !!calSheet.ctl && (!calSheet.ctl.calibrating || calSheet.ctl.nextEnabled)
                          onClicked: if (enabled_) calSheet.ctl.nextButtonClicked() }
            }
        }
    }
}
