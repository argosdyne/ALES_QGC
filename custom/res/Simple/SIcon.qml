import QtQuick 2.12
import QGroundControl.Controls 1.0
import "."

// Line icon from qrc:/simple/icons, tinted with `color`
QGCColoredImage {
    property string name:   ""
    property real   size:   48
    width:              SimpleTheme.px(size)
    height:             width
    sourceSize.width:   width
    sourceSize.height:  height
    source:             name ? "qrc:/simple/icons/" + name + ".svg" : ""
    color:              SimpleTheme.textPrimary
    fillMode:           Image.PreserveAspectFit
    smooth:             true
}
