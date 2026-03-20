#include "CustomSettings.h"

DECLARE_SETTINGGROUP(Custom, "Custom")
{
    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
    qmlRegisterUncreatableType<CustomSettings>("CustomQmlInterface", 1, 0, "CustomSettings", "Reference only");
}

DECLARE_SETTINGSFACT(CustomSettings, is3DMap)
DECLARE_SETTINGSFACT(CustomSettings, rtcmSource)
DECLARE_SETTINGSFACT(CustomSettings, privacyVideoRecordingEnabled)
DECLARE_SETTINGSFACT(CustomSettings, networkUdpListenerEnabled)
DECLARE_SETTINGSFACT(CustomSettings, networkTcpServerEnabled)
DECLARE_SETTINGSFACT(CustomSettings, networkVideoStreamingEnabled)
DECLARE_SETTINGSFACT(CustomSettings, networkUdpBindAddress)
DECLARE_SETTINGSFACT(CustomSettings, networkUdpPort)
DECLARE_SETTINGSFACT(CustomSettings, networkTcpBindAddress)
DECLARE_SETTINGSFACT(CustomSettings, networkTcpPort)
DECLARE_SETTINGSFACT(CustomSettings, networkVideoUrl)
DECLARE_SETTINGSFACT(CustomSettings, securityStrictMavlinkValidation)
DECLARE_SETTINGSFACT(CustomSettings, securityAllowlistVehicleIds)
DECLARE_SETTINGSFACT(CustomSettings, securityWizardCompleted)
DECLARE_SETTINGSFACT(CustomSettings, securityRememberChoice)

DECLARE_SETTINGSFACT_NO_FUNC(CustomSettings, teamMode)
{
    if (!_teamModeFact) {
        _teamModeFact = _createSettingsFact(teamModeName);
    #if defined (ENABLE_WIFI_P2P)
        FactMetaData* metaData = _nameToMetaDataMap[teamModeName];
        metaData->addEnumInfo(QString("Wifi P2P"), QVariant(2));
        if(_teamModeFact->rawValue().toInt() == 1) {
            FactMetaData* metaData = _nameToMetaDataMap[teamModeName];
            metaData->addEnumInfo(QString("Wifi LAN"), QVariant(1));
        } else {
            QGCCorePlugin* plugin = qgcApp()->toolbox()->corePlugin();
            if(plugin) {
                if(plugin->showAdvancedUI()) {
                    FactMetaData* metaData = _nameToMetaDataMap[teamModeName];
                    metaData->addEnumInfo(QString("Wifi LAN"), QVariant(1));
                } else {
                    connect(plugin, &QGCCorePlugin::showAdvancedUIChanged, this, [this](bool advance) {
                        FactMetaData* metaData = _nameToMetaDataMap[teamModeName];
                        if(advance && !metaData->enumValues().contains(QVariant(1))) {
                            metaData->addEnumInfo(QString("Wifi LAN"), QVariant(1));
                        }
                    });
                }
            }
        }
    #else
        FactMetaData* metaData = _nameToMetaDataMap[teamModeName];
        metaData->addEnumInfo(QString("Wifi LAN"), QVariant(1));
    #endif
    }
    return _teamModeFact;
}
