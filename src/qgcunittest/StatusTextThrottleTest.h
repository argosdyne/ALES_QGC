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
#include <QStringList>

class UASMessageHandler;

/// Duplicate status text throttling in UASMessageHandler must work the same
/// whether or not the status text is translated.
class StatusTextThrottleTest : public UnitTest
{
    Q_OBJECT

private slots:
    void init(void) override;
    void cleanup(void) override;

    // Basic
    void _basicDuplicateDroppedEnglish(void);
    void _basicDuplicateDroppedKorean(void);
    void _basicWindowExpires(void);
    void _basicUnkeyedNotDropped(void);

    // Abnormal input
    void _abnormalInputs(void);

    // Stress
    void _stressFailsafeFlood(void);

    // Random
    void _randomSameDecisionsInEveryLanguage(void);

private:
    void    _setLanguage        (QLocale::Language language);
    void    _send               (const QString& text, const QString& description = QString());
    int     _storedCount        (const QString& sourceText);
    int     _storedTotal        (const QStringList& sourceTexts);

    UASMessageHandler*  _handler        = nullptr;
    QVariant            _savedLanguage;
};
