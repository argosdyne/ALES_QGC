// S35 / S38: map tap menu rules (Go here allowed or why not), coordinates check, change-altitude sheet
import QtQuick 2.12
import QtPositioning 5.12
import QtTest 1.12
import "../../res/Simple"

Item {
    id: root
    width: 1920; height: 1080

    // vehicle double: what the sheets and the menu read
    QtObject {
        id: veh
        property var  coordinate: QtPositioning.coordinate(37.5665, 126.9780)
        property QtObject altitudeRelative: QtObject { property var rawValue: 47 }
        property QtObject altitudeAMSL:     QtObject { property var rawValue: 85 }
        property QtObject groundSpeed:      QtObject { property var rawValue: 0 }
        property QtObject objectAvoidance:  QtObject { property bool available: false; property bool enabled: false
                                                        property var distances: []; property real maxDistance: 0 }
        property string flightMode: "Guided"
        property string gotoFlightMode: "Guided"
    }
    // vehicle-state double (SimpleVehicleState fields the menu uses)
    QtObject {
        id: vsd
        property var  vehicle: veh
        property bool present: true
        property bool lost: false
        property bool connected: present && !lost
        property bool flying: true
    }
    QtObject {
        id: guided
        property bool showGotoLocation: true
        property bool showSetHome: true
    }

TestCase {
    id: tc
    name: "SimpleGoHere"
    when: windowShown

    Component { id: menuComp;  SimpleMapTapMenu { width: 1920; height: 1080 } }
    Component { id: altComp;   SimpleAltitudeSheet { } }
    Component { id: coordComp; SimpleCoordSheet { } }
    Component { id: goComp;    SimpleGoHereSheet { } }
    SignalSpy { id: spy }

    function init() {
        globals.guidedControllerFlyView = guided
        vsd.present = true; vsd.lost = false; vsd.flying = true
        guided.showGotoLocation = true; guided.showSetHome = true
        veh.altitudeRelative.rawValue = 47
    }
    function cleanup() { globals.guidedControllerFlyView = undefined; globals.planMasterControllerFlyView = undefined; spy.clear() }

    function menuAt(dNorthM) {
        return createTemporaryObject(menuComp, root, { vs: vsd, coordinate: veh.coordinate.atDistanceAndAzimuth(dNorthM, 0) })
    }

    // ---- S35 rules
    function test_menu_go_here_allowed_in_flight() {
        var m = menuAt(300)
        compare(m.goHereBlock.text, "")
        verify(Math.abs(m.distance - 300) < 1)
        verify(m.canSetHome)
    }
    function test_menu_ground_disabled_not_red() {
        vsd.flying = false
        var m = menuAt(300)
        compare(m.goHereBlock.text, "Available after take-off")
        compare(m.goHereBlock.red, false)
        verify(m.canSetHome, "set home stays on the ground")
    }
    function test_menu_link_lost() {
        vsd.lost = true
        var m = menuAt(300)
        compare(m.goHereBlock.text, "Not available while the signal is lost")
        verify(!m.canSetHome)
    }
    function test_menu_no_vehicle() {
        vsd.present = false
        compare(menuAt(300).goHereBlock.text, "No drone connected")
    }
    function test_menu_guided_bar_says_no() {
        guided.showGotoLocation = false
        compare(menuAt(300).goHereBlock.text, "Not available now")
    }
    function test_menu_max_distance_boundary() {
        // maxGoToLocationDistance = 1000 m (mock): 999 m ok, 1001 m refused in red
        compare(menuAt(999).goHereBlock.text, "")
        var far = menuAt(1001)
        verify(far.goHereBlock.text.indexOf("Too far") === 0, far.goHereBlock.text)
        compare(far.goHereBlock.red, true)
    }
    // Tuleap bugs #36984 / #36986: every safety refusal is listed, each with what to do
    QtObject {
        id: fenceBlocks
        property QtObject geoFenceController: QtObject {
            property bool fenceLoaded: true
            function goToTargetBlockReason(c) { return "outside" }
        }
    }
    function test_menu_lists_every_refusal_with_action() {
        globals.planMasterControllerFlyView = fenceBlocks
        var m = menuAt(1001)                              // outside the fence and too far
        compare(m.goHereBlock.red, true)
        compare(m.goHereBlock.reasons.length, 2)
        compare(m.goHereBlock.text, "Outside the geofence or in an excluded area")
        verify(m.goHereBlock.reasons[1].text.indexOf("Too far") === 0, m.goHereBlock.reasons[1].text)
        for (var i = 0; i < 2; i++) verify(m.goHereBlock.reasons[i].action !== "", "action for reason " + i)
        var shown = 0
        var walk = function(n) { if (n.objectName === "goReason" && n.visible) shown++; for (var k = 0; k < n.children.length; k++) walk(n.children[k]) }
        walk(m)
        compare(shown, 2, "both reasons drawn")
        // the sheet's recheck names the first reason and how many more
        var sh = createTemporaryObject(goComp, root, { vehicle: veh, coordinate: m.coordinate, recheck: m.goHereBlockNow })
        var refused = createTemporaryObject(spyComp, tc, { target: sh, signalName: "refused" })
        sh.send()
        compare(refused.count, 1)
        compare(refused.signalArguments[0][0], "Outside the geofence or in an excluded area (and 1 more)")
        globals.planMasterControllerFlyView = undefined
        var one = menuAt(1001)
        compare(one.goHereBlock.reasons.length, 1)
        compare(one.goHereBlock.reasons[0].action, "Choose a closer point. The limit is in Settings › Fly screen (Advanced mode).")
    }
    function test_menu_grey_states_have_no_reason_list() {
        vsd.flying = false
        var m = menuAt(1001)
        compare(m.goHereBlock.red, false)
        compare(m.goHereBlock.reasons.length, 0)
    }
    function test_menu_invalid_coordinate() {
        var m = createTemporaryObject(menuComp, root, { vs: vsd, coordinate: QtPositioning.coordinate() })
        compare(m.goHereBlock.text, "Drone position unknown")
        verify(!m.canSetHome)
    }
    function test_menu_buttons_emit() {
        var m = menuAt(300)
        spy.target = m; spy.signalName = "goHereRequested"
        m.goHereRequested(m.coordinate)
        compare(spy.count, 1)
    }

    // ---- coordinates sheet
    // Tuleap bug #36993: the menu checks run again when the slide completes (state may change after the menu opened)
    function test_go_here_rechecked_at_send() {
        var m = menuAt(300)
        compare(m.goHereBlock.text, "")
        var sh = createTemporaryObject(goComp, root, { vehicle: veh, coordinate: m.coordinate, recheck: m.goHereBlockNow })
        var refused = createTemporaryObject(spyComp, tc, { target: sh, signalName: "refused" })
        var sent = createTemporaryObject(spyComp, tc, { target: sh, signalName: "sent" })
        sh.send()                                         // still allowed: no refusal (no map here, so "not sent")
        compare(refused.count, 0); compare(sent.count, 1)
        var start = veh.coordinate
        veh.coordinate = m.coordinate.atDistanceAndAzimuth(1100, 180)   // the drone moved: now 1100 m from the target
        sh.send()
        compare(refused.count, 1)
        verify(String(refused.signalArguments[0][0]).indexOf("Too far") === 0, refused.signalArguments[0][0])
        compare(sent.count, 1, "nothing sent")
        veh.coordinate = start
        vsd.lost = true                                   // link lost while the sheet was open
        sh.send()
        compare(refused.count, 2)
        compare(refused.signalArguments[1][0], "Not available while the signal is lost")
    }
    function test_go_here_without_recheck_unchanged() {
        var sh = createTemporaryObject(goComp, root, { vehicle: veh, coordinate: veh.coordinate.atDistanceAndAzimuth(300, 0) })
        var refused = createTemporaryObject(spyComp, tc, { target: sh, signalName: "refused" })
        sh.send()
        compare(refused.count, 0)
    }
    Component { id: spyComp; SignalSpy { } }
    function test_coord_validation() {
        var s = createTemporaryObject(coordComp, root)
        verify(s._latOk === false && s._lonOk === false, "empty is not valid")
        compare(s._num("37,5665"), 37.5665, "comma decimal accepted")
        verify(isNaN(s._num("abc")))
        verify(isNaN(s._num("")))
    }

    // ---- S38 change altitude
    function test_alt_step_snaps_to_grid() {
        var s = createTemporaryObject(altComp, root, { vehicle: veh })
        s.visible = false; s.visible = true             // onVisibleChanged: target = now (47)
        compare(s.targetD, 47)
        s._step(1);  compare(s.targetD, 50)
        s._step(1);  compare(s.targetD, 55)
        s._step(-1); compare(s.targetD, 50)
        s._set(47); s._step(-1); compare(s.targetD, 45)
    }
    function test_alt_limits() {
        var s = createTemporaryObject(altComp, root, { vehicle: veh })
        for (var i = 0; i < 100; i++) s._step(1)
        compare(s.targetD, 120, "max = guidedMaximumAltitude")
        for (i = 0; i < 100; i++) s._step(-1)
        compare(s.targetD, 2, "min = guidedMinimumAltitude")
        s._set(-50);  compare(s.targetD, 2)
        s._set(9999); compare(s.targetD, 120)
    }
    function test_alt_change_sign_and_signal() {
        var s = createTemporaryObject(altComp, root, { vehicle: veh })
        s._set(65)
        compare(s.changeD, 18)
        spy.target = s; spy.signalName = "confirmed"
        s.confirmed(s.targetM - s._nowM)
        compare(spy.signalArguments[0][0], 18)
        s._set(30)
        compare(s.changeD, -17)
    }
    function test_alt_random_stays_in_range() {
        var s = createTemporaryObject(altComp, root, { vehicle: veh })
        for (var i = 0; i < 500; i++) {
            if (Math.random() < 0.5) s._step(Math.random() < 0.5 ? 1 : -1)
            else s._set(Math.round(Math.random() * 400 - 100))
            verify(s.targetD >= 2 && s.targetD <= 120, "target " + s.targetD)
        }
    }
}
}
