// SimpleTheme: px()/fs() scaling and applyUnitSystem() (basic, boundary, abnormal, random)
import QtQuick 2.12
import QtTest 1.12
import "../../res/Simple"

TestCase {
    name: "SimpleTheme"

    // Fact double: rawValue + the reboot-flag setter the theme calls
    Component {
        id: factComp
        QtObject {
            property var  rawValue: 0
            property bool ignoreReboot: false
            property int  writes: 0
            property bool rebootFlagLeftOn: false
            function _setIgnoreQGCRebootRequired(on) { ignoreReboot = on }
            onRawValueChanged: { writes++; if (!ignoreReboot) rebootFlagLeftOn = true }
        }
    }
    function makeUnits(h, v, a, s, t) {
        var u = {
            horizontalDistanceUnits: factComp.createObject(null, { rawValue: h }),
            verticalDistanceUnits:   factComp.createObject(null, { rawValue: v }),
            areaUnits:               factComp.createObject(null, { rawValue: a }),
            speedUnits:              factComp.createObject(null, { rawValue: s }),
            temperatureUnits:        factComp.createObject(null, { rawValue: t })
        }
        for (var k in u) { u[k].writes = 0; u[k].rebootFlagLeftOn = false }   // creation is not a write
        return u
    }

    function cleanup() { SimpleTheme.scale = 1.0; SimpleTheme.textScale = 1.0 }

    // ---- basic
    function test_px_identity() {
        compare(SimpleTheme.px(100), 100)
        compare(SimpleTheme.px(0), 0)
        compare(SimpleTheme.fs(26), 26)
    }
    function test_px_scaled_tablet() {
        SimpleTheme.scale = 1280 / 1920
        compare(SimpleTheme.px(96), 64)
        compare(SimpleTheme.px(1920), 1280)
    }
    function test_fs_large_text() {
        SimpleTheme.textScale = 1.2
        compare(SimpleTheme.fs(30), 36)
        compare(SimpleTheme.px(30), 30, "layout must not grow with text size")
    }
    // ---- boundary / abnormal
    function test_fs_never_below_one() {
        SimpleTheme.scale = 0.001
        compare(SimpleTheme.fs(10), 1)
        SimpleTheme.scale = 0
        compare(SimpleTheme.fs(10), 1)
        compare(SimpleTheme.px(10), 0)
    }
    function test_px_negative_and_nan() {
        compare(SimpleTheme.px(-20), -20)
        verify(isNaN(SimpleTheme.px(NaN)), "NaN propagates (caller must not pass NaN)")
        verify(SimpleTheme.px(undefined) !== SimpleTheme.px(undefined), "undefined gives NaN")
    }
    function test_withAlpha() {
        var c = SimpleTheme.withAlpha("#ff0000", 0.5)
        fuzzyCompare(c.a, 0.5, 0.01)
        fuzzyCompare(c.r, 1.0, 0.01)
        c = SimpleTheme.withAlpha("black", 0)
        compare(c.a, 0)
    }
    // ---- random: px is monotonic and within rounding error for random scales
    function test_random_scales() {
        for (var i = 0; i < 2000; i++) {
            var sc = Math.random() * 3
            SimpleTheme.scale = sc
            var v = Math.random() * 2000
            var p = SimpleTheme.px(v)
            verify(Math.abs(p - v * sc) <= 0.5 + 1e-9, "px rounding: scale " + sc + " v " + v + " -> " + p)
            verify(SimpleTheme.px(v + 10) >= p, "monotonic")
            verify(SimpleTheme.fs(v) >= 1)
        }
    }
    // ---- applyUnitSystem
    function test_units_metric_to_imperial_and_back() {
        var u = makeUnits(1, 1, 3, 1, 0)                 // metric
        compare(SimpleTheme.applyUnitSystem(u, true), false, "already metric -> nothing changed")
        compare(SimpleTheme.applyUnitSystem(u, false), true)
        compare(u.horizontalDistanceUnits.rawValue, 0)   // feet
        compare(u.verticalDistanceUnits.rawValue, 0)
        compare(u.areaUnits.rawValue, 4)                 // acres
        compare(u.speedUnits.rawValue, 2)                // mph
        compare(u.temperatureUnits.rawValue, 1)          // F
        compare(SimpleTheme.applyUnitSystem(u, true), true)
        compare(u.areaUnits.rawValue, 3)
    }
    function test_units_reboot_popup_suppressed() {
        var u = makeUnits(0, 0, 4, 2, 1)
        SimpleTheme.applyUnitSystem(u, true)
        var keys = ["horizontalDistanceUnits", "verticalDistanceUnits", "areaUnits", "speedUnits", "temperatureUnits"]
        for (var i = 0; i < keys.length; i++) {
            verify(!u[keys[i]].rebootFlagLeftOn, keys[i] + " written without suppressing the restart popup")
            verify(!u[keys[i]].ignoreReboot, keys[i] + " suppression flag must be switched back off")
        }
    }
    function test_units_mixed_state() {
        // e.g. user changed only speed in Advanced mode
        var u = makeUnits(1, 1, 3, 2, 0)
        compare(SimpleTheme.applyUnitSystem(u, true), true)
        compare(u.speedUnits.rawValue, 1)
        compare(u.horizontalDistanceUnits.writes, 0, "unchanged facts are not rewritten")
    }
    function test_units_stress_toggle() {
        var u = makeUnits(1, 1, 3, 1, 0)
        for (var i = 0; i < 500; i++) {
            verify(SimpleTheme.applyUnitSystem(u, i % 2 === 0 ? false : true))
        }
        compare(u.areaUnits.writes, 500)
    }
}
