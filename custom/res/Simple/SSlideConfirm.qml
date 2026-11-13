import QtQuick 2.12
import "."

// "Slide to confirm" track (Figma S03/S33/S38). Emits confirmed() when the knob reaches the end.
Rectangle {
    id: slide
    property string text: ""
    signal confirmed()

    height: SimpleTheme.px(96)
    radius: SimpleTheme.px(48)
    color:  SimpleTheme.surfaceControl

    function reset() { knob.x = SimpleTheme.px(6) }

    SText {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: SimpleTheme.px(40)
        text: slide.text
        size: 28
        medium: true
        color: SimpleTheme.textSecondary
        opacity: 1 - (knob.x / Math.max(1, slide.width - knob.width))
    }
    Rectangle {
        id: knob
        x: SimpleTheme.px(6)
        y: SimpleTheme.px(6)
        width:  SimpleTheme.px(156)
        height: parent.height - SimpleTheme.px(12)
        radius: height / 2
        color:  SimpleTheme.brandGreen
        SIcon { anchors.centerIn: parent; name: "chevron"; size: 40 }
        Behavior on x { enabled: !drag.drag.active; NumberAnimation { duration: 150 } }
        MouseArea {
            id: drag
            anchors.fill: parent
            drag.target: knob
            drag.axis: Drag.XAxis
            drag.minimumX: SimpleTheme.px(6)
            drag.maximumX: slide.width - knob.width - SimpleTheme.px(6)
            onReleased: {
                if (knob.x >= drag.drag.maximumX - SimpleTheme.px(8)) {
                    slide.confirmed()
                }
                slide.reset()
            }
        }
    }
}
