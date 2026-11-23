/****************************************************************************
 * AQGC Simple UI — S88 Analyze › MAVLink Inspector › Chart (Figma 160:43006, 2026-11-18), developer tools.
 * Up to two numeric fields of the selected message (ticked "Chart" in S63). Values are sampled every 100 ms from the
 * inspector field objects into a buffer as long as the time window (10 / 30 / 60 s) and drawn with a QML Canvas
 * (no QtCharts). Vertical scale is automatic. Pause stops drawing, sampling goes on. Closing clears the buffer.
 ****************************************************************************/
import QtQuick 2.12
import "."

SSheet {
    id: ch
    title: qsTr("Chart")
    designWidth: 1400
    closeOnOutside: true

    property string messageName: ""
    property real   rateHz: 0
    property var    fields: []             // [{ name, obj }] — obj = inspector field (value as text)
    property int    windowS: 30
    property bool   paused: false
    property var    series: [[], []]        // [[{t, v}]]
    readonly property var colors: [SimpleTheme.ok, SimpleTheme.textLink]
    signal removeField(string name)

    subtitle: qsTr("%1 · from the drone, %2 values per second").arg(messageName).arg(rateHz.toFixed(0))
    onAboutToShow: { series = [[], []]; paused = false }
    onClosed: series = [[], []]
    onFieldsChanged: series = [[], []]

    function latest(i) { var s = series[i]; return s && s.length ? s[s.length - 1].v : NaN }
    function fmt(v) { return isNaN(v) ? "—" : (Math.abs(v) >= 1000 ? v.toFixed(0) : Math.abs(v) >= 10 ? v.toFixed(2) : v.toFixed(4)) }

    Timer {
        interval: 100; repeat: true; running: ch.visible
        onTriggered: {
            var now = Date.now(), keep = now - ch.windowS * 1000, s = [[], []]
            for (var i = 0; i < 2; i++) {
                var old = ch.series[i] || []
                for (var k = 0; k < old.length; k++) if (old[k].t >= keep) s[i].push(old[k])
                if (i < ch.fields.length && ch.fields[i].obj) {
                    var v = parseFloat(ch.fields[i].obj.value)
                    if (!isNaN(v)) s[i].push({ t: now, v: v })
                }
            }
            ch.series = s
            if (!ch.paused) canvas.requestPaint()
        }
    }

    // fields + window
    Item {
        width: ch.innerWidth; height: SimpleTheme.px(56)
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: SimpleTheme.px(12)
            Repeater {
                model: ch.fields
                Rectangle {
                    height: SimpleTheme.px(48); width: fr.width + SimpleTheme.px(32); radius: SimpleTheme.px(14); color: SimpleTheme.surfaceControl
                    Row {
                        id: fr
                        anchors.centerIn: parent; spacing: SimpleTheme.px(10)
                        Rectangle { width: SimpleTheme.px(16); height: width; radius: width / 2; color: ch.colors[index]; anchors.verticalCenter: parent.verticalCenter }
                        SText { text: modelData.name; size: 22; medium: true; anchors.verticalCenter: parent.verticalCenter }
                        SIcon { name: "close"; size: 24; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter
                                MouseArea { anchors.fill: parent; anchors.margins: -SimpleTheme.px(10); onClicked: ch.removeField(modelData.name) } }
                    }
                }
            }
            SText { visible: ch.fields.length < 2; anchors.verticalCenter: parent.verticalCenter; size: 22; color: SimpleTheme.textSecondary
                    text: qsTr("Tick “Chart” on a field to add it (max 2)") }
        }
        SSegmented {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            model: ["10 s", "30 s", "60 s"]; designWidth: 360
            currentIndex: [10, 30, 60].indexOf(ch.windowS)
            onActivated: ch.windowS = [10, 30, 60][index]
        }
    }
    Rectangle {
        width: ch.innerWidth; height: SimpleTheme.px(420); radius: SimpleTheme.px(16); color: SimpleTheme.bgBase
        Canvas {
            id: canvas
            anchors.fill: parent
            property real vmin: 0
            property real vmax: 1
            onPaint: {
                var ctx = getContext("2d"), w = width, h = height, left = SimpleTheme.px(110), top = SimpleTheme.px(20), bot = SimpleTheme.px(20)
                ctx.reset()
                var mn = Infinity, mx = -Infinity
                for (var i = 0; i < 2; i++) { var s = ch.series[i] || []; for (var k = 0; k < s.length; k++) { mn = Math.min(mn, s[k].v); mx = Math.max(mx, s[k].v) } }
                if (!isFinite(mn)) { mn = 0; mx = 1 }
                if (mx - mn < 1e-9) { mn -= 0.5; mx += 0.5 }
                var pad = (mx - mn) * 0.08; mn -= pad; mx += pad
                vmin = mn; vmax = mx
                ctx.strokeStyle = SimpleTheme.line; ctx.lineWidth = 1
                for (var g = 0; g <= 4; g++) { var y = top + (h - top - bot) * g / 4; ctx.beginPath(); ctx.moveTo(left, y); ctx.lineTo(w - SimpleTheme.px(20), y); ctx.stroke() }
                var now = Date.now(), span = ch.windowS * 1000
                for (var j = 0; j < 2; j++) {
                    var d = ch.series[j] || []
                    if (d.length < 2) continue
                    ctx.strokeStyle = ch.colors[j]; ctx.lineWidth = SimpleTheme.px(3)
                    ctx.beginPath()
                    for (var n = 0; n < d.length; n++) {
                        var x = left + (w - left - SimpleTheme.px(20)) * (1 - (now - d[n].t) / span)
                        var yy = top + (h - top - bot) * (1 - (d[n].v - mn) / (mx - mn))
                        if (n === 0) ctx.moveTo(x, yy); else ctx.lineTo(x, yy)
                    }
                    ctx.stroke()
                }
            }
        }
        SText { x: SimpleTheme.px(12); y: SimpleTheme.px(10); text: ch.fmt(canvas.vmax); size: 18; color: SimpleTheme.textSecondary }
        SText { x: SimpleTheme.px(12); anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(10); text: ch.fmt(canvas.vmin); size: 18; color: SimpleTheme.textSecondary }
        SText { anchors.centerIn: parent; visible: ch.fields.length === 0; text: qsTr("No field chosen"); size: 24; color: SimpleTheme.textSecondary }
    }
    Item {
        width: ch.innerWidth; height: SimpleTheme.px(48)
        SText { anchors.verticalCenter: parent.verticalCenter; size: 24; medium: true
                text: ch.fields.map(function(f, i) { return f.name + "  " + ch.fmt(ch.latest(i)) }).join("   ·   ") }
        SText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; size: 22; color: SimpleTheme.textSecondary; text: qsTr("Scale: auto") }
    }
    Row {
        spacing: SimpleTheme.px(12)
        SButton { objectName: "chartPause"; width: (ch.innerWidth - parent.spacing) / 2; designHeight: 72; textSize: 26
                  text: ch.paused ? qsTr("Resume") : qsTr("Pause"); onClicked: ch.paused = !ch.paused }
        SButton { width: (ch.innerWidth - parent.spacing) / 2; designHeight: 72; textSize: 26; kind: "primary"; text: qsTr("Close"); onClicked: ch.close() }
    }
}
