/****************************************************************************
 * AQGC Simple UI — S81 Vehicle setup › Radio › Calibrate sticks (Figma 158:42563, 2026-11-18).
 * Three steps: 1 centre the sticks, throttle down (captures the centre = trim) · 2 move every stick and switch to its
 * ends (min / max per channel grow live) · 3 check the table and Save → RCn_MIN / RCn_MAX / RCn_TRIM.
 * Only channels that moved (range > 200) are written; the throttle trim is its minimum (ArduPilot rule).
 * The radio page owns the channel values (RCChannelMonitorController) and passes them in.
 ****************************************************************************/
import QtQuick 2.12
import "."

SSheet {
    id: cal
    title: qsTr("Calibrate sticks")
    steps: 3
    designWidth: 1000

    property var  values: []          // live PWM per channel (index 0 = ch 1)
    property int  count: 8
    property var  page: null          // the radio page: nameOf(ch), p(paramName)
    function nameOf(ch) { return page ? page.nameOf(ch) : qsTr("Ch %1").arg(ch + 1) }
    function param(n) { return page ? page.p(n) : null }
    property bool armed: false
    property int  throttleCh: 2       // 0-based

    property var trims: []
    property var mins: []
    property var maxs: []
    property string saved: ""

    subtitle: step === 0 ? qsTr("Step 1 of 3 · Put both sticks in the centre and the throttle all the way down. Leave the switches where they are.")
            : step === 1 ? qsTr("Step 2 of 3 · Move both sticks to every corner and all switches to every position. The bars grow while you move.")
            : qsTr("Step 3 of 3 · Check the values. Channels you did not move keep their old values.")

    onAboutToShow: { step = 0; trims = []; mins = []; maxs = []; saved = "" }

    onValuesChanged: {
        if (step !== 1) return
        var mn = mins.slice(), mx = maxs.slice(), ch = false
        for (var i = 0; i < count; i++) {
            var v = values[i]
            if (!(v > 0)) continue
            if (mn[i] === undefined || v < mn[i]) { mn[i] = v; ch = true }
            if (mx[i] === undefined || v > mx[i]) { mx[i] = v; ch = true }
        }
        if (ch) { mins = mn; maxs = mx }
    }

    function moved(i) { return mins[i] !== undefined && maxs[i] !== undefined && maxs[i] - mins[i] > 200 }
    function frac(v) { return Math.max(0, Math.min(1, (v - 800) / 1400)) }
    readonly property bool throttleTopMissing: step === 1 && !(maxs[throttleCh] > 1800)
    readonly property var narrow: {
        var r = []
        for (var i = 0; i < Math.min(4, count); i++) if (step === 1 && !(maxs[i] - mins[i] > 800)) r.push(i)
        return r
    }

    function next() {
        if (step === 0) {
            var t = [], mn = [], mx = []
            for (var i = 0; i < count; i++) if (values[i] > 0) { t[i] = values[i]; mn[i] = values[i]; mx[i] = values[i] }
            trims = t; mins = mn; maxs = mx
            step = 1
        } else if (step === 1) {
            step = 2
        }
    }
    function save() {
        var n = 0
        for (var i = 0; i < count; i++) {
            if (!moved(i)) continue
            var c = i + 1
            var fMin = param("RC" + c + "_MIN"), fMax = param("RC" + c + "_MAX"), fTrim = param("RC" + c + "_TRIM")
            if (!fMin || !fMax || !fTrim) continue
            var trim = i === throttleCh ? mins[i] : Math.max(mins[i], Math.min(maxs[i], trims[i] > 0 ? trims[i] : 1500))
            fMin.rawValue = mins[i]; fMax.rawValue = maxs[i]; fTrim.rawValue = trim
            n++
        }
        saved = n > 0 ? qsTr("Saved %n channel(s).", "", n) : qsTr("Nothing moved: no values changed.")
        if (n > 0) close()
    }

    // channel list (steps 2 and 3)
    Rectangle {
        width: cal.innerWidth; height: list.height + SimpleTheme.px(32); radius: SimpleTheme.px(20)
        color: SimpleTheme.surfaceControl
        Column {
            id: list
            x: SimpleTheme.px(24); y: SimpleTheme.px(16); width: parent.width - SimpleTheme.px(48)
            spacing: SimpleTheme.px(6)
            Repeater {
                model: cal.count
                Item {
                    width: list.width; height: SimpleTheme.px(52)
                    visible: v > 0 || hasRange          // channels without a signal are not listed
                    readonly property int v: cal.values[index] > 0 ? cal.values[index] : 0
                    readonly property bool hasRange: cal.step > 0 && cal.mins[index] !== undefined
                    SText { width: SimpleTheme.px(270); anchors.verticalCenter: parent.verticalCenter; text: cal.nameOf(index); size: 24; elide: Text.ElideRight }
                    Item {
                        x: SimpleTheme.px(280); width: parent.width - SimpleTheme.px(500); height: SimpleTheme.px(8); anchors.verticalCenter: parent.verticalCenter
                        Rectangle { anchors.fill: parent; radius: height / 2; color: SimpleTheme.surfaceRaised }
                        Rectangle { visible: parent.parent.hasRange; height: parent.height; radius: height / 2; color: SimpleTheme.brandGreen
                                    x: parent.width * cal.frac(cal.mins[index] || 0)
                                    width: Math.max(SimpleTheme.px(4), parent.width * (cal.frac(cal.maxs[index] || 0) - cal.frac(cal.mins[index] || 0))) }
                        Rectangle { visible: parent.parent.v > 0 && cal.step < 2; width: SimpleTheme.px(24); height: width; radius: width / 2; color: SimpleTheme.textPrimary
                                    anchors.verticalCenter: parent.verticalCenter; x: parent.width * cal.frac(parent.parent.v) - width / 2 }
                    }
                    SText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; size: 22; medium: true
                            color: cal.step > 0 && !cal.moved(index) ? SimpleTheme.textSecondary : SimpleTheme.textPrimary
                            text: cal.step === 0 ? (parent.v > 0 ? parent.v : "—")
                                : cal.step === 1 ? (parent.hasRange ? cal.mins[index] + " – " + cal.maxs[index] : "—")
                                : (cal.moved(index) ? cal.mins[index] + " · " + (index === cal.throttleCh ? cal.mins[index] : cal.trims[index]) + " · " + cal.maxs[index] : qsTr("not moved")) }
                }
            }
        }
    }
    SNotice { visible: cal.throttleTopMissing; level: "warn"; text: qsTr("Throttle has not reached the top yet. Push it all the way up once.") }
    SNotice { visible: cal.step === 1 && !cal.throttleTopMissing && cal.narrow.length > 0; level: "warn"
              text: qsTr("Small range on: %1. Move it to both ends.").arg(cal.narrow.map(function(i) { return cal.nameOf(i) }).join(", ")) }
    SText { visible: cal.step === 2; width: cal.innerWidth; size: 22; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap
            text: qsTr("Minimum · centre · maximum. The throttle centre is its minimum.") }
    SNotice { visible: cal.armed; level: "danger"; text: qsTr("The drone is armed. Stop the motors first.") }
    SText { visible: cal.saved !== ""; text: cal.saved; size: 22; color: SimpleTheme.warn }
    SText { visible: cal.step < 2; width: cal.innerWidth; size: 22; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap
            text: qsTr("The motors stay off. The drone must not be armed.") }
    Row {
        spacing: SimpleTheme.px(12)
        SButton { objectName: "radioCalCancel"; width: (cal.innerWidth - parent.spacing) / 2; designHeight: 72; textSize: 26
                  text: qsTr("Cancel"); onClicked: cal.close() }
        SButton { objectName: "radioCalNext"; width: (cal.innerWidth - parent.spacing) / 2; designHeight: 72; textSize: 26; kind: "primary"
                  enabled_: !cal.armed && (cal.step !== 0 || cal.values.length > 0)
                  text: cal.step < 2 ? qsTr("Next") : qsTr("Save")
                  onClicked: cal.step < 2 ? cal.next() : cal.save() }
    }
}
