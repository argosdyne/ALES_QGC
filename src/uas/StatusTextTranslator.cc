/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "StatusTextTranslator.h"
#include "UASWarningPatterns.h"

#include <QCoreApplication>
#include <QRegularExpression>
#include <QVector>

#include <algorithm>

namespace {

const char* const kContext = "UASWarning";

/// A literal "%%", a printf conversion such as %d, %5.2f, %s, or a Qt %1..%9 argument.
/// printf is tried first so "%3.1f" is not read as Qt argument %3.
const QRegularExpression& _conversionExpression()
{
    static const QRegularExpression expression(QStringLiteral("%(?:(%)|[-+ #0]*\\d*(?:\\.\\d+)?(?:hh|h|ll|l|z)?([diuoxXfFeEgGcs])|([1-9]))"));
    return expression;
}

/// Arguments are paired by class, so a translation may reorder arguments of different types
QChar _conversionClass(const QRegularExpressionMatch& match)
{
    if (!match.captured(3).isEmpty()) {
        return match.captured(3).at(0);     // Qt %1..%9
    }
    switch (match.captured(2).at(0).toLatin1()) {
    case 'd': case 'i': case 'u':
        return QLatin1Char('i');
    case 'o':
        return QLatin1Char('o');
    case 'x': case 'X':
        return QLatin1Char('x');
    case 'c':
        return QLatin1Char('c');
    case 's':
        return QLatin1Char('s');
    default:
        return QLatin1Char('f');
    }
}

QString _capturePattern(QChar conversionClass)
{
    switch (conversionClass.toLatin1()) {
    case 'i':
        return QStringLiteral("\\s*([-+]?\\d+)");
    case 'o':
        return QStringLiteral("\\s*([0-7]+)");
    case 'x':
        return QStringLiteral("\\s*([0-9A-Fa-f]+)");
    case 'f':
        return QStringLiteral("\\s*([-+]?(?:\\d+(?:\\.\\d*)?|\\.\\d+)(?:[eE][-+]?\\d+)?|[-+]?(?:nan|NaN|NAN|inf|Inf|INF))");
    case 'c':
        return QStringLiteral("(.)");
    default:
        return QStringLiteral("(.*?)");      // %s and Qt %1..%9
    }
}

struct StatusTextPattern {
    QRegularExpression  expression;
    QByteArray          key;
    QVector<QChar>      conversionClasses;
    int                 literalLength = 0;
};

QVector<StatusTextPattern> _buildPatterns()
{
    QVector<StatusTextPattern> patterns;
    for (const char* rawKey : kUASWarningPatternKeys) {
        const QString key = QString::fromUtf8(rawKey);
        StatusTextPattern pattern;
        pattern.key = QByteArray(rawKey);

        QString regex;
        int literalStart = 0;
        QRegularExpressionMatchIterator it = _conversionExpression().globalMatch(key);
        while (it.hasNext()) {
            const QRegularExpressionMatch match = it.next();
            const QString literal = key.mid(literalStart, match.capturedStart() - literalStart);
            regex += QRegularExpression::escape(literal);
            pattern.literalLength += literal.length();
            if (!match.captured(1).isEmpty()) {
                regex += QRegularExpression::escape(QStringLiteral("%"));
                pattern.literalLength++;
            } else {
                const QChar conversionClass = _conversionClass(match);
                regex += _capturePattern(conversionClass);
                pattern.conversionClasses.append(conversionClass);
            }
            literalStart = match.capturedEnd();
        }
        const QString tail = key.mid(literalStart);
        regex += QRegularExpression::escape(tail);
        pattern.literalLength += tail.length();

        pattern.expression = QRegularExpression(QStringLiteral("\\A(?:%1)\\z").arg(regex), QRegularExpression::DotMatchesEverythingOption);
        if (!pattern.expression.isValid() || pattern.conversionClasses.isEmpty()) {
            continue;
        }
        pattern.expression.optimize();
        patterns.append(pattern);
    }

    // Try the most specific keys first so "Compass %d not calibrated" wins over "%s not calibrated"
    std::stable_sort(patterns.begin(), patterns.end(), [](const StatusTextPattern& a, const StatusTextPattern& b) {
        return a.literalLength > b.literalLength;
    });
    return patterns;
}

QString _translate(const QString& text, int depth);

/// Inserts the values captured from the vehicle text into the translated key.
/// %s values are translated too, so "PreArm: %s" also translates the reason text.
QString _fillArguments(const QString& translated, const StatusTextPattern& pattern, const QRegularExpressionMatch& valueMatch, int depth)
{
    QVector<bool> used(pattern.conversionClasses.count(), false);
    QString result;
    int literalStart = 0;
    QRegularExpressionMatchIterator it = _conversionExpression().globalMatch(translated);
    while (it.hasNext()) {
        const QRegularExpressionMatch match = it.next();
        result += translated.mid(literalStart, match.capturedStart() - literalStart);
        literalStart = match.capturedEnd();
        if (!match.captured(1).isEmpty()) {
            result += QLatin1Char('%');
            continue;
        }
        const QChar conversionClass = _conversionClass(match);
        int index = -1;
        for (int i = 0; i < pattern.conversionClasses.count(); i++) {
            if (!used[i] && pattern.conversionClasses[i] == conversionClass) {
                index = i;
                break;
            }
        }
        if (index < 0) {
            result += match.captured(0);
            continue;
        }
        used[index] = true;
        const QString value = valueMatch.captured(index + 1);
        result += (conversionClass == QLatin1Char('s') && depth < 2) ? _translate(value, depth + 1) : value;
    }
    result += translated.mid(literalStart);
    return result;
}

QString _translate(const QString& text, int depth)
{
    const QByteArray textUtf8 = text.toUtf8();
    const QString exact = QCoreApplication::translate(kContext, textUtf8.constData());
    if (exact != text) {
        return exact;
    }

    static const QVector<StatusTextPattern> patterns = _buildPatterns();
    for (const StatusTextPattern& pattern : patterns) {
        const QRegularExpressionMatch match = pattern.expression.match(text);
        if (!match.hasMatch()) {
            continue;
        }
        const QString translated = QCoreApplication::translate(kContext, pattern.key.constData());
        if (translated == QString::fromUtf8(pattern.key)) {
            // The current language has no translation for this key
            return text;
        }
        return _fillArguments(translated, pattern, match, depth);
    }
    return text;
}

} // namespace

QString StatusTextTranslator::translate(const QString& text)
{
    return _translate(text, 0);
}
