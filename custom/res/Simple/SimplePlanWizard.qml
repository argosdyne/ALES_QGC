/****************************************************************************
 * AQGC Simple UI — Plan in 3 steps (Figma S07 choose task · S08 area mapping / S23 waypoint flight · S39 check & send)
 * Uses the classic PlanView map and PlanMasterController underneath (its panels are hidden in Simple mode).
 ****************************************************************************/
import QtQuick 2.12
import QtPositioning 5.3
import QtLocation 5.3
import QGroundControl 1.0
import QGroundControl.Controllers 1.0
import QGroundControl.FactSystem 1.0
import "."
import "SimpleMissionInfo.js" as MissionInfo

Item {
    id: wiz
    property var    vs
    property string step:   "choose"        // choose | saved (S24) | edit | check
    property string kind:   "area"          // area (S08) | waypoint (S23) | corridor (S40) | structure (S41) | lidar (S42) | editor (S80, Advanced) | other (check only)
    readonly property bool _ysOn: !!QGroundControl.corePlugin.settings && !!QGroundControl.corePlugin.settings.ysEnable.rawValue
    property var    scanItem: null          // corridor / structure complex item being edited
    property string shape:  "rectangle"     // structure outline: rectangle | circle | draw | custom (opened file)
    property var    survey: null

    readonly property var _plan:    planView._planMasterController
    readonly property var _mission: _plan ? _plan.missionController : null
    readonly property var _cam:     survey ? survey.cameraCalc : null
    readonly property real _maxAlt: Number(QGroundControl.settingsManager.flyViewSettings.guidedMaximumAltitude.rawValue)
    // drone geofence (ArduPilot FENCE_ENABLE / FENCE_RADIUS) for the default area size (Tuleap bug #28585)
    readonly property var  _veh:    QGroundControl.multiVehicleManager.activeVehicle
    // FactPanelController binds to the vehicle it is created with: create it again for another active drone
    on_VehChanged: { fenceFpc.active = false; fenceFpc.active = Qt.binding(function() { return !!wiz._veh && wiz._veh.parameterManager.parametersReady }) }
    Loader { id: fenceFpc; visible: false; active: !!wiz._veh && wiz._veh.parameterManager.parametersReady
             sourceComponent: Component { FactPanelController { } } }
    function _param(n) { var f = fenceFpc.item; return f && f.parameterExists(-1, n) ? f.getParameterFact(-1, n, false) : null }
    function _fenceRadius() {           // 0 = no fence radius to respect
        if (_veh && !_veh.apmFirmware) {    // PX4: the same limit as the S39 check
            var gf = _param("GF_MAX_HOR_DIST")
            return gf && Number(gf.rawValue) > 0 ? Number(gf.rawValue) : 0
        }
        var en = _param("FENCE_ENABLE"), rad = _param("FENCE_RADIUS"), typ = _param("FENCE_TYPE"), auto = _param("FENCE_AUTOENABLE")
        var circle = !typ || (Number(typ.rawValue) & 2) !== 0     // FENCE_TYPE bit 2 = circle fence
        // on now, or can be turned on in flight (auto-enable, RC switch RCn_OPTION = 11), as in the S39 check
        var on = en && Number(en.rawValue) !== 0 || auto && Number(auto.rawValue) !== 0
        for (var n = 1; !on && n <= 16; n++) { var o = _param("RC" + n + "_OPTION"); on = !!o && Number(o.rawValue) === 11 }
        return on && rad && circle && Number(rad.rawValue) > 0 ? Number(rad.rawValue) : 0
    }
    // Scale of the default area so that the area plus extra (Init Path figure 8: 30 m line + 10 m turn ≈ 50 m) stays
    // inside 90 % of the fence radius around home (or the area centre without a home). 1 = the 200 m x 150 m default.
    function _defaultAreaScale(c, extra) {
        var r = _fenceRadius()
        if (r <= 0) return 1
        var home = _veh && _veh.homePosition && _veh.homePosition.isValid ? _veh.homePosition : c
        var room = 0.9 * r - extra - home.distanceTo(c)
        // the map centre is outside the fence (planning a far site): shrinking cannot help, keep the default size
        // and let the S39 check report the distance (code review 2026-11-21)
        if (room <= 0) return 1
        return Math.max(0.2, Math.min(1, room / 125))      // 125 m = half diagonal of 200 x 150
    }

    property bool interrupted: false        // set when a critical alert took the user to the fly screen

    // The plan can be replaced underneath (e.g. loaded from the drone): never keep editing a survey that
    // is no longer in the mission — pick up the new one, or start again from the task choice.
    Connections {
        target: wiz._mission
        function onVisualItemsChanged() {
            // S42: Init Path items are really deleted when the mission is replaced: redraw the figure 8 for the new ones
            if (wiz.kind === "lidar") Qt.callLater(function() { wiz._ipCount = wiz._initPaths().length; wiz._drawInitPaths() })
            if (wiz.kind === "waypoint") {
                // a plan replaced underneath (only the settings item left): start again from the task choice
                if (wiz.step !== "choose" && wiz._mission.visualItems.count <= 1) wiz.step = "choose"
                return
            }
            if (wiz.kind === "corridor" || wiz.kind === "structure") {
                var f = wiz._findScan(wiz.kind)
                if (f !== wiz.scanItem) { wiz.scanItem = f; if (!f && wiz.step !== "choose") wiz.step = "choose" }
                return
            }
            if (!wiz.survey) return
            var s = wiz._findSurvey()
            if (s === wiz.survey) return
            wiz.survey = s
            if (!s) wiz.step = "choose"
        }
    }

    function start() {
        // Back after a critical alert (02 Flows D): continue the mission being edited, do not start a new one
        if (interrupted) {
            interrupted = false
            if (kind === "waypoint" && step !== "choose" && _mission && _mission.visualItems.count > 2) return
            var s = _findSurvey()
            if (s && step !== "choose") { survey = s; return }
        }
        step = "choose"
        kind = "area"
        survey = null
        scanItem = null
        _ipCount = 0
        _drawInitPaths()
    }

    function _findSurvey() {
        if (!_mission) return null
        var items = _mission.visualItems
        for (var i = 0; i < items.count; i++) {
            var it = items.get(i)
            // only a survey has gridAngle (corridor and init path items also have surveyAreaPolygon)
            if (it && it.gridAngle !== undefined && it.cameraCalc !== undefined) return it
        }
        return null
    }

    function createAreaMapping(extra) {
        kind = "area"
        _plan.removeAll()
        var c = planView.mapCenter()
        _mission.insertTakeoffItem(c, 1, false)
        var item = _mission.insertComplexMissionItem(_mission.surveyComplexItemName, c, 2, true)
        _mission.insertLandItem(c, 3, false)
        // the transects run past the area by the turnaround distance: keep that inside the fence too
        var turn = item && item.turnAroundDistance ? Number(item.turnAroundDistance.rawValue) : 0
        var k = _defaultAreaScale(c, (extra === undefined ? 0 : extra) + (isFinite(turn) ? turn : 0))
        if (item && item.surveyAreaPolygon.count === 0) {
            // Default 200 m x 150 m area around the map centre, smaller when the drone's geofence is smaller
            var hx = 100 * k, hy = 75 * k, p = []
            p.push(c.atDistanceAndAzimuth(hx, -90).atDistanceAndAzimuth(hy, 0))
            p.push(c.atDistanceAndAzimuth(hx,  90).atDistanceAndAzimuth(hy, 0))
            p.push(c.atDistanceAndAzimuth(hx,  90).atDistanceAndAzimuth(hy, 180))
            p.push(c.atDistanceAndAzimuth(hx, -90).atDistanceAndAzimuth(hy, 180))
            item.surveyAreaPolygon.appendVertices(p)
        }
        if (item && item.cameraCalc) item.cameraCalc.distanceToSurface.rawValue = Math.min(80, _maxAlt)
        survey = item ? item : _findSurvey()
        _plan.fitViewportToItems()
        step = "edit"
    }

    // S23: take-off → (points added on the map) → return home (RTL = MAV_CMD_NAV_RETURN_TO_LAUNCH 20)
    function createWaypointFlight() {
        _plan.removeAll()
        var c = planView.mapCenter()
        _mission.insertTakeoffItem(c, 1, false)
        var rtl = _mission.insertSimpleMissionItem(c, 2, false)
        if (rtl) rtl.command = 20
        survey = null
        kind = "waypoint"
        step = "edit"
        if (wpEditor) wpEditor.addMode = true
    }
    // S80 (Advanced mode): the mission editor works on the mission being planned; a new one starts as take-off, return home
    function openEditor() {
        if (_mission.visualItems.count <= 1) {
            var c = planView.mapCenter()
            _mission.insertTakeoffItem(c, 1, false)
            var rtl = _mission.insertSimpleMissionItem(c, 2, false)
            if (rtl) rtl.command = 20
        }
        survey = null
        kind = "editor"
        step = "edit"
    }
    // "Review mission" after a drone restart (bug #28564): read the mission from the drone and show it in its editor.
    // An unsent plan being edited is replaced only after a confirm (code review 2026-11-21). No drone: new-plan choice.
    property bool _awaitVehicle: false
    function reviewLoaded() {
        interrupted = false
        if (!_plan || _plan.offline) { start(); return }
        if (_plan.dirty && _mission.visualItems.count > 1) { _pending = { vehicle: true }; replaceSheet.visible = true; return }
        _loadVehicleMission()
    }
    function _loadVehicleMission() {
        _awaitVehicle = true
        _plan.loadFromVehicle()
        if (!_plan.syncInProgress) _afterVehicleLoad()
    }
    function _afterVehicleLoad() {
        _awaitVehicle = false
        if (_mission.visualItems.count > 1) { _plan.fitViewportToItems(); _routeToEditor() }
        else start()
    }
    Connections {
        target: wiz._plan
        function onSyncInProgressChanged() { if (wiz._awaitVehicle && !wiz._plan.syncInProgress) wiz._afterVehicleLoad() }
    }
    // S24: open a saved mission in the matching editor (area, waypoint) or straight in the check (other kinds)
    // The plan being edited is replaced by Open / Import: ask first when it is not saved on this tablet.
    property var _pending: null
    function _hasUnsavedPlan() { return !!_plan && _plan.currentPlanFile === "" && _mission.visualItems.count > 2 }
    function requestOpen(path)   { if (_hasUnsavedPlan()) { _pending = { open: path }; replaceSheet.visible = true } else openFile(path) }
    function requestImport(path) { if (_hasUnsavedPlan()) { _pending = { imp: path }; replaceSheet.visible = true } else importFile(path) }
    function _runPending() {
        var p = _pending; _pending = null
        if (p && p.open) openFile(p.open)
        else if (p && p.imp) importFile(p.imp)
        else if (p && p.vehicle) _loadVehicleMission()
    }
    function openFile(path) {
        _plan.loadFromFile(path)
        _plan.fitViewportToItems()
        _routeToEditor()
    }
    function _routeToEditor() {
        var k = MissionInfo.kindOf(_mission)
        if (k === "corridor" || k === "structure") { survey = null; kind = k; scanItem = _findScan(k); shape = "custom"; _editScan(); step = "edit"; return }
        if (k === "lidar") { survey = _findSurvey(); kind = "lidar"; _ipCount = _initPaths().length; _drawInitPaths()
                             if (survey && !survey.cameraCalc.isYSLidar) { _ysSelect(survey.cameraCalc); ysCalc() }
                             if (survey) _mission.setCurrentPlanViewSeqNum(survey.sequenceNumber, true); step = "edit"; return }
        if (k === "area") { survey = _findSurvey(); kind = "area"; if (survey) _mission.setCurrentPlanViewSeqNum(survey.sequenceNumber, true); step = "edit" }
        else if (k === "waypoint") { survey = null; kind = "waypoint"; step = "edit"; wpEditor.addMode = false }
        else { survey = null; kind = "other"; step = "check" }
    }
    // S24 import: .plan as is; a .kml with an area becomes an area mapping (lines: corridor mapping, later version).
    // KMZ is not read by the classic shape loader (it only takes names ending in lower-case .kml / .shp).
    function importFile(path) {
        var name = String(path)
        if (/\.plan$/i.test(name)) { openFile(path); return }
        if (!/\.kml$/.test(name)) {
            savedPage.message = qsTr("Only .plan and .kml files can be imported. Save a KMZ as KML in Google Earth first.")
            return
        }
        _plan.removeAll()
        var c = planView.mapCenter()
        _mission.insertTakeoffItem(c, 1, false)
        var item = _mission.insertComplexMissionItemFromKMLOrSHP(_mission.surveyComplexItemName, path, 2, true)
        // the survey is created even when the file has no polygon: check the area
        if (!item || !item.surveyAreaPolygon || item.surveyAreaPolygon.count < 3) {
            _plan.removeAll()
            savedPage.message = qsTr("No area found in this file. Lines (corridors) come with corridor mapping.")
            return
        }
        _mission.insertLandItem(c, 3, false)
        if (item.cameraCalc) item.cameraCalc.distanceToSurface.rawValue = Math.min(80, _maxAlt)
        _plan.fitViewportToItems()
        survey = item; kind = "area"; step = "edit"
    }
    function saveAs(name) {
        var path = QGroundControl.settingsManager.appSettings.missionSavePath + "/" + name + ".plan"
        _plan.saveToFile(path)
        savedPage.setCached(name + ".plan", MissionInfo.info(_mission))
        savedPage.refresh()
    }
    readonly property string _planName: _plan && _plan.currentPlanFile !== "" ? savedPage.baseName(_plan.currentPlanFile) : ""
    QGCFileDialogController { id: wizFdc }

    // a map tap while editing a waypoint flight adds a point
    Connections {
        target: typeof planView !== "undefined" ? planView : null
        function onSimpleMapClicked(coordinate) {
            if (!wiz.visible || wiz.step !== "edit") return
            if (wiz.kind === "waypoint") wpEditor.addPoint(coordinate)
            else if (wiz.kind === "editor") missionEditor.mapClicked(coordinate)
            // S40: a tap adds a point at the end of the corridor line
            else if (wiz.kind === "corridor" && wiz.scanItem) wiz.scanItem.corridorPolyline.appendVertex(coordinate)
            // S41 "Draw": taps outline the structure (the first tap starts a new outline)
            else if (wiz.kind === "structure" && wiz.scanItem && wiz.shape === "draw") {
                var poly = wiz.scanItem.structurePolygon
                if (wiz._drawFresh) { poly.clear(); wiz._drawFresh = false }
                poly.appendVertex(coordinate)
            }
        }
    }
    // route and highest point for the S39 check
    // S39 check: every coordinate and the highest point of the whole mission (not only the survey or the waypoints)
    readonly property var _route: {
        if (step !== "check" || !_mission) return null
        var dep = _mission.visualItems.count
        return MissionInfo.route(_mission)
    }
    readonly property real _routeHeight: {
        if (step !== "check" || !_mission) return NaN
        var dep = _mission.visualItems.count
        return MissionInfo.maxHeight(_mission)
    }

    // S42: area survey with the YellowScan "camera" (line spacing from height, line overlap and scanner FOV)
    // and a figure-8 Init Path before and after it (YellowScanInitPathComplexItem, settles the INS)
    function createLidarSurvey() {
        createAreaMapping(50)                  // room for the Init Path figure 8 before and after the survey
        kind = "lidar"
        var cc = survey ? survey.cameraCalc : null
        if (!cc) return
        _ysSelect(cc)
        cc.distanceToSurface.rawValue = Math.min(60, _maxAlt)
        cc.yellowScanOverlapFact.rawValue = 50
        ysCalc()
        setInitPaths(true)
        _plan.fitViewportToItems()
    }
    // choose the YellowScan "camera" (the classic turns it into Manual and remembers YellowScan in CameraCalc.isYSLidar)
    function _ysSelect(cc) {
        var brands = cc.cameraBrandList, b = ""
        for (var i = 0; i < brands.length; i++) if (String(brands[i]).indexOf("Yellow") >= 0) b = brands[i]
        if (b !== "") {
            cc.cameraBrand = b
            var models = cc.cameraModelList, m = models.length > 0 ? models[0] : ""
            for (var j = 0; j < models.length; j++) if (String(models[j]).indexOf("Ultra") >= 0) m = models[j]
            if (m !== "") cc.cameraModel = m
        }
    }
    // line spacing from height + line overlap + FOV (the classic "Calculate" with spacing as the result)
    function ysCalc() {
        var cc = survey ? survey.cameraCalc : null
        if (!cc || !cc.isYSLidar || !(cc.distanceToSurface.rawValue > 0)) return
        cc.isYSAltitudeUse.rawValue = true
        cc.isYSOverlapUse.rawValue = true
        cc.isYSFOVuse.rawValue = true
        cc.isYSSpacingUse.rawValue = false
        cc.yellowScanCalculate()
        _placeInitPaths()
    }
    function _initPaths() {
        var r = []
        if (!_mission) return r
        for (var i = 1; i < _mission.visualItems.count; i++) {
            var it = _mission.visualItems.get(i)
            if (it && it.corridorPolyline !== undefined && it.turnRadius !== undefined) r.push(i)
        }
        return r
    }
    readonly property bool hasInitPaths: _ipCount > 0
    property int _ipCount: 0
    function setInitPaths(on) {
        var idx = _initPaths()
        if (!on) {
            for (var i = idx.length - 1; i >= 0; i--) _mission.removeVisualItem(idx[i])
        } else if (idx.length === 0 && survey) {
            var si = -1
            for (var k = 1; k < _mission.visualItems.count; k++) if (_mission.visualItems.get(k) === survey) si = k
            if (si < 0) return
            _mission.insertComplexMissionItem("Init Path", survey.coordinate, si, false)
            _mission.insertComplexMissionItem("Init Path", survey.exitCoordinate, si + 2, false)
            _placeInitPaths()
        }
        _ipCount = _initPaths().length
        _drawInitPaths()
        if (survey) _mission.setCurrentPlanViewSeqNum(survey.sequenceNumber, true)
    }
    // S42 note: the classic Init Path visual shows only its base line — draw the flown figure 8 on the map
    property var _ipLines: []
    function _drawInitPaths() {
        var map = planView.simpleMap
        for (var i = 0; i < _ipLines.length; i++) { if (map) map.removeMapItem(_ipLines[i]); _ipLines[i].destroy() }
        var lines = []
        var idx = kind === "lidar" ? _initPaths() : []
        for (var k = 0; k < idx.length && map; k++) {
            var l = ipLineComp.createObject(map, { ip: _mission.visualItems.get(idx[k]) })
            map.addMapItem(l)
            lines.push(l)
        }
        _ipLines = lines
    }
    Component {
        id: ipLineComp
        MapPolyline {
            property var ip: null
            visible: wiz.visible && wiz.kind === "lidar"
            line.width: SimpleTheme.px(5)
            line.color: SimpleTheme.warn
            path: ip ? ip.visualTransectPoints : []
        }
    }
    // before: at the survey entry, after: at its exit, along the grid lines, at the survey height
    function _placeInitPaths() {
        var idx = _initPaths()
        _ipCount = idx.length
        if (!survey || idx.length !== 2) return
        var az = Number(survey.gridAngle.rawValue)
        _setInit(_mission.visualItems.get(idx[0]), survey.coordinate, az)
        _setInit(_mission.visualItems.get(idx[1]), survey.exitCoordinate, az)
    }
    function _setInit(ip, at, az) {
        if (!at || !at.isValid) return
        var c = QtPositioning.coordinate(at.latitude, at.longitude)
        var p = ip.corridorPolyline.path
        var e = c.atDistanceAndAzimuth(30, az)
        if (p.length !== 2 || p[0].distanceTo(c) > 0.5 || p[1].distanceTo(e) > 0.5) {
            ip.corridorPolyline.clear()
            ip.corridorPolyline.appendVertex(c)
            ip.corridorPolyline.appendVertex(e)
        }
        if (ip.cameraCalc) ip.cameraCalc.distanceToSurface.rawValue = survey.cameraCalc.distanceToSurface.rawValue
    }
    // the init paths follow the survey when its area or lines change
    Connections {
        target: wiz.kind === "lidar" ? wiz.survey : null
        ignoreUnknownSignals: true
        function onCoordinateChanged()     { ipTimer.restart() }
        function onExitCoordinateChanged() { ipTimer.restart() }
    }
    Timer { id: ipTimer; interval: 300; onTriggered: wiz._placeInitPaths() }

    // S40 / S41: take-off → corridor or structure scan → return home
    function _findScan(k) {
        if (!_mission) return null
        for (var i = 0; i < _mission.visualItems.count; i++) {
            var it = _mission.visualItems.get(i)
            if (!it) continue
            if (k === "corridor" && it.corridorPolyline !== undefined && it.turnRadius === undefined) return it
            if (k === "structure" && it.structureHeight !== undefined) return it
        }
        return null
    }
    function _createScan(k) {
        kind = k
        survey = null
        _plan.removeAll()
        var c = planView.mapCenter()
        _mission.insertTakeoffItem(c, 1, false)
        var item = _mission.insertComplexMissionItem(k === "corridor" ? _mission.corridorScanComplexItemName : _mission.structureScanComplexItemName, c, 2, true)
        var rtl = _mission.insertSimpleMissionItem(c, 3, false)
        if (rtl) rtl.command = 20
        scanItem = item ? item : _findScan(k)
        if (scanItem && k === "corridor") {
            if (scanItem.corridorPolyline.count < 2) {
                scanItem.corridorPolyline.clear()
                // 2 x 110 m: with the turns the farthest point stays inside a 300 m geofence (like the area default)
                scanItem.corridorPolyline.appendVertex(c.atDistanceAndAzimuth(110, 250))
                scanItem.corridorPolyline.appendVertex(c)
                scanItem.corridorPolyline.appendVertex(c.atDistanceAndAzimuth(110, 60))
            }
            scanItem.corridorWidth.rawValue = 40
            if (scanItem.cameraCalc) scanItem.cameraCalc.distanceToSurface.rawValue = Math.min(80, _maxAlt)
        } else if (scanItem) {
            setShape("rectangle")
            if (scanItem.cameraCalc) scanItem.cameraCalc.distanceToSurface.rawValue = 15
            scanItem.scanBottomAlt.rawValue = 5
            scanItem.structureHeight.rawValue = Math.min(45, _maxAlt)
            scanItem.entranceAlt.rawValue = Math.min(Number(scanItem.entranceAlt.rawValue), _maxAlt)
        }
        _editScan()
        _plan.fitViewportToItems()
        step = "edit"
    }
    // the classic map shows the drag handles of the current item only
    function _editScan() { if (scanItem) _mission.setCurrentPlanViewSeqNum(scanItem.sequenceNumber, true) }
    property bool _drawFresh: false
    function setShape(sh) {
        shape = sh
        if (!scanItem || kind !== "structure") return
        var poly = scanItem.structurePolygon
        if (sh === "draw") { _drawFresh = true; return }
        // copy: a QML value-type reference would read the (cleared) centre again
        var pc = poly.center
        var c = poly.count >= 3 ? QtPositioning.coordinate(pc.latitude, pc.longitude) : planView.mapCenter()
        poly.clear()
        if (sh === "circle") {
            for (var a = 0; a < 360; a += 30) poly.appendVertex(c.atDistanceAndAzimuth(12, a))
        } else {
            // 30 m x 20 m
            var d = Math.sqrt(15 * 15 + 10 * 10), b = Math.atan2(15, 10) * 180 / Math.PI
            poly.appendVertex(c.atDistanceAndAzimuth(d, -b))
            poly.appendVertex(c.atDistanceAndAzimuth(d, b))
            poly.appendVertex(c.atDistanceAndAzimuth(d, 180 - b))
            poly.appendVertex(c.atDistanceAndAzimuth(d, 180 + b))
        }
    }

    function _fmtTime(sec) {
        if (!sec || isNaN(sec)) return "—"
        var m = Math.round(sec / 60)
        return m < 1 ? "<1 min" : m + " min"
    }

    //------------------------------------------------------------------ Header with steps
    Rectangle {
        id: header
        visible: wiz.step !== "saved"
        width: parent.width; height: SimpleTheme.px(104)
        color: SimpleTheme.surfaceGlass
        MouseArea { anchors.fill: parent }
        Row {
            anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
            spacing: SimpleTheme.px(20)
            SButton {
                designHeight: 80; icon: "back"; textSize: 26
                text: wiz.step === "check" ? (wiz.kind === "other" ? qsTr("Saved missions") : qsTr("Settings")) : qsTr("Fly")
                onClicked: wiz.step === "check" ? wiz.step = (wiz.kind === "other" ? "saved" : "edit") : simpleRoot.showFly()
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                SText { text: wiz.step === "choose" ? qsTr("Plan a mission") : wiz.kind === "waypoint" ? qsTr("Waypoint flight")
                            : wiz.kind === "editor" ? qsTr("Mission editor")
                            : wiz.kind === "corridor" ? qsTr("Corridor mapping") : wiz.kind === "structure" ? qsTr("Structure scan")
                            : wiz.kind === "lidar" ? qsTr("LiDAR survey")
                            : wiz.kind === "other" ? qsTr("Saved mission") : qsTr("Area mapping"); size: 34; bold: true }
                SText { size: 22; color: SimpleTheme.textSecondary
                        text: wiz.step === "choose" ? qsTr("What do you want to do?")
                            : wiz._planName === "" ? qsTr("New mission · not saved") : wiz._planName }
            }
        }
        Row {
            visible: wiz.step !== "choose"
            anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
            spacing: SimpleTheme.px(10)
            // S24: save the mission being edited
            SButton {
                designHeight: 60; textSize: 24; icon: "folder"; text: qsTr("Save")
                onClicked: { saveField.text = wiz._planName; saveField.reset(); saveSheet.visible = true }
            }
            Repeater {
                model: [wiz.kind === "waypoint" || wiz.kind === "editor" ? qsTr("Add points") : wiz.kind === "corridor" ? qsTr("Draw line")
                        : wiz.kind === "structure" ? qsTr("Select structure") : qsTr("Draw area"), qsTr("Settings"), qsTr("Check & send")]
                Rectangle {
                    id: stepItem
                    readonly property int cur: wiz.step === "check" ? 2 : 1
                    height: SimpleTheme.px(60); radius: height / 2
                    width: stepRow.implicitWidth + SimpleTheme.px(28)
                    color: index === cur ? SimpleTheme.brandGreen : SimpleTheme.surfaceControl
                    Row {
                        id: stepRow
                        anchors.centerIn: parent
                        spacing: SimpleTheme.px(10)
                        Rectangle {
                            width: SimpleTheme.px(40); height: width; radius: width / 2
                            color: index < stepItem.cur ? SimpleTheme.ok : index === stepItem.cur ? SimpleTheme.textPrimary : SimpleTheme.surfaceRaised
                            SIcon { visible: index < stepItem.cur; anchors.centerIn: parent; name: "check"; size: 28; color: SimpleTheme.bgBase }
                            SText { visible: index >= stepItem.cur; anchors.centerIn: parent; text: index + 1; size: 24; bold: true; color: index === stepItem.cur ? SimpleTheme.brandGreenDark : SimpleTheme.textSecondary }
                        }
                        SText { text: modelData; size: 24; medium: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }

    //------------------------------------------------------------------ S07 choose a task
    Rectangle {
        visible: wiz.step === "choose"
        anchors.top: header.bottom; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        color: SimpleTheme.bgBase
        MouseArea { anchors.fill: parent }
        Grid {
            anchors.centerIn: parent
            columns: 3
            spacing: SimpleTheme.px(28)
            Repeater {
                model: [
                    { key: "area",      icon: "grid",      title: qsTr("Area mapping"),      sub: qsTr("Photos of a field or site for a 2D map or 3D model"), ok: true },
                    { key: "waypoint",  icon: "pin",       title: qsTr("Waypoint flight"),   sub: qsTr("Fly through points you tap on the map"),            ok: true },
                    { key: "corridor",  icon: "corridor",  title: qsTr("Corridor mapping"),  sub: qsTr("Road, canal or power line"),                         ok: true },
                    { key: "structure", icon: "structure", title: qsTr("Structure scan"),    sub: qsTr("Circles around a tower or building"),               ok: true },
                    { key: "lidar",     icon: "lidar",     title: qsTr("LiDAR survey"),      sub: qsTr("YellowScan with init path"),                        ok: wiz._ysOn,
                      off: qsTr("Turn on YellowScan in Settings › Payloads") },
                    { key: "open",      icon: "folder",    title: qsTr("Open saved mission"), sub: qsTr("From this tablet or a KML file"),                  ok: true }
                ].concat(QGroundControl.corePlugin.advancedMode ? [
                    { key: "editor",    icon: "sliders",   title: qsTr("Mission editor"),    sub: qsTr("Every item, fence and rally points (Advanced)"),     ok: true } ] : [])
                Rectangle {
                    width: SimpleTheme.px(500); height: SimpleTheme.px(260); radius: SimpleTheme.px(24)
                    color: SimpleTheme.surfaceRaised
                    border.width: modelData.ok ? SimpleTheme.px(2) : 0; border.color: SimpleTheme.brandGreen
                    opacity: modelData.ok ? 1 : 0.45
                    Column {
                        anchors.fill: parent; anchors.margins: SimpleTheme.px(28)
                        spacing: SimpleTheme.px(12)
                        SIcon { name: modelData.icon; size: 64; color: modelData.ok ? SimpleTheme.ok : SimpleTheme.textSecondary }
                        SText { text: modelData.title; size: 32; bold: true }
                        SText { width: parent.width; text: modelData.ok ? modelData.sub : modelData.off ? modelData.off : qsTr("Next version"); size: 22; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap }
                    }
                    MouseArea { anchors.fill: parent; enabled: modelData.ok
                                onClicked: modelData.key === "waypoint" ? wiz.createWaypointFlight()
                                         : modelData.key === "editor" ? wiz.openEditor()
                                         : modelData.key === "open" ? wiz.step = "saved"
                                         : modelData.key === "corridor" || modelData.key === "structure" ? wiz._createScan(modelData.key)
                                         : modelData.key === "lidar" ? wiz.createLidarSurvey()
                                         : wiz.createAreaMapping() }
                }
            }
        }
    }

    //------------------------------------------------------------------ S08 settings panel (map editing happens on the PlanView map below)
    SPanel {
        id: settingsPanel
        visible: wiz.step === "edit" && wiz.kind === "area" && !!wiz.survey
        closable: false
        x: parent.width - width - SimpleTheme.px(24)
        y: header.height + SimpleTheme.px(24)
        width: SimpleTheme.px(620)
        height: parent.height - y - SimpleTheme.px(24)

        Column {
            anchors.fill: parent
            spacing: SimpleTheme.px(14)
            Item {
                width: parent.width; height: SimpleTheme.px(60)
                SText { text: qsTr("Flight height"); size: 26; medium: true; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            }
            SStepper {
                unit: "m"; step: 5; from: 10; to: wiz._maxAlt
                value: wiz._cam ? Math.round(wiz._cam.distanceToSurface.rawValue) : 80
                onEdited: if (wiz._cam) wiz._cam.distanceToSurface.rawValue = value
            }
            SText {
                width: parent.width
                text: wiz._cam && !wiz._cam.isManualCamera
                      ? qsTr("Photo detail ≈ %1 per pixel · limited to %2 m").arg(wiz._cam.imageDensity.valueString + " " + wiz._cam.imageDensity.units).arg(wiz._maxAlt)
                      : qsTr("Limited to %1 m (maximum altitude)").arg(wiz._maxAlt)
                size: 22; color: SimpleTheme.textTertiary; wrapMode: Text.WordWrap
            }
            SText { visible: wiz._cam && !wiz._cam.isManualCamera; text: qsTr("Image overlap"); size: 26; medium: true; color: SimpleTheme.textSecondary }
            SSegmented {
                visible: wiz._cam && !wiz._cam.isManualCamera
                designWidth: 556
                model: [qsTr("Standard · 2D map"), qsTr("High · 3D model")]
                currentIndex: wiz._cam && wiz._cam.frontalOverlap.rawValue >= 80 ? 1 : 0
                onActivated: {
                    wiz._cam.frontalOverlap.rawValue = index === 1 ? 80 : 70
                    wiz._cam.sideOverlap.rawValue    = index === 1 ? 70 : 60
                }
            }
            Rectangle { width: parent.width; height: 1; color: SimpleTheme.line }
            Grid {
                width: parent.width
                columns: 2
                rowSpacing: SimpleTheme.px(20)
                Repeater {
                    model: [
                        { l: qsTr("FLIGHT TIME"), v: wiz._fmtTime(wiz._mission ? wiz._mission.missionTime : 0) },
                        { l: qsTr("PHOTOS"),      v: wiz.survey ? String(wiz.survey.cameraShots) : "—" },
                        { l: qsTr("BATTERIES"),   v: wiz._mission && wiz._mission.batteriesRequired > 0 ? String(wiz._mission.batteriesRequired) : "—" },
                        { l: qsTr("AREA"),        v: wiz.survey ? (wiz.survey.coveredArea / 10000).toFixed(1) + " ha" : "—" }
                    ]
                    Column {
                        width: parent.width / 2
                        SText { text: modelData.l; size: 22; medium: true; color: SimpleTheme.textTertiary }
                        SText { text: modelData.v; size: 32; bold: true }
                    }
                }
            }
        }
        SButton {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: SimpleTheme.px(28)
            kind: "primary"
            text: qsTr("Next: check & send")
            onClicked: wiz.step = "check"
        }
    }

    Rectangle {
        visible: wiz.step === "edit" && (wiz.kind === "area" || wiz.kind === "corridor" || wiz.kind === "structure" || wiz.kind === "lidar")
        x: SimpleTheme.px(24); anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(24)
        width: hintRow.implicitWidth + SimpleTheme.px(40); height: SimpleTheme.px(64); radius: SimpleTheme.px(16)
        color: SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
        Row {
            id: hintRow
            anchors.centerIn: parent
            spacing: SimpleTheme.px(12)
            SIcon { name: "info"; size: 32; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            SText { size: 24; color: SimpleTheme.textSecondary
                    text: wiz.kind === "corridor" ? qsTr("Tap the map to add points · drag a point to move it")
                        : wiz.kind === "structure" ? (wiz.shape === "draw" ? qsTr("Tap around the structure to outline it") : qsTr("Drag the corners to fit the structure, or pick a shape"))
                        : wiz.kind === "lidar" && wiz.hasInitPaths ? qsTr("Drag the corners to fit the site · the init path is added automatically")
                        : qsTr("Drag the corners to fit the area. Tap an edge midpoint to add a corner.") }
        }
    }

    //------------------------------------------------------------------ S40 corridor / S41 structure settings
    SimpleScanSettings {
        visible: wiz.step === "edit" && ((wiz.kind === "corridor" || wiz.kind === "structure") && !!wiz.scanItem
                                          || wiz.kind === "lidar" && !!wiz.survey)
        x: parent.width - width - SimpleTheme.px(24)
        y: header.height + SimpleTheme.px(24)
        width: SimpleTheme.px(620)
        height: parent.height - y - SimpleTheme.px(24)
        kind: wiz.kind
        item: wiz.kind === "lidar" ? wiz.survey : wiz.scanItem
        mission: wiz._mission
        initPaths: wiz.hasInitPaths
        onInitPathsRequested: wiz.setInitPaths(on)
        onYsEdited: wiz.ysCalc()
        maxAlt: wiz._maxAlt
        shape: wiz.shape
        onShapeRequested: wiz.setShape(shape)
        onNextRequested: wiz.step = "check"
    }

    //------------------------------------------------------------------ S23 waypoint flight
    SimpleWaypointEditor {
        id: wpEditor
        anchors.fill: parent
        visible: wiz.step === "edit" && wiz.kind === "waypoint"
        plan: wiz._plan
        map: typeof planView !== "undefined" ? planView.simpleMap : null
        maxAlt: wiz._maxAlt
        topInset: header.height
        onNextRequested: wiz.step = "check"
    }

    //------------------------------------------------------------------ S80 mission editor (Advanced mode)
    SimpleMissionEditor {
        id: missionEditor
        anchors.fill: parent
        visible: wiz.step === "edit" && wiz.kind === "editor"
        plan: wiz._plan
        map: typeof planView !== "undefined" ? planView.simpleMap : null
        topInset: header.height
        onNextRequested: wiz.step = "check"
        onVisibleChanged: if (!visible && typeof planView !== "undefined" && planView.simpleSetEditingLayer) planView.simpleSetEditingLayer("mission")
    }

    //------------------------------------------------------------------ S39 check & send
    SimplePlanCheck {
        visible: wiz.step === "check"
        x: parent.width - width - SimpleTheme.px(24)
        y: header.height + SimpleTheme.px(24)
        width: SimpleTheme.px(620)
        height: parent.height - y - SimpleTheme.px(24)
        vs: wiz.vs
        plan: wiz._plan
        survey: wiz.kind === "area" || wiz.kind === "lidar" ? wiz.survey : null
        route: wiz._route
        routeHeight: wiz._routeHeight
        maxAlt: wiz._maxAlt
    }

    //------------------------------------------------------------------ S24 saved missions
    SimpleSavedMissions {
        id: savedPage
        anchors.fill: parent
        visible: wiz.step === "saved"
        onBackRequested: simpleRoot.showFly()
        onNewRequested: { message = ""; wiz.step = "choose" }
        onOpenRequested: { message = ""; wiz.requestOpen(file) }
        onImportRequested: { message = ""; wiz.requestImport(file) }
    }

    // save under a name (S24)
    Rectangle {
        anchors.fill: parent
        visible: saveSheet.visible
        color: SimpleTheme.withAlpha("black", 0.45)
        MouseArea { anchors.fill: parent; onClicked: saveSheet.visible = false }
    }
    SPanel {
        id: saveSheet
        visible: false
        anchors.centerIn: parent
        width: SimpleTheme.px(820); height: SimpleTheme.px(400)
        title: qsTr("Save mission"); titleIcon: "folder"
        onCloseRequested: visible = false
        readonly property string _name: saveField.currentText.trim()
        readonly property bool _valid: _name !== "" && /^[^\\/:*?"<>|]+$/.test(_name)
        readonly property bool _exists: _valid && wizFdc.fileExists(QGroundControl.settingsManager.appSettings.missionSavePath + "/" + _name + ".plan")
        Column {
            anchors.fill: parent; spacing: SimpleTheme.px(18)
            STextField { id: saveField; designWidth: 764; label: qsTr("Name"); placeholder: qsTr("e.g. Field A survey") }
            SText {
                width: parent.width; wrapMode: Text.WordWrap; size: 22
                color: saveSheet._exists ? SimpleTheme.warn : SimpleTheme.textSecondary
                text: saveSheet._exists ? qsTr("A mission with this name exists and will be replaced.")
                                        : qsTr("Saved on this tablet · Plan › Open saved mission")
            }
            SButton {
                kind: "primary"; text: saveSheet._exists ? qsTr("Replace") : qsTr("Save")
                enabled_: saveSheet._valid
                onClicked: { wiz.saveAs(saveSheet._name); saveSheet.visible = false }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: replaceSheet.visible
        color: SimpleTheme.withAlpha("black", 0.45)
        MouseArea { anchors.fill: parent; onClicked: { replaceSheet.visible = false; wiz._pending = null } }
    }
    SimpleConfirmSheet {
        id: replaceSheet
        visible: false
        anchors.centerIn: parent
        icon: "warn"
        title: qsTr("Replace the plan being edited?")
        detail: qsTr("The current plan is not saved on this tablet. It is replaced by the mission you open.")
        note: qsTr("To keep it, close this and use Save first.")
        slideText: qsTr("Slide to replace")
        onCloseRequested: { visible = false; wiz._pending = null }
        onConfirmed: { visible = false; wiz._runPending() }
    }
}
