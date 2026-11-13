/****************************************************************************
 * AQGC Simple UI — S28 flight mode: only Position hold / Altitude hold (others in Advanced)
 ****************************************************************************/
import QtQuick 2.12
import "."

SPanel {
    id: sheet
    property var vehicle: null
    title: qsTr("Flight mode")
    width:  SimpleTheme.px(760)
    height: SimpleTheme.px(470)

    // ArduPilot names first, PX4 names second
    readonly property var _choices: [
        { names: ["Loiter", "Position"],      title: qsTr("Position hold"), detail: qsTr("Holds position and height when you let go of the sticks") },
        { names: ["Altitude Hold", "AltHold", "Altitude"], title: qsTr("Altitude hold"), detail: qsTr("Holds height only — the drone drifts with the wind") }
    ]
    function _available(names) {
        if (!vehicle) return ""
        for (var i = 0; i < names.length; i++) if (vehicle.flightModes.indexOf(names[i]) !== -1) return names[i]
        return ""
    }

    Column {
        anchors.fill: parent
        spacing: SimpleTheme.px(12)
        Repeater {
            model: sheet._choices
            Rectangle {
                readonly property string modeName: sheet._available(modelData.names)
                visible: modeName !== ""
                width: parent.width; height: SimpleTheme.px(110); radius: SimpleTheme.px(18)
                color: sheet.vehicle && sheet.vehicle.flightMode === modeName ? SimpleTheme.withAlpha(SimpleTheme.brandGreen, 0.35) : SimpleTheme.surfaceRaised
                border.width: sheet.vehicle && sheet.vehicle.flightMode === modeName ? SimpleTheme.px(2) : 0
                border.color: SimpleTheme.brandGreen
                Column {
                    anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(24); anchors.verticalCenter: parent.verticalCenter
                    SText { text: modelData.title; size: 30; bold: true }
                    SText { text: modelData.detail; size: 22; color: SimpleTheme.textSecondary }
                }
                MouseArea { anchors.fill: parent; onClicked: { sheet.vehicle.flightMode = parent.modeName; sheet.closeRequested() } }
            }
        }
        SText { text: qsTr("Other flight modes are available in Advanced mode."); size: 22; color: SimpleTheme.textTertiary }
    }
}
