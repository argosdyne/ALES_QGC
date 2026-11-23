// S24: mission kind, numbers, text, route and height (SimpleMissionInfo.js) with mission-controller doubles
import QtQuick 2.12
import QtTest 1.12
import "../../res/Simple/SimpleMissionInfo.js" as MissionInfo

TestCase {
    name: "SimpleMissionInfo"

    readonly property var words: ({ area: "Area mapping", waypoint: "Waypoint flight", corridor: "Corridor mapping",
                                    structure: "Structure scan", lidar: "LiDAR survey", mission: "Mission", photos: "%1 photos",
                                    points: "%1 points", items: "%1 items", minutes: "%1 min",
                                    fmtArea: function(m2) { return (m2 / 10000).toFixed(1) + " ha" },
                                    fmtDist: function(m) { return (m / 1000).toFixed(1) + " km" } })

    // items: plain objects; visualItems.get(i) / .count like QmlObjectListModel
    function mission(items, time, dist) {
        return { visualItems: { count: items.length, get: function(i) { return items[i] } },
                 missionTime: time === undefined ? 0 : time, missionDistance: dist === undefined ? 0 : dist }
    }
    readonly property var settingsItem: ({ isSimpleItem: false })
    function coord(lat, lon) { return { latitude: lat, longitude: lon, isValid: true } }
    function simple(cmd, alt, c) {
        return { isSimpleItem: true, command: cmd, specifiesCoordinate: !!c, coordinate: c ? c : { isValid: false },
                 specifiesAltitude: alt !== undefined, altitude: { rawValue: alt === undefined ? 0 : alt } }
    }
    function survey(transects, h) {
        return { isSimpleItem: false, surveyAreaPolygon: { path: [], count: 4 }, gridAngle: { rawValue: 0 }, coveredArea: 42000, cameraShots: 312,
                 visualTransectPoints: transects || [], cameraCalc: { distanceToSurface: { rawValue: h === undefined ? 80 : h } } }
    }

    function test_waypoint() {
        var m = mission([settingsItem, simple(22, 10), simple(16, 50), simple(16, 60), simple(20)], 300)
        compare(MissionInfo.kindOf(m), "waypoint")
        compare(MissionInfo.text(MissionInfo.info(m), words), "Waypoint flight · 2 points · 5 min")
    }
    function test_area() {
        var m = mission([settingsItem, simple(22), survey(), simple(21)], 840)
        compare(MissionInfo.kindOf(m), "area")
        compare(MissionInfo.text(MissionInfo.info(m), words), "Area mapping · 4.2 ha · 14 min · 312 photos")
    }
    // review finding: a mixed mission must never open in an editor that only checks part of it
    function test_mixed_is_other() {
        compare(MissionInfo.kindOf(mission([settingsItem, simple(22), survey(), simple(16, 300), simple(21)])), "other")
        compare(MissionInfo.kindOf(mission([settingsItem, simple(22), simple(16), simple(82), simple(20)])), "other", "spline waypoint")
        compare(MissionInfo.kindOf(mission([settingsItem, simple(22), simple(16), simple(19), simple(20)])), "other", "loiter")
        compare(MissionInfo.kindOf(mission([settingsItem, survey(), survey()])), "other", "two surveys")
        compare(MissionInfo.kindOf(mission([settingsItem, simple(22), { isSimpleItem: false }, simple(20)])), "other", "unknown complex")
    }
    function test_corridor_and_structure() {
        compare(MissionInfo.kindOf(mission([settingsItem, simple(22), { isSimpleItem: false, corridorPolyline: { path: [] }, surveyAreaPolygon: { path: [] } }, simple(20)])),
                "corridor", "a corridor also has surveyAreaPolygon")
        compare(MissionInfo.kindOf(mission([settingsItem, simple(22), { isSimpleItem: false, corridorPolyline: { path: [] } }, simple(20)])), "corridor")
        compare(MissionInfo.kindOf(mission([settingsItem, { isSimpleItem: false, structureHeight: { rawValue: 30 } }])), "structure")
        var pt = function(m) { return { m: m, distanceTo: function(o) { return Math.abs(o.m - this.m) } } }
        compare(MissionInfo.text(MissionInfo.info(mission([settingsItem, { isSimpleItem: false, corridorPolyline: { path: [pt(0), pt(1500), pt(2100)] } }], 0, 9e6)), words),
                "Corridor mapping · 2.1 km", "line length, not the mission distance")
    }
    // S42: the YellowScan "Init Path" item has a corridor line too, but is not a corridor mapping
    function test_init_path_is_not_corridor() {
        compare(MissionInfo.kindOf(mission([settingsItem, simple(22), { isSimpleItem: false, corridorPolyline: { path: [] }, turnRadius: { rawValue: 30 } }, simple(20)])), "other")
    }
    // S42: a YellowScan survey with init paths before and after is a LiDAR survey (no photo count)
    function test_lidar() {
        var ys = survey(); ys.cameraCalc.isYSLidar = true
        // like the C++ items: every transect item also has surveyAreaPolygon and coveredArea
        var ip = function() { return { isSimpleItem: false, corridorPolyline: { path: [] }, turnRadius: { rawValue: 10 },
                                       surveyAreaPolygon: { path: [] }, coveredArea: 0, cameraShots: 5 } }
        var m = mission([settingsItem, simple(22), ip(), ys, ip(), simple(21)], 600)
        compare(MissionInfo.kindOf(m), "lidar")
        compare(MissionInfo.text(MissionInfo.info(m), words), "LiDAR survey · 4.2 ha · 10 min")
        // the file keeps no YellowScan mark (classic: camera "Manual"): without init paths it is an area mapping
        compare(MissionInfo.kindOf(mission([settingsItem, simple(22), ys, simple(21)])), "area", "without init paths")
        compare(MissionInfo.kindOf(mission([settingsItem, simple(22), ip(), simple(16), simple(21)])), "other", "init path with waypoints")
        compare(MissionInfo.kindOf(mission([settingsItem, simple(22), ip(), simple(21)])), "other", "init path alone")
        compare(MissionInfo.iconFor("lidar"), "lidar")
    }
    // S41: the structure's entrance height counts, the distance to the structure does not
    function test_structure_height() {
        var st = { isSimpleItem: false, structureHeight: { rawValue: 45 }, topFlightAlt: 44, entranceAlt: { rawValue: 50 },
                   cameraCalc: { distanceToSurface: { rawValue: 90 } } }
        compare(MissionInfo.maxHeight(mission([settingsItem, st])), 50)
    }
    function test_empty() {
        compare(MissionInfo.kindOf(mission([settingsItem])), "other")
        compare(MissionInfo.kindOf(null), "other")
        compare(MissionInfo.text(null, words), "")
    }
    // the S39 check sees every point and the highest one, also in a mixed mission
    function test_route_and_height_cover_everything() {
        var t = [coord(1, 1), coord(1, 2)]
        var m = mission([settingsItem, simple(22, 10, coord(0, 0)), survey(t, 80), simple(16, 300, coord(5, 5)), simple(21, 0, coord(0, 0))])
        var r = MissionInfo.route(m)
        compare(r.length, 5, "take-off, 2 transect points, waypoint, land")
        compare(r[3].latitude, 5)
        compare(MissionInfo.maxHeight(m), 300)
        compare(MissionInfo.maxHeight(mission([settingsItem, survey([], 95)])), 95)
        compare(MissionInfo.maxHeight(mission([settingsItem, { isSimpleItem: false, topFlightAlt: 110 }])), 110)
    }
    // ---- abnormal: damaged or unexpected items (a broken .plan, a plan from another QGC)
    function test_abnormal_items() {
        var odd = [null, undefined, {}, { isSimpleItem: true }, { isSimpleItem: true, command: "16" },
                   { isSimpleItem: false, corridorPolyline: null }, { isSimpleItem: false, gridAngle: null, cameraCalc: null },
                   { isSimpleItem: true, command: 16, specifiesCoordinate: true, coordinate: null },
                   { isSimpleItem: true, command: 16, specifiesAltitude: true, altitude: null },
                   { isSimpleItem: false, corridorPolyline: { path: null }, turnRadius: {} }]
        for (var i = 0; i < odd.length; i++) {
            var m = mission([settingsItem, odd[i]])
            var k = MissionInfo.kindOf(m)
            verify(["area", "waypoint", "corridor", "structure", "lidar", "other"].indexOf(k) >= 0, "kind " + k + " for item " + i)
            MissionInfo.text(MissionInfo.info(m), words)
            MissionInfo.route(m)
            verify(isFinite(MissionInfo.maxHeight(m)) || isNaN(MissionInfo.maxHeight(m)) === false, "height for item " + i)
        }
    }
    // ---- random: any mix of items gives a known kind, and the editor kinds keep their rules
    function randomItem() {
        var r = Math.random()
        if (r < 0.45) return simple([22, 20, 21, 16, 16, 16, 19, 82, 183][Math.floor(Math.random() * 9)], Math.random() * 200, coord(Math.random(), Math.random()))
        if (r < 0.60) return survey([coord(1, 1)], Math.random() * 150)
        if (r < 0.72) return { isSimpleItem: false, corridorPolyline: { path: [] }, surveyAreaPolygon: { path: [] } }
        if (r < 0.84) return { isSimpleItem: false, structureHeight: { rawValue: 30 }, topFlightAlt: Math.random() * 100 }
        if (r < 0.96) return { isSimpleItem: false, corridorPolyline: { path: [] }, turnRadius: { rawValue: 10 }, surveyAreaPolygon: { path: [] } }
        return null
    }
    function test_random_missions() {
        for (var run = 0; run < 3000; run++) {
            var items = [settingsItem], n = Math.floor(Math.random() * 8)
            for (var i = 0; i < n; i++) items.push(randomItem())
            var m = mission(items, Math.random() * 3000, Math.random() * 9000)
            var k = MissionInfo.kindOf(m)
            var complex = 0, ip = 0, wp = 0, other = 0
            for (var j = 1; j < items.length; j++) {
                var it = items[j]; if (!it) continue
                if (it.isSimpleItem) { if (it.command === 16) wp++; else if ([22, 20, 21].indexOf(it.command) < 0) other++ }
                else if (it.turnRadius !== undefined) ip++
                else complex++
            }
            if (k === "waypoint") verify(complex === 0 && ip === 0 && other === 0 && wp > 0, "waypoint rule, run " + run)
            if (k === "area" || k === "corridor" || k === "structure") verify(complex === 1 && ip === 0 && wp === 0 && other === 0, k + " rule, run " + run)
            if (k === "lidar") verify(complex === 1 && ip > 0 && wp === 0 && other === 0, "lidar rule, run " + run)
            var t = MissionInfo.text(MissionInfo.info(m), words)
            verify(typeof t === "string" && t.length > 0, "summary text, run " + run)
            verify(MissionInfo.maxHeight(m) >= 0, "height, run " + run)
        }
    }
    // ---- stress: a heavy user's long mission (several thousand items) stays quick
    function test_stress_big_mission() {
        var items = [settingsItem]
        for (var i = 0; i < 5000; i++) items.push(simple(16, i % 120, coord(i * 1e-5, 0)))
        var m = mission(items, 99999, 99999)
        var t0 = Date.now()
        for (var r = 0; r < 20; r++) { MissionInfo.kindOf(m); MissionInfo.info(m); MissionInfo.route(m); MissionInfo.maxHeight(m) }
        var ms = Date.now() - t0
        compare(MissionInfo.kindOf(m), "waypoint"); compare(MissionInfo.route(m).length, 5000); compare(MissionInfo.maxHeight(m), 119)
        verify(ms < 5000, "20 rounds over 5000 items took " + ms + " ms")
    }
    function test_icons() {
        compare(MissionInfo.iconFor("area"), "grid")
        compare(MissionInfo.iconFor("waypoint"), "pin")
        compare(MissionInfo.iconFor("nonsense"), "folder")
    }
}
