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

    sendCommand(0, index);

}

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
    /// 0 = Once
    /// 1 = Loop
    /// -1 = Stop

    _vehicle->sendMavCommand(
        _vehicle->defaultComponentId(),     // MAV_COMP_ID_AUTOPILOT1
        MAV_CMD_PLAY_AUDIO,                 // 6000
        true,                               // showError
        audioIndex,                         // param1: Audio Index
        playMode,                           // param2: Play Mode
        0,                                  // param3
        0,                                  // param4
        0,                                  // param5
        0,                                  // param6
        0                                   // param7
        );
}


