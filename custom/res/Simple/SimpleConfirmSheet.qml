/****************************************************************************
 * AQGC Simple UI — S33-style confirm sheet (Return home / Land): explanation + slide to confirm
 ****************************************************************************/
import QtQuick 2.12
import "."

SPanel {
    id: sheet
    property string icon:       "home"
    property string detail:     ""
    property string note:       ""
    property string slideText:  ""
    signal confirmed()

    width:  SimpleTheme.px(980)
    height: SimpleTheme.px(400)
    titleIcon: icon
    onVisibleChanged: if (visible) slider.reset()

    Column {
        anchors.fill: parent
        spacing: SimpleTheme.px(16)
        SText { width: parent.width; text: sheet.detail; size: 26; wrapMode: Text.WordWrap }
        Row {
            spacing: SimpleTheme.px(10)
            SIcon { name: "info"; size: 28; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            SText { text: sheet.note; size: 22; color: SimpleTheme.textSecondary }
        }
        Item { width: 1; height: SimpleTheme.px(4) }
        SSlideConfirm {
            id: slider
            width: parent.width
            text: sheet.slideText
            onConfirmed: sheet.confirmed()
        }
    }
}
