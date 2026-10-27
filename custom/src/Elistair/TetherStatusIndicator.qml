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

    visible: station !== null
    width: ScreenTools.defaultFontPixelWidth * 6.4
    height: parent ? parent.height : ScreenTools.defaultFontPixelHeight * 2.4
    color: tetherMouse.containsMouse ? "#353e49" : "transparent"
    radius: ScreenTools.defaultFontPixelWidth * 0.35

    Row {
        anchors.centerIn: parent
        spacing: ScreenTools.defaultFontPixelWidth * 0.38

        Rectangle {
            width: ScreenTools.defaultFontPixelHeight * 0.72
            height: width
            radius: width / 2
            color: station.connected ? root.green : root.red
            border.color: "white"
            border.width: 1
        }

        QGCLabel {
            text: qsTr("Tether")
            color: "white"
            font.family: ScreenTools.demiboldFontFamily
            font.pointSize: ScreenTools.defaultFontPointSize
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
        x: Math.max(0, root.width - width)
        y: root.height + ScreenTools.defaultFontPixelHeight * 0.45
        width: ScreenTools.defaultFontPixelWidth * 25
        height: contentItem.implicitHeight + topPadding + bottomPadding
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

        contentItem: ColumnLayout {
            spacing: ScreenTools.defaultFontPixelHeight * 0.36

            RowLayout {
                Layout.fillWidth: true
                QGCLabel {
                    text: qsTr("Tether Status")
                    color: "white"
                    font.family: ScreenTools.demiboldFontFamily
                    font.pointSize: ScreenTools.largeFontPointSize
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: statusText.implicitWidth + ScreenTools.defaultFontPixelWidth
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.45
                    radius: height / 2
                    color: station.connected ? root.green : root.red
                    QGCLabel {
                        id: statusText
                        anchors.centerIn: parent
                        text: station.connected ? qsTr("CONNECTED") : qsTr("DISCONNECTED")
                        color: "white"
                        font.family: ScreenTools.demiboldFontFamily
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: "#3a424d" }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: ScreenTools.defaultFontPixelWidth * 0.7
                rowSpacing: ScreenTools.defaultFontPixelHeight * 0.2

                QGCLabel { text: qsTr("Station:"); color: root.mutedColor }
                QGCLabel { text: qsTr("SAFE-T #1 - %1").arg(station.stationAddress); color: "white"; elide: Text.ElideRight; Layout.fillWidth: true }
                QGCLabel { text: qsTr("Link:"); color: root.mutedColor }
                QGCLabel { text: station.connected ? qsTr("Connected - Ext V1") : qsTr("Disconnected"); color: station.connected ? "white" : root.red; Layout.fillWidth: true }
                QGCLabel { text: qsTr("Authority:"); color: root.mutedColor }
                QGCLabel { text: station.powerRemote ? qsTr("REMOTE") : qsTr("LOCAL"); color: "white"; Layout.fillWidth: true }
                QGCLabel { text: qsTr("Power:"); color: root.mutedColor }
                QGCLabel { text: station.powerOn ? qsTr("ON - %1 W").arg(station.powerWatts.toFixed(0)) : qsTr("OFF - 0 W"); color: "white"; Layout.fillWidth: true }
                QGCLabel { text: qsTr("Tether:"); color: root.mutedColor }
                QGCLabel { text: qsTr("%1 m / 100.0 m").arg(station.cableLength.toFixed(1)); color: "white"; Layout.fillWidth: true }
                QGCLabel { text: qsTr("Torque:"); color: root.mutedColor }
                QGCLabel { text: qsTr("set %1%% - applied %2%%").arg(station.torquePercent).arg(station.appliedTorquePercent); color: "white"; Layout.fillWidth: true }
                QGCLabel { text: qsTr("Spool temp:"); color: root.mutedColor }
                QGCLabel { text: station.spoolTemperature + qsTr(" C"); color: "white"; Layout.fillWidth: true }
                QGCLabel { text: qsTr("Alarms:"); color: root.mutedColor }
                QGCLabel { text: station.alarmSummary === qsTr("No alarms") ? qsTr("None") : station.alarmSummary; color: station.alarmSummary === qsTr("No alarms") ? "white" : root.red; Layout.fillWidth: true; elide: Text.ElideRight }
            }

            QGCButton {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Open Tether Panel")
                onClicked: {
                    tetherStatusPopup.close()
                    mainWindow.tetherPanelVisible = true
                }
            }
        }
    }
}
