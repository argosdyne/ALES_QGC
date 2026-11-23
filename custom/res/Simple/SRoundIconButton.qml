import QtQuick 2.12
import "."

Rectangle {
    id: b
    property string icon: ""
    property real designWidth: 84
    property real designHeight: 80
    property real iconSize: 36
    property bool enabled_: true
    signal clicked()
    width:  SimpleTheme.px(designWidth)
    height: SimpleTheme.px(designHeight)
    radius: SimpleTheme.px(16)
    opacity: enabled_ ? 1 : 0.4
    color:  ma.pressed ? Qt.darker(SimpleTheme.surfaceControl, 1.3) : SimpleTheme.surfaceControl
    SIcon { anchors.centerIn: parent; name: b.icon; size: b.iconSize }
    MouseArea { id: ma; anchors.fill: parent; enabled: b.enabled_; onClicked: b.clicked() }
}
