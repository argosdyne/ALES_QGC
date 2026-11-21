/****************************************************************************
 * AQGC Simple UI — S23 waypoint flight editor (on the classic PlanView map; its panels are hidden in Simple mode).
 * Mission = take-off → waypoints → return home (created by SimplePlanWizard). Points are classic SimpleMissionItems:
 *   tap the map with "Add point" on → insert before the return item; drag a point on the map to move it (classic);
 *   tap a point to select it (classic currentPlanViewItem).
 * Panel for the selected point: height (altitude), speed (speedSection), wait (param1 "Hold"), action at the point
 * (cameraSection.cameraAction: nothing / photo / start video / stop video), drone faces (param4 "Yaw": NaN = next point).
 * Height profile: route heights (orange) and the ground under each point (terrainAltitude, green); red when a point
 * is not at least 5 m above the ground.
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

Item {
    id: we
    property var  plan:     null
    property var  map:      null            // PlanView editor map (planView.simpleMap)
    property real maxAlt:   120
    property real topInset: 0               // below the wizard header
    signal nextRequested()

    readonly property var _mission: plan ? plan.missionController : null
    readonly property var _units:   QGroundControl.unitsConversion
    property bool addMode: true
    property var  _undo: []

    // ---- waypoints (NAV_WAYPOINT = 16) between take-off and return
    readonly property var wps: {
        var out = []
        if (!_mission) return out
        var items = _mission.visualItems
        var n = items.count       // re-evaluate when items are added or removed
        for (var i = 0; i < n; i++) {
            var it = items.get(i)
            if (it && it.isSimpleItem && it.command === 16) out.push(it)
        }
        return out
    }
    readonly property var selected: {
        var cur = _mission ? _mission.currentPlanViewItem : null
        return wps.indexOf(cur) >= 0 ? cur : (wps.length > 0 ? wps[wps.length - 1] : null)
    }
    readonly property int selIndex: wps.indexOf(selected)

    function _returnIndex() {
        var items = _mission.visualItems
        for (var i = items.count - 1; i >= 0; i--) {
            var it = items.get(i)
            if (it && it.isSimpleItem && (it.command === 20 || it.command === 21)) return i   // RTL or LAND
        }
        return items.count
    }
    function _indexOf(item) {
        var items = _mission.visualItems
        for (var i = 0; i < items.count; i++) if (items.get(i) === item) return i
        return -1
    }
    function addPoint(coord) {
        if (!_mission || !addMode) return
        var alt = selected ? Number(selected.altitude.rawValue) : 50
        var item = _mission.insertSimpleMissionItem(coord, _returnIndex(), true)
        if (item && item.altitude) item.altitude.rawValue = Math.max(5, Math.min(maxAlt, alt))
        var u = _undo.slice(); u.push(item); _undo = u
    }
    function undo() {
        var u = _undo.slice()
        while (u.length > 0) {
            var item = u.pop()
            var i = _indexOf(item)
            if (i >= 0) { _mission.removeVisualItem(i); break }
        }
        _undo = u
    }
    function deleteSelected() {
        if (!selected) return
        var i = _indexOf(selected)
        if (i >= 0) _mission.removeVisualItem(i)
    }
    function select(i) { if (i >= 0 && i < wps.length) _mission.setCurrentPlanViewSeqNum(wps[i].sequenceNumber, false) }

    function fact(item, name) {
        if (!item) return null
        var lists = [item.textFieldFacts, item.nanFacts]
        for (var l = 0; l < lists.length; l++) {
            var lst = lists[l]
            if (!lst) continue
            for (var i = 0; i < lst.count; i++) { var f = lst.get(i); if (f && f.name === name) return f }
        }
        return null
    }
    readonly property var holdFact: fact(selected, "Hold")
    readonly property var yawFact:  fact(selected, "Yaw")
    readonly property var speedSec: selected ? selected.speedSection : null
    readonly property var camSec:   selected ? selected.cameraSection : null
    readonly property real defaultSpeed: Number(QGroundControl.settingsManager.appSettings.offlineEditingHoverSpeed.rawValue)

    // ---- summary and profile
    readonly property real homeAMSL: _mission && _mission.visualItems.count > 0 ? _mission.visualItems.get(0).coordinate.altitude : NaN
    function _fmtTime(sec) { if (!sec || isNaN(sec)) return "—"; var m = Math.round(sec / 60); return m < 1 ? qsTr("<1 min") : qsTr("about %1 min").arg(m) }
    readonly property string summary: !_mission ? "" : qsTr("route %1 km · %2 · %3")
        .arg((_mission.missionDistance / 1000).toFixed(1)).arg(_fmtTime(_mission.missionTime))
        .arg(_mission.batteriesRequired > 0 ? qsTr("batteries: %1").arg(_mission.batteriesRequired) : qsTr("battery not estimated"))
    readonly property var lowPoints: {
        var out = []
        for (var i = 0; i < wps.length; i++) {
            var t = wps[i].terrainAltitude
            if (isFinite(t) && isFinite(homeAMSL) && Number(wps[i].altitude.rawValue) < t - homeAMSL + 5) out.push(i + 1)
        }
        return out
    }

    //---------------------------------------------------------------- height labels next to the points on the map
    Repeater {
        model: we.map ? we.wps : []
        Rectangle {
            readonly property point _pt: {
                var dep = we.map.center.latitude + we.map.center.longitude + we.map.zoomLevel + we.map.bearing + we.map.width
                var c = modelData.coordinate
                return we.map.fromCoordinate(c, false)
            }
            x: _pt.x + SimpleTheme.px(30); y: _pt.y - height / 2
            visible: _pt.y > we.topInset && _pt.x > 0 && _pt.x < we.width
            width: lbl.implicitWidth + SimpleTheme.px(16); height: SimpleTheme.px(36); radius: SimpleTheme.px(8)
            color: we.lowPoints.indexOf(index + 1) >= 0 ? SimpleTheme.danger : SimpleTheme.withAlpha(SimpleTheme.bgBase, 0.85)
            SText { id: lbl; anchors.centerIn: parent; size: 22; medium: true
                    text: Math.round(Number(modelData.altitude.rawValue)) + " m" }
        }
    }

    //---------------------------------------------------------------- left tools
    Rectangle {
        x: SimpleTheme.px(24); y: we.topInset + SimpleTheme.px(36)
        width: SimpleTheme.px(140); height: tools.height + SimpleTheme.px(28); radius: SimpleTheme.px(24)
        color: SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
        MouseArea { anchors.fill: parent }
        Column {
            id: tools
            anchors.horizontalCenter: parent.horizontalCenter; y: SimpleTheme.px(14)
            spacing: SimpleTheme.px(10)
            Repeater {
                model: [
                    { key: "add",  icon: "plus", text: qsTr("Add point") },
                    { key: "undo", icon: "undo", text: qsTr("Undo") }
                ]
                Column {
                    spacing: SimpleTheme.px(4)
                    readonly property bool _on: modelData.key === "add" && we.addMode
                    readonly property bool _enabled: modelData.key === "add" || we._undo.length > 0
                    opacity: _enabled ? 1 : 0.4
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: SimpleTheme.px(96); height: width; radius: width / 2
                        color: parent._on ? SimpleTheme.brandGreen : SimpleTheme.surfaceControl
                        SIcon { anchors.centerIn: parent; name: modelData.icon; size: 44 }
                        MouseArea {
                            anchors.fill: parent; enabled: parent.parent._enabled
                            onClicked: modelData.key === "add" ? we.addMode = !we.addMode : we.undo()
                        }
                    }
                    SText { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.text; size: 22; medium: true }
                }
            }
        }
    }

    //---------------------------------------------------------------- hint when there is no point yet
    Rectangle {
        visible: we.wps.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: we.topInset + SimpleTheme.px(36)
        width: hint.implicitWidth + SimpleTheme.px(48); height: SimpleTheme.px(72); radius: SimpleTheme.px(18)
        color: SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
        SText { id: hint; anchors.centerIn: parent; size: 26
                text: qsTr("Tap the map to add points. Drag a point to move it.") }
    }

    //---------------------------------------------------------------- height profile (bottom left)
    Rectangle {
        id: profile
        visible: we.wps.length > 0
        x: SimpleTheme.px(150); anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(24)
        width: SimpleTheme.px(940); height: SimpleTheme.px(180); radius: SimpleTheme.px(20)
        color: SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
        Row {
            x: SimpleTheme.px(20); y: SimpleTheme.px(14)
            spacing: SimpleTheme.px(14)
            SText { text: qsTr("Height profile"); size: 24; bold: true }
            SText { text: we.summary; size: 22; color: SimpleTheme.textSecondary; anchors.baseline: parent.children[0].baseline }
        }
        SText {
            visible: we.lowPoints.length > 0
            anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(20); y: SimpleTheme.px(14)
            text: qsTr("Point %1: too close to the ground").arg(we.lowPoints.join(", ")); size: 22; color: SimpleTheme.textDanger
        }
        Canvas {
            id: prof
            x: SimpleTheme.px(20); y: SimpleTheme.px(56)
            width: parent.width - SimpleTheme.px(40); height: parent.height - SimpleTheme.px(72)
            property var _sig: [we.wps.length, we.selIndex, we.homeAMSL, we.lowPoints.length]
            onPaint: {
                var g = getContext("2d"); g.reset()
                var w = we.wps; if (w.length === 0) return
                // distance along the route: start at the first point's previous item (take-off) = 0
                var home = we._mission.visualItems.get(0).coordinate
                var d = [0], alts = [0], ter = [NaN], dist = 0
                for (var i = 0; i < w.length; i++) {
                    dist += (i > 0 ? w[i - 1].coordinate : home).distanceTo(w[i].coordinate)
                    d.push(dist); alts.push(Number(w[i].altitude.rawValue))
                    var t = w[i].terrainAltitude
                    ter.push(isFinite(t) && isFinite(we.homeAMSL) ? t - we.homeAMSL : NaN)
                }
                d.push(dist + w[w.length - 1].coordinate.distanceTo(home)); alts.push(0); ter.push(NaN)
                var maxD = Math.max(1, d[d.length - 1]), maxA = 10
                for (i = 0; i < alts.length; i++) { maxA = Math.max(maxA, alts[i]); if (isFinite(ter[i])) maxA = Math.max(maxA, ter[i]) }
                function X(v) { return v / maxD * width }
                function Y(v) { return height - v / (maxA * 1.1) * height }
                // ground under the points
                g.strokeStyle = SimpleTheme.ok; g.lineWidth = SimpleTheme.px(3); g.beginPath()
                var started = false
                for (i = 0; i < d.length; i++) {
                    var tv = isFinite(ter[i]) ? ter[i] : 0
                    if (!started) { g.moveTo(X(d[i]), Y(tv)); started = true } else g.lineTo(X(d[i]), Y(tv))
                }
                g.stroke()
                // route heights
                g.strokeStyle = SimpleTheme.warn; g.lineWidth = SimpleTheme.px(4); g.beginPath()
                for (i = 0; i < d.length; i++) { if (i === 0) g.moveTo(X(d[i]), Y(alts[i])); else g.lineTo(X(d[i]), Y(alts[i])) }
                g.stroke()
                // selected point
                if (we.selIndex >= 0) {
                    var k = we.selIndex + 1
                    g.fillStyle = SimpleTheme.info; g.beginPath(); g.arc(X(d[k]), Y(alts[k]), SimpleTheme.px(9), 0, Math.PI * 2); g.fill()
                }
            }
            on_SigChanged: requestPaint()
            Connections { target: we._mission; function onMissionDistanceChanged() { prof.requestPaint() } }
        }
    }

    //---------------------------------------------------------------- selected point panel (right)
    SPanel {
        id: panel
        closable: false
        x: parent.width - width - SimpleTheme.px(24)
        y: we.topInset + SimpleTheme.px(24)
        width: SimpleTheme.px(600)
        height: parent.height - y - SimpleTheme.px(24)

        Column {
            width: parent.width
            spacing: SimpleTheme.px(16)
        // header: < Waypoint n of N >
        Item {
            width: parent.width; height: SimpleTheme.px(80)
            SRoundIconButton { id: prevBtn; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; icon: "back"
                               enabled_: we.selIndex > 0; onClicked: we.select(we.selIndex - 1) }
            SText { anchors.centerIn: parent; size: 32; bold: true
                    text: we.selected ? qsTr("Point %1 (%2 of %3)").arg(we.selected.sequenceNumber).arg(we.selIndex + 1).arg(we.wps.length) : qsTr("No point yet") }
            SRoundIconButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; icon: "chevron"
                               enabled_: we.selIndex >= 0 && we.selIndex < we.wps.length - 1; onClicked: we.select(we.selIndex + 1) }
        }

        // recreated for every selected point: the S* steppers / segmented controls break their bindings when edited
        Loader {
            id: pointLoader
            width: parent.width
            active: !!we.selected
            sourceComponent: pointComp
            Connections { target: we; function onSelectedChanged() { pointLoader.active = false; pointLoader.active = !!we.selected } }
        }
        }

        Row {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            spacing: SimpleTheme.px(14)
            SButton {
                kind: "danger"; text: qsTr("Delete point"); enabled_: !!we.selected
                onClicked: we.deleteSelected()
            }
            SButton {
                width: parent.width - x
                kind: "primary"; text: qsTr("Next: check & send")
                enabled_: we.wps.length > 0
                onClicked: we.nextRequested()
            }
        }
        Component {
            id: pointComp
            Column {
            width: pointLoader.width
            spacing: SimpleTheme.px(16)

            Item {
                width: parent.width; height: SimpleTheme.px(80)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Height"); size: 24; color: SimpleTheme.textSecondary }
                SStepper {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    value: we.selected ? Math.round(Number(we.selected.altitude.rawValue)) : 0
                    from: 5; to: we.maxAlt; step: 5; unit: "m"
                    onEdited: we.selected.altitude.rawValue = value
                }
            }
            Item {
                visible: !!we.speedSec && we.speedSec.available
                width: parent.width; height: SimpleTheme.px(80)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Speed"); size: 24; color: SimpleTheme.textSecondary }
                SStepper {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    value: we.speedSec ? (we.speedSec.specifyFlightSpeed ? Number(we.speedSec.flightSpeed.rawValue) : we.defaultSpeed) : 0
                    from: 1; to: 15; step: 0.5; decimals: 1; unit: "m/s"
                    onEdited: { we.speedSec.specifyFlightSpeed = true; we.speedSec.flightSpeed.rawValue = value }
                }
            }
            Item {
                visible: !!we.holdFact
                width: parent.width; height: SimpleTheme.px(80)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Wait here"); size: 24; color: SimpleTheme.textSecondary }
                SStepper {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    value: we.holdFact ? Number(we.holdFact.rawValue) : 0
                    from: 0; to: 120; step: 5; unit: "s"
                    onEdited: we.holdFact.rawValue = value
                }
            }
            SText { visible: !!we.camSec; text: qsTr("At this point"); size: 24; color: SimpleTheme.textSecondary }
            SSegmented {
                visible: !!we.camSec
                designWidth: 544
                readonly property var _vals: [0, 6, 4, 5]   // CameraSection: none, take photo, start video, stop video
                model: [qsTr("Nothing"), qsTr("Photo"), qsTr("Start video"), qsTr("Stop video")]
                currentIndex: we.camSec ? Math.max(0, _vals.indexOf(Number(we.camSec.cameraAction.rawValue))) : 0
                onActivated: we.camSec.cameraAction.rawValue = _vals[index]
            }
            SText { visible: !!we.yawFact; text: qsTr("Drone faces"); size: 24; color: SimpleTheme.textSecondary }
            SSegmented {
                id: yawSeg
                visible: !!we.yawFact
                designWidth: 544
                model: [qsTr("Next point"), qsTr("Fixed direction")]
                currentIndex: we.yawFact && isFinite(Number(we.yawFact.rawValue)) ? 1 : 0
                onActivated: we.yawFact.rawValue = index === 1 ? 0 : NaN
            }
            Item {
                visible: !!we.yawFact && yawSeg.currentIndex === 1
                width: parent.width; height: SimpleTheme.px(80)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Direction"); size: 24; color: SimpleTheme.textSecondary }
                SStepper {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    value: we.yawFact && isFinite(Number(we.yawFact.rawValue)) ? Number(we.yawFact.rawValue) : 0
                    from: 0; to: 345; step: 15; unit: "°"
                    onEdited: we.yawFact.rawValue = value
                }
            }
            SText {
                width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textTertiary
                text: qsTr("Height is above the take-off point · max %1 m.").arg(we.maxAlt)
            }
        }
        }
    }
}
