package org.mavlink.qgroundcontrol.update;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.PendingIntent;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.PackageInstaller;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;
import android.widget.Toast;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

public final class USBUpdateManager {
    public static final String LOG_TAG = "QGC_USBUpdate";
    public static final String ACTION_TEST_SCAN =
            "org.mavlink.qgroundcontrol.update.TEST_SCAN";
    public static final String ACTION_INSTALL_COMMIT_RESULT =
            "org.mavlink.qgroundcontrol.update.INSTALL_COMMIT_RESULT";
    public static final String EXTRA_SCAN_PATH = "scan_path";
    public static final String EXTRA_INSTALL_APK_PATH = "install_apk_path";
    public static final String EXTRA_INSTALL_APK_SHA256 = "install_apk_sha256";
    public static final String EXTRA_INSTALL_TO_VERSION = "install_to_version";
    public static final String APK_NAME_PREFIX = "ALES_QGC";
    public static final String SIGNER_DISPLAY_NAME = "EasyGripper Production Key";

    // EG-SEC-UPD-002 says "no APK found" should be silent in production.
    // Keep this enabled while field-testing the USB detection flow.
    public static final boolean SHOW_NO_APK_FOUND_DIALOG = true;

    // Set this to the SHA-256 fingerprint of the production signing certificate.
    // Debug/test keys intentionally fail until this is configured for that build.
    public static final String PINNED_CERT_SHA256 =
            "d7282edbe297a892b4c9e57ed8db946dc8724a430ab8b4c3b439f22c4ba0ee";

    private static final String TAG = LOG_TAG;
    private static final InstallGateway INSTALL_GATEWAY = new PackageInstallerGateway();

    private USBUpdateManager() { }

    public static void scanAndValidate(final Context context, File rootDir, Activity activity) {
        Log.i(TAG, "FLOW: scanAndValidate started rootPath="
                + (rootDir != null ? rootDir.getAbsolutePath() : "null")
                + " activityAvailable=" + (activity != null));
        showToast(activity, "USB detected. Scanning for QGC update...");
        UpdateAuditLogger.log(context, "SCAN_STARTED", null,
                rootDir != null ? rootDir.getAbsolutePath() : "null root path");

        UpdateResult scanResult = APKScanner.scan(rootDir);
        Log.i(TAG, "FLOW: scan result event=" + scanResult.event
                + " success=" + scanResult.success
                + " message=" + scanResult.message);
        if (!scanResult.success) {
            if (!"NO_APK_FOUND".equals(scanResult.event)) {
                UpdateAuditLogger.log(context, scanResult.event, scanResult.candidate, scanResult.message);
                showError(activity, scanResult.message);
            } else {
                Log.i(TAG, scanResult.message);
                if (SHOW_NO_APK_FOUND_DIALOG) {
                    showInfo(activity,
                            "No QGC Update Found",
                            "USB was detected, but no matching update APK was found.\n\nExpected file name:\n"
                                    + APK_NAME_PREFIX + "*.apk");
                }
            }
            return;
        }

        UpdateCandidate candidate = scanResult.candidate;
        Log.i(TAG, "FLOW: candidate apk="
                + (candidate.apkFile != null ? candidate.apkFile.getAbsolutePath() : "null")
                + " sha256File="
                + (candidate.sha256File != null ? candidate.sha256File.getAbsolutePath() : "null"));
        UpdateResult metadataResult = populateAndValidateMetadata(context, candidate);
        Log.i(TAG, "FLOW: metadata result event=" + metadataResult.event
                + " success=" + metadataResult.success
                + " message=" + metadataResult.message);
        if (!metadataResult.success) {
            reject(context, activity, metadataResult);
            return;
        }

        UpdateResult signatureResult = SignatureVerifier.verify(context, candidate);
        Log.i(TAG, "FLOW: signature result event=" + signatureResult.event
                + " success=" + signatureResult.success
                + " message=" + signatureResult.message);
        if (!signatureResult.success) {
            reject(context, activity, signatureResult);
            return;
        }

        UpdateResult hashResult = verifyHash(candidate);
        Log.i(TAG, "FLOW: hash result event=" + hashResult.event
                + " success=" + hashResult.success
                + " message=" + hashResult.message);
        if (!hashResult.success) {
            reject(context, activity, hashResult);
            return;
        }

        Log.i(TAG, "FLOW: VALIDATION_PASSED version=" + candidate.versionName
                + " versionCode=" + candidate.versionCode
                + " hash=" + candidate.shortSha256());
        UpdateAuditLogger.log(context, "VALIDATION_PASSED", candidate, "APK ready for confirmation");
        showConfirmation(context, activity, candidate);
    }

    public static boolean isPinnedCertificateConfigured() {
        return PINNED_CERT_SHA256 != null
                && PINNED_CERT_SHA256.length() > 0
                && !PINNED_CERT_SHA256.startsWith("REPLACE_WITH");
    }

    public static void handleInstallCommitResult(Context context, Intent intent) {
        int status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS,
                PackageInstaller.STATUS_FAILURE);
        String message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE);
        String apkPath = intent.getStringExtra(EXTRA_INSTALL_APK_PATH);
        String apkSha256 = intent.getStringExtra(EXTRA_INSTALL_APK_SHA256);
        String toVersion = intent.getStringExtra(EXTRA_INSTALL_TO_VERSION);

        UpdateCandidate candidate = new UpdateCandidate();
        candidate.apkFile = apkPath != null ? new File(apkPath) : null;
        candidate.apkSha256 = apkSha256;
        candidate.versionName = toVersion;

        Log.i(TAG, "INSTALL: commit callback status=" + status
                + " message=" + message
                + " apk=" + apkPath);

        if (status == PackageInstaller.STATUS_SUCCESS) {
            UpdateAuditLogger.log(context, "INSTALL_SUCCESS", candidate,
                    "PackageInstaller completed successfully");
        } else if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
            UpdateAuditLogger.log(context, "INSTALL_PENDING_USER_ACTION", candidate,
                    "PackageInstaller requires user confirmation");
            Intent confirmationIntent = intent.getParcelableExtra(Intent.EXTRA_INTENT);
            if (confirmationIntent != null) {
                confirmationIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                Log.i(TAG, "INSTALL: launching PackageInstaller user confirmation");
                context.startActivity(confirmationIntent);
            } else {
                Log.w(TAG, "INSTALL: pending user action without confirmation intent");
                UpdateAuditLogger.log(context, "INSTALL_FAILED", candidate,
                        "PackageInstaller requested user action without confirmation intent");
            }
        } else {
            UpdateAuditLogger.log(context, "INSTALL_FAILED", candidate,
                    message != null ? message : "PackageInstaller failed with status " + status);
        }
    }

    private static UpdateResult populateAndValidateMetadata(Context context, UpdateCandidate candidate) {
        Log.i(TAG, "META: starting metadata validation");
        if (context == null) {
            Log.w(TAG, "META: context is null");
            return UpdateResult.failure("REJECTED_PACKAGE", "Context is not available", candidate);
        }
        if (candidate == null || candidate.apkFile == null) {
            Log.w(TAG, "META: candidate or apkFile is null");
            return UpdateResult.failure("REJECTED_PACKAGE", "APK candidate is not available", candidate);
        }

        PackageManager packageManager = context.getPackageManager();
        Log.i(TAG, "META: reading archive info apk=" + candidate.apkFile.getAbsolutePath());
        PackageInfo archiveInfo = packageManager.getPackageArchiveInfo(
                candidate.apkFile.getAbsolutePath(), 0);
        if (archiveInfo == null) {
            Log.w(TAG, "META: PackageManager returned null archive info");
            return UpdateResult.failure("REJECTED_PACKAGE",
                    "APK package metadata could not be read", candidate);
        }

        candidate.packageName = archiveInfo.packageName;
        candidate.versionName = archiveInfo.versionName;
        candidate.versionCode = getVersionCode(archiveInfo);

        String expectedPackageName = context.getPackageName();
        Log.i(TAG, "META: archive package=" + candidate.packageName
                + " versionName=" + candidate.versionName
                + " versionCode=" + candidate.versionCode
                + " expectedPackage=" + expectedPackageName);
        if (!expectedPackageName.equals(candidate.packageName)) {
            Log.w(TAG, "META: package mismatch apkPackage=" + candidate.packageName
                    + " expectedPackage=" + expectedPackageName);
            return UpdateResult.failure("REJECTED_PACKAGE",
                    "APK package is " + candidate.packageName
                            + ", expected " + expectedPackageName, candidate);
        }

        try {
            PackageInfo currentInfo = packageManager.getPackageInfo(expectedPackageName, 0);
            candidate.currentVersionName = currentInfo.versionName;
            candidate.currentVersionCode = getVersionCode(currentInfo);
            Log.i(TAG, "META: installed versionName=" + candidate.currentVersionName
                    + " versionCode=" + candidate.currentVersionCode);
        } catch (PackageManager.NameNotFoundException e) {
            Log.w(TAG, "META: installed package metadata not found: " + e.getMessage());
            return UpdateResult.failure("REJECTED_PACKAGE",
                    "Installed package metadata could not be read", candidate);
        }

        if (candidate.versionCode <= candidate.currentVersionCode) {
            Log.w(TAG, "META: downgrade or same-version rejected apkVersionCode="
                    + candidate.versionCode
                    + " installedVersionCode=" + candidate.currentVersionCode);
            return UpdateResult.failure("REJECTED_DOWNGRADE",
                    "USB APK versionCode " + candidate.versionCode
                            + " is not newer than installed versionCode "
                            + candidate.currentVersionCode, candidate);
        }

        Log.i(TAG, "META: metadata validation passed");
        return UpdateResult.success("METADATA_OK", "APK package metadata verified", candidate);
    }

    private static long getVersionCode(PackageInfo info) {
        if (Build.VERSION.SDK_INT >= 28) {
            return info.getLongVersionCode();
        }
        return info.versionCode;
    }

    private static UpdateResult verifyHash(UpdateCandidate candidate) {
        try {
            Log.i(TAG, "HASH: reading expected hash from "
                    + (candidate.sha256File != null ? candidate.sha256File.getAbsolutePath() : "null"));
            String expected = HashVerifier.readExpectedSha256(candidate.sha256File);
            Log.i(TAG, "HASH: computing APK SHA-256 for "
                    + (candidate.apkFile != null ? candidate.apkFile.getAbsolutePath() : "null"));
            String actual = HashVerifier.computeSha256(candidate.apkFile);
            candidate.apkSha256 = actual;
            if (!HashVerifier.constantTimeEquals(expected, actual)) {
                Log.w(TAG, "HASH: mismatch expected=" + shortHash(expected)
                        + " actual=" + shortHash(actual));
                return UpdateResult.failure("REJECTED_HASH",
                        "Update rejected: package integrity check failed", candidate);
            }
            Log.i(TAG, "HASH: verified actual=" + shortHash(actual));
            return UpdateResult.success("HASH_OK", "APK SHA-256 verified", candidate);
        } catch (IOException e) {
            Log.w(TAG, "HASH: verification failed: " + e.getMessage());
            return UpdateResult.failure("REJECTED_HASH",
                    "Update rejected: " + e.getMessage(), candidate);
        }
    }

    private static void reject(Context context, Activity activity, UpdateResult result) {
        Log.w(TAG, "FLOW: rejecting update event=" + result.event
                + " message=" + result.message);
        UpdateAuditLogger.log(context, result.event, result.candidate, result.message);
        showError(activity, result.message);
    }

    private static void showConfirmation(final Context context,
                                         final Activity activity,
                                         final UpdateCandidate candidate) {
        if (activity == null) {
            UpdateAuditLogger.log(context, "INSTALL_WAITING_FOR_UI", candidate,
                    "No foreground QGC activity available to show confirmation dialog");
            Log.w(TAG, "No foreground activity available for update confirmation");
            return;
        }

        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Log.i(TAG, "UI: showing update confirmation dialog");
                String message = "Current version: " + safe(candidate.currentVersionName)
                        + "\nNew version: " + safe(candidate.versionName)
                        + "\nAPK SHA-256: " + candidate.shortSha256()
                        + "\nSigned by: " + safe(candidate.signerDisplayName);

                new AlertDialog.Builder(activity)
                        .setTitle("QGC Update Found")
                        .setMessage(message)
                        .setPositiveButton("INSTALL", new DialogInterface.OnClickListener() {
                            @Override
                            public void onClick(DialogInterface dialog, int which) {
                                Log.i(TAG, "UI: user tapped INSTALL");
                                UpdateResult installResult =
                                        INSTALL_GATEWAY.requestInstall(context, candidate);
                                Log.i(TAG, "INSTALL: result event=" + installResult.event
                                        + " success=" + installResult.success
                                        + " message=" + installResult.message);
                                UpdateAuditLogger.log(context, installResult.event,
                                        candidate, installResult.message);
                                Toast.makeText(activity, installResult.message,
                                        Toast.LENGTH_LONG).show();
                            }
                        })
                        .setNegativeButton("CANCEL", new DialogInterface.OnClickListener() {
                            @Override
                            public void onClick(DialogInterface dialog, int which) {
                                Log.i(TAG, "UI: user tapped CANCEL");
                                UpdateAuditLogger.log(context, "CANCELLED", candidate,
                                        "User cancelled update installation");
                            }
                        })
                        .show();
            }
        });
    }

    private static void showInfo(final Activity activity,
                                 final String title,
                                 final String message) {
        if (activity == null) {
            Log.i(TAG, "UI: info dialog skipped because activity is null title=" + title
                    + " message=" + message);
            return;
        }
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Log.i(TAG, "UI: showing info dialog title=" + title + " message=" + message);
                new AlertDialog.Builder(activity)
                        .setTitle(title)
                        .setMessage(message)
                        .setPositiveButton("OK", null)
                        .show();
            }
        });
    }

    private static void showError(final Activity activity, final String message) {
        if (activity == null) {
            Log.w(TAG, message);
            return;
        }
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Log.i(TAG, "UI: showing update rejection dialog message=" + message);
                new AlertDialog.Builder(activity)
                        .setTitle("QGC Update Rejected")
                        .setMessage(message)
                        .setPositiveButton("OK", null)
                        .show();
            }
        });
    }

    private static void showToast(final Activity activity, final String message) {
        if (activity == null) {
            Log.i(TAG, "UI: toast skipped because activity is null message=" + message);
            return;
        }
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Toast.makeText(activity, message, Toast.LENGTH_SHORT).show();
            }
        });
    }

    private static String safe(String value) {
        return value != null ? value : "";
    }

    private static String shortHash(String hash) {
        if (hash == null) {
            return "null";
        }
        return hash.length() > 16 ? hash.substring(0, 16) + "..." : hash;
    }

    public static final class UpdateCandidate {
        public File apkFile;
        public File sha256File;
        public String packageName;
        public String versionName;
        public long versionCode;
        public String currentVersionName;
        public long currentVersionCode;
        public String apkSha256;
        public String signerSha256;
        public String signerDisplayName;

        public String shortSha256() {
            if (apkSha256 == null) {
                return "";
            }
            return apkSha256.length() > 16 ? apkSha256.substring(0, 16) + "..." : apkSha256;
        }
    }

    public static final class UpdateResult {
        public final boolean success;
        public final String event;
        public final String message;
        public final UpdateCandidate candidate;

        private UpdateResult(boolean success, String event, String message, UpdateCandidate candidate) {
            this.success = success;
            this.event = event;
            this.message = message;
            this.candidate = candidate;
        }

        public static UpdateResult success(String event, String message, UpdateCandidate candidate) {
            return new UpdateResult(true, event, message, candidate);
        }

        public static UpdateResult failure(String event, String message, UpdateCandidate candidate) {
            return new UpdateResult(false, event, message, candidate);
        }
    }

    private interface InstallGateway {
        UpdateResult requestInstall(Context context, UpdateCandidate candidate);
    }

    private static final class PackageInstallerGateway implements InstallGateway {
        @Override
        public UpdateResult requestInstall(Context context, UpdateCandidate candidate) {
            if (context == null || candidate == null || candidate.apkFile == null) {
                return UpdateResult.failure("INSTALL_FAILED",
                        "Install request is missing context or APK file", candidate);
            }

            PackageInstaller.Session session = null;
            int sessionId = -1;
            try {
                PackageInstaller installer = context.getPackageManager().getPackageInstaller();
                PackageInstaller.SessionParams params =
                        new PackageInstaller.SessionParams(
                                PackageInstaller.SessionParams.MODE_FULL_INSTALL);
                params.setAppPackageName(candidate.packageName);

                sessionId = installer.createSession(params);
                session = installer.openSession(sessionId);
                streamApkIntoSession(session, candidate.apkFile);

                Intent callbackIntent = new Intent();
                callbackIntent.setClassName(context.getPackageName(),
                        "org.mavlink.qgroundcontrol.update.USBUpdateReceiver");
                callbackIntent.setAction(ACTION_INSTALL_COMMIT_RESULT);
                callbackIntent.putExtra(EXTRA_INSTALL_APK_PATH, candidate.apkFile.getAbsolutePath());
                callbackIntent.putExtra(EXTRA_INSTALL_APK_SHA256, candidate.apkSha256);
                callbackIntent.putExtra(EXTRA_INSTALL_TO_VERSION, candidate.versionName);

                PendingIntent pendingIntent = PendingIntent.getBroadcast(
                        context,
                        sessionId,
                        callbackIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT);

                Log.i(TAG, "INSTALL: committing PackageInstaller sessionId=" + sessionId
                        + " apk=" + candidate.apkFile.getAbsolutePath());
                session.commit(pendingIntent.getIntentSender());
                session.close();
                return UpdateResult.success("INSTALL_REQUESTED",
                        "Install request sent to Android PackageInstaller", candidate);
            } catch (Exception e) {
                Log.e(TAG, "INSTALL: PackageInstaller request failed", e);
                if (session != null) {
                    try {
                        session.abandon();
                    } catch (Exception ignored) {
                    }
                }
                return UpdateResult.failure("INSTALL_FAILED",
                        "PackageInstaller request failed: " + e.getMessage(), candidate);
            }
        }

        private void streamApkIntoSession(PackageInstaller.Session session, File apkFile)
                throws IOException {
            InputStream input = null;
            OutputStream output = null;
            try {
                input = new FileInputStream(apkFile);
                output = session.openWrite("package", 0, apkFile.length());
                byte[] buffer = new byte[65536];
                int count;
                while ((count = input.read(buffer)) >= 0) {
                    output.write(buffer, 0, count);
                }
                session.fsync(output);
            } finally {
                if (output != null) {
                    output.close();
                }
                if (input != null) {
                    input.close();
                }
            }
        }
    }
}
