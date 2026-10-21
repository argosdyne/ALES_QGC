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

/// GeoCage pseudo-3D map visuals (base + elevated outline to hint height)
Item {
    id: _root
    z: QGroundControl.zOrderMapItems + 5

    property var    map
    property var    myGeoCageController
    property bool   interactive:        false   ///< true: user can interact with items
    property var    homePosition
    property real   cageOpacity:        0.35
    property color  boundaryColor:      "#ff3d00"
    property bool   showVertical:       true
    property int    breachStyle:        Qt.SolidLine   // Qt.SolidLine, Qt.DashLine, Qt.DotLine
    property bool   useFenceGeometry:   false

    readonly property real _radiusMeters:  myGeoCageController && myGeoCageController.cageRadius ? myGeoCageController.cageRadius.rawValue : 0
    readonly property real _maxAltMeters:  myGeoCageController && myGeoCageController.cageMaxAltitude ? myGeoCageController.cageMaxAltitude.rawValue : 0

    property var _baseCoords: []
    property var _topCoords: []
    property var _centerCoord: QtPositioning.coordinate()
    property int _circleSegments: 32
    property var _pillarCoords: []
    property var _edgeExtrudeCoords: []

    function _buildSquare(center, radiusMeters) {
        if (!center.isValid || radiusMeters <= 0) {
            return []
        }
        var p1 = center.atDistanceAndAzimuth(radiusMeters, -135)
        var p2 = center.atDistanceAndAzimuth(radiusMeters,  -45)
        var p3 = center.atDistanceAndAzimuth(radiusMeters,   45)
        var p4 = center.atDistanceAndAzimuth(radiusMeters,  135)
        return [p1, p2, p3, p4]
    }

    function _buildCirclePath(center, radiusMeters) {
        if (!center.isValid || radiusMeters <= 0) {
            return []
        }
        var pts = []
        for (var i = 0; i < _circleSegments; i++) {
            var az = (360 / _circleSegments) * i
            pts.push(center.atDistanceAndAzimuth(radiusMeters, az))
        }
        return pts
    }

    function _baseFromFence() {
        var coords = []
        if (myGeoCageController && myGeoCageController.circles && myGeoCageController.circles.count > 0) {
            var circle = myGeoCageController.circles.get(0)
            if (circle && circle.radius && circle.radius.rawValue > 0 && circle.center && circle.center.isValid) {
                _centerCoord = circle.center
                coords = _buildCirclePath(circle.center, circle.radius.rawValue)
            }
        } else if (myGeoCageController && myGeoCageController.polygons && myGeoCageController.polygons.count > 0) {
            var poly = myGeoCageController.polygons.get(0)
            if (poly) {
                // Prefer coordinateList() to ensure QGeoCoordinates
                if (typeof poly.coordinateList === "function") {
                    coords = poly.coordinateList()
                } else if (poly.path && poly.path.length > 2) {
                    coords = poly.path
                }

                // rough centroid for label/height calculations
                if (coords.length > 0) {
                    var minLat = coords[0].latitude
                    var maxLat = coords[0].latitude
                    var minLon = coords[0].longitude
                    var maxLon = coords[0].longitude
                    for (var i = 1; i < coords.length; i++) {
                        var c = coords[i]
                        minLat = Math.min(minLat, c.latitude)
                        maxLat = Math.max(maxLat, c.latitude)
                        minLon = Math.min(minLon, c.longitude)
                        maxLon = Math.max(maxLon, c.longitude)
                    }
                    _centerCoord = QtPositioning.coordinate((minLat + maxLat) / 2, (minLon + maxLon) / 2)
                } else if (poly.center && poly.center.isValid) {
                    _centerCoord = poly.center
                }
            }
        }
        return coords
    }

    function _pixelsPerMeter(centerCoord) {
        if (!map || !centerCoord || !centerCoord.isValid || typeof map.fromCoordinate !== "function") {
            return 1
        }
        var c1 = centerCoord
        var c2 = centerCoord.atDistanceAndAzimuth(1, 0)
        var p1 = map.fromCoordinate(c1, false)
        var p2 = map.fromCoordinate(c2, false)
        if (!p1 || !p2) {
            return 1
        }
        var dx = p2.x - p1.x
        var dy = p2.y - p1.y
        return Math.max(1, Math.sqrt(dx * dx + dy * dy))
    }

    function _extrudePath(basePath, heightPx) {
        if (!map || heightPx <= 0 || typeof map.fromCoordinate !== "function" || typeof map.toCoordinate !== "function") {
            return basePath
        }
        var top = []
        for (var i = 0; i < basePath.length; i++) {
            var pt = map.fromCoordinate(basePath[i], false)
            if (!pt) {
                return basePath
            }
            // shift upward in screen space and slightly left for perspective
            pt.y = pt.y - heightPx
            pt.x = pt.x - (heightPx * 0.22)
            var coord = map.toCoordinate(Qt.point(pt.x, pt.y), false)
            top.push(coord)
        }
        return top
    }

    function _buildPillars(basePath, heightPx) {
        if (!map || heightPx <= 0 || typeof map.fromCoordinate !== "function" || typeof map.toCoordinate !== "function") {
            return []
        }
        var tops = []
        for (var i = 0; i < basePath.length; i++) {
            var pt = map.fromCoordinate(basePath[i], false)
            if (!pt) {
                return []
            }
            pt.y = pt.y - heightPx
            pt.x = pt.x - (heightPx * 0.18)
            tops.push(map.toCoordinate(Qt.point(pt.x, pt.y), false))
        }
        return tops
    }

    function _effectiveHeightPixels(centerCoord, radius) {
        var meters = _maxAltMeters > 0 ? _maxAltMeters : Math.max(radius * 0.8, 50)
        var pxPerM = _pixelsPerMeter(centerCoord)
        var hPx = meters * pxPerM
        return Math.min(Math.max(hPx, 60), 450) // clamp for visibility
    }

    function _refreshCoords() {
        var basePath = []
        var centerCoord = (homePosition && homePosition.isValid) ? homePosition : QtPositioning.coordinate()
        var radius = _radiusMeters

        if (useFenceGeometry) {
            basePath = _baseFromFence()
            if (_centerCoord && _centerCoord.isValid) {
                centerCoord = _centerCoord
            }
            if (basePath.length === 0 && centerCoord.isValid && radius > 0) {
                basePath = _buildSquare(centerCoord, radius)
            }
        }

        if (basePath.length === 0) {
            if (!centerCoord.isValid) {
                if (map && map.center && map.center.isValid) {
                    centerCoord = map.center
                }
            }
            if (radius <= 0) {
                radius = 50
            }
            if (centerCoord.isValid) {
                basePath = _buildSquare(centerCoord, radius)
            }
        }

        if (basePath.length < 3) {
            _baseCoords = []
            _topCoords = []
            _pillarCoords = []
            _edgeExtrudeCoords = []
            return
        }

        // derive a rough radius for height scaling if we came from polygon
        if (useFenceGeometry && radius <= 0 && _centerCoord && _centerCoord.isValid) {
            radius = _centerCoord.distanceTo(basePath[0])
        }

        var heightPx = _effectiveHeightPixels(centerCoord, radius)
        _baseCoords = basePath
        _topCoords = _extrudePath(basePath, heightPx)
        _pillarCoords = _buildPillars(basePath, heightPx * 0.6)
        _edgeExtrudeCoords = _extrudePath(basePath, heightPx * 0.8)
    }

    on_RadiusMetersChanged: _refreshCoords()
    on_MaxAltMetersChanged: _refreshCoords()
    onHomePositionChanged:  _refreshCoords()
    onUseFenceGeometryChanged: _refreshCoords()
    Component.onCompleted:  _refreshCoords()

    MapPolygon {
        id: baseFace
        border.width:   3
        border.color:   boundaryColor
        color:          Qt.rgba(boundaryColor.r, boundaryColor.g, boundaryColor.b, cageOpacity)
        visible:        _baseCoords && _baseCoords.length > 2
        path:           _baseCoords && _baseCoords.length > 2 ? _baseCoords : []
        opacity:        _root.opacity
        antialiasing:   true
    }

    MapPolygon {
        id: topFace
        border.width:   3
        border.color:   boundaryColor
        color:          Qt.rgba(boundaryColor.r, boundaryColor.g, boundaryColor.b, cageOpacity * 0.65)
        visible:        _topCoords && _topCoords.length > 2 && showVertical
        path:           _topCoords && _topCoords.length > 2 ? _topCoords : []
        opacity:        _root.opacity
        antialiasing:   true
    }

    Repeater {
        model: (_baseCoords.length >= 3 && _topCoords.length === _baseCoords.length) ? _baseCoords.length : 0

        MapPolygon {
            visible:    showVertical
            path: [
                _baseCoords[index],
                _baseCoords[(index + 1) % _baseCoords.length],
                _topCoords[(index + 1) % _topCoords.length],
                _topCoords[index]
            ]
            color:      Qt.rgba(boundaryColor.r, boundaryColor.g, boundaryColor.b, cageOpacity * 0.35)
            border.width: 2
            border.color: boundaryColor
            opacity:    _root.opacity
            antialiasing: true
        }
    }

    MapPolyline {
        visible:    _topCoords && _topCoords.length > 2 && showVertical
        line.width: 3
        line.color: boundaryColor
        opacity:    _root.opacity
        path:       _topCoords && _topCoords.length > 2 ? _topCoords : []
        antialiasing: true
    }

    // Edge guide lines (vát) from base edges toward extruded edge (accent only)
    MapPolyline {
        visible:    _edgeExtrudeCoords && _edgeExtrudeCoords.length === _baseCoords.length && _baseCoords.length >= 2
        line.width: 3
        line.color: boundaryColor
        opacity:    _root.opacity * 0.9
        path:       _edgeExtrudeCoords && _edgeExtrudeCoords.length > 0 ? _edgeExtrudeCoords : []
        antialiasing: true
    }

    Repeater {
        model: (_baseCoords.length >= 3 && _topCoords.length === _baseCoords.length) ? _baseCoords.length : 0

        MapPolyline {
            visible:    showVertical
            line.width: 3
            line.color: boundaryColor
            opacity:    _root.opacity
            path: [ _baseCoords[index], _topCoords[index] ]
            antialiasing: true
        }
    }

    Repeater {
        model: (_baseCoords.length >= 3 && _pillarCoords.length === _baseCoords.length) ? _baseCoords.length : 0

        MapPolyline {
            line.width: 3
            line.color: boundaryColor
            opacity:    _root.opacity
            path: [ _baseCoords[index], _pillarCoords[index] ]
            antialiasing: true
        }
    }

    // Altitude label at the top center
    MapQuickItem {
        visible:        topFace.visible
        coordinate:     _topCoords.length > 0 ? _topCoords[1] : homePosition
        anchorPoint.x:  labelItem.width / 2
        anchorPoint.y:  labelItem.height
        sourceItem: Rectangle {
            id: labelItem
            color:      qgcPal.window
            radius:     ScreenTools.defaultFontPixelWidth * 0.25
            border.color: qgcPal.text
            border.width: 1
            anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
            anchors.centerIn: textItem
            QGCLabel {
                id: textItem
                anchors.margins: ScreenTools.defaultFontPixelWidth * 0.5
                anchors.centerIn: parent
                text: qsTr("Max Alt %1 m").arg(_maxAltMeters > 0 ? _maxAltMeters.toFixed(0) : "")
                color: qgcPal.text
            }
        }
    }
}
