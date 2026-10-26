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
import QtQuick.Controls         2.12 as QQC2
import QtQuick.Layouts          1.2

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controllers   1.0

SetupPage {
    id:             missionPage
    pageComponent:  missionPageComponent

    Component {
        id: missionPageComponent

        ColumnLayout {
            width:      Math.min(availableWidth, ScreenTools.defaultFontPixelWidth * 68)
            spacing:    ScreenTools.defaultFontPixelHeight * 1.25

            APMMissionComponentController { id: controller }

            property bool _armed:   controller.vehicle ? controller.vehicle.armed : false
            property bool _canEdit: controller.valueKnown && !controller.busy && !_armed
            property int  _savedBit0: (controller.currentValue & 1) ? 1 : 0
            property int  _savedBit2: (controller.currentValue & 4) ? 1 : 0

            Component.onCompleted: controller.refresh()

            Connections {
                target: controller
                onStateChanged: {
                    clearSwitch.checked = controller.clearOnReboot
                    continueSwitch.checked = controller.continueAfterLand
                }
            }

            QGCPalette { id: qgcPal; colorGroupEnabled: true }

            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: optionColumn.height + (ScreenTools.defaultFontPixelHeight * 2)
                color:                  qgcPal.windowShade

                ColumnLayout {
                    id:                 optionColumn
                    anchors.margins:    ScreenTools.defaultFontPixelWidth * 2
                    anchors.top:        parent.top
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    spacing:            ScreenTools.defaultFontPixelHeight

                    QGCLabel {
                        Layout.fillWidth:   true
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode:           Text.WordWrap
                        font.pointSize:     ScreenTools.mediumFontPointSize
                        text: {
                            if (!controller.valueKnown) {
                                return qsTr("Current value: MIS_OPTIONS = —")
                            }
                            if (controller.continueAfterLandSupported) {
                                return qsTr("Current value: MIS_OPTIONS = %1 (bit0 = %2, bit2 = %3)").arg(controller.currentValue).arg(_savedBit0).arg(_savedBit2)
                            }
                            return qsTr("Current value: MIS_OPTIONS = %1 (bit0 = %2)").arg(controller.currentValue).arg(_savedBit0)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth:   true
                        spacing:            ScreenTools.defaultFontPixelHeight * 0.25

                        RowLayout {
                            Layout.fillWidth: true

                            ColumnLayout {
                                Layout.fillWidth:   true
                                spacing:            ScreenTools.defaultFontPixelHeight * 0.15

                                QGCLabel {
                                    text:           qsTr("Clear mission on reboot")
                                    font.family:    ScreenTools.demiboldFontFamily
                                    font.pointSize: ScreenTools.largeFontPointSize
                                    wrapMode:       Text.WordWrap
                                    Layout.fillWidth: true
                                }
                                QGCLabel {
                                    text:           qsTr("MIS_OPTIONS bit0 · Clear Mission on reboot")
                                    wrapMode:       Text.WordWrap
                                    Layout.fillWidth: true
                                    font.pointSize: ScreenTools.mediumFontPointSize
                                }
                            }

                            Item {
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 9
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.7
                                Layout.alignment:       Qt.AlignVCenter

                                QGCSwitch {
                                    id:                 clearSwitch
                                    anchors.centerIn:   parent
                                    scale:              1.5
                                    enabled:            _canEdit
                                    onClicked:          controller.setClearOnReboot(checked)
                                }

                                MouseArea {
                                    anchors.fill:   parent
                                    enabled:        _armed
                                    hoverEnabled:   true
                                    QQC2.ToolTip.visible: containsMouse
                                    QQC2.ToolTip.text:    qsTr("Cannot be changed while armed.")
                                    QQC2.ToolTip.delay:   300
                                }
                            }
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            font.pointSize:     ScreenTools.mediumFontPointSize
                            text:               qsTr("ON: The stored mission is cleared when the vehicle reboots. Re-upload the mission after a reboot.\nOFF: The previous mission is retained after reboot. Verify the mission before starting it.")
                        }

                        Rectangle {
                            Layout.fillWidth:   true
                            implicitHeight:     rebootNote.implicitHeight + ScreenTools.defaultFontPixelHeight
                            color:              qgcPal.window
                            border.color:       qgcPal.colorBlue
                            border.width:       1
                            radius:             3

                            QGCLabel {
                                id:                 rebootNote
                                anchors.margins:    ScreenTools.defaultFontPixelWidth
                                anchors.left:       parent.left
                                anchors.right:      parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                wrapMode:           Text.WordWrap
                                color:              qgcPal.colorBlue
                                font.pointSize:     ScreenTools.mediumFontPointSize
                                text:               qsTr("The change takes effect after the next reboot.")
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth:   true
                        visible:            controller.continueAfterLandSupported
                        spacing:            ScreenTools.defaultFontPixelHeight * 0.25

                        RowLayout {
                            Layout.fillWidth: true

                            ColumnLayout {
                                Layout.fillWidth:   true
                                spacing:            ScreenTools.defaultFontPixelHeight * 0.15

                                QGCLabel {
                                    text:           qsTr("Continue mission after landing")
                                    font.family:    ScreenTools.demiboldFontFamily
                                    font.pointSize: ScreenTools.largeFontPointSize
                                    wrapMode:       Text.WordWrap
                                    Layout.fillWidth: true
                                }
                                QGCLabel {
                                    text:           qsTr("MIS_OPTIONS bit2 · ContinueAfterLand")
                                    wrapMode:       Text.WordWrap
                                    Layout.fillWidth: true
                                    font.pointSize: ScreenTools.mediumFontPointSize
                                }
                            }

                            Item {
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 9
                                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.7
                                Layout.alignment:       Qt.AlignVCenter

                                QGCSwitch {
                                    id:                 continueSwitch
                                    anchors.centerIn:   parent
                                    scale:              1.5
                                    enabled:            _canEdit
                                    onClicked:          controller.setContinueAfterLand(checked)
                                }

                                MouseArea {
                                    anchors.fill:   parent
                                    enabled:        _armed
                                    hoverEnabled:   true
                                    QQC2.ToolTip.visible: containsMouse
                                    QQC2.ToolTip.text:    qsTr("Cannot be changed while armed.")
                                    QQC2.ToolTip.delay:   300
                                }
                            }
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            font.pointSize:     ScreenTools.mediumFontPointSize
                            text:               qsTr("ON: If the next item after landing is a takeoff, the mission continues.\nOFF: After landing, the vehicle disarms and the mission stops.")
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: ScreenTools.defaultFontPixelWidth

                        Item { Layout.fillWidth: true }

                        QGCButton {
                            text:       qsTr("Cancel")
                            pointSize:  ScreenTools.mediumFontPointSize
                            enabled:    _canEdit && controller.dirty
                            onClicked:  controller.cancel()
                        }

                        QGCButton {
                            text:       qsTr("Apply")
                            pointSize:  ScreenTools.mediumFontPointSize
                            primary:    true
                            enabled:    _canEdit && controller.dirty
                            onClicked:  controller.apply()
                        }
                    }

                    QGCLabel {
                        Layout.fillWidth:   true
                        wrapMode:           Text.WordWrap
                        visible:            statusText !== ""
                        font.pointSize:     ScreenTools.mediumFontPointSize
                        color:              statusIsError ? "red" : qgcPal.text
                        text:               statusText

                        property bool statusIsError: controller.status === APMMissionComponentController.StatusFailed ||
                                                     controller.status === APMMissionComponentController.StatusReadFailed
                        property string statusText: {
                            if (controller.status === APMMissionComponentController.StatusApplied) {
                                var applied = qsTr("Applied.")
                                if (controller.lastApplyChangedClear) {
                                    applied += " " + qsTr("Clear mission on reboot takes effect after the next reboot.")
                                }
                                if (controller.lastApplyChangedContinue) {
                                    applied += " " + qsTr("Continue after land takes effect on the next landing.")
                                }
                                return applied
                            }
                            if (controller.status === APMMissionComponentController.StatusFailed) {
                                return qsTr("Failed to apply the setting. The previous value has been restored.")
                            }
                            if (controller.status === APMMissionComponentController.StatusReadFailed) {
                                return qsTr("Could not read MIS_OPTIONS.")
                            }
                            return ""
                        }
                    }
                }
            }
        }
    }
}
