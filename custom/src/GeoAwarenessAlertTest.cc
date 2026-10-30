#include "GeoAwarenessAlertTest.h"
#include "QGCApplication.h"
#include "SettingsManager.h"

#include <QElapsedTimer>
#include <QRandomGenerator>
#include <QSettings>
#include <QtMath>

#include <algorithm>
#include <limits>

CustomQmlInterface* GeoAwarenessAlertTest::_interface = nullptr;

namespace {

const char* kLanguageKey = "qLocaleLanguage";
constexpr int kAnimationSettleMs = 400;     // y animations run for 200 ms
constexpr int kSpeechDelayMs     = 1500;    // speech is scheduled 1200 ms after the alert sound

// AudioOutput has no speech engine in unit tests, so say() only logs "say <text>"
QStringList*     gSpoken         = nullptr;
QtMessageHandler gPreviousHandler = nullptr;

void captureSay(QtMsgType type, const QMessageLogContext& context, const QString& message)
{
    if (gSpoken && type == QtDebugMsg && message.startsWith(QStringLiteral("say "))) {
        gSpoken->append(message);
    }
    if (gPreviousHandler) {
        gPreviousHandler(type, context, message);
    }
}

const GeoAwarenessErrorId kTypes[] = { GeoAwarenessErrorId::Inside, GeoAwarenessErrorId::Near, GeoAwarenessErrorId::NoData };

} // namespace

void GeoAwarenessAlertTest::init(void)
{
    UnitTest::init();
    _savedLanguage = QSettings().value(kLanguageKey);

    if (!_interface) {
        // Created once and leaked, like the production instance
        _interface = new CustomQmlInterface(qgcApp(), qgcApp()->toolbox());
    }
    _interface->setProperty("defaultFontPixelHeight", 16.0f);
    _interface->setProperty("defaultFontPixelWidth", 8.0f);
    // No alert sound during tests; say() still logs the text
    qgcApp()->toolbox()->settingsManager()->appSettings()->audioMuted()->setRawValue(true);
    _closeAll();
}

void GeoAwarenessAlertTest::cleanup(void)
{
    _closeAll();
    QSettings settings;
    if (_savedLanguage.isValid()) {
        settings.setValue(kLanguageKey, _savedLanguage);
    } else {
        settings.remove(kLanguageKey);
    }
    qgcApp()->setLanguage();
    UnitTest::cleanup();
}

void GeoAwarenessAlertTest::_setLanguage(QLocale::Language language)
{
    QSettings().setValue(kLanguageKey, static_cast<int>(language));
    qgcApp()->setLanguage();
}

QList<SystemMessage*> GeoAwarenessAlertTest::_messages(void)
{
    QList<SystemMessage*> messages;
    QmlObjectListModel* model = _interface->geoAwarenessMessages();
    for (int i = 0; i < model->count(); i++) {
        messages.append(model->value<SystemMessage*>(i));
    }
    return messages;
}

void GeoAwarenessAlertTest::_settle(void)
{
    QTest::qWait(kAnimationSettleMs);
}

void GeoAwarenessAlertTest::_closeAll(void)
{
    for (SystemMessage* message : _messages()) {
        message->geoAwarenessCloseItstyle();
    }
    // Run the deleteLater calls and any pending speech timers
    QTest::qWait(kSpeechDelayMs);
    QCOMPARE(_interface->geoAwarenessMessages()->count(), 0);
}

void GeoAwarenessAlertTest::_verifyNoOverlap(const QString& context)
{
    QList<SystemMessage*> messages = _messages();
    std::sort(messages.begin(), messages.end(), [](SystemMessage* a, SystemMessage* b) { return a->geoAwarenessY() < b->geoAwarenessY(); });
    for (int i = 0; i < messages.count(); i++) {
        const SystemMessage* m = messages[i];
        QVERIFY2(qIsFinite(m->geoAwarenessY()) && m->geoAwarenessY() >= 0, qPrintable(context + ": bad y"));
        if (i > 0) {
            const SystemMessage* above = messages[i - 1];
            const float bottom = above->geoAwarenessY() + above->geoAwarenessStackHeight();
            QVERIFY2(m->geoAwarenessY() + 0.5f >= bottom,
                     qPrintable(QStringLiteral("%1: alert at y %2 overlaps alert above (y %3, height %4)")
                                .arg(context).arg(m->geoAwarenessY()).arg(above->geoAwarenessY()).arg(above->geoAwarenessStackHeight())));
        }
    }
}

QStringList GeoAwarenessAlertTest::_spokenWithin(int msecs)
{
    QStringList spoken;
    gSpoken = &spoken;
    gPreviousHandler = qInstallMessageHandler(captureSay);
    QTest::qWait(msecs);
    qInstallMessageHandler(gPreviousHandler);
    gSpoken = nullptr;
    return spoken;
}

void GeoAwarenessAlertTest::_basicStackUsesDrawnHeight(void)
{
    _interface->geoAwarenessMessage(GeoAwarenessErrorId::Inside, QStringLiteral("Inside GeoZone. ") + QString(120, QChar('x')));
    _interface->geoAwarenessMessage(GeoAwarenessErrorId::Near, QStringLiteral("Approaching GeoZone."));
    _settle();

    QList<SystemMessage*> messages = _messages();
    QCOMPARE(messages.count(), 2);

    // QML reports a wrapped alert far taller than the character-count estimate
    SystemMessage* top    = messages[1];    // newest is drawn on top
    SystemMessage* bottom = messages[0];
    const float drawn = top->geoAwarenessHeight() * 4;
    top->setGeoAwarenessDisplayHeight(drawn);
    bottom->setGeoAwarenessDisplayHeight(bottom->geoAwarenessHeight());
    _settle();

    QCOMPARE(top->geoAwarenessStackHeight(), drawn);
    QVERIFY(bottom->geoAwarenessY() >= top->geoAwarenessY() + drawn);
    _verifyNoOverlap(QStringLiteral("basic"));

    // Shrinking back never goes below the estimate
    top->setGeoAwarenessDisplayHeight(1);
    _settle();
    QCOMPARE(top->geoAwarenessStackHeight(), top->geoAwarenessHeight());
    _verifyNoOverlap(QStringLiteral("basic shrink"));
}

void GeoAwarenessAlertTest::_basicSpeechOnlyInEnglish(void)
{
    _setLanguage(QLocale::English);
    _interface->geoAwarenessMessage(GeoAwarenessErrorId::Inside, QStringLiteral("Inside GeoZone"));
    QStringList spoken = _spokenWithin(kSpeechDelayMs);
    QCOMPARE(spoken.count(), 1);
    QVERIFY(spoken[0].contains(QStringLiteral("Warning. Inside GeoZone.")));
    _closeAll();

    for (QLocale::Language language : { QLocale::Korean, QLocale::Japanese, QLocale::Vietnamese, QLocale::Danish, QLocale::Portuguese, QLocale::Chinese }) {
        _setLanguage(language);
        for (GeoAwarenessErrorId type : kTypes) {
            _interface->geoAwarenessMessage(type, QStringLiteral("alert"));
        }
        // The alert is still shown even though nothing is spoken
        QCOMPARE(_interface->geoAwarenessMessages()->count(), 3);
        spoken = _spokenWithin(kSpeechDelayMs);
        QVERIFY2(spoken.isEmpty(), qPrintable(QLocale::languageToString(language) + ": " + spoken.join(", ")));
        _closeAll();
    }
}

void GeoAwarenessAlertTest::_abnormalHeights(void)
{
    for (GeoAwarenessErrorId type : kTypes) {
        _interface->geoAwarenessMessage(type, QStringLiteral("alert"));
    }
    _settle();

    const float values[] = { 0.0f, -100.0f, std::numeric_limits<float>::quiet_NaN(), 0.1f, 1.0e6f };
    for (float value : values) {
        for (SystemMessage* message : _messages()) {
            message->setGeoAwarenessDisplayHeight(value);
            QVERIFY(message->geoAwarenessStackHeight() >= message->geoAwarenessHeight());
        }
        _settle();
        _verifyNoOverlap(QStringLiteral("height %1").arg(value));
    }
}

void GeoAwarenessAlertTest::_abnormalSetterAfterClose(void)
{
    _interface->geoAwarenessMessage(GeoAwarenessErrorId::Inside, QStringLiteral("inside"));
    _interface->geoAwarenessMessage(GeoAwarenessErrorId::Near, QStringLiteral("near"));
    _settle();

    // QML can still report a height after the message left the model but before deleteLater runs
    SystemMessage* closed = _messages()[0];
    closed->geoAwarenessCloseItstyle();
    closed->setGeoAwarenessDisplayHeight(500);
    QCOMPARE(_interface->geoAwarenessMessages()->count(), 1);
    _settle();
    _verifyNoOverlap(QStringLiteral("after close"));
    QCOMPARE(_messages()[0]->geoAwarenessY(), 8.0f);    // half a font height from the top
}

void GeoAwarenessAlertTest::_abnormalMessages(void)
{
    // The same type is shown only once until it closes
    _interface->geoAwarenessMessage(GeoAwarenessErrorId::Inside, QStringLiteral("first"));
    _interface->geoAwarenessMessage(GeoAwarenessErrorId::Inside, QStringLiteral("second"));
    QCOMPARE(_interface->geoAwarenessMessages()->count(), 1);

    // Unknown types are ignored
    _interface->geoAwarenessMessage(GeoAwarenessErrorId::Unknown, QStringLiteral("unknown"));
    _interface->geoAwarenessMessage(static_cast<GeoAwarenessErrorId>(42), QStringLiteral("bad"));
    QCOMPARE(_interface->geoAwarenessMessages()->count(), 1);

    // Empty and very long texts
    _interface->geoAwarenessMessage(GeoAwarenessErrorId::Near, QString());
    _interface->geoAwarenessMessage(GeoAwarenessErrorId::NoData, QString(20000, QChar('w')));
    QCOMPARE(_interface->geoAwarenessMessages()->count(), 3);
    _settle();
    _verifyNoOverlap(QStringLiteral("empty/long"));

    // A closed type can be shown again
    _closeAll();
    _interface->geoAwarenessMessage(GeoAwarenessErrorId::Inside, QStringLiteral("again"));
    QCOMPARE(_interface->geoAwarenessMessages()->count(), 1);
}

void GeoAwarenessAlertTest::_stressHeightUpdates(void)
{
    for (GeoAwarenessErrorId type : kTypes) {
        _interface->geoAwarenessMessage(type, QString(200, QChar('s')));
    }

    QRandomGenerator rng(1234);
    QElapsedTimer timer;
    timer.start();
    constexpr int kUpdates = 5000;
    for (int i = 0; i < kUpdates; i++) {
        const QList<SystemMessage*> messages = _messages();
        messages[rng.bounded(messages.count())]->setGeoAwarenessDisplayHeight(rng.bounded(1, 600));
        if (i % 50 == 0) {
            QCoreApplication::processEvents();  // let some animations run mid-way
        }
    }
    qDebug() << "Stress:" << kUpdates << "height updates in" << timer.elapsed() << "ms";
    _settle();
    _verifyNoOverlap(QStringLiteral("stress"));
}

void GeoAwarenessAlertTest::_randomShowResizeClose(void)
{
    const quint32 seed = QRandomGenerator::global()->generate();
    qDebug() << "Random seed:" << seed;
    QRandomGenerator rng(seed);

    constexpr int kSteps = 150;
    for (int step = 0; step < kSteps; step++) {
        switch (rng.bounded(4)) {
        case 0:
        case 1: {
            const GeoAwarenessErrorId type = kTypes[rng.bounded(3)];
            _interface->geoAwarenessMessage(type, QString(rng.bounded(0, 400), QChar('r')));
            break;
        }
        case 2: {
            const QList<SystemMessage*> messages = _messages();
            if (!messages.isEmpty()) {
                messages[rng.bounded(messages.count())]->setGeoAwarenessDisplayHeight(rng.bounded(0, 500));
            }
            break;
        }
        case 3: {
            const QList<SystemMessage*> messages = _messages();
            if (!messages.isEmpty()) {
                messages[rng.bounded(messages.count())]->geoAwarenessCloseItstyle();
            }
            break;
        }
        }
        if (rng.bounded(3) == 0) {
            _settle();
            _verifyNoOverlap(QStringLiteral("seed %1 step %2").arg(seed).arg(step));
        }
    }
    _settle();
    _verifyNoOverlap(QStringLiteral("seed %1 end").arg(seed));
}

UT_REGISTER_TEST(GeoAwarenessAlertTest)
