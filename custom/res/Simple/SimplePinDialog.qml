/****************************************************************************
 * AQGC Simple UI — S12 admin PIN (6 digits, 5 wrong tries = 5 min lock)
 * The wrong-try count and the lock end time are stored in the settings, so restarting the app
 * does not clear the lock. A stored PIN that is not exactly 6 digits is replaced by the default.
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

    readonly property int    maxTries:      5
    readonly property real   lockMs:        5 * 60 * 1000
    readonly property string defaultPin:    "000000"
    readonly property var    _s:            QGroundControl.corePlugin.settings
    readonly property string _pin:          validPin(String(_s.simpleAdminPin.rawValue)) ? String(_s.simpleAdminPin.rawValue) : defaultPin

    function validPin(p)  { return /^[0-9]{6}$/.test(p) }
    function _now()       { return Date.now() }      // tests override this

    function open(p) { purpose = p || "advanced"; entered = ""; error = ""; _refreshLock(); opened = true }
    function close() { opened = false }

    // Restore the lock from the settings. A lock end time further away than lockMs means the clock was
    // set back: never lock longer than lockMs from now.
    function _refreshLock() {
        var until = Number(_s.simpleAdminLockUntil.rawValue) || 0
        var now = _now()
        if (until > now + lockMs) {
            until = now + lockMs
            _s.simpleAdminLockUntil.rawValue = until
        }
        if (until > now) {
            locked = true
            lockTimer.interval = Math.max(1, until - now)
            lockTimer.restart()
            error = qsTr("Too many wrong PINs — try again in %1 min").arg(Math.ceil((until - now) / 60000))
        } else if (locked || until > 0) {
            _unlock()
        }
    }
    function _unlock() {
        lockTimer.stop()
        locked = false; failures = 0; error = ""
        _s.simpleAdminFailures.rawValue = 0
        _s.simpleAdminLockUntil.rawValue = 0
    }
    function _press(d) {
        if (locked) return
        if (d === "back") { entered = entered.slice(0, -1); return }
        if (entered.length >= 6) return
        entered += d
        if (entered.length === 6) {
            if (entered === _pin) {
                failures = 0; _s.simpleAdminFailures.rawValue = 0
                close(); accepted(purpose)
            } else {
                failures++
                _s.simpleAdminFailures.rawValue = failures
                entered = ""
                if (failures >= maxTries) {
                    _s.simpleAdminLockUntil.rawValue = _now() + lockMs
                    _refreshLock()
                } else {
                    error = qsTr("Wrong PIN — %1 tries left").arg(maxTries - failures)
                }
            }
        }
    }
    Component.onCompleted: {
        // A hand-edited or damaged PIN (not 6 digits) would lock everyone out: fall back to the default
        if (!validPin(String(_s.simpleAdminPin.rawValue))) {
            console.warn("SimplePinDialog: stored admin PIN is not 6 digits, reset to default")
            _s.simpleAdminPin.rawValue = defaultPin
        }
        failures = Math.min(maxTries, Math.max(0, Number(_s.simpleAdminFailures.rawValue) || 0))
        _refreshLock()
        if (failures >= maxTries && !locked) {          // count reached but no lock stored (e.g. app killed in between)
            _s.simpleAdminLockUntil.rawValue = _now() + lockMs
            _refreshLock()
        }
    }
    Timer { id: lockTimer; interval: 5 * 60 * 1000; onTriggered: dlg._unlock() }

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
