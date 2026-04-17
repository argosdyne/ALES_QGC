import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Controls.Styles  1.4
import QtQuick.Layouts          1.2

import QGroundControl                       1.0
import QGroundControl.Controls              1.0
import QGroundControl.Palette               1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.SettingsManager       1.0

Rectangle {
    id:                 _root
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    property real _panelWidth:                  _root.width * _internalWidthRatio
    property real _labelWidth:                  _panelWidth * 0.4
    property real _valueWidth:                  _panelWidth * 0.4
    property var rajantManager:                 QGroundControl.corePlugin.rajantManager
    property var rajantAirManager:              QGroundControl.corePlugin.rajantAirManager
    property bool _connected:                   rajantManager ? rajantManager.connected && rajantManager.authenticated : false
    property bool _airConnected:                rajantAirManager ? rajantAirManager.connected && rajantAirManager.authenticated : false

    readonly property real _internalWidthRatio:          0.8

    QGCFlickable {
        clip:               true
        anchors.fill:       parent
        contentHeight:      settingsColumn.height
        contentWidth:       settingsColumn.width
        Column {
            id:                 settingsColumn
            width:              _root.width
            spacing:            ScreenTools.defaultFontPixelHeight * 0.5
            anchors.margins:    ScreenTools.defaultFontPixelWidth
            //-----------------------------------------------------------------
            //-- Link Status
            Item {
                width:                      _panelWidth
                height:                     statusLabel.height
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                QGCLabel {
                    id:                     statusLabel
                    text:                   qsTr("Link Status")
                    font.family:            ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:                     statusCol.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:                      _panelWidth
                color:                      qgcPal.windowShade
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                Column {
                    id:                     statusCol
                    spacing:                ScreenTools.defaultFontPixelHeight * 0.5
                    width:                  parent.width
                    anchors.centerIn:       parent
                    GridLayout {
                        anchors.margins:    ScreenTools.defaultFontPixelHeight
                        columnSpacing:      ScreenTools.defaultFontPixelWidth * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        columns: 2
                        QGCLabel {
                            text:           qsTr("Status:")
                            Layout.preferredWidth: _labelWidth
                        }
                        QGCLabel {
                            text:           _connected ? qsTr("Connected") : qsTr("Not Connected")
                            color:          _connected ? qgcPal.colorGreen : qgcPal.colorRed
                            Layout.preferredWidth: _labelWidth
                        }
                        QGCLabel {
                            text:           qsTr("Node Address:")
                            Layout.minimumWidth: _labelWidth
                            visible:        false
                        }
                        QGCLabel {
                            text:           rajantManager ? rajantManager.nodeAddress : qsTr("N/A")
                            Layout.minimumWidth: _valueWidth
                            visible:        false
                        }
                        QGCLabel {
                            text:           qsTr("Radio:")
                            visible:        false
                        }
                        QGCLabel {
                            text:           rajantManager ? rajantManager.radioName + " (ch " + rajantManager.channel + ")" : ""
                            visible:        false
                        }
                        QGCLabel {
                            text:           qsTr("Signal:")
                            visible:        _connected
                        }
                        QGCLabel {
                            text:           rajantManager ? rajantManager.signal + " / " + rajantManager.noise + " dBm" : ""
                            visible:        _connected
                        }
                        QGCLabel {
                            text:           qsTr("Noise:")
                            visible:        _connected
                        }
                        QGCLabel {
                            text:           rajantManager ? rajantManager.noise + " dBm" : ""
                            visible:        _connected
                        }

                        QGCLabel {
                            text:           qsTr("Sky Signal:")
                            visible:        _airConnected
                        }
                        QGCLabel {
                            text:           rajantAirManager ? rajantAirManager.signal + " / " + rajantAirManager.noise + " dBm" : ""
                            visible:        _airConnected
                        }
                        QGCLabel {
                            text:           qsTr("Sky Noise:")
                            visible:        _airConnected
                        }
                        QGCLabel {
                            text:           rajantAirManager ? rajantAirManager.noise + " dBm" : ""
                            visible:        _airConnected
                        }

                        QGCLabel {
                            text:           qsTr("SNR:")
                            visible:        _connected
                        }
                        QGCLabel {
                            text:           rajantManager ? rajantManager.snr + " dB" : ""
                            visible:        _connected
                        }
                        QGCLabel {
                            text:           qsTr("Link Rate:")
                            visible:        false
                        }
                        QGCLabel {
                            text:           rajantManager ? rajantManager.linkRate + " Mbps" : ""
                            visible:        false
                        }
                        QGCLabel {
                            text:           qsTr("Tx Power:")
                            visible:        _connected
                        }
                        QGCLabel {
                            text:           rajantManager ? rajantManager.txPower + " dBm" : ""
                            visible:        _connected
                        }
                        QGCLabel {
                            text:           qsTr("Peers:")
                            visible:        _connected
                        }
                        QGCLabel {
                            text:           rajantManager ? rajantManager.peerCount.toString() : ""
                            visible:        _connected
                        }
                        QGCLabel {
                            text:           qsTr("Version:")
                        }
                        QGCLabel {
                            text:           qsTr("Rajant BCAPI 11.29")
                        }
                    }
                }
            }
        }
    }
}
