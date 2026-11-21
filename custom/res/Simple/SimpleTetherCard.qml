/****************************************************************************
 * AQGC Simple UI — S11 tether card (tether profile, top right left of the camera rail).
 * Values from the SAFE-T station (ElistairStationManager) and the drone battery (backup battery):
 *   Cable out    cableLength; the station protocol has no maximum length, so the reference is the station's
 *                length alarm (stationSettings.lengthAlarm, read once) when known
 *   Tension      SAFE-T alarm state (no tension value is reported)
 *   Ground power powerOn / noPower;  Power powerWatts;  Spool temperature spoolTemperature
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

Rectangle {
    id: tc
    property var vs: null
    readonly property var  _st:   vs ? vs.tetherStation : null
    readonly property bool _mon:  !!_st && _st.hasMonitoring
    readonly property real lengthAlarm: _st && _st.stationSettings && _st.stationSettings.lengthAlarm !== undefined ? Number(_st.stationSettings.lengthAlarm) : NaN
    readonly property real cableRatio: _mon && isFinite(lengthAlarm) && lengthAlarm > 0 ? _st.cableLength / lengthAlarm : NaN

    // ask the station once for its settings (length alarm) when it is connected
    property bool _asked: false
    function _ask() { if (!_asked && _st && _st.connected && !_st.settingsBusy) { _asked = true; _st.readSettings() } }
    Component.onCompleted: _ask()
    Connections { target: tc._st; function onConnectedChanged() { tc._ask() } }

    function row(label, value, level) { return { l: label, v: value, c: level } }
    readonly property var rows: !_st ? [] : [
        row(qsTr("Cable out"), !_mon ? "—" : Number(_st.cableLength).toFixed(0) + " m" + (isFinite(lengthAlarm) ? " / " + qsTr("alarm %1 m").arg(Math.round(lengthAlarm)) : ""),
            isFinite(cableRatio) && cableRatio >= 0.9 ? "warn" : ""),
        row(qsTr("Tension"), !_mon ? "—" : _st.alarmActive ? qsTr("Alarm") : qsTr("Normal"), !_mon ? "" : _st.alarmActive ? "danger" : "ok"),
        row(qsTr("Ground power"), _st.noPower ? qsTr("Lost") : _st.powerOn ? qsTr("On") : qsTr("Off"), _st.noPower ? "danger" : _st.powerOn ? "ok" : "warn"),
        row(qsTr("Backup battery"), isNaN(vs.batteryPct) ? "—" : Math.round(vs.batteryPct) + " %" + (/[1-9]/.test(vs.batteryTime) ? " · ≈ " + vs.batteryTime : ""),
            !isNaN(vs.batteryPct) && vs.batteryPct <= 15 ? "danger" : !isNaN(vs.batteryPct) && vs.batteryPct <= 30 ? "warn" : "ok"),
        row(qsTr("Power"), !_mon ? "—" : Math.round(_st.powerWatts).toLocaleString(Qt.locale(), 'f', 0) + " W", ""),
        row(qsTr("Spool temperature"), !_mon ? "—" : Math.round(_st.spoolTemperature) + " °C", "")
    ]
    readonly property string statusLevel: !_st ? "off" : _st.noPower || _st.alarmActive || _st.linkLost ? "danger"
                                        : isFinite(cableRatio) && cableRatio >= 0.9 ? "warn" : _mon ? "ok" : "off"

    width:  SimpleTheme.px(560)
    height: col.height + SimpleTheme.px(40)
    radius: SimpleTheme.px(24)
    color:  SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.95)
    border.width: tc.statusLevel === "danger" ? SimpleTheme.px(3) : SimpleTheme.px(1)
    border.color: tc.statusLevel === "danger" ? SimpleTheme.danger : SimpleTheme.line
    MouseArea { anchors.fill: parent }

    Column {
        id: col
        x: SimpleTheme.px(24); y: SimpleTheme.px(20)
        width: parent.width - SimpleTheme.px(48)
        spacing: SimpleTheme.px(8)
        Item {
            width: parent.width; height: SimpleTheme.px(64)
            Rectangle {
                id: ib; width: SimpleTheme.px(60); height: width; radius: SimpleTheme.px(14); color: SimpleTheme.surfaceControl
                anchors.verticalCenter: parent.verticalCenter
                SIcon { anchors.centerIn: parent; name: "tether"; size: 36 }
            }
            SText { anchors.left: ib.right; anchors.leftMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Tether"); size: 30; bold: true }
            Rectangle {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                height: SimpleTheme.px(44); radius: SimpleTheme.px(12); width: st.implicitWidth + SimpleTheme.px(28)
                color: tc.statusLevel === "ok" ? SimpleTheme.ok : tc.statusLevel === "warn" ? SimpleTheme.warn
                     : tc.statusLevel === "danger" ? SimpleTheme.danger : SimpleTheme.surfaceControl
                SText { id: st; anchors.centerIn: parent; size: 22; medium: true
                        color: tc.statusLevel === "ok" || tc.statusLevel === "warn" ? SimpleTheme.bgBase : SimpleTheme.textPrimary
                        text: !tc._st ? "" : tc._st.linkLost ? qsTr("Station lost") : !tc._mon ? qsTr("No data")
                            : tc.statusLevel === "danger" ? qsTr("Check") : tc.statusLevel === "warn" ? qsTr("Caution") : qsTr("Normal") }
            }
        }
        Repeater {
            model: tc.rows
            Item {
                width: col.width; height: SimpleTheme.px(42)
                SText { anchors.verticalCenter: parent.verticalCenter; text: modelData.l; size: 24; color: SimpleTheme.textSecondary }
                SText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: modelData.v; size: 26; medium: true
                    color: modelData.c === "danger" ? SimpleTheme.textDanger : modelData.c === "warn" ? SimpleTheme.warn
                         : modelData.c === "ok" ? SimpleTheme.ok : SimpleTheme.textPrimary
                }
            }
        }
    }
}
