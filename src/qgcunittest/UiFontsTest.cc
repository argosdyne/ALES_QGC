/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "UiFontsTest.h"
#include "QGCApplication.h"

#include <QFont>
#include <QFontDatabase>
#include <QFontInfo>
#include <QGlyphRun>
#include <QRawFont>
#include <QSettings>
#include <QTextLayout>

namespace {

const char* kLanguageKey = "qLocaleLanguage";

} // namespace

void UiFontsTest::init(void)
{
    UnitTest::init();
    _savedLanguage = QSettings().value(kLanguageKey);
}

void UiFontsTest::cleanup(void)
{
    QSettings settings;
    if (_savedLanguage.isValid()) {
        settings.setValue(kLanguageKey, _savedLanguage);
    } else {
        settings.remove(kLanguageKey);
    }
    qgcApp()->setLanguage();
    UnitTest::cleanup();
}

void UiFontsTest::_setLanguage(QLocale::Language language)
{
    QSettings().setValue(kLanguageKey, static_cast<int>(language));
    qgcApp()->setLanguage();
}

QString UiFontsTest::_familyDrawing(const QString& family, const QString& text)
{
    // The font that actually draws the text, after fallback
    QFont font(family);
    font.setPixelSize(20);
    QTextLayout layout(text, font);
    layout.beginLayout();
    layout.createLine();
    layout.endLayout();
    const QList<QGlyphRun> runs = layout.glyphRuns();
    return runs.isEmpty() ? QString() : runs.first().rawFont().familyName();
}

void UiFontsTest::_basicLatinFonts(void)
{
    _setLanguage(QLocale::English);

    QCOMPARE(qgcApp()->normalFontFamily(), QStringLiteral("Roboto"));
    QVERIFY(qgcApp()->mediumFontFamily().startsWith(QStringLiteral("Roboto")));
    QCOMPARE(qgcApp()->fixedFontFamily(), QStringLiteral("Roboto Mono"));

    // Bundled fonts, not system fonts that happen to have the same name
    const QStringList families = QFontDatabase().families();
    for (const QString& family : { qgcApp()->normalFontFamily(), qgcApp()->mediumFontFamily(), qgcApp()->fixedFontFamily() }) {
        QVERIFY2(families.contains(family), qPrintable(family));
        QCOMPARE(QFontInfo(QFont(family)).family(), family);
    }
    QCOMPARE(_familyDrawing(qgcApp()->normalFontFamily(), QStringLiteral("Altitude 120 m")), QStringLiteral("Roboto"));
    QCOMPARE(_familyDrawing(qgcApp()->fixedFontFamily(), QStringLiteral("PARAM_1 = 0.25")), QStringLiteral("Roboto Mono"));

    // No CJK fallback for Latin languages
    QVERIFY(QFont::substitutes(qgcApp()->normalFontFamily()).isEmpty());
    QVERIFY(QFont::substitutes(qgcApp()->fixedFontFamily()).isEmpty());
}

void UiFontsTest::_basicCjkFallbackPerLanguage(void)
{
    const struct {
        QLocale::Language   language;
        const char*         regular;
        const char*         medium;
    } cases[] = {
        { QLocale::Korean,   "Noto Sans KR", "Noto Sans KR Medium" },
        { QLocale::Japanese, "Noto Sans JP", "Noto Sans JP Medium" },
        { QLocale::Chinese,  "Noto Sans SC", "Noto Sans SC Medium" },
    };
    for (const auto& c : cases) {
        _setLanguage(c.language);
        const QString language = QLocale::languageToString(c.language);
        // Qt stores substitute names in lower case
        QCOMPARE(QFont::substitutes(qgcApp()->normalFontFamily()), QStringList(QString::fromLatin1(c.regular).toLower()));
        QCOMPARE(QFont::substitutes(qgcApp()->fixedFontFamily()), QStringList(QString::fromLatin1(c.regular).toLower()));
        if (qgcApp()->mediumFontFamily() != qgcApp()->normalFontFamily()) {
            QCOMPARE(QFont::substitutes(qgcApp()->mediumFontFamily()), QStringList(QString::fromLatin1(c.medium).toLower()));
        }
        QVERIFY2(QFontDatabase().families().contains(QString::fromLatin1(c.regular)), qPrintable(language));
    }

    // Back to a Latin language: the fallback is removed
    _setLanguage(QLocale::English);
    QVERIFY(QFont::substitutes(qgcApp()->normalFontFamily()).isEmpty());
}

void UiFontsTest::_basicGlyphsComeFromLanguageFont(void)
{
    // Latin letters stay Roboto, CJK characters come from the language's Noto Sans. Switching at
    // run time must take effect too (Qt caches font engines with their fallbacks).
    _setLanguage(QLocale::Korean);
    QCOMPARE(_familyDrawing(qgcApp()->normalFontFamily(), QStringLiteral("Altitude")), QStringLiteral("Roboto"));
    QCOMPARE(_familyDrawing(qgcApp()->normalFontFamily(), QStringLiteral("고도")), QStringLiteral("Noto Sans KR"));

    _setLanguage(QLocale::Japanese);
    QCOMPARE(_familyDrawing(qgcApp()->normalFontFamily(), QStringLiteral("高度")), QStringLiteral("Noto Sans JP"));

    _setLanguage(QLocale::Chinese);
    QCOMPARE(_familyDrawing(qgcApp()->normalFontFamily(), QStringLiteral("检查")), QStringLiteral("Noto Sans SC"));

    // Back to a language loaded before
    _setLanguage(QLocale::Korean);
    QCOMPARE(_familyDrawing(qgcApp()->normalFontFamily(), QStringLiteral("고도")), QStringLiteral("Noto Sans KR"));
}

void UiFontsTest::_stressLanguageSwitching(void)
{
    const QLocale::Language languages[] = { QLocale::Korean, QLocale::English, QLocale::Japanese, QLocale::Chinese, QLocale::Vietnamese };
    for (int i = 0; i < 25; i++) {
        _setLanguage(languages[i % 5]);
    }
    // Ends on Vietnamese: Roboto only, and Latin text with tone marks still drawn by Roboto
    QVERIFY(QFont::substitutes(qgcApp()->normalFontFamily()).isEmpty());
    QCOMPARE(_familyDrawing(qgcApp()->normalFontFamily(), QStringLiteral("Độ cao")), QStringLiteral("Roboto"));
    _setLanguage(QLocale::Japanese);
    QCOMPARE(_familyDrawing(qgcApp()->normalFontFamily(), QStringLiteral("高度")), QStringLiteral("Noto Sans JP"));
}

UT_REGISTER_TEST(UiFontsTest)
