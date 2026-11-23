import QtQuick 2.12
import "."

// Status chip (Figma S66, 00 Overview §10): tinted background + icon, text in the normal text colour.
// level: ok (green, protected) | warn (orange, action needed) | danger (red) | info (blue, cannot be changed) | off
Rectangle {
    id: chip
    property string text:  ""
    property string level: "off"
    readonly property color _c: level === "ok" ? SimpleTheme.ok : level === "warn" ? SimpleTheme.warn
                              : level === "danger" ? SimpleTheme.danger : level === "info" ? SimpleTheme.info
                              : SimpleTheme.textTertiary
    height: SimpleTheme.px(48); radius: height / 2
    width: row.implicitWidth + SimpleTheme.px(32)
    color: SimpleTheme.withAlpha(_c, 0.22)
    Row {
        id: row
        anchors.centerIn: parent
        spacing: SimpleTheme.px(8)
        SIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: chip.level === "ok" ? "check" : chip.level === "info" ? "info" : chip.level === "off" ? "info" : "warn"
            size: 28; color: chip._c
        }
        SText { anchors.verticalCenter: parent.verticalCenter; text: chip.text; size: 22; medium: true }
    }
}
