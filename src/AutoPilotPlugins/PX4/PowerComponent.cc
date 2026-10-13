/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


/// @file
///     @author Gus Grubba <gus@auterion.com>

#include "PowerComponent.h"
#include "PX4AutoPilotPlugin.h"
#include "ParameterManager.h"

namespace {

QString _batteryParamName(ParameterManager* parameterManager, const QString& paramSuffix)
{
    const QString indexedName = QStringLiteral("BAT1_%1").arg(paramSuffix);
    if (parameterManager->parameterExists(FactSystem::defaultComponentId, indexedName)) {
        return indexedName;
    }

    return QStringLiteral("BAT_%1").arg(paramSuffix);
}

bool _batteryParamExists(ParameterManager* parameterManager, const QString& paramSuffix)
{
    return parameterManager->parameterExists(FactSystem::defaultComponentId, _batteryParamName(parameterManager, paramSuffix));
}

Fact* _batteryParamFact(ParameterManager* parameterManager, const QString& paramSuffix)
{
    return parameterManager->getParameter(FactSystem::defaultComponentId, _batteryParamName(parameterManager, paramSuffix));
}

}

PowerComponent::PowerComponent(Vehicle* vehicle, AutoPilotPlugin* autopilot, QObject* parent) :
    VehicleComponent(vehicle, autopilot, parent),
    _name(tr("Power"))
{
}

QString PowerComponent::name(void) const
{
    return _name;
}

QString PowerComponent::description(void) const
{
    return tr("Power Setup is used to setup battery parameters as well as advanced settings for propellers.");
}

QString PowerComponent::iconResource(void) const
{
    return "/qmlimages/PowerComponentIcon.png";
}

bool PowerComponent::requiresSetup(void) const
{
    return true;
}

bool PowerComponent::setupComplete(void) const
{
    ParameterManager* parameterManager = _vehicle->parameterManager();
    if (!_batteryParamExists(parameterManager, QStringLiteral("SOURCE")) ||
        !_batteryParamExists(parameterManager, QStringLiteral("V_CHARGED")) ||
        !_batteryParamExists(parameterManager, QStringLiteral("V_EMPTY")) ||
        !_batteryParamExists(parameterManager, QStringLiteral("N_CELLS"))) {
        return true;
    }
    return _batteryParamFact(parameterManager, QStringLiteral("SOURCE"))->rawValue().toInt() == -1 ||
        (_batteryParamFact(parameterManager, QStringLiteral("V_CHARGED"))->rawValue().toFloat() != 0.0f &&
        _batteryParamFact(parameterManager, QStringLiteral("V_EMPTY"))->rawValue().toFloat() != 0.0f &&
        _batteryParamFact(parameterManager, QStringLiteral("N_CELLS"))->rawValue().toInt() != 0);
}

QStringList PowerComponent::setupCompleteChangedTriggerList(void) const
{
    return {
        "BAT1_SOURCE", "BAT1_V_CHARGED", "BAT1_V_EMPTY", "BAT1_N_CELLS",
        "BAT_SOURCE", "BAT_V_CHARGED", "BAT_V_EMPTY", "BAT_N_CELLS"
    };
}

QUrl PowerComponent::setupSource(void) const
{
    return QUrl::fromUserInput("qrc:/qml/PowerComponent.qml");
}

QUrl PowerComponent::summaryQmlSource(void) const
{
    return QUrl::fromUserInput("qrc:/qml/PowerComponentSummary.qml");
}
