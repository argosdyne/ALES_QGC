import QtQuick 2.12
import "."

// Payload card (Figma S10): header (icon, name, status pill) + body for up to 3 controls.
Rectangle {
    id: card
    property string icon:   ""
    property string name:   ""
    property string statusText:  ""
    property string statusLevel: "off"      // ok | warn | danger | info | off
    property bool   dim:    false
    default property alias content: body.data

    height: head.height + body.height + SimpleTheme.px(56)
    radius: SimpleTheme.px(20)
    color:  SimpleTheme.surfaceRaised

    Item {
        id: head
        x: SimpleTheme.px(20); y: SimpleTheme.px(18)
        width: card.width - SimpleTheme.px(40); height: SimpleTheme.px(64)
        Rectangle {
            id: iconBox
            width: SimpleTheme.px(64); height: width; radius: SimpleTheme.px(14)
            color: SimpleTheme.surfaceControl
            SIcon { anchors.centerIn: parent; name: card.icon; size: 36 }
        }
        SText {
            anchors.left: iconBox.right; anchors.leftMargin: SimpleTheme.px(16)
            anchors.right: pill.left; anchors.rightMargin: SimpleTheme.px(8)
            anchors.verticalCenter: parent.verticalCenter
            text: card.name; size: 28; bold: true
        }
        Rectangle {
            id: pill
            visible: card.statusText !== ""
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            height: SimpleTheme.px(44); radius: SimpleTheme.px(12)
            width: pillText.implicitWidth + SimpleTheme.px(28)
            color: card.statusLevel === "ok" ? SimpleTheme.ok : card.statusLevel === "warn" ? SimpleTheme.warn
                 : card.statusLevel === "danger" ? SimpleTheme.danger : card.statusLevel === "info" ? SimpleTheme.info : SimpleTheme.surfaceControl
            SText {
                id: pillText; anchors.centerIn: parent; size: 22; medium: true; text: card.statusText
                color: card.statusLevel === "ok" || card.statusLevel === "warn" ? SimpleTheme.bgBase : SimpleTheme.textPrimary
            }
        }
    }
    Column {
        id: body
        x: SimpleTheme.px(20); y: head.y + head.height + SimpleTheme.px(18)
        width: card.width - SimpleTheme.px(40)
        spacing: SimpleTheme.px(12)
        opacity: card.dim ? 0.45 : 1
    }
}
