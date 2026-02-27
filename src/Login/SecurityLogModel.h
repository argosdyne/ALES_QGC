/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QObject>
#include <QStringListModel>
#include <QFile>

// Hackish way to force only this translation unit to have public ctor access
#ifndef _SECLOG_CTOR_ACCESS_
#define _SECLOG_CTOR_ACCESS_ private
#endif

class SecurityLogModel : public QStringListModel
{
    Q_OBJECT
public:
    Q_INVOKABLE void writeMessages(const QString destFile);
    Q_INVOKABLE void clearLog();
    static void log(const QString message);

signals:
    void emitLog(const QString message);
    void writeStarted();
    void writeFinished(bool success);

private slots:
    void threadsafeLog(const QString message);

private:
    void _initPersistentLog();
    QFile _logFile;
    bool _persistentInitDone = false;

_SECLOG_CTOR_ACCESS_:
    SecurityLogModel();
};

class SecurityLog
{
public:
    static void installModel();
    static SecurityLogModel* getModel();
    static void logEvent(const QString& message);
};
