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

    function levelColor(line) {
        return line.indexOf("[E]") >= 0 || line.indexOf("[!]") >= 0 ? "#f7b24a" : "#ffffff"
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
                height:                     contentColumn.implicitHeight + _margins * 2

                Column {
                    id:                     contentColumn
                    width:                  parent.width - (_margins * 2)
                    anchors.left:           parent.left
                    anchors.top:            parent.top
                    anchors.margins:        _margins
                    spacing:                ScreenTools.defaultFontPixelHeight * 0.7

                    QGCLabel {
                        text: qsTr("Security / Validation Events")
                        font.family: ScreenTools.demiboldFontFamily
                        font.pointSize: ScreenTools.largeFontPointSize
                    }

                    QGCLabel {
                        text: qsTr("Showing the shared persistent security event log.")
                        color: qgcPal.colorGrey
                    }

                    Rectangle {
                        width:          parent.width
                        height:         Math.max(ScreenTools.defaultFontPixelHeight * 10, securityLogModel.rowCount() * ScreenTools.defaultFontPixelHeight * 1.35)
                        color:          "#000000"
                        border.color:   qgcPal.windowShadeDark
                        radius:         3

                        Item {
                            anchors.fill: parent
                            visible: securityLogModel.rowCount() === 0

                            QGCLabel {
                                anchors.centerIn: parent
                                text: qsTr("No security events captured yet.")
                                color: qgcPal.colorGrey
                            }
                        }

                        ListView {
                            id:                     listView
                            anchors.fill:           parent
                            anchors.margins:        ScreenTools.defaultFontPixelWidth
                            model:                  securityLogModel
                            clip:                   true
                            visible:                securityLogModel.rowCount() > 0

                            Component.onCompleted: {
                                positionViewAtEnd()
                            }

                            delegate: Rectangle {
                                width:          ListView.view.width
                                height:         ScreenTools.defaultFontPixelHeight * 1.2
                                color:          "transparent"

                                QGCLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: display
                                    color: _root.levelColor(display)
                                    font.family: "Consolas"
                                }
                            }
                        }
                    }

                    RowLayout {
                        width: parent.width
                        Item { Layout.fillWidth: true }

                        QGCButton {
                            id: saveButton
                            text: qsTr("Save Secure Log")
                            onClicked: saveDialog.openForSave()
                        }

                        QGCButton {
                            text: qsTr("Clear Log")
                            onClicked: securityLogModel.clearLog()
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
        title: qsTr("Select security events save file")
        onAcceptedForSave: {
            securityLogModel.writeMessages(file)
            visible = false
        }
    }

    Connections {
        target: securityLogModel
        onDataChanged: {
            listView.positionViewAtEnd()
        }
    }

    Connections {
        target: securityLogModel
        onWriteStarted: saveButton.enabled = false
        onWriteFinished: saveButton.enabled = true
    }
}
