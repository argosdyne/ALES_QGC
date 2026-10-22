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
    property color accentColor: "#2d7ff9"
    property color safeColor: "#20c978"
    property color panelColor: qgcPal.windowShade

    visible: station !== null
    width: ScreenTools.defaultFontPixelWidth * 37
    height: ScreenTools.defaultFontPixelHeight * 28
    color: qgcPal.window
    radius: ScreenTools.defaultFontPixelWidth
    border.color: qgcPal.button
    border.width: 1

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth * 1.25
        spacing: ScreenTools.defaultFontPixelHeight * 0.55

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth
            Rectangle {
                width: ScreenTools.defaultFontPixelHeight * 1.9; height: width; radius: width / 2; color: root.accentColor
                QGCLabel { anchors.centerIn: parent; text: "↯"; color: "white"; font.pointSize: ScreenTools.largeFontPointSize; font.bold: true }
            }
            ColumnLayout {
                spacing: 0
                QGCLabel { text: qsTr("Elistair SAFE-T"); font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.largeFontPointSize }
                QGCLabel { text: qsTr("Tether station control"); color: qgcPal.buttonText; font.pointSize: ScreenTools.smallFontPointSize }
            }
            Item { Layout.fillWidth: true }
            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth * 0.5
                Rectangle { width: ScreenTools.defaultFontPixelHeight * 0.7; height: width; radius: width / 2; color: station.connected ? root.safeColor : qgcPal.colorRed }
                QGCLabel { text: station.connected ? qsTr("Connected") : qsTr("Disconnected"); color: station.connected ? root.safeColor : qgcPal.colorRed; font.family: ScreenTools.demiboldFontFamily }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: qgcPal.button }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 6.4
            spacing: ScreenTools.defaultFontPixelWidth

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; color: root.panelColor; radius: ScreenTools.defaultFontPixelWidth * 0.6
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth; spacing: ScreenTools.defaultFontPixelHeight * 0.45
                    QGCLabel { text: qsTr("Power Control"); font.family: ScreenTools.demiboldFontFamily }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 3
                        Rectangle {
                            Layout.fillWidth: true; height: ScreenTools.defaultFontPixelHeight * 1.45; radius: height / 2
                            color: !station.powerRemote ? root.accentColor : qgcPal.windowShadeDark; border.color: !station.powerRemote ? root.accentColor : qgcPal.button
                            QGCLabel { anchors.centerIn: parent; text: qsTr("Local"); color: !station.powerRemote ? "white" : qgcPal.buttonText }
                            MouseArea { anchors.fill: parent; onClicked: station.setPowerRemote(false) }
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: ScreenTools.defaultFontPixelHeight * 1.45; radius: height / 2
                            color: station.powerRemote ? root.accentColor : qgcPal.windowShadeDark; border.color: station.powerRemote ? root.accentColor : qgcPal.button
                            QGCLabel { anchors.centerIn: parent; text: qsTr("Remote"); color: station.powerRemote ? "white" : qgcPal.buttonText }
                            MouseArea { anchors.fill: parent; onClicked: station.setPowerRemote(true) }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: ScreenTools.defaultFontPixelWidth * 0.5
                        QGCButton { Layout.fillWidth: true; text: qsTr("ON"); enabled: station.powerRemote && !station.powerOn; onClicked: station.setPowerOn(true) }
                        QGCButton {
                            Layout.fillWidth: true; text: qsTr("OFF"); enabled: station.powerRemote && station.powerOn
                            onClicked: { var vehicle = QGroundControl.multiVehicleManager.activeVehicle; if (vehicle && vehicle.armed) powerOffConfirm.open(); else station.setPowerOn(false) }
                        }
                    }
                    QGCLabel {
                        Layout.fillWidth: true
                        text: station.powerRemote ? (station.powerOn ? qsTr("Remote output enabled") : qsTr("Remote output disabled")) : qsTr("Controlled locally at station")
                        color: station.powerRemote && station.powerOn ? root.safeColor : qgcPal.buttonText; horizontalAlignment: Text.AlignHCenter; font.pointSize: ScreenTools.smallFontPointSize
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true; color: root.panelColor; radius: ScreenTools.defaultFontPixelWidth * 0.6
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth; spacing: ScreenTools.defaultFontPixelHeight * 0.35
                    RowLayout {
                        Layout.fillWidth: true
                        QGCLabel { text: qsTr("Torque Control"); font.family: ScreenTools.demiboldFontFamily }
                        Item { Layout.fillWidth: true }
                        QGCLabel { text: qsTr("%1%").arg(station.torquePercent); color: root.accentColor; font.family: ScreenTools.demiboldFontFamily }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 3
                        Rectangle {
                            Layout.fillWidth: true; height: ScreenTools.defaultFontPixelHeight * 1.45; radius: height / 2
                            color: !station.torqueRemote ? root.accentColor : qgcPal.windowShadeDark; border.color: !station.torqueRemote ? root.accentColor : qgcPal.button
                            QGCLabel { anchors.centerIn: parent; text: qsTr("Local"); color: !station.torqueRemote ? "white" : qgcPal.buttonText }
                            MouseArea { anchors.fill: parent; onClicked: station.setTorqueRemote(false) }
                        }
                        Rectangle {
                            Layout.fillWidth: true; height: ScreenTools.defaultFontPixelHeight * 1.45; radius: height / 2
                            color: station.torqueRemote ? root.accentColor : qgcPal.windowShadeDark; border.color: station.torqueRemote ? root.accentColor : qgcPal.button
                            QGCLabel { anchors.centerIn: parent; text: qsTr("Remote"); color: station.torqueRemote ? "white" : qgcPal.buttonText }
                            MouseArea { anchors.fill: parent; onClicked: station.setTorqueRemote(true) }
                        }
                    }
                    Slider { Layout.fillWidth: true; from: 0; to: 100; stepSize: 1; enabled: station.torqueRemote; value: station.torquePercent; onMoved: station.setTorquePercent(Math.round(value)) }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 4
                        Repeater {
                            model: [25, 50, 75, 100]
                            delegate: Rectangle {
                                Layout.fillWidth: true; height: ScreenTools.defaultFontPixelHeight * 1.35; radius: ScreenTools.defaultFontPixelWidth * 0.35
                                color: station.torquePercent === modelData ? root.accentColor : qgcPal.windowShadeDark; border.color: station.torquePercent === modelData ? root.accentColor : qgcPal.button
                                QGCLabel { anchors.centerIn: parent; text: modelData + "%"; color: station.torquePercent === modelData ? "white" : qgcPal.buttonText; font.pointSize: ScreenTools.smallFontPointSize }
                                MouseArea { anchors.fill: parent; enabled: station.torqueRemote; onClicked: station.setTorquePercent(modelData) }
                            }
                        }
                    }
                }
            }
        }

        QGCLabel { text: qsTr("Live Telemetry"); font.family: ScreenTools.demiboldFontFamily; Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.15 }

        GridLayout {
            Layout.fillWidth: true; columns: 2; columnSpacing: ScreenTools.defaultFontPixelWidth * 0.7; rowSpacing: ScreenTools.defaultFontPixelHeight * 0.45
            Repeater {
                model: [
                    { label: qsTr("Power"),          value: station.powerWatts + " W",                             accent: "#f2a93b" },
                    { label: qsTr("Cable Length"),   value: station.cableLength.toFixed(1) + " m",                  accent: "#65c9ff" },
                    { label: qsTr("Cable Speed"),    value: station.cableSpeed.toFixed(1) + " m/s",                accent: "#5eacff" },
                    { label: qsTr("Spool Temp."),    value: station.spoolTemperature + " °C",                      accent: "#f06767" },
                    { label: qsTr("Voltage"),        value: station.voltage.toFixed(1) + " V",                     accent: "#56d6a0" },
                    { label: qsTr("Current"),        value: station.current.toFixed(2) + " A",                     accent: "#65c9ff" },
                    { label: qsTr("Applied Torque"), value: station.appliedTorquePercent + "%",                    accent: "#f2a93b" },
                    { label: qsTr("Station"),        value: station.connected ? qsTr("Online") : qsTr("Offline"), accent: station.connected ? root.safeColor : qgcPal.colorRed }
                ]
                delegate: Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4; color: root.panelColor; radius: ScreenTools.defaultFontPixelWidth * 0.55
                    RowLayout {
                        anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * 0.7; spacing: ScreenTools.defaultFontPixelWidth * 0.7
                        Rectangle { width: 3; Layout.fillHeight: true; radius: 2; color: modelData.accent }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            QGCLabel { text: modelData.label; color: qgcPal.buttonText; font.pointSize: ScreenTools.smallFontPointSize }
                            QGCLabel { text: modelData.value; font.family: ScreenTools.demiboldFontFamily }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.15
            color: station.alarmSummary === qsTr("No alarms") ? Qt.rgba(0.12, 0.75, 0.45, 0.12) : Qt.rgba(0.95, 0.35, 0.25, 0.16)
            radius: ScreenTools.defaultFontPixelWidth * 0.5; border.color: station.alarmSummary === qsTr("No alarms") ? root.safeColor : qgcPal.colorRed
            RowLayout {
                anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth; spacing: ScreenTools.defaultFontPixelWidth * 0.6
                Rectangle { width: ScreenTools.defaultFontPixelHeight * 0.6; height: width; radius: width / 2; color: station.alarmSummary === qsTr("No alarms") ? root.safeColor : qgcPal.colorRed }
                QGCLabel { text: station.alarmSummary; color: station.alarmSummary === qsTr("No alarms") ? root.safeColor : qgcPal.colorRed; font.family: ScreenTools.demiboldFontFamily }
                Item { Layout.fillWidth: true }
                QGCLabel { text: qsTr("System status"); color: qgcPal.buttonText; font.pointSize: ScreenTools.smallFontPointSize }
            }
        }

        QGCLabel { Layout.fillWidth: true; visible: station.lastError.length > 0; text: station.lastError; color: qgcPal.colorRed; wrapMode: Text.WordWrap }
    }

    MessageDialog {
        id: powerOffConfirm
        title: qsTr("Confirm tether power OFF")
        text: qsTr("The vehicle is armed. Turning tether power off may force it onto onboard battery. Confirm only when this is safe.")
        standardButtons: StandardButton.Cancel | StandardButton.Ok
        onAccepted: station.setPowerOn(false)
    }
}
