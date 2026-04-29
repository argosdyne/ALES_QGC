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
    property var  corePlugin:                   QGroundControl.corePlugin
    property var  rajantManager:                QGroundControl.corePlugin.rajantManager
    // Treat a dead mesh link the same as disconnected — UI goes to N/A, not stale values
    property bool _connected:                   rajantManager ? rajantManager.connected && rajantManager.authenticated && rajantManager.linkLive : false
    property int  _signal:                      rajantManager ? rajantManager.signal    : 0
    property int  _noise:                       rajantManager ? rajantManager.noise     : 0
    property int  _snr:                         rajantManager ? rajantManager.snr       : 0
    property int  _skySignal:                   rajantManager ? rajantManager.skySignal : 0
    property int  _skySnr:                      rajantManager ? rajantManager.skySnr    : 0
    property string _networkInput:              ""

    readonly property real _internalWidthRatio:          0.8

    Component.onCompleted: {
        if (corePlugin) {
            corePlugin.rajantProbeStatus()
        }
    }

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
                            text:           qsTr("IPv6 Link-Local:")
                            Layout.minimumWidth: _labelWidth
                        }
                        QGCLabel {
                            text:           corePlugin && corePlugin.rajantNodeAddress.length > 0
                                              ? corePlugin.rajantNodeAddress : qsTr("N/A")
                            Layout.minimumWidth: _valueWidth
                        }
                        QGCLabel {
                            text:           qsTr("Serial Number:")
                        }
                        QGCLabel {
                            text:           corePlugin && corePlugin.rajantNodeSerial.length > 0
                                              ? corePlugin.rajantNodeSerial : qsTr("N/A")
                        }
                        QGCLabel {
                            text:           qsTr("Current Network Name:")
                        }
                        QGCLabel {
                            text:           corePlugin && corePlugin.rajantCurrentNetworkName.length > 0
                                              ? corePlugin.rajantCurrentNetworkName : qsTr("N/A")
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
                            text:           qsTr("RSSI:")
                            visible:        _connected
                        }
                        QGCLabel {
                            text:           _connected
                                              ? _signal + " dBm / " + _snr + " dB"
                                              : ""
                            visible:        _connected
                        }
                        QGCLabel {
                            text:           qsTr("Sky RSSI:")
                            visible:        _connected
                        }
                        QGCLabel {
                            text:           _connected && _skySnr > 0
                                              ? _skySignal + " dBm / " + _skySnr + " dB"
                                              : qsTr("N/A")
                            visible:        _connected
                        }
                        QGCLabel {
                            text:           qsTr("Noise Floor:")
                            visible:        _connected
                        }
                        QGCLabel {
                            text:           _connected ? _noise + " dBm" : ""
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
                            text:           qsTr("Hostname:")
                            visible:        false
                        }
                        QGCLabel {
                            text:           rajantManager ? rajantManager.nodeName : ""
                            visible:        false
                        }
                        QGCLabel {
                            text:           qsTr("Firmware:")
                            visible:        _connected && rajantManager && rajantManager.firmwareVersion.length > 0
                        }
                        QGCLabel {
                            text:           rajantManager ? rajantManager.firmwareVersion : ""
                            visible:        _connected && rajantManager && rajantManager.firmwareVersion.length > 0
                        }
                        QGCLabel {
                            text:           ""
                        }
                        QGCButton {
                            text:           qsTr("Refresh")
                            enabled:        corePlugin && !corePlugin.rajantPairingBusy
                            onClicked:      corePlugin.rajantProbeStatus()
                        }
                    }
                }
            }
            //-----------------------------------------------------------------
            //-- Pairing Device
            Item {
                width:                      _panelWidth
                height:                     pairingLabel.height
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                QGCLabel {
                    id:                     pairingLabel
                    text:                   qsTr("Pairing Device")
                    font.family:            ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:                     pairingCol.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:                      _panelWidth
                color:                      qgcPal.windowShade
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                Column {
                    id:                     pairingCol
                    spacing:                ScreenTools.defaultFontPixelHeight * 0.8
                    width:                  parent.width
                    anchors.centerIn:       parent

                    QGCLabel {
                        text:               qsTr("Set Network Name (Drone-XXXXXX or XXXXXX)")
                        width:              parent.width - (ScreenTools.defaultFontPixelWidth * 4)
                        anchors.horizontalCenter: parent.horizontalCenter
                        wrapMode:           Text.WordWrap
                    }

                    QGCTextField {
                        id:                 networkNameField
                        width:              parent.width - (ScreenTools.defaultFontPixelWidth * 4)
                        anchors.horizontalCenter: parent.horizontalCenter
                        placeholderText:    qsTr("Example: Drone-AAAAAA or AAAAAA")
                    }

                    Row {
                        spacing:            ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        QGCButton {
                            text:           qsTr("Connect")
                            enabled:        corePlugin && !corePlugin.rajantPairingBusy
                            onClicked:      corePlugin.rajantConnectDevice(networkNameField.text)
                        }
                        QGCButton {
                            text:           qsTr("Disconnect")
                            enabled:        corePlugin && !corePlugin.rajantPairingBusy
                            onClicked:      corePlugin.rajantDisconnectDevice()
                        }
                    }

                    QGCLabel {
                        text:               corePlugin ? corePlugin.rajantPairingStatus : ""
                        visible:            text.length > 0
                        width:              parent.width - (ScreenTools.defaultFontPixelWidth * 4)
                        anchors.horizontalCenter: parent.horizontalCenter
                        wrapMode:           Text.WordWrap
                    }
                }
            }
            //-----------------------------------------------------------------
            //-- Power Control
            Item {
                width:                      _panelWidth
                height:                     powerLabel.height
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                QGCLabel {
                    id:                     powerLabel
                    text:                   qsTr("Module Power")
                    font.family:            ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:                     powerCol.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:                      _panelWidth
                color:                      qgcPal.windowShade
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                Column {
                    id:                     powerCol
                    spacing:                ScreenTools.defaultFontPixelHeight * 0.8
                    width:                  parent.width
                    anchors.centerIn:       parent

                    QGCLabel {
                        text:               corePlugin && corePlugin.rajantPowerSupported
                                              ? qsTr("Control Rajant power via gpio442.")
                                              : qsTr("GPIO power control is available on Linux/Android only.")
                        width:              parent.width - (ScreenTools.defaultFontPixelWidth * 4)
                        anchors.horizontalCenter: parent.horizontalCenter
                        wrapMode:           Text.WordWrap
                    }

                    Row {
                        spacing:            ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        QGCButton {
                            text:           qsTr("Power ON")
                            enabled:        corePlugin && corePlugin.rajantPowerSupported && !corePlugin.rajantPowerBusy
                            onClicked:      corePlugin.rajantPowerOn()
                        }
                        QGCButton {
                            text:           qsTr("Power OFF")
                            enabled:        corePlugin && corePlugin.rajantPowerSupported && !corePlugin.rajantPowerBusy
                            onClicked:      corePlugin.rajantPowerOff()
                        }
                    }

                    Row {
                        spacing:            ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        Rectangle {
                            width:          ScreenTools.defaultFontPixelHeight * 0.8
                            height:         width
                            radius:         width * 0.5
                            color:          corePlugin && corePlugin.rajantPowerOnState ? qgcPal.colorGreen : qgcPal.textDisabled
                            border.color:   qgcPal.text
                        }
                        QGCLabel {
                            text:           corePlugin && corePlugin.rajantPowerOnState
                                              ? qsTr("Power: ON")
                                              : qsTr("Power: OFF")
                        }
                    }

                    QGCLabel {
                        text:               corePlugin ? corePlugin.rajantPowerStatus : ""
                        visible:            text.length > 0
                        width:              parent.width - (ScreenTools.defaultFontPixelWidth * 4)
                        anchors.horizontalCenter: parent.horizontalCenter
                        wrapMode:           Text.WordWrap
                    }
                }
            }
        }
    }
}
