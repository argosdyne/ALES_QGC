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
    property var  rajantManager:                QGroundControl.corePlugin.rajantManager
    // Treat a dead mesh link the same as disconnected — UI goes to N/A, not stale values
    property bool _connected:                   rajantManager ? rajantManager.connected && rajantManager.authenticated && rajantManager.linkLive : false
    property int  _signal:                      rajantManager ? rajantManager.signal    : 0
    property int  _noise:                       rajantManager ? rajantManager.noise     : 0
    property int  _snr:                         rajantManager ? rajantManager.snr       : 0
    property int  _skySignal:                   rajantManager ? rajantManager.skySignal : 0
    property int  _skySnr:                      rajantManager ? rajantManager.skySnr    : 0
    property bool _pairingBusy:                 rajantManager ? rajantManager.pairingBusy : false

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
                            text:           qsTr("Node adress:")
                            Layout.minimumWidth: _labelWidth
                        }
                        QGCLabel {
                            text:           _connected && rajantManager && rajantManager.linkLocalAddress.length > 0
                                              ?  rajantManager.linkLocalAddress
                                              : qsTr("N/A")
                            Layout.minimumWidth: _valueWidth
                        }

                         QGCLabel {
                            text:           qsTr("Serial Number:")
                        }
                        QGCLabel {
                            text:           rajantManager && rajantManager.serialNumber.length > 0
                                              ? rajantManager.serialNumber
                                              : qsTr("N/A")
                        }
                        QGCLabel {
                            text:           qsTr("Current Network Name:")
                        }
                        QGCLabel {
                            text:           rajantManager && rajantManager.networkName.length > 0
                                              ? rajantManager.networkName
                                              : qsTr("N/A")
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
                            // visible:        _connected && rajantManager && rajantManager.nodeName.length > 0
                            visible:        false
                        }
                        QGCLabel {
                            text:           rajantManager ? rajantManager.nodeName : ""
                            // visible:        _connected && rajantManager && rajantManager.nodeName.length > 0
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
                width:                      _panelWidth
                height:                     pairingCol.height + (ScreenTools.defaultFontPixelHeight * 2)
                color:                      qgcPal.windowShade
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter

                Column {
                    id:                     pairingCol
                    width:                  parent.width
                    spacing:                ScreenTools.defaultFontPixelHeight * 0.5
                    anchors.centerIn:       parent

                    GridLayout {
                        anchors.margins:    ScreenTools.defaultFontPixelHeight
                        columnSpacing:      ScreenTools.defaultFontPixelWidth * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        columns:            2

                        QGCLabel {
                            text:           qsTr("Set Network Name:")
                            Layout.preferredWidth: _labelWidth
                        }

                        QGCTextField {
                            id:                     networkNameInput
                            Layout.preferredWidth:  _valueWidth
                            Layout.fillWidth:       true
                            placeholderText:        qsTr("Drone-XXXXXX")
                            enabled:                !_pairingBusy
                        }

                        Item {
                            Layout.preferredWidth: _labelWidth
                            Layout.preferredHeight: actionRow.height
                        }

                        Row {
                            id:                     actionRow
                            spacing:                ScreenTools.defaultFontPixelWidth
                            Layout.preferredWidth:  _valueWidth
                            Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.8
                            Layout.alignment:       Qt.AlignHCenter
                            QGCButton {
                                text:               qsTr("Connect")
                                width:              (actionRow.width - actionRow.spacing) / 2
                                enabled:            rajantManager && !_pairingBusy
                                                    && networkNameInput.text.trim().length > 0
                                onClicked:          rajantManager.pairToDrone(networkNameInput.text)
                            }
                            QGCButton {
                                text:               qsTr("Disconnect")
                                width:              (actionRow.width - actionRow.spacing) / 2
                                enabled:            rajantManager && _connected && !_pairingBusy
                                onClicked:          rajantManager.disconnectFromDroneMesh()
                            }
                        }

                        Item {
                            Layout.preferredWidth: _labelWidth
                            visible:        _pairingBusy
                        }
                        QGCLabel {
                            text:           _pairingBusy ? qsTr("Applying settings and waiting reboot...") : ""
                            visible:        _pairingBusy
                            Layout.preferredWidth: _valueWidth
                        }
                    }
                }
            }
        }
    }
}
