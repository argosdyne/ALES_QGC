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
    function detail(title) {
        if (title === "Cable Settings") return "Length alarm • Protection length • Theoretical tether length • Tether weight"
        if (title === "Power Settings") return "Power alarm • Alert percentage • Automatic output-power thresholds"
        if (title === "Safety Limits") return "Take-off/landing protection • Anti-shock • Anti-entrapment • Anti-ground dragging"
        if (title === "Control Settings") return "Control-frame timeout • Algorithm authorization • Torque presets"
        return "Maintenance counter • Total powered hours • Number of drone flights"
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
                    id: settings
                    width: Math.min(parent.width, ScreenTools.defaultFontPixelWidth * 72)
                    x: Math.max(0, (parent.width - width) / 2)
                    spacing: ScreenTools.defaultFontPixelHeight * 0.7
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: warning.implicitHeight + ScreenTools.defaultFontPixelHeight * 2; color: settingsLocked ? "#a87508" : "#b7791f"; radius: 4
                        RowLayout {
                            anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth
                            QGCLabel { text: "⚠"; color: "#1b1f24"; font.pointSize: ScreenTools.largeFontPointSize; font.bold: true }
                            QGCLabel { id: warning; Layout.fillWidth: true; color: "#1b1f24"; wrapMode: Text.WordWrap; text: settingsLocked ? "Configuration is locked. Connect SAFE-T and keep the aircraft disarmed before reading or writing configuration." : "Configuration may cut tether output. Ensure the aircraft is disarmed and tether is not flying." }
                            QGCButton { text: "Read Configuration"; enabled: !settingsLocked; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 18 }
                        }
                    }
                    RowLayout {
                        Item { Layout.fillWidth: true }
                        QGCButton { text: "Write Changed Values"; enabled: !settingsLocked; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 20 }
                    }
                    Repeater {
                        model: ["Cable Settings", "Power Settings", "Safety Limits", "Control Settings", "Maintenance"]
                        delegate: Item {
                            Layout.fillWidth: true
                            property bool expanded: false
                            implicitHeight: header.implicitHeight + (expanded ? details.implicitHeight : 0)
                            Rectangle {
                                id: header; width: parent.width; implicitHeight: ScreenTools.defaultFontPixelHeight * 3.1
                                color: qgcPal.button; radius: 4
                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.25; anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.25
                                    QGCLabel { text: parent.parent.expanded ? "⌄" : "›"; color: qgcPal.buttonText; font.pointSize: ScreenTools.largeFontPointSize }
                                    QGCLabel { Layout.fillWidth: true; text: modelData; font.bold: true }
                                    QGCLabel { text: "Configure"; color: qgcPal.buttonText }
                                }
                                MouseArea { anchors.fill: parent; onClicked: parent.parent.expanded = !parent.parent.expanded }
                            }
                            Rectangle {
                                id: details; visible: parent.expanded; y: header.height; width: parent.width
                                implicitHeight: detailText.implicitHeight + ScreenTools.defaultFontPixelHeight * 2
                                color: qgcPal.windowShade; radius: 4
                                QGCLabel { id: detailText; anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * 1.5; text: detail(modelData); wrapMode: Text.WordWrap; color: qgcPal.buttonText }
                            }
                        }
                    }
                    QGCLabel { Layout.topMargin: ScreenTools.defaultFontPixelHeight * .4; text: "SAFE-T Config V0  •  Read 0xA5 / Write 0xD5  •  EEPROM writes are sent once only."; wrapMode: Text.WordWrap; color: qgcPal.buttonText; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
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
