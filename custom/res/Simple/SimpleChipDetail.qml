/****************************************************************************
 * AQGC Simple UI — S25/S26/S27/S14 chip details: values in plain words, raw value in one grey line
 ****************************************************************************/
import QtQuick 2.12
import "."

SPanel {
    id: panel
    property string kind: ""
    property var vs
    width:  SimpleTheme.px(640)
    height: col.implicitHeight + SimpleTheme.px(150)
    title:  kind === "battery" ? qsTr("Battery") : kind === "gps" ? qsTr("GPS") : kind === "link" ? qsTr("Radio link") : qsTr("Remote ID")
    titleIcon: kind === "battery" ? "battery" : kind === "gps" ? "gps" : kind === "link" ? "signal" : "rid"

    readonly property var _b: vs.battery
    readonly property var _rows: {
        if (kind === "battery") return [
            [qsTr("Remaining"), isNaN(vs.batteryPct) ? "—" : Math.round(vs.batteryPct) + " %"],
            [qsTr("Flight time left"), vs.batteryTime !== "" ? "≈ " + vs.batteryTime : "—"],
            [qsTr("Voltage"), _b ? _b.voltage.valueString + " " + _b.voltage.units : "—"],
            [qsTr("Warning / return home"), qsTr("30 % / 20 %")]]
        if (kind === "gps") return [
            [qsTr("Quality"), vs.gpsQuality],
            [qsTr("Satellites"), vs.present ? vs.gpsCount : "—"],
            [qsTr("Accuracy (approx.)"), isNaN(vs.gpsHdop) ? "—" : "± " + (vs.gpsHdop * 2.5).toFixed(1) + " m"],
            [qsTr("HDOP (raw)"), isNaN(vs.gpsHdop) ? "—" : vs.gpsHdop.toFixed(2)]]
        if (kind === "link") return [
            [qsTr("Signal"), vs.linkText],
            [qsTr("RSSI"), vs.rssi >= 0 ? vs.rssi + " %" : qsTr("not reported")],
            [qsTr("Distance to drone"), vs.present ? vs.vehicle.distanceToGCS.valueString + " " + vs.vehicle.distanceToGCS.units : "—"],
            [qsTr("If the link is lost"), qsTr("Drone follows its failsafe (Settings › Safety)")]]
        return [
            [qsTr("Status"), !vs.ridAvailable ? qsTr("Not enabled") : vs.ridGood ? qsTr("Broadcasting") : qsTr("Check")],
            [qsTr("Message"), vs.rid && vs.rid.armStatusError ? vs.rid.armStatusError : "—"],
            [qsTr("Operator ID"), vs.rid ? (vs.rid.operatorIDGood ? qsTr("OK") : qsTr("Missing or invalid")) : "—"]]
    }

    Column {
        id: col
        width: parent.width
        spacing: SimpleTheme.px(14)
        Repeater {
            model: panel._rows
            Item {
                width: col.width; height: SimpleTheme.px(44)
                SText { text: modelData[0]; size: 24; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                SText { text: modelData[1]; size: 26; bold: true; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: Math.min(implicitWidth, col.width * 0.6); horizontalAlignment: Text.AlignRight }
            }
        }
    }
}
