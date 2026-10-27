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
    property color card: "#363c43"
    property color muted: "#a1a9b8"
    property color teal: "#0aa27e"
    property real controlHeight: ScreenTools.defaultFontPixelHeight * 2.1
    color: "#202428"
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
            color: "#1d2226"
            ColumnLayout {
                anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * .6
                Repeater {
                    model: [qsTr("Connection"), qsTr("Settings"), qsTr("Device Info")]
                    delegate: Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.8
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
                                QGCComboBox { model: [qsTr("Auto (detect)")]; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 29; Layout.preferredHeight: root.controlHeight }
                            }
                            RowLayout {
                                QGCButton { text: qsTr("Test"); Layout.preferredHeight: root.controlHeight; onClicked: root.testConnection() }
                                Rectangle {
                                    visible: station.connected; width: ok.implicitWidth + ScreenTools.defaultFontPixelWidth; height: ScreenTools.defaultFontPixelHeight * 1.6
                                    radius: height / 2; color: root.teal
                                    QGCLabel { id: ok; anchors.centerIn: parent; text: qsTr("OK"); color: "white" }
                                }
                                QGCLabel { text: station.connected ? qsTr("S/N [S/N] - FW [x.y] / [x.y] / [x.y] - Ext V1") : qsTr("Waiting for station response"); color: root.muted; font.pointSize: ScreenTools.smallFontPointSize }
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
            Rectangle {
                color: root.card
                ColumnLayout { anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * 2
                    QGCLabel { text: qsTr("Station settings"); color: "white"; font.pointSize: ScreenTools.largeFontPointSize }
                    QGCLabel { text: qsTr("Station configuration will be available when SAFE-T configuration read/write is enabled."); color: root.muted; wrapMode: Text.WordWrap }
                }
            }
            Rectangle {
                color: root.card
                ColumnLayout { anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * 2
                    QGCLabel { text: qsTr("Device information"); color: "white"; font.pointSize: ScreenTools.largeFontPointSize }
                    GridLayout { columns: 2; columnSpacing: ScreenTools.defaultFontPixelWidth * 3
                        QGCLabel { text: qsTr("Model"); color: root.muted }
                                QGCLabel { text: qsTr("SAFE-T Extended V1"); color: "white" }
                        QGCLabel { text: qsTr("Station endpoint"); color: root.muted }
                                QGCLabel { text: station.stationAddress + ":" + station.stationPort; color: "white" }
                        QGCLabel { text: qsTr("Connection"); color: root.muted }
                                QGCLabel { text: station.connected ? qsTr("Connected") : qsTr("Disconnected"); color: station.connected ? root.teal : root.muted }
                    }
                }
            }
        }
    }
}
