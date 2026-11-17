/****************************************************************************
 * AQGC Simple UI — S77 Vehicle setup › Gimbal (Figma 128:40314, 2026-11-17).
 * MNT1_TYPE, tilt / pan control channel (RCx_OPTION 213 Mount1 Pitch / 214 Mount1 Yaw), tilt range
 * MNT1_PITCH_MIN/MAX (same values as Settings › Payloads › Camera & gimbal). Rows whose parameter the firmware does
 * not have are hidden (keep level: MNT1_STAB_TILT on older firmware).
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
    readonly property var pmin: p("MNT1_PITCH_MIN") || p("MNT_ANGMIN_TIL")
    readonly property var pmax: p("MNT1_PITCH_MAX") || p("MNT_ANGMAX_TIL")
    readonly property bool hasMount: !!p("MNT1_TYPE") && Number(p("MNT1_TYPE").rawValue) !== 0

    Column {
        id: col
        width: gb.width
        spacing: SimpleTheme.px(12)
        SText { text: qsTr("Gimbal"); size: 40; bold: true }
        SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                text: qsTr("Gimbal connection and limits. Speed and tilt range for pilots are in Settings › Payloads.") }
        SSettingRow { visible: !!gb.p("MNT1_TYPE"); title: qsTr("Gimbal type"); sub: qsTr("How the drone talks to the gimbal. Changing it needs a drone restart.")
                      SFactField { fact: gb.p("MNT1_TYPE"); designWidth: 460 } }
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
            visible: gb.hasMount && !!gb.pmin && !!gb.pmax
            title: qsTr("Tilt range"); sub: qsTr("Lowest and highest angle")
            Row {
                spacing: SimpleTheme.px(10)
                SFactField { fact: gb.pmin; designWidth: 330; anchors.verticalCenter: parent.verticalCenter }
                SText { text: qsTr("to"); size: 22; anchors.verticalCenter: parent.verticalCenter }
                SFactField { fact: gb.pmax; designWidth: 330; anchors.verticalCenter: parent.verticalCenter }
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
        SSettingRow { visible: gb.hasMount && !!gb.p("MNT1_STAB_TILT"); title: qsTr("Keep the camera level"); sub: qsTr("Gimbal holds its angle when the drone tilts")
                      SFactField { fact: gb.p("MNT1_STAB_TILT"); designWidth: 300 } }
        SText { visible: !gb.hasMount; width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                text: qsTr("No gimbal is set. Choose the gimbal type above, then restart the drone.") }
    }
}
