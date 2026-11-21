// SimpleVehicleState (02 Flows › C): state rules with a vehicle double
import QtQuick 2.12
import QtTest 1.12
import QGroundControl 1.0
import "../../res/Simple"

TestCase {
    id: tc
    name: "SimpleVehicleState"

    Component {
        id: factComp
        QtObject { property var rawValue: 0; property string valueString: "" }
    }
    Component {
        id: vehicleComp
        QtObject {
            id: v
            property QtObject vehicleLinkManager: QtObject { property bool communicationLost: false }
            property QtObject parameterManager:   QtObject { property bool parametersReady: true }
            property bool   armed:  false
            property bool   flying: false
            property bool   landing: false
            property string flightMode: "Loiter"
            readonly property string rtlFlightMode:      "RTL"
            readonly property string smartRTLFlightMode: "Smart RTL"
            readonly property string landFlightMode:     "Land"
            readonly property string missionFlightMode:  "Auto"
            readonly property string pauseFlightMode:    "Brake"
            property real   pct: 80
            property QtObject batteries: QtObject {
                property int count: 1
                property QtObject b0: QtObject {
                    property QtObject percentRemaining: QtObject { property var rawValue: v.pct }
                    property QtObject timeRemainingStr: QtObject { property string valueString: "12:00" }
                }
                function get(i) { return b0 }
            }
            property QtObject gps: QtObject {
                property QtObject count: QtObject { property var rawValue: 12 }
                property QtObject lock:  QtObject { property var rawValue: 3 }
                property QtObject hdop:  QtObject { property var rawValue: 0.8 }
            }
            property int    rcRSSI: 0
            property var    remoteIDManager: QtObject { property bool armStatusGood: true; property bool commsGood: true }
            property QtObject homePosition: QtObject { property bool isValid: true }
            property bool   readyToFlyAvailable: false
            property bool   readyToFly: true
            property int    sensorsUnhealthyBits: 0
            signal textMessageReceived(int uasid, int componentid, int severity, string text, string description)
        }
    }
    Component { id: stateComp; SimpleVehicleState { } }

    property var s: null
    property var v: null
    function init() {
        v = createTemporaryObject(vehicleComp, tc)
        s = createTemporaryObject(stateComp, tc, { vehicle: v })
        globals.planMasterControllerFlyView = null
    }

    // ---- basic state table
    function test_no_vehicle() {
        s.vehicle = null
        compare(s.state, "disconnected"); verify(!s.present); verify(!s.critical)
        compare(s.batteryLevel, "off"); compare(s.gpsLevel, "off"); compare(s.linkLevel, "off")
        verify(!s.readyToTakeOff); verify(!s.hasMission)
    }
    function test_ground() { compare(s.state, "ground"); verify(s.readyToTakeOff) }
    function test_flying() { v.armed = true; v.flying = true; compare(s.state, "flying"); verify(!s.readyToTakeOff) }
    function test_mission() { v.armed = true; v.flying = true; v.flightMode = "Auto"; verify(s.missionActive); compare(s.state, "flying") }
    function test_paused() { v.armed = true; v.flying = true; v.flightMode = "Brake"; verify(s.paused); compare(s.state, "flying") }
    function test_returning_rtl_and_smartrtl() {
        v.armed = true; v.flying = true; v.flightMode = "RTL"; compare(s.state, "returning")
        v.flightMode = "Smart RTL"; compare(s.state, "returning")
    }
    function test_landing() {
        v.armed = true; v.flying = true; v.flightMode = "Land"; compare(s.state, "returning"); verify(s.landing)
        v.flightMode = "Loiter"; v.landing = true; verify(s.landing)
    }
    function test_rtl_mode_while_disarmed_is_ground() { v.flightMode = "RTL"; compare(s.state, "ground") }
    function test_lost_overrides_everything() {
        v.armed = true; v.flying = true; v.flightMode = "RTL"
        v.vehicleLinkManager.communicationLost = true
        compare(s.state, "lost"); verify(s.critical); compare(s.linkLevel, "danger")
        verify(!s.connected); verify(!s.paramsReady); verify(!s.readyToTakeOff)
    }
    function test_critical_low_battery_return() {
        v.armed = true; v.flying = true; v.flightMode = "RTL"; v.pct = 20
        verify(s.critical)
        v.pct = 21; verify(!s.critical)
        v.flightMode = "Loiter"; v.pct = 5; verify(!s.critical, "low battery without return is a warning, not a forced switch")
    }
    function test_has_mission() {
        globals.planMasterControllerFlyView = { missionController: { visualItems: { count: 1 } } }
        s.vehicle = null; s.vehicle = v
        verify(!s.hasMission, "only the planned-home item")
        globals.planMasterControllerFlyView = { missionController: { visualItems: { count: 3 } } }
        s.vehicle = null; s.vehicle = v
        verify(s.hasMission)
    }

    // ---- boundaries
    function test_battery_boundaries_data() {
        return [ { tag: "100", p: 100, lvl: "ok" }, { tag: "30.01", p: 30.01, lvl: "ok" },
                 { tag: "30", p: 30, lvl: "warn" }, { tag: "20.01", p: 20.01, lvl: "warn" },
                 { tag: "20", p: 20, lvl: "danger" }, { tag: "0", p: 0, lvl: "danger" },
                 { tag: "NaN", p: NaN, lvl: "off" }, { tag: "150 (bad FC value)", p: 150, lvl: "ok" },
                 { tag: "-1 (unknown from FC)", p: -1, lvl: "danger" } ]
    }
    function test_battery_boundaries(d) { v.pct = d.p; compare(s.batteryLevel, d.lvl) }
    function test_takeoff_battery_gate_data() {
        return [ { tag: "31", p: 31, ok: true }, { tag: "30", p: 30, ok: false }, { tag: "NaN", p: NaN, ok: true } ]
    }
    function test_takeoff_battery_gate(d) { v.pct = d.p; compare(s.readyToTakeOff, d.ok) }
    // top bar "%1 items to fix" counts the red S02 rows (SITL test 2026-11-20: GPS off showed "1 item" with 2 red rows)
    function test_takeoff_blockers_count() {
        compare(s.takeoffBlockers, 0)
        v.gps.lock.rawValue = 0;     compare(s.takeoffBlockers, 1); verify(!s.readyToTakeOff)
        v.sensorsUnhealthyBits = 1;  compare(s.takeoffBlockers, 2)
        v.pct = 20;                  compare(s.takeoffBlockers, 3)
        v.gps.lock.rawValue = 3; v.sensorsUnhealthyBits = 0; v.pct = 80
        compare(s.takeoffBlockers, 0); verify(s.readyToTakeOff)
    }
    function test_battery_unknown_minus_one() {
        // ArduPilot reports battery_remaining = -1 when unknown. QGC turns that into NaN, but if -1 ever reaches here:
        v.pct = -1
        verify(!s.readyToTakeOff, "-1 % blocks take-off (safe side)")
    }
    function test_gps_boundaries_data() {
        return [ { tag: "lock2", lock: 2, n: 12, h: 0.8, q: "No fix", lvl: "danger" },
                 { tag: "lock3 good", lock: 3, n: 8, h: 2.0, q: "Good", lvl: "ok" },
                 { tag: "7 sats", lock: 3, n: 7, h: 0.8, q: "Weak", lvl: "warn" },
                 { tag: "hdop 2.01", lock: 3, n: 12, h: 2.01, q: "Weak", lvl: "warn" },
                 { tag: "rtk", lock: 6, n: 4, h: 9, q: "RTK", lvl: "ok" },
                 { tag: "hdop NaN", lock: 3, n: 12, h: NaN, q: "Good", lvl: "ok" } ]
    }
    function test_gps_boundaries(d) {
        v.gps.lock.rawValue = d.lock; v.gps.count.rawValue = d.n; v.gps.hdop.rawValue = d.h
        compare(s.gpsQuality, d.q); compare(s.gpsLevel, d.lvl)
        compare(s.readyToTakeOff, d.lock >= 3)
    }
    function test_rssi_boundaries_data() {
        return [ { tag: "0 = not reported", r: 0, t: "Connected", lvl: "ok" }, { tag: "1", r: 1, t: "Weak", lvl: "warn" },
                 { tag: "29", r: 29, t: "Weak", lvl: "warn" }, { tag: "30", r: 30, t: "Fair", lvl: "ok" },
                 { tag: "59", r: 59, t: "Fair", lvl: "ok" }, { tag: "60", r: 60, t: "Strong", lvl: "ok" },
                 { tag: "100", r: 100, t: "Strong", lvl: "ok" }, { tag: "255 = invalid", r: 255, t: "Connected", lvl: "ok" },
                 { tag: "-5", r: -5, t: "Connected", lvl: "ok" } ]
    }
    function test_rssi_boundaries(d) { v.rcRSSI = d.r; compare(s.linkText, d.t); compare(s.linkLevel, d.lvl) }
    function test_sensors() {
        v.sensorsUnhealthyBits = 4; verify(!s.sensorsOk); verify(!s.readyToTakeOff)
        v.readyToFlyAvailable = true; v.readyToFly = true; verify(s.sensorsOk, "readyToFly wins when available")
        v.readyToFly = false; verify(!s.sensorsOk)
    }
    function test_remote_id() {
        compare(s.ridLevel, "off", "Remote ID disabled in settings")
        QGroundControl.settingsManager.remoteIDSettings.enable.rawValue = true
        compare(s.ridLevel, "ok"); verify(s.readyToTakeOff, "broadcasting: take-off allowed")
        v.remoteIDManager.commsGood = false; compare(s.ridLevel, "danger"); verify(!s.readyToTakeOff, "Remote ID on but not broadcasting blocks take-off")
        v.remoteIDManager.commsGood = true
        QGroundControl.settingsManager.remoteIDSettings.enable.rawValue = false
    }
    // ---- S11/S16 tether profile: ground power gates take-off; chip text and level
    Component {
        id: stationComp
        QtObject {
            property bool enabled: true; property bool connected: true; property bool hasMonitoring: true
            property bool powerOn: true; property bool noPower: false; property bool linkLost: false; property real powerWatts: 900
        }
    }
    function test_tether_profile() {
        var st = createTemporaryObject(stationComp, tc)
        QGroundControl.corePlugin.elistairStationManager = st
        verify(!s.tethered, "profile not Tether: classic rules")
        QGroundControl.corePlugin.settings.simpleProductProfile.rawValue = 2
        verify(s.tethered); verify(s.tetherPowerOk); compare(s.tetherText, "Power OK"); compare(s.tetherLevel, "ok")
        verify(s.readyToTakeOff, "power on: take-off allowed")
        st.powerOn = false
        compare(s.tetherText, "Power off"); compare(s.tetherLevel, "warn"); verify(!s.readyToTakeOff, "power off blocks take-off (S16)")
        st.powerOn = true; st.noPower = true
        compare(s.tetherText, "No power"); compare(s.tetherLevel, "danger"); verify(!s.readyToTakeOff)
        st.noPower = false; st.linkLost = true; st.connected = false
        compare(s.tetherText, "Station lost"); verify(!s.readyToTakeOff)
        st.linkLost = false; st.connected = true; st.enabled = false
        verify(!s.tethered, "station switched off: classic rules"); verify(s.readyToTakeOff)
        QGroundControl.corePlugin.settings.simpleProductProfile.rawValue = 0
        QGroundControl.corePlugin.elistairStationManager = null
    }
    function test_no_battery() {
        v.batteries.count = 0
        compare(s.batteryLevel, "off"); compare(s.batteryTime, ""); verify(s.readyToTakeOff)
    }

    // ---- random: invariants over random vehicle states
    // ---- reason for return / landing / mission stop (payload test 2026-11-21 #32/#33, code review 2026-11-21)
    function test_cause_plain_words_and_rank() {
        compare(s.recentReason, "")
        v.textMessageReceived(1, 1, 6, "Mission: 3 WP", "")               // info: ignored
        v.textMessageReceived(1, 1, 4, "PreArm: GPS 1: Bad fix", "")      // pre-arm: ignored
        compare(s.recentReason, "")
        v.textMessageReceived(1, 1, 2, "EKF Failsafe", "")
        compare(s.recentCause, "GPS or position lost")
        v.textMessageReceived(1, 1, 4, "Something unrelated", "")         // unknown: kept at the lowest rank
        compare(s.recentCause, "GPS or position lost")
        v.textMessageReceived(1, 1, 4, "Battery 1 is low", "")            // lower rank: kept, not shown
        compare(s.recentCause, "GPS or position lost")
        v.textMessageReceived(1, 1, 2, "Crash: Disarming", "")            // higher rank: shown
        compare(s.recentCause, "Crash detected")
        verify(s.recentReason.indexOf("Crash detected") === 0)
    }
    function test_cause_only_from_the_autopilot() {
        v.textMessageReceived(1, 25, 4, "GPS not fixed", "")              // YellowScan LiDAR (component 25)
        v.textMessageReceived(1, 236, 2, "Battery low", "")               // Remote ID module
        compare(s.recentCause, "")
        v.textMessageReceived(1, 1, 4, "Battery 1 is low", "")
        compare(s.recentCause, "Battery low")
    }
    function test_cause_benign_and_cleared() {
        var benign = ["EKF primary changed:1", "SmartRTL deactivated", "Battery 1 OK", "EKF3 IMU0 is using GPS"]
        for (var i = 0; i < benign.length; i++) v.textMessageReceived(1, 1, 4, benign[i], "")
        compare(s.recentCause, "")
        v.textMessageReceived(1, 1, 4, "Bad compass health", "")          // "OK" only as a word
        compare(s.recentCause, "GPS or position lost")
        v.textMessageReceived(1, 1, 4, "GPS Glitch", "")
        v.textMessageReceived(1, 1, 4, "Battery 1 is low", "")            // kept below the GPS cause
        compare(s.recentCause, "GPS or position lost")
        v.textMessageReceived(1, 1, 4, "GPS Glitch cleared", "")          // GPS reported gone: the battery shows
        compare(s.recentCause, "Battery low")
        compare(s.recentWarning, "Battery 1 is low")
    }
    function test_cause_unknown_warning_keeps_text() {
        v.textMessageReceived(1, 1, 2, "Dead Reckoning failsafe", "")
        compare(s.recentCause, "Warning — see the messages (bell)")
        compare(s.recentWarning, "Dead Reckoning failsafe")
        v.textMessageReceived(1, 1, 2, "Lost manual control", "")
        compare(s.recentCause, "Controller signal lost")
    }
    function test_cause_expiry_hold_and_arm() {
        v.armed = true; v.flying = true
        v.textMessageReceived(1, 1, 4, "Battery 1 is low", "")
        verify(s._warnTimer.running)
        v.flightMode = "RTL"                                              // returning: never expires
        verify(s._holdCauses)
        s._causes[7].t = Date.now() - 600000
        s._expireCauses()
        compare(s.recentCause, "Battery low")
        verify(Date.now() - s._causes[7].t < 5000)                        // refreshed while held
        v.flying = false; v.armed = false; v.flightMode = "Loiter"        // landed: 60 s from the last hold
        verify(!s._holdCauses)
        compare(s.recentCause, "Battery low")                             // the S92 card still reads it at disarm
        s._causes[7].t = Date.now() - 61000
        s._expireCauses()
        compare(s.recentCause, ""); verify(!s._warnTimer.running)
        v.textMessageReceived(1, 1, 2, "EKF Failsafe", "")
        v.armed = true                                                    // next flight starts clean
        compare(s.recentCause, ""); compare(s.recentReason, "")
    }
    function test_random_states() {
        var modes = ["Loiter", "RTL", "Smart RTL", "Land", "Auto", "Brake", "Stabilize", ""]
        var allowed = ["disconnected", "lost", "returning", "flying", "ground"]
        for (var i = 0; i < 5000; i++) {
            v.vehicleLinkManager.communicationLost = Math.random() < 0.15
            v.armed = Math.random() < 0.6
            v.flying = v.armed && Math.random() < 0.7
            v.landing = Math.random() < 0.1
            v.flightMode = modes[Math.floor(Math.random() * modes.length)]
            v.pct = Math.random() < 0.05 ? NaN : Math.random() * 110 - 5
            v.gps.lock.rawValue = Math.floor(Math.random() * 7)
            v.gps.count.rawValue = Math.floor(Math.random() * 20)
            v.gps.hdop.rawValue = Math.random() * 5
            v.rcRSSI = Math.floor(Math.random() * 300) - 20
            verify(allowed.indexOf(s.state) >= 0, "state " + s.state)
            if (s.critical) verify(s.lost || s.returning, "critical only when lost or returning")
            if (s.readyToTakeOff) verify(s.connected && !s.armed && s.gpsLock >= 3)
            if (s.state === "lost") compare(s.linkLevel, "danger")
            if (s.missionActive || s.paused) verify(s.flying)
            verify(["off", "ok", "warn", "danger"].indexOf(s.batteryLevel) >= 0)
            verify(["Connected", "Strong", "Fair", "Weak", "Lost"].indexOf(s.linkText) >= 0, s.linkText)
        }
    }
    // ---- stress: vehicle object swapped many times (connect / disconnect)
    function test_stress_reconnect() {
        for (var i = 0; i < 2000; i++) {
            s.vehicle = (i % 2) ? null : v
            compare(s.state, (i % 2) ? "disconnected" : "ground")
        }
    }
}
