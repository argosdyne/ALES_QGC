/****************************************************************************
 * AQGC Simple UI — S84 Vehicle setup › Safety › Pre-arm checks (Figma 158:43058, 2026-11-18).
 * ARMING_CHECK bitmask: bit value 1 = "All". The item names come from the bundled parameter documentation
 * (fact.bitmaskStrings / bitmaskValues), shown with plain names where known. Turning one item off while "All" is on
 * writes the sum of the other items. A value of 0 (no checks) needs a red confirm first. Every change goes to the
 * security log. Baseline (user 2026-11-18) = the company reference (SimpleReference, ARMING_CHECK 32254 on AQUILA-3F):
 * checks the reference leaves off are normal; only checks off beyond the reference are orange. The top switch
 * "Company setting" writes the reference value (1 = All when there is no reference).
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

SSheet {
    id: pa
    title: qsTr("Pre-arm checks")
    subtitle: qsTr("The drone refuses to start when a check fails. Keep all on for normal flights.")
    designWidth: 900
    closeOnOutside: true

    property var  fact: null          // ARMING_CHECK
    property bool armed: false
    property int  pending: -1         // value waiting for the "no checks" confirm

    readonly property int  value: fact ? Number(fact.rawValue) : 0
    readonly property bool all: (value & 1) === 1
    readonly property var  bits: fact ? fact.bitmaskValues : []
    readonly property int  missing: fact ? SimpleReference.armingMissing(value, bits) : 0     // on in the reference, off here
    readonly property bool company: !!fact && missing === 0
    readonly property int  refValue: SimpleReference.armingReference()
    function inReference(bit) { return (SimpleReference.armingEffective(refValue, bits) & bit) !== 0 }
    readonly property var  items: {
        var r = []
        if (!fact) return r
        var s = fact.bitmaskStrings, v = fact.bitmaskValues
        for (var i = 0; i < v.length; i++) if (Number(v[i]) !== 1) r.push({ bit: Number(v[i]), name: plain(Number(v[i]), s[i]) })
        return r
    }
    readonly property var offNames: {
        var r = []
        for (var i = 0; i < items.length; i++) if ((missing & items[i].bit) !== 0) r.push(items[i].name)
        return r
    }
    function plain(bit, docName) {
        var m = { 2: qsTr("Barometer"), 4: qsTr("Compass"), 8: qsTr("GPS lock"), 16: qsTr("Inertial sensors"), 32: qsTr("Parameters"),
                  64: qsTr("Radio (RC)"), 128: qsTr("Board voltage"), 256: qsTr("Battery level"), 1024: qsTr("Logging"),
                  2048: qsTr("Safety switch"), 4096: qsTr("GPS configuration"), 8192: qsTr("System"), 16384: qsTr("Mission"),
                  32768: qsTr("Rangefinder"), 65536: qsTr("Camera"), 131072: qsTr("Auxiliary authorisation"),
                  262144: qsTr("Visual odometry"), 524288: qsTr("FFT") }
        return m[bit] !== undefined ? m[bit] : docName
    }
    function isOn(bit) { return all || (value & bit) !== 0 }
    function write(nv, what) {
        if (!fact || armed) return
        if (nv === 0 && pending !== 0) { pending = 0; return }
        pending = -1
        fact.rawValue = nv
        var pd = QGroundControl.corePlugin.privacyData
        if (pd) pd.logEvent("Pre-arm checks", what + " → ARMING_CHECK = " + nv)
    }
    function setItem(bit, on) {
        var cur = all ? 0 : value
        if (all) for (var i = 0; i < items.length; i++) cur |= items[i].bit
        var nv = on ? (cur | bit) : (cur & ~bit)
        var full = 0
        for (var j = 0; j < items.length; j++) full |= items[j].bit
        if (nv === full) nv = 1
        write(nv, plain(bit, "") + (on ? " on" : " off"))
    }
    onAboutToShow: pending = -1

    Item {
        width: pa.innerWidth; height: SimpleTheme.px(72)
        Column {
            anchors.verticalCenter: parent.verticalCenter
            SText { text: qsTr("Company setting (recommended)"); size: 28; bold: true }
            SText { text: pa.all ? qsTr("All checks on") : qsTr("%1 reference").arg(SimpleReference.product); size: 20; color: SimpleTheme.textSecondary }
        }
        SToggle { objectName: "prearmAll"; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                  checked: pa.company; enabled: !pa.company && !pa.armed; opacity: enabled || pa.company ? 1 : 0.4
                  onToggled: { if (checked) pa.write(pa.refValue, "Company setting") } }
    }
    Rectangle {
        width: pa.innerWidth; height: grid.height + SimpleTheme.px(16); radius: SimpleTheme.px(20)
        color: SimpleTheme.surfaceControl
        Grid {
            id: grid
            x: SimpleTheme.px(20); y: SimpleTheme.px(8)
            columns: 2; columnSpacing: SimpleTheme.px(40)
            Repeater {
                model: pa.items
                Item {
                    width: (pa.innerWidth - SimpleTheme.px(80)) / 2; height: SimpleTheme.px(64)
                    Column {
                        anchors.left: parent.left; anchors.right: t.left; anchors.rightMargin: SimpleTheme.px(8); anchors.verticalCenter: parent.verticalCenter
                        SText { width: parent.width; text: modelData.name; size: 24; elide: Text.ElideRight
                                color: (pa.missing & modelData.bit) !== 0 ? SimpleTheme.warn : SimpleTheme.textPrimary }
                        SText { visible: !pa.inReference(modelData.bit); text: qsTr("Off in the company setting"); size: 18; color: SimpleTheme.textTertiary }
                    }
                    SToggle { id: t; objectName: "prearm_" + modelData.bit; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                              scale: 0.8; transformOrigin: Item.Right
                              checked: pa.isOn(modelData.bit); enabled: !pa.armed
                              onToggled: { pa.setItem(modelData.bit, checked) } }
                }
            }
        }
    }
    SNotice { visible: pa.offNames.length > 0 && pa.value !== 0; level: "warn"
              text: qsTr("%n check(s) off that the company setting has on: %1. Turn them back on before normal flights.", "", pa.offNames.length).arg(pa.offNames.join(", ")) }
    SNotice { visible: pa.value === 0 && !!pa.fact; level: "danger"; text: qsTr("No checks: the drone starts even with a fault.") }
    SNotice { visible: pa.armed; level: "danger"; text: qsTr("The drone is armed. Stop the motors first.") }
    Column {
        visible: pa.pending === 0
        width: pa.innerWidth; spacing: SimpleTheme.px(12)
        SNotice { level: "danger"; text: qsTr("Turn off every check? The drone will start even with a broken sensor or no GPS.") }
        Row {
            spacing: SimpleTheme.px(12)
            SButton { width: (pa.innerWidth - parent.spacing) / 2; designHeight: 72; textSize: 26; text: qsTr("Keep this check on"); onClicked: pa.pending = -1 }
            SButton { objectName: "prearmNoneConfirm"; width: (pa.innerWidth - parent.spacing) / 2; designHeight: 72; textSize: 26; kind: "danger"
                      text: qsTr("Turn all off"); onClicked: pa.write(0, "All off") }
        }
    }
    SButton { visible: pa.pending !== 0; width: pa.innerWidth; designHeight: 72; textSize: 26; kind: "primary"; text: qsTr("Done"); onClicked: pa.close() }
}
