#include "CustomSettings.h"

DECLARE_SETTINGGROUP(Custom, "Custom")
{
    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
    qmlRegisterUncreatableType<CustomSettings>("CustomQmlInterface", 1, 0, "CustomSettings", "Reference only");
}

DECLARE_SETTINGSFACT(CustomSettings, is3DMap)
DECLARE_SETTINGSFACT(CustomSettings, rtcmSource)

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
