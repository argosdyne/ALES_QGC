// S102 critical LiDAR message queue (SimpleLidarQueue.js, used by SimpleFlyOverlay): Tuleap bugs #28588 / #28595
import QtQuick 2.12
import QtTest 1.12
import "../../res/Simple/SimpleLidarQueue.js" as LidarQueue

TestCase {
    id: tc
    name: "SimpleLidarQueue"

    readonly property int max: 5
    function isKept(m) { return String(m).indexOf("LiDAR: Start rejected") === 0 }
    function push(st, m) { return LidarQueue.push(st, m, max, isKept) }

    // ---- basic
    function test_push_pop_clear() {
        var st = LidarQueue.empty()
        st = push(st, "a"); st = push(st, "b")
        compare(st.queue, ["a", "b"]); compare(st.dropped, 0)
        st = push(st, "a")                                    // already waiting: not queued twice
        compare(st.queue.length, 2)
        st = LidarQueue.pop(st)
        compare(st.queue, ["b"])
        st = LidarQueue.pop(st)
        compare(st.queue, []); compare(st.dropped, 0)
        st = push(st, "c")
        st = LidarQueue.empty()
        compare(st.queue, []); compare(Object.keys(st.droppedTexts).length, 0)
    }
    function test_state_not_changed_in_place() {
        var st0 = LidarQueue.empty()
        var st1 = push(st0, "a")
        compare(st0.queue.length, 0)
        for (var i = 0; i < 8; i++) st1 = push(st1, "m" + i)
        var texts = Object.keys(st1.droppedTexts).length
        var st2 = push(st1, "new")
        compare(Object.keys(st1.droppedTexts).length, texts, "the old state keeps its dropped texts")
        verify(st2 !== st1)
    }

    // ---- boundaries: the limit (#28588)
    function test_limit_keeps_shown_and_newest() {
        var st = LidarQueue.empty()
        for (var i = 0; i < 7; i++) st = push(st, "m" + i)
        compare(st.queue.length, max)
        compare(st.queue[0], "m0", "the message on screen is never dropped")
        compare(st.queue[max - 1], "m6")
        compare(st.dropped, 2)
        verify(st.droppedTexts["m1"] === true && st.droppedTexts["m2"] === true)
    }

    // ---- #28595: a dropped text coming again is not queued and not counted again
    function test_dropped_text_not_recounted() {
        var st = LidarQueue.empty()
        for (var i = 0; i < 6; i++) st = push(st, "m" + i)    // m1 dropped
        compare(st.dropped, 1)
        var before = st.queue.slice()
        for (var r = 0; r < 20; r++) st = push(st, "m1")     // a faulty LiDAR repeats it
        compare(st.dropped, 1, "not counted again")
        compare(st.queue, before, "other waiting messages are not pushed out")
    }
    function test_dropped_texts_forgotten_when_emptied() {
        var st = LidarQueue.empty()
        for (var i = 0; i < 6; i++) st = push(st, "m" + i)
        while (st.queue.length > 0) st = LidarQueue.pop(st)
        compare(st.dropped, 0)
        st = push(st, "m1")                                   // a new episode: shown again
        compare(st.queue, ["m1"])
    }

    // ---- #28595: a Start rejected is never dropped
    function test_start_rejected_never_dropped() {
        var st = LidarQueue.empty()
        st = push(st, "shown")
        st = push(st, "LiDAR: Start rejected: USB storage full (0x12)")
        for (var i = 0; i < 10; i++) st = push(st, "LiDAR critical: m" + i + ".")
        compare(st.queue.length, max)
        compare(st.queue[0], "shown")
        compare(st.queue[1], "LiDAR: Start rejected: USB storage full (0x12)")
        compare(st.dropped, 7)                                // 2 + 10 messages, limit 5
    }
    function test_only_start_rejected_waiting_keeps_all() {
        var st = LidarQueue.empty()
        for (var i = 0; i < 8; i++) st = push(st, "LiDAR: Start rejected (0x0" + i + ")")
        compare(st.queue.length, 8, "nothing that may be dropped: all kept")
        compare(st.dropped, 0)
        st = push(st, "LiDAR critical: x.")
        compare(st.queue.length, 8, "the new ordinary message is the one dropped")
        compare(st.dropped, 1)
        verify(st.droppedTexts["LiDAR critical: x."] === true)
    }

    // ---- abnormal
    function test_odd_texts() {
        var st = LidarQueue.empty()
        st = push(st, ""); st = push(st, "")
        compare(st.queue, [""])
        st = push(st, "__proto__"); st = push(st, "constructor")
        compare(st.queue.length, 3)
        for (var i = 0; i < 6; i++) st = push(st, "m" + i)
        st = push(st, "constructor")
        compare(st.dropped, 4)
    }

    // ---- random / stress: invariants over long random sequences
    function test_random_invariants() {
        var st = LidarQueue.empty()
        for (var i = 0; i < 20000; i++) {
            var r = Math.random()
            if (r < 0.7) {
                var m = Math.random() < 0.05 ? "LiDAR: Start rejected (0x" + Math.floor(Math.random() * 3) + ")"
                                             : "LiDAR critical: " + Math.floor(Math.random() * 30) + "."
                st = push(st, m)
            } else if (r < 0.98) st = LidarQueue.pop(st)
            else st = LidarQueue.empty()
            var normal = 0
            for (var j = 1; j < st.queue.length; j++) if (!isKept(st.queue[j])) normal++
            verify(st.queue.length <= max || normal === 0, "over the limit only with Start rejected messages waiting")
            for (var k = 0; k < st.queue.length; k++) {
                verify(st.droppedTexts[st.queue[k]] !== true, "a waiting text is never also a dropped one")
                compare(st.queue.indexOf(st.queue[k]), k, "no duplicates")
            }
            if (st.queue.length === 0) compare(st.dropped, 0)
        }
    }
}
