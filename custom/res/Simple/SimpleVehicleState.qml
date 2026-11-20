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

    // QA F5: the drone's last warning (STATUSTEXT, severity WARNING or worse) in the last 60 s, e.g. why it lands
    property string recentWarning: ""
    property Timer _warnTimer: Timer { interval: 60000; onTriggered: recentWarning = "" }
    property Connections _warnConn: Connections {
        target: present ? vehicle : null
        function onTextMessageReceived(uasid, componentid, severity, text, description) {
            if (severity <= 4 && text !== "" && text.indexOf("PreArm") !== 0) { recentWarning = text; _warnTimer.restart() }
        }
    }

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
