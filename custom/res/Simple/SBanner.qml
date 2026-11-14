/****************************************************************************
 * AQGC Simple UI — top alert banner: title + one-line reason + one action (layer rules 1/3)
 ****************************************************************************/
import QtQuick 2.12
import "."

Rectangle {
    id: bn
    property string level:      "warn"   // warn | danger | info
    property string icon:       "warn"
    property string title:      ""
    property string detail:     ""
    property string actionText: ""
    signal action()

    width:  SimpleTheme.px(1395)
    height: SimpleTheme.px(120)
    radius: SimpleTheme.px(20)
    color:  level === "danger" ? SimpleTheme.danger : level === "warn" ? SimpleTheme.warn : SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.97)
    readonly property color _fg: level === "warn" ? SimpleTheme.bgBase : SimpleTheme.textPrimary

    MouseArea { anchors.fill: parent }
    SIcon {
        id: ic
        anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(26)
        anchors.verticalCenter: parent.verticalCenter
        name: bn.icon; size: 56; color: bn._fg
    }
    Column {
        anchors.left: ic.right; anchors.leftMargin: SimpleTheme.px(22)
        anchors.right: btn.visible ? btn.left : parent.right; anchors.rightMargin: SimpleTheme.px(22)
        anchors.verticalCenter: parent.verticalCenter
        SText { width: parent.width; text: bn.title; size: 32; bold: true; color: bn._fg }
        SText { width: parent.width; text: bn.detail; size: 24; color: bn._fg; visible: text !== "" }
    }
    SButton {
        id: btn
        visible: bn.actionText !== ""
        anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(20)
        anchors.verticalCenter: parent.verticalCenter
        designHeight: 80
        fillColor: bn.level === "info" ? SimpleTheme.brandGreen : SimpleTheme.textPrimary
        textColor: bn.level === "info" ? SimpleTheme.textPrimary : SimpleTheme.bgBase
        text: bn.actionText
        textSize: 26
        onClicked: bn.action()
    }
}
