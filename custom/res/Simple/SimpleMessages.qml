/****************************************************************************
 * AQGC Simple UI — S29 message history (vehicle messages)
 ****************************************************************************/
import QtQuick 2.12
import QtQuick.Controls 2.4
import "."

SPanel {
    id: panel
    property var vehicle: null
    width:  SimpleTheme.px(900)
    height: SimpleTheme.px(780)
    title:  qsTr("Messages")
    titleIcon: "bell"

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.bottomMargin: SimpleTheme.px(100)
        contentHeight: txt.height
        clip: true
        ScrollBar.vertical: ScrollBar {}
        TextEdit {
            id: txt
            width: flick.width
            readOnly: true
            textFormat: TextEdit.RichText
            wrapMode: TextEdit.WordWrap
            color: SimpleTheme.textPrimary
            font.pixelSize: SimpleTheme.fs(22)
            text: panel.vehicle ? panel.vehicle.formattedMessages : ""
        }
    }
    SButton {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        designHeight: 80
        text: qsTr("Clear")
        icon: "trash"
        onClicked: if (panel.vehicle) panel.vehicle.clearMessages()
    }
}
