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
    }

    //------------------------------------------------------------------ Telemetry bar (x = 24, bottom 24)
    STelemetryBar {
        x: SimpleTheme.px(SimpleTheme.telemetryX)
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(24)
        vehicle: fly._veh
        visible: vs.present
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
        SBanner {
            visible: vs.state === "returning"
            level: "warn"; icon: vs.landing ? "land" : "home"
            title: vs.landing ? qsTr("Landing") : (!isNaN(vs.batteryPct) && vs.batteryPct <= 20 ? qsTr("Battery low — returning home") : qsTr("Returning home"))
            detail: qsTr("Pause stops the drone in place. Land lands here.")
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
        note:   qsTr("You can stop it any time with Pause. Return-home altitude: Settings › Safety")
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
