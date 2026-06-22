/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/
import QtQuick          2.3

import QGroundControl.FactSystem    1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0

FactTextField {
    unitsLabel:                             fact ? fact.units : ""
    showUnits:                              true
    showHelp:                               true
    customValidateFunction:                 function(valueText) { return validateSpeed(valueText) }
    customValidationReplacesFactValidation: true

    function _formatRangeValue(value, decimals) {
        var rounded = Number(value).toFixed(decimals)
        return rounded.indexOf(".") === -1 ? rounded : rounded.replace(/\.?0+$/, "")
    }

    function _speedMaxForUnits(units) {
        switch (units) {
        case "m/s":  return 30
        case "ft/s": return 30 * 3.280839895
        case "mph":  return 30 * 2.236936292
        case "km/h": return 30 * 3.6
        case "kn":   return 30 * 1.943844492
        default:     return NaN
        }
    }

    function _speedRegexForUnits(units) {
        return units === "km/h" ? /^\d{1,3}(\.\d)?$/ : /^\d{1,2}(\.\d)?$/
    }

    function validateSpeed(valueText) {
        if (!fact || isNaN(_speedMaxForUnits(fact.units))) {
            return ""
        }

        var units = fact.units
        var maxValue = _speedMaxForUnits(units)
        var rangeDecimals = units === "km/h" ? 0 : 1

        if (!_speedRegexForUnits(units).test(valueText)) {
            return qsTr("Speed must be numeric with up to 1 decimal place and within 0-%1 %2.")
                    .arg(_formatRangeValue(maxValue, rangeDecimals))
                    .arg(units)
        }

        var value = Number(valueText)
        if (isNaN(value) || value < 0 || value > maxValue) {
            return qsTr("Speed must be within 0-%1 %2.")
                    .arg(_formatRangeValue(maxValue, rangeDecimals))
                    .arg(units)
        }

        return ""
    }
}
