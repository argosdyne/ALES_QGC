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
    function test_icons() {
        compare(MissionInfo.iconFor("area"), "grid")
        compare(MissionInfo.iconFor("waypoint"), "pin")
        compare(MissionInfo.iconFor("nonsense"), "folder")
    }
}
