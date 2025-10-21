/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick                      2.11
import QtQuick.Controls             2.4
import QtLocation                   5.3
import QtPositioning                5.3
import QtQuick.Dialogs              1.2

import QGroundControl                   1.0
import QGroundControl.ScreenTools       1.0
import QGroundControl.Palette           1.0
import QGroundControl.Controls          1.0
import QGroundControl.FlightMap         1.0
import QGroundControl.ShapeFileHelper   1.0

/// QGCMapPolyline map visuals
Item {
    id: _root

    property var    missionItem:            null
    property var    transectPoints:         missionItem.visualTransectPoints
    property var    _splitHandle
    property var    _splitArea

    property var    mapControl                  ///< Map control to place item in
    property var    mapPolyline                 ///< QGCMapPolyline object
    property bool   interactive:    mapPolyline.interactive
    property int    lineWidth:      3
    property color  lineColor:      "#be781c"

    property var    _dragHandlesComponent
    property var    _splitHandlesComponent
    property string _instructionText:       _corridorToolsText
    property real   _zorderDragHandle:      QGroundControl.zOrderMapItems + 3   // Highest to prevent splitting when items overlap
    property real   _zorderSplitHandle:     QGroundControl.zOrderMapItems + 2
    property real _zorderCenterHandle:  QGroundControl.zOrderMapItems + 1
    property var    _savedVertices:         [ ]

    readonly property string _corridorToolsText:    qsTr("Polyline Tools")
    readonly property string _traceText:            qsTr("Click in the map to add vertices. Click 'Done Tracing' when finished.")

    function _addCommonVisuals() {
        if (_objMgrCommonVisuals.empty) {
            _objMgrCommonVisuals.createObject(mapControl, true)
        }
    }

    function _addInteractiveVisuals() {
        if (_objMgrInteractiveVisuals.empty) {
            // ★ polyline이 비어있을 때만 리셋 ★
            if (mapPolyline.count < 2) {
                _resetPolyline()
            }
            _objMgrInteractiveVisuals.createObjects([splitHandlesComponent ], mapControl)
        }
    }

     function _defaultPolylineVertices() {
        // 화면 중심점을 시작점으로 사용
        var centerX = mapControl.centerViewport.x + (mapControl.centerViewport.width / 2)
        var centerY = mapControl.centerViewport.y + (mapControl.centerViewport.height / 2)
        var centerCoord = mapControl.toCoordinate(Qt.point(centerX, centerY), false /* clipToViewPort */)

        // 고정 길이 30m
        var lineLength = 30.0  // meters

        // 기본 방향: 북쪽(0도) 또는 원하는 방향
        var bearing = 0.0  // 0 = North, 90 = East, 180 = South, 270 = West

        // 시작점: 중심에서 15m 뒤
        var startPoint = centerCoord.atDistanceAndAzimuth(lineLength / 2, bearing + 180)

        // 끝점: 중심에서 15m 앞
        var endPoint = centerCoord.atDistanceAndAzimuth(lineLength / 2, bearing)

        return [ startPoint, endPoint ]
    }

    /// Reset polyline back to initial default
    function _resetPolyline() {
        mapPolyline.beginReset()
        mapPolyline.clear()
        var initialVertices = _defaultPolylineVertices()
        mapPolyline.appendVertex(initialVertices[0])
        mapPolyline.appendVertex(initialVertices[1])
        mapPolyline.endReset()

        console.log("Transect points count = ", transectPoints.length)
    }

    function _saveCurrentVertices() {
        _savedVertices = [ ]
        for (var i=0; i<mapPolyline.count; i++) {
            _savedVertices.push(mapPolyline.vertexCoordinate(i))
        }
    }

    function _restorePreviousVertices() {
        mapPolyline.beginReset()
        mapPolyline.clear()
        for (var i=0; i<_savedVertices.length; i++) {
            mapPolyline.appendVertex(_savedVertices[i])
        }
        mapPolyline.endReset()
    }

    onInteractiveChanged: {
        if (interactive) {
            _addInteractiveVisuals()
        } else {
            _objMgrInteractiveVisuals.destroyObjects()
        }
    }

    Connections {
        target: mapPolyline
        onTraceModeChanged: {
            if (mapPolyline.traceMode) {
                _instructionText = _traceText
                _objMgrTraceVisuals.createObject(traceMouseAreaComponent, mapControl, false)
            } else {
                _instructionText = _corridorToolsText
                _objMgrTraceVisuals.destroyObjects()
            }
        }
    }

    Component.onCompleted: {
        _addCommonVisuals()
        if (interactive) {
            _addInteractiveVisuals()
        }        
    }
    Component.onDestruction: mapPolyline.traceMode = false

    QGCDynamicObjectManager { id: _objMgrCommonVisuals }
    QGCDynamicObjectManager { id: _objMgrInteractiveVisuals }
    QGCDynamicObjectManager { id: _objMgrTraceVisuals }

    QGCPalette { id: qgcPal }

    QGCFileDialog {
        id:             kmlLoadDialog
        folder:         QGroundControl.settingsManager.appSettings.missionSavePath
        title:          qsTr("Select KML File")
        selectExisting: true
        nameFilters:    ShapeFileHelper.fileDialogKMLFilters

        onAcceptedForLoad: {
            mapPolyline.loadKMLFile(file)
            close()
        }
    }

    QGCMenu {
        id: menu
        property int _removeVertexIndex

        function popUpWithIndex(curIndex) {
            _removeVertexIndex = curIndex
            removeVertexItem.visible = mapPolyline.count > 2
            menu.popup()
        }

        QGCMenuItem {
            id:             removeVertexItem
            text:           qsTr("Remove vertex" )
            onTriggered:    mapPolyline.removeVertex(menu._removeVertexIndex)
        }

        QGCMenuItem {
            text:           qsTr("Edit position..." )
            onTriggered:    editPositionDialog.createObject(mainWindow, { coordinate: mapPolyline.path[menu._removeVertexIndex] }).open()
        }
    }

    Component {
        id: editPositionDialog

        EditPositionDialog {
            onCoordinateChanged: mapPolyline.adjustVertex(menu._removeVertexIndex,coordinate)
        }
    }

    Component {
        id: splitHandleComponent

        MapQuickItem {
            id:             mapQuickItem
            anchorPoint.x:  sourceItem.width / 2
            anchorPoint.y:  sourceItem.height / 2
            z:              _zorderSplitHandle
            opacity:        _root.opacity

            property int vertexIndex

            sourceItem: SplitIndicator {
                onClicked:  {
                    mapPolyline.splitSegment(mapQuickItem.vertexIndex)
                    console.log("Center BTN Click")
                }

            }
        }
    }

    function _setHandlePosition() {
        if (!transectPoints || transectPoints.length < 2) {
            console.warn("⚠️ transectPoints not ready or invalid:", transectPoints)
            return
        }

        var distance = transectPoints[1].distanceTo(transectPoints[2]) //_vertices[index].distanceTo(_vertices[nextIndex])
        var azimuth = transectPoints[1].azimuthTo(transectPoints[2]) //_vertices[index].azimuthTo(_vertices[nextIndex])
        _splitHandle.coordinate = transectPoints[1].atDistanceAndAzimuth(distance / 2, azimuth)
    }

    Component {
        id: splitHandlesComponent
        Item {

            property var _vertices:     mapPolyline.pathModel

            opacity:    _root.opacity
            Component.onCompleted: {

                _splitHandle = centerDragHandle.createObject(mapControl)

                _splitArea = centerDragAreaComponent.createObject(mapControl, { "itemIndicator": _splitHandle, "itemCoordinate": _splitHandle.coordinate })
                //_splitHandle.vertexIndex = index
                _setHandlePosition()
                mapControl.addMapItem(_splitHandle)
            }

            Component.onDestruction: {
                if (_splitHandle) {
                    _splitHandle.destroy()
                }
                if(_splitArea) {
                    _splitArea.destroy()
                }
            }
        }

    }

    function updateCenterHandlePosition() {
        if (_splitHandle && transectPoints.length >= 2) {
            var start =  transectPoints[1]
            var end   =  transectPoints[2]
            var distance = start.distanceTo(end)
            var azimuth = start.azimuthTo(end)
            _splitHandle.coordinate = start.atDistanceAndAzimuth(distance/2, azimuth)
        }
    }

    // Move Center Icon
    onTransectPointsChanged: {        
        updateCenterHandlePosition()
    }


    // Control which is used to drag polygon vertices
    Component {
        id: dragAreaComponent

        MissionItemIndicatorDrag {
            mapControl: _root.mapControl
            id:         dragArea
            z:          _zorderDragHandle
            opacity:    _root.opacity

            property int polylineVertex

            property bool _creationComplete: false

            Component.onCompleted: _creationComplete = true

            onItemCoordinateChanged: {
                if (_creationComplete) {
                    // During component creation some bad coordinate values got through which screws up draw
                    mapPolyline.adjustVertex(polylineVertex, itemCoordinate)
                }
            }

            onClicked: {
                menu.popUpWithIndex(polylineVertex)
            }

        }
    }



    Component {
        id: centerDragHandle
        MapQuickItem {
            id:             mapQuickItem
            anchorPoint.x:  dragHandle.width  * 0.5
            anchorPoint.y:  dragHandle.height * 0.5
            z:              _zorderDragHandle

            property int polylineVertex

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

    Component {
        id: dragHandleComponent

        MapQuickItem {
            id:             mapQuickItem
            anchorPoint.x:  dragHandle.width / 2
            anchorPoint.y:  dragHandle.height / 2
            z:              _zorderDragHandle
            opacity:        _root.opacity

            property int polylineVertex

            sourceItem: Rectangle {
                id:             dragHandle
                width:          ScreenTools.defaultFontPixelHeight * 1.5
                height:         width
                radius:         width * 0.5
                color:          "red"//Qt.rgba(1,1,1,0.8)
                border.color:   Qt.rgba(0,0,0,0.25)
                border.width:   1
            }
        }
    }

    // Add all polygon vertex drag handles to the map
    Component {
        id: dragHandlesComponent

        Repeater {
            model: mapPolyline.pathModel

            delegate: Item {
                property var _visuals: [ ]

                opacity:    _root.opacity

                Component.onCompleted: {
                    var dragHandle = dragHandleComponent.createObject(mapControl)
                    dragHandle.coordinate = Qt.binding(function() { return object.coordinate })
                    dragHandle.polylineVertex = Qt.binding(function() { return index })
                    mapControl.addMapItem(dragHandle)
                    var dragArea = dragAreaComponent.createObject(mapControl, { "itemIndicator": dragHandle, "itemCoordinate": object.coordinate })
                    dragArea.polylineVertex = Qt.binding(function() { return index })
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
        id: centerDragAreaComponent

        MissionItemIndicatorDrag {
            itemIndicator: _splitHandle
            itemCoordinate: _splitHandle.coordinate
            mapControl:                 _root.mapControl
            z:                          _zorderCenterHandle
            property int polylineVertex

            property bool _creationComplete: false

            Component.onCompleted: _creationComplete = true

            onItemCoordinateChanged: {
                if (_creationComplete) {
                    var deltaLat = itemCoordinate.latitude - _splitHandle.coordinate.latitude
                    var deltaLon = itemCoordinate.longitude - _splitHandle.coordinate.longitude

                    // polyline 전체 이동
                    for (var i = 0; i < mapPolyline.count; i++) {
                        var c = mapPolyline.vertexCoordinate(i)
                        mapPolyline.adjustVertex(i, QtPositioning.coordinate(c.latitude + deltaLat, c.longitude + deltaLon))
                    }

                    // splitHandle 좌표 동기화
                    _splitHandle.coordinate = itemCoordinate
                }
            }
        }
    }    

    Component {
        id: centerDragHandleComponent

        Repeater {
            model: mapPolyline.path
            Item {
                property var dragHandle
                property var dragArea
                property var _vertices:     mapPolyline.path

                function _setHandlePosition() {
                    var nextIndex = index + 1
                    var distance = _vertices[index].distanceTo(_vertices[nextIndex])
                    var azimuth = _vertices[index].azimuthTo(_vertices[nextIndex])
                    dragHandle.coordinate = _vertices[index].atDistanceAndAzimuth(distance / 2, azimuth)
                }

                Component.onCompleted: {
                    if (index + 1 <= _vertices.length - 1) {
                        dragHandle = centerDragHandle.createObject(mapControl)
                        _setHandlePosition()
                        dragHandle.polylineVertex = Qt.binding(function() { return index })
                        mapControl.addMapItem(dragHandle)
                        dragArea = centerDragAreaComponent.createObject(mapControl, { "itemIndicator": dragHandle, "itemCoordinate": dragHandle.coordinate })
                        dragArea.polylineVertex = Qt.binding(function() { return index })
                    }
                }

                Component.onDestruction: {
                    dragHandle.destroy()
                    dragArea.destroy()
                }
            }
        }
    }

    Component {
        id: toolbarComponent

        PlanEditToolbar {
            anchors.horizontalCenter:       mapControl.left
            anchors.horizontalCenterOffset: mapControl.centerViewport.left + (mapControl.centerViewport.width / 2)
            y:                              mapControl.centerViewport.top
            z:                              QGroundControl.zOrderMapItems + 2
            availableWidth:                 mapControl.centerViewport.width

            QGCButton {
                _horizontalPadding: 0
                text:               qsTr("Basic")
                visible:            !mapPolyline.traceMode
                onClicked:          _resetPolyline()
            }

            QGCButton {
                _horizontalPadding: 0
                text:               mapPolyline.traceMode ? qsTr("Done Tracing") : qsTr("Trace")
                onClicked: {
                    if (mapPolyline.traceMode) {
                        if (mapPolyline.count < 2) {
                            _restorePreviousVertices()
                        }
                        mapPolyline.traceMode = false
                    } else {
                        _saveCurrentVertices()
                        mapPolyline.traceMode = true
                        mapPolyline.clear();
                    }
                }
            }

            QGCButton {
                _horizontalPadding: 0
                text:               qsTr("Load KML...")
                onClicked:          kmlLoadDialog.openForLoad()
                visible:            !mapPolyline.traceMode
            }
        }
    }

    // Mouse area to capture clicks for tracing a polyline
    Component {
        id:  traceMouseAreaComponent

        MouseArea {
            anchors.fill:       mapControl
            preventStealing:    true
            z:                  QGroundControl.zOrderMapItems + 1   // Over item indicators

            onClicked: {
                if (mouse.button === Qt.LeftButton && _root.interactive) {
                    mapPolyline.appendVertex(mapControl.toCoordinate(Qt.point(mouse.x, mouse.y), false /* clipToViewPort */))
                }
            }
        }
    }
}

