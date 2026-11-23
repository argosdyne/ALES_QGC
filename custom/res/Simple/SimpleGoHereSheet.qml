/****************************************************************************
 * AQGC Simple UI — S35 → Go here confirm sheet (same pattern as S03): height · obstacle detection · time + slide
 * Sends the classic GoTo (GuidedActionsController.actionGoto, MAV_CMD_DO_REPOSITION) with the same data as the
 * classic GoTo editor, so progress, arrival and termination use the classic FlyViewMap GoTo state (S36).
 ****************************************************************************/
import QtQuick 2.12
import QtPositioning 5.12
import QGroundControl 1.0
import "."

SPanel {
    id: sheet
    property var  vehicle:    null
    property var  map:        null
    property var  coordinate: QtPositioning.coordinate()
    property real heightM:    NaN       // target height above home (m)
    signal sent(bool ok)

    readonly property var  _units:  QGroundControl.unitsConversion
    readonly property var  _fly:    QGroundControl.settingsManager.flyViewSettings
    readonly property var  _app:    QGroundControl.settingsManager.appSettings
    readonly property real _minM:   Number(_fly.guidedMinimumAltitude.rawValue)
    readonly property real _maxM:   Number(_fly.guidedMaximumAltitude.rawValue)
    readonly property real _nowM:   vehicle ? Number(vehicle.altitudeRelative.rawValue) : NaN
    readonly property real _homeAMSL: vehicle ? Number(vehicle.altitudeAMSL.rawValue) - Number(vehicle.altitudeRelative.rawValue) : NaN
    readonly property real distance: vehicle && vehicle.coordinate.isValid && coordinate.isValid ? vehicle.coordinate.distanceTo(coordinate) : NaN
    readonly property bool obstacleOn: !!vehicle && !!vehicle.objectAvoidance && vehicle.objectAvoidance.available && vehicle.objectAvoidance.enabled
    // planning speeds, as in the classic GoTo editor (an estimate)
    readonly property real etaSec: {
        var h = Number(_app.offlineEditingHoverSpeed.rawValue)
        var dz = heightM - _nowM
        var v = Number((dz >= 0 ? _app.offlineEditingAscentSpeed : _app.offlineEditingDescentSpeed).rawValue)
        return isFinite(distance) && isFinite(dz) && h > 0 && v > 0 ? distance / h + Math.abs(dz) / v : NaN
    }
    readonly property bool _ok: isFinite(heightM) && isFinite(_homeAMSL) && coordinate.isValid

    function _toDisp(m) { return Number(_units.metersToAppSettingsVerticalDistanceUnits(m)) }
    function _toM(d)    { return Number(_units.appSettingsVerticalDistanceUnitsToMeters(d)) }
    readonly property string _vu: _units.appSettingsVerticalDistanceUnitsString
    function _hDist(m) { return Math.round(_units.metersToAppSettingsHorizontalDistanceUnits(m)) + " " + _units.appSettingsHorizontalDistanceUnitsString }
    function _time(s) {
        if (!isFinite(s)) return "—"
        s = Math.round(s)
        return s < 60 ? qsTr("%1 s").arg(s) : qsTr("%1 min %2 s").arg(Math.floor(s / 60)).arg(s % 60)
    }

    width:  SimpleTheme.px(980)
    height: col.implicitHeight + SimpleTheme.px(136)
    title:  qsTr("Go here")
    titleIcon: "pin"
    // start at the current height (rounded); called when the sheet opens
    function _init() {
        slider.reset()
        heightM = isFinite(_nowM) ? Math.max(_minM, Math.min(_maxM, Math.round(_nowM))) : _minM
    }
    onVisibleChanged: if (visible) _init()
    Component.onCompleted: _init()

    function send() {
        var g = globals.guidedControllerFlyView
        if (!g || !_ok || !map) { sent(false); return }
        var target = QtPositioning.coordinate(coordinate.latitude, coordinate.longitude, heightM + _homeAMSL)
        g.executeAction(g.actionGoto, {
            coordinate:   target,
            vehicle:      vehicle,
            map:          map,
            altitudeMode: Number(_fly.gotoAltitudeReference.rawValue)
        }, 0, false)
        // the map starts its GoTo progress only when the drone took the command
        sent(map.gotoProgressActive)
    }

    Column {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        spacing: SimpleTheme.px(20)
        Row {
            spacing: SimpleTheme.px(24)
            SStepper {
                id: stepper
                value: Math.round(sheet._toDisp(sheet.heightM)); step: 1; unit: sheet._vu
                from: Math.ceil(sheet._toDisp(sheet._minM)); to: Math.floor(sheet._toDisp(sheet._maxM))
                onEdited: sheet.heightM = sheet._toM(value)
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: SimpleTheme.px(4)
                SText { text: qsTr("Height above home"); size: 24; medium: true }
                SText {
                    size: 22; color: SimpleTheme.textSecondary
                    text: qsTr("Now %1 · allowed %2 – %3").arg(Math.round(sheet._toDisp(sheet._nowM)) + " " + sheet._vu)
                          .arg(Math.ceil(sheet._toDisp(sheet._minM))).arg(Math.floor(sheet._toDisp(sheet._maxM)) + " " + sheet._vu)
                }
            }
        }
        SText {
            width: parent.width; wrapMode: Text.WordWrap; size: 26
            text: qsTr("The drone flies straight to the pin (%1, about %2) and holds position there.")
                  .arg(isFinite(sheet.distance) ? sheet._hDist(sheet.distance) : "—").arg(sheet._time(sheet.etaSec))
        }
        Row {
            spacing: SimpleTheme.px(10)
            SIcon { name: sheet.obstacleOn ? "check" : "warn"; size: 28; color: sheet.obstacleOn ? SimpleTheme.ok : SimpleTheme.warn; anchors.verticalCenter: parent.verticalCenter }
            SText {
                size: 22; color: sheet.obstacleOn ? SimpleTheme.textSecondary : SimpleTheme.warn
                text: sheet.obstacleOn ? qsTr("Obstacle detection on — the drone stops in front of obstacles.")
                                       : qsTr("This drone cannot detect obstacles. Check that the way is clear.")
            }
        }
        // terrain (decision 2026-11-16): the height is above home, the app has no ground height along the way
        Row {
            width: parent.width
            spacing: SimpleTheme.px(10)
            SIcon { id: terrainIcon; name: "warn"; size: 28; color: SimpleTheme.warn }
            SText {
                width: parent.width - terrainIcon.width - parent.spacing
                wrapMode: Text.WordWrap
                size: 22; color: SimpleTheme.warn
                text: qsTr("Height is above the home point, not above the ground. Check for hills and buildings on the way.")
            }
        }
        SSlideConfirm {
            id: slider
            width: parent.width
            text: qsTr("Slide to go")
            onConfirmed: sheet.send()
        }
    }
}
