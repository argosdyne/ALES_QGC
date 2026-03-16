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
#include <QTimer>

class QEvent;

class SessionManager : public QObject {
    Q_OBJECT
    
public:
    explicit SessionManager(QObject *parent = nullptr);
    ~SessionManager();
    static SessionManager* instance();
    
    // Start session with 15 minute auto-lock
    Q_INVOKABLE void startSession();
    // Reset inactivity timer after user interaction
    Q_INVOKABLE void recordUserInteraction();
    
    // Android lifecycle callbacks
    Q_INVOKABLE void onAppBackground();  // App goes to background → lock immediately
    Q_INVOKABLE void onAppForeground();  // App comes to foreground → restore
    
signals:
    void sessionLocked();  // Emitted after 15 minutes of inactivity
    
private slots:
    void _onSessionTimeout();
    
private:
    bool eventFilter(QObject *watched, QEvent *event) override;
    void _restartInactivityTimer();

    QTimer m_sessionTimer;           // Timer for 15-minute inactivity timeout
    static constexpr int SESSION_TIMEOUT_MS = 15 * 60 * 1000;   // 15 minutes = 900000 ms
    bool m_isAppInBackground = false;
    bool m_sessionActive = false;
    static SessionManager* s_instance;
};

