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
            signal geoFenceAlertTierChanged(int tier)
            signal fcFenceBreachCountChanged()
            property int    defaultComponentId: 1
            property bool   fcFenceBreach: true
            function fenceStatusBreached() { return fcFenceBreach }
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
    // a failed compare must not leave Advanced mode on for the next tests (recentReason adds the FC text there)
    function cleanup() { QGroundControl.corePlugin.advancedMode = false }

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
        v.textMessageReceived(1, 1, 4, "Bad compass health", "")          // "OK" only as a word; compass is its own cause
        compare(s.recentCause, "Compass problem")
        s._clearCause()
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
        s._causes["battery"].t = Date.now() - 600000
        s._expireCauses()
        compare(s.recentCause, "Battery low")
        verify(Date.now() - s._causes["battery"].h < 5000)                // hold time refreshed, arrival time kept
        verify(Date.now() - s._causes["battery"].t > 500000)
        v.flying = false; v.armed = false; v.flightMode = "Loiter"        // landed: 60 s from the last hold
        verify(!s._holdCauses)
        compare(s.recentCause, "Battery low")                             // the S92 card still reads it at disarm
        s._causes["battery"].t = Date.now() - 61000; s._causes["battery"].h = Date.now() - 61000
        s._expireCauses()
        compare(s.recentCause, ""); verify(!s._warnTimer.running)
        v.textMessageReceived(1, 1, 2, "EKF Failsafe", "")
        v.armed = true                                                    // next flight starts clean
        compare(s.recentCause, ""); compare(s.recentReason, "")
    }
    // code review round 3: kinds of the same rank are kept apart; the app's own geofence / C2 texts are skipped;
    // a "cleared" line counts at any severity; another drone starts clean
    function test_cause_kinds_app_messages_and_vehicle_change() {
        v.textMessageReceived(1, 1, 2, "EKF Failsafe", "")
        v.textMessageReceived(1, 1, 2, "GPS Glitch", "")
        v.textMessageReceived(1, 1, 6, "GPS Glitch cleared", "")          // info severity still clears the GPS kind
        compare(s.recentCause, "GPS or position lost")                     // the EKF failsafe stays
        compare(s.recentWarning, "EKF Failsafe")
        s._clearCause()
        v.geoFenceAlertTierChanged(1)                                     // app geofence margin alert (Vehicle.cc)
        v.textMessageReceived(1, 1, 4, "Approaching geofence margin", "")
        compare(s.recentCause, "")
        v.geoFenceAlertTierChanged(3)                                     // breach (from FENCE_STATUS): the fence cause
        v.textMessageReceived(1, 1, 3, "지오펜스 위반: boundary", "")       // translated text, no regex needed
        compare(s.recentCause, "Geofence reached")
        v.geoFenceAlertTierChanged(0)                                     // "Exited breach area": not a cause, keeps it
        v.textMessageReceived(1, 1, 6, "Exited breach area", "")
        compare(s.recentCause, "Geofence reached")
        s._clearCause()
        v.textMessageReceived(1, 1, 4, qsTranslate("Vehicle", "C2 link quality degraded"), "")
        compare(s.recentCause, "")
        v.textMessageReceived(1, 1, 4, "Fence breach", "")                // the FC's own fence line counts
        compare(s.recentCause, "Geofence reached")
        s.vehicle = createTemporaryObject(vehicleComp, tc)                 // another active drone
        compare(s.recentCause, "")
    }
    // code review round 4: real ArduCopter strings
    function test_cause_real_arducopter_strings() {
        v.textMessageReceived(1, 1, 2, "GPS Glitch or Compass error", "")
        compare(s.recentCause, "GPS or position lost")
        v.textMessageReceived(1, 1, 2, "Glitch cleared", "")
        compare(s.recentCause, "")
        v.textMessageReceived(1, 1, 2, "EKF Failsafe: changed to Land Mode", "")
        compare(s.recentCause, "GPS or position lost")
        compare(s.recentWarning, "EKF Failsafe: changed to Land Mode")
        v.textMessageReceived(1, 1, 4, "EKF primary changed:1", "")
        compare(s.recentWarning, "EKF Failsafe: changed to Land Mode")
    }
    // round 4: equal-rank causes keep their arrival order across a hold
    function test_cause_tie_after_hold() {
        v.armed = true; v.flying = true
        v.textMessageReceived(1, 1, 2, "EKF variance", "")
        s._causes["ekf"].t = Date.now() - 5000
        v.textMessageReceived(1, 1, 2, "GPS Glitch or Compass error", "")
        v.flightMode = "RTL"
        s._expireCauses()
        v.flying = false; v.armed = false; v.flightMode = "Loiter"
        s._refreshCause()
        compare(s.recentWarning, "GPS Glitch or Compass error")        // the newest of rank 8
    }
    // round 6: the vehicle's own autopilot component id; "clear" only as a whole word
    function test_cause_component_id_and_clear_word() {
        v.defaultComponentId = 2
        v.textMessageReceived(1, 1, 4, "Battery 1 is low", "")
        compare(s.recentCause, "")
        v.textMessageReceived(1, 2, 4, "Battery 1 is low", "")
        compare(s.recentCause, "Battery low")
        v.textMessageReceived(1, 2, 4, "Terrain clearance low", "")       // "clearance" is not "cleared"
        compare(s._causes["terrain"] !== undefined, true)
        compare(s._causes["battery"] !== undefined, true)
    }
    // round 7: "RC" only as a word; "OK" only in "Battery n OK"; an unrecognised warning is not held
    function test_cause_round7() {
        v.textMessageReceived(1, 1, 4, "Arc fault on ESC", "")
        compare(s.recentCause, "Warning — see the messages (bell)")
        v.textMessageReceived(1, 1, 4, "RC3 failsafe", "")
        compare(s.recentCause, "Controller signal lost")
        s._clearCause()
        v.textMessageReceived(1, 1, 4, "Battery 1 OK", "")
        compare(s.recentCause, "")
        v.textMessageReceived(1, 1, 4, "GPS 1: ok, glitch", "")
        compare(s.recentCause, "GPS or position lost")
        s._clearCause()
        v.armed = true; v.flying = true
        v.textMessageReceived(1, 1, 4, "Something unrelated", "")
        s._causes["other"].t = Date.now() - 61000
        v.flightMode = "RTL"                                              // held: but not the "other" warning
        compare(s.recentCause, "")
    }
    // round 8: only causes from shortly before the return are held; FC text unescaped; "position" tighter
    function test_cause_round8() {
        v.armed = true; v.flying = true
        v.textMessageReceived(1, 1, 4, "Vibration compensation ON", "")
        s._causes["vibration"].t = Date.now() - 40000                     // 40 s before the return
        v.flightMode = "RTL"
        compare(s.recentCause, "")                                        // dropped when the return began
        v.textMessageReceived(1, 1, 4, "Batt voltage &lt; 10.5V", "")
        compare(s.recentWarning, "Batt voltage < 10.5V")
        s._clearCause()
        v.textMessageReceived(1, 1, 4, "Mode change to Loiter failed: requires position", "")
        compare(s.recentCause, "Warning — see the messages (bell)")
    }
    // round 9: a cause from before the hold window cannot outrank the real one during the return
    function test_cause_round9() {
        v.armed = true; v.flying = true
        v.textMessageReceived(1, 1, 4, "Bad compass health", "")
        s._causes["compass"].t = Date.now() - 30000
        v.textMessageReceived(1, 1, 2, "Battery 1 is low", "")
        v.flightMode = "RTL"
        compare(s.recentCause, "Battery low")
    }
    // round 10: an unrecognised failsafe at the return is held; a cause held in an earlier return is not re-held
    function test_cause_round10() {
        v.armed = true; v.flying = true
        v.textMessageReceived(1, 1, 2, "Dead Reckoning failsafe", "")
        v.flightMode = "RTL"
        compare(s.recentCause, "Warning — see the messages (bell)")
        compare(s.recentWarning, "Dead Reckoning failsafe")
        v.flightMode = "Loiter"                                           // pilot takes over, flies on
        s._causes["other"].t = Date.now() - 30000; s._causes["other"].h = Date.now() - 30000
        v.flightMode = "RTL"                                              // manual return 30 s later
        compare(s.recentCause, "")
    }
    // round 11: a paused return is the same return; an app-only geofence breach is not a cause
    function test_cause_round11() {
        v.armed = true; v.flying = true
        v.textMessageReceived(1, 1, 2, "Battery 1 is low", "")
        v.flightMode = "RTL"
        s._causes["battery"].t = Date.now() - 60000
        v.flightMode = "Brake"                                            // pilot pauses the return
        v.flightMode = "RTL"                                              // and returns again
        compare(s.recentCause, "Battery low")
        v.flightMode = "Loiter"
        s._clearCause()
        v.fcFenceBreach = false
        v.geoFenceAlertTierChanged(3)
        v.textMessageReceived(1, 1, 3, "GeoFence breach: boundary", "")
        compare(s.recentCause, "")
    }
    // ---- Tuleap bug #28594: return reason in edge cases (code review round 12)
    // 1. RTL -> Brake keeps the return latch, so a long pause and a new return keep the cause
    function test_bug28594_pause_keeps_latch() {
        v.armed = true; v.flying = true
        v.textMessageReceived(1, 1, 4, "Battery 1 is low", "")
        v.flightMode = "RTL"
        verify(s._returnLatch); verify(s._holdCauses)
        v.flightMode = "Brake"
        verify(s._returnLatch, "Pause during a return keeps the latch")
        verify(s._holdCauses, "the hold goes on while paused")
        s._holdSince = Date.now() - 20000                                 // paused for 20 s
        s._causes["battery"].h = Date.now() - 20000
        s._expireCauses()                                                 // timer tick while paused: still held
        compare(s.recentCause, "Battery low")
        v.flightMode = "RTL"
        compare(s.recentCause, "Battery low")
        v.flightMode = "Loiter"                                           // the pilot flies on: latch and hold end
        verify(!s._returnLatch); verify(!s._holdCauses)
        v.flightMode = "Brake"
        verify(!s._holdCauses, "a pause outside a return is not a hold")
    }
    // 2. a "... cleared" line does not remove the cause that started the return; later causes still clear
    function test_bug28594_cleared_keeps_start_cause() {
        v.armed = true; v.flying = true
        v.textMessageReceived(1, 1, 2, "Radio Failsafe", "")
        v.flightMode = "RTL"
        v.textMessageReceived(1, 1, 6, "Radio Failsafe Cleared", "")
        compare(s.recentCause, "Controller signal lost")
        s._holdSince = Date.now() - 10000                                 // 10 s into the return
        v.textMessageReceived(1, 1, 4, "GPS Glitch", "")                  // not a start cause
        verify(!s._isStartCause(s._causes["gps"]))
        compare(s.recentCause, "Controller signal lost")
        v.textMessageReceived(1, 1, 6, "GPS Glitch cleared", "")
        verify(s._causes["gps"] === undefined, "a later cause is still cleared")
        v.flying = false; v.armed = false; v.flightMode = "Loiter"         // landed: S92 reads the start cause
        compare(s.recentCause, "Controller signal lost")
    }
    // 3. an event-only FC fence breach (breach_count up, breach_status 0) is the fence cause
    function test_bug28594_fence_event_only() {
        v.fcFenceBreach = false
        v.fcFenceBreachCountChanged()
        compare(s.recentCause, "Geofence reached")
        compare(s.recentWarning, "")
        QGroundControl.corePlugin.advancedMode = true
        compare(s.recentReason, "Geofence reached", "no empty brackets in Advanced mode")
        v.geoFenceAlertTierChanged(3)                                     // the app's breach text follows
        v.textMessageReceived(1, 1, 3, "GeoFence breach: boundary", "")
        compare(s.recentWarning, "GeoFence breach: boundary")
        compare(s.recentReason, "Geofence reached (GeoFence breach: boundary)")
        QGroundControl.corePlugin.advancedMode = false
        s._clearCause()
        s._fcFenceBreachAt = Date.now() - 10000                           // an old event does not make an app breach the FC's
        v.geoFenceAlertTierChanged(3)
        v.textMessageReceived(1, 1, 3, "GeoFence breach: boundary", "")
        compare(s.recentCause, "")
    }
    // 3b. a fence event during a return fills in the text of the start cause, nothing else
    function test_bug28594_fence_event_in_return() {
        v.armed = true; v.flying = true; v.fcFenceBreach = false
        v.fcFenceBreachCountChanged()
        v.flightMode = "RTL"
        verify(s._isStartCause(s._causes["fence"]))
        v.geoFenceAlertTierChanged(3)
        v.textMessageReceived(1, 1, 3, "GeoFence breach: boundary", "")
        compare(s.recentWarning, "GeoFence breach: boundary")
    }
    // 4. a higher warning during the return does not replace the starting cause (also after disarm)
    function test_bug28594_higher_rank_does_not_replace() {
        v.armed = true; v.flying = true
        v.textMessageReceived(1, 1, 4, "Battery 1 is low", "")
        v.flightMode = "RTL"
        s._holdSince = Date.now() - 5000; s._causes["battery"].t = Date.now() - 6000
        v.textMessageReceived(1, 1, 2, "EKF Failsafe", "")                // 5 s into the return
        compare(s.recentCause, "Battery low")
        v.textMessageReceived(1, 1, 4, "Battery 1 is low", "")            // a repeat keeps the start time
        verify(s._causes["battery"].t < Date.now() - 5000)
        v.flightMode = "Land"
        compare(s.recentCause, "Battery low")
        v.flying = false; v.armed = false; v.flightMode = "Loiter"
        compare(s.recentCause, "Battery low", "the S92 card shows the cause that started the return")
        v.armed = true
        compare(s.recentCause, "")
    }
    // 4b. no cause at the start: a warning during the return is shown; when the pilot flies on, rank rules again
    function test_bug28594_no_start_cause_and_fly_on() {
        v.armed = true; v.flying = true
        v.flightMode = "RTL"                                              // manual return
        s._holdSince = Date.now() - 5000
        v.textMessageReceived(1, 1, 4, "Battery 1 is low", "")
        compare(s.recentCause, "Battery low")
        s._clearCause()
        v.flightMode = "Loiter"
        s._holdEndedAt = Date.now() - 6000
        v.textMessageReceived(1, 1, 4, "Battery 1 is low", "")
        v.flightMode = "RTL"
        verify(s._isStartCause(s._causes["battery"]))
        v.flightMode = "Loiter"                                           // flies on: the mark stops counting after 5 s
        s._holdEndedAt = Date.now() - 6000
        verify(!s._isStartCause(s._causes["battery"]))
        v.textMessageReceived(1, 1, 2, "EKF Failsafe", "")
        compare(s.recentCause, "GPS or position lost")
    }
    // 5. another active drone resets latch, hold times and the app alert tier
    function test_bug28594_vehicle_change_resets() {
        v.armed = true; v.flying = true; v.flightMode = "RTL"
        v.geoFenceAlertTierChanged(3)
        verify(s._returnLatch); verify(s._holdSince > 0); compare(s._appTier, 3)
        var v2 = createTemporaryObject(vehicleComp, tc)
        s.vehicle = v2
        verify(!s._returnLatch); compare(s._holdSince, 0); compare(s._appTier, -1)
        compare(s.recentCause, "")
        v2.textMessageReceived(1, 1, 4, "Battery 1 is low", "")          // a stale app tier would skip this FC line
        compare(s.recentCause, "Battery low")
        s._clearCause()
        v2.armed = true; v2.flying = true; v2.flightMode = "Brake"
        verify(!s._holdCauses)
        v2.flightMode = "RTL"                                             // the new drone's return (within 5 s) gets its own start
        verify(s._holdSince > 0)
    }
    // code review (important): a new return 3 s after the pilot ended a GPS return is named by its own cause
    function test_new_return_after_takeover() {
        v.armed = true; v.flying = true
        v.textMessageReceived(1, 1, 2, "GPS Glitch", "")
        v.flightMode = "RTL"                                              // GPS failsafe return
        compare(s.recentCause, "GPS or position lost")
        verify(s._isStartCause(s._causes["gps"]))
        s._holdSince = Date.now() - 60000; s._causes["gps"].t = Date.now() - 61000
        v.flightMode = "Loiter"                                           // pilot takes over
        s._holdEndedAt = Date.now() - 3000                                // ... 3 s ago
        v.textMessageReceived(1, 1, 4, "Battery 1 is low", "")
        v.flightMode = "RTL"                                              // battery failsafe return
        compare(s.recentCause, "Battery low")
        verify(!s._isStartCause(s._causes["gps"]))
        v.flying = false; v.armed = false; v.flightMode = "Loiter"         // S92 card at disarm
        compare(s.recentCause, "Battery low")
    }
    // a hold that comes back within 1 s (mode-switch binding order) is the same return
    function test_hold_blip_is_same_return() {
        v.armed = true; v.flying = true
        v.textMessageReceived(1, 1, 4, "Battery 1 is low", "")
        v.flightMode = "RTL"
        var since = s._holdSince
        s._holdSince = since - 30000; s._causes["battery"].t = since - 31000; since = s._holdSince
        v.flightMode = "Loiter"; v.flightMode = "RTL"                     // ends and comes back at once
        compare(s._holdSince, since)
        verify(s._isStartCause(s._causes["battery"]))
        v.textMessageReceived(1, 1, 2, "EKF Failsafe", "")
        compare(s.recentCause, "Battery low")
    }
    // code review nit: switching to another drone that is already returning starts its own hold window
    function test_vehicle_switch_while_returning() {
        v.armed = true; v.flying = true; v.flightMode = "RTL"
        verify(s._holdCauses)
        var v2 = createTemporaryObject(vehicleComp, tc)
        v2.armed = true; v2.flying = true; v2.flightMode = "RTL"
        s.vehicle = v2
        tryVerify(function() { return s._holdSince > 0 }, 1000, "hold window started for the new drone")
        v2.textMessageReceived(1, 1, 2, "Battery 1 is low", "")
        verify(s._isStartCause(s._causes["battery"]))
    }
    // random: mode sequences never leave a latch while disarmed, and a hold always has a start time
    function test_bug28594_random_modes() {
        var modes = ["Loiter", "RTL", "Smart RTL", "Land", "Brake", "Auto"]
        var texts = ["Battery 1 is low", "EKF Failsafe", "Radio Failsafe", "Radio Failsafe Cleared", "GPS Glitch cleared", "Crash: Disarming"]
        for (var i = 0; i < 3000; i++) {
            v.armed = Math.random() < 0.8
            v.flying = v.armed && Math.random() < 0.9
            v.flightMode = modes[Math.floor(Math.random() * modes.length)]
            if (Math.random() < 0.3) v.textMessageReceived(1, 1, Math.floor(Math.random() * 7), texts[i % texts.length], "")
            if (!v.armed) verify(!s._returnLatch)
            if (s._holdCauses) verify(s._holdSince > 0)
            if (s.recentCause !== "") verify(s._causeRank > 0)
        }
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
