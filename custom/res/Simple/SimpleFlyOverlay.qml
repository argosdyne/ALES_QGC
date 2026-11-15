/****************************************************************************
 * AQGC Simple UI — fly screen overlay (Figma S01–S05, S10 basic, S18 rail, S25–S29, S33, S34, S37)
 * Sits on top of the classic FlyView (map, video PiP); the classic widgets are hidden in Simple mode.
 ****************************************************************************/
import QtQuick 2.12
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
    property string sheet:      ""
    property string chipKind:   ""

    function closeSheet() { sheet = "" }
    function openSheet(name) { sheet = name }

    // Layer rule 1: a critical alert closes confirm sheets
    Connections {
        target: vs
        function onCriticalChanged() { if (vs.critical && (fly.sheet === "takeoff" || fly.sheet === "mission" || fly.sheet === "rtl" || fly.sheet === "land")) fly.closeSheet() }
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
            enabled_: vs.state !== "lost" && _veh && _veh.pauseVehicleSupported
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
    }

    //------------------------------------------------------------------ Telemetry bar (x = 24, bottom 24)
    STelemetryBar {
        x: SimpleTheme.px(SimpleTheme.telemetryX)
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(24)
        vehicle: fly._veh
        visible: vs.present
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
        anchors.fill: parent
        visible: !fly.videoMain && typeof flightView !== "undefined"
        map: typeof flightView !== "undefined" ? flightView.simpleMap : null
        vehicle: fly._veh
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
            detail: vs.landing ? qsTr("Pause stops the drone in place.") : qsTr("Pause stops the drone in place. Land lands here.")
        }
        SBanner {
            visible: vs.paused
            level: "info"; icon: "pause"
            title: qsTr("Paused — holding position")
            detail: vs.hasMission ? qsTr("Mission paused. Resume continues from the current waypoint.") : qsTr("Use Return home or Land, or change the flight mode.")
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
}
