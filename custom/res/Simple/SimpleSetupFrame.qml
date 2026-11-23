/****************************************************************************
 * AQGC Simple UI — S70 Vehicle setup › Frame (Figma 127:39455, 2026-11-17).
 * Six multicopter frames (FRAME_CLASS / FRAME_TYPE). The company drones (AQUILA-2, AQUILA-3F) are Quadcopter X; the
 * card says so to avoid a change by mistake. Apply = confirm → save → restart the drone → test the motors (S74).
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import QGroundControl.FactSystem 1.0
import QGroundControl.Controllers 1.0
import "."

Flickable {
    id: fr
    // this page says itself that the drone restarts (no restart toast for FRAME_CLASS / FRAME_TYPE)
    Component.onCompleted:   SimpleTheme.ownRestartHints++
    Component.onDestruction: SimpleTheme.ownRestartHints--
    contentHeight: col.height
    clip: true
    FactPanelController { id: fpc }
    function p(n) { return fpc.parameterExists(-1, n) ? fpc.getParameterFact(-1, n, false) : null }
    readonly property var  _veh: QGroundControl.multiVehicleManager.activeVehicle
    readonly property int  curClass: p("FRAME_CLASS") ? Number(p("FRAME_CLASS").rawValue) : -1
    readonly property int  curType:  p("FRAME_TYPE") ? Number(p("FRAME_TYPE").rawValue) : -1
    readonly property var  frames: [
        { t: qsTr("Quadcopter X"), s: qsTr("4 motors · AQUILA-2, AQUILA-3F"), c: 1, ty: 1 },
        { t: qsTr("Quadcopter +"), s: qsTr("4 motors"), c: 1, ty: 0 },
        { t: qsTr("Hexacopter X"), s: qsTr("6 motors"), c: 2, ty: 1 },
        { t: qsTr("Octocopter X"), s: qsTr("8 motors"), c: 3, ty: 1 },
        { t: qsTr("Y6"),           s: qsTr("6 motors, coaxial"), c: 5, ty: 10 },
        { t: qsTr("X8"),           s: qsTr("8 motors, coaxial"), c: 4, ty: 1 }
    ]
    function isCurrent(f) { return f.c === curClass && (f.c === 5 || f.ty === curType) }
    property int chosen: -1
    property bool confirm: false
    property string done: ""

    Column {
        id: col
        width: fr.width
        spacing: SimpleTheme.px(14)
        SText { text: qsTr("Frame"); size: 40; bold: true }
        SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                text: qsTr("The frame type must match the drone. Changing it restarts the drone.") }
        Grid {
            columns: 3; columnSpacing: SimpleTheme.px(14); rowSpacing: SimpleTheme.px(14)
            Repeater {
                model: fr.frames
                Rectangle {
                    readonly property bool cur: fr.isCurrent(modelData)
                    readonly property bool sel: fr.chosen === index
                    width: (col.width - SimpleTheme.px(28)) / 3; height: SimpleTheme.px(150); radius: SimpleTheme.px(18)
                    color: sel ? SimpleTheme.withAlpha(SimpleTheme.brandGreen, 0.25) : SimpleTheme.surfaceRaised
                    border.width: sel || cur ? SimpleTheme.px(3) : 0; border.color: sel ? SimpleTheme.brandGreen : SimpleTheme.ok
                    Column {
                        x: SimpleTheme.px(24); y: SimpleTheme.px(22); width: parent.width - SimpleTheme.px(48)
                        spacing: SimpleTheme.px(6)
                        SIcon { name: "drone"; size: 40 }
                        SText { width: parent.width; text: modelData.t; size: 28; medium: true }
                        SText { width: parent.width; text: modelData.s; size: 20; color: SimpleTheme.textSecondary; elide: Text.ElideRight }
                    }
                    SStatusChip { visible: cur; text: qsTr("Now"); level: "ok"; anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(16); y: SimpleTheme.px(18) }
                    MouseArea { anchors.fill: parent; onClicked: { fr.chosen = cur ? -1 : index; fr.confirm = false } }
                }
            }
        }
        Rectangle {
            width: col.width; height: rCol.height + SimpleTheme.px(32); radius: SimpleTheme.px(18)
            color: SimpleTheme.withAlpha(fr.confirm ? SimpleTheme.danger : SimpleTheme.warn, 0.15)
            Column {
                id: rCol
                x: SimpleTheme.px(24); y: SimpleTheme.px(16); width: parent.width - SimpleTheme.px(48)
                spacing: SimpleTheme.px(12)
                SText { text: qsTr("Restart needed"); size: 28; medium: true }
                SText { width: parent.width; wrapMode: Text.WordWrap; size: 22
                        text: fr.done !== "" ? fr.done
                            : fr.confirm ? qsTr("Change the frame to %1 and restart the drone now? A wrong frame makes the drone flip at take-off.").arg(fr.frames[fr.chosen].t)
                            : qsTr("After choosing another frame the drone restarts and the motors must be tested (Motors).") }
                Row {
                    spacing: SimpleTheme.px(12)
                    SButton { visible: !fr.confirm; kind: "primary"; text: qsTr("Apply and restart"); enabled_: fr.chosen >= 0 && !!fr._veh && !fr._veh.armed
                              onClicked: fr.confirm = true }
                    SButton { visible: fr.confirm; kind: "danger"; text: qsTr("Change and restart")
                              onClicked: {
                                  var f = fr.frames[fr.chosen]
                                  fr.p("FRAME_CLASS").value = f.c
                                  if (f.c !== 5 || fr.p("FRAME_TYPE")) fr.p("FRAME_TYPE").value = f.ty
                                  fr._veh.rebootVehicle()
                                  fr.done = qsTr("Frame saved. The drone restarts; then test each motor in Motors.")
                                  fr.confirm = false; fr.chosen = -1
                              } }
                    SButton { visible: fr.confirm; text: qsTr("Cancel"); onClicked: fr.confirm = false }
                }
            }
        }
    }
}
