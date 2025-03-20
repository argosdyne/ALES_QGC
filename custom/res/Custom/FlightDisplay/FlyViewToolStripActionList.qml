import QtQml.Models 2.12

import QGroundControl           1.0
import QGroundControl.Controls  1.0
import QGroundControl.FlightDisplay 1.0

ToolStripActionList {
    id: _root

    signal displayPreFlightChecklist

    model: [
        ToolStripAction {
            text:           qsTr("Plan")
            iconSource:     "/qmlimages/Plan.svg"
            onTriggered:    mainWindow.showPlanView()
        },
        PreFlightCheckListShowAction { onTriggered: displayPreFlightChecklist() },
        GuidedToolStripAction {
            text:       _guidedController.armTitle
            message:    _guidedController.armMessage
            iconSource: "/custom/img/armed.svg"
            visible:    _guidedController.showArm
            enabled:    _guidedController.showArm
            actionID:   _guidedController.actionArm
        },
        GuidedToolStripAction {
            text:       _guidedController.disarmTitle
            message:    _guidedController.disarmMessage
            iconSource: "/custom/img/disarmed.svg"
            visible:    _guidedController.showDisarm
            enabled:    _guidedController.showDisarm
            actionID:   _guidedController.actionDisarm
        },
        GuidedToolStripAction {
            text:       _guidedController.emergencyStopTitle
            message:    _guidedController.emergencyStopMessage
            iconSource: "/custom/img/disarmed.svg"
            visible:    _guidedController.showEmergenyStop
            enabled:    _guidedController.showEmergenyStop
            actionID:   _guidedController.actionEmergencyStop
        },
        GuidedActionTakeoff { },
        GuidedActionLand { },
        GuidedActionRTL { },
        GuidedActionPause { },
        GuidedActionActionList { }
    ]
}
