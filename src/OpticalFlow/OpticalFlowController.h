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

#include "QGCApplication.h"
#include "QGCLoggingCategory.h"

Q_DECLARE_LOGGING_CATEGORY(OpticalFlowLog)

class Vehicle;

class OpticalFlowController : public QObject
{
    Q_OBJECT
public:
    OpticalFlowController(Vehicle* vehicle);
    virtual ~OpticalFlowController();

    Q_INVOKABLE void setModeGPS();
    Q_INVOKABLE void setModeOptical();
    Q_INVOKABLE void setModeAuto();
    Q_INVOKABLE void calibrate();
    Q_INVOKABLE void calibrateStop();

    void sendCommand(uint16_t commandId);

protected:
    Vehicle* _vehicle = nullptr;
};
