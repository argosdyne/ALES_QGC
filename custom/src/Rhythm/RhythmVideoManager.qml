import QtQuick 2.15
import QtQuick.Controls 2.15
import QtMultimedia 5.15
import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controllers   1.0

Item {
    id: root
    anchors.fill: parent

    property var detectionObjects: []

    // Class colors (customize as needed)
    property var typeColors: {
        0: "red",    // person
        64: "green", // other type
        8: "blue",   // another type
        32: "yellow" // another type
    }


    // Create rectangles for each detection
    Repeater {
        id: detectionRepeater
        model: Rhythm.detectionObjects // Direct binding to C++ property

        Rectangle {
            // Convert normalized coordinates to pixel coordinates based on the video output size
            x: parent.width * modelData.x
            y: parent.height * modelData.y
            width: parent.width * modelData.width
            height: parent.height * modelData.height

            color: "transparent"
            border.color: root.typeColors[modelData.type] || "white"
            border.width: 2

            // Display detection information
            Text {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 2
                text: "Type: " + modelData.type + " (" + Math.round(modelData.score * 100) + "%)"
                color: parent.border.color
                font.pixelSize: Math.max(parent.width, parent.height) * 0.1
                font.bold: true
                style: Text.Outline
                styleColor: "red"
            }
        }
    }
    // Debug text - helpful for troubleshooting
    Text {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        text: "Detection count: " + detectionRepeater.count
        color: "white"
        font.pixelSize: 14
        style: Text.Outline
        styleColor: "black"
        visible: true // Set to false in production
    }
}
