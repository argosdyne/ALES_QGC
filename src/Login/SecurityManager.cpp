/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "SecurityManager.h"
#include "SecurityLogModel.h"

#include <QSettings>
#include <QDebug>

#include <openssl/rand.h>
#include <openssl/evp.h>
#include <openssl/crypto.h>

#ifdef Q_OS_ANDROID
#include <QAndroidJniEnvironment>
#include <QAndroidJniObject>
#include <QDebug>

static bool androidIsKeystoreAvailable()
{
    QAndroidJniEnvironment env;
    jboolean available = QAndroidJniObject::callStaticMethod<jboolean>(
        "org/mavlink/qgroundcontrol/SecurityHelper",
        "isKeystoreAvailable",
        "()Z");

    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        return false;
    }

    return available == JNI_TRUE;
}

static QByteArray androidHmacPassword(const QByteArray &password)
{
    if (password.isEmpty()) return QByteArray();

    QAndroidJniEnvironment env;

    // Convert password to Java byte[]
    jbyteArray passwordBytes = env->NewByteArray(password.size());
    if (!passwordBytes) return QByteArray();
    env->SetByteArrayRegion(passwordBytes, 0, password.size(), (jbyte*)password.constData());

    // Call Java SecurityHelper.hmacPassword() - returns QAndroidJniObject (which wraps jbyteArray)
    QAndroidJniObject resultObj = QAndroidJniObject::callStaticObjectMethod(
        "org/mavlink/qgroundcontrol/SecurityHelper",
        "hmacPassword",
        "([B)[B",
        passwordBytes);

    QByteArray result;
    if (resultObj.isValid()) {
        jbyteArray jArray = resultObj.object<jbyteArray>();
        if (jArray) {
            jint size = env->GetArrayLength(jArray);
            jbyte* elements = env->GetByteArrayElements(jArray, nullptr);
            if (elements) {
                result = QByteArray(reinterpret_cast<const char*>(elements), size);
                env->ReleaseByteArrayElements(jArray, elements, JNI_ABORT);
            }
        }
    }

    env->DeleteLocalRef(passwordBytes);

    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        return QByteArray();
    }

    return result;
}

static bool androidDeleteKeystore()
{
    QAndroidJniEnvironment env;

    jboolean ok = QAndroidJniObject::callStaticMethod<jboolean>(
        "org/mavlink/qgroundcontrol/SecurityHelper",
        "deleteKeystore",
        "()Z");

    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        return false;
    }

    return ok;
}

#endif

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

    if (!validatePINStrength(pin).isEmpty()) {
        return false;
    }
    
    QByteArray password = pin.toUtf8();
    
    // On Android: HMAC password using Keystore key (key never leaves Keystore)
    // On other platforms: use password as-is
    QByteArray peppered = password;
#ifdef Q_OS_ANDROID
    if (!m_keystoreInitialized && !initializeKeystore()) {
        qWarning() << "[SecurityManager] Keystore initialization failed during setPin";
        OPENSSL_cleanse(password.data(), password.size());
        return false;
    }

    peppered = androidHmacPassword(password);
    if (peppered.isEmpty()) {
        qWarning() << "[SecurityManager] Keystore HMAC failed during setPin";
        OPENSSL_cleanse(password.data(), password.size());
        return false;
    }
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
    s.setValue("failedAttempts_login", 0);
    s.setValue("lockoutUntil_login", 0);
    s.remove("failedAttempts");
    s.remove("lockoutUntil");
#ifdef Q_OS_ANDROID
    s.setValue("useKeystore", true);  // Flag that Keystore HMAC was used
#endif
    s.endGroup();
    s.sync();

    // Wipe sensitive data from memory
    OPENSSL_cleanse(password.data(), password.size());
    if (peppered != password) OPENSSL_cleanse(peppered.data(), peppered.size());
    OPENSSL_cleanse(dk.data(), dk.size());
    emit lockoutClearedForScope(QStringLiteral("login"));
    emit lockoutCleared();
    return true;
}

QString SecurityManager::generateAndStoreRecoveryKey()
{
    static const int RECOVERY_KEY_LENGTH = 24;
    static const char kAlphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

    QByteArray random = randomBytes(RECOVERY_KEY_LENGTH);
    if (random.size() != RECOVERY_KEY_LENGTH) {
        qWarning() << "[SecurityManager] Failed to generate random bytes for recovery key";
        return QString();
    }

    QByteArray rawKey;
    rawKey.resize(RECOVERY_KEY_LENGTH);
    for (int i = 0; i < RECOVERY_KEY_LENGTH; ++i) {
        const unsigned char v = static_cast<unsigned char>(random.at(i));
        rawKey[i] = kAlphabet[v % 26];
    }

    QByteArray password = rawKey;

    QByteArray peppered = password;
#ifdef Q_OS_ANDROID
    if (!m_keystoreInitialized && !initializeKeystore()) {
        qWarning() << "[SecurityManager] Keystore initialization failed during recovery key generation";
        OPENSSL_cleanse(password.data(), password.size());
        OPENSSL_cleanse(rawKey.data(), rawKey.size());
        return QString();
    }

    peppered = androidHmacPassword(password);
    if (peppered.isEmpty()) {
        qWarning() << "[SecurityManager] Keystore HMAC failed during recovery key generation";
        OPENSSL_cleanse(password.data(), password.size());
        OPENSSL_cleanse(rawKey.data(), rawKey.size());
        return QString();
    }
#endif

    QByteArray salt = randomBytes(SALT_LEN);
    if (salt.isEmpty()) {
        qWarning() << "[SecurityManager] Failed to generate recovery key salt";
        OPENSSL_cleanse(password.data(), password.size());
        OPENSSL_cleanse(rawKey.data(), rawKey.size());
        if (peppered != password) OPENSSL_cleanse(peppered.data(), peppered.size());
        return QString();
    }

    const int it = DEFAULT_ITERATIONS;
    QByteArray dk = deriveKey(peppered, salt, it, DK_LEN);
    if (dk.isEmpty()) {
        qWarning() << "[SecurityManager] Failed to derive recovery key";
        OPENSSL_cleanse(password.data(), password.size());
        OPENSSL_cleanse(rawKey.data(), rawKey.size());
        if (peppered != password) OPENSSL_cleanse(peppered.data(), peppered.size());
        return QString();
    }

    QSettings s;
    s.beginGroup("SecurityManager");
    s.setValue("recoveryKdf", "PBKDF2-HMAC-SHA256");
    s.setValue("recoveryIterations", it);
    s.setValue("recoverySalt", salt.toBase64());
    s.setValue("recoveryDerived", dk.toBase64());
#ifdef Q_OS_ANDROID
    s.setValue("recoveryUseKeystore", true);
#endif
    s.endGroup();
    s.sync();

    QString formatted;
    formatted.reserve(RECOVERY_KEY_LENGTH + 15);
    for (int i = 0; i < RECOVERY_KEY_LENGTH; ++i) {
        formatted.append(QChar::fromLatin1(rawKey.at(i)));
        if (((i + 1) % 4) == 0 && i != (RECOVERY_KEY_LENGTH - 1)) {
            formatted.append(QStringLiteral(" - "));
        }
    }

    OPENSSL_cleanse(password.data(), password.size());
    OPENSSL_cleanse(rawKey.data(), rawKey.size());
    if (peppered != password) OPENSSL_cleanse(peppered.data(), peppered.size());
    OPENSSL_cleanse(dk.data(), dk.size());

    return formatted;
}

bool SecurityManager::verifyRecoveryKey(const QString &recoveryKey)
{
    QSettings s;
    s.beginGroup("SecurityManager");
    if (!s.contains("recoveryDerived") || !s.contains("recoverySalt") || !s.contains("recoveryIterations")) {
        s.endGroup();
        return false;
    }

    const QByteArray dkStored = QByteArray::fromBase64(s.value("recoveryDerived").toByteArray());
    const QByteArray salt = QByteArray::fromBase64(s.value("recoverySalt").toByteArray());
    const int it = s.value("recoveryIterations", DEFAULT_ITERATIONS).toInt();
#ifdef Q_OS_ANDROID
    const bool useKeystore = s.value("recoveryUseKeystore", false).toBool();
#endif
    s.endGroup();

    QString normalized;
    normalized.reserve(24);
    const QString upper = recoveryKey.toUpper();
    for (int i = 0; i < upper.length(); ++i) {
        const QChar ch = upper.at(i);
        if (ch >= QLatin1Char('A') && ch <= QLatin1Char('Z')) {
            normalized.append(ch);
        }
    }

    if (normalized.length() != 24) {
        return false;
    }

    QByteArray password = normalized.toUtf8();
    QByteArray peppered = password;

#ifdef Q_OS_ANDROID
    if (useKeystore) {
        if (!m_keystoreInitialized && !initializeKeystore()) {
            qWarning() << "[SecurityManager] Keystore initialization failed during verifyRecoveryKey";
            OPENSSL_cleanse(password.data(), password.size());
            return false;
        }

        peppered = androidHmacPassword(password);
        if (peppered.isEmpty()) {
            qWarning() << "[SecurityManager] Keystore HMAC failed during verifyRecoveryKey";
            OPENSSL_cleanse(password.data(), password.size());
            return false;
        }
    }
#endif

    QByteArray candidate = deriveKey(peppered, salt, it, dkStored.size());
    if (candidate.isEmpty()) {
        OPENSSL_cleanse(password.data(), password.size());
        if (peppered != password) OPENSSL_cleanse(peppered.data(), peppered.size());
        return false;
    }

    const bool ok = constantTimeCompare(candidate, dkStored);
    OPENSSL_cleanse(password.data(), password.size());
    if (peppered != password) OPENSSL_cleanse(peppered.data(), peppered.size());
    OPENSSL_cleanse(candidate.data(), candidate.size());

    return ok;
}

bool SecurityManager::hasStoredRecoveryKey() const
{
    QSettings s;
    s.beginGroup("SecurityManager");
    const bool ok = s.contains("recoveryDerived");
    s.endGroup();
    return ok;
}

bool SecurityManager::verifyRestorePhrase(const QString &input) const
{
    // Pre-computed: PBKDF2-HMAC-SHA256 Restore phrase)
    static const uint8_t RESTORE_SALT[16] = {
        0xAF, 0x1F, 0xCC, 0xE9, 0x01, 0xE0, 0x3D, 0x7F,
        0x46, 0x85, 0x42, 0x7C, 0x73, 0x69, 0x69, 0xFD
    };
    static const uint8_t RESTORE_HASH[32] = {
        0xCA, 0x31, 0x1B, 0x6A, 0xC3, 0xAF, 0xEB, 0x2F,
        0xEB, 0x6A, 0x8C, 0x7A, 0xBC, 0xB6, 0x4C, 0x19,
        0x55, 0xBD, 0x91, 0x7C, 0x2C, 0x41, 0x7E, 0x3B,
        0x10, 0x42, 0x8D, 0xA2, 0xCA, 0x99, 0xE6, 0x00
    };

    const QByteArray salt(reinterpret_cast<const char*>(RESTORE_SALT), sizeof(RESTORE_SALT));
    const QByteArray expected(reinterpret_cast<const char*>(RESTORE_HASH), sizeof(RESTORE_HASH));

    QByteArray password = input.trimmed().toUpper().toUtf8();
    QByteArray candidate = deriveKey(password, salt, 10000, static_cast<int>(expected.size()));
    OPENSSL_cleanse(password.data(), password.size());
    if (candidate.isEmpty()) return false;

    const bool ok = constantTimeCompare(candidate, expected);
    OPENSSL_cleanse(candidate.data(), candidate.size());
    return ok;
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
        if (!m_keystoreInitialized && !initializeKeystore()) {
            qWarning() << "[SecurityManager] Keystore initialization failed during verifyPin";
            OPENSSL_cleanse(password.data(), password.size());
            recordFailedAttempt();
            return false;
        }

        peppered = androidHmacPassword(password);
        if (peppered.isEmpty()) {
            qWarning() << "[SecurityManager] Keystore HMAC failed during verifyPin";
            OPENSSL_cleanse(password.data(), password.size());
            recordFailedAttempt();
            return false;
        }
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
    if (!ok) {
        recordFailedAttempt();
        SecurityLog::logEvent(QStringLiteral("Invalid PIN attempt (count=%1)").arg(failedAttempts()));
    } else {
        resetFailedAttempts();
        SecurityLog::logEvent(QStringLiteral("Login success"));
    }

    // Wipe sensitive data from memory
    OPENSSL_cleanse(password.data(), password.size());
    if (peppered != password) OPENSSL_cleanse(peppered.data(), peppered.size());
    OPENSSL_cleanse(candidate.data(), candidate.size());

    return ok;
}

namespace {
QString normalizedLockoutScope(const QString &scope)
{
    const QString trimmed = scope.trimmed().toLower();
    return trimmed.isEmpty() ? QStringLiteral("login") : trimmed;
}

QString failedAttemptsKey(const QString &scope)
{
    return QStringLiteral("failedAttempts_%1").arg(scope);
}

QString lockoutUntilKey(const QString &scope)
{
    return QStringLiteral("lockoutUntil_%1").arg(scope);
}
}

void SecurityManager::recordFailedAttempt()
{
    recordFailedAttemptForScope(QStringLiteral("login"));
}

void SecurityManager::recordFailedAttemptForScope(const QString &scope)
{
    const QString normalizedScope = normalizedLockoutScope(scope);

    QSettings s;
    s.beginGroup("SecurityManager");
    const QString attemptsKey = failedAttemptsKey(normalizedScope);
    const QString untilKey = lockoutUntilKey(normalizedScope);
    int attempts = s.value(attemptsKey, 0).toInt();
    attempts += 1;
    s.setValue(attemptsKey, attempts);

    // Exponential lockout: start lockout after 5 attempts, then increase exponentially
    if (attempts >= 5) {
        // Base lockout time: 10 seconds
        const long long BASE_LOCKOUT_MS = 10 * 1000;
        // Exponential multiplier: 2^(attempts - 5)
        long long multiplier = 1LL << (attempts - 5); // left shift = 2^(attempts-5)
        long long lockoutDuration = BASE_LOCKOUT_MS * multiplier;

        qint64 until = QDateTime::currentMSecsSinceEpoch() + lockoutDuration;
        s.setValue(untilKey, until);

        SecurityLog::logEvent(QStringLiteral("Lockout [%1] until %2 after %3 failed attempts")
                               .arg(normalizedScope)
                               .arg(QDateTime::fromMSecsSinceEpoch(until).toString(Qt::ISODate))
                               .arg(attempts));

        // Notify QML/UI immediately that a lockout period started
        emit lockoutStartedForScope(normalizedScope, until);
        if (normalizedScope == QStringLiteral("login")) {
            emit lockoutStarted(until);
        }
    }
    s.endGroup();
    s.sync();
}

void SecurityManager::resetFailedAttempts()
{
    resetFailedAttemptsForScope(QStringLiteral("login"));
}

void SecurityManager::resetFailedAttemptsForScope(const QString &scope)
{
    const QString normalizedScope = normalizedLockoutScope(scope);

    QSettings s;
    s.beginGroup("SecurityManager");
    const QString attemptsKey = failedAttemptsKey(normalizedScope);
    const QString untilKey = lockoutUntilKey(normalizedScope);
    const int previousAttempts = s.value(attemptsKey, 0).toInt();
    const qint64 previousLockout = s.value(untilKey, 0).toLongLong();
    s.setValue(attemptsKey, 0);
    s.setValue(untilKey, 0);
    s.endGroup();
    s.sync();

    if (previousAttempts > 0 || previousLockout > 0) {
        SecurityLog::logEvent(QStringLiteral("Failed attempts reset [%1]; lockout cleared").arg(normalizedScope));
    }

    // Notify UI that lockout has been cleared
    emit lockoutClearedForScope(normalizedScope);
    if (normalizedScope == QStringLiteral("login")) {
        emit lockoutCleared();
    }
}

int SecurityManager::failedAttempts() const
{
    return failedAttemptsForScope(QStringLiteral("login"));
}

int SecurityManager::failedAttemptsForScope(const QString &scope) const
{
    const QString normalizedScope = normalizedLockoutScope(scope);

    QSettings s;
    s.beginGroup("SecurityManager");
    const int attempts = s.value(failedAttemptsKey(normalizedScope), 0).toInt();
    s.endGroup();
    return attempts;
}

qint64 SecurityManager::lockoutUntil() const
{
    return lockoutUntilForScope(QStringLiteral("login"));
}

qint64 SecurityManager::lockoutUntilForScope(const QString &scope) const
{
    const QString normalizedScope = normalizedLockoutScope(scope);

    QSettings s;
    s.beginGroup("SecurityManager");
    const qint64 until = s.value(lockoutUntilKey(normalizedScope), 0).toLongLong();
    s.endGroup();
    return until;
}

bool SecurityManager::isLocked() const
{
    return isLockedForScope(QStringLiteral("login"));
}

bool SecurityManager::isLockedForScope(const QString &scope) const
{
    const qint64 until = lockoutUntilForScope(scope);
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
    SecurityLog::logEvent(QStringLiteral("Security restore executed: cleared all stored security credentials"));

    QSettings s;
    s.beginGroup("SecurityManager");
    s.remove("");
    s.endGroup();
    s.sync();
    
    // Also clear Keystore on Android
    clearKeystore();
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

bool SecurityManager::hasRepeatedNumericBlocks(const QString &pin) const
{
    int pinLength = pin.length();
    // Repeated digit pairs pattern (e.g., 112233, 445566)
    if (pinLength >= 6 && (pinLength % 2) == 0) {
        bool isRepeatedPairPattern = true;
        for (int i = 0; i < pinLength; i += 2) {
            if (pin.at(i) != pin.at(i + 1)) {
                isRepeatedPairPattern = false;
                break;
            }
        }
        if (isRepeatedPairPattern) {
            return true;
        }
    }
    // Repeated numeric blocks (e.g., 121212, 123123)
    for (int blockLength = 2; blockLength <= (pinLength / 2); ++blockLength) {
        if ((pinLength % blockLength) != 0) {
            continue;
        }

        const QString block = pin.left(blockLength);
        bool isRepeatedBlock = true;

        for (int start = blockLength; start < pinLength; start += blockLength) {
            if (pin.mid(start, blockLength) != block) {
                isRepeatedBlock = false;
                break;
            }
        }

        if (isRepeatedBlock) {
            return true;
        }
    }

    return false;
}

QString SecurityManager::validatePINStrength(const QString &pin) const
{
    // Check if PIN contains only digits
    if (!hasOnlyDigits(pin)) {
        return "PIN must contain only digits";
    }

    if (hasRepeatingDigits(pin)) {
        return "PIN cannot be all same digits";
    }
    if (hasSequentialDigits(pin)) {
        return "PIN cannot be sequential";
    }
    if (hasRepeatedNumericBlocks(pin)) {
        return "PIN cannot contain repeated numeric patterns";
    }
    return ""; // empty string = valid
}

//-------------------------------------------------------------------------
//-- Keystore Management (Android - Hardware-Backed HMAC Key)

bool SecurityManager::initializeKeystore()
{
#ifdef Q_OS_ANDROID
    if (!androidIsKeystoreAvailable()) {
        qWarning() << "[SecurityManager] Android Keystore not available";
        return false;
    }

    // Prefer using the Java helper if present (it handles KeyGenParameterSpec construction).
    QAndroidJniEnvironment env;
    jboolean ok = QAndroidJniObject::callStaticMethod<jboolean>(
        "org/mavlink/qgroundcontrol/SecurityHelper",
        "initializeKeystore",
        "()Z");

    if (env->ExceptionCheck()) {
        qWarning() << "[SecurityManager] Exception calling SecurityHelper.initializeKeystore()";
        env->ExceptionDescribe();
        env->ExceptionClear();
        m_keystoreInitialized = false;
    } else {
        m_keystoreInitialized = ok;
    }

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
    if (!androidDeleteKeystore()) {
        qWarning() << "[SecurityManager] Failed to delete Keystore key";
    } else {
        qDebug() << "[SecurityManager] Keystore key deleted";
    }
    m_keystoreInitialized = false;
#endif
}