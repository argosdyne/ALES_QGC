/****************************************************************************
 * AQGC Simple UI — design tokens (Figma "AQGC-simpler", collection "AQGC Simple")
 * Layout values are in design pixels of a 1920x1080 screen; use px() / fs().
 ****************************************************************************/
pragma Singleton
import QtQuick 2.12

QtObject {
    // Set by SimpleRoot from the window size (1920x1080 = 1.0)
    property real scale:        1.0
    // Settings > General > Text size (Large = 1.2)
    property real textScale:    1.0

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

    // Fonts (design: Roboto UI, Noto Sans KR for Korean — bundled fonts are a v2 item)
    readonly property string fontFamily:    "Roboto"

    // Layout rules (design px) — see Figma 00 Overview §8
    readonly property int topBarHeight:     104
    readonly property int actionX:          28
    readonly property int actionY0:         250
    readonly property int actionStep:       200
    readonly property int telemetryX:       448
    readonly property int panelBottomMax:   910
    readonly property int touchMin:         96

    function withAlpha(c, a) { var q = Qt.lighter(c, 1.0); return Qt.rgba(q.r, q.g, q.b, a) }
}
