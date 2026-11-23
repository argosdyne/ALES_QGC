/****************************************************************************
 * AQGC — security log, see SecurityLog.h
 ****************************************************************************/

#include "SecurityLog.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QTextStream>

namespace {
    const qint64 kLogMaxBytes = 256 * 1024;

    QStringList readLines(const QString& file)
    {
        QStringList result;
        QFile f(file);
        if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QTextStream in(&f);
            while (!in.atEnd()) {
                const QString line = in.readLine().trimmed();
                if (!line.isEmpty()) {
                    result.append(line);
                }
            }
        }
        return result;
    }
}

QString SecurityLog::path()
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/security.log");
}

void SecurityLog::write(const QString& source, const QString& text)
{
    const QString file = path();
    QDir().mkpath(QFileInfo(file).absolutePath());
    if (QFileInfo(file).size() > kLogMaxBytes) {
        QFile::remove(file + QStringLiteral(".1"));
        QFile::rename(file, file + QStringLiteral(".1"));
    }
    QFile f(file);
    if (f.open(QIODevice::Append | QIODevice::Text)) {
        QTextStream out(&f);
        out << QDateTime::currentDateTime().toString(Qt::ISODate) << " " << source << ": " << text << "\n";
    }
}

QStringList SecurityLog::lines(int maxLines)
{
    QStringList all = readLines(path() + QStringLiteral(".1")) + readLines(path());
    QStringList result;
    for (int i = all.count() - 1; i >= 0 && result.count() < maxLines; i--) {
        result.append(all[i]);
    }
    return result;
}
