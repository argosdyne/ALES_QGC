import QtQuick 2.12
import "."

// Top-bar status chip: icon + value + label (Figma ui/StatusChip). level: ok | warn | danger | off
Rectangle {
    id: chip
    property string icon:   ""
    property string value:  ""
    property string label:  ""
    property string level:  "ok"
    signal clicked()

    readonly property color _levelColor: level === "danger" ? SimpleTheme.danger
                                       : level === "warn"   ? SimpleTheme.warn
                                       : level === "off"    ? SimpleTheme.textTertiary
                                       : SimpleTheme.ok

    implicitWidth:  row.implicitWidth + SimpleTheme.px(32)
    height:         SimpleTheme.px(72)
    radius:         SimpleTheme.px(16)
    color:          level === "danger" ? SimpleTheme.danger
                  : level === "warn"   ? SimpleTheme.withAlpha(SimpleTheme.warn, 0.25)
                  : SimpleTheme.surfaceRaised

    Row {
        id: row
        anchors.centerIn: parent
        spacing: SimpleTheme.px(12)
        SIcon {
            name: chip.icon
            size: 36
            color: chip.level === "danger" ? SimpleTheme.textPrimary : chip._levelColor
            anchors.verticalCenter: parent.verticalCenter
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            SText { text: chip.value; size: 28; bold: true }
            SText { text: chip.label; size: 22; color: chip.level === "danger" ? SimpleTheme.textPrimary : SimpleTheme.textSecondary }
        }
    }
    MouseArea { anchors.fill: parent; onClicked: chip.clicked() }
}
