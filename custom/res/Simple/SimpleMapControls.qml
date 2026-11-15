import QtQuick 2.12
import QtPositioning 5.12
import QGroundControl 1.0
import "."

// Figma S30 map controls & layers (1920 x 1080 design):
// - button column left of the PiP (x 1382, bottom 24): Layers, Drone (centre on the drone), Me (centre on this
//   device), zoom + / −
// - Layers panel left of the column: map style, flight trail, keep drone in view, offline map status.
//   The "Flight zones" switch stays hidden until flight zone data exists (decision 2026-11-15)
// - scale bar top left under the menu (x 180, y 130; decision 2026-11-15)
// Hidden while the video is the main view (S18).
Item {
    id: mc
    property var map: null              // FlyViewMap (flightView.simpleMap)
    property var vehicle: null
    property bool layersOpen: false

    readonly property var  _fm:   QGroundControl.settingsManager.flightMapSettings
    readonly property var  _fly:  QGroundControl.settingsManager.flyViewSettings
    readonly property var  _mgr:  QGroundControl.mapEngineManager
    readonly property var  _gcs:  QGroundControl.qgcPositionManger ? QGroundControl.qgcPositionManger.gcsPosition : QtPositioning.coordinate()
    readonly property bool _vehOk: !!vehicle && vehicle.coordinate.isValid
    readonly property string _trailKey: "SimpleShowFlightTrail"
    // flight zones (FlightZoneManager, colours and visibility in FlightZoneManagerGeoFenceMapVisuals)
    readonly property var  _zones:      typeof mainWindow !== "undefined" ? mainWindow.flightZoneManager : null
    readonly property int  _zoneCount:  _zones ? _zones.polygons.count + _zones.circles.count : 0
    readonly property bool _zonesShown: typeof mainWindow !== "undefined" && mainWindow.simpleShowFlightZones
    function setZones(on) { mainWindow.simpleShowFlightZones = on; QGroundControl.saveBoolGlobalSetting("SimpleShowFlightZones", on) }

    // S15 zone details: zones under a map tap, most restrictive first (prohibited, authorisation, my zone, information)
    property var tappedZones: []
    function _rank(c) { return c === 1 ? 0 : c === 2 ? 1 : c === 4 ? 2 : 3 }
    function zonesAt(coord) {
        var out = []
        if (!_zones || !coord || !coord.isValid) return out
        for (var i = 0; i < _zones.polygons.count; i++) {
            var p = _zones.polygons.get(i)
            if (p && p.containsCoordinate(coord)) out.push(p)
        }
        for (var j = 0; j < _zones.circles.count; j++) {
            var c = _zones.circles.get(j)
            if (c && c.center.distanceTo(coord) <= Number(c.radius.rawValue)) out.push(c)
        }
        out.sort(function(a, b) { return mc._rank(a.zoneClass) - mc._rank(b.zoneClass) })
        return out
    }
    Connections {
        target: mc.map
        function onSimpleMapClicked(coordinate) {
            if (!mc.visible || !mc._zonesShown) return
            mc.layersOpen = false
            mc.tappedZones = mc.zonesAt(coordinate)
        }
    }
    function className(c) {
        return c === 1 ? qsTr("Prohibited") : c === 2 ? qsTr("Authorisation required") : c === 4 ? qsTr("My zone") : qsTr("Information")
    }
    function classColor(c) { return c === 1 ? SimpleTheme.danger : c === 2 ? SimpleTheme.warn : c === 4 ? SimpleTheme.surfaceControl : SimpleTheme.info }
    function heightText(z) {
        var u = QGroundControl.unitsConversion.appSettingsVerticalDistanceUnitsString
        function h(m) { return Math.round(QGroundControl.unitsConversion.metersToAppSettingsVerticalDistanceUnits(m)) + " " + u }
        var lo = z.altitudeMin > 0 ? h(z.altitudeMin) : qsTr("Ground")
        return z.altitudeMax >= 99999 ? qsTr("%1 and up").arg(lo) : lo + " – " + h(z.altitudeMax)
    }
    readonly property string sourceText: {
        if (mc._fly.dataType.rawValue === 1) return qsTr("Altitude Angel (online)")
        var f = String(mc._fly.filePath.rawValue)
        return f.substring(Math.max(f.lastIndexOf("/"), f.lastIndexOf("\\")) + 1)
    }

    function typeFor(kind) {
        var types = _mgr.mapTypeList(_fm.mapProvider.value)
        var re = kind === 0 ? /satellite/i : kind === 1 ? /(road|street)/i : /hybrid/i
        for (var i = 0; i < types.length; i++) if (re.test(types[i])) return types[i]
        return ""
    }
    readonly property int _curType: { var t = String(_fm.mapType.value); return t === typeFor(0) ? 0 : t === typeFor(1) ? 1 : t === typeFor(2) ? 2 : -1 }

    // offline map sets made by the user (QGC's "<name> Elevation" companion sets are not counted)
    readonly property int _offlineSets: {
        var n = 0, m = _mgr.tileSets
        for (var i = 0; i < m.count; i++) { var o = m.get(i); if (o && !o.defaultSet && o.mapTypeStr !== QGroundControl.elevationProviderName) n++ }
        return n
    }

    function centerOn(c) { if (map && c && c.isValid) map.center = c }
    function zoomBy(d) { if (map) map.zoomLevel = Math.max(map.minimumZoomLevel, Math.min(map.maximumZoomLevel, Math.round(map.zoomLevel) + d)) }
    function setTrail(on) { if (map) map.simpleShowTrail = on; QGroundControl.saveBoolGlobalSetting(_trailKey, on) }

    Component.onCompleted: {
        _mgr.loadTileSets()
        if (map) map.simpleShowTrail = QGroundControl.loadBoolGlobalSetting(_trailKey, true)
    }
    onVisibleChanged: if (!visible) { layersOpen = false; tappedZones = [] }

    // ---------------------------------------------------------------- scale bar (top left)
    Rectangle {
        id: scale
        x: SimpleTheme.px(180); y: SimpleTheme.px(130)
        width: Math.max(SimpleTheme.px(148), scaleBar.width + SimpleTheme.px(28)); height: SimpleTheme.px(54)
        radius: SimpleTheme.px(12)
        color: SimpleTheme.withAlpha(SimpleTheme.bgBase, 0.6)
        visible: _len > 0
        property real _len: 0           // length shown, in the app distance unit
        property real _barPx: 0
        // nice length (1, 2, 5 x 10^n) that fits in about 120 design px at the map centre
        function update() {
            if (!mc.map || mc.map.width <= 0) { _len = 0; return }
            var maxPx = SimpleTheme.px(120)
            var cy = mc.map.height / 2, cx = mc.map.width / 2
            var a = mc.map.toCoordinate(Qt.point(cx, cy), false), b = mc.map.toCoordinate(Qt.point(cx + maxPx, cy), false)
            if (!a.isValid || !b.isValid) { _len = 0; return }
            var maxU = Number(QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(a.distanceTo(b)))
            if (!(maxU > 0)) { _len = 0; return }
            var p = Math.pow(10, Math.floor(Math.log(maxU) / Math.LN10)), nice = p
            if (5 * p <= maxU) nice = 5 * p; else if (2 * p <= maxU) nice = 2 * p
            _len = nice; _barPx = maxPx * nice / maxU
        }
        Timer { id: scaleTimer; interval: 150; onTriggered: scale.update() }
        Connections {
            target: mc.map
            function onZoomLevelChanged() { scaleTimer.restart() }
            function onCenterChanged()    { scaleTimer.restart() }
            function onWidthChanged()     { scaleTimer.restart() }
        }
        Component.onCompleted: scaleTimer.start()
        SText {
            x: SimpleTheme.px(14); y: SimpleTheme.px(6); size: 24
            readonly property string _u: QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString
            text: _u === "m" && scale._len >= 1000 ? (scale._len / 1000) + " km" : scale._len + " " + _u
        }
        Rectangle { id: scaleBar; x: SimpleTheme.px(14); y: SimpleTheme.px(40); width: Math.round(scale._barPx); height: SimpleTheme.px(4); color: SimpleTheme.textPrimary }
    }

    // ---------------------------------------------------------------- flight zone legend (Figma S15)
    // Figma has it at x 24 above the telemetry bar; it moves right of the action buttons (x 190) so that it
    // does not cover the third action button in flight.
    Rectangle {
        visible: mc._zonesShown && mc._zoneCount > 0
        x: SimpleTheme.px(190)
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(1080 - 936 + 16)
        width: legendCol.width + SimpleTheme.px(36); height: legendCol.height + SimpleTheme.px(28)
        radius: SimpleTheme.px(18)
        color: SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
        Column {
            id: legendCol
            x: SimpleTheme.px(18); y: SimpleTheme.px(14)
            spacing: SimpleTheme.px(8)
            Repeater {
                model: { var m = [[qsTr("Prohibited"), SimpleTheme.danger], [qsTr("Authorisation required"), SimpleTheme.warn], [qsTr("Information"), SimpleTheme.info]]
                         if (mc._zones && mc._zones.myZoneList.length > 0) m.push([qsTr("My zones"), SimpleTheme.danger, true]); return m }
                Row {
                    spacing: SimpleTheme.px(10)
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: SimpleTheme.px(28); height: SimpleTheme.px(18); radius: SimpleTheme.px(4)
                        color: SimpleTheme.withAlpha(modelData[1], 0.6); border.width: SimpleTheme.px(2); border.color: modelData[2] ? SimpleTheme.textPrimary : modelData[1]
                    }
                    SText { text: modelData[0]; size: 24 }
                }
            }
        }
    }

    // ---------------------------------------------------------------- button column (left of the PiP)
    Column {
        id: col
        x: SimpleTheme.px(1382)
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(24)
        width: SimpleTheme.px(90)
        spacing: SimpleTheme.px(8)

        component MapBtn: Rectangle {
            property string icon: ""
            property bool active: false
            property bool enabled_: true
            signal clicked()
            anchors.horizontalCenter: parent.horizontalCenter
            width: SimpleTheme.px(80); height: width; radius: SimpleTheme.px(24)
            opacity: enabled_ ? 1 : 0.4
            color: active ? SimpleTheme.brandGreen
                          : (ma.pressed ? SimpleTheme.surfaceControl : SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.9))
            SIcon { anchors.centerIn: parent; name: parent.icon; size: 44 }
            MouseArea { id: ma; anchors.fill: parent; enabled: parent.enabled_; onClicked: parent.clicked() }
        }

        MapBtn { icon: "layers"; active: mc.layersOpen; onClicked: mc.layersOpen = !mc.layersOpen }
        MapBtn { icon: "locate"; enabled_: mc._vehOk; onClicked: mc.centerOn(mc.vehicle.coordinate) }
        MapBtn { icon: "pin";    enabled_: mc._gcs.isValid; onClicked: mc.centerOn(mc._gcs) }
        Rectangle {
            width: SimpleTheme.px(90); height: SimpleTheme.px(130); radius: SimpleTheme.px(24)
            color: SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.9)
            Column {
                anchors.centerIn: parent
                Repeater {
                    model: [["plus", 1], ["minus", -1]]
                    Rectangle {
                        width: SimpleTheme.px(88); height: SimpleTheme.px(64); radius: SimpleTheme.px(20)
                        color: zma.pressed ? SimpleTheme.surfaceControl : "transparent"
                        SIcon { anchors.centerIn: parent; name: modelData[0]; size: 40 }
                        MouseArea { id: zma; anchors.fill: parent; onClicked: mc.zoomBy(modelData[1]) }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- Layers panel
    MouseArea {             // tap outside closes the panel
        anchors.fill: parent
        visible: mc.layersOpen
        onClicked: mc.layersOpen = false
    }
    Rectangle {
        id: panel
        visible: mc.layersOpen
        anchors.right: col.left; anchors.rightMargin: SimpleTheme.px(24)
        y: col.y + SimpleTheme.px(254) - height     // bottom level with the zoom box top (Figma: 916)
        width: SimpleTheme.px(520); height: pcol.height + SimpleTheme.px(48)
        radius: SimpleTheme.px(24)
        color: SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.98)
        border.width: SimpleTheme.px(1); border.color: SimpleTheme.line
        MouseArea { anchors.fill: parent }      // keep taps inside
        Column {
            id: pcol
            x: SimpleTheme.px(25); y: SimpleTheme.px(23)
            width: parent.width - SimpleTheme.px(50)
            spacing: SimpleTheme.px(14)

            SText { text: qsTr("Map"); size: 30; bold: true }
            Row {
                spacing: SimpleTheme.px(12)
                Repeater {
                    model: [[qsTr("Satellite"), "#5c6e47"], [qsTr("Street"), "#d9d9d1"], [qsTr("Hybrid"), "#738066"]]
                    Item {
                        width: SimpleTheme.px(140); height: SimpleTheme.px(124)
                        readonly property bool sel: mc._curType === index
                        opacity: mc.typeFor(index) !== "" ? 1 : 0.4
                        Rectangle {
                            width: parent.width; height: SimpleTheme.px(90); radius: SimpleTheme.px(14)
                            color: modelData[1]
                            border.width: parent.sel ? SimpleTheme.px(3) : 0; border.color: SimpleTheme.ok
                        }
                        SText {
                            anchors.horizontalCenter: parent.horizontalCenter; y: SimpleTheme.px(96)
                            text: modelData[0]; size: 24; bold: parent.sel
                            color: parent.sel ? SimpleTheme.textPrimary : SimpleTheme.textSecondary
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { var t = mc.typeFor(index); if (t !== "") mc._fm.mapType.value = t }
                        }
                    }
                }
            }

            component LayerRow: Item {
                property string title: ""
                property string sub: ""
                property alias checked: tg.checked
                signal toggled(bool on)
                width: pcol.width; height: SimpleTheme.px(56)
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - tg.width - SimpleTheme.px(12)
                    SText { text: title; size: 24; width: parent.width; elide: Text.ElideRight }
                    SText { text: sub; size: 22; color: SimpleTheme.textSecondary; width: parent.width; elide: Text.ElideRight }
                }
                SToggle { id: tg; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; onToggled: parent.toggled(checked) }
            }

            LayerRow {
                title: qsTr("Flight zones")
                sub: mc._zoneCount > 0 ? qsTr("%1 zones loaded").arg(mc._zoneCount) : qsTr("No zone data (Settings › Map & flight zones)")
                checked: mc._zonesShown
                onToggled: mc.setZones(on)
            }
            LayerRow {
                title: qsTr("Flight trail"); sub: qsTr("Where the drone has flown")
                checked: !!mc.map && mc.map.simpleShowTrail
                onToggled: mc.setTrail(on)
            }
            LayerRow {
                title: qsTr("Keep drone in view"); sub: qsTr("Map follows the drone")
                checked: mc._fly.keepMapCenteredOnVehicle.rawValue
                onToggled: mc._fly.keepMapCenteredOnVehicle.rawValue = on
            }
            Row {
                spacing: SimpleTheme.px(10)
                SIcon { name: mc._offlineSets > 0 ? "check" : "info"; size: 28; color: mc._offlineSets > 0 ? SimpleTheme.ok : SimpleTheme.textSecondary
                        anchors.verticalCenter: parent.verticalCenter }
                SText {
                    width: pcol.width - SimpleTheme.px(38); wrapMode: Text.WordWrap; size: 24
                    color: mc._offlineSets > 0 ? SimpleTheme.ok : SimpleTheme.textSecondary
                    text: mc._offlineSets > 0 ? (mc._offlineSets === 1 ? qsTr("Offline map: 1 area downloaded") : qsTr("Offline maps: %1 areas downloaded").arg(mc._offlineSets))
                                              : qsTr("No offline maps (Settings › Map & flight zones)")
                }
            }
        }
    }

    // ---------------------------------------------------------------- S15 zone details (tap on a zone)
    Rectangle {
        id: zoneDetails
        readonly property var zone: mc.tappedZones.length > 0 ? mc.tappedZones[0] : null
        visible: !!zone
        x: SimpleTheme.px(1336); y: SimpleTheme.px(300)
        width: SimpleTheme.px(560); height: zcol.height + SimpleTheme.px(50)
        radius: SimpleTheme.px(28)
        color: SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.96)
        border.width: SimpleTheme.px(1); border.color: SimpleTheme.line
        MouseArea { anchors.fill: parent }
        Column {
            id: zcol
            x: SimpleTheme.px(29); y: SimpleTheme.px(25)
            width: parent.width - SimpleTheme.px(58)
            spacing: SimpleTheme.px(12)
            Item {
                width: parent.width; height: SimpleTheme.px(40)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Zone details"); size: 32; bold: true }
                SIcon {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; name: "close"; size: 40
                    MouseArea { anchors.fill: parent; anchors.margins: -SimpleTheme.px(16); onClicked: mc.tappedZones = [] }
                }
            }
            Rectangle {
                width: chipText.implicitWidth + SimpleTheme.px(28); height: SimpleTheme.px(40); radius: SimpleTheme.px(14)
                color: zoneDetails.zone ? mc.classColor(zoneDetails.zone.zoneClass) : "transparent"
                SText { id: chipText; anchors.centerIn: parent; size: 24
                        color: zoneDetails.zone && zoneDetails.zone.zoneClass === 2 ? SimpleTheme.bgBase : SimpleTheme.textPrimary
                        text: zoneDetails.zone ? mc.className(zoneDetails.zone.zoneClass) : "" }
            }
            Repeater {
                model: zoneDetails.zone ? [
                    [qsTr("Name"),    zoneDetails.zone.zoneName],
                    [qsTr("Height"),  mc.heightText(zoneDetails.zone)],
                    [qsTr("Details"), zoneDetails.zone.zoneDetail],
                    [qsTr("Source"),  zoneDetails.zone.zoneClass === 4 ? qsTr("My zones") : mc.sourceText]
                ] : []
                Item {
                    visible: modelData[1] !== ""
                    width: zcol.width; height: visible ? Math.max(SimpleTheme.px(28), val.height) : 0
                    SText { text: modelData[0]; size: 24; color: SimpleTheme.textSecondary }
                    SText {
                        id: val; anchors.right: parent.right
                        width: parent.width * 0.62; horizontalAlignment: Text.AlignRight; wrapMode: Text.WordWrap
                        text: modelData[1]; size: 24
                    }
                }
            }
            SText {
                visible: mc.tappedZones.length > 1
                width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textTertiary
                text: qsTr("%1 zones overlap here — the most restrictive one is shown first.").arg(mc.tappedZones.length)
            }
        }
    }
}
