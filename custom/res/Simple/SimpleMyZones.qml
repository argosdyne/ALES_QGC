/****************************************************************************
 * AQGC Simple UI — S32 My flight zones (Settings › Map & flight zones › My zones)
 *
 * Decision 2026-11-15: each zone is "Do not enter" (blocks take-off / plan sending in the app checks and goes to the
 * drone as an ArduPilot exclusion fence) or "Warn only" (app warning). Zones are stored by FlightZoneManager
 * (<GeoZone>/MyZones/my-zones.geojson) and shown on every map with the official zones. Editing is locked while the
 * motors run (Figma G-01b rule).
 ****************************************************************************/
import QtQuick 2.12
import QtLocation 5.3
import QtPositioning 5.3
import QGroundControl 1.0
import QGroundControl.FlightMap 1.0
import QGroundControl.FactSystem 1.0
import "."

Rectangle {
    id: mz
    color: SimpleTheme.bgBase
    property var vs: null
    signal closeRequested()

    readonly property var  _mgr:    mainWindow.flightZoneManager
    readonly property bool _locked: !!vs && !!vs.vehicle && vs.vehicle.armed
    property var    zones:   []          // FlightZoneManager.myZoneList (as last loaded)
    property int    editIndex: -2        // -2 list, -1 new zone, >= 0 editing zones[editIndex]
    readonly property bool editing: editIndex > -2

    // zone being edited
    property var    corners: []
    property string zName:   ""
    property bool   zNoEntry: true
    property real   zFloor:  0
    property real   zCeiling: 120
    property real   zWarn:   30

    MouseArea { anchors.fill: parent }   // keep taps off the pages below
    Component.onCompleted: zones = _mgr.myZoneList

    // ---- drone fence (5b): "do not enter" zones go to the ArduPilot fence as exclusion polygons
    readonly property int  _noEntryCount: { var n = 0; for (var i = 0; i < zones.length; i++) if (zones[i].noEntry) n++; return n }
    readonly property bool _canUpload: !!vs && vs.connected && !vs.armed && vs.paramsReady
    readonly property var  _plan:  globals.planMasterControllerFlyView
    readonly property var  _fence: _plan ? _plan.geoFenceController : null
    property bool confirmUpload: false
    property string uploadState: ""      // "" | "sending" | "done" | "busy" | "failed"
    // FactPanelController binds to the vehicle when created: only once the parameters are ready
    Loader { id: fpc; active: !!mz.vs && mz.vs.paramsReady; sourceComponent: Component { FactPanelController { } } }
    function _fact(name) { return fpc.item && fpc.item.parameterExists(-1, name) ? fpc.item.getParameterFact(-1, name, false) : null }
    readonly property var  _fEnable: _fact("FENCE_ENABLE")
    readonly property var  _fType:   _fact("FENCE_TYPE")
    readonly property var  _fAction: _fact("FENCE_ACTION")
    readonly property bool _polygonOn: !!_fEnable && !!_fType && _fEnable.rawValue > 0 && (_fType.rawValue & 4) !== 0
    function actionText(a) {
        return a === 0 ? qsTr("only reports the breach") : a === 2 ? qsTr("lands") : a === 4 ? qsTr("brakes, or lands")
             : (a === 3 || a === 5) ? qsTr("returns on its own path, or lands") : qsTr("returns home, or lands")
    }
    function upload() {
        confirmUpload = false
        // nothing changes on the drone unless the fence can be sent now (e.g. not while it is still being loaded)
        if (!_fence || _fence.syncInProgress) { uploadState = "busy"; return }
        // fence off before: turn on the polygon fence only (FENCE_TYPE 7 would also turn on the circle and the
        // altitude fence); fence already on: add the polygon to what is there
        if (_fEnable && _fEnable.rawValue === 0) {
            if (_fType) _fType.rawValue = 4
            _fEnable.rawValue = 1
        } else if (_fType && (_fType.rawValue & 4) === 0) {
            _fType.rawValue = _fType.rawValue | 4
        }
        uploadState = _mgr.uploadMyZonesFence(_fence) >= 0 ? "sending" : "busy"
        if (uploadState === "sending") uploadTimeout.restart()
    }
    Timer { id: uploadTimeout; interval: 20000; onTriggered: if (mz.uploadState === "sending") mz.uploadState = "failed" }
    Connections {
        target: mz._fence
        function onSyncInProgressChanged() { if (mz.uploadState === "sending" && !mz._fence.syncInProgress) mz.uploadState = "done" }
    }

    function startEdit(i) {
        editIndex = i
        var z = i >= 0 ? zones[i] : null
        corners  = z ? z.path.slice() : []
        zName    = z ? z.name : qsTr("My zone %1").arg(zones.length + 1)
        zNoEntry = z ? z.noEntry : true
        zFloor   = z ? z.floor : 0
        zCeiling = z ? z.ceiling : 120
        zWarn    = z ? z.warnDistance : 30
        if (z && z.path.length > 0) map.center = z.path[0]
    }
    function save() {
        var list = zones.slice()
        var z = { name: nameField.currentText.trim() !== "" ? nameField.currentText.trim() : zName,
                  noEntry: zNoEntry, floor: zFloor, ceiling: zCeiling, warnDistance: zWarn, path: corners }
        if (editIndex >= 0) list[editIndex] = z; else list.push(z)
        if (_mgr.saveMyZones(list)) { zones = _mgr.myZoneList; editIndex = -2 }
    }
    function remove(i) {
        var list = zones.slice(); list.splice(i, 1)
        if (_mgr.saveMyZones(list)) zones = _mgr.myZoneList
    }
    function addCorner(c) { var a = corners.slice(); a.push(c); corners = a }
    function moveCorner(i, c) { var a = corners.slice(); a[i] = c; corners = a }
    // area in hectares (flat approximation, fine for zone sizes)
    function areaHa(path) {
        if (path.length < 3) return 0
        var lat0 = path[0].latitude, k = Math.cos(lat0 * Math.PI / 180) * 111320, s = 0
        for (var i = 0; i < path.length; i++) {
            var a = path[i], b = path[(i + 1) % path.length]
            s += (a.longitude * k) * (b.latitude * 111320) - (b.longitude * k) * (a.latitude * 111320)
        }
        return Math.abs(s) / 2 / 10000
    }

    FlightMap {
        id: map
        anchors.fill: parent
        mapName: "SimpleMyZones"
        allowGCSLocationCenter: true
        allowVehicleLocationCenter: true
        Component.onCompleted: {
            if (QGroundControl.flightMapPosition && QGroundControl.flightMapPosition.isValid) center = QGroundControl.flightMapPosition
            zoomLevel = Math.max(QGroundControl.flightMapZoom, 15)
        }
        MouseArea {
            anchors.fill: parent
            enabled: mz.editing && !mz._locked
            onClicked: mz.addCorner(map.toCoordinate(Qt.point(mouse.x, mouse.y), false))
        }
        // the zone being drawn
        MapPolygon {
            visible: mz.editing && mz.corners.length >= 3
            path: mz.corners
            color: SimpleTheme.withAlpha(mz.zNoEntry ? SimpleTheme.danger : SimpleTheme.warn, 0.3)
            border.width: SimpleTheme.px(3); border.color: SimpleTheme.textPrimary
        }
        MapPolyline {
            visible: mz.editing && mz.corners.length === 2
            path: mz.corners
            line.width: SimpleTheme.px(3); line.color: SimpleTheme.textPrimary
        }
        MapItemView {
            model: mz.editing ? mz.corners.length : 0
            delegate: MapQuickItem {
                coordinate: index < mz.corners.length ? mz.corners[index] : QtPositioning.coordinate()
                anchorPoint.x: handle.width / 2; anchorPoint.y: handle.height / 2
                z: 1000
                sourceItem: Rectangle {
                    id: handle
                    width: SimpleTheme.px(40); height: width; radius: width / 2
                    color: SimpleTheme.textPrimary; border.width: SimpleTheme.px(5); border.color: SimpleTheme.danger
                    MouseArea {      // drag a corner
                        anchors.fill: parent; anchors.margins: -SimpleTheme.px(12)
                        enabled: !mz._locked
                        preventStealing: true
                        onPositionChanged: {
                            var p = mapToItem(map, mouse.x, mouse.y)
                            mz.moveCorner(index, map.toCoordinate(Qt.point(p.x, p.y), false))
                        }
                    }
                }
            }
        }
        MapQuickItem {
            visible: mz.editing && mz.corners.length >= 3
            coordinate: {
                var la = 0, lo = 0, n = mz.corners.length
                for (var i = 0; i < n; i++) { la += mz.corners[i].latitude; lo += mz.corners[i].longitude }
                return n > 0 ? QtPositioning.coordinate(la / n, lo / n) : QtPositioning.coordinate()
            }
            anchorPoint.x: areaLabel.width / 2; anchorPoint.y: areaLabel.height / 2
            sourceItem: Rectangle {
                id: areaLabel
                width: areaText.implicitWidth + SimpleTheme.px(24); height: SimpleTheme.px(40); radius: SimpleTheme.px(8)
                color: SimpleTheme.withAlpha(SimpleTheme.bgBase, 0.8)
                SText { id: areaText; anchors.centerIn: parent; size: 22
                        text: (nameField.currentText !== "" ? nameField.currentText : mz.zName) + " · " + mz.areaHa(mz.corners).toFixed(1) + " ha" }
            }
        }
    }

    // ---------------------------------------------------------------- header
    Rectangle {
        id: header
        width: parent.width; height: SimpleTheme.px(104)
        color: SimpleTheme.surfaceGlass
        MouseArea { anchors.fill: parent }
        Row {
            anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
            spacing: SimpleTheme.px(20)
            SButton { designHeight: 80; icon: "back"; text: qsTr("Settings"); textSize: 26
                      onClicked: if (mz.editing) mz.editIndex = -2; else mz.closeRequested() }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                SText { text: mz.editIndex === -1 ? qsTr("New flight zone") : mz.editing ? qsTr("Edit flight zone") : qsTr("My flight zones"); size: 34; bold: true }
                SText { text: qsTr("Map & flight zones › My zones"); size: 22; color: SimpleTheme.textSecondary }
            }
        }
    }

    // ---------------------------------------------------------------- drawing tools (left)
    Rectangle {
        visible: mz.editing
        x: SimpleTheme.px(24); y: header.height + SimpleTheme.px(24)
        width: SimpleTheme.px(144); height: tools.height + SimpleTheme.px(32)
        radius: SimpleTheme.px(20); color: SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
        Column {
            id: tools
            anchors.horizontalCenter: parent.horizontalCenter; y: SimpleTheme.px(16)
            spacing: SimpleTheme.px(16)
            Repeater {
                model: [["plus", qsTr("Add corner"), 0], ["undo", qsTr("Undo"), 1], ["trash", qsTr("Clear"), 2]]
                Column {
                    spacing: SimpleTheme.px(6)
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: SimpleTheme.px(80); height: width; radius: width / 2
                        color: modelData[2] === 0 ? SimpleTheme.brandGreen : SimpleTheme.surfaceControl
                        opacity: mz._locked || (modelData[2] > 0 && mz.corners.length === 0) ? 0.4 : 1
                        SIcon { anchors.centerIn: parent; name: modelData[0]; size: 40 }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !mz._locked
                            onClicked: {
                                if (modelData[2] === 0) mz.addCorner(map.center)
                                else if (modelData[2] === 1) { var a = mz.corners.slice(); a.pop(); mz.corners = a }
                                else mz.corners = []
                            }
                        }
                    }
                    SText { anchors.horizontalCenter: parent.horizontalCenter; text: modelData[1]; size: 22 }
                }
            }
        }
    }
    // hint (bottom left)
    Rectangle {
        visible: mz.editing
        x: SimpleTheme.px(24); anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(24)
        width: hint.implicitWidth + SimpleTheme.px(80); height: SimpleTheme.px(56); radius: SimpleTheme.px(14)
        color: SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
        SIcon { x: SimpleTheme.px(18); anchors.verticalCenter: parent.verticalCenter; name: "info"; size: 28; color: SimpleTheme.textSecondary }
        SText { id: hint; x: SimpleTheme.px(58); anchors.verticalCenter: parent.verticalCenter; size: 22; color: SimpleTheme.textSecondary
                text: mz._locked ? qsTr("Locked while the motors are running.")
                                 : qsTr("Tap the map to add corners, drag a corner to move it. Official zones cannot be edited.") }
    }

    // ---------------------------------------------------------------- right panel
    Rectangle {
        id: panel
        anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(24)
        anchors.top: header.bottom; anchors.topMargin: SimpleTheme.px(24)
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(24)
        width: SimpleTheme.px(600)
        radius: SimpleTheme.px(24)
        color: SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.98)
        border.width: SimpleTheme.px(1); border.color: SimpleTheme.line
        MouseArea { anchors.fill: parent }

        // ---- list of my zones
        Column {
            visible: !mz.editing
            x: SimpleTheme.px(28); y: SimpleTheme.px(28)
            width: parent.width - SimpleTheme.px(56)
            spacing: SimpleTheme.px(14)
            SText { text: qsTr("%1 zones you drew").arg(mz.zones.length); size: 30; bold: true }
            SText { visible: mz.zones.length === 0; width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                    text: qsTr("Draw a zone the drone must not enter (for example a building or a crowd area) or a zone to be warned about.") }
            Repeater {
                model: mz.zones
                Rectangle {
                    width: parent.width; height: SimpleTheme.px(104); radius: SimpleTheme.px(16)
                    color: SimpleTheme.surfaceRaised
                    property bool confirmDel: false
                    Rectangle { x: SimpleTheme.px(18); anchors.verticalCenter: parent.verticalCenter; width: SimpleTheme.px(14); height: SimpleTheme.px(56); radius: SimpleTheme.px(4)
                                color: modelData.noEntry ? SimpleTheme.danger : SimpleTheme.warn }
                    Column {
                        x: SimpleTheme.px(48); anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - SimpleTheme.px(48) - btns.width - SimpleTheme.px(24)
                        SText { text: modelData.name; size: 26; medium: true; width: parent.width; elide: Text.ElideRight }
                        SText { size: 22; color: SimpleTheme.textSecondary; width: parent.width; elide: Text.ElideRight
                                text: (modelData.noEntry ? qsTr("Do not enter") : qsTr("Warn only")) + " · " + Math.round(modelData.floor) + "–" + Math.round(modelData.ceiling) + " m" }
                    }
                    Row {
                        id: btns
                        anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                        spacing: SimpleTheme.px(10)
                        SButton { visible: !parent.parent.confirmDel; designHeight: 72; textSize: 24; text: qsTr("Edit"); enabled_: !mz._locked; onClicked: mz.startEdit(index) }
                        SButton { visible: !parent.parent.confirmDel; designHeight: 72; textSize: 24; kind: "danger"; icon: "trash"; text: ""; enabled_: !mz._locked; onClicked: parent.parent.confirmDel = true }
                        SButton { visible: parent.parent.confirmDel; designHeight: 72; textSize: 24; text: qsTr("Keep"); onClicked: parent.parent.confirmDel = false }
                        SButton { visible: parent.parent.confirmDel; designHeight: 72; textSize: 24; kind: "danger"; text: qsTr("Delete"); onClicked: mz.remove(index) }
                    }
                }
            }
            SButton { kind: "primary"; icon: "plus"; text: qsTr("New zone"); enabled_: !mz._locked; onClicked: mz.startEdit(-1) }

            // ---- drone fence
            Rectangle { width: parent.width; height: SimpleTheme.px(1); color: SimpleTheme.line }
            SText { text: qsTr("DRONE FENCE"); size: 24; medium: true; color: SimpleTheme.textTertiary }
            SText {
                width: parent.width; wrapMode: Text.WordWrap; size: 24
                color: mz._canUpload ? SimpleTheme.textPrimary : SimpleTheme.textSecondary
                text: !mz.vs || !mz.vs.connected ? qsTr("Connect the drone to upload the 'do not enter' zones to its fence.")
                    : mz.vs.armed ? qsTr("The fence can be uploaded only on the ground with the motors off.")
                    : !mz._fEnable ? qsTr("This drone has no fence parameters.")
                    : mz._polygonOn ? qsTr("Polygon fence on. At a zone edge the drone %1.").arg(mz.actionText(mz._fAction ? mz._fAction.rawValue : 1))
                    : qsTr("The drone's polygon fence is off.")
            }
            SText {
                visible: mz.uploadState !== ""
                width: parent.width; wrapMode: Text.WordWrap; size: 24
                color: mz.uploadState === "done" ? SimpleTheme.ok : mz.uploadState === "sending" ? SimpleTheme.textSecondary : SimpleTheme.textDanger
                text: mz.uploadState === "done" ? qsTr("Uploaded to the drone.")
                    : mz.uploadState === "sending" ? qsTr("Uploading…")
                    : mz.uploadState === "busy" ? qsTr("The drone is still sending its mission or fence. Try again in a moment.")
                    : qsTr("The drone did not confirm the fence. Check the connection and try again.")
            }
            // inline confirm (Figma rule: confirm changes to the drone)
            Rectangle {
                visible: mz.confirmUpload
                width: parent.width; height: confirmCol.height + SimpleTheme.px(32)
                radius: SimpleTheme.px(16); color: SimpleTheme.withAlpha(SimpleTheme.warn, 0.14)
                border.width: SimpleTheme.px(2); border.color: SimpleTheme.warn
                Column {
                    id: confirmCol
                    x: SimpleTheme.px(18); y: SimpleTheme.px(16); width: parent.width - SimpleTheme.px(36)
                    spacing: SimpleTheme.px(12)
                    SText { width: parent.width; wrapMode: Text.WordWrap; size: 24
                            text: (mz._fEnable && mz._fEnable.rawValue === 0
                                   ? qsTr("Upload %1 'do not enter' zones to the drone? The drone's fence is off: only the polygon fence is turned on (FENCE_ENABLE = 1, FENCE_TYPE = polygon).")
                                   : qsTr("Upload %1 'do not enter' zones to the drone? They replace the exclusion areas on the drone; the circle, altitude and inclusion fences stay as they are.")).arg(mz._noEntryCount) }
                    Row {
                        spacing: SimpleTheme.px(12)
                        SButton { designHeight: 72; textSize: 24; text: qsTr("Cancel"); onClicked: mz.confirmUpload = false }
                        SButton { designHeight: 72; textSize: 24; kind: "primary"; text: qsTr("Upload"); onClicked: mz.upload() }
                    }
                }
            }
            SButton {
                visible: !mz.confirmUpload
                icon: "download"; text: qsTr("Upload to drone (%1 zones)").arg(mz._noEntryCount)
                enabled_: mz._canUpload && !!mz._fEnable && mz.uploadState !== "sending"
                onClicked: mz.confirmUpload = true
            }
        }

        // ---- zone settings (S32)
        Column {
            visible: mz.editing
            x: SimpleTheme.px(28); y: SimpleTheme.px(28)
            width: parent.width - SimpleTheme.px(56)
            spacing: SimpleTheme.px(18)
            STextField { id: nameField; designWidth: 544; label: qsTr("Name"); text: mz.zName }
            SText { text: qsTr("What happens near this zone"); size: 24; color: SimpleTheme.textSecondary }
            SSegmented {
                designWidth: 544
                model: [qsTr("Do not enter"), qsTr("Warn only")]
                currentIndex: mz.zNoEntry ? 0 : 1
                onActivated: { mz.zNoEntry = index === 0; currentIndex = Qt.binding(function() { return mz.zNoEntry ? 0 : 1 }) }
            }
            Repeater {
                model: [[qsTr("From height"), 0], [qsTr("Up to height"), 1], [qsTr("Warn when closer than"), 2]]
                Item {
                    width: parent.width; height: SimpleTheme.px(80)
                    SText { anchors.verticalCenter: parent.verticalCenter; width: parent.width - st.width - SimpleTheme.px(12); wrapMode: Text.WordWrap
                            text: modelData[0]; size: 24 }
                    SStepper {
                        id: st
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        unit: "m"; step: modelData[1] === 2 ? 5 : 10
                        from: modelData[1] === 1 ? mz.zFloor + 10 : modelData[1] === 2 ? 5 : 0
                        to: modelData[1] === 0 ? mz.zCeiling - 10 : modelData[1] === 1 ? 500 : 200
                        value: modelData[1] === 0 ? mz.zFloor : modelData[1] === 1 ? mz.zCeiling : mz.zWarn
                        onEdited: { if (modelData[1] === 0) mz.zFloor = value; else if (modelData[1] === 1) mz.zCeiling = value; else mz.zWarn = value }
                    }
                }
            }
            SText {
                width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textTertiary
                text: mz.zNoEntry ? qsTr("'Do not enter' blocks take-off and plan sending inside the zone, and goes to the drone's fence when it is uploaded — the drone stops at the edge.")
                                  : qsTr("'Warn only' shows an orange warning and speaks when the drone comes closer than the warning distance.")
            }
            Row {
                spacing: SimpleTheme.px(16)
                SButton { text: qsTr("Cancel"); onClicked: mz.editIndex = -2 }
                SButton { kind: "primary"; text: qsTr("Save zone"); enabled_: !mz._locked && mz.corners.length >= 3; onClicked: mz.save() }
            }
            SText { visible: mz.corners.length < 3; width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                    text: qsTr("Add at least 3 corners.") }
        }
    }
}
