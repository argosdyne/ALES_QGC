/****************************************************************************
 * AQGC Simple UI — S39 check before sending (red = blocked, orange = caution)
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import QGroundControl.FactSystem 1.0
import "."

SPanel {
    id: chk
    property var  vs
    property var  plan
    property var  survey
    property real maxAlt: 120
    closable: false
    title: qsTr("Check before sending")

    readonly property var  _mission:    plan ? plan.missionController : null
    readonly property real _alt:        survey && survey.cameraCalc ? survey.cameraCalc.distanceToSurface.rawValue : 0
    readonly property real _maxDist:    _mission ? _mission.missionMaxTelemetry : 0
    readonly property int  _batteries:  _mission ? _mission.batteriesRequired : -1
    property bool _sent: false

    // FactPanelController binds to the active vehicle when it is created, so create it only once
    // the vehicle's parameters are ready (and again for a new vehicle).
    Loader { id: fpcLoader; visible: false; active: vs.paramsReady; sourceComponent: Component { FactPanelController { } } }
    readonly property string _fenceName: vs.present && vs.vehicle.apmFirmware ? "FENCE_RADIUS" : "GF_MAX_HOR_DIST"
    readonly property var _fenceRad: fpcLoader.item && fpcLoader.item.parameterExists(-1, _fenceName)
                                     ? fpcLoader.item.getParameterFact(-1, _fenceName, false) : null
    readonly property real _distLimit: _fenceRad && _fenceRad.rawValue > 0 ? _fenceRad.rawValue : 500

    // level: 0 ok, 1 caution, 2 blocked
    readonly property var _checks: [
        { lvl: _alt > maxAlt ? 2 : 0, t: qsTr("Height"), d: qsTr("%1 m (limit %2 m)").arg(Math.round(_alt)).arg(maxAlt) },
        { lvl: _maxDist > _distLimit ? 2 : 0, t: qsTr("Distance"), d: qsTr("Farthest point %1 m (limit %2 m)").arg(Math.round(_maxDist)).arg(Math.round(_distLimit)) },
        { lvl: _batteries > 1 ? 1 : 0, t: qsTr("Battery"), d: _batteries > 1 ? qsTr("Needs %1 batteries — the drone returns to swap").arg(_batteries) : _batteries === 1 ? qsTr("Fits one battery") : qsTr("Not estimated for this drone") },
        { lvl: 1, t: qsTr("Flight zones"), d: qsTr("Check the zones on the map yourself") },
        { lvl: vs.connected ? 0 : 2, t: qsTr("Drone"), d: vs.connected ? qsTr("Connected") : qsTr("Not connected — the mission stays on this tablet") }
    ]
    readonly property bool _blocked: { for (var i = 0; i < _checks.length; i++) if (_checks[i].lvl === 2) return true; return false }

    onVisibleChanged: if (visible) _sent = false
    Connections {
        target: chk.plan
        function onSyncInProgressChanged() { if (chk.plan && !chk.plan.syncInProgress && chk.visible) chk._sent = true }
    }

    Column {
        anchors.fill: parent
        spacing: SimpleTheme.px(10)
        Repeater {
            model: chk._checks
            Rectangle {
                width: parent.width; height: SimpleTheme.px(92); radius: SimpleTheme.px(16)
                color: modelData.lvl === 0 ? SimpleTheme.surfaceRaised : modelData.lvl === 1 ? SimpleTheme.withAlpha(SimpleTheme.warn, 0.14) : SimpleTheme.withAlpha(SimpleTheme.danger, 0.16)
                border.width: modelData.lvl === 0 ? 0 : SimpleTheme.px(2)
                border.color: modelData.lvl === 1 ? SimpleTheme.warn : SimpleTheme.danger
                SIcon {
                    id: ic
                    anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                    name: modelData.lvl === 0 ? "check" : "warn"; size: 36
                    color: modelData.lvl === 0 ? SimpleTheme.ok : modelData.lvl === 1 ? SimpleTheme.warn : SimpleTheme.textDanger
                }
                Column {
                    anchors.left: ic.right; anchors.leftMargin: SimpleTheme.px(14); anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(12)
                    anchors.verticalCenter: parent.verticalCenter
                    SText { width: parent.width; text: modelData.t; size: 26; medium: true }
                    SText { width: parent.width; text: modelData.d; size: 22; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                }
            }
        }
    }

    Column {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: SimpleTheme.px(28)
        spacing: SimpleTheme.px(10)
        SText {
            visible: chk.plan && chk.plan.syncInProgress
            text: qsTr("Sending to drone… %1 %").arg(chk.plan && chk._mission ? Math.round(chk._mission.progressPct * 100) : 0)
            size: 24; medium: true; color: SimpleTheme.textSecondary
        }
        Rectangle {
            visible: chk.plan && chk.plan.syncInProgress
            width: parent.width; height: SimpleTheme.px(14); radius: height / 2; color: SimpleTheme.surfaceControl
            Rectangle { width: parent.width * (chk._mission ? chk._mission.progressPct : 0); height: parent.height; radius: height / 2; color: SimpleTheme.brandGreen }
        }
        SText { visible: chk._blocked && !chk._sent; width: parent.width; wrapMode: Text.WordWrap; text: qsTr("Fix the red items before sending."); size: 22; color: SimpleTheme.textDanger }
        SButton {
            width: parent.width
            kind: "primary"
            visible: !chk._sent
            enabled_: !chk._blocked && chk.plan && !chk.plan.syncInProgress
            text: qsTr("Send to drone")
            onClicked: chk.plan.sendToVehicle()
        }
        SButton {
            width: parent.width
            kind: "primary"
            visible: chk._sent
            icon: "map"
            text: qsTr("Sent — go to Fly")
            onClicked: simpleRoot.showFly()
        }
    }
}
