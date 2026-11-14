/****************************************************************************
 * AQGC Simple UI — telemetry bar (Figma ui/TelemetryBar): 4 labeled values
 ****************************************************************************/
import QtQuick 2.12
import "."

Rectangle {
    id: tb
    property var vehicle: null

    function _fact(f, digits) {
        if (!vehicle || !f) return { v: "—", u: "" }
        var raw = Number(f.value)
        return { v: isNaN(raw) ? "—" : raw.toFixed(digits), u: f.units }
    }
    readonly property var _items: [
        { label: qsTr("ALTITUDE"),    val: _fact(vehicle ? vehicle.altitudeRelative : null, 1) },
        { label: qsTr("DISTANCE"),    val: _fact(vehicle ? vehicle.distanceToHome : null, 0) },
        { label: qsTr("SPEED"),       val: _fact(vehicle ? vehicle.groundSpeed : null, 1) },
        { label: qsTr("FLIGHT TIME"), val: { v: vehicle ? vehicle.getFact("flightTime").valueString : "00:00:00", u: "" } }
    ]

    width:  SimpleTheme.px(902)
    height: SimpleTheme.px(120)
    radius: SimpleTheme.px(20)
    color:  SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)

    Row {
        anchors.fill: parent
        anchors.leftMargin: SimpleTheme.px(28)
        Repeater {
            model: tb._items
            Item {
                width: (tb.width - SimpleTheme.px(28)) / 4
                height: tb.height
                Rectangle { visible: index > 0; width: 1; height: parent.height * 0.5; anchors.verticalCenter: parent.verticalCenter; color: SimpleTheme.line; x: -SimpleTheme.px(14) }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    SText { text: modelData.label; size: 22; medium: true; color: SimpleTheme.textSecondary }
                    Row {
                        spacing: SimpleTheme.px(6)
                        SText { id: v; text: modelData.val.v; size: 40; bold: true }
                        SText { text: modelData.val.u; size: 22; color: SimpleTheme.textSecondary; anchors.baseline: v.baseline }
                    }
                }
            }
        }
    }
}
