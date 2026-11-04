/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "PlanManagerLifetimeTest.h"
#include "MockLink.h"
#include "Vehicle.h"
#include "MissionManager.h"
#include "GeoFenceManager.h"
#include "RallyPointManager.h"

#include <QPointer>

void PlanManagerLifetimeTest::_managersDeletedWithVehicle(void)
{
    _connectMockLink(MAV_AUTOPILOT_PX4);

    QPointer<MissionManager>    missionManager      = _vehicle->missionManager();
    QPointer<GeoFenceManager>   geoFenceManager     = _vehicle->geoFenceManager();
    QPointer<RallyPointManager> rallyPointManager   = _vehicle->rallyPointManager();

    _disconnectMockLink();

    QVERIFY(missionManager.isNull());
    QVERIFY2(geoFenceManager.isNull(), "GeoFenceManager outlived its Vehicle");
    QVERIFY2(rallyPointManager.isNull(), "RallyPointManager outlived its Vehicle");
}

void PlanManagerLifetimeTest::_vehicleDeletedWhileLoadsPending(void)
{
    _connectMockLink(MAV_AUTOPILOT_PX4);

    // The vehicle never answers MISSION_REQUEST_LIST, so every load keeps its ack timer running
    _mockLink->setMissionItemFailureMode(MockLinkMissionItemHandler::FailReadRequestListNoResponse, MAV_MISSION_ACCEPTED);
    _vehicle->missionManager()->loadFromVehicle();
    _vehicle->geoFenceManager()->loadFromVehicle();
    _vehicle->rallyPointManager()->loadFromVehicle();
    QVERIFY(_vehicle->geoFenceManager()->inProgress());
    QVERIFY(_vehicle->rallyPointManager()->inProgress());

    // Link lost while the loads are pending: the Vehicle is deleted
    _disconnectMockLink();

    // Longer than the ack timeout (3 s). A manager still alive would retry here and crash.
    QTest::qWait(4000);
}

UT_REGISTER_TEST(PlanManagerLifetimeTest)
