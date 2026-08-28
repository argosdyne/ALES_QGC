/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "SecurityLogModel.h"
#include "QGCApplication.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QMetaObject>
#include <QStandardPaths>
#include <QTextStream>
#include <QThread>
#include <QtConcurrent>

#ifdef __ANDROID__
#include <jni.h>
#endif

namespace {
// Accessed only on the QGC application/QML thread. Worker and JNI callers post
// messages to that thread through SecurityLog::logEvent.
SecurityLogModel* s_securityLogModel = nullptr;
}

constexpr int SecurityLogModel::_maxModelMessages;
constexpr int SecurityLogModel::_maxPendingMessages;
constexpr qint64 SecurityLogModel::_recentLogReadBytes;

SecurityLogModel::SecurityLogModel(QObject* parent)
    : QStringListModel(parent)
{
    // Serialising file work preserves append, clear and export order while
    // keeping every file operation off the QML/UI thread.
    _fileWorker.setMaxThreadCount(1);

    // The timer runs on the model's UI thread, but only schedules a worker
    // task. It never performs file I/O on that thread.
    _flushTimer.setSingleShot(true);
    _flushTimer.setInterval(250);
    connect(&_flushTimer, &QTimer::timeout, this, &SecurityLogModel::_flushPendingMessages);

    _initPersistentLog();
}

void SecurityLogModel::appendMessage(const QString& message)
{
    Q_ASSERT(QThread::currentThread() == thread());

    QStringList messages;
    messages.append(message);
    _appendMessagesToModel(messages);

    if (_logFilePath.isEmpty()) {
        return;
    }

    // Bound memory during a log flood. UI display remains independently
    // capped by _maxModelMessages.
    if (_pendingMessages.count() >= _maxPendingMessages) {
        if (!_pendingOverflowReported) {
            qWarning() << "QGC_SecurityLog: pending log queue is full; dropping messages";
            _pendingOverflowReported = true;
        }
        return;
    }

    _pendingMessages.append(message);
    if (!_flushTimer.isActive()) {
        _flushTimer.start();
    }
}

void SecurityLogModel::_appendMessagesToModel(const QStringList& messages)
{
    for (const QString& message : messages) {
        if (message.isEmpty()) {
            continue;
        }
        const int row = rowCount();
        insertRows(row, 1);
        setData(index(row), message, Qt::DisplayRole);
    }

    const int excess = rowCount() - _maxModelMessages;
    if (excess > 0) {
        removeRows(0, excess);
    }
}

void SecurityLogModel::_initPersistentLog()
{
    const QString baseDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (baseDir.isEmpty()) {
        qWarning() << "QGC_SecurityLog: AppDataLocation is empty, persistence disabled";
        return;
    }

    QDir dir(baseDir);
    if (!dir.exists() && !dir.mkpath(QStringLiteral("."))) {
        qWarning() << "QGC_SecurityLog: Failed to create log directory:" << dir.absolutePath();
        return;
    }

    _logFilePath = dir.absoluteFilePath(QStringLiteral("QGCSecurity.log"));
    auto* watcher = new QFutureWatcher<QStringList>(this);
    connect(watcher, &QFutureWatcher<QStringList>::finished, this, [this, watcher] {
        const QStringList persistentMessages = watcher->result();
        watcher->deleteLater();

        if (!_clearRequested) {
            QStringList combined = persistentMessages;
            combined.append(stringList());
            while (combined.count() > _maxModelMessages) {
                combined.removeFirst();
            }
            setStringList(combined);
        }
    });
    watcher->setFuture(QtConcurrent::run(&_fileWorker, &SecurityLogModel::_loadRecentMessages, _logFilePath));
}

QStringList SecurityLogModel::_loadRecentMessages(const QString& logPath)
{
    QFile file(logPath);
    if (!file.exists() || !file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }

    const qint64 startOffset = qMax<qint64>(0, file.size() - _recentLogReadBytes);
    if (startOffset > 0 && file.seek(startOffset)) {
        // Discard the possibly incomplete first line after seeking near EOF.
        file.readLine();
    }

    QTextStream stream(&file);
    QStringList messages;
    while (!stream.atEnd()) {
        const QString message = stream.readLine();
        if (message.isEmpty()) {
            continue;
        }
        messages.append(message);
        if (messages.count() > _maxModelMessages) {
            messages.removeFirst();
        }
    }
    return messages;
}

void SecurityLogModel::_flushPendingMessages()
{
    Q_ASSERT(QThread::currentThread() == thread());

    if (_pendingMessages.isEmpty()) {
        return;
    }

    const QStringList messages = _pendingMessages;
    _pendingMessages.clear();
    _pendingOverflowReported = false;
    const QString logFilePath = _logFilePath;
    QtConcurrent::run(&_fileWorker, [logFilePath, messages] {
        if (!_appendPersistentMessages(logFilePath, messages)) {
            qWarning() << "QGC_SecurityLog: failed to append persistent log";
        }
    });
}

bool SecurityLogModel::_appendPersistentMessages(const QString& logPath, const QStringList& messages)
{
    QFile file(logPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        return false;
    }

    QTextStream stream(&file);
    for (const QString& message : messages) {
        stream << message << '\n';
    }
    return stream.status() == QTextStream::Ok && file.flush();
}

bool SecurityLogModel::_clearPersistentLog(const QString& logPath)
{
    QFile file(logPath);
    return file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text);
}

bool SecurityLogModel::_exportPersistentLog(const QString& logPath, const QString& destFile)
{
    if (QFileInfo(logPath).absoluteFilePath() == QFileInfo(destFile).absoluteFilePath()) {
        return false;
    }

    QFile source(logPath);
    QFile destination(destFile);
    if (!source.open(QIODevice::ReadOnly) || !destination.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return false;
    }

    QByteArray buffer;
    while (!(buffer = source.read(64 * 1024)).isEmpty()) {
        if (destination.write(buffer) != buffer.size()) {
            return false;
        }
    }
    return source.atEnd() && destination.flush();
}

void SecurityLogModel::writeMessages(const QString destFile)
{
    if (destFile.isEmpty() || _logFilePath.isEmpty()) {
        emit writeFinished(false);
        return;
    }

    // Enqueue pending records before export so the resulting file includes
    // every event accepted before this request.
    _flushTimer.stop();
    _flushPendingMessages();

    const QString logFilePath = _logFilePath;
    auto* watcher = new QFutureWatcher<bool>(this);
    connect(watcher, &QFutureWatcher<bool>::finished, this, [this, watcher] {
        const bool success = watcher->result();
        watcher->deleteLater();
        emit writeFinished(success);
    });

    emit writeStarted();
    watcher->setFuture(QtConcurrent::run(&_fileWorker, &SecurityLogModel::_exportPersistentLog, logFilePath, destFile));
}

void SecurityLogModel::clearLog()
{
    _clearRequested = true;
    _flushTimer.stop();
    _pendingMessages.clear();
    _pendingOverflowReported = false;
    setStringList(QStringList());
    if (_logFilePath.isEmpty()) {
        return;
    }

    const QString logFilePath = _logFilePath;
    QtConcurrent::run(&_fileWorker, [logFilePath] {
        if (!_clearPersistentLog(logFilePath)) {
            qWarning() << "QGC_SecurityLog: failed to clear persistent log";
        }
    });
}

void SecurityLog::installModel(QObject* owner)
{
    Q_ASSERT(owner);
    Q_ASSERT(QThread::currentThread() == owner->thread());

    if (s_securityLogModel) {
        if (s_securityLogModel->thread() != owner->thread()) {
            qCritical() << "QGC_SecurityLog: refusing to share a model across QML threads";
        }
        return;
    }

    s_securityLogModel = new SecurityLogModel(owner);
    QObject::connect(s_securityLogModel, &QObject::destroyed, [](QObject*) {
        s_securityLogModel = nullptr;
    });
}

SecurityLogModel* SecurityLog::getModel()
{
    return s_securityLogModel;
}

void SecurityLog::logEvent(const QString& message)
{
    const QString timestamp = QDateTime::currentDateTime().toString(Qt::ISODate);
    const QString fullMsg = QStringLiteral("[%1] %2").arg(timestamp, message);

    QGCApplication* const app = qgcApp();
    if (!app || QCoreApplication::closingDown()) {
        return;
    }

    QMetaObject::invokeMethod(app, [fullMsg] {
        if (!s_securityLogModel) {
            return;
        }
        if (s_securityLogModel->thread() != QThread::currentThread()) {
            qCritical() << "QGC_SecurityLog: application and model threads differ; dropping log event";
            return;
        }
        s_securityLogModel->appendMessage(fullMsg);
    }, Qt::QueuedConnection);
}

#ifdef __ANDROID__
extern "C" JNIEXPORT void JNICALL
Java_org_mavlink_qgroundcontrol_QGCActivity_nativeLogSecurityEvent(
        JNIEnv* env, jclass, jstring message)
{
    if (!env || !message) {
        qWarning() << "QGC_SecurityLog: JNI nativeLogSecurityEvent missing env/message";
        return;
    }

    const char* string = env->GetStringUTFChars(message, nullptr);
    if (!string) {
        qWarning() << "QGC_SecurityLog: JNI GetStringUTFChars returned null";
        return;
    }

    const QString logMessage = QString::fromUtf8(string).trimmed();
    env->ReleaseStringUTFChars(message, string);
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
    }

    if (logMessage.isEmpty()) {
        qWarning() << "QGC_SecurityLog: JNI received empty security event";
        return;
    }

    SecurityLog::logEvent(logMessage);
}
#endif
