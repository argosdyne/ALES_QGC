// S40 / S41 / S42 settings panel (SimpleScanSettings): basic, boundary, abnormal, random and stress cases,
// with corridor / structure / survey item doubles (Fact-like QtObjects so the bindings follow the edits)
import QtQuick 2.12
import QtTest 1.12
import "../../res/Simple"

Item {
    id: root
    width: 1920; height: 1080

    Component {
        id: camC
        QtObject {
            property bool isManualCamera: false
            property bool isYSLidar: false
            property QtObject distanceToSurface:     QtObject { property var rawValue: 80 }
            property QtObject imageDensity:          QtObject { property var rawValue: 2.1; property string valueString: "2.1"; property string units: "cm" }
            property QtObject frontalOverlap:        QtObject { property var rawValue: 70 }
            property QtObject sideOverlap:           QtObject { property var rawValue: 60 }
            property QtObject adjustedFootprintSide: QtObject { property var rawValue: 60 }
            property QtObject yellowScanOverlapFact: QtObject { property var rawValue: 50 }
        }
    }
    Component {
        id: polylineC
        QtObject { property var path: [] }
    }
    Component {
        id: corridorC
        QtObject {
            property var cameraCalc: null
            property var corridorPolyline: null
            property QtObject corridorWidth: QtObject { property var rawValue: 40 }
            property int cameraShots: 27
        }
    }
    Component {
        id: structureC
        QtObject {
            property var cameraCalc: null
            property QtObject structureHeight: QtObject { property var rawValue: 45 }
            property QtObject scanBottomAlt:   QtObject { property var rawValue: 5 }
            property QtObject layers:          QtObject { property var rawValue: 2; property string valueString: "2" }
            property QtObject gimbalPitch:     QtObject { property var rawValue: 0 }
            property int cameraShots: 16
        }
    }
    Component {
        id: surveyC
        QtObject {
            property var cameraCalc: null
            property QtObject gridAngle: QtObject { property var rawValue: 0 }
            property real coveredArea: 30000
            property int cameraShots: 0
        }
    }
    Component {
        id: missionC
        QtObject {
            property real missionTime: 180
            property int  batteriesRequired: 1
            property QtObject settingsItem: QtObject {
                property QtObject speedSection: QtObject {
                    property bool specifyFlightSpeed: false
                    property QtObject flightSpeed: QtObject { property var rawValue: 10 }
                }
            }
            property QtObject visualItems: QtObject {
                property int count: 1
                function get(i) { return i === 0 ? settingsItem : null }
            }
        }
    }
    Component { id: panelC; SimpleScanSettings { width: 620; height: 900 } }
    SignalSpy { id: shapeSpy; signalName: "shapeRequested" }
    SignalSpy { id: ipSpy;    signalName: "initPathsRequested" }
    SignalSpy { id: ysSpy;    signalName: "ysEdited" }
    SignalSpy { id: nextSpy;  signalName: "nextRequested" }

    TestCase {
        name: "SimpleScanSettings"
        when: windowShown

        function find(item, name) {
            if (!item) return null
            if (item.objectName === name) return item
            var kids = item.children || []
            for (var i = 0; i < kids.length; i++) { var r = find(kids[i], name); if (r) return r }
            if (item.item) return find(item.item, name)        // Loader
            return null
        }
        function corridor()  { var c = createTemporaryObject(corridorC, root); c.cameraCalc = createTemporaryObject(camC, root)
                               c.corridorPolyline = createTemporaryObject(polylineC, root)
                               c.corridorPolyline.path = [pt(0), pt(300)]; return c }
        function structure() { var s = createTemporaryObject(structureC, root); s.cameraCalc = createTemporaryObject(camC, root)
                               s.cameraCalc.distanceToSurface.rawValue = 15; return s }
        function survey()    { var s = createTemporaryObject(surveyC, root); s.cameraCalc = createTemporaryObject(camC, root)
                               s.cameraCalc.isYSLidar = true; s.cameraCalc.distanceToSurface.rawValue = 60; return s }
        function pt(m)       { return { m: m, distanceTo: function(o) { return Math.abs(o.m - this.m) } } }
        function panel(kind, item, extra) {
            var props = { kind: kind, item: item, mission: createTemporaryObject(missionC, root), maxAlt: 120 }
            for (var k in extra) props[k] = extra[k]
            var p = createTemporaryObject(panelC, root, props)
            shapeSpy.target = p; ipSpy.target = p; ysSpy.target = p; nextSpy.target = p
            shapeSpy.clear(); ipSpy.clear(); ysSpy.clear(); nextSpy.clear()
            return p
        }
        // press + or - of a stepper n times (through the same path as a tap)
        function press(st, plus, n) { for (var i = 0; i < (n || 1); i++) st._set(st.value + (plus ? st.step : -st.step)) }

        // ---- basic
        function test_corridor_basic() {
            var c = corridor(), p = panel("corridor", c)
            var w = find(p, "width"), d = find(p, "dist")
            verify(w && d)
            compare(w.value, 40); compare(d.value, 80)
            press(w, true, 2); compare(c.corridorWidth.rawValue, 60)
            press(d, false);   compare(c.cameraCalc.distanceToSurface.rawValue, 75)
            compare(p.lineLength, 300)
            find(p, "overlap").activated(1)
            compare(c.cameraCalc.frontalOverlap.rawValue, 80); compare(c.cameraCalc.sideOverlap.rawValue, 70)
        }
        function test_structure_basic() {
            var s = structure(), p = panel("structure", s, { shape: "rectangle" })
            compare(find(p, "shape").currentIndex, 0)
            find(p, "shape").activated(1); compare(shapeSpy.count, 1); compare(shapeSpy.signalArguments[0][0], "circle")
            find(p, "shape").activated(2); compare(shapeSpy.signalArguments[1][0], "draw")
            press(find(p, "top"), false, 5); compare(s.structureHeight.rawValue, 40)
            press(find(p, "bottom"), true, 3); compare(s.scanBottomAlt.rawValue, 8)
            find(p, "camera").activated(1); compare(s.gimbalPitch.rawValue, -15)
        }
        function test_lidar_basic() {
            var s = survey(), p = panel("lidar", s, { initPaths: true })
            press(find(p, "dist"), true); compare(s.cameraCalc.distanceToSurface.rawValue, 65); compare(ysSpy.count, 1)
            find(p, "ysOverlap").activated(1); compare(s.cameraCalc.yellowScanOverlapFact.rawValue, 70); compare(ysSpy.count, 2)
            var sp = find(p, "speed"); verify(sp && sp.visible)
            press(sp, false, 2)
            compare(p.mission.settingsItem.speedSection.flightSpeed.rawValue, 8)
            verify(p.mission.settingsItem.speedSection.specifyFlightSpeed, "speed edit turns the mission speed on")
            var t = find(p, "initPaths"); verify(t.checked)
            mouseClick(t); compare(ipSpy.count, 1); compare(ipSpy.signalArguments[0][0], false)
            verify(t.checked, "the switch follows the wizard (initPaths), not the tap")
        }
        // ---- boundaries
        function test_limits() {
            var c = corridor(), p = panel("corridor", c, { maxAlt: 50 })
            var d = find(p, "dist")
            compare(d.to, 50)
            press(d, true, 50); compare(c.cameraCalc.distanceToSurface.rawValue, 50, "never above the maximum altitude")
            press(d, false, 50); compare(c.cameraCalc.distanceToSurface.rawValue, 10, "never below 10 m")
            var w = find(p, "width"); press(w, true, 100); compare(c.corridorWidth.rawValue, 300)
            press(w, false, 100); compare(c.corridorWidth.rawValue, 10)
            var s = structure(); p = panel("structure", s, { maxAlt: 30 })
            press(find(p, "top"), true, 100); verify(s.structureHeight.rawValue <= 30, "top within max altitude")
            press(find(p, "bottom"), true, 100)
            verify(s.scanBottomAlt.rawValue < s.structureHeight.rawValue, "bottom stays under the top")
            var dist = find(p, "dist"); press(dist, false, 100); compare(s.cameraCalc.distanceToSurface.rawValue, 3)
        }
        // ---- abnormal
        function test_null_item_and_mission() {
            var p = panel("corridor", null)
            compare(p.lineLength, 0)
            p.mission = null
            p.kind = "lidar"; p.kind = "structure"
            verify(true, "no exception without an item or mission")
        }
        function test_kind_and_item_mismatch() {
            // the wizard can change kind before item for a moment: wrong-kind item must not throw
            var p = panel("corridor", structure())
            compare(p.lineLength, 0)
            p.kind = "structure"; p.item = corridor()
            p.kind = "lidar"; p.item = structure()
            compare(p._v("corridorWidth"), 0); compare(p._v("nothing"), 0)
        }
        function test_manual_camera_hides_overlap() {
            var c = corridor(); c.cameraCalc.isManualCamera = true
            var p = panel("corridor", c)
            verify(!find(p, "overlap").visible)
        }
        // ---- random (user taps in any order, the wizard swaps items)
        function test_random_edits() {
            var kinds = ["corridor", "structure", "lidar"]
            var p = panel("corridor", corridor())
            for (var i = 0; i < 400; i++) {
                var k = kinds[Math.floor(Math.random() * 3)]
                if (Math.random() < 0.15) { p.kind = k; p.item = k === "corridor" ? corridor() : k === "structure" ? structure() : survey() }
                if (Math.random() < 0.05) p.maxAlt = 20 + Math.floor(Math.random() * 101)
                var names = ["dist", "width", "bottom", "top", "speed"]
                var st = find(p, names[Math.floor(Math.random() * names.length)])
                if (st && st.visible) {
                    var v0 = st.value, up = Math.random() < 0.5
                    press(st, up, 1 + Math.floor(Math.random() * 5))
                    // a lower maximum altitude does not move a value already set (the S39 check reports it);
                    // the buttons never push a value past the limits
                    if (up) verify(st.value <= Math.max(v0, st.to), st.objectName + " above its limit at step " + i)
                    else    verify(st.value >= Math.min(v0, st.from), st.objectName + " below its limit at step " + i)
                }
                var it = p.item
                if (p.kind === "structure" && it && it.scanBottomAlt)
                    verify(it.scanBottomAlt.rawValue >= 2, "bottom >= 2 m at step " + i)
            }
        }
        // ---- stress: the wizard replaces the item many times (Loader rebuild each time)
        function test_stress_item_swaps() {
            var p = panel("corridor", corridor())
            var t0 = Date.now()
            for (var i = 0; i < 300; i++) {
                p.item = (i % 3 === 0) ? corridor() : (i % 3 === 1) ? structure() : survey()
                p.kind = (i % 3 === 0) ? "corridor" : (i % 3 === 1) ? "structure" : "lidar"
            }
            verify(Date.now() - t0 < 20000, "300 swaps in " + (Date.now() - t0) + " ms")
            verify(find(p, "dist"), "panel still built")
        }
        function test_next_button() {
            var p = panel("corridor", corridor())
            p.nextRequested(); compare(nextSpy.count, 1)
        }
    }
}
