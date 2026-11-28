/****************************************************************************
 * AQGC Simple UI — S35 map tap menu: pin at the tapped point + Go here · Set as home point · Enter coordinates
 * Rules (02 Flows, classic GoTo G-01/G-03):
 * - Go here only while flying with a live link; on the ground it is disabled ("Available after take-off").
 * - A target inside a prohibited / "do not enter" zone, or a way that crosses one, is refused in red (no Go here).
 *   The classic GoTo checks also apply: geofence (GeoFenceController.goToTargetBlockReason) and the maximum
 *   GoTo distance (Fly view settings).
 * - Set as home point is offered when the classic guided bar offers it (showSetHome).
 * - Flight zones under the tap (Layers › Flight zones on) are listed at the top; "Details" opens the S15 card.
 * The menu follows the pin when the map moves (drone tracking keeps re-centring the map).
 ****************************************************************************/
import QtQuick 2.12
import QtPositioning 5.12
import QGroundControl 1.0
import "."

Item {
    id: tm
    property var  map:        null      // FlyViewMap
    property var  vs:         null
    property var  coordinate: QtPositioning.coordinate()
    property var  zones:      []        // S15 zones under the tap (SimpleMapControls.zonesAt), most restrictive first
    property real bottomLimit: height   // keep the card above the telemetry bar
    signal goHereRequested(var coordinate)
    signal setHomeRequested(var coordinate)
    signal coordinatesRequested()
    signal zoneDetailsRequested(var coordinate)
    signal closeRequested()

    readonly property var  _veh:    vs ? vs.vehicle : null
    readonly property var  _guided: globals.guidedControllerFlyView
    readonly property var  _units:  QGroundControl.unitsConversion
    readonly property var  _fly:    QGroundControl.settingsManager.flyViewSettings
    readonly property var  _zm:     typeof mainWindow !== "undefined" ? mainWindow.flightZoneManager : null
    readonly property var  _fence:  globals.planMasterControllerFlyView ? globals.planMasterControllerFlyView.geoFenceController : null
    readonly property bool _valid:  coordinate && coordinate.isValid
    readonly property bool _vehPos: !!_veh && _veh.coordinate.isValid

    // pin position on screen; re-evaluated when the map pans, zooms or turns
    readonly property point _pt: {
        if (!map || !_valid) return Qt.point(-1000, -1000)
        var dep = map.center.latitude + map.center.longitude + map.zoomLevel + map.bearing + map.width + map.height
        return map.fromCoordinate(coordinate, false)
    }

    function hDist(m) {
        return Math.round(_units.metersToAppSettingsHorizontalDistanceUnits(m)) + " " + _units.appSettingsHorizontalDistanceUnitsString
    }
    function vDist(m) {
        return Math.round(_units.metersToAppSettingsVerticalDistanceUnits(m)) + " " + _units.appSettingsVerticalDistanceUnitsString
    }

    readonly property real distance: _vehPos && _valid ? _veh.coordinate.distanceTo(coordinate) : NaN
    readonly property real bearing:  _vehPos && _valid ? _veh.coordinate.azimuthTo(coordinate) : NaN

    // Why Go here cannot be used (text "" = it can). Grey states (no drone, signal lost, on the ground, ...) give one reason.
    // red = refused for safety: every failed check is listed with what to do (Tuleap bugs #36984, #36986), as
    // reasons [{ text, action }]; text = the first reason. The Go here sheet runs the same checks again when the slide
    // completes (Tuleap bug #36993).
    readonly property var goHereBlock: goHereBlockNow()
    function goHereBlockNow() {
        if (!vs || !vs.present)             return { text: qsTr("No drone connected"), red: false, reasons: [] }
        if (vs.lost)                        return { text: qsTr("Not available while the signal is lost"), red: false, reasons: [] }
        if (!vs.flying)                     return { text: qsTr("Available after take-off"), red: false, reasons: [] }
        if (!_guided || !_guided.showGotoLocation) return { text: qsTr("Not available now"), red: false, reasons: [] }
        if (!_valid || !_vehPos)            return { text: qsTr("Drone position unknown"), red: false, reasons: [] }
        var r = []
        if (_zm) {
            var here = _zm.zoneAt(coordinate)
            var hereBlocks = !!here && (here.zoneClass === 1 || here.noEntry)
            if (hereBlocks)
                r.push({ text: qsTr("Inside %1 — the drone may not fly there").arg(here.zoneName !== "" ? here.zoneName : qsTr("a prohibited zone")),
                         action: qsTr("Choose a point outside the zone.") })
            var way = _zm.zoneOnPath([_veh.coordinate, coordinate])
            // the zone the point is in is also "on the way": list it once
            if (way && (way.zoneClass === 1 || way.noEntry) && !(hereBlocks && way.zoneName === here.zoneName))
                r.push({ text: qsTr("The way crosses %1").arg(way.zoneName !== "" ? way.zoneName : qsTr("a prohibited zone")),
                         action: qsTr("Choose a point the drone can reach in a straight line without crossing the zone.") })
        }
        // the core text is not translated in the Simple UI (Tuleap bug #28581): own words
        if (_fence && _fence.fenceLoaded && _fence.goToTargetBlockReason(coordinate) !== "")
            r.push({ text: qsTr("Outside the geofence or in an excluded area"), action: qsTr("Choose a point inside the drone's fence.") })
        var maxD = Number(_fly.maxGoToLocationDistance.rawValue)
        if (maxD > 0 && distance > maxD)
            r.push({ text: qsTr("Too far — Go here reaches up to %1").arg(hDist(maxD)),
                     action: qsTr("Choose a closer point. The limit is in Settings › Fly screen (Advanced mode).") })
        return r.length > 0 ? { text: r[0].text, red: true, reasons: r } : { text: "", red: false, reasons: [] }
    }
    readonly property bool canSetHome: !!vs && vs.connected && !!_guided && _guided.showSetHome && _valid

    //---------------------------------------------------------------- pin
    SIcon {
        id: pin
        name: "pin"; size: 64; color: SimpleTheme.warn
        x: tm._pt.x - width / 2
        y: tm._pt.y - height
    }

    //---------------------------------------------------------------- card
    Rectangle {
        id: card
        readonly property real _gap: SimpleTheme.px(28)
        width: SimpleTheme.px(460)
        height: col.height + SimpleTheme.px(32)
        // right of the pin, or left of it when there is no room; inside the free map area
        // (left of the map control column at x 1382 and the camera rail, so neither is covered)
        x: {
            var right = tm._pt.x + _gap
            var left  = tm._pt.x - _gap - width
            var maxX  = SimpleTheme.px(1366) - width
            return right <= maxX ? right : Math.max(SimpleTheme.px(180), Math.min(left, maxX))
        }
        y: Math.max(SimpleTheme.px(SimpleTheme.topBarHeight + 16), Math.min(tm._pt.y - SimpleTheme.px(60), tm.bottomLimit - height))
        radius: SimpleTheme.px(20)
        color: SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.97)
        border.width: SimpleTheme.px(1); border.color: SimpleTheme.line
        MouseArea { anchors.fill: parent }      // keep taps off the map

        Column {
            id: col
            x: SimpleTheme.px(16); y: SimpleTheme.px(16)
            width: parent.width - SimpleTheme.px(32)
            spacing: SimpleTheme.px(10)

            Item {
                width: parent.width; height: SimpleTheme.px(44)
                SText {
                    anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(4)
                    anchors.right: closeIcon.left; anchors.verticalCenter: parent.verticalCenter
                    size: 24; color: SimpleTheme.textSecondary; elide: Text.ElideRight
                    text: isFinite(tm.distance) ? qsTr("%1 away · %2°").arg(tm.hDist(tm.distance)).arg(Math.round((tm.bearing + 360) % 360))
                                                : (tm._valid ? tm.coordinate.latitude.toFixed(6) + ", " + tm.coordinate.longitude.toFixed(6) : "")
                }
                SIcon {
                    id: closeIcon
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    name: "close"; size: 36; color: SimpleTheme.textSecondary
                    MouseArea { anchors.fill: parent; anchors.margins: -SimpleTheme.px(16); onClicked: tm.closeRequested() }
                }
            }

            // flight zones under the tap
            Rectangle {
                visible: tm.zones.length > 0
                readonly property var zone: tm.zones.length > 0 ? tm.zones[0] : null
                readonly property color _c: !zone ? SimpleTheme.info : zone.zoneClass === 1 ? SimpleTheme.danger : zone.zoneClass === 2 ? SimpleTheme.warn
                                          : zone.zoneClass === 4 ? SimpleTheme.surfaceControl : SimpleTheme.info
                width: parent.width; height: SimpleTheme.px(72); radius: SimpleTheme.px(14)
                color: SimpleTheme.withAlpha(_c, 0.25)
                border.width: SimpleTheme.px(2); border.color: _c
                SIcon { id: zIcon; x: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter; name: "warn"; size: 32 }
                SText {
                    anchors.left: zIcon.right; anchors.leftMargin: SimpleTheme.px(12)
                    anchors.right: zMore.left; anchors.rightMargin: SimpleTheme.px(8)
                    anchors.verticalCenter: parent.verticalCenter
                    size: 22; medium: true; elide: Text.ElideRight
                    text: !parent.zone ? "" : (parent.zone.zoneClass === 1 ? qsTr("Prohibited") : parent.zone.zoneClass === 2 ? qsTr("Authorisation required")
                                          : parent.zone.zoneClass === 4 ? qsTr("My zone") : qsTr("Information"))
                                          + (parent.zone.zoneName !== "" ? " · " + parent.zone.zoneName : "")
                }
                SText {
                    id: zMore
                    anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Details"); size: 22; color: SimpleTheme.textLink
                }
                MouseArea { anchors.fill: parent; onClicked: tm.zoneDetailsRequested(tm.coordinate) }
            }

            // Go here (green) — or the reason it is not possible
            Rectangle {
                id: goRow
                readonly property bool _ok: tm.goHereBlock.text === ""
                width: parent.width; height: Math.max(SimpleTheme.px(104), goCol.height + SimpleTheme.px(36)); radius: SimpleTheme.px(16)
                color: _ok ? (goMa.pressed ? SimpleTheme.brandGreenDark : SimpleTheme.brandGreen)
                           : tm.goHereBlock.red ? SimpleTheme.withAlpha(SimpleTheme.danger, 0.25) : SimpleTheme.surfaceRaised
                border.width: tm.goHereBlock.red ? SimpleTheme.px(2) : 0; border.color: SimpleTheme.danger
                SIcon { id: goIcon; x: SimpleTheme.px(22); y: tm.goHereBlock.red ? SimpleTheme.px(22) : (parent.height - height) / 2
                        name: tm.goHereBlock.red ? "warn" : "pin"; size: 36
                        opacity: goRow._ok || tm.goHereBlock.red ? 1 : 0.45 }
                Column {
                    id: goCol
                    anchors.left: goIcon.right; anchors.leftMargin: SimpleTheme.px(18)
                    anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: SimpleTheme.px(4)
                    SText { text: qsTr("Go here"); size: 28; bold: true; opacity: goRow._ok || tm.goHereBlock.red ? 1 : 0.45 }
                    SText {
                        visible: !tm.goHereBlock.red
                        width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2
                        size: 21
                        color: goRow._ok ? SimpleTheme.textPrimary : SimpleTheme.textSecondary
                        text: goRow._ok ? qsTr("Fly to this point at %1").arg(tm.vDist(Number(tm._veh.altitudeRelative.rawValue))) : tm.goHereBlock.text
                    }
                    // every refusal with what to do (Figma "S35 state · Go here refused")
                    Repeater {
                        model: tm.goHereBlock.red ? tm.goHereBlock.reasons : []
                        Column {
                            objectName: "goReason"
                            width: goCol.width
                            SText { width: parent.width; wrapMode: Text.WordWrap; size: 21; color: SimpleTheme.textDanger; text: "• " + modelData.text }
                            SText { width: parent.width; wrapMode: Text.WordWrap; size: 20; color: SimpleTheme.textSecondary; text: "→ " + modelData.action }
                        }
                    }
                }
                MouseArea { id: goMa; anchors.fill: parent; enabled: goRow._ok; onClicked: tm.goHereRequested(tm.coordinate) }
            }

            Rectangle {
                visible: tm.canSetHome
                width: parent.width; height: SimpleTheme.px(104); radius: SimpleTheme.px(16)
                color: homeMa.pressed ? SimpleTheme.surfaceControl : SimpleTheme.surfaceRaised
                SIcon { id: homeIcon; x: SimpleTheme.px(22); anchors.verticalCenter: parent.verticalCenter; name: "home"; size: 36 }
                Column {
                    anchors.left: homeIcon.right; anchors.leftMargin: SimpleTheme.px(18)
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    SText { text: qsTr("Set as home point"); size: 28; bold: true }
                    SText { text: qsTr("Return home will come here"); size: 21; color: SimpleTheme.textSecondary }
                }
                MouseArea { id: homeMa; anchors.fill: parent; onClicked: tm.setHomeRequested(tm.coordinate) }
            }

            Rectangle {
                width: parent.width; height: SimpleTheme.px(104); radius: SimpleTheme.px(16)
                color: coordMa.pressed ? SimpleTheme.surfaceControl : SimpleTheme.surfaceRaised
                SIcon { id: coordIcon; x: SimpleTheme.px(22); anchors.verticalCenter: parent.verticalCenter; name: "globe"; size: 36 }
                Column {
                    anchors.left: coordIcon.right; anchors.leftMargin: SimpleTheme.px(18)
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    SText { text: qsTr("Enter coordinates…"); size: 28; bold: true }
                    SText { text: qsTr("Type latitude / longitude"); size: 21; color: SimpleTheme.textSecondary }
                }
                MouseArea { id: coordMa; anchors.fill: parent; onClicked: tm.coordinatesRequested() }
            }
        }
    }
}
