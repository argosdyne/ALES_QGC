/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.3
import QtQuick.Controls 1.2
import QtQuick.Dialogs  1.2
import QtQuick.Layouts  1.2

import QGroundControl               1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controllers   1.0

// Exposes the set of battery parameters for new and old firmwares
//  Older firmware: BAT_* naming
//  Newer firmware: BAT#_* naming, with indices starting at 1
QtObject {
    property var controller     ///< FactPanelController
    property int batteryIndex   ///< 1-based battery index


    property Fact battSource:                   _batteryFact("SOURCE")
    property Fact battNumCells:                 _batteryFact("N_CELLS")
    property Fact battHighVolt:                 _batteryFact("V_CHARGED")
    property Fact battLowVolt:                  _batteryFact("V_EMPTY")
    property Fact battVoltLoadDrop:             _batteryFact("V_LOAD_DROP")
    property Fact battVoltageDivider:           _batteryFact("V_DIV")
    property Fact battAmpsPerVolt:              _batteryFact("A_PER_V")

    property bool battVoltageDividerAvailable:  _batteryParamExists("V_DIV")
    property bool battAmpsPerVoltAvailable:     _batteryParamExists("A_PER_V")

    property string _batNCellsIndexedParamName:     "BAT#_N_CELLS"
    property bool   _indexedBatteryParamsAvailable: controller.parameterExists(-1, _batNCellsIndexedParamName.replace("#", 1))
    property int    _indexedBatteryParamCount:      getIndexedBatteryParamCount()

    Component.onCompleted: {
        if (batteryIndex > 1 && !_indexedBatteryParamsAvailable) {
            console.warn("Internal Error: BatteryParams.qml batteryIndex > 1 while indexed params are not available", batteryIndex)
        }
    }

    function getIndexedBatteryParamCount() {
        var batteryIndex = 1
        do {
            if (!controller.parameterExists(-1, _batNCellsIndexedParamName.replace("#", batteryIndex))) {
                return batteryIndex - 1
            }
            batteryIndex++
        } while (true)
    }

    function _batteryParamName(paramSuffix) {
        if (_indexedBatteryParamsAvailable) {
            var indexedName = "BAT" + batteryIndex + "_" + paramSuffix
            if (controller.parameterExists(-1, indexedName) || batteryIndex > 1) {
                return indexedName
            }
        }

        return "BAT_" + paramSuffix
    }

    function _batteryParamExists(paramSuffix) {
        return controller.parameterExists(-1, _batteryParamName(paramSuffix))
    }

    function _batteryFact(paramSuffix) {
        var paramName = _batteryParamName(paramSuffix)
        return controller.parameterExists(-1, paramName) ? controller.getParameterFact(-1, paramName, false) : null
    }
}
