/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "FlyViewSettings.h"

#include <QQmlEngine>
#include <QtQml>

DECLARE_SETTINGGROUP(FlyView, "FlyView")
{
    qmlRegisterUncreatableType<FlyViewSettings>("QGroundControl.SettingsManager", 1, 0, "FlyViewSettings", "Reference only"); \
}

DECLARE_SETTINGSFACT(FlyViewSettings, guidedMinimumAltitude)
DECLARE_SETTINGSFACT(FlyViewSettings, guidedMaximumAltitude)
DECLARE_SETTINGSFACT(FlyViewSettings, showLogReplayStatusBar)
DECLARE_SETTINGSFACT(FlyViewSettings, alternateInstrumentPanel)
DECLARE_SETTINGSFACT(FlyViewSettings, showAdditionalIndicatorsCompass)
DECLARE_SETTINGSFACT(FlyViewSettings, lockNoseUpCompass)
DECLARE_SETTINGSFACT(FlyViewSettings, maxGoToLocationDistance)
DECLARE_SETTINGSFACT(FlyViewSettings, keepMapCenteredOnVehicle)
DECLARE_SETTINGSFACT(FlyViewSettings, showSimpleCameraControl)
DECLARE_SETTINGSFACT(FlyViewSettings, showObstacleDistanceOverlay)
DECLARE_SETTINGSFACT(FlyViewSettings, updateHomePosition)
DECLARE_SETTINGSFACT(FlyViewSettings, enableCustomActions)
DECLARE_SETTINGSFACT(FlyViewSettings, customActionDefinitions)
DECLARE_SETTINGSFACT(FlyViewSettings, alarmDistance)
DECLARE_SETTINGSFACT(FlyViewSettings, dataType)
DECLARE_SETTINGSFACT(FlyViewSettings, filePath)
DECLARE_SETTINGSFACT(FlyViewSettings, onlinePath)
DECLARE_SETTINGSFACT(FlyViewSettings, onlineLicenseKey)
DECLARE_SETTINGSFACT(FlyViewSettings, enableAudioController)


QString FlyViewSettings::readTextFile(const QString& path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return "";
    QTextStream in(&file);
    return in.readAll();
}

void FlyViewSettings::setFilePathRawValue(QString filepath){
    filePath()->setRawValue(filepath);
}

void FlyViewSettings:: setOnlinePathRawValue(QString onlinepath){
    onlinePath()->setRawValue(onlinepath);
}

void FlyViewSettings:: setOnlineLicenseKeyRawValue(QString lisencekey){
    onlineLicenseKey()->setRawValue(lisencekey);
}

