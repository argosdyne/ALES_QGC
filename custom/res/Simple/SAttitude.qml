import QtQuick 2.12
import QtGraphicalEffects 1.12
import "."

// Attitude indicator (Figma S18 video main): sky / ground disc that tilts with roll and moves with pitch,
// fixed orange line = the drone's wings. Shows a plain grey disc when no data.
Rectangle {
    id: a
    property real roll:  NaN            // degrees, right wing down = positive
    property real pitch: NaN            // degrees, nose up = positive
    property real designSize: 148
    readonly property bool _valid: !isNaN(roll) && !isNaN(pitch)
    width: SimpleTheme.px(designSize); height: width; radius: width / 2
    color: SimpleTheme.surfaceControl
    border.width: SimpleTheme.px(2); border.color: SimpleTheme.line
    clip: true
    // clip to the circle (a Rectangle clip is square)
    layer.enabled: true
    layer.effect: OpacityMask { maskSource: Rectangle { width: a.width; height: a.height; radius: a.width / 2 } }

    Item {
        id: horizon
        visible: a._valid
        anchors.centerIn: parent
        width: parent.width * 2; height: parent.height * 2
        rotation: a._valid ? -a.roll : 0
        // 1 degree of pitch = 1/90 of the radius
        transform: Translate { y: a._valid ? Math.max(-1, Math.min(1, a.pitch / 90)) * a.height / 2 : 0 }
        Rectangle { width: parent.width; height: parent.height / 2; color: "#4a90d9" }
        Rectangle { y: parent.height / 2; width: parent.width; height: parent.height / 2; color: "#7a5a3a" }
        Rectangle { y: parent.height / 2 - 1; width: parent.width; height: 2; color: SimpleTheme.textPrimary; opacity: 0.8 }
    }
    // round mask edge
    Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: SimpleTheme.px(2); border.color: SimpleTheme.line }
    // wings
    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.42; height: SimpleTheme.px(5); radius: height / 2
        color: SimpleTheme.warn
    }
    SText { visible: !a._valid; anchors.centerIn: parent; text: "—"; size: 26; color: SimpleTheme.textSecondary }
}
