// MAVLink 2 signing helper (src/comm/MAVLinkSigning, Figma S66): key, fingerprint, timestamp units, link states,
// accept / drop rules. Uses the signingTest hooks of the test runner (main.cpp).
import QtQuick 2.12
import QtTest 1.12

TestCase {
    name: "MAVLinkSigning"

    readonly property int noKey: 0
    readonly property int notProtected: 1
    readonly property int protectedLink: 2
    readonly property int mismatch: 3
    readonly property int heartbeat: 0
    readonly property int radioStatus: 109

    function init() {
        signingTest.removeKey()
        for (var c = 1; c <= 3; c++) signingTest.clearChannel(c)
    }
    function cleanupTestCase() { init() }

    // ---- basic
    function test_fingerprint_and_timestamp() {
        var fp = signingTest.fingerprintOf(7)
        verify(/^[0-9A-F]{4}…[0-9A-F]{4}$/.test(fp), fp)
        verify(signingTest.fingerprintOf(7) !== signingTest.fingerprintOf(8))
        compare(signingTest.fingerprint(), "", "no key, no fingerprint")
        // 10 microsecond units since 2015-01-01
        var expected = (Date.now() - 1420070400000) * 100
        verify(Math.abs(signingTest.timestampNow() - expected) < 100 * 2000, "timestamp in 10 us units")
    }
    function test_pairing_states() {
        signingTest.setKey(7)
        verify(signingTest.hasKey())
        compare(signingTest.fingerprint(), signingTest.fingerprintOf(7))
        signingTest.initChannel(1)
        compare(signingTest.state(1), notProtected, "key here, drone not paired yet")
        verify(signingTest.feed(1, heartbeat, 0), "unpaired drone: unsigned packets accepted")
        compare(signingTest.state(1), notProtected)
        verify(signingTest.feed(1, heartbeat, 7), "packet signed with our key")
        compare(signingTest.state(1), protectedLink)
    }
    function test_protected_link_drops() {
        signingTest.setKey(7); signingTest.initChannel(1)
        signingTest.feed(1, heartbeat, 7)
        compare(signingTest.state(1), protectedLink)
        verify(!signingTest.feed(1, heartbeat, 0), "unsigned packet dropped on a protected link")
        verify(signingTest.feed(1, radioStatus, 0), "RADIO_STATUS from the radio is accepted unsigned")
        verify(!signingTest.feed(1, heartbeat, 9), "packet signed with another key dropped")
        verify(signingTest.feed(1, heartbeat, 7), "our key still accepted")
        compare(signingTest.state(1), protectedLink, "stays protected")
    }
    // ---- abnormal
    function test_key_mismatch() {
        signingTest.setKey(7); signingTest.initChannel(1)
        verify(signingTest.feed(1, heartbeat, 9), "not paired: telemetry still shown")
        compare(signingTest.state(1), mismatch, "the drone signs with another key")
        verify(signingTest.feed(1, heartbeat, 7))
        compare(signingTest.state(1), protectedLink, "after the drone takes our key")
    }
    function test_no_key_but_drone_signs() {
        signingTest.initChannel(2)
        compare(signingTest.state(2), noKey)
        verify(signingTest.feed(2, heartbeat, 0))
        compare(signingTest.state(2), noKey, "unsigned drone, no key: no warning")
        verify(signingTest.feed(2, heartbeat, 9), "signed by a drone paired elsewhere: shown")
        compare(signingTest.state(2), mismatch, "but it ignores our unsigned commands")
    }
    // review of the SITL run 2026-11-17: a drone without GPS time lets its signing clock fall behind
    function test_drone_clock_behind() {
        signingTest.setKey(7); signingTest.initChannel(1)
        verify(signingTest.feed(1, heartbeat, 7, 300), "5 minutes behind: still our key")
        compare(signingTest.state(1), protectedLink, "a slow drone clock is not a key mismatch")
        verify(signingTest.feed(1, heartbeat, 7, 600), "telemetry keeps flowing")
    }
    function test_remove_key() {
        signingTest.setKey(7); signingTest.initChannel(1); signingTest.feed(1, heartbeat, 7)
        signingTest.removeKey()
        verify(!signingTest.hasKey())
        compare(signingTest.state(1), noKey, "no key: the link is not signed any more")
        verify(signingTest.feed(1, heartbeat, 0), "unsigned accepted again")
    }
    function test_channel_cleared() {
        signingTest.setKey(7); signingTest.initChannel(3); signingTest.feed(3, heartbeat, 7)
        signingTest.clearChannel(3)
        compare(signingTest.state(3), noKey)
        signingTest.initChannel(3)
        compare(signingTest.state(3), notProtected, "a new link starts not protected")
    }
    // ---- random / stress
    function test_random_packets() {
        signingTest.setKey(7); signingTest.initChannel(1)
        var wasProtected = false
        for (var i = 0; i < 2000; i++) {
            var r = Math.random()
            var key = r < 0.4 ? 7 : r < 0.6 ? 9 : 0
            var id = Math.random() < 0.1 ? radioStatus : heartbeat
            var ok = signingTest.feed(1, id, key, Math.random() * 900)
            var st = signingTest.state(1)
            if (key === 7) { verify(ok, "our key accepted, step " + i); compare(st, protectedLink) ; wasProtected = true }
            if (wasProtected && key === 9) verify(!ok, "other key dropped once protected, step " + i)
            if (wasProtected && key === 0 && id === heartbeat) verify(!ok, "unsigned dropped once protected, step " + i)
            if (wasProtected) compare(st, protectedLink, "never leaves protected, step " + i)
        }
    }
}
