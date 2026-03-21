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
import QtQuick.Dialogs          1.2
import QtQuick.Layouts          1.12

import QGroundControl               1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controls      1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Controllers   1.0
import QGroundControl.ScreenTools   1.0

Item {
    id:         _root

    property bool loaded: false

    function clearConsoleLog() {
        debugMessageModel.clearMessages()
    }

    function deleteAllSavedLogFiles() {
        var folderPath = writeDialog.folder
        var fileNames = fileController.getFiles(folderPath, ["*.txt", "*.log"])

        for (var i = 0; i < fileNames.length; i++) {
            var fullPath = fileController.fullyQualifiedFilename(folderPath, fileNames[i])
            fileController.deleteFile(fullPath)
        }
    }

    QGCFileDialogController {
        id: fileController
    }

    Item {
        id:             panel
        anchors.fill:   parent

        Rectangle {
            id:              logwindow
            anchors.fill:    parent
            anchors.margins: ScreenTools.defaultFontPixelWidth
            color:           qgcPal.window

            Connections {
                target: debugMessageModel

                onDataChanged: {
                    // Keep the view in sync if the button is checked
                    if (loaded) {
                        if (followTail.checked) {
                            listview.positionViewAtEnd();
                        }
                    }
                }
            }

            Component {
                id: delegateItem
                Rectangle {
                    color:  index % 2 == 0 ? qgcPal.window : qgcPal.windowShade
                    height: Math.round(ScreenTools.defaultFontPixelHeight * 0.5 + field.height)
                    width:  listview.width

                    QGCLabel {
                        id:         field
                        text:       display
                        width:      parent.width
                        wrapMode:   Text.Wrap
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            QGCListView {
                Component.onCompleted: {
                    loaded = true
                }
                anchors.top:     parent.top
                anchors.left:    parent.left
                anchors.right:   parent.right
                anchors.bottom:  followTail.top
                anchors.bottomMargin: ScreenTools.defaultFontPixelWidth
                clip:            true
                id:              listview
                model:           debugMessageModel
                delegate:        delegateItem
            }

            QGCFileDialog {
                id:             writeDialog
                folder:         QGroundControl.settingsManager.appSettings.logSavePath
                nameFilters:    [qsTr("Log files (*.txt)"), qsTr("All Files (*)")]
                selectExisting: false
                title:          qsTr("Select log save file")
                onAcceptedForSave: {
                    debugMessageModel.writeMessages(file);
                    visible = false;
                }
            }

            Connections {
                target:          debugMessageModel
                onWriteStarted:  writeButton.enabled = false;
                onWriteFinished: writeButton.enabled = true;
            }

            QGCButton {
                id:              writeButton
                anchors.bottom:  parent.bottom
                anchors.left:    parent.left
                leftPadding:        0
                rightPadding:       0
                onClicked: {
                    if (!QGroundControl.settingsManager.appSettings.telemetrySave.rawValue) {
                        mainWindow.showMessageDialog(qsTr("Telemetry Logs Disabled"),
                                                     qsTr("Telemetry logs are not saved, Please enable it in Privacy Settings."))
                        return
                    }
                    writeDialog.openForSave()
                }
                text:            qsTr("Save App Log")
            }

            QGCButton {
                id:              clearButton
                anchors.bottom:  parent.bottom
                anchors.left:    writeButton.right
                leftPadding:        0
                rightPadding:       0
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                onClicked:       _root.clearConsoleLog()
                text:            qsTr("Clear Log")
            }

            QGCButton {
                id:              deleteAllSavedButton
                anchors.bottom:  parent.bottom
                anchors.left:    clearButton.right
                leftPadding:        0
                rightPadding:       0
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                onClicked: {
                    mainWindow.showMessageDialog(qsTr("Delete All Saved Log Files"),
                                                 qsTr("All saved .txt/.log files in the log folder will be permanently deleted. Continue?"),
                                                 StandardButton.Yes | StandardButton.No,
                                                 function() { _root.deleteAllSavedLogFiles() })
                }
                text:            qsTr("Delete Log")
            }

            QGCLabel {
                id:                     gstLabel
                anchors.left:           deleteAllSavedButton.right
                leftPadding:        0
                rightPadding:       0
                anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
                anchors.verticalCenter: gstCombo.verticalCenter
                text:                   qsTr("GStreamer Debug Level")
                visible:                QGroundControl.settingsManager.appSettings.gstDebugLevel.visible
            }

            FactComboBox {
                id:                 gstCombo
                anchors.left:       gstLabel.right
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth / 2
                anchors.bottom:     parent.bottom
                fact:               QGroundControl.settingsManager.appSettings.gstDebugLevel
                visible:            QGroundControl.settingsManager.appSettings.gstDebugLevel.visible
                sizeToContents:     true
            }

            QGCButton {
                id:                     followTail
                anchors.right:          filterButton.left
                leftPadding:        0
                rightPadding:       0
                anchors.rightMargin:    ScreenTools.defaultFontPixelWidth
                anchors.bottom:         parent.bottom
                text:                   qsTr("Show Latest")
                checkable:              true
                checked:                true

                onCheckedChanged: {
                    if (checked && loaded) {
                        listview.positionViewAtEnd();
                    }
                }
            }

            QGCButton {
                id:             filterButton
                anchors.bottom: parent.bottom
                anchors.right:  parent.right
                leftPadding:        0
                rightPadding:       0
                text:           qsTr("Set Logging")
                onClicked:      filtersDialogComponent.createObject(mainWindow).open()
            }
        }
    }

    Component {
        id: filtersDialogComponent

        QGCPopupDialog {
            title:      qsTr("Logging categories")
            buttons:    StandardButton.Close

            ColumnLayout {
                RowLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 2
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillHeight: true
                    Layout.fillWidth: true

                    QGCLabel {
                        text: qsTr("Search:")
                    }

                    QGCTextField {
                        id: searchText
                        text: ""
                        Layout.fillWidth: true
                        enabled: true
                    }

                    QGCButton {
                        text: qsTr("Clear")
                        onClicked: searchText.text = ""
                    }
                }

                Row {
                    spacing:    ScreenTools.defaultFontPixelHeight / 2
                    QGCButton {
                        text: qsTr("Clear All")
                        onClicked: categoryRepeater.setAllLogs(false)
                    }
                }

                Column {
                    id:         categoryColumn
                    spacing:    ScreenTools.defaultFontPixelHeight / 2

                    Repeater {
                        id:     categoryRepeater
                        model:  QGroundControl.loggingCategories()

                        function setAllLogs(value) {
                            var logCategories = QGroundControl.loggingCategories()
                            for (var category of logCategories) {
                                QGroundControl.setCategoryLoggingOn(category, value)
                            }
                            QGroundControl.updateLoggingFilterRules()
                            // Update model for repeater
                            categoryRepeater.model = undefined
                            categoryRepeater.model = QGroundControl.loggingCategories()
                        }

                        QGCCheckBox {
                            text:       modelData
                            visible:    searchText.text ? text.match(`(${searchText.text})`, "i") : true
                            checked:    QGroundControl.categoryLoggingOn(modelData)
                            onClicked:  {
                                QGroundControl.setCategoryLoggingOn(modelData, checked)
                                QGroundControl.updateLoggingFilterRules()
                            }
                        }
                    }
                }
            }
        }
    }
}

