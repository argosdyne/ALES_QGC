/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "GeoZoneMakeViewSettings.h"

#include <QQmlEngine>
#include <QtQml>

DECLARE_SETTINGGROUP(GeoZoneMakeView, "PlanView")
{
    qmlRegisterUncreatableType<GeoZoneMakeViewSettings>("QGroundControl.SettingsManager", 1, 0, "GeoZoneMakeViewSettings", "Reference only"); \
}


