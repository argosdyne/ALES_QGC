import QtQuick 2.12
import "."

// Segmented control. model: array of strings
Rectangle {
    id: seg
    property var    model:          []
    property int    currentIndex:   0
    property real   designWidth:    300
    signal activated(int index)

    width:  SimpleTheme.px(designWidth)
    height: SimpleTheme.px(80)
    radius: SimpleTheme.px(18)
    color:  SimpleTheme.surfaceControl

    Row {
        anchors.fill: parent
        anchors.margins: SimpleTheme.px(4)
        spacing: SimpleTheme.px(4)
        Repeater {
            model: seg.model
            Rectangle {
                width:  (seg.width - SimpleTheme.px(8) - SimpleTheme.px(4) * (seg.model.length - 1)) / seg.model.length
                height: parent.height
                radius: SimpleTheme.px(14)
                color:  index === seg.currentIndex ? SimpleTheme.brandGreen : "transparent"
                SText {
                    anchors.centerIn: parent
                    width: parent.width - SimpleTheme.px(8)
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    size: 24
                    bold: true
                    color: index === seg.currentIndex ? SimpleTheme.textPrimary : SimpleTheme.textSecondary
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { seg.currentIndex = index; seg.activated(index) }
                }
            }
        }
    }
}
