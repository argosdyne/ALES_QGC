/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include "SettingsGroup.h"

class GeoZoneMakeViewSettings : public SettingsGroup
{
    Q_OBJECT
public:
    GeoZoneMakeViewSettings(QObject* parent = nullptr);
    DEFINE_SETTING_NAME_GROUP()

    // Most individual settings related to PlanView are still in AppSettings due to historical reasons.

};
