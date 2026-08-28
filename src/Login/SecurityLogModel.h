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
#include <QThreadPool>
#include <QTimer>

class SecurityLogModel : public QStringListModel
{
    Q_OBJECT
public:
    explicit SecurityLogModel(QObject* parent = nullptr);

    Q_INVOKABLE void writeMessages(const QString destFile);
    Q_INVOKABLE void clearLog();
    void appendMessage(const QString& message);

signals:
    void writeStarted();
    void writeFinished(bool success);

private:
    static constexpr int    _maxModelMessages = 5000;
    static constexpr int    _maxPendingMessages = 5000;
    static constexpr qint64 _recentLogReadBytes = 1024 * 1024;

    void _initPersistentLog();
    void _appendMessagesToModel(const QStringList& messages);
    void _flushPendingMessages();

    static QStringList _loadRecentMessages(const QString& logPath);
    static bool _appendPersistentMessages(const QString& logPath, const QStringList& messages);
    static bool _clearPersistentLog(const QString& logPath);
    static bool _exportPersistentLog(const QString& logPath, const QString& destFile);

    QString     _logFilePath;
    QThreadPool _fileWorker;
    QTimer      _flushTimer;
    QStringList _pendingMessages;
    bool        _pendingOverflowReported = false;
    bool        _clearRequested = false;
};

class SecurityLog
{
public:
    static void installModel(QObject* owner);
    static SecurityLogModel* getModel();
    static void logEvent(const QString& message);
};
