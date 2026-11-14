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
    height: SimpleTheme.px(820)
    title: qsTr("Pre-flight check")
    titleIcon: "check"

    readonly property var _items: [
        { ok: vs.connected, warn: false, title: qsTr("Drone connected"), detail: vs.connected ? qsTr("Radio link is working") : qsTr("Turn on the drone and the controller") },
        { ok: vs.gpsLock >= 3, warn: vs.gpsLock >= 3 && vs.gpsQuality === qsTr("Weak"), title: qsTr("GPS"),
          detail: vs.gpsLock >= 3 ? qsTr("%1 satellites · %2").arg(vs.gpsCount).arg(vs.gpsQuality) : qsTr("Waiting for GPS — move away from buildings and metal") },
        { ok: isNaN(vs.batteryPct) || vs.batteryPct > 30, warn: !isNaN(vs.batteryPct) && vs.batteryPct <= 50 && vs.batteryPct > 30, title: qsTr("Battery"),
          detail: isNaN(vs.batteryPct) ? qsTr("Battery level not reported") : qsTr("%1 % — at least 30 % needed to take off").arg(Math.round(vs.batteryPct)) },
        { ok: vs.sensorsOk, warn: false, title: qsTr("Sensors (compass, IMU)"),
          detail: vs.sensorsOk ? qsTr("All sensors healthy") : (vs.vehicle && vs.vehicle.prearmError !== "" ? vs.vehicle.prearmError : qsTr("A sensor needs attention")) , fix: !vs.sensorsOk },
        { ok: vs.homeSet, warn: false, title: qsTr("Home point"), detail: vs.homeSet ? qsTr("Set at the take-off position") : qsTr("Set automatically once GPS is good") },
        { ok: !vs.ridAvailable || vs.ridGood, warn: !vs.ridAvailable, title: qsTr("Remote ID"),
          detail: !vs.ridAvailable ? qsTr("Not enabled on this tablet") : vs.ridGood ? qsTr("Broadcasting") : (vs.rid ? vs.rid.armStatusError : "") }
    ]

    Column {
        anchors.fill: parent
        spacing: SimpleTheme.px(10)
        Repeater {
            model: sheet._items
            Rectangle {
                width: parent.width
                height: SimpleTheme.px(86)
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
                    anchors.left: ic.right; anchors.leftMargin: SimpleTheme.px(16)
                    anchors.right: fixBtn.visible ? fixBtn.left : parent.right; anchors.rightMargin: SimpleTheme.px(16)
                    anchors.verticalCenter: parent.verticalCenter
                    SText { width: parent.width; text: modelData.title; size: 28; medium: true }
                    SText { width: parent.width; text: modelData.detail; size: 22; color: SimpleTheme.textSecondary }
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
