// AQGC Simple UI — kind, numbers and one-line summary of a mission (S24 saved missions, plan save / open), from a
// MissionController. Kinds:
//   area      one survey + only take-off / land / return items (what Plan › Area mapping makes)
//   waypoint  only take-off, waypoints (NAV_WAYPOINT 16) and land / return (what Plan › Waypoint flight makes)
//   corridor  one corridor scan + only take-off / land / return;  structure  likewise with a structure scan
//   other     anything else (mixed or special items): it is opened in the S39 check only, never in an editor
.pragma library

var _frame = [22, 20, 21]          // NAV_TAKEOFF, NAV_RETURN_TO_LAUNCH, NAV_LAND

function kindOf(mission) {
    if (!mission) return "other"
    var items = mission.visualItems
    var complexKind = "", complexCount = 0, wp = 0
    for (var i = 1; i < items.count; i++) {          // 0 = mission settings item
        var it = items.get(i)
        if (!it) continue
        if (it.isSimpleItem) {
            if (it.command === 16) wp++
            else if (_frame.indexOf(it.command) < 0) return "other"
        } else {
            complexCount++
            complexKind = it.surveyAreaPolygon !== undefined ? "area" : it.corridorPolyline !== undefined ? "corridor"
                        : it.structureHeight !== undefined ? "structure" : "unknown"
        }
    }
    if (complexCount === 0) return wp > 0 ? "waypoint" : "other"
    if (complexCount === 1 && wp === 0 && complexKind !== "unknown") return complexKind
    return "other"
}

// numbers only (cached by the saved-missions page; text is made when shown, in the current language and units)
function info(mission) {
    var kind = kindOf(mission)
    var r = { kind: kind, areaM2: NaN, photos: 0, points: 0, distM: mission ? mission.missionDistance : NaN,
              timeSec: mission ? mission.missionTime : NaN, items: 0 }
    if (!mission) return r
    var items = mission.visualItems
    r.items = Math.max(0, items.count - 1)
    for (var i = 1; i < items.count; i++) {
        var it = items.get(i)
        if (!it) continue
        if (it.isSimpleItem && it.command === 16) r.points++
        if (it.surveyAreaPolygon !== undefined) { r.areaM2 = it.coveredArea; r.photos = it.cameraShots }
        else if (it.cameraShots !== undefined && it.cameraShots > 0) r.photos += it.cameraShots
    }
    return r
}

// T: from the caller (QML): words area, waypoint, corridor, structure, mission, photos "%1 photos", points "%1 points",
// items "%1 items", minutes "%1 min", and functions fmtArea(m2), fmtDist(m)
function text(r, T) {
    if (!r) return ""
    var parts = []
    if (r.kind === "area") {
        parts.push(T.area)
        if (isFinite(r.areaM2)) parts.push(T.fmtArea(r.areaM2))
    } else if (r.kind === "waypoint") {
        parts.push(T.waypoint); parts.push(T.points.replace("%1", r.points))
    } else if (r.kind === "corridor") {
        parts.push(T.corridor); if (isFinite(r.distM)) parts.push(T.fmtDist(r.distM))
    } else if (r.kind === "structure") {
        parts.push(T.structure)
    } else {
        parts.push(T.mission); parts.push(T.items.replace("%1", r.items))
    }
    if (isFinite(r.timeSec) && r.timeSec > 0) parts.push(T.minutes.replace("%1", Math.max(1, Math.round(r.timeSec / 60))))
    if (r.photos > 0) parts.push(T.photos.replace("%1", r.photos))
    return parts.join(" · ")
}

// every coordinate the drone flies to or around (S39 check route, map preview): survey transects, corridor / structure
// outlines and all simple items with a coordinate
function route(mission) {
    var pts = []
    if (!mission) return pts
    var items = mission.visualItems
    for (var i = 1; i < items.count; i++) {
        var it = items.get(i)
        if (!it) continue
        var t = it.visualTransectPoints
        if (t && t.length > 0) { for (var k = 0; k < t.length; k++) pts.push(t[k]); continue }
        var poly = it.corridorPolyline !== undefined ? it.corridorPolyline : it.structurePolygon !== undefined ? it.structurePolygon
                 : it.surveyAreaPolygon !== undefined ? it.surveyAreaPolygon : null
        if (poly && poly.path && poly.path.length > 0) { for (var j = 0; j < poly.path.length; j++) pts.push(poly.path[j]); continue }
        if (it.specifiesCoordinate && it.coordinate && it.coordinate.isValid) pts.push(it.coordinate)
    }
    return pts
}

// highest planned height above home over all items (simple altitudes, survey / corridor distance to surface, structure top)
function maxHeight(mission) {
    var m = 0
    if (!mission) return m
    var items = mission.visualItems
    for (var i = 1; i < items.count; i++) {
        var it = items.get(i)
        if (!it) continue
        if (it.isSimpleItem && it.specifiesAltitude && it.altitude) m = Math.max(m, Number(it.altitude.rawValue))
        if (it.cameraCalc && it.cameraCalc.distanceToSurface) m = Math.max(m, Number(it.cameraCalc.distanceToSurface.rawValue))
        if (it.topFlightAlt !== undefined) m = Math.max(m, Number(it.topFlightAlt))
    }
    return m
}

function iconFor(kind) {
    return kind === "area" ? "grid" : kind === "waypoint" ? "pin" : kind === "corridor" ? "corridor" : kind === "structure" ? "structure" : "folder"
}
