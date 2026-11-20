import QtQuick 2.12
import "."

// A tap does not change `checked`: it only emits toggled(newValue). Bind `checked` to the real state (device, setting,
// parameter) and write that state in onToggled, so the switch keeps following it (assigning `checked` here broke the
// caller's binding: the searchlight and auto-torque switches stopped following the device after one tap).
Rectangle {
    id: tg
    property bool checked: false
    signal toggled(bool checked)
    width:  SimpleTheme.px(104)
    height: SimpleTheme.px(56)
    radius: height / 2
    color:  checked ? SimpleTheme.brandGreen : SimpleTheme.surfaceControl
    Rectangle {
        width: SimpleTheme.px(44); height: width; radius: width / 2
        y: SimpleTheme.px(6)
        x: tg.checked ? tg.width - width - SimpleTheme.px(6) : SimpleTheme.px(6)
        color: SimpleTheme.textPrimary
        Behavior on x { NumberAnimation { duration: 120 } }
    }
    MouseArea { anchors.fill: parent; anchors.margins: -SimpleTheme.px(20); onClicked: tg.toggled(!tg.checked) }
}
