// SimplePinDialog (S12): 6-digit admin PIN, 5 wrong tries = 5 min lock
import QtQuick 2.12
import QtTest 1.12
import QGroundControl 1.0
import "../../res/Simple"

Item {
    id: root
    width: 1920; height: 1080

TestCase {
    id: tc
    name: "SimplePinDialog"
    when: windowShown

    Component { id: dlgComp; SimplePinDialog { width: 1920; height: 1080 } }
    SignalSpy { id: spy; signalName: "accepted" }

    property var dlg: null
    function init() {
        QGroundControl.corePlugin.settings.simpleAdminPin.rawValue = "000000"
        dlg = createTemporaryObject(dlgComp, root)
        spy.target = dlg; spy.clear()
        dlg.open("advanced")
    }
    function type(s) { for (var i = 0; i < s.length; i++) dlg._press(s[i]) }
    function lockTimer() {
        for (var i = 0; i < dlg.resources.length; i++)
            if (dlg.resources[i].interval !== undefined) return dlg.resources[i]
        return null
    }

    // ---- basic
    function test_default_pin_accepted() {
        type("000000")
        compare(spy.count, 1)
        compare(spy.signalArguments[0][0], "advanced")
        verify(!dlg.opened)
    }
    function test_purpose_passed() {
        dlg.open("setup"); type("000000")
        compare(spy.signalArguments[0][0], "setup")
    }
    function test_backspace() {
        type("12"); dlg._press("back"); compare(dlg.entered, "1")
        dlg._press("back"); dlg._press("back"); compare(dlg.entered, "", "backspace on empty is harmless")
    }
    function test_wrong_then_right() {
        type("123456")
        compare(dlg.failures, 1); compare(dlg.entered, ""); verify(dlg.error.indexOf("4") >= 0, dlg.error)
        type("000000")
        compare(spy.count, 1); compare(dlg.failures, 0)
    }
    function test_custom_pin() {
        QGroundControl.corePlugin.settings.simpleAdminPin.rawValue = "482915"
        type("000000"); compare(spy.count, 0)
        type("482915"); compare(spy.count, 1)
    }
    // ---- lock
    function test_five_wrong_locks() {
        for (var i = 0; i < 5; i++) type("111111")
        verify(dlg.locked); compare(dlg.failures, 5)
        type("000000")
        compare(spy.count, 0, "correct PIN must be refused while locked")
        compare(dlg.entered, "", "input ignored while locked")
        var t = lockTimer(); verify(t); compare(t.interval, 300000); verify(t.running)
    }
    function test_lock_expires() {
        for (var i = 0; i < 5; i++) type("111111")
        var t = lockTimer(); t.stop(); t.interval = 50; t.start()
        tryVerify(function() { return !dlg.locked }, 2000)
        compare(dlg.failures, 0); compare(dlg.error, "")
        type("000000"); compare(spy.count, 1)
    }
    function test_four_wrong_not_locked() {
        for (var i = 0; i < 4; i++) type("999999")
        verify(!dlg.locked); type("000000"); compare(spy.count, 1)
    }
    function test_lock_survives_close_reopen() {
        for (var i = 0; i < 5; i++) type("111111")
        dlg.close(); dlg.open("advanced")
        verify(dlg.locked, "closing and reopening the dialog must not clear the lock")
        type("000000"); compare(spy.count, 0)
    }
    // ---- abnormal
    function test_more_than_six_digits_ignored() {
        type("0000001")   // 7th press goes to a fresh entry after the accept
        compare(spy.count, 1)
    }
    function test_stored_pin_wrong_length() {
        QGroundControl.corePlugin.settings.simpleAdminPin.rawValue = "1234"
        type("123400"); compare(spy.count, 0)
        // A PIN that is not 6 digits can never be entered: documents the risk if the setting is edited by hand
        expectFail("", "4-digit stored PIN cannot be typed on a 6-digit keypad")
        type("1234"); compare(spy.count, 1)
    }
    function test_stored_pin_numeric_type() {
        QGroundControl.corePlugin.settings.simpleAdminPin.rawValue = 0   // e.g. settings file holds a number
        type("000000")
        expectFail("", "numeric 0 becomes \"0\", so 000000 is refused")
        compare(spy.count, 1)
    }
    function test_open_resets_entry_but_not_failures() {
        type("111111"); type("12")
        dlg.open("advanced")
        compare(dlg.entered, ""); compare(dlg.failures, 1, "failures carry over between openings")
    }
    // ---- random / stress
    function test_random_presses_invariants() {
        var keys = ["0","1","2","3","4","5","6","7","8","9","back"]
        for (var run = 0; run < 300; run++) {
            var d = createTemporaryObject(dlgComp, root); spy.target = d; spy.clear(); d.open("advanced")
            var typed = ""
            for (var i = 0; i < 40; i++) {
                var k = keys[Math.floor(Math.random() * keys.length)]
                var before = d.entered
                d._press(k)
                verify(d.entered.length <= 6, "entry never longer than 6")
                verify(d.failures <= 5, "failures capped at 5")
                if (d.locked) verify(d.entered === "", "no entry while locked")
                if (spy.count > 0) { compare(before + k, "000000", "accepted only on the exact PIN"); break }
            }
            d.destroy()
        }
    }
    function test_stress_many_attempts() {
        for (var i = 0; i < 4; i++) type("123123")
        for (var n = 0; n < 10000; n++) dlg._press(String(n % 10))
        verify(dlg.locked)
        compare(spy.count, 0)
    }
    // ---- UI: keypad taps go through the same path
    function test_tap_background_closes() {
        verify(dlg.visible)
        mouseClick(dlg, 10, 10)        // tap on the dimmed background closes the dialog
        verify(!dlg.opened)
    }
}
}
