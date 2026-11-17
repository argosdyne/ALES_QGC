/****************************************************************************
 * AQGC Simple UI — S06 menu drawer + S44 Advanced panel (Figma 36:34086, 2026-11-17)
 * Advanced mode (no PIN, kept over restarts) keeps the Simple screens and adds the Advanced panel. Its items open
 * the classic alesQGC pages until the new screens (S58–S80) exist; "Classic alesQGC screens" is temporary.
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

Item {
    id: drawer
    property var vs
    property bool opened: false
    property bool advancedOpen: false       // S44 panel next to the menu
    property bool profileOpen: false
    readonly property bool _adv: QGroundControl.corePlugin.advancedMode
    readonly property var  _profileNames: [qsTr("Inspection / Surveillance"), qsTr("Mapping"), qsTr("Tether"), qsTr("Cleaning")]
    function open()  { opened = true }
    function close() { opened = false; advancedOpen = false; profileOpen = false }
    visible: opened

    Rectangle {
        anchors.fill: parent
        color: SimpleTheme.withAlpha("black", 0.5)
        MouseArea { anchors.fill: parent; onClicked: drawer.close() }
    }

    Rectangle {
        id: panel
        width:  SimpleTheme.px(620)
        height: parent.height
        color:  SimpleTheme.surfaceGlass
        MouseArea { anchors.fill: parent }

        Column {
            anchors.fill: parent
            anchors.margins: SimpleTheme.px(28)
            spacing: SimpleTheme.px(8)

            // Vehicle header
            Row {
                spacing: SimpleTheme.px(18)
                height: SimpleTheme.px(90)
                SIcon { name: "drone"; size: 56; color: vs.connected ? SimpleTheme.ok : SimpleTheme.textTertiary; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    SText { text: vs.present ? (vs.vehicle.vehicleTypeString + " · " + vs.vehicle.id) : qsTr("No drone"); size: 32; bold: true }
                    SText { text: vs.connected ? qsTr("Connected") : vs.lost ? qsTr("Connection lost") : qsTr("Not connected"); size: 24; color: vs.connected ? SimpleTheme.ok : SimpleTheme.textSecondary }
                }
            }

            Repeater {
                model: [
                    { key: "fly",      icon: "map",      title: qsTr("Fly"),              sub: qsTr("Map, camera and flight controls"),           enabled: true },
                    { key: "plan",     icon: "plan",     title: qsTr("Plan a mission"),   sub: qsTr("Area mapping, waypoint flight"), enabled: true },
                    { key: "saved",    icon: "folder",   title: qsTr("Saved missions"),   sub: qsTr("Open, import, rename, delete"),  enabled: true },
                    { key: "maps",     icon: "download", title: qsTr("Offline maps"),     sub: qsTr("Download maps before you go"),            enabled: true },
                    { key: "settings", icon: "sliders",  title: qsTr("Settings"),         sub: qsTr("Safety, units, language"),                   enabled: true },
                    { key: "help",     icon: "help",     title: qsTr("Help & support"),   sub: qsTr("Versions, manual, contact"),                 enabled: true }
                ]
                Rectangle {
                    width: parent.width; height: SimpleTheme.px(96); radius: SimpleTheme.px(18)
                    color: (modelData.key === "fly" && simpleRoot.page === "fly") || (modelData.key === "plan" && simpleRoot.page === "plan")
                           || (modelData.key === "settings" && simpleRoot.page === "settings") ? SimpleTheme.brandGreen : "transparent"
                    opacity: modelData.enabled ? 1 : 0.45
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                        spacing: SimpleTheme.px(20)
                        SIcon { name: modelData.icon; size: 44; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            SText { text: modelData.title; size: 30; medium: true }
                            SText { text: modelData.sub; size: 22; color: SimpleTheme.textSecondary; width: SimpleTheme.px(450); elide: Text.ElideRight }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: modelData.enabled
                        onClicked: {
                            drawer.close()
                            if (modelData.key === "fly")            simpleRoot.showFly()
                            else if (modelData.key === "plan")      simpleRoot.showPlan()
                            else if (modelData.key === "saved")     simpleRoot.showSaved()              // S24 saved missions
                            else if (modelData.key === "maps")      simpleRoot.showSettings("maps")     // S46 offline maps
                            else if (modelData.key === "settings")  simpleRoot.showSettings("general")
                            else if (modelData.key === "help")      simpleRoot.showSettings("about")
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: SimpleTheme.line }

            // Advanced mode (no PIN, Figma S06 / S44): the switch turns it on and opens the Advanced panel
            Rectangle {
                objectName: "advancedRow"
                width: parent.width; height: SimpleTheme.px(96); radius: SimpleTheme.px(18)
                color: drawer._adv ? SimpleTheme.withAlpha(SimpleTheme.brandGreen, 0.18) : SimpleTheme.surfaceRaised
                border.width: drawer._adv ? SimpleTheme.px(2) : 0; border.color: SimpleTheme.brandGreen
                MouseArea {
                    anchors.fill: parent
                    onClicked: { QGroundControl.corePlugin.advancedMode = true; drawer.advancedOpen = true }
                }
                Row {
                    anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                    spacing: SimpleTheme.px(20)
                    SIcon { name: "layers"; size: 44; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        SText { text: qsTr("Advanced mode"); size: 30; medium: true }
                        SText { text: drawer._adv ? qsTr("On · tools for setup and service") : qsTr("Setup, parameters, tools")
                                size: 22; color: SimpleTheme.textSecondary; width: SimpleTheme.px(340); elide: Text.ElideRight }
                    }
                }
                SToggle {
                    id: advToggle
                    objectName: "advancedToggle"
                    anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                    checked: drawer._adv
                    onToggled: {
                        QGroundControl.corePlugin.advancedMode = checked
                        drawer.advancedOpen = checked
                        advToggle.checked = Qt.binding(function() { return drawer._adv })
                    }
                }
            }
        }
        SText {
            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: SimpleTheme.px(28)
            text: "alesQGC " + QGroundControl.qgcVersion + "  ·  ARGOSDYNE"
            size: 22; color: SimpleTheme.textTertiary
        }
    }

    //------------------------------------------------------------------ S44 Advanced panel
    SPanel {
        id: advPanel
        objectName: "advancedPanel"
        visible: drawer.advancedOpen && drawer._adv
        closable: false
        x: panel.width + SimpleTheme.px(28)
        y: SimpleTheme.px(26)
        width: SimpleTheme.px(634)
        height: advCol.height + SimpleTheme.px(48)

        Column {
            id: advCol
            x: SimpleTheme.px(24); y: SimpleTheme.px(24)
            width: parent.width - SimpleTheme.px(48)
            spacing: SimpleTheme.px(12)

            Row {
                spacing: SimpleTheme.px(16)
                SIcon { name: "layers"; size: 44; color: SimpleTheme.ok; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    SText { text: qsTr("Advanced"); size: 34; bold: true }
                    SText { text: qsTr("Setup, service and expert tools"); size: 22; color: SimpleTheme.textSecondary }
                }
            }
            Repeater {
                model: [
                    { key: "setup",      icon: "drone",   t: qsTr("Vehicle setup"),  s: qsTr("Frame, sensors, radio, flight modes, power"), warn: false },
                    { key: "parameters", icon: "sliders", t: qsTr("Parameters"),     s: qsTr("All flight controller parameters"), warn: true },
                    { key: "analyze",    icon: "folder",  t: qsTr("Analyze tools"),  s: qsTr("Log download, vibration, developer tools"), warn: false },
                    { key: "settings",   icon: "sliders", t: qsTr("More settings"),  s: qsTr("Fly screen, video, plan, data & logs, devices"), warn: false },
                    { key: "profile",    icon: "grid",    t: qsTr("Product profile"), warn: false,
                      s: qsTr("%1 · change").arg(drawer._profileNames[Math.max(0, Math.min(3, Number(QGroundControl.corePlugin.settings.simpleProductProfile.rawValue)))]) },
                    { key: "classic",    icon: "info",    t: qsTr("Classic alesQGC screens"), s: qsTr("Until every screen is redesigned (temporary)"), warn: false }
                ]
                Rectangle {
                    objectName: "adv_" + modelData.key
                    width: advCol.width; height: Math.max(SimpleTheme.px(100), advText.height + SimpleTheme.px(24)); radius: SimpleTheme.px(18)
                    color: advMouse.pressed ? Qt.darker(SimpleTheme.surfaceRaised, 1.25) : SimpleTheme.surfaceRaised
                    MouseArea {
                        id: advMouse
                        anchors.fill: parent
                        onClicked: {
                            if (modelData.key === "profile") { drawer.profileOpen = !drawer.profileOpen; return }
                            drawer.close()
                            if (modelData.key === "analyze")    { simpleRoot.showAnalyze(); return }      // S61–S63
                            if (modelData.key === "parameters") { simpleRoot.showParameters(); return }   // S60
                            if (modelData.key === "setup")      { simpleRoot.showVehicleSetup(); return }   // S58
                            simpleRoot.openClassic(modelData.key === "classic" ? "fly" : modelData.key)
                        }
                    }
                    SIcon { id: advIcon; name: modelData.icon; size: 40; anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(22); anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        id: advText
                        anchors.left: advIcon.right; anchors.leftMargin: SimpleTheme.px(20)
                        anchors.right: advChev.left; anchors.rightMargin: SimpleTheme.px(12)
                        anchors.verticalCenter: parent.verticalCenter
                        SText { width: parent.width; text: modelData.t; size: 30; medium: true }
                        SText { width: parent.width; text: modelData.s; size: 22; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                                color: modelData.warn ? SimpleTheme.warn : SimpleTheme.textSecondary }
                    }
                    SIcon { id: advChev; name: "chevron"; size: 36; opacity: 0.7
                            anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(18); anchors.verticalCenter: parent.verticalCenter
                            rotation: modelData.key === "profile" && drawer.profileOpen ? 90 : 0 }
                }
            }
            // Product profile choice (on the ground; Tether = S11 fly screen)
            Flow {
                visible: drawer.profileOpen
                width: advCol.width
                spacing: SimpleTheme.px(10)
                Repeater {
                    model: drawer._profileNames
                    SButton {
                        designHeight: 72; textSize: 24
                        kind: Number(QGroundControl.corePlugin.settings.simpleProductProfile.rawValue) === index ? "primary" : "secondary"
                        text: modelData
                        enabled_: !drawer.vs.armed
                        onClicked: QGroundControl.corePlugin.settings.simpleProductProfile.rawValue = index
                    }
                }
            }
            SButton {
                objectName: "returnToSimple"
                width: advCol.width
                text: qsTr("Return to Simple")
                onClicked: { QGroundControl.corePlugin.advancedMode = false; drawer.advancedOpen = false }
            }
        }
    }
}
