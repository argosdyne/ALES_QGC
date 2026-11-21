pragma Singleton
/****************************************************************************
 * AQGC Simple UI — company reference parameters (user 2026-11-18, Figma S60 / S84 notes).
 * Source: docs/REF_45_SC_AQ3F_reference.param ("NAME,value" per line), bundled as qrc:/simple/reference/AQUILA-3F.param.
 * Used for every connected ArduCopter until there are files per product. Values that differ on every unit
 * (calibration offsets / scales, RC ranges, AHRS trim, device IDs, statistics, learned hover throttle) are never compared.
 ****************************************************************************/
import QtQuick 2.12

QtObject {
    id: ref
    readonly property string product: "AQUILA-3F"
    readonly property string source:  "qrc:/simple/reference/AQUILA-3F.param"
    property var  values: ({})                // NAME → number
    property int  count: 0
    property bool loaded: false

    // per-unit or learned values: not part of the comparison
    // (a RegExp in a property var does not survive in Qt 5 QML: keep it inside a function)
    function perUnit(name) { return /^(AHRS_TRIM_[XYZ]|BARO_GND_TEMP|BARO_ALT_OFFSET|BARO\d_(DEVID|GND_PRESS)|BATT\d?_SERIAL_NUM|BRD_SERIAL_NUM|COMPASS_(DEV_ID\d?|DIA\d?_[XYZ]|ODI\d?_[XYZ]|OFS\d?_[XYZ]|MOT\d?_[XYZ]|PRIO\d_ID|SCALE\d?)|INS_(ACC|GYR)\d?_ID|INS_(ACC|GYR)\d?_CALTEMP|INS_(ACC|GYR)\d?(OFFS|SCAL)_[XYZ]|INS_TCAL\d?_\w+|RC\d+_(MIN|MAX|TRIM)|STAT_\w+|FORMAT_VERSION|MOT_THST_HOVER|SYSID_THISMAV)$/.test(name) }

    function compared(name) { return values[name] !== undefined && !perUnit(name) }
    function refValue(name)  { return compared(name) ? values[name] : undefined }
    // true when the fact has a reference value and differs from it
    function differs(fact) {
        if (!fact || !loaded) return false
        var r = refValue(fact.name)
        if (r === undefined) return false
        var v = Number(fact.rawValue)
        if (isNaN(v)) return false
        return Math.abs(v - r) > Math.max(1e-6, 1e-4 * Math.abs(r))
    }
    function text(fact) {
        var r = fact ? refValue(fact.name) : undefined
        if (r === undefined) return ""
        return String(r) + (fact.units !== "" && fact.enumStrings.length === 0 && fact.bitmaskStrings.length === 0 ? " " + fact.units : "")
    }

    // ARMING_CHECK (S84 / S75): the reference value is "normal". bitValues = fact.bitmaskValues (without 1 = All).
    function armingFull(bitValues) { var f = 0; for (var i = 0; i < bitValues.length; i++) if (Number(bitValues[i]) !== 1) f |= Number(bitValues[i]); return f }
    function armingEffective(value, bitValues) { return (Number(value) & 1) ? armingFull(bitValues) : Number(value) }
    function armingReference() { var r = values["ARMING_CHECK"]; return r === undefined ? 1 : r }
    // checks the reference has on but the drone has off
    function armingMissing(value, bitValues) {
        return armingEffective(armingReference(), bitValues) & ~armingEffective(value, bitValues)
    }

    function _load() {
        var x = new XMLHttpRequest()
        x.open("GET", source, false)               // small file in the resources: read once, synchronously
        x.send()
        var v = {}, n = 0
        var lines = String(x.responseText).split(/\r?\n/)
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim()
            if (l === "" || l.charAt(0) === "#") continue
            var c = l.indexOf(",")
            if (c < 1) continue
            var num = Number(l.substring(c + 1))
            if (isNaN(num)) continue
            v[l.substring(0, c).trim()] = num; n++
        }
        values = v; count = n; loaded = n > 0
    }
    Component.onCompleted: _load()
}
