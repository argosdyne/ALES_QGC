// AQGC Simple UI — kind and one-line summary of a mission (S24 saved missions, S07/S08/S23 save), from a
// MissionController. Kinds: area (survey), corridor, structure, waypoint (only simple items), other.
.pragma library

function kindOf(mission) {
    if (!mission) return "other"
    var items = mission.visualItems
    var hasWp = false, other = false
    for (var i = 0; i < items.count; i++) {
        var it = items.get(i)
        if (!it) continue
        if (it.surveyAreaPolygon !== undefined) return "area"
        if (it.corridorPolyline !== undefined) return "corridor"
        if (it.structureHeight !== undefined) return "structure"
        if (it.isSimpleItem && it.command === 16) hasWp = true
        else if (!it.isSimpleItem && i > 0) other = true
    }
    return hasWp && !other ? "waypoint" : "other"
}

function _minutes(sec) { return !sec || isNaN(sec) ? "" : Math.max(1, Math.round(sec / 60)) + " min" }

// T: translated strings from the caller (QML qsTr): area, waypoint, corridor, structure, mission, photos, points, items
function summary(mission, T) {
    var kind = kindOf(mission)
    var parts = []
    var items = mission.visualItems
    if (kind === "area") {
        parts.push(T.area)
        for (var i = 0; i < items.count; i++) {
            var it = items.get(i)
            if (it && it.surveyAreaPolygon !== undefined) {
                parts.push((it.coveredArea / 10000).toFixed(1) + " ha")
                if (it.cameraShots > 0) parts.push(T.photos.replace("%1", it.cameraShots))
                break
            }
        }
    } else if (kind === "waypoint") {
        var n = 0
        for (var j = 0; j < items.count; j++) { var w = items.get(j); if (w && w.isSimpleItem && w.command === 16) n++ }
        parts.push(T.waypoint)
        parts.push(T.points.replace("%1", n))
    } else if (kind === "corridor") {
        parts.push(T.corridor)
        parts.push((mission.missionDistance / 1000).toFixed(1) + " km")
    } else if (kind === "structure") {
        parts.push(T.structure)
    } else {
        parts.push(T.mission)
        parts.push(T.items.replace("%1", Math.max(0, items.count - 1)))
    }
    var m = _minutes(mission.missionTime)
    if (m !== "") parts.splice(kind === "area" ? 2 : parts.length, 0, m)
    return { kind: kind, text: parts.join(" · ") }
}

// coordinates that outline the mission (for the map preview and the S39 check route)
function outline(mission) {
    var pts = []
    var items = mission.visualItems
    for (var i = 1; i < items.count; i++) {
        var it = items.get(i)
        if (!it) continue
        var poly = it.surveyAreaPolygon !== undefined ? it.surveyAreaPolygon : it.corridorPolyline !== undefined ? it.corridorPolyline : null
        if (poly && poly.path) { for (var k = 0; k < poly.path.length; k++) pts.push(poly.path[k]) }
        else if (it.specifiesCoordinate && it.coordinate && it.coordinate.isValid) pts.push(it.coordinate)
    }
    return pts
}

function iconFor(kind) {
    return kind === "area" ? "grid" : kind === "waypoint" ? "pin" : kind === "corridor" ? "corridor" : kind === "structure" ? "structure" : "folder"
}
