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
    DEFINE_SETTINGFACT(privacyVideoRecordingEnabled)
    DEFINE_SETTINGFACT(networkUdpListenerEnabled)
    DEFINE_SETTINGFACT(networkTcpServerEnabled)
    DEFINE_SETTINGFACT(networkVideoStreamingEnabled)
    DEFINE_SETTINGFACT(networkUdpBindAddress)
    DEFINE_SETTINGFACT(networkUdpPort)
    DEFINE_SETTINGFACT(networkTcpBindAddress)
    DEFINE_SETTINGFACT(networkTcpPort)
    DEFINE_SETTINGFACT(networkVideoUrl)
    DEFINE_SETTINGFACT(securityStrictMavlinkValidation)
    DEFINE_SETTINGFACT(securityAllowlistVehicleIds)
    DEFINE_SETTINGFACT(securityWizardCompleted)
};
