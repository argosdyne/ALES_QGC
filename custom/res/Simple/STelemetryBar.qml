/****************************************************************************
 * AQGC Simple UI — telemetry bar (Figma ui/TelemetryBar): 4 labeled values
 ****************************************************************************/
import QtQuick 2.12
import "."

Rectangle {
    id: tb
    property var vehicle: null
    property bool stale: false      // QA F4: link lost -> the values are the last ones received, not live
    property bool altitudeTappable: false   // S38: tap ALTITUDE to change the altitude in flight
    signal altitudeClicked()

    function _fact(f, digits) {
        if (!vehicle || !f) return { v: "—", u: "" }
        var raw = Number(f.value)
        return { v: isNaN(raw) ? "—" : raw.toFixed(digits), u: f.units }
    }
    // S11 tether profile: CABLE OUT and TENSION (SAFE-T alarm state; the station reports no tension value) instead of
    // DISTANCE and SPEED
    property var tether: null
    readonly property var _items: tether ? [
        { label: qsTr("ALTITUDE"),    val: _fact(vehicle ? vehicle.altitudeRelative : null, 1) },
        { label: qsTr("CABLE OUT"),   val: { v: tether.hasMonitoring ? Number(tether.cableLength).toFixed(0) : "—", u: "m" } },
        { label: qsTr("TENSION"),     val: { v: !tether.hasMonitoring ? "—" : tether.alarmActive ? qsTr("Alarm") : qsTr("Normal"), u: "" } },
        { label: qsTr("FLIGHT TIME"), val: { v: vehicle ? vehicle.getFact("flightTime").valueString : "00:00:00", u: "" } }
    ] : [
        { label: qsTr("ALTITUDE"),    val: _fact(vehicle ? vehicle.altitudeRelative : null, 1) },
        { label: qsTr("DISTANCE"),    val: _fact(vehicle ? vehicle.distanceToHome : null, 0) },
        { label: qsTr("SPEED"),       val: _fact(vehicle ? vehicle.groundSpeed : null, 1) },
        { label: qsTr("FLIGHT TIME"), val: { v: vehicle ? vehicle.getFact("flightTime").valueString : "00:00:00", u: "" } }
    ]

    width:  SimpleTheme.px(902)
    height: SimpleTheme.px(120)
    radius: SimpleTheme.px(20)
    color:  SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
    border.width: stale ? SimpleTheme.px(2) : 0
    border.color: SimpleTheme.danger
    Rectangle {
        visible: tb.stale
        anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(16)
        anchors.top: parent.top; anchors.topMargin: -height / 2
        width: staleText.implicitWidth + SimpleTheme.px(20); height: SimpleTheme.px(32); radius: height / 2
        color: SimpleTheme.danger
        SText { id: staleText; anchors.centerIn: parent; size: 18; medium: true; text: qsTr("Last received values") }
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: SimpleTheme.px(28)
        Repeater {
            model: tb._items
            Item {
                width: (tb.width - SimpleTheme.px(28)) / 4
                height: tb.height
                MouseArea { anchors.fill: parent; enabled: index === 0 && tb.altitudeTappable; onClicked: tb.altitudeClicked() }
                Rectangle { visible: index > 0; width: 1; height: parent.height * 0.5; anchors.verticalCenter: parent.verticalCenter; color: SimpleTheme.line; x: -SimpleTheme.px(14) }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Row {
                        spacing: SimpleTheme.px(6)
                        SText { text: modelData.label; size: 22; medium: true; color: SimpleTheme.textSecondary }
                        SIcon { visible: index === 0 && tb.altitudeTappable; name: "chevron"; size: 20; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Row {
                        spacing: SimpleTheme.px(6)
                        SText { id: v; text: modelData.val.v; size: 40; bold: true; color: tb.stale ? SimpleTheme.textTertiary : SimpleTheme.textPrimary }
                        SText { text: modelData.val.u; size: 22; color: SimpleTheme.textSecondary; anchors.baseline: v.baseline }
                    }
                }
            }
        }
    }
}
