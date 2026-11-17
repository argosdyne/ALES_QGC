/****************************************************************************
 * AQGC Simple UI — S66 Settings › Connection › Link security (Figma node 119:39331, 00 Overview §10)
 * How the links to the drone and to online services are protected. Orange = action needed.
 * - Drone control link · MAVLink: MAVLink 2 signing (corePlugin.linkSecurity, src/comm/MAVLinkSigning). The key goes
 *   to the drone only over a USB cable (or a link to this PC, SITL), drone disarmed. Set / change / remove.
 * - Video stream (RTSP): not encrypted (information, blue). RTK correction (NTRIP 1): not encrypted (orange).
 *   Flight zone service (Altitude Angel): HTTPS, certificate checked.
 * Radio password / radio encryption rows come with the radio (Doodle Labs) security work.
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

Column {
    id: ls
    signal backRequested()
    spacing: SimpleTheme.px(16)

    readonly property var  _sec:   QGroundControl.corePlugin.linkSecurity
    readonly property bool _key:   !!_sec && _sec.hasKey
    readonly property int  _state: _sec ? _sec.activeState : -1
    property string confirm: ""            // "" | "set" | "remove"

    // chip for the drone link: no drone / protected / not protected / key mismatch
    readonly property var _chip: _state === 2 ? { t: qsTr("Protected"), l: "ok" }
                               : _state === 3 ? { t: qsTr("Key mismatch"), l: "danger" }
                               : _state < 0   ? { t: _key ? qsTr("Key set") : qsTr("No key"), l: _key ? "info" : "warn" }
                               : { t: qsTr("Not protected"), l: "warn" }
    readonly property string _blockText: !_sec ? ""
        : _sec.pairBlock === "novehicle" ? qsTr("Connect the drone first.")
        : _sec.pairBlock === "armed"     ? qsTr("Land and turn the motors off first.")
        : _sec.pairBlock === "usb"       ? qsTr("Connect the drone with a USB cable to set the key. Over the radio the key would travel unprotected.")
        : ""
    readonly property var _result: !_sec || _sec.result === "" ? null
        : _sec.result === "ok"        ? { t: qsTr("The drone accepted the key. This link is now protected."), l: "ok" }
        : _sec.result === "refused"   ? { t: qsTr("The drone did not accept the key. Check the firmware supports MAVLink signing and try again over USB."), l: "warn" }
        : _sec.result === "reverted"  ? { t: qsTr("The drone did not accept the new key, so the app went back to the old key."), l: "warn" }
        : _sec.result === "removed"   ? { t: qsTr("The key was removed from the drone and from this app."), l: "info" }
        : { t: qsTr("The key was deleted from this app. Paired drones must be paired again."), l: "info" }

    // header: breadcrumb + title + description
    Row {
        spacing: SimpleTheme.px(8)
        SText { text: qsTr("Connection"); size: 24; color: SimpleTheme.textLink
                MouseArea { anchors.fill: parent; anchors.margins: -SimpleTheme.px(12); onClicked: ls.backRequested() } }
        SIcon { name: "chevron"; size: 28; anchors.verticalCenter: parent.verticalCenter }
    }
    SText { text: qsTr("Link security"); size: 40; bold: true }
    SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
            text: qsTr("How the links to the drone and to online services are protected. Orange = not protected.") }

    // ---- drone control link (MAVLink signing)
    Rectangle {
        width: parent.width; height: mavCol.height + SimpleTheme.px(40)
        radius: SimpleTheme.px(20); color: SimpleTheme.surfaceRaised
        Column {
            id: mavCol
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: SimpleTheme.px(20); anchors.leftMargin: SimpleTheme.px(28)
            spacing: SimpleTheme.px(14)
            Item {
                width: parent.width; height: Math.max(SimpleTheme.px(80), mavText.height)
                SIcon { id: mavIcon; name: "link"; size: 40; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    id: mavText
                    anchors.left: mavIcon.right; anchors.leftMargin: SimpleTheme.px(22)
                    anchors.right: mavChip.left; anchors.rightMargin: SimpleTheme.px(16)
                    anchors.verticalCenter: parent.verticalCenter
                    SText { width: parent.width; text: qsTr("Drone control link · MAVLink"); size: 30; medium: true }
                    SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                            text: ls._key ? qsTr("Signed with a key shared by this app and the drone · key %1, set %2").arg(ls._sec.fingerprint).arg(ls._sec.keyDate)
                                          : qsTr("No key yet: anyone on the radio network could send commands to the drone.") }
                }
                SStatusChip { id: mavChip; anchors.right: mavBtn.left; anchors.rightMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                              text: ls._chip.t; level: ls._chip.l }
                SButton {
                    id: mavBtn
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    kind: ls._key ? "secondary" : "primary"
                    text: ls._key ? qsTr("Change key") : qsTr("Set key")
                    enabled_: !!ls._sec && !ls._sec.busy
                    onClicked: ls.confirm = ls.confirm === "" ? "set" : ""
                }
            }
            SText { visible: ls._state === 3; width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textDanger
                    text: qsTr("This drone uses another key and ignores this app's commands. Change or remove its key with the tablet that paired it, or reset the drone's key over USB.") }
            SText { visible: ls._sec && ls._sec.busy; width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                    text: qsTr("Waiting for the drone to answer with the new key…") }
            Rectangle {
                visible: !!ls._result
                width: parent.width; height: resText.height + SimpleTheme.px(24); radius: SimpleTheme.px(14)
                color: ls._result ? SimpleTheme.withAlpha(ls._result.l === "ok" ? SimpleTheme.ok : ls._result.l === "warn" ? SimpleTheme.warn : SimpleTheme.info, 0.18) : "transparent"
                SText { id: resText; anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: SimpleTheme.px(18); anchors.rightMargin: SimpleTheme.px(18)
                        wrapMode: Text.WordWrap; size: 22; text: ls._result ? ls._result.t : "" }
            }
            // set / change / remove (inline, on the ground over USB)
            Column {
                visible: ls.confirm !== ""
                width: parent.width
                spacing: SimpleTheme.px(12)
                Rectangle { width: parent.width; height: 1; color: SimpleTheme.line }
                SText { width: parent.width; wrapMode: Text.WordWrap; size: 24
                        text: ls._key ? qsTr("A new key is sent to this drone and used from now on. Other drones paired with the old key must be paired again.")
                                      : qsTr("A new key is made on this tablet and sent to the drone. From then on the drone only obeys this app (and others with the same key).") }
                SText { visible: ls._blockText !== ""; width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textDanger; text: ls._blockText }
                Row {
                    spacing: SimpleTheme.px(14)
                    SButton { kind: "primary"; text: ls._key ? qsTr("Send a new key") : qsTr("Send the key")
                              enabled_: !!ls._sec && ls._sec.pairBlock === "" && !ls._sec.busy
                              onClicked: { ls.confirm = ""; ls._sec.pair() } }
                    SButton { visible: ls._key; kind: "danger"; text: qsTr("Remove key")
                              enabled_: !!ls._sec && ls._sec.pairBlock === "" && !ls._sec.busy
                              onClicked: { ls.confirm = ""; ls._sec.removeKey() } }
                    SButton { text: qsTr("Cancel"); onClicked: ls.confirm = "" }
                }
            }
        }
    }

    // ---- other links (information)
    Repeater {
        model: [
            { icon: "video", t: qsTr("Video stream · RTSP"), s: qsTr("Camera video is not encrypted between the drone and this app"), c: qsTr("Not encrypted"), l: "info" },
            { icon: "gps",   t: qsTr("RTK correction · NTRIP"), s: qsTr("User name and password are sent without encryption (NTRIP 1)"), c: qsTr("Not encrypted"), l: "warn" },
            { icon: "map",   t: qsTr("Flight zone service · Altitude Angel"), s: qsTr("HTTPS · server certificate checked"), c: qsTr("Protected"), l: "ok" }
        ]
        Rectangle {
            width: ls.width; height: Math.max(SimpleTheme.px(104), infoText.height + SimpleTheme.px(36))
            radius: SimpleTheme.px(20); color: SimpleTheme.surfaceRaised
            SIcon { id: infoIcon; name: modelData.icon; size: 40; anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(28); anchors.verticalCenter: parent.verticalCenter }
            Column {
                id: infoText
                anchors.left: infoIcon.right; anchors.leftMargin: SimpleTheme.px(22)
                anchors.right: infoChip.left; anchors.rightMargin: SimpleTheme.px(16)
                anchors.verticalCenter: parent.verticalCenter
                SText { width: parent.width; text: modelData.t; size: 30; medium: true }
                SText { width: parent.width; wrapMode: Text.WordWrap; text: modelData.s; size: 22; color: SimpleTheme.textSecondary }
            }
            SStatusChip { id: infoChip; anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(28); anchors.verticalCenter: parent.verticalCenter
                          text: modelData.c; level: modelData.l }
        }
    }
}
