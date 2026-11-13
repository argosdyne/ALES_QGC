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
    readonly property bool   readyToTakeOff: connected && !armed && sensorsOk && gpsLock >= 3 && (isNaN(batteryPct) || batteryPct > 30)

    // Overall state name used by the UI rules
    readonly property string state: !present ? "disconnected"
                                  : lost ? "lost"
                                  : (returning || landing) ? "returning"
                                  : flying ? "flying"
                                  : "ground"

    // Situations that always bring the user back to the fly screen (layer rule 1)
    readonly property bool   critical:      lost || (returning && !isNaN(batteryPct) && batteryPct <= 20)
}
