/****************************************************************************
 * AQGC Simple UI — S24 saved missions: list (.plan files in Settings › mission save path), preview, Open · Rename ·
 * Export · Delete, Import file (.plan, .kml/.kmz) and New mission.
 * - List: FolderListModel (newest first) with a search field. A one-line summary per file is cached in the app
 *   settings (category SimpleMissions) when a mission is saved here or previewed — files are not all parsed.
 * - Preview: the selected file is loaded into its own PlanMasterController (never the one used for editing/sending),
 *   shown on a small map with the classic mission visuals and summarised.
 * - Rename = save under the new name + delete the old file (there is no rename call in QGC).
 * Opening and importing are done by SimplePlanWizard (signals), so the editors get the mission.
 ****************************************************************************/
import QtQuick 2.12
import QtPositioning 5.12
import QtLocation 5.12
import Qt.labs.folderlistmodel 2.12
import Qt.labs.settings 1.0
import QGroundControl 1.0
import QGroundControl.Controls 1.0
import QGroundControl.Controllers 1.0
import QGroundControl.FlightMap 1.0
import "."
import "SimpleMissionInfo.js" as MissionInfo

Rectangle {
    id: sm
    signal backRequested()
    signal newRequested()
    signal openRequested(string file)
    signal importRequested(string file)

    color: SimpleTheme.bgBase
    MouseArea { anchors.fill: parent }

    readonly property string dir: QGroundControl.settingsManager.appSettings.missionSavePath
    property string selected: ""            // full path of the selected file
    property string message: ""             // import result shown under the search field (set by the wizard)
    property string search: ""

    // translated words for MissionInfo.summary()
    readonly property var words: ({
        area: qsTr("Area mapping"), waypoint: qsTr("Waypoint flight"), corridor: qsTr("Corridor mapping"),
        structure: qsTr("Structure scan"), mission: qsTr("Mission"), photos: qsTr("%1 photos"),
        points: qsTr("%1 points"), items: qsTr("%1 items")
    })

    // summaries cache: { "<file name>": { kind, text } }
    Settings { id: cache; category: "SimpleMissions"; property string summaries: "{}" }
    function cached(name) { try { var m = JSON.parse(cache.summaries); return m[name] || null } catch (e) { return null } }
    function setCached(name, info) {
        var m = {}
        try { m = JSON.parse(cache.summaries) } catch (e) { }
        if (info) m[name] = info; else delete m[name]
        cache.summaries = JSON.stringify(m)
    }
    function baseName(path) { var n = String(path).replace(/\\/g, "/"); n = n.substring(n.lastIndexOf("/") + 1); return n.replace(/\.plan$/i, "") }

    QGCFileDialogController { id: fdc }

    FolderListModel {
        id: files
        folder: sm.dir === "" ? "" : (sm.dir.charAt(0) === "/" ? "file://" : "file:///") + sm.dir
        nameFilters: ["*.plan"]
        showDirs: false
        sortField: FolderListModel.Time
    }
    function refresh() { var f = files.folder; files.folder = ""; files.folder = f }
    function visibleCount() {
        var n = 0
        for (var i = 0; i < files.count; i++) if (matches(files.get(i, "fileName"))) n++
        return n
    }
    function matches(name) { return sm.search === "" || String(name).toLowerCase().indexOf(sm.search.toLowerCase()) >= 0 }

    //---------------------------------------------------------------- header
    Rectangle {
        id: header
        width: parent.width; height: SimpleTheme.px(104)
        color: SimpleTheme.surfaceGlass
        Row {
            anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
            spacing: SimpleTheme.px(20)
            SButton { designHeight: 80; icon: "back"; textSize: 26; text: qsTr("Fly"); onClicked: sm.backRequested() }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                SText { text: qsTr("Saved missions"); size: 34; bold: true }
                SText { text: qsTr("%1 missions on this tablet").arg(list.count); size: 22; color: SimpleTheme.textSecondary }
            }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
            spacing: SimpleTheme.px(14)
            SButton { designHeight: 80; textSize: 26; text: qsTr("Import file"); onClicked: { fileDialog.forExport = false; fileDialog.nameFilters = ["*.plan", "*.kml", "*.kmz"]; fileDialog.title = qsTr("Import a mission"); fileDialog.openForLoad() } }
            SButton { designHeight: 80; textSize: 26; kind: "primary"; text: qsTr("New mission"); onClicked: sm.newRequested() }
        }
    }

    //---------------------------------------------------------------- list
    Column {
        id: listCol
        x: SimpleTheme.px(40); y: header.height + SimpleTheme.px(36)
        width: SimpleTheme.px(1060)
        spacing: SimpleTheme.px(12)
        STextField { id: searchField; designWidth: 1060; placeholder: qsTr("Search missions"); onEdited: sm.search = text
                     Connections { target: searchField; function onCurrentTextChanged() { sm.search = searchField.currentText } } }
        SText {
            visible: sm.message !== ""
            width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.warn
            text: sm.message
        }
        SText {
            visible: list.count === 0
            width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
            text: qsTr("No saved missions yet. Save a mission from the plan screen, or import a .plan or .kml file.")
        }
    }
    ListView {
        id: list
        anchors.top: listCol.bottom; anchors.topMargin: SimpleTheme.px(12)
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(24)
        x: listCol.x; width: listCol.width
        clip: true
        spacing: SimpleTheme.px(12)
        model: files
        delegate: Rectangle {
            readonly property bool _show: sm.matches(fileName)
            readonly property var _info: { cache.summaries; return sm.cached(fileName) }
            visible: _show
            width: list.width; height: _show ? SimpleTheme.px(104) : 0
            radius: SimpleTheme.px(18)
            color: sm.selected === filePath ? SimpleTheme.withAlpha(SimpleTheme.brandGreen, 0.18) : SimpleTheme.surfaceRaised
            border.width: sm.selected === filePath ? SimpleTheme.px(2) : 0; border.color: SimpleTheme.brandGreen
            Rectangle {
                id: ib; x: SimpleTheme.px(18); anchors.verticalCenter: parent.verticalCenter
                width: SimpleTheme.px(64); height: width; radius: SimpleTheme.px(14); color: SimpleTheme.brandGreen
                SIcon { anchors.centerIn: parent; name: MissionInfo.iconFor(parent.parent._info ? parent.parent._info.kind : ""); size: 36 }
            }
            Column {
                anchors.left: ib.right; anchors.leftMargin: SimpleTheme.px(18); anchors.right: dateText.left; anchors.rightMargin: SimpleTheme.px(12)
                anchors.verticalCenter: parent.verticalCenter
                SText { width: parent.width; text: sm.baseName(fileName); size: 28; bold: true }
                SText { width: parent.width; size: 22; color: SimpleTheme.textSecondary
                        text: parent.parent._info ? parent.parent._info.text : qsTr("Tap to see the details") }
            }
            SText { id: dateText; anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                    text: Qt.formatDate(fileModified, "yyyy-MM-dd"); size: 22; color: SimpleTheme.textSecondary }
            MouseArea { anchors.fill: parent; onClicked: sm.selected = filePath }
        }
    }

    //---------------------------------------------------------------- preview (right)
    Rectangle {
        id: previewBox
        visible: sm.selected !== ""
        x: listCol.x + listCol.width + SimpleTheme.px(24); y: header.height + SimpleTheme.px(36)
        width: parent.width - x - SimpleTheme.px(40)
        height: pcol.height + SimpleTheme.px(48)
        radius: SimpleTheme.px(24); color: SimpleTheme.surfaceRaised

        // the preview controller is rebuilt for each selected file
        Loader {
            id: ctrlLoader
            active: sm.selected !== "" && sm.visible
            sourceComponent: Component {
                PlanMasterController {
                    flyView: false
                    Component.onCompleted: { start(); loadFromFile(sm.selected) }
                }
            }
            onActiveChanged: if (active) previewTimer.restart()
        }
        Connections { target: sm; function onSelectedChanged() { ctrlLoader.active = false; ctrlLoader.active = sm.selected !== "" && sm.visible } }
        readonly property var ctrl: ctrlLoader.item
        readonly property var mission: ctrl ? ctrl.missionController : null
        property var info: null
        // give the controller a moment to compute distance / time, then summarise, cache and fit the map
        Timer {
            id: previewTimer; interval: 400
            onTriggered: {
                if (!previewBox.mission) return
                previewBox.info = MissionInfo.summary(previewBox.mission, sm.words)
                sm.setCached(sm.baseName(sm.selected) + ".plan", previewBox.info)
                var pts = MissionInfo.outline(previewBox.mission)
                if (pts.length > 0) {
                    var minLat = 90, maxLat = -90, minLon = 180, maxLon = -180
                    for (var i = 0; i < pts.length; i++) {
                        minLat = Math.min(minLat, pts[i].latitude); maxLat = Math.max(maxLat, pts[i].latitude)
                        minLon = Math.min(minLon, pts[i].longitude); maxLon = Math.max(maxLon, pts[i].longitude)
                    }
                    var pad = Math.max(maxLat - minLat, maxLon - minLon) * 0.15 + 0.0005
                    previewMap.visibleRegion = QtPositioning.rectangle(QtPositioning.coordinate(maxLat + pad, minLon - pad),
                                                                       QtPositioning.coordinate(minLat - pad, maxLon + pad))
                }
            }
        }

        Column {
            id: pcol
            x: SimpleTheme.px(24); y: SimpleTheme.px(24)
            width: parent.width - SimpleTheme.px(48)
            spacing: SimpleTheme.px(16)
            Item {
                width: parent.width; height: SimpleTheme.px(400)
                clip: true
                FlightMap {
                    id: previewMap
                    anchors.fill: parent
                    mapName: "simpleMissionPreview"
                    gesture.enabled: false
                    Repeater {
                        model: previewBox.mission ? previewBox.mission.visualItems : 0
                        delegate: MissionItemMapVisual {
                            map: previewMap
                            interactive: false
                            vehicle: previewBox.ctrl ? previewBox.ctrl.controllerVehicle : null
                        }
                    }
                }
            }
            SText { width: parent.width; text: sm.baseName(sm.selected); size: 32; bold: true }
            SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                    text: previewBox.info ? previewBox.info.text : qsTr("Loading…") }
            Row {
                spacing: SimpleTheme.px(12)
                SButton { kind: "primary"; text: qsTr("Open"); onClicked: sm.openRequested(sm.selected) }
                SButton { text: qsTr("Rename"); onClicked: { renameField.text = sm.baseName(sm.selected); renameField.reset(); renameSheet.visible = true } }
                SButton { text: qsTr("Export"); onClicked: { fileDialog.forExport = true; fileDialog.nameFilters = ["*.plan"]; fileDialog.title = qsTr("Export a copy"); fileDialog.openForSave() } }
                SButton { kind: "danger"; text: qsTr("Delete"); onClicked: deleteSheet.visible = true }
            }
            Row {
                spacing: SimpleTheme.px(10)
                SIcon { name: "info"; size: 28; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                SText { text: qsTr("Import: .plan (QGC) · .kml / .kmz with an area (Google Earth)"); size: 22; color: SimpleTheme.textSecondary }
            }
        }
    }

    //---------------------------------------------------------------- rename / delete sheets
    Rectangle {
        anchors.fill: parent
        visible: renameSheet.visible || deleteSheet.visible
        color: SimpleTheme.withAlpha("black", 0.45)
        MouseArea { anchors.fill: parent; onClicked: { renameSheet.visible = false; deleteSheet.visible = false } }
    }
    SPanel {
        id: renameSheet
        visible: false
        anchors.centerIn: parent
        width: SimpleTheme.px(820); height: SimpleTheme.px(380)
        title: qsTr("Rename mission"); titleIcon: "folder"
        onCloseRequested: visible = false
        readonly property string _new: renameField.currentText.trim()
        readonly property bool _taken: _new !== "" && _new !== sm.baseName(sm.selected) && fdc.fileExists(sm.dir + "/" + _new + ".plan")
        Column {
            anchors.fill: parent; spacing: SimpleTheme.px(18)
            STextField { id: renameField; designWidth: 764; label: qsTr("Name"); error: renameSheet._taken }
            SText { visible: renameSheet._taken; text: qsTr("A mission with this name already exists."); size: 22; color: SimpleTheme.textDanger }
            SButton {
                kind: "primary"; text: qsTr("Rename")
                enabled_: renameSheet._new !== "" && !renameSheet._taken && /^[^\\/:*?"<>|]+$/.test(renameSheet._new) && !!previewBox.ctrl
                onClicked: {
                    var oldPath = sm.selected, newPath = sm.dir + "/" + renameSheet._new + ".plan"
                    if (newPath === oldPath) { renameSheet.visible = false; return }
                    previewBox.ctrl.saveToFile(newPath)
                    if (fdc.fileExists(newPath)) {
                        var info = sm.cached(sm.baseName(oldPath) + ".plan")
                        fdc.deleteFile(oldPath)
                        sm.setCached(sm.baseName(oldPath) + ".plan", null)
                        sm.setCached(renameSheet._new + ".plan", info)
                        sm.selected = newPath
                        sm.refresh()
                    }
                    renameSheet.visible = false
                }
            }
        }
    }
    SimpleConfirmSheet {
        id: deleteSheet
        visible: false
        anchors.centerIn: parent
        icon: "trash"
        title: qsTr("Delete “%1”?").arg(sm.baseName(sm.selected))
        detail: qsTr("The mission file is removed from this tablet. This cannot be undone.")
        note: qsTr("A mission already sent to the drone stays on the drone.")
        slideText: qsTr("Slide to delete")
        onCloseRequested: visible = false
        onConfirmed: {
            fdc.deleteFile(sm.selected)
            sm.setCached(sm.baseName(sm.selected) + ".plan", null)
            sm.selected = ""
            sm.refresh()
            visible = false
        }
    }

    //---------------------------------------------------------------- import / export file dialog (classic)
    QGCFileDialog {
        id: fileDialog
        property bool forExport: false
        folder: sm.dir
        onAcceptedForLoad: { close(); sm.importRequested(file) }
        onAcceptedForSave: { if (forExport && previewBox.ctrl) previewBox.ctrl.saveToFile(file); close(); sm.refresh() }
    }
}
