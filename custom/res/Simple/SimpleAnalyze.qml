/****************************************************************************
 * AQGC Simple UI — Analyze tools (Advanced mode, Figma S61 113:38985, S62 113:39141, S63 113:39273; 2026-11-17)
 * Frame like Settings (S09): header, categories left, content right.
 * - S61 Log download: classic LogDownloadController (list, download selected to the log folder, erase all).
 * - S62 Vibration: vehicle.vibration (30 = check, 60 = too high, clipping counts).
 * - Developer tools switch (setting simpleDeveloperTools, default off): S63 MAVLink Inspector (read only, classic
 *   MAVLinkInspectorController; charts stay in the classic inspector for now) and App log (debugMessageModel).
 ****************************************************************************/
import QtQuick 2.12
import QtQuick.Controls 2.4
import QGroundControl 1.0
import QGroundControl.Controllers 1.0
import "."

Rectangle {
    id: an
    property var    vs
    property string category: "logs"
    color: SimpleTheme.bgBase
    MouseArea { anchors.fill: parent }

    readonly property var  _veh:  QGroundControl.multiVehicleManager.activeVehicle
    readonly property var  _custom: QGroundControl.corePlugin.settings
    readonly property bool _dev:  !!_custom && !!_custom.simpleDeveloperTools.rawValue
    onCategoryChanged: if (!_dev && (category === "inspector" || category === "applog")) category = "logs"
    on_DevChanged:     if (!_dev && (category === "inspector" || category === "applog")) category = "logs"

    // Header
    Rectangle {
        id: header
        width: parent.width; height: SimpleTheme.px(104)
        color: SimpleTheme.surfaceGlass
        Row {
            anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
            spacing: SimpleTheme.px(20)
            SButton { designHeight: 80; icon: "back"; text: qsTr("Back"); textSize: 26; onClicked: simpleRoot.showFly() }
            SText { text: qsTr("Analyze tools"); size: 34; bold: true; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // Categories
    Rectangle {
        id: cats
        anchors.top: header.bottom; anchors.bottom: parent.bottom
        width: SimpleTheme.px(520)
        color: SimpleTheme.surfaceGlass
        Column {
            anchors.fill: parent
            anchors.margins: SimpleTheme.px(20)
            spacing: SimpleTheme.px(8)
            Repeater {
                model: [
                    { key: "logs",      icon: "download", title: qsTr("Log download"), dev: false },
                    { key: "vibration", icon: "signal",   title: qsTr("Vibration"),    dev: false }
                ]
                Rectangle {
                    width: parent.width; height: SimpleTheme.px(88); radius: SimpleTheme.px(18)
                    color: an.category === modelData.key ? SimpleTheme.brandGreen : "transparent"
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                        spacing: SimpleTheme.px(18)
                        SIcon { name: modelData.icon; size: 40; anchors.verticalCenter: parent.verticalCenter }
                        SText { text: modelData.title; size: 30; medium: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { anchors.fill: parent; onClicked: an.category = modelData.key }
                }
            }
            Rectangle { width: parent.width; height: 1; color: SimpleTheme.line }
            Item {
                width: parent.width; height: SimpleTheme.px(88)
                Row {
                    anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                    spacing: SimpleTheme.px(18)
                    SIcon { name: "sliders"; size: 40; anchors.verticalCenter: parent.verticalCenter }
                    SText { text: qsTr("Developer tools"); size: 30; medium: true; anchors.verticalCenter: parent.verticalCenter }
                }
                SToggle {
                    id: devToggle
                    objectName: "developerToolsToggle"
                    anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(12); anchors.verticalCenter: parent.verticalCenter
                    checked: an._dev
                    onToggled: {
                        an._custom.simpleDeveloperTools.rawValue = checked
                        devToggle.checked = Qt.binding(function() { return an._dev })
                    }
                }
            }
            Repeater {
                model: an._dev ? [
                    { key: "inspector", icon: "link",   title: qsTr("MAVLink Inspector") },
                    { key: "applog",    icon: "folder", title: qsTr("App log") }
                ] : []
                Rectangle {
                    width: parent.width; height: SimpleTheme.px(88); radius: SimpleTheme.px(18)
                    color: an.category === modelData.key ? SimpleTheme.brandGreen : "transparent"
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                        spacing: SimpleTheme.px(18)
                        SIcon { name: modelData.icon; size: 40; anchors.verticalCenter: parent.verticalCenter }
                        SText { text: modelData.title; size: 30; medium: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { anchors.fill: parent; onClicked: an.category = modelData.key }
                }
            }
        }
    }

    // Content (one page loaded at a time: the controllers only run while their page is open)
    Loader {
        id: content
        anchors.left: cats.right; anchors.leftMargin: SimpleTheme.px(60)
        anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(40)
        anchors.top: header.bottom; anchors.topMargin: SimpleTheme.px(40)
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(24)
        sourceComponent: an.category === "vibration" ? vibComp
                       : an.category === "inspector" ? inspComp
                       : an.category === "applog"    ? appLogComp
                       : logsComp
    }

    //================================================================== S61 Log download
    Component {
        id: logsComp
        Item {
            id: lg
            LogDownloadController { id: logCtl }
            property bool confirmErase: false
            readonly property int _selected: { var n = 0; _rev; for (var i = 0; i < logCtl.model.count; i++) { var e = logCtl.model.get(i); if (e && e.selected) n++ } return n }
            property int _rev: 0
            readonly property bool _busy: logCtl.requestingList || logCtl.downloadingLogs
            Component.onCompleted: if (an._veh) logCtl.refresh()

            Column {
                id: lgHead
                width: parent.width
                spacing: SimpleTheme.px(14)
                SText { text: qsTr("Log download"); size: 40; bold: true }
                SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                        text: qsTr("Flight logs saved on the drone. Download them for service or after an incident. A USB cable is faster than the radio.") }
                Item {
                    width: parent.width; height: SimpleTheme.px(80)
                    Row {
                        spacing: SimpleTheme.px(14)
                        SButton { designHeight: 80; textSize: 26; icon: "undo"; text: qsTr("Refresh"); objectName: "logRefresh"
                                  enabled_: !!an._veh && !lg._busy; onClicked: logCtl.refresh() }
                        SButton { designHeight: 80; textSize: 26; icon: "download"; kind: "primary"; objectName: "logDownload"
                                  visible: !logCtl.downloadingLogs
                                  text: qsTr("Download selected (%1)").arg(lg._selected)
                                  enabled_: !!an._veh && !lg._busy && lg._selected > 0; onClicked: logCtl.download() }
                        SButton { designHeight: 80; textSize: 26; icon: "close"; text: qsTr("Cancel")
                                  visible: logCtl.downloadingLogs || logCtl.requestingList; onClicked: logCtl.cancel() }
                    }
                    SButton { anchors.right: parent.right; designHeight: 80; textSize: 26; icon: "trash"; kind: "danger"
                              text: qsTr("Erase all logs")
                              enabled_: !!an._veh && !lg._busy && logCtl.model.count > 0 && !an._veh.armed
                              onClicked: lg.confirmErase = true }
                }
                // erase confirmation (inline)
                Rectangle {
                    visible: lg.confirmErase
                    width: parent.width; height: eraseRow.height + SimpleTheme.px(32); radius: SimpleTheme.px(16)
                    color: SimpleTheme.withAlpha(SimpleTheme.danger, 0.18); border.width: SimpleTheme.px(2); border.color: SimpleTheme.danger
                    Row {
                        id: eraseRow
                        anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                        spacing: SimpleTheme.px(16)
                        SText { anchors.verticalCenter: parent.verticalCenter; width: lg.width - SimpleTheme.px(560); wrapMode: Text.WordWrap; size: 24
                                text: qsTr("Erase all %1 logs on the drone? Logs not downloaded are lost.").arg(logCtl.model.count) }
                        SButton { designHeight: 72; textSize: 24; kind: "danger"; text: qsTr("Erase all"); objectName: "logEraseConfirm"
                                  onClicked: { lg.confirmErase = false; logCtl.eraseAll() } }
                        SButton { designHeight: 72; textSize: 24; text: qsTr("Cancel"); onClicked: lg.confirmErase = false }
                    }
                }
            }

            // table
            Rectangle {
                id: table
                anchors.top: lgHead.bottom; anchors.topMargin: SimpleTheme.px(16)
                width: parent.width
                height: Math.min(parent.height - lgHead.height - SimpleTheme.px(90), tHead.height + rowsCol.height + SimpleTheme.px(16))
                radius: SimpleTheme.px(18); color: SimpleTheme.surfaceRaised
                readonly property real cId: SimpleTheme.px(110)
                readonly property real cTime: SimpleTheme.px(320)
                readonly property real cSize: SimpleTheme.px(200)
                Row {
                    id: tHead
                    x: SimpleTheme.px(90); y: SimpleTheme.px(16); height: SimpleTheme.px(44)
                    SText { width: table.cId;   text: qsTr("Log");           size: 22; color: SimpleTheme.textSecondary }
                    SText { width: table.cTime; text: qsTr("Date and time"); size: 22; color: SimpleTheme.textSecondary }
                    SText { width: table.cSize; text: qsTr("Size");          size: 22; color: SimpleTheme.textSecondary }
                    SText { text: qsTr("Status"); size: 22; color: SimpleTheme.textSecondary }
                }
                Flickable {
                    anchors.top: tHead.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.bottomMargin: SimpleTheme.px(8)
                    clip: true
                    contentHeight: rowsCol.height
                    Column {
                        id: rowsCol
                        width: parent.width
                        SText {
                            visible: logCtl.model.count === 0
                            x: SimpleTheme.px(24); height: SimpleTheme.px(70); verticalAlignment: Text.AlignVCenter
                            size: 24; color: SimpleTheme.textSecondary
                            text: !an._veh ? qsTr("Connect the drone to see its logs.")
                                : logCtl.requestingList ? qsTr("Reading the list of logs…") : qsTr("No logs on the drone.")
                        }
                        Repeater {
                            model: logCtl.model
                            Item {
                                width: rowsCol.width; height: SimpleTheme.px(76)
                                readonly property var e: logEntry
                                Rectangle {
                                    id: cb
                                    x: SimpleTheme.px(24); anchors.verticalCenter: parent.verticalCenter
                                    width: SimpleTheme.px(40); height: width; radius: SimpleTheme.px(8)
                                    color: e && e.selected ? SimpleTheme.brandGreen : "transparent"
                                    border.width: SimpleTheme.px(3); border.color: e && e.selected ? SimpleTheme.brandGreen : SimpleTheme.textSecondary
                                    SIcon { anchors.centerIn: parent; name: "check"; size: 30; visible: !!e && e.selected }
                                }
                                Row {
                                    x: SimpleTheme.px(90); anchors.verticalCenter: parent.verticalCenter
                                    SText { width: table.cId; text: e ? "#" + e.id : ""; size: 26; medium: true }
                                    SText { width: table.cTime; size: 26
                                            text: e && e.received && e.time.getUTCFullYear() > 2000 ? Qt.formatDateTime(e.time, "yyyy-MM-dd  hh:mm") : "—" }
                                    SText { width: table.cSize; text: e ? e.sizeStr : ""; size: 26 }
                                    Item {
                                        width: SimpleTheme.px(420); height: SimpleTheme.px(44)
                                        // downloaded
                                        SStatusChip { visible: !!e && e.progress >= 1; anchors.verticalCenter: parent.verticalCenter
                                                      text: qsTr("Downloaded"); level: "ok" }
                                        // downloading
                                        Row {
                                            visible: !!e && e.progress >= 0 && e.progress < 1
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: SimpleTheme.px(14)
                                            Rectangle {
                                                width: SimpleTheme.px(180); height: SimpleTheme.px(10); radius: height / 2
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: SimpleTheme.surfaceControl
                                                Rectangle { width: parent.width * Math.max(0, e ? e.progress : 0); height: parent.height; radius: parent.radius; color: SimpleTheme.brandGreen }
                                            }
                                            SText { text: qsTr("Downloading %1 %").arg(Math.round((e ? e.progress : 0) * 100)); size: 24 }
                                        }
                                        // waiting / error / timed out / canceled
                                        SText { visible: !!e && e.progress < 0; anchors.verticalCenter: parent.verticalCenter; size: 24
                                                color: e && (e.status === qsTranslate("LogDownloadController", "Error") || e.status === qsTranslate("LogDownloadController", "Timed Out")) ? SimpleTheme.textDanger : SimpleTheme.textSecondary
                                                text: !e ? "" : (e.status === qsTranslate("LogDownloadController", "Available") || e.status === qsTranslate("LogDownloadController", "Pending")) ? "—" : e.status }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !lg._busy
                                    onClicked: { e.selected = !e.selected; lg._rev++ }
                                }
                            }
                        }
                    }
                }
            }
            SText {
                anchors.top: table.bottom; anchors.topMargin: SimpleTheme.px(16)
                width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                text: qsTr("Saved to %1. To send a log to ARGOSDYNE support, use Help & support.").arg(QGroundControl.settingsManager.appSettings.logSavePath)
            }
        }
    }

    //================================================================== S62 Vibration
    Component {
        id: vibComp
        Column {
            id: vb
            spacing: SimpleTheme.px(16)
            readonly property var  _vib: an._veh ? an._veh.vibration : null
            readonly property var  _vals: _vib ? [Number(_vib.xAxis.rawValue), Number(_vib.yAxis.rawValue), Number(_vib.zAxis.rawValue)] : [0, 0, 0]
            readonly property var  _clip: _vib ? [Number(_vib.clipCount1.rawValue), Number(_vib.clipCount2.rawValue), Number(_vib.clipCount3.rawValue)] : [0, 0, 0]
            readonly property real _max: Math.max(_vals[0], _vals[1], _vals[2])
            readonly property bool _clipping: _clip[0] > 0 || _clip[1] > 0 || _clip[2] > 0
            readonly property string _level: !_vib ? "info" : _max >= 60 ? "danger" : (_max >= 30 || _clipping) ? "warn" : "ok"

            SText { text: qsTr("Vibration"); size: 40; bold: true }
            SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                    text: qsTr("Hover for 30 seconds, then read the values. Check after changing propellers, motors or the payload.") }
            Rectangle {
                width: parent.width; height: SimpleTheme.px(92); radius: SimpleTheme.px(18)
                color: SimpleTheme.withAlpha(vb._level === "ok" ? SimpleTheme.ok : vb._level === "warn" ? SimpleTheme.warn : vb._level === "danger" ? SimpleTheme.danger : SimpleTheme.info, 0.18)
                Row {
                    anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(28); anchors.verticalCenter: parent.verticalCenter
                    spacing: SimpleTheme.px(18)
                    SIcon { name: vb._level === "ok" ? "check" : vb._level === "info" ? "info" : "warn"; size: 40; anchors.verticalCenter: parent.verticalCenter }
                    SText { anchors.verticalCenter: parent.verticalCenter; size: 30; bold: true
                            text: !vb._vib ? qsTr("Connect the drone") : vb._level === "ok" ? qsTr("Vibration is OK")
                                : vb._level === "warn" ? qsTr("Check the vibration") : qsTr("Vibration too high") }
                    SText { anchors.verticalCenter: parent.verticalCenter; size: 24; color: SimpleTheme.textSecondary
                            text: !vb._vib ? qsTr("Values come from the flight controller.")
                                : vb._level === "ok" ? qsTr("All axes below 30 m/s² · no clipping")
                                : vb._max >= 60 ? qsTr("An axis is above 60 m/s²: do not fly; check propellers, motors and mounts.")
                                : vb._clipping ? qsTr("The accelerometer clipped: check for loose parts.")
                                : qsTr("An axis is above 30 m/s²: check propellers and mounts.") }
                }
            }
            Row {
                width: parent.width
                spacing: SimpleTheme.px(16)
                Repeater {
                    model: [qsTr("X axis"), qsTr("Y axis"), qsTr("Z axis")]
                    Rectangle {
                        width: (vb.width - SimpleTheme.px(32)) / 3; height: SimpleTheme.px(190); radius: SimpleTheme.px(18)
                        color: SimpleTheme.surfaceRaised
                        readonly property real v: vb._vals[index]
                        Row {
                            x: SimpleTheme.px(28); y: SimpleTheme.px(24); spacing: SimpleTheme.px(12)
                            SText { text: modelData; size: 28; medium: true; anchors.baseline: num.baseline }
                            SText { id: num; text: vb._vib ? Math.round(v) : "—"; size: 48; bold: true }
                            SText { text: "m/s²"; size: 22; color: SimpleTheme.textSecondary; anchors.baseline: num.baseline }
                        }
                        Item {
                            id: scale
                            x: SimpleTheme.px(28); y: SimpleTheme.px(104)
                            width: parent.width - SimpleTheme.px(56); height: SimpleTheme.px(16)
                            Rectangle { anchors.fill: parent; radius: height / 2; color: SimpleTheme.surfaceControl }
                            Rectangle { width: parent.width * Math.min(1, Math.max(0, v) / 90); height: parent.height; radius: height / 2
                                        color: v >= 60 ? SimpleTheme.danger : v >= 30 ? SimpleTheme.warn : SimpleTheme.ok }
                            Rectangle { x: parent.width / 3; width: SimpleTheme.px(4); height: SimpleTheme.px(32); y: -SimpleTheme.px(8); color: SimpleTheme.warn }
                            Rectangle { x: parent.width * 2 / 3; width: SimpleTheme.px(4); height: SimpleTheme.px(32); y: -SimpleTheme.px(8); color: SimpleTheme.danger }
                        }
                        Item {
                            anchors.left: scale.left; anchors.right: scale.right; y: SimpleTheme.px(140); height: SimpleTheme.px(30)
                            SText { text: "0"; size: 20; color: SimpleTheme.textSecondary }
                            SText { x: parent.width / 3 - width / 2; text: qsTr("30 check"); size: 20; color: SimpleTheme.textSecondary }
                            SText { x: parent.width * 2 / 3 - width / 2; text: qsTr("60 too high"); size: 20; color: SimpleTheme.textSecondary }
                            SText { anchors.right: parent.right; text: "90"; size: 20; color: SimpleTheme.textSecondary }
                        }
                    }
                }
            }
            Rectangle {
                width: parent.width; height: Math.max(SimpleTheme.px(110), clipText.height + SimpleTheme.px(32)); radius: SimpleTheme.px(18)
                color: SimpleTheme.surfaceRaised
                Column {
                    id: clipText
                    anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(28)
                    anchors.right: clipChips.left; anchors.rightMargin: SimpleTheme.px(20)
                    anchors.verticalCenter: parent.verticalCenter
                    SText { text: qsTr("Clipping"); size: 28; medium: true }
                    SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                            text: qsTr("Times the accelerometer hit its limit. A number that keeps rising means a loose part.") }
                }
                Row {
                    id: clipChips
                    anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(24); anchors.verticalCenter: parent.verticalCenter
                    spacing: SimpleTheme.px(12)
                    Repeater {
                        model: 3
                        SStatusChip { text: qsTr("Accel %1: %2").arg(index + 1).arg(vb._vib ? vb._clip[index] : "—")
                                      level: !vb._vib ? "info" : vb._clip[index] > 0 ? "warn" : "ok" }
                    }
                }
            }
        }
    }

    //================================================================== S63 MAVLink Inspector (developer, read only)
    Component {
        id: inspComp
        Item {
            id: ins
            MAVLinkInspectorController { id: inspCtl }
            readonly property var _sys: inspCtl.activeSystem
            // the controller fills field values only for the message selected on the system
            readonly property int sel: _sys ? _sys.selected : 0
            readonly property var _msg: _sys && _sys.messages.count > 0 ? _sys.messages.get(Math.max(0, Math.min(sel, _sys.messages.count - 1))) : null

            Column {
                id: insHead
                width: parent.width
                spacing: SimpleTheme.px(14)
                SText { text: qsTr("MAVLink Inspector"); size: 40; bold: true }
                Rectangle {
                    width: parent.width; height: SimpleTheme.px(60); radius: SimpleTheme.px(14)
                    color: SimpleTheme.withAlpha(SimpleTheme.info, 0.18); border.width: SimpleTheme.px(2); border.color: SimpleTheme.info
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(18); anchors.verticalCenter: parent.verticalCenter
                        spacing: SimpleTheme.px(12)
                        SIcon { name: "info"; size: 30; anchors.verticalCenter: parent.verticalCenter }
                        SText { text: qsTr("For developers and service. Read only: nothing here changes the drone."); size: 22; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
            SText {
                visible: !ins._sys
                anchors.top: insHead.bottom; anchors.topMargin: SimpleTheme.px(24)
                text: qsTr("Connect the drone to see its messages."); size: 26; color: SimpleTheme.textSecondary
            }
            // message list
            Rectangle {
                id: msgList
                visible: !!ins._sys
                anchors.top: insHead.bottom; anchors.topMargin: SimpleTheme.px(16); anchors.bottom: parent.bottom
                width: parent.width * 0.42; radius: SimpleTheme.px(18); color: SimpleTheme.surfaceRaised
                ListView {
                    anchors.fill: parent; anchors.margins: SimpleTheme.px(8)
                    clip: true
                    model: ins._sys ? ins._sys.messages : null
                    delegate: Rectangle {
                        width: ListView.view.width; height: SimpleTheme.px(70); radius: SimpleTheme.px(12)
                        color: index === ins.sel ? SimpleTheme.surfaceControl : "transparent"
                        SText { anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                                text: object.name; size: 24 }
                        SText { anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                                text: object.messageHz.toFixed(1) + " Hz"; size: 22; color: SimpleTheme.textSecondary }
                        MouseArea { anchors.fill: parent; onClicked: ins._sys.selected = index }
                    }
                }
            }
            // fields of the selected message
            Rectangle {
                visible: !!ins._msg
                anchors.top: msgList.top; anchors.bottom: parent.bottom
                anchors.left: msgList.right; anchors.leftMargin: SimpleTheme.px(16); anchors.right: parent.right
                radius: SimpleTheme.px(18); color: SimpleTheme.surfaceRaised
                SText {
                    id: msgTitle
                    x: SimpleTheme.px(24); y: SimpleTheme.px(18)
                    text: ins._msg ? qsTr("%1 · system %2, component %3").arg(ins._msg.name).arg(ins._sys.id).arg(ins._msg.cid) : ""
                    size: 26; bold: true
                }
                ListView {
                    anchors.top: msgTitle.bottom; anchors.topMargin: SimpleTheme.px(10)
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: chartBtn.top
                    anchors.leftMargin: SimpleTheme.px(24); anchors.rightMargin: SimpleTheme.px(24); anchors.bottomMargin: SimpleTheme.px(10)
                    clip: true
                    model: ins._msg ? ins._msg.fields : null
                    delegate: Item {
                        width: ListView.view.width; height: SimpleTheme.px(60)
                        SText { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: object.name; size: 22; color: SimpleTheme.textSecondary }
                        SText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: object.value; size: 24; bold: true
                                width: parent.width * 0.6; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft }
                    }
                }
                SButton {
                    id: chartBtn
                    anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(24); anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(18)
                    designHeight: 72; textSize: 24; icon: "layers"
                    text: qsTr("Charts (classic inspector)")
                    onClicked: simpleRoot.openClassic("analyze")
                }
            }
        }
    }

    //================================================================== App log (developer)
    Component {
        id: appLogComp
        Item {
            id: al
            property string saved: ""
            Column {
                id: alHead
                width: parent.width
                spacing: SimpleTheme.px(14)
                SText { text: qsTr("App log"); size: 40; bold: true }
                Item {
                    width: parent.width; height: SimpleTheme.px(80)
                    SText { anchors.verticalCenter: parent.verticalCenter; width: parent.width - saveBtn.width - SimpleTheme.px(20)
                            wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                            text: al.saved !== "" ? qsTr("Saved: %1").arg(al.saved) : qsTr("Messages of this app since it started (newest at the bottom). Secrets are never written to it.") }
                    SButton {
                        id: saveBtn
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        designHeight: 72; textSize: 24; icon: "download"; text: qsTr("Save to file")
                        onClicked: {
                            var f = QGroundControl.settingsManager.appSettings.logSavePath + "/AppLog_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss") + ".txt"
                            debugMessageModel.writeMessages(f)
                            al.saved = f
                        }
                    }
                }
            }
            Rectangle {
                anchors.top: alHead.bottom; anchors.topMargin: SimpleTheme.px(12); anchors.bottom: parent.bottom
                width: parent.width; radius: SimpleTheme.px(18); color: SimpleTheme.surfaceRaised
                // the log keeps only the categories turned on in the classic logging page (all off by default)
                Column {
                    visible: logView.count === 0
                    anchors.centerIn: parent
                    width: parent.width * 0.7
                    spacing: SimpleTheme.px(18)
                    SText { width: parent.width; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; size: 24; color: SimpleTheme.textSecondary
                            text: qsTr("No messages yet. The app records only the log categories that are turned on (all are off by default).") }
                    SButton { anchors.horizontalCenter: parent.horizontalCenter; designHeight: 72; textSize: 24; icon: "sliders"
                              text: qsTr("Choose log categories (classic)"); onClicked: simpleRoot.openClassic("analyze") }
                }
                ListView {
                    id: logView
                    anchors.fill: parent; anchors.margins: SimpleTheme.px(16)
                    clip: true
                    model: debugMessageModel
                    delegate: SText { width: ListView.view.width; text: display; size: 18; wrapMode: Text.WrapAnywhere; color: SimpleTheme.textSecondary }
                    onCountChanged: if (atYEnd || count < 3) positionViewAtEnd()
                    Component.onCompleted: positionViewAtEnd()
                }
            }
        }
    }
}
