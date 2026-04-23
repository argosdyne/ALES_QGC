import QtQuick          2.3
import QtQuick.Controls 1.2

import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0

Item {
    anchors.fill:   parent

    FactPanelController { id: controller; }

    function _localizedFlightModeEnumText(enumText) {
        if (!enumText || enumText.length === 0) {
            return enumText
        }

        if (enumText.indexOf("Channel ") === 0) {
            return qsTranslate("PX4SimpleFlightModes", "Channel %1").arg(enumText.substring(8))
        }

        const fromSimpleModes = qsTranslate("PX4SimpleFlightModes", enumText)
        if (fromSimpleModes !== enumText) {
            return fromSimpleModes
        }

        const fromFirmwarePlugin = qsTranslate("PX4FirmwarePlugin", enumText)
        if (fromFirmwarePlugin !== enumText) {
            return fromFirmwarePlugin
        }

        const fromMetaData = qsTranslate("PX4ParameterMetaData", enumText)
        if (fromMetaData !== enumText) {
            return fromMetaData
        }

        return enumText
    }

    property Fact _nullFact
    property Fact _rcMapFltmode:    controller.parameterExists(-1, "RC_MAP_FLTMODE") ? controller.getParameterFact(-1, "RC_MAP_FLTMODE") : _nullFact

	Column {
		anchors.fill:       parent
		VehicleSummaryRow {
			labelText: qsTr("Mode switch")
			valueText: _rcMapFltmode.value === 0 ? qsTr("Setup required") : _localizedFlightModeEnumText(_rcMapFltmode.enumStringValue)
		}
		Repeater {
			model: 6
			VehicleSummaryRow {
				labelText: qsTr("Flight Mode %1 ").arg(index + 1)
				valueText: _localizedFlightModeEnumText(controller.getParameterFact(-1, "COM_FLTMODE" + (index + 1)).enumStringValue)
			}
		}
    }
}
