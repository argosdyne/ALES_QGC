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

    property bool loaded: false
    QGCPalette { id: qgcPal }

    function levelColor(line) {
        return line.indexOf("[E]") >= 0 || line.indexOf("[!]") >= 0 ? "#f7b24a" : "#ffffff"
    }

    Connections {
        target: securityLogModel
        onDataChanged: {
            if (loaded && followTail.checked) {
                listView.positionViewAtEnd()
            }
        }
    }

    Component {
        id: delegateItem

        Rectangle {
            color: index % 2 === 0 ? qgcPal.window : qgcPal.windowShade
            height: Math.round(ScreenTools.defaultFontPixelHeight * 0.5 + field.height)
            width: listView.width

            QGCLabel {
                id: field
                text: display
                width: parent.width
                wrapMode: Text.Wrap
                color: _root.levelColor(display)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Item {
        anchors.fill: parent

        Rectangle {
            id: logWindow
            anchors.fill: parent
            color: qgcPal.window

            Item {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: followTail.top
                anchors.bottomMargin: ScreenTools.defaultFontPixelWidth

                QGCListView {
                    id: listView
                    Component.onCompleted: {
                        loaded = true
                        positionViewAtEnd()
                    }
                    anchors.fill: parent
                    clip: true
                    model: securityLogModel
                    delegate: delegateItem
                    visible: securityLogModel.rowCount() > 0
                }

                QGCLabel {
                    anchors.centerIn: parent
                    text: qsTr("No security events captured yet.")
                    color: qgcPal.colorGrey
                    visible: securityLogModel.rowCount() === 0
                }
            }

            QGCButton {
                id: saveButton
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                onClicked: saveDialog.openForSave()
                text: qsTr("Save Secure Log")
            }

            QGCButton {
                id: clearButton
                anchors.left: saveButton.right
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                anchors.bottom: parent.bottom
                onClicked: securityLogModel.clearLog()
                text: qsTr("Clear Log")
            }

            QGCButton {
                id: followTail
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: qsTr("Show Latest")
                checkable: true
                checked: true

                onCheckedChanged: {
                    if (checked && loaded) {
                        listView.positionViewAtEnd()
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
        onWriteStarted: saveButton.enabled = false
        onWriteFinished: saveButton.enabled = true
    }
}
