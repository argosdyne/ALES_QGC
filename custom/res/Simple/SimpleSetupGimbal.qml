/****************************************************************************
 * AQGC Simple UI — S77 Vehicle setup › Gimbal (Figma 128:40314, 2026-11-17) + S101 servo gimbal (Figma 176:47788,
 * 2026-11-18, replaces the rest of the classic Vehicle setup › Camera page APMCameraComponent).
 * MNT1_TYPE, angle ranges tilt / roll / pan (MNT1_PITCH/ROLL/YAW_MIN/MAX; older firmware MNT_ANGMIN/MAX_TIL/ROL/PAN),
 * Servo gimbal only: output per axis = the SERVOn_FUNCTION set to Mount tilt 7 / roll 8 / pan 6 (choosing one clears it
 * elsewhere, as the classic page did), PWM range SERVOn_MIN/MAX, reverse SERVOn_REVERSED; start-up mode MNT1_DEFLT_MODE;
 * tilt / pan control channel (RCx_OPTION 213 Mount1 Pitch / 214 Mount1 Yaw). Rows whose parameter the firmware does
 * not have are hidden (keep level: MNT1_STAB_TILT / MNT_STAB_TILT on older firmware). The page is locked while armed
 * (SimpleVehicleSetup.locked).
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import QGroundControl.FactSystem 1.0
import QGroundControl.Controllers 1.0
import "."

Flickable {
    id: gb
    contentHeight: col.height
    clip: true
    FactPanelController { id: fpc }
    function p(n) { return fpc.parameterExists(-1, n) ? fpc.getParameterFact(-1, n, false) : null }
    function p2(a, b) { return p(a) || p(b) }
    property int rev: 0
    // channel (1–16) whose RCx_OPTION is opt, 0 = none
    function channelOf(opt) { rev; for (var n = 1; n <= 16; n++) { var f = p("RC" + n + "_OPTION"); if (f && Number(f.rawValue) === opt) return n } return 0 }
    // free channels (option 0) plus the one in use
    function choices(opt) {
        rev
        var out = [{ n: 0, t: qsTr("None") }], cur = channelOf(opt)
        for (var n = 5; n <= 16; n++) { var f = p("RC" + n + "_OPTION"); if (f && (Number(f.rawValue) === 0 || n === cur)) out.push({ n: n, t: qsTr("Channel %1").arg(n) }) }
        return out
    }
    function setChannel(opt, n) {
        var cur = channelOf(opt)
        if (cur === n) return
        if (cur > 0) p("RC" + cur + "_OPTION").value = 0
        if (n > 0) p("RC" + n + "_OPTION").value = opt
        rev++
    }
    // servo outputs (SERVOn_FUNCTION): same rules for the drone outputs
    function outputOf(fn) { rev; for (var n = 1; n <= 16; n++) { var f = p("SERVO" + n + "_FUNCTION"); if (f && Number(f.rawValue) === fn) return n } return 0 }
    function outChoices(fn) {
        rev
        var out = [{ n: 0, t: qsTr("None") }], cur = outputOf(fn)
        for (var n = 1; n <= 16; n++) { var f = p("SERVO" + n + "_FUNCTION"); if (f && (Number(f.rawValue) === 0 || n === cur)) out.push({ n: n, t: qsTr("Output %1").arg(n) }) }
        return out
    }
    function setOutput(fn, n) {
        // clear every output that has this function (the classic page did the same), then set the chosen one
        for (var i = 1; i <= 16; i++) { var f = p("SERVO" + i + "_FUNCTION"); if (f && i !== n && Number(f.rawValue) === fn) f.value = 0 }
        if (n > 0) p("SERVO" + n + "_FUNCTION").value = fn
        restartNeeded = true
        rev++
    }
    property bool restartNeeded: false
    // this page shows its own restart notice: no restart toast while it is open
    Component.onCompleted:   SimpleTheme.ownRestartHints++
    Component.onDestruction: SimpleTheme.ownRestartHints--
    Connections { target: gb.p("MNT1_TYPE"); ignoreUnknownSignals: true; function onRawValueChanged() { gb.restartNeeded = true } }

    readonly property var pmin: p2("MNT1_PITCH_MIN", "MNT_ANGMIN_TIL")
    readonly property var pmax: p2("MNT1_PITCH_MAX", "MNT_ANGMAX_TIL")
    readonly property var rmin: p2("MNT1_ROLL_MIN",  "MNT_ANGMIN_ROL")
    readonly property var rmax: p2("MNT1_ROLL_MAX",  "MNT_ANGMAX_ROL")
    readonly property var ymin: p2("MNT1_YAW_MIN",   "MNT_ANGMIN_PAN")
    readonly property var ymax: p2("MNT1_YAW_MAX",   "MNT_ANGMAX_PAN")
    readonly property bool hasMount: !!p("MNT1_TYPE") && Number(p("MNT1_TYPE").rawValue) !== 0
    readonly property bool isServo:  !!p("MNT1_TYPE") && Number(p("MNT1_TYPE").rawValue) === 1

    Column {
        id: col
        width: gb.width
        spacing: SimpleTheme.px(12)
        SText { text: qsTr("Gimbal"); size: 40; bold: true }
        SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                text: qsTr("Gimbal connection and limits. Speed and tilt range for pilots are in Settings › Payloads.") }
        SNotice { visible: gb.restartNeeded; width: parent.width; level: "info"
                  text: qsTr("Restart the drone to use the new gimbal type or outputs.") }
        SSettingRow { visible: !!gb.p("MNT1_TYPE"); title: qsTr("Gimbal type"); sub: qsTr("How the drone talks to the gimbal. Changing it needs a drone restart.")
                      SFactField { fact: gb.p("MNT1_TYPE"); designWidth: 460 } }
        Repeater {
            model: [{ t: qsTr("Tilt range"), s: qsTr("Lowest and highest angle"),          lo: gb.pmin, hi: gb.pmax },
                    { t: qsTr("Roll range"), s: qsTr("Left and right tilt of the camera"), lo: gb.rmin, hi: gb.rmax },
                    { t: qsTr("Pan range"),  s: qsTr("Turn left and right"),               lo: gb.ymin, hi: gb.ymax }]
            SSettingRow {
                visible: gb.hasMount && !!modelData.lo && !!modelData.hi
                title: modelData.t; sub: modelData.s
                Row {
                    spacing: SimpleTheme.px(10)
                    SFactField { fact: modelData.lo; designWidth: 400; anchors.verticalCenter: parent.verticalCenter }
                    SText { text: qsTr("to"); size: 22; anchors.verticalCenter: parent.verticalCenter }
                    SFactField { fact: modelData.hi; designWidth: 400; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        SText { visible: gb.isServo; width: parent.width; wrapMode: Text.WordWrap; size: 22; medium: true; color: SimpleTheme.textTertiary
                text: qsTr("SERVO OUTPUTS — which drone output drives each axis, its PWM range and direction") }
        Repeater {
            model: [{ t: qsTr("Tilt servo"), fn: 7 }, { t: qsTr("Roll servo"), fn: 8 }, { t: qsTr("Pan servo"), fn: 6 }]
            SSettingRow {
                id: sr
                readonly property int fn: modelData.fn
                readonly property int out: gb.outputOf(fn)
                readonly property var rv: out > 0 ? gb.p("SERVO" + out + "_REVERSED") : null
                visible: gb.isServo
                title: modelData.t
                sub: out > 0 ? qsTr("Output · PWM range · reverse") : qsTr("Not connected to a drone output")
                Row {
                    spacing: SimpleTheme.px(12)
                    SComboBox {
                        anchors.verticalCenter: parent.verticalCenter
                        designWidth: 220
                        readonly property var opts: gb.outChoices(sr.fn)
                        model: opts.map(function(o) { return o.t })
                        currentIndex: { for (var i = 0; i < opts.length; i++) if (opts[i].n === sr.out) return i; return 0 }
                        onActivated: gb.setOutput(sr.fn, opts[index].n)
                    }
                    SStepper {
                        readonly property var f: sr.out > 0 ? gb.p("SERVO" + sr.out + "_MIN") : null
                        visible: !!f; anchors.verticalCenter: parent.verticalCenter
                        from: 800; to: 2200; step: 10
                        value: f ? Number(f.rawValue) : 0
                        onEdited: if (f) f.value = value
                    }
                    SText { visible: sr.out > 0; text: "–"; size: 22; anchors.verticalCenter: parent.verticalCenter }
                    SStepper {
                        readonly property var f: sr.out > 0 ? gb.p("SERVO" + sr.out + "_MAX") : null
                        visible: !!f; anchors.verticalCenter: parent.verticalCenter
                        from: 800; to: 2200; step: 10
                        value: f ? Number(f.rawValue) : 0
                        onEdited: if (f) f.value = value
                    }
                    Column {
                        visible: !!sr.rv
                        anchors.verticalCenter: parent.verticalCenter
                        SToggle {
                            id: revT
                            anchors.horizontalCenter: parent.horizontalCenter
                            checked: !!sr.rv && Number(sr.rv.rawValue) !== 0
                            onToggled: { sr.rv.value = checked ? 1 : 0 }
                        }
                        SText { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("Reverse"); size: 18; color: SimpleTheme.textSecondary }
                    }
                }
            }
        }
        SSettingRow { visible: gb.hasMount && !!gb.p("MNT1_DEFLT_MODE"); title: qsTr("At start-up"); sub: qsTr("Where the gimbal points when the drone starts")
                      SFactField { fact: gb.p("MNT1_DEFLT_MODE"); designWidth: 460 } }

        SSettingRow {
            visible: gb.hasMount
            title: qsTr("Tilt control"); sub: qsTr("Controller channel that moves the camera up and down")
            SComboBox {
                designWidth: 300
                readonly property var opts: gb.choices(213)
                model: opts.map(function(o) { return o.t })
                currentIndex: { var c = gb.channelOf(213); for (var i = 0; i < opts.length; i++) if (opts[i].n === c) return i; return 0 }
                onActivated: gb.setChannel(213, opts[index].n)
            }
        }
        SSettingRow {
            visible: gb.hasMount
            title: qsTr("Pan control"); sub: qsTr("Turn left and right")
            SComboBox {
                designWidth: 300
                readonly property var opts: gb.choices(214)
                model: opts.map(function(o) { return o.t })
                currentIndex: { var c = gb.channelOf(214); for (var i = 0; i < opts.length; i++) if (opts[i].n === c) return i; return 0 }
                onActivated: gb.setChannel(214, opts[index].n)
            }
        }
        SSettingRow { id: keepRow; readonly property var f: gb.p2("MNT1_STAB_TILT", "MNT_STAB_TILT")
                      visible: gb.hasMount && !!f; title: qsTr("Keep the camera level"); sub: qsTr("Gimbal holds its angle when the drone tilts")
                      SFactField { fact: keepRow.f; designWidth: 300 } }
        SText { visible: !gb.hasMount; width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                text: qsTr("No gimbal is set. Choose the gimbal type above, then restart the drone.") }
    }
}
