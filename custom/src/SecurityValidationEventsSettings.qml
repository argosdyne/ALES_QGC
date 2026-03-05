import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Layouts          1.2

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0

Rectangle {
    id:                 _root
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    property real _panelWidth: _root.width * 0.84
    property real _margins:    ScreenTools.defaultFontPixelWidth

    QGCPalette { id: qgcPal }

    ListModel {
        id: eventModel
        ListElement { level: "[!]"; time: "14:02:12"; message: "Dropped MAVLink frame: Bad CRC | src: 192.168.1.5" }
        ListElement { level: "[!]"; time: "14:05:45"; message: "Dropped message: SYSID 12 not allowlisted" }
        ListElement { level: "[i]"; time: "14:10:00"; message: "Network policy re-applied: All ports closed." }
        ListElement { level: "[i]"; time: "15:00:01"; message: "Security heartbeat: OK." }
    }

    function levelColor(level) {
        return level === "[!]" ? "#f7b24a" : "#ffffff"
    }

    QGCFlickable {
        anchors.fill:   parent
        clip:           true
        contentHeight:  bodyColumn.height
        contentWidth:   bodyColumn.width

        Column {
            id: bodyColumn
            width: _root.width
            spacing: ScreenTools.defaultFontPixelHeight

            Rectangle {
                width:                      _panelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                color:                      qgcPal.windowShade
                border.color:               qgcPal.windowShadeDark
                radius:                     4
                height:                     contentColumn.height + _margins * 2

                Column {
                    id:                     contentColumn
                    anchors.fill:           parent
                    anchors.margins:        _margins
                    spacing:                ScreenTools.defaultFontPixelHeight * 0.7

                    QGCLabel {
                        text: qsTr("Security / Validation Events")
                        font.family: ScreenTools.demiboldFontFamily
                        font.pointSize: ScreenTools.largeFontPointSize
                    }

                    Rectangle {
                        width:          parent.width
                        height:         Math.max(ScreenTools.defaultFontPixelHeight * 8, eventModel.count * ScreenTools.defaultFontPixelHeight * 1.35)
                        color:          "#000000"
                        border.color:   qgcPal.windowShadeDark
                        radius:         3

                        ListView {
                            anchors.fill:           parent
                            anchors.margins:        ScreenTools.defaultFontPixelWidth
                            model:                  eventModel
                            clip:                   true

                            delegate: Rectangle {
                                width:          ListView.view.width
                                height:         ScreenTools.defaultFontPixelHeight * 1.2
                                color:          "transparent"

                                QGCLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: level + " " + time + " - " + message
                                    color: _root.levelColor(level)
                                    font.family: "Consolas"
                                }
                            }
                        }
                    }

                    RowLayout {
                        width: parent.width
                        Item { Layout.fillWidth: true }

                        QGCButton {
                            text: qsTr("Clear")
                            onClicked: eventModel.clear()
                        }

                        QGCButton {
                            text: qsTr("Export Logs")
                            onClicked: exportDialog.open()
                        }
                    }
                }
            }
        }
    }

    QGCSimpleMessageDialog {
        id: exportDialog
        title: qsTr("Export Logs")
        text: qsTr("Export handler is ready for backend integration.")
    }
}
