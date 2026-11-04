/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include "UnitTest.h"

/// The plan managers (mission, geofence, rally) must go away with their Vehicle. A manager that
/// outlives it keeps its ack timer and dereferences the deleted Vehicle when the timer fires.
class PlanManagerLifetimeTest : public UnitTest
{
    Q_OBJECT

private slots:
    void _managersDeletedWithVehicle(void);
    void _vehicleDeletedWhileLoadsPending(void);
};
