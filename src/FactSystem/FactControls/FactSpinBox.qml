import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Controls.Styles  1.4
import QtQuick.Dialogs          1.2

import QGroundControl.FactSystem    1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0

QGCSpinBox {
    id: spinBox

    //property int decimals: fact ? fact.decimalPlaces : 0
    property real realValue: value / decimalFactor
    property int decimals: {
        if (!fact) return 0

        // 1) 메타데이터가 있으면 최우선
        var d = fact.decimalPlaces
        if (d > 0) return d

        // 2) increment 기반 자동 계산
        var inc = fact.increment
        if (!isFinite(inc) || inc <= 0) return 0

        // 3) 부동소수 오차 제거 (핵심)
        //    0.2000000029 -> 0.2
        var clean = Math.round(inc * 1000) / 1000   // 필요시 10000으로 조절

        // 4) 문자열로 소수 자리 계산
        var s = clean.toString()
        if (s.indexOf("e-") >= 0) {
            return Math.min(3, parseInt(s.split("e-")[1]))
        }

        var p = s.indexOf(".")
        if (p < 0) return 0

        return s.length - p - 1
    }


    readonly property int decimalFactor: Math.pow(10, decimals)
    property bool initialized:  false
    property Fact fact: null
    property bool _isOk: fact && !isNaN(fact.increment)
    from: fact ? decimalToInt(fact.min) : 0
    value: _isOk ? decimalToInt(fact.value) : 0
    to: fact ? decimalToInt(fact.max) : 100
    //stepSize: fact ? decimalToInt(fact.increment) : decimalFactor
    stepSize: fact ? Math.max(1, decimalToInt(fact.increment)) : decimalFactor
    unitsLabel: fact ? fact.units : ""
    validator: DoubleValidator {
        bottom: Math.min(spinBox.from, spinBox.to)
        top:  Math.max(spinBox.from, spinBox.to)
        decimals: spinBox.decimals
        notation: DoubleValidator.StandardNotation
    }
    textFromValue: function(value, locale) {
        return Number(value / decimalFactor).toLocaleString(locale, 'f', spinBox.decimals)
    }
    valueFromText: function(text, locale) {
        return Math.round(Number.fromLocaleString(locale, text) * decimalFactor)
    }
    function decimalToInt(decimal) {
        return Math.round(decimal * decimalFactor)
    }

    Component.onCompleted: {
        if(_isOk) {
            initialized = true
        }

        console.log("[ZoomFact]",
                        "name=", fact ? fact.name : "null",
                        "value=", fact ? fact.value : "null",
                        "inc=", fact ? fact.increment : "null",
                        "decimals=", fact ? fact.decimalPlaces : "null",
                        "min/max=", fact ? (fact.min + "/" + fact.max) : "null")
    }

    onValueModified: {
        if(fact && initialized) fact.value = realValue
    }
}
