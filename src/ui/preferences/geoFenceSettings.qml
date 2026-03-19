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
import QtQuick.Layouts          1.2

import QGroundControl                       1.0
import QGroundControl.FactSystem            1.0
import QGroundControl.FactControls          1.0
import QGroundControl.Controls              1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.MultiVehicleManager   1.0
import QGroundControl.Palette               1.0
import QGroundControl.Controllers           1.0
import QGroundControl.SettingsManager       1.0



Rectangle {
    id:                 _root
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    property Fact _savePath:                            QGroundControl.settingsManager.appSettings.savePath

    property real   _comboFieldWidth:           ScreenTools.defaultFontPixelWidth * 30
    property real   _valueFieldWidth:           ScreenTools.defaultFontPixelWidth * 10
    property real   _margins:                   ScreenTools.defaultFontPixelWidth

    property var    _planViewSettings:          QGroundControl.settingsManager.planViewSettings
    property var    _flyViewSettings:           QGroundControl.settingsManager.flyViewSettings
    property var    _videoSettings:             QGroundControl.settingsManager.videoSettings

    property var    _appSettings:                       QGroundControl.settingsManager.appSettings
    property var    _geoZoneViewSettings:           QGroundControl.settingsManager.geoZoneMakeViewSettings


    function loadFromSelectedFile() {
        fileDialog.title =          qsTr("Select Geozone File")
        fileDialog.selectExisting = true
        fileDialog.nameFilters =    _geoZoneViewSettings.loadNameFilters
        fileDialog.openForLoad()
    }

    GeoZoneFileDialog {
        id:             fileDialog
        folder:         _appSettings ? _appSettings.geoZoneSavePath : ""

        // onAcceptedForSave: {
        //     if (planFiles) {
        //         _planMasterController.saveToFile(file)
        //     } else {
        //         _planMasterController.saveToKml(file)
        //     }
        //     close()
        // }

        onAcceptedForSave: {

        }

        onAcceptedForLoad: {
            _geoZoneViewSettings.loadFromFile(file)
            // _planMasterController.fitViewportToItems()
            // _missionController.setCurrentPlanViewSeqNum(0, true)
            close()
        }
    }


        QGCFlickable {
            clip:               true
            anchors.fill:       parent
            contentHeight:      outerItem.height
            contentWidth:       outerItem.width

            Item {
                id:     outerItem
                width:  Math.max(_root.width, settingsColumn.width)
                height: settingsColumn.height

                ColumnLayout {
                    id:                         settingsColumn
                    anchors.horizontalCenter:   parent.horizontalCenter

                    QGCLabel {
                        id:         flyViewSectionLabel
                        text:       qsTr("GeoAwareness Settings")
                        visible:    QGroundControl.settingsManager.flyViewSettings.visible
                    }
                    Rectangle {
                        Layout.preferredHeight: flyViewCol.height + (_margins * 2)
                        Layout.preferredWidth:  flyViewCol.width + (_margins * 2)
                        color:                  qgcPal.windowShade
                        visible:                flyViewSectionLabel.visible
                        Layout.fillWidth:       true

                        ColumnLayout {
                            id:                         flyViewCol
                            anchors.margins:            _margins
                            anchors.top:                parent.top
                            anchors.horizontalCenter:   parent.horizontalCenter
                            spacing:                    _margins

                            GridLayout {
                                columns: 2
                                QGCLabel {
                                    text:       qsTr("Set Alarm Distance (meters, 0 = off) ")
                                    visible:    alarmDistance.visible
                                }
                                FactTextField {
                                    id:                     alarmDistance
                                    Layout.preferredWidth:  _valueFieldWidth
                                    visible:                true
                                    fact:                    _flyViewSettings.alarmDistance
                                }

                                // Alarm value must be >= 40 when enabled. 0 disables alerts.
                                Connections {
                                    target: alarmDistance
                                    function onEditingFinished() {
                                        if (alarmDistance.fact.value < 0) {
                                            alarmDistance.fact.value = 0;
                                        } else if (alarmDistance.fact.value > 0 && alarmDistance.fact.value < 40) {
                                            alarmDistance.fact.value = 40;
                                        }
                                    }
                                }
                            }

                            GridLayout {
                                id:         videoGrid
                                columns:    2
                                visible:    true

                                QGCLabel {
                                    id:         videoDecodeLabel
                                    text:       qsTr("Select GeoAwareness Data Type")
                                    visible:    geoDataType.visible
                                }
                                FactComboBox {
                                    id:                     geoDataType
                                    Layout.preferredWidth:  _comboFieldWidth
                                    fact:                   _flyViewSettings.dataType
                                    visible:                true
                                    indexModel:             false
                                }
                            }
                            QGCLabel { text: qsTr("Application Load/Save Path"); visible: geoDataType.currentIndex === 0}

                            FactTextField {
                                id: filePathTextField
                                Layout.fillWidth:   true
                                readOnly:           true
                                visible:            geoDataType.currentIndex === 0
                                fact:   _flyViewSettings.filePath
                            }
                            QGCButton {
                                visible:    geoDataType.currentIndex === 0
                                text:       qsTr("Browse")
                                onClicked:  {
                                    loadFromSelectedFile()
                                    //androidFileDialog.open()
                                }
                                // FileDialog {
                                //     id: androidFileDialog
                                //     title: "Select a File"
                                //     folder: Qt.platform.os === "android" ? "/storage/emulated/0/" : fileUrl
                                //     nameFilters: ["All Files (*)", "Text Files (*.txt)"] // 원하는 파일 필터
                                //     selectExisting: true
                                //     selectMultiple: false
                                //     selectFolder: false

                                //     // 파일 선택 완료 시 호출
                                //     onAccepted: {
                                //         console.log("Selected file path: " + fileUrl) // 선택한 파일의 경로 출력
                                //         console.log("Current platform : " + Qt.platform.os)

                                //         if(Qt.platform.os === "windows"){
                                //             let plainPath = fileUrl.toString().startsWith("file:///") ? fileUrl.toString().substring(8) : fileUrl.toString()
                                //                 console.log("Plain file path: " + plainPath)
                                //                 filePathTextField.text = plainPath
                                //                 _flyViewSettings.setFilePathRawValue(plainPath)
                                //         }
                                //         else {
                                //             filePathTextField.text = fileUrl.toString()
                                //             _flyViewSettings.setFilePathRawValue(fileUrl.toString())
                                //         }
                                //     }
                                //     // 파일 선택 취소 시 호출
                                //     onRejected: {
                                //         console.log("File selection cancelled.")
                                //     }
                                // }
                            }
                            QGCLabel {
                                text:       qsTr("Get Online GeoAwareness ")
                                visible:            geoDataType.currentIndex === 1
                            }
                            FactTextField {
                                id:                     onlinePath
                                Layout.fillWidth:   true
                                visible:            geoDataType.currentIndex === 1
                                fact:               _flyViewSettings.onlinePath

                                Connections {
                                    target: onlinePath.fact
                                    onValueChanged: {
                                        console.log("onlinePath 값이 변경됨:", onlinePath.fact.value)
                                        _flyViewSettings.setOnlinePathRawValue(onlinePath.text)
                                    }
                                }
                            }
                            // QGCLabel {
                            //     text: qsTr("License key")
                            //     visible: geoDataType.currentIndex === 1
                            // }

                            // FactTextField {
                            //     id: licenceKey
                            //     Layout.fillWidth: true
                            //     visible: geoDataType.currentIndex === 1
                            //     fact: _flyViewSettings.onlineLicenseKey
                            // }

                            // QGCButton {
                            //     visible:    geoDataType.currentIndex === 1
                            //     text:       qsTr("Read txt")
                            //     onClicked:  androidFileDialog2.open()
                            //     FileDialog {
                            //         id: androidFileDialog2
                            //         title: "Select a File"
                            //         folder: Qt.platform.os === "android" ? "/storage/emulated/0/" : fileUrl
                            //         nameFilters: ["All Files (*)", "Text Files (*.txt)"] // 원하는 파일 필터
                            //         selectExisting: true
                            //         selectMultiple: false
                            //         selectFolder: false

                            //         // 파일 선택 완료 시 호출
                            //         onAccepted: {
                            //             console.log("Selected file path: " + fileUrl) // 선택한 파일의 경로 출력
                            //             console.log("Current platform : " + Qt.platform.os)

                            //             if(Qt.platform.os === "windows"){
                            //                 let plainPath = fileUrl.toString().startsWith("file:///") ? fileUrl.toString().substring(8) : fileUrl.toString()
                            //                     console.log("Plain file path: " + plainPath)
                            //                     //licenceKey.text = plainPath
                            //                 licenceKey.text = _flyViewSettings.readTextFile(plainPath)
                            //                 _flyViewSettings.setOnlineLicenseKeyRawValue(_flyViewSettings.readTextFile(plainPath))
                            //             }
                            //             else {
                            //                 //licenceKey.text = fileUrl.toString()
                            //                 licenceKey.text = _flyViewSettings.readTextFile(fileUrl.toString())
                            //                 _flyViewSettings.setOnlineLicenseKeyRawValue(_flyViewSettings.readTextFile(fileUrl.toString()))

                            //             }
                            //         }
                            //         // 파일 선택 취소 시 호출
                            //         onRejected: {
                            //             console.log("File selection cancelled.")
                            //         }
                            //     }
                            // }
                        }
                    }
                }
            }
    }
}
