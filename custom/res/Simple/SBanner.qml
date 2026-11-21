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
    property var    actions:    []      // several choices (S36 obstacle: Go around · Return home · Hold here); the last one is light
    property string holdText:   ""      // hold-to-run action left of the button (S102: hold to stop the LiDAR)
    signal action()
    signal held()
    signal actionAt(int index)

    // the banner column can narrow the banners (bannerWidth) when a panel is open on the right (Tuleap bug #28587)
    // When the buttons leave less than 360 px for the text (narrow banner next to a panel, 4:3 screen), the buttons move
    // to their own row under the text (code review 2026-11-21). The banner is never narrower than its buttons.
    readonly property real _btnsW: (hold.visible ? hold.width + SimpleTheme.px(16) : 0) + (btn.visible ? btn.width : 0)
                                   + (multi.visible ? multi.width : 0)
    readonly property real _textW: width - SimpleTheme.px(26 + 56 + 22 + 22 + 20) - _btnsW
    readonly property bool _stack: _btnsW > 0 && _textW < SimpleTheme.px(360)
    width:  Math.max(parent && parent.bannerWidth > 0 ? parent.bannerWidth : SimpleTheme.px(1395), _btnsW + SimpleTheme.px(40))
    height: _stack ? txt.height + SimpleTheme.px(16 + 12 + 80 + 16)
                   : Math.max(SimpleTheme.px(120), txt.height + SimpleTheme.px(32))     // a long detail wraps to 2 lines
    radius: SimpleTheme.px(20)
    color:  level === "danger" ? SimpleTheme.danger : level === "warn" ? SimpleTheme.warn : SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.97)
    readonly property color _fg: level === "warn" ? SimpleTheme.bgBase : SimpleTheme.textPrimary

    MouseArea { anchors.fill: parent }
    SIcon {
        id: ic
        anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(26)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: bn._stack ? -(SimpleTheme.px(80 + 12) / 2) : 0
        name: bn.icon; size: 56; color: bn._fg
    }
    Column {
        id: txt
        anchors.left: ic.right; anchors.leftMargin: SimpleTheme.px(22)
        anchors.right: bn._stack ? parent.right : hold.visible ? hold.left : btn.visible ? btn.left : multi.visible ? multi.left : parent.right
        anchors.rightMargin: SimpleTheme.px(22)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: bn._stack ? -(SimpleTheme.px(80 + 12) / 2) : 0
        SText { width: parent.width; text: bn.title; size: 32; bold: true; color: bn._fg }
        SText { width: parent.width; text: bn.detail; size: 24; color: bn._fg; visible: text !== ""
                wrapMode: Text.WordWrap; maximumLineCount: 2 }
    }
    SHoldButton {
        id: hold
        visible: bn.holdText !== ""
        anchors.right: btn.visible ? btn.left : multi.visible ? multi.left : parent.right; anchors.rightMargin: SimpleTheme.px(btn.visible || multi.visible ? 16 : 20)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: bn._stack ? (parent.height - SimpleTheme.px(80)) / 2 - SimpleTheme.px(16) : 0
        width: implicitWidth
        designHeight: 80
        fillColor: SimpleTheme.bgBase
        text: bn.holdText
        onActivated: bn.held()
    }
    SButton {
        id: btn
        visible: bn.actionText !== ""
        anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(20)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: bn._stack ? (parent.height - SimpleTheme.px(80)) / 2 - SimpleTheme.px(16) : 0
        designHeight: 80
        fillColor: bn.level === "info" ? SimpleTheme.brandGreen : SimpleTheme.textPrimary
        textColor: bn.level === "info" ? SimpleTheme.textPrimary : SimpleTheme.bgBase
        text: bn.actionText
        textSize: 26
        onClicked: bn.action()
    }
    Row {
        id: multi
        visible: bn.actions.length > 0
        anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(20)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: bn._stack ? (parent.height - SimpleTheme.px(80)) / 2 - SimpleTheme.px(16) : 0
        spacing: SimpleTheme.px(16)
        Repeater {
            model: bn.actions
            SButton {
                readonly property bool _last: index === bn.actions.length - 1
                designHeight: 80; textSize: 26
                fillColor: _last ? SimpleTheme.textPrimary : SimpleTheme.withAlpha(SimpleTheme.bgBase, 0.85)
                textColor: _last ? SimpleTheme.bgBase : SimpleTheme.textPrimary
                text: modelData
                onClicked: bn.actionAt(index)
            }
        }
    }
}
