/****************************************************************************
 * AQGC Simple UI — S97 Vehicle setup › Mission (Figma 171:45927, 2026-11-18). Replaces the classic Mission setup page
 * (APMMissionComponent, company firmware): MIS_OPTIONS bit0 clear the mission on restart, bit2 continue after landing.
 * Same controller as the classic page (APMMissionComponentController: refresh / set… / apply / cancel).
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import QGroundControl.Controllers 1.0
import "."

Flickable {
    id: mo
    contentHeight: col.height
    clip: true

    APMMissionComponentController { id: ctl }
    Component.onCompleted: ctl.refresh()
    readonly property bool _armed: !!ctl.vehicle && ctl.vehicle.armed
    readonly property bool _canEdit: ctl.valueKnown && !ctl.busy && !_armed
    readonly property bool _savedClear: (ctl.currentValue & 1) !== 0
    readonly property bool _savedContinue: (ctl.currentValue & 4) !== 0

    Column {
        id: col
        width: mo.width
        spacing: SimpleTheme.px(16)
        SText { text: qsTr("Mission"); size: 40; bold: true }
        SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                text: qsTr("What the drone does with its mission after a restart or a landing.") }

        SNotice { visible: mo._armed; width: parent.width; level: "warn"; text: qsTr("Locked while the drone is armed.") }

        SSettingRow {
            title: qsTr("Clear the mission when the drone restarts")
            sub: qsTr("On: send the mission again after every restart. Off: the old mission stays — check it before you start. Takes effect after the next restart.")
            locked: !mo._canEdit
            SToggle {
                id: clearT
                checked: ctl.clearOnReboot
                onToggled: { ctl.setClearOnReboot(checked) }
            }
        }
        SSettingRow {
            visible: ctl.continueAfterLandSupported
            title: qsTr("Continue the mission after landing")
            sub: qsTr("On: if the next item after a landing is a take-off, the mission goes on. Off: the drone stops and disarms after landing.")
            locked: !mo._canEdit
            SToggle {
                id: contT
                checked: ctl.continueAfterLand
                onToggled: { ctl.setContinueAfterLand(checked) }
            }
        }

        SNotice {
            visible: ctl.dirty
            width: parent.width; level: "info"
            text: qsTr("Changed. Press Apply to send it to the drone.")
        }
        Row {
            spacing: SimpleTheme.px(14)
            SButton { designHeight: 72; textSize: 26; text: qsTr("Cancel"); enabled_: mo._canEdit && ctl.dirty; onClicked: if (enabled_) ctl.cancel() }
            SButton { designHeight: 72; textSize: 26; kind: "primary"; text: ctl.busy ? qsTr("Sending…") : qsTr("Apply")
                      enabled_: mo._canEdit && ctl.dirty; onClicked: if (enabled_) ctl.apply() }
        }
        SText {
            width: parent.width; wrapMode: Text.WordWrap; size: 22
            readonly property bool err: ctl.status === APMMissionComponentController.StatusFailed || ctl.status === APMMissionComponentController.StatusReadFailed
            color: err ? SimpleTheme.textDanger : SimpleTheme.textSecondary
            text: ctl.status === APMMissionComponentController.StatusApplied
                  ? qsTr("Applied.") + (ctl.lastApplyChangedClear ? " " + qsTr("Clearing on restart changes after the next restart.") : "")
                                     + (ctl.lastApplyChangedContinue ? " " + qsTr("Continue after landing changes at the next landing.") : "")
                  : ctl.status === APMMissionComponentController.StatusFailed ? qsTr("Could not apply the setting. The previous value is back.")
                  : ctl.status === APMMissionComponentController.StatusReadFailed ? qsTr("Could not read MIS_OPTIONS from the drone.")
                  : ctl.valueKnown ? qsTr("Current value: MIS_OPTIONS = %1").arg(ctl.currentValue) : qsTr("Reading MIS_OPTIONS…")
        }
    }
}
