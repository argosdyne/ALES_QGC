/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QString>

/// Translates vehicle status texts (STATUSTEXT, pre-arm errors) through the "UASWarning"
/// translation context. Texts that the vehicle has already formatted with values
/// (e.g. "Compass 2 not calibrated") are matched against the printf-style keys
/// in UASWarningPatterns.h ("Compass %d not calibrated"), and the values are
/// inserted into the translated text.
class StatusTextTranslator
{
public:
    /// @return the translated text, or @p text unchanged when no translation exists
    static QString translate(const QString& text);
};
