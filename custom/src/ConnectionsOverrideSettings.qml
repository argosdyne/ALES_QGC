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

    QGCPalette { id: qgcPal }

    function boolToIndex(value) {
        return value ? 1 : 0
    }

    function indexToBool(index) {
        return index === 1
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
                                onActivated: _udpEnabled.rawValue = _root.indexToBool(index)
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
                                text: qsTr("MAVLink TCP Server (%1)").arg(_tcpPort.rawValue)
                            }
                            QGCComboBox {
                                model: ["OFF", "ON"]
                                currentIndex: _root.boolToIndex(_tcpEnabled.rawValue)
                                onActivated: _tcpEnabled.rawValue = _root.indexToBool(index)
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
                                onActivated: _videoEnabled.rawValue = _root.indexToBool(index)
                            }
                        }
                    }

                    QGCLabel {
                        text: qsTr("Open Network Services & Ports Documentation")
                        color: qgcPal.colorBlue
                    }
                }
            }
        }
    }
}
