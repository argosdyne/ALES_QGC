/****************************************************************************
 * AQGC Simple UI — centred modal sheet (Figma S67 / S81–S90 pattern): dim 60 %, surface, radius 28, padding 36/40,
 * title 36 bold, optional subtitle 24 and step dots. Children go into a Column (spacing 16).
 ****************************************************************************/
import QtQuick 2.12
import QtQuick.Controls 2.12
import "."

Popup {
    id: sh
    property string title: ""
    property string subtitle: ""
    property int    steps: 0         // > 0: step dots
    property int    step: 0
    property real   designWidth: 1000
    property bool   closeOnOutside: false
    default property alias content: body.data
    readonly property real innerWidth: width - leftPadding - rightPadding

    parent: Overlay.overlay
    modal: true
    focus: true
    closePolicy: closeOnOutside ? (Popup.CloseOnEscape | Popup.CloseOnPressOutside) : Popup.CloseOnEscape
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.max(SimpleTheme.px(16), Math.round((parent.height - height) / 2)) : 0
    width: Math.min(SimpleTheme.px(designWidth), parent ? parent.width - SimpleTheme.px(32) : SimpleTheme.px(designWidth))
    topPadding: SimpleTheme.px(36); bottomPadding: SimpleTheme.px(36)
    leftPadding: SimpleTheme.px(40); rightPadding: SimpleTheme.px(40)
    background: Rectangle { color: SimpleTheme.surfaceRaised; radius: SimpleTheme.px(28); border.width: SimpleTheme.px(2); border.color: SimpleTheme.line }
    Overlay.modal: Rectangle { color: "#99000000" }

    // taller than the window: the content scrolls (buttons stay reachable)
    contentItem: Flickable {
        implicitHeight: Math.min(sheetCol.height, (sh.parent ? sh.parent.height : SimpleTheme.px(1080)) - SimpleTheme.px(32) - sh.topPadding - sh.bottomPadding)
        contentHeight: sheetCol.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        Column {
            id: sheetCol
            width: sh.innerWidth
            spacing: SimpleTheme.px(16)
            SText { width: parent.width; text: sh.title; size: 36; bold: true; wrapMode: Text.WordWrap }
            Row {
                visible: sh.steps > 0
                spacing: SimpleTheme.px(10)
                Repeater {
                    model: sh.steps
                    Rectangle { width: SimpleTheme.px(index === sh.step ? 48 : 16); height: SimpleTheme.px(16); radius: height / 2
                                color: index <= sh.step ? SimpleTheme.ok : SimpleTheme.line }
                }
            }
            SText { visible: text !== ""; width: parent.width; text: sh.subtitle; size: 24; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap }
            Column {
                id: body
                width: parent.width
                spacing: SimpleTheme.px(16)
            }
        }
    }
}
