/****************************************************************************
 * AQGC Simple UI — Plan in 3 steps (Figma S07 choose task · S08 area mapping · S39 check & send)
 * Uses the classic PlanView map and PlanMasterController underneath (its panels are hidden in Simple mode).
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

Item {
    id: wiz
    property var    vs
    property string step:   "choose"        // choose | edit | check
    property var    survey: null

    readonly property var _plan:    planView._planMasterController
    readonly property var _mission: _plan ? _plan.missionController : null
    readonly property var _cam:     survey ? survey.cameraCalc : null
    readonly property real _maxAlt: Number(QGroundControl.settingsManager.flyViewSettings.guidedMaximumAltitude.rawValue)

    function start() {
        step = "choose"
        survey = null
    }

    function _findSurvey() {
        if (!_mission) return null
        var items = _mission.visualItems
        for (var i = 0; i < items.count; i++) {
            var it = items.get(i)
            if (it.surveyAreaPolygon !== undefined && it.cameraCalc !== undefined) return it
        }
        return null
    }

    function createAreaMapping() {
        _plan.removeAll()
        var c = planView.mapCenter()
        _mission.insertTakeoffItem(c, 1, false)
        var item = _mission.insertComplexMissionItem(_mission.surveyComplexItemName, c, 2, true)
        _mission.insertLandItem(c, 3, false)
        if (item && item.surveyAreaPolygon.count === 0) {
            // Default 200 m x 150 m (stays inside a 300 m geofence) area around the map centre
            var p = []
            p.push(c.atDistanceAndAzimuth(100, -90).atDistanceAndAzimuth(75, 0))
            p.push(c.atDistanceAndAzimuth(100,  90).atDistanceAndAzimuth(75, 0))
            p.push(c.atDistanceAndAzimuth(100,  90).atDistanceAndAzimuth(75, 180))
            p.push(c.atDistanceAndAzimuth(100, -90).atDistanceAndAzimuth(75, 180))
            item.surveyAreaPolygon.appendVertices(p)
        }
        if (item && item.cameraCalc) item.cameraCalc.distanceToSurface.rawValue = Math.min(80, _maxAlt)
        survey = item ? item : _findSurvey()
        step = "edit"
    }

    function _fmtTime(sec) {
        if (!sec || isNaN(sec)) return "—"
        var m = Math.round(sec / 60)
        return m < 1 ? "<1 min" : m + " min"
    }

    //------------------------------------------------------------------ Header with steps
    Rectangle {
        id: header
        width: parent.width; height: SimpleTheme.px(104)
        color: SimpleTheme.surfaceGlass
        MouseArea { anchors.fill: parent }
        Row {
            anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
            spacing: SimpleTheme.px(20)
            SButton {
                designHeight: 80; icon: "back"; textSize: 26
                text: wiz.step === "check" ? qsTr("Settings") : qsTr("Fly")
                onClicked: wiz.step === "check" ? wiz.step = "edit" : simpleRoot.showFly()
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                SText { text: wiz.step === "choose" ? qsTr("Plan a mission") : qsTr("Area mapping"); size: 34; bold: true }
                SText { text: wiz.step === "choose" ? qsTr("What do you want to do?") : qsTr("New mission"); size: 22; color: SimpleTheme.textSecondary }
            }
        }
        Row {
            visible: wiz.step !== "choose"
            anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
            spacing: SimpleTheme.px(10)
            Repeater {
                model: [qsTr("Draw area"), qsTr("Settings"), qsTr("Check & send")]
                Rectangle {
                    id: stepItem
                    readonly property int cur: wiz.step === "check" ? 2 : 1
                    height: SimpleTheme.px(60); radius: height / 2
                    width: stepRow.implicitWidth + SimpleTheme.px(28)
                    color: index === cur ? SimpleTheme.brandGreen : SimpleTheme.surfaceControl
                    Row {
                        id: stepRow
                        anchors.centerIn: parent
                        spacing: SimpleTheme.px(10)
                        Rectangle {
                            width: SimpleTheme.px(40); height: width; radius: width / 2
                            color: index < stepItem.cur ? SimpleTheme.ok : index === stepItem.cur ? SimpleTheme.textPrimary : SimpleTheme.surfaceRaised
                            SIcon { visible: index < stepItem.cur; anchors.centerIn: parent; name: "check"; size: 28; color: SimpleTheme.bgBase }
                            SText { visible: index >= stepItem.cur; anchors.centerIn: parent; text: index + 1; size: 24; bold: true; color: index === stepItem.cur ? SimpleTheme.brandGreenDark : SimpleTheme.textSecondary }
                        }
                        SText { text: modelData; size: 24; medium: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }

    //------------------------------------------------------------------ S07 choose a task
    Rectangle {
        visible: wiz.step === "choose"
        anchors.top: header.bottom; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        color: SimpleTheme.bgBase
        MouseArea { anchors.fill: parent }
        Grid {
            anchors.centerIn: parent
            columns: 3
            spacing: SimpleTheme.px(28)
            Repeater {
                model: [
                    { key: "area",      icon: "grid",      title: qsTr("Area mapping"),      sub: qsTr("Photos of a field or site for a 2D map or 3D model"), ok: true },
                    { key: "waypoint",  icon: "pin",       title: qsTr("Waypoint flight"),   sub: qsTr("Fly through points you tap on the map"),            ok: false },
                    { key: "corridor",  icon: "corridor",  title: qsTr("Corridor mapping"),  sub: qsTr("Road, canal or power line"),                         ok: false },
                    { key: "structure", icon: "structure", title: qsTr("Structure scan"),    sub: qsTr("Circles around a tower or building"),               ok: false },
                    { key: "lidar",     icon: "lidar",     title: qsTr("LiDAR survey"),      sub: qsTr("YellowScan with init path"),                        ok: false },
                    { key: "open",      icon: "folder",    title: qsTr("Open saved mission"), sub: qsTr("From this tablet or a KML file"),                  ok: false }
                ]
                Rectangle {
                    width: SimpleTheme.px(500); height: SimpleTheme.px(260); radius: SimpleTheme.px(24)
                    color: SimpleTheme.surfaceRaised
                    border.width: modelData.ok ? SimpleTheme.px(2) : 0; border.color: SimpleTheme.brandGreen
                    opacity: modelData.ok ? 1 : 0.45
                    Column {
                        anchors.fill: parent; anchors.margins: SimpleTheme.px(28)
                        spacing: SimpleTheme.px(12)
                        SIcon { name: modelData.icon; size: 64; color: modelData.ok ? SimpleTheme.ok : SimpleTheme.textSecondary }
                        SText { text: modelData.title; size: 32; bold: true }
                        SText { width: parent.width; text: modelData.ok ? modelData.sub : qsTr("Next version"); size: 22; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap }
                    }
                    MouseArea { anchors.fill: parent; enabled: modelData.ok; onClicked: wiz.createAreaMapping() }
                }
            }
        }
    }

    //------------------------------------------------------------------ S08 settings panel (map editing happens on the PlanView map below)
    SPanel {
        id: settingsPanel
        visible: wiz.step === "edit" && !!wiz.survey
        closable: false
        x: parent.width - width - SimpleTheme.px(24)
        y: header.height + SimpleTheme.px(24)
        width: SimpleTheme.px(620)
        height: parent.height - y - SimpleTheme.px(24)

        Column {
            anchors.fill: parent
            spacing: SimpleTheme.px(14)
            Item {
                width: parent.width; height: SimpleTheme.px(60)
                SText { text: qsTr("Flight height"); size: 26; medium: true; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            }
            SStepper {
                unit: "m"; step: 5; from: 10; to: wiz._maxAlt
                value: wiz._cam ? Math.round(wiz._cam.distanceToSurface.rawValue) : 80
                onEdited: if (wiz._cam) wiz._cam.distanceToSurface.rawValue = value
            }
            SText {
                width: parent.width
                text: wiz._cam && !wiz._cam.isManualCamera
                      ? qsTr("Photo detail ≈ %1 per pixel · limited to %2 m").arg(wiz._cam.imageDensity.valueString + " " + wiz._cam.imageDensity.units).arg(wiz._maxAlt)
                      : qsTr("Limited to %1 m (maximum altitude)").arg(wiz._maxAlt)
                size: 22; color: SimpleTheme.textTertiary; wrapMode: Text.WordWrap
            }
            SText { visible: wiz._cam && !wiz._cam.isManualCamera; text: qsTr("Image overlap"); size: 26; medium: true; color: SimpleTheme.textSecondary }
            SSegmented {
                visible: wiz._cam && !wiz._cam.isManualCamera
                designWidth: 556
                model: [qsTr("Standard · 2D map"), qsTr("High · 3D model")]
                currentIndex: wiz._cam && wiz._cam.frontalOverlap.rawValue >= 80 ? 1 : 0
                onActivated: {
                    wiz._cam.frontalOverlap.rawValue = index === 1 ? 80 : 70
                    wiz._cam.sideOverlap.rawValue    = index === 1 ? 70 : 60
                }
            }
            Rectangle { width: parent.width; height: 1; color: SimpleTheme.line }
            Grid {
                width: parent.width
                columns: 2
                rowSpacing: SimpleTheme.px(20)
                Repeater {
                    model: [
                        { l: qsTr("FLIGHT TIME"), v: wiz._fmtTime(wiz._mission ? wiz._mission.missionTime : 0) },
                        { l: qsTr("PHOTOS"),      v: wiz.survey ? String(wiz.survey.cameraShots) : "—" },
                        { l: qsTr("BATTERIES"),   v: wiz._mission && wiz._mission.batteriesRequired > 0 ? String(wiz._mission.batteriesRequired) : "—" },
                        { l: qsTr("AREA"),        v: wiz.survey ? (wiz.survey.coveredArea / 10000).toFixed(1) + " ha" : "—" }
                    ]
                    Column {
                        width: parent.width / 2
                        SText { text: modelData.l; size: 22; medium: true; color: SimpleTheme.textTertiary }
                        SText { text: modelData.v; size: 32; bold: true }
                    }
                }
            }
        }
        SButton {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: SimpleTheme.px(28)
            kind: "primary"
            text: qsTr("Next: check & send")
            onClicked: wiz.step = "check"
        }
    }

    Rectangle {
        visible: wiz.step === "edit"
        x: SimpleTheme.px(24); anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(24)
        width: hintRow.implicitWidth + SimpleTheme.px(40); height: SimpleTheme.px(64); radius: SimpleTheme.px(16)
        color: SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
        Row {
            id: hintRow
            anchors.centerIn: parent
            spacing: SimpleTheme.px(12)
            SIcon { name: "info"; size: 32; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            SText { text: qsTr("Drag the corners to fit the area. Tap an edge midpoint to add a corner."); size: 24; color: SimpleTheme.textSecondary }
        }
    }

    //------------------------------------------------------------------ S39 check & send
    SimplePlanCheck {
        visible: wiz.step === "check"
        x: parent.width - width - SimpleTheme.px(24)
        y: header.height + SimpleTheme.px(24)
        width: SimpleTheme.px(620)
        height: parent.height - y - SimpleTheme.px(24)
        vs: wiz.vs
        plan: wiz._plan
        survey: wiz.survey
        maxAlt: wiz._maxAlt
    }
}
