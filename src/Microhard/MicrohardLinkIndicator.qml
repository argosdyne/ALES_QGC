import QtQuick          2.11
import QtQuick.Layouts  1.11

import QGroundControl                       1.0
import QGroundControl.Controls              1.0
import QGroundControl.MultiVehicleManager   1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.Palette               1.0
import QGroundControl.FactSystem            1.0

import Custom.Widgets                       1.0

Item {
    id:             _root
    width:          signalRow.width

    QGCPalette { id: qgcPal }

    property var  microhardManager:     QGroundControl.microhardManager
    property var  _activeVehicle:       QGroundControl.multiVehicleManager.activeVehicle
    property bool _enabled:             QGroundControl.settingsManager.appSettings.enableMicrohard.rawValue
    property bool _connected:           _enabled && (microhardManager.statsConnected || microhardManager.connected === 1 || microhardManager.linkConnected === 1)
    property bool showIndicator:        _enabled

    function _isNumber(value) {
        return value !== undefined && value !== null && value !== "" && value !== "--" && !isNaN(Number(value))
    }

    function _formatValue(value, unit) {
        return value !== undefined && value !== null && value !== "" && value !== "--" ? value + unit : qsTr("N/A")
    }

    function _formatRssi(value) {
        return _formatValue(value, " dBm")
    }

    function _cachedGroundRssi() {
        if (microhardManager.groundRSSI !== "--") {
            return microhardManager.groundRSSI
        }
        return microhardManager.downlinkRSSI < 0 ? microhardManager.downlinkRSSI.toString() : "--"
    }

    function _cachedSkyRssi() {
        if (microhardManager.skyRSSI !== "--") {
            return microhardManager.skyRSSI
        }
        return microhardManager.uplinkRSSI < 0 ? microhardManager.uplinkRSSI.toString() : "--"
    }

    function _firstRssiNumber(value) {
        var match = value.toString().match(/-?\d+(\.\d+)?/)
        return match ? Number(match[0]) : 0
    }

    function getSignalStrength(rssi) {
        if (rssi >= -60) return 100
        if (rssi >= -70) return 75
        if (rssi >= -80) return 50
        if (rssi < 0) return 25
        return 0
    }

    Component {
        id: microhardInfo

        Rectangle {
            width:                              statsCol.width  + ScreenTools.defaultFontPixelWidth * 4
            height:                             statsCol.height + ScreenTools.defaultFontPixelWidth * 4
            radius:                             ScreenTools.defaultFontPixelHeight * 0.5
            color:                              qgcPal.window
            border.color:                       qgcPal.text

            Component.onCompleted:              microhardManager.refreshStats()

            MouseArea {
                anchors.fill:                   parent
                preventStealing:                true
                onWheel:                        wheel.accepted = true
            }

            Column {
                id:                             statsCol
                spacing:                        ScreenTools.defaultFontPixelHeight
                anchors.margins:                ScreenTools.defaultFontPixelHeight
                anchors.centerIn:               parent

                QGCLabel {
                    text:                       _connected ? qsTr("Link RSSI Status") : qsTr("Link Disconnected")
                    font.family:                ScreenTools.demiboldFontFamily
                    anchors.horizontalCenter:   parent.horizontalCenter
                }

                GridLayout {
                    visible:                    _connected
                    columnSpacing:              ScreenTools.defaultFontPixelWidth
                    rowSpacing:                 ScreenTools.defaultFontPixelHeight * 0.35
                    columns:                    2
                    anchors.horizontalCenter:   parent.horizontalCenter

                    QGCLabel { text: qsTr("RSSI:") }
                    QGCLabel { text: _formatRssi(_cachedGroundRssi()) }

                    QGCLabel { text: qsTr("Sky RSSI:") }
                    QGCLabel { text: _formatRssi(_cachedSkyRssi()) }

                    QGCLabel { text: qsTr("SNR:") }
                    QGCLabel { text: _formatValue(microhardManager.snr, " dB") }

                    QGCLabel { text: qsTr("TX Rate:") }
                    QGCLabel { text: _formatValue(microhardManager.txRate, "") }

                    QGCLabel { text: qsTr("RX Rate:") }
                    QGCLabel { text: _formatValue(microhardManager.rxRate, "") }

                    QGCLabel { text: qsTr("TX/RX Throughput:") }
                    QGCLabel { text: _formatValue(microhardManager.txThroughput, "") + " / " + _formatValue(microhardManager.rxThroughput, "") }

                    QGCLabel { text: qsTr("TX/RX Bytes:") }
                    QGCLabel { text: _formatValue(microhardManager.txBytes, "") + " / " + _formatValue(microhardManager.rxBytes, "") }

                    QGCLabel { text: qsTr("Queue Length:") }
                    QGCLabel { text: _formatValue(microhardManager.queueLength, "") }

                    QGCLabel {
                        text:       qsTr("Frequency:")
                        visible:    microhardManager.frequency !== "--"
                    }
                    QGCLabel {
                        text:       _formatValue(microhardManager.frequency, "")
                        visible:    microhardManager.frequency !== "--"
                    }

                    QGCLabel {
                        text:       qsTr("Temperature:")
                        visible:    microhardManager.temperature !== "--"
                    }
                    QGCLabel {
                        text:       _formatValue(microhardManager.temperature, "")
                        visible:    microhardManager.temperature !== "--"
                    }

                    QGCLabel {
                        text:       qsTr("Version:")
                        visible:    microhardManager.version !== "--"
                    }
                    QGCLabel {
                        text:       _formatValue(microhardManager.version, "")
                        visible:    microhardManager.version !== "--"
                    }

                    QGCLabel { text: qsTr("Main Link:") }
                    QGCLabel { text: _activeVehicle ? (_activeVehicle.mainLinkName + (_activeVehicle.rcOnUDP ? "+" : "")) : microhardManager.mainLink }
                }

                QGCLabel {
                    visible:                    !_connected
                    text:                       qsTr("Waiting for Microhard stats on UDP 20202/20203")
                    color:                      qgcPal.text
                    anchors.horizontalCenter:   parent.horizontalCenter
                }

                QGCButton {
                    text:                       qsTr("Start Pair")
                    visible:                    QGroundControl.pairingManager && QGroundControl.pairingManager.microhardIndex >= 0
                    width:                      ScreenTools.defaultFontPixelWidth * 15
                    anchors.horizontalCenter:   parent.horizontalCenter
                    onClicked: {
                        mainWindow.hideIndicatorPopup()
                        QGroundControl.pairingManager.startMicrohardPairing()
                    }
                }
            }
        }
    }

    Row {
        id:                                     signalRow
        spacing:                                ScreenTools.defaultFontPixelWidth
        anchors.top:                            parent.top
        anchors.bottom:                         parent.bottom
        anchors.horizontalCenter:               parent.horizontalCenter

        SignalStrength {
            anchors.verticalCenter:             parent.verticalCenter
            size:                               ScreenTools.defaultFontPixelHeight * 1.6
            percent:                            _connected ? getSignalStrength(Math.min(_firstRssiNumber(_cachedGroundRssi()), _firstRssiNumber(_cachedSkyRssi()))) : 0
        }

        Column {
            anchors.verticalCenter:             parent.verticalCenter
            spacing:                            0

            QGCLabel {
                text:                           "2.4G"
                font.pointSize:                 ScreenTools.defaultFontPointSize
            }
            QGCLabel {
                text:                           "Microhard"
                font.pointSize:                 ScreenTools.defaultFontPointSize
            }
        }
    }

    MouseArea {
        anchors.fill:                           parent
        anchors.margins:                        -ScreenTools.defaultFontPixelHeight * 0.66
        onClicked:                              mainWindow.showIndicatorPopup(_root, microhardInfo)
    }
}
