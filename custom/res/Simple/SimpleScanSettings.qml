/****************************************************************************
 * AQGC Simple UI — settings panel for corridor mapping (S40), structure scan (S41) and LiDAR survey (S42).
 * The shapes are edited on the classic PlanView map (corridor line / structure outline visuals: drag points,
 * tap a midpoint to add one). Taps on the map are handled by SimplePlanWizard (add a line point / outline point).
 *   corridor  : height (cameraCalc.distanceToSurface), width (corridorWidth), overlap (frontal / side)
 *   structure : shape preset (rectangle / circle / draw), distance from the structure (cameraCalc.distanceToSurface,
 *               caution under 10 m), bottom (scanBottomAlt) and top (structureHeight, ≤ max altitude), layers (as
 *               calculated, read-only), camera points (gimbalPitch 0 / -15)
 *   lidar     : height (line spacing from height, line overlap and the scanner FOV: ysEdited → wizard ysCalc), speed
 *               (mission settings item flight speed), line overlap 50 / 70 %, init path before and after (on / off)
 * More options stay in Advanced › Plan (classic editors).
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

SPanel {
    id: sp
    property string kind:    "corridor"     // corridor | structure | lidar
    property var    item:    null           // CorridorScanComplexItem / StructureScanComplexItem
    property var    mission: null
    property real   maxAlt:  120
    property string shape:   "rectangle"    // structure: rectangle | circle | draw | custom (none selected)
    signal nextRequested()
    signal shapeRequested(string shape)
    property bool   initPaths: false        // lidar: init path items are in the mission
    signal initPathsRequested(bool on)
    signal ysEdited()                       // lidar: height or overlap changed → recalculate the line spacing
    readonly property var _speed: mission && mission.visualItems.count > 0 && mission.visualItems.get(0).speedSection
                                  ? mission.visualItems.get(0).speedSection : null

    readonly property var _cam: item ? item.cameraCalc : null
    // the item can be of the other kind for a moment while kind / item change
    function _v(name) { return item && item[name] ? Number(item[name].rawValue) : 0 }
    closable: false

    function _fmtTime(sec) { if (!sec || isNaN(sec)) return "—"; var m = Math.round(sec / 60); return m < 1 ? qsTr("<1 min") : qsTr("%1 min").arg(m) }
    readonly property real lineLength: {
        if (kind !== "corridor" || !item || !item.corridorPolyline) return 0
        var p = item.corridorPolyline.path, d = 0
        for (var i = 1; i < p.length; i++) d += p[i - 1].distanceTo(p[i])
        return d
    }

    // the S* controls break their bindings when edited: rebuild them when the item changes
    Loader {
        id: body
        width: parent.width
        active: !!sp.item
        sourceComponent: sp.kind === "structure" ? structureComp : sp.kind === "lidar" ? lidarComp : corridorComp
    }
    Connections { target: sp; function onItemChanged() { body.active = false; body.active = !!sp.item } }

    Component {
        id: corridorComp
        Column {
            width: body.width
            spacing: SimpleTheme.px(14)
            Item {
                width: parent.width; height: SimpleTheme.px(80)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Flight height"); size: 24; color: SimpleTheme.textSecondary }
                SStepper { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    unit: "m"; step: 5; from: 10; to: sp.maxAlt
                    value: sp._cam ? Math.round(sp._cam.distanceToSurface.rawValue) : 80
                    onEdited: sp._cam.distanceToSurface.rawValue = value; objectName: "dist" }
            }
            SText {
                width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textTertiary
                text: sp._cam && !sp._cam.isManualCamera
                      ? qsTr("Photo detail ≈ %1 per pixel · limited to %2 m").arg(sp._cam.imageDensity.valueString + " " + sp._cam.imageDensity.units).arg(sp.maxAlt)
                      : qsTr("Limited to %1 m (maximum altitude)").arg(sp.maxAlt)
            }
            Item {
                width: parent.width; height: SimpleTheme.px(80)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Corridor width"); size: 24; color: SimpleTheme.textSecondary }
                SStepper { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    unit: "m"; step: 10; from: 10; to: 300
                    value: Math.round(sp._v("corridorWidth"))
                    onEdited: sp.item.corridorWidth.rawValue = value; objectName: "width" }
            }
            SText {
                width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textTertiary
                text: qsTr("Strip mapped on both sides of the line (%1 m each side)").arg(Math.round(sp._v("corridorWidth") / 2))
            }
            SText { visible: !!sp._cam && !sp._cam.isManualCamera; text: qsTr("Image overlap"); size: 24; color: SimpleTheme.textSecondary }
            SSegmented {
                visible: !!sp._cam && !sp._cam.isManualCamera
                designWidth: 544
                model: [qsTr("Standard · 2D map"), qsTr("High · 3D model")]
                currentIndex: sp._cam && sp._cam.frontalOverlap.rawValue >= 80 ? 1 : 0
                objectName: "overlap"
                onActivated: { sp._cam.frontalOverlap.rawValue = index === 1 ? 80 : 70; sp._cam.sideOverlap.rawValue = index === 1 ? 70 : 60 }
            }
        }
    }

    Component {
        id: lidarComp
        Column {
            width: body.width
            spacing: SimpleTheme.px(12)
            Item {
                width: parent.width; height: SimpleTheme.px(76)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Flight height"); size: 24; color: SimpleTheme.textSecondary }
                SStepper { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    unit: "m"; step: 5; from: 20; to: sp.maxAlt
                    value: sp._cam ? Math.round(sp._cam.distanceToSurface.rawValue) : 60
                    objectName: "dist"; onEdited: { sp._cam.distanceToSurface.rawValue = value; sp.ysEdited() } }
            }
            SText {
                width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textTertiary
                text: qsTr("Line spacing %1 m · limited to %2 m").arg(sp._cam ? Math.round(sp._cam.adjustedFootprintSide.rawValue) : "—").arg(sp.maxAlt)
            }
            Item {
                visible: !!sp._speed
                width: parent.width; height: SimpleTheme.px(76)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Speed"); size: 24; color: SimpleTheme.textSecondary }
                SStepper { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    unit: "m/s"; step: 1; from: 2; to: 15
                    value: sp._speed ? Math.round(sp._speed.flightSpeed.rawValue) : 8
                    objectName: "speed"; onEdited: { sp._speed.specifyFlightSpeed = true; sp._speed.flightSpeed.rawValue = value } }
            }
            SText { text: qsTr("Line overlap"); size: 24; color: SimpleTheme.textSecondary }
            SSegmented {
                designWidth: 544
                model: [qsTr("50 % · Standard"), qsTr("70 % · Dense")]
                currentIndex: sp._cam && sp._cam.yellowScanOverlapFact.rawValue >= 60 ? 1 : 0
                objectName: "ysOverlap"
                onActivated: { sp._cam.yellowScanOverlapFact.rawValue = index === 1 ? 70 : 50; sp.ysEdited() }
            }
            Item {
                width: parent.width; height: SimpleTheme.px(96)
                Column {
                    anchors.left: parent.left; anchors.right: ipToggle.left; anchors.verticalCenter: parent.verticalCenter
                    SText { text: qsTr("Init path before and after"); size: 24; color: SimpleTheme.textPrimary }
                    SText { width: parent.width; wrapMode: Text.WordWrap; text: qsTr("Figure 8 to settle the INS (required for good data)"); size: 21; color: SimpleTheme.textTertiary }
                }
                SToggle { id: ipToggle; objectName: "initPaths"; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                          checked: sp.initPaths
                          onToggled: { sp.initPathsRequested(ipToggle.checked); ipToggle.checked = Qt.binding(function() { return sp.initPaths }) } }
            }
            SText {
                visible: !sp.initPaths
                width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.warn
                text: qsTr("Without the init path the LiDAR data may be poor.")
            }
            SText {
                visible: !!sp.mission && sp.mission.batteriesRequired > 1
                width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.warn
                text: qsTr("Needs %1 batteries — plan a battery change.").arg(sp.mission ? sp.mission.batteriesRequired : 0)
            }
        }
    }

    Component {
        id: structureComp
        Column {
            width: body.width
            spacing: SimpleTheme.px(12)
            SText { text: qsTr("Structure outline"); size: 24; color: SimpleTheme.textSecondary }
            SSegmented {
                designWidth: 544
                model: [qsTr("Rectangle"), qsTr("Circle"), qsTr("Draw")]
                currentIndex: sp.shape === "circle" ? 1 : sp.shape === "draw" ? 2 : sp.shape === "rectangle" ? 0 : -1
                objectName: "shape"
                onActivated: sp.shapeRequested(index === 1 ? "circle" : index === 2 ? "draw" : "rectangle")
            }
            Item {
                width: parent.width; height: SimpleTheme.px(76)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Distance from structure"); size: 24; color: SimpleTheme.textSecondary }
                SStepper { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    unit: "m"; step: 1; from: 3; to: 100
                    value: sp._cam ? Math.round(sp._cam.distanceToSurface.rawValue) : 15
                    onEdited: sp._cam.distanceToSurface.rawValue = value; objectName: "dist" }
            }
            SText {
                visible: !!sp._cam && sp._cam.distanceToSurface.rawValue < 10
                width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.warn
                text: qsTr("Closer than 10 m: the drone may touch the structure in wind.")
            }
            Item {
                width: parent.width; height: SimpleTheme.px(76)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Bottom height"); size: 24; color: SimpleTheme.textSecondary }
                SStepper { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    unit: "m"; step: 1; from: 2; to: Math.max(2, Math.round(sp._v("structureHeight")) - 1)
                    value: Math.round(sp._v("scanBottomAlt"))
                    onEdited: sp.item.scanBottomAlt.rawValue = value; objectName: "bottom" }
            }
            Item {
                width: parent.width; height: SimpleTheme.px(76)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Top height"); size: 24; color: SimpleTheme.textSecondary }
                SStepper { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    unit: "m"; step: 1; from: Math.round(sp._v("scanBottomAlt")) + 1; to: sp.maxAlt
                    value: Math.round(sp._v("structureHeight"))
                    onEdited: sp.item.structureHeight.rawValue = value; objectName: "top" }
            }
            Item {
                width: parent.width; height: SimpleTheme.px(56)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Layers"); size: 24; color: SimpleTheme.textSecondary }
                SText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: (sp.item && sp.item.layers ? sp.item.layers.valueString : "—"); size: 30; bold: true }
            }
            SText { width: parent.width; wrapMode: Text.WordWrap; size: 21; color: SimpleTheme.textTertiary
                    text: qsTr("Calculated from the camera and overlap (one circle per layer)") }
            SText { text: qsTr("Camera points"); size: 24; color: SimpleTheme.textSecondary }
            SSegmented {
                designWidth: 544
                model: [qsTr("At structure"), qsTr("Slightly down · −15°")]
                currentIndex: sp._v("gimbalPitch") < -5 ? 1 : 0
                objectName: "camera"
                onActivated: sp.item.gimbalPitch.rawValue = index === 1 ? -15 : 0
            }
        }
    }

    // summary + next (bottom)
    Column {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        spacing: SimpleTheme.px(14)
        Rectangle { width: parent.width; height: 1; color: SimpleTheme.line }
        Row {
            width: parent.width
            Repeater {
                model: [
                    { l: qsTr("FLIGHT TIME"), v: sp._fmtTime(sp.mission ? sp.mission.missionTime : 0) },
                    sp.kind === "lidar" ? { l: qsTr("AREA"), v: sp.item && sp.item.coveredArea !== undefined ? (sp.item.coveredArea / 10000).toFixed(1) + " ha" : "—" }
                                        : { l: qsTr("PHOTOS"), v: sp.item && sp.item.cameraShots !== undefined ? String(sp.item.cameraShots) : "—" },
                    { l: qsTr("BATTERIES"),   v: sp.mission && sp.mission.batteriesRequired > 0 ? String(sp.mission.batteriesRequired) : "—" },
                    sp.kind === "lidar" ? { l: qsTr("SPACING"), v: sp._cam ? Math.round(sp._cam.adjustedFootprintSide.rawValue) + " m" : "—" }
                  : sp.kind === "structure" ? { l: qsTr("LAYERS"), v: sp.item ? (sp.item && sp.item.layers ? sp.item.layers.valueString : "—") : "—" }
                                            : { l: qsTr("LENGTH"), v: (sp.lineLength / 1000).toFixed(1) + " km" }
                ]
                Column {
                    width: parent.width / 4
                    SText { text: modelData.l; size: 20; medium: true; color: SimpleTheme.textTertiary }
                    SText { text: modelData.v; size: 30; bold: true }
                }
            }
        }
        SButton {
            width: parent.width
            kind: "primary"
            text: qsTr("Next: check & send")
            onClicked: sp.nextRequested()
        }
    }
}
