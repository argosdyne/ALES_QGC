import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Controls.Styles  1.4
import QtQuick.Layouts          1.2

import QGroundControl                       1.0
import QGroundControl.Controllers           1.0
import QGroundControl.Controls              1.0
import QGroundControl.FactControls          1.0
import QGroundControl.FactSystem            1.0
import QGroundControl.Palette               1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.SettingsManager       1.0

import CustomQmlInterface                   1.0

Rectangle {
    id:                 _root
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    property real _labelWidth:                  ScreenTools.defaultFontPixelWidth * 26
    property real _valueWidth:                  ScreenTools.defaultFontPixelWidth * 20
    property real _panelWidth:                  _root.width * _internalWidthRatio
    property var arManager: CustomQmlInterface.arManager

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
            QGCLabel {
                text:           qsTr("Reboot ground/air unit for changes to take effect.")
                color:          qgcPal.colorOrange
                visible:        false
                font.family:    ScreenTools.demiboldFontFamily
                anchors.horizontalCenter:   parent.horizontalCenter
            }
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
                            Layout.minimumWidth: _labelWidth
                        }
                        QGCLabel {
                            text:           arManager.mounted ? qsTr("Connected") : qsTr("Not Connected")
                            color:          arManager.mounted ? qgcPal.colorGreen : qgcPal.colorRed
                            Layout.minimumWidth: _valueWidth
                        }
                        QGCLabel {
                            text:           qsTr("Bind Status:")
                            Layout.minimumWidth: _labelWidth
                        }
                        QGCLabel {
                            text:           arManager.connected ? qsTr("Binded") : qsTr("Not Binded")
                            color:          arManager.connected ? qgcPal.colorGreen : qgcPal.colorRed
                            Layout.minimumWidth: _valueWidth
                        }
                        QGCLabel {
                            text:           qsTr("Frequency Band:")
                        }
                        QGCLabel {
                            text:           arManager.is24G ? "2.4G" : "5.8G"
                        }
                        QGCLabel {
                            text:           qsTr("Frequency:")
                        }
                        QGCLabel {
                            text:           arManager.txFrequency / 1000 + " , " + arManager.rxFrequency / 1000 + " , " + arManager.brFrequency / 1000
                        }
                        QGCLabel {
                            text:           qsTr("Bandwidth/Flow:")
                        }
                        QGCLabel {
                            text:           arManager.upRate / 1000 + " / " + arManager.flow / 1000 + " Kb"
                        }
						QGCLabel {
                            text:           qsTr("Ground/Air MCS:")
                        }
                        QGCLabel {
                            text:           arManager.mcs + " / " + arManager.skyMcs
                        }
                        QGCLabel {
                            text:           qsTr("Ground/Air/BR SNR:")
                        }
                        QGCLabel {
                            text:           arManager.snr + " / " + arManager.skySnr + " / " + arManager.brSnr
                        }
						QGCLabel {
                            text:           qsTr("Ground RSSI A/B:")
                        }
                        QGCLabel {
                            text:           arManager.rssiA * -1 + " / " + arManager.rssiB * -1 + " dB"
                        }
                        QGCLabel {
                            text:           qsTr("Air RSSI A/B:")
                        }
                        QGCLabel {
                            text:           arManager.skyRssiA * -1 + " / " + arManager.skyRssiB * -1 + " dB"
                        }
                        QGCLabel {
                            text:           qsTr("BR RSSI A/B:")
                        }
                        QGCLabel {
                            text:           arManager.brRssiA * -1 + " / " + arManager.brRssiB * -1 + " dB"
                        }
                        QGCLabel {
                            text:           qsTr("Temperature: G/A")
                        }
                        QGCLabel {
                            text:           arManager.temperature + " / " + arManager.skyTemperature + " degC"
                        }
                        QGCLabel {
                            text:           qsTr("Version:")
                        }
                        QGCLabel {
                            text:           arManager.version
                        }
                    }
                }
            }
            Connections {
                target: arManager
                function onAckFromDevice(cmd) {
                    console.info("onAckFromDevice", cmd)
                    if(cmd == 2) {
                        tiggerBindButton.checked = false
                    } else if(cmd == 4) {
                        enabled24GButton.checked = false
                    } else if(cmd == 5) {
                        enabled58GButton.checked = false
                    } else if(cmd == 3) {
                        rebootButton.checked = false
                    } else if(cmd == 7) {
                        remoteEnabled24GButton.checked = false
                    } else if(cmd == 8) {
                        remoteEnabled58GButton.checked = false
                    } else if(cmd == 6) {
                        remoteRebootButton.checked = false
                    }
                }
            }
			//-----------------------------------------------------------------
            //-- Ground Settings
            Item {
                width:                      _panelWidth
                height:                     groundSettingsLabel.height
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                QGCLabel {
                    id:                     groundSettingsLabel
                    text:                   qsTr("Ground Settings")
                    font.family:            ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:                     groundSettingsGrid.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:                      _panelWidth
                color:                      qgcPal.windowShade
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                GridLayout {
                    id:                 groundSettingsGrid
                    anchors.centerIn:   parent
                    columnSpacing:      ScreenTools.defaultFontPixelWidth * 2
                    rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.5
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 3         
                    QGCButton {
                        id: tiggerBindButton
                        Layout.columnSpan: 3
                        Layout.fillWidth: true
                        checkable: true
                        hoverEnabled: false
                        enabled: arManager.mounted
                        text: qsTr("Bind")
                        onClicked: {
                            arManager.pair()
                        }
                    }
                    QGCButton {
                        id: enabled24GButton
                        Layout.preferredWidth: _valueWidth
                        text: qsTr("Enable 2.4G")
                        checkable: true
                        hoverEnabled: false
                        enabled: arManager.mounted
                        onClicked: {
                            arManager.enable24G()
                        }
                    }
                    QGCButton {
                        id: enabled58GButton
                        Layout.preferredWidth: _valueWidth
                        checkable: true
                        hoverEnabled: false
                        text: qsTr("Enable 5.8G")
                        enabled: arManager.mounted
                        onClicked: {
                            arManager.enable58G()
                        }
                    }
                    QGCButton {
                        id: rebootButton
                        Layout.preferredWidth: _valueWidth
                        text: qsTr("Reboot")
                        checkable: true
                        hoverEnabled: false
                        enabled: arManager.mounted
                        onClicked: {
                            arManager.restartDevice()
                        }
                    }
                }
            }
            //-----------------------------------------------------------------
            //-- Air Settings
            Item {
                width:                      _panelWidth
                height:                     airSettingsLabel.height
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                QGCLabel {
                    id:                     airSettingsLabel
                    text:                   qsTr("Air Settings")
                    font.family:            ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:                     airSettingsGrid.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:                      _panelWidth
                color:                      qgcPal.windowShade
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                GridLayout {
                    id:                 airSettingsGrid
                    anchors.centerIn:   parent
                    columnSpacing:      ScreenTools.defaultFontPixelWidth * 2
                    rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.5
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 3         
                    QGCButton {
                        id: remoteEnabled24GButton
                        Layout.preferredWidth: _valueWidth
                        text: qsTr("Enable 2.4G")
                        checkable: true
                        hoverEnabled: false
                        enabled: arManager.connected && arManager.mounted
                        onClicked: {
                            arManager.enableRemote24G()
                        }
                    }
                    QGCButton {
                        id: remoteEnabled58GButton
                        Layout.preferredWidth: _valueWidth
                        text: qsTr("Enable 5.8G")
                        checkable: true
                        hoverEnabled: false
                        enabled: arManager.connected && arManager.mounted
                        onClicked: {
                            arManager.enableRemote58G()
                        }
                    }
                    QGCButton {
                        id: remoteRebootButton
                        Layout.preferredWidth: _valueWidth
                        text: qsTr("Reboot")
                        checkable: true
                        hoverEnabled: false
                        enabled: arManager.connected && arManager.mounted
                        onClicked: {
                            arManager.restartRemoteDevice()
                        }
                    }
                }
            }
        }
    }
}
