/****************************************************************************
 * AQGC — security log (CE RED 3.3(d)/(e), EN 18031, Figma S65 "Security log", 2026-11-17).
 * One line per security event: keys and passwords set / changed / removed, refused keys, certificate changes,
 * data deleted. Never a key, password or other secret. File: <AppData>/security.log (+ security.log.1 when full).
 ****************************************************************************/
#pragma once

#include <QString>
#include <QStringList>

namespace SecurityLog {
    /// append "<ISO time> <source>: <text>"
    void        write   (const QString& source, const QString& text);
    QString     path    ();
    /// newest first, at most maxLines (current file, then the rotated one)
    QStringList lines   (int maxLines = 200);
}
