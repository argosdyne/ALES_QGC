import QtQuick          2.11
import QtQuick.Controls 2.4

import QGroundControl.Palette           1.0
import QGroundControl.Controls          1.0
import QGroundControl.ScreenTools       1.0

Rectangle {
    id: root
    property bool checked: false
    property alias source: thermometryImage.source
    property alias size: thermometryImage.width

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    height: thermometryImage.height + ScreenTools.defaultFontPixelWidth
    width: thermometryImage.width + ScreenTools.defaultFontPixelWidth
    color: checked ? qgcPal.buttonHighlight : "transparent"
    radius: 2

    signal clicked()

    QGCColoredImage {
        id: thermometryImage
        anchors.centerIn: parent
        width:              ScreenTools.defaultFontPixelWidth * 4
        height:             width
        sourceSize.height:  width
        fillMode:           Image.PreserveAspectFit
        color:              qgcPal.text
        MouseArea {
            anchors.fill: parent
            anchors.margins: -ScreenTools.defaultFontPixelWidth * 0.5
            onClicked: {
                root.clicked()
            }
        }
    }
}
