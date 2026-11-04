import QtQuick 2.12
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.12

import QGroundControl 1.0
import QGroundControl.Controls 1.0
import QGroundControl.ScreenTools 1.0

Rectangle {
    id: root

    property var station: QGroundControl.corePlugin.elistairStationManager
    readonly property color panelColor: "#20252b"
    readonly property color mutedColor: "#a6afbf"
    readonly property color green: "#00a77c"
    readonly property color red: "#e1544e"
    readonly property color lostColor: "#68717b"
    readonly property var statusRows: [
        { label: qsTr("Station:"), value: "SAFE-T #1 - " + station.stationAddress },
        { label: qsTr("Link:"), value: station.linkLost ? qsTr("Lost - reconnecting (%1)").arg(station.reconnectAttempt) : (station.noReply ? qsTr("No reply - waiting") : (station.frameVersionDetected ? qsTr("Connected - %1").arg(station.activeFrameVersion) : qsTr("Not connected"))) },
        { label: qsTr("Authority:"), value: station.powerRemote ? qsTr("REMOTE") : qsTr("LOCAL") },
        { label: qsTr("Power:"), value: (station.noPower ? qsTr("NO POWER") : station.powerOn ? qsTr("ON") : qsTr("OFF")) + " - " + station.powerWatts.toFixed(0) + " W" },
        { label: qsTr("Tether:"), value: station.cableLength.toFixed(1) + " m / " + (station.stationSettings.tetherLength !== undefined ? station.stationSettings.tetherLength : "--") + " m" },
        { label: qsTr("Torque:"), value: qsTr("set %1% - applied %2%").arg(station.torqueSetpointAvailable ? station.torquePercent : "—").arg(station.activeFrameVersion === "Extended V1" && station.hasMonitoring ? station.appliedTorquePercent : "—") },
        { label: qsTr("Spool temp:"), value: station.spoolTemperature + " \u00b0C" },
        { label: qsTr("Last data:"), value: station.lastMonitoringTime.length ? station.lastMonitoringTime : "--" },
        { label: qsTr("Alarms:"), value: station.linkLost ? qsTr("Station link lost") : station.alarmSummary, alarm: true }
    ]

    readonly property bool showIndicator: station !== null && station !== undefined
    visible: showIndicator
    width: ScreenTools.defaultFontPixelWidth * 6.4
    height: parent ? parent.height : ScreenTools.defaultFontPixelHeight * 2.4
    color: tetherMouse.containsMouse ? "#353e49" : "transparent"
    radius: ScreenTools.defaultFontPixelWidth * 0.35

    Row {
        anchors.centerIn: parent
        spacing: ScreenTools.defaultFontPixelWidth * 0.38

        QGCColoredImage {
            width: ScreenTools.defaultFontPixelHeight * 1.45
            height: width
            anchors.verticalCenter: parent.verticalCenter
            source: "/res/SafeTStation.svg"
            color: station.noPower ? root.red : station.connected && station.hasMonitoring && !station.linkLost && !station.noReply ? "white" : root.lostColor
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            QGCLabel {
                text: station.noPower ? station.powerWatts + " W" : !station.connected ? qsTr("OFF") : (station.linkLost ? qsTr("LOST") : (station.noReply ? qsTr("NO REPLY") : (!station.hasMonitoring ? qsTr("WAIT") : (station.powerOn ? qsTr("ON") : qsTr("OFF")))))
                color: station.noPower ? root.red : station.connected && station.hasMonitoring && !station.linkLost && !station.noReply ? "white" : root.mutedColor
                font.pointSize: ScreenTools.smallFontPointSize
            }
            QGCLabel {
                text: station.cableLength.toFixed(1) + qsTr(" m")
                color: station.connected && station.hasMonitoring && !station.linkLost && !station.noReply ? "white" : root.mutedColor
                font.pointSize: ScreenTools.smallFontPointSize
            }
        }
    }

    MouseArea {
        id: tetherMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: tetherStatusPopup.open()
    }

    Popup {
        id: tetherStatusPopup
        parent: Overlay.overlay
        width: Math.min(parent.width - 24, ScreenTools.defaultFontPixelWidth * 36)
        height: Math.min(parent.height - y - 12, summaryColumn.implicitHeight + topPadding + bottomPadding)
        onAboutToShow: {
            var point = root.mapToItem(parent, root.width, root.height)
            x = Math.max(12, Math.min(parent.width - width - 12, point.x - width))
            y = Math.max(12, point.y + ScreenTools.defaultFontPixelHeight * .45)
        }
        padding: ScreenTools.defaultFontPixelWidth * 1.05
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: root.panelColor
            radius: ScreenTools.defaultFontPixelWidth * 0.55
            border.color: "#4b5562"
            border.width: 1
        }

        contentItem: Flickable {
            clip: true
            contentWidth: width
            contentHeight: summaryColumn.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
        Column {
            id: summaryColumn
            width: parent.width
            spacing: ScreenTools.defaultFontPixelHeight * 0.36

            Item {
                width: parent.width
                height: Math.max(summaryTitle.implicitHeight, statusChip.height)
                QGCLabel {
                    id: summaryTitle
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Tether Status")
                    color: "white"
                    font.family: ScreenTools.demiboldFontFamily
                    font.pointSize: ScreenTools.largeFontPointSize
                }
                Rectangle {
                    id: statusChip
                    anchors.right: parent.right
                    width: statusText.implicitWidth + ScreenTools.defaultFontPixelWidth
                    height: ScreenTools.defaultFontPixelHeight * 1.45
                    radius: height / 2
                    color: station.linkLost ? root.lostColor : (station.noReply ? root.lostColor : root.green)
                    QGCLabel {
                        id: statusText
                        anchors.centerIn: parent
                        text: station.linkLost ? qsTr("LOST > 5 s") : (station.noReply ? qsTr("NO REPLY") : (!station.frameVersionDetected ? qsTr("CONNECTING") : qsTr("CONNECTED")))
                        color: "white"
                        font.family: ScreenTools.demiboldFontFamily
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#3a424d" }

            Repeater {
                model: root.statusRows
                Item {
                    width: summaryColumn.width
                    height: Math.max(fieldLabel.implicitHeight, fieldValue.implicitHeight)
                    QGCLabel {
                        id: fieldLabel
                        width: parent.width * .28
                        text: modelData.label; color: root.mutedColor
                    }
                    QGCLabel {
                        id: fieldValue
                        x: fieldLabel.width + ScreenTools.defaultFontPixelWidth * .7
                        width: parent.width - x
                        wrapMode: Text.Wrap
                        text: modelData.value
                        color: station.linkLost || station.noReply ? root.mutedColor : (modelData.alarm && station.alarmSummary !== qsTr("No alarms") ? root.red : "white")
                    }
                }
            }

            QGCButton {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Open Tether Panel")
                onClicked: {
                    tetherStatusPopup.close()
                    mainWindow.tetherPanelVisible = true
                }
            }
        }
        }
    }
}
