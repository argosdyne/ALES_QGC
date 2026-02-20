// AndroidSecurityStorage.h
// Android Keystore integration for HMAC-ing password using hardware-backed keys
// Key never leaves the Keystore, only signatures/HMAC results are exported

#pragma once

#include <QString>
#include <QByteArray>

#ifdef Q_OS_ANDROID
#include <jni.h>

class AndroidSecurityStorage
{
public:
    // Sign/HMAC password using Keystore-backed key
    // Input: password bytes
    // Output: HMAC result (can be used as peppered password input to PBKDF2)
    // Key stays in Keystore, never exported
    static QByteArray hmacPassword(const QByteArray &password);
    
    // Initialize Keystore key (create if not exists)
    // Should be called once at app startup
    static bool initializeKeystore();
    
    // Delete Keystore key (e.g., when clearing PIN)
    static bool deleteKeystore();
    
    // Check if Android Keystore is available (API 23+)
    static bool isKeystoreAvailable();
    
private:
    static const char* const KEYSTORE_ALIAS;
    static const char* const PROVIDER_NAME;
};

#else
// Stub untuk non-Android platforms
class AndroidSecurityStorage
{
public:
    static QByteArray hmacPassword(const QByteArray &password) { return password; }  // Fallback: no HMAC
    static bool initializeKeystore() { return true; }
    static bool deleteKeystore() { return true; }
    static bool isKeystoreAvailable() { return false; }
};
#endif
