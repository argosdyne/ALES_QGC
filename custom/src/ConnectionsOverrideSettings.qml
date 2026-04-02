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
                width:                      _panelWidth *5/6

                QGCLabel {
                    id:   connectionsSectionLabel
                    text: qsTr("Connections")
                    font.family:    ScreenTools.demiboldFontFamily
                }

                Rectangle {
                    Layout.preferredHeight: connectionsCol.height + (_margins * 6)
                    Layout.preferredWidth:  _panelWidth
                    color:                  qgcPal.windowShade
                    Layout.fillWidth:       true

                    ColumnLayout {
                        id:                         connectionsCol                       
                        anchors.top:                parent.top
                        anchors.topMargin:          _margins *3
                        anchors.left:               parent.left
                        anchors.leftMargin:            _margins *3
                        anchors.right:              parent.right
                        anchors.rightMargin:           _margins *5
                        spacing:                    _margins *1.5

                        QGCLabel {
                            text:           qsTr("Network Services (Manual OverRide)")
                            font.family:    ScreenTools.demiboldFontFamily
                        }

                        RowLayout {
                            Layout.fillWidth:   true
                            spacing:            _margins

                            QGCLabel {
                                Layout.fillWidth:   true
                                text:               qsTr("MAVLink UDP Listener (%1)").arg(_udpPort.rawValue)
                            }
                            QGCComboBox {
                                model:          ["OFF", "ON"]
                                currentIndex:   _root.boolToIndex(_udpEnabled.rawValue)
                                onActivated:    _root._setUdpEnabled(_root.indexToBool(index))
                            }
                        }

                        RowLayout {
                            Layout.fillWidth:   true
                            spacing:            _margins

                            QGCLabel {
                                Layout.fillWidth:   true
                                text:               qsTr("MAVLink TCP Connection (%1)").arg(_tcpPort.rawValue)
                            }
                            QGCComboBox {
                                model:          ["OFF", "ON"]
                                currentIndex:   _root.boolToIndex(_tcpEnabled.rawValue)
                                onActivated:    _root._setTcpEnabled(_root.indexToBool(index))
                            }
                        }

                        RowLayout {
                            Layout.fillWidth:   true
                            spacing:            _margins

                            QGCLabel {
                                Layout.fillWidth:   true
                                text:               qsTr("Video Streaming (GStreamer)")
                            }
                            QGCComboBox {
                                model:          ["OFF", "ON"]
                                currentIndex:   _root.boolToIndex(_videoEnabled.rawValue)
                                onActivated:    _root._applyVideoState(_root.indexToBool(index))
                            }
                        }

                        QGCLabel {
                            text:   qsTr("Open Network Services & Ports Documentation")
                            color:  qgcPal.colorGrey

                            MouseArea {
                                anchors.fill:   parent
                                cursorShape:    Qt.PointingHandCursor
                                onClicked:      _root._openNetworkServicesPage()
                            }
                        }
                    }
                }
            }
        }
    }
}
