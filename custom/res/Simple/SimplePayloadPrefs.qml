/****************************************************************************
 * AQGC Simple UI — payload settings of S56 (Settings › Payloads › Megaphone, Searchlight, Winch, Cleaning device).
 * Decision 2026-11-16: the S56 values are kept in the app as designed. Only these are used today:
 *   winchHoldMs            hold time of "Hold to release" on the fly screen
 *   megaphoneStopOnLanding stop the clip when the drone lands
 *   lightOffOnLanding      turn the searchlight off when the drone lands
 * The others (volume, speech language, brightness, strobe, lowering speed, cleaning values) wait for device commands.
 ****************************************************************************/
pragma Singleton
import QtQuick 2.12
import Qt.labs.settings 1.0

Settings {
    category: "SimplePayloads"
    property int    megaphoneMaxVolume:     80      // %
    property int    megaphoneLanguage:      0       // 0 English, 1 Korean
    property bool   megaphoneStopOnLanding: true
    property int    lightMaxBrightness:     100     // %
    property bool   lightStrobe:            false
    property bool   lightOffOnLanding:      true
    property int    winchHoldMs:            2000    // 1000 / 2000 / 3000
    property int    winchSpeed:             1       // 0 slow, 1 normal, 2 fast
    property int    cleanPressure:          1       // 0 low, 1 mid, 2 high
    property real   cleanWallDistance:      2.5     // m
    readonly property real cleanAutoStop:   1.5     // m, safety limit (fixed)
}
