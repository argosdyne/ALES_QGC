/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QObject>
#include <QTimer>
#include <QThread>
#include <QStringList>
#include <QTextToSpeech>


#include "QGCApplication.h"


class AudioControl : public QObject
{
    Q_OBJECT
public:    

    AudioControl(Vehicle* vehicle);
    virtual ~AudioControl();

    Q_INVOKABLE void _playAudio(int index);
    Q_INVOKABLE void _stopAudio();
    Q_INVOKABLE void _loopAudio(int index);

    void sendCommand(int playMode, int audioIndex = 0);


public slots:


private slots:


protected:


    Vehicle*            _vehicle            = nullptr;
};

