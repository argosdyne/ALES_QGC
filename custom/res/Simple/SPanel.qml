import QtQuick 2.12
import "."

// Glass panel / sheet background with optional title and close button
Rectangle {
    id: panel
    property string title: ""
    property string titleIcon: ""
    property bool   closable: true
    default property alias content: body.data
    property alias  bodyItem: body
    signal closeRequested()

    color:  SimpleTheme.surfaceGlass
    radius: SimpleTheme.px(28)
    border.width: SimpleTheme.px(2)
    border.color: SimpleTheme.line

    // Swallow clicks so the map below does not get them
    MouseArea { anchors.fill: parent; onWheel: wheel.accepted = true }

    Row {
        id: header
        visible: panel.title !== ""
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: SimpleTheme.px(28)
        anchors.topMargin: SimpleTheme.px(24)
        spacing: SimpleTheme.px(14)
        SIcon { visible: panel.titleIcon !== ""; name: panel.titleIcon; size: 40; anchors.verticalCenter: parent.verticalCenter; color: SimpleTheme.ok }
        SText { text: panel.title; size: 34; bold: true; anchors.verticalCenter: parent.verticalCenter }
    }
    SRoundIconButton {
        visible: panel.closable
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: SimpleTheme.px(16)
        designWidth: 80; designHeight: 80
        radius: width / 2
        icon: "close"
        onClicked: panel.closeRequested()
    }
    Item {
        id: body
        anchors.fill: parent
        anchors.leftMargin: SimpleTheme.px(28)
        anchors.rightMargin: SimpleTheme.px(28)
        anchors.bottomMargin: SimpleTheme.px(24)
        anchors.topMargin: panel.title !== "" ? SimpleTheme.px(112) : SimpleTheme.px(24)
    }
}
