/****************************************************************************
 * AQGC Simple UI — S39 check before sending (red = blocked, orange = caution)
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import QGroundControl.FactSystem 1.0
import "."

SPanel {
    id: chk
    property var  vs
    property var  plan
    property var  survey
    property var  route: null           // S23: waypoint coordinates (instead of the survey transects)
    property real routeHeight: NaN      // S23: highest waypoint (instead of the survey height)
    property real maxAlt: 120
    closable: false
    title: qsTr("Check before sending")

    readonly property var  _mission:    plan ? plan.missionController : null
    readonly property real _alt:        isFinite(routeHeight) ? routeHeight : survey && survey.cameraCalc ? survey.cameraCalc.distanceToSurface.rawValue : 0
    readonly property real _maxDist:    _mission ? _mission.missionMaxTelemetry : 0
    // Flight zones on the route (decision 2026-11-15): prohibited / "do not enter" = blocked, others = caution
    readonly property var  _zm:         typeof mainWindow !== "undefined" ? mainWindow.flightZoneManager : null
    readonly property var  _zone: {
        if (!_zm || !visible) return { zoneClass: 0, zoneName: "", noEntry: false }
        var path = []
        var home = vs.present && vs.vehicle.homePosition.isValid ? vs.vehicle.homePosition : null
        if (home) path.push(home)
        var t = route ? route : survey ? survey.visualTransectPoints : []
        for (var i = 0; i < t.length; i++) path.push(t[i])
        if (home && path.length > 1) path.push(home)       // the way back home at the end (RTL)
        _zm.polygons.count; _zm.circles.count       // re-check when the zone data changes
        return _zm.zoneOnPath(path)
    }
    readonly property int  _zoneLvl:    !_zm ? 1 : (_zone.zoneClass === 1 || _zone.noEntry) ? 2
                                        : (_zone.zoneClass === 2 || _zone.zoneClass === 4) ? 1
                                        : _zone.zoneClass === 3 ? 0 : (_zm.polygons.count + _zm.circles.count > 0 ? 0 : 1)
    readonly property int  _batteries:  _mission ? _mission.batteriesRequired : -1
    property bool _sent: false
    property bool _sendFailed: false        // the drone refused the mission (e.g. a command it does not support)
    property bool _missionOk: false

    // FactPanelController binds to the active vehicle when it is created, so create it only once
    // the vehicle's parameters are ready (and again for a new vehicle).
    Loader { id: fpcLoader; visible: false; active: vs.paramsReady; sourceComponent: Component { FactPanelController { } } }
    // created again for another active drone (FactPanelController keeps the vehicle it was created with)
    Connections {
        target: vs
        function onVehicleChanged() { fpcLoader.active = false; fpcLoader.active = Qt.binding(function() { return vs.paramsReady }) }
    }
    readonly property string _fenceName: vs.present && vs.vehicle.apmFirmware ? "FENCE_RADIUS" : "GF_MAX_HOR_DIST"
    readonly property var _fenceRad: fpcLoader.item && fpcLoader.item.parameterExists(-1, _fenceName)
                                     ? fpcLoader.item.getParameterFact(-1, _fenceName, false) : null
    readonly property real _distLimit: _fenceRad && _fenceRad.rawValue > 0 ? _fenceRad.rawValue : 500
    // The distance limit blocks sending only when the drone's geofence is on: the FC enforces it then, and Go here uses
    // the same rule. With the fence off it is a caution (Tuleap bug #28586: the check blocked at 300 m while
    // Go here allowed 364 m). PX4 has no fence on/off parameter here: treated as on.
    readonly property var  _fenceEn:  vs.present && vs.vehicle.apmFirmware && fpcLoader.item && fpcLoader.item.parameterExists(-1, "FENCE_ENABLE")
                                      ? fpcLoader.item.getParameterFact(-1, "FENCE_ENABLE", false) : null
    // FENCE_TYPE value 2 (bit 1) = circle (FENCE_RADIUS): with only the polygon / altitude fence on, the radius is not enforced
    readonly property var  _fenceType: _fenceEn && fpcLoader.item.parameterExists(-1, "FENCE_TYPE")
                                       ? fpcLoader.item.getParameterFact(-1, "FENCE_TYPE", false) : null
    // FENCE_ENABLE is only the ground-time state: the fence also counts as on when it can be turned on in flight
    // (FENCE_AUTOENABLE, an RC switch RCn_OPTION = 11, or a DO_FENCE_ENABLE item in this mission) (code review 2026-11-21)
    function _fenceCanTurnOn() {
        var f = fpcLoader.item
        if (!f) return false
        if (f.parameterExists(-1, "FENCE_AUTOENABLE") && Number(f.getParameterFact(-1, "FENCE_AUTOENABLE", false).rawValue) !== 0) return true
        for (var n = 1; n <= 16; n++) {
            var o = "RC" + n + "_OPTION"
            if (f.parameterExists(-1, o) && Number(f.getParameterFact(-1, o, false).rawValue) === 11) return true
        }
        var items = _mission ? _mission.visualItems : null
        if (items) for (var i = 0; i < items.count; i++) {
            var it = items.get(i)
            if (!it || it.command !== 207) continue                  // MAV_CMD_DO_FENCE_ENABLE
            // param1: 1 = enable, 0 = disable, 2 = disable floor only; unknown (raw edit) counts as enable
            // raw edit: comboboxFacts are command / frame, not param1, so count it as enable
            if (it.rawEdit) return true
            var p1 = it.comboboxFacts && it.comboboxFacts.count > 0 ? it.comboboxFacts.get(0) : null
            if (!p1 || Number(p1.rawValue) === 1) return true
        }
        return false
    }
    readonly property bool _fenceOn:  !_fenceEn || ((Number(_fenceEn.rawValue) !== 0 || _fenceCanTurnOn())
                                                    && (!_fenceType || (Number(_fenceType.rawValue) & 2) !== 0))

    // level: 0 ok, 1 caution, 2 blocked
    readonly property var _checks: [
        { lvl: _alt > maxAlt ? 2 : 0, t: qsTr("Height"), d: qsTr("%1 m (limit %2 m)").arg(Math.round(_alt)).arg(maxAlt) },
        { lvl: _maxDist > _distLimit ? (_fenceOn ? 2 : 1) : 0, t: qsTr("Distance"),
          d: _maxDist <= _distLimit ? qsTr("Farthest point %1 m (limit %2 m)").arg(Math.round(_maxDist)).arg(Math.round(_distLimit))
           : _fenceOn ? qsTr("Farthest point %1 m (limit %2 m). Make the area smaller or raise Maximum distance in Settings › Safety.").arg(Math.round(_maxDist)).arg(Math.round(_distLimit))
           : _fenceEn && (Number(_fenceEn.rawValue) !== 0 || _fenceCanTurnOn())
             ? qsTr("Farthest point %1 m — over Maximum distance %2 m (the drone's fence has no distance limit: not enforced)").arg(Math.round(_maxDist)).arg(Math.round(_distLimit))
             : qsTr("Farthest point %1 m — over Maximum distance %2 m (geofence off: not enforced)").arg(Math.round(_maxDist)).arg(Math.round(_distLimit)) },
        { lvl: _batteries > 1 ? 1 : 0, t: qsTr("Battery"), d: _batteries > 1 ? qsTr("Needs %1 batteries — the drone returns to swap").arg(_batteries) : _batteries === 1 ? qsTr("Fits one battery") : qsTr("Not estimated for this drone") },
        { lvl: _zoneLvl, t: qsTr("Flight zones"),
          d: !_zm ? qsTr("Check the zones on the map yourself")
           : _zone.zoneClass === 0 ? (_zm.polygons.count + _zm.circles.count > 0 ? qsTr("No restricted zone on the route") : qsTr("No zone data — check the zones yourself"))
           : _zoneLvl === 2 ? qsTr("The route enters a no-fly zone (%1). Move the area.").arg(_zone.zoneName)
           : _zone.zoneClass === 3 ? qsTr("Information zone on the route (%1)").arg(_zone.zoneName)
           : qsTr("The route touches %1. Check that you may fly there.").arg(_zone.zoneName) },
        { lvl: vs.connected ? 0 : 2, t: qsTr("Drone"), d: vs.connected ? qsTr("Connected") : qsTr("Not connected — the mission stays on this tablet") }
    ]
    readonly property bool _blocked: { for (var i = 0; i < _checks.length; i++) if (_checks[i].lvl === 2) return true; return false }

    onVisibleChanged: if (visible) { _sent = false; _sendFailed = false; _missionOk = false }
    Connections {
        target: chk.plan
        // fence and rally points follow the mission: "sent" only when everything ended and the mission was accepted
        function onSyncInProgressChanged() { if (chk.plan && !chk.plan.syncInProgress && chk.visible && chk._missionOk) chk._sent = true }
    }
    Connections {
        target: chk.plan ? chk.plan.missionController : null
        function onSendToVehicleFinished(error) { chk._missionOk = !error; chk._sendFailed = error }
    }

    Column {
        anchors.fill: parent
        spacing: SimpleTheme.px(10)
        Repeater {
            model: chk._checks
            Rectangle {
                width: parent.width; height: SimpleTheme.px(92); radius: SimpleTheme.px(16)
                color: modelData.lvl === 0 ? SimpleTheme.surfaceRaised : modelData.lvl === 1 ? SimpleTheme.withAlpha(SimpleTheme.warn, 0.14) : SimpleTheme.withAlpha(SimpleTheme.danger, 0.16)
                border.width: modelData.lvl === 0 ? 0 : SimpleTheme.px(2)
                border.color: modelData.lvl === 1 ? SimpleTheme.warn : SimpleTheme.danger
                SIcon {
                    id: ic
                    anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                    name: modelData.lvl === 0 ? "check" : "warn"; size: 36
                    color: modelData.lvl === 0 ? SimpleTheme.ok : modelData.lvl === 1 ? SimpleTheme.warn : SimpleTheme.textDanger
                }
                Column {
                    anchors.left: ic.right; anchors.leftMargin: SimpleTheme.px(14); anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(12)
                    anchors.verticalCenter: parent.verticalCenter
                    SText { width: parent.width; text: modelData.t; size: 26; medium: true }
                    SText { width: parent.width; text: modelData.d; size: 22; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                }
            }
        }
    }

    Column {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: SimpleTheme.px(28)
        spacing: SimpleTheme.px(10)
        SText {
            visible: chk.plan && chk.plan.syncInProgress
            text: qsTr("Sending to drone… %1 %").arg(chk.plan && chk._mission ? Math.round(chk._mission.progressPct * 100) : 0)
            size: 24; medium: true; color: SimpleTheme.textSecondary
        }
        Rectangle {
            visible: chk.plan && chk.plan.syncInProgress
            width: parent.width; height: SimpleTheme.px(14); radius: height / 2; color: SimpleTheme.surfaceControl
            Rectangle { width: parent.width * (chk._mission ? chk._mission.progressPct : 0); height: parent.height; radius: height / 2; color: SimpleTheme.brandGreen }
        }
        SText { visible: chk._sendFailed; width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textDanger
                text: qsTr("The drone did not accept the mission. Check the message, change the mission and send again.") }
        SText { visible: chk._blocked && !chk._sent; width: parent.width; wrapMode: Text.WordWrap; text: qsTr("Fix the red items before sending."); size: 22; color: SimpleTheme.textDanger }
        SButton {
            width: parent.width
            kind: "primary"
            visible: !chk._sent
            enabled_: !chk._blocked && chk.plan && !chk.plan.syncInProgress
            text: qsTr("Send to drone")
            onClicked: {
                // the drone fence is sent with the plan: keep the "do not enter" My zones in it (decision 2026-11-15)
                if (chk._zm) chk._zm.applyMyZonesToFence(chk.plan.geoFenceController)
                chk._sendFailed = false; chk._missionOk = false
                chk.plan.sendToVehicle()
            }
        }
        SButton {
            width: parent.width
            kind: "primary"
            visible: chk._sent
            icon: "map"
            text: qsTr("Sent — go to Fly")
            onClicked: simpleRoot.showFly()
        }
    }
}
