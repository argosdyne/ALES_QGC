import QtQuick 2.12
import "."

Text {
    property real   size:   26
    property bool   bold:   false
    property bool   medium: false
    color:              SimpleTheme.textPrimary
    font.family:        SimpleTheme.fontFamily
    font.pixelSize:     SimpleTheme.fs(size)
    font.weight:        bold ? Font.Bold : (medium ? Font.Medium : Font.Normal)
    elide:              Text.ElideRight
    verticalAlignment:  Text.AlignVCenter
}
