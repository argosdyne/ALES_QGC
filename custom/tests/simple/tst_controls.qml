// S* components: stepper, slide-to-confirm, segmented, toggle, button, setting row (mouse-driven)
import QtQuick 2.12
import QtTest 1.12
import "../../res/Simple"

Item {
    id: root
    width: 1920; height: 1080

TestCase {
    id: tc
    name: "SimpleControls"
    when: windowShown

    Component { id: stepperComp; SStepper { } }
    Component { id: slideComp;   SSlideConfirm { width: 640; text: "Slide to start" } }
    Component { id: segComp;     SSegmented { designWidth: 338; model: ["Metric", "Imperial"] } }
    Component { id: toggleComp;  SToggle { } }
    Component { id: buttonComp;  SButton { text: "OK" } }
    Component { id: rowComp;     SSettingRow { width: 900; title: "Legal & licenses"; sub: "x" } }
    SignalSpy { id: spy }

    function cleanup() { SimpleTheme.scale = 1.0; SimpleTheme.textScale = 1.0; spy.clear() }

    // ---- SStepper
    function test_stepper_clamp() {
        var st = createTemporaryObject(stepperComp, root, { value: 50, from: 10, to: 120, step: 10 })
        spy.target = null; spy.signalName = "edited"; spy.target = st
        for (var i = 0; i < 20; i++) st._set(st.value + st.step)
        compare(st.value, 120)
        for (i = 0; i < 20; i++) st._set(st.value - st.step)
        compare(st.value, 10)
        compare(spy.count, 18, "edited only when the value really changes")
    }
    function test_stepper_decimals_no_float_drift() {
        var st = createTemporaryObject(stepperComp, root, { value: 0, from: 0, to: 5, step: 0.1, decimals: 1 })
        for (var i = 0; i < 3; i++) st._set(st.value + st.step)
        compare(st.value, 0.3, "0.1 + 0.1 + 0.1 must show 0.3")
    }
    function test_stepper_abnormal() {
        var st = createTemporaryObject(stepperComp, root, { value: 5, from: 0, to: 10 })
        st._set(NaN)
        verify(!isNaN(st.value), "NaN input must not reach the value (got " + st.value + ")")
    }
    function test_stepper_from_greater_than_to() {
        var st = createTemporaryObject(stepperComp, root, { value: 5, from: 10, to: 0 })
        st._set(7)
        verify(st.value === 0 || st.value === 10, "inverted range clamps to a bound: " + st.value)
    }
    function test_stepper_buttons_disable_at_limits() {
        var st = createTemporaryObject(stepperComp, root, { value: 0, from: 0, to: 2, step: 1 })
        var minus = st.children[0], plus = st.children[2]
        verify(!minus.enabled_); verify(plus.enabled_)
        mouseClick(plus); mouseClick(plus); mouseClick(plus)
        compare(st.value, 2); verify(!plus.enabled_)
    }
    function test_stepper_random() {
        var st = createTemporaryObject(stepperComp, root, { value: 50, from: 0, to: 120, step: 5 })
        for (var i = 0; i < 3000; i++) {
            st._set(st.value + (Math.random() < 0.5 ? -1 : 1) * st.step * Math.floor(Math.random() * 4))
            verify(st.value >= 0 && st.value <= 120)
            compare(st.value % 5, 0)
        }
    }

    // ---- SSlideConfirm
    function test_slide_full_confirms() {
        var sl = createTemporaryObject(slideComp, root, { y: 100 })
        spy.target = null; spy.signalName = "confirmed"; spy.target = sl
        var knob = sl.children[1]
        mouseDrag(sl, knob.x + knob.width / 2, sl.height / 2, sl.width, 0)
        compare(spy.count, 1)
        tryCompare(knob, "x", SimpleTheme.px(6), 1000, "knob returns after confirm")
    }
    function test_slide_half_does_not_confirm() {
        var sl = createTemporaryObject(slideComp, root, { y: 100 })
        spy.target = null; spy.signalName = "confirmed"; spy.target = sl
        var knob = sl.children[1]
        mouseDrag(sl, knob.x + knob.width / 2, sl.height / 2, (sl.width - knob.width) / 2, 0)
        compare(spy.count, 0)
    }
    function test_slide_tap_does_not_confirm() {
        var sl = createTemporaryObject(slideComp, root, { y: 100 })
        spy.target = null; spy.signalName = "confirmed"; spy.target = sl
        var knob = sl.children[1]
        for (var i = 0; i < 20; i++) mouseClick(knob)
        compare(spy.count, 0, "a tap must never fly the drone")
    }
    function test_slide_narrow_track() {
        // abnormal: track narrower than the knob (tiny window / wrong layout)
        var sl = createTemporaryObject(slideComp, root, { y: 100, width: 150 })
        spy.target = null; spy.signalName = "confirmed"; spy.target = sl
        mouseClick(sl.children[1])
        compare(spy.count, 0, "tap on a too-narrow track must not confirm")
    }
    function test_slide_vertical_drag_ignored() {
        var sl = createTemporaryObject(slideComp, root, { y: 300 })
        spy.target = null; spy.signalName = "confirmed"; spy.target = sl
        var knob = sl.children[1]
        mouseDrag(sl, knob.x + knob.width / 2, sl.height / 2, 0, 200)
        compare(spy.count, 0)
    }
    function test_slide_random_drags() {
        var sl = createTemporaryObject(slideComp, root, { y: 100 })
        spy.target = null; spy.signalName = "confirmed"; spy.target = sl
        var knob = sl.children[1]
        var expected = 0
        for (var i = 0; i < 60; i++) {
            var maxX = sl.width - knob.width - SimpleTheme.px(6)
            var dx
            do { dx = Math.random() * sl.width * 1.2 - sl.width * 0.1 }
            while (Math.abs(SimpleTheme.px(6) + dx - (maxX - SimpleTheme.px(8))) < 20)   // skip the drag-threshold band
            var endX = Math.max(SimpleTheme.px(6), Math.min(maxX, SimpleTheme.px(6) + dx))
            if (endX >= maxX - SimpleTheme.px(8)) expected++
            mouseDrag(sl, knob.x + knob.width / 2, sl.height / 2, dx, 0)
            wait(200)
            compare(knob.x, SimpleTheme.px(6), "knob back at start")
        }
        compare(spy.count, expected)
    }

    // ---- SSegmented / SToggle / SButton / SSettingRow
    function test_segmented_click() {
        var sg = createTemporaryObject(segComp, root)
        spy.target = null; spy.signalName = "activated"; spy.target = sg
        mouseClick(sg, sg.width * 0.75, sg.height / 2)
        compare(sg.currentIndex, 1); compare(spy.signalArguments[0][0], 1)
        mouseClick(sg, sg.width * 0.25, sg.height / 2)
        compare(sg.currentIndex, 0)
    }
    function test_segmented_empty_model() {
        var sg = createTemporaryObject(segComp, root, { model: [] })
        mouseClick(sg); compare(sg.currentIndex, 0)
    }
    function test_toggle() {
        var t = createTemporaryObject(toggleComp, root, { x: 100, y: 100 })
        spy.target = null; spy.signalName = "toggled"; spy.target = t
        mouseClick(t); verify(t.checked); mouseClick(t); verify(!t.checked)
        compare(spy.count, 2)
        mouseClick(t, -10, t.height / 2); verify(t.checked, "touch area extends 20 px around the toggle")
    }
    function test_button_disabled() {
        var b = createTemporaryObject(buttonComp, root, { enabled_: false })
        spy.target = null; spy.signalName = "clicked"; spy.target = b
        mouseClick(b); compare(spy.count, 0)
        b.enabled_ = true; mouseClick(b); compare(spy.count, 1)
    }
    function test_setting_row_clickable() {
        var r = createTemporaryObject(rowComp, root)
        spy.target = null; spy.signalName = "clicked"; spy.target = r
        mouseClick(r); compare(spy.count, 0, "plain rows are not clickable")
        r.clickable = true; mouseClick(r); compare(spy.count, 1)
        r.locked = true; mouseClick(r); compare(spy.count, 1, "locked rows ignore taps")
    }
    function test_setting_row_control_keeps_clicks() {
        var r = createTemporaryObject(rowComp, root, { clickable: true })
        var t = toggleComp.createObject(r.children[r.children.length - 1])   // into the control slot (ctl), as `SSettingRow { SToggle {} }` does
        spy.target = null; spy.signalName = "clicked"; spy.target = r
        var p = t.mapToItem(r, t.width / 2, t.height / 2)
        mouseClick(r, p.x, p.y)
        verify(t.checked, "the control on the right still gets its tap")
        compare(spy.count, 0, "and the row does not open at the same time")
    }
    // ---- stress: rapid taps
    function test_stress_rapid_taps() {
        var t = createTemporaryObject(toggleComp, root, { x: 100, y: 100 })
        for (var i = 0; i < 500; i++) mouseClick(t)
        verify(!t.checked)
    }
}
}
