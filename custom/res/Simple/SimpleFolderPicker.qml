/****************************************************************************
 * AQGC Simple UI — S90 Settings › Data & logs › Save folder (Figma 160:43332, 2026-11-18). Desktop only (the row is
 * hidden on mobile, as in the classic General page). Path bar (tap a part to go there; "This PC" = drive list), Up,
 * folders by name (FolderListModel, no files), New folder, free space. "Use" writes appSettings.savePath; the app
 * makes its sub-folders. Files in the old folder are not moved. Folder helpers: corePlugin.privacyData (C++).
 ****************************************************************************/
import QtQuick 2.12
import Qt.labs.folderlistmodel 2.12
import QGroundControl 1.0
import "."

SSheet {
    id: fp
    title: qsTr("Save folder")
    subtitle: qsTr("Logs, missions, parameters and photos are saved in folders inside this one. Files already saved stay where they are.")
    designWidth: 1000
    closeOnOutside: true

    property var    fact: null              // appSettings.savePath
    property string dir: ""                 // "" = drive list
    property string picked: ""              // highlighted sub-folder
    property bool   naming: false
    property string newName: ""
    property string error: ""
    readonly property var pd: QGroundControl.corePlugin.privacyData
    readonly property var info: pd && dir !== "" ? pd.folderInfo(dir) : ({})
    readonly property string target: picked !== "" ? picked : dir
    readonly property var targetInfo: pd && target !== "" ? pd.folderInfo(target) : ({})

    function go(path) { dir = path; picked = ""; naming = false; error = "" }
    function openAt(path) {
        var p = String(path || "")
        go(pd && p !== "" && pd.folderInfo(p).exists ? p : (pd ? pd.drives()[0] || "" : ""))
        open()
    }
    function crumbs() {
        if (dir === "") return []
        var parts = dir.split("/").filter(function(x) { return x !== "" }), r = [], acc = dir.charAt(0) === "/" ? "" : ""
        for (var i = 0; i < parts.length; i++) {
            acc = i === 0 ? (dir.charAt(0) === "/" ? "/" + parts[0] : parts[0] + "/") : (acc.charAt(acc.length - 1) === "/" ? acc : acc + "/") + parts[i]
            r.push({ t: parts[i], p: acc })
        }
        return r
    }
    function fmtFree(b) { return b < 0 ? "" : b >= 1e9 ? qsTr("Free: %1 GB").arg((b / 1e9).toFixed(0)) : qsTr("Free: %1 MB").arg((b / 1e6).toFixed(0)) }

    FolderListModel {
        id: folders
        folder: fp.dir === "" ? "" : (fp.dir.charAt(0) === "/" ? "file://" : "file:///") + fp.dir
        showFiles: false; showDirs: true; showDotAndDotDot: false; showHidden: false
        sortField: FolderListModel.Name
    }

    // path bar
    Rectangle {
        width: fp.innerWidth; height: SimpleTheme.px(60); radius: SimpleTheme.px(16); color: SimpleTheme.surfaceControl
        Flickable {
            anchors.fill: parent; anchors.leftMargin: SimpleTheme.px(20); anchors.rightMargin: SimpleTheme.px(20)
            contentWidth: crumbRow.width; clip: true; flickableDirection: Flickable.HorizontalFlick
            Row {
                id: crumbRow
                height: parent.height; spacing: SimpleTheme.px(8)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("This PC"); size: 22; medium: true
                        color: fp.dir === "" ? SimpleTheme.textPrimary : SimpleTheme.textLink
                        MouseArea { anchors.fill: parent; anchors.margins: -SimpleTheme.px(8); onClicked: fp.go("") } }
                Repeater {
                    model: fp.crumbs()
                    Row {
                        anchors.verticalCenter: parent.verticalCenter; spacing: SimpleTheme.px(8)
                        SText { text: "›"; size: 22; color: SimpleTheme.textSecondary }
                        SText { text: modelData.t; size: 22; medium: true
                                color: modelData.p === fp.dir ? SimpleTheme.textPrimary : SimpleTheme.textLink
                                MouseArea { anchors.fill: parent; anchors.margins: -SimpleTheme.px(8); onClicked: fp.go(modelData.p) } }
                    }
                }
            }
        }
    }
    // up
    Item {
        visible: fp.dir !== ""
        width: fp.innerWidth; height: SimpleTheme.px(56)
        Row {
            anchors.verticalCenter: parent.verticalCenter; x: SimpleTheme.px(20); spacing: SimpleTheme.px(18)
            SIcon { name: "undo"; size: 30; color: SimpleTheme.textSecondary }
            SText { text: qsTr("Up one level"); size: 24; medium: true; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { anchors.fill: parent; objectName: "folderUp"; onClicked: fp.go(fp.info.parent || "") }
    }
    // drives or folders
    ListView {
        width: fp.innerWidth; height: SimpleTheme.px(420); clip: true; spacing: SimpleTheme.px(8)
        model: fp.dir === "" ? (fp.pd ? fp.pd.drives() : []) : folders
        delegate: Rectangle {
            readonly property string path: fp.dir === "" ? modelData : filePath
            readonly property string label: fp.dir === "" ? modelData : fileName
            readonly property bool sel: fp.picked === path
            readonly property bool current: fp.fact && String(fp.fact.rawValue) === path
            width: ListView.view.width; height: SimpleTheme.px(84); radius: SimpleTheme.px(16)
            color: sel ? SimpleTheme.brandGreen : SimpleTheme.surfaceControl
            objectName: "folder_" + index
            SIcon { id: fi; name: "folder"; size: 32; anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter }
            Column {
                anchors.left: fi.right; anchors.leftMargin: SimpleTheme.px(18); anchors.right: chev.left; anchors.rightMargin: SimpleTheme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                SText { width: parent.width; text: parent.parent.label; size: 26; medium: true; elide: Text.ElideMiddle }
                SText { visible: parent.parent.current; text: qsTr("Used now"); size: 20 }
            }
            SIcon { id: chev; name: "chevron"; size: 30; color: SimpleTheme.textSecondary
                    anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter }
            MouseArea { anchors.fill: parent; anchors.rightMargin: SimpleTheme.px(90); onClicked: fp.picked = fp.picked === parent.path ? "" : parent.path }
            MouseArea { anchors.right: parent.right; width: SimpleTheme.px(90); height: parent.height; onClicked: fp.go(parent.path) }
        }
    }
    // new folder
    Item {
        visible: fp.dir !== ""
        width: fp.innerWidth; height: fp.naming ? SimpleTheme.px(100) : SimpleTheme.px(48)
        SText { visible: !fp.naming; anchors.verticalCenter: parent.verticalCenter; text: qsTr("+ New folder"); size: 24; medium: true; color: SimpleTheme.textLink
                MouseArea { anchors.fill: parent; anchors.margins: -SimpleTheme.px(12); objectName: "folderNew"; onClicked: { fp.naming = true; fp.newName = ""; fp.error = "" } } }
        Row {
            visible: fp.naming
            anchors.verticalCenter: parent.verticalCenter; spacing: SimpleTheme.px(12)
            STextField { id: nf; designWidth: 560; placeholder: qsTr("Folder name"); text: fp.newName; onEdited: fp.newName = text; objectName: "folderNewName" }
            SButton { designHeight: 72; textSize: 24; kind: "primary"; text: qsTr("Create"); anchors.bottom: nf.bottom; objectName: "folderCreate"
                      onClicked: { var p = fp.pd ? fp.pd.makeFolder(fp.dir, fp.newName) : ""; if (p === "") fp.error = qsTr("This folder cannot be made here."); else { fp.naming = false; fp.picked = p } } }
            SButton { designHeight: 72; textSize: 24; text: qsTr("Cancel"); anchors.bottom: nf.bottom; onClicked: fp.naming = false }
        }
        SText { visible: !fp.naming; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; size: 22; color: SimpleTheme.textSecondary
                text: fp.fmtFree(fp.info.freeBytes !== undefined ? fp.info.freeBytes : -1) }
    }
    SNotice { visible: fp.error !== ""; level: "danger"; text: fp.error }
    SNotice { visible: fp.target !== "" && !!fp.targetInfo.exists && !fp.targetInfo.writable; level: "danger"
              text: qsTr("The app cannot write in this folder. Pick another one.") }
    Row {
        spacing: SimpleTheme.px(12)
        SButton { width: (fp.innerWidth - parent.spacing) / 2; designHeight: 72; textSize: 26; text: qsTr("Cancel"); onClicked: fp.close() }
        SButton {
            objectName: "folderUse"
            width: (fp.innerWidth - parent.spacing) / 2; designHeight: 72; textSize: 26; kind: "primary"
            enabled_: fp.target !== "" && !!fp.targetInfo.writable
            text: fp.target === "" ? qsTr("Use") : qsTr("Use “%1”").arg(fp.target.split("/").filter(function(x) { return x !== "" }).pop() || fp.target)
            onClicked: { fp.fact.rawValue = fp.target; fp.close() }
        }
    }
}
