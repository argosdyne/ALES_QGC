import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Layouts          1.2

import QGroundControl                       1.0
import QGroundControl.Controls              1.0
import QGroundControl.FactSystem            1.0
import QGroundControl.Palette               1.0
import QGroundControl.ScreenTools           1.0

Rectangle {
    id:                 _root
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    property real _panelWidth:      _root.width * 0.84
    property real _margins:         ScreenTools.defaultFontPixelWidth
    property var  _customSettings:  QGroundControl.corePlugin.settings

    property Fact _udpEnabled:      _customSettings.networkUdpListenerEnabled
    property Fact _tcpEnabled:      _customSettings.networkTcpServerEnabled
    property Fact _videoEnabled:    _customSettings.networkVideoStreamingEnabled
    property Fact _udpPort:         _customSettings.networkUdpPort
    property Fact _tcpPort:         _customSettings.networkTcpPort
    property Fact _udpBind:         _customSettings.networkUdpBindAddress
    property Fact _tcpBind:         _customSettings.networkTcpBindAddress
    property Fact _videoUrl:        _customSettings.networkVideoUrl
    property Fact _strictValidation:_customSettings.securityStrictMavlinkValidation
    property Fact _allowlistIds:    _customSettings.securityAllowlistVehicleIds

    property int _openPortCount: (_udpEnabled.rawValue ? 1 : 0) + (_tcpEnabled.rawValue ? 1 : 0) + (_videoEnabled.rawValue ? 1 : 0)

    QGCPalette { id: qgcPal }

    function _buildAuditReport() {
        return "ALES QGC Network Services Audit Report\n"
                + "Generated: " + new Date().toISOString() + "\n\n"
                + "UDP Listener Enabled: " + _udpEnabled.rawValue + "\n"
                + "UDP Port: " + _udpPort.rawValue + "\n"
                + "UDP Bind: " + _udpBind.rawValue + "\n\n"
                + "TCP Connection Enabled: " + _tcpEnabled.rawValue + "\n"
                + "TCP Port: " + _tcpPort.rawValue + "\n"
                + "TCP Bind/Host Setting: " + _tcpBind.rawValue + "\n\n"
                + "Video Streaming Enabled: " + _videoEnabled.rawValue + "\n"
                + "Video URI: " + _videoUrl.rawValue + "\n\n"
                + "Strict MAVLink Validation: " + _strictValidation.rawValue + "\n"
                + "Allowlist Vehicle IDs: " + _allowlistIds.rawValue + "\n"
                + "Open Network Service Count: " + _openPortCount + "\n"
        }

    QGCFlickable {
        clip:           true
        anchors.fill:   parent
        contentHeight:  outerItem.height
        contentWidth:   outerItem.width

        Item {
            id:     outerItem
            width:  Math.max(_root.width, settingsColumn.width)
            height: settingsColumn.height

            ColumnLayout {
                id:                         settingsColumn
                anchors.horizontalCenter:   parent.horizontalCenter
                width:                      _panelWidth
                spacing:                    ScreenTools.defaultFontPixelHeight * 0.3

                QGCLabel {
                    text:               qsTr("Network Services & Ports")
                    font.family:        ScreenTools.demiboldFontFamily
                }

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: summarySection.height + (_margins * 4)
                    color:                  qgcPal.windowShade

                    Item {
                        id:                 summarySection
                        anchors.margins:    _margins * 2
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        height:             summaryCard.height

                        Rectangle {
                            id:             summaryCard
                            width:          parent.width
                            color:          qgcPal.window
                            border.color:   "#B5B5B5"
                            border.width:   1
                            height:         summaryColumn.height + (_margins * 4)

                            Column {
                                id:                     summaryColumn
                                anchors.left:           parent.left
                                anchors.right:          parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins:        _margins * 1.2
                                spacing:                ScreenTools.defaultFontPixelHeight * 0.35

                                QGCLabel { text: qsTr("Factory Default: ALL OFF"); font.family: ScreenTools.demiboldFontFamily }
                                QGCLabel {
                                    text: qsTr("Current Status : Secure (%1 Listening Ports)").arg(_openPortCount)
                                    color: _openPortCount === 0 ? qgcPal.colorGreen : qgcPal.colorRed
                                    font.family: ScreenTools.demiboldFontFamily
                                }
                            }
                        }
                    }
                }

                QGCLabel {
                    text:               qsTr("Service Catalog")
                    font.family:        ScreenTools.demiboldFontFamily
                }

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: catalogSection.height + (_margins * 4)
                    color:                  qgcPal.windowShade

                    Column {
                        id:                     catalogSection
                        anchors.left:           parent.left
                        anchors.right:          parent.right
                        anchors.top:            parent.top
                        anchors.margins:        _margins * 2
                        spacing:                _margins * 2

                        Rectangle {
                            width:          parent.width
                            color:          qgcPal.window
                            border.color:   "#B5B5B5"
                            border.width:   1
                            height:         udpColumn.height + (_margins * 1.5)

                            Column {
                                id:                     udpColumn
                                anchors.left:           parent.left
                                anchors.right:          parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins:        _margins * 1.2
                                spacing:                ScreenTools.defaultFontPixelHeight * 0.35

                                QGCLabel { text: qsTr("MAVLink UDP Listener"); font.family: ScreenTools.demiboldFontFamily }
                                QGCLabel { text: qsTr("Protocol: UDP             Default Port : %1             Bind : %2").arg(_udpPort.rawValue).arg(_udpBind.rawValue) }
                                QGCLabel { text: qsTr("Disable capability : Yes (Instant)") }
                            }
                        }

                        Rectangle {
                            width:          parent.width
                            color:          qgcPal.window
                            border.color:   "#B5B5B5"
                            border.width:   1
                            height:         tcpColumn.height + (_margins * 1.5)

                            Column {
                                id:                     tcpColumn
                                anchors.left:           parent.left
                                anchors.right:          parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins:        _margins * 1.2
                                spacing:                ScreenTools.defaultFontPixelHeight * 0.35

                                QGCLabel { text: qsTr("MAVLink TCP Connection"); font.family: ScreenTools.demiboldFontFamily }
                                QGCLabel { text: qsTr("Protocol: TCP             Default Port : %1             Bind : %2").arg(_tcpPort.rawValue).arg(_tcpBind.rawValue) }
                                QGCLabel { text: qsTr("Disable capability : Yes (Instant)") }
                            }
                        }

                        QGCButton {
                            width:      parent.width * 0.62
                            anchors.horizontalCenter: parent.horizontalCenter
                            text:       qsTr("Export as Audit Report (.txt)")
                            onClicked:  saveDialog.openForSave()
                        }
                    }
                }
            }
        }
    }

    QGCFileDialog {
        id: saveDialog
        folder: QGroundControl.settingsManager.appSettings.logSavePath
        nameFilters: [qsTr("Log files (*.txt)"), qsTr("All Files (*)")]
        selectExisting: false
        title: qsTr("Select audit report save file")
        onAcceptedForSave: {
            CustomQmlInterface.exportTextReportToPath(file, _root._buildAuditReport())
            visible = false
        }
    }
}
