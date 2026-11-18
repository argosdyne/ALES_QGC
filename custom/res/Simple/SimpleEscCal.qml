/****************************************************************************
 * AQGC Simple UI — S83 Vehicle setup › Power › ESC calibration (Figma 158:42905, 2026-11-18).
 * ArduPilot ESC_CALIBRATION = 3 ("calibrate at next start"), then the user cycles the battery:
 *   0 propellers removed (check) → Start writes ESC_CALIBRATION = 3
 *   1 unplug battery and USB: goes on by itself when the drone link is gone
 *   2 plug the battery in: tone, one beep per cell, one long beep → "I heard the long beep"
 *   3 unplug and start normally: when the drone is back, ESC_CALIBRATION = 0 means done (else it is set back to 0)
 * The sheet lives in the Vehicle setup root (not in the Power page): the page is unloaded while the drone is away.
 * Cancel sets ESC_CALIBRATION back to 0 while the drone is connected.
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import QGroundControl.FactSystem 1.0
import QGroundControl.Controllers 1.0
import "."

SSheet {
    id: esc
    title: qsTr("ESC calibration")
    subtitle: qsTr("Only after replacing ESCs. Takes about 2 minutes.")
    steps: 3
    designWidth: 1000

    readonly property var  _veh: QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool _ready: !!_veh && _veh.parameterManager.parametersReady
    property int  phase: 0            // 0..3 as above, 4 = done, 5 = did not run
    property bool propsOff: false
    readonly property var fact: factLoader.item ? factLoader.item.fact : null

    step: phase <= 0 ? 0 : phase <= 2 ? 1 : 2
    onAboutToShow: { phase = 0; propsOff = false }
    onClosed: if (phase >= 1 && phase <= 3 && fact && Number(fact.rawValue) !== 0) fact.rawValue = 0

    Loader {
        id: factLoader
        active: esc._ready          // not tied to visible: onClosed still needs the fact
        sourceComponent: Item {
            FactPanelController { id: fpc }
            readonly property var fact: fpc.parameterExists(-1, "ESC_CALIBRATION") ? fpc.getParameterFact(-1, "ESC_CALIBRATION", false) : null
        }
    }
    Connections {
        target: esc
        function on_VehChanged() {
            if (!esc._veh && esc.phase === 1) esc.phase = 2
        }
        function on_ReadyChanged() {
            if (esc._ready && esc.phase === 3) Qt.callLater(esc.checkDone)
        }
    }
    function checkDone() {
        if (!fact) return
        if (Number(fact.rawValue) === 0) phase = 4
        else { fact.rawValue = 0; phase = 5 }
    }

    Repeater {
        model: [
            { n: 1, t: qsTr("Propellers removed"),         s: esc.propsOff ? qsTr("Confirmed") : qsTr("Tap to confirm. All propellers must be off.") },
            { n: 2, t: qsTr("Unplug the battery and USB"), s: qsTr("The drone turns off. Wait 5 seconds.") },
            { n: 3, t: qsTr("Plug the battery in again"),  s: qsTr("You hear a tone, then one beep per cell, then one long beep.") },
            { n: 4, t: qsTr("Unplug and start normally"),  s: qsTr("The app shows “ESC calibration done” after the restart.") }
        ]
        Rectangle {
            readonly property bool cur: esc.phase === index || (index === 0 && esc.phase === 0)
            readonly property bool done: esc.phase > index || (index === 0 && esc.propsOff)
            width: esc.innerWidth; height: Math.max(SimpleTheme.px(80), txt.height + SimpleTheme.px(32)); radius: SimpleTheme.px(16)
            color: cur ? SimpleTheme.surfaceControl : "transparent"
            Rectangle {
                id: num
                x: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                width: SimpleTheme.px(48); height: width; radius: width / 2
                color: parent.done ? SimpleTheme.brandGreen : parent.cur ? SimpleTheme.ok : SimpleTheme.surfaceControl
                SIcon { anchors.centerIn: parent; visible: parent.parent.done; name: "check"; size: 30 }
                SText { anchors.centerIn: parent; visible: !parent.parent.done; text: modelData.n; size: 24; bold: true
                        color: parent.parent.cur ? SimpleTheme.bgBase : SimpleTheme.textPrimary }
            }
            Column {
                id: txt
                anchors.left: num.right; anchors.leftMargin: SimpleTheme.px(20); anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(20)
                anchors.verticalCenter: parent.verticalCenter
                SText { text: modelData.t; size: 28; medium: true }
                SText { width: parent.width; text: modelData.s; size: 22; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap }
            }
            MouseArea { anchors.fill: parent; enabled: index === 0 && esc.phase === 0; onClicked: esc.propsOff = !esc.propsOff; objectName: "escPropsOff" }
        }
    }
    SNotice { visible: esc.phase === 4; level: "info"; text: qsTr("ESC calibration done.") }
    SNotice { visible: esc.phase === 5; level: "warn"; text: qsTr("The drone did not calibrate the ESCs. The setting is back to off. Try again and keep the battery in until the long beep.") }
    SNotice { visible: esc.phase === 0 && !esc.fact && esc._ready; level: "warn"; text: qsTr("This drone has no ESC calibration setting.") }
    SNotice { visible: esc.phase >= 1 && esc.phase <= 3; level: "danger"; text: qsTr("Keep hands away from the motors while the battery is plugged in.") }
    Row {
        spacing: SimpleTheme.px(12)
        SButton { objectName: "escCancel"; width: (esc.innerWidth - parent.spacing) / 2; designHeight: 72; textSize: 26
                  text: esc.phase >= 4 ? qsTr("Close") : qsTr("Cancel"); onClicked: esc.close() }
        SButton {
            objectName: "escNext"
            width: (esc.innerWidth - parent.spacing) / 2; designHeight: 72; textSize: 26
            kind: esc.phase === 1 || esc.phase === 3 ? "secondary" : "primary"
            enabled_: esc.phase === 0 ? (esc.propsOff && !!esc.fact && !(esc._veh && esc._veh.armed)) : (esc.phase === 2 || esc.phase >= 4)
            text: esc.phase === 0 ? qsTr("Start") : esc.phase === 1 ? qsTr("Waiting for the drone…") : esc.phase === 2 ? qsTr("I heard the long beep")
                : esc.phase === 3 ? qsTr("Waiting for the drone…") : qsTr("Done")
            onClicked: {
                if (esc.phase === 0) { esc.fact.rawValue = 3; esc.phase = 1 }
                else if (esc.phase === 2) { esc.phase = 3; if (esc._ready) Qt.callLater(esc.checkDone) }
                else esc.close()
            }
        }
    }
}
