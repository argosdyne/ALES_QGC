#include "SessionManager.h"

#include <QCoreApplication>
#include <QDebug>
#include <QEvent>
#include <QMetaObject>

#ifdef Q_OS_ANDROID
#include <jni.h>
#endif

SessionManager* SessionManager::s_instance = nullptr;

SessionManager::SessionManager(QObject *parent)
    : QObject(parent)
    , m_isAppInBackground(false)
{
    s_instance = this;

    connect(&m_sessionTimer, &QTimer::timeout,
            this, &SessionManager::_onSessionTimeout);

    m_sessionTimer.setInterval(SESSION_TIMEOUT_MS);
    m_sessionTimer.setSingleShot(true);

    if (qApp) {
        qApp->installEventFilter(this);
    }
}

SessionManager::~SessionManager() {
    if (s_instance == this) {
        s_instance = nullptr;
    }
}

SessionManager* SessionManager::instance()
{
    return s_instance;
}

void SessionManager::startSession() {
    qDebug() << "[SessionManager] Session started - inactivity timeout timer started";
    m_isAppInBackground = false;
    m_sessionActive = true;
    _restartInactivityTimer();
}

void SessionManager::recordUserInteraction() {
    _restartInactivityTimer();
}

void SessionManager::_onSessionTimeout() {
    qDebug() << "[SessionManager] Inactivity timeout reached - locking session";
    m_sessionActive = false;
    m_sessionTimer.stop();
    emit sessionLocked();
}

void SessionManager::onAppBackground() {
    qDebug() << "[SessionManager] App backgrounded - locking session immediately";
    m_isAppInBackground = true;
    m_sessionActive = false;
    m_sessionTimer.stop();
    emit sessionLocked();
}

void SessionManager::onAppForeground() {
    qDebug() << "[SessionManager] App foregrounded - session remains locked";
    m_isAppInBackground = false;
}

bool SessionManager::eventFilter(QObject *watched, QEvent *event) {
    Q_UNUSED(watched)

    if (!m_sessionActive || m_isAppInBackground || !event) {
        return QObject::eventFilter(watched, event);
    }

    switch (event->type()) {
    case QEvent::MouseButtonPress:
    case QEvent::MouseButtonDblClick:
    case QEvent::MouseButtonRelease:
    case QEvent::MouseMove:
    case QEvent::KeyPress:
    case QEvent::KeyRelease:
    case QEvent::Wheel:
    case QEvent::TouchBegin:
    case QEvent::TouchUpdate:
    case QEvent::TouchEnd:
    case QEvent::TabletPress:
    case QEvent::Gesture:
        _restartInactivityTimer();
        break;
    default:
        break;
    }

    return QObject::eventFilter(watched, event);
}

void SessionManager::_restartInactivityTimer() {
    if (!m_sessionActive || m_isAppInBackground) {
        return;
    }

    m_sessionTimer.stop();
    m_sessionTimer.start();
}

#ifdef Q_OS_ANDROID
extern "C" JNIEXPORT void JNICALL
Java_org_mavlink_qgroundcontrol_QGCActivity_nativeOnActivityPause(JNIEnv*, jobject)
{
    SessionManager* sessionManager = SessionManager::instance();
    if (sessionManager) {
        QMetaObject::invokeMethod(sessionManager, "onAppBackground", Qt::QueuedConnection);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_org_mavlink_qgroundcontrol_QGCActivity_nativeOnActivityResume(JNIEnv*, jobject)
{
    SessionManager* sessionManager = SessionManager::instance();
    if (sessionManager) {
        QMetaObject::invokeMethod(sessionManager, "onAppForeground", Qt::QueuedConnection);
    }
}
#endif
