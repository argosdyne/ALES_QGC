/****************************************************************************
 * AQGC Simple UI — S02 pre-flight check (plain-language items, FC text in one grey line)
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

SPanel {
    id: sheet
    property var vs
    signal takeoffRequested()

    width:  SimpleTheme.px(980)
    // grows with wrapped item details; SPanel body margins: top 112, bottom 24
    height: Math.max(SimpleTheme.px(820), listCol.implicitHeight + SimpleTheme.px(136))
    title: qsTr("Pre-flight check")
    titleIcon: "check"

    // ST-07 (payload test 2026-11-20 #54): the FC PreArm text in plain words, under the item it is about (GPS texts under
    // GPS, not under Sensors). Unknown texts are shown without the "PreArm: " prefix.
    readonly property string _pa: vs.vehicle && vs.vehicle.prearmError ? String(vs.vehicle.prearmError).replace(/^PreArm:\s*/, "") : ""
    readonly property bool   _paGps: /GPS|GNSS|HDOP|Need Position|position estimate|waiting for home|EKF.*(origin|position)/i.test(_pa)
    function plainPrearm(t) {
        if (/Bad fix|GPS.*(no fix|not fixed)|waiting for 3D fix/i.test(t)) return qsTr("GPS has no good position yet. Wait in the open, away from buildings.")
        if (/HDOP|horiz.*(pos|accuracy)|GPS.*accuracy/i.test(t))           return qsTr("GPS position is not accurate enough yet. Wait a little.")
        if (/Need Position|position estimate|waiting for home|EKF/i.test(t)) return qsTr("The drone is still working out its position. Wait for GPS.")
        if (/Compass.*(calib|offsets)|mag.*calib/i.test(t))                 return qsTr("The compass needs calibrating (Vehicle setup › Sensors).")
        if (/Compass|mag field|magnet/i.test(t))                            return qsTr("The compass reading is off. Move away from metal or calibrate it.")
        if (/Accel.*calib|3D Accel/i.test(t))                               return qsTr("The accelerometer needs calibrating (Vehicle setup › Sensors).")
        if (/Accel|Gyro|INS|IMU/i.test(t))                                  return qsTr("Motion sensor (IMU) problem. Keep the drone still or restart it.")
        if (/Baro/i.test(t))                                                return qsTr("Barometer problem. Restart the drone.")
        if (/RC |Radio|Throttle/i.test(t))                                  return qsTr("The controller is not ready. Check the controller and its calibration.")
        if (/Batt/i.test(t))                                                return qsTr("The drone's battery check failed.")
        if (/Fence/i.test(t))                                               return qsTr("Geofence problem. Check Settings › Safety.")
        if (/Logging|SD card/i.test(t))                                 return qsTr("Flight log problem (SD card in the drone).")
        return t
    }

    readonly property var _items: [
        { ok: vs.connected, warn: false, title: qsTr("Drone connected"), detail: vs.connected ? qsTr("Radio link is working") : qsTr("Turn on the drone and the controller") },
        { ok: vs.gpsLock >= 3 && !(_paGps && !vs.sensorsOk), warn: vs.gpsLock >= 3 && vs.gpsQuality === qsTr("Weak"), title: qsTr("GPS"),
          detail: _paGps && !vs.sensorsOk ? plainPrearm(_pa)
                : vs.gpsLock >= 3 ? qsTr("%1 satellites · %2").arg(vs.gpsCount).arg(vs.gpsQuality) : qsTr("Waiting for GPS — move away from buildings and metal") },
        { ok: isNaN(vs.batteryPct) || vs.batteryPct > 30, warn: !isNaN(vs.batteryPct) && vs.batteryPct <= 50 && vs.batteryPct > 30, title: qsTr("Battery"),
          detail: isNaN(vs.batteryPct) ? qsTr("Battery level not reported") : qsTr("%1 % — at least 30 % needed to take off").arg(Math.round(vs.batteryPct)) },
        { ok: vs.sensorsOk || _paGps, warn: false, title: qsTr("Sensors (compass, IMU)"),
          detail: vs.sensorsOk || _paGps ? qsTr("All sensors healthy") : (_pa !== "" ? plainPrearm(_pa) : qsTr("A sensor needs attention")), fix: !vs.sensorsOk && !_paGps },
        { ok: vs.homeSet, warn: false, title: qsTr("Home point"), detail: vs.homeSet ? qsTr("Set at the take-off position") : qsTr("Set automatically once GPS is good") },
        { ok: !vs.ridAvailable || vs.ridGood, warn: !vs.ridAvailable, title: qsTr("Remote ID"),
          detail: !vs.ridAvailable ? qsTr("Not enabled on this tablet") : vs.ridGood ? qsTr("Broadcasting")
                : !vs.rid.commsGood ? qsTr("No Remote ID module found on the drone. If it is not required here, turn it off in Settings › Remote ID.")
                : (vs.rid.armStatusError !== "" ? vs.rid.armStatusError : qsTr("The Remote ID module is not ready")) },
        { ok: !vs.zoneBlocked, warn: vs.zoneCaution, title: qsTr("Flight zones"),
          detail: !vs.zoneHere || vs.zoneHere.zoneClass === 0 ? qsTr("No restricted zone here")
                : vs.zoneBlocked ? qsTr("The drone is in a no-fly zone (%1). Move to another place to take off.").arg(vs.zoneHere.zoneName)
                : qsTr("The drone is in a zone that needs care (%1). Check that you may fly here.").arg(vs.zoneHere.zoneName) }
    ].concat(vs.tethered ? [
        { ok: vs.tetherPowerOk, warn: false, title: qsTr("Tether power"),
          detail: vs.tetherPowerOk ? qsTr("Ground unit on · %1 W").arg(Math.round(vs.tetherStation.powerWatts))
                : qsTr("%1 — turn the tether power on in the Payloads panel").arg(vs.tetherText) } ] : [])

    Column {
        id: listCol
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        spacing: SimpleTheme.px(10)
        Repeater {
            model: sheet._items
            Rectangle {
                width: parent.width
                height: Math.max(SimpleTheme.px(86), itemText.implicitHeight + SimpleTheme.px(24))   // long details wrap
                radius: SimpleTheme.px(16)
                color: modelData.ok ? (modelData.warn ? SimpleTheme.withAlpha(SimpleTheme.warn, 0.14) : SimpleTheme.surfaceRaised) : SimpleTheme.withAlpha(SimpleTheme.danger, 0.16)
                border.width: modelData.ok && !modelData.warn ? 0 : SimpleTheme.px(2)
                border.color: modelData.ok ? SimpleTheme.warn : SimpleTheme.danger
                SIcon {
                    id: ic
                    anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(18); anchors.verticalCenter: parent.verticalCenter
                    name: modelData.ok && !modelData.warn ? "check" : "warn"; size: 40
                    color: modelData.ok ? (modelData.warn ? SimpleTheme.warn : SimpleTheme.ok) : SimpleTheme.textDanger
                }
                Column {
                    id: itemText
                    anchors.left: ic.right; anchors.leftMargin: SimpleTheme.px(16)
                    anchors.right: fixBtn.visible ? fixBtn.left : parent.right; anchors.rightMargin: SimpleTheme.px(16)
                    anchors.verticalCenter: parent.verticalCenter
                    SText { width: parent.width; text: modelData.title; size: 28; medium: true }
                    SText { width: parent.width; text: modelData.detail; size: 22; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap }
                }
                SButton {
                    id: fixBtn
                    visible: !!modelData.fix
                    anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(12); anchors.verticalCenter: parent.verticalCenter
                    designHeight: 64; textSize: 24
                    text: qsTr("Fix")
                    onClicked: simpleRoot.requestAdvanced("setup")
                }
            }
        }
        Item { width: 1; height: SimpleTheme.px(8) }
        SButton {
            width: parent.width
            kind: "primary"
            icon: "takeoff"
            enabled_: vs.readyToTakeOff
            text: vs.readyToTakeOff ? qsTr("Take off") : qsTr("Fix the red items to take off")
            onClicked: sheet.takeoffRequested()
        }
    }
}
