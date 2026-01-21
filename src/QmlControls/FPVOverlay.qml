import QtQuick 2.12
import QtQuick.Window 2.2

import QGroundControl 1.0
import QGroundControl.ScreenTools 1.0
import QGroundControl.Controls 1.0
import QGroundControl.Palette 1.0

Item {
    id: _root
    width: _fpvSize
    height: _fpvSize * (9/16)
    visible: item1 && item1.visible && item2 && pipOverlay && show
    enabled: item1 && item1.visible && item2 && pipOverlay
    property var  item1: null    // Required
    property var  item2: null    // Optional, may come and go
    property var  pipOverlay // QGCPipOverlay control
    property real maxSize: 0.75
    property real minSize: 0.10
    property bool show: true

    property bool   _fpvIsItem1: true
    property real   _fpvSize:    parent.width * 0.2
    MouseArea {
        id: moveArea
        anchors.fill: parent
        drag.target: _root
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: _root.parent.width - _root.width
        drag.maximumY: _root.parent.height - _root.height
        onClicked: {
            QGroundControl.saveBoolGlobalSetting(pipOverlay.item1IsFullSettingsKey, false)
            if(_fpvIsItem1) {
                pipOverlay.item2 = item1
                if(item2) {
                    item2.pipState.state = item2.pipState.fpvState
                }
            } else {
                pipOverlay.item2 = item2
                if(item1) {
                    item1.pipState.state = item1.pipState.fpvState
                }
            }
            _fpvIsItem1 = !_fpvIsItem1
        }
    }

//    MouseArea {
//        id: fpvAreaResize
//        anchors.top: parent.top
//        anchors.right: parent.right
//        height: ScreenTools.minTouchPixels
//        width: height
//        property real initialX: 0
//        property real initialWidth: 0

//        onClicked: {
//            // TODO propagate
//        }

//        onDoubleClicked: {

//        }

//        // When we push the mouse button down, we un-anchor the mouse area to prevent a resizing loop
//        onPressed: {
//            fpvAreaResize.anchors.top = undefined // Top doesn't seem to 'detach'
//            fpvAreaResize.anchors.right = undefined // This one works right, which is what we really need
//            fpvAreaResize.initialX = mouse.x
//            fpvAreaResize.initialWidth = _root.width
//        }

//        // When we let go of the mouse button, we re-anchor the mouse area in the correct position
//        onReleased: {
//            fpvAreaResize.anchors.top = fpvResizeIcon.top
//            fpvAreaResize.anchors.right = fpvResizeIcon.right
//        }

//        // Drag
//        onPositionChanged: {
//            if (fpvAreaResize.pressed) {
//                var parentW = _root.parent.width // flightView
//                var newW = fpvAreaResize.initialWidth + mouse.x - fpvAreaResize.initialX
//                if (newW < parentW * _root.maxSize && newW > parentW * _root.minSize) {
//                    var offset = (newW - _root.width) / 1.667
//                    if(_root.y - offset >= 0) {
//                        _root.y -= offset
//                        _root.x = _root.x
//                        _root.width = newW
//                    }
//                }
//            }
//        }
//    }
//    // Resize icon
//    Image {
//        id:             fpvResizeIcon
//        source:         "/qmlimages/pipResize.svg"
//        fillMode:       Image.PreserveAspectFit
//        mipmap: true
//        anchors.right:  parent.right
//        anchors.top:    parent.top
//        visible:        moveArea.containsMouse || (!item2 && _fpvIsItem1)
//        height:         ScreenTools.defaultFontPixelHeight * 2.5
//        width:          ScreenTools.defaultFontPixelHeight * 2.5
//        sourceSize.height:  height
//    }
}
