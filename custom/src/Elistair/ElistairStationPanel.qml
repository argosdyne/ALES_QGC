import QtQuick 2.12
import QtQuick.Controls 2.4
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
            Rectangle {
                Layout.preferredWidth: connectedLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.3
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.65
                radius: height / 2
                color: station.linkLost ? root.danger : (station.noReply ? root.orange : root.green)
                QGCLabel {
                    id: connectedLabel
                    anchors.centerIn: parent
                    text: station.linkLost ? qsTr("LOST > 5 s") : (station.noReply ? qsTr("NO REPLY") : qsTr("CONNECTED"))
                    color: "white"
                    font.family: ScreenTools.demiboldFontFamily
                    font.pointSize: ScreenTools.smallFontPointSize
                }
            }
        }

        QGCLabel {
            Layout.fillWidth: true
            text: qsTr("SAFE-T #1 - %1:%2 - Ext V1").arg(station.stationAddress).arg(station.stationPort)
            color: mutedText
            font.pointSize: ScreenTools.smallFontPointSize
            elide: Text.ElideRight
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: dividerColor }

        RowLayout {
            Layout.fillWidth: true
            QGCLabel { text: qsTr("Authority"); color: mutedText; font.pointSize: ScreenTools.defaultFontPointSize }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6.4; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.65
                color: !station.powerRemote ? localButton : "#343b45"
                QGCLabel { anchors.centerIn: parent; text: qsTr("LOCAL"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                MouseArea { anchors.fill: parent; enabled: !station.linkLost; onClicked: station.setPowerRemote(false) }
            }
            Rectangle {
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 7.3; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.65
                color: station.powerRemote ? green : "#343b45"
                QGCLabel { anchors.centerIn: parent; text: qsTr("REMOTE"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                MouseArea { anchors.fill: parent; enabled: station.connected && !station.linkLost; onClicked: station.setPowerRemote(true) }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth * 0.7
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.85
                color: station.powerOn ? "#59636e" : "#46515d"
                QGCLabel { anchors.centerIn: parent; text: qsTr("Power ON"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                MouseArea { anchors.fill: parent; enabled: station.connected && station.powerRemote && !station.powerOn; onClicked: station.setPowerOn(true) }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.85
                color: "#343b45"; border.color: danger; border.width: 1
                QGCLabel { anchors.centerIn: parent; text: qsTr("Power OFF"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                MouseArea {
                    anchors.fill: parent; enabled: station.connected && station.powerRemote && station.powerOn
                    onClicked: { var vehicle = QGroundControl.multiVehicleManager.activeVehicle; if (vehicle && vehicle.armed) powerOffConfirm.open(); else station.setPowerOn(false) }
                }
            }
        }

        QGCLabel {
            Layout.fillWidth: true
            text: station.linkLost ? qsTr("Link lost - authority reverted to LOCAL") : (station.noReply ? qsTr("No station reply - waiting for telemetry") : (station.powerRemote ? qsTr("In flight: Power OFF requires confirmation") : qsTr("Needs REMOTE authority (station or here)")))
            color: station.linkLost ? danger : (station.noReply ? orange : mutedText)
            font.pointSize: ScreenTools.smallFontPointSize
        }

        RowLayout {
            Layout.fillWidth: true
            QGCLabel { text: qsTr("Torque"); color: mutedText; font.pointSize: ScreenTools.defaultFontPointSize }
            Item { Layout.fillWidth: true }
            QGCLabel {
                text: qsTr("set %1%% - applied %2%%").arg(station.torquePercent).arg(station.appliedTorquePercent)
                color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.defaultFontPointSize
            }
        }

        Slider {
            id: torqueSlider
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.15
            from: 0; to: 100; stepSize: 1
            enabled: station.connected && station.torqueRemote
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
                    color: station.torquePercent === modelData ? green : "#48525d"
                    QGCLabel { anchors.centerIn: parent; text: modelData + " %"; color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                    MouseArea { anchors.fill: parent; enabled: station.connected && station.torqueRemote; onClicked: station.setTorquePercent(modelData) }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: dividerColor }

        RowLayout {
            Layout.fillWidth: true
            QGCLabel { text: qsTr("Power"); color: mutedText; font.pointSize: ScreenTools.defaultFontPointSize }
            Item { Layout.fillWidth: true }
            QGCLabel { text: station.powerWatts.toLocaleString(Qt.locale(), 'f', 0) + " W"; color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.largeFontPointSize }
            Rectangle { visible: station.powerOn; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 3.2; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.45; radius: height / 2; color: green; QGCLabel { anchors.centerIn: parent; text: qsTr("ON"); color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.smallFontPointSize } }
        }
        QGCLabel { Layout.fillWidth: true; text: qsTr("%1 V - %2 A - Input unavailable").arg(station.voltage.toFixed(1)).arg(station.current.toFixed(1)); color: mutedText; font.pointSize: ScreenTools.smallFontPointSize }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.5; radius: height / 2; color: "#44505b"; Rectangle { width: parent.width * root.percent(station.powerWatts, 2500); height: parent.height; radius: parent.radius; color: green } }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: dividerColor }

        RowLayout {
            Layout.fillWidth: true
            QGCLabel { text: qsTr("Tether"); color: mutedText; font.pointSize: ScreenTools.defaultFontPointSize }
            Item { Layout.fillWidth: true }
            QGCLabel { text: station.cableLength.toFixed(1) + " m"; color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.largeFontPointSize }
        }
        QGCLabel { Layout.fillWidth: true; text: qsTr("Cable speed %1 m/s - Spool %2 C").arg(station.cableSpeed.toFixed(1)).arg(station.spoolTemperature); color: mutedText; font.pointSize: ScreenTools.smallFontPointSize }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.5; radius: height / 2; color: "#44505b"; Rectangle { width: parent.width * root.percent(station.cableLength, 100); height: parent.height; radius: parent.radius; color: orange } }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: dividerColor }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.75; radius: ScreenTools.defaultFontPixelWidth * 0.35
            color: station.alarmSummary === qsTr("No alarms") ? "#1e5e51" : "#6d322f"
            RowLayout {
                anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * 0.7
                QGCLabel { text: station.alarmSummary === qsTr("No alarms") ? qsTr("No active alarms") : station.alarmSummary; color: station.alarmSummary === qsTr("No alarms") ? "#28d49b" : "#ff867e"; font.pointSize: ScreenTools.defaultFontPointSize }
                Item { Layout.fillWidth: true }
                QGCLabel { text: Qt.formatTime(new Date(), "hh:mm:ss"); color: mutedText; font.pointSize: ScreenTools.smallFontPointSize }
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
    Popup {
        id: powerOffConfirm
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(root.width - ScreenTools.defaultFontPixelWidth * 2, ScreenTools.defaultFontPixelWidth * 27)
        height: contentColumn.implicitHeight + ScreenTools.defaultFontPixelHeight * 2
        x: (root.width - width) / 2
        y: Math.max(ScreenTools.defaultFontPixelHeight, (root.height - height) / 2)
        padding: ScreenTools.defaultFontPixelWidth
        background: Rectangle {
            color: "#293039"
            border.color: danger
            border.width: 1
            radius: ScreenTools.defaultFontPixelWidth * .5
        }
        onOpened: offSlider.value = 0

        ColumnLayout {
            id: contentColumn
            width: parent.width
            spacing: ScreenTools.defaultFontPixelHeight * .65
            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("Turn tether power OFF?")
                color: "white"
                font.family: ScreenTools.demiboldFontFamily
                font.pointSize: ScreenTools.defaultFontPointSize
            }
            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("The vehicle is armed. Slide to confirm power-off.")
                color: mutedText
                wrapMode: Text.WordWrap
                font.pointSize: ScreenTools.smallFontPointSize
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.7
                radius: height / 2
                color: "#404955"
                border.color: "#65707e"
                QGCLabel {
                    anchors.centerIn: parent
                    text: qsTr("Slide to confirm")
                    color: "white"
                    font.pointSize: ScreenTools.smallFontPointSize
                }
                Slider {
                    id: offSlider
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelWidth * .4
                    from: 0; to: 1
                    onMoved: {
                        if (value >= .94) {
                            station.setPowerOn(false)
                            powerOffConfirm.close()
                        }
                    }
                    background: Rectangle {
                        x: offSlider.leftPadding; y: offSlider.topPadding + offSlider.availableHeight / 2 - height / 2
                        width: offSlider.availableWidth; height: ScreenTools.defaultFontPixelHeight * .42
                        radius: height / 2; color: "#20252b"
                        Rectangle { width: offSlider.visualPosition * parent.width; height: parent.height; radius: parent.radius; color: danger }
                    }
                    handle: Rectangle {
                        x: offSlider.leftPadding + offSlider.visualPosition * (offSlider.availableWidth - width)
                        y: offSlider.topPadding + offSlider.availableHeight / 2 - height / 2
                        width: ScreenTools.defaultFontPixelHeight * 1.7; height: width; radius: width / 2
                        color: danger; border.color: "white"; border.width: 1
                    }
                }
            }
            QGCButton {
                Layout.alignment: Qt.AlignRight
                text: qsTr("Cancel")
                onClicked: powerOffConfirm.close()
            }
        }
    }
}
