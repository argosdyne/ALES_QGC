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

    // Why Go here cannot be used ("" = it can). red = refused for safety (shown in red instead of the button text).
    readonly property var goHereBlock: {
        if (!vs || !vs.present)             return { text: qsTr("No drone connected"), red: false }
        if (vs.lost)                        return { text: qsTr("Not available while the signal is lost"), red: false }
        if (!vs.flying)                     return { text: qsTr("Available after take-off"), red: false }
        if (!_guided || !_guided.showGotoLocation) return { text: qsTr("Not available now"), red: false }
        if (!_valid || !_vehPos)            return { text: qsTr("Drone position unknown"), red: false }
        if (_zm) {
            var here = _zm.zoneAt(coordinate)
            if (here && (here.zoneClass === 1 || here.noEntry))
                return { text: qsTr("Inside %1 — the drone may not fly there").arg(here.zoneName !== "" ? here.zoneName : qsTr("a prohibited zone")), red: true }
            var way = _zm.zoneOnPath([_veh.coordinate, coordinate])
            if (way && (way.zoneClass === 1 || way.noEntry))
                return { text: qsTr("The way crosses %1 — choose another point").arg(way.zoneName !== "" ? way.zoneName : qsTr("a prohibited zone")), red: true }
        }
        if (_fence && _fence.fenceLoaded) {
            var reason = _fence.goToTargetBlockReason(coordinate)
            if (reason !== "") return { text: reason, red: true }
        }
        var maxD = Number(_fly.maxGoToLocationDistance.rawValue)
        if (maxD > 0 && distance > maxD)    return { text: qsTr("Too far — Go here reaches up to %1").arg(hDist(maxD)), red: true }
        return { text: "", red: false }
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
                width: parent.width; height: SimpleTheme.px(104); radius: SimpleTheme.px(16)
                color: _ok ? (goMa.pressed ? SimpleTheme.brandGreenDark : SimpleTheme.brandGreen)
                           : tm.goHereBlock.red ? SimpleTheme.withAlpha(SimpleTheme.danger, 0.25) : SimpleTheme.surfaceRaised
                border.width: tm.goHereBlock.red ? SimpleTheme.px(2) : 0; border.color: SimpleTheme.danger
                SIcon { id: goIcon; x: SimpleTheme.px(22); anchors.verticalCenter: parent.verticalCenter; name: tm.goHereBlock.red ? "warn" : "pin"; size: 36
                        opacity: goRow._ok || tm.goHereBlock.red ? 1 : 0.45 }
                Column {
                    anchors.left: goIcon.right; anchors.leftMargin: SimpleTheme.px(18)
                    anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(14)
                    anchors.verticalCenter: parent.verticalCenter
                    SText { text: qsTr("Go here"); size: 28; bold: true; opacity: goRow._ok || tm.goHereBlock.red ? 1 : 0.45 }
                    SText {
                        width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2
                        size: 21
                        color: goRow._ok ? SimpleTheme.textPrimary : tm.goHereBlock.red ? SimpleTheme.textDanger : SimpleTheme.textSecondary
                        text: goRow._ok ? qsTr("Fly to this point at %1").arg(tm.vDist(Number(tm._veh.altitudeRelative.rawValue))) : tm.goHereBlock.text
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
