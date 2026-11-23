/****************************************************************************
 * AQGC Simple UI — S28 flight mode: only Position hold / Altitude hold (Simple).
 * Advanced mode (Figma S79 129:40949, 2026-11-17): every mode the drone offers, grouped by use, plain name + ArduPilot
 * name; modes without GPS hold (Stabilize, Acro, Sport, Drift) are orange and ask first; Return home / Land go to the
 * same slide-to-confirm sheets as in Simple.
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

SPanel {
    id: sheet
    property var vehicle: null
    signal rtlRequested()
    signal landRequested()
    readonly property bool _adv: QGroundControl.corePlugin.advancedMode
    title: _adv ? qsTr("Flight mode · all modes") : qsTr("Flight mode")
    width:  SimpleTheme.px(_adv ? 980 : 760)
    height: _adv ? Math.min(SimpleTheme.px(900), advFlick.contentHeight + SimpleTheme.px(130)) : SimpleTheme.px(470)
    property string confirmMode: ""

    // ArduPilot names first, PX4 names second
    readonly property var _choices: [
        { names: ["Loiter", "Position"],      title: qsTr("Position hold"), detail: qsTr("Holds position and height when you let go of the sticks") },
        { names: ["Altitude Hold", "AltHold", "Altitude"], title: qsTr("Altitude hold"), detail: qsTr("Holds height only — the drone drifts with the wind") }
    ]
    function _available(names) {
        if (!vehicle) return ""
        for (var i = 0; i < names.length; i++) if (vehicle.flightModes.indexOf(names[i]) !== -1) return names[i]
        return ""
    }

    // Advanced: groups of ArduCopter modes (names as the firmware plugin reports them)
    readonly property var _groups: [
        { t: qsTr("HOLDS POSITION (GPS)"), modes: [
            { n: "Loiter", t: qsTr("Position hold"), d: qsTr("Holds its place when you let go") },
            { n: "Position Hold", t: qsTr("Position hold (pilot)"), d: qsTr("Like position hold, with direct stick feel") },
            { n: "Brake", t: qsTr("Brake"), d: qsTr("Stops at once and holds") } ] },
        { t: qsTr("HEIGHT ONLY — DRIFTS WITH WIND"), modes: [
            { n: "Altitude Hold", t: qsTr("Altitude hold"), d: qsTr("Holds height, not position") },
            { n: "Stabilize", t: qsTr("Stabilize"), d: qsTr("No height or position hold"), warn: true } ] },
        { t: qsTr("EXPERT"), modes: [
            { n: "Acro", t: qsTr("Acro"), d: qsTr("Rate control, no self-levelling"), warn: true },
            { n: "Sport", t: qsTr("Sport"), d: qsTr("Rate control with height hold"), warn: true },
            { n: "Drift", t: qsTr("Drift"), d: qsTr("Car-like turns, no position hold"), warn: true } ] },
        { t: qsTr("AUTOMATIC"), modes: [
            { n: "Auto", t: qsTr("Mission"), d: qsTr("Flies the mission on the drone") },
            { n: "Guided", t: qsTr("Guided"), d: qsTr("Goes where the app sends it") },
            { n: "Follow", t: qsTr("Follow"), d: qsTr("Follows this device") },
            { n: "Circle", t: qsTr("Circle"), d: qsTr("Circles around a point") },
            { n: "ZigZag", t: qsTr("ZigZag"), d: qsTr("Flies back and forth between two points") } ] },
        { t: qsTr("RETURN AND LAND"), modes: [
            { n: "RTL", t: qsTr("Return home"), d: qsTr("Climbs, flies home, lands"), rtl: true },
            { n: "Smart RTL", t: qsTr("Smart return"), d: qsTr("Flies back the way it came") },
            { n: "AutoRTL", t: qsTr("Return after mission"), d: qsTr("Goes to the mission's landing") },
            { n: "Land", t: qsTr("Land"), d: qsTr("Lands where it is"), land: true } ] }
    ]
    // modes the drone offers that are not in a group (shown last)
    readonly property var _others: {
        if (!vehicle) return []
        var known = {}
        for (var g = 0; g < _groups.length; g++) for (var m = 0; m < _groups[g].modes.length; m++) known[_groups[g].modes[m].n] = true
        var out = []
        for (var i = 0; i < vehicle.flightModes.length; i++) if (!known[vehicle.flightModes[i]]) out.push({ n: vehicle.flightModes[i], t: vehicle.flightModes[i], d: "" })
        return out
    }
    function _pick(m) {
        if (m.rtl) { sheet.closeRequested(); sheet.rtlRequested(); return }
        if (m.land) { sheet.closeRequested(); sheet.landRequested(); return }
        if (m.warn && confirmMode !== m.n) { confirmMode = m.n; return }
        confirmMode = ""
        vehicle.flightMode = m.n
        sheet.closeRequested()
    }
    onVisibleChanged: confirmMode = ""

    // ------------------------------------------------ Simple: two modes
    Column {
        visible: !sheet._adv
        anchors.fill: parent
        spacing: SimpleTheme.px(12)
        Repeater {
            model: sheet._adv ? [] : sheet._choices
            Rectangle {
                readonly property string modeName: sheet._available(modelData.names)
                visible: modeName !== ""
                width: parent.width; height: SimpleTheme.px(110); radius: SimpleTheme.px(18)
                color: sheet.vehicle && sheet.vehicle.flightMode === modeName ? SimpleTheme.withAlpha(SimpleTheme.brandGreen, 0.35) : SimpleTheme.surfaceRaised
                border.width: sheet.vehicle && sheet.vehicle.flightMode === modeName ? SimpleTheme.px(2) : 0
                border.color: SimpleTheme.brandGreen
                Column {
                    anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(24); anchors.verticalCenter: parent.verticalCenter
                    SText { text: modelData.title; size: 30; bold: true }
                    SText { text: modelData.detail; size: 22; color: SimpleTheme.textSecondary }
                }
                MouseArea { anchors.fill: parent; onClicked: { sheet.vehicle.flightMode = parent.modeName; sheet.closeRequested() } }
            }
        }
        SText { text: qsTr("Other flight modes are available in Advanced mode."); size: 22; color: SimpleTheme.textTertiary }
    }

    // ------------------------------------------------ Advanced: all modes (S79)
    Flickable {
        id: advFlick
        visible: sheet._adv
        anchors.fill: parent
        clip: true
        contentHeight: advCol.height
        Column {
            id: advCol
            width: advFlick.width
            spacing: SimpleTheme.px(10)
            Repeater {
                model: sheet._adv ? sheet._groups.concat(sheet._others.length ? [{ t: qsTr("OTHER"), modes: sheet._others }] : []) : []
                Column {
                    readonly property var avail: modelData.modes.filter(function(m) { return sheet.vehicle && sheet.vehicle.flightModes.indexOf(m.n) !== -1 })
                    visible: avail.length > 0
                    width: advCol.width
                    spacing: SimpleTheme.px(8)
                    SText { text: modelData.t; size: 20; medium: true; color: SimpleTheme.textSecondary }
                    Flow {
                        width: parent.width
                        spacing: SimpleTheme.px(10)
                        Repeater {
                            model: parent.parent.avail
                            Rectangle {
                                readonly property bool cur: sheet.vehicle && sheet.vehicle.flightMode === modelData.n
                                readonly property bool asking: sheet.confirmMode === modelData.n
                                width: (advCol.width - SimpleTheme.px(20)) / 3; height: SimpleTheme.px(122); radius: SimpleTheme.px(16)
                                color: asking ? SimpleTheme.withAlpha(SimpleTheme.warn, 0.25) : cur ? SimpleTheme.withAlpha(SimpleTheme.brandGreen, 0.35) : SimpleTheme.surfaceRaised
                                border.width: cur || asking ? SimpleTheme.px(2) : 0; border.color: asking ? SimpleTheme.warn : SimpleTheme.brandGreen
                                Column {
                                    x: SimpleTheme.px(18); y: SimpleTheme.px(12); width: parent.width - SimpleTheme.px(36)
                                    Row {
                                        spacing: SimpleTheme.px(8)
                                        SIcon { visible: !!modelData.warn; name: "warn"; size: 26; color: SimpleTheme.warn; anchors.verticalCenter: parent.verticalCenter }
                                        SText { text: modelData.t; size: 26; bold: true }
                                    }
                                    SText { text: modelData.n; size: 18; color: SimpleTheme.textTertiary }
                                    SText { width: parent.width; size: 20; color: asking ? SimpleTheme.warn : SimpleTheme.textSecondary; elide: Text.ElideRight
                                            text: asking ? qsTr("No GPS hold. Tap again to change.") : modelData.d }
                                }
                                MouseArea { anchors.fill: parent; onClicked: sheet._pick(modelData) }
                            }
                        }
                    }
                }
            }
        }
    }
}
