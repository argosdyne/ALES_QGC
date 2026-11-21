/****************************************************************************
 * AQGC Simple UI — editor for one FC parameter (Vehicle setup S70–S77, 2026-11-17).
 * List values: drop-down. Numbers: − value + (unit); typed values are checked with fact.validate() and sent when the
 * field is left (Enter / focus out). Every change goes to the drone at once. stepsOnly = only −/+ (tuning in flight).
 ****************************************************************************/
import QtQuick 2.12
import "."

Item {
    id: ff
    property var    fact: null
    property real   step: 0                 // 0 = fact increment or 10^-decimals
    property int    decimals: fact ? Math.max(0, fact.decimalPlaces) : 0
    property bool   stepsOnly: false
    property bool   enabled_: true
    property real   designWidth: 420
    property string error: ""
    signal changed(var oldValue, var newValue)

    readonly property bool _enum: !!fact && fact.enumStrings.length > 0 && fact.bitmaskStrings.length === 0
    readonly property real _step: step > 0 ? step : (fact && fact.increment > 0 && isFinite(fact.increment) ? fact.increment : Math.pow(10, -decimals))

    width: SimpleTheme.px(designWidth)
    height: col.height
    opacity: enabled_ ? 1 : 0.4

    function apply(v) {
        if (!fact) return
        var err = fact.validate(String(v), false)
        if (err !== "") { error = err; input.reset(); return }
        error = ""
        var old = fact.value
        fact.value = v
        changed(old, v)
    }

    Column {
        id: col
        width: parent.width
        spacing: SimpleTheme.px(6)
        SComboBox {
            visible: ff._enum
            designWidth: ff.designWidth
            enabled: ff.enabled_
            model: ff._enum ? ff.fact.enumStrings : []
            currentIndex: ff._enum ? ff.fact.enumIndex : -1
            onActivated: ff.apply(ff.fact.enumValues[index])
        }
        Row {
            visible: !ff._enum && !!ff.fact
            spacing: SimpleTheme.px(8)
            SRoundIconButton { icon: "minus"; anchors.verticalCenter: parent.verticalCenter; enabled_: ff.enabled_
                               onClicked: ff.apply(Number((Number(ff.fact.value) - ff._step).toFixed(ff.decimals))) }
            STextField {
                id: input
                anchors.verticalCenter: parent.verticalCenter
                designWidth: 170
                decimal: true
                enabled_: ff.enabled_ && !ff.stepsOnly
                error: ff.error !== ""
                text: ff.fact ? Number(ff.fact.value).toFixed(ff.decimals) : ""
                onEdited: ff.apply(text)
            }
            SRoundIconButton { icon: "plus"; anchors.verticalCenter: parent.verticalCenter; enabled_: ff.enabled_
                               onClicked: ff.apply(Number((Number(ff.fact.value) + ff._step).toFixed(ff.decimals))) }
            SText { anchors.verticalCenter: parent.verticalCenter; text: ff.fact ? ff.fact.units : ""; size: 22; color: SimpleTheme.textSecondary }
        }
        SText { visible: ff.error !== ""; width: parent.width; wrapMode: Text.WordWrap; size: 20; color: SimpleTheme.textDanger; text: ff.error }
    }
}
