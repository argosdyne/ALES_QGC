#pragma once

#include "UnitTest.h"
#include "CustomQmlInterface.h"

#include <QLocale>

/// GeoAwareness alerts: stacking uses the height QML draws, and the spoken
/// warning is played only when the UI language is English.
class GeoAwarenessAlertTest : public UnitTest
{
    Q_OBJECT

private slots:
    void init(void) override;
    void cleanup(void) override;

    // Basic
    void _basicStackUsesDrawnHeight(void);
    void _basicSpeechOnlyInEnglish(void);

    // Abnormal input
    void _abnormalHeights(void);
    void _abnormalSetterAfterClose(void);
    void _abnormalMessages(void);

    // Stress
    void _stressHeightUpdates(void);

    // Random
    void _randomShowResizeClose(void);

private:
    void                    _setLanguage    (QLocale::Language language);
    QList<SystemMessage*>   _messages       (void);
    void                    _settle         (void);
    void                    _closeAll       (void);
    void                    _verifyNoOverlap(const QString& context);
    QStringList             _spokenWithin   (int msecs);

    static CustomQmlInterface* _interface;
    QVariant _savedLanguage;
};
