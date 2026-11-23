import QtQuick 2.12
import "."

// Heading dial (Figma S18 video main): N mark turns with the heading, arrow = drone nose, number = heading in degrees
Rectangle {
    id: c
    property real heading: NaN          // degrees, 0 = north
    property real designSize: 148
    width: SimpleTheme.px(designSize); height: width; radius: width / 2
    color: SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
    border.width: SimpleTheme.px(2); border.color: SimpleTheme.line

    // N mark on the rim, rotated so it points to north relative to the drone nose (up)
    Item {
        anchors.fill: parent
        rotation: isNaN(c.heading) ? 0 : -c.heading
        Behavior on rotation { RotationAnimation { duration: 150; direction: RotationAnimation.Shortest } }
        SText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: SimpleTheme.px(8)
            text: "N"; size: 24; bold: true; color: SimpleTheme.textDanger
        }
    }
    // drone nose arrow (always up)
    Canvas {
        id: arrow
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.26
        width: parent.width * 0.26; height: parent.height * 0.34
        onPaint: {
            var g = getContext("2d"); g.reset()
            g.fillStyle = SimpleTheme.info
            g.beginPath(); g.moveTo(width / 2, 0); g.lineTo(width, height); g.lineTo(width / 2, height * 0.78); g.lineTo(0, height); g.closePath(); g.fill()
        }
    }
    SText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(14)
        text: isNaN(c.heading) ? "—" : Math.round((c.heading % 360 + 360) % 360) + "°"
        size: 24; bold: true
    }
}
