/****************************************************************************
 *
 * Lightweight polygon visuals to reduce RAM usage.
 * - Only renders a MapPolygon with border + fill.
 * - No drag handles, split handles, edge labels, trace/toolbar, or menus.
 *
 * Usage:
 *   import "qrc:/src/MissionManager"
 *   LightMapPolygonVisuals {
 *       mapControl: map
 *       mapPolygon: object   // QGCMapPolygon
 *       interiorColor: "red"
 *       borderColor: "red"
 *       interiorOpacity: object.strokeOpacity
 *   }
 *
 ****************************************************************************/
import QtQuick          2.11
import QtLocation       5.3
import QtPositioning    5.3

Item {
    id: _root

    property var    mapControl          ///< Map control to place item in
    property var    mapPolygon          ///< QGCMapPolygon object
    property real   borderWidth: 0
    property color  borderColor: "red"
    property color  interiorColor: "red"
    property real   interiorOpacity: 0.35

    // Single MapPolygon for the given path; no extra visuals to keep memory low
    MapPolygon {
        id: poly
        color:          interiorColor
        opacity:        interiorOpacity
        border.color:   borderColor
        border.width:   borderWidth
        path:           mapPolygon ? mapPolygon.path : []
        visible:        mapPolygon && path.length >= 3
        z:              _root.z

        Component.onCompleted: {
            if (mapControl && mapControl.addMapItem) {
                mapControl.addMapItem(poly)
            }
        }
        Component.onDestruction: {
            if (mapControl && mapControl.removeMapItem) {
                mapControl.removeMapItem(poly)
            }
        }
    }
}
