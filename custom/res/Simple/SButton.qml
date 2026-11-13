import QtQuick 2.12
import "."

// Rounded button. kind: "primary" | "secondary" | "danger" | "ghost"
Rectangle {
    id: control
    property string text:       ""
    property string icon:       ""
    property string kind:       "secondary"
    property real   designHeight: 96
    property real   textSize:   28
    property bool   enabled_:   true
    property color  textColor:  kind === "danger" ? SimpleTheme.textDanger : SimpleTheme.textPrimary
    property color  fillColor:  kind === "primary" ? SimpleTheme.brandGreen
                              : kind === "danger"  ? SimpleTheme.withAlpha(SimpleTheme.danger, 0.18)
                              : kind === "ghost"   ? "transparent"
                              : SimpleTheme.surfaceControl
    signal clicked()

    implicitWidth:  row.implicitWidth + SimpleTheme.px(56)
    implicitHeight: SimpleTheme.px(designHeight)
    radius:         SimpleTheme.px(20)
    opacity:        enabled_ ? 1 : 0.4
    color:          mouse.pressed ? Qt.darker(fillColor, 1.25) : fillColor
    border.width:   kind === "ghost" ? SimpleTheme.px(2) : 0
    border.color:   SimpleTheme.line

    Row {
        id: row
        anchors.centerIn: parent
        spacing: SimpleTheme.px(12)
        SIcon {
            visible: control.icon !== ""
            name: control.icon
            size: 32
            color: control.textColor
            anchors.verticalCenter: parent.verticalCenter
        }
        SText {
            text: control.text
            size: control.textSize
            bold: true
            color: control.textColor
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: control.enabled_
        onClicked: control.clicked()
    }
}
