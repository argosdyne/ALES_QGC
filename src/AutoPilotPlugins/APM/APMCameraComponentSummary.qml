import QtQuick          2.3
import QtQuick.Controls 1.2

import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0

Item {
    anchors.fill:   parent

    FactPanelController { id: controller; }

    function _mountParamFact(suffix) {
        if (controller.parameterExists(-1, "MNT1_" + suffix)) {
            return controller.getParameterFact(-1, "MNT1_" + suffix, false)
        }
        if (controller.parameterExists(-1, "MNT_" + suffix)) {
            return controller.getParameterFact(-1, "MNT_" + suffix, false)
        }
        return null
    }

    function _mountParamExists(suffix) {
        return controller.parameterExists(-1, "MNT1_" + suffix) || controller.parameterExists(-1, "MNT_" + suffix)
    }

    property Fact _mountRCInTilt:   _mountParamFact("RC_IN_TILT")
    property Fact _mountRCInRoll:   _mountParamFact("RC_IN_ROLL")
    property Fact _mountRCInPan:    _mountParamFact("RC_IN_PAN")

    // MNT_TYPE parameter is not in older firmware versions
    property bool   _mountTypeExists: _mountParamExists("TYPE")
    property string _mountTypeValue: _mountTypeExists ? _mountParamFact("TYPE").enumStringValue : ""

    Column {
        anchors.fill:       parent

        VehicleSummaryRow {
            visible:    _mountTypeExists
            labelText:  qsTr("Gimbal type")
            valueText:  _mountTypeValue
        }

        VehicleSummaryRow {
            labelText:  qsTr("Tilt input channel")
            valueText:  _mountRCInTilt.enumStringValue
        }

        VehicleSummaryRow {
            labelText:  qsTr("Pan input channel")
            valueText:  _mountRCInPan.enumStringValue
        }

        VehicleSummaryRow {
            labelText:  qsTr("Roll input channel")
            valueText:  _mountRCInRoll.enumStringValue
        }
    }
}
