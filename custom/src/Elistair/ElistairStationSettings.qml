import QtQuick 2.12
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.12
import QGroundControl 1.0
import QGroundControl.Controls 1.0
import QGroundControl.Palette 1.0
import QGroundControl.ScreenTools 1.0

Rectangle {
    id: root
    property var station: QGroundControl.corePlugin.elistairStationManager
    property color accentColor: "#2d7ff9"
    property color formColor: qgcPal.windowShade
    property bool settingsLocked: !station.connected
    color: qgcPal.window

    QGCPalette { id: qgcPal }

    function showPreviewNotice() {
        previewNotice.text = qsTr("UI preview only — SAFE-T configuration read/write is not connected yet.")
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth * 2
        spacing: ScreenTools.defaultFontPixelHeight * 0.7

        QGCLabel { text: qsTr("SAFE-T Station"); font.pointSize: ScreenTools.largeFontPointSize; font.family: ScreenTools.demiboldFontFamily }

        QGCTabBar {
            id: tabs
            Layout.fillWidth: true
            QGCTabButton { text: qsTr("Connection") }
            QGCTabButton { text: qsTr("Settings") }
            QGCTabButton { text: qsTr("Device Info") }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabs.currentIndex

            Flickable {
                clip: true
                contentWidth: width
                contentHeight: connectionColumn.implicitHeight
                ColumnLayout {
                    id: connectionColumn
                    width: parent.width
                    spacing: ScreenTools.defaultFontPixelHeight
                    QGCLabel { text: qsTr("Connection Settings"); font.family: ScreenTools.demiboldFontFamily }
                    GridLayout {
                        columns: 2
                        columnSpacing: ScreenTools.defaultFontPixelWidth * 2
                        rowSpacing: ScreenTools.defaultFontPixelHeight * 0.45
                        QGCLabel { text: qsTr("Station IP Address") }
                        QGCTextField { id: address; text: station.stationAddress; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 28 }
                        QGCLabel { text: qsTr("UDP Port") }
                        QGCTextField { id: port; text: station.stationPort; inputMethodHints: Qt.ImhDigitsOnly }
                    }
                    RowLayout {
                        QGCButton { text: qsTr("Test Connection"); onClicked: { station.stationAddress = address.text; station.stationPort = Number(port.text); station.connectStation() } }
                        QGCButton { text: qsTr("Disconnect"); onClicked: station.disconnectStation() }
                        QGCLabel { text: station.connected ? qsTr("Connected") : qsTr("Waiting for monitoring frame"); color: station.connected ? qgcPal.colorGreen : qgcPal.colorYellow }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: qgcPal.button }
                    QGCLabel { text: qsTr("GCS Behavior"); font.family: ScreenTools.demiboldFontFamily }
                    GridLayout {
                        columns: 2
                        QGCLabel { text: qsTr("Control Rate") }
                        QGCComboBox { model: [qsTr("5 Hz (200 ms)")] }
                        QGCLabel { text: qsTr("Response Timeout") }
                        QGCComboBox { model: [qsTr("1 s")] }
                        QGCLabel { text: qsTr("Disconnected Timeout") }
                        QGCComboBox { model: [qsTr("5 s")] }
                    }
                }
            }

            Flickable {
                clip: true
                contentWidth: width
                contentHeight: settingsColumn.implicitHeight

                ColumnLayout {
                    id: settingsColumn
                    width: Math.min(parent.width, ScreenTools.defaultFontPixelWidth * 72)
                    x: Math.max(0, (parent.width - width) / 2)
                    spacing: ScreenTools.defaultFontPixelHeight * 0.65

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: previewWarning.implicitHeight + ScreenTools.defaultFontPixelHeight * 1.4
                        color: "#755a1b"
                        radius: ScreenTools.defaultFontPixelWidth * 0.4
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelWidth
                            QGCLabel { text: "!"; color: "#fff1b8"; font.pointSize: ScreenTools.largeFontPointSize; font.bold: true }
                            QGCLabel {
                                id: previewWarning
                                Layout.fillWidth: true
                                text: qsTr("Configuration UI preview. Values are editable for review, but will not be transmitted to SAFE-T yet.")
                                color: "#fff1b8"
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        QGCButton { text: qsTr("Read Configuration"); enabled: !settingsLocked; onClicked: root.showPreviewNotice() }
                        Item { Layout.fillWidth: true }
                        QGCButton { text: qsTr("Write Changed Values"); enabled: !settingsLocked; onClicked: root.showPreviewNotice() }
                    }
                    QGCLabel { id: previewNotice; Layout.fillWidth: true; visible: text.length > 0; color: qgcPal.colorYellow; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }

                    // Cable Settings
                    Rectangle {
                        id: cableSection
                        property bool expanded: true
                        Layout.fillWidth: true
                        implicitHeight: cableHeader.height + (expanded ? cableForm.implicitHeight : 0)
                        color: root.formColor
                        radius: ScreenTools.defaultFontPixelWidth * 0.45
                        Rectangle {
                            id: cableHeader
                            width: parent.width; height: ScreenTools.defaultFontPixelHeight * 2.65
                            color: qgcPal.button; radius: parent.radius
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.2; anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.2
                                QGCLabel { text: cableSection.expanded ? "⌄" : "›"; font.pointSize: ScreenTools.largeFontPointSize }
                                QGCLabel { Layout.fillWidth: true; text: qsTr("Cable Settings"); font.family: ScreenTools.demiboldFontFamily }
                                QGCLabel { text: qsTr("Length and tether properties"); color: qgcPal.buttonText; font.pointSize: ScreenTools.smallFontPointSize }
                            }
                            MouseArea { anchors.fill: parent; onClicked: cableSection.expanded = !cableSection.expanded }
                        }
                        RowLayout {
                            id: cableForm
                            visible: cableSection.expanded
                            width: parent.width - ScreenTools.defaultFontPixelWidth * 2
                            x: ScreenTools.defaultFontPixelWidth; y: cableHeader.height + ScreenTools.defaultFontPixelHeight * 0.65
                            spacing: ScreenTools.defaultFontPixelWidth * 3
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 3; columnSpacing: ScreenTools.defaultFontPixelWidth * 0.7; rowSpacing: ScreenTools.defaultFontPixelHeight * 0.45
                                QGCLabel { text: qsTr("Length alarm"); Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 16 }
                                QGCTextField { text: "80"; inputMethodHints: Qt.ImhFormattedNumbersOnly; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10 }
                                QGCLabel { text: qsTr("m"); color: qgcPal.buttonText }
                                QGCLabel { text: qsTr("Protection length") }
                                QGCTextField { text: "5"; inputMethodHints: Qt.ImhFormattedNumbersOnly; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10 }
                                QGCLabel { text: qsTr("m"); color: qgcPal.buttonText }
                            }
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 3; columnSpacing: ScreenTools.defaultFontPixelWidth * 0.7; rowSpacing: ScreenTools.defaultFontPixelHeight * 0.45
                                QGCLabel { text: qsTr("Theoretical tether length"); Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 19 }
                                QGCTextField { text: "100"; inputMethodHints: Qt.ImhFormattedNumbersOnly; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10 }
                                QGCLabel { text: qsTr("m"); color: qgcPal.buttonText }
                                QGCLabel { text: qsTr("Tether weight") }
                                QGCTextField { text: "0.0"; inputMethodHints: Qt.ImhFormattedNumbersOnly; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10 }
                                QGCLabel { text: qsTr("kg"); color: qgcPal.buttonText }
                            }
                        }
                    }

                    // Power Settings
                    Rectangle {
                        id: powerSection
                        property bool expanded: false
                        Layout.fillWidth: true
                        implicitHeight: powerHeader.height + (expanded ? powerForm.implicitHeight : 0)
                        color: root.formColor; radius: ScreenTools.defaultFontPixelWidth * 0.45
                        Rectangle {
                            id: powerHeader; width: parent.width; height: ScreenTools.defaultFontPixelHeight * 2.65; color: qgcPal.button; radius: parent.radius
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.2; anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.2
                                QGCLabel { text: powerSection.expanded ? "⌄" : "›"; font.pointSize: ScreenTools.largeFontPointSize }
                                QGCLabel { Layout.fillWidth: true; text: qsTr("Power Settings"); font.family: ScreenTools.demiboldFontFamily }
                                QGCLabel { text: qsTr("Alarms and output thresholds"); color: qgcPal.buttonText; font.pointSize: ScreenTools.smallFontPointSize }
                            }
                            MouseArea { anchors.fill: parent; onClicked: powerSection.expanded = !powerSection.expanded }
                        }
                        RowLayout {
                            id: powerForm; visible: powerSection.expanded
                            width: parent.width - ScreenTools.defaultFontPixelWidth * 2; x: ScreenTools.defaultFontPixelWidth; y: powerHeader.height + ScreenTools.defaultFontPixelHeight * 0.65
                            spacing: ScreenTools.defaultFontPixelWidth * 3
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 3; columnSpacing: ScreenTools.defaultFontPixelWidth * 0.7; rowSpacing: ScreenTools.defaultFontPixelHeight * 0.45
                                QGCLabel { text: qsTr("Power alarm"); Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 16 }
                                QGCTextField { text: "1200"; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10; inputMethodHints: Qt.ImhDigitsOnly }
                                QGCLabel { text: qsTr("W"); color: qgcPal.buttonText }
                                QGCLabel { text: qsTr("Alert percentage") }
                                QGCTextField { text: "20"; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10; inputMethodHints: Qt.ImhDigitsOnly }
                                QGCLabel { text: qsTr("%"); color: qgcPal.buttonText }
                            }
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2; columnSpacing: ScreenTools.defaultFontPixelWidth; rowSpacing: ScreenTools.defaultFontPixelHeight * 0.45
                                QGCLabel { text: qsTr("Auto output disable"); Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 18 }
                                QGCComboBox { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 20; model: [qsTr("Disabled"), qsTr("On cable fault"), qsTr("On power alarm")] }
                            }
                        }
                    }

                    // Safety Limits
                    Rectangle {
                        id: safetySection
                        property bool expanded: false
                        Layout.fillWidth: true
                        implicitHeight: safetyHeader.height + (expanded ? safetyForm.implicitHeight : 0)
                        color: root.formColor; radius: ScreenTools.defaultFontPixelWidth * 0.45
                        Rectangle {
                            id: safetyHeader; width: parent.width; height: ScreenTools.defaultFontPixelHeight * 2.65; color: qgcPal.button; radius: parent.radius
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.2; anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.2
                                QGCLabel { text: safetySection.expanded ? "⌄" : "›"; font.pointSize: ScreenTools.largeFontPointSize }
                                QGCLabel { Layout.fillWidth: true; text: qsTr("Safety Limits"); font.family: ScreenTools.demiboldFontFamily }
                                QGCLabel { text: qsTr("Take-off, landing and cable protection"); color: qgcPal.buttonText; font.pointSize: ScreenTools.smallFontPointSize }
                            }
                            MouseArea { anchors.fill: parent; onClicked: safetySection.expanded = !safetySection.expanded }
                        }
                        ColumnLayout {
                            id: safetyForm; visible: safetySection.expanded
                            width: parent.width - ScreenTools.defaultFontPixelWidth * 2; x: ScreenTools.defaultFontPixelWidth; y: safetyHeader.height + ScreenTools.defaultFontPixelHeight * 0.5
                            spacing: ScreenTools.defaultFontPixelHeight * 0.25
                            QGCCheckBox { text: qsTr("Enable take-off / landing protection"); checked: true }
                            QGCCheckBox { text: qsTr("Enable anti-shock protection"); checked: true }
                            QGCCheckBox { text: qsTr("Enable anti-entrapment protection"); checked: true }
                            QGCCheckBox { text: qsTr("Enable anti-ground-dragging protection"); checked: true }
                        }
                    }

                    // Control Settings
                    Rectangle {
                        id: controlSection
                        property bool expanded: false
                        Layout.fillWidth: true
                        implicitHeight: controlHeader.height + (expanded ? controlForm.implicitHeight : 0)
                        color: root.formColor; radius: ScreenTools.defaultFontPixelWidth * 0.45
                        Rectangle {
                            id: controlHeader; width: parent.width; height: ScreenTools.defaultFontPixelHeight * 2.65; color: qgcPal.button; radius: parent.radius
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.2; anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.2
                                QGCLabel { text: controlSection.expanded ? "⌄" : "›"; font.pointSize: ScreenTools.largeFontPointSize }
                                QGCLabel { Layout.fillWidth: true; text: qsTr("Control Settings"); font.family: ScreenTools.demiboldFontFamily }
                                QGCLabel { text: qsTr("Timeout and algorithm authorization"); color: qgcPal.buttonText; font.pointSize: ScreenTools.smallFontPointSize }
                            }
                            MouseArea { anchors.fill: parent; onClicked: controlSection.expanded = !controlSection.expanded }
                        }
                        GridLayout {
                            id: controlForm; visible: controlSection.expanded
                            width: parent.width - ScreenTools.defaultFontPixelWidth * 2; x: ScreenTools.defaultFontPixelWidth; y: controlHeader.height + ScreenTools.defaultFontPixelHeight * 0.65
                            columns: 2; columnSpacing: ScreenTools.defaultFontPixelWidth * 2; rowSpacing: ScreenTools.defaultFontPixelHeight * 0.45
                            QGCLabel { text: qsTr("Control frame timeout") }
                            QGCTextField { text: "250"; inputMethodHints: Qt.ImhDigitsOnly; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12 }
                            QGCLabel { text: qsTr("Station algorithm") }
                            QGCComboBox { model: [qsTr("Authorized"), qsTr("Not authorized")] }
                            QGCLabel { text: qsTr("Default torque") }
                            QGCComboBox { model: ["25%", "50%", "75%", "100%"]; currentIndex: 1 }
                        }
                    }

                    // Maintenance
                    Rectangle {
                        id: maintenanceSection
                        property bool expanded: false
                        Layout.fillWidth: true
                        implicitHeight: maintenanceHeader.height + (expanded ? maintenanceForm.implicitHeight : 0)
                        color: root.formColor; radius: ScreenTools.defaultFontPixelWidth * 0.45
                        Rectangle {
                            id: maintenanceHeader; width: parent.width; height: ScreenTools.defaultFontPixelHeight * 2.65; color: qgcPal.button; radius: parent.radius
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 1.2; anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 1.2
                                QGCLabel { text: maintenanceSection.expanded ? "⌄" : "›"; font.pointSize: ScreenTools.largeFontPointSize }
                                QGCLabel { Layout.fillWidth: true; text: qsTr("Maintenance"); font.family: ScreenTools.demiboldFontFamily }
                                QGCLabel { text: qsTr("Counters and service records"); color: qgcPal.buttonText; font.pointSize: ScreenTools.smallFontPointSize }
                            }
                            MouseArea { anchors.fill: parent; onClicked: maintenanceSection.expanded = !maintenanceSection.expanded }
                        }
                        GridLayout {
                            id: maintenanceForm; visible: maintenanceSection.expanded
                            width: parent.width - ScreenTools.defaultFontPixelWidth * 2; x: ScreenTools.defaultFontPixelWidth; y: maintenanceHeader.height + ScreenTools.defaultFontPixelHeight * 0.65
                            columns: 2; columnSpacing: ScreenTools.defaultFontPixelWidth * 2; rowSpacing: ScreenTools.defaultFontPixelHeight * 0.45
                            QGCLabel { text: qsTr("Maintenance counter") }
                            QGCTextField { text: "0"; inputMethodHints: Qt.ImhDigitsOnly }
                            QGCLabel { text: qsTr("Total powered hours") }
                            QGCTextField { text: "0"; inputMethodHints: Qt.ImhDigitsOnly }
                            QGCLabel { text: qsTr("Number of drone flights") }
                            QGCTextField { text: "0"; inputMethodHints: Qt.ImhDigitsOnly }
                        }
                    }

                    QGCLabel {
                        Layout.fillWidth: true
                        text: qsTr("SAFE-T configuration preview · Read 0xA5 / Write 0xD5 protocol integration pending")
                        color: qgcPal.buttonText
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Flickable {
                clip: true
                contentWidth: width
                contentHeight: deviceColumn.implicitHeight
                ColumnLayout {
                    id: deviceColumn
                    width: parent.width
                    spacing: ScreenTools.defaultFontPixelHeight
                    QGCLabel { text: qsTr("Device Information"); font.family: ScreenTools.demiboldFontFamily }
                    QGCLabel { text: qsTr("Values will be populated after SAFE-T configuration read is implemented."); color: qgcPal.buttonText; wrapMode: Text.WordWrap }
                    GridLayout {
                        columns: 2; columnSpacing: ScreenTools.defaultFontPixelWidth * 3; rowSpacing: ScreenTools.defaultFontPixelHeight * 0.45
                        QGCLabel { text: qsTr("Serial Number") }
                        QGCLabel { text: "—" }
                        QGCLabel { text: qsTr("Model") }
                        QGCLabel { text: qsTr("SAFE-T V2.1 / V2.2") }
                        QGCLabel { text: qsTr("Interface Firmware") }
                        QGCLabel { text: "—" }
                        QGCLabel { text: qsTr("Command Firmware") }
                        QGCLabel { text: "—" }
                        QGCLabel { text: qsTr("Power Firmware") }
                        QGCLabel { text: "—" }
                        QGCLabel { text: qsTr("Total Flight Hours") }
                        QGCLabel { text: "—" }
                    }
                }
            }
        }
    }
}
