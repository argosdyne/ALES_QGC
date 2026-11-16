/****************************************************************************
 * AQGC Simple UI — fly screen overlay (Figma S01–S05, S10 basic, S18 rail, S25–S29, S33–S38)
 * Sits on top of the classic FlyView (map, video PiP); the classic widgets are hidden in Simple mode.
 ****************************************************************************/
import QtQuick 2.12
import QtPositioning 5.12
import QGroundControl 1.0
import "."

Item {
    id: fly
    property var vs
    readonly property var  _veh:    vs.vehicle
    readonly property var  _guided: globals.guidedControllerFlyView
    readonly property real _W:      width
    readonly property real _H:      height

    // which sheet/panel is open: "" | preflight | takeoff | rtl | land | mode | chip | messages
    //                            | gohere | coords | sethome | altitude (S35, S38)
    property string sheet:      ""
    property string chipKind:   ""

    // S35 map tap menu (not a dimmed sheet: the map stays usable, a new tap moves the pin)
    property var  tapCoord:     QtPositioning.coordinate()
    property var  tapZones:     []
    readonly property var _map: typeof flightView !== "undefined" ? flightView.simpleMap : null
    function closeTapMenu() { tapCoord = QtPositioning.coordinate(); tapZones = [] }
    function openTapMenu(coord) { tapCoord = coord; tapZones = mapControls.zonesShownAt(coord) }
    Connections {
        target: fly._map
        function onSimpleMapClicked(coordinate) {
            if (!vs.present || fly.videoMain || fly.sheet !== "") return
            if (fly.payloadsOpen || fly.cameraOpen) { fly.payloadsOpen = false; fly.cameraOpen = false; return }   // a map tap first closes the panel
            mapControls.tappedZones = []
            fly.openTapMenu(coordinate)
        }
    }
    onVideoMainChanged: if (videoMain) { closeTapMenu(); payloadsOpen = false }

    // short message at the bottom centre (S36: arrived, Go here not sent, choose a new target)
    function toast(text, level) {
        toastBox.text = text
        toastBox.level = level === undefined ? "info" : level
        toastBox.visible = true
        toastTimer.restart()
    }

    // closing the tether power-off sheet without the slide cancels the station's pending request
    function closeSheet() {
        if (sheet === "tetheroff" && _guided) _guided.cancelTetherPowerOff()
        sheet = ""
    }
    function openSheet(name) { sheet = name }

    // S10 Payloads panel (not a dimmed sheet, like the S35 menu)
    property bool payloadsOpen: false
    property bool cameraOpen: false      // S43 camera settings (same place as the Payloads panel; never both)

    // Tether station confirmations (S16 power off in flight, S50 no-power Land / Return to station).
    // The classic confirm dialog lives in the hidden classic widget layer, so Simple shows its own slide sheets.
    readonly property var _st: QGroundControl.corePlugin.elistairStationManager
    property bool tetherRtl: false
    property var  tetherIncident: 0
    Connections {
        target: fly._st
        function onPowerOffConfirmationRequested() { fly.openSheet("tetheroff") }
        function onNoPowerActionRequested(rtl, incident) { fly.tetherRtl = rtl; fly.tetherIncident = incident; fly.openSheet("tethernp") }
    }

    // S51: LiDAR start refused (shown for 10 s)
    property string lidarRefusal: ""
    Timer { id: lidarRefusalTimer; interval: 10000; onTriggered: fly.lidarRefusal = "" }

    // Layer rule 1: a critical alert closes confirm sheets; so does a lost link on the ground (nothing can be sent)
    function _closeConfirmSheet() {
        if ((vs.critical || vs.lost) && (fly.sheet === "takeoff" || fly.sheet === "mission" || fly.sheet === "rtl" || fly.sheet === "land"
                                         || fly.sheet === "gohere" || fly.sheet === "sethome" || fly.sheet === "altitude")) fly.closeSheet()
        // Go here / change altitude only while flying (not returning, landing or on the ground)
        if (vs.state !== "flying" && (fly.sheet === "gohere" || fly.sheet === "altitude")) fly.closeSheet()
    }
    Connections {
        target: vs
        function onCriticalChanged() { fly._closeConfirmSheet() }
        function onLostChanged()     { fly._closeConfirmSheet() }
        function onStateChanged()    { fly._closeConfirmSheet() }
        function onPresentChanged()  { if (!vs.present) fly.closeTapMenu() }
    }

    function _act(code, data, value, option) {
        if (_guided) _guided.executeAction(code, data === undefined ? null : data, value === undefined ? 0 : value, option === undefined ? false : option)
    }

    //------------------------------------------------------------------ Top bar
    SimpleTopBar {
        id: topBar
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        vs: fly.vs
        onMenuClicked:      simpleRoot.openMenu()
        onStatusClicked:    if (vs.state === "ground" || vs.state === "disconnected") fly.openSheet("preflight")
        onModeClicked:      if (vs.connected) fly.openSheet("mode")
        onChipClicked:      { fly.chipKind = which; fly.openSheet("chip") }
        onMessagesClicked:  if (vs.present) { _veh.resetAllMessages(); fly.openSheet("messages") }
    }

    //------------------------------------------------------------------ Left actions (state rules)
    Column {
        id: actions
        x: SimpleTheme.px(SimpleTheme.actionX)
        y: SimpleTheme.px(SimpleTheme.actionY0)
        spacing: SimpleTheme.px(SimpleTheme.actionStep - 148)
        visible: vs.present

        SActionButton {
            visible: vs.state === "ground"
            text: qsTr("Take off"); icon: "takeoff"
            fill: vs.readyToTakeOff ? SimpleTheme.brandGreen : SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
            onClicked: fly.openSheet(vs.readyToTakeOff ? "takeoff" : "preflight")
        }
        SActionButton {
            visible: vs.state === "ground" && vs.hasMission
            text: qsTr("Start mission"); icon: "play"
            fill: vs.readyToTakeOff ? SimpleTheme.brandGreen : SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
            onClicked: fly.openSheet(vs.readyToTakeOff ? "mission" : "preflight")
        }
        SActionButton {
            visible: vs.paused && vs.hasMission
            text: qsTr("Resume"); icon: "play"
            fill: SimpleTheme.brandGreen
            onClicked: fly._act(fly._guided.actionContinueMission)
        }
        SActionButton {
            visible: vs.state === "flying" || vs.state === "lost"
            enabled_: vs.state !== "lost"
            text: qsTr("Return home"); icon: "home"
            onClicked: fly.openSheet("rtl")
        }
        SActionButton {
            visible: vs.state === "flying" || vs.state === "returning" || vs.state === "lost"
            enabled_: vs.state !== "lost" && !vs.landing
            text: qsTr("Land"); icon: "land"
            onClicked: fly.openSheet("land")
        }
        SActionButton {
            visible: (vs.state === "flying" && !vs.paused) || vs.state === "returning" || vs.state === "lost"
            enabled_: vs.state !== "lost" && _veh && _veh.pauseVehicleSupported && vs.gpsLock >= 3   // QA F6
            text: qsTr("Pause"); icon: "pause"
            onClicked: fly._act(fly._guided.actionPause)
        }
    }

    //------------------------------------------------------------------ Camera rail (right)
    SimpleCameraRail {
        id: rail
        anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(24)
        y: SimpleTheme.px(128)
        vehicle: fly._veh
        visible: vs.present
        blocked: fly.waitingVideo
        settingsOpen: fly.cameraOpen
        onSettingsClicked: { fly.closeTapMenu(); fly.payloadsOpen = false; fly.cameraOpen = !fly.cameraOpen }
    }

    // S10: Payloads button under the camera rail (badge = connected payloads) and the panel left of the rail
    Rectangle {
        id: payloadsBtn
        visible: vs.present && payloadPanel.count > 0
        anchors.horizontalCenter: rail.horizontalCenter
        y: rail.y + rail.height + SimpleTheme.px(16)
        width: rail.width; height: SimpleTheme.px(124); radius: SimpleTheme.px(28)
        color: fly.payloadsOpen ? SimpleTheme.withAlpha(SimpleTheme.brandGreen, 0.35) : SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
        border.width: SimpleTheme.px(3); border.color: fly.payloadsOpen ? SimpleTheme.ok : SimpleTheme.line
        Column {
            anchors.centerIn: parent
            SIcon { anchors.horizontalCenter: parent.horizontalCenter; name: "plus"; size: 44 }
            SText { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("Payloads"); size: 20 }
        }
        Rectangle {
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: -SimpleTheme.px(6)
            width: SimpleTheme.px(40); height: width; radius: width / 2
            color: SimpleTheme.brandGreen
            SText { anchors.centerIn: parent; text: payloadPanel.count; size: 22; bold: true }
        }
        MouseArea { anchors.fill: parent; onClicked: { fly.closeTapMenu(); fly.cameraOpen = false; fly.payloadsOpen = !fly.payloadsOpen } }
    }
    SimplePayloadPanel {
        id: payloadPanel
        visible: fly.payloadsOpen && vs.present
        anchors.right: rail.left; anchors.rightMargin: SimpleTheme.px(16)
        y: topBar.height + SimpleTheme.px(16)
        maxHeight: SimpleTheme.px(810) - y          // above the video PiP (top at 830)
        vs: fly.vs
        onCloseRequested: fly.payloadsOpen = false
        onLidarRefused: { fly.lidarRefusal = reason; lidarRefusalTimer.restart() }
    }
    SimpleCameraSheet {
        visible: fly.cameraOpen && vs.present
        anchors.right: rail.left; anchors.rightMargin: SimpleTheme.px(16)
        y: topBar.height + SimpleTheme.px(16)
        maxHeight: SimpleTheme.px(810) - y
        vehicle: fly._veh
        onCloseRequested: fly.cameraOpen = false
        onAdvancedRequested: { fly.cameraOpen = false; simpleRoot.requestAdvanced("advanced") }
    }

    //------------------------------------------------------------------ Telemetry bar (x = 24, bottom 24)
    STelemetryBar {
        x: SimpleTheme.px(SimpleTheme.telemetryX)
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(24)
        vehicle: fly._veh
        visible: vs.present
        stale: vs.lost
        // S38: tap ALTITUDE in flight (not during a mission, return or landing: classic showChangeAlt)
        altitudeTappable: vs.state === "flying" && !!fly._guided && fly._guided.showChangeAlt
        onAltitudeClicked: { fly.closeTapMenu(); fly.openSheet("altitude") }
    }

    //------------------------------------------------------------------ Video main (S18) and waiting for video (S49)
    // Video is the main view after a tap on the PiP (FlyView). Map overlays are hidden then; camera info is shown.
    readonly property bool videoMain:   typeof flightView !== "undefined" && !flightView._mainWindowIsMap
    readonly property var  _camMgr:     _veh ? _veh.cameraManager : null
    readonly property var  _cam:        _camMgr && _camMgr.cameras.count > 0 ? _camMgr.cameras.get(_camMgr.currentCamera) : null
    readonly property bool _decoding:   QGroundControl.videoManager.decoding
    readonly property bool waitingVideo: videoMain && !_decoding
    property bool noVideoLong: false            // no picture for more than 30 s
    onWaitingVideoChanged: { noVideoLong = false; if (waitingVideo) noVideoTimer.restart(); else noVideoTimer.stop() }
    Timer { id: noVideoTimer; interval: 30000; onTriggered: fly.noVideoLong = true }

    // REC indicator, top centre
    Rectangle {
        visible: fly.videoMain && !!fly._cam && fly._cam.videoStatus === 1
        anchors.horizontalCenter: parent.horizontalCenter
        y: topBar.height + SimpleTheme.px(24)
        height: SimpleTheme.px(52); radius: SimpleTheme.px(14)
        width: recRow.width + SimpleTheme.px(36)
        color: SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
        Row {
            id: recRow; anchors.centerIn: parent; spacing: SimpleTheme.px(12)
            Rectangle { width: SimpleTheme.px(16); height: width; radius: width / 2; color: SimpleTheme.danger; anchors.verticalCenter: parent.verticalCenter }
            SText { text: qsTr("REC %1").arg(fly._cam ? fly._cam.recordTimeStr : ""); size: 26; bold: true; anchors.verticalCenter: parent.verticalCenter }
            SText { visible: !!fly._cam && fly._cam.storageFreeStr !== ""; text: qsTr("%1 left").arg(fly._cam ? fly._cam.storageFreeStr : "")
                    size: 22; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // Zoom (only for zoom cameras): hold + / − to zoom, tap the factor to step 1× → 2× → 5× → 10×
    Rectangle {
        id: zoomBox
        visible: fly.videoMain && !!fly._cam && fly._cam.hasZoom
        anchors.right: rail.left; anchors.rightMargin: SimpleTheme.px(16)
        y: rail.y + SimpleTheme.px(64)
        width: SimpleTheme.px(120); height: zoomCol.height + SimpleTheme.px(28)
        radius: width / 2
        color: SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
        border.width: SimpleTheme.px(2); border.color: SimpleTheme.line
        Column {
            id: zoomCol; anchors.horizontalCenter: parent.horizontalCenter; y: SimpleTheme.px(14); spacing: SimpleTheme.px(10)
            SRoundIconButton { designWidth: 88; designHeight: 88; radius: width / 2; icon: "plus"
                MouseArea { anchors.fill: parent; onPressed: fly._cam.startZoom(1); onReleased: fly._cam.stopZoom(); onCanceled: fly._cam.stopZoom() } }
            SText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: fly._cam ? Number(fly._cam.zoomLevel).toFixed(1) + "×" : ""; size: 26; bold: true
                MouseArea {
                    anchors.fill: parent; anchors.margins: -SimpleTheme.px(16)
                    onClicked: {
                        var steps = [1, 2, 5, 10], z = Number(fly._cam.zoomLevel), next = 1
                        for (var i = 0; i < steps.length; i++) if (steps[i] > z + 0.05) { next = steps[i]; break }
                        fly._cam.zoomLevel = next
                    }
                }
            }
            SRoundIconButton { designWidth: 88; designHeight: 88; radius: width / 2; icon: "minus"
                MouseArea { anchors.fill: parent; onPressed: fly._cam.startZoom(-1); onReleased: fly._cam.stopZoom(); onCanceled: fly._cam.stopZoom() } }
            SText { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("Zoom"); size: 20; color: SimpleTheme.textSecondary }
        }
    }

    // Gimbal angles under the camera rail
    Rectangle {
        visible: fly.videoMain && !!fly._veh && fly._veh.gimbalData
        anchors.right: rail.left; anchors.rightMargin: SimpleTheme.px(16)
        y: rail.y + rail.height - height
        height: SimpleTheme.px(52); radius: SimpleTheme.px(14)
        width: gimbalText.implicitWidth + SimpleTheme.px(32)
        color: SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
        SText {
            id: gimbalText; anchors.centerIn: parent; size: 24; bold: true
            text: fly._veh ? qsTr("Pitch %1° · Yaw %2°").arg(Math.round(fly._veh.gimbalPitch)).arg(Math.round(fly._veh.gimbalYaw)) : ""
        }
    }

    // Heading and attitude, right of the telemetry bar (direction sense when only the video is visible)
    Row {
        visible: fly.videoMain && vs.present
        x: SimpleTheme.px(950)
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(24)
        spacing: SimpleTheme.px(22)
        SCompass  { heading: fly._veh ? Number(fly._veh.heading.rawValue) : NaN }
        SAttitude { roll: fly._veh ? Number(fly._veh.roll.rawValue) : NaN; pitch: fly._veh ? Number(fly._veh.pitch.rawValue) : NaN }
    }

    // S30: map controls left of the PiP, Layers panel, scale bar (hidden while the video is the main view)
    SimpleMapControls {
        id: mapControls
        anchors.fill: parent
        tapMenuEnabled: vs.present
        visible: !fly.videoMain && !fly.payloadsOpen && !fly.cameraOpen && typeof flightView !== "undefined"
        map: typeof flightView !== "undefined" ? flightView.simpleMap : null
        vehicle: fly._veh
    }

    // S36: Go here in progress — above the telemetry bar, left of the map controls
    SimpleGoHereCard {
        id: goCard
        anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(1920 - 1366)
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(24 + 120 + 16)
        visible: active && vs.present && !fly.videoMain
        map: fly._map
        vehicle: fly._veh
        onChangeTargetRequested: fly.toast(qsTr("Tap the map to choose a new point"))
        onArrived: { fly.toast(qsTr("Arrived — holding position"), "ok"); arrivedClear.restart() }
    }
    // keep the "Arrived" pin a few seconds, then clear the Go here target from the map
    Timer { id: arrivedClear; interval: 5000; onTriggered: if (fly._map && fly._map.gotoArrivalConfirmed) fly._map.clearGotoProgress() }

    // S35: map tap menu
    SimpleMapTapMenu {
        anchors.fill: parent
        visible: fly.tapCoord.isValid && vs.present && !fly.videoMain && fly.sheet === ""
        map: fly._map
        vs: fly.vs
        coordinate: fly.tapCoord
        zones: fly.tapZones
        bottomLimit: height - SimpleTheme.px(24 + 120 + 16)
        onCloseRequested: fly.closeTapMenu()
        onGoHereRequested: fly.openSheet("gohere")
        onSetHomeRequested: fly.openSheet("sethome")
        onCoordinatesRequested: fly.openSheet("coords")
        onZoneDetailsRequested: { mapControls.showZonesAt(coordinate); fly.closeTapMenu() }
    }

    // S49: waiting for video / no video (flight controls stay as they are)
    Column {
        id: waitPanel
        visible: fly.waitingVideo
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: -SimpleTheme.px(40)
        width: SimpleTheme.px(760)
        spacing: SimpleTheme.px(16)
        property bool help: false
        readonly property bool _camOk: !!fly._cam
        readonly property bool _streaming: QGroundControl.videoManager.streaming
        Canvas {
            id: spinner
            visible: !fly.noVideoLong
            anchors.horizontalCenter: parent.horizontalCenter
            width: SimpleTheme.px(96); height: width
            onPaint: { var g = getContext("2d"); g.reset(); g.lineWidth = SimpleTheme.px(8); g.strokeStyle = SimpleTheme.brandGreen; g.lineCap = "round"
                       g.beginPath(); g.arc(width / 2, height / 2, width / 2 - g.lineWidth, 0, Math.PI * 1.5); g.stroke() }
            RotationAnimation on rotation { running: spinner.visible && waitPanel.visible; from: 0; to: 360; duration: 1100; loops: Animation.Infinite }
        }
        SIcon { visible: fly.noVideoLong; anchors.horizontalCenter: parent.horizontalCenter; name: "video"; size: 72; color: SimpleTheme.textSecondary }
        SText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: fly.noVideoLong ? qsTr("No video — flight is not affected") : qsTr("Waiting for video…"); size: 36; bold: true
        }
        SText {
            width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
            text: fly.noVideoLong ? qsTr("The drone keeps flying normally. Check the camera and the video link, or use the map.")
                                  : qsTr("The camera is starting. This usually takes about 10 seconds.")
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: SimpleTheme.px(6)
            Row {
                spacing: SimpleTheme.px(10)
                SIcon { name: waitPanel._camOk ? "check" : "warn"; size: 28; color: waitPanel._camOk ? SimpleTheme.ok : SimpleTheme.warn; anchors.verticalCenter: parent.verticalCenter }
                SText { text: waitPanel._camOk ? qsTr("Camera %1 connected").arg(fly._cam.modelName) : qsTr("Camera not reported by the drone")
                        size: 24; color: waitPanel._camOk ? SimpleTheme.textPrimary : SimpleTheme.warn }
            }
            Row {
                spacing: SimpleTheme.px(10)
                SIcon { name: waitPanel._streaming ? "check" : "warn"; size: 28; color: waitPanel._streaming ? SimpleTheme.ok : SimpleTheme.warn; anchors.verticalCenter: parent.verticalCenter }
                SText { text: waitPanel._streaming ? qsTr("Video link connected · waiting for the first picture") : qsTr("Video link: searching")
                        size: 24; color: waitPanel._streaming ? SimpleTheme.textPrimary : SimpleTheme.warn }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: SimpleTheme.px(16)
            SButton { kind: fly.noVideoLong ? "primary" : "secondary"; icon: "map"; text: qsTr("Show map instead"); onClicked: flightView.simpleShowMap() }
            SButton { icon: "help"; text: qsTr("Video help"); onClicked: waitPanel.help = !waitPanel.help }
        }
        SText {
            visible: waitPanel.help
            width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
            text: qsTr("1. Camera: powered on and its cable plugged in.  2. Video link: the radio is connected (Settings › Connection).  3. Video address: Settings › Payloads › Camera & gimbal. Error details are in the messages (bell).")
        }
    }

    //------------------------------------------------------------------ Banners (S34 paused, S05/S33 returning, S37 lost)
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: topBar.height + SimpleTheme.px(24)
        spacing: SimpleTheme.px(12)
        SBanner {
            visible: vs.state === "lost"
            level: "danger"; icon: "signal"
            title: qsTr("Radio signal lost — the drone follows its failsafe (usually Return home)")
            detail: qsTr("Move closer or raise the controller antenna. Controls return when the signal is back.")
        }
        // S50 tether power lost (classic SAFE-T no-power rules: failsafe 0 recommend land, 1 warn only, 2 auto land)
        SBanner {
            readonly property bool _ask: fly._st && fly._st.noPowerPrompt && !fly._st.noPowerVehicleNeedsConfirmation
            visible: !!fly._st && fly._st.noPower
            level: "danger"; icon: "tether"
            title: qsTr("Tether power lost — the drone is on its onboard battery")
            detail: !fly._st ? "" : fly._st.noPowerVehicleNeedsConfirmation ? qsTr("Confirm the tethered drone in the Advanced tether panel first.")
                  : fly._st.noPowerFailsafe === 2 ? qsTr("The drone lands by itself. Keep the area below clear.")
                  : fly._st.noPowerFailsafe === 1 ? qsTr("Check the generator and the ground unit. Land if power does not return.")
                  : qsTr("Landing is recommended. Keep the area below clear.")
            actions: _ask ? [qsTr("Land"), qsTr("To station"), qsTr("Continue")] : []
            onActionAt: {
                if (index === 0) fly._st.requestNoPowerAction(false)
                else if (index === 1) fly._st.requestNoPowerAction(true)
                else fly._st.dismissNoPower()
            }
        }
        // S51 LiDAR start refused
        SBanner {
            visible: fly.lidarRefusal !== ""
            level: "warn"; icon: "lidar"
            title: qsTr("LiDAR can't start recording")
            detail: fly.lidarRefusal
            actionText: qsTr("OK")
            onAction: fly.lidarRefusal = ""
        }
        // S36 obstacle during Go here (classic G-05 stopped / G-06 going around)
        SBanner {
            visible: goCard.obstacleStopped && vs.state === "flying"
            level: "warn"; icon: "warn"
            title: qsTr("Obstacle %1 ahead — drone stopped").arg(goCard.hDist(goCard.obstacleM))
            detail: qsTr("Choose what to do. The drone keeps holding until you choose.")
            readonly property var _codes: goCard.obstacleOn ? ["around", "rtl", "hold"] : ["rtl", "hold"]
            actions: goCard.obstacleOn ? [qsTr("Go around"), qsTr("Return home"), qsTr("Hold here")] : [qsTr("Return home"), qsTr("Hold here")]
            onActionAt: {
                var c = _codes[index]
                if (c === "around") goCard.goAround()
                else if (c === "rtl") fly.openSheet("rtl")
                else goCard.stop()
            }
        }
        SBanner {
            visible: goCard.obstacleAvoiding && vs.state === "flying"
            level: "info"; icon: "warn"
            title: qsTr("Obstacle %1 ahead — going around it").arg(goCard.hDist(goCard.obstacleM))
            detail: qsTr("The drone finds its own way to the point. Stop on the card holds it in place.")
        }
        // Flight zones (Figma S15): near = orange, inside = red; voice from FlightZoneManager. Only while the drone flies.
        SBanner {
            readonly property var  _z: typeof mainWindow !== "undefined" ? mainWindow.flightZoneManager : null
            readonly property int  _lvl: _z && vs.present && vs.state !== "ground" ? _z.zoneLevel : 0
            readonly property string _kind: !_z ? "" : _z.zoneStatusClass === 1 ? qsTr("Prohibited zone")
                                            : _z.zoneStatusNoEntry ? qsTr("No-entry zone")
                                            : _z.zoneStatusClass === 2 ? qsTr("Authorisation zone")
                                            : _z.zoneStatusClass === 4 ? qsTr("My zone") : qsTr("Flight zone")
            readonly property string _dist: _z ? Math.round(QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(_z.zoneDistance))
                                                 + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString : ""
            visible: _lvl > 0
            level: _lvl === 2 ? "danger" : "warn"; icon: "warn"
            title: _lvl === 2 ? qsTr("Inside: %1").arg(_kind) : qsTr("%1 %2 ahead").arg(_kind).arg(_dist)
            detail: (_z && _z.zoneStatusName !== "" ? _z.zoneStatusName + " · " : "")
                    + (_lvl === 2 ? qsTr("Leave the zone: return home or fly back out.") : qsTr("Turn back or stop."))
            actionText: _lvl === 2 ? qsTr("Return home") : ""
            onAction: fly.openSheet("rtl")
        }
        // Battery warning (decision 2026-11-15): flying at 30 % or less shows a banner, not only the orange chip.
        // At 20 % or less while the drone is not yet returning, it turns red. Returning has its own banner below.
        SBanner {
            visible: vs.state === "flying" && !vs.paused && !isNaN(vs.batteryPct) && vs.batteryPct <= 30
            level: vs.batteryPct <= 20 ? "danger" : "warn"; icon: "battery"
            title: vs.batteryPct <= 20 ? qsTr("Battery very low (%1 %) — return home now").arg(Math.round(vs.batteryPct))
                                       : qsTr("Battery low (%1 %) — plan to return home").arg(Math.round(vs.batteryPct))
            // batteryTime is "--:--:--" when the drone does not report it
            detail: /[1-9]/.test(vs.batteryTime) ? qsTr("About %1 of flight left.").arg(vs.batteryTime) : qsTr("Bring the drone back while there is enough battery.")
            actionText: qsTr("Return home")
            onAction: fly.openSheet("rtl")
        }
        SBanner {
            visible: vs.state === "returning"
            level: "warn"; icon: vs.landing ? "land" : "home"
            title: vs.landing ? qsTr("Landing") : (!isNaN(vs.batteryPct) && vs.batteryPct <= 20 ? qsTr("Battery low — returning home") : qsTr("Returning home"))
            detail: [vs.recentWarning !== "" ? qsTr("Drone: %1").arg(vs.recentWarning) : "",          // QA F5: why it returns / lands
                     vs.gpsLock < 3 ? (vs.landing ? "" : qsTr("Land lands here."))                         // QA F6: no pause without GPS
                     : vs.landing ? qsTr("Pause stops the drone in place.") : qsTr("Pause stops the drone in place. Land lands here.")]
                    .filter(function(t) { return t !== "" }).join(" · ")
        }
        SBanner {
            visible: vs.paused
            level: "info"; icon: "pause"
            title: qsTr("Paused — holding position")
            detail: vs.hasMission ? qsTr("Mission paused. Resume continues from the current waypoint.")
                  : goCard.paused ? qsTr("Go here stopped. Continue or Cancel on the card below.")
                  : qsTr("Use Return home or Land, or change the flight mode.")
            actionText: vs.hasMission ? qsTr("Resume mission") : ""
            onAction: fly._act(fly._guided.actionContinueMission)
        }
    }

    //------------------------------------------------------------------ S01 connecting card
    SimpleConnectCard {
        anchors.centerIn: parent
        visible: !vs.present
    }

    //------------------------------------------------------------------ Dim + sheets
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: topBar.height
        visible: fly.sheet !== ""
        color: SimpleTheme.withAlpha("black", 0.45)
        MouseArea { anchors.fill: parent; onClicked: fly.closeSheet() }   // tap outside = close top layer
    }

    SimplePreflightSheet {
        visible: fly.sheet === "preflight"
        anchors.centerIn: parent
        vs: fly.vs
        onCloseRequested: fly.closeSheet()
        onTakeoffRequested: fly.openSheet("takeoff")
    }
    SimpleTakeoffSheet {
        visible: fly.sheet === "takeoff"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(40)
        onCloseRequested: fly.closeSheet()
        onConfirmed: { fly._act(fly._guided.actionTakeoff, null, altitude); fly.closeSheet() }
    }
    SimpleConfirmSheet {
        visible: fly.sheet === "rtl" || fly.sheet === "land" || fly.sheet === "mission"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(40)
        icon:   fly.sheet === "rtl" ? "home" : fly.sheet === "land" ? "land" : "play"
        title:  fly.sheet === "rtl" ? qsTr("Return home") : fly.sheet === "land" ? qsTr("Land here") : qsTr("Start mission")
        detail: fly.sheet === "rtl" ? qsTr("The drone climbs to the return-home altitude, flies back to the home point and lands.")
              : fly.sheet === "land" ? qsTr("The drone descends and lands straight below its current position.")
              : qsTr("The drone takes off and flies the mission on the map. It returns home when the mission ends.")
        note:   fly.sheet === "land" ? qsTr("You can stop it any time with Pause.") : qsTr("You can stop it any time with Pause. Return-home altitude: Settings › Safety")
        slideText: fly.sheet === "rtl" ? qsTr("Slide to return home") : fly.sheet === "land" ? qsTr("Slide to land") : qsTr("Slide to start")
        onCloseRequested: fly.closeSheet()
        onConfirmed: {
            if (fly.sheet === "rtl") fly._act(fly._guided.actionRTL, null, 0, false)
            else if (fly.sheet === "mission") fly._act(fly._guided.actionStartMission)
            else fly._act(fly._guided.actionLand)
            fly.closeSheet()
        }
    }
    SimpleModeSheet {
        visible: fly.sheet === "mode"
        anchors.centerIn: parent
        vehicle: fly._veh
        onCloseRequested: fly.closeSheet()
    }
    SimpleChipDetail {
        visible: fly.sheet === "chip"
        anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(24)
        y: topBar.height + SimpleTheme.px(16)
        kind: fly.chipKind
        vs: fly.vs
        onCloseRequested: fly.closeSheet()
    }
    SimpleMessages {
        visible: fly.sheet === "messages"
        anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(24)
        y: topBar.height + SimpleTheme.px(16)
        vehicle: fly._veh
        onCloseRequested: fly.closeSheet()
    }

    //------------------------------------------------------------------ S35 / S38 sheets
    SimpleGoHereSheet {
        visible: fly.sheet === "gohere"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(40)
        vehicle: fly._veh
        map: fly._map
        coordinate: fly.tapCoord
        onCloseRequested: fly.closeSheet()
        onSent: {
            fly.closeSheet()
            if (ok) fly.closeTapMenu()
            else fly.toast(qsTr("The drone did not take Go here. Try again."), "danger")
        }
    }
    SimpleConfirmSheet {
        visible: fly.sheet === "sethome"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(40)
        icon: "home"
        title: qsTr("Set as home point")
        detail: qsTr("Return home and failsafe returns will fly to this point instead of the take-off point.")
        note: fly.tapCoord.isValid ? fly.tapCoord.latitude.toFixed(6) + ", " + fly.tapCoord.longitude.toFixed(6) : ""
        slideText: qsTr("Slide to set home here")
        onCloseRequested: fly.closeSheet()
        onConfirmed: {
            fly._act(fly._guided.actionSetHome, fly.tapCoord)
            fly.closeSheet()
            fly.closeTapMenu()
            fly.toast(qsTr("Home point sent to the drone"), "ok")
        }
    }
    SimpleCoordSheet {
        visible: fly.sheet === "coords"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(40)
        start: fly.tapCoord
        onCloseRequested: fly.closeSheet()
        onAccepted: {
            fly.closeSheet()
            if (fly._map) fly._map.center = coordinate
            fly.openTapMenu(coordinate)
        }
    }
    // S16 tether power off in flight / S50 no-power action: slide to confirm (classic SAFE-T confirmations)
    SimpleConfirmSheet {
        visible: fly.sheet === "tetheroff"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(40)
        icon: "power"
        title: qsTr("Turn tether power off?")
        detail: fly._guided && fly.sheet === "tetheroff" ? fly._guided.tetherPowerOffMessage() : ""
        note: qsTr("The drone may fall if its battery is too low.")
        slideText: qsTr("Slide to turn power off")
        onCloseRequested: fly.closeSheet()
        onConfirmed: {
            fly._act(fly._guided.actionTetherPowerOff, fly._st.powerOffRequestId)
            fly.sheet = ""
        }
    }
    SimpleConfirmSheet {
        visible: fly.sheet === "tethernp"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(40)
        icon: fly.tetherRtl ? "home" : "land"
        title: fly.tetherRtl ? qsTr("Return to the tether station") : qsTr("Land now")
        detail: fly.tetherRtl ? qsTr("Tether power is lost. The drone flies back to the station on its onboard battery and lands.")
                              : qsTr("Tether power is lost. The drone lands at its current position on its onboard battery.")
        note: qsTr("Keep the area below clear.")
        slideText: fly.tetherRtl ? qsTr("Slide to return") : qsTr("Slide to land")
        onCloseRequested: fly.closeSheet()
        onConfirmed: {
            fly._act(fly.tetherRtl ? fly._guided.actionTetherRTL : fly._guided.actionTetherLand, fly.tetherIncident)
            fly.closeSheet()
        }
    }
    SimpleAltitudeSheet {
        visible: fly.sheet === "altitude"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(40)
        vehicle: fly._veh
        onCloseRequested: fly.closeSheet()
        onConfirmed: { fly._act(fly._guided.actionChangeAlt, null, changeM); fly.closeSheet() }
    }

    //------------------------------------------------------------------ Toast
    Rectangle {
        id: toastBox
        property string text:  ""
        property string level: "info"   // info | ok | danger
        visible: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(24 + 120 + 16 + 104 + 16)
        width: toastText.implicitWidth + SimpleTheme.px(56); height: SimpleTheme.px(72); radius: height / 2
        color: level === "danger" ? SimpleTheme.danger : level === "ok" ? SimpleTheme.brandGreen : SimpleTheme.withAlpha(SimpleTheme.surfaceRaised, 0.97)
        border.width: level === "info" ? SimpleTheme.px(1) : 0; border.color: SimpleTheme.line
        SText { id: toastText; anchors.centerIn: parent; text: toastBox.text; size: 26; medium: true }
        Timer { id: toastTimer; interval: 4000; onTriggered: toastBox.visible = false }
        MouseArea { anchors.fill: parent; onClicked: toastBox.visible = false }
    }
}
