import QtQuick          2.12
import QtQuick.Controls 2.5
import QtQuick.Layouts  1.2

import QGroundControl                 1.0
import QGroundControl.Controllers     1.0
import QGroundControl.Controls        1.0
import QGroundControl.FactControls    1.0
import QGroundControl.FactSystem      1.0
import QGroundControl.Palette         1.0
import QGroundControl.ScreenTools     1.0
import QGroundControl.SettingsManager 1.0
import Custom.Widgets                 1.0

Rectangle {
    id:                 _root
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    QtObject {
        id: nullM2Manager
        property bool mounted: false
        property bool connected: false
        property bool binding: false
        property bool scanning: false
        property var ssid: "Unknown"
        property var freq: 0.0
        property var rssi: 0.0
        property var linkspeed: 0.0
        property var rssiA: 0.0
        property var rssiB: 0.0
        property var cpuTemp: 0.0
        property var rfTemp: 0.0
        property var version: "Unknown"
        property var skyRssi: 0.0
        property var skyLinkspeed: 0.0
        property var skyRssiA: 0.0
        property var skyRssiB: 0.0
        property var skyCpuTemp: 0.0
        property var skyRfTemp: 0.0
        property var skyVersion: "Unknown"
        property var scanedChannels: []
        property var skyScanedChannels: []
    }

    property real _labelWidth:                  ScreenTools.defaultFontPixelWidth * 26
    property real _valueWidth:                  ScreenTools.defaultFontPixelWidth * 20
    property real _panelWidth:                  _root.width * _internalWidthRatio
    property real _panelHeight:                 ScreenTools.defaultFontPixelHeight * 8
    property var m2Manager: QGroundControl.m2Manager ? QGroundControl.m2Manager : nullM2Manager

    readonly property real _internalWidthRatio:          1

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
                            Layout.minimumWidth: _labelWidth
                        }
                        QGCLabel {
                            text:           m2Manager.mounted ? qsTr("Connected") : qsTr("Not Connected")
                            color:          m2Manager.mounted ? qgcPal.colorGreen : qgcPal.colorRed
                            Layout.minimumWidth: _valueWidth
                        }
                        QGCLabel {
                            text:           qsTr("SSID:")
                            Layout.minimumWidth: _labelWidth
                        }
                        QGCLabel {
                            text:           m2Manager.ssid
                        }
                        QGCLabel {
                            text:           qsTr("Bind Status:")
                            Layout.minimumWidth: _labelWidth
                        }
                        QGCLabel {
                            text:           m2Manager.binding ? qsTr("Binding") : (m2Manager.connected ? qsTr("Finished") : qsTr("Not Binded"))
                            color:          m2Manager.connected || m2Manager.binding ? qgcPal.colorGreen : qgcPal.colorRed
                            Layout.minimumWidth: _valueWidth
                        }
                        QGCLabel {
                            text:           qsTr("Frequency:")
                        }
                        QGCLabel {
                            text:           m2Manager.freq
                        }
                        QGCLabel {
                            text:           qsTr("RSSI:")
                        }
                        QGCLabel {
                            text:           m2Manager.rssi + " / " + m2Manager.skyRssi
                        }
                        QGCLabel {
                            text:           qsTr("LinkSpeed:")
                        }
                        QGCLabel {
                            text:           m2Manager.linkspeed + " / " + m2Manager.skyLinkspeed
                        }
                        QGCLabel {
                            text:           qsTr("RSSI A/B:")
                        }
                        QGCLabel {
                            text:           m2Manager.rssiA + " / " + m2Manager.rssiB
                        }
						QGCLabel {
                            text:           qsTr("Sky RSSI A/B:")
                        }
                        QGCLabel {
                            text:           m2Manager.skyRssiA + " / " + m2Manager.skyRssiB
                        }
                        QGCLabel {
                            text:           qsTr("CPU Temp:")
                        }
                        QGCLabel {
                            text:           m2Manager.cpuTemp + " / " + m2Manager.skyCpuTemp
                        }
                        QGCLabel {
                            text:           qsTr("RF Temp:")
                        }
                        QGCLabel {
                            text:           m2Manager.rfTemp + " / " + m2Manager.skyRfTemp
                        }
                        QGCLabel {
                            text:           qsTr("Version:")
                        }
                        QGCLabel {
                            text:           m2Manager.version + " / " + m2Manager.skyVersion
                        }
                    }
                }
            }
            Row {
                width:                      _panelWidth
                height:                     channelsLabel.height
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                spacing:                    ScreenTools.defaultFontPixelHeight
                QGCLabel {
                    id:                     channelsLabel
                    text:                   qsTr("Channel Information & Selection")
                    font.family:            ScreenTools.demiboldFontFamily
                }
                QGCButton {
                    id: scanButton
                    hoverEnabled: false
                    enabled: m2Manager.mounted
                    visible: !m2Manager.scanning
                    height: channelsLabel.height * 1.8
                    anchors.verticalCenter: parent.verticalCenter
                    _verticalPadding: 0
                    text: qsTr("Scan")
                    onClicked: {
                        m2Manager.scan()
                    }
                }
            }
            Rectangle {
                height:                     Math.max(scanGrid.height, scanRectangle.height) + (ScreenTools.defaultFontPixelHeight * 2)
                width:                      _panelWidth
                color:                      qgcPal.windowShade
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                GridLayout {
                    id: scanGrid
                    columnSpacing: ScreenTools.defaultFontPixelWidth * 0.6
                    width:                  parent.width - ScreenTools.defaultFontPixelWidth * 2
                    anchors.centerIn:       parent

                    Repeater {
                        model: m2Manager.skyScanedChannels.count > 0 ? m2Manager.skyScanedChannels : m2Manager.scanedChannels
                        QGCLabel {
                            Layout.row: 0
                            Layout.column: index
                            text: object.quality
                            font.pointSize: ScreenTools.smallFontPointSize
                            font.bold: m2Manager.freqIndex === index ? true : false
                            Layout.alignment: Qt.AlignCenter
                            opacity: m2Manager.skyScanedChannels.count > 0 ? 1 : 0.3
                            width: ScreenTools.defaultFontPixelWidth
                        }
                    }

                    Repeater {
                        model: m2Manager.skyScanedChannels.count > 0 ? m2Manager.skyScanedChannels : m2Manager.scanedChannels
                        Rectangle {
                            radius: 4
                            Layout.row: 1
                            Layout.column: index
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignBottom
                            Layout.preferredHeight: _panelHeight * (object.quality / 100)
                            opacity: m2Manager.skyScanedChannels.count > 0 ? 1 : 0.3
                            color: object.color
                            border.color: qgcPal.text
                            border.width: m2Manager.freqIndex === index ? 3 : 0
                            MouseArea {
                                anchors.fill: parent
                                enabled: m2Manager.freqIndex !== index
                                onClicked: {
                                    m2Manager.setChannel(object.id)
                                }
                            }
                        }
                    }

                    Repeater {
                        model: m2Manager.scanedChannels
                        QGCLabel {
                            Layout.row: 2
                            Layout.column: index
                            text: object.freq
                            font.pointSize: ScreenTools.smallFontPointSize
                            font.bold: m2Manager.freqIndex === index ? true : false
                            Layout.alignment: Qt.AlignCenter
                            width: ScreenTools.defaultFontPixelWidth
                        }
                    }

                    Repeater {
                        model: m2Manager.scanedChannels
                        Rectangle {
                            radius: 4
                            Layout.row: 3
                            Layout.column: index
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredHeight: _panelHeight * (object.quality / 100)
                            color: object.color
                            border.color: qgcPal.text
                            border.width: m2Manager.freqIndex === index ? 3 : 0
                            MouseArea {
                                anchors.fill: parent
                                enabled: m2Manager.freqIndex !== index
                                onClicked: {
                                    m2Manager.setChannel(object.id)
                                }
                            }
                        }
                    }

                    Repeater {
                        model: m2Manager.scanedChannels
                        QGCLabel {
                            Layout.row: 4
                            Layout.column: index
                            text: object.quality
                            font.pointSize: ScreenTools.smallFontPointSize
                            Layout.alignment: Qt.AlignCenter
                            font.bold: m2Manager.freqIndex === index ? true : false
                            width: ScreenTools.defaultFontPixelWidth
                        }
                    }
                }
                Item {
                    id: scanRectangle
                    anchors.margins: ScreenTools.defaultFontPixelWidth
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.left: parent.left
                    height: _panelHeight * 2 + ScreenTools.defaultFontPixelHeight * 3
                    CustomBusyIndicator {
                        visible: m2Manager.scanning
                        width: ScreenTools.defaultFontPixelHeight * 3
                        height: ScreenTools.defaultFontPixelHeight * 3
                        anchors.centerIn: parent
                        running: visible
                        firstColor: qgcPal.text
                        secondColor: qgcPal.windowShade
                        pointColor: qgcPal.windowShade
                    }
                }
            }
        }
    }
}
