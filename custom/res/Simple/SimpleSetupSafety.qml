/****************************************************************************
 * AQGC Simple UI — S75 Vehicle setup › Safety, all failsafes (Figma 128:39889, 2026-11-17).
 * Battery (two levels), controller signal, ground station link, navigation (EKF), geofence (circle / ceiling),
 * pre-arm checks, crash check. A row opens its values in place; an action of 0 ("none" / disabled) is orange.
 * Pre-arm checks = S84 sheet (SimplePrearmChecks.qml, ARMING_CHECK bitmask).
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import QGroundControl.FactSystem 1.0
import QGroundControl.Controllers 1.0
import "."

Flickable {
    id: sf
    contentHeight: col.height
    clip: true
    FactPanelController { id: fpc }
    function p(n) { return fpc.parameterExists(-1, n) ? fpc.getParameterFact(-1, n, false) : null }
    function v(n) { var f = p(n); return f ? f.valueString + (f.units !== "" ? " " + f.units : "") : "—" }
    function e(n) { var f = p(n); return f ? f.enumOrValueString : "—" }
    function off(n) { var f = p(n); return !!f && Number(f.rawValue) === 0 }
    property string open: ""

    readonly property var rows: [
        { key: "low",   t: qsTr("Low battery"),       s: qsTr("%1 or %2 left").arg(v("BATT_LOW_VOLT")).arg(v("BATT_LOW_MAH")),
          act: "BATT_FS_LOW_ACT", facts: ["BATT_LOW_VOLT", "BATT_LOW_MAH", "BATT_FS_LOW_ACT"] },
        { key: "crt",   t: qsTr("Critical battery"),  s: qsTr("%1 or %2 left").arg(v("BATT_CRT_VOLT")).arg(v("BATT_CRT_MAH")),
          act: "BATT_FS_CRT_ACT", facts: ["BATT_CRT_VOLT", "BATT_CRT_MAH", "BATT_FS_CRT_ACT"] },
        { key: "thr",   t: qsTr("Controller signal lost"), s: qsTr("Throttle below %1").arg(v("FS_THR_VALUE")),
          act: "FS_THR_ENABLE", facts: ["FS_THR_ENABLE", "FS_THR_VALUE"] },
        { key: "gcs",   t: qsTr("Ground station link lost"), s: p("FS_GCS_TIMEOUT") ? qsTr("After %1 without the app").arg(v("FS_GCS_TIMEOUT")) : qsTr("When the app link is lost"),
          act: "FS_GCS_ENABLE", facts: ["FS_GCS_ENABLE", "FS_GCS_TIMEOUT"] },
        { key: "ekf",   t: qsTr("Navigation error (EKF)"), s: qsTr("Position estimate is not good"),
          act: "FS_EKF_ACTION", facts: ["FS_EKF_ACTION", "FS_EKF_THRESH"] },
        { key: "fence", t: qsTr("Geofence"), s: off("FENCE_ENABLE") ? qsTr("Off") : qsTr("Circle %1 · ceiling %2").arg(v("FENCE_RADIUS")).arg(v("FENCE_ALT_MAX")),
          act: "FENCE_ACTION", actOff: "FENCE_ENABLE", facts: ["FENCE_ENABLE", "FENCE_RADIUS", "FENCE_ALT_MAX", "FENCE_ACTION"] },
        { key: "arm",   t: qsTr("Pre-arm checks"), s: qsTr("The drone refuses to start when a check fails"), arm: true },
        { key: "crash", t: qsTr("Crash check"), s: qsTr("Stops the motors after a crash"),
          act: "FS_CRASH_CHECK", facts: ["FS_CRASH_CHECK"] }
    ]

    Column {
        id: col
        width: sf.width
        spacing: SimpleTheme.px(12)
        SText { text: qsTr("Safety"); size: 40; bold: true }
        SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                text: qsTr("All failsafe settings. Settings › Safety shows the main ones in plain words.") }
        Repeater {
            model: sf.rows
            Rectangle {
                readonly property bool _noProtect: modelData.arm ? false : (modelData.actOff ? sf.off(modelData.actOff) : sf.off(modelData.act))
                // pre-arm: the company reference is "normal" (SimpleReference, user 2026-11-18)
                readonly property bool _allChecks: !!sf.p("ARMING_CHECK") && SimpleReference.armingMissing(sf.p("ARMING_CHECK").rawValue, sf.p("ARMING_CHECK").bitmaskValues) === 0
                readonly property bool _noChecks: !!sf.p("ARMING_CHECK") && Number(sf.p("ARMING_CHECK").rawValue) === 0
                width: col.width; height: rc.height + SimpleTheme.px(28); radius: SimpleTheme.px(18)
                color: SimpleTheme.surfaceRaised
                Column {
                    id: rc
                    x: SimpleTheme.px(24); y: SimpleTheme.px(14); width: parent.width - SimpleTheme.px(48)
                    spacing: SimpleTheme.px(10)
                    Item {
                        width: parent.width; height: Math.max(SimpleTheme.px(64), rt.height)
                        Column {
                            id: rt
                            anchors.left: parent.left; anchors.right: chip.left; anchors.rightMargin: SimpleTheme.px(14)
                            anchors.verticalCenter: parent.verticalCenter
                            SText { width: parent.width; text: modelData.t; size: 28; medium: true }
                            SText { width: parent.width; text: modelData.s; size: 22; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap }
                        }
                        SStatusChip {
                            id: chip
                            anchors.right: btn.left; anchors.rightMargin: SimpleTheme.px(14); anchors.verticalCenter: parent.verticalCenter
                            text: modelData.arm ? (parent.parent.parent._allChecks ? (Number(sf.p("ARMING_CHECK").rawValue) & 1 ? qsTr("All on") : qsTr("Company setting")) : parent.parent.parent._noChecks ? qsTr("None") : qsTr("Some off"))
                                : parent.parent.parent._noProtect ? qsTr("No protection") : sf.e(modelData.act)
                            level: modelData.arm ? (parent.parent.parent._allChecks ? "ok" : parent.parent.parent._noChecks ? "danger" : "warn") : parent.parent.parent._noProtect ? "warn" : "info"
                        }
                        SButton { id: btn; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; designHeight: 64; textSize: 22
                                  objectName: "safetyChange_" + modelData.key
                                  text: modelData.arm ? qsTr("Change") : sf.open === modelData.key ? qsTr("Close") : qsTr("Change")
                                  onClicked: modelData.arm ? prearm.open() : (sf.open = sf.open === modelData.key ? "" : modelData.key) }
                    }
                    Column {
                        visible: sf.open === modelData.key
                        width: parent.width
                        spacing: SimpleTheme.px(8)
                        Repeater {
                            model: sf.open === modelData.key && modelData.facts ? modelData.facts : []
                            Item {
                                readonly property var f: sf.p(modelData)
                                visible: !!f
                                width: rc.width; height: Math.max(SimpleTheme.px(84), fld.height + SimpleTheme.px(8))
                                Column {
                                    anchors.left: parent.left; anchors.right: fld.left; anchors.rightMargin: SimpleTheme.px(14); anchors.verticalCenter: parent.verticalCenter
                                    SText { width: parent.width; text: f ? f.shortDescription : ""; size: 22; wrapMode: Text.WordWrap }
                                    SText { width: parent.width; text: modelData; size: 18; color: SimpleTheme.textTertiary }
                                }
                                SFactField { id: fld; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; fact: f; designWidth: 460 }
                            }
                        }
                    }
                }
            }
        }
    }

    //================================================================== S84 Pre-arm checks
    SimplePrearmChecks {
        id: prearm
        fact: sf.p("ARMING_CHECK")
        armed: !!QGroundControl.multiVehicleManager.activeVehicle && QGroundControl.multiVehicleManager.activeVehicle.armed
    }
}
