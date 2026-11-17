/****************************************************************************
 * AQGC Simple UI — S74 Vehicle setup › Motors (Figma 128:39706, 2026-11-17).
 * One motor at a time (vehicle.motorTest, ArduPilot test order A, B, C … clockwise from the front right). Nothing can
 * spin before "Propellers removed" is ticked (EN safety); throttle 7 % default, at most 20 %; time 2 s default.
 * Quadcopter X shows the CW / CCW directions; other frames only the order. Locked while armed (category lock).
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import QGroundControl.FactSystem 1.0
import QGroundControl.Controllers 1.0
import "."

Flickable {
    id: mt
    contentHeight: col.height
    clip: true
    FactPanelController { id: fpc }
    function p(n) { return fpc.parameterExists(-1, n) ? fpc.getParameterFact(-1, n, false) : null }
    readonly property var  _veh: QGroundControl.multiVehicleManager.activeVehicle
    readonly property int  frameClass: p("FRAME_CLASS") ? Number(p("FRAME_CLASS").rawValue) : 1
    readonly property int  frameType:  p("FRAME_TYPE") ? Number(p("FRAME_TYPE").rawValue) : 1
    readonly property int  count: frameClass === 2 || frameClass === 5 ? 6 : (frameClass === 3 || frameClass === 4) ? 8 : 4
    readonly property bool quadX: frameClass === 1 && frameType === 1
    readonly property bool plus: frameType === 0
    property bool propsOff: false
    property int  throttle: 7
    property int  seconds: 2
    property int  spinning: -1          // motor index being tested
    property int  queue: -1             // next motor in "test all"
    readonly property string letters: "ABCDEFGH"
    // a test arms the drone for a moment: the next motor of "test all" may start while it still reports armed
    function spin(i, fromQueue) {
        if (!propsOff || !_veh || _veh.flying || (_veh.armed && !fromQueue)) return
        spinning = i
        _veh.motorTest(i + 1, throttle, seconds, true)
        stopTimer.restart()
    }
    Timer {
        id: stopTimer
        interval: mt.seconds * 1000 + 600
        onTriggered: {
            mt.spinning = -1
            if (mt.queue >= 0 && mt.queue < mt.count) { var n = mt.queue; mt.queue = n + 1 < mt.count ? n + 1 : -1; mt.spin(n, true) }
        }
    }

    Column {
        id: col
        width: mt.width
        spacing: SimpleTheme.px(14)
        SText { text: qsTr("Motors"); size: 40; bold: true }
        SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                text: qsTr("Spin one motor at a time to check the order and direction.") }
        Rectangle {
            width: parent.width; height: wRow.height + SimpleTheme.px(24); radius: SimpleTheme.px(14)
            color: SimpleTheme.withAlpha(SimpleTheme.warn, 0.18); border.width: SimpleTheme.px(2); border.color: SimpleTheme.warn
            Row { id: wRow; anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(18); anchors.verticalCenter: parent.verticalCenter; spacing: SimpleTheme.px(14)
                  SIcon { name: "warn"; size: 32; anchors.verticalCenter: parent.verticalCenter }
                  SText { anchors.verticalCenter: parent.verticalCenter; size: 24; text: qsTr("Remove all propellers before testing. Motors spin at the throttle set below.") } }
        }
        Row {
            spacing: SimpleTheme.px(30)
            // diagram
            Rectangle {
                id: diag
                width: SimpleTheme.px(420); height: width; radius: SimpleTheme.px(18); color: SimpleTheme.surfaceRaised
                SText { x: SimpleTheme.px(14); y: SimpleTheme.px(10); text: qsTr("▲ Front"); size: 22; color: SimpleTheme.textSecondary }
                Rectangle { anchors.centerIn: parent; width: SimpleTheme.px(70); height: width; radius: SimpleTheme.px(14); color: SimpleTheme.surfaceControl }
                Repeater {
                    model: mt.count
                    Rectangle {
                        // clockwise from the front right (X) or from the front (+)
                        readonly property real ang: (mt.plus ? 0 : 180 / mt.count) + index * 360 / mt.count
                        readonly property real rr: diag.width * 0.31
                        width: SimpleTheme.px(88); height: width; radius: width / 2
                        x: diag.width / 2 + rr * Math.sin(ang * Math.PI / 180) - width / 2
                        y: diag.height / 2 - rr * Math.cos(ang * Math.PI / 180) - height / 2
                        color: mt.spinning === index ? SimpleTheme.brandGreen : SimpleTheme.surfaceControl
                        border.width: SimpleTheme.px(2); border.color: SimpleTheme.line
                        Column {
                            anchors.centerIn: parent
                            SText { anchors.horizontalCenter: parent.horizontalCenter; text: mt.letters[index]; size: 28; bold: true }
                            SText { visible: mt.quadX; anchors.horizontalCenter: parent.horizontalCenter; text: index % 2 === 0 ? "CCW" : "CW"; size: 16; color: SimpleTheme.textSecondary }
                        }
                    }
                }
            }
            Column {
                width: col.width - diag.width - SimpleTheme.px(30)
                spacing: SimpleTheme.px(14)
                SText { visible: mt.spinning >= 0; size: 26; medium: true; color: SimpleTheme.ok
                        text: qsTr("Motor %1 spinning · %2 s").arg(mt.letters[Math.max(0, mt.spinning)]).arg(mt.seconds) }
                // propellers removed
                Item {
                    width: parent.width; height: SimpleTheme.px(76)
                    objectName: "propsOff"
                    Rectangle { id: pbox; width: SimpleTheme.px(44); height: width; radius: SimpleTheme.px(8); anchors.verticalCenter: parent.verticalCenter
                                color: mt.propsOff ? SimpleTheme.brandGreen : "transparent"; border.width: SimpleTheme.px(3)
                                border.color: mt.propsOff ? SimpleTheme.brandGreen : SimpleTheme.warn
                                SIcon { anchors.centerIn: parent; name: "check"; size: 32; visible: mt.propsOff } }
                    Column { anchors.left: pbox.right; anchors.leftMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                             SText { text: qsTr("Propellers removed"); size: 28; medium: true }
                             SText { text: qsTr("Required before any motor spins"); size: 20; color: SimpleTheme.textSecondary } }
                    MouseArea { anchors.fill: parent; onClicked: mt.propsOff = !mt.propsOff }
                }
                Row {
                    spacing: SimpleTheme.px(30)
                    Column {
                        SText { text: qsTr("Throttle"); size: 22; color: SimpleTheme.textSecondary }
                        SStepper { value: mt.throttle; from: 1; to: 20; step: 1; unit: "%"; onEdited: mt.throttle = value }
                    }
                    Column {
                        SText { text: qsTr("Spin time"); size: 22; color: SimpleTheme.textSecondary }
                        SStepper { value: mt.seconds; from: 1; to: 5; step: 1; unit: "s"; onEdited: mt.seconds = value }
                    }
                }
                Flow {
                    width: parent.width
                    spacing: SimpleTheme.px(10)
                    Repeater {
                        model: mt.count
                        SButton { designHeight: 72; textSize: 24; text: qsTr("Motor %1").arg(mt.letters[index]); objectName: "motor" + index
                                  enabled_: mt.propsOff && mt.spinning < 0 && !!mt._veh && !mt._veh.armed; onClicked: mt.spin(index, false) }
                    }
                    SButton { designHeight: 72; textSize: 24; kind: "primary"; text: qsTr("Test all in order")
                              enabled_: mt.propsOff && mt.spinning < 0 && !!mt._veh && !mt._veh.armed
                              onClicked: { mt.queue = 1; mt.spin(0, false) } }
                }
                SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                        text: qsTr("If the order or a direction is wrong, check the frame (Frame) or the motor wiring.") }
            }
        }
    }
}
