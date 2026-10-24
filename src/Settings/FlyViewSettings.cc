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
#include <QNetworkRequest>

// The key is generated into the build directory by custom/custom.pri (never committed)
#if defined(QGC_HAS_ALTITUDE_ANGEL_KEY_HEADER)
#include "AltitudeAngelKey.h"
#else
#define QGC_ALTITUDE_ANGEL_API_KEY ""
#endif

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
DECLARE_SETTINGSFACT(FlyViewSettings, enableOpticalFlowController)


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

QString FlyViewSettings::altitudeAngelApiKey()
{
    const QString userKey = onlineLicenseKey()->rawValueString().trimmed();
    return userKey.isEmpty() ? QStringLiteral(QGC_ALTITUDE_ANGEL_API_KEY) : userKey;
}

bool FlyViewSettings::addAltitudeAngelAuthorization(QNetworkRequest& request)
{
    // Never send the key to a host other than the Altitude Angel API (onlinePath is user editable)
    const QUrl url = request.url();
    const QString host = url.host().toLower();
    const bool altitudeAngelHost = host == QStringLiteral("altitudeangel.com") || host.endsWith(QStringLiteral(".altitudeangel.com"));
    if (url.scheme() != QStringLiteral("https") || !altitudeAngelHost) {
        qWarning() << "GeoAwareness: not sending the Altitude Angel key to" << url.host();
        return false;
    }
    const QString key = altitudeAngelApiKey();
    if (key.isEmpty()) {
        qWarning() << "GeoAwareness: no Altitude Angel API key (set ALTITUDE_ANGEL_API_KEY at build time)";
        return false;
    }
    request.setRawHeader("Authorization", QStringLiteral("X-AA-ApiKey %1").arg(key).toUtf8());
    return true;
}

