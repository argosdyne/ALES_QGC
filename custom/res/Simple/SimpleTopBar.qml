/****************************************************************************
 * AQGC Simple UI — top bar (Figma ui/TopBar): Menu · flight status · flight mode · 4 chips · messages
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

Rectangle {
    id: bar
    property var vs
    signal menuClicked()
    signal statusClicked()
    signal modeClicked()
    signal chipClicked(string which)
    signal messagesClicked()

    height: SimpleTheme.px(SimpleTheme.topBarHeight)
    color:  SimpleTheme.withAlpha(SimpleTheme.bgBase, 0.95)

    readonly property var    _veh: vs.vehicle
    readonly property string _statusText: {
        switch (vs.state) {
        case "disconnected":    return qsTr("Not connected")
        case "lost":            return qsTr("Signal lost")
        case "returning":       return vs.landing ? qsTr("Landing") : qsTr("Returning home")
        case "flying":          return vs.paused ? qsTr("Paused · hovering") : vs.missionActive ? qsTr("Flying · mission") : qsTr("Flying")
        default:                return vs.readyToTakeOff ? qsTr("Ready to fly") : qsTr("1 item to fix")
        }
    }
    readonly property color _statusColor: {
        switch (vs.state) {
        case "disconnected":    return SimpleTheme.surfaceControl
        case "lost":            return SimpleTheme.danger
        case "returning":       return SimpleTheme.warn
        case "flying":          return vs.paused ? SimpleTheme.warn : SimpleTheme.info
        default:                return vs.readyToTakeOff ? SimpleTheme.brandGreen : SimpleTheme.warn
        }
    }

    MouseArea { anchors.fill: parent }   // do not pass clicks to the map

    Row {
        anchors.left: parent.left
        anchors.leftMargin: SimpleTheme.px(16)
        anchors.verticalCenter: parent.verticalCenter
        spacing: SimpleTheme.px(16)

        SButton {
            designHeight: 80
            icon: "menu"
            text: qsTr("Menu")
            textSize: 24
            onClicked: bar.menuClicked()
        }
        Rectangle {
            id: status
            height: SimpleTheme.px(80)
            width:  statusRow.implicitWidth + SimpleTheme.px(48)
            radius: height / 2
            color:  bar._statusColor
            Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: SimpleTheme.px(12)
                Rectangle { width: SimpleTheme.px(14); height: width; radius: width / 2; color: SimpleTheme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                SText { text: bar._statusText; size: 30; bold: true; color: vs.state === "returning" || (vs.state === "ground" && !vs.readyToTakeOff) || vs.paused ? SimpleTheme.bgBase : SimpleTheme.textPrimary }
                SIcon { name: "chevron"; size: 28; anchors.verticalCenter: parent.verticalCenter; opacity: 0.7 }
            }
            MouseArea { anchors.fill: parent; onClicked: bar.statusClicked() }
        }
        Item {
            visible: vs.present
            anchors.verticalCenter: parent.verticalCenter
            width: modeCol.implicitWidth; height: modeCol.implicitHeight
            Column {
                id: modeCol
                SText { text: qsTr("FLIGHT MODE"); size: 22; medium: true; color: SimpleTheme.textSecondary }
                SText { text: vs.mode; size: 26; bold: true }
            }
            MouseArea { anchors.fill: parent; onClicked: bar.modeClicked() }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: SimpleTheme.px(16)
        anchors.verticalCenter: parent.verticalCenter
        spacing: SimpleTheme.px(12)

        SChip {
            icon: "battery"
            level: vs.batteryLevel
            value: isNaN(vs.batteryPct) ? "—" : Math.round(vs.batteryPct) + "%"
            label: vs.batteryTime !== "" ? "≈ " + vs.batteryTime : qsTr("Battery")
            onClicked: bar.chipClicked("battery")
        }
        SChip {
            icon: "gps"
            level: vs.gpsLevel
            value: vs.present ? vs.gpsCount : "—"
            label: vs.present ? vs.gpsQuality : qsTr("GPS")
            onClicked: bar.chipClicked("gps")
        }
        SChip {
            icon: "signal"
            level: vs.linkLevel
            value: vs.linkText
            label: qsTr("Link")
            onClicked: bar.chipClicked("link")
        }
        SChip {
            icon: "rid"
            level: vs.ridLevel
            value: !vs.ridAvailable ? qsTr("Off") : vs.ridGood ? qsTr("On") : qsTr("Check")
            label: qsTr("Remote ID")
            onClicked: bar.chipClicked("rid")
        }
        Rectangle {
            width: SimpleTheme.px(80); height: width; radius: SimpleTheme.px(16)
            color: SimpleTheme.surfaceRaised
            SIcon { anchors.centerIn: parent; name: "bell"; size: 40 }
            Rectangle {
                visible: vs.present && bar._veh.newMessageCount > 0
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: -SimpleTheme.px(4)
                width: SimpleTheme.px(30); height: width; radius: width / 2
                color: bar._veh && bar._veh.messageTypeError ? SimpleTheme.danger : SimpleTheme.warn
                SText { anchors.centerIn: parent; text: bar._veh ? bar._veh.newMessageCount : ""; size: 18; bold: true }
            }
            MouseArea { anchors.fill: parent; onClicked: bar.messagesClicked() }
        }
    }
}
