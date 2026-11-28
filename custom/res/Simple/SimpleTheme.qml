/****************************************************************************
 * AQGC Simple UI — design tokens (Figma "AQGC-simpler", collection "AQGC Simple")
 * Layout values are in design pixels of a 1920x1080 screen; use px() / fs().
 ****************************************************************************/
pragma Singleton
import QtQuick 2.12
import QGroundControl 1.0

QtObject {
    // Set by SimpleRoot from the window size (1920x1080 = 1.0)
    property real scale:        1.0
    // Settings > General > Text size (Large = 1.2)
    property real textScale:    1.0

    // Restart toast (SimpleRoot.showRestartNotice, Figma S60 / S101 notes 2026-11-19) is not shown when the screen
    // shows its own restart notice: ownRestartHints = pages open that do it for every value they change (count),
    // quietRestart = set around one change whose screen shows the note itself (the core reports it synchronously).
    property int  ownRestartHints: 0
    property bool quietRestart:    false

    function px(v)  { return Math.round(v * scale) }
    function fs(v)  { return Math.max(1, Math.round(v * scale * textScale)) }

    // Colors
    readonly property color bgBase:         "#0f1216"
    readonly property color surfaceGlass:   "#151920"
    readonly property color surfaceRaised:  "#1e232b"
    readonly property color surfaceControl: "#2a303a"
    readonly property color line:           "#3a414c"
    readonly property color textPrimary:    "#f4f6f8"
    readonly property color textSecondary:  "#a9b2be"
    readonly property color textTertiary:   "#939ca9"
    readonly property color brandGreen:     "#0c8062"
    readonly property color brandGreenDark: "#0b6f54"
    readonly property color ok:             "#2fcb7f"
    readonly property color warn:           "#f5a524"
    readonly property color danger:         "#c9353d"
    readonly property color info:           "#2a68cc"
    readonly property color textLink:       "#7ab0ff"
    readonly property color textDanger:     "#ff7a80"

    // Fonts: Roboto, bundled in fonts/ and registered in QGCApplication::setLanguage().
    // Hangul falls back to Noto Sans KR, kana / kanji to Noto Sans JP (QFont substitution, set once for every
    // language); Latin and digits stay Roboto.
    // Some platforms register Roboto Medium as its own family "Roboto Medium".
    readonly property string fontFamily:        "Roboto"
    readonly property string fontFamilyMedium:  Qt.fontFamilies().indexOf("Roboto Medium") >= 0 ? "Roboto Medium" : "Roboto"

    // Layout rules (design px) — see Figma 00 Overview §8
    readonly property int topBarHeight:     104
    readonly property int actionX:          28
    readonly property int actionY0:         250
    readonly property int actionStep:       200
    readonly property int telemetryX:       24      // left = flight, right = camera (decision 2026-11-13)
    readonly property int panelBottomMax:   910
    readonly property int touchMin:         96

    function withAlpha(c, a) { var q = Qt.lighter(c, 1.0); return Qt.rgba(q.r, q.g, q.b, a) }

    // Units on the plan screens (Tuleap bug #22586: heights and distances were always shown in metres). Values stay in
    // metres; these convert for display and back from a stepper. The unit system is set in Settings › General (it
    // applies after a restart, like every QGC unit).
    readonly property var _uc: QGroundControl.unitsConversion
    function vUnit()   { return _uc.appSettingsVerticalDistanceUnitsString }
    function hUnit()   { return _uc.appSettingsHorizontalDistanceUnitsString }
    function toV(m)    { return Number(_uc.metersToAppSettingsVerticalDistanceUnits(m)) }
    function fromV(d)  { return Number(_uc.appSettingsVerticalDistanceUnitsToMeters(d)) }
    function toH(m)    { return Number(_uc.metersToAppSettingsHorizontalDistanceUnits(m)) }
    function fromH(d)  { return Number(_uc.appSettingsHorizontalDistanceUnitsToMeters(d)) }
    // whole numbers with the unit, "—" for no value
    function vText(m)  { return isFinite(m) ? Math.round(toV(m)) + " " + vUnit() : "—" }
    function hText(m)  { return isFinite(m) ? Math.round(toH(m)) + " " + hUnit() : "—" }
    // stepper step for a step given in metres: 5 m = 15 ft, 10 m = 35 ft, 1 m = 3 ft
    function vStep(mStep) { return _unitStep(toV(mStep)) }
    function hStep(mStep) { return _unitStep(toH(mStep)) }
    function _unitStep(s) { return s < 5 ? Math.max(1, Math.round(s)) : Math.round(s / 5) * 5 }
    // area and route length as on the saved-missions list (ha / km or ac / mi)
    function areaText(m2) { return !isFinite(m2) ? "—" : hUnit() === "m" ? (m2 / 10000).toFixed(1) + " ha" : (m2 / 4046.86).toFixed(1) + " ac" }
    function longText(m)  { return !isFinite(m) ? "—" : hUnit() === "m" ? (m / 1000).toFixed(1) + " km" : (m / 1609.34).toFixed(1) + " mi" }

    // Unit system used by Settings › General and the first-start welcome (S57).
    // Metric: m, m, ha, m/s, °C · Imperial: ft, ft, acres, mph, °F (UnitsSettings enum values)
    // The classic "requires restart" popup is suppressed; callers show their own plain hint.
    // Returns true when something changed.
    function applyUnitSystem(units, metric) {
        var rg = [ [units.horizontalDistanceUnits, metric ? 1 : 0],
                   [units.verticalDistanceUnits,   metric ? 1 : 0],
                   [units.areaUnits,               metric ? 3 : 4],
                   [units.speedUnits,              metric ? 1 : 2],
                   [units.temperatureUnits,        metric ? 0 : 1] ]
        var changed = false
        for (var i = 0; i < rg.length; i++) {
            var f = rg[i][0]
            if (f.rawValue !== rg[i][1]) {
                f._setIgnoreQGCRebootRequired(true)
                f.rawValue = rg[i][1]
                f._setIgnoreQGCRebootRequired(false)
                changed = true
            }
        }
        return changed
    }
}
