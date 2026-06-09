/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

// Allows QGlobalStatic to work on this translation unit
#define _SECLOG_CTOR_ACCESS_ public

#include "SecurityLogModel.h"

#include <QStringListModel>
#include <QtConcurrent>
#include <QDebug>
#include <QTextStream>
#include <QDateTime>
#include <QThread>
#include <QDir>
#include <QStandardPaths>

#ifdef __ANDROID__
#include <jni.h>
#endif

Q_GLOBAL_STATIC(SecurityLogModel, s_seclogModel)

SecurityLogModel::SecurityLogModel()
    : QStringListModel()
{
    connect(this, &SecurityLogModel::emitLog, this, &SecurityLogModel::threadsafeLog, Qt::AutoConnection);
    _initPersistentLog();
}

void SecurityLogModel::log(const QString message)
{
    // Guard against calls after Q_GLOBAL_STATIC has been destroyed during app shutdown
    if (s_seclogModel.isDestroyed()) {
        return;
    }
    emit s_seclogModel->emitLog(message);
}

void SecurityLogModel::threadsafeLog(const QString message)
{
    qInfo().noquote() << "QGC_SecurityLog: threadsafeLog received:" << message;
    if (!_persistentInitDone) {
        _initPersistentLog();
    }

    const int line = rowCount();
    insertRows(line, 1);
    setData(index(line), message, Qt::DisplayRole);

    if (_logFile.isOpen()) {
        QTextStream out(&_logFile);
        out << message << "\n";
        _logFile.flush();
        qInfo().noquote() << "QGC_SecurityLog: wrote persistent log:" << _logFile.fileName();
    } else {
        qWarning().noquote() << "QGC_SecurityLog: persistent log file is not open";
    }
}

void SecurityLogModel::_initPersistentLog()
{
    if (_persistentInitDone) {
        return;
    }
    _persistentInitDone = true;

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

    const QString logPath = dir.absoluteFilePath(QStringLiteral("QGCSecurity.log"));
    qInfo().noquote() << "QGC_SecurityLog: init persistent log:" << logPath;

    QFile readFile(logPath);
    if (readFile.exists() && readFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&readFile);
        while (!in.atEnd()) {
            const QString lineText = in.readLine();
            if (lineText.isEmpty()) {
                continue;
            }
            const int line = rowCount();
            insertRows(line, 1);
            setData(index(line), lineText, Qt::DisplayRole);
        }
    }

    _logFile.setFileName(logPath);
    if (!_logFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        qWarning() << "QGC_SecurityLog: Failed to open log file:" << _logFile.fileName() << _logFile.errorString();
    }
}

void SecurityLogModel::writeMessages(const QString destFile)
{
    const QString writebuffer(stringList().join('\n').append('\n'));
    QtConcurrent::run([destFile, writebuffer] {
        if (s_seclogModel.isDestroyed()) return;
        emit s_seclogModel->writeStarted();
        bool success = false;
        QFile file(destFile);
        if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream out(&file);
            out << writebuffer;
            success = out.status() == QTextStream::Ok;
        } else {
            qWarning() << "SecurityLogModel::writeMessages failed:" << file.errorString();
        }
        if (!s_seclogModel.isDestroyed())
            emit s_seclogModel->writeFinished(success);
    });
}

void SecurityLogModel::clearLog()
{
    if (!_persistentInitDone) {
        _initPersistentLog();
    }

    if (rowCount() > 0) {
        removeRows(0, rowCount());
    }

    const QString logPath = _logFile.fileName();
    if (logPath.isEmpty()) {
        return;
    }

    if (_logFile.isOpen()) {
        _logFile.close();
    }

    QFile clearFile(logPath);
    if (!clearFile.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        qWarning() << "SecurityLogModel: Failed to clear log file:" << logPath << clearFile.errorString();
        return;
    }
    clearFile.close();

    if (!_logFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        qWarning() << "SecurityLogModel: Failed to reopen log file after clear:" << _logFile.fileName() << _logFile.errorString();
    }
}

// SecurityLog static helpers

void SecurityLog::installModel()
{
    // Force creation of the model on the calling (main) thread
    Q_UNUSED(*s_seclogModel);
}

SecurityLogModel* SecurityLog::getModel()
{
    return s_seclogModel;
}

void SecurityLog::logEvent(const QString& message)
{
    const QString timestamp = QDateTime::currentDateTime().toString(Qt::ISODate);
    const QString fullMsg = QStringLiteral("[%1] %2").arg(timestamp, message);
    qInfo().noquote() << "QGC_SecurityLog: logEvent:" << fullMsg;
    SecurityLogModel::log(fullMsg);
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

    qInfo().noquote() << "QGC_SecurityLog: JNI received USB security event:" << logMessage;
    SecurityLog::logEvent(logMessage);
    qInfo().noquote() << "SECURITY:" << logMessage;
}
#endif
