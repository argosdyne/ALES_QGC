/****************************************************************************
 * AQGC Simple UI — S76 Vehicle setup › Tuning (Figma 128:40107, 2026-11-17).
 * The only category that stays open in flight (user 2026-11-16: pilots tune while flying). In flight: orange banner,
 * only −/+ (one small step at a time), "Undo changes in this flight" = back to the values at arming. Each change is
 * written to the security log.
 * Roll & pitch response = ATC_RAT_RLL_P + ATC_RAT_PIT_P (changed together), yaw = ATC_RAT_YAW_P, climb = PSC_POSZ_P,
 * hover throttle = MOT_THST_HOVER (learned, read only), AutoTune = AUTOTUNE_AXES / AUTOTUNE_AGGR / RCx_OPTION 17.
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import QGroundControl.FactSystem 1.0
import QGroundControl.Controllers 1.0
import "."

Flickable {
    id: tn
    contentHeight: col.height
    clip: true
    FactPanelController { id: fpc }
    function p(n) { return fpc.parameterExists(-1, n) ? fpc.getParameterFact(-1, n, false) : null }
    readonly property var  _veh: QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool armed: !!_veh && _veh.armed
    readonly property var  names: ["ATC_RAT_RLL_P", "ATC_RAT_PIT_P", "ATC_RAT_YAW_P", "PSC_POSZ_P", "AUTOTUNE_AGGR", "AUTOTUNE_AXES"]
    property var atArm: ({})         // values when the motors were armed (undo in this flight)
    property int rev: 0
    function snapshot() { var s = {}; for (var i = 0; i < names.length; i++) { var f = p(names[i]); if (f) s[names[i]] = Number(f.rawValue) } atArm = s }
    onArmedChanged: if (armed) snapshot()
    Component.onCompleted: if (armed) snapshot()
    readonly property bool changedInFlight: {
        rev
        if (!armed) return false
        for (var k in atArm) { var f = p(k); if (f && Number(f.rawValue) !== atArm[k]) return true }
        return false
    }
    function log(text) { var pd = QGroundControl.corePlugin.privacyData; if (pd) pd.logEvent("Tuning", text + (armed ? " (in flight)" : "")) }
    function setStep(names, delta, decimals) {
        for (var i = 0; i < names.length; i++) {
            var f = p(names[i]); if (!f) continue
            var nv = Number((Number(f.rawValue) + delta).toFixed(decimals))
            if (f.validate(String(nv), false) !== "") continue
            var old = Number(f.rawValue)
            f.value = nv
            log(names[i] + " " + old.toFixed(decimals) + " -> " + nv.toFixed(decimals))
        }
        rev++
    }
    function undo() {
        for (var k in atArm) { var f = p(k); if (f && Number(f.rawValue) !== atArm[k]) { f.value = atArm[k]; log(k + " back to " + Number(atArm[k]).toFixed(3)) } }
        rev++
    }
    // AutoTune switch channel (RCx_OPTION 17)
    function channelOf(opt) { rev; for (var n = 1; n <= 16; n++) { var f = p("RC" + n + "_OPTION"); if (f && Number(f.rawValue) === opt) return n } return 0 }

    Column {
        id: col
        width: tn.width
        spacing: SimpleTheme.px(12)
        SText { text: qsTr("Tuning"); size: 40; bold: true }
        SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                text: qsTr("Factory tuning fits the company drones. Change it only after a payload or frame change.") }
        Rectangle {
            visible: tn.armed
            width: parent.width; height: inRow.height + SimpleTheme.px(24); radius: SimpleTheme.px(14)
            color: SimpleTheme.withAlpha(SimpleTheme.warn, 0.18); border.width: SimpleTheme.px(2); border.color: SimpleTheme.warn
            Row {
                id: inRow
                anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(18); anchors.verticalCenter: parent.verticalCenter
                spacing: SimpleTheme.px(14)
                SIcon { name: "warn"; size: 32; anchors.verticalCenter: parent.verticalCenter }
                SText { anchors.verticalCenter: parent.verticalCenter; width: col.width - SimpleTheme.px(520); wrapMode: Text.WordWrap; size: 24
                        text: qsTr("In flight: each change is sent at once. Change in small steps and watch the drone.") }
                SButton { designHeight: 64; textSize: 22; text: qsTr("Undo changes in this flight"); enabled_: tn.changedInFlight; onClicked: tn.undo() }
            }
        }
        Repeater {
            model: [
                { t: qsTr("Roll and pitch response"), s: qsTr("How quickly the drone follows the sticks"), names: ["ATC_RAT_RLL_P", "ATC_RAT_PIT_P"], step: 0.005, dec: 3 },
                { t: qsTr("Yaw response"),            s: qsTr("How quickly the drone turns"),             names: ["ATC_RAT_YAW_P"], step: 0.01, dec: 3 },
                { t: qsTr("Climb response"),          s: qsTr("How quickly height changes"),              names: ["PSC_POSZ_P"], step: 0.05, dec: 2 }
            ]
            SSettingRow {
                readonly property var f: tn.p(modelData.names[0])
                visible: !!f
                title: modelData.t; sub: modelData.s
                Row {
                    spacing: SimpleTheme.px(10)
                    SText { text: qsTr("Softer"); size: 22; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                    SRoundIconButton { icon: "minus"; anchors.verticalCenter: parent.verticalCenter; onClicked: tn.setStep(modelData.names, -modelData.step, modelData.dec) }
                    SText { width: SimpleTheme.px(110); horizontalAlignment: Text.AlignHCenter; anchors.verticalCenter: parent.verticalCenter
                            size: 30; bold: true
                            text: { tn.rev; return f ? Number(f.rawValue).toFixed(modelData.dec) : "—" } }
                    SRoundIconButton { icon: "plus"; anchors.verticalCenter: parent.verticalCenter; onClicked: tn.setStep(modelData.names, modelData.step, modelData.dec) }
                    SText { text: qsTr("Sharper"); size: 22; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
        SSettingRow {
            visible: !!tn.p("MOT_THST_HOVER")
            title: qsTr("Hover throttle"); sub: qsTr("Learned in flight")
            Row {
                spacing: SimpleTheme.px(12)
                SText { text: tn.p("MOT_THST_HOVER") ? Number(tn.p("MOT_THST_HOVER").rawValue).toFixed(2) : ""; size: 30; bold: true; anchors.verticalCenter: parent.verticalCenter }
                SStatusChip { text: qsTr("Learned"); level: "info"; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        // AutoTune
        Rectangle {
            visible: !!tn.p("AUTOTUNE_AXES")
            width: col.width; height: atCol.height + SimpleTheme.px(32); radius: SimpleTheme.px(18)
            color: SimpleTheme.surfaceRaised
            Column {
                id: atCol
                x: SimpleTheme.px(28); y: SimpleTheme.px(16); width: parent.width - SimpleTheme.px(56)
                spacing: SimpleTheme.px(12)
                SText { text: qsTr("AutoTune"); size: 30; medium: true }
                SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                        text: qsTr("Tunes in flight on a calm day: fly in Altitude hold, then hold the AutoTune switch until it finishes (about 5 min per axis).") }
                Row {
                    spacing: SimpleTheme.px(10)
                    Repeater {
                        model: [{ t: qsTr("Roll"), bit: 1 }, { t: qsTr("Pitch"), bit: 2 }, { t: qsTr("Yaw"), bit: 4 }]
                        SButton {
                            readonly property var f: tn.p("AUTOTUNE_AXES")
                            readonly property bool on: { tn.rev; return !!f && (Number(f.rawValue) & modelData.bit) !== 0 }
                            designHeight: 64; textSize: 22; kind: on ? "primary" : "secondary"; text: modelData.t
                            onClicked: { var old = Number(f.rawValue); f.value = old ^ modelData.bit; tn.log("AUTOTUNE_AXES " + old + " -> " + (old ^ modelData.bit)); tn.rev++ }
                        }
                    }
                }
                Row {
                    spacing: SimpleTheme.px(24)
                    Column {
                        visible: !!tn.p("AUTOTUNE_AGGR")
                        SText { text: qsTr("Strength"); size: 22; color: SimpleTheme.textSecondary }
                        SFactField { fact: tn.p("AUTOTUNE_AGGR"); step: 0.01; stepsOnly: tn.armed; designWidth: 400
                                     onChanged: { tn.log("AUTOTUNE_AGGR " + oldValue + " -> " + newValue); tn.rev++ } }
                    }
                    Column {
                        SText { text: qsTr("Switch"); size: 22; color: SimpleTheme.textSecondary }
                        SText { text: tn.channelOf(17) > 0 ? qsTr("Channel %1").arg(tn.channelOf(17)) : qsTr("No switch set (Radio › channel options)"); size: 26; medium: true }
                    }
                }
            }
        }
    }
}
