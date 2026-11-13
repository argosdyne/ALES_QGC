import QtQuick 2.12
import "."

// [-] value unit [+]
Row {
    id: st
    property real   value:  0
    property real   step:   1
    property real   from:   0
    property real   to:     100
    property int    decimals: 0
    property string unit:   ""
    property bool   enabled_: true
    signal edited(real value)

    spacing: SimpleTheme.px(8)

    function _set(v) {
        v = Math.max(from, Math.min(to, v))
        v = Number(v.toFixed(decimals))
        if (v !== value) { value = v; edited(v) }
    }

    SRoundIconButton { icon: "minus"; enabled_: st.enabled_ && st.value > st.from; onClicked: st._set(st.value - st.step) }
    Item {
        width:  SimpleTheme.px(140)
        height: SimpleTheme.px(80)
        opacity: st.enabled_ ? 1 : 0.4
        Row {
            anchors.centerIn: parent
            spacing: SimpleTheme.px(6)
            SText { id: valueText; text: st.value.toFixed(st.decimals); size: 34; bold: true }
            SText { text: st.unit; size: 22; color: SimpleTheme.textSecondary; anchors.baseline: valueText.baseline }
        }
    }
    SRoundIconButton { icon: "plus"; enabled_: st.enabled_ && st.value < st.to; onClicked: st._set(st.value + st.step) }
}
