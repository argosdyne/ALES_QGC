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
#include <QByteArray>
#include <QString>
#include <QDateTime>

// Android-specific functionality is implemented inside SecurityManager.cpp

class SecurityManager : public QObject
{
    Q_OBJECT
public:
    explicit SecurityManager(QObject *parent = nullptr);

    // Expose core APIs to QML
    Q_INVOKABLE bool setPin(const QString &pin);
    Q_INVOKABLE bool verifyPin(const QString &pin);
    Q_INVOKABLE bool hasStoredPin() const;
    Q_INVOKABLE bool rememberMeEnabled() const;
    Q_INVOKABLE void setRememberMeEnabled(bool enabled);
    Q_INVOKABLE QString generateAndStoreRecoveryKey();
    Q_INVOKABLE bool verifyRecoveryKey(const QString &recoveryKey);
    Q_INVOKABLE bool hasStoredRecoveryKey() const;
    Q_INVOKABLE bool verifyRestorePhrase(const QString &input) const;

    // Failed attempts and lockout
    Q_INVOKABLE void recordFailedAttempt();
    Q_INVOKABLE void resetFailedAttempts();
    Q_INVOKABLE int failedAttempts() const;
    Q_INVOKABLE qint64 lockoutUntil() const; // unix msecs
    Q_INVOKABLE bool isLocked() const;
    Q_INVOKABLE void recordFailedAttemptForScope(const QString &scope);
    Q_INVOKABLE void resetFailedAttemptsForScope(const QString &scope);
    Q_INVOKABLE int failedAttemptsForScope(const QString &scope) const;
    Q_INVOKABLE qint64 lockoutUntilForScope(const QString &scope) const; // unix msecs
    Q_INVOKABLE bool isLockedForScope(const QString &scope) const;

    // KDF parameters accessors
    Q_INVOKABLE void setIterations(int it);
    Q_INVOKABLE int iterations() const;

    // Clear stored data (for testing / reset)
    Q_INVOKABLE void clearStored();

    // PIN strength validation
    Q_INVOKABLE bool hasRepeatingDigits(const QString &pin) const;
    Q_INVOKABLE bool hasSequentialDigits(const QString &pin) const;
    Q_INVOKABLE bool hasRepeatedNumericBlocks(const QString &pin) const;
    Q_INVOKABLE bool hasOnlyDigits(const QString &pin) const;
    Q_INVOKABLE QString validatePINStrength(const QString &pin) const;

signals:
    // Emitted when a lockout period starts; parameter is unix msecs until which lockout is active
    void lockoutStarted(qint64 until);
    // Emitted when lockout is cleared/reset
    void lockoutCleared();
    // Scope-aware signals for independent lockout flows (login/forgot_pin/system_restore)
    void lockoutStartedForScope(const QString &scope, qint64 until);
    void lockoutClearedForScope(const QString &scope);

private:
    // internal helpers
    QByteArray deriveKey(const QByteArray &password, const QByteArray &salt, int iterations, int dkLen) const;
    bool constantTimeCompare(const QByteArray &a, const QByteArray &b) const;
    QByteArray randomBytes(int length) const;

    // Keystore management (Android only) - key never leaves Keystore
    bool initializeKeystore();           // Initialize Keystore key at startup
    void clearKeystore();                // Clear Keystore key on PIN reset

    // defaults
    static const int DEFAULT_ITERATIONS = 200000;
    static const int SALT_LEN = 16;
    static const int DK_LEN = 32; // 256-bit derived key

    bool m_keystoreInitialized;
};
