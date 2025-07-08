import QtQuick            2.12
import QtQuick.Controls   2.5
import QtGraphicalEffects 1.0

BusyIndicator {
    id: busyIndicator
    property color firstColor: "#80c342"
    property color secondColor: "#006325"
    property color pointColor: "#006325"
    visible: running
    contentItem: Item {
        Rectangle {
            id: rect
            width: parent.width
            height: parent.height
            color: Qt.rgba(0, 0, 0, 0)
            radius: width / 2
            border.width: width / 6
            visible: false
        }
        ConicalGradient {
            width: rect.width
            height: rect.height
            gradient: Gradient {
                GradientStop { position: 0.0; color: firstColor }
                GradientStop { position: 1.0; color: secondColor }
            }
            source: rect
            Rectangle {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: rect.border.width
                height: width
                radius: width / 2
                color: pointColor
            }
            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
            }
        }
    }
}
