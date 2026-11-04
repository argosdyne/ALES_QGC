#include "CustomResourcesTest.h"

#include <QFile>

void CustomResourcesTest::_resourcesPresent(void)
{
    const QStringList paths = {
        ":/json/Vehicle/GimbalFact.json",           // GimbalController (MAVLink gimbal facts)
        ":/toolbar/M2LinkIndicator.qml",            // CustomMainToolBar.qml with an M2 link
        ":/res/yes.svg",                            // M2LinkIndicator.qml
        ":/res/no.svg",                             // M2LinkIndicator.qml
        ":/MockLink/Arduplane.params.ftp.bin",      // MockLinkFTP parameter download
        ":/qml/geoFenceSettings.qml",               // custom-only entry that updateqrc.py would drop
    };
    for (const QString& path : paths) {
        QVERIFY2(QFile::exists(path), qPrintable(path));
    }
}

UT_REGISTER_TEST(CustomResourcesTest)
