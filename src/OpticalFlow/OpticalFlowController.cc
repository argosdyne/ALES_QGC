/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "OpticalFlowController.h"
#include "Vehicle.h"
#include "QGCApplication.h"
#include "MAVLinkProtocol.h"
#include "QGCMAVLink.h"

QGC_LOGGING_CATEGORY(OpticalFlowLog, "OpticalFlowLog")

// Vendor-specific MAVLink command IDs (not registered in the MAVLink XML).
// Free range verified against ardupilotmega.xml / common.xml and project sources.
static constexpr uint16_t CMD_OPTICAL_FLOW_GPS        = 42685;
static constexpr uint16_t CMD_OPTICAL_FLOW_OPTICAL    = 42686;
static constexpr uint16_t CMD_OPTICAL_FLOW_AUTO       = 42687;
static constexpr uint16_t CMD_OPTICAL_FLOW_CALIB      = 42688;
static constexpr uint16_t CMD_OPTICAL_FLOW_CALIB_STOP = 42689;

OpticalFlowController::OpticalFlowController(Vehicle* vehicle)
    : _vehicle(vehicle)
{
    qCInfo(OpticalFlowLog) << "OpticalFlowController is ready";
}

OpticalFlowController::~OpticalFlowController()
{
}

void OpticalFlowController::setModeGPS()
{
    qCInfo(OpticalFlowLog) << "OpticalFlow: GPS mode requested";
    sendCommand(CMD_OPTICAL_FLOW_GPS);
}

void OpticalFlowController::setModeOptical()
{
    qCInfo(OpticalFlowLog) << "OpticalFlow: Optical mode requested";
    sendCommand(CMD_OPTICAL_FLOW_OPTICAL);
}

void OpticalFlowController::setModeAuto()
{
    qCInfo(OpticalFlowLog) << "OpticalFlow: Auto mode requested";
    sendCommand(CMD_OPTICAL_FLOW_AUTO);
}

void OpticalFlowController::calibrate()
{
    qCInfo(OpticalFlowLog) << "OpticalFlow: Calibration start requested";
    sendCommand(CMD_OPTICAL_FLOW_CALIB);
}

void OpticalFlowController::calibrateStop()
{
    qCInfo(OpticalFlowLog) << "OpticalFlow: Calibration stop requested";
    sendCommand(CMD_OPTICAL_FLOW_CALIB_STOP);
}

void OpticalFlowController::sendCommand(uint16_t commandId)
{
    if (!_vehicle) {
        qCWarning(OpticalFlowLog) << "OpticalFlowController: vehicle is null";
        return;
    }

    SharedLinkInterfacePtr sharedLink = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (!sharedLink) {
        qCWarning(OpticalFlowLog) << "OpticalFlowController: no primary link";
        return;
    }

    mavlink_message_t      msg;
    mavlink_command_long_t cmd;
    memset(&cmd, 0, sizeof(cmd));

    cmd.target_system    = _vehicle->id();
    cmd.target_component = MAV_COMP_ID_AUTOPILOT1;
    cmd.command          = commandId;
    cmd.confirmation     = 0;
    cmd.param1           = 1; // execute flag (1 = action)

    mavlink_msg_command_long_encode(
        qgcApp()->toolbox()->mavlinkProtocol()->getSystemId(),
        qgcApp()->toolbox()->mavlinkProtocol()->getComponentId(),
        &msg,
        &cmd
        );

    _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), msg);

    qInfo() << "TX OpticalFlow command id:" << commandId;
}
