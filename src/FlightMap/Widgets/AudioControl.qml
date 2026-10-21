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
    //implicitHeight: content.implicitHeight
    visible:        QGroundControl.settingsManager.flyViewSettings.enableAudioController.value
    property real   _margins:                                   ScreenTools.defaultFontPixelHeight / 2
    property var    _activeVehicle:                             QGroundControl.multiVehicleManager.activeVehicle


    property var _audioControl:                 _activeVehicle ? _activeVehicle.audioControl : null
    //----------------------------------------------------------------------------------------------- Functions

    Rectangle {
        id: root
        color: "#2B2B2B"
        radius: _margins

        implicitWidth: contentLayout.implicitWidth + _margins * 2
        implicitHeight: contentLayout.implicitHeight + _margins * 2

        RowLayout {
            id: contentLayout
            anchors.margins: _margins
            anchors.centerIn: parent
            spacing: ScreenTools.defaultFontPixelHeight / 2

            // ComboBox
            QGCComboBox {
                id: audioIndexCombo

                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 3.5
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight

                model: [1,2,3,4,5,6,7,8]

                background: Rectangle {
                    radius: _margins
                    color: qgcPal.button
                }

                onActivated: {
                    console.log("Selected audio index:", currentText)
                }
            }

            // Play
            Rectangle {
                radius: _margins
                color: playMouseArea.pressed
                       ? qgcPal.buttonHighlight
                       : qgcPal.button

                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 3.5
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 2

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Play")
                    color: qgcPal.buttonText
                    font.pointSize: ScreenTools.defaultFontPointSize
                }

                MouseArea {
                    id: playMouseArea
                    anchors.fill: parent
                    onClicked: _audioControl._playAudio(audioIndexCombo.currentText)
                }
            }

            // // Loop
            // Rectangle {
            //     radius: _margins
            //     color: loopMouseArea.pressed
            //            ? qgcPal.buttonHighlight
            //            : qgcPal.button

            //     Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 3.5
            //     Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 2

            //     Text {
            //         anchors.centerIn: parent
            //         text: qsTr("Loop")
            //         color: qgcPal.buttonText
            //         font.pointSize: ScreenTools.defaultFontPointSize
            //     }

            //     MouseArea {
            //         id: loopMouseArea
            //         anchors.fill: parent
            //         onClicked: _audioControl._loopAudio(audioIndexCombo.currentText)
            //     }
            // }

            // Stop
            Rectangle {
                radius: _margins
                color: stopMouseArea.pressed
                       ? qgcPal.buttonHighlight
                       : qgcPal.button

                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 3.5
                Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 2

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Stop")
                    color: qgcPal.buttonText
                    font.pointSize: ScreenTools.defaultFontPointSize
                }

                MouseArea {
                    id: stopMouseArea
                    anchors.fill: parent
                    onClicked: _audioControl._stopAudio()
                }
            }
        }
    }
}
