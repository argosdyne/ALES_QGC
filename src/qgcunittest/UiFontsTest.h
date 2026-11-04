/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include "UnitTest.h"

#include <QLocale>
#include <QVariant>

/// ARGOSDYNE UI font standard: bundled Roboto / Roboto Mono for every language, with the
/// Noto Sans of the UI language as the fallback for Korean, Japanese and Chinese characters.
class UiFontsTest : public UnitTest
{
    Q_OBJECT

private slots:
    void init(void) override;
    void cleanup(void) override;

    // Basic
    void _basicLatinFonts(void);
    void _basicCjkFallbackPerLanguage(void);
    void _basicGlyphsComeFromLanguageFont(void);

    // Stress
    void _stressLanguageSwitching(void);

private:
    void    _setLanguage        (QLocale::Language language);
    QString _familyDrawing      (const QString& family, const QString& text);

    QVariant _savedLanguage;
};
