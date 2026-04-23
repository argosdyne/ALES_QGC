import QtQuick          2.12
import QtQuick.Layouts  1.2
import QtQuick.Controls 2.5

import QGroundControl                     1.0
import QGroundControl.Controls            1.0
import QGroundControl.ScreenTools         1.0
import QGroundControl.Palette             1.0

Item {
    id:     _root
    width:  signalRow.width

    QGCPalette { id: qgcPal }

    property var  rajantManager:    QGroundControl.corePlugin.rajantManager
    // Treat a dead mesh link the same as disconnected — UI goes to N/A, not stale values
    property bool _connected:       rajantManager ? rajantManager.connected && rajantManager.authenticated && rajantManager.linkLive : false
    property int  _signal:          rajantManager ? rajantManager.signal    : 0
    property int  _noise:           rajantManager ? rajantManager.noise     : 0
    property int  _snr:             rajantManager ? rajantManager.snr       : 0
    property int  _skySignal:       rajantManager ? rajantManager.skySignal : 0
    property int  _skySnr:          rajantManager ? rajantManager.skySnr    : 0
    property int  _linkRate:        rajantManager ? rajantManager.linkRate  : 0

    function getSignalStrength(signal) {
        // Map dBm signal to percentage for signal icon
        if (signal === 0 || !_connected)  return 0
        if (signal <= -90) return 10
        if (signal <= -80) return 30
        if (signal <= -70) return 50
        if (signal <= -60) return 70
        if (signal <= -50) return 85
        return 100
    }

    Component {
        id: rajantRssiInfo
        Rectangle {
            width:                  rssiInfoCol.width  + ScreenTools.defaultFontPixelWidth * 4
            height:                 rssiInfoCol.height + ScreenTools.defaultFontPixelWidth * 4
            radius:                 ScreenTools.defaultFontPixelHeight * 0.5
            color:                  qgcPal.window
            border.color:           qgcPal.text

            MouseArea {
                anchors.fill:       parent
                preventStealing:    true
                onWheel:            wheel.accepted = true
            }

            Column {
                id:                             rssiInfoCol
                spacing:                        ScreenTools.defaultFontPixelHeight
                anchors.margins:                ScreenTools.defaultFontPixelHeight
                anchors.centerIn:               parent

                QGCLabel {
                    text:                       _connected ? qsTr("Rajant Link Status") : qsTr("Rajant Disconnected")
                    font.family:                ScreenTools.demiboldFontFamily
                    anchors.horizontalCenter:   parent.horizontalCenter
                }

                GridLayout {
                    visible:                    _connected
                    columnSpacing:              ScreenTools.defaultFontPixelWidth
                    columns:                    2
                    anchors.horizontalCenter:   parent.horizontalCenter

                    QGCLabel { text: qsTr("Radio:"); color: qgcPal.text; visible:false }
                    QGCLabel {
                        text: rajantManager ? rajantManager.radioName + " (ch " + rajantManager.channel + ")" : "N/A"
                        color: qgcPal.text
                        visible: false
                    }

                    QGCLabel { text: qsTr("RSSI:"); color: qgcPal.text }
                    QGCLabel {
                        text: _connected ? _signal + " dBm / " + _snr + " dB" : qsTr("N/A")
                        color: qgcPal.text
                    }

                    QGCLabel { text: qsTr("Sky RSSI:"); color: qgcPal.text }
                    QGCLabel {
                        text: _connected && _skySnr > 0
                              ? _skySignal + " dBm / " + _skySnr + " dB"
                              : qsTr("N/A")
                        color: qgcPal.text
                    }

                    QGCLabel { text: qsTr("Noise:"); color: qgcPal.text }
                    QGCLabel {
                        text: _connected ? _noise + " dBm" : qsTr("N/A")
                        color: qgcPal.text
                    }

                    QGCLabel { text: qsTr("Link Rate:"); color: qgcPal.text; visible: false }
                    QGCLabel {
                        text: _connected ? _linkRate + " Mbps" : qsTr("N/A")
                        color: qgcPal.text
                        visible: false
                    }

                    QGCLabel { text: qsTr("Tx Power:"); color: qgcPal.text; visible: false }
                    QGCLabel {
                        text: _connected && rajantManager ? rajantManager.txPower + " dBm" : qsTr("N/A")
                        color: qgcPal.text
                        visible: false
                    }

                    QGCLabel { text: qsTr("Peers:"); color: qgcPal.text }
                    QGCLabel {
                        text: _connected && rajantManager ? rajantManager.peerCount.toString() : qsTr("N/A")
                        color: qgcPal.text
                    }
                    QGCLabel { text: qsTr("Main Link:"); color: qgcPal.text }
                    QGCLabel { text: qsTr("UDP"); color: qgcPal.text }
                }
            }
        }
    }

    // Toolbar icon + label
    Row {
        id:                     signalRow
        spacing:                ScreenTools.defaultFontPixelWidth
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        SignalStrength {
            anchors.verticalCenter: parent.verticalCenter
            size:                   ScreenTools.defaultFontPixelHeight * 1.6
            percent:                _connected ? getSignalStrength(_signal) : 0
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            QGCLabel {
                text:               "Rajant"
                font.pointSize:     ScreenTools.defaultFontPointSize
            }
            QGCLabel {
                text:               _connected ? _signal + " dBm" : "N/A"
                font.pointSize:     ScreenTools.defaultFontPointSize
            }
        }
    }

    MouseArea {
        anchors.fill:           parent
        anchors.margins:        -ScreenTools.defaultFontPixelHeight * 0.66
        onClicked: {
            if (_connected) {
                mainWindow.showIndicatorPopup(_root, rajantRssiInfo)
            }
        }
    }
}
