#pragma once

#include "SettingsGroup.h"

class CustomSettings : public SettingsGroup
{
    Q_OBJECT

public:
    CustomSettings(QObject* parent = nullptr);
    DEFINE_SETTING_NAME_GROUP()
    DEFINE_SETTINGFACT(is3DMap)
    DEFINE_SETTINGFACT(rtcmSource)
    DEFINE_SETTINGFACT(teamMode)
};
