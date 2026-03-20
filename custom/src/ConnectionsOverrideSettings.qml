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
    property Fact _videoUrl:        _customSettings.networkVideoUrl
    property var  _videoSettings:   QGroundControl.settingsManager.videoSettings

    QGCPalette { id: qgcPal }

    function boolToIndex(value) {
        return value ? 1 : 0
    }

    function indexToBool(index) {
        return index === 1
    }

    function _applyVideoState(enabled) {
        _videoEnabled.rawValue = enabled
        _videoSettings.streamEnabled.rawValue = enabled
        CustomQmlInterface.logSecurityEvent("Video streaming " + (enabled ? "enabled" : "disabled") + " from Connections settings")
        if (enabled) {
            var videoUri = _videoUrl.rawValue.toString().trim()
            if (videoUri.indexOf("rtsp://") === 0) {
                _videoSettings.videoSource.rawValue = _videoSettings.rtspVideoSource
                _videoSettings.rtspUrl.rawValue = videoUri
                return
            } else if (videoUri.indexOf("tcp://") === 0) {
                _videoSettings.videoSource.rawValue = _videoSettings.tcpVideoSource
                _videoSettings.tcpUrl.rawValue = videoUri
                return
            } else if (videoUri.indexOf("udp265://") === 0) {
                _videoSettings.videoSource.rawValue = _videoSettings.udp265VideoSource
            } else if (videoUri.indexOf("mpegts://") === 0) {
                _videoSettings.videoSource.rawValue = _videoSettings.mpegtsVideoSource
            } else {
                _videoSettings.videoSource.rawValue = _videoSettings.udp264VideoSource
            }

            var portMatch = videoUri.match(/:(\d+)\s*$/)
            if (portMatch && portMatch.length > 1) {
                _videoSettings.udpPort.rawValue = parseInt(portMatch[1], 10)
            }
        }
    }

    function _setUdpEnabled(enabled) {
        _udpEnabled.rawValue = enabled
        CustomQmlInterface.logSecurityEvent("UDP listener " + (enabled ? "enabled" : "disabled") + " from Connections settings")
        if (enabled) {
            QGroundControl.linkManager.refreshNetworkLinks()
        } else {
            QGroundControl.linkManager.disconnectLinksByType(LinkConfiguration.TypeUdp)
        }
    }

    function _setTcpEnabled(enabled) {
        _tcpEnabled.rawValue = enabled
        CustomQmlInterface.logSecurityEvent("TCP connection " + (enabled ? "enabled" : "disabled") + " from Connections settings")
        if (enabled) {
            QGroundControl.linkManager.refreshNetworkLinks()
        } else {
            QGroundControl.linkManager.disconnectLinksByType(LinkConfiguration.TypeTcp)
        }
    }

    function _openNetworkServicesPage() {
        var item = _root
        while (item) {
            if (item.hasOwnProperty("source")) {
                item.source = "qrc:/custom/NetworkServicesPortsSettings.qml"
                return
            }
            item = item.parent
        }
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
                height:                     sectionColumn.height + _margins * 2

                Column {
                    id:                     sectionColumn
                    spacing:                ScreenTools.defaultFontPixelHeight * 0.7
                    anchors.left:           parent.left
                    anchors.right:          parent.right
                    anchors.top:            parent.top
                    anchors.margins:        _margins

                    QGCLabel {
                        text: qsTr("Settings > Connections")
                        font.family: ScreenTools.demiboldFontFamily
                        font.pointSize: ScreenTools.largeFontPointSize
                    }

                    QGCLabel {
                        text: qsTr("NETWORK SERVICES (MANUAL OVERRIDE)")
                        color: qgcPal.colorBlue
                        font.family: ScreenTools.demiboldFontFamily
                    }

                    Rectangle {
                        width:          parent.width
                        color:          qgcPal.windowShadeDark
                        radius:         3
                        height:         udpRow.height + _margins

                        RowLayout {
                            id:                     udpRow
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins:        _margins

                            QGCLabel {
                                Layout.fillWidth: true
                                text: qsTr("MAVLink UDP Listener (%1)").arg(_udpPort.rawValue)
                            }
                            QGCComboBox {
                                model: ["OFF", "ON"]
                                currentIndex: _root.boolToIndex(_udpEnabled.rawValue)
                                onActivated: _root._setUdpEnabled(_root.indexToBool(index))
                            }
                        }
                    }

                    Rectangle {
                        width:          parent.width
                        color:          qgcPal.windowShadeDark
                        radius:         3
                        height:         tcpRow.height + _margins

                        RowLayout {
                            id:                     tcpRow
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins:        _margins

                            QGCLabel {
                                Layout.fillWidth: true
                                text: qsTr("MAVLink TCP Connection (%1)").arg(_tcpPort.rawValue)
                            }
                            QGCComboBox {
                                model: ["OFF", "ON"]
                                currentIndex: _root.boolToIndex(_tcpEnabled.rawValue)
                                onActivated: _root._setTcpEnabled(_root.indexToBool(index))
                            }
                        }
                    }

                    Rectangle {
                        width:          parent.width
                        color:          qgcPal.windowShadeDark
                        radius:         3
                        height:         videoRow.height + _margins

                        RowLayout {
                            id:                     videoRow
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins:        _margins

                            QGCLabel {
                                Layout.fillWidth: true
                                text: qsTr("Video Streaming (GStreamer)")
                            }
                            QGCComboBox {
                                model: ["OFF", "ON"]
                                currentIndex: _root.boolToIndex(_videoEnabled.rawValue)
                                onActivated: _root._applyVideoState(_root.indexToBool(index))
                            }
                        }
                    }

                    QGCLabel {
                        id: networkServicesDocLink
                        text: qsTr("Open Network Services & Ports Documentation")
                        color: qgcPal.colorBlue

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: _root._openNetworkServicesPage()
                        }
                    }
                }
            }
        }
    }
}
