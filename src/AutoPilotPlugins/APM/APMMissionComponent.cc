/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "APMMissionComponent.h"

APMMissionComponent::APMMissionComponent(Vehicle* vehicle, AutoPilotPlugin* autopilot, QObject* parent)
    : VehicleComponent(vehicle, autopilot, parent)
    , _name(tr("Mission"))
{
}

QString APMMissionComponent::name(void) const
{
    return _name;
}

QString APMMissionComponent::description(void) const
{
    return tr("Mission options control whether the stored mission is cleared on reboot. The change takes effect after the next reboot.");
}

QString APMMissionComponent::iconResource(void) const
{
    return QStringLiteral("/res/waypoint.svg");
}

QUrl APMMissionComponent::setupSource(void) const
{
    return QUrl::fromUserInput(QStringLiteral("qrc:/qml/APMMissionComponent.qml"));
}
