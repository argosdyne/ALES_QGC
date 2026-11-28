// AQGC Simple UI — queue of S102 critical LiDAR messages (SimpleFlyOverlay), shown one at a time.
// - At most `max` are kept: the oldest waiting message is dropped, never the one on screen (index 0) and never a
//   "Start rejected" (it comes only once; LiDARAcquisition._setRejected). Tuleap bug #28588 (limit), #28595.
// - A text already waiting or already dropped is not queued again, so a faulty LiDAR repeating its message does not
//   push other messages out or raise the "older not shown" count again (#28595).
// - The dropped texts are forgotten when the queue is emptied (OK on the last one, or "Dismiss all").
.pragma library

// state: { queue: [], dropped: 0, droppedTexts: {} } (not changed); returns the new state.
// isKept(text) = true for texts that must not be dropped.
function push(state, message, max, isKept) {
    if (state.queue.indexOf(message) !== -1 || state.droppedTexts[message] === true) return state
    var q = state.queue.slice(), dropped = state.dropped, texts = state.droppedTexts, copied = false
    q.push(message)
    while (q.length > max) {
        var i = 1
        while (i < q.length && isKept(q[i])) i++
        if (i >= q.length) break                        // only kept messages are waiting: keep them all
        if (!copied) { var t = Object.create(null); for (var k in texts) t[k] = true; texts = t; copied = true }
        texts[q[i]] = true
        q.splice(i, 1)
        dropped++
    }
    return { queue: q, dropped: dropped, droppedTexts: texts }
}

function pop(state) {
    var q = state.queue.slice(1)
    return q.length === 0 ? empty() : { queue: q, dropped: state.dropped, droppedTexts: state.droppedTexts }
}

// droppedTexts has no prototype, so texts such as "constructor" or "__proto__" are plain keys
function empty() { return { queue: [], dropped: 0, droppedTexts: Object.create(null) } }
