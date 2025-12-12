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
    property color  _borderColor:               boundaryColor
    property int    _borderWidthInclusion:      2
    property int    _borderWidthExclusion:      0
    property color  _interiorColorExclusion:    "orange"
    property color  _interiorColorInclusion:    "transparent"
    property real   _interiorOpacityExclusion:  0.2 * opacity * fenceOpacity
    property real   _interiorOpacityInclusion:  1 * opacity * fenceOpacity
    property real   _extrudeHeightPx:           ScreenTools.defaultFontPixelHeight * 20
    property int    _circleSegmentsExtrude:     40
    property bool   show3DView:                 false
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
        for (var i = 0; i < _circleSegmentsExtrude; i++) {
            var az = (360 / _circleSegmentsExtrude) * i
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

    function _segmentizeVertical(startCoord, endCoord) {
        if (!map || !startCoord || !endCoord || !startCoord.isValid || !endCoord.isValid || typeof map.fromCoordinate !== "function" || typeof map.toCoordinate !== "function") {
            return [[startCoord, endCoord]]
        }

        var startPt = map.fromCoordinate(startCoord, false)
        var endPt = map.fromCoordinate(endCoord, false)
        if (!startPt || !endPt) {
            return [[startCoord, endCoord]]
        }

        var segments = []
        var count = breachStyle === Qt.DotLine ? 28 : 1
        var drawRatio = breachStyle === Qt.DotLine ? 0.25 : 1.0

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
        var p1 = map.fromCoordinate(path[0], false)
        var p2 = map.fromCoordinate(path[1], false)
        if (!p1 || !p2) {
            return _extrudeHeightPx
        }
        var dx = p2.x - p1.x
        var dy = p2.y - p1.y
        var basePx = Math.sqrt(dx * dx + dy * dy)
        return Math.min(Math.max(basePx, ScreenTools.defaultFontPixelHeight * 10), ScreenTools.defaultFontPixelHeight * 40)
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
            interiorColor:      object.inclusion ? _interiorColorInclusion : _interiorColorExclusion
            interiorOpacity:    (object.inclusion ? _interiorOpacityInclusion : _interiorOpacityExclusion)
            interactive:        _root.interactive && mapPolygon && mapPolygon.interactive
        }
    }

    // 3D-style extrusion of polygon fences using vertical line segments
    Repeater {
        model: show3DView ? _polygons : 0

        Item {
            id: extrudePoly
            property var basePath: _normalizedPath(_polygonPath(object))
            property real _mapKey: map ? (map.zoomLevel + map.bearing + map.tilt) : 0
            property real heightPx: { _mapKey; return _extrudeHeight(basePath) }
            property var topPath: { _mapKey; return _extrudePath(basePath, heightPx) }
            property var topPathClosed: { _mapKey; return _closedPath(topPath) }
            property color edgeColor: _edgeColor(object)
            property color faceColor: Qt.rgba(edgeColor.r, edgeColor.g, edgeColor.b, Math.min(0.65, Math.max(0.25, fenceOpacity * 0.5)))
            visible: show3DView && topPath.length > 2 && basePath.length === topPath.length

            MapPolyline {
                property var mapRef: map
                z: QGroundControl.zOrderMapItems + 1
                parent: mapRef
                visible: extrudePoly.visible && mapRef
                path: extrudePoly.topPathClosed
                line.width: 3
                line.color: edgeColor
                opacity: _root.opacity * fenceOpacity
                antialiasing: true
                Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
            }

            MapPolygon {
                property var mapRef: map
                z: QGroundControl.zOrderMapItems + 1
                parent: mapRef
                path: topPath
                color: faceColor
                border.width: 1
                border.color: edgeColor
                opacity: _root.opacity * fenceOpacity
                antialiasing: true
                visible: extrudePoly.visible && mapRef && topPath.length > 2
                Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
            }

            Repeater {
                model: extrudePoly.visible ? extrudePoly.basePath.length : 0
                delegate: Item {
                    property int vertexIndex: index
                    Repeater {
                        model: _segmentizeVertical(extrudePoly.basePath[vertexIndex], extrudePoly.topPath[vertexIndex])
                        MapPolyline {
                            property var mapRef: map
                            z: QGroundControl.zOrderMapItems + 1
                        parent: mapRef
                        path: modelData
                        line.width: 3
                        line.color: edgeColor
                        opacity: _root.opacity * fenceOpacity
                        antialiasing: true
                        Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
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
                        color: faceColor
                        border.width: 1
                        border.color: edgeColor
                        opacity: _root.opacity * fenceOpacity
                        antialiasing: true
                        Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
                    }
                }
            }
        }
    }

    Instantiator {
        model: _circles

        delegate : QGCMapCircleVisuals {
            parent:             _root
            mapControl:         map
            mapCircle:          object
            borderWidth:        object.inclusion ? _borderWidthInclusion : _borderWidthExclusion
            borderColor:        _borderColor
            interiorColor:      object.inclusion ? _interiorColorInclusion : _interiorColorExclusion
            interiorOpacity:    (object.inclusion ? _interiorOpacityInclusion : _interiorOpacityExclusion)
            interactive:         _root.interactive && mapCircle && mapCircle.interactive
        }
    }

    // 3D-style extrusion of circular fences using vertical line segments
    Repeater {
        model: show3DView ? _circles : 0

        Item {
            id: extrudeCircle
            property var basePath: _circlePath(object)
            property real _mapKey: map ? (map.zoomLevel + map.bearing + map.tilt) : 0
            property real heightPx: { _mapKey; return _extrudeHeight(basePath) }
            property var topPath: { _mapKey; return _extrudePath(basePath, heightPx) }
            property var topPathClosed: { _mapKey; return _closedPath(topPath) }
            property color edgeColor: _edgeColor(object)
            visible: show3DView && topPath.length > 6 && basePath.length === topPath.length

            MapPolyline {
                property var mapRef: map
                z: QGroundControl.zOrderMapItems + 1
                parent: mapRef
                visible: extrudeCircle.visible && mapRef
                path: extrudeCircle.topPathClosed
                line.width: 3
                line.color: edgeColor
                opacity: _root.opacity * fenceOpacity
                antialiasing: true
                Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
            }

            Repeater {
                model: extrudeCircle.visible ? extrudeCircle.basePath.length : 0
                delegate: Item {
                    property int vertexIndex: index
                    Repeater {
                        model: _segmentizeVertical(extrudeCircle.basePath[vertexIndex], extrudeCircle.topPath[vertexIndex])
                        MapPolyline {
                            property var mapRef: map
                            z: QGroundControl.zOrderMapItems + 1
                        parent: mapRef
                        path: modelData
                        line.width: 3
                        line.color: edgeColor
                        opacity: _root.opacity * fenceOpacity
                        antialiasing: true
                        Component.onCompleted: { if (mapRef && mapRef.addMapItem) mapRef.addMapItem(this) }
                    }
                }
            }
            }
        }
    }

    // Circular geofence specified from parameter
    Component {
        id: paramCircleFenceComponent

        MapCircle {
            color:          _interiorColorInclusion
            opacity:        _interiorOpacityInclusion
            border.color:   _borderColor
            border.width:   _borderWidthInclusion
            center:         homePosition
            radius:         _radius
            visible:        homePosition.isValid && _radius > 0

            property real _radius: myGeoFenceController.paramCircularFence

            on_RadiusChanged: console.log("_radius", _radius, homePosition.isValid, homePosition)
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

            sourceItem: MissionItemIndexLabel {
                label:      qsTr("B", "Breach Return Point item indicator")
                checked:    true
            }
        }
    }
}
