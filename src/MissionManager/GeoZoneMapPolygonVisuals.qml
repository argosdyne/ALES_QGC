/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick                          2.11
import QtQuick.Controls                 2.4
import QtLocation                       5.3
import QtPositioning                    5.3
import QtQuick.Dialogs                  1.2
import QtQuick.Layouts                  1.11

import QGroundControl                   1.0
import QGroundControl.ScreenTools       1.0
import QGroundControl.Palette           1.0
import QGroundControl.Controls          1.0
import QGroundControl.FlightMap         1.0
import QGroundControl.ShapeFileHelper   1.0

/// QGCMapPolygon map visuals
Item {
    id: _root

    property var    mapControl                                  ///< Map control to place item in
    property var    mapPolygon                                  ///< QGCMapPolygon object
    property bool   interactive:        mapPolygon.interactive
    property color  interiorColor:      "transparent"
    property color  altColor:           "transparent"
    property real   interiorOpacity:    1
    property int    borderWidth:        0
    property color  borderColor:        "black"

    property bool   _circleMode:                false
    property real   _circleRadius
    property bool   _circleRadiusDrag:          false
    property var    _circleRadiusDragCoord:     QtPositioning.coordinate()
    property bool   _editCircleRadius:          false
    property string _instructionText:           _polygonToolsText
    property var    _savedVertices:             [ ]
    property bool   _savedCircleMode
    property bool   _isVertexBeingDragged:      false

    property real _zorderDragHandle:    QGroundControl.zOrderMapItems + 3   // Highest to prevent splitting when items overlap
    property real _zorderSplitHandle:   QGroundControl.zOrderMapItems + 2
    property real _zorderCenterHandle:  QGroundControl.zOrderMapItems + 1   // Lowest such that drag or split takes precedence

    readonly property string _polygonToolsText: qsTr("Polygon Tools")
    readonly property string _traceText:        qsTr("Click in the map to add vertices. Click 'Done Tracing' when finished.")

    property var    _geoZoneViewSettings:           QGroundControl.settingsManager.geoZoneMakeViewSettings

    function addCommonVisuals() {
        if (_objMgrCommonVisuals.empty) {
            _objMgrCommonVisuals.createObject(polygonComponent, mapControl, true)
        }
    }

    function removeCommonVisuals() {
        _objMgrCommonVisuals.destroyObjects()
    }

    function addEditingVisuals() {
        if (_objMgrEditingVisuals.empty) {
            _objMgrEditingVisuals.createObjects(
                [ dragHandlesComponent, splitHandlesComponent, centerDragHandleComponent, edgeLengthHandlesComponent ], 
                mapControl, 
                false /* addToMap */)
        }
    }

    function removeEditingVisuals() {
        _objMgrEditingVisuals.destroyObjects()
    }

    function addToolbarVisuals() {
        if (_objMgrToolVisuals.empty) {
            // var toolbar = _objMgrToolVisuals.createObject(toolbarComponent, mapControl)
            // toolbar.z = QGroundControl.zOrderWidgets
            //_resetPolygon()
        }
    }

    function removeToolVisuals() {
        _objMgrToolVisuals.destroyObjects()
    }

    function addCircleVisuals() {
        if (_objMgrCircleVisuals.empty) {
            _objMgrCircleVisuals.createObject(radiusVisualsComponent, mapControl)
        }
    }

    /// Calculate the default/initial 4 sided polygon
    function defaultPolygonVertices() {
        // Initial polygon is inset to take 2/3rds space
        var rect = Qt.rect(mapControl.centerViewport.x, mapControl.centerViewport.y, mapControl.centerViewport.width, mapControl.centerViewport.height)
        rect.x += (rect.width * 0.25) / 2
        rect.y += (rect.height * 0.25) / 2
        rect.width *= 0.75
        rect.height *= 0.75

        var centerCoord =       mapControl.toCoordinate(Qt.point(rect.x + (rect.width / 2), rect.y + (rect.height / 2)),   false /* clipToViewPort */)
        var topLeftCoord =      mapControl.toCoordinate(Qt.point(rect.x, rect.y),                                          false /* clipToViewPort */)
        var topRightCoord =     mapControl.toCoordinate(Qt.point(rect.x + rect.width, rect.y),                             false /* clipToViewPort */)
        var bottomLeftCoord =   mapControl.toCoordinate(Qt.point(rect.x, rect.y + rect.height),                            false /* clipToViewPort */)
        var bottomRightCoord =  mapControl.toCoordinate(Qt.point(rect.x + rect.width, rect.y + rect.height),               false /* clipToViewPort */)

        // Initial polygon has max width and height of 3000 meters
        var halfWidthMeters =   Math.min(topLeftCoord.distanceTo(topRightCoord), 3000) / 2
        var halfHeightMeters =  Math.min(topLeftCoord.distanceTo(bottomLeftCoord), 3000) / 2
        topLeftCoord =      centerCoord.atDistanceAndAzimuth(halfWidthMeters, -90).atDistanceAndAzimuth(halfHeightMeters, 0)
        topRightCoord =     centerCoord.atDistanceAndAzimuth(halfWidthMeters, 90).atDistanceAndAzimuth(halfHeightMeters, 0)
        bottomLeftCoord =   centerCoord.atDistanceAndAzimuth(halfWidthMeters, -90).atDistanceAndAzimuth(halfHeightMeters, 180)
        bottomRightCoord =  centerCoord.atDistanceAndAzimuth(halfWidthMeters, 90).atDistanceAndAzimuth(halfHeightMeters, 180)

        return [ topLeftCoord, topRightCoord, bottomRightCoord, bottomLeftCoord  ]
    }

    /// Reset polygon back to initial default
    function _resetPolygon() {
        mapPolygon.beginReset()
        mapPolygon.clear()
        mapPolygon.appendVertices(defaultPolygonVertices())
        mapPolygon.endReset()
        _circleMode = false
    }

    function _createCircularPolygon(center, radius) {
        var unboundCenter = center.atDistanceAndAzimuth(0, 0)
        var segments = 16
        var angleIncrement = 360 / segments
        var angle = 0
        mapPolygon.beginReset()
        mapPolygon.clear()
        _circleRadius = radius
        for (var i=0; i<segments; i++) {
            var vertex = unboundCenter.atDistanceAndAzimuth(radius, angle)
            mapPolygon.appendVertex(vertex)
            angle += angleIncrement
        }
        mapPolygon.endReset()
        _circleMode = true
    }

    function _handleInteractiveChanged() {        
        if (interactive) {
            addEditingVisuals()
            addToolbarVisuals()
        } else {
            mapPolygon.traceMode = false
            removeEditingVisuals()
            removeToolVisuals()
        }
    }

    onInteractiveChanged: _handleInteractiveChanged()

    on_CircleModeChanged: {
        if (_circleMode) {
            addCircleVisuals()
        } else {
            _objMgrCircleVisuals.destroyObjects()
        }
    }

    Connections {
        target: mapPolygon
        onTraceModeChanged: {
            if (mapPolygon.traceMode) {
                _instructionText = _traceText
                _objMgrTraceVisuals.createObject(traceMouseAreaComponent, mapControl, false)
            } else {
                _instructionText = _polygonToolsText
                _objMgrTraceVisuals.destroyObjects()
            }
        }
    }

    Component.onCompleted: {        
        addCommonVisuals()
        _handleInteractiveChanged()
    }
    Component.onDestruction: mapPolygon.traceMode = false

    QGCDynamicObjectManager { id: _objMgrCommonVisuals }
    QGCDynamicObjectManager { id: _objMgrToolVisuals }
    QGCDynamicObjectManager { id: _objMgrEditingVisuals }
    QGCDynamicObjectManager { id: _objMgrTraceVisuals }
    QGCDynamicObjectManager { id: _objMgrCircleVisuals }

    QGCPalette { id: qgcPal }

    Component {
        id: polygonComponent

        MapPolygon {
            color:          mapPolygon.showAltColor ? altColor : interiorColor
            opacity:        interiorOpacity
            border.color:   borderColor
            border.width:   borderWidth
            path:           mapPolygon.path
        }
    }

    Component {
        id: edgeLengthHandleComponent

        MapQuickItem {
            id:             mapQuickItem
            anchorPoint.x:  sourceItem.width / 2
            anchorPoint.y:  sourceItem.height / 2
            visible:        !_circleMode

            property int vertexIndex
            property real distance

            property var _unitsConversion: QGroundControl.unitsConversion

            sourceItem: Text {
              text:     _unitsConversion.metersToAppSettingsHorizontalDistanceUnits(distance).toFixed(1) + " " +
                        _unitsConversion.appSettingsHorizontalDistanceUnitsString
              color:    "white"
            }
        }
    }

    Component {
        id: edgeLengthHandlesComponent

        Repeater {
            model: _isVertexBeingDragged ? mapPolygon.path : undefined

            delegate: Item {
                property var _edgeLengthHandle
                property var _vertices:     mapPolygon.path

                function _setHandlePosition() {
                    var nextIndex = index + 1
                    if (nextIndex > _vertices.length - 1) {
                        nextIndex = 0
                    }
                    var distance = _vertices[index].distanceTo(_vertices[nextIndex])
                    var azimuth = _vertices[index].azimuthTo(_vertices[nextIndex])
                    _edgeLengthHandle.coordinate =_vertices[index].atDistanceAndAzimuth(distance / 3, azimuth)
                    _edgeLengthHandle.distance = distance

                    //console.log("vertical length = ", getEdgeLengths().height, "Horizontal length = ", getEdgeLengths().width)
                    // _geoZoneViewSettings.verticalArea = getEdgeLengths().height
                    // _geoZoneViewSettings.horizontalArea = getEdgeLengths().width
                }

                // function getEdgeLengths() {
                //     if (_vertices.length !== 4)
                //         return { width: 0, height: 0 }

                //     // width: distance between point 0 and 1 (or 2 and 3)
                //     var width = _vertices[0].distanceTo(_vertices[1])

                //     // height: distance between point 1 and 2 (or 0 and 3)
                //     var height = _vertices[1].distanceTo(_vertices[2])

                //     return { width: width, height: height }
                // }


                Component.onCompleted: {
                    _edgeLengthHandle = edgeLengthHandleComponent.createObject(mapControl)
                    _edgeLengthHandle.vertexIndex = index
                    _setHandlePosition()
                    mapControl.addMapItem(_edgeLengthHandle)
                }

                Component.onDestruction: {
                    if (_edgeLengthHandle) {
                        _edgeLengthHandle.destroy()
                    }
                }
            }
        }
    }

    Component {
        id: splitHandlesComponent

        Repeater {
            model: mapPolygon.path

            delegate: Item {
                property var _splitHandle
                property var _vertices:     mapPolygon.path

                function _setHandlePosition() {
                    var nextIndex = index + 1
                    if (nextIndex > _vertices.length - 1) {
                        nextIndex = 0
                    }
                    var distance = _vertices[index].distanceTo(_vertices[nextIndex])
                    var azimuth = _vertices[index].azimuthTo(_vertices[nextIndex])
                }

                Component.onCompleted: {
                    _setHandlePosition()
                }

                Component.onDestruction: {
                    if (_splitHandle) {
                        _splitHandle.destroy()
                    }
                }
            }
        }
    }

    // Control which is used to drag polygon vertices
    Component {
        id: dragAreaComponent

        GeoZoneItemIndicatorDrag {
            id:             dragArea
            mapControl:     _root.mapControl
            z:              _zorderDragHandle
            visible:        !_circleMode
            onDragStart:    _isVertexBeingDragged = true
            onDragStop:     { _isVertexBeingDragged = false; mapPolygon.verifyClockwiseWinding() }

            property int polygonVertex

            property bool _creationComplete: false

            Component.onCompleted: _creationComplete = true

            function sortVerticesByPosition(vertices) {
                if (vertices.length < 4) return vertices;

                // 중심점 계산
                var centerLat = 0;
                var centerLon = 0;
                for (var i = 0; i < vertices.length; i++) {
                    centerLat += vertices[i].latitude;
                    centerLon += vertices[i].longitude;
                }
                centerLat /= vertices.length;
                centerLon /= vertices.length;

                // 각 꼭짓점에 각도 부여 (0° = 동쪽, 90° = 북쪽)
                return vertices.slice().sort(function(a, b) {
                    var angleA = Math.atan2(a.latitude - centerLat, a.longitude - centerLon);
                    var angleB = Math.atan2(b.latitude - centerLat, b.longitude - centerLon);
                    return angleA - angleB;
                });
            }
            onItemCoordinateChanged: {
                if (_creationComplete) {
                    // During component creation some bad coordinate values got through which screws up draw
                    //mapPolygon.adjustVertex(polygonVertex, itemCoordinate)

                    if (_creationComplete && !mapPolygon.inAdjustGeoZoneVertex) {
                        mapPolygon.adjustGeoZoneVertex(polygonVertex, itemCoordinate)

                        //_geoZoneViewSettings.printPolygonSize()

                        // 가로/세로 계산
                        var vertices = mapPolygon.path
                        var sorted = sortVerticesByPosition(mapPolygon.path)
                        if (sorted.length < 4)
                                return;

                        if (sorted.length >= 4) {
                            var width1 = sorted[0].distanceTo(sorted[3]);
                            var width2 = sorted[1].distanceTo(sorted[2]);
                            var height1 = sorted[0].distanceTo(sorted[1]);
                            var height2 = sorted[3].distanceTo(sorted[2]);

                            var avgWidth = (width1 + width2) / 2;
                            var avgHeight = (height1 + height2) / 2;

                            var horizontal = (sorted[0].longitude !== sorted[1].longitude) ?
                                                (sorted[0].distanceTo(sorted[1]) + sorted[3].distanceTo(sorted[2])) / 2 :
                                                (sorted[0].distanceTo(sorted[3]) + sorted[1].distanceTo(sorted[2])) / 2;

                            var vertical = (sorted[0].longitude !== sorted[1].longitude) ?
                                                (sorted[0].distanceTo(sorted[3]) + sorted[1].distanceTo(sorted[2])) / 2 :
                                                (sorted[0].distanceTo(sorted[1]) + sorted[3].distanceTo(sorted[2])) / 2;


                            // _geoZoneViewSettings.setHorizontalSize(horizontal);
                            // _geoZoneViewSettings.setVerticalSize(vertical);
                            _geoZoneViewSettings.horizontalLength = horizontal;
                            _geoZoneViewSettings.verticalLength = vertical;

                            // _geoZoneViewSettings.horizontalArea = horizontal;
                            // _geoZoneViewSettings.verticalArea = vertical;

                            console.log("Fixed Width:", _geoZoneViewSettings.horizontalLength, ", Height:", _geoZoneViewSettings.verticalLength);
                        }
                    }
                }
            }




            // onItemCoordinateChanged: {
            //     if (!_creationComplete || mapPolygon.inAdjustGeoZoneVertex)
            //         return;

            //     if (polygonVertex >= mapPolygon.path.length) {
            //         console.warn("Invalid vertex index:", polygonVertex, "vs", mapPolygon.path.length);
            //         return;
            //     }

            //     mapPolygon.adjustGeoZoneVertex(polygonVertex, itemCoordinate)

            //     var sorted = sortVerticesByPosition(mapPolygon.path)
            //     if (sorted.length < 4)
            //         return;

            //     var width1 = sorted[0].distanceTo(sorted[3]);
            //     var width2 = sorted[1].distanceTo(sorted[2]);
            //     var height1 = sorted[0].distanceTo(sorted[1]);
            //     var height2 = sorted[3].distanceTo(sorted[2]);

            //     var avgWidth = (width1 + width2) / 2;
            //     var avgHeight = (height1 + height2) / 2;

            //     var horizontal = avgWidth >= avgHeight ? avgWidth : avgHeight;
            //     var vertical = avgWidth >= avgHeight ? avgHeight : avgWidth;

            //     Qt.callLater(() => {
            //         _geoZoneViewSettings.horizontalArea = horizontal;
            //         _geoZoneViewSettings.verticalArea = vertical;
            //     });
            // }



            // onItemCoordinateChanged: {
            //     if (_creationComplete) {
            //         console.log("polygonVertex =", polygonVertex)
            //         console.log("itemCoordinate =", itemCoordinate.latitude, itemCoordinate.longitude)

            //         if (polygonVertex < 0 || polygonVertex > 3) {
            //             console.warn("Invalid polygonVertex:", polygonVertex)
            //             return
            //         }

            //         //mapPolygon.adjustVertex(polygonVertex, itemCoordinate)
            //         _geoZoneViewSettings.adjustRectangleByVertex(polygonVertex, itemCoordinate)

            //     }
            // }
        }
    }

    // Connections {
    //     target: _geoZoneViewSettings
    //     onVerticalAreaChanged: {
    //         // if(_geoZoneViewSettings.centerCoord.latitude !== 0 && _geoZoneViewSettings.centerCoord.longitude !== 0){
    //         //     mapPolygon.center = _geoZoneViewSettings.centerCoord
    //         // }
    //     }
    // }

    // Center Icon
    Component {
        id: centerDragHandle
        MapQuickItem {
            id:             mapQuickItem
            anchorPoint.x:  dragHandle.width  * 0.5
            anchorPoint.y:  dragHandle.height * 0.5
            z:              _zorderDragHandle
            sourceItem: Rectangle {
                id:             dragHandle
                width:          ScreenTools.defaultFontPixelHeight * 1.5
                height:         width
                radius:         width * 0.5
                color:          Qt.rgba(1,1,1,0.8)
                border.color:   Qt.rgba(0,0,0,0.25)
                border.width:   1
                QGCColoredImage {
                    width:      parent.width
                    height:     width
                    color:      Qt.rgba(0,0,0,1)
                    mipmap:     true
                    fillMode:   Image.PreserveAspectFit
                    source:     "/qmlimages/MapCenter.svg"
                    sourceSize.height:  height
                    anchors.centerIn:   parent
                }
            }
        }
    }

    //Dragable vertex items
    Component {
        id: dragHandleComponent

        MapQuickItem {
            id:             mapQuickItem
            anchorPoint.x:  dragHandle.width  / 2
            anchorPoint.y:  dragHandle.height / 2
            z:              _zorderDragHandle
            visible:        !_circleMode

            property int polygonVertex

            sourceItem: Rectangle {
                id:             dragHandle
                width:          ScreenTools.defaultFontPixelHeight * 1.5
                height:         width
                radius:         width * 0.5
                color:          Qt.rgba(1,1,1,0.8)
                border.color:   Qt.rgba(0,0,0,0.25)
                border.width:   1
            }
        }
    }

    // Add all polygon vertex drag handles to the map
    Component {
        id: dragHandlesComponent

        Repeater {
            model: mapPolygon.pathModel

            delegate: Item {
                property var _visuals: [ ]

                Component.onCompleted: {
                    var dragHandle = dragHandleComponent.createObject(mapControl)
                    dragHandle.coordinate = Qt.binding(function() { return object.coordinate })
                    dragHandle.polygonVertex = Qt.binding(function() { return index })
                    mapControl.addMapItem(dragHandle)
                    var dragArea = dragAreaComponent.createObject(mapControl, { "itemIndicator": dragHandle, "itemCoordinate": object.coordinate })
                    dragArea.polygonVertex = Qt.binding(function() { return index })
                    _visuals.push(dragHandle)
                    _visuals.push(dragArea)                
                }

                Component.onDestruction: {
                    for (var i=0; i<_visuals.length; i++) {
                        _visuals[i].destroy()
                    }
                    _visuals = [ ]
                }
            }
        }
    }

    Component {
        id: editCenterPositionDialog

        EditPositionDialog {
            title:      qsTr("Edit Center Position")
            coordinate: mapPolygon.center
            onCoordinateChanged: {
                // Prevent spamming signals on vertex changes by setting centerDrag = true when changing center position.
                // This also fixes a bug where Qt gets confused by all the signalling and draws a bad visual.
                mapPolygon.centerDrag = true
                mapPolygon.center = coordinate
                mapPolygon.centerDrag = false
            }
        }
    }

    Component {
        id: editVertexPositionDialog

        EditPositionDialog {
            title:      qsTr("Edit Vertex Position")
            coordinate: mapPolygon.vertexCoordinate(menu._editingVertexIndex)
            onCoordinateChanged: {
                mapPolygon.adjustVertex(menu._editingVertexIndex, coordinate)
                mapPolygon.verifyClockwiseWinding()
            }
        }
    }

    Component {
        id: centerDragAreaComponent

        GeoZoneItemIndicatorDrag {
            mapControl:                 _root.mapControl
            z:                          _zorderCenterHandle
            onDragStart:                mapPolygon.centerDrag = true
            onDragStop:                 mapPolygon.centerDrag = false
            onItemCoordinateChanged:    {
                mapPolygon.center = itemCoordinate
                _geoZoneViewSettings.centerCoord = mapPolygon.center
            }
        }
    }

    Connections {
        target: _geoZoneViewSettings
        onCenterCoordChanged: {
            if(_geoZoneViewSettings.centerCoord.latitude !== 0 && _geoZoneViewSettings.centerCoord.longitude !== 0){
                mapPolygon.center = _geoZoneViewSettings.centerCoord
            }
        }
    }

    //About Drag Center Item
    Component {
        id: centerDragHandleComponent

        Item {
            property var dragHandle
            property var dragArea

            Component.onCompleted: {
                dragHandle = centerDragHandle.createObject(mapControl)
                dragHandle.coordinate = Qt.binding(function() { return mapPolygon.center })
                mapControl.addMapItem(dragHandle)
                dragArea = centerDragAreaComponent.createObject(mapControl, { "itemIndicator": dragHandle, "itemCoordinate": mapPolygon.center })

                console.log("centerDragHandleComponent oncompleted")
                _geoZoneViewSettings.centerCoord = dragHandle.coordinate
            }

            Component.onDestruction: {
                dragHandle.destroy()
                dragArea.destroy()
            }
        }
    }


    // Mouse area to capture clicks for tracing a polygon
    Component {
        id:  traceMouseAreaComponent

        MouseArea {
            anchors.fill:       mapControl
            preventStealing:    true
            z:                  QGroundControl.zOrderMapItems + 1   // Over item indicators

            onClicked: {
                if (mouse.button === Qt.LeftButton && _root.interactive) {
                    mapPolygon.appendVertex(mapControl.toCoordinate(Qt.point(mouse.x, mouse.y), false /* clipToViewPort */))
                }
            }
        }
    }

    Component {
        id: radiusDragHandleComponent

        MapQuickItem {
            id:             mapQuickItem
            anchorPoint.x:  dragHandle.width / 2
            anchorPoint.y:  dragHandle.height / 2
            z:              QGroundControl.zOrderMapItems + 2

            sourceItem: Rectangle {
                id:         dragHandle
                width:      ScreenTools.defaultFontPixelHeight * 1.5
                height:     width
                radius:     width / 2
                color:      "white"
                opacity:    interiorOpacity * .90
            }
        }
    }

    Component {
        id: radiusDragAreaComponent

        GeoZoneItemIndicatorDrag {
            mapControl: _root.mapControl

            property real _lastRadius

            onItemCoordinateChanged: {
                var radius = mapPolygon.center.distanceTo(itemCoordinate)
                // Prevent signalling re-entrancy
                if (!_circleRadiusDrag && Math.abs(radius - _lastRadius) > 0.1) {
                    _circleRadiusDrag = true
                    _createCircularPolygon(mapPolygon.center, radius)
                    _circleRadiusDragCoord = itemCoordinate
                    _circleRadiusDrag = false
                    _lastRadius = radius
                }
            }
        }
    }

    Component {
        id: radiusVisualsComponent

        Item {
            property var    circleCenterCoord:  mapPolygon.center

            function _calcRadiusDragCoord() {
                _circleRadiusDragCoord = circleCenterCoord.atDistanceAndAzimuth(_circleRadius, 90)
            }

            onCircleCenterCoordChanged: {
                if (!_circleRadiusDrag) {
                    _calcRadiusDragCoord()
                }
            }

            QGCDynamicObjectManager {
                id: _objMgr
            }

            Component.onCompleted: {
                _calcRadiusDragCoord()
                var radiusDragHandle = _objMgr.createObject(radiusDragHandleComponent, mapControl, true)
                radiusDragHandle.coordinate = Qt.binding(function() { return _circleRadiusDragCoord })
                var radiusDragIndicator = radiusDragAreaComponent.createObject(mapControl, { "itemIndicator": radiusDragHandle, "itemCoordinate": _circleRadiusDragCoord })
                _objMgr.addObject(radiusDragIndicator)
            }
        }
    }
}

