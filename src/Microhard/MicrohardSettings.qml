/****************************************************************************
 *
 *   (c) 2019 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


import QtGraphicalEffects       1.0
import QtMultimedia             5.5
import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Controls.Styles  1.4
import QtQuick.Dialogs          1.2
import QtQuick.Layouts          1.2
import QtLocation               5.3
import QtPositioning            5.3

import QGroundControl                       1.0
import QGroundControl.Controllers           1.0
import QGroundControl.Controls              1.0
import QGroundControl.FactControls          1.0
import QGroundControl.FactSystem            1.0
import QGroundControl.Palette               1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.SettingsManager       1.0

Rectangle {
    id:                 _root
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    property real _labelWidth:                  ScreenTools.defaultFontPixelWidth * 26
    property real _valueWidth:                  ScreenTools.defaultFontPixelWidth * 20
    property real _panelWidth:                  _root.width * _internalWidthRatio
    property Fact _microhardEnabledFact:        QGroundControl.settingsManager.appSettings.enableMicrohard
    //-- Auto-detect: the page populates whenever Microhard stats are arriving, no
    //   manual "Enable Microhard" toggle required.
    property bool _microhardEnabled:            QGroundControl.microhardManager.statsConnected
    property bool _showAdvancedTcpSettings:     false
    property bool _showRawStats:                false

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
                //-- Placeholder when no Microhard link is detected
                Item {
                    width:                      _panelWidth
                    height:                     noLinkLabel.height + (ScreenTools.defaultFontPixelHeight * 2)
                    visible:                    !_microhardEnabled
                    anchors.horizontalCenter:   parent.horizontalCenter
                    QGCLabel {
                        id:                     noLinkLabel
                        anchors.centerIn:       parent
                        text:                   qsTr("No Microhard link detected")
                        color:                  qgcPal.text
                    }
                }
                //-----------------------------------------------------------------
                //-- Connection Status
                Item {
                    width:                      _panelWidth
                    height:                     statusLabel.height
                    anchors.margins:            ScreenTools.defaultFontPixelWidth
                    anchors.horizontalCenter:   parent.horizontalCenter
                    visible:                    _microhardEnabled
                    QGCLabel {
                        id:                     statusLabel
                        text:                   qsTr("Connection Status")
                        font.family:            ScreenTools.demiboldFontFamily
                    }
                }
                Rectangle {
                    height:                     statusCol.height + (ScreenTools.defaultFontPixelHeight * 2)
                    width:                      _panelWidth
                    color:                      qgcPal.windowShade
                    visible:                    _microhardEnabled
                    anchors.margins:            ScreenTools.defaultFontPixelWidth
                    anchors.horizontalCenter:   parent.horizontalCenter
                    Column {
                        id:                     statusCol
                        spacing:                ScreenTools.defaultFontPixelHeight
                        width:                  parent.width - (ScreenTools.defaultFontPixelWidth * 8)
                        anchors.centerIn:       parent
                        QGCLabel {
                            text:               qsTr("Connection")
                            font.family:        ScreenTools.demiboldFontFamily
                        }
                        GridLayout {
                            width:              parent.width
                            columnSpacing:      ScreenTools.defaultFontPixelWidth * 2
                            rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.5
                            columns:            2
                            QGCLabel {
                                text:           qsTr("Ground Unit:")
                                Layout.minimumWidth: _labelWidth
                            }
                            QGCLabel {
                                text:           QGroundControl.microhardManager.statsConnected ? qsTr("Connected") : qsTr("Not Connected")
                                color:          QGroundControl.microhardManager.statsConnected ? qgcPal.colorGreen : qgcPal.colorRed
                                Layout.minimumWidth: _valueWidth
                            }
                            QGCLabel {
                                text:           qsTr("Air Unit:")
                            }
                            QGCLabel {
                                text:           QGroundControl.microhardManager.statsConnected ? qsTr("Connected") : qsTr("Not Connected")
                                color:          QGroundControl.microhardManager.statsConnected ? qgcPal.colorGreen : qgcPal.colorRed
                            }
                        }

                        Rectangle {
                            width:              parent.width
                            height:             1
                            color:              qgcPal.text
                            opacity:            0.25
                        }

                        QGCLabel {
                            text:               qsTr("Radio Metrics")
                            font.family:        ScreenTools.demiboldFontFamily
                        }
                        GridLayout {
                            width:              parent.width
                            columnSpacing:      ScreenTools.defaultFontPixelWidth * 2
                            rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.5
                            columns:            2
                            QGCLabel {
                                text:           qsTr("Ground RSSI:")
                                Layout.minimumWidth: _labelWidth
                            }
                            QGCLabel {
                                text:           QGroundControl.microhardManager.groundRSSI !== "--" ? QGroundControl.microhardManager.groundRSSI + " dBm" : qsTr("N/A")
                                Layout.minimumWidth: _valueWidth
                            }
                            QGCLabel {
                                text:           qsTr("Sky RSSI:")
                            }
                            QGCLabel {
                                text:           QGroundControl.microhardManager.skyRSSI !== "--" ? QGroundControl.microhardManager.skyRSSI + " dBm" : qsTr("N/A")
                            }
                            QGCLabel {
                                text:           qsTr("SNR:")
                            }
                            QGCLabel {
                                text:           QGroundControl.microhardManager.snr !== "--" ? QGroundControl.microhardManager.snr + " dB" : qsTr("N/A")
                            }
                            QGCLabel {
                                text:           qsTr("Frequency:")
                            }
                            QGCLabel {
                                text:           QGroundControl.microhardManager.frequency !== "--" ? QGroundControl.microhardManager.frequency : qsTr("N/A")
                            }
                            QGCLabel {
                                text:           qsTr("TX/RX Throughput:")
                            }
                            QGCLabel {
                                text:           (QGroundControl.microhardManager.txThroughput !== "--" || QGroundControl.microhardManager.rxThroughput !== "--")
                                                    ? QGroundControl.microhardManager.txThroughput + " / " + QGroundControl.microhardManager.rxThroughput
                                                    : qsTr("N/A")
                            }
                            QGCLabel {
                                text:           qsTr("TX/RX Bytes:")
                            }
                            QGCLabel {
                                text:           (QGroundControl.microhardManager.txBytes !== "--" || QGroundControl.microhardManager.rxBytes !== "--")
                                                    ? QGroundControl.microhardManager.txBytes + " / " + QGroundControl.microhardManager.rxBytes
                                                    : qsTr("N/A")
                            }
                        }

                        Rectangle {
                            width:              parent.width
                            height:             1
                            color:              qgcPal.text
                            opacity:            0.25
                        }

                        QGCLabel {
                            text:               qsTr("Diagnostics")
                            font.family:        ScreenTools.demiboldFontFamily
                        }
                        GridLayout {
                            width:              parent.width
                            columnSpacing:      ScreenTools.defaultFontPixelWidth * 2
                            rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.5
                            columns:            2
                            QGCLabel {
                                text:           qsTr("Master Packets:")
                                Layout.minimumWidth: _labelWidth
                            }
                            QGCLabel {
                                text:           QGroundControl.microhardManager.masterStatsPacketCount
                                Layout.minimumWidth: _valueWidth
                            }
                            QGCLabel {
                                text:           qsTr("Slave Packets:")
                            }
                            QGCLabel {
                                text:           QGroundControl.microhardManager.slaveStatsPacketCount
                            }
                            QGCLabel {
                                text:           qsTr("Last Source:")
                            }
                            QGCLabel {
                                text:           QGroundControl.microhardManager.statsLastSource
                            }
                            QGCLabel {
                                text:           qsTr("Sources:")
                                Layout.alignment: Qt.AlignTop
                            }
                            QGCLabel {
                                text:           QGroundControl.microhardManager.statsSources
                                Layout.fillWidth: true
                                wrapMode:       Text.WordWrap
                            }
                        }

                        QGCButton {
                            text:               _showRawStats ? qsTr("Hide Raw Stats") : qsTr("Show Raw Stats")
                            visible:            QGroundControl.microhardManager.statsRawText !== ""
                            width:              ScreenTools.defaultFontPixelWidth * 18
                            onClicked:          _showRawStats = !_showRawStats
                        }

                        QGCLabel {
                            text:               QGroundControl.microhardManager.statsRawText
                            visible:            _showRawStats && QGroundControl.microhardManager.statsRawText !== ""
                            wrapMode:           Text.WordWrap
                            width:              parent.width
                        }
                    }
                }
                //-----------------------------------------------------------------
                //-- Legacy TCP Settings
                Item {
                    width:                      _panelWidth
                    height:                     ipSettingsLabel.height
                    anchors.margins:            ScreenTools.defaultFontPixelWidth
                    anchors.horizontalCenter:   parent.horizontalCenter
                    visible:                    _microhardEnabled && _showAdvancedTcpSettings
                    QGCLabel {
                        id:                     ipSettingsLabel
                        text:                   qsTr("Legacy TCP Settings")
                        font.family:            ScreenTools.demiboldFontFamily
                    }
                }
                Rectangle {
                    height:                     ipSettingsCol.height + (ScreenTools.defaultFontPixelHeight * 2)
                    width:                      _panelWidth
                    color:                      qgcPal.windowShade
                    visible:                    _microhardEnabled && _showAdvancedTcpSettings
                    anchors.margins:            ScreenTools.defaultFontPixelWidth
                    anchors.horizontalCenter:   parent.horizontalCenter
                    Column {
                        id:                     ipSettingsCol
                        spacing:                ScreenTools.defaultFontPixelHeight * 0.5
                        width:                  parent.width
                        anchors.centerIn:       parent
                        GridLayout {
                            anchors.margins:    ScreenTools.defaultFontPixelHeight
                            columnSpacing:      ScreenTools.defaultFontPixelWidth * 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            columns: 2
                            QGCLabel {
                                text:           qsTr("Local IP Address:")
                                Layout.minimumWidth: _labelWidth
                            }
                            QGCTextField {
                                id:             localIP
                                text:           QGroundControl.microhardManager.localIPAddr
                                enabled:        true
                                inputMethodHints:    Qt.ImhFormattedNumbersOnly
                                Layout.minimumWidth: _valueWidth
                            }
                            QGCLabel {
                                text:           qsTr("Remote IP Address:")
                            }
                            QGCTextField {
                                id:             remoteIP
                                text:           QGroundControl.microhardManager.remoteIPAddr
                                enabled:        true
                                inputMethodHints:    Qt.ImhFormattedNumbersOnly
                                Layout.minimumWidth: _valueWidth
                            }
                            QGCLabel {
                                text:           qsTr("Network Mask:")
                            }
                            QGCTextField {
                                id:             netMask
                                text:           QGroundControl.microhardManager.netMask
                                enabled:        true
                                inputMethodHints:    Qt.ImhFormattedNumbersOnly
                                Layout.minimumWidth: _valueWidth
                            }
                            QGCLabel {
                                text:           qsTr("Configuration User Name:")
                            }
                            QGCTextField {
                                id:             configUserName
                                text:           QGroundControl.microhardManager.configUserName
                                enabled:        true
                                Layout.minimumWidth: _valueWidth
                            }
                            QGCLabel {
                                text:           qsTr("Configuration Password:")
                            }
                            QGCTextField {
                                id:             configPassword
                                text:           QGroundControl.microhardManager.configPassword
                                enabled:        true
                                echoMode:       TextInput.Password
                                Layout.minimumWidth: _valueWidth
                            }
                            QGCLabel {
                                text:           qsTr("Encryption key:")
                            }
                            QGCTextField {
                                id:             encryptionKey
                                text:           QGroundControl.microhardManager.encryptionKey
                                enabled:        true
                                echoMode:       TextInput.Password
                                Layout.minimumWidth: _valueWidth
                            }
                        }
                        Item {
                            width:  1
                            height: ScreenTools.defaultFontPixelHeight
                        }
                        QGCButton {
                            function validateIPaddress(ipaddress) {
                                if (/^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/.test(ipaddress))
                                    return true
                                return false
                            }
                            function testEnabled() {
                                if(localIP.text          === QGroundControl.microhardManager.localIPAddr &&
                                    remoteIP.text        === QGroundControl.microhardManager.remoteIPAddr &&
                                    netMask.text         === QGroundControl.microhardManager.netMask &&
                                    configUserName.text  === QGroundControl.microhardManager.configUserName &&
                                    configPassword.text  === QGroundControl.microhardManager.configPassword &&
                                    encryptionKey.text   === QGroundControl.microhardManager.encryptionKey)
                                    return false
                                if(!validateIPaddress(localIP.text))  return false
                                if(!validateIPaddress(remoteIP.text)) return false
                                if(!validateIPaddress(netMask.text))  return false
                                return true
                            }
                            enabled:            testEnabled()
                            text:               qsTr("Apply")
                            anchors.horizontalCenter:   parent.horizontalCenter
                            onClicked: {
                                QGroundControl.microhardManager.setIPSettings(localIP.text, remoteIP.text, netMask.text, configUserName.text, configPassword.text, encryptionKey.text)
                            }

                        }
                    }
                }
            }
        }
    }
