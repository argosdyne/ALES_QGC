/****************************************************************************
 * AQGC Simple UI — S65 Settings › About › Security & privacy (Figma 118:39104, UX note 118:39316) with
 * S67 Delete my data (118:39319) and the security log list. CE RED 3.3(e) / EN 18031 (00 Overview §10), 2026-11-17.
 * - Left: data on this device (corePlugin.privacyData: logs, videos/photos, missions; map cache from
 *   mapEngineManager; accounts and keys in the secure store). Delete my data… → S67 (data on the drone is kept).
 * - Right: app signature (Windows code signature check; Android checks the APK at install), security updates and
 *   security contact ("Not set yet" until the company sets them, user 2026-11-17), location sharing (followTarget,
 *   default off), security log, legal & licenses.
 ****************************************************************************/
import QtQuick 2.12
import QtQuick.Controls 2.12
import QGroundControl 1.0
import "."

Item {
    id: sp
    signal backRequested()
    signal licensesRequested()
    width: parent ? parent.width : 0
    height: showLog ? logCol.height : mainCol.height

    readonly property var  _pd:   QGroundControl.corePlugin.privacyData
    readonly property var  _map:  QGroundControl.mapEngineManager
    readonly property var  _app:  QGroundControl.settingsManager.appSettings
    property bool showLog: false
    property bool showDelete: false
    property int  _mapRev: 0

    Component.onCompleted: { if (_pd) _pd.refresh(); _map.loadTileSets() }
    Connections { target: sp._map; function onTileSetsChanged() { sp._mapRev++ } }

    function fmtBytes(b) {
        if (b === undefined || b === null) return ""
        if (b >= 1024 * 1024 * 1024) return (b / (1024 * 1024 * 1024)).toFixed(1) + " GB"
        if (b >= 1024 * 1024) return Math.round(b / (1024 * 1024)) + " MB"
        if (b >= 1024) return Math.round(b / 1024) + " KB"
        return b + " B"
    }
    function entry(key) { return _pd && _pd.sizes[key] ? _pd.sizes[key] : null }
    // map cache: the default set holds every cached tile; user sets = saved offline areas
    readonly property var _mapInfo: {
        _mapRev
        var m = _map.tileSets, areas = 0, bytes = 0
        for (var i = 0; i < m.count; i++) {
            var o = m.get(i)
            if (!o) continue
            if (o.defaultSet) bytes = o.savedTileSize
            else if (o.mapTypeStr !== QGroundControl.elevationProviderName && o.name.indexOf(" Elevation") < 0) areas++
        }
        return { areas: areas, bytes: bytes }
    }
    function accountNames() {
        if (!_pd) return []
        var names = { "NTRIP": "NTRIP", "Altitude Angel": "Altitude Angel", "Radio": qsTr("radio password"),
                      "Map tokens": qsTr("map tokens"), "OTA": "OTA", "Link key": qsTr("link key") }
        var out = []
        for (var i = 0; i < _pd.accounts.length; i++) out.push(names[_pd.accounts[i]] || _pd.accounts[i])
        return out
    }
    readonly property string _accountsSub: {
        var n = accountNames()
        if (n.length === 0) return qsTr("Nothing stored")
        return n.join(", ") + " · " + (Qt.platform.os === "android" ? qsTr("stored in the app's private storage") : qsTr("stored encrypted"))
    }
    readonly property var _dataRows: [
        { key: "logs",     icon: "folder", t: qsTr("Flight logs"),
          s: entry("logs") ? qsTr("%1 files · %2").arg(entry("logs").files).arg(fmtBytes(entry("logs").bytes)) : "…" },
        { key: "media",    icon: "camera", t: qsTr("Videos and photos"),
          s: entry("media") ? qsTr("%1 files · %2").arg(entry("media").files).arg(fmtBytes(entry("media").bytes)) : "…" },
        { key: "missions", icon: "plan",   t: qsTr("Saved missions"),
          s: entry("missions") ? qsTr("%1 missions · %2").arg(entry("missions").plans).arg(fmtBytes(entry("missions").bytes)) : "…" },
        { key: "map",      icon: "map",    t: qsTr("Map cache"),
          s: qsTr("%1 areas · %2").arg(_mapInfo.areas).arg(fmtBytes(_mapInfo.bytes)) },
        { key: "accounts", icon: "lock",   t: qsTr("Accounts and keys"), s: _accountsSub }
    ]
    readonly property string _lastLog: {
        if (!_pd || _pd.securityLog.length === 0) return qsTr("No security events yet")
        return qsTr("Last: %1").arg(logText(_pd.securityLog[0]))
    }
    // "2026-11-17T15:23:18 Radio: radio password changed" → "2026-11-17 15:23 · radio password changed"
    function logText(line) {
        var sp1 = line.indexOf(" "), colon = line.indexOf(": ", sp1)
        var when = line.substring(0, sp1).replace("T", " ").substring(0, 16)
        return when + " · " + (colon > 0 ? line.substring(colon + 2) : line.substring(sp1 + 1))
    }
    function logSource(line) {
        var sp1 = line.indexOf(" "), colon = line.indexOf(": ", sp1)
        return colon > 0 ? line.substring(sp1 + 1, colon) : ""
    }

    //================================================================== S65 main page
    Column {
        id: mainCol
        visible: !sp.showLog
        width: parent.width
        spacing: SimpleTheme.px(16)

        Row {
            spacing: SimpleTheme.px(8)
            SText { text: qsTr("About & support"); size: 24; color: SimpleTheme.textLink
                    MouseArea { anchors.fill: parent; anchors.margins: -SimpleTheme.px(12); onClicked: sp.backRequested() } }
            SIcon { name: "chevron"; size: 28; anchors.verticalCenter: parent.verticalCenter }
        }
        SText { text: qsTr("Security & privacy"); size: 40; bold: true }

        Row {
            width: parent.width
            spacing: SimpleTheme.px(24)

            // ---------------- left: data on this device
            Column {
                width: (parent.width - parent.spacing) / 2
                spacing: SimpleTheme.px(12)
                SText { text: qsTr("DATA ON THIS DEVICE"); size: 22; medium: true; color: SimpleTheme.textSecondary }
                Repeater {
                    model: sp._dataRows
                    Rectangle {
                        width: parent.width; height: Math.max(SimpleTheme.px(92), dText.height + SimpleTheme.px(28))
                        radius: SimpleTheme.px(18); color: SimpleTheme.surfaceRaised
                        SIcon { id: dIcon; name: modelData.icon; size: 36; anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(24); anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            id: dText
                            anchors.left: dIcon.right; anchors.leftMargin: SimpleTheme.px(20)
                            anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(20)
                            anchors.verticalCenter: parent.verticalCenter
                            SText { width: parent.width; text: modelData.t; size: 28; medium: true }
                            SText { width: parent.width; text: modelData.s; size: 22; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap }
                        }
                    }
                }
                Row {
                    spacing: SimpleTheme.px(14)
                    SButton { designHeight: 80; textSize: 26; icon: "trash"; kind: "danger"; text: qsTr("Delete my data…")
                              objectName: "deleteMyData"
                              enabled_: !!sp._pd && !sp._pd.busy; onClicked: { sp._pd.clearResult(); sp.showDelete = true } }
                    SButton { visible: !!sp._pd && sp._pd.canOpenFolder; designHeight: 80; textSize: 26; icon: "folder"; text: qsTr("Open folder")
                              onClicked: sp._pd.openFolder() }
                }
                SText {
                    visible: !!sp._pd && sp._pd.result !== ""
                    width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.ok
                    text: sp._pd && sp._pd.result === "restart" ? qsTr("Deleted. Restart the app to finish: the app settings are cleared at the next start.")
                                                                : qsTr("The selected data was deleted from this tablet.")
                }
            }

            // ---------------- right: this app + privacy
            Column {
                width: (parent.width - parent.spacing) / 2
                spacing: SimpleTheme.px(12)
                SText { text: qsTr("THIS APP"); size: 22; medium: true; color: SimpleTheme.textSecondary }
                SSettingRow {
                    id: sigRow
                    readonly property string _sig: sp._pd ? sp._pd.signature : ""
                    title: _sig === "verified" && sp._pd.signer !== "" ? qsTr("Signed by %1").arg(sp._pd.signer) : qsTr("App signature")
                    sub: _sig === "verified" ? qsTr("Installer and app checked by Windows / Android")
                       : _sig === "android"  ? qsTr("Android checks the app signature when it is installed")
                       : _sig === "unsigned" ? qsTr("This build has no code signature (test build). Install only builds from ARGOSDYNE.")
                       : _sig === "invalid"  ? qsTr("The signature of this app is not valid. Reinstall it from ARGOSDYNE.")
                       : qsTr("Checking…")
                    SStatusChip { visible: sigRow._sig !== ""
                                  text: sigRow._sig === "verified" ? qsTr("Verified") : sigRow._sig === "android" ? qsTr("Android")
                                      : sigRow._sig === "unsigned" ? qsTr("Not signed") : qsTr("Not valid")
                                  level: sigRow._sig === "verified" ? "ok" : sigRow._sig === "android" ? "info"
                                       : sigRow._sig === "unsigned" ? "warn" : "danger" }
                }
                SSettingRow { title: qsTr("Security updates"); sub: qsTr("Support period not set yet") }
                SText { text: qsTr("PRIVACY"); size: 22; medium: true; color: SimpleTheme.textSecondary }
                SSettingRow {
                    id: locRow
                    readonly property var _fact: sp._app.followTarget
                    title: qsTr("Share this device's location")
                    sub: qsTr("Sends the tablet position to the drone (follow me). Off unless you turn it on.")
                    SToggle {
                        id: locToggle
                        objectName: "locationToggle"
                        checked: locRow._fact.rawValue !== 0
                        onToggled: {
                            locRow._fact.rawValue = checked ? 2 : 0
                            locToggle.checked = Qt.binding(function() { return locRow._fact.rawValue !== 0 })
                        }
                    }
                }
                SSettingRow { title: qsTr("Report a security issue"); sub: qsTr("Security contact not set yet") }
                SSettingRow {
                    title: qsTr("Security log"); sub: sp._lastLog
                    clickable: true; objectName: "securityLogRow"
                    onClicked: { if (sp._pd) sp._pd.reloadSecurityLog(); sp.showLog = true }
                    SIcon { name: "chevron"; size: 40; opacity: 0.7 }
                }
                SSettingRow {
                    title: qsTr("Legal & licenses"); sub: qsTr("Open-source licenses")
                    clickable: true
                    onClicked: sp.licensesRequested()
                    SIcon { name: "chevron"; size: 40; opacity: 0.7 }
                }
            }
        }
    }

    //================================================================== security log list
    Column {
        id: logCol
        visible: sp.showLog
        width: parent.width
        spacing: SimpleTheme.px(14)
        Row {
            spacing: SimpleTheme.px(8)
            SText { text: qsTr("Security & privacy"); size: 24; color: SimpleTheme.textLink
                    MouseArea { anchors.fill: parent; anchors.margins: -SimpleTheme.px(12); onClicked: sp.showLog = false } }
            SIcon { name: "chevron"; size: 28; anchors.verticalCenter: parent.verticalCenter }
        }
        SText { text: qsTr("Security log"); size: 40; bold: true }
        SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                text: qsTr("Security events on this tablet, newest first: keys and passwords, refused keys, radio certificate, deleted data. Secrets are never written here.") }
        SText { visible: !sp._pd || sp._pd.securityLog.length === 0; text: qsTr("No security events yet"); size: 26 }
        Repeater {
            model: sp._pd ? sp._pd.securityLog : []
            Rectangle {
                width: logCol.width; height: lText.height + SimpleTheme.px(24)
                radius: SimpleTheme.px(14); color: SimpleTheme.surfaceRaised
                Column {
                    id: lText
                    anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: SimpleTheme.px(24); anchors.rightMargin: SimpleTheme.px(24)
                    SText { width: parent.width; text: sp.logText(modelData); size: 24; wrapMode: Text.WordWrap }
                    SText { width: parent.width; text: sp.logSource(modelData); size: 20; color: SimpleTheme.textSecondary; visible: text !== "" }
                }
            }
        }
    }

    //================================================================== S67 Delete my data (dialog)
    Popup {
        id: delPopup
        parent: Overlay.overlay
        visible: sp.showDelete
        modal: true
        closePolicy: Popup.CloseOnEscape
        onClosed: sp.showDelete = false
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0
        width: SimpleTheme.px(820)
        padding: SimpleTheme.px(40)
        background: Rectangle { color: SimpleTheme.surfaceGlass; radius: SimpleTheme.px(28); border.width: SimpleTheme.px(2); border.color: SimpleTheme.line }
        Overlay.modal: Rectangle { color: "#99000000" }

        property var sel: ({ logs: true, media: true, missions: false, map: false, accounts: true, settings: false })
        readonly property int count: { var n = 0; for (var k in sel) if (sel[k]) n++; return n }
        onAboutToShow: sel = { logs: true, media: true, missions: false, map: false, accounts: true, settings: false }

        contentItem: Column {
            spacing: SimpleTheme.px(14)
            SText { text: qsTr("Delete my data"); size: 36; bold: true }
            SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                    text: qsTr("Choose what to delete from this tablet. Data on the drone is not deleted.") }
            Repeater {
                model: [
                    { key: "logs",     t: qsTr("Flight logs"),       s: sp.entry("logs") ? sp.fmtBytes(sp.entry("logs").bytes) : "" },
                    { key: "media",    t: qsTr("Videos and photos"), s: sp.entry("media") ? sp.fmtBytes(sp.entry("media").bytes) : "" },
                    { key: "missions", t: qsTr("Saved missions"),    s: sp.entry("missions") ? sp.fmtBytes(sp.entry("missions").bytes) : "" },
                    { key: "map",      t: qsTr("Map cache"),         s: sp.fmtBytes(sp._mapInfo.bytes) },
                    { key: "accounts", t: qsTr("Accounts and keys"), s: sp.accountNames().join(", ") },
                    { key: "settings", t: qsTr("App settings"),      s: qsTr("Back to the first-start screen") }
                ]
                Item {
                    width: parent.width; height: SimpleTheme.px(76)
                    objectName: "delRow_" + modelData.key
                    Rectangle {
                        id: box
                        width: SimpleTheme.px(40); height: width; radius: SimpleTheme.px(8)
                        anchors.verticalCenter: parent.verticalCenter
                        color: delPopup.sel[modelData.key] ? SimpleTheme.brandGreen : "transparent"
                        border.width: SimpleTheme.px(3); border.color: delPopup.sel[modelData.key] ? SimpleTheme.brandGreen : SimpleTheme.textSecondary
                        SIcon { anchors.centerIn: parent; name: "check"; size: 30; visible: !!delPopup.sel[modelData.key] }
                    }
                    SText { anchors.left: box.right; anchors.leftMargin: SimpleTheme.px(22); anchors.verticalCenter: parent.verticalCenter
                            text: modelData.t; size: 28 }
                    SText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * 0.45; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                            text: modelData.s; size: 22; color: SimpleTheme.textSecondary }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { var s = Object.assign({}, delPopup.sel); s[modelData.key] = !s[modelData.key]; delPopup.sel = s }
                    }
                }
            }
            Rectangle {
                width: parent.width; height: warnText.height + SimpleTheme.px(28); radius: SimpleTheme.px(14)
                color: SimpleTheme.withAlpha(SimpleTheme.danger, 0.18); border.width: SimpleTheme.px(2); border.color: SimpleTheme.danger
                SIcon { id: warnIcon; name: "warn"; size: 32; anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(18); anchors.verticalCenter: parent.verticalCenter }
                SText { id: warnText; anchors.left: warnIcon.right; anchors.leftMargin: SimpleTheme.px(14); anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(18)
                        anchors.verticalCenter: parent.verticalCenter; wrapMode: Text.WordWrap; size: 22
                        text: qsTr("This cannot be undone. Deleting accounts and keys also unpairs the drone link.") }
            }
            Row {
                spacing: SimpleTheme.px(16)
                SButton { width: (delPopup.availableWidth - parent.spacing) / 2; text: qsTr("Cancel"); onClicked: delPopup.close() }
                SButton {
                    width: (delPopup.availableWidth - parent.spacing) / 2
                    objectName: "deleteSelected"
                    kind: "danger"; icon: "trash"
                    text: qsTr("Delete selected (%1)").arg(delPopup.count)
                    enabled_: delPopup.count > 0
                    onClicked: {
                        var keys = []
                        for (var k in delPopup.sel) if (delPopup.sel[k]) keys.push(k)
                        if (delPopup.sel.map) {
                            // the default set holds every cached tile: deleting it clears the whole cache, saved areas included
                            var m = sp._map.tileSets
                            for (var i = 0; i < m.count; i++) { var o = m.get(i); if (o && o.defaultSet) { sp._map.deleteTileSet(o); break } }
                        }
                        sp._pd.deleteData(keys)    // also logs the deletion (the map cache has no folder there)
                        delPopup.close()
                    }
                }
            }
        }
    }
}
