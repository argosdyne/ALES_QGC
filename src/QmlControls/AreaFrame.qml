import QtQuick          2.11
import QtQuick.Controls 2.4

import QGroundControl.Palette           1.0
import QGroundControl.Controls          1.0
import QGroundControl.ScreenTools       1.0

Item {
    property color color: "white"
    property alias icon: image.source
    property real radius: 1
    property real lineHFactor: 0.2
    property real lineVFactor: 0.2
    property real lineWidth: 2

    QGCColoredImage {
        id: image
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: ScreenTools.defaultFontPixelWidth * 0.5
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.5
        width:              parent.height * (parent.lineHFactor + 0.1)
        height:             width
        sourceSize.height:  width
        fillMode:           Image.PreserveAspectFit
        color:              parent.color
    }

    Rectangle {
        anchors.left:   parent.left
        anchors.top:    parent.top
        width:          parent.lineWidth
        height:         parent.height * parent.lineVFactor
        color:          parent.color
        radius:         parent.radius
    }
    Rectangle {
        anchors.left:   parent.left
        anchors.top:    parent.top
        width:          parent.width * parent.lineHFactor
        height:         parent.lineWidth
        color:          parent.color
        radius:         parent.radius
    }

    Rectangle {
        anchors.right:  parent.right
        anchors.top:    parent.top
        width:          parent.lineWidth
        height:         parent.height * parent.lineVFactor
        color:          parent.color
        radius:         parent.radius
    }
    Rectangle {
        anchors.right:  parent.right
        anchors.top:    parent.top
        width:          parent.width * parent.lineHFactor
        height:         parent.lineWidth
        color:          parent.color
        radius:         parent.radius
    }

    Rectangle {
        anchors.left:   parent.left
        anchors.bottom: parent.bottom
        width:          parent.lineWidth
        height:         parent.height * parent.lineVFactor
        color:          parent.color
        radius:         parent.radius
    }
    Rectangle {
        anchors.left:   parent.left
        anchors.bottom: parent.bottom
        width:          parent.width * parent.lineHFactor
        height:         parent.lineWidth
        color:          parent.color
        radius:         parent.radius
    }

    Rectangle {
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        width:          parent.lineWidth
        height:         parent.height * parent.lineVFactor
        color:          parent.color
        radius:         parent.radius
    }
    Rectangle {
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        width:          parent.width * parent.lineHFactor
        height:         parent.lineWidth
        color:          parent.color
        radius:         parent.radius
    }
}
