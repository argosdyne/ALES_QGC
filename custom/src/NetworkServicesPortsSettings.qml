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

    function _exportAuditReport() {
        var filePath = CustomQmlInterface.exportTextReport("ALES_QGC_NetworkServicesAudit.txt", _buildAuditReport())
        if (filePath.length) {
            console.info("SECURITY: Network services audit exported to " + filePath)
            exportDialog.text = qsTr("Audit report exported to:\n%1").arg(filePath)
        } else {
            exportDialog.text = qsTr("Failed to export audit report.")
        }
        exportDialog.open()
    }

    QGCFlickable {
        anchors.fill:   parent
        clip:           true
        contentHeight:  contentColumn.height
        contentWidth:   contentColumn.width

        Column {
            id:                 contentColumn
            width:              _root.width
            spacing:            ScreenTools.defaultFontPixelHeight

            Rectangle {
                width:                      _panelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                color:                      qgcPal.windowShade
                border.color:               qgcPal.windowShadeDark
                radius:                     4
                height:                     cardColumn.height + _margins * 2

                Column {
                    id:                     cardColumn
                    spacing:                ScreenTools.defaultFontPixelHeight * 0.7
                    anchors.left:           parent.left
                    anchors.right:          parent.right
                    anchors.top:            parent.top
                    anchors.margins:        _margins

                    QGCLabel {
                        text: qsTr("Network Services & Ports")
                        font.family: ScreenTools.demiboldFontFamily
                        font.pointSize: ScreenTools.largeFontPointSize
                    }

                    Rectangle {
                        width:          parent.width
                        color:          qgcPal.windowShadeDark
                        border.color:   qgcPal.windowShadeDark
                        radius:         3
                        height:         summaryColumn.height + _margins

                        Column {
                            id:                     summaryColumn
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins:        _margins
                            spacing:                ScreenTools.defaultFontPixelHeight * 0.2

                            QGCLabel { text: qsTr("Factory Default: ALL OFF"); font.family: ScreenTools.demiboldFontFamily }
                            QGCLabel {
                                text: qsTr("Current Status: Secure (%1 Listening Ports)").arg(_openPortCount)
                                color: _openPortCount === 0 ? qgcPal.colorGreen : qgcPal.colorRed
                                font.family: ScreenTools.demiboldFontFamily
                            }
                        }
                    }

                    QGCLabel {
                        text: qsTr("SERVICE CATALOG")
                        color: qgcPal.colorBlue
                        font.family: ScreenTools.demiboldFontFamily
                    }

                    Rectangle {
                        width:          parent.width
                        color:          "transparent"
                        border.color:   qgcPal.windowShadeDark
                        radius:         3
                        height:         udpColumn.height + _margins

                        Column {
                            id:                     udpColumn
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins:        _margins
                            spacing:                ScreenTools.defaultFontPixelHeight * 0.25

                            QGCLabel { text: qsTr("MAVLink UDP Listener"); font.family: ScreenTools.demiboldFontFamily }
                            QGCLabel { text: qsTr("Protocol: UDP | Default Port: %1 | Bind: %2").arg(_udpPort.rawValue).arg(_udpBind.rawValue) }
                            QGCLabel { text: qsTr("Disable capability: Yes (Instant)") }
                        }
                    }

                    Rectangle {
                        width:          parent.width
                        color:          "transparent"
                        border.color:   qgcPal.windowShadeDark
                        radius:         3
                        height:         tcpColumn.height + _margins

                        Column {
                            id:                     tcpColumn
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins:        _margins
                            spacing:                ScreenTools.defaultFontPixelHeight * 0.25

                            QGCLabel { text: qsTr("MAVLink TCP Connection"); font.family: ScreenTools.demiboldFontFamily }
                            QGCLabel { text: qsTr("Protocol: TCP | Default Port: %1 | Bind: %2").arg(_tcpPort.rawValue).arg(_tcpBind.rawValue) }
                            QGCLabel { text: qsTr("Disable capability: Yes (Instant)") }
                        }
                    }

                    QGCButton {
                        width: parent.width
                        text: qsTr("Export as Audit Report (.txt)")
                        onClicked: _root._exportAuditReport()
                    }
                }
            }
        }
    }

    QGCSimpleMessageDialog {
        id: exportDialog
        title: qsTr("Audit Export")
        text: ""
    }
}
