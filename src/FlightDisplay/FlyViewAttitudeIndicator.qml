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

/// Round attitude indicator (Figma "AttitudeIndicator / New"), drawn on a 180 x 180 design grid.
/// Sky and ground, pitch ladder and the roll pointer move with the vehicle; the bank scale,
/// top index and aircraft symbol are fixed.
Item {
    id: control

    property real roll:     0   // degrees, right wing down positive
    property real pitch:    0   // degrees, nose up positive

    implicitWidth:  ScreenTools.defaultFontPixelHeight * 4.74
    implicitHeight: implicitWidth

    readonly property real _rollClamped:    isNaN(roll) ? 0 : roll
    readonly property real _pitchClamped:   isNaN(pitch) ? 0 : Math.max(-60, Math.min(60, pitch))

    on_RollClampedChanged:  canvas.requestPaint()
    on_PitchClampedChanged: canvas.requestPaint()
    onWidthChanged:         canvas.requestPaint()

    Canvas {
        id:             canvas
        anchors.fill:   parent

        readonly property color _sky:       "#3B8EDB"
        readonly property color _ground:    "#8A6A44"
        readonly property color _symbol:    "#FFC107"
        readonly property color _bezel:     "#1F2328"
        readonly property real  _pxPerDeg:  3      // design: 10 degrees = 30 px

        onPaint: {
            var ctx = getContext("2d")
            var k = width / 180
            ctx.reset()
            ctx.save()
            ctx.scale(k, k)

            // Moving part, clipped to the dial
            ctx.save()
            ctx.beginPath()
            ctx.arc(90, 90, 87, 0, 2 * Math.PI)
            ctx.clip()
            ctx.translate(90, 90)
            ctx.rotate(-control._rollClamped * Math.PI / 180)
            ctx.translate(0, control._pitchClamped * _pxPerDeg)

            ctx.fillStyle = _sky
            ctx.fillRect(-200, -400, 400, 400)
            ctx.fillStyle = _ground
            ctx.fillRect(-200, 0, 400, 400)

            ctx.strokeStyle = "white"
            ctx.lineWidth = 2
            ctx.beginPath()
            ctx.moveTo(-200, 0)
            ctx.lineTo(200, 0)
            ctx.stroke()

            // Pitch ladder: long lines with labels every 10 degrees, short lines at the 5s. Only rungs
            // near the dial center are drawn, so the ladder stays clear of the bank scale.
            ctx.fillStyle = "white"
            ctx.font = "bold 13px \"" + ScreenTools.demiboldFontFamily + "\""
            ctx.textAlign = "center"
            ctx.textBaseline = "middle"
            for (var deg = -30; deg <= 30; deg += 5) {
                if (deg === 0) {
                    continue
                }
                var y = -deg * _pxPerDeg
                if (Math.abs(y + control._pitchClamped * _pxPerDeg) > 50) {
                    continue
                }
                var major = (deg % 10) === 0
                var half = major ? 24 : 10
                ctx.lineWidth = major ? 2 : 1.5
                ctx.beginPath()
                ctx.moveTo(-half, y)
                ctx.lineTo(half, y)
                ctx.stroke()
                if (major) {
                    ctx.fillText(deg.toString(), -39, y)
                    ctx.fillText(deg.toString(), 39, y)
                }
            }
            ctx.restore()

            // Roll pointer (rotates with the roll, does not move with the pitch)
            ctx.save()
            ctx.translate(90, 90)
            ctx.rotate(-control._rollClamped * Math.PI / 180)
            ctx.fillStyle = _symbol
            ctx.beginPath()
            ctx.moveTo(0, -70)
            ctx.lineTo(-5, -61)
            ctx.lineTo(5, -61)
            ctx.closePath()
            ctx.fill()
            ctx.restore()

            // Fixed bank scale: 10, 20, 30, 45, 60 degrees on both sides
            ctx.strokeStyle = "white"
            ctx.lineCap = "round"
            var marks = [10, 20, 30, 45, 60]
            for (var i = 0; i < marks.length; i++) {
                var isLong = marks[i] === 30 || marks[i] === 60
                ctx.lineWidth = isLong ? 2.5 : 2
                for (var side = -1; side <= 1; side += 2) {
                    var a = (side * marks[i] - 90) * Math.PI / 180
                    var r1 = 81
                    var r2 = isLong ? 69 : 74
                    ctx.beginPath()
                    ctx.moveTo(90 + r1 * Math.cos(a), 90 + r1 * Math.sin(a))
                    ctx.lineTo(90 + r2 * Math.cos(a), 90 + r2 * Math.sin(a))
                    ctx.stroke()
                }
            }
            // Top index
            ctx.fillStyle = "white"
            ctx.beginPath()
            ctx.moveTo(90, 10)
            ctx.lineTo(84, 0)
            ctx.lineTo(96, 0)
            ctx.closePath()
            ctx.fill()

            // Fixed aircraft symbol
            ctx.strokeStyle = _symbol
            ctx.lineWidth = 4
            ctx.lineJoin = "round"
            ctx.beginPath()
            ctx.moveTo(46, 90)
            ctx.lineTo(76, 90)
            ctx.lineTo(90, 100)
            ctx.lineTo(104, 90)
            ctx.lineTo(134, 90)
            ctx.stroke()
            ctx.fillStyle = _symbol
            ctx.beginPath()
            ctx.arc(90, 90, 3, 0, 2 * Math.PI)
            ctx.fill()

            // Bezel
            ctx.strokeStyle = _bezel
            ctx.lineWidth = 6
            ctx.beginPath()
            ctx.arc(90, 90, 87, 0, 2 * Math.PI)
            ctx.stroke()

            ctx.restore()
        }
    }
}
