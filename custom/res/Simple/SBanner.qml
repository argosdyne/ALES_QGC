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
    // to a row under the text; if the hold button and the other buttons do not fit on one row either, the hold button
    // gets a row of its own (code reviews 2026-11-21). So the banner keeps the column width (bannerWidth).
    readonly property real _baseW: parent && parent.bannerWidth > 0 ? parent.bannerWidth : SimpleTheme.px(1395)
    readonly property real _holdW: hold.visible ? hold.implicitWidth : 0
    // natural width of the action buttons (itemAt() has no notify signal: recomputed when items come, go or resize)
    property real _multiNat: 0
    function _recalcMulti() {
        var w = 0
        for (var i = 0; i < multiRep.count; i++) { var it = multiRep.itemAt(i); if (it) w += it.implicitWidth }
        _multiNat = w + Math.max(0, multiRep.count - 1) * SimpleTheme.px(16)
    }
    readonly property real _rowW:  (btn.visible ? btn.implicitWidth : 0) + (multi.visible ? _multiNat : 0)
    readonly property real _btnsW: _holdW + (_holdW > 0 && _rowW > 0 ? SimpleTheme.px(16) : 0) + _rowW
    readonly property real _textW: _baseW - SimpleTheme.px(26 + 56 + 22 + 22 + 20) - _btnsW
    readonly property bool _stack: _btnsW > 0 && _textW < SimpleTheme.px(360)
    readonly property bool _stack2: _stack && _holdW > 0 && _rowW > 0 && _btnsW + SimpleTheme.px(40) > _baseW
    readonly property int  _rows: _stack2 ? 2 : _stack ? 1 : 0
    // the action buttons share the row when they are wider than the banner (e.g. 3 actions next to a panel)
    readonly property bool _squeeze: _stack && multi.visible && _rowW + SimpleTheme.px(40) > _baseW
    readonly property real _squeezeW: Math.floor((_baseW - SimpleTheme.px(40) - Math.max(0, multiRep.count - 1) * SimpleTheme.px(16))
                                                 / Math.max(1, multiRep.count))
    width:  Math.max(_baseW, _holdW + SimpleTheme.px(40))
    height: _stack ? txt.height + SimpleTheme.px(32 + 92 * _rows)
                   : Math.max(SimpleTheme.px(120), txt.height + SimpleTheme.px(32))     // a long detail wraps to 2 lines
    radius: SimpleTheme.px(20)
    color:  level === "danger" ? SimpleTheme.danger : level === "warn" ? SimpleTheme.warn : SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.97)
    readonly property color _fg: level === "warn" ? SimpleTheme.bgBase : SimpleTheme.textPrimary

    MouseArea { anchors.fill: parent }
    SIcon {
        id: ic
        anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(26)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -SimpleTheme.px(92) * bn._rows / 2
        name: bn.icon; size: 56; color: bn._fg
    }
    Column {
        id: txt
        anchors.left: ic.right; anchors.leftMargin: SimpleTheme.px(22)
        anchors.right: bn._stack ? parent.right : hold.visible ? hold.left : btn.visible ? btn.left : multi.visible ? multi.left : parent.right
        anchors.rightMargin: SimpleTheme.px(22)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -SimpleTheme.px(92) * bn._rows / 2
        SText { width: parent.width; text: bn.title; size: 32; bold: true; color: bn._fg }
        SText { width: parent.width; text: bn.detail; size: 24; color: bn._fg; visible: text !== ""
                wrapMode: Text.WordWrap; maximumLineCount: 2 }
    }
    SHoldButton {
        id: hold
        visible: bn.holdText !== ""
        anchors.right: bn._stack2 ? parent.right : btn.visible ? btn.left : multi.visible ? multi.left : parent.right
        anchors.rightMargin: SimpleTheme.px(!bn._stack2 && (btn.visible || multi.visible) ? 16 : 20)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: bn._stack ? (parent.height - SimpleTheme.px(80)) / 2 - SimpleTheme.px(16) - (bn._stack2 ? SimpleTheme.px(92) : 0) : 0
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
            id: multiRep
            model: bn.actions
            onItemAdded: bn._recalcMulti()
            onItemRemoved: Qt.callLater(bn._recalcMulti)
            SButton {
                readonly property bool _last: index === bn.actions.length - 1
                width: bn._squeeze ? bn._squeezeW : implicitWidth
                onImplicitWidthChanged: bn._recalcMulti()
                designHeight: 80; textSize: 26
                fillColor: _last ? SimpleTheme.textPrimary : SimpleTheme.withAlpha(SimpleTheme.bgBase, 0.85)
                textColor: _last ? SimpleTheme.bgBase : SimpleTheme.textPrimary
                text: modelData
                onClicked: bn.actionAt(index)
            }
        }
    }
}
