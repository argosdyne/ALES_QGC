/****************************************************************************
 * AQGC Simple UI — S68 Vehicle setup › Firmware (Figma 119:39511, 2026-11-18). PC only, USB.
 * No internet download: only a file chosen on this PC (.apj). Install = classic FirmwareUpgradeController flow:
 * board search → the user unplugs and plugs the USB cable → showFirmwareSelectDlg → flashFirmwareUrl(file).
 * The company does not sign firmware yet (user 2026-11-17): the signature and the "no downgrade" checks are shown as
 * "not checked yet" and must be added (company public key, signed .apj, version in the file) when the firmware team
 * signs releases. Every install attempt goes to the security log. Works without a drone connection.
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import QGroundControl.Controls 1.0
import QGroundControl.Controllers 1.0
import "."

Flickable {
    id: fw
    contentHeight: col.height
    clip: true

    readonly property var    _veh: QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool   desktop: Qt.platform.os !== "android" && Qt.platform.os !== "ios"
    property string file: ""                 // chosen firmware file (local path)
    property string phase: ""                // "" | replug | flashing | done | failed
    readonly property string fileName: file.split("/").pop()

    function log(text) { var pd = QGroundControl.corePlugin.privacyData; if (pd) pd.logEvent("Firmware", text) }
    function install() {
        statusLog.clear(); progress.value = 0
        phase = "replug"
        log("Install started: " + fileName)
        if (_veh) _veh.vehicleLinkManager.autoDisconnect = true
        ctlLoader.item.startBoardSearch()
    }

    Loader {
        id: ctlLoader
        active: fw.desktop && fw.phase !== ""
        sourceComponent: FirmwareUpgradeController {
            progressBar: progress
            statusLog: statusLog
            onShowFirmwareSelectDlg: { fw.phase = "flashing"; flashFirmwareUrl(fw.file) }
            onFlashComplete: { fw.phase = "done"; fw.log("Installed: " + fw.fileName) }
            onError: { fw.phase = "failed"; fw.log("Install failed: " + fw.fileName) }
            onFlashCancelled: fw.phase = ""
        }
    }
    readonly property var ctl: ctlLoader.item

    QGCFileDialog {
        id: fileDialog
        title: qsTr("Choose a firmware file")
        nameFilters: [qsTr("Firmware files (*.apj)")]
        selectExisting: true
        folder: String(QGroundControl.settingsManager.appSettings.savePath.rawValue)
        onAcceptedForLoad: { fw.file = file; fw.phase = ""; close() }
    }

    Column {
        id: col
        width: fw.width
        spacing: SimpleTheme.px(12)
        SText { text: qsTr("Firmware"); size: 40; bold: true }
        SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                text: fw.desktop ? qsTr("Connect the drone with USB, propellers off. Only firmware from ARGOSDYNE support can be installed.")
                                 : qsTr("Firmware is updated from a PC with a USB cable.") }

        // installed
        Rectangle {
            width: col.width; height: SimpleTheme.px(100); radius: SimpleTheme.px(18); color: SimpleTheme.surfaceRaised
            SIcon { id: i1; name: "check"; size: 36; anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(24); anchors.verticalCenter: parent.verticalCenter }
            Column {
                anchors.left: i1.right; anchors.leftMargin: SimpleTheme.px(20); anchors.right: c1.left; anchors.rightMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                SText { width: parent.width; size: 28; medium: true
                        text: fw._veh ? qsTr("Installed · %1 %2.%3.%4").arg(fw._veh.firmwareTypeString).arg(fw._veh.firmwareMajorVersion).arg(fw._veh.firmwareMinorVersion).arg(fw._veh.firmwarePatchVersion)
                                      : qsTr("Installed · drone not connected") }
                SText { width: parent.width; size: 22; color: SimpleTheme.textSecondary; text: qsTr("Signature check on the drone (secure boot): not set up yet") }
            }
            SStatusChip { id: c1; anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(24); anchors.verticalCenter: parent.verticalCenter
                          text: qsTr("Not checked"); level: "info" }
        }
        // update file
        Rectangle {
            visible: fw.desktop
            width: col.width; height: Math.max(SimpleTheme.px(100), t2.height + SimpleTheme.px(28)); radius: SimpleTheme.px(18); color: SimpleTheme.surfaceRaised
            SIcon { id: i2; name: "download"; size: 36; anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(24); anchors.verticalCenter: parent.verticalCenter }
            Column {
                id: t2
                anchors.left: i2.right; anchors.leftMargin: SimpleTheme.px(20); anchors.right: r2.left; anchors.rightMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                SText { width: parent.width; size: 28; medium: true; elide: Text.ElideMiddle
                        text: fw.file !== "" ? qsTr("Update file · %1").arg(fw.fileName) : qsTr("No update file chosen") }
                SText { width: parent.width; size: 22; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap
                        text: fw.file !== "" ? qsTr("Signature and version are not checked yet: install only files from ARGOSDYNE support.")
                                             : qsTr("Get the file from ARGOSDYNE support, then choose it here.") }
            }
            Row {
                id: r2
                anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                spacing: SimpleTheme.px(12)
                SStatusChip { visible: fw.file !== ""; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Signature not checked"); level: "warn" }
                SButton { visible: fw.file !== ""; objectName: "fwInstall"; designHeight: 72; textSize: 24; kind: "primary"; icon: "download"; text: qsTr("Install")
                          enabled_: fw.phase === "" || fw.phase === "done" || fw.phase === "failed"
                          onClicked: fw.install() }
            }
        }
        // older versions
        Rectangle {
            visible: fw.desktop
            width: col.width; height: SimpleTheme.px(100); radius: SimpleTheme.px(18); color: SimpleTheme.surfaceRaised
            SIcon { id: i3; name: "lock"; size: 36; anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(24); anchors.verticalCenter: parent.verticalCenter }
            Column {
                anchors.left: i3.right; anchors.leftMargin: SimpleTheme.px(20); anchors.right: c3.left; anchors.rightMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                SText { width: parent.width; size: 28; medium: true; text: qsTr("Older versions") }
                SText { width: parent.width; size: 22; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap
                        text: qsTr("Blocked once the firmware files carry a signed version number") }
            }
            SStatusChip { id: c3; anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(24); anchors.verticalCenter: parent.verticalCenter
                          text: qsTr("Not checked yet"); level: "info" }
        }
        SButton { visible: fw.desktop; objectName: "fwChoose"; designHeight: 72; textSize: 24; icon: "folder"; text: qsTr("Choose file…")
                  enabled_: fw.phase !== "replug" && fw.phase !== "flashing"
                  onClicked: fileDialog.openForLoad() }

        // install progress
        Rectangle {
            visible: fw.phase !== ""
            width: col.width; height: pc.height + SimpleTheme.px(40); radius: SimpleTheme.px(18); color: SimpleTheme.surfaceRaised
            Column {
                id: pc
                x: SimpleTheme.px(24); y: SimpleTheme.px(20); width: parent.width - SimpleTheme.px(48)
                spacing: SimpleTheme.px(14)
                SText { width: parent.width; size: 28; medium: true; wrapMode: Text.WordWrap
                        text: fw.phase === "replug" ? qsTr("Unplug the USB cable, wait 2 seconds and plug it in again.")
                            : fw.phase === "flashing" ? qsTr("Installing. Do not unplug the drone.")
                            : fw.phase === "done" ? qsTr("Firmware installed. The drone restarts.")
                            : qsTr("Install failed. Plug the drone straight into a USB port of the PC (no hub) and try again.") }
                Item {
                    id: progress
                    property real value: 0
                    width: parent.width; height: SimpleTheme.px(16)
                    Rectangle { anchors.fill: parent; radius: height / 2; color: SimpleTheme.surfaceControl }
                    Rectangle { width: parent.width * Math.max(0, Math.min(1, progress.value)); height: parent.height; radius: height / 2; color: SimpleTheme.brandGreen }
                }
                Item {
                    id: statusLog
                    width: parent.width; height: logCol.height
                    property var lines: []
                    function append(text) { var l = lines.slice(); l.push(String(text).replace(/<[^>]*>/g, "")); if (l.length > 6) l.shift(); lines = l; return true }
                    function clear() { lines = [] }
                    Column { id: logCol; width: parent.width
                             Repeater { model: statusLog.lines
                                        SText { width: statusLog.width; text: modelData; size: 20; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap } } }
                }
                SButton { visible: fw.phase === "replug"; designHeight: 64; textSize: 22; text: qsTr("Cancel")
                          onClicked: { if (fw.ctl) fw.ctl.cancel(); fw.phase = ""; fw.log("Install cancelled: " + fw.fileName) } }
            }
        }
        SNotice { visible: fw.desktop; level: "warn"
                  text: qsTr("Do not unplug the drone while installing. If the power is lost, plug it in again and install once more.") }
    }
}
