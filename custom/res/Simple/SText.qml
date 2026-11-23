import QtQuick 2.12
import "."

Text {
    property real   size:   26
    property bool   bold:   false
    property bool   medium: false
    // < 1: a label with a fixed width shrinks to fit it, down to this share of its size (long translations,
    // TASK-i18n-five-languages.md §3.5: 0.8 = the 80 % minimum), then elides
    property real   fitMin: 1
    color:              SimpleTheme.textPrimary
    font.family:        (medium && !bold) ? SimpleTheme.fontFamilyMedium : SimpleTheme.fontFamily
    font.pixelSize:     SimpleTheme.fs(size)
    font.weight:        bold ? Font.Bold : (medium ? Font.Medium : Font.Normal)
    fontSizeMode:       fitMin < 1 ? Text.HorizontalFit : Text.FixedSize
    minimumPixelSize:   Math.max(1, Math.round(font.pixelSize * fitMin))
    elide:              Text.ElideRight
    verticalAlignment:  Text.AlignVCenter
}
