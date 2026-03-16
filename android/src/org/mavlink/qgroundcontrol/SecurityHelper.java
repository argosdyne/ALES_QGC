package org.mavlink.qgroundcontrol;

import android.os.Build;
import android.security.keystore.KeyProperties;
import android.security.keystore.KeyGenParameterSpec;

import javax.crypto.KeyGenerator;
import javax.crypto.Mac;
import java.security.Key;
import java.security.KeyStore;

/**
 * SecurityHelper - Java wrapper for Android Keystore operations
 * Handles all Keystore logic on Java side, keeping C++ code clean
 */
public class SecurityHelper {
    private static final String KEYSTORE_ALIAS = "qgc_pepper_key";
    private static final String PROVIDER_NAME = "AndroidKeyStore";
    private static final int KEY_SIZE = 256;

    private static Mac createHmacMac() throws Exception {
        try {
            return Mac.getInstance("HmacSHA256");
        } catch (Exception first) {
            return Mac.getInstance("HMACSHA256");
        }
    }

    /**
     * Check if Android Keystore is available (API 23+)
     */
    public static boolean isKeystoreAvailable() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.M;  // API 23
    }

    /**
     * Initialize Keystore and create HMAC-SHA256 key if not exists
     * @return true if successful, false otherwise
     */
    public static boolean initializeKeystore() {
        if (!isKeystoreAvailable()) {
            android.util.Log.w("SecurityHelper", "Keystore not available (API < 23)");
            return false;
        }

        try {
            KeyStore keyStore = KeyStore.getInstance(PROVIDER_NAME);
            keyStore.load(null);

            // Check if key already exists
            if (keyStore.containsAlias(KEYSTORE_ALIAS)) {
                android.util.Log.d("SecurityHelper", "Keystore key already exists");
                return true;
            }

            // Create symmetric key for HMAC-SHA256
            KeyGenParameterSpec spec = new KeyGenParameterSpec.Builder(
                    KEYSTORE_ALIAS,
                    KeyProperties.PURPOSE_SIGN | KeyProperties.PURPOSE_VERIFY)
                    .setKeySize(KEY_SIZE)
                    .setDigests(KeyProperties.DIGEST_SHA256)
                    .setUserAuthenticationRequired(false)
                    .build();

            KeyGenerator keyGen = KeyGenerator.getInstance("HmacSHA256", PROVIDER_NAME);
            keyGen.init(spec);
            keyGen.generateKey();

            android.util.Log.d("SecurityHelper", "Keystore key created successfully");
            return true;

        } catch (Exception e) {
            android.util.Log.e("SecurityHelper", "Error initializing keystore: " + e.getMessage(), e);
            return false;
        }
    }

    /**
     * Perform HMAC-SHA256 on password using Keystore key
     * @param password password bytes to HMAC
     * @return HMAC result, or empty array if error
     */
    public static byte[] hmacPassword(byte[] password) {
        if (password == null || password.length == 0) {
            android.util.Log.w("SecurityHelper", "Cannot HMAC empty password");
            return new byte[0];
        }

        if (!isKeystoreAvailable()) {
            android.util.Log.w("SecurityHelper", "Keystore not available");
            return new byte[0];
        }

        try {
            KeyStore keyStore = KeyStore.getInstance(PROVIDER_NAME);
            keyStore.load(null);

            Key key = keyStore.getKey(KEYSTORE_ALIAS, null);
            if (key == null) {
                android.util.Log.w("SecurityHelper", "Key not found in Keystore, attempting reinitialize");
                if (!initializeKeystore()) {
                    return new byte[0];
                }
                keyStore = KeyStore.getInstance(PROVIDER_NAME);
                keyStore.load(null);
                key = keyStore.getKey(KEYSTORE_ALIAS, null);
                if (key == null) {
                    android.util.Log.e("SecurityHelper", "Key still not found after reinitialize");
                    return new byte[0];
                }
            }

            Mac mac = createHmacMac();
            mac.init(key);
            android.util.Log.d("SecurityHelper", "HMAC start len=" + password.length + " provider=" + mac.getProvider().getName());
            byte[] result = mac.doFinal(password);
            android.util.Log.d("SecurityHelper", "HMAC ok resultLen=" + result.length);
            return result;

        } catch (Exception e) {
            android.util.Log.e("SecurityHelper", "Error HMACing password: " + e.getMessage(), e);
            return new byte[0];
        }
    }

    /**
     * Delete Keystore key entry
     * @return true if successful, false otherwise
     */
    public static boolean deleteKeystore() {
        if (!isKeystoreAvailable()) {
            return false;
        }

        try {
            KeyStore keyStore = KeyStore.getInstance(PROVIDER_NAME);
            keyStore.load(null);
            keyStore.deleteEntry(KEYSTORE_ALIAS);

            android.util.Log.d("SecurityHelper", "Keystore key deleted successfully");
            return true;

        } catch (Exception e) {
            android.util.Log.e("SecurityHelper", "Error deleting keystore key: " + e.getMessage(), e);
            return false;
        }
    }
}
