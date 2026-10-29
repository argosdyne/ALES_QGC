import QtQuick 2.12
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.12
import QGroundControl 1.0
import QGroundControl.Controls 1.0
import QGroundControl.ScreenTools 1.0

Rectangle {
    id: root
    property var station: QGroundControl.corePlugin.elistairStationManager
    property int page: 0
    property color card: "#2b3138"
    property color muted: "#a1a9b8"
    property color teal: "#0aa27e"
    property real controlHeight: ScreenTools.defaultFontPixelHeight * 1.65
    property bool settingsDirty: false
    property bool showPassword: false
    property bool lengthError: false
    color: "#1f2328"
    function testConnection() {
        station.stationAddress = address.text.trim()
        station.stationPort = Number(port.text)
        station.connectStation()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
            color: "#181c20"
            ColumnLayout {
                anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * .6
                Repeater {
                    model: [qsTr("Connection"), qsTr("Settings"), qsTr("Device Info")]
                    delegate: Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.1
                        color: root.page === index ? root.teal : "#505861"
                        QGCLabel { anchors.centerIn: parent; text: modelData; color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                        MouseArea { anchors.fill: parent; onClicked: root.page = index }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        StackLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; currentIndex: root.page
            Item {
                RowLayout {
                    anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * 1.3
                    spacing: ScreenTools.defaultFontPixelWidth
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 30
                        Layout.alignment: Qt.AlignTop; color: root.card
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * 1.1
                            QGCLabel { text: qsTr("Connection"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                            QGCCheckBox { text: qsTr("Enable SAFE-T tether station"); checked: true }
                            QGCCheckBox { text: qsTr("Auto-connect on start"); checked: true }
                            GridLayout {
                                Layout.fillWidth: true; columns: 2
                                columnSpacing: ScreenTools.defaultFontPixelWidth * 2; rowSpacing: ScreenTools.defaultFontPixelHeight * .65
                                QGCLabel { text: qsTr("Name"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCTextField { text: "SAFE-T #1"; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 24; Layout.preferredHeight: root.controlHeight }
                                QGCLabel { text: qsTr("Station IP"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCTextField { id: address; text: station.stationAddress; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 24; Layout.preferredHeight: root.controlHeight }
                                QGCLabel { text: qsTr("UDP port"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCTextField { id: port; text: station.stationPort; inputMethodHints: Qt.ImhDigitsOnly; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 15; Layout.preferredHeight: root.controlHeight }
                                QGCLabel { text: qsTr("Frame version"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCComboBox {
                                    model: [qsTr("Auto"), qsTr("Extended V1"), qsTr("Extended V0"), qsTr("Standard")]
                                    currentIndex: Math.max(0, model.indexOf(station.frameVersion))
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 29; Layout.preferredHeight: root.controlHeight
                                    onActivated: station.frameVersion = model[index]
                                }
                            }
                            RowLayout {
                                QGCButton { text: qsTr("Test"); Layout.preferredHeight: root.controlHeight; onClicked: root.testConnection() }
                                Rectangle {
                                    visible: station.connected; width: ok.implicitWidth + ScreenTools.defaultFontPixelWidth; height: ScreenTools.defaultFontPixelHeight * 1.6
                                    radius: height / 2; color: root.teal
                                    QGCLabel { id: ok; anchors.centerIn: parent; text: qsTr("OK"); color: "white" }
                                }
                                QGCLabel { text: station.connected ? qsTr("S/N [S/N] - FW [x.y] / [x.y] / [x.y] - %1").arg(station.activeFrameVersion) : qsTr("Waiting for station response"); color: root.muted; font.pointSize: ScreenTools.smallFontPointSize }
                            }
                            QGCLabel { Layout.fillWidth: true; text: qsTr("Ethernet, direct UDP to the station. One station per GCS. On failure, check PC IP, cable and station power."); color: root.muted; wrapMode: Text.WordWrap; font.pointSize: ScreenTools.smallFontPointSize }
                            Item { Layout.fillHeight: true }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 30
                        Layout.alignment: Qt.AlignTop; color: root.card
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * 1.1
                            QGCLabel { text: qsTr("GCS behavior"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                            GridLayout {
                                columns: 3; Layout.fillWidth: true
                                QGCLabel { text: qsTr("Control rate"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("5 Hz"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("fixed"); color: root.muted }
                                QGCLabel { text: qsTr("No reply / Lost"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("1 s / 5 s"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("fixed"); color: root.muted }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                QGCLabel { text: qsTr("No-power failsafe"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                Item { Layout.fillWidth: true }
                                QGCComboBox { model: [qsTr("Recommend land"), qsTr("Warn only"), qsTr("Auto land")]; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 25; Layout.preferredHeight: root.controlHeight }
                            }
                            QGCLabel { text: qsTr("Options: Warn only - Recommend land - Auto land"); color: root.muted; font.pointSize: ScreenTools.smallFontPointSize }
                            RowLayout {
                                QGCLabel { text: qsTr("Torque presets"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                Item { Layout.fillWidth: true }
                                Repeater { model: [0, 30, 100]; delegate: QGCButton { text: modelData + " %"; Layout.preferredHeight: root.controlHeight; onClicked: { station.setTorqueRemote(true); station.setTorquePercent(modelData) } } }
                            }
                            QGCLabel { Layout.fillWidth: true; text: qsTr("Values apply immediately and are kept after restart."); color: root.muted; wrapMode: Text.WordWrap; font.pointSize: ScreenTools.smallFontPointSize }
                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }
            Item {
                id: settingsPage
                property real compactHeight: root.controlHeight
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelWidth * 1.25
                    spacing: ScreenTools.defaultFontPixelWidth * 1.15

                    ColumnLayout {
                        Layout.preferredWidth: parent.width * .31
                        Layout.fillHeight: true
                        spacing: ScreenTools.defaultFontPixelHeight * .45
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.65
                            color: "#258bdc"; radius: ScreenTools.defaultFontPixelWidth * .35
                            QGCLabel { anchors.centerIn: parent; text: qsTr("?  Stored in the station (EEPROM). Changes are written together when you press Save."); color: "white"; font.pointSize: ScreenTools.smallFontPointSize }
                        }
                        QGCLabel { text: qsTr("Power alarms"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 8.7; color: root.card
                            GridLayout {
                                anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * .8; columns: 2
                                columnSpacing: ScreenTools.defaultFontPixelWidth; rowSpacing: ScreenTools.defaultFontPixelHeight * .4
                                QGCLabel { text: qsTr("Power Alarm"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("[W] read-only"); color: root.muted; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true; font.pointSize: ScreenTools.smallFontPointSize }
                                QGCLabel { text: qsTr("Power Alert"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCTextField { text: "85"; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 9; Layout.preferredHeight: settingsPage.compactHeight; inputMethodHints: Qt.ImhDigitsOnly; onTextChanged: root.settingsDirty = true }
                                QGCLabel { text: qsTr("Length Alarm"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCTextField { text: "10"; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 9; Layout.preferredHeight: settingsPage.compactHeight; inputMethodHints: Qt.ImhDigitsOnly; onTextChanged: root.settingsDirty = true }
                            }
                        }
                        QGCLabel { text: qsTr("Auto power-off"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 11.3; color: root.card
                            ColumnLayout { anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * .8; spacing: ScreenTools.defaultFontPixelHeight * .45
                                QGCCheckBox { text: qsTr("Enable"); checked: true; onClicked: root.settingsDirty = true }
                                RowLayout { Layout.fillWidth: true; QGCLabel { text: qsTr("High / Low"); color: "white"; Layout.fillWidth: true }
                                QGCTextField { text: "[W]"; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6; Layout.preferredHeight: settingsPage.compactHeight }
                                QGCTextField { text: "[W]"; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6; Layout.preferredHeight: settingsPage.compactHeight } }
                                RowLayout { Layout.fillWidth: true; QGCLabel { text: qsTr("Time trigger"); color: "white"; Layout.fillWidth: true }
                                QGCTextField { text: "[s]"; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10; Layout.preferredHeight: settingsPage.compactHeight; onTextChanged: root.settingsDirty = true } }
                                RowLayout { Layout.fillWidth: true; QGCLabel { text: qsTr("Length trigger"); color: "white"; Layout.fillWidth: true }
                                QGCTextField { id: lengthTrigger; text: "100"; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10; Layout.preferredHeight: settingsPage.compactHeight; inputMethodHints: Qt.ImhDigitsOnly; onTextChanged: { root.settingsDirty = true; root.lengthError = Number(text) > 200 } } }
                                QGCLabel { visible: root.lengthError; text: qsTr("Allowed 0?200 m"); color: "#ff5e57"; font.pointSize: ScreenTools.smallFontPointSize }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: parent.width * .37
                        Layout.fillHeight: true
                        spacing: ScreenTools.defaultFontPixelHeight * .45
                        QGCLabel { text: qsTr("Winch functions"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 13.6; color: root.card
                            ColumnLayout { anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * .8; spacing: ScreenTools.defaultFontPixelHeight * .35
                                RowLayout { Layout.fillWidth: true; QGCCheckBox { text: qsTr("Take-off/land protection"); checked: true; onClicked: root.settingsDirty = true }
                                Item { Layout.fillWidth: true }
                                QGCTextField { text: "10"; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6; Layout.preferredHeight: settingsPage.compactHeight; inputMethodHints: Qt.ImhDigitsOnly; onTextChanged: root.settingsDirty = true }
                                QGCLabel { text: "m"; color: "white" } }
                                RowLayout { Layout.fillWidth: true; QGCCheckBox { text: qsTr("Anti-shock"); checked: true; onClicked: root.settingsDirty = true }
                                Item { Layout.fillWidth: true }
                                QGCTextField { text: "30"; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6; Layout.preferredHeight: settingsPage.compactHeight; inputMethodHints: Qt.ImhDigitsOnly; onTextChanged: root.settingsDirty = true }
                                QGCLabel { text: "%"; color: "white" } }
                                RowLayout { Layout.fillWidth: true; QGCCheckBox { text: qsTr("Anti-ground dragging"); checked: false; onClicked: root.settingsDirty = true }
                                Item { Layout.fillWidth: true }
                                QGCLabel { text: qsTr("2.0 s ? 1 %"); color: root.muted; font.pointSize: ScreenTools.smallFontPointSize } }
                                QGCCheckBox { text: qsTr("Anti-entrapment"); checked: true; onClicked: root.settingsDirty = true }
                                QGCLabel { text: qsTr("Keep Anti-entrapment enabled (warning on disable)."); color: "#f4b244"; wrapMode: Text.WordWrap; font.pointSize: ScreenTools.smallFontPointSize }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.25; color: "#d7ad00"; radius: ScreenTools.defaultFontPixelWidth * .35
                            QGCLabel { anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * .7; text: qsTr("Read-only while the vehicle is armed or the station reports flight (> 200 W)."); color: "black"; wrapMode: Text.WordWrap; font.pointSize: ScreenTools.smallFontPointSize }
                        }
                        RowLayout { Layout.fillWidth: true; QGCLabel { text: root.settingsDirty ? (root.lengthError ? qsTr("1 change ? 1 error") : qsTr("1 change")) : qsTr("No changes"); color: root.lengthError ? "#ff5e57" : "#258bdc"; font.pointSize: ScreenTools.defaultFontPointSize }
                                Item { Layout.fillWidth: true }
                                QGCButton { text: qsTr("Cancel"); Layout.preferredHeight: settingsPage.compactHeight; onClicked: { root.settingsDirty = false; root.lengthError = false; lengthTrigger.text = "100" } }
                                QGCButton { text: qsTr("Save"); enabled: root.settingsDirty && !root.lengthError; Layout.preferredHeight: settingsPage.compactHeight; onClicked: root.settingsDirty = false } }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: ScreenTools.defaultFontPixelHeight * .45
                        QGCLabel { text: qsTr("Comms & Wi-Fi"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 15.5; color: root.card
                            GridLayout { anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * .8; columns: 2; columnSpacing: ScreenTools.defaultFontPixelWidth; rowSpacing: ScreenTools.defaultFontPixelHeight * .55
                                QGCLabel { text: qsTr("Control timeout"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCTextField { text: "250"; Layout.preferredHeight: settingsPage.compactHeight; inputMethodHints: Qt.ImhDigitsOnly; onTextChanged: root.settingsDirty = true }
                                QGCLabel { text: qsTr("Tether length"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("[m]"); color: root.muted; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true }
                                QGCLabel { text: qsTr("Tether weight"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("[g/m]"); color: root.muted; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true }
                                QGCLabel { text: qsTr("Wi-Fi SSID"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCTextField { text: "SAFE-T-[S/N]"; Layout.preferredHeight: settingsPage.compactHeight; onTextChanged: root.settingsDirty = true }
                                QGCLabel { text: qsTr("Wi-Fi password"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCTextField { id: wifiPassword; text: "safetpass"; echoMode: root.showPassword ? TextInput.Normal : TextInput.Password; Layout.preferredHeight: settingsPage.compactHeight; onTextChanged: root.settingsDirty = true }
                                Item { }
                                QGCCheckBox { text: qsTr("Show password"); checked: root.showPassword; onClicked: root.showPassword = checked }
                            }
                        }
                    }
                }
            }
            Item {
                id: deviceInfoPage
                property string serialNumber: station.connected ? qsTr("S/N") : qsTr("Not available")
                property string deviceText: qsTr("Serial No.: %1\nFW ? Interface board: [x.y]\nFW ? Command board: [x.y]\nFW ? Power board: [x.y]\nFrame version: Ext V1 (auto-detected)\nPowered hours: 312 h\nFlights: 148\nSince maintenance: 46 h / interval [h]").arg(serialNumber)
                TextEdit { id: deviceInfoCopyBuffer; visible: false; text: deviceInfoPage.deviceText }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelWidth * 1.3
                    spacing: ScreenTools.defaultFontPixelHeight * .7
                    QGCLabel { text: qsTr("Device"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                    Rectangle {
                        Layout.preferredWidth: parent.width * .56
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 15.2
                        color: root.card
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * .9
                            spacing: ScreenTools.defaultFontPixelHeight * .36
                            GridLayout {
                                Layout.fillWidth: true; columns: 2
                                columnSpacing: ScreenTools.defaultFontPixelWidth * 4
                                rowSpacing: ScreenTools.defaultFontPixelHeight * .3
                                QGCLabel { text: qsTr("Serial No."); color: root.muted; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: deviceInfoPage.serialNumber; color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("FW ? Interface board"); color: root.muted; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: "[x.y]"; color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("FW ? Command board"); color: root.muted; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: "[x.y]"; color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("FW ? Power board"); color: root.muted; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: "[x.y]"; color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("Frame version"); color: root.muted; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("Ext V1 (auto-detected)"); color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("Powered hours"); color: root.muted; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: "312 h"; color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("Flights"); color: root.muted; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: "148"; color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("Since maintenance"); color: root.muted; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("46 h / interval [h]"); color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.defaultFontPointSize }
                            }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * .38; radius: height / 2; color: "#20252b"; Rectangle { width: parent.width * .37; height: parent.height; radius: parent.radius; color: root.teal } }
                        }
                    }
                    QGCLabel { Layout.preferredWidth: parent.width * .56; text: qsTr("Maintenance reminder: caution at 90 % of the interval, warning above 100 %. Counter reset is not provided until Elistair defines a frame."); color: root.muted; wrapMode: Text.WordWrap; font.pointSize: ScreenTools.smallFontPointSize }
                    RowLayout {
                        Layout.preferredWidth: parent.width * .56
                        QGCButton { text: qsTr("Copy device info"); Layout.preferredHeight: root.controlHeight; onClicked: { deviceInfoCopyBuffer.selectAll(); deviceInfoCopyBuffer.copy(); deviceInfoCopyBuffer.deselect() } }
                        Item { Layout.fillWidth: true }
                        QGCLabel { text: qsTr("Read-only"); color: root.muted; font.pointSize: ScreenTools.smallFontPointSize }
                    }
                }
            }
        }
    }
}
