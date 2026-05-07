/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick                  2.4
import QtPositioning            5.2
import QtQuick.Layouts          1.2
import QtQuick.Controls         1.4
import QtQuick.Dialogs          1.2
import QtGraphicalEffects       1.0
import QtQuick.Window           2.11

import QGroundControl                   1.0
import QGroundControl.ScreenTools       1.0
import QGroundControl.Controls          1.0
import QGroundControl.Palette           1.0
import QGroundControl.Vehicle           1.0
import QGroundControl.Controllers       1.0
import QGroundControl.FactSystem        1.0
import QGroundControl.FactControls      1.0
import QGroundControl.FlightDisplay     1.0
import QGroundControl.FlightMap         1.0


Item {
    visible:        QGroundControl.settingsManager.flyViewSettings.enableOpticalFlowController.value
    property real   _margins:                                   ScreenTools.defaultFontPixelHeight / 2
    property var    _activeVehicle:                             QGroundControl.multiVehicleManager.activeVehicle
    property var    _opticalFlowController:                     _activeVehicle ? _activeVehicle.opticalFlowController : null
    property string _selectedMode:                              ""

    implicitWidth:  root.implicitWidth
    implicitHeight: root.implicitHeight

    Rectangle {
        id: root
        color: "#2B2B2B"
        radius: _margins

        implicitWidth: contentLayout.implicitWidth + _margins * 2
        implicitHeight: contentLayout.implicitHeight + _margins * 2

        // Catch clicks on empty / black areas of the panel so they don't fall
        // through to the map below (which would trigger "Set Home" etc.)
        MouseArea {
            anchors.fill:    parent
            propagateComposedEvents: false
            preventStealing: true
            onClicked:       (mouse) => mouse.accepted = true
            onPressed:       (mouse) => mouse.accepted = true
        }

        ColumnLayout {
            id: contentLayout
            anchors.margins: _margins
            anchors.centerIn: parent
            spacing: ScreenTools.defaultFontPixelHeight / 2
            QGCLabel {
                text: qsTr("Optical Flow Sensor")
                color: qgcPal.buttonText
                font.pointSize: ScreenTools.defaultFontPointSize
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            RowLayout {
                spacing: ScreenTools.defaultFontPixelHeight / 2
                Layout.alignment: Qt.AlignHCenter

            // GPS (radio)
            Rectangle {
                radius: _margins
                color: _selectedMode === "gps"
                       ? qgcPal.buttonHighlight
                       : (gpsMouseArea.pressed ? qgcPal.buttonHighlight : qgcPal.button)

                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 4.5
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 2

                RowLayout {
                    anchors.centerIn: parent
                    spacing: ScreenTools.defaultFontPixelHeight / 4

                    Rectangle {
                        width:  ScreenTools.defaultFontPixelHeight * 0.7
                        height: width
                        radius: width / 2
                        color:  "transparent"
                        border.color: qgcPal.buttonText
                        border.width: 1
                        Rectangle {
                            anchors.centerIn: parent
                            width:  parent.width * 0.5
                            height: width
                            radius: width / 2
                            color:  qgcPal.buttonText
                            visible: _selectedMode === "gps"
                        }
                    }
                    Text {
                        text: qsTr("GPS")
                        color: qgcPal.buttonText
                        font.pointSize: ScreenTools.defaultFontPointSize
                    }
                }

                MouseArea {
                    id: gpsMouseArea
                    anchors.fill: parent
                    onClicked: {
                        console.log("Optical Flow: GPS pressed")
                        _selectedMode = "gps"
                        if (_opticalFlowController) {
                            _opticalFlowController.setModeGPS()
                        }
                    }
                }
            }

            // Optical (radio)
            Rectangle {
                radius: _margins
                color: _selectedMode === "optical"
                       ? qgcPal.buttonHighlight
                       : (opticalMouseArea.pressed ? qgcPal.buttonHighlight : qgcPal.button)

                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 4.5
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 2

                RowLayout {
                    anchors.centerIn: parent
                    spacing: ScreenTools.defaultFontPixelHeight / 4

                    Rectangle {
                        width:  ScreenTools.defaultFontPixelHeight * 0.7
                        height: width
                        radius: width / 2
                        color:  "transparent"
                        border.color: qgcPal.buttonText
                        border.width: 1
                        Rectangle {
                            anchors.centerIn: parent
                            width:  parent.width * 0.5
                            height: width
                            radius: width / 2
                            color:  qgcPal.buttonText
                            visible: _selectedMode === "optical"
                        }
                    }
                    Text {
                        text: qsTr("Optical")
                        color: qgcPal.buttonText
                        font.pointSize: ScreenTools.defaultFontPointSize
                    }
                }

                MouseArea {
                    id: opticalMouseArea
                    anchors.fill: parent
                    onClicked: {
                        console.log("Optical Flow: Optical pressed")
                        _selectedMode = "optical"
                        if (_opticalFlowController) {
                            _opticalFlowController.setModeOptical()
                        }
                    }
                }
            }

            // Auto (radio)
            Rectangle {
                radius: _margins
                color: _selectedMode === "auto"
                       ? qgcPal.buttonHighlight
                       : (autoMouseArea.pressed ? qgcPal.buttonHighlight : qgcPal.button)

                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 4.5
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 2

                RowLayout {
                    anchors.centerIn: parent
                    spacing: ScreenTools.defaultFontPixelHeight / 4

                    Rectangle {
                        width:  ScreenTools.defaultFontPixelHeight * 0.7
                        height: width
                        radius: width / 2
                        color:  "transparent"
                        border.color: qgcPal.buttonText
                        border.width: 1
                        Rectangle {
                            anchors.centerIn: parent
                            width:  parent.width * 0.5
                            height: width
                            radius: width / 2
                            color:  qgcPal.buttonText
                            visible: _selectedMode === "auto"
                        }
                    }
                    Text {
                        text: qsTr("Auto")
                        color: qgcPal.buttonText
                        font.pointSize: ScreenTools.defaultFontPointSize
                    }
                }

                MouseArea {
                    id: autoMouseArea
                    anchors.fill: parent
                    onClicked: {
                        console.log("Optical Flow: Auto pressed")
                        _selectedMode = "auto"
                        if (_opticalFlowController) {
                            _opticalFlowController.setModeAuto()
                        }
                    }
                }
            }
            }

            RowLayout {
                spacing: ScreenTools.defaultFontPixelHeight / 2
                Layout.alignment: Qt.AlignHCenter

            // Calib Start
            Rectangle {
                radius: _margins
                color: calibStartMouseArea.pressed
                       ? qgcPal.buttonHighlight
                       : qgcPal.button

                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 4.5
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 2

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Calib Start")
                    color: qgcPal.buttonText
                    font.pointSize: ScreenTools.defaultFontPointSize
                }

                MouseArea {
                    id: calibStartMouseArea
                    anchors.fill: parent
                    onClicked: {
                        console.log("Optical Flow: Calib Start pressed")
                        if (_opticalFlowController) {
                            _opticalFlowController.calibrate()
                        }
                    }
                }
            }

            // Calib Stop
            Rectangle {
                radius: _margins
                color: calibStopMouseArea.pressed
                       ? qgcPal.buttonHighlight
                       : qgcPal.button

                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 4.5
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 2

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Calib Stop")
                    color: qgcPal.buttonText
                    font.pointSize: ScreenTools.defaultFontPointSize
                }

                MouseArea {
                    id: calibStopMouseArea
                    anchors.fill: parent
                    onClicked: {
                        console.log("Optical Flow: Calib Stop pressed")
                        if (_opticalFlowController) {
                            _opticalFlowController.calibrateStop()
                        }
                    }
                }
            }
            }
        }
    }
}
