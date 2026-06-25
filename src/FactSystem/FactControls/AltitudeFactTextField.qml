/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/
import QtQuick          2.3
import QtQuick.Dialogs  1.2
import QtQuick.Layouts  1.2

import QGroundControl               1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0

FactTextField {
    unitsLabel:                 fact ? fact.units : ""
    extraUnitsLabel:            fact ? _altitudeModeExtraUnits : ""
    showUnits:                  true
    showHelp:                   true
    displayDecimalPlaces:       2
    customValidateFunction:     function(valueText) { return validateAltitude(valueText) }
    customValidationReplacesFactValidation: true

    property int altitudeMode: QGroundControl.AltitudeModeNone

    property string _altitudeModeExtraUnits

    onAltitudeModeChanged: updateAltitudeModeExtraUnits()

    function updateAltitudeModeExtraUnits() {
        _altitudeModeExtraUnits = QGroundControl.altitudeModeExtraUnits(altitudeMode);
    }

    function _formatRangeValue(value, decimals) {
        var rounded = Number(value).toFixed(decimals)
        return rounded.indexOf(".") === -1 ? rounded : rounded.replace(/\.?0+$/, "")
    }

    function _altitudeMaxForUnits(units) {
        switch (units) {
        case "m":
        case "meter":
        case "meters":
        case "vertical m":
            return 500
        case "ft":
            return 500 * 3.280839895
        default:
            return NaN
        }
    }

    function _altitudeRegexForUnits(units) {
        return units === "ft" ? /^\d{1,4}(\.\d{1,2})?$/ : /^\d{1,3}(\.\d{1,2})?$/
    }

    function validateAltitude(valueText) {
        if (!fact || isNaN(_altitudeMaxForUnits(fact.units))) {
            return ""
        }

        var units = fact.units
        var maxValue = _altitudeMaxForUnits(units)
        var rangeDecimals = units === "ft" ? 2 : 0
        if (!_altitudeRegexForUnits(units).test(valueText)) {
            return qsTr("Altitude must be numeric with up to 2 decimal places and within 0-%1 %2.")
                    .arg(_formatRangeValue(maxValue, rangeDecimals))
                    .arg(units)
        }

        var value = Number(valueText)
        if (isNaN(value) || value < 0 || value > maxValue) {
            return qsTr("Altitude must be within 0-%1 %2.")
                    .arg(_formatRangeValue(maxValue, rangeDecimals))
                    .arg(units)
        }

        return ""
    }
}
