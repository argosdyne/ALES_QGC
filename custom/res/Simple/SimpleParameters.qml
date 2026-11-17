/****************************************************************************
 * AQGC Simple UI — S60 Parameters (Advanced mode, Figma 112:39099, 2026-11-17). Frame like Settings (S09).
 * Classic ParameterEditorController (FactPanelController: created only after the parameters are ready).
 * Left: All parameters · Changed from default · parameter groups with counts. Right: search, Save to file, More
 * (Refresh, Restart drone, Reset all to defaults, Load from file = classic page), orange warning, table (orange
 * dot = changed from default) and the edit panel (number with −/+, list, bitmask, text; Save, Reset to default).
 * Every change is sent to the drone at once (as in the classic editor).
 ****************************************************************************/
import QtQuick 2.12
import QtQuick.Controls 2.4
import QGroundControl 1.0
import QGroundControl.FactSystem 1.0
import QGroundControl.Controllers 1.0
import "."

Rectangle {
    id: pp
    color: SimpleTheme.bgBase
    MouseArea { anchors.fill: parent }

    readonly property var  _veh:   QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool _ready: !!_veh && _veh.parameterManager.parametersReady

    // Header
    Rectangle {
        id: header
        width: parent.width; height: SimpleTheme.px(104)
        color: SimpleTheme.surfaceGlass
        Row {
            anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
            spacing: SimpleTheme.px(20)
            SButton { designHeight: 80; icon: "back"; text: qsTr("Back"); textSize: 26; onClicked: simpleRoot.showFly() }
            SText { text: qsTr("Parameters"); size: 34; bold: true; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    SText {
        visible: !pp._ready
        anchors.centerIn: parent
        text: !pp._veh ? qsTr("Connect the drone to see its parameters.") : qsTr("Reading the parameters from the drone…")
        size: 30; color: SimpleTheme.textSecondary
    }

    Loader {
        anchors.top: header.bottom; anchors.bottom: parent.bottom
        width: parent.width
        active: pp._ready
        sourceComponent: editorComp
    }

    Component {
        id: editorComp
        Item {
            id: ed
            ParameterEditorController { id: ctl }

            // left list: "all" | "changed" | group index (groups of the same name in Standard / Advanced are merged)
            property string mode: "all"
            property var    groupFacts: []      // facts of the selected merged group
            property var    fact: null          // selected parameter
            property string editText: ""
            property string editError: ""
            property string note: ""            // result line (saved file, restart needed …)
            property bool   moreOpen: false
            property string confirm: ""         // "" | "resetall"
            property int    rev: 0              // recount after changes

            readonly property var plainNames: ({
                "AHRS": qsTr("Attitude estimate"), "ARMING": qsTr("Arming checks"), "ATC": qsTr("Attitude control"),
                "BATT": qsTr("Battery"), "BRD": qsTr("Board"), "COMPASS": qsTr("Compass"), "EK3": qsTr("Position estimate (EKF3)"),
                "FENCE": qsTr("Geofence"), "FLTMODE": qsTr("Flight modes"), "FS": qsTr("Failsafe"), "GPS": qsTr("GPS"),
                "INS": qsTr("Inertial sensors"), "LAND": qsTr("Landing"), "LOG": qsTr("Logging"), "MNT1": qsTr("Gimbal mount"),
                "MOT": qsTr("Motors"), "PILOT": qsTr("Pilot input"), "PSC": qsTr("Position control"), "RC": qsTr("Radio channels"),
                "RTL": qsTr("Return home"), "SERIAL": qsTr("Serial ports"), "SERVO": qsTr("Servo outputs"), "TERRAIN": qsTr("Terrain"),
                "WPNAV": qsTr("Waypoints") })
            // groups by name over all categories: { name, lists: [QmlObjectListModel], count }
            // (QmlObjectListModel.get() at the last index returned the parent object here: check the type)
            readonly property var groups: {
                var byName = {}, out = []
                for (var c = 0; c < ctl.categories.count; c++) {
                    var cat = ctl.categories.get(c)
                    for (var g = 0; g < cat.groups.count; g++) {
                        var grp = cat.groups.get(g)
                        if (!grp || !grp.facts) continue
                        if (!byName[grp.name]) { byName[grp.name] = { name: grp.name, lists: [], count: 0 }; out.push(byName[grp.name]) }
                        byName[grp.name].lists.push(grp.facts)
                        byName[grp.name].count += grp.facts.count
                    }
                }
                out.sort(function(a, b) { return a.name.localeCompare(b.name) })
                return out
            }
            readonly property int total: { var n = 0; for (var i = 0; i < groups.length; i++) n += groups[i].count; return n }
            // defaults come from the parameter documentation; the bundled ArduPilot file has none
            readonly property var defaultsInfo: {
                rev
                var n = 0, any = false
                for (var i = 0; i < groups.length; i++) {
                    for (var l = 0; l < groups[i].lists.length; l++) {
                        var f = groups[i].lists[l]
                        for (var j = 0; j < f.count; j++) {
                            var o = f.get(j)
                            if (o && o.defaultValueAvailable) { any = true; if (!o.valueEqualsDefault) n++ }
                        }
                    }
                }
                return { any: any, changed: n }
            }
            readonly property int changed: defaultsInfo.changed

            function show(m) {
                mode = String(m)
                search.reset()
                groupFacts = []
                if (mode === "all")          { ctl.showModifiedOnly = false; ctl.searchText = "." }
                else if (mode === "changed") { ctl.searchText = ""; ctl.showModifiedOnly = true }
                else {
                    var g = groups[Number(mode)], arr = []
                    for (var l = 0; l < g.lists.length; l++) for (var j = 0; j < g.lists[l].count; j++) { var o = g.lists[l].get(j); if (o && o.name !== undefined) arr.push(o) }
                    arr.sort(function(a, b) { return a.name.localeCompare(b.name) })
                    groupFacts = arr
                }
            }
            function select(f) {
                fact = f
                editError = ""
                editText = f ? (f.enumStrings.length > 0 || f.bitmaskStrings.length > 0 ? "" : f.valueString) : ""
                Qt.callLater(function() { valField.reset() })      // also when the text is the same as before typing
            }
            function stepOf(f) { return f.increment > 0 && isFinite(f.increment) ? f.increment : Math.pow(10, -Math.max(0, f.decimalPlaces)) }
            function apply(value) {
                if (!fact) return
                var err = fact.validate(String(value), false)
                if (err !== "") { editError = err; return }
                fact.value = value
                editError = ""
                note = fact.vehicleRebootRequired ? qsTr("%1 saved. Restart the drone to use the new value.").arg(fact.name) : qsTr("%1 saved on the drone.").arg(fact.name)
                rev++
            }
            Component.onCompleted: show(defaultsInfo.any && defaultsInfo.changed > 0 ? "changed" : "all")
            Connections { target: ctl; function onParametersChanged() { ed.rev++ } }

            // ---------------- categories
            Rectangle {
                id: cats
                anchors.top: parent.top; anchors.bottom: parent.bottom
                width: SimpleTheme.px(520)
                color: SimpleTheme.surfaceGlass
                ListView {
                    anchors.fill: parent; anchors.margins: SimpleTheme.px(20)
                    clip: true
                    spacing: SimpleTheme.px(4)
                    model: [{ key: "all", t: qsTr("All parameters"), n: ed.total }]
                           .concat(ed.defaultsInfo.any ? [{ key: "changed", t: qsTr("Changed from default"), n: ed.changed }] : [])
                           .concat(ed.groups.map(function(g, i) { return { key: String(i), t: ed.plainNames[g.name] ? g.name + " · " + ed.plainNames[g.name] : g.name, n: g.count } }))
                    delegate: Rectangle {
                        width: ListView.view.width; height: SimpleTheme.px(76); radius: SimpleTheme.px(16)
                        color: ed.mode === modelData.key && search.currentText === "" ? SimpleTheme.brandGreen : "transparent"
                        SText { anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                                anchors.right: cnt.left; anchors.rightMargin: SimpleTheme.px(10); elide: Text.ElideRight
                                text: modelData.t; size: 26; medium: modelData.key === "all" || modelData.key === "changed" }
                        SText { id: cnt; anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                                text: modelData.n; size: 22; color: SimpleTheme.textSecondary }
                        MouseArea { anchors.fill: parent; onClicked: ed.show(modelData.key) }
                    }
                }
            }

            // ---------------- content
            Item {
                anchors.left: cats.right; anchors.leftMargin: SimpleTheme.px(40)
                anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(24)
                anchors.top: parent.top; anchors.topMargin: SimpleTheme.px(24); anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(24)

                // toolbar
                Item {
                    id: toolbar
                    width: parent.width; height: SimpleTheme.px(80)
                    STextField {
                        id: search
                        objectName: "paramSearch"
                        anchors.left: parent.left; anchors.right: toolBtns.left; anchors.rightMargin: SimpleTheme.px(16)
                        designWidth: 600
                        placeholder: qsTr("Search name or description")
                        onCurrentTextChanged: {
                            if (currentText !== "") { ctl.showModifiedOnly = false; ctl.searchText = currentText }
                            else ed.show(ed.mode)
                        }
                    }
                    Row {
                        id: toolBtns
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        spacing: SimpleTheme.px(12)
                        SButton {
                            designHeight: 80; textSize: 26; icon: "download"; text: qsTr("Save to file")
                            onClicked: {
                                var f = QGroundControl.settingsManager.appSettings.parameterSavePath + "/" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss") + ".params"
                                ctl.saveToFile(f)
                                ed.note = qsTr("Saved: %1").arg(f)
                            }
                        }
                        SButton { designHeight: 80; textSize: 26; icon: "sliders"; text: qsTr("More"); objectName: "paramMore"; onClicked: ed.moreOpen = !ed.moreOpen }
                    }
                }
                // More menu
                SPanel {
                    visible: ed.moreOpen
                    closable: false
                    z: 10
                    anchors.right: parent.right; anchors.top: toolbar.bottom; anchors.topMargin: SimpleTheme.px(8)
                    width: SimpleTheme.px(460); height: moreCol.height + SimpleTheme.px(32)
                    Column {
                        id: moreCol
                        x: SimpleTheme.px(16); y: SimpleTheme.px(16); width: parent.width - SimpleTheme.px(32)
                        spacing: SimpleTheme.px(8)
                        SButton { width: parent.width; designHeight: 76; textSize: 24; text: qsTr("Read again from the drone")
                                  onClicked: { ed.moreOpen = false; ctl.refresh() } }
                        SButton { width: parent.width; designHeight: 76; textSize: 24; text: qsTr("Restart the drone")
                                  enabled_: !!pp._veh && !pp._veh.armed; onClicked: { ed.moreOpen = false; pp._veh.rebootVehicle(); ed.note = qsTr("Restart sent to the drone.") } }
                        SButton { width: parent.width; designHeight: 76; textSize: 24; kind: "danger"; text: qsTr("Reset all to defaults…")
                                  enabled_: !!pp._veh && !pp._veh.armed; onClicked: { ed.moreOpen = false; ed.confirm = "resetall" } }
                        SButton { width: parent.width; designHeight: 76; textSize: 24; text: qsTr("Load from file (classic)")
                                  onClicked: { ed.moreOpen = false; simpleRoot.openClassic("parameters") } }
                    }
                }
                // warning / confirmation
                Rectangle {
                    id: warn
                    anchors.top: toolbar.bottom; anchors.topMargin: SimpleTheme.px(14)
                    width: parent.width; height: warnRow.height + SimpleTheme.px(24); radius: SimpleTheme.px(14)
                    color: SimpleTheme.withAlpha(ed.confirm !== "" ? SimpleTheme.danger : SimpleTheme.warn, 0.18)
                    border.width: SimpleTheme.px(2); border.color: ed.confirm !== "" ? SimpleTheme.danger : SimpleTheme.warn
                    Row {
                        id: warnRow
                        anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(18); anchors.verticalCenter: parent.verticalCenter
                        spacing: SimpleTheme.px(14)
                        SIcon { name: "warn"; size: 32; anchors.verticalCenter: parent.verticalCenter }
                        SText { anchors.verticalCenter: parent.verticalCenter; size: 24
                                width: ed.confirm !== "" ? warn.width - SimpleTheme.px(560) : warn.width - SimpleTheme.px(80); wrapMode: Text.WordWrap
                                text: ed.confirm !== "" ? qsTr("Reset every parameter to its default? Calibrations and setup are lost; the drone needs a restart.")
                                    : pp._veh && pp._veh.armed ? qsTr("Motors are running: a wrong value can make the drone unsafe now. Changes are sent at once.")
                                    : qsTr("A wrong value can make the drone unsafe. Changes are sent to the drone at once.") }
                        SButton { visible: ed.confirm !== ""; designHeight: 64; textSize: 22; kind: "danger"; text: qsTr("Reset all")
                                  onClicked: { ed.confirm = ""; ctl.resetAllToDefaults(); ed.note = qsTr("All parameters reset. Restart the drone.") } }
                        SButton { visible: ed.confirm !== ""; designHeight: 64; textSize: 22; text: qsTr("Cancel"); onClicked: ed.confirm = "" }
                    }
                }
                SText {
                    id: noteText
                    visible: ed.note !== ""
                    anchors.top: warn.bottom; anchors.topMargin: SimpleTheme.px(8)
                    width: parent.width; elide: Text.ElideMiddle; size: 22; color: SimpleTheme.ok; text: ed.note
                }

                // table
                Rectangle {
                    id: table
                    anchors.top: noteText.visible ? noteText.bottom : warn.bottom; anchors.topMargin: SimpleTheme.px(14)
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left; anchors.right: panel.left; anchors.rightMargin: SimpleTheme.px(16)
                    radius: SimpleTheme.px(18); color: SimpleTheme.surfaceRaised
                    readonly property real cName: width * 0.38
                    readonly property real cVal:  width * 0.22
                    Row {
                        id: th
                        x: SimpleTheme.px(24); y: SimpleTheme.px(14); height: SimpleTheme.px(44)
                        SText { width: table.cName; text: qsTr("Name"); size: 22; color: SimpleTheme.textSecondary }
                        SText { width: table.cVal;  text: qsTr("Value"); size: 22; color: SimpleTheme.textSecondary }
                        SText { text: qsTr("Description"); size: 22; color: SimpleTheme.textSecondary }
                    }
                    ListView {
                        id: list
                        anchors.top: th.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                        anchors.bottomMargin: SimpleTheme.px(8)
                        clip: true
                        // a merged group shows its own list; all / changed / search use the controller's list
                        model: ed.groupFacts.length > 0 && search.currentText === "" ? ed.groupFacts : ctl.parameters
                        delegate: Rectangle {
                            width: ListView.view.width; height: SimpleTheme.px(76)
                            readonly property var object: typeof modelData !== "undefined" && modelData && modelData.name !== undefined ? modelData : model.object
                            color: ed.fact === object ? SimpleTheme.surfaceControl : "transparent"
                            readonly property bool _changed: object.defaultValueAvailable && !object.valueEqualsDefault
                            Rectangle { visible: parent._changed; x: SimpleTheme.px(10); anchors.verticalCenter: parent.verticalCenter
                                        width: SimpleTheme.px(10); height: width; radius: width / 2; color: SimpleTheme.warn }
                            Row {
                                x: SimpleTheme.px(24); anchors.verticalCenter: parent.verticalCenter
                                SText { width: table.cName; text: object.name; size: 24; medium: true; elide: Text.ElideRight }
                                SText { width: table.cVal - SimpleTheme.px(14); size: 24; bold: true; elide: Text.ElideRight
                                        text: object.enumOrValueString + (object.units !== "" && object.enumStrings.length === 0 ? " " + object.units : "") }
                                Item { width: SimpleTheme.px(14); height: 1 }
                                SText { width: table.width - table.cName - table.cVal - SimpleTheme.px(40); size: 22; color: SimpleTheme.textSecondary
                                        text: object.shortDescription; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                            }
                            MouseArea { anchors.fill: parent; onClicked: ed.select(object) }
                        }
                        SText { visible: list.count === 0; anchors.centerIn: parent; size: 24; color: SimpleTheme.textSecondary
                                text: ed.mode === "changed" && search.currentText === "" ? qsTr("No parameter differs from its default.") : qsTr("No parameters found.") }
                    }
                }

                // edit panel
                Rectangle {
                    id: panel
                    anchors.top: table.top; anchors.right: parent.right
                    width: SimpleTheme.px(460)
                    height: Math.min(parent.height - y, pCol.height + SimpleTheme.px(48))
                    radius: SimpleTheme.px(18); color: SimpleTheme.surfaceRaised
                    Flickable {
                        anchors.fill: parent; anchors.margins: SimpleTheme.px(24)
                        clip: true; contentHeight: pCol.height
                        Column {
                            id: pCol
                            width: parent.width
                            spacing: SimpleTheme.px(14)
                            SText { visible: !ed.fact; width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                                    text: qsTr("Choose a parameter to see and change it.") }
                            SText { visible: !!ed.fact; width: parent.width; text: ed.fact ? ed.fact.name : ""; size: 30; bold: true; elide: Text.ElideRight }
                            SText { visible: !!ed.fact; width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                                    text: ed.fact ? (ed.fact.longDescription !== "" ? ed.fact.longDescription : ed.fact.shortDescription) : "" }

                            // number / text
                            Row {
                                visible: !!ed.fact && ed.fact.enumStrings.length === 0 && ed.fact.bitmaskStrings.length === 0
                                spacing: SimpleTheme.px(10)
                                readonly property bool _num: !!ed.fact && !ed.fact.typeIsString
                                SRoundIconButton { visible: parent._num; icon: "minus"; anchors.verticalCenter: parent.verticalCenter
                                                   onClicked: ed.editText = String(Number((Number(valField.currentText) - ed.stepOf(ed.fact)).toFixed(Math.max(0, ed.fact.decimalPlaces)))) }
                                STextField {
                                    id: valField
                                    objectName: "paramValue"
                                    designWidth: parent._num ? 220 : 380
                                    decimal: parent._num
                                    text: ed.editText
                                    error: ed.editError !== ""
                                }
                                SRoundIconButton { visible: parent._num; icon: "plus"; anchors.verticalCenter: parent.verticalCenter
                                                   onClicked: ed.editText = String(Number((Number(valField.currentText) + ed.stepOf(ed.fact)).toFixed(Math.max(0, ed.fact.decimalPlaces)))) }
                                SText { visible: !!ed.fact && ed.fact.units !== ""; anchors.verticalCenter: parent.verticalCenter; text: ed.fact ? ed.fact.units : ""; size: 22; color: SimpleTheme.textSecondary }
                            }
                            // list of choices
                            Column {
                                visible: !!ed.fact && ed.fact.enumStrings.length > 0 && ed.fact.bitmaskStrings.length === 0
                                width: parent.width
                                spacing: SimpleTheme.px(6)
                                Repeater {
                                    model: ed.fact && ed.fact.bitmaskStrings.length === 0 ? ed.fact.enumStrings : []
                                    SButton { width: pCol.width; designHeight: 64; textSize: 22
                                              kind: ed.fact && ed.fact.enumIndex === index ? "primary" : "secondary"
                                              text: modelData; onClicked: ed.apply(ed.fact.enumValues[index]) }
                                }
                            }
                            // bitmask
                            Column {
                                visible: !!ed.fact && ed.fact.bitmaskStrings.length > 0
                                width: parent.width
                                spacing: SimpleTheme.px(6)
                                Repeater {
                                    model: ed.fact ? ed.fact.bitmaskStrings : []
                                    Item {
                                        width: pCol.width; height: SimpleTheme.px(56)
                                        readonly property int bit: ed.fact ? Number(ed.fact.bitmaskValues[index]) : 0
                                        readonly property bool on: ed.fact ? (Number(ed.fact.value) & bit) !== 0 : false
                                        Rectangle { id: bbox; width: SimpleTheme.px(36); height: width; radius: SimpleTheme.px(8); anchors.verticalCenter: parent.verticalCenter
                                                    color: parent.on ? SimpleTheme.brandGreen : "transparent"; border.width: SimpleTheme.px(3)
                                                    border.color: parent.on ? SimpleTheme.brandGreen : SimpleTheme.textSecondary
                                                    SIcon { anchors.centerIn: parent; name: "check"; size: 26; visible: parent.parent.on } }
                                        SText { anchors.left: bbox.right; anchors.leftMargin: SimpleTheme.px(14); anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter; text: modelData; size: 22; elide: Text.ElideRight }
                                        MouseArea { anchors.fill: parent; onClicked: ed.apply(Number(ed.fact.value) ^ parent.bit) }
                                    }
                                }
                            }
                            SText { visible: ed.editError !== ""; width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textDanger; text: ed.editError }
                            SText {
                                visible: !!ed.fact
                                width: parent.width; wrapMode: Text.WordWrap; size: 20; color: SimpleTheme.textSecondary
                                text: !ed.fact ? "" : [
                                    (!ed.fact.minIsDefaultForType || !ed.fact.maxIsDefaultForType) ? qsTr("Range %1 – %2 %3").arg(ed.fact.minString).arg(ed.fact.maxString).arg(ed.fact.units) : "",
                                    ed.fact.defaultValueAvailable ? qsTr("default %1").arg(ed.fact.defaultValueString) : "",
                                    ed.fact.enumStrings.length === 0 && ed.fact.bitmaskStrings.length === 0 && !ed.fact.typeIsString ? qsTr("step %1").arg(ed.stepOf(ed.fact)) : "",
                                    ed.fact.vehicleRebootRequired ? qsTr("needs a drone restart") : ""
                                ].filter(function(s) { return s !== "" }).join(" · ")
                            }
                            SButton {
                                visible: !!ed.fact && ed.fact.enumStrings.length === 0 && ed.fact.bitmaskStrings.length === 0
                                width: parent.width; kind: "primary"; text: qsTr("Save"); objectName: "paramSave"
                                enabled_: !!ed.fact && valField.currentText !== "" && valField.currentText !== ed.fact.valueString
                                onClicked: ed.apply(valField.currentText)
                            }
                            SButton {
                                visible: !!ed.fact && ed.fact.defaultValueAvailable
                                width: parent.width; text: qsTr("Reset to default")
                                enabled_: !!ed.fact && !ed.fact.valueEqualsDefault
                                onClicked: { ed.apply(ed.fact.defaultValue); ed.select(ed.fact) }
                            }
                        }
                    }
                }
            }
        }
    }
}
