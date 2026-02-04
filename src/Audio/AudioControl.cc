/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "AudioControl.h"
#include "QGCApplication.h"

#include "MAVLinkProtocol.h"
#include "QGCMAVLink.h"

AudioControl::AudioControl(Vehicle *vehicle)
    : _vehicle(vehicle)
{
    qInfo() << "AudioControl is ready";
}

AudioControl::~AudioControl()
{
}

void AudioControl::_playAudio(int index)
{
    qInfo() << "Call Play Audio : index = " << index;

    if (!_vehicle) {
        qWarning() << "AudioControl: vehicle is null";
        return;
    }

    sendCommand(1, index);

}
//Not Used
void AudioControl::_loopAudio(int index)
{
    qInfo() << "Call Loop Audio : index = " << index;

    if (!_vehicle) {
        qWarning() << "AudioControl: vehicle is null";
        return;
    }

    sendCommand(1, index);
}

void AudioControl::_stopAudio()
{
    qInfo() << "Call Stop Audio";

    if (!_vehicle) {
        qWarning() << "AudioControl: vehicle is null";
        return;
    }

    sendCommand(-1);
}

void AudioControl::sendCommand(int playMode, int audioIndex)
{
    if (!_vehicle) {
        qWarning() << "AudioControl: vehicle is null";
        return;
    }

    qInfo() << "Sending MAV_CMD_PLAY_AUDIO"
            << "index:" << audioIndex
            << "mode:" << playMode;
    /// PlayMode
    /// 1 = Play
    /// -1 = Stop


    SharedLinkInterfacePtr sharedLink = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (!sharedLink) {
        return;
    }

    mavlink_message_t msg;
    mavlink_command_long_t cmd;
    memset(&cmd, 0, sizeof(cmd));

    cmd.target_system    = _vehicle->id();
    cmd.target_component = MAV_COMP_ID_AUTOPILOT1;
    cmd.command          = MAV_CMD_PLAY_AUDIO;
    cmd.confirmation     = 0;

    cmd.param1 = audioIndex;
    cmd.param2 = static_cast<int>(playMode); // 1 / -1

    mavlink_msg_command_long_encode(
        qgcApp()->toolbox()->mavlinkProtocol()->getSystemId(),     // QGC system id
        qgcApp()->toolbox()->mavlinkProtocol()->getComponentId(),  // QGC component id
        &msg,
        &cmd
        );

    _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), msg);

    qInfo() << "TX MAV_CMD_PLAY_AUDIO"
            << "index:" << audioIndex
            << "mode:" << static_cast<int>(playMode);


}


