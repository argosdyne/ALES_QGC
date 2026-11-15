/****************************************************************************
 * AQGC Simple UI — S46 › Download new area: move and zoom the map so the area fits the frame, then download.
 * Uses the existing QGC offline map download (mapEngineManager.updateForCurrentView + startDownload), like
 * Advanced › Offline Maps, which also takes the visible map area (decision 2026-11-15: frame, not a drawn rectangle).
 ****************************************************************************/
import QtQuick 2.12
import QtLocation 5.3
import QtPositioning 5.3
import QGroundControl 1.0
import QGroundControl.FlightMap 1.0
import "."

Rectangle {
    id: dl
    color: SimpleTheme.bgBase
    signal closeRequested()

    readonly property var  _mgr:      QGroundControl.mapEngineManager
    readonly property var  _fm:       QGroundControl.settingsManager.flightMapSettings
    readonly property var  _off:      QGroundControl.settingsManager.offlineMapsSettings
    readonly property string mapType: _fm.mapProvider.value + " " + _fm.mapType.value
    readonly property int  _maxTiles: _off ? Number(_off.maxTilesForDownload.rawValue) : 100000
    property int  detail:   0                                  // 0 standard (zoom 17), 1 high (zoom 19)
    readonly property int  maxZoom:   detail === 1 ? 19 : 17
    readonly property int  minZoom:   Math.max(1, Math.min(13, Math.floor(map.zoomLevel)))
    readonly property bool tooMany:   _mgr.tileCount > _maxTiles
    property string nameError: ""

    MouseArea { anchors.fill: parent }   // keep taps off the pages below

    function update() {
        var tl = map.mapFromItem(frame, 0, 0)
        var br = map.mapFromItem(frame, frame.width - 1, frame.height - 1)
        var c0 = map.toCoordinate(Qt.point(tl.x, tl.y), false)
        var c1 = map.toCoordinate(Qt.point(br.x, br.y), false)
        if (!c0.isValid || !c1.isValid) return
        _mgr.updateForCurrentView(c0.longitude, c0.latitude, c1.longitude, c1.latitude, minZoom, Math.max(minZoom, maxZoom), mapType)
    }
    function download() {
        var n = nameField.currentText.trim()
        if (n === "") { nameError = qsTr("Enter a name"); return }
        if (_mgr.findName(n)) { nameError = qsTr("A saved map already has this name"); return }
        nameError = ""
        update()
        _mgr.startDownload(n, mapType)
        dl.closeRequested()
    }
    onDetailChanged: update()

    FlightMap {
        id: map
        anchors.fill: parent
        mapName: "SimpleOfflineMap"
        allowGCSLocationCenter: true
        allowVehicleLocationCenter: true
        onCenterChanged:    updateTimer.restart()
        onZoomLevelChanged: updateTimer.restart()
        onWidthChanged:     updateTimer.restart()
        onHeightChanged:    updateTimer.restart()
        Component.onCompleted: {
            if (QGroundControl.flightMapPosition && QGroundControl.flightMapPosition.isValid) center = QGroundControl.flightMapPosition
            zoomLevel = Math.max(QGroundControl.flightMapZoom, 13)
        }
    }
    Timer { id: updateTimer; interval: 250; onTriggered: dl.update() }

    // Frame: the area to download (left of the panel, below the header)
    Item {
        id: frameArea
        anchors.top: header.bottom; anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: panel.left
        anchors.margins: SimpleTheme.px(48)
        Rectangle {
            id: frame
            anchors.fill: parent
            color: "transparent"
            border.width: SimpleTheme.px(4); border.color: SimpleTheme.textPrimary
            radius: SimpleTheme.px(12)
        }
    }
    // dim outside the frame
    Rectangle { anchors.top: header.bottom; anchors.left: parent.left; anchors.right: panel.left; height: SimpleTheme.px(48); color: "#66000000" }
    Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: panel.left; height: SimpleTheme.px(48); color: "#66000000" }
    Rectangle { anchors.top: header.bottom; anchors.topMargin: SimpleTheme.px(48); anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(48); anchors.left: parent.left; width: SimpleTheme.px(48); color: "#66000000" }
    Rectangle { anchors.top: header.bottom; anchors.topMargin: SimpleTheme.px(48); anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(48); anchors.right: panel.left; width: SimpleTheme.px(48); color: "#66000000" }

    // Header
    Rectangle {
        id: header
        width: parent.width; height: SimpleTheme.px(104)
        color: SimpleTheme.surfaceGlass
        MouseArea { anchors.fill: parent }
        Row {
            anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
            spacing: SimpleTheme.px(20)
            SButton { designHeight: 80; icon: "back"; text: qsTr("Map & flight zones"); textSize: 26; onClicked: dl.closeRequested() }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                SText { text: qsTr("Download new area"); size: 34; bold: true }
                SText { text: qsTr("Move and zoom the map so the area fits the frame"); size: 22; color: SimpleTheme.textSecondary }
            }
        }
    }

    // Panel
    SPanel {
        id: panel
        closable: false
        anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(24)
        anchors.top: header.bottom; anchors.topMargin: SimpleTheme.px(24)
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(24)
        width: SimpleTheme.px(620)
        Column {
            anchors.left: parent.left; anchors.right: parent.right
            spacing: SimpleTheme.px(18)
            STextField {
                id: nameField
                designWidth: 564; label: qsTr("Name"); maximumLength: 40
                text: Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm") + " " + qsTr("area")
                error: dl.nameError !== ""
            }
            SText { visible: dl.nameError !== ""; text: dl.nameError; size: 22; color: SimpleTheme.textDanger }
            SText { text: qsTr("Detail"); size: 26; medium: true; color: SimpleTheme.textSecondary }
            SSegmented {
                designWidth: 564
                model: [qsTr("Standard"), qsTr("High")]
                currentIndex: dl.detail
                onActivated: { dl.detail = index; currentIndex = Qt.binding(function() { return dl.detail }) }
            }
            SText {
                width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textTertiary
                text: dl.detail === 1 ? qsTr("Buildings and small paths. Needs much more space.") : qsTr("Roads, fields and large buildings.")
            }
            Rectangle { width: parent.width; height: 1; color: SimpleTheme.line }
            Grid {
                width: parent.width; columns: 2; rowSpacing: SimpleTheme.px(14)
                Column {
                    width: parent.width / 2
                    SText { text: qsTr("SIZE"); size: 22; medium: true; color: SimpleTheme.textTertiary }
                    SText { text: dl._mgr.tileSizeStr; size: 32; bold: true }
                }
                Column {
                    width: parent.width / 2
                    SText { text: qsTr("MAP TILES"); size: 22; medium: true; color: SimpleTheme.textTertiary }
                    SText { text: dl._mgr.tileCountStr; size: 32; bold: true; color: dl.tooMany ? SimpleTheme.textDanger : SimpleTheme.textPrimary }
                }
            }
            SText {
                width: parent.width; wrapMode: Text.WordWrap; size: 22
                color: dl.tooMany ? SimpleTheme.textDanger : SimpleTheme.textTertiary
                text: dl.tooMany ? qsTr("Area too large. Zoom in or choose Standard detail.")
                                 : qsTr("Free space on this device: %1").arg(dl._mgr.freeDiskSpace > 0 ? (dl._mgr.freeDiskSpace / 1048576).toFixed(1) + " GB" : "—")
            }
        }
        SButton {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: SimpleTheme.px(28)
            kind: "primary"; icon: "download"
            text: qsTr("Download")
            enabled_: !dl.tooMany && dl._mgr.tileCount > 0
            onClicked: if (enabled_) dl.download()
        }
    }
}
