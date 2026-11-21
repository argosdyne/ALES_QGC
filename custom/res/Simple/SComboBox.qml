import QtQuick 2.12
import QtQuick.Controls 2.12
import "."

// Drop-down list in the Simple style (Settings › General language, first-start welcome)
ComboBox {
    id: box
    property real designWidth: 338

    width:  SimpleTheme.px(designWidth)
    height: SimpleTheme.px(80)
    font.pixelSize: SimpleTheme.fs(26)

    background: Rectangle {
        radius: SimpleTheme.px(16)
        color:  SimpleTheme.surfaceControl
        border.width: SimpleTheme.px(2)
        border.color: box.visualFocus ? SimpleTheme.info : SimpleTheme.line
    }
    contentItem: SText {
        leftPadding:  SimpleTheme.px(20)
        rightPadding: SimpleTheme.px(56)
        text: box.displayText
        size: 26
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: SIcon {
        x: box.width - width - SimpleTheme.px(18)
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron"; size: 28; rotation: 90
        color: SimpleTheme.textSecondary
    }
    delegate: ItemDelegate {
        width:  box.width
        height: SimpleTheme.px(64)
        highlighted: box.highlightedIndex === index
        background: Rectangle { color: highlighted ? SimpleTheme.brandGreenDark : SimpleTheme.surfaceRaised }
        contentItem: SText { text: modelData; size: 24; verticalAlignment: Text.AlignVCenter; leftPadding: SimpleTheme.px(8) }
    }
    popup.background: Rectangle { color: SimpleTheme.surfaceRaised; radius: SimpleTheme.px(12); border.color: SimpleTheme.line }
}
