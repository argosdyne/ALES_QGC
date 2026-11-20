// S10 Payloads panel: which cards appear, LiDAR refusal reason (S51), hold-to-run button
import QtQuick 2.12
import QtTest 1.12
import QGroundControl 1.0
import "../../res/Simple"

Item {
    id: root
    width: 1920; height: 1080

    QtObject {
        id: veh
        property bool px4Firmware: false
        property bool hasGripper: false
        property QtObject audioControl: QtObject {
            property int played: -1
            property int stops: 0
            function _playAudio(i) { played = i }
            function _stopAudio() { stops++ }
        }
        property int gripper: -1
        function sendGripperAction(a) { gripper = a }
    }
    QtObject { id: vsd; property var vehicle: veh; property bool flying: true; property bool armed: true; property bool paramsReady: true }
    QtObject {
        id: station
        property bool enabled: false
        property bool noPower: false; property bool linkLost: false; property bool connected: true; property bool hasMonitoring: true
        property bool noReply: false; property bool powerOn: true; property bool powerOffPending: false
        property bool frameVersionDetected: true; property bool torqueRemote: false; property bool torqueSetpointAvailable: false
        property int torquePercent: 0; property real appliedTorquePercent: 0
        property real powerWatts: 1200; property real cableLength: 40.5; property real spoolTemperature: 31
        property bool alarmActive: false; property string alarmSummary: ""
        property string activeFrameVersion: "Extended V1"
        property int lastTorque: -1
        signal controlChanged()
        signal telemetryChanged()
        function setTorquePercent(v) { lastTorque = v }
        function setTorqueRemote(on) { torqueRemote = on; controlChanged() }
        function setPowerOn(on) {}
    }
    QtObject {
        id: lidar
        property int lidarState: 4
        property real recordingSeconds: 0
        property bool insNotLocked: true
        property var preChecks: [ { name: "INS/GNSS", state: 1, detail: "not locked" }, { name: "Scanner", state: 0, detail: "" } ]
        property int starts: 0
        function startAcquisition() { starts++ }
        function stopAcquisition() {}
    }
    QtObject {
        id: mission
        property int slStatus: 0
        property int drops: 0
        function getSearchlight() {}
        function setSearchlight(v) { slStatus = v }
        function deployLifeVest() { drops++ }
    }
    QtObject { id: pmc; property var missionController: mission }

TestCase {
    id: tc
    name: "SimplePayloads"
    when: windowShown

    Component { id: panelComp; SimplePayloadPanel { visible: false } }
    Component { id: holdComp;  SHoldButton { width: 300; holdMs: 300; text: "Hold" } }
    SignalSpy { id: spy }

    function init() {
        globals.planMasterControllerFlyView = pmc
        QGroundControl.corePlugin.elistairStationManager = station
        QGroundControl.corePlugin.ysManager = lidar
        station.enabled = false
        veh.hasGripper = false; veh.px4Firmware = false
        QGroundControl.settingsManager.flyViewSettings.enableAudioController.rawValue = false
        QGroundControl.corePlugin.settings.lifeJacketEnable.rawValue = false
        QGroundControl.corePlugin.settings.ysEnable.rawValue = false
    }
    function cleanup() {
        globals.planMasterControllerFlyView = undefined
        QGroundControl.corePlugin.elistairStationManager = null
        QGroundControl.corePlugin.ysManager = null
        spy.clear()
    }

    function test_no_payloads() {
        var p = createTemporaryObject(panelComp, root, { vs: vsd })
        compare(p.count, 0)
        compare(p.kinds.length, 0)
    }
    function test_each_switch_adds_its_card() {
        var p = createTemporaryObject(panelComp, root, { vs: vsd })
        station.enabled = true;                                                     compare(p.kinds, ["tether"])
        QGroundControl.corePlugin.settings.ysEnable.rawValue = true;               compare(p.kinds, ["tether", "lidar"])
        QGroundControl.settingsManager.flyViewSettings.enableAudioController.rawValue = true
        compare(p.kinds, ["tether", "lidar", "megaphone"])
        QGroundControl.corePlugin.settings.lifeJacketEnable.rawValue = true
        compare(p.kinds, ["tether", "lidar", "megaphone", "searchlight", "lifejacket"])
        veh.hasGripper = true
        compare(p.kinds, ["tether", "lidar", "megaphone", "searchlight", "winch", "lifejacket"])
        compare(p.count, 6)
    }
    function test_birdcom_not_on_px4() {
        QGroundControl.corePlugin.settings.lifeJacketEnable.rawValue = true
        veh.px4Firmware = true
        var p = createTemporaryObject(panelComp, root, { vs: vsd })
        compare(p.kinds.indexOf("searchlight"), -1)
        compare(p.kinds.indexOf("lifejacket"), -1)
    }
    function test_no_vehicle_no_vehicle_cards() {
        QGroundControl.corePlugin.settings.lifeJacketEnable.rawValue = true
        QGroundControl.settingsManager.flyViewSettings.enableAudioController.rawValue = true
        veh.hasGripper = true
        var p = createTemporaryObject(panelComp, root, { vs: null })
        compare(p.count, 0)
    }
    function findTether(item) {
        if (item && item.selectTorqueLevel !== undefined) return item
        var kids = item ? item.children : []
        for (var i = 0; i < kids.length; i++) { var r = findTether(kids[i]); if (r) return r }
        return null
    }
    function resetStation() {
        station.torqueRemote = false; station.torqueSetpointAvailable = false; station.torquePercent = 0
        station.appliedTorquePercent = 0; station.activeFrameVersion = "Extended V1"; station.lastTorque = -1
        station.hasMonitoring = true; station.connected = true; station.frameVersionDetected = true
    }
    // #317: torque in 0–10 steps; the shown step is a reference (set value, else applied value on Extended V1)
    function test_tether_torque_steps_follow_set_value() {
        resetStation(); station.enabled = true
        station.torqueRemote = true; station.torqueSetpointAvailable = true; station.torquePercent = 30; station.appliedTorquePercent = 30
        var p = createTemporaryObject(panelComp, root, { vs: vsd })
        var t = findTether(p); verify(t !== null)
        compare(t.torqueLevelKnown, true); compare(t.torqueLevel, 3); compare(t.torqueReferenceIsApplied, true)
        t.selectTorqueLevel(4)
        compare(station.lastTorque, 40); compare(t.torqueLevel, 4); compare(t.torqueReferenceIsApplied, false)
        t.selectTorqueLevel(12)                      // clamped to 10 steps
        compare(station.lastTorque, 100)
        resetStation(); station.enabled = false
    }
    function test_tether_torque_off_shows_applied_value() {
        resetStation(); station.enabled = true
        var p = createTemporaryObject(panelComp, root, { vs: vsd })
        var t = findTether(p); verify(t !== null)
        station.appliedTorquePercent = 50; station.telemetryChanged()
        compare(t.torqueLevel, 5); compare(t.torqueReferenceIsApplied, true)
        t.selectTorqueLevel(6)                       // automatic torque off: no command
        compare(station.lastTorque, -1)
        resetStation(); station.enabled = false
    }
    function test_tether_torque_unknown_and_locked() {
        resetStation(); station.enabled = true
        station.activeFrameVersion = "Standard"; station.torqueRemote = true    // no setpoint, no applied value
        var p = createTemporaryObject(panelComp, root, { vs: vsd })
        var t = findTether(p); verify(t !== null)
        compare(t.torqueLevelKnown, false)
        station.hasMonitoring = false                // link not ready: locked, no command
        compare(t.ctrl, false)
        t.selectTorqueLevel(1); compare(station.lastTorque, -1)
        compare(t.torqueLevelKnown, false)
        resetStation(); station.enabled = false
    }
    function test_tether_status() {
        station.enabled = true
        var p = createTemporaryObject(panelComp, root, { vs: vsd })
        compare(p.tetherStatus().l, "ok")
        station.powerOn = false;  compare(p.tetherStatus().l, "warn")
        station.linkLost = true;  compare(p.tetherStatus().l, "danger")
        station.noPower = true;   compare(p.tetherStatus().t, "No power")
        station.noPower = false; station.linkLost = false; station.powerOn = true
    }
    function test_lidar_refusal_reason_names_failing_check() {
        QGroundControl.corePlugin.settings.ysEnable.rawValue = true
        var p = createTemporaryObject(panelComp, root, { vs: vsd })
        compare(p.lidarNotReadyReason(), "INS/GNSS — not locked")
        lidar.preChecks = []
        compare(p.lidarNotReadyReason(), "INS not locked — fly the init path first")
        lidar.preChecks = [ { name: "INS/GNSS", state: 1, detail: "not locked" }, { name: "Scanner", state: 0, detail: "" } ]
    }
    function test_lidar_status_recording_time() {
        QGroundControl.corePlugin.settings.ysEnable.rawValue = true
        var p = createTemporaryObject(panelComp, root, { vs: vsd })
        lidar.lidarState = 7; lidar.recordingSeconds = 125
        compare(p.lidarStatus().t, "Recording 02:05")
        lidar.lidarState = 4
    }

    // ---- hold-to-run
    function test_hold_fires_after_time() {
        var b = createTemporaryObject(holdComp, root)
        spy.target = b; spy.signalName = "activated"
        mousePress(b, 10, 10)
        wait(150)
        compare(spy.count, 0, "not yet")
        tryCompare(spy, "count", 1, 1000)
        mouseRelease(b, 10, 10)
        compare(b.progress, 0)
    }
    function test_hold_released_early_does_nothing() {
        var b = createTemporaryObject(holdComp, root)
        spy.target = b; spy.signalName = "activated"
        mousePress(b, 10, 10); wait(120); mouseRelease(b, 10, 10)
        wait(400)
        compare(spy.count, 0)
        compare(b.progress, 0)
    }
    function test_hold_disabled() {
        var b = createTemporaryObject(holdComp, root, { enabled_: false })
        spy.target = b; spy.signalName = "activated"
        mousePress(b, 10, 10); wait(500); mouseRelease(b, 10, 10)
        compare(spy.count, 0)
    }
}
}
