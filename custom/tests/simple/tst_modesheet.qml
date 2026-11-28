// S28 / S79 flight mode sheet: a mode the drone answers with "No such mode" is hidden for that drone (Tuleap bug #8378)
import QtQuick 2.12
import QtTest 1.12
import QGroundControl 1.0
import "../../res/Simple"

Item {
    id: root
    width: 1920; height: 1080

    Component {
        id: vehComp
        QtObject {
            property var    flightModes: ["Stabilize", "Altitude Hold", "Loiter", "RTL", "Land", "Auto", "Guided", "Slow"]
            property string flightMode: "Loiter"
            // like a drone that refuses the mode: the reported mode stays the old one
            property bool   refuseModes: false
            property string _lastMode: "Loiter"
            onFlightModeChanged: { if (refuseModes) { if (flightMode !== _lastMode) flightMode = _lastMode } else _lastMode = flightMode }
            signal textMessageReceived(int uasid, int componentid, int severity, string text, string description)
        }
    }
    Component { id: sheetComp; SimpleModeSheet { } }
    Component { id: spyComp; SignalSpy { } }

TestCase {
    id: tc
    name: "SimpleModeSheet"
    when: windowShown

    property var v: null
    property var s: null
    function init() {
        QGroundControl.corePlugin.advancedMode = true
        v = createTemporaryObject(vehComp, root)
        s = createTemporaryObject(sheetComp, root, { vehicle: v })
    }
    function cleanup() { QGroundControl.corePlugin.advancedMode = false }

    function _availNames() {
        var out = []
        var all = s._groups.concat(s._others.length ? [{ modes: s._others }] : [])
        for (var g = 0; g < all.length; g++)
            for (var m = 0; m < all[g].modes.length; m++) {
                var n = all[g].modes[m].n
                if (v.flightModes.indexOf(n) !== -1 && !s._refused[n]) out.push(n)
            }
        return out
    }

    // Figma S79 note 2026-11-28: Slow (mode 30) is listed until the firmware has SLOW_ON; old firmware hides it
    function test_slow_listed_until_refused() {
        verify(_availNames().indexOf("Slow") !== -1)
        var spy = createTemporaryObject(spyComp, tc, { target: s, signalName: "modeRefused" })
        v.refuseModes = true
        s._pick({ n: "Slow", t: "Slow", d: "" })
        v.textMessageReceived(1, 1, 4, "No such mode 30", "")
        compare(spy.count, 1)
        verify(_availNames().indexOf("Slow") === -1)
    }
    function test_refused_mode_is_hidden() {
        var spy = createTemporaryObject(spyComp, tc, { target: s, signalName: "modeRefused" })
        verify(_availNames().indexOf("Guided") !== -1)
        v.refuseModes = true
        s._pick({ n: "Guided", t: "Guided", d: "" })
        compare(v.flightMode, "Loiter", "the drone did not take it")
        wait(0)
        v.textMessageReceived(1, 1, 4, "No such mode 4", "")
        compare(spy.count, 1)
        compare(spy.signalArguments[0][0], "Guided")
        verify(_availNames().indexOf("Guided") === -1, "Guided hidden for this drone")
        verify(_availNames().indexOf("Loiter") !== -1)
    }
    function test_text_without_request_or_late_is_ignored() {
        var spy = createTemporaryObject(spyComp, tc, { target: s, signalName: "modeRefused" })
        v.textMessageReceived(1, 1, 4, "No such mode 30", "")         // nothing asked
        compare(spy.count, 0)
        s._pick({ n: "Guided", t: "Guided", d: "" })
        s._askedAt = Date.now() - 6000                                 // answer after 5 s: not this request
        v.textMessageReceived(1, 1, 4, "No such mode 4", "")
        compare(spy.count, 0)
        s._pick({ n: "Guided", t: "Guided", d: "" })
        v.textMessageReceived(1, 1, 4, "Mode change to Guided failed: requires position", "")   // other refusal
        compare(spy.count, 0)
        verify(_availNames().indexOf("Guided") !== -1)
    }
    // code review: "No such mode 30" from an RC switch after a successful change does not hide the asked mode
    function test_other_mode_number_or_success_ignored() {
        var spy = createTemporaryObject(spyComp, tc, { target: s, signalName: "modeRefused" })
        s._pick({ n: "Guided", t: "Guided", d: "" })                     // Guided = 4
        v.textMessageReceived(1, 1, 4, "No such mode 30", "")         // another number: not this request
        compare(spy.count, 0)
        verify(_availNames().indexOf("Guided") !== -1)
        v.flightMode = "Stabilize"
        s._pick({ n: "Loiter", t: "Position hold", d: "" })              // the drone takes it
        tryCompare(s, "_asked", "", 1000, "the drone took Loiter: nothing is waited for")
        v.textMessageReceived(1, 1, 4, "No such mode 5", "")
        compare(spy.count, 0)
        verify(_availNames().indexOf("Loiter") !== -1)
    }
    function test_simple_choice_and_other_drone() {
        QGroundControl.corePlugin.advancedMode = false
        compare(s._available(["Altitude Hold", "AltHold"]), "Altitude Hold")
        v.refuseModes = true
        s._setMode("Altitude Hold", "Altitude hold")
        v.textMessageReceived(1, 1, 4, "No such mode 2", "")
        compare(s._available(["Altitude Hold", "AltHold"]), "", "hidden in the Simple choice too")
        s.vehicle = createTemporaryObject(vehComp, root)                  // another drone starts clean
        compare(s._available(["Altitude Hold", "AltHold"]), "Altitude Hold")
    }
}
}
