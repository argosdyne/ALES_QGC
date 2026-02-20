// SecurityManager.cpp
#include "SecurityManager.h"

#include <QSettings>
#include <QDebug>

#include <openssl/rand.h>
#include <openssl/evp.h>
#include <openssl/crypto.h>

SecurityManager::SecurityManager(QObject *parent)
    : QObject(parent), m_keystoreInitialized(false)
{
    // Initialize Keystore on Android at startup
#ifdef Q_OS_ANDROID
    initializeKeystore();
#endif
}

QByteArray SecurityManager::randomBytes(int length) const
{
    if (length <= 0) return QByteArray();

    QByteArray out;
    out.resize(length);
    int rc = RAND_bytes(reinterpret_cast<unsigned char*>(out.data()), length);
    if (rc != 1) {
        qWarning() << "[SecurityManager] RAND_bytes failed, rc =" << rc;
        return QByteArray();
    }
    return out;
}

QByteArray SecurityManager::deriveKey(const QByteArray &password, const QByteArray &salt, int iterations, int dkLen) const
{
    // PBKDF2-HMAC-SHA256 using OpenSSL
    if (dkLen <= 0 || iterations <= 0) {
        qWarning() << "[SecurityManager] Invalid parameters: dkLen=" << dkLen << "iterations=" << iterations;
        return QByteArray();
    }

    QByteArray out;
    out.resize(dkLen);

    int rc = PKCS5_PBKDF2_HMAC(
        password.constData(), password.size(),
        reinterpret_cast<const unsigned char*>(salt.constData()), salt.size(),
        iterations,
        EVP_sha256(),
        dkLen,
        reinterpret_cast<unsigned char*>(out.data())
        );

    if (rc != 1) {
        qWarning() << "[SecurityManager] PKCS5_PBKDF2_HMAC failed, rc =" << rc;
        return QByteArray();
    }

    return out;
}

bool SecurityManager::constantTimeCompare(const QByteArray &a, const QByteArray &b) const
{
    if (a.size() != b.size()) return false;
    unsigned char result = 0;
    for (int i = 0; i < a.size(); ++i)
        result |= a[i] ^ b[i];
    return result == 0;
}

bool SecurityManager::setPin(const QString &pin)
{
    if (pin.isEmpty()) return false;
    
    QByteArray password = pin.toUtf8();
    
    // On Android: HMAC password using Keystore key (key never leaves Keystore)
    // On other platforms: use password as-is
    QByteArray peppered = password;
#ifdef Q_OS_ANDROID
    peppered = AndroidSecurityStorage::hmacPassword(password);
#endif
    
    QByteArray salt = randomBytes(SALT_LEN);
    if (salt.isEmpty()) {
        qWarning() << "[SecurityManager] Failed to generate random salt";
        OPENSSL_cleanse(password.data(), password.size());
        if (peppered != password) OPENSSL_cleanse(peppered.data(), peppered.size());
        return false;
    }

    int it = DEFAULT_ITERATIONS;
    // Derive key using peppered password (HMAC result)
    QByteArray dk = deriveKey(peppered, salt, it, DK_LEN);
    if (dk.isEmpty()) {
        qWarning() << "[SecurityManager] Failed to derive key";
        OPENSSL_cleanse(password.data(), password.size());
        if (peppered != password) OPENSSL_cleanse(peppered.data(), peppered.size());
        return false;
    }

    QSettings s; // platform default locations
    s.beginGroup("SecurityManager");
    s.setValue("kdf", "PBKDF2-HMAC-SHA256");
    s.setValue("iterations", it);
    s.setValue("salt", salt.toBase64());
    s.setValue("derived", dk.toBase64());
    s.setValue("failedAttempts", 0);
    s.setValue("lockoutUntil", 0);
#ifdef Q_OS_ANDROID
    s.setValue("useKeystore", true);  // Flag that Keystore HMAC was used
#endif
    s.endGroup();
    s.sync();

    // Wipe sensitive data from memory
    OPENSSL_cleanse(password.data(), password.size());
    if (peppered != password) OPENSSL_cleanse(peppered.data(), peppered.size());
    OPENSSL_cleanse(dk.data(), dk.size());

    qDebug() << "[SecurityManager] PIN registered successfully (Keystore HMAC applied on Android)";
    // Ensure UI is notified that any previous lockout is cleared when a new PIN is set
    emit lockoutCleared();
    return true;
}

bool SecurityManager::hasStoredPin() const
{
    QSettings s;
    s.beginGroup("SecurityManager");
    bool ok = s.contains("derived");
    s.endGroup();
    return ok;
}

bool SecurityManager::verifyPin(const QString &pin)
{
    QSettings s;
    s.beginGroup("SecurityManager");
    if (!s.contains("derived") || !s.contains("salt") || !s.contains("iterations")) {
        s.endGroup();
        return false;
    }
    QByteArray dkStored = QByteArray::fromBase64(s.value("derived").toByteArray());
    QByteArray salt = QByteArray::fromBase64(s.value("salt").toByteArray());
    int it = s.value("iterations", DEFAULT_ITERATIONS).toInt();
#ifdef Q_OS_ANDROID
    bool useKeystore = s.value("useKeystore", false).toBool();  // Changed from usePepper
#endif
    s.endGroup();

    QByteArray password = pin.toUtf8();
    
    // On Android: HMAC password using Keystore key (key never leaves Keystore)
    // On other platforms: use password as-is
    QByteArray peppered = password;
    
#ifdef Q_OS_ANDROID
    if (useKeystore) {
        peppered = AndroidSecurityStorage::hmacPassword(password);
    }
#endif
    
    QByteArray candidate = deriveKey(peppered, salt, it, dkStored.size());

    if (candidate.isEmpty()) {
        qWarning() << "[SecurityManager] deriveKey failed during verification";
        OPENSSL_cleanse(password.data(), password.size());
        if (peppered != password) OPENSSL_cleanse(peppered.data(), peppered.size());
        return false;
    }

    bool ok = constantTimeCompare(candidate, dkStored);
    if (!ok) recordFailedAttempt();
    else resetFailedAttempts();

    // Wipe sensitive data from memory
    OPENSSL_cleanse(password.data(), password.size());
    if (peppered != password) OPENSSL_cleanse(peppered.data(), peppered.size());
    OPENSSL_cleanse(candidate.data(), candidate.size());

    return ok;
}

void SecurityManager::recordFailedAttempt()
{
    QSettings s;
    s.beginGroup("SecurityManager");
    int attempts = s.value("failedAttempts", 0).toInt();
    attempts += 1;
    s.setValue("failedAttempts", attempts);

    // Exponential lockout: start lockout after 5 attempts, then increase exponentially
    if (attempts >= 5) {
        // Base lockout time: 10 seconds
        const long long BASE_LOCKOUT_MS = 10 * 1000;
        // Exponential multiplier: 2^(attempts - 5)
        long long multiplier = 1LL << (attempts - 5); // left shift = 2^(attempts-5)
        long long lockoutDuration = BASE_LOCKOUT_MS * multiplier;

        qint64 until = QDateTime::currentMSecsSinceEpoch() + lockoutDuration;
        s.setValue("lockoutUntil", until);

        qDebug() << "[SecurityManager] Failed attempt" << attempts
                 << "- exponential lockout for" << (lockoutDuration / 1000) << "s";

        // Notify QML/UI immediately that a lockout period started
        emit lockoutStarted(until);
    }
    s.endGroup();
    s.sync();
}

void SecurityManager::resetFailedAttempts()
{
    QSettings s;
    s.beginGroup("SecurityManager");
    s.setValue("failedAttempts", 0);
    s.setValue("lockoutUntil", 0);
    s.endGroup();
    s.sync();

    // Notify UI that lockout has been cleared
    emit lockoutCleared();
}

int SecurityManager::failedAttempts() const
{
    QSettings s;
    s.beginGroup("SecurityManager");
    int attempts = s.value("failedAttempts", 0).toInt();
    s.endGroup();
    return attempts;
}

qint64 SecurityManager::lockoutUntil() const
{
    QSettings s;
    s.beginGroup("SecurityManager");
    qint64 until = s.value("lockoutUntil", 0).toLongLong();
    s.endGroup();
    return until;
}

bool SecurityManager::isLocked() const
{
    qint64 until = lockoutUntil();
    if (until <= 0) return false;
    return QDateTime::currentMSecsSinceEpoch() < until;
}

void SecurityManager::setIterations(int it)
{
    if (it <= 0) return;
    QSettings s;
    s.beginGroup("SecurityManager");
    s.setValue("iterations", it);
    s.endGroup();
    s.sync();
}

int SecurityManager::iterations() const
{
    QSettings s;
    s.beginGroup("SecurityManager");
    int it = s.value("iterations", DEFAULT_ITERATIONS).toInt();
    s.endGroup();
    return it;
}

void SecurityManager::clearStored()
{
    QSettings s;
    s.beginGroup("SecurityManager");
    s.remove("");
    s.endGroup();
    s.sync();
}

bool SecurityManager::hasOnlyDigits(const QString &pin) const
{
    if (pin.isEmpty()) return false;

    for (int i = 0; i < pin.length(); ++i) {
        if (!pin.at(i).isDigit()) {
            return false;
        }
    }
    return true;
}

bool SecurityManager::hasRepeatingDigits(const QString &pin) const
{
    if (pin.isEmpty()) return false;

    QChar firstChar = pin.at(0);
    for (int i = 1; i < pin.length(); ++i) {
        if (pin.at(i) != firstChar) return false;
    }
    return true;
}

bool SecurityManager::hasSequentialDigits(const QString &pin) const
{
    if (pin.length() < 2) return false;

    // Check ascending: each digit is 1 more than previous
    bool isAscending = true;
    for (int i = 1; i < pin.length(); ++i) {
        int prev = pin.at(i - 1).digitValue();
        int curr = pin.at(i).digitValue();
        if (prev == -1 || curr == -1 || curr != prev + 1) {
            isAscending = false;
            break;
        }
    }
    if (isAscending) return true;

    // Check descending: each digit is 1 less than previous
    bool isDescending = true;
    for (int i = 1; i < pin.length(); ++i) {
        int prev = pin.at(i - 1).digitValue();
        int curr = pin.at(i).digitValue();
        if (prev == -1 || curr == -1 || curr != prev - 1) {
            isDescending = false;
            break;
        }
    }
    return isDescending;
}

QString SecurityManager::validatePINStrength(const QString &pin) const
{
    // Check if PIN contains only digits
    if (!hasOnlyDigits(pin)) {
        return "PIN must contain only digits (0-9)";
    }

    if (hasRepeatingDigits(pin)) {
        return "PIN cannot be all same digits (e.g., 11111111)";
    }
    if (hasSequentialDigits(pin)) {
        return "PIN cannot be sequential (e.g., 12345678 or 87654321)";
    }
    return ""; // empty string = valid
}
//-------------------------------------------------------------------------
//-- Keystore Management (Android - Hardware-Backed HMAC Key)

bool SecurityManager::initializeKeystore()
{
#ifdef Q_OS_ANDROID
    if (!AndroidSecurityStorage::isKeystoreAvailable()) {
        qWarning() << "[SecurityManager] Android Keystore not available";
        return false;
    }
    
    m_keystoreInitialized = AndroidSecurityStorage::initializeKeystore();
    
    if (m_keystoreInitialized) {
        qDebug() << "[SecurityManager] Android Keystore initialized (key stays in Keystore)";
    } else {
        qWarning() << "[SecurityManager] Failed to initialize Keystore key";
    }
    
    return m_keystoreInitialized;
#else
    m_keystoreInitialized = true;  // Non-Android: no Keystore, always success
    return true;
#endif
}

void SecurityManager::clearKeystore()
{
#ifdef Q_OS_ANDROID
    if (!AndroidSecurityStorage::deleteKeystore()) {
        qWarning() << "[SecurityManager] Failed to delete Keystore key";
    } else {
        qDebug() << "[SecurityManager] Keystore key deleted";
    }
    m_keystoreInitialized = false;
#endif
}