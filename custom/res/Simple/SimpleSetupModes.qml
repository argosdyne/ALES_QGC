/****************************************************************************
 * AQGC Simple UI — S72 Vehicle setup › Flight modes (Figma 127:39840, 2026-11-17).
 * Six switch positions (FLTMODE1–6 on FLTMODE_CH), PWM ranges as ArduPilot uses them, the current position from the
 * controller channel (RCChannelMonitorController). Mode names: plain name + ArduPilot name (Advanced mode).
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import QGroundControl.FactSystem 1.0
import QGroundControl.Controllers 1.0
import "."

Flickable {
    id: fm
    contentHeight: col.height
    clip: true
    FactPanelController { id: fpc }
    RCChannelMonitorController {
        id: rc
        onChannelRCValueChanged: if (channel + 1 === fm.modeChannel) fm.pwm = rcValue
    }
    function p(n) { return fpc.parameterExists(-1, n) ? fpc.getParameterFact(-1, n, false) : null }
    readonly property int modeChannel: p("FLTMODE_CH") ? Number(p("FLTMODE_CH").rawValue) : 5
    property int pwm: 0
    // ArduPilot position bands
    readonly property var bands: [[0, 1230], [1231, 1360], [1361, 1490], [1491, 1620], [1621, 1749], [1750, 9999]]
    readonly property int nowIndex: { for (var i = 0; i < bands.length; i++) if (pwm >= bands[i][0] && pwm <= bands[i][1] && pwm > 0) return i; return -1 }
    // ArduCopter mode numbers → ArduPilot name (English, as in the docs) and plain name. The app translates the
    // enum strings, so names are looked up by number.
    readonly property var apName: ({ 0: "Stabilize", 1: "Acro", 2: "AltHold", 3: "Auto", 4: "Guided", 5: "Loiter", 6: "RTL", 7: "Circle",
        9: "Land", 11: "Drift", 13: "Sport", 14: "Flip", 15: "AutoTune", 16: "PosHold", 17: "Brake", 18: "Throw", 19: "Avoid_ADSB",
        20: "Guided_NoGPS", 21: "Smart_RTL", 22: "FlowHold", 23: "Follow", 24: "ZigZag", 25: "SystemID", 26: "Heli_Autorotate", 27: "Auto RTL" })
    readonly property var plain: ({ 0: qsTr("Manual (self-level)"), 1: qsTr("Acro (no self-level)"), 2: qsTr("Altitude hold"), 3: qsTr("Mission"),
        4: qsTr("Guided by the app"), 5: qsTr("Position hold"), 6: qsTr("Return home"), 7: qsTr("Circle"), 9: qsTr("Land"), 11: qsTr("Drift"),
        13: qsTr("Sport"), 15: qsTr("AutoTune"), 16: qsTr("Position hold (pilot)"), 17: qsTr("Brake"), 21: qsTr("Return the way it came"),
        23: qsTr("Follow"), 27: qsTr("Return after mission") })
    function plainOf(num, fallback) { return plain[num] !== undefined ? plain[num] : fallback }
    function apOf(num, fallback) { return apName[num] !== undefined ? apName[num] : fallback }
    property int editing: -1
    property int confirmIndex: -1        // change of the position the switch is on now
    property int confirmValue: 0

    Column {
        id: col
        width: fm.width
        spacing: SimpleTheme.px(12)
        SText { text: qsTr("Flight modes"); size: 40; bold: true }
        SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                text: qsTr("The six positions of the mode switch (channel %1). The current position is highlighted.").arg(fm.modeChannel) }
        Repeater {
            model: 6
            Rectangle {
                readonly property var f: fm.p("FLTMODE" + (index + 1))
                width: col.width; height: rowCol.height + SimpleTheme.px(28); radius: SimpleTheme.px(18)
                color: SimpleTheme.surfaceRaised
                border.width: fm.nowIndex === index ? SimpleTheme.px(3) : 0; border.color: SimpleTheme.ok
                Column {
                    id: rowCol
                    x: SimpleTheme.px(24); y: SimpleTheme.px(14); width: parent.width - SimpleTheme.px(48)
                    spacing: SimpleTheme.px(10)
                    Item {
                        width: parent.width; height: SimpleTheme.px(64)
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            SText { text: qsTr("Position %1").arg(index + 1); size: 26; medium: true }
                            SText { text: index === 5 ? qsTr("PWM %1 +").arg(fm.bands[5][0]) : qsTr("PWM %1 – %2").arg(fm.bands[index][0]).arg(fm.bands[index][1]); size: 20; color: SimpleTheme.textSecondary }
                        }
                        SStatusChip { visible: fm.nowIndex === index; text: qsTr("Now"); level: "ok"; x: SimpleTheme.px(260); anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            x: SimpleTheme.px(400); anchors.verticalCenter: parent.verticalCenter
                            SText { text: f ? fm.plainOf(Number(f.rawValue), f.enumStringValue) : "—"; size: 28; medium: true }
                            SText { text: f ? qsTr("ArduPilot: %1").arg(fm.apOf(Number(f.rawValue), f.enumStringValue)) : ""; size: 20; color: SimpleTheme.textSecondary }
                        }
                        SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; designHeight: 64; textSize: 22
                                  text: fm.editing === index ? qsTr("Close") : qsTr("Change"); onClicked: fm.editing = fm.editing === index ? -1 : index }
                    }
                    // choices
                    Flow {
                        visible: fm.editing === index && !!f
                        width: parent.width
                        spacing: SimpleTheme.px(8)
                        Repeater {
                            model: f ? f.enumStrings : []
                            SButton {
                                designHeight: 64; textSize: 22
                                kind: f && f.enumIndex === index ? "primary" : "secondary"
                                text: fm.plainOf(Number(f.enumValues[index]), modelData)
                                onClicked: {
                                    var pos = fm.editing
                                    if (pos === fm.nowIndex) { fm.confirmIndex = pos; fm.confirmValue = f.enumValues[index] }
                                    else { f.value = f.enumValues[index]; fm.editing = -1 }
                                }
                            }
                        }
                    }
                }
            }
        }
        // confirm: changing the mode of the position the switch is on now
        Rectangle {
            visible: fm.confirmIndex >= 0
            width: col.width; height: cRow.height + SimpleTheme.px(28); radius: SimpleTheme.px(16)
            color: SimpleTheme.withAlpha(SimpleTheme.warn, 0.18); border.width: SimpleTheme.px(2); border.color: SimpleTheme.warn
            Row {
                id: cRow
                anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                spacing: SimpleTheme.px(14)
                SText { anchors.verticalCenter: parent.verticalCenter; width: col.width - SimpleTheme.px(420); wrapMode: Text.WordWrap; size: 24
                        text: qsTr("The switch is on position %1 now: the drone changes to the new mode at once.").arg(fm.confirmIndex + 1) }
                SButton { designHeight: 64; textSize: 22; kind: "primary"; text: qsTr("Change now")
                          onClicked: { fm.p("FLTMODE" + (fm.confirmIndex + 1)).value = fm.confirmValue; fm.confirmIndex = -1; fm.editing = -1 } }
                SButton { designHeight: 64; textSize: 22; text: qsTr("Cancel"); onClicked: fm.confirmIndex = -1 }
            }
        }
    }
}
