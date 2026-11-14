import QtQuick 2.12
import "."

// Left-side flight action: 96 px round button with label (Figma ui/ActionButton)
Item {
    id: control
    property string text:   ""
    property string icon:   ""
    property color  fill:   SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
    property bool   enabled_: true
    signal clicked()

    width:  SimpleTheme.px(140)
    height: SimpleTheme.px(148)
    opacity: enabled_ ? 1 : 0.4

    Rectangle {
        id: circle
        anchors.horizontalCenter: parent.horizontalCenter
        width:  SimpleTheme.px(112)
        height: width
        radius: width / 2
        color:  mouse.pressed ? Qt.darker(control.fill, 1.3) : control.fill
        border.width: SimpleTheme.px(2)
        border.color: SimpleTheme.line
        SIcon { anchors.centerIn: parent; name: control.icon; size: 48 }
    }
    SText {
        anchors.top: circle.bottom
        anchors.topMargin: SimpleTheme.px(8)
        anchors.horizontalCenter: parent.horizontalCenter
        text: control.text
        size: 22
        medium: true
        style: Text.Raised
        styleColor: SimpleTheme.withAlpha("black", 0.7)
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: control.enabled_
        onClicked: control.clicked()
    }
}
