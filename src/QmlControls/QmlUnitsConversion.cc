/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "QmlUnitsConversion.h"

#include "QGCApplication.h"
#include "SettingsManager.h"

#include <qmath.h>

QmlUnitsConversion::QmlUnitsConversion(QObject* parent)
    : QObject(parent)
{
    if (!qgcApp() || !qgcApp()->toolbox()) {
        return;
    }

    auto unitsSettings = qgcApp()->toolbox()->settingsManager()->unitsSettings();

    connect(unitsSettings->horizontalDistanceUnits(), &Fact::rawValueChanged, this, [this](QVariant) {
        emit appSettingsHorizontalDistanceUnitsStringChanged();
    });
    connect(unitsSettings->verticalDistanceUnits(), &Fact::rawValueChanged, this, [this](QVariant) {
        emit appSettingsVerticalDistanceUnitsStringChanged();
    });
    connect(unitsSettings->areaUnits(), &Fact::rawValueChanged, this, [this](QVariant) {
        emit appSettingsAreaUnitsStringChanged();
    });
    connect(unitsSettings->weightUnits(), &Fact::rawValueChanged, this, [this](QVariant) {
        emit appSettingsWeightUnitsStringChanged();
    });
    connect(unitsSettings->speedUnits(), &Fact::rawValueChanged, this, [this](QVariant) {
        emit appSettingsSpeedUnitsStringChanged();
    });
}

double QmlUnitsConversion::degreesToRadians(double degrees) const
{
    return qDegreesToRadians(degrees);
}

double QmlUnitsConversion::radiansToDegrees(double radians) const
{
    return qRadiansToDegrees(radians);
}
