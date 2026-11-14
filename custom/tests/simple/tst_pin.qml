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
    readonly property var st: QGroundControl.corePlugin.settings
    function resetSettings() {
        st.simpleAdminPin.rawValue = "000000"
        st.simpleAdminFailures.rawValue = 0
        st.simpleAdminLockUntil.rawValue = 0
    }
    // New dialog instance = what the app does after a restart (state comes only from the settings)
    function restart() {
        var d = createTemporaryObject(dlgComp, root)
        spy.target = d; spy.clear(); d.open("advanced")
        return d
    }
    function init() {
        resetSettings()
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
    function test_invalid_stored_pin_falls_back_to_default_data() {
        return [ { tag: "4 digits", v: "1234" }, { tag: "7 digits", v: "1234567" }, { tag: "letters", v: "abc 한글" },
                 { tag: "empty", v: "" }, { tag: "number 0", v: 0 }, { tag: "spaces", v: " 12345" },
                 { tag: "undefined", v: undefined } ]
    }
    function test_invalid_stored_pin_falls_back_to_default(d) {
        st.simpleAdminPin.rawValue = d.v
        var x = restart()
        compare(String(st.simpleAdminPin.rawValue), "000000", "damaged PIN is reset in the settings")
        for (var i = 0; i < 6; i++) x._press("0")
        compare(spy.count, 1, "default PIN opens Advanced mode")
    }
    function test_numeric_six_digit_pin_still_works() {
        st.simpleAdminPin.rawValue = 482915      // stored as a number
        var x = restart()
        "482915".split("").forEach(function(c) { x._press(c) })
        compare(spy.count, 1)
    }
    // ---- lock kept over restarts
    function test_lock_survives_restart() {
        for (var i = 0; i < 5; i++) type("111111")
        verify(Number(st.simpleAdminLockUntil.rawValue) > Date.now(), "lock end time stored")
        var x = restart()
        verify(x.locked, "a new instance (restart) is still locked")
        "000000".split("").forEach(function(c) { x._press(c) })
        compare(spy.count, 0, "correct PIN refused after restart while locked")
        verify(x.error.indexOf("5") >= 0, "shows the minutes left: " + x.error)
    }
    function test_failures_survive_restart() {
        for (var i = 0; i < 3; i++) type("111111")
        compare(Number(st.simpleAdminFailures.rawValue), 3)
        var x = restart()
        compare(x.failures, 3)
        "222222".split("").forEach(function(c) { x._press(c) })
        verify(x.error.indexOf("1") >= 0, "1 try left: " + x.error)
        "333333".split("").forEach(function(c) { x._press(c) })
        verify(x.locked, "restarting does not give 5 new tries")
    }
    function test_expired_lock_cleared_on_restart() {
        st.simpleAdminFailures.rawValue = 5
        st.simpleAdminLockUntil.rawValue = Date.now() - 1000
        var x = restart()
        verify(!x.locked); compare(x.failures, 0)
        compare(Number(st.simpleAdminLockUntil.rawValue), 0)
        "000000".split("").forEach(function(c) { x._press(c) })
        compare(spy.count, 1)
    }
    function test_clock_set_back_caps_lock() {
        st.simpleAdminFailures.rawValue = 5
        st.simpleAdminLockUntil.rawValue = Date.now() + 24 * 3600 * 1000   // clock was a day ahead when locking
        var x = restart()
        verify(x.locked)
        verify(Number(st.simpleAdminLockUntil.rawValue) <= Date.now() + 5 * 60 * 1000 + 50, "never longer than 5 min")
    }
    function test_count_reached_without_stored_lock() {
        st.simpleAdminFailures.rawValue = 5          // app killed between the two writes
        st.simpleAdminLockUntil.rawValue = 0
        var x = restart()
        verify(x.locked)
    }
    function test_garbage_lock_values() {
        st.simpleAdminFailures.rawValue = "abc"
        st.simpleAdminLockUntil.rawValue = "xyz"
        var x = restart()
        verify(!x.locked); compare(x.failures, 0)
        st.simpleAdminFailures.rawValue = -7
        x = restart(); compare(x.failures, 0)
        st.simpleAdminFailures.rawValue = 999
        x = restart(); verify(x.locked, "huge count is treated as the limit")
    }
    function test_correct_pin_clears_stored_count() {
        type("111111"); type("000000")
        compare(Number(st.simpleAdminFailures.rawValue), 0)
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
            resetSettings()
            var d = createTemporaryObject(dlgComp, root); spy.target = d; spy.clear(); d.open("advanced")
            var typed = ""
            for (var i = 0; i < 40; i++) {
                var k = keys[Math.floor(Math.random() * keys.length)]
                var before = d.entered
                d._press(k)
                verify(d.entered.length <= 6, "entry never longer than 6")
                verify(d.failures <= 5, "failures capped at 5")
                compare(Number(st.simpleAdminFailures.rawValue), d.failures, "stored count follows the dialog")
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
