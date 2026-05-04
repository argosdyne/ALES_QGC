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

            // GPS
            Rectangle {
                radius: _margins
                color: gpsMouseArea.pressed
                       ? qgcPal.buttonHighlight
                       : qgcPal.button

                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 3.5
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 2

                Text {
                    anchors.centerIn: parent
                    text: qsTr("GPS")
                    color: qgcPal.buttonText
                    font.pointSize: ScreenTools.defaultFontPointSize
                }

                MouseArea {
                    id: gpsMouseArea
                    anchors.fill: parent
                    onClicked: {
                        console.log("Optical Flow: GPS pressed")
                        if (_opticalFlowController) {
                            _opticalFlowController.setModeGPS()
                        }
                    }
                }
            }

            // Optical
            Rectangle {
                radius: _margins
                color: opticalMouseArea.pressed
                       ? qgcPal.buttonHighlight
                       : qgcPal.button

                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 3.5
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 2

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Optical")
                    color: qgcPal.buttonText
                    font.pointSize: ScreenTools.defaultFontPointSize
                }

                MouseArea {
                    id: opticalMouseArea
                    anchors.fill: parent
                    onClicked: {
                        console.log("Optical Flow: Optical pressed")
                        if (_opticalFlowController) {
                            _opticalFlowController.setModeOptical()
                        }
                    }
                }
            }

            // Auto
            Rectangle {
                radius: _margins
                color: autoMouseArea.pressed
                       ? qgcPal.buttonHighlight
                       : qgcPal.button

                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 3.5
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 2

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Auto")
                    color: qgcPal.buttonText
                    font.pointSize: ScreenTools.defaultFontPointSize
                }

                MouseArea {
                    id: autoMouseArea
                    anchors.fill: parent
                    onClicked: {
                        console.log("Optical Flow: Auto pressed")
                        if (_opticalFlowController) {
                            _opticalFlowController.setModeAuto()
                        }
                    }
                }
            }

            // Calib
            Rectangle {
                radius: _margins
                color: calibMouseArea.pressed
                       ? qgcPal.buttonHighlight
                       : qgcPal.button

                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 3.5
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 2

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Calib")
                    color: qgcPal.buttonText
                    font.pointSize: ScreenTools.defaultFontPointSize
                }

                MouseArea {
                    id: calibMouseArea
                    anchors.fill: parent
                    onClicked: {
                        console.log("Optical Flow: Calib pressed")
                        if (_opticalFlowController) {
                            _opticalFlowController.calibrate()
                        }
                    }
                }
            }
            }
        }
    }
}
