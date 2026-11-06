import QtQuick 2.12
import QtQuick.Controls 2.4
import QtQuick.Controls 2.4 as Controls2
import QtQuick.Dialogs 1.3
import QtQuick.Layouts 1.12

import QGroundControl 1.0
import QGroundControl.Controls 1.0
import QGroundControl.Palette 1.0
import QGroundControl.ScreenTools 1.0

Rectangle {
    id: root

    property var station: QGroundControl.corePlugin.elistairStationManager
    property color backgroundColor: "#1f2328"
    property color cardColor: "#2b3138"
    property color mutedText: "#9ca5b5"
    property color dividerColor: "#3a424d"
    property color green: "#00a77c"
    property color blue: "#1689db"
    property color orange: "#d68714"
    property color danger: "#e1544e"
    property color localButton: "#515b67"
    // Keep controls usable during the 1-second NO REPLY grace period, but
    // lock them after the 5-second LOST threshold or before first telemetry.
    readonly property bool controlsAvailable: station && station.frameVersionDetected && station.hasMonitoring && !station.linkLost && (station.connected || station.noReply)
    function measurement(value) { return isFinite(value) ? Number(value).toFixed(1) : "—" }
    readonly property real telemetryOpacity: station && station.linkLost ? 0.48 : 1.0
    readonly property color lostColor: "#68717b"
    readonly property bool inFlight: station && station.powerOffRequiresConfirmation
    readonly property var flightVehicle: QGroundControl.multiVehicleManager.activeVehicle
    Controls2.Dialog {
        id: associateVehicleDialog
        property var candidate: null
        property real incident: 0
        parent: Controls2.Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.85, ScreenTools.defaultFontPixelWidth * 52)
        implicitHeight: ScreenTools.defaultFontPixelHeight * 14
        modal: true
        title: qsTr("Confirm tethered vehicle")
        standardButtons: Controls2.Dialog.Yes | Controls2.Dialog.No
        contentItem: QGCLabel {
            width: associateVehicleDialog.availableWidth
            wrapMode: Text.WordWrap
            text: qsTr("Verify that vehicle %1 (UID %2) is physically connected to this tether station. Association does not send Land/RTL; a separate slide confirmation is required.")
                .arg(associateVehicleDialog.candidate ? associateVehicleDialog.candidate.id : "--")
                .arg(associateVehicleDialog.candidate ? associateVehicleDialog.candidate.vehicleUIDStr : "--")
        }
        onAccepted: {
            root.station.associateNoPowerVehicle(incident, candidate)
            candidate = null
        }
        onRejected: candidate = null
    }
    readonly property var droneBattery: flightVehicle && !flightVehicle.vehicleLinkManager.communicationLost && flightVehicle.batteries.count ? flightVehicle.batteries.get(0) : null
    function droneBatteryText() {
        var volts = droneBattery ? Number(droneBattery.voltage.rawValue) : NaN
        var seconds = droneBattery ? Number(droneBattery.timeRemaining.rawValue) : NaN
        return (isFinite(volts) && volts > 0 ? volts.toFixed(1) + " V" : qsTr("Voltage unavailable")) + " - " +
                (isFinite(seconds) && seconds > 0 ? Math.floor(seconds / 60) + ":" + ("0" + Math.floor(seconds % 60)).slice(-2) + qsTr(" left") : qsTr("time unavailable"))
    }

    visible: station !== null
    width: ScreenTools.defaultFontPixelWidth * 31
    height: Math.min(parent ? parent.height - ScreenTools.defaultFontPixelHeight * 2 : ScreenTools.defaultFontPixelHeight * 38,
                     ScreenTools.defaultFontPixelHeight * 38)
    color: backgroundColor
    opacity: 1.0
    layer.enabled: true
    layer.smooth: false
    z: 100000
    radius: ScreenTools.defaultFontPixelWidth * 0.7
    border.color: "#2c343e"
    border.width: 1

    QGCPalette { id: qgcPal; colorGroupEnabled: root.enabled }

    function percent(value, maximum) {
        return maximum <= 0 ? 0 : Math.max(0, Math.min(1, value / maximum))
    }

    // Kept as a separate item because the Android scene graph can skip the
    // root Rectangle fill when this file is instantiated through Loader.
    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
        opacity: 1.0
        z: 100001
    }

    ColumnLayout {
        z: 100002
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth * 0.8
        spacing: ScreenTools.defaultFontPixelHeight * 0.28

        RowLayout {
            Layout.fillWidth: true
            QGCLabel {
                text: qsTr("Tether")
                color: "white"
                font.family: ScreenTools.demiboldFontFamily
                font.pointSize: ScreenTools.largeFontPointSize
            }
            Item { Layout.fillWidth: true }
            QGCLabel { text: !station.frameVersionDetected ? "—" : station.activeFrameVersion === "Standard" ? "STD" : station.activeFrameVersion === "Extended V0" ? "V0" : "V1"; color: root.mutedText; font.pointSize: ScreenTools.smallFontPointSize }
            Rectangle {
                Layout.preferredWidth: connectedLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.3
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.65
                radius: height / 2
                color: station.noPower ? root.danger : station.linkLost ? root.lostColor : (station.noReply ? root.lostColor : root.green)
                QGCLabel {
                    id: connectedLabel
                    anchors.centerIn: parent
                    text: station.noPower ? qsTr("NO POWER") : station.linkLost ? qsTr("LOST > 5 s") : (station.noReply ? qsTr("NO REPLY") : (!station.frameVersionDetected ? qsTr("CONNECTING") : qsTr("CONNECTED")))
                    color: "white"
                    font.family: ScreenTools.demiboldFontFamily
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }
        }

        QGCLabel {
            Layout.fillWidth: true
            text: qsTr("SAFE-T #1 - %1:%2 - %3").arg(station.stationAddress).arg(station.stationPort).arg(station.frameVersionDetected ? station.activeFrameVersion : qsTr("Not detected"))
            color: mutedText
            font.pointSize: ScreenTools.smallFontPointSize
            elide: Text.ElideRight
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: dividerColor }

        Rectangle {
            visible: station.linkLost
            Layout.fillWidth: true
            Layout.preferredHeight: linkLostText.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.5
            color: "#765718"
            radius: ScreenTools.defaultFontPixelWidth * 0.25
            QGCLabel {
                id: linkLostText
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                text: qsTr("Station link lost - last data %1 - reconnecting attempt %2").arg(station.lastMonitoringTime.length ? station.lastMonitoringTime : "--").arg(station.reconnectAttempt)
                color: "#ffe2a0"
                wrapMode: Text.WordWrap
                font.pointSize: ScreenTools.smallFontPointSize
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: !station.noPower
        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth * 0.7
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.85
                color: !root.controlsAvailable ? "#59616b" : (station.powerOn && !station.powerOffPending ? root.blue : "#48525d")
                border.color: !root.controlsAvailable ? "#6d7681" : (station.powerOn && !station.powerOffPending ? root.blue : "#69717b"); border.width: 1
                QGCLabel { anchors.centerIn: parent; text: qsTr("Power ON"); color: root.controlsAvailable ? "white" : "#9ca5b5"; font.pointSize: ScreenTools.defaultFontPointSize }
                MouseArea { anchors.fill: parent; enabled: root.controlsAvailable && !station.powerOn; onClicked: station.setPowerOn(true) }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.85
                color: !root.controlsAvailable ? "#59616b" : (station.powerOffPending ? root.green : (!station.powerOn ? root.blue : "#48525d"))
                border.color: station.powerOffPending ? root.danger : (!root.controlsAvailable ? "#6d7681" : (!station.powerOn ? root.blue : "#69717b")); border.width: station.powerOffPending ? 2 : 1
                QGCLabel { anchors.centerIn: parent; text: qsTr("Power OFF"); color: root.controlsAvailable ? "white" : "#9ca5b5"; font.pointSize: ScreenTools.defaultFontPointSize }
                MouseArea {
                    anchors.fill: parent; enabled: root.controlsAvailable && station.powerOn && !station.powerOffPending
                    onClicked: station.setPowerOn(false)
                }
            }
        }

        QGCLabel {
            Layout.fillWidth: true
            visible: root.inFlight
            text: qsTr("In flight: Power OFF \u2192 slide to confirm")
            color: root.mutedText
            font.pointSize: ScreenTools.smallFontPointSize
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("Automatic Torque Control")
                color: root.mutedText
                font.pointSize: ScreenTools.defaultFontPointSize
                elide: Text.ElideRight
            }
            Switch {
                id: torqueControlSwitch
                objectName: "automaticTorqueControlSwitch"
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 4.7
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.4
                padding: 0
                checked: station.torqueRemote
                enabled: root.controlsAvailable
                onClicked: station.setTorqueRemote(checked)
                contentItem: Item {}
                indicator: Rectangle {
                    width: torqueControlSwitch.width
                    height: ScreenTools.defaultFontPixelHeight
                    y: (torqueControlSwitch.height - height) / 2
                    radius: height / 2
                    color: !torqueControlSwitch.enabled ? "#59616b" : (torqueControlSwitch.checked ? root.green : "#69717b")
                    Rectangle {
                        width: parent.height - 6; height: width; radius: width / 2
                        x: torqueControlSwitch.checked ? parent.width - width - 3 : 3
                        y: 3
                        color: torqueControlSwitch.enabled ? "white" : "#a1a9b8"
                    }
                }
            }
            QGCLabel {
                text: station.torqueRemote ? qsTr("ON") : qsTr("OFF")
                color: root.controlsAvailable ? "white" : root.mutedText
                font.pointSize: ScreenTools.smallFontPointSize
            }
        }

        RowLayout {
            Layout.fillWidth: true
            QGCLabel { text: qsTr("Torque"); color: mutedText; font.pointSize: ScreenTools.defaultFontPointSize }
            Item { Layout.fillWidth: true }
            QGCLabel {
                text: qsTr("set %1% - applied %2%").arg(station.torqueSetpointAvailable ? station.torquePercent : "—").arg(station.activeFrameVersion === "Extended V1" && station.hasMonitoring ? station.appliedTorquePercent : "—")
                color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.defaultFontPointSize
            }
        }

        Slider {
            id: torqueSlider
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.15
            from: 0; to: 100; stepSize: 1
            enabled: root.controlsAvailable && station.torqueRemote
            opacity: station.torqueRemote ? 1.0 : 0.55
            value: station.torquePercent
            onMoved: station.setTorquePercent(Math.round(value))
            background: Rectangle {
                x: torqueSlider.leftPadding; y: torqueSlider.topPadding + torqueSlider.availableHeight / 2 - height / 2
                width: torqueSlider.availableWidth; height: ScreenTools.defaultFontPixelHeight * 0.24; radius: height / 2; color: "#69717b"
                Rectangle { width: torqueSlider.visualPosition * parent.width; height: parent.height; radius: parent.radius; color: root.blue }
            }
            handle: Rectangle {
                x: torqueSlider.leftPadding + torqueSlider.visualPosition * (torqueSlider.availableWidth - width)
                y: torqueSlider.topPadding + torqueSlider.availableHeight / 2 - height / 2
                width: ScreenTools.defaultFontPixelHeight * 1.15; height: width; radius: width / 2; color: "#4c5660"; border.color: "white"; border.width: 1
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: ScreenTools.defaultFontPixelWidth * 0.7
            Repeater {
                model: [0, 30, 100]
                delegate: Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.7
                    color: !station.torqueRemote ? "#59616b" : (station.torqueSetpointAvailable && station.torquePercent === modelData ? root.blue : "#48525d")
                    border.color: !station.torqueRemote ? "#6d7681" : (station.torqueSetpointAvailable && station.torquePercent === modelData ? root.blue : "#69717b"); border.width: 1
                    QGCLabel { anchors.centerIn: parent; text: modelData + " %"; color: station.torqueRemote ? "white" : "#9ca5b5"; font.pointSize: ScreenTools.defaultFontPointSize }
                    MouseArea { anchors.fill: parent; enabled: root.controlsAvailable && station.torqueRemote; onClicked: station.setTorquePercent(modelData) }
                }
            }
        }

        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: station.noPower
            QGCLabel { Layout.fillWidth: true; text: qsTr("Drone battery: %1").arg(root.droneBatteryText()); color: "white"; wrapMode: Text.WordWrap }
            QGCLabel { text: qsTr("Altitude: %1 m").arg(root.flightVehicle && !root.flightVehicle.vehicleLinkManager.communicationLost ? root.flightVehicle.altitudeRelative.rawValue.toFixed(1) : "--"); color: "white" }
            QGCLabel { visible: station.noPowerPrompt; text: qsTr("SELECT ACTION"); color: root.mutedText }
            QGCLabel { visible: station.noPowerPrompt && station.noPowerVehicleNeedsConfirmation; Layout.fillWidth: true; text: qsTr("Vehicle changed or unavailable. Confirm the tethered vehicle before requesting Land/RTL."); color: root.orange; wrapMode: Text.WordWrap }
            QGCButton {
                visible: station.noPowerPrompt && station.noPowerVehicleNeedsConfirmation
                Layout.fillWidth: true
                text: qsTr("Confirm tethered vehicle")
                enabled: root.controlsAvailable && root.flightVehicle && !root.flightVehicle.vehicleLinkManager.communicationLost
                onClicked: {
                    associateVehicleDialog.candidate = root.flightVehicle
                    associateVehicleDialog.incident = station.noPowerIncident
                    associateVehicleDialog.open()
                }
            }
            QGCButton { visible: station.noPowerPrompt; Layout.fillWidth: true; text: qsTr("Land"); primary: true; enabled: root.controlsAvailable && !station.noPowerVehicleNeedsConfirmation; onClicked: station.requestNoPowerAction(false) }
            QGCButton { visible: station.noPowerPrompt; Layout.fillWidth: true; text: qsTr("RTL to Station"); enabled: root.controlsAvailable && !station.noPowerVehicleNeedsConfirmation; onClicked: station.requestNoPowerAction(true) }
            QGCButton { visible: station.noPowerPrompt; Layout.fillWidth: true; text: qsTr("Continue"); onClicked: station.dismissNoPower() }
            QGCLabel { Layout.fillWidth: true; text: [qsTr("Failsafe: Recommend land"), qsTr("Failsafe: Warn only"), qsTr("Failsafe: Auto land")][station.noPowerFailsafe]; color: root.mutedText; wrapMode: Text.WordWrap }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: dividerColor }

        RowLayout {
            Layout.fillWidth: true
            opacity: root.telemetryOpacity
            QGCLabel { text: qsTr("Power"); color: mutedText; font.pointSize: ScreenTools.defaultFontPointSize }
            Item { Layout.fillWidth: true }
            QGCLabel { text: station.powerWatts.toLocaleString(Qt.locale(), 'f', 0) + " W"; color: station.noPower ? root.danger : "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.largeFontPointSize }
            Rectangle { visible: station.powerOn && !station.noPower; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 3.2; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.45; radius: height / 2; color: green; QGCLabel { anchors.centerIn: parent; text: qsTr("ON"); color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.smallFontPointSize } }
        }
        QGCLabel { Layout.fillWidth: true; opacity: root.telemetryOpacity; text: qsTr("%1 V - %2 A - Input unavailable").arg(station.hasMonitoring ? root.measurement(station.voltage) : "—").arg(station.hasMonitoring ? root.measurement(station.current) : "—"); color: station.noPower ? root.danger : mutedText; font.pointSize: ScreenTools.smallFontPointSize }
        Rectangle { Layout.fillWidth: true; opacity: root.telemetryOpacity; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.5; radius: height / 2; color: "#44505b"; Rectangle { width: parent.width * root.percent(station.powerWatts, 2500); height: parent.height; radius: parent.radius; color: green } }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: dividerColor }

        RowLayout {
            Layout.fillWidth: true
            opacity: root.telemetryOpacity
            QGCLabel { text: qsTr("Tether"); color: mutedText; font.pointSize: ScreenTools.defaultFontPointSize }
            Item { Layout.fillWidth: true }
            QGCLabel { text: station.cableLength.toFixed(1) + " m"; color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.largeFontPointSize }
        }
        QGCLabel { Layout.fillWidth: true; opacity: root.telemetryOpacity; text: qsTr("Cable speed %1 m/s - Spool %2 C").arg(station.cableSpeed.toFixed(1)).arg(station.spoolTemperature); color: mutedText; font.pointSize: ScreenTools.smallFontPointSize }
        Rectangle { Layout.fillWidth: true; opacity: root.telemetryOpacity; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.5; radius: height / 2; color: "#44505b"; Rectangle { width: parent.width * root.percent(station.cableLength, 100); height: parent.height; radius: parent.radius; color: orange } }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: dividerColor }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.75; radius: ScreenTools.defaultFontPixelWidth * 0.35
            color: station.linkLost ? "#765718" : (station.alarmActive ? "#6d322f" : "#1e5e51")
            RowLayout {
                anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * 0.7
                QGCLabel { text: station.linkLost ? qsTr("Station link lost") : (!station.alarmActive ? qsTr("No active alarms") : station.alarmSummary); color: station.linkLost ? "#ffe2a0" : (station.alarmActive ? "#ff867e" : "#28d49b"); font.pointSize: ScreenTools.defaultFontPointSize }
                Item { Layout.fillWidth: true }
                QGCLabel { text: station.linkLost ? qsTr("last %1 - retry %2").arg(station.lastMonitoringTime.length ? station.lastMonitoringTime : "--").arg(station.reconnectAttempt) : station.lastMonitoringTime; color: mutedText; font.pointSize: ScreenTools.smallFontPointSize }
            }
        }
        QGCLabel {
            Layout.fillWidth: true
            text: qsTr("Station Setup  >")
            color: blue
            font.pointSize: ScreenTools.defaultFontPointSize
            MouseArea {
                anchors.fill: parent
                onClicked: mainWindow.showStationSetupTool()
            }
        }
        QGCLabel { Layout.fillWidth: true; visible: station.lastError.length > 0; text: station.lastError; color: danger; wrapMode: Text.WordWrap; font.pointSize: ScreenTools.smallFontPointSize }
    }

    // SAFE-T T-01b: power-off during flight requires a deliberate slide action.
}
