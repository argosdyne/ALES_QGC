// S24: mission kind and summary (SimpleMissionInfo.js) with mission-controller doubles
import QtQuick 2.12
import QtTest 1.12
import "../../res/Simple/SimpleMissionInfo.js" as MissionInfo

TestCase {
    name: "SimpleMissionInfo"

    readonly property var words: ({ area: "Area mapping", waypoint: "Waypoint flight", corridor: "Corridor mapping",
                                    structure: "Structure scan", mission: "Mission", photos: "%1 photos",
                                    points: "%1 points", items: "%1 items" })

    // items: array of plain objects; visualItems.get(i) / .count like QmlObjectListModel
    function mission(items, time, dist) {
        return { visualItems: { count: items.length, get: function(i) { return items[i] } },
                 missionTime: time === undefined ? 0 : time, missionDistance: dist === undefined ? 0 : dist }
    }
    readonly property var settingsItem: ({ isSimpleItem: false })
    function simple(cmd) { return { isSimpleItem: true, command: cmd, specifiesCoordinate: true, coordinate: { isValid: false } } }

    function test_waypoint() {
        var m = mission([settingsItem, simple(22), simple(16), simple(16), simple(20)], 300)
        compare(MissionInfo.kindOf(m), "waypoint")
        compare(MissionInfo.summary(m, words).text, "Waypoint flight · 2 points · 5 min")
    }
    function test_area() {
        var survey = { isSimpleItem: false, surveyAreaPolygon: { path: [] }, coveredArea: 42000, cameraShots: 312 }
        var m = mission([settingsItem, simple(22), survey, simple(21)], 840)
        compare(MissionInfo.kindOf(m), "area")
        compare(MissionInfo.summary(m, words).text, "Area mapping · 4.2 ha · 14 min · 312 photos")
    }
    function test_corridor_and_structure() {
        compare(MissionInfo.kindOf(mission([settingsItem, { isSimpleItem: false, corridorPolyline: { path: [] } }])), "corridor")
        compare(MissionInfo.kindOf(mission([settingsItem, { isSimpleItem: false, structureHeight: { rawValue: 30 } }])), "structure")
        compare(MissionInfo.summary(mission([settingsItem, { isSimpleItem: false, corridorPolyline: { path: [] } }], 0, 2100), words).text,
                "Corridor mapping · 2.1 km")
    }
    function test_other() {
        // a simple item that is not a waypoint plus a complex one that is none of the known kinds
        var m = mission([settingsItem, simple(22), { isSimpleItem: false }, simple(20)])
        compare(MissionInfo.kindOf(m), "other")
        compare(MissionInfo.summary(m, words).text, "Mission · 3 items")
    }
    function test_empty() {
        compare(MissionInfo.kindOf(mission([settingsItem])), "other")
        compare(MissionInfo.kindOf(null), "other")
    }
    function test_icons() {
        compare(MissionInfo.iconFor("area"), "grid")
        compare(MissionInfo.iconFor("waypoint"), "pin")
        compare(MissionInfo.iconFor("nonsense"), "folder")
    }
}
