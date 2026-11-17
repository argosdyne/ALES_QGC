/****************************************************************************
 * AQGC Simple UI — S80 Plan › Mission editor (Advanced mode, Figma 129:41964, 2026-11-17).
 * Same PlanView map as the Simple wizard; the right panel lists the items and edits the selected one.
 * Tabs: Mission (all items, command from the list the company firmware accepts — DO_SET_ROI only, not
 * ROI_LOCATION / ROI_NONE / ROI_WPNEXT_OFFSET, CLAUDE.md 2026-11-16), Fence (polygons and circles, edited on the map by
 * the classic fence visuals), Rally points (tap the map to add). Item parameters come from the classic item
 * (textFieldFacts / comboboxFacts), so they match the firmware's command definitions. Heights are above home.
 * Complex items (survey, corridor, structure, LiDAR) are made with the Simple wizards and shown here as one row.
 ****************************************************************************/
import QtQuick 2.12
import QtPositioning 5.12
import QGroundControl 1.0
import "."

Item {
    id: me
    property var  plan:     null
    property var  map:      null
    property real topInset: 0
    signal nextRequested()

    readonly property var _mission: plan ? plan.missionController : null
    readonly property var _fence:   plan ? plan.geoFenceController : null
    readonly property var _rally:   plan ? plan.rallyPointController : null
    property string tab: "mission"          // mission | fence | rally
    property bool   addMode: true
    property int    rev: 0

    onTabChanged: if (typeof planView !== "undefined" && planView.simpleSetEditingLayer) planView.simpleSetEditingLayer(tab)
    onVisibleChanged: if (visible && typeof planView !== "undefined" && planView.simpleSetEditingLayer) planView.simpleSetEditingLayer(tab)

    // commands the company firmware accepts (MAV_CMD numbers), plain names
    readonly property var commands: [
        { c: 16,   t: qsTr("Waypoint") },        { c: 22,  t: qsTr("Take off") },        { c: 21,  t: qsTr("Land") },
        { c: 20,   t: qsTr("Return home") },     { c: 19,  t: qsTr("Hover for a time") }, { c: 18,  t: qsTr("Circle (turns)") },
        { c: 17,   t: qsTr("Hover until next command") }, { c: 93, t: qsTr("Wait") },     { c: 178, t: qsTr("Change speed") },
        { c: 201,  t: qsTr("Point camera at (ROI)") }, { c: 177, t: qsTr("Jump to item") },  { c: 2000, t: qsTr("Take photo") },
        { c: 206,  t: qsTr("Photos every distance") }, { c: 2500, t: qsTr("Start video") }, { c: 2501, t: qsTr("Stop video") },
        { c: 205,  t: qsTr("Gimbal angle") },    { c: 211, t: qsTr("Gripper") },         { c: 183, t: qsTr("Set servo") }
    ]
    function cmdName(item) {
        if (!item) return ""
        if (!item.isSimpleItem) return item.commandName
        for (var i = 0; i < commands.length; i++) if (commands[i].c === item.command) return commands[i].t
        return item.commandName
    }
    // mission items (index 0 = the mission settings / home item, not listed)
    readonly property var items: {
        rev
        var out = []
        if (!_mission) return out
        var vi = _mission.visualItems, n = vi.count
        for (var i = 1; i < n; i++) out.push(vi.get(i))
        return out
    }
    readonly property var current: _mission ? _mission.currentPlanViewItem : null
    function indexOfItem(it) { var vi = _mission.visualItems; for (var i = 0; i < vi.count; i++) if (vi.get(i) === it) return i; return -1 }
    function select(it) { if (it) _mission.setCurrentPlanViewSeqNum(it.sequenceNumber, true) }
    Connections { target: me._mission; function onVisualItemsChanged() { me.rev++ } }

    // where a new item goes: after the selected item, never before the take-off, before a final Return home / Land
    function insertIndex() {
        var vi = _mission.visualItems, n = vi.count
        var takeoff = 0
        for (var i = 1; i < n; i++) { var t = vi.get(i); if (t && t.isSimpleItem && (t.command === 22 || t.command === 84)) { takeoff = i; break } }
        var cur = current ? indexOfItem(current) : -1
        var at = Math.max(cur + 1, takeoff + 1, 1)
        var last = vi.get(n - 1)
        if (last && last.isSimpleItem && (last.command === 20 || last.command === 21) && at >= n) at = n - 1
        return Math.min(at, n)
    }
    // map tap (forwarded by the wizard)
    function mapClicked(coord) {
        if (tab === "mission" && addMode && _mission) {
            _mission.insertSimpleMissionItem(coord, insertIndex(), true)
            rev++
        } else if (tab === "rally" && _rally) {
            _rally.addPoint(coord)
        }
    }
    function insertAfterCurrent() {
        var c = current && current.coordinate && current.coordinate.isValid ? current.coordinate : (typeof planView !== "undefined" ? planView.mapCenter() : QtPositioning.coordinate())
        _mission.insertSimpleMissionItem(c, insertIndex(), true)
        rev++
    }
    function deleteCurrent() {
        var i = indexOfItem(current)
        if (i > 0) { _mission.removeVisualItem(i); rev++ }
    }
    function mapRect() {
        if (!map) return null
        return { tl: map.toCoordinate(Qt.point(map.width * 0.35, map.height * 0.3), false), br: map.toCoordinate(Qt.point(map.width * 0.6, map.height * 0.6), false) }
    }

    // ---------------- left tools
    Column {
        x: SimpleTheme.px(24); y: me.topInset + SimpleTheme.px(24)
        spacing: SimpleTheme.px(12)
        visible: me.tab !== "fence"
        SActionButton {
            text: me.tab === "rally" ? qsTr("Tap map to add") : me.addMode ? qsTr("Adding points") : qsTr("Add point"); icon: "plus"
            fill: me.addMode || me.tab === "rally" ? SimpleTheme.brandGreen : SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
            onClicked: if (me.tab === "mission") me.addMode = !me.addMode
        }
    }

    // ---------------- right panel
    SPanel {
        id: panel
        closable: false
        anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(24)
        y: me.topInset + SimpleTheme.px(24)
        width: SimpleTheme.px(640)
        height: parent.height - y - SimpleTheme.px(24)

        Column {
            id: pcol
            x: SimpleTheme.px(20); y: SimpleTheme.px(20); width: parent.width - SimpleTheme.px(40)
            spacing: SimpleTheme.px(12)
            SSegmented {
                designWidth: 570
                model: [qsTr("Mission (%1)").arg(me.items.length), qsTr("Fence"), qsTr("Rally points")]
                currentIndex: me.tab === "fence" ? 1 : me.tab === "rally" ? 2 : 0
                onActivated: me.tab = index === 1 ? "fence" : index === 2 ? "rally" : "mission"
            }

            // ======== Mission
            Rectangle {
                visible: me.tab === "mission"
                width: pcol.width; height: Math.max(SimpleTheme.px(200), panel.height - SimpleTheme.px(290) - (editor.visible ? editor.height : 0))
                radius: SimpleTheme.px(16); color: SimpleTheme.surfaceRaised
                ListView {
                    id: list
                    anchors.fill: parent; anchors.margins: SimpleTheme.px(8)
                    clip: true
                    model: me.items
                    delegate: Rectangle {
                        width: ListView.view.width; height: SimpleTheme.px(54); radius: SimpleTheme.px(10)
                        color: modelData === me.current ? SimpleTheme.withAlpha(SimpleTheme.brandGreen, 0.3) : "transparent"
                        border.width: modelData === me.current ? SimpleTheme.px(2) : 0; border.color: SimpleTheme.brandGreen
                        SText { x: SimpleTheme.px(12); anchors.verticalCenter: parent.verticalCenter; width: SimpleTheme.px(40); text: index + 1; size: 22; color: SimpleTheme.textSecondary }
                        SText { x: SimpleTheme.px(56); anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.55; elide: Text.ElideRight
                                text: me.cmdName(modelData); size: 24 }
                        SText { anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(14); anchors.verticalCenter: parent.verticalCenter; size: 22; color: SimpleTheme.textSecondary
                                text: modelData.isSimpleItem && modelData.specifiesCoordinate && modelData.altitude ? Math.round(Number(modelData.altitude.rawValue)) + " m" : "" }
                        MouseArea { anchors.fill: parent; onClicked: me.select(modelData) }
                    }
                }
            }
            // editor of the selected item
            Rectangle {
                id: editor
                visible: me.tab === "mission" && !!me.current && me.indexOfItem(me.current) > 0
                width: pcol.width; height: visible ? Math.min(edCol.height + SimpleTheme.px(32), panel.height * 0.56) : 0
                radius: SimpleTheme.px(16); color: SimpleTheme.surfaceRaised
                readonly property var it: me.current
                Flickable {
                  anchors.fill: parent
                  clip: true
                  contentHeight: edCol.height + SimpleTheme.px(32)
                  Column {
                    id: edCol
                    x: SimpleTheme.px(20); y: SimpleTheme.px(16); width: editor.width - SimpleTheme.px(40)
                    spacing: SimpleTheme.px(10)
                    Item {
                        width: parent.width; height: SimpleTheme.px(64)
                        SText { anchors.verticalCenter: parent.verticalCenter; size: 26; bold: true
                                text: editor.it ? qsTr("Item %1 · %2").arg(me.indexOfItem(editor.it)).arg(me.cmdName(editor.it)) : "" }
                        Row {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            spacing: SimpleTheme.px(8)
                            SRoundIconButton { icon: "plus"; onClicked: me.insertAfterCurrent() }
                            SRoundIconButton { icon: "trash"; onClicked: me.deleteCurrent() }
                        }
                    }
                    // command
                    Item {
                        visible: !!editor.it && editor.it.isSimpleItem
                        width: parent.width; height: SimpleTheme.px(80)
                        SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Command"); size: 22; color: SimpleTheme.textSecondary }
                        SComboBox {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            designWidth: 380
                            model: me.commands.map(function(c) { return c.t })
                            currentIndex: { if (!editor.it) return -1; for (var i = 0; i < me.commands.length; i++) if (me.commands[i].c === editor.it.command) return i; return -1 }
                            displayText: editor.it ? me.cmdName(editor.it) : ""
                            onActivated: { editor.it.command = me.commands[index].c; me.rev++ }
                        }
                    }
                    // altitude (above home)
                    Item {
                        visible: !!editor.it && editor.it.isSimpleItem && (editor.it.specifiesCoordinate || editor.it.specifiesAltitudeOnly) && !!editor.it.altitude
                        width: parent.width; height: altF.height + SimpleTheme.px(8)
                        Column { anchors.verticalCenter: parent.verticalCenter
                                 SText { text: qsTr("Altitude"); size: 22; color: SimpleTheme.textSecondary }
                                 SText { text: qsTr("above home"); size: 18; color: SimpleTheme.textTertiary } }
                        SFactField { id: altF; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; designWidth: 380
                                     fact: editor.it && editor.it.isSimpleItem ? editor.it.altitude : null; step: 5; decimals: 0 }
                    }
                    // command parameters (from the item's command definition)
                    Repeater {
                        model: editor.it && editor.it.isSimpleItem ? editor.it.comboboxFacts : null
                        Item {
                            width: edCol.width; height: Math.max(SimpleTheme.px(80), cf.height + SimpleTheme.px(8))
                            SText { anchors.verticalCenter: parent.verticalCenter; width: parent.width - cf.width - SimpleTheme.px(10); text: object.name; size: 22; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap }
                            SFactField { id: cf; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; designWidth: 380; fact: object }
                        }
                    }
                    Repeater {
                        model: editor.it && editor.it.isSimpleItem ? editor.it.textFieldFacts : null
                        Item {
                            width: edCol.width; height: Math.max(SimpleTheme.px(80), tf.height + SimpleTheme.px(8))
                            SText { anchors.verticalCenter: parent.verticalCenter; width: parent.width - tf.width - SimpleTheme.px(10); text: object.name; size: 22; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap }
                            SFactField { id: tf; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; designWidth: 380; fact: object }
                        }
                    }
                    SText { visible: !!editor.it && !editor.it.isSimpleItem; width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                            text: qsTr("A pattern made with the mission wizards. Change its area or settings there; here it can be deleted.") }
                  }
                }
            }

            // ======== Fence
            Column {
                visible: me.tab === "fence"
                width: pcol.width
                spacing: SimpleTheme.px(10)
                SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                        text: qsTr("Inclusion: the drone stays inside. Exclusion: the drone stays out. Drag the corners on the map. My zones (Map & flight zones) are added when the mission is sent.") }
                Row {
                    spacing: SimpleTheme.px(10)
                    SButton { designHeight: 64; textSize: 22; icon: "plus"; text: qsTr("Polygon")
                              onClicked: { var r = me.mapRect(); if (r) me._fence.addInclusionPolygon(r.tl, r.br) } }
                    SButton { designHeight: 64; textSize: 22; icon: "plus"; text: qsTr("Circle")
                              onClicked: { var r = me.mapRect(); if (r) me._fence.addInclusionCircle(r.tl, r.br) } }
                }
                Repeater {
                    model: me._fence ? me._fence.polygons : null
                    Rectangle {
                        width: pcol.width; height: SimpleTheme.px(80); radius: SimpleTheme.px(14); color: SimpleTheme.surfaceRaised
                        SText { x: SimpleTheme.px(18); anchors.verticalCenter: parent.verticalCenter; size: 22; width: pcol.width - SimpleTheme.px(360); elide: Text.ElideRight
                                text: qsTr("Polygon %1 · %2 corners").arg(index + 1).arg(object.count) }
                        Row {
                            anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(12); anchors.verticalCenter: parent.verticalCenter
                            spacing: SimpleTheme.px(8)
                            SSegmented { designWidth: 250; model: [qsTr("Inclusion"), qsTr("Exclusion")]; currentIndex: object.inclusion ? 0 : 1
                                         onActivated: object.inclusion = index === 0 }
                            SRoundIconButton { icon: "trash"; onClicked: me._fence.deletePolygon(index) }
                        }
                    }
                }
                Repeater {
                    model: me._fence ? me._fence.circles : null
                    Rectangle {
                        width: pcol.width; height: SimpleTheme.px(80); radius: SimpleTheme.px(14); color: SimpleTheme.surfaceRaised
                        SText { x: SimpleTheme.px(18); anchors.verticalCenter: parent.verticalCenter; size: 22; width: pcol.width - SimpleTheme.px(360); elide: Text.ElideRight
                                text: qsTr("Circle %1 · %2 m").arg(index + 1).arg(Math.round(Number(object.radius.rawValue))) }
                        Row {
                            anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(12); anchors.verticalCenter: parent.verticalCenter
                            spacing: SimpleTheme.px(8)
                            SSegmented { designWidth: 250; model: [qsTr("Inclusion"), qsTr("Exclusion")]; currentIndex: object.inclusion ? 0 : 1
                                         onActivated: object.inclusion = index === 0 }
                            SRoundIconButton { icon: "trash"; onClicked: me._fence.deleteCircle(index) }
                        }
                    }
                }
                SText { visible: me._fence && me._fence.polygons.count === 0 && me._fence.circles.count === 0; size: 22; color: SimpleTheme.textTertiary
                        text: qsTr("No fence in this mission.") }
            }

            // ======== Rally points
            Column {
                visible: me.tab === "rally"
                width: pcol.width
                spacing: SimpleTheme.px(10)
                SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                        text: qsTr("Safe places to return to instead of home. Tap the map to add one; drag it on the map to move it.") }
                Repeater {
                    model: me._rally ? me._rally.points : null
                    Rectangle {
                        width: pcol.width; height: SimpleTheme.px(76); radius: SimpleTheme.px(14); color: SimpleTheme.surfaceRaised
                        SText { x: SimpleTheme.px(18); anchors.verticalCenter: parent.verticalCenter; size: 22
                                text: qsTr("Point %1 · %2, %3").arg(index + 1).arg(object.coordinate.latitude.toFixed(5)).arg(object.coordinate.longitude.toFixed(5)) }
                        SRoundIconButton { anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(12); anchors.verticalCenter: parent.verticalCenter
                                           icon: "trash"; onClicked: me._rally.removePoint(object) }
                    }
                }
                SText { visible: me._rally && me._rally.points.count === 0; size: 22; color: SimpleTheme.textTertiary; text: qsTr("No rally points.") }
            }
        }
        SButton {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: SimpleTheme.px(20)
            kind: "primary"; text: qsTr("Check & send"); objectName: "editorNext"
            onClicked: me.nextRequested()
        }
    }
}
