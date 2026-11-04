/****************************************************************************
 *
 * LiDAR Setup > Settings
 * Placeholder - scanner / camera parameter page is a separate story.
 *
 ****************************************************************************/

import QtQuick          2.11
import QtQuick.Layouts  1.11

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0

Rectangle {
    color: qgcPal.window

    QGCPalette { id: qgcPal }

    ColumnLayout {
        anchors.left:   parent.left
        anchors.top:    parent.top
        spacing:        ScreenTools.defaultFontPixelHeight * 0.25

        QGCLabel {
            text:           qsTr("Settings")
            font.family:    ScreenTools.demiboldFontFamily
        }

        QGCLabel {
            text:       qsTr("Model: %1").arg(QGroundControl.corePlugin.settings.ysModel.enumStringValue)
            opacity:    0.6
        }

        QGCLabel {
            text:       qsTr("LiDAR scanner / camera settings will be available here.")
            opacity:    0.6
        }
    }
}
