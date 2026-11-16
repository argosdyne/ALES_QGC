import QtQuick 2.12
import "."

// "Hold to run" button for risky actions (Figma S10: release hook, drop, stop recording).
// The fill grows while pressed; `activated` fires once after `holdMs`. Releasing early cancels.
Rectangle {
    id: hb
    property string text:       ""
    property int    holdMs:     2000
    property bool   enabled_:   true
    property color  fillColor:  SimpleTheme.danger
    property real   designHeight: 88
    property real   progress:   0
    signal activated()

    implicitWidth:  label.implicitWidth + SimpleTheme.px(56)
    height: SimpleTheme.px(designHeight)
    radius: SimpleTheme.px(16)
    color:  SimpleTheme.withAlpha(fillColor, 0.25)
    border.width: SimpleTheme.px(2); border.color: fillColor
    opacity: enabled_ ? 1 : 0.4
    clip: true

    Rectangle {
        width: parent.width * hb.progress; height: parent.height
        radius: parent.radius
        color: hb.fillColor
    }
    SText { id: label; anchors.centerIn: parent; text: hb.text; size: 26; bold: true }

    NumberAnimation {
        id: fill
        target: hb; property: "progress"; from: 0; to: 1; duration: hb.holdMs
        onFinished: if (ma.pressed) { hb.activated(); hb.progress = 0 }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: hb.enabled_
        onPressed: fill.restart()
        onReleased: { fill.stop(); hb.progress = 0 }
        onCanceled: { fill.stop(); hb.progress = 0 }
    }
}
