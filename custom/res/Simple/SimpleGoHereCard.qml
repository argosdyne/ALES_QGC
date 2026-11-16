/****************************************************************************
 * AQGC Simple UI — S36 Go here in progress: card with remaining distance · height · obstacle detection
 * + Change target · Stop (stopped: Continue · Cancel). State comes from the classic FlyViewMap GoTo
 * (gotoProgressActive / Paused / Termination / ArrivalConfirmed), so the classic rules stay in one place.
 * Arrival (classic G-07): within 2 m, in the GoTo mode and slower than 0.3 m/s for 2 s.
 * Obstacles (classic G-05/G-06): nearest OBSTACLE_DISTANCE reading 3 m or less; stopped = slower than 0.3 m/s.
 ****************************************************************************/
import QtQuick 2.12
import QtPositioning 5.12
import QGroundControl 1.0
import "."

Rectangle {
    id: card
    property var map:     null
    property var vehicle: null
    signal changeTargetRequested()
    signal arrived()

    readonly property var  _units:   QGroundControl.unitsConversion
    readonly property var  _guided:  globals.guidedControllerFlyView
    readonly property bool active:   !!map && map.gotoProgressActive && map.gotoProgressTermination === "" && !map.gotoArrivalConfirmed
    readonly property bool paused:   active && map.gotoProgressPaused
    readonly property var  target:   map ? map.gotoProgressCoordinate : QtPositioning.coordinate()
    readonly property real remaining: vehicle && vehicle.coordinate.isValid && target && target.isValid ? vehicle.coordinate.distanceTo(target) : NaN
    readonly property real speed:    vehicle ? Number(vehicle.groundSpeed.rawValue) : NaN
    readonly property bool obstacleOn: !!vehicle && !!vehicle.objectAvoidance && vehicle.objectAvoidance.available && vehicle.objectAvoidance.enabled

    // nearest obstacle in metres (NaN = none / no sensor), as in the classic GoTo progress panel
    readonly property real obstacleM: {
        if (!vehicle || !vehicle.objectAvoidance || !vehicle.objectAvoidance.available) return NaN
        var minimum = Number.POSITIVE_INFINITY
        var maximum = Number(vehicle.objectAvoidance.maxDistance)
        var d = vehicle.objectAvoidance.distances
        for (var i = 0; i < d.length; i++) {
            var v = Number(d[i])
            if (isFinite(v) && v >= 0 && v < maximum) minimum = Math.min(minimum, v / 100.0)
        }
        return minimum === Number.POSITIVE_INFINITY ? NaN : minimum
    }
    readonly property bool obstacle:        active && !paused && isFinite(obstacleM) && obstacleM <= 3
    readonly property bool obstacleStopped: obstacle && (!isFinite(speed) || speed <= 0.3)
    readonly property bool obstacleAvoiding: obstacle && !obstacleStopped && obstacleOn

    readonly property bool _hoverCandidate: active && !paused && isFinite(remaining) && remaining <= 2 &&
                                            !!vehicle && vehicle.flightMode === vehicle.gotoFlightMode && isFinite(speed) && speed <= 0.3
    Timer {
        interval: 2000
        running: card._hoverCandidate
        onTriggered: if (card._hoverCandidate) { card.map.confirmGotoArrival(); card.arrived() }
    }

    function hDist(m) { return isFinite(m) ? Math.round(_units.metersToAppSettingsHorizontalDistanceUnits(m)) + " " + _units.appSettingsHorizontalDistanceUnitsString : "—" }
    function vDist(m) { return isFinite(m) ? Math.round(_units.metersToAppSettingsVerticalDistanceUnits(m)) + " " + _units.appSettingsVerticalDistanceUnitsString : "—" }

    function stop()     { if (_guided) _guided.executeAction(_guided.actionPause, null, 0, false) }
    function resume()   { if (_guided) _guided.executeAction(_guided.actionContinueGoTo, { map: map, vehicle: vehicle, coordinate: target }, 0, false) }
    // obstacle "Go around": send the same target again; the drone's own avoidance (BendyRuler / Dijkstra) finds the way
    function goAround() {
        if (!_guided || !target.isValid) return
        _guided.executeAction(_guided.actionGoto, { coordinate: target, vehicle: vehicle, map: map,
                                                     altitudeMode: map.gotoProgressAltitudeMode }, 0, false)
    }

    visible: active
    width:  SimpleTheme.px(800)
    height: SimpleTheme.px(104)
    radius: SimpleTheme.px(20)
    color:  SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.95)
    border.width: SimpleTheme.px(1); border.color: SimpleTheme.line
    MouseArea { anchors.fill: parent }

    SIcon {
        id: ic
        x: SimpleTheme.px(24); anchors.verticalCenter: parent.verticalCenter
        name: card.paused ? "pause" : "pin"; size: 40; color: card.paused ? SimpleTheme.textSecondary : SimpleTheme.warn
    }
    Column {
        anchors.left: ic.right; anchors.leftMargin: SimpleTheme.px(18)
        anchors.right: btns.left; anchors.rightMargin: SimpleTheme.px(16)
        anchors.verticalCenter: parent.verticalCenter
        SText {
            width: parent.width; size: 28; bold: true
            text: (card.paused ? qsTr("Stopped") : qsTr("Going to point")) + " · " + qsTr("%1 left").arg(card.hDist(card.remaining))
        }
        SText {
            width: parent.width; size: 21; color: SimpleTheme.textSecondary
            text: card.vDist(card.vehicle ? Number(card.vehicle.altitudeRelative.rawValue) : NaN) + " · "
                  + (card.obstacleOn ? qsTr("obstacle detection on") : qsTr("no obstacle detection"))
        }
    }
    Row {
        id: btns
        anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(14)
        anchors.verticalCenter: parent.verticalCenter
        spacing: SimpleTheme.px(12)
        SButton {
            designHeight: 76; textSize: 26
            kind: card.paused ? "primary" : "secondary"
            text: card.paused ? qsTr("Continue") : qsTr("Change target")
            onClicked: card.paused ? card.resume() : card.changeTargetRequested()
        }
        SButton {
            designHeight: 76; textSize: 26
            text: card.paused ? qsTr("Cancel") : qsTr("Stop")
            onClicked: card.paused ? card.map.clearGotoProgress() : card.stop()
        }
    }
}
