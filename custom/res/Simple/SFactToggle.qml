/****************************************************************************
 * AQGC Simple UI — switch bound to a bool setting / parameter (S64, S69). invert = on means false.
 ****************************************************************************/
import QtQuick 2.12
import "."

SToggle {
    id: tg
    property var  fact: null
    property bool invert: false
    readonly property bool _value: !!fact && (invert ? !fact.rawValue : !!fact.rawValue)
    checked: _value
    onToggled: {
        if (fact) fact.rawValue = invert ? !checked : checked
        tg.checked = Qt.binding(function() { return tg._value })
    }
}
