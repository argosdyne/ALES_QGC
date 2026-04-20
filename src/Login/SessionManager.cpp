/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/
#include "SessionManager.h"
#include "SecurityLogModel.h"

#include <QCoreApplication>
#include <QGuiApplication>
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
    if (auto* guiApp = qobject_cast<QGuiApplication*>(qApp)) {
        connect(guiApp, &QGuiApplication::applicationStateChanged,
                this, [this](Qt::ApplicationState state) {
            qInfo() << "[SESSION_TRACE][CPP] applicationStateChanged fallback state=" << state;

            switch (state) {
            case Qt::ApplicationActive:
                onAppForeground();
                break;
            case Qt::ApplicationInactive:
            case Qt::ApplicationHidden:
            case Qt::ApplicationSuspended:
                onAppBackground();
                break;
            default:
                break;
            }
        });
    } else {
        qWarning() << "[SESSION_TRACE][CPP] applicationStateChanged fallback unavailable: qApp is not QGuiApplication";
    }
}

SessionManager::~SessionManager() {
    if (qApp) {
        qApp->removeEventFilter(this);
    }
    m_sessionTimer.stop();
    if (s_instance == this) {
        s_instance = nullptr;
    }
}

SessionManager* SessionManager::instance()
{
    return s_instance;
}

void SessionManager::startSession() {
    m_isAppInBackground = false;
    m_sessionActive = true;
    _restartInactivityTimer();
}

void SessionManager::recordUserInteraction() {
    _restartInactivityTimer();
}

void SessionManager::_onSessionTimeout() {
    SecurityLog::logEvent(QStringLiteral("Session timeout - session locked"));
    m_sessionActive = false;
    m_sessionTimer.stop();
    emit sessionLocked();
}

void SessionManager::onAppBackground() {
    m_isAppInBackground = true;
    m_sessionActive = false;
    m_sessionTimer.stop();
    emit sessionLocked();
}

void SessionManager::onAppForeground() {
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
