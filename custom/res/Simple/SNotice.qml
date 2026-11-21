/****************************************************************************
 * AQGC Simple UI — notice box inside a sheet or page (Figma "Warning"): tinted fill 16 %, 2 px border, icon + text 22.
 ****************************************************************************/
import QtQuick 2.12
import "."

Rectangle {
    id: nt
    property string level: "warn"      // warn | danger | info
    property string text: ""
    readonly property color _c: level === "danger" ? SimpleTheme.danger : level === "info" ? SimpleTheme.info : SimpleTheme.warn
    width: parent ? parent.width : SimpleTheme.px(800)
    height: Math.max(SimpleTheme.px(64), tx.height + SimpleTheme.px(28))
    radius: SimpleTheme.px(16)
    color: SimpleTheme.withAlpha(_c, 0.16)
    border.width: SimpleTheme.px(2); border.color: _c
    SIcon { id: ic; name: nt.level === "info" ? "info" : "warn"; size: 30
            anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter }
    SText { id: tx; text: nt.text; size: 22; medium: true; wrapMode: Text.WordWrap
            anchors.left: ic.right; anchors.leftMargin: SimpleTheme.px(12); anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(20)
            anchors.verticalCenter: parent.verticalCenter }
}
