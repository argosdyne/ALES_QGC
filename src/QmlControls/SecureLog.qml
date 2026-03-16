/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Controls.Styles  1.4
import QtQuick.Layouts          1.12

import QGroundControl               1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0

Item {
    id: root

    property bool loaded: false

    QGCPalette { id: qgcPal }

    Item {
        anchors.fill: parent

        Rectangle {
            id: logWindow
            anchors.fill: parent
            anchors.margins: ScreenTools.defaultFontPixelWidth
            color: qgcPal.window

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
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            QGCListView {
                id: listView
                Component.onCompleted: {
                    loaded = true
                }
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: followTail.top
                anchors.bottomMargin: ScreenTools.defaultFontPixelWidth
                clip: true
                model: securityLogModel
                delegate: delegateItem
            }

            QGCFileDialog {
                id: saveDialog
                folder: QGroundControl.settingsManager.appSettings.logSavePath
                nameFilters: [qsTr("Log files (*.txt)"), qsTr("All Files (*)")]
                selectExisting: false
                title: qsTr("Select secure log save file")
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
}
