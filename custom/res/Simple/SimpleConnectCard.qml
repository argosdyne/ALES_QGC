/****************************************************************************
 * AQGC Simple UI — S01 connecting to drone
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

SPanel {
    width:  SimpleTheme.px(760)
    height: SimpleTheme.px(470)
    closable: false
    title: qsTr("Connecting to your drone…")
    titleIcon: "drone"

    Column {
        anchors.fill: parent
        spacing: SimpleTheme.px(20)
        Repeater {
            model: [
                qsTr("1  Turn on the controller and the radio"),
                qsTr("2  Turn on the drone and wait for the lights"),
                qsTr("3  The app connects automatically")
            ]
            SText { text: modelData; size: 28; color: SimpleTheme.textSecondary }
        }
        Item { width: 1; height: SimpleTheme.px(10) }
        Row {
            spacing: SimpleTheme.px(16)
            SButton { text: qsTr("Connection help"); icon: "help"; onClicked: simpleRoot.showSettings("about") }
            SButton { text: qsTr("Connection settings"); icon: "link"; onClicked: simpleRoot.showSettings("connection") }
        }
    }
}
