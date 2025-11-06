import QtQuick 2.11
import QGroundControl.ScreenTools 1.0

Item {
    id: trackerItem
    property alias model: targetObjectsRepeater.model
    Repeater {
        id: targetObjectsRepeater
        Rectangle{
            id: trackerRect
            visible: object.credibility !== 0
            border.width: 2
            border.color: object.objectColor
            color: "transparent"
            x: object.x * trackerItem.width
            y: object.y * trackerItem.height
            width: object.width * trackerItem.width
            height: object.height * trackerItem.height
            Rectangle{
                id: trackerText
                width: text.width + ScreenTools.defaultFontPixelWidth
                height: text.height
                radius: 1
                color: object.objectColor
                anchors.top: trackerRect.top
                anchors.left: trackerRect.left
                visible: text.text !== ""//object.objectName.length
                Text {
                    id: text
                    anchors.centerIn: parent
                    font.pixelSize: ScreenTools.defaultFontPointSize
                    font.family:    ScreenTools.normalFontFamily
                    color:          "white"
                    antialiasing:   true
                    verticalAlignment: Text.AlignVCenter
                    text: object.name === "tracking_object" ? object.objectName : object.name
                }
            }
        }
    }
}
