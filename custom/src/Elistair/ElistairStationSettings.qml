import QtQuick 2.12
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.12
import QGroundControl 1.0
import QGroundControl.Controls 1.0
import QGroundControl.Palette 1.0
import QGroundControl.ScreenTools 1.0

Rectangle {
    property var station: QGroundControl.corePlugin.elistairStationManager
    property bool settingsLocked: !station.connected
    color: qgcPal.window
    QGCPalette { id: qgcPal }
    function description(title) {
        if (title === "Cable Settings") return "Length alarm, protection length, theoretical tether length and tether weight."
        if (title === "Power Settings") return "Power alarm, alert percentage and automatic output-power disable thresholds."
        if (title === "Safety Limits") return "Take-off/landing protection, anti-shock, anti-entrapment and anti-ground dragging."
        if (title === "Control Settings") return "Control-frame timeout and station algorithm authorization."
        return "Maintenance counter, total powered hours and number of drone flights."
    }
    ColumnLayout {
        anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * 2
        QGCLabel { text: "SAFE-T Station"; font.pointSize: ScreenTools.largeFontPointSize; font.bold: true }
        QGCTabBar {
            id: tabs; Layout.fillWidth: true
            QGCTabButton { text: "Connection" }
            QGCTabButton { text: "Settings" }
            QGCTabButton { text: "Device Info" }
        }
        StackLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; currentIndex: tabs.currentIndex
            Flickable {
                clip: true; contentHeight: connection.implicitHeight
                ColumnLayout {
                    id: connection; width: parent.width; spacing: ScreenTools.defaultFontPixelHeight
                    QGCLabel { text: "Connection Settings"; font.bold: true }
                    GridLayout {
                        columns: 2
                        QGCLabel { text: "Station IP Address" }
                        QGCTextField { id: address; text: station.stationAddress; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 28 }
                        QGCLabel { text: "UDP Port" }
                        QGCTextField { id: port; text: station.stationPort; inputMethodHints: Qt.ImhDigitsOnly }
                    }
                    RowLayout {
                        QGCButton { text: "Test Connection"; onClicked: { station.stationAddress = address.text; station.stationPort = Number(port.text); station.connectStation() } }
                        QGCButton { text: "Disconnect"; onClicked: station.disconnectStation() }
                        QGCLabel { text: station.connected ? "Connected" : "Waiting for monitoring frame"; color: station.connected ? qgcPal.colorGreen : qgcPal.colorYellow }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: qgcPal.button }
                    QGCLabel { text: "GCS Behavior"; font.bold: true }
                    GridLayout {
                        columns: 2
                        QGCLabel { text: "Control Rate" }
                        QGCComboBox { model: ["5 Hz (200 ms)"] }
                        QGCLabel { text: "Response Timeout" }
                        QGCComboBox { model: ["1 s"] }
                        QGCLabel { text: "Disconnected Timeout" }
                        QGCComboBox { model: ["5 s"] }
                        QGCLabel { text: "No-power Failsafe" }
                        QGCComboBox { model: ["Recommend landing", "Warn only", "Auto Land"] }
                    }
                }
            }
            Flickable {
                clip: true; contentHeight: settings.implicitHeight
                ColumnLayout {
                    id: settings; width: parent.width; spacing: ScreenTools.defaultFontPixelHeight
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: warning.implicitHeight + ScreenTools.defaultFontPixelHeight * 2; color: settingsLocked ? "#d69e2e" : qgcPal.colorGreen
                        QGCLabel { id: warning; anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth; color: "white"; wrapMode: Text.WordWrap; text: settingsLocked ? "Configuration is locked until SAFE-T is connected. It must only be read or written while the aircraft is disarmed and tether is not flying." : "Configuration write is allowed only while the aircraft is disarmed and tether output is safe." }
                    }
                    RowLayout {
                        QGCButton { text: "Read Configuration"; enabled: !settingsLocked }
                        QGCButton { text: "Write Changed Values"; enabled: !settingsLocked }
                    }
                    Repeater {
                        model: ["Cable Settings", "Power Settings", "Safety Limits", "Control Settings", "Maintenance"]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: sectionColumn.implicitHeight + ScreenTools.defaultFontPixelHeight
                            color: qgcPal.button
                            radius: 3
                            ColumnLayout {
                                id: sectionColumn
                                anchors.fill: parent
                                anchors.margins: ScreenTools.defaultFontPixelWidth
                                QGCLabel { text: modelData; font.bold: true }
                                QGCLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: description(modelData); color: qgcPal.buttonText }
                            }
                        }
                    }
                    QGCLabel { text: "SAFE-T Config V0: Read 0xA5 / Write 0xD5. EEPROM writes are sent once only, never periodically."; wrapMode: Text.WordWrap; color: qgcPal.buttonText }
                }
            }
            Flickable {
                clip: true; contentHeight: device.implicitHeight
                ColumnLayout {
                    id: device; width: parent.width; spacing: ScreenTools.defaultFontPixelHeight
                    QGCLabel { text: "Device Information"; font.bold: true }
                    QGCLabel { text: station.connected ? "Read Configuration to populate station information." : "Connect, then read configuration safely on the ground."; wrapMode: Text.WordWrap }
                    GridLayout {
                        columns: 2
                        QGCLabel { text: "Serial Number" }
                        QGCLabel { text: "—" }
                        QGCLabel { text: "Model" }
                        QGCLabel { text: "SAFE-T V2.1 / V2.2" }
                        QGCLabel { text: "Interface Firmware" }
                        QGCLabel { text: "—" }
                        QGCLabel { text: "Command Firmware" }
                        QGCLabel { text: "—" }
                        QGCLabel { text: "Power Firmware" }
                        QGCLabel { text: "—" }
                        QGCLabel { text: "Total Flight Hours" }
                        QGCLabel { text: "—" }
                        QGCLabel { text: "Power Source" }
                        QGCLabel { text: "—" }
                    }
                }
            }
        }
    }
}
