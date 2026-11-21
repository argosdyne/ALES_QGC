/****************************************************************************
 * AQGC Simple UI — vehicle state used by the state rules (Figma 02 Flows › C)
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0

QtObject {
    id: s
    property var vehicle: null

    readonly property bool   present:       !!vehicle
    readonly property bool   lost:          present && vehicle.vehicleLinkManager.communicationLost
    readonly property bool   connected:     present && !lost
    readonly property bool   paramsReady:   connected && vehicle.parameterManager.parametersReady
    readonly property bool   armed:         present && vehicle.armed
    readonly property bool   flying:        present && vehicle.flying
    readonly property string mode:          present ? vehicle.flightMode : ""
    readonly property bool   returning:     present && armed && (mode === vehicle.rtlFlightMode || mode === vehicle.smartRTLFlightMode)
    readonly property bool   landing:       present && armed && (vehicle.landing || mode === vehicle.landFlightMode)
    readonly property bool   missionActive: present && flying && mode === vehicle.missionFlightMode
    readonly property bool   paused:        present && flying && mode === vehicle.pauseFlightMode
    readonly property bool   hasMission:    present && globals.planMasterControllerFlyView && globals.planMasterControllerFlyView.missionController.visualItems.count > 1

    // Battery
    readonly property var    battery:       present && vehicle.batteries.count > 0 ? vehicle.batteries.get(0) : null
    readonly property real   batteryPct:    battery ? Number(battery.percentRemaining.rawValue) : NaN
    readonly property string batteryTime:   battery && battery.timeRemainingStr ? battery.timeRemainingStr.valueString : ""
    readonly property string batteryLevel:  isNaN(batteryPct) ? "off" : batteryPct <= 20 ? "danger" : batteryPct <= 30 ? "warn" : "ok"

    // GPS
    readonly property int    gpsCount:      present ? Number(vehicle.gps.count.rawValue) : 0
    readonly property int    gpsLock:       present ? Number(vehicle.gps.lock.rawValue) : 0
    readonly property real   gpsHdop:       present ? Number(vehicle.gps.hdop.rawValue) : NaN
    readonly property string gpsQuality:    !present || gpsLock < 3 ? qsTr("No fix") : gpsLock >= 6 ? qsTr("RTK") : (gpsHdop > 2 || gpsCount < 8) ? qsTr("Weak") : qsTr("Good")
    readonly property string gpsLevel:      !present ? "off" : gpsLock < 3 ? "danger" : gpsQuality === qsTr("Weak") ? "warn" : "ok"

    // Link (RC / telemetry RSSI when the radio reports it, otherwise connection state)
    readonly property int    rssi:          present ? (vehicle.rcRSSI > 0 && vehicle.rcRSSI <= 100 ? vehicle.rcRSSI : -1) : -1
    readonly property string linkText:      !present ? qsTr("None") : lost ? qsTr("Lost") : rssi < 0 ? qsTr("Connected") : rssi >= 60 ? qsTr("Strong") : rssi >= 30 ? qsTr("Fair") : qsTr("Weak")
    readonly property string linkLevel:     !present ? "off" : lost ? "danger" : (rssi >= 0 && rssi < 30) ? "warn" : "ok"

    // Remote ID
    readonly property var    rid:           present ? vehicle.remoteIDManager : null
    readonly property bool   ridAvailable:  !!rid && QGroundControl.settingsManager.remoteIDSettings.enable.rawValue
    readonly property bool   ridGood:       ridAvailable && rid.armStatusGood && rid.commsGood
    readonly property string ridLevel:      !ridAvailable ? "off" : ridGood ? "ok" : "danger"

    // Pre-flight readiness (S02)
    readonly property bool   homeSet:       present && vehicle.homePosition.isValid
    readonly property bool   sensorsOk:     present && (vehicle.readyToFlyAvailable ? vehicle.readyToFly : vehicle.sensorsUnhealthyBits === 0)
    // Remote ID blocks take-off when it is turned on (Settings › Remote ID) but the module is not broadcasting (S02, S47)
    // Flight zones (decision 2026-11-15): taking off inside a prohibited zone or a "do not enter" zone is blocked;
    // authorisation and warn-only zones are a caution. Checked once a second (2D, FlightZoneManager.zoneAt).
    property var             zoneHere:      null
    readonly property bool   zoneBlocked:   !!zoneHere && (zoneHere.zoneClass === 1 || zoneHere.noEntry)
    readonly property bool   zoneCaution:   !!zoneHere && !zoneBlocked && (zoneHere.zoneClass === 2 || zoneHere.zoneClass === 4)
    property Timer _zoneTimer: Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: present && !armed && typeof mainWindow !== "undefined" && !!mainWindow.flightZoneManager
        onTriggered: zoneHere = vehicle.coordinate.isValid ? mainWindow.flightZoneManager.zoneAt(vehicle.coordinate) : null
        onRunningChanged: if (!running) zoneHere = null
    }
    // Tether profile (S11/S16): product profile "Tether" (set in Advanced › General) with the SAFE-T station switched on.
    // Ground power must be on before take-off (S16).
    readonly property var    tetherStation: QGroundControl.corePlugin.elistairStationManager
    readonly property bool   tetherProfile: Number(QGroundControl.corePlugin.settings.simpleProductProfile.rawValue) === 2
    readonly property bool   tethered:      tetherProfile && !!tetherStation && tetherStation.enabled
    readonly property bool   tetherPowerOk: tethered && tetherStation.connected && tetherStation.hasMonitoring && tetherStation.powerOn && !tetherStation.noPower
    readonly property string tetherLevel:   !tethered ? "off" : tetherPowerOk ? "ok" : tetherStation.noPower || tetherStation.linkLost ? "danger" : "warn"
    readonly property string tetherText:    !tethered ? "" : tetherStation.noPower ? qsTr("No power") : tetherStation.linkLost ? qsTr("Station lost")
                                          : !(tetherStation.connected && tetherStation.hasMonitoring) ? qsTr("No station") : tetherStation.powerOn ? qsTr("Power OK") : qsTr("Power off")

    readonly property bool   readyToTakeOff: connected && !armed && sensorsOk && gpsLock >= 3 && (isNaN(batteryPct) || batteryPct > 30)
                                             && (!ridAvailable || ridGood) && !zoneBlocked && (!tethered || tetherPowerOk)
    // red rows of the S02 pre-flight check (same conditions as readyToTakeOff; top bar "%n items to fix")
    readonly property int    takeoffBlockers: (connected ? 0 : 1) + (gpsLock >= 3 ? 0 : 1) + (isNaN(batteryPct) || batteryPct > 30 ? 0 : 1)
                                             + (sensorsOk ? 0 : 1) + (!ridAvailable || ridGood ? 0 : 1) + (zoneBlocked ? 1 : 0)
                                             + (tethered && !tetherPowerOk ? 1 : 0)

    // QA F5: why the drone returns / lands / stopped a mission, in plain words (Tuleap bug #28582, code reviews 2026-11-21).
    // - Only the flight controller's warnings count (STATUSTEXT from component 1, severity WARNING or worse, no PreArm):
    //   a LiDAR, Remote ID module or camera on the same system must not name the cause. The app's own geofence and
    //   C2 link messages (Vehicle.cc, also sent as component 1) are skipped.
    // - Each kind of cause (EKF, GPS, compass, battery, ...) is kept on its own; the most serious kind still kept is
    //   shown (the newest one on a tie), so a lower cause appears when a higher one expires or is reported cleared
    //   ("GPS Glitch cleared" clears only the GPS kind, not an EKF failsafe).
    // - Lines that report a normal switch-over ("EKF primary changed", "SmartRTL deactivated", "Battery OK", "using GPS")
    //   are ignored; FC warnings with no known cause are kept as "Warning — see the messages" (lowest rank) with their text.
    // - A cause is kept 60 s, but never expires while the drone is returning or landing (the S92 card reads it at
    //   disarm); arming or another active drone clears them.
    // recentWarning keeps the raw FC text of the shown cause (Advanced mode shows it after the plain cause).
    readonly property int    _autopilotComponent: 1         // MAV_COMP_ID_AUTOPILOT1
    readonly property int    _causeKeepMs: 60000
    property var             _causes: ({})                   // kind -> { rank, cause, text, t }
    property string recentWarning: ""
    property string recentCause: ""
    property int    _causeRank: 0
    property bool   _appMessage: false                       // the next text is the app's own geofence alert
    readonly property bool   _holdCauses: armed && (returning || landing)
    function _now() { return Date.now() }
    function _clearCause() { _causes = ({}); _refreshCause() }
    function _refreshCause() {
        var best = null
        for (var k in _causes) {
            var e = _causes[k]
            if (!best || e.rank > best.rank || (e.rank === best.rank && e.t >= best.t)) best = e
        }
        _causeRank = best ? best.rank : 0
        recentCause = best ? best.cause : ""
        recentWarning = best ? best.text : ""
    }
    function _setCauses(c) { _causes = c; _refreshCause() }
    // drops causes older than 60 s (kept fresh while returning / landing)
    function _expireCauses() {
        var now = _now(), c = {}, changed = false
        for (var k in _causes) {
            var e = _causes[k]
            if (_holdCauses) c[k] = { rank: e.rank, cause: e.cause, text: e.text, t: now }
            else if (now - e.t < _causeKeepMs) c[k] = e
            else changed = true
        }
        _causes = c
        if (changed) _refreshCause()
    }
    property Timer _warnTimer: Timer {
        interval: 1000; repeat: true
        running: s._causeRank > 0
        onTriggered: s._expireCauses()
    }
    // a new flight (or another drone) starts without the old causes
    onArmedChanged: if (armed) _clearCause()
    onVehicleChanged: _clearCause()
    on_HoldCausesChanged: _expireCauses()
    function _causeOf(t) {          // { kind, rank, cause }; rank 0 = not a cause
        function r(kind, rank, cause) { return { kind: kind, rank: rank, cause: cause } }
        if (/crash/i.test(t))                                     return r("crash", 9, qsTr("Crash detected"))
        if (/compass|mag\b|magnet/i.test(t))                      return r("compass", 8, qsTr("Compass problem"))
        if (/EKF|variance/i.test(t))                              return r("ekf", 8, qsTr("GPS or position lost"))
        if (/GPS|position|Need Position|Glitch/i.test(t))         return r("gps", 8, qsTr("GPS or position lost"))
        if (/batt|voltage|capacity/i.test(t))                     return r("battery", 7, qsTr("Battery low"))
        if (/radio|RC |throttle failsafe|RC failsafe|manual control/i.test(t)) return r("rc", 6, qsTr("Controller signal lost"))
        if (/GCS|telemetry|link/i.test(t))                        return r("gcs", 5, qsTr("App link lost"))
        if (/fence/i.test(t))                                     return r("fence", 4, qsTr("Geofence reached"))
        if (/terrain|rangefinder/i.test(t))                       return r("terrain", 3, qsTr("Terrain data problem"))
        if (/vibration/i.test(t))                                 return r("vibration", 3, qsTr("Strong vibration"))
        if (/wind/i.test(t))                                      return r("wind", 2, qsTr("Strong wind"))
        return r("", 0, "")
    }
    function _isAppMessage(text) {
        if (_appMessage) return true
        return text === qsTranslate("Vehicle", "C2 link quality critical") || text === qsTranslate("Vehicle", "C2 link quality degraded")
    }
    function _onFcWarning(componentid, severity, text) {
        var app = _isAppMessage(text)
        _appMessage = false
        if (app || componentid !== _autopilotComponent || text === "" || text.indexOf("PreArm") === 0) return
        // a problem reported gone (any severity): forget that kind ("GPS Glitch cleared", "Radio failsafe cleared")
        if (/clear|restored|recovered|resolved/i.test(text)) {
            var gone = _causeOf(text.replace(/clear\w*|restored|recovered|resolved/ig, ""))
            if (gone.rank > 0 && _causes[gone.kind] !== undefined) {
                var c0 = {}
                for (var k0 in _causes) if (k0 !== gone.kind) c0[k0] = _causes[k0]
                _setCauses(c0)
            }
            return
        }
        if (severity > 4) return
        // a normal switch-over is not a cause
        if (/changed|deactivat|\bOK\b|using GPS/i.test(text)) return
        var c = _causeOf(text)
        if (c.rank === 0) c = { kind: "other", rank: 1, cause: qsTr("Warning — see the messages (bell)") }
        var n = {}
        for (var k in _causes) n[k] = _causes[k]
        n[c.kind] = { rank: c.rank, cause: c.cause, text: text, t: _now() }
        _setCauses(n)
    }
    property Connections _warnConn: Connections {
        target: present ? vehicle : null
        ignoreUnknownSignals: true
        function onTextMessageReceived(uasid, componentid, severity, text, description) { s._onFcWarning(componentid, severity, text) }
        // the app's own geofence alert text follows this signal at once (Vehicle._updateGeoFenceAlert)
        function onGeoFenceAlertTierChanged(tier) { s._appMessage = true; Qt.callLater(function() { s._appMessage = false }) }
    }
    // reason line for banners and the S92 card: plain cause; Advanced mode adds the FC text
    readonly property string recentReason: recentCause === "" ? ""
                                         : (QGroundControl.corePlugin.advancedMode ? recentCause + " (" + recentWarning + ")" : recentCause)

    // Overall state name used by the UI rules
    readonly property string state: !present ? "disconnected"
                                  : lost ? "lost"
                                  : (returning || landing) ? "returning"
                                  : flying ? "flying"
                                  : "ground"

    // Situations that always bring the user back to the fly screen (layer rule 1, 02 Flows D).
    // Link lost counts only in flight (last known state armed or flying): on the ground the user may be
    // swapping the battery or restarting the radio, so Plan / Settings stay open (2026-11-15).
    readonly property bool   lostInFlight:  lost && (armed || flying)
    readonly property bool   lostOnGround:  lost && !lostInFlight
    readonly property bool   critical:      lostInFlight || (returning && !isNaN(batteryPct) && batteryPct <= 20)
}
