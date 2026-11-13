import QtQuick 2.12
import "."

// Settings row: title + one-line description on the left, control on the right (Figma S09/S45)
Rectangle {
    id: row
    property string title:  ""
    property string sub:    ""
    property bool   locked: false
    property string lockReason: ""
    default property alias control: ctl.data

    width:  parent ? parent.width : 0
    height: Math.max(SimpleTheme.px(116), txt.implicitHeight + SimpleTheme.px(36))
    radius: SimpleTheme.px(20)
    color:  SimpleTheme.surfaceRaised

    Column {
        id: txt
        anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(28)
        anchors.right: ctl.left; anchors.rightMargin: SimpleTheme.px(24)
        anchors.verticalCenter: parent.verticalCenter
        SText { width: parent.width; text: row.title; size: 30; medium: true }
        SText { width: parent.width; text: row.locked && row.lockReason !== "" ? row.lockReason : row.sub; size: 24; color: row.locked ? SimpleTheme.warn : SimpleTheme.textSecondary; visible: text !== ""; wrapMode: Text.WordWrap; maximumLineCount: 2 }
    }
    Item {
        id: ctl
        anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(20)
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width; height: childrenRect.height
        opacity: row.locked ? 0.4 : 1
        enabled: !row.locked
    }
}
