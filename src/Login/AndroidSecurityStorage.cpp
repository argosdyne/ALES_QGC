// AndroidSecurityStorage.cpp
// Android Keystore integration using hardware-backed secret key for HMAC
// Key never leaves Keystore, only HMAC results are returned

#include "AndroidSecurityStorage.h"

#ifdef Q_OS_ANDROID
#include <QAndroidJniEnvironment>
#include <QAndroidJniObject>
#include <QDebug>

const char* const AndroidSecurityStorage::KEYSTORE_ALIAS = "qgc_pepper_key";
const char* const AndroidSecurityStorage::PROVIDER_NAME = "AndroidKeyStore";

bool AndroidSecurityStorage::isKeystoreAvailable()
{
    // Check Android 6+ (API 23)
    QAndroidJniObject buildVersion = QAndroidJniObject::getStaticField<jint>(
        "android/os/Build$VERSION", "SDK_INT");
    int apiLevel = buildVersion;
    
    qDebug() << "[AndroidSecurityStorage] Android API Level:" << apiLevel;
    return apiLevel >= 23;
}

bool AndroidSecurityStorage::initializeKeystore()
{
    if (!isKeystoreAvailable()) {
        qWarning() << "[AndroidSecurityStorage] Keystore not available";
        return false;
    }

    QAndroidJniEnvironment env;
    
    try {
        // Get or create KeyStore instance
        QAndroidJniObject keyStore = QAndroidJniObject::callStaticObjectMethod(
            "java/security/KeyStore",
            "getInstance",
            "(Ljava/lang/String;)Ljava/security/KeyStore;",
            QAndroidJniObject::fromString(PROVIDER_NAME).object());
        
        if (!keyStore.isValid()) {
            qWarning() << "[AndroidSecurityStorage] Failed to get KeyStore";
            return false;
        }

        // Load the KeyStore (required before first use)
        keyStore.callMethod<void>("load", "(Ljava/security/KeyStore$LoadStoreParameter;)V", nullptr);

        // Check if key already exists
        QAndroidJniObject alias = QAndroidJniObject::fromString(KEYSTORE_ALIAS);
        bool keyExists = keyStore.callMethod<jboolean>("containsAlias", "(Ljava/lang/String;)Z", alias.object());
        
        if (keyExists) {
            qDebug() << "[AndroidSecurityStorage] Keystore key already exists";
            return true;
        }

        // Create new symmetric key for HMAC-SHA256
        // Get PURPOSE_SIGN constant from KeyProperties
        jint purposeSign = QAndroidJniObject::getStaticField<jint>(
            "android/security/keystore/KeyProperties", "PURPOSE_SIGN");
        
        QAndroidJniObject keyGenParams = QAndroidJniObject(
            "android/security/keystore/KeyGenParameterSpec$Builder",
            "(Ljava/lang/String;I)V",
            alias.object(),
            purposeSign);

        // Set algorithm
        keyGenParams = keyGenParams.callObjectMethod(
            "setKeySize",
            "(I)Landroid/security/keystore/KeyGenParameterSpec$Builder;",
            256);  // 256-bit key

        // Create array of digests for setDigests([Ljava/lang/String;)
        QAndroidJniObject digestSHA256 = QAndroidJniObject::getStaticObjectField(
            "android/security/keystore/KeyProperties", 
            "DIGEST_SHA256", 
            "Ljava/lang/String;");
        
        jobjectArray digestArray = env->NewObjectArray(
            1,  // array size: 1 element
            env->FindClass("java/lang/String"),
            nullptr);
        env->SetObjectArrayElement(digestArray, 0, digestSHA256.object<jobject>());
        
        keyGenParams = keyGenParams.callObjectMethod(
            "setDigests",
            "([Ljava/lang/String;)Landroid/security/keystore/KeyGenParameterSpec$Builder;",
            digestArray);
        
        env->DeleteLocalRef(digestArray);

        // Build the spec
        QAndroidJniObject spec = keyGenParams.callObjectMethod(
            "build",
            "()Landroid/security/keystore/KeyGenParameterSpec;");

        if (!spec.isValid()) {
            qWarning() << "[AndroidSecurityStorage] Failed to build KeyGenParameterSpec";
            return false;
        }

        // Generate the key
        QAndroidJniObject keyGen = QAndroidJniObject::callStaticObjectMethod(
            "javax/crypto/KeyGenerator",
            "getInstance",
            "(Ljava/lang/String;Ljava/lang/String;)Ljavax/crypto/KeyGenerator;",
            QAndroidJniObject::fromString("HmacSHA256").object(),
            QAndroidJniObject::fromString(PROVIDER_NAME).object());

        if (!keyGen.isValid()) {
            qWarning() << "[AndroidSecurityStorage] Failed to get KeyGenerator";
            return false;
        }

        keyGen.callMethod<void>("init", "(Landroid/security/keystore/KeyGenParameterSpec;)V", spec.object());

        QAndroidJniObject key = keyGen.callObjectMethod(
            "generateKey",
            "()Ljavax/crypto/SecretKey;");

        if (!key.isValid()) {
            qWarning() << "[AndroidSecurityStorage] Failed to generate key";
            return false;
        }

        qDebug() << "[AndroidSecurityStorage] Keystore key created successfully";
        return true;

    } catch (const std::exception &e) {
        qWarning() << "[AndroidSecurityStorage] Exception initializing keystore:" << QString::fromStdString(e.what());
        return false;
    }
}

QByteArray AndroidSecurityStorage::hmacPassword(const QByteArray &password)
{
    if (password.isEmpty()) {
        qWarning() << "[AndroidSecurityStorage] Cannot HMAC empty password";
        return QByteArray();
    }

    if (!isKeystoreAvailable()) {
        qWarning() << "[AndroidSecurityStorage] Keystore not available, returning password as-is";
        return QByteArray();
    }

    QAndroidJniEnvironment env;
    
    try {
        // Get KeyStore instance
        QAndroidJniObject keyStore = QAndroidJniObject::callStaticObjectMethod(
            "java/security/KeyStore",
            "getInstance",
            "(Ljava/lang/String;)Ljava/security/KeyStore;",
            QAndroidJniObject::fromString(PROVIDER_NAME).object());

        keyStore.callMethod<void>("load", "(Ljava/security/KeyStore$LoadStoreParameter;)V", nullptr);

        // Get the key (never leaves Keystore)
        QAndroidJniObject alias = QAndroidJniObject::fromString(KEYSTORE_ALIAS);
        QAndroidJniObject key = keyStore.callObjectMethod(
            "getKey",
            "(Ljava/lang/String;[C)Ljava/security/Key;",
            alias.object(),
            nullptr);  // No password needed

        if (!key.isValid()) {
            qWarning() << "[AndroidSecurityStorage] Key not found in Keystore";
            return password;  // Fallback
        }

        // Get Mac instance and initialize with the key
        QAndroidJniObject mac = QAndroidJniObject::callStaticObjectMethod(
            "javax/crypto/Mac",
            "getInstance",
            "(Ljava/lang/String;Ljava/lang/String;)Ljavax/crypto/Mac;",
            QAndroidJniObject::fromString("HmacSHA256").object(),
            QAndroidJniObject::fromString(PROVIDER_NAME).object());

        if (!mac.isValid()) {
            qWarning() << "[AndroidSecurityStorage] Failed to get Mac instance";
            return password;  // Fallback
        }

        mac.callMethod<void>("init", "(Ljava/security/Key;)V", key.object());

        // Create byte array from password
        jbyteArray passwordBytes = env->NewByteArray(password.size());
        env->SetByteArrayRegion(passwordBytes, 0, password.size(), (jbyte*)password.constData());

        // Perform HMAC
        QAndroidJniObject resultArray = mac.callObjectMethod(
            "doFinal",
            "([B)[B",
            passwordBytes);

        // Convert result to QByteArray
        jbyteArray jArray = resultArray.object<jbyteArray>();
        jint arraySize = env->GetArrayLength(jArray);
        jbyte* elements = env->GetByteArrayElements(jArray, nullptr);
        
        QByteArray result(reinterpret_cast<const char*>(elements), arraySize);
        
        env->ReleaseByteArrayElements(jArray, elements, JNI_ABORT);
        env->DeleteLocalRef(passwordBytes);

        qDebug() << "[AndroidSecurityStorage] Password HMAC-ed successfully (" << result.size() << " bytes)";
        return result;

    } catch (const std::exception &e) {
        qWarning() << "[AndroidSecurityStorage] Exception HMACing password:" << QString::fromStdString(e.what());
        return QByteArray();   // return empty QByteArray
    }
}

bool AndroidSecurityStorage::deleteKeystore()
{
    if (!isKeystoreAvailable()) {
        return false;
    }

    QAndroidJniEnvironment env;
    
    try {
        QAndroidJniObject keyStore = QAndroidJniObject::callStaticObjectMethod(
            "java/security/KeyStore",
            "getInstance",
            "(Ljava/lang/String;)Ljava/security/KeyStore;",
            QAndroidJniObject::fromString(PROVIDER_NAME).object());

        keyStore.callMethod<void>("load", "(Ljava/security/KeyStore$LoadStoreParameter;)V", nullptr);

        QAndroidJniObject alias = QAndroidJniObject::fromString(KEYSTORE_ALIAS);
        keyStore.callMethod<void>("deleteEntry", "(Ljava/lang/String;)V", alias.object());

        qDebug() << "[AndroidSecurityStorage] Keystore key deleted successfully";
        return true;

    } catch (const std::exception &e) {
        qWarning() << "[AndroidSecurityStorage] Exception deleting keystore key:" << QString::fromStdString(e.what());
        return false;
    }
}

#endif
