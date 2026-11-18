/****************************************************************************
 * AQGC Simple UI — S87 Parameters › Load from file / Save to file (Figma 159:43117, 2026-11-18).
 * Folder = appSettings.parameterSavePath, *.params newest first (FolderListModel).
 * Load: ParameterEditorController.buildDiffFromFile() → diffList (name, drone → file); "Send N values" = sendDiff()
 * (only items with load = true). A file of another drone type (diffOtherVehicle) starts with every item off and a red
 * notice; items can be ticked one by one. Save: name (default <date>) → ctl.saveToFile(). Changes go to the security log.
 ****************************************************************************/
import QtQuick 2.12
import Qt.labs.folderlistmodel 2.12
import QGroundControl 1.0
import "."

SSheet {
    id: pf
    property var    editor: null        // ParameterEditorController of the Parameters page
    property bool   armed: false
    property string mode: "load"        // load | save
    property string selected: ""        // file path
    property string message: ""
    property int    rev: 0              // bumps when the diff list changes (QmlObjectListModel items are QObjects)
    readonly property string dir: QGroundControl.settingsManager.appSettings.parameterSavePath
    readonly property string ext: QGroundControl.settingsManager.appSettings.parameterFileExtension
    signal saved(string path)

    title: mode === "load" ? qsTr("Load parameters from a file") : qsTr("Save parameters to a file")
    subtitle: mode === "load" ? qsTr("Pick a file saved with “Save to file”. Only the values that differ are sent.")
                              : qsTr("All values of the drone are saved in the parameters folder of this tablet.")
    designWidth: 1100
    closeOnOutside: true

    function openLoad() { mode = "load"; selected = ""; message = ""; if (editor) editor.clearDiff(); rev++; open() }
    function openSave() { mode = "save"; message = ""; nameField.text = Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm"); open() }
    function choose(path) {
        selected = path; message = ""
        if (!editor) return
        if (!editor.buildDiffFromFile(path)) { message = qsTr("This file cannot be read."); rev++; return }
        if (editor.diffOtherVehicle) for (var i = 0; i < editor.diffList.count; i++) editor.diffList.get(i).load = false
        rev++
    }
    readonly property int loadCount: { rev; var n = 0; if (editor) for (var i = 0; i < editor.diffList.count; i++) if (editor.diffList.get(i).load) n++; return n }
    function send() {
        var n = loadCount
        editor.sendDiff()
        var pd = QGroundControl.corePlugin.privacyData
        if (pd) pd.logEvent("Parameters", "Loaded " + n + " values from " + selected.split("/").pop())
        message = qsTr("%n value(s) sent to the drone.", "", n)
        editor.clearDiff(); selected = ""; rev++
    }
    function save() {
        var name = nameField.text.replace(/[\\/:*?"<>|]/g, "_").trim()
        if (name === "") return
        var path = dir + "/" + name + "." + ext
        editor.saveToFile(path)
        saved(path)
        close()
    }
    onClosed: if (editor) editor.clearDiff()

    FolderListModel {
        id: files
        folder: pf.dir === "" ? "" : (pf.dir.charAt(0) === "/" ? "file://" : "file:///") + pf.dir
        nameFilters: ["*." + pf.ext]
        showDirs: false
        sortField: FolderListModel.Time
    }

    // ---------------------------------------------------------------- load
    SText { visible: pf.mode === "load" && files.count === 0; width: pf.innerWidth; size: 24; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap
            text: qsTr("No parameter files yet. Use “Save to file” first.") }
    ListView {
        visible: pf.mode === "load" && files.count > 0
        width: pf.innerWidth; height: Math.min(contentHeight, SimpleTheme.px(pf.selected === "" ? 520 : 260))
        clip: true; spacing: SimpleTheme.px(8)
        model: files
        delegate: Rectangle {
            readonly property bool sel: pf.selected === filePath
            width: ListView.view.width; height: SimpleTheme.px(84); radius: SimpleTheme.px(16)
            color: sel ? SimpleTheme.brandGreen : SimpleTheme.surfaceControl
            objectName: "paramFile_" + index
            SIcon { id: fi; name: "folder"; size: 32; anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter }
            Column {
                anchors.left: fi.right; anchors.leftMargin: SimpleTheme.px(18); anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(20)
                anchors.verticalCenter: parent.verticalCenter
                SText { width: parent.width; text: fileName; size: 26; medium: true; elide: Text.ElideMiddle }
                SText { text: Qt.formatDateTime(fileModified, "yyyy-MM-dd hh:mm"); size: 20; color: parent.parent.sel ? SimpleTheme.textPrimary : SimpleTheme.textSecondary }
            }
            MouseArea { anchors.fill: parent; onClicked: pf.choose(filePath) }
        }
    }
    Rectangle {
        visible: pf.mode === "load" && pf.selected !== "" && pf.message === ""
        width: pf.innerWidth; height: diffCol.height + SimpleTheme.px(24); radius: SimpleTheme.px(20)
        color: SimpleTheme.surfaceControl
        Column {
            id: diffCol
            x: SimpleTheme.px(24); y: SimpleTheme.px(12); width: parent.width - SimpleTheme.px(48)
            Item {
                width: parent.width; height: SimpleTheme.px(48)
                SText { anchors.verticalCenter: parent.verticalCenter; size: 24; bold: true
                        text: { pf.rev; return pf.editor && pf.editor.diffList.count > 0 ? qsTr("%n value(s) differ", "", pf.editor.diffList.count) : qsTr("Same as the drone") } }
                SText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; size: 22; color: SimpleTheme.textSecondary; text: qsTr("Now → In file") }
            }
            ListView {
                width: parent.width; height: Math.min(contentHeight, SimpleTheme.px(250)); clip: true
                model: pf.editor ? pf.editor.diffList : null
                delegate: Item {
                    width: ListView.view.width; height: SimpleTheme.px(52)
                    Rectangle {
                        id: lb
                        visible: pf.editor && pf.editor.diffOtherVehicle
                        width: visible ? SimpleTheme.px(34) : 0; height: SimpleTheme.px(34); radius: SimpleTheme.px(8); anchors.verticalCenter: parent.verticalCenter
                        color: object.load ? SimpleTheme.brandGreen : "transparent"
                        border.width: SimpleTheme.px(3); border.color: object.load ? SimpleTheme.brandGreen : SimpleTheme.textSecondary
                        SIcon { anchors.centerIn: parent; name: "check"; size: 26; visible: object.load }
                        MouseArea { anchors.fill: parent; anchors.margins: -SimpleTheme.px(10); onClicked: { object.load = !object.load; pf.rev++ } }
                    }
                    SText { anchors.left: lb.right; anchors.leftMargin: lb.visible ? SimpleTheme.px(14) : 0; anchors.verticalCenter: parent.verticalCenter
                            text: object.name; size: 24; medium: true }
                    SText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; size: 24
                            text: (object.noVehicleValue ? qsTr("not on drone") : object.vehicleValue) + "  →  " + object.fileValue + (object.units !== "" ? " " + object.units : "") }
                }
            }
        }
    }
    SNotice { visible: pf.mode === "load" && !!pf.editor && pf.editor.diffOtherVehicle && pf.selected !== ""; level: "danger"
              text: qsTr("This file is from another drone. Tick only the values you are sure about.") }
    SNotice { visible: pf.mode === "load" && pf.selected !== "" && pf.loadCount > 0; level: "warn"
              text: qsTr("The drone uses the new values at once. Check the flight with care after loading.") }
    SNotice { visible: pf.armed; level: "danger"; text: qsTr("The drone is armed. Stop the motors first.") }
    SText { visible: pf.message !== ""; width: pf.innerWidth; text: pf.message; size: 24; medium: true; wrapMode: Text.WordWrap }

    // ---------------------------------------------------------------- save
    STextField { id: nameField; objectName: "paramFileName"; visible: pf.mode === "save"; label: qsTr("File name"); designWidth: 1020
                 onEdited: nameField.text = text }
    SText { visible: pf.mode === "save"; width: pf.innerWidth; size: 22; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap
            text: qsTr("Folder: %1").arg(pf.dir) }

    Row {
        spacing: SimpleTheme.px(12)
        SButton { width: (pf.innerWidth - parent.spacing) / 2; designHeight: 72; textSize: 26; text: pf.message !== "" ? qsTr("Close") : qsTr("Cancel"); onClicked: pf.close() }
        SButton {
            objectName: "paramFileGo"
            width: (pf.innerWidth - parent.spacing) / 2; designHeight: 72; textSize: 26; kind: "primary"; icon: "download"
            enabled_: pf.mode === "save" ? !!pf.editor : (!pf.armed && pf.loadCount > 0)
            text: pf.mode === "save" ? qsTr("Save") : qsTr("Send %n value(s)", "", pf.loadCount)
            onClicked: pf.mode === "save" ? pf.save() : pf.send()
        }
    }
}
