/****************************************************************************
 * AQGC Simple UI — S71 Vehicle setup › Radio (Figma 127:39657, 2026-11-17).
 * Live channel bars (RCChannelMonitorController): name from RCMAP_*, the mode channel and RCx_OPTION, PWM value,
 * centre line at 1500. Calibrate sticks / reverse a channel open the classic Radio page (the company controller is
 * calibrated at the factory: only after a repair or a new controller).
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import QGroundControl.FactSystem 1.0
import QGroundControl.Controllers 1.0
import "."

Flickable {
    id: rd
    contentHeight: col.height
    clip: true
    FactPanelController { id: fpc }
    function p(n) { return fpc.parameterExists(-1, n) ? fpc.getParameterFact(-1, n, false) : null }
    property var values: []
    RCChannelMonitorController {
        id: rc
        onChannelRCValueChanged: { var v = rd.values.slice(); v[channel] = rcValue; rd.values = v }
    }
    readonly property int count: Math.max(8, Math.min(16, rc.channelCount))
    function nameOf(ch) {
        var n = ch + 1
        var map = [["RCMAP_ROLL", qsTr("Roll")], ["RCMAP_PITCH", qsTr("Pitch")], ["RCMAP_THROTTLE", qsTr("Throttle")], ["RCMAP_YAW", qsTr("Yaw")]]
        for (var i = 0; i < map.length; i++) { var f = p(map[i][0]); if (f && Number(f.rawValue) === n) return map[i][1] + " · " + qsTr("ch %1").arg(n) }
        var m = p("FLTMODE_CH"); if (m && Number(m.rawValue) === n) return qsTr("Mode switch · ch %1").arg(n)
        var o = p("RC" + n + "_OPTION"); if (o && Number(o.rawValue) !== 0) return qsTr("Ch %1 · %2").arg(n).arg(o.enumOrValueString)
        return qsTr("Ch %1").arg(n)
    }

    Column {
        id: col
        width: rd.width
        spacing: SimpleTheme.px(12)
        SText { text: qsTr("Radio"); size: 40; bold: true }
        SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                text: qsTr("Move each stick and switch to check it. The company controller is calibrated at the factory: calibrate only after a repair or with a new controller.") }
        Rectangle {
            width: col.width; height: bars.height + SimpleTheme.px(32); radius: SimpleTheme.px(18)
            color: SimpleTheme.surfaceRaised
            Column {
                id: bars
                x: SimpleTheme.px(24); y: SimpleTheme.px(16); width: parent.width - SimpleTheme.px(48)
                spacing: SimpleTheme.px(10)
                SText { visible: rc.channelCount === 0; text: qsTr("No controller signal yet. Turn on the controller."); size: 24; color: SimpleTheme.textSecondary }
                Repeater {
                    model: rd.count
                    Item {
                        width: bars.width; height: SimpleTheme.px(44)
                        readonly property int v: rd.values[index] !== undefined ? rd.values[index] : 0
                        SText { width: SimpleTheme.px(330); anchors.verticalCenter: parent.verticalCenter; text: rd.nameOf(index); size: 22; elide: Text.ElideRight }
                        Item {
                            id: bar
                            x: SimpleTheme.px(340); width: parent.width - SimpleTheme.px(450); height: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                            Rectangle { anchors.fill: parent; radius: height / 2; color: SimpleTheme.surfaceControl }
                            Rectangle { visible: parent.parent.v > 0; height: parent.height; radius: height / 2; color: SimpleTheme.brandGreen
                                        width: parent.width * Math.max(0, Math.min(1, (parent.parent.v - 800) / 1400)) }
                            Rectangle { x: parent.width * (700 / 1400); width: SimpleTheme.px(3); height: SimpleTheme.px(28); y: -SimpleTheme.px(6); color: SimpleTheme.textSecondary }
                        }
                        SText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: v > 0 ? v : "—"; size: 24; bold: true }
                    }
                }
            }
        }
        Row {
            spacing: SimpleTheme.px(12)
            SButton { kind: "primary"; text: qsTr("Calibrate sticks (classic)"); onClicked: simpleRoot.openClassic("setup:RadioComponent") }
            SButton { text: qsTr("Reverse a channel (classic)"); onClicked: simpleRoot.openClassic("setup:RadioComponent") }
        }
    }
}
