/****************************************************************************
 * AQGC Simple UI — S78 Fly › More actions (Advanced mode, Figma 129:39962, 2026-11-17).
 * Arm motors (on the ground only, no take-off: service / tests), Emergency stop (hold 3 s, motors off at once — the
 * drone falls), Change speed, Set home here, Messages (raw flight controller text). Every action goes through the
 * classic GuidedActionsController (executeAction), as in the classic fly view.
 * S96 (Figma 169:45516, 2026-11-18): Custom actions from the file set in Settings › Fly screen (CustomActionManager,
 * same as the classic action list); each button asks once, then CustomAction.sendTo(vehicle).
 ****************************************************************************/
import QtQuick 2.12
import QtPositioning 5.12
import QGroundControl 1.0
import QGroundControl.Controllers 1.0
import "."

SPanel {
    id: more
    property var vs
    property var guided: null
    readonly property var _veh: vs ? vs.vehicle : null
    title: qsTr("More actions")
    width: SimpleTheme.px(720)
    height: Math.min(SimpleTheme.px(880), col.height + SimpleTheme.px(130))
    property string open: ""            // "" | arm | speed | home | custom | messages
    property int    customAsk: -1       // custom action waiting for "Send"
    property real   speed: 5
    onVisibleChanged: { open = ""; customAsk = -1 }

    CustomActionManager { id: customManager }
    readonly property bool hasCustom: !!QGroundControl.settingsManager.flyViewSettings.enableCustomActions.rawValue && customManager.hasActions

    function act(code, data, value) { if (guided) guided.executeAction(code, data === undefined ? null : data, value === undefined ? 0 : value, false) }

    Flickable {
        anchors.fill: parent
        clip: true
        contentHeight: col.height
        Column {
            id: col
            width: parent.width
            spacing: SimpleTheme.px(10)

            // Arm motors (ground only)
            Rectangle {
                width: col.width; height: armCol.height + SimpleTheme.px(28); radius: SimpleTheme.px(18); color: SimpleTheme.surfaceRaised
                opacity: !!more._veh && !more._veh.armed && !!more.guided && more.guided.showArm ? 1 : 0.45
                Column {
                    id: armCol
                    x: SimpleTheme.px(24); y: SimpleTheme.px(14); width: parent.width - SimpleTheme.px(48)
                    spacing: SimpleTheme.px(10)
                    SText { text: qsTr("Arm motors"); size: 28; medium: true }
                    SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                            text: qsTr("On the ground only · motors spin at idle") }
                    SHoldButton {
                        width: parent.width; designHeight: 76; holdMs: 1500; fillColor: SimpleTheme.warn
                        text: qsTr("Hold to arm")
                        enabled_: !!more._veh && !more._veh.armed && !!more.guided && more.guided.showArm
                        onActivated: more.act(more.guided.actionArm)
                    }
                }
            }
            // Emergency stop
            Rectangle {
                width: col.width; height: esCol.height + SimpleTheme.px(28); radius: SimpleTheme.px(18)
                color: SimpleTheme.withAlpha(SimpleTheme.danger, 0.15); border.width: SimpleTheme.px(2); border.color: SimpleTheme.danger
                Column {
                    id: esCol
                    x: SimpleTheme.px(24); y: SimpleTheme.px(14); width: parent.width - SimpleTheme.px(48)
                    spacing: SimpleTheme.px(10)
                    SText { text: qsTr("Emergency stop"); size: 28; medium: true; color: SimpleTheme.textDanger }
                    SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textDanger
                            text: qsTr("Motors off at once — the drone falls. Hold 3 s.") }
                    SHoldButton {
                        objectName: "emergencyStop"
                        width: parent.width; designHeight: 76; holdMs: 3000
                        text: qsTr("Hold 3 s to stop the motors")
                        enabled_: !!more._veh && more._veh.armed
                        onActivated: more.act(more.guided.actionEmergencyStop)
                    }
                }
            }
            // Change speed
            Rectangle {
                width: col.width; height: spCol.height + SimpleTheme.px(28); radius: SimpleTheme.px(18); color: SimpleTheme.surfaceRaised
                readonly property bool can: !!more.guided && more.guided.showChangeSpeed
                opacity: can ? 1 : 0.45
                Column {
                    id: spCol
                    x: SimpleTheme.px(24); y: SimpleTheme.px(14); width: parent.width - SimpleTheme.px(48)
                    spacing: SimpleTheme.px(10)
                    SText { text: qsTr("Change speed"); size: 28; medium: true }
                    SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                            text: parent.parent.can ? qsTr("Horizontal speed for this flight") : qsTr("In flight, not during a mission") }
                    Row {
                        visible: parent.parent.can
                        spacing: SimpleTheme.px(14)
                        readonly property real maxSpeed: more._veh && more._veh.haveMRSpeedLimits ? more._veh.maximumHorizontalSpeedMultirotor() : 15
                        SStepper { value: more.speed; from: 0.5; to: parent.maxSpeed; step: 0.5; decimals: 1; unit: "m/s"; onEdited: more.speed = value }
                        SButton { kind: "primary"; designHeight: 76; text: qsTr("Apply")
                                  onClicked: more.act(more.guided.actionChangeSpeed, null, QGroundControl.unitsConversion.metersSecondToAppSettingsSpeedUnits(more.speed)) }
                    }
                }
            }
            // Set home here
            Rectangle {
                width: col.width; height: hmCol.height + SimpleTheme.px(28); radius: SimpleTheme.px(18); color: SimpleTheme.surfaceRaised
                readonly property bool can: !!more.guided && more.guided.showSetHome && !!more._veh && more._veh.coordinate.isValid
                opacity: can ? 1 : 0.45
                Column {
                    id: hmCol
                    x: SimpleTheme.px(24); y: SimpleTheme.px(14); width: parent.width - SimpleTheme.px(48)
                    spacing: SimpleTheme.px(10)
                    SText { text: qsTr("Set home here"); size: 28; medium: true }
                    SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                            text: qsTr("Return home goes to the drone's position now") }
                    Row {
                        spacing: SimpleTheme.px(12)
                        SButton { visible: more.open !== "home"; designHeight: 72; textSize: 24; text: qsTr("Set home here…"); enabled_: parent.parent.parent.can; onClicked: more.open = "home" }
                        SButton { visible: more.open === "home"; designHeight: 72; textSize: 24; kind: "primary"; text: qsTr("Set home")
                                  onClicked: { var c = more._veh.coordinate; more.act(more.guided.actionSetHome, QtPositioning.coordinate(c.latitude, c.longitude, c.altitude)); more.open = "" } }
                        SButton { visible: more.open === "home"; designHeight: 72; textSize: 24; text: qsTr("Cancel"); onClicked: more.open = "" }
                    }
                }
            }
            // Custom actions (S96)
            Rectangle {
                visible: more.hasCustom
                width: col.width; height: visible ? caCol.height + SimpleTheme.px(28) : 0; radius: SimpleTheme.px(18); color: SimpleTheme.surfaceRaised
                Column {
                    id: caCol
                    x: SimpleTheme.px(24); y: SimpleTheme.px(14); width: parent.width - SimpleTheme.px(48)
                    spacing: SimpleTheme.px(10)
                    Item {
                        width: parent.width; height: SimpleTheme.px(64)
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            SText { text: qsTr("Custom actions"); size: 28; medium: true }
                            SText { text: qsTr("From the actions file · %n button(s)", "", customManager.actions.count); size: 22; color: SimpleTheme.textSecondary }
                        }
                        SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; designHeight: 64; textSize: 22
                                  text: more.open === "custom" ? qsTr("Close") : qsTr("Show")
                                  onClicked: { more.customAsk = -1; more.open = more.open === "custom" ? "" : "custom" } }
                    }
                    Flow {
                        visible: more.open === "custom"
                        width: parent.width
                        spacing: SimpleTheme.px(12)
                        Repeater {
                            model: customManager.actions
                            SButton {
                                designHeight: 64; textSize: 22
                                text: object.label
                                enabled_: !!more._veh
                                kind: more.customAsk === index ? "primary" : "secondary"
                                onClicked: if (enabled_) more.customAsk = index
                            }
                        }
                    }
                    Rectangle {
                        visible: more.open === "custom" && more.customAsk >= 0
                        width: parent.width; height: askCol.height + SimpleTheme.px(24); radius: SimpleTheme.px(14)
                        color: SimpleTheme.withAlpha(SimpleTheme.warn, 0.18)
                        Column {
                            id: askCol
                            x: SimpleTheme.px(16); y: SimpleTheme.px(12); width: parent.width - SimpleTheme.px(32)
                            spacing: SimpleTheme.px(10)
                            SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; medium: true
                                    text: more.customAsk >= 0 && more.customAsk < customManager.actions.count
                                          ? qsTr("Send “%1” to the drone now?").arg(customManager.actions.get(more.customAsk).label) : "" }
                            Row {
                                spacing: SimpleTheme.px(12)
                                SButton { designHeight: 60; textSize: 22; text: qsTr("Cancel"); onClicked: more.customAsk = -1 }
                                SButton { designHeight: 60; textSize: 22; kind: "primary"; text: qsTr("Send"); enabled_: !!more._veh
                                          onClicked: {
                                              if (!enabled_ || more.customAsk < 0) return
                                              customManager.actions.get(more.customAsk).sendTo(more._veh)
                                              more.customAsk = -1
                                          } }
                            }
                        }
                    }
                }
            }
            // Messages (raw)
            Rectangle {
                width: col.width; height: msgCol.height + SimpleTheme.px(28); radius: SimpleTheme.px(18); color: SimpleTheme.surfaceRaised
                Column {
                    id: msgCol
                    x: SimpleTheme.px(24); y: SimpleTheme.px(14); width: parent.width - SimpleTheme.px(48)
                    spacing: SimpleTheme.px(10)
                    Item {
                        width: parent.width; height: SimpleTheme.px(64)
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            SText { text: qsTr("Messages (raw)"); size: 28; medium: true }
                            SText { text: qsTr("Flight controller messages as sent"); size: 22; color: SimpleTheme.textSecondary }
                        }
                        SButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; designHeight: 64; textSize: 22
                                  text: more.open === "messages" ? qsTr("Close") : qsTr("Show"); onClicked: more.open = more.open === "messages" ? "" : "messages" }
                    }
                    Rectangle {
                        visible: more.open === "messages"
                        width: parent.width; height: SimpleTheme.px(360); radius: SimpleTheme.px(12); color: SimpleTheme.bgBase
                        Flickable {
                            anchors.fill: parent; anchors.margins: SimpleTheme.px(12)
                            clip: true; contentHeight: rawText.height
                            Text {
                                id: rawText
                                width: parent.width
                                textFormat: Text.RichText
                                wrapMode: Text.WrapAnywhere
                                color: SimpleTheme.textSecondary
                                font.family: "Roboto Mono"; font.pixelSize: SimpleTheme.fs(18)
                                text: more._veh ? more._veh.formattedMessages : ""
                            }
                        }
                    }
                }
            }
        }
    }
}
