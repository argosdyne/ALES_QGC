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
    DEFINE_SETTINGFACT(doodleLabsIP)
    DEFINE_SETTINGFACT(doodleLabsIPEnable)
    DEFINE_SETTINGFACT(lifeJacketEnable)

    // YellowScan LiDAR (LiDAR Setup > Connection)
    DEFINE_SETTINGFACT(ysEnable)
    DEFINE_SETTINGFACT(ysOpenPanelOnConnect)
    DEFINE_SETTINGFACT(ysModel)
    DEFINE_SETTINGFACT(ysLink)
    DEFINE_SETTINGFACT(ysMavCompId)
    DEFINE_SETTINGFACT(ysCamera)
    DEFINE_SETTINGFACT(ysMissionStartStop)

    // Simple UI (AQGC Simple)
    DEFINE_SETTINGFACT(simpleAdminPin)
    DEFINE_SETTINGFACT(simpleWelcomeShown)
    DEFINE_SETTINGFACT(simpleLargeText)
    DEFINE_SETTINGFACT(simpleStartScreen)
    DEFINE_SETTINGFACT(simpleProductProfile)
};
