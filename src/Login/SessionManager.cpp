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
#include <QSettings>

#ifdef Q_OS_ANDROID
#include <jni.h>
#endif

SessionManager* SessionManager::s_instance = nullptr;

SessionManager::SessionManager(QObject *parent)
    : QObject(parent)
    , m_isAppInBackground(false)
{
    s_instance = this;

    QSettings settings;
    m_sessionManagementEnabled = settings.value(QStringLiteral("SessionManagement/Enabled"), true).toBool();

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
                qInfo() << "[SESSION_TRACE][CPP] ApplicationInactive ignored; waiting for Hidden/Suspended";
                break;
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

void SessionManager::setSessionManagementEnabled(bool enabled)
{
    if (m_sessionManagementEnabled == enabled) {
        return;
    }

    m_sessionManagementEnabled = enabled;
    QSettings settings;
    settings.setValue(QStringLiteral("SessionManagement/Enabled"), enabled);

    if (!m_sessionManagementEnabled) {
        m_sessionActive = false;
        m_sessionTimer.stop();
    } else if (!m_isAppInBackground) {
        startSession();
    }

    emit sessionManagementEnabledChanged();
}

void SessionManager::startSession() {
    if (!m_sessionManagementEnabled) {
        m_sessionActive = false;
        m_sessionTimer.stop();
        return;
    }

    m_isAppInBackground = false;
    m_sessionActive = true;
    _restartInactivityTimer();
}

void SessionManager::recordUserInteraction() {
    if (!m_sessionManagementEnabled) {
        return;
    }

    _restartInactivityTimer();
}

void SessionManager::_onSessionTimeout() {
    if (!m_sessionManagementEnabled) {
        return;
    }

    SecurityLog::logEvent(QStringLiteral("Session timeout - session locked"));
    m_sessionActive = false;
    m_sessionTimer.stop();
    emit sessionLocked();
}

void SessionManager::onAppBackground() {
    if (!m_sessionManagementEnabled) {
        return;
    }

    if (m_sessionLockSuppressionCount > 0) {
        m_backgroundEventSuppressed = true;
        qInfo() << "[SESSION_TRACE][CPP] App background ignored while session lock is suppressed; reason="
                << m_sessionLockSuppressionReason
                << "count=" << m_sessionLockSuppressionCount;
        return;
    }

    m_isAppInBackground = true;
    m_sessionActive = false;
    m_sessionTimer.stop();
    emit sessionLocked();
}

void SessionManager::onAppForeground() {
    m_isAppInBackground = false;
    m_backgroundEventSuppressed = false;
}

void SessionManager::setSessionLockSuppressed(bool suppressed, const QString& reason)
{
    if (suppressed) {
        ++m_sessionLockSuppressionCount;
        m_sessionLockSuppressionReason = reason;
    } else if (m_sessionLockSuppressionCount > 0) {
        --m_sessionLockSuppressionCount;
        if (m_sessionLockSuppressionCount == 0) {
            m_sessionLockSuppressionReason.clear();
            if (m_backgroundEventSuppressed) {
                m_backgroundEventSuppressed = false;
                if (auto* guiApp = qobject_cast<QGuiApplication*>(qApp)) {
                    const Qt::ApplicationState state = guiApp->applicationState();
                    if (state == Qt::ApplicationHidden || state == Qt::ApplicationSuspended) {
                        qInfo() << "[SESSION_TRACE][CPP] Applying deferred background lock after suppression ended; state="
                                << state;
                        onAppBackground();
                    }
                }
            }
        }
    }

    qInfo() << "[SESSION_TRACE][CPP] session lock suppression"
            << (suppressed ? "enabled" : "disabled")
            << "reason=" << reason
            << "count=" << m_sessionLockSuppressionCount;
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
    if (!m_sessionManagementEnabled || !m_sessionActive || m_isAppInBackground) {
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

extern "C" JNIEXPORT void JNICALL
Java_org_mavlink_qgroundcontrol_QGCActivity_nativeSetSessionLockSuppressed(JNIEnv* env, jclass, jboolean suppressed, jstring reason)
{
    SessionManager* sessionManager = SessionManager::instance();
    if (!sessionManager) {
        return;
    }

    QString reasonString;
    if (reason) {
        const char* chars = env->GetStringUTFChars(reason, nullptr);
        if (chars) {
            reasonString = QString::fromUtf8(chars);
            env->ReleaseStringUTFChars(reason, chars);
        }
    }

    QMetaObject::invokeMethod(sessionManager,
                              "setSessionLockSuppressed",
                              Qt::QueuedConnection,
                              Q_ARG(bool, suppressed == JNI_TRUE),
                              Q_ARG(QString, reasonString));
}
#endif
