/****************************************************************************
 * AQGC Simple UI — S12 admin PIN (6 digits, 5 wrong tries = 5 min lock)
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

Item {
    id: dlg
    property bool   opened:     false
    property string entered:    ""
    property string purpose:    "advanced"   // advanced | setup
    property int    failures:   0
    property bool   locked:     false
    property string error:      ""
    signal accepted(string purpose)

    readonly property string _pin: String(QGroundControl.corePlugin.settings.simpleAdminPin.rawValue)

    function open(p) { purpose = p || "advanced"; entered = ""; error = ""; opened = true }
    function close() { opened = false }
    function _press(d) {
        if (locked) return
        if (d === "back") { entered = entered.slice(0, -1); return }
        if (entered.length >= 6) return
        entered += d
        if (entered.length === 6) {
            if (entered === _pin) { failures = 0; close(); accepted(purpose) }
            else {
                failures++
                entered = ""
                if (failures >= 5) { locked = true; lockTimer.start(); error = qsTr("Too many wrong PINs — try again in 5 minutes") }
                else error = qsTr("Wrong PIN — %1 tries left").arg(5 - failures)
            }
        }
    }
    Timer { id: lockTimer; interval: 5 * 60 * 1000; onTriggered: { dlg.locked = false; dlg.failures = 0; dlg.error = "" } }

    visible: opened
    Rectangle { anchors.fill: parent; color: SimpleTheme.withAlpha("black", 0.6); MouseArea { anchors.fill: parent; onClicked: dlg.close() } }

    SPanel {
        anchors.centerIn: parent
        width:  SimpleTheme.px(640)
        height: SimpleTheme.px(800)
        title:  qsTr("Enter admin PIN")
        titleIcon: "lock"
        onCloseRequested: dlg.close()

        Column {
            anchors.fill: parent
            spacing: SimpleTheme.px(18)
            SText { text: dlg.purpose === "setup" ? qsTr("Vehicle setup needs Advanced mode.") : qsTr("Advanced mode shows all alesQGC screens."); size: 24; color: SimpleTheme.textSecondary }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: SimpleTheme.px(18)
                Repeater {
                    model: 6
                    Rectangle {
                        width: SimpleTheme.px(28); height: width; radius: width / 2
                        color: index < dlg.entered.length ? SimpleTheme.textPrimary : "transparent"
                        border.width: SimpleTheme.px(3); border.color: SimpleTheme.textSecondary
                    }
                }
            }
            SText { anchors.horizontalCenter: parent.horizontalCenter; text: dlg.error; size: 24; color: SimpleTheme.textDanger; visible: text !== "" }
            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 3
                spacing: SimpleTheme.px(14)
                Repeater {
                    model: ["1","2","3","4","5","6","7","8","9","","0","back"]
                    Rectangle {
                        width: SimpleTheme.px(160); height: SimpleTheme.px(104); radius: SimpleTheme.px(20)
                        visible: modelData !== ""
                        opacity: dlg.locked ? 0.4 : 1
                        color: ma.pressed ? Qt.darker(SimpleTheme.surfaceControl, 1.3) : SimpleTheme.surfaceControl
                        SText { anchors.centerIn: parent; visible: modelData !== "back"; text: modelData; size: 40; bold: true }
                        SIcon { anchors.centerIn: parent; visible: modelData === "back"; name: "backspace"; size: 44 }
                        MouseArea { id: ma; anchors.fill: parent; onClicked: dlg._press(modelData) }
                    }
                }
            }
            SText { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("The app returns to Simple mode when it restarts."); size: 22; color: SimpleTheme.textTertiary }
        }
    }
}
