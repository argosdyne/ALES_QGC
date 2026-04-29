import QtQuick          2.11
import QGroundControl.Controls          1.0
import QGroundControl.Palette           1.0
import QGroundControl.ScreenTools       1.0

Item {
    id: selectItem
    property bool enableRectangle: true
    property bool enablePoint: true
    property bool busy: pointAnimationGroup.running || animationGroup.running
    readonly property int joystickMoveSpeed: 16
    readonly property real touchPointScale: 0.04 //for ScaleAnimator
    readonly property real rangeRectScale: 0.5 //for ScaleAnimator
    property real rangeRectSize: 0.3 //really Scale
    property real offset_x: selectItem.width * rangeRectSize * rangeRectScale * 0.5
    property real offset_y: selectItem.height * rangeRectSize * rangeRectScale * 0.5

    signal touchPressAndHold(real x, real y)
    signal touchWithPointed(real x, real y)
    signal touchWithRectangled(real x1, real y1, real x2, real y2)
    signal touchDoubleClicked(real x, real y)

    Rectangle{
        id: touchPoint
        transformOrigin: Item.Center
        color: "#9022D700"
        opacity: 0
        radius: width / 2

        SequentialAnimation {
            id: pointAnimationGroup
            OpacityAnimator { target: touchPoint; duration: 150; from:1; to: 0.6 }
            OpacityAnimator { target: touchPoint; duration: 150; from:0.6; to: 1 }
            OpacityAnimator { target: touchPoint; duration: 150; from:1; to: 0.6 }
            OpacityAnimator { target: touchPoint; duration: 150; from:0.6; to: 1 }
            OpacityAnimator { target: touchPoint; duration: 50;  from:1; to: 0 }
        }

        function restart(x,y) {
            // pointAnimationGroup.stop()
            touchPoint.width = ScreenTools.defaultFontPixelHeight
            touchPoint.height = ScreenTools.defaultFontPixelHeight
            touchPoint.x = x - touchPoint.width * 0.5
            touchPoint.y = y - touchPoint.height * 0.5
            touchPoint.opacity = 1
            // pointAnimationGroup.start()
            pointAnimationGroup.restart()
        }
    }

    Rectangle{
        id: rangeRect
        border.width: 3
        border.color: "red"
        transformOrigin: Item.Center
        color: "#40000000"
        opacity: 0

        SequentialAnimation {
            id: animationGroup
            ScaleAnimator   { target: rangeRect; duration: 200; from:1; to: rangeRectScale }
            OpacityAnimator { target: rangeRect; duration: 150; from:1; to: 0.6 }
            OpacityAnimator { target: rangeRect; duration: 150; from:0.6; to: 1 }
            OpacityAnimator { target: rangeRect; duration: 150; from:1; to: 0.6 }
            OpacityAnimator { target: rangeRect; duration: 150; from:0.6; to: 1 }
            OpacityAnimator { target: rangeRect; duration: 50;  from:1; to: 0 }
        }

        SequentialAnimation {
            id: hightlightGroup
            OpacityAnimator { target: rangeRect; duration: 150; from:1; to: 0.6 }
            OpacityAnimator { target: rangeRect; duration: 150; from:0.6; to: 1 }
            OpacityAnimator { target: rangeRect; duration: 150; from:1; to: 0.6 }
            OpacityAnimator { target: rangeRect; duration: 150; from:0.6; to: 1 }
            OpacityAnimator { target: rangeRect; duration: 50;  from:1; to: 0 }
        }

        function restart(x,y) {
            animationGroup.stop()
            hightlightGroup.stop()
            rangeRect.width = selectItem.width * rangeRectSize
            rangeRect.height = selectItem.height * rangeRectSize
            rangeRect.x = x - rangeRect.width * 0.5
            rangeRect.y = y - rangeRect.height * 0.5
            rangeRect.opacity = 1
            animationGroup.start()
        }

        function hightlight() {
            animationGroup.stop()
            hightlightGroup.stop()
            hightlightGroup.start()
        }

        function showSize(x, y) {
            rangeRect.width = selectItem.width * rangeRectSize
            rangeRect.height = selectItem.height * rangeRectSize
            rangeRect.x = x - rangeRect.width * 0.5
            rangeRect.y = y - rangeRect.height * 0.5
            rangeRect.opacity = 1
        }
    }

    function touchPointTrack(x,y) {
        touchPoint.restart(x,y)
        touchWithPointed(x / selectItem.width,
                         y / selectItem.height)
    }

    function rangeRectTrackWithoutSize(x,y) {
        rangeRect.restart(x,y)
        touchWithRectangled((x - offset_x) / selectItem.width,
                            (y - offset_y) / selectItem.height,
                            (x + offset_x) / selectItem.width,
                            (y + offset_y) / selectItem.height)
    }

    function rangeRectTrack() {
        if(rangeRect.width > ScreenTools.defaultFontPixelHeight && rangeRect.height > ScreenTools.defaultFontPixelHeight) {
            rangeRect.hightlight()
            touchWithRectangled(rangeRect.x / selectItem.width,
                                rangeRect.y / selectItem.height,
                                (rangeRect.x + rangeRect.width) / selectItem.width,
                                (rangeRect.y + rangeRect.height) / selectItem.height)
        } else {
            touchPressAndHold(rangeRect.x / selectItem.width, rangeRect.y / selectItem.height)
            rangeRect.width = rangeRect.height = 0
            rangeRect.opacity = 0
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        // Keep MouseArea enabled so the 2nd tap of a double-click is never
        // dropped while click animations are running.
        enabled: true
        preventStealing: true
        pressAndHoldInterval: enableRectangle ? 350 : 800
        property bool isPressAndHold: false
        onClicked: {
            if(selectItem.busy) return
            if(!enablePoint) return
            touchPointTrack(mouseX, mouseY)
        }
        onPressed: {
            if(selectItem.busy) return
            if(!enableRectangle) return
            isPressAndHold = false
            rangeRect.x = mouseX
            rangeRect.y = mouseY
        }
        onPressAndHold: {
            if(selectItem.busy) return
            if(!enableRectangle) {
                touchPressAndHold(mouseX / selectItem.width, mouseY / selectItem.height)
                return
            }
            isPressAndHold = true
            rangeRect.width = rangeRect.height = 0
            rangeRect.opacity = 1
        }
        onPositionChanged: {
            if(!enableRectangle || !isPressAndHold) return
            if(rangeRect.opacity == 1 && !hightlightGroup.running && !animationGroup.running) {
                rangeRect.width = Math.abs(mouseX - rangeRect.x)
                rangeRect.height = Math.abs(mouseY - rangeRect.y)
            }
        }
        onReleased: {
            if(!enableRectangle || !isPressAndHold) return
            if(rangeRect.opacity == 1 && !hightlightGroup.running && !animationGroup.running) {
                rangeRectTrack()
            }
        }
        onDoubleClicked: {
            touchDoubleClicked(mouseX, mouseY)
        }
    }
}
