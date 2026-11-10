/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick                      2.12
import QtQuick.Layouts              1.12

import QGroundControl               1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Vehicle       1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0

Rectangle {
    id:                 telemetryPanel
    height:             telemetryLayout.height + (_padding * 2)
    width:              telemetryLayout.width + (_padding * 2)
    color:              qgcPal.window
    radius:             ScreenTools.figmaPx * 8

    property bool       bottomMode: true
    property real       _padding:   ScreenTools.figmaPx * 12    // Figma TelemetryValuesBar padding

    DeadMouseArea { anchors.fill: parent }

    ColumnLayout {
        id:                 telemetryLayout
        anchors.margins:    _padding
        anchors.bottom:     parent.bottom
        spacing:            ScreenTools.figmaPx * 8      // Figma: 8 px between the values and the confirm panel
        anchors.left:       parent.left

         RowLayout {
            visible: mouseArea.containsMouse || valueArea.settingsUnlocked

            QGCColoredImage {
                source:             "/res/layout-bottom.svg"
                mipmap:             true
                width:              ScreenTools.minTouchPixels * 0.75
                height:             width
                sourceSize.width:   width
                color:              qgcPal.text
                fillMode:           Image.PreserveAspectFit
                visible:            !bottomMode

                QGCMouseArea {
                    fillItem:   parent
                    onClicked:  bottomMode = true
                }
            }

            QGCColoredImage {
                source:             "/res/layout-right.svg"
                mipmap:             true
                width:              ScreenTools.minTouchPixels * 0.75
                height:             width
                sourceSize.width:   width
                color:              qgcPal.text
                fillMode:           Image.PreserveAspectFit
                visible:            bottomMode

                QGCMouseArea {
                    fillItem:   parent
                    onClicked:  bottomMode = false
                }
            }

            QGCColoredImage {
                source:             valueArea.settingsUnlocked ? "/res/LockOpen.svg" : "/res/pencil.svg"
                mipmap:             true
                width:              ScreenTools.minTouchPixels * 0.75
                height:             width
                sourceSize.width:   width
                color:              qgcPal.text
                fillMode:           Image.PreserveAspectFit

                QGCMouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    valueArea.settingsUnlocked = !valueArea.settingsUnlocked
                }
            }
        }

        QGCMouseArea {
            id:                         mouseArea
            x:                          telemetryLayout.x
            y:                          telemetryLayout.y
            width:                      telemetryLayout.width
            height:                     telemetryLayout.height
            hoverEnabled:               !ScreenTools.isMobile
            propagateComposedEvents:    true

            onClicked: {
                if (ScreenTools.isMobile && !valueArea.settingsUnlocked) {
                    valueArea.settingsUnlocked = true
                    mouse.accepted = true
                } else {
                    mouse.accepted = false
                }
            }
        }

        HorizontalFactValueGrid {
            id:                     valueArea
            userSettingsGroup:      telemetryBarUserSettingsGroup
            defaultSettingsGroup:   telemetryBarDefaultSettingsGroup
        }

        GuidedActionConfirm {
            Layout.fillWidth: true
            guidedController: _guidedController
            guidedValueSlider: _guidedValueSlider
        }
    }
}
