/****************************************************************************
 * AQGC Simple UI — S91 Mission complete / S92 Mission not finished (Figma 165:43128, 165:44101, 2026-11-18).
 * Replaces the classic "Flight Plan complete" popup (FlyViewMissionCompleteDialog, hidden in Simple mode) with the
 * same trigger: the drone flew in mission mode while armed and is now disarmed. A moment after the disarm the classic
 * GuidedActionsController.showResumeMission tells whether the mission ended early (S92) or not (S91).
 * Values are taken at the disarm: flight time, flight distance, photos (missionImageCount, else camera trigger
 * points), battery % at arm → disarm, the drone's last warning (why it came back), "flight log saved" (telemetrySave).
 * Done keeps the mission on the drone; Remove = PlanMasterController.removeAllFromVehicle(); Continue from waypoint N =
 * actionResumeMission (rebuilds the mission from the last waypoint flown and uploads it). Arming again closes it.
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

Rectangle {
    id: mr
    property var vs                                   // SimpleVehicleState
    property var guided: globals.guidedControllerFlyView
    property var plan:   globals.planMasterControllerFlyView
    signal toast(string text)

    // tracking (same rule as the classic dialog)
    property bool  _wasArmed: false
    property bool  _wasInMission: false
    property real  _battAtArm: NaN
    // result
    property bool   shown: false
    property bool   finished: true
    property int    resumeIndex: 0
    property int    itemCount: 0
    property string flightTime: ""
    property string distance: ""
    property int    photos: -1
    property real   battStart: NaN
    property real   battEnd: NaN
    property string reason: ""
    property bool   resumed: false
    readonly property bool logSaved: !!QGroundControl.settingsManager.appSettings.telemetrySave.rawValue
    readonly property string planName: {
        var f = plan ? String(plan.currentPlanFile) : ""
        if (f === "") return qsTr("Mission")
        f = f.split("/").pop().split("\\").pop()
        return f.replace(/\.plan$/i, "")
    }

    readonly property bool _armed: !!vs && vs.armed
    readonly property bool _inMission: !!vs && vs.present && vs.vehicle.flightMode === vs.vehicle.missionFlightMode
    on_ArmedChanged: {
        if (_armed) {
            _wasArmed = true; _wasInMission = _inMission; _battAtArm = vs.batteryPct
            shown = false; resumed = false
        } else if (_wasArmed) {
            if (_wasInMission && plan && plan.missionController.containsItems) {
                var ft = String(vs.vehicle.getFact("flightTime").valueString)
                flightTime = /^00:\d\d:\d\d$/.test(ft) ? ft.substring(3) : ft          // mm:ss under an hour (Figma)
                distance = vs.vehicle.flightDistance.valueString + " " + vs.vehicle.flightDistance.units
                photos = vs.vehicle.missionImageCount >= 0 ? vs.vehicle.missionImageCount : vs.vehicle.cameraTriggerPoints.count
                battStart = _battAtArm; battEnd = vs.batteryPct
                reason = vs.recentReason
                decide.restart()                       // showResumeMission settles a moment after the disarm
            }
            _wasArmed = false; _wasInMission = false
        }
    }
    on_InMissionChanged: if (_inMission && _armed) _wasInMission = true
    Timer {
        id: decide
        interval: 1500
        onTriggered: {
            mr.finished = !(mr.guided && mr.guided.showResumeMission)
            mr.resumeIndex = mr.guided ? mr.guided._resumeMissionIndex : 0
            mr.itemCount = mr.plan ? mr.plan.missionController.missionItemCount : 0
            mr.shown = true
        }
    }
    Connections {
        target: mr.vs ? mr.vs.vehicle : null
        ignoreUnknownSignals: true
        function onMissionImageCountChanged(n) { if (mr.shown && n >= 0) mr.photos = n }   // counted a moment after the end
    }

    visible: shown
    // narrower when the banner column is narrowed by a right panel (code review 2026-11-21, bug #28587)
    width: parent && parent.bannerWidth > 0 ? Math.min(SimpleTheme.px(1000), Math.max(SimpleTheme.px(640), parent.bannerWidth)) : SimpleTheme.px(1000)   // 4 values need 640
    height: col.height + SimpleTheme.px(48)
    radius: SimpleTheme.px(26)
    color: SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.95)
    border.width: SimpleTheme.px(2); border.color: SimpleTheme.line
    MouseArea { anchors.fill: parent }

    Column {
        id: col
        x: SimpleTheme.px(28); y: SimpleTheme.px(24); width: parent.width - SimpleTheme.px(56)
        spacing: SimpleTheme.px(16)
        Item {
            width: parent.width; height: SimpleTheme.px(60)
            Rectangle {
                id: dot
                width: SimpleTheme.px(52); height: width; radius: width / 2; anchors.verticalCenter: parent.verticalCenter
                color: SimpleTheme.withAlpha(mr.finished ? SimpleTheme.ok : SimpleTheme.warn, 0.22)
                SIcon { anchors.centerIn: parent; name: mr.finished ? "check" : "warn"; size: 32; color: mr.finished ? SimpleTheme.ok : SimpleTheme.warn }
            }
            Column {
                anchors.left: dot.right; anchors.leftMargin: SimpleTheme.px(16); anchors.right: pct.left; anchors.rightMargin: SimpleTheme.px(16)
                anchors.verticalCenter: parent.verticalCenter
                SText { text: mr.finished ? qsTr("Mission complete") : qsTr("Mission not finished"); size: 32; bold: true }
                SText { width: parent.width; size: 22; color: SimpleTheme.textSecondary; elide: Text.ElideRight
                        text: mr.finished ? mr.planName
                            : qsTr("%1 · stopped after waypoint %2").arg(mr.planName).arg(mr.resumeIndex) }
            }
            SText { id: pct; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; size: 30; bold: true
                    color: mr.finished ? SimpleTheme.ok : SimpleTheme.warn
                    text: mr.finished ? "100 %" : (mr.itemCount > 1 ? Math.round(100 * mr.resumeIndex / (mr.itemCount - 1)) + " %" : "") }
        }
        SNotice { visible: !mr.finished && mr.reason !== ""; level: "warn"; text: mr.reason }
        Row {
            spacing: SimpleTheme.px(12)
            Repeater {
                model: [
                    { l: qsTr("FLIGHT TIME"), v: mr.flightTime, u: "" },
                    { l: qsTr("DISTANCE"),    v: mr.distance,   u: "" },
                    { l: qsTr("PHOTOS"),      v: mr.photos >= 0 ? String(mr.photos) : "—", u: "" },
                    { l: qsTr("BATTERY"),     v: isNaN(mr.battStart) || isNaN(mr.battEnd) ? "—" : Math.round(mr.battStart) + " → " + Math.round(mr.battEnd), u: isNaN(mr.battEnd) ? "" : "%" }
                ]
                Rectangle {
                    width: (col.width - 3 * SimpleTheme.px(12)) / 4; height: SimpleTheme.px(90); radius: SimpleTheme.px(16)
                    color: SimpleTheme.surfaceRaised
                    Column {
                        x: SimpleTheme.px(18); anchors.verticalCenter: parent.verticalCenter
                        SText { text: modelData.l; size: 18; medium: true; color: SimpleTheme.textSecondary }
                        Row {
                            spacing: SimpleTheme.px(6)
                            SText { text: modelData.v; size: 34; bold: true }
                            SText { text: modelData.u; size: 20; color: SimpleTheme.textSecondary; y: SimpleTheme.px(14) }
                        }
                    }
                }
            }
        }
        SText {
            width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
            text: (mr.logSaved ? qsTr("Flight log saved.") + " " : "")
                + (mr.resumed ? qsTr("Ready: the next flight starts at waypoint %1.").arg(mr.resumeIndex)
                   : mr.finished ? qsTr("The mission stays on the drone: Start mission flies it again.")
                   : qsTr("Next flight can continue from waypoint %1 (photos already taken are kept).").arg(mr.resumeIndex))
        }
        Row {
            spacing: SimpleTheme.px(12)
            readonly property real _w: mr.finished || mr.resumed ? (col.width - SimpleTheme.px(12)) / 2 : (col.width - 2 * SimpleTheme.px(12)) / 3
            SButton {
                objectName: "missionRemove"
                visible: mr.vs && mr.vs.connected
                width: parent._w; designHeight: 72; textSize: 24; kind: "danger"; icon: "trash"
                text: mr.finished ? qsTr("Remove mission from drone") : qsTr("Remove from drone")
                onClicked: { mr.plan.removeAllFromVehicle(); mr.shown = false; mr.toast(qsTr("Mission removed from the drone")) }
            }
            SButton {
                objectName: "missionKeep"
                visible: !mr.finished && !mr.resumed
                width: parent._w; designHeight: 72; textSize: 24
                text: qsTr("Keep as is"); onClicked: mr.shown = false
            }
            SButton {
                objectName: "missionDone"
                width: parent._w; designHeight: 72; textSize: 24; kind: "primary"
                icon: mr.finished || mr.resumed ? "" : "plan"
                text: mr.finished || mr.resumed ? qsTr("Done") : qsTr("Continue from waypoint %1").arg(mr.resumeIndex)
                onClicked: {
                    if (mr.finished || mr.resumed) { mr.shown = false; return }
                    mr.guided.executeAction(mr.guided.actionResumeMission, null, null)
                    mr.resumed = true
                }
            }
        }
    }
}
