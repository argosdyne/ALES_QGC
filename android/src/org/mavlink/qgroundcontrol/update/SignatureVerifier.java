package org.mavlink.qgroundcontrol.update;

import android.content.Context;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.os.Build;
import android.util.Log;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

import org.mavlink.qgroundcontrol.update.USBUpdateManager.UpdateCandidate;
import org.mavlink.qgroundcontrol.update.USBUpdateManager.UpdateResult;

public final class SignatureVerifier {
    private static final String TAG = USBUpdateManager.LOG_TAG;

    private SignatureVerifier() { }

    public static UpdateResult verify(Context context, UpdateCandidate candidate) {
        Log.i(TAG, "SIG: starting signature verification");
        if (!USBUpdateManager.isPinnedCertificateConfigured()) {
            Log.w(TAG, "SIG: pinned certificate is not configured");
            return UpdateResult.failure("REJECTED_SIG",
                    "Pinned production certificate SHA-256 is not configured", candidate);
        }
        if (context == null || candidate == null || candidate.apkFile == null) {
            Log.w(TAG, "SIG: context, candidate, or apkFile is null");
            return UpdateResult.failure("REJECTED_SIG",
                    "APK candidate is not available for signature verification", candidate);
        }

        int flags = Build.VERSION.SDK_INT >= 28
                ? PackageManager.GET_SIGNING_CERTIFICATES | PackageManager.GET_SIGNATURES
                : PackageManager.GET_SIGNATURES;
        Log.i(TAG, "SIG: reading package signature info flags=" + flags
                + " sdk=" + Build.VERSION.SDK_INT
                + " apk=" + candidate.apkFile.getAbsolutePath());
        PackageInfo packageInfo = context.getPackageManager().getPackageArchiveInfo(
                candidate.apkFile.getAbsolutePath(), flags);
        if (packageInfo == null) {
            Log.w(TAG, "SIG: PackageManager returned null signature metadata");
            return UpdateResult.failure("REJECTED_SIG",
                    "APK signature metadata could not be read", candidate);
        }

        Signature[] signatures = getSignatures(packageInfo);
        if ((signatures == null || signatures.length == 0) && Build.VERSION.SDK_INT >= 28) {
            Log.w(TAG, "SIG: no signers from GET_SIGNING_CERTIFICATES; retrying GET_SIGNATURES");
            PackageInfo legacyPackageInfo = context.getPackageManager().getPackageArchiveInfo(
                    candidate.apkFile.getAbsolutePath(), PackageManager.GET_SIGNATURES);
            signatures = legacyPackageInfo != null ? legacyPackageInfo.signatures : null;
        }
        if (signatures == null || signatures.length == 0) {
            Log.w(TAG, "SIG: no APK content signers found");
            return UpdateResult.failure("REJECTED_SIG",
                    "APK does not contain signing certificates", candidate);
        }

        String expected = normalizeFingerprint(USBUpdateManager.PINNED_CERT_SHA256);
        Log.i(TAG, "SIG: signerCount=" + signatures.length
                + " expectedFingerprint=" + shortHash(expected));
        for (int i = 0; i < signatures.length; i++) {
            String actual = sha256(signatures[i].toByteArray());
            Log.i(TAG, "SIG: signer[" + i + "] fingerprint=" + shortHash(actual));
            if (expected.equals(actual)) {
                candidate.signerSha256 = actual;
                candidate.signerDisplayName = USBUpdateManager.SIGNER_DISPLAY_NAME;
                Log.i(TAG, "SIG: signature verification passed");
                return UpdateResult.success("SIGNATURE_OK",
                        "APK signing certificate verified", candidate);
            }
        }

        Log.w(TAG, "SIG: signature verification failed, no signer matched pinned cert");
        return UpdateResult.failure("REJECTED_SIG",
                "APK is not signed by the configured EasyGripper production key", candidate);
    }

    private static Signature[] getSignatures(PackageInfo packageInfo) {
        if (Build.VERSION.SDK_INT >= 28 && packageInfo.signingInfo != null) {
            Log.i(TAG, "SIG: signingInfo present multipleSigners="
                    + packageInfo.signingInfo.hasMultipleSigners()
                    + " pastCerts="
                    + packageInfo.signingInfo.hasPastSigningCertificates());
            Signature[] currentSigners = packageInfo.signingInfo.getApkContentsSigners();
            if (currentSigners != null && currentSigners.length > 0) {
                return currentSigners;
            }
            Signature[] signingHistory = packageInfo.signingInfo.getSigningCertificateHistory();
            if (signingHistory != null && signingHistory.length > 0) {
                Log.i(TAG, "SIG: using signing certificate history count=" + signingHistory.length);
                return signingHistory;
            }
        }
        Log.i(TAG, "SIG: using legacy signatures count="
                + (packageInfo.signatures != null ? packageInfo.signatures.length : 0));
        return packageInfo.signatures;
    }

    private static String sha256(byte[] bytes) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] result = digest.digest(bytes);
            StringBuilder builder = new StringBuilder(result.length * 2);
            for (int i = 0; i < result.length; i++) {
                builder.append(String.format("%02x", result[i] & 0xff));
            }
            return builder.toString();
        } catch (NoSuchAlgorithmException e) {
            return "";
        }
    }

    private static String normalizeFingerprint(String fingerprint) {
        return fingerprint == null
                ? ""
                : fingerprint.replace(":", "").replace(" ", "").toLowerCase(java.util.Locale.US);
    }

    private static String shortHash(String hash) {
        if (hash == null) {
            return "null";
        }
        return hash.length() > 16 ? hash.substring(0, 16) + "..." : hash;
    }
}
