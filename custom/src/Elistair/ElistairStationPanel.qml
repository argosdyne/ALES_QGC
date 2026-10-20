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
    visible: station !== null
    width: ScreenTools.defaultFontPixelWidth * 32
    height: ScreenTools.defaultFontPixelHeight * 25
    color: qgcPal.window
    radius: ScreenTools.defaultFontPixelWidth
    border.color: qgcPal.button
    border.width: 1

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelHeight * 0.45

        RowLayout {
            Layout.fillWidth: true
            QGCLabel { text: qsTr("Elistair SAFE-T"); font.bold: true; font.pointSize: ScreenTools.largeFontPointSize }
            Item { Layout.fillWidth: true }
            QGCLabel { text: station.connected ? qsTr("Connected") : qsTr("Disconnected"); color: station.connected ? qgcPal.colorGreen : qgcPal.colorRed }
        }

        GridLayout {
            columns: 2
            Layout.fillWidth: true
            QGCLabel { text: qsTr("Power authority") }
            RowLayout {
                QGCRadioButton { text: qsTr("Local"); checked: !station.powerRemote; onClicked: station.setPowerRemote(false) }
                QGCRadioButton { text: qsTr("Remote"); checked: station.powerRemote; onClicked: station.setPowerRemote(true) }
            }
            QGCButton { text: qsTr("Power ON"); enabled: station.powerRemote; Layout.fillWidth: true; onClicked: station.setPowerOn(true) }
            QGCButton {
                text: qsTr("Power OFF")
                enabled: station.powerRemote
                Layout.fillWidth: true
                onClicked: {
                    var vehicle = QGroundControl.multiVehicleManager.activeVehicle
                    if (vehicle && vehicle.armed) {
                        powerOffConfirm.open()
                    } else {
                        station.setPowerOn(false)
                    }
                }
            }
            QGCLabel { text: qsTr("Torque authority") }
            RowLayout {
                QGCRadioButton { text: qsTr("Local"); checked: !station.torqueRemote; onClicked: station.setTorqueRemote(false) }
                QGCRadioButton { text: qsTr("Remote"); checked: station.torqueRemote; onClicked: station.setTorqueRemote(true) }
            }
        }

        QGCLabel { text: qsTr("Torque: %1%").arg(station.torquePercent) }
        Slider { Layout.fillWidth: true; from: 0; to: 100; stepSize: 1; enabled: station.torqueRemote; value: station.torquePercent; onMoved: station.setTorquePercent(Math.round(value)) }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            QGCLabel { text: qsTr("Power"); color: qgcPal.buttonText }
            QGCLabel { text: "%1 W".arg(station.powerWatts) }
            QGCLabel { text: qsTr("Cable length") }
            QGCLabel { text: "%1 m".arg(station.cableLength.toFixed(1)) }
            QGCLabel { text: qsTr("Cable speed") }
            QGCLabel { text: "%1 m/s".arg(station.cableSpeed.toFixed(1)) }
            QGCLabel { text: qsTr("Spool temperature") }
            QGCLabel { text: qsTr("%1 degrees C").arg(station.spoolTemperature) }
            QGCLabel { text: qsTr("Output") }
            QGCLabel { text: "%1 V / %2 A".arg(station.voltage.toFixed(1)).arg(station.current.toFixed(2)) }
            QGCLabel { text: qsTr("Applied torque") }
            QGCLabel { text: "%1%".arg(station.appliedTorquePercent) }
        }

        QGCLabel { Layout.fillWidth: true; text: station.alarmSummary; color: station.alarmSummary === qsTr("No alarms") ? qgcPal.colorGreen : qgcPal.colorRed; horizontalAlignment: Text.AlignHCenter }
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
