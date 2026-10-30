/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "StatusTextThrottleTest.h"
#include "QGCApplication.h"
#include "UASMessageHandler.h"
#include "StatusTextTranslator.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"

#include <QElapsedTimer>
#include <QRandomGenerator>
#include <QSet>
#include <QSettings>

namespace {

const char* kLanguageKey = "qLocaleLanguage";
constexpr int kThrottleWindowMs = 3000;

struct PoolText {
    const char* text;
    const char* key;    // throttle group, nullptr when the text is never throttled
};

// Keyed texts all have a Korean translation in qgc_source_ko_KR.ts
const PoolText kPool[] = {
    { "PreArm: Radio failsafe on",          "radio" },
    { "Radio Failsafe",                     "radio" },
    { "Radio Failsafe - Disarming",         "radio" },
    { "Radio Failsafe Cleared",             "radio" },
    { "Radio failsafe on",                  "radio" },
    { "C2 link quality degraded",           "c2-degraded" },
    { "Battery 1 low",                      nullptr },
    { "EKF variance",                       nullptr },
    { "Compass 2 not calibrated",           nullptr },
    { "PreArm: Compass 2 not calibrated",   nullptr },
    { "GPS 1: detected",                    nullptr },
};

} // namespace

void StatusTextThrottleTest::init(void)
{
    UnitTest::init();
    _savedLanguage = QSettings().value(kLanguageKey);
    _handler = qgcApp()->toolbox()->uasMessageHandler();
    // handleTextMessage() needs an active vehicle. MockLink asserts on this fork's parameter
    // requests, so attach the offline editing vehicle instead.
    Vehicle* vehicle = qgcApp()->toolbox()->multiVehicleManager()->offlineEditingVehicle();
    QVERIFY(QMetaObject::invokeMethod(_handler, "_activeVehicleChanged", Q_ARG(Vehicle*, vehicle)));
    _handler->clearMessages();
}

void StatusTextThrottleTest::cleanup(void)
{
    QSettings settings;
    if (_savedLanguage.isValid()) {
        settings.setValue(kLanguageKey, _savedLanguage);
    } else {
        settings.remove(kLanguageKey);
    }
    qgcApp()->setLanguage();
    QMetaObject::invokeMethod(_handler, "_activeVehicleChanged", Q_ARG(Vehicle*, nullptr));
    _handler = nullptr;
    UnitTest::cleanup();
}

void StatusTextThrottleTest::_setLanguage(QLocale::Language language)
{
    QSettings().setValue(kLanguageKey, static_cast<int>(language));
    qgcApp()->setLanguage();
    _handler->clearMessages();
}

void StatusTextThrottleTest::_send(const QString& text, const QString& description)
{
    _handler->handleTextMessage(0, 1, MAV_SEVERITY_CRITICAL, text, description);
}

int StatusTextThrottleTest::_storedCount(const QString& sourceText)
{
    const QString stored = StatusTextTranslator::translate(sourceText).replace("\n", "<br/>");
    int count = 0;
    _handler->lockAccess();
    for (UASMessage* message : _handler->messages()) {
        if (message->getText() == stored) {
            count++;
        }
    }
    _handler->unlockAccess();
    return count;
}

int StatusTextThrottleTest::_storedTotal(const QStringList& sourceTexts)
{
    int total = 0;
    for (const QString& text : QSet<QString>(sourceTexts.begin(), sourceTexts.end())) {
        total += _storedCount(text);
    }
    return total;
}

void StatusTextThrottleTest::_basicDuplicateDroppedEnglish(void)
{
    _setLanguage(QLocale::English);
    const QString text("PreArm: Radio failsafe on");
    QCOMPARE(StatusTextTranslator::translate(text), text);

    _send(text);
    _send(text);
    QCOMPARE(_storedCount(text), 1);
}

void StatusTextThrottleTest::_basicDuplicateDroppedKorean(void)
{
    _setLanguage(QLocale::Korean);

    const QStringList texts = { "PreArm: Radio failsafe on", "Radio Failsafe", "C2 link quality degraded" };
    for (const QString& text : texts) {
        // The fix only matters when the text is actually translated
        QVERIFY2(StatusTextTranslator::translate(text) != text, qPrintable(text));
        // The first two texts share a throttle group, so start each one from a clean state
        _handler->clearMessages();
        _send(text);
        _send(text);
        _send(text);
        QCOMPARE(_storedCount(text), 1);
    }

    // Different texts in the same throttle group are dropped too
    _handler->clearMessages();
    _send("Radio Failsafe");
    _send("Radio Failsafe - Disarming");
    _send("PreArm: Radio failsafe on");
    QCOMPARE(_storedTotal({ "Radio Failsafe", "Radio Failsafe - Disarming", "PreArm: Radio failsafe on" }), 1);
}

void StatusTextThrottleTest::_basicWindowExpires(void)
{
    _setLanguage(QLocale::Korean);
    const QString text("Radio Failsafe");

    _send(text);
    QTest::qWait(kThrottleWindowMs + 200);
    _send(text);
    QCOMPARE(_storedCount(text), 2);
}

void StatusTextThrottleTest::_basicUnkeyedNotDropped(void)
{
    _setLanguage(QLocale::Korean);
    const QString text("Compass 2 not calibrated");

    _send(text);
    _send(text);
    _send(text);
    QCOMPARE(_storedCount(text), 3);
}

void StatusTextThrottleTest::_abnormalInputs(void)
{
    const QString hugeKeyed     = QString(50000, QChar('x')) + QStringLiteral(" radio failsafe ") + QString(50000, QChar('y'));
    const QString hugeUnkeyed   = QString(100000, QChar('z'));
    const QString withNul       = QStringLiteral("Radio Failsafe") + QChar(0) + QStringLiteral("tail");

    struct Case {
        QString text;
        QString description;
        int     sends;
        int     expectedStored;
    };
    const QList<Case> cases = {
        { QString(),                                QString(),          2, 2 },
        { QStringLiteral("   "),                    QString(),          2, 2 },
        { QStringLiteral("<b>Radio Failsafe</b>"),  QString(),          2, 1 },
        { QStringLiteral("Radio Failsafe"),         QStringLiteral("detail\nline"), 2, 1 },
        { QStringLiteral("Radio\nFailsafe"),        QString(),          2, 1 },
        { QStringLiteral("RADIO FAILSAFE"),         QString(),          2, 1 },
        { hugeKeyed,                                QString(),          2, 1 },
        { hugeUnkeyed,                              QString(),          2, 2 },
        { withNul,                                  QString(),          2, 1 },
        { QStringLiteral("PreArm: %s %d %n %%"),    QString(),          2, 2 },
        { QStringLiteral("PreArm: %1 %2"),          QString(),          2, 2 },
        { QStringLiteral("무선 페일세이프"),        QString(),          2, 2 },
    };

    for (QLocale::Language language : { QLocale::English, QLocale::Korean }) {
        _setLanguage(language);
        for (const Case& c : cases) {
            _handler->clearMessages();
            for (int i = 0; i < c.sends; i++) {
                _send(c.text, c.description);
            }
            _handler->lockAccess();
            const int stored = _handler->messages().count();
            _handler->unlockAccess();
            QVERIFY2(stored == c.expectedStored,
                     qPrintable(QStringLiteral("lang %1, text '%2': stored %3, expected %4")
                                .arg(QLocale::languageToString(language)).arg(c.text.left(40)).arg(stored).arg(c.expectedStored)));
        }
    }
}

void StatusTextThrottleTest::_stressFailsafeFlood(void)
{
    _setLanguage(QLocale::Korean);

    const QStringList radio = { "PreArm: Radio failsafe on", "Radio Failsafe", "Radio Failsafe - Disarming" };
    const QString c2("C2 link quality degraded");
    constexpr int kSends = 3000;

    QElapsedTimer timer;
    timer.start();
    for (int i = 0; i < kSends; i++) {
        _send(radio[i % radio.count()]);
        _send(c2);
    }
    const qint64 elapsed = timer.elapsed();
    const int maxPerGroup = static_cast<int>(elapsed / kThrottleWindowMs) + 1;

    const int radioStored = _storedTotal(radio);
    const int c2Stored    = _storedCount(c2);
    qDebug() << "Stress:" << kSends * 2 << "failsafe texts in" << elapsed << "ms, stored radio" << radioStored << "c2" << c2Stored;
    QVERIFY(radioStored >= 1 && radioStored <= maxPerGroup);
    QVERIFY(c2Stored >= 1 && c2Stored <= maxPerGroup);

    // A flood of distinct texts must stay within the stored-message limit
    _handler->clearMessages();
    for (int i = 0; i < 2000; i++) {
        _send(QStringLiteral("Unique status %1").arg(i));
    }
    _handler->lockAccess();
    const int stored = _handler->messages().count();
    _handler->unlockAccess();
    QVERIFY(stored <= 200);
}

void StatusTextThrottleTest::_randomSameDecisionsInEveryLanguage(void)
{
    const quint32 seed = QRandomGenerator::global()->generate();
    qDebug() << "Random seed:" << seed;
    QRandomGenerator rng(seed);

    constexpr int kRounds   = 20;
    constexpr int kSends    = 60;
    const int poolCount     = sizeof(kPool) / sizeof(kPool[0]);
    const QString noiseChars = QStringLiteral("0123456789 %$#@!-_:.가나다라마바사페일세이프");

    for (int round = 0; round < kRounds; round++) {
        QStringList texts;
        QSet<QString> keys;
        int expected = 0;
        for (int i = 0; i < kSends; i++) {
            if (rng.bounded(4) == 0) {
                // Unique noise that can never contain a throttle phrase
                QString noise = QStringLiteral("N%1-%2:").arg(round).arg(i);
                const int length = rng.bounded(1, 40);
                for (int c = 0; c < length; c++) {
                    noise += noiseChars.at(rng.bounded(noiseChars.length()));
                }
                texts.append(noise);
                expected++;
            } else {
                const PoolText& pool = kPool[rng.bounded(poolCount)];
                texts.append(QString::fromUtf8(pool.text));
                if (!pool.key) {
                    expected++;
                } else if (!keys.contains(pool.key)) {
                    keys.insert(pool.key);
                    expected++;
                }
            }
        }

        for (QLocale::Language language : { QLocale::English, QLocale::Korean, QLocale::Japanese, QLocale::Danish }) {
            _setLanguage(language);
            QElapsedTimer timer;
            timer.start();
            for (const QString& text : texts) {
                _send(text);
            }
            QVERIFY2(timer.elapsed() < kThrottleWindowMs, "Round took longer than the throttle window");

            _handler->lockAccess();
            const int stored = _handler->messages().count();
            _handler->unlockAccess();
            QVERIFY2(stored == expected,
                     qPrintable(QStringLiteral("seed %1 round %2 lang %3: stored %4, expected %5")
                                .arg(seed).arg(round).arg(QLocale::languageToString(language)).arg(stored).arg(expected)));
        }
    }
}
