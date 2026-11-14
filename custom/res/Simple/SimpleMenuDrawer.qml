/****************************************************************************
 * AQGC Simple UI — S06 menu drawer
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

Item {
    id: drawer
    property var vs
    property bool opened: false
    function open()  { opened = true }
    function close() { opened = false }
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
                    { key: "plan",     icon: "plan",     title: qsTr("Plan a mission"),   sub: qsTr("Area mapping (more in next version)"), enabled: true },
                    { key: "saved",    icon: "folder",   title: qsTr("Saved missions"),   sub: qsTr("Next version · Advanced › Plan"),  enabled: false },
                    { key: "maps",     icon: "download", title: qsTr("Offline maps"),     sub: qsTr("Next version · Advanced › Settings"),     enabled: false },
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
                            else if (modelData.key === "settings")  simpleRoot.showSettings("general")
                            else if (modelData.key === "help")      simpleRoot.showSettings("about")
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: SimpleTheme.line }

            // Advanced mode (admin PIN)
            Rectangle {
                width: parent.width; height: SimpleTheme.px(96); radius: SimpleTheme.px(18)
                color: SimpleTheme.surfaceRaised
                Row {
                    anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                    spacing: SimpleTheme.px(20)
                    SIcon { name: "lock"; size: 44; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        SText { text: qsTr("Advanced mode"); size: 30; medium: true }
                        SText { text: qsTr("Setup, parameters, tools · PIN"); size: 22; color: SimpleTheme.textSecondary; width: SimpleTheme.px(340); elide: Text.ElideRight }
                    }
                }
                SToggle { anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter; checked: false; enabled: false }
                MouseArea { anchors.fill: parent; onClicked: { drawer.close(); simpleRoot.requestAdvanced("advanced") } }
            }
        }
        SText {
            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: SimpleTheme.px(28)
            text: "alesQGC " + QGroundControl.qgcVersion + "  ·  ARGOSDYNE"
            size: 22; color: SimpleTheme.textTertiary
        }
    }
}
