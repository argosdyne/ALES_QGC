/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


/// @file
/// @author Gus Grubba <gus@auterion.com>

#include "ScreenToolsController.h"
#include <QFontDatabase>
#include <QScreen>
#include <QFontMetrics>

#include "SettingsManager.h"

#if defined(Q_OS_ANDROID)
#include <QtAndroidExtras/QAndroidJniObject>
#endif

#if defined(__ios__)
#include <sys/utsname.h>
#endif

ScreenToolsController::ScreenToolsController()
{

}

bool
ScreenToolsController::hasTouch() const
{
    return QTouchDevice::devices().count() > 0 || isMobile();
}

QString
ScreenToolsController::iOSDevice() const
{
#if defined(__ios__)
    struct utsname systemInfo;
    uname(&systemInfo);
    return QString(systemInfo.machine);
#else
    return QString();
#endif
}

QString
ScreenToolsController::androidVersion() const
{
#if defined(Q_OS_ANDROID)
    return QAndroidJniObject::getStaticObjectField(
        "android/os/Build$VERSION",
        "RELEASE",
        "Ljava/lang/String;").toString();
#else
    return QString();
#endif
}

QString
ScreenToolsController::androidSecurityPatch() const
{
#if defined(Q_OS_ANDROID)
    static const int androidMarshmallowSdk = 23;
    const int sdkInt = QAndroidJniObject::getStaticField<jint>(
        "android/os/Build$VERSION",
        "SDK_INT");

    if (sdkInt >= androidMarshmallowSdk) {
        return QAndroidJniObject::getStaticObjectField(
            "android/os/Build$VERSION",
            "SECURITY_PATCH",
            "Ljava/lang/String;").toString();
    }
#endif

    return QString();
}

QString
ScreenToolsController::fixedFontFamily() const
{
    return QFontDatabase::systemFont(QFontDatabase::FixedFont).family();
}

QString
ScreenToolsController::normalFontFamily() const
{
    //-- See App.SettinsGroup.json for index
    int langID = qgcApp()->toolbox()->settingsManager()->appSettings()->qLocaleLanguage()->rawValue().toInt();
    if(langID == QLocale::Korean) {
        return QString("NanumGothic");
    } else {
        return QString("Open Sans");
    }
}

QString
ScreenToolsController::boldFontFamily() const
{
    //-- See App.SettinsGroup.json for index
    int langID = qgcApp()->toolbox()->settingsManager()->appSettings()->qLocaleLanguage()->rawValue().toInt();
    if(langID == QLocale::Korean) {
        return QString("NanumGothic");
    } else {
        return QString("Open Sans Semibold");
    }
}

double ScreenToolsController::defaultFontDescent(int pointSize) const
{
    return QFontMetrics(QFont(normalFontFamily(), pointSize)).descent();
}
