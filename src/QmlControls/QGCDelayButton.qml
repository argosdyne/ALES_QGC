import QtQuick           2.12
import QtQuick.Controls  2.5

import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0

DelayButton{
    id: item
    clip: true
    delay: 1000
    implicitWidth: ScreenTools.defaultFontPixelWidth * 8
    implicitHeight: ScreenTools.defaultFontPixelWidth * 8
    property bool isMapButton: false
    property bool autoReset: true
    property var _qgcPal: QGCPalette { colorGroupEnabled: item.enabled }
    property bool _showHighlight: (pressed | hovered | checked | autoStartNumberAnimation.running | autoStopNumberAnimation.running)
    property int __lastGlobalMouseX:    0
    property int __lastGlobalMouseY:    0
    property real autoProgress: 0
    property string iconSource

    function autoStart() {
        autoStopNumberAnimation.stop()
        autoStartNumberAnimation.restart()
    }

    function autoStop() {
        autoStartNumberAnimation.stop()
        if(autoProgress !== 1) autoStopNumberAnimation.restart()
    }

    NumberAnimation on autoProgress {
        id: autoStartNumberAnimation
        running: false
        duration: item.delay * (1 - autoProgress)
        to: 1
        onFinished: activated()
    }

    NumberAnimation on autoProgress {
        id: autoStopNumberAnimation
        running: false
        duration: 200
        to: 0
    }

    background: Rectangle {
        id: foreGroundRect
        implicitWidth: ScreenTools.defaultFontPixelWidth * 8
        implicitHeight: ScreenTools.defaultFontPixelWidth * 8
        opacity: enabled ? 1 : 0.3
        color: _showHighlight ? (isMapButton ? item._qgcPal.mapButtonHighlight : item._qgcPal.buttonHighlight)
                              : (isMapButton ? item._qgcPal.mapButton : item._qgcPal.button)
        radius: size / 2

        readonly property real size: Math.min(item.width, item.height)
        width: size
        height: size
        anchors.centerIn: parent

        SequentialAnimation {
            id: hightlightGroup
            OpacityAnimator { target:foreGroundRect; from:1; to: 0.3; duration: 250 }
            OpacityAnimator { target:foreGroundRect; from:0.3; to: 1; duration: 250 }
            OpacityAnimator { target:foreGroundRect; from:1; to: 0.3; duration: 250 }
            OpacityAnimator { target:foreGroundRect; from:0.3; to: 1; duration: 250 }
            onFinished: {
                autoProgress = 0
                item.checked = !autoReset
            }
        }

        Canvas {
            id: canvas
            anchors.fill: parent

            Connections {
                target: item
                onProgressChanged: canvas.requestPaint()
                onActivated: hightlightGroup.restart()
                onAutoProgressChanged: canvas.requestPaint()
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = item._qgcPal.colorGreen
                ctx.lineWidth = parent.size / 20
                ctx.beginPath()
                var startAngle = Math.PI / 5 * 3
                var endAngle = startAngle + Math.max(item.progress, autoProgress) * Math.PI / 5 * 9
                ctx.arc(width / 2, height / 2, width / 2 - ctx.lineWidth / 2 - 2, startAngle, endAngle)
                ctx.stroke()
            }
        }
    }


    contentItem: Item {
        implicitWidth:          text.implicitWidth + icon.width
        implicitHeight:         text.implicitHeight
        baselineOffset:         text.y + text.baselineOffset

        QGCColoredImage {
            id:                     icon
            source:                 item.iconSource
            height:                 text.text.length ? item.height * 0.4 : item.height * 0.6
            width:                  height
            color:                  text.color
            fillMode:               Image.PreserveAspectFit
            sourceSize.height:      height
            anchors.centerIn:       parent
            anchors.verticalCenterOffset: text.text.length ? -item.height * 0.07 : 0
            visible:                status === Image.Ready
        }

        Text {
            id:                     text
            anchors.centerIn:       parent
            anchors.verticalCenterOffset: icon.status === Image.Ready ? item.height * 0.2 : 0
            antialiasing:           true
            text:                   item.text
            font.pointSize:         icon.status === Image.Ready ? ScreenTools.smallFontPointSize : ScreenTools.defaultFontPointSize
            font.family:            ScreenTools.normalFontFamily
            color:                  _showHighlight ? item._qgcPal.buttonHighlightText : item._qgcPal.buttonText
        }
    }
}
