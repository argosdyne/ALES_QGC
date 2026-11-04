/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick 2.12

import QGroundControl.ScreenTools 1.0

/// North-up compass dial with the vehicle heading arrow and value (Figma "CompassDial / New"),
/// drawn on a 120 x 140 design grid.
Rectangle {
    id: control

    property real heading: 0    // degrees

    implicitWidth:  ScreenTools.defaultFontPixelHeight * 3.16
    implicitHeight: implicitWidth * 140 / 120
    radius:         width * 12 / 120
    color:          Qt.rgba(33 / 255, 37 / 255, 41 / 255, 0.85)

    readonly property real _k:          width / 120
    readonly property real _heading:    isNaN(heading) ? 0 : heading

    Canvas {
        id:             dial
        x:              0
        y:              0
        width:          control.width
        height:         control.width
        onWidthChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            var k = control._k
            ctx.reset()
            ctx.save()
            ctx.scale(k, k)
            ctx.strokeStyle = "white"
            ctx.lineCap = "round"

            ctx.lineWidth = 1.5
            ctx.beginPath()
            ctx.arc(60, 60, 44, 0, 2 * Math.PI)
            ctx.stroke()

            // Ticks every 30 degrees, longer at the cardinal points
            for (var deg = 0; deg < 360; deg += 30) {
                var cardinal = (deg % 90) === 0
                var a = (deg - 90) * Math.PI / 180
                var inner = cardinal ? 35 : 38
                ctx.lineWidth = cardinal ? 2 : 1.5
                ctx.beginPath()
                ctx.moveTo(60 + 44 * Math.cos(a), 60 + 44 * Math.sin(a))
                ctx.lineTo(60 + inner * Math.cos(a), 60 + inner * Math.sin(a))
                ctx.stroke()
            }
            ctx.restore()
        }
    }

    Text {
        x:                      60 * control._k - width / 2
        y:                      15 * control._k
        text:                   qsTr("N")
        color:                  "white"
        font.family:            ScreenTools.demiboldFontFamily
        font.pixelSize:         Math.round(13 * control._k)
    }

    // Vehicle heading arrow, rotated around the dial center
    Canvas {
        id:             arrow
        x:              0
        y:              0
        width:          control.width
        height:         control.width
        rotation:       control._heading
        onWidthChanged: requestPaint()

        onPaint: {
            var ctx = getContext("2d")
            var k = control._k
            ctx.reset()
            ctx.save()
            ctx.scale(k, k)
            ctx.fillStyle = "#2ECC40"
            ctx.strokeStyle = "#0B3D12"
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(60, 36)
            ctx.lineTo(70, 74)
            ctx.lineTo(60, 66)
            ctx.lineTo(50, 74)
            ctx.closePath()
            ctx.fill()
            ctx.stroke()
            ctx.restore()
        }
    }

    Rectangle {
        x:      38 * control._k
        y:      110 * control._k
        width:  44 * control._k
        height: 24 * control._k
        radius: 4 * control._k
        color:  "black"

        Text {
            anchors.centerIn:   parent
            text:               Math.round((control._heading % 360 + 360) % 360)
            color:              "white"
            font.family:        ScreenTools.demiboldFontFamily
            font.pixelSize:     Math.round(14 * control._k)
        }
    }
}
