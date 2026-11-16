/****************************************************************************
 * AQGC Simple UI — S12 admin PIN (6 digits, 5 wrong tries = 5 min lock)
 * The wrong-try count and the lock end time are stored in the settings, so restarting the app
 * does not clear the lock. The PIN is stored as a PBKDF2 hash (corePlugin.simplePinHash, SimplePinHash.h);
 * a plain 6-digit PIN from an older version is replaced by its hash on start. A stored value that is neither
 * is replaced by the hash of the default PIN.
 * purpose "change" (Advanced › Settings › General): current PIN → new PIN → new PIN again.
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

Item {
    id: dlg
    property bool   opened:     false
    property string entered:    ""
    property string purpose:    "advanced"   // advanced | setup | change
    property string stage:      "enter"      // enter (current PIN) | new | confirm (purpose change)
    property string _newPin:    ""
    property int    failures:   0
    property bool   locked:     false
    property string error:      ""
    signal accepted(string purpose)
    signal pinChanged()

    readonly property int    maxTries:      5
    readonly property real   lockMs:        5 * 60 * 1000
    readonly property string defaultPin:    "000000"
    readonly property var    _cp:           QGroundControl.corePlugin
    readonly property var    _s:            _cp.settings

    function validPin(p)  { return /^[0-9]{6}$/.test(p) }
    function _stored()    { var v = _s.simpleAdminPin.rawValue; return v === undefined || v === null ? "" : String(v) }
    function _check(pin)  { return _cp.simplePinCheck(pin, _stored()) }
    function _now()       { return Date.now() }      // tests override this

    function open(p) { purpose = p || "advanced"; stage = "enter"; _newPin = ""; entered = ""; error = ""; _refreshLock(); opened = true }
    function close() { opened = false; stage = "enter"; _newPin = ""; entered = "" }

    // Restore the lock from the settings. A lock end time further away than lockMs means the clock was
    // set back: never lock longer than lockMs from now.
    function _refreshLock() {
        // another dialog instance (Simple root / Advanced settings popup) may have counted wrong tries meanwhile
        failures = Math.min(maxTries, Math.max(0, Number(_s.simpleAdminFailures.rawValue) || 0))
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
        if (entered.length !== 6) return
        if (stage === "new") {
            if (entered === defaultPin) { error = qsTr("Choose a PIN other than %1").arg(defaultPin); entered = ""; return }
            _newPin = entered; entered = ""; error = ""; stage = "confirm"
            return
        }
        if (stage === "confirm") {
            if (entered === _newPin) {
                _s.simpleAdminPin.rawValue = _cp.simplePinHash(_newPin)
                close(); pinChanged()
            } else {
                _newPin = ""; entered = ""; stage = "new"
                error = qsTr("The PINs do not match — enter the new PIN again")
            }
            return
        }
        {
            if (_check(entered)) {
                failures = 0; _s.simpleAdminFailures.rawValue = 0
                if (purpose === "change") { entered = ""; error = ""; stage = "new"; return }
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
        // A hand-edited or damaged value would lock everyone out: fall back to the default PIN.
        // A plain PIN (older versions) is replaced by its hash.
        var v = _stored()
        if (validPin(v)) {
            _s.simpleAdminPin.rawValue = _cp.simplePinHash(v)
        } else if (!_cp.simplePinIsHash(v)) {
            console.warn("SimplePinDialog: stored admin PIN is not valid, reset to default")
            _s.simpleAdminPin.rawValue = _cp.simplePinHash(defaultPin)
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
        title:  dlg.stage === "new" ? qsTr("New admin PIN") : dlg.stage === "confirm" ? qsTr("New PIN again")
              : dlg.purpose === "change" ? qsTr("Current admin PIN") : qsTr("Enter admin PIN")
        titleIcon: "lock"
        onCloseRequested: dlg.close()

        Column {
            anchors.fill: parent
            spacing: SimpleTheme.px(18)
            SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                    text: dlg.stage === "new" ? qsTr("6 digits. Write it down: without it Advanced mode cannot be opened.")
                        : dlg.stage === "confirm" ? qsTr("Enter the new PIN once more.")
                        : dlg.purpose === "change" ? qsTr("Enter the current PIN to change it.")
                        : dlg.purpose === "setup" ? qsTr("Vehicle setup needs Advanced mode.") : qsTr("Advanced mode shows all alesQGC screens.") }
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
            // the error line always keeps its height, so the keys do not move under the finger when it appears
            SText { anchors.horizontalCenter: parent.horizontalCenter; text: dlg.error !== "" ? dlg.error : " "; size: 24; color: SimpleTheme.textDanger }
            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 3
                spacing: SimpleTheme.px(14)
                Repeater {
                    model: ["1","2","3","4","5","6","7","8","9","","0","back"]
                    Rectangle {
                        width: SimpleTheme.px(160); height: SimpleTheme.px(104); radius: SimpleTheme.px(20)
                        // the empty key keeps its place (an invisible item would be skipped by the Grid: 0 moved left)
                        opacity: modelData === "" ? 0 : dlg.locked ? 0.4 : 1
                        color: ma.pressed ? Qt.darker(SimpleTheme.surfaceControl, 1.3) : SimpleTheme.surfaceControl
                        SText { anchors.centerIn: parent; visible: modelData !== "back"; text: modelData; size: 40; bold: true }
                        SIcon { anchors.centerIn: parent; visible: modelData === "back"; name: "backspace"; size: 44 }
                        MouseArea { id: ma; anchors.fill: parent; enabled: modelData !== ""; onClicked: dlg._press(modelData) }
                    }
                }
            }
            SText { anchors.horizontalCenter: parent.horizontalCenter; visible: dlg.purpose !== "change"
                    text: qsTr("The app returns to Simple mode when it restarts."); size: 22; color: SimpleTheme.textTertiary }
        }
    }
}
