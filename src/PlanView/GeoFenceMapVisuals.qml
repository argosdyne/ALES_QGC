/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.3
import QtQuick.Controls 1.2
import QtLocation       5.3
import QtPositioning    5.3

import QGroundControl               1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controls      1.0
import QGroundControl.FlightMap     1.0

/// GeoFence map visuals
Item {
    id: _root
    z: QGroundControl.zOrderMapItems

    property var    map
    property var    myGeoFenceController
    property bool   interactive:            false   ///< true: user can interact with items
    property bool   planView:               false   ///< true: visuals showing in plan view
    property var    homePosition

    property var    _breachReturnPointComponent
    property var    _breachReturnDragComponent
    property var    _paramCircleFenceComponent
    property var    _polygons:                  myGeoFenceController.polygons
    property var    _circles:                   myGeoFenceController.circles
    property color  boundaryColor:              "orange"
    property real   fenceOpacity:               1.0
    property bool   fillTopFace:                false
    property bool   fillSideFaces:              false
    property bool   showOperationalLayer:       true
    property bool   showBufferLayer:            true
    property bool   showContingencyLayer:       true
    property color  _borderColor:               boundaryColor
    property int    _borderWidthInclusion:      2
    property int    _borderWidthExclusion:      0
    property color  _interiorColorExclusion:    "orange"
    property color  _interiorColorInclusion:    "transparent"
    property real   _interiorOpacityExclusion:  0.2 * opacity * fenceOpacity
    property real   _interiorOpacityInclusion:  1 * opacity * fenceOpacity
    property real   fenceMarginMeters:          (myGeoFenceController && myGeoFenceController.fenceMargin && myGeoFenceController.fenceMargin.rawValue !== undefined) ? myGeoFenceController.fenceMargin.rawValue : 0
    property real   contingencyWidthMeters:     (myGeoFenceController && myGeoFenceController.cvWidthMeters !== undefined) ? myGeoFenceController.cvWidthMeters : 0
    property color  marginColor:                Qt.rgba(boundaryColor.r, boundaryColor.g, boundaryColor.b, 0.6)
    property color  contingencyColor:           Qt.rgba(1.0, 0.0, 0.0, 0.55)
    property real   _sideFaceOpacityScale:      0.6
    property real   _sideFaceAltOpacityScale:   0.85
    property real   _extrudeHeightPx:           ScreenTools.defaultFontPixelHeight * 20
    property int    _circleSegmentsExtrude:     40
    property int    circleSegments:            40
    property bool   show3DView:                 false
    property bool   showMinMaxAltitude:         false
    property real   extrudeScale:               1.0
    property real   minExtrudeScale:            0.6
    property real   maxExtrudeScale:            1.6
    property bool   hideOccludedEdges:          true
    property bool   showOccludedEdgesDashed:    false
    property int    breachStyle:                Qt.SolidLine

    function addPolygon(inclusionPolygon) {
        // Initial polygon is inset to take 2/3rds space
        var rect = Qt.rect(map.centerViewport.x, map.centerViewport.y, map.centerViewport.width, map.centerViewport.height)
        rect.x += (rect.width * 0.25) / 2
        rect.y += (rect.height * 0.25) / 2
        rect.width *= 0.75
        rect.height *= 0.75

        var centerCoord =       map.toCoordinate(Qt.point(rect.x + (rect.width / 2), rect.y + (rect.height / 2)),   false /* clipToViewPort */)
        var topLeftCoord =      map.toCoordinate(Qt.point(rect.x, rect.y),                                          false /* clipToViewPort */)
        var topRightCoord =     map.toCoordinate(Qt.point(rect.x + rect.width, rect.y),                             false /* clipToViewPort */)
        var bottomLeftCoord =   map.toCoordinate(Qt.point(rect.x, rect.y + rect.height),                            false /* clipToViewPort */)
        var bottomRightCoord =  map.toCoordinate(Qt.point(rect.x + rect.width, rect.y + rect.height),               false /* clipToViewPort */)

        // Initial polygon has max width and height of 3000 meters
        var halfWidthMeters =   Math.min(topLeftCoord.distanceTo(topRightCoord), 3000) / 2
        var halfHeightMeters =  Math.min(topLeftCoord.distanceTo(bottomLeftCoord), 3000) / 2
        topLeftCoord =      centerCoord.atDistanceAndAzimuth(halfWidthMeters, -90).atDistanceAndAzimuth(halfHeightMeters, 0)
        topRightCoord =     centerCoord.atDistanceAndAzimuth(halfWidthMeters, 90).atDistanceAndAzimuth(halfHeightMeters, 0)
        bottomLeftCoord =   centerCoord.atDistanceAndAzimuth(halfWidthMeters, -90).atDistanceAndAzimuth(halfHeightMeters, 180)
        bottomRightCoord =  centerCoord.atDistanceAndAzimuth(halfWidthMeters, 90).atDistanceAndAzimuth(halfHeightMeters, 180)

        console.log(map.center)
        console.log(topLeftCoord)
        console.log(bottomRightCoord)

        if (inclusionPolygon) {
            myGeoFenceController.addInclusion(topLeftCoord, bottomRightCoord)
        } else {
            myGeoFenceController.addExclusion(topLeftCoord, bottomRightCoord)
        }
    }

    Component.onCompleted: {
        _breachReturnPointComponent = breachReturnPointComponent.createObject(map)
        map.addMapItem(_breachReturnPointComponent)
        _breachReturnDragComponent = breachReturnDragComponent.createObject(map, { "itemIndicator": _breachReturnPointComponent })
        _paramCircleFenceComponent = paramCircleFenceComponent.createObject(map)
        map.addMapItem(_paramCircleFenceComponent)
    }

    Component.onDestruction: {
        _breachReturnPointComponent.destroy()
        _breachReturnDragComponent.destroy()
        _paramCircleFenceComponent.destroy()
    }

    function _polygonPath(poly) {
        if (!poly) {
            return []
        }
        if (typeof poly.coordinateList === "function") {
            return poly.coordinateList()
        }
        if (poly.path && poly.path.length > 2) {
            return poly.path
        }
        return []
    }

    function _circlePath(circle) {
        if (!circle || !circle.center || !circle.center.isValid) {
            return []
        }
        var radius = 0
        if (circle.radius) {
            radius = circle.radius.rawValue ? circle.radius.rawValue : circle.radius
        }
        if (radius <= 0) {
            return []
        }
        var pts = []
        var count = Math.max(12, circleSegments > 0 ? circleSegments : _circleSegmentsExtrude)
        for (var i = 0; i < count; i++) {
            var az = (360 / count) * i
            pts.push(circle.center.atDistanceAndAzimuth(radius, az))
        }
        return pts
    }

    function _extrudePath(basePath, heightPx) {
        if (!map || !basePath || basePath.length === 0 || heightPx <= 0 || typeof map.fromCoordinate !== "function" || typeof map.toCoordinate !== "function") {
            return []
        }
        var top = []
        for (var i = 0; i < basePath.length; i++) {
            var pt = map.fromCoordinate(basePath[i], false)
            if (!pt) {
                return []
            }
            // shift upward in screen space and slight left for faux perspective
            pt.y -= heightPx
            pt.x -= (heightPx * 0.18)
            top.push(map.toCoordinate(Qt.point(pt.x, pt.y), false))
        }
        return top
    }

    function _pillarTops(basePath, heightPx) {
        if (!map || !basePath || basePath.length === 0 || heightPx <= 0 || typeof map.fromCoordinate !== "function" || typeof map.toCoordinate !== "function") {
            return []
        }
        var tops = []
        for (var i = 0; i < basePath.length; i++) {
            var pt = map.fromCoordinate(basePath[i], false)
            if (!pt) {
                return []
            }
            pt.y -= heightPx
            pt.x -= (heightPx * 0.12)
            tops.push(map.toCoordinate(Qt.point(pt.x, pt.y), false))
        }
        return tops
    }

    function _offsetCoordinate(coord, dx, dy) {
        if (!map || !coord || !coord.isValid || typeof map.fromCoordinate !== "function" || typeof map.toCoordinate !== "function") {
            return coord
        }
        var pt = map.fromCoordinate(coord, false)
        if (!pt) {
            return coord
        }
        pt.x += dx
        pt.y += dy
        return map.toCoordinate(Qt.point(pt.x, pt.y), false)
    }

    function _closedPath(pathArray) {
        if (!pathArray || pathArray.length < 2) {
            return pathArray ? pathArray : []
        }
        var closed = pathArray.slice(0)
        closed.push(pathArray[0])
        return closed
    }

    function _normalizedPath(pathArray) {
        if (!pathArray || pathArray.length === 0) {
            return []
        }
        var norm = pathArray.slice(0)
        if (norm.length > 1) {
            var first = norm[0]
            var last = norm[norm.length - 1]
            var same = first.latitude === last.latitude && first.longitude === last.longitude
            if (same) {
                norm.pop()
            }
        }
        return norm
    }

    function _segmentizeVertical(startCoord, endCoord, dotted) {
        if (!map || !startCoord || !endCoord || !startCoord.isValid || !endCoord.isValid || typeof map.fromCoordinate !== "function" || typeof map.toCoordinate !== "function") {
            return [[startCoord, endCoord]]
        }

        var startPt = map.fromCoordinate(startCoord, false)
        var endPt = map.fromCoordinate(endCoord, false)
        if (!startPt || !endPt) {
            return [[startCoord, endCoord]]
        }

        var segments = []
        var useDotted = dotted || breachStyle === Qt.DotLine
        var count = useDotted ? 28 : 1
        var drawRatio = useDotted ? 0.25 : 1.0

        for (var i = 0; i < count; i++) {
            var t0 = i / count
            var t1 = Math.min(1, t0 + (drawRatio / count))
            var p0 = Qt.point(startPt.x + (endPt.x - startPt.x) * t0, startPt.y + (endPt.y - startPt.y) * t0)
            var p1 = Qt.point(startPt.x + (endPt.x - startPt.x) * t1, startPt.y + (endPt.y - startPt.y) * t1)
            var c0 = map.toCoordinate(p0, false)
            var c1 = map.toCoordinate(p1, false)
            segments.push([c0, c1])
        }

        return segments
    }

    function _segmentizeEdge(startCoord, endCoord, dotted) {
        if (!map || !startCoord || !endCoord || !startCoord.isValid || !endCoord.isValid || typeof map.fromCoordinate !== "function" || typeof map.toCoordinate !== "function") {
            return [[startCoord, endCoord]]
        }

        var startPt = map.fromCoordinate(startCoord, false)
        var endPt = map.fromCoordinate(endCoord, false)
        if (!startPt || !endPt) {
            return [[startCoord, endCoord]]
        }

        var segments = []
        var count = dotted ? 28 : 1
        var drawRatio = dotted ? 0.25 : 1.0

        for (var i = 0; i < count; i++) {
            var t0 = i / count
            var t1 = Math.min(1, t0 + (drawRatio / count))
            var p0 = Qt.point(startPt.x + (endPt.x - startPt.x) * t0, startPt.y + (endPt.y - startPt.y) * t0)
            var p1 = Qt.point(startPt.x + (endPt.x - startPt.x) * t1, startPt.y + (endPt.y - startPt.y) * t1)
            var c0 = map.toCoordinate(p0, false)
            var c1 = map.toCoordinate(p1, false)
            segments.push([c0, c1])
        }

        return segments
    }

    function _visibleEdgeMask(basePath, topPath) {
        if (!map || !basePath || !topPath || basePath.length < 2 || basePath.length !== topPath.length || typeof map.fromCoordinate !== "function") {
            return []
        }

        var basePts = []
        for (var i = 0; i < basePath.length; i++) {
            var pt = map.fromCoordinate(basePath[i], false)
            if (!pt) {
                return []
            }
            basePts.push(pt)
        }

        var basePt0 = basePts[0]
        var topPt0 = map.fromCoordinate(topPath[0], false)
        if (!topPt0) {
            return []
        }
        var v = Qt.point(topPt0.x - basePt0.x, topPt0.y - basePt0.y)
        if (v.x === 0 && v.y === 0) {
            return []
        }
        var view = Qt.point(-v.x, -v.y)
        var viewLen = Math.sqrt(view.x * view.x + view.y * view.y)
        if (viewLen < 0.001) {
            return []
        }
        view.x /= viewLen
        view.y /= viewLen

        var area = 0
        for (i = 0; i < basePts.length; i++) {
            var p = basePts[i]
            var n = basePts[(i + 1) % basePts.length]
            area += (p.x * n.y) - (n.x * p.y)
        }
        var ccw = area > 0
        var epsilon = -0.01

        var mask = []
        for (i = 0; i < basePts.length; i++) {
            var p0 = basePts[i]
            var p1 = basePts[(i + 1) % basePts.length]
            var dx = p1.x - p0.x
            var dy = p1.y - p0.y
            var normal = ccw ? Qt.point(dy, -dx) : Qt.point(-dy, dx)
            var visDot = (normal.x * view.x) + (normal.y * view.y)
            mask.push(visDot > epsilon)
        }

        return mask
    }

    function _visibleVertexMask(edgeMask) {
        if (!edgeMask || edgeMask.length === 0) {
            return []
        }
        var mask = []
        for (var i = 0; i < edgeMask.length; i++) {
            var prev = (i - 1 + edgeMask.length) % edgeMask.length
            mask.push(edgeMask[i] || edgeMask[prev])
        }
        return mask
    }

    function _visibleVertexMaskByCenter(basePath, topPath) {
        if (!map || !basePath || !topPath || basePath.length < 2 || basePath.length !== topPath.length || typeof map.fromCoordinate !== "function") {
            return []
        }

        var basePts = []
        for (var i = 0; i < basePath.length; i++) {
            var pt = map.fromCoordinate(basePath[i], false)
            if (!pt) {
                return []
            }
            basePts.push(pt)
        }

        var basePt0 = basePts[0]
        var topPt0 = map.fromCoordinate(topPath[0], false)
        if (!topPt0) {
            return []
        }
        var v = Qt.point(topPt0.x - basePt0.x, topPt0.y - basePt0.y)
        if (v.x === 0 && v.y === 0) {
            return []
        }
        var view = Qt.point(-v.x, -v.y)
        var viewLen = Math.sqrt(view.x * view.x + view.y * view.y)
        if (viewLen < 0.001) {
            return []
        }
        view.x /= viewLen
        view.y /= viewLen

        var center = Qt.point(0, 0)
        for (i = 0; i < basePts.length; i++) {
            center.x += basePts[i].x
            center.y += basePts[i].y
        }
        center.x /= basePts.length
        center.y /= basePts.length

        var mask = []
        for (i = 0; i < basePts.length; i++) {
            var d = Qt.point(basePts[i].x - center.x, basePts[i].y - center.y)
            var dot = (d.x * view.x) + (d.y * view.y)
            mask.push(dot > 0)
        }
        return mask
    }

    function _rightmostCoord(pathArray) {
        if (!map || !pathArray || pathArray.length === 0 || typeof map.fromCoordinate !== "function") {
            return pathArray && pathArray.length > 0 ? pathArray[0] : QtPositioning.coordinate()
        }
        var bestCoord = pathArray[0]
        var bestPt = map.fromCoordinate(bestCoord, false)
        if (!bestPt) {
            return bestCoord
        }
        for (var i = 1; i < pathArray.length; i++) {
            var pt = map.fromCoordinate(pathArray[i], false)
            if (pt && pt.x > bestPt.x) {
                bestPt = pt
                bestCoord = pathArray[i]
            }
        }
        return bestCoord
    }

    function _edgeColor(polyObj) {
        if (polyObj && polyObj.inclusion === false) {
            return Qt.rgba(boundaryColor.r, boundaryColor.g, boundaryColor.b, Math.max(0.15, fenceOpacity * 0.6))
        }
        return boundaryColor
    }

    function _extrudeHeight(path) {
        if (!map || !path || path.length < 2 || typeof map.fromCoordinate !== "function") {
            return _extrudeHeightPx
        }
        var scale = Math.min(Math.max(extrudeScale, minExtrudeScale), maxExtrudeScale)
        var p1 = map.fromCoordinate(path[0], false)
        var p2 = map.fromCoordinate(path[1], false)
        if (!p1 || !p2) {
            return _extrudeHeightPx
        }
        var dx = p2.x - p1.x
        var dy = p2.y - p1.y
        var basePx = Math.sqrt(dx * dx + dy * dy)
        var minPx = ScreenTools.defaultFontPixelHeight * 10 * minExtrudeScale
        var maxPx = ScreenTools.defaultFontPixelHeight * 40 * maxExtrudeScale
        return Math.min(Math.max(basePx * scale, minPx), maxPx)
    }

    // By default the parent for Instantiator.delegate item is the Instatiator itself. By there is a bug
    // in Qt which will cause a crash if this delete item has Menu item within it. Since the Menu item
    // doesn't like having a non-visual item as parent. This is likely related to hybrid QQuickWidtget+QML
    // Hence Qt folks are going to care. In order to workaround you have to parent the item to _root Item instead.
    Instantiator {
        model: _polygons

        delegate : QGCMapPolygonVisuals {
            parent:             _root
            mapControl:         map
            mapPolygon:         object
            borderWidth:        object.inclusion ? _borderWidthInclusion : _borderWidthExclusion
            borderColor:        _borderColor
            interiorColor:      (show3DView && fillTopFace) ? boundaryColor : (object.inclusion ? _interiorColorInclusion : _interiorColorExclusion)
            interiorOpacity:    (show3DView && !fillTopFace) ? 0 : (object.inclusion ? _interiorOpacityInclusion : _interiorOpacityExclusion)
            interactive:        _root.interactive && mapPolygon && mapPolygon.interactive
            visible:            _root.showOperationalLayer
        }
    }

    Repeater {
        model: (showBufferLayer && fenceMarginMeters > 0) ? _polygons : 0

        Item {
            property var mapRef: map
            property var _polygon: object
            property var _marginPath: []

            function _updateMarginPath() {
                if (!_polygon || fenceMarginMeters <= 0) {
                    _marginPath = []
                    return
                }
                _marginPath = _closedPath(_polygon.offsetPath(_polygon.inclusion ? -fenceMarginMeters : fenceMarginMeters))
            }

            MapPolyline {
                parent: mapRef
                z: QGroundControl.zOrderMapItems + 1
                path: _marginPath
                line.width: 1
                line.color: marginColor
                opacity: _root.opacity * fenceOpacity
                antialiasing: true
                visible: mapRef && path.length > 2
                Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
            }

            Connections {
                target: _polygon
                function onPathChanged() { _updateMarginPath() }
            }

            Connections {
                target: _root
                function onFenceMarginMetersChanged() { _updateMarginPath() }
            }

            Component.onCompleted: _updateMarginPath()
        }
    }

    Repeater {
        model: (showContingencyLayer && contingencyWidthMeters > 0) ? _polygons : 0

        Item {
            property var mapRef: map
            property var _polygon: object
            property var _cvPath: []

            function _updateCvPath() {
                if (!_polygon || !_polygon.inclusion || contingencyWidthMeters <= 0) {
                    _cvPath = []
                    return
                }
                _cvPath = _closedPath(_polygon.offsetPath(contingencyWidthMeters))
            }

            MapPolyline {
                parent: mapRef
                z: QGroundControl.zOrderMapItems + 1
                path: _cvPath
                line.width: 2
                line.color: contingencyColor
                opacity: _root.opacity * fenceOpacity
                antialiasing: true
                visible: mapRef && path.length > 2
                Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
            }

            Connections {
                target: _polygon
                function onPathChanged() { _updateCvPath() }
            }

            Connections {
                target: _root
                function onContingencyWidthMetersChanged() { _updateCvPath() }
            }

            Component.onCompleted: _updateCvPath()
        }
    }

    // 3D-style extrusion of polygon fences using vertical line segments
    Repeater {
        model: (show3DView && showOperationalLayer) ? _polygons : 0

        Item {
            id: extrudePoly
            property var basePath: _normalizedPath(_polygonPath(object))
            property real _mapKey: map ? (map.zoomLevel + map.bearing + map.tilt + extrudeScale + minExtrudeScale + maxExtrudeScale) : 0
            property real heightPx: { _mapKey; return _extrudeHeight(basePath) }
            property var topPath: { _mapKey; return _extrudePath(basePath, heightPx) }
            property var topPathClosed: { _mapKey; return _closedPath(topPath) }
            property color edgeColor: _edgeColor(object)
            property color faceColor: {
                if (!fillSideFaces || !object) {
                    return "transparent"
                }
                var alpha = (object.inclusion === false ? _interiorOpacityExclusion : _interiorOpacityInclusion) * _sideFaceOpacityScale
                return Qt.rgba(edgeColor.r, edgeColor.g, edgeColor.b, alpha)
            }
            property color topFaceColor: {
                if (!fillTopFace || !object) {
                    return "transparent"
                }
                var alpha = object.inclusion === false ? _interiorOpacityExclusion : _interiorOpacityInclusion
                return Qt.rgba(edgeColor.r, edgeColor.g, edgeColor.b, alpha)
            }
            property var edgeVisible: { _mapKey; return _visibleEdgeMask(basePath, topPath) }
            property var vertexVisible: { _mapKey; return _visibleVertexMask(edgeVisible) }
            property real _labelOffsetX: ScreenTools.defaultFontPixelWidth * 8
            property var minLabelCoord: { _mapKey; return _offsetCoordinate(_rightmostCoord(basePath), _labelOffsetX, 0) }
            property var maxLabelCoord: { _mapKey; return _offsetCoordinate(_rightmostCoord(topPath), _labelOffsetX, 0) }
            visible: show3DView && topPath.length > 2 && basePath.length === topPath.length

            Repeater {
                model: extrudePoly.visible ? extrudePoly.topPath.length : 0
                MapPolyline {
                    property var mapRef: map
                    z: QGroundControl.zOrderMapItems + 1
                    parent: mapRef
                    visible: extrudePoly.visible && mapRef
                    path: [
                        extrudePoly.topPath[index],
                        extrudePoly.topPath[(index + 1) % extrudePoly.topPath.length]
                    ]
                    line.width: object && object.inclusion ? _borderWidthInclusion : _borderWidthExclusion
                    line.color: edgeColor
                    opacity: _root.opacity * fenceOpacity
                    antialiasing: true
                    Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
                }
            }

            Repeater {
                model: extrudePoly.visible ? extrudePoly.basePath.length : 0
                Item {
                    property int edgeIndex: index
                    property bool _edgeVisible: (extrudePoly.edgeVisible.length === 0 && extrudePoly.vertexVisible.length === 0) ||
                                                (extrudePoly.edgeVisible[edgeIndex] &&
                                                 extrudePoly.vertexVisible[edgeIndex] &&
                                                 extrudePoly.vertexVisible[(edgeIndex + 1) % extrudePoly.basePath.length])
                    property bool _showOccludedDashed: hideOccludedEdges && showOccludedEdgesDashed
                    property var _edgeStart: extrudePoly.basePath[edgeIndex]
                    property var _edgeEnd: extrudePoly.basePath[(edgeIndex + 1) % extrudePoly.basePath.length]
                    property var _dashedSegments: _showOccludedDashed && !_edgeVisible ? _segmentizeEdge(_edgeStart, _edgeEnd, true) : []

                    MapPolyline {
                        property var mapRef: map
                        z: QGroundControl.zOrderMapItems + 1
                        parent: mapRef
                        visible: extrudePoly.visible && mapRef &&
                                 (!hideOccludedEdges || _edgeVisible)
                        path: [_edgeStart, _edgeEnd]
                        line.width: object && object.inclusion ? _borderWidthInclusion : _borderWidthExclusion
                        line.color: edgeColor
                        opacity: _root.opacity * fenceOpacity
                        antialiasing: true
                        Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
                    }

                    Repeater {
                        model: _dashedSegments.length
                        MapPolyline {
                            property var mapRef: map
                            z: QGroundControl.zOrderMapItems + 1
                            parent: mapRef
                            visible: extrudePoly.visible && mapRef && _showOccludedDashed && !_edgeVisible
                            path: _dashedSegments[index]
                            line.width: object && object.inclusion ? _borderWidthInclusion : _borderWidthExclusion
                            line.color: edgeColor
                            opacity: _root.opacity * fenceOpacity
                            antialiasing: true
                            Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
                        }
                    }
                }
            }

            MapPolygon {
                property var mapRef: map
                z: QGroundControl.zOrderMapItems + 1
                parent: mapRef
                path: topPath
                color: topFaceColor
                border.width: object && object.inclusion ? _borderWidthInclusion : _borderWidthExclusion
                border.color: edgeColor
                opacity: _root.opacity
                antialiasing: true
                visible: extrudePoly.visible && mapRef && topPath.length > 2
                Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
            }

            Repeater {
                model: extrudePoly.visible ? extrudePoly.basePath.length : 0
                delegate: Item {
                    property int vertexIndex: index
                    property bool _vertexVisible: extrudePoly.vertexVisible.length === 0 || extrudePoly.vertexVisible[vertexIndex]
                    property bool _showOccludedDashed: hideOccludedEdges && showOccludedEdgesDashed
                    property var _solidSegments: _segmentizeVertical(extrudePoly.basePath[vertexIndex], extrudePoly.topPath[vertexIndex], false)
                    property var _dashedSegments: _showOccludedDashed && !_vertexVisible ? _segmentizeVertical(extrudePoly.basePath[vertexIndex], extrudePoly.topPath[vertexIndex], true) : []

                    Repeater {
                        model: _solidSegments.length
                        MapPolyline {
                            property var mapRef: map
                            z: QGroundControl.zOrderMapItems + 1
                            parent: mapRef
                            path: _solidSegments[index]
                            line.width: object && object.inclusion ? _borderWidthInclusion : _borderWidthExclusion
                            line.color: edgeColor
                            visible: !hideOccludedEdges || _vertexVisible
                            opacity: _root.opacity * fenceOpacity
                            antialiasing: true
                            Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
                        }
                    }

                    Repeater {
                        model: _dashedSegments.length
                        MapPolyline {
                            property var mapRef: map
                            z: QGroundControl.zOrderMapItems + 1
                            parent: mapRef
                            path: _dashedSegments[index]
                            line.width: object && object.inclusion ? _borderWidthInclusion : _borderWidthExclusion
                            line.color: edgeColor
                            visible: _showOccludedDashed && !_vertexVisible
                            opacity: _root.opacity * fenceOpacity
                            antialiasing: true
                            Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
                        }
                    }
                }
            }

            // Vertical faces (quads) for shading
            Repeater {
                model: extrudePoly.visible ? extrudePoly.basePath.length : 0
                MapPolygon {
                    property var mapRef: map
                    z: QGroundControl.zOrderMapItems + 1
                    parent: mapRef
                    path: [
                        extrudePoly.basePath[index],
                        extrudePoly.basePath[(index + 1) % extrudePoly.basePath.length],
                        extrudePoly.topPath[(index + 1) % extrudePoly.topPath.length],
                        extrudePoly.topPath[index]
                    ]
                    color: {
                        if (!faceColor || faceColor === "transparent") {
                            return faceColor
                        }
                        var alpha = faceColor.a
                        var scale = (index % 2 === 0) ? 1.0 : _sideFaceAltOpacityScale
                        return Qt.rgba(faceColor.r, faceColor.g, faceColor.b, alpha * scale)
                    }
                    border.width: hideOccludedEdges ? 0 : (object && object.inclusion ? _borderWidthInclusion : _borderWidthExclusion)
                    border.color: edgeColor
                    opacity: _root.opacity
                    antialiasing: true
                    Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
                }
            }

            MapQuickItem {
                visible:            _root.showMinMaxAltitude && extrudePoly.visible && extrudePoly.basePath.length > 0
                coordinate:         minLabelCoord
                z:                  QGroundControl.zOrderMapItems + 2
                property var mapRef: map
                parent:             mapRef
                anchorPoint.x:      minLabelItem.width / 2
                anchorPoint.y:      minLabelItem.height / 2
                sourceItem: QGCLabel {
                    id: minLabelItem
                    text: qsTr("Min Altitude: %1").arg(minExtrudeScale.toFixed(2))
                    color: edgeColor
                }
                Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
            }

            MapQuickItem {
                visible:            _root.showMinMaxAltitude && extrudePoly.visible && extrudePoly.topPath.length > 0
                coordinate:         maxLabelCoord
                z:                  QGroundControl.zOrderMapItems + 2
                property var mapRef: map
                parent:             mapRef
                anchorPoint.x:      maxLabelItem.width / 2
                anchorPoint.y:      maxLabelItem.height / 2
                sourceItem: QGCLabel {
                    id: maxLabelItem
                    text: qsTr("Max Altitude: %1").arg(maxExtrudeScale.toFixed(2))
                    color: edgeColor
                }
                Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
            }
        }
    }

    Instantiator {
        model: showOperationalLayer ? _circles : 0

        delegate : QGCMapCircleVisuals {
            parent:             _root
            mapControl:         map
            mapCircle:          object
            borderWidth:        object.inclusion ? _borderWidthInclusion : _borderWidthExclusion
            borderColor:        _borderColor
            interiorColor:      (show3DView && fillTopFace) ? boundaryColor : (object.inclusion ? _interiorColorInclusion : _interiorColorExclusion)
            interiorOpacity:    (show3DView && !fillTopFace) ? 0 : (object.inclusion ? _interiorOpacityInclusion : _interiorOpacityExclusion)
            interactive:         _root.interactive && mapCircle && mapCircle.interactive
        }
    }

    Repeater {
        model: (showBufferLayer && fenceMarginMeters > 0) ? _circles : 0

        MapCircle {
            property var mapRef: map
            parent: mapRef
            z: QGroundControl.zOrderMapItems + 1
            center: object.center
            radius: object.inclusion ? Math.max(0, object.radius.rawValue - fenceMarginMeters) : object.radius.rawValue + fenceMarginMeters
            color: "transparent"
            border.color: marginColor
            border.width: 1
            opacity: _root.opacity * fenceOpacity
            visible: mapRef && center.isValid && radius > 0
            Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
        }
    }

    Repeater {
        model: (showContingencyLayer && contingencyWidthMeters > 0) ? _circles : 0

        MapCircle {
            property var mapRef: map
            parent: mapRef
            z: QGroundControl.zOrderMapItems + 1
            center: object.center
            radius: object.inclusion ? object.radius.rawValue + contingencyWidthMeters : 0
            color: "transparent"
            border.color: contingencyColor
            border.width: 2
            opacity: _root.opacity * fenceOpacity
            visible: mapRef && object.inclusion && center.isValid && radius > 0
            Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
        }
    }

    // 3D-style extrusion of circular fences using vertical line segments
    Repeater {
        model: (show3DView && showOperationalLayer) ? _circles : 0

        Item {
            id: extrudeCircle
            property var basePath: _circlePath(object)
            property real _mapKey: map ? (map.zoomLevel + map.bearing + map.tilt + extrudeScale + minExtrudeScale + maxExtrudeScale) : 0
            property real heightPx: { _mapKey; return _extrudeHeight(basePath) }
            property var topPath: { _mapKey; return _extrudePath(basePath, heightPx) }
            property var topPathClosed: { _mapKey; return _closedPath(topPath) }
            property color edgeColor: _edgeColor(object)
            property color faceColor: {
                if (!fillSideFaces || !object) {
                    return "transparent"
                }
                var alpha = (object.inclusion === false ? _interiorOpacityExclusion : _interiorOpacityInclusion) * _sideFaceOpacityScale
                return Qt.rgba(edgeColor.r, edgeColor.g, edgeColor.b, alpha)
            }
            property color topFaceColor: {
                if (!fillTopFace || !object) {
                    return "transparent"
                }
                var alpha = object.inclusion === false ? _interiorOpacityExclusion : _interiorOpacityInclusion
                return Qt.rgba(edgeColor.r, edgeColor.g, edgeColor.b, alpha)
            }
            property var edgeVisible: { _mapKey; return _visibleEdgeMask(basePath, topPath) }
            property var vertexVisible: { _mapKey; return _visibleVertexMask(edgeVisible) }
            property real _labelOffsetX: ScreenTools.defaultFontPixelWidth * 8
            property var minLabelCoord: { _mapKey; return _offsetCoordinate(_rightmostCoord(basePath), _labelOffsetX, 0) }
            property var maxLabelCoord: { _mapKey; return _offsetCoordinate(_rightmostCoord(topPath), _labelOffsetX, 0) }
            visible: show3DView && topPath.length > 6 && basePath.length === topPath.length

            Repeater {
                model: extrudeCircle.visible ? extrudeCircle.topPath.length : 0
                MapPolyline {
                    property var mapRef: map
                    z: QGroundControl.zOrderMapItems + 1
                    parent: mapRef
                    visible: extrudeCircle.visible && mapRef
                    path: [
                        extrudeCircle.topPath[index],
                        extrudeCircle.topPath[(index + 1) % extrudeCircle.topPath.length]
                    ]
                    line.width: object && object.inclusion ? _borderWidthInclusion : _borderWidthExclusion
                    line.color: edgeColor
                    opacity: _root.opacity * fenceOpacity
                    antialiasing: true
                    Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
                }
            }

            Repeater {
                model: extrudeCircle.visible ? extrudeCircle.basePath.length : 0
                Item {
                    property int edgeIndex: index
                    property bool _edgeVisible: (extrudeCircle.edgeVisible.length === 0 && extrudeCircle.vertexVisible.length === 0) ||
                                                (extrudeCircle.edgeVisible[edgeIndex] &&
                                                 extrudeCircle.vertexVisible[edgeIndex] &&
                                                 extrudeCircle.vertexVisible[(edgeIndex + 1) % extrudeCircle.basePath.length])
                    property bool _showOccludedDashed: hideOccludedEdges && showOccludedEdgesDashed
                    property var _edgeStart: extrudeCircle.basePath[edgeIndex]
                    property var _edgeEnd: extrudeCircle.basePath[(edgeIndex + 1) % extrudeCircle.basePath.length]
                    property var _dashedSegments: _showOccludedDashed && !_edgeVisible ? _segmentizeEdge(_edgeStart, _edgeEnd, true) : []

                    MapPolyline {
                        property var mapRef: map
                        z: QGroundControl.zOrderMapItems + 1
                        parent: mapRef
                        visible: extrudeCircle.visible && mapRef &&
                                 (!hideOccludedEdges || _edgeVisible)
                        path: [_edgeStart, _edgeEnd]
                        line.width: object && object.inclusion ? _borderWidthInclusion : _borderWidthExclusion
                        line.color: edgeColor
                        opacity: _root.opacity * fenceOpacity
                        antialiasing: true
                        Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
                    }

                    Repeater {
                        model: _dashedSegments.length
                        MapPolyline {
                            property var mapRef: map
                            z: QGroundControl.zOrderMapItems + 1
                            parent: mapRef
                            visible: extrudeCircle.visible && mapRef && _showOccludedDashed && !_edgeVisible
                            path: _dashedSegments[index]
                            line.width: object && object.inclusion ? _borderWidthInclusion : _borderWidthExclusion
                            line.color: edgeColor
                            opacity: _root.opacity * fenceOpacity
                            antialiasing: true
                            Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
                        }
                    }
                }
            }

            MapPolygon {
                property var mapRef: map
                z: QGroundControl.zOrderMapItems + 1
                parent: mapRef
                path: topPath
                color: topFaceColor
                border.width: object && object.inclusion ? _borderWidthInclusion : _borderWidthExclusion
                border.color: edgeColor
                opacity: _root.opacity
                antialiasing: true
                visible: extrudeCircle.visible && mapRef && topPath.length > 6
                Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
            }

            Repeater {
                model: extrudeCircle.visible ? extrudeCircle.basePath.length : 0
                delegate: Item {
                    property int vertexIndex: index
                    property bool _vertexVisible: extrudeCircle.vertexVisible.length === 0 || extrudeCircle.vertexVisible[vertexIndex]
                    property bool _showOccludedDashed: hideOccludedEdges && showOccludedEdgesDashed
                    property var _solidSegments: _segmentizeVertical(extrudeCircle.basePath[vertexIndex], extrudeCircle.topPath[vertexIndex], false)
                    property var _dashedSegments: _showOccludedDashed && !_vertexVisible ? _segmentizeVertical(extrudeCircle.basePath[vertexIndex], extrudeCircle.topPath[vertexIndex], true) : []

                    Repeater {
                        model: _solidSegments.length
                        MapPolyline {
                            property var mapRef: map
                            z: QGroundControl.zOrderMapItems + 1
                            parent: mapRef
                            path: _solidSegments[index]
                            line.width: object && object.inclusion ? _borderWidthInclusion : _borderWidthExclusion
                            line.color: edgeColor
                            visible: !hideOccludedEdges || _vertexVisible
                            opacity: _root.opacity * fenceOpacity
                            antialiasing: true
                            Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
                        }
                    }

                    Repeater {
                        model: _dashedSegments.length
                        MapPolyline {
                            property var mapRef: map
                            z: QGroundControl.zOrderMapItems + 1
                            parent: mapRef
                            path: _dashedSegments[index]
                            line.width: object && object.inclusion ? _borderWidthInclusion : _borderWidthExclusion
                            line.color: edgeColor
                            visible: _showOccludedDashed && !_vertexVisible
                            opacity: _root.opacity * fenceOpacity
                            antialiasing: true
                            Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
                        }
                    }
                }
            }

            // Vertical faces (quads) for shading
            Repeater {
                model: extrudeCircle.visible ? extrudeCircle.basePath.length : 0
                MapPolygon {
                    property var mapRef: map
                    z: QGroundControl.zOrderMapItems + 1
                    parent: mapRef
                    path: [
                        extrudeCircle.basePath[index],
                        extrudeCircle.basePath[(index + 1) % extrudeCircle.basePath.length],
                        extrudeCircle.topPath[(index + 1) % extrudeCircle.topPath.length],
                        extrudeCircle.topPath[index]
                    ]
                    color: {
                        if (!faceColor || faceColor === "transparent") {
                            return faceColor
                        }
                        var alpha = faceColor.a
                        var scale = (index % 2 === 0) ? 1.0 : _sideFaceAltOpacityScale
                        return Qt.rgba(faceColor.r, faceColor.g, faceColor.b, alpha * scale)
                    }
                    border.width: hideOccludedEdges ? 0 : (object && object.inclusion ? _borderWidthInclusion : _borderWidthExclusion)
                    border.color: edgeColor
                    opacity: _root.opacity
                    antialiasing: true
                    Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
                }
            }

            MapQuickItem {
                visible:            _root.showMinMaxAltitude && extrudeCircle.visible && extrudeCircle.basePath.length > 0
                coordinate:         minLabelCoord
                z:                  QGroundControl.zOrderMapItems + 2
                property var mapRef: map
                parent:             mapRef
                anchorPoint.x:      minCircleLabelItem.width / 2
                anchorPoint.y:      minCircleLabelItem.height / 2
                sourceItem: QGCLabel {
                    id: minCircleLabelItem
                    text: qsTr("Min Altitude: %1").arg(minExtrudeScale.toFixed(2))
                    color: edgeColor
                }
                Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
            }

            MapQuickItem {
                visible:            _root.showMinMaxAltitude && extrudeCircle.visible && extrudeCircle.topPath.length > 0
                coordinate:         maxLabelCoord
                z:                  QGroundControl.zOrderMapItems + 2
                property var mapRef: map
                parent:             mapRef
                anchorPoint.x:      maxCircleLabelItem.width / 2
                anchorPoint.y:      maxCircleLabelItem.height / 2
                sourceItem: QGCLabel {
                    id: maxCircleLabelItem
                    text: qsTr("Max Altitude: %1").arg(maxExtrudeScale.toFixed(2))
                    color: edgeColor
                }
                Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
            }
        }
    }

    // Circular geofence specified from parameter
    Component {
        id: paramCircleFenceComponent

        Item {
            property var mapRef: map
            property real _radius: myGeoFenceController.paramCircularFence
            property real _margin: _root.fenceMarginMeters
            property real _cvWidth: _root.contingencyWidthMeters

            MapCircle {
                parent:         mapRef
                color:          (show3DView && fillTopFace) ? boundaryColor : _interiorColorInclusion
                opacity:        (show3DView && !fillTopFace) ? 0 : _interiorOpacityInclusion
                border.color:   _borderColor
                border.width:   _borderWidthInclusion
                center:         homePosition
                radius:         _radius
                visible:        showOperationalLayer && homePosition.isValid && _radius > 0
                Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
            }

            MapCircle {
                parent:         mapRef
                color:          "transparent"
                border.color:   marginColor
                border.width:   1
                center:         homePosition
                radius:         Math.max(0, _radius - _margin)
                opacity:        _root.opacity * fenceOpacity
                visible:        showBufferLayer && homePosition.isValid && _radius > 0 && _margin > 0 && radius > 0
                Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
            }

            MapCircle {
                parent:         mapRef
                color:          "transparent"
                border.color:   contingencyColor
                border.width:   2
                center:         homePosition
                radius:         _radius + _cvWidth
                opacity:        _root.opacity * fenceOpacity
                visible:        showContingencyLayer && homePosition.isValid && _radius > 0 && _cvWidth > 0
                Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
            }
        }
    }

    Component {
        id: breachReturnDragComponent

        MissionItemIndicatorDrag {
            mapControl:     map
            itemCoordinate: myGeoFenceController.breachReturnPoint
            visible:        _root.interactive

            onItemCoordinateChanged: myGeoFenceController.breachReturnPoint = itemCoordinate
        }
    }


    // Breach return point
    Component {
        id: breachReturnPointComponent

        MapQuickItem {
            anchorPoint.x:  sourceItem.anchorPointX
            anchorPoint.y:  sourceItem.anchorPointY
            z:              QGroundControl.zOrderMapItems
            coordinate:     myGeoFenceController.breachReturnPoint
            opacity:        _root.opacity
            visible:        _root.showOperationalLayer

            sourceItem: MissionItemIndexLabel {
                label:      qsTr("B", "Breach Return Point item indicator")
                checked:    true
            }
        }
    }
}
