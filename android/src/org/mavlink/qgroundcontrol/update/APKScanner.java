package org.mavlink.qgroundcontrol.update;

import android.util.Log;

import java.io.File;
import java.io.FileFilter;

import org.mavlink.qgroundcontrol.update.USBUpdateManager.UpdateCandidate;
import org.mavlink.qgroundcontrol.update.USBUpdateManager.UpdateResult;

public final class APKScanner {
    private static final String TAG = USBUpdateManager.LOG_TAG;

    private APKScanner() { }

    public static UpdateResult scan(File rootDir) {
        Log.i(TAG, "SCAN: starting rootPath="
                + (rootDir != null ? rootDir.getAbsolutePath() : "null"));
        if (rootDir == null) {
            Log.w(TAG, "SCAN: root path is null");
            return UpdateResult.failure("NO_APK_FOUND", "USB root path is not available", null);
        }
        if (!rootDir.exists() || !rootDir.isDirectory()) {
            Log.w(TAG, "SCAN: root path is not a directory exists=" + rootDir.exists()
                    + " isDirectory=" + rootDir.isDirectory()
                    + " path=" + rootDir.getAbsolutePath());
            return UpdateResult.failure("NO_APK_FOUND",
                    "USB root path is not a directory: " + rootDir.getAbsolutePath(), null);
        }

        File[] apkFiles = rootDir.listFiles(new FileFilter() {
            @Override
            public boolean accept(File file) {
                String name = file.getName();
                return file.isFile()
                        && name.startsWith(USBUpdateManager.APK_NAME_PREFIX)
                        && name.toLowerCase(java.util.Locale.US).endsWith(".apk");
            }
        });

        if (apkFiles == null || apkFiles.length == 0) {
            Log.i(TAG, "SCAN: no matching APK found prefix=" + USBUpdateManager.APK_NAME_PREFIX
                    + " rootPath=" + rootDir.getAbsolutePath());
            return UpdateResult.failure("NO_APK_FOUND",
                    "No EasyGripper QGC APK found in " + rootDir.getAbsolutePath(), null);
        }
        if (apkFiles.length > 1) {
            Log.w(TAG, "SCAN: multiple APK files found count=" + apkFiles.length);
            return UpdateResult.failure("REJECTED_MULTIPLE_APK",
                    "Multiple EasyGripper QGC APK files found; remove all but one", null);
        }

        UpdateCandidate candidate = new UpdateCandidate();
        candidate.apkFile = apkFiles[0];
        candidate.sha256File = new File(candidate.apkFile.getAbsolutePath() + ".sha256");
        Log.i(TAG, "SCAN: found apk=" + candidate.apkFile.getAbsolutePath());
        Log.i(TAG, "SCAN: expected hash file=" + candidate.sha256File.getAbsolutePath());
        if (!candidate.sha256File.exists() || !candidate.sha256File.isFile()) {
            Log.w(TAG, "SCAN: hash file missing path=" + candidate.sha256File.getAbsolutePath());
            return UpdateResult.failure("REJECTED_HASH",
                    "Hash file not found: " + candidate.sha256File.getName(), candidate);
        }

        Log.i(TAG, "SCAN: found APK and companion hash file");
        return UpdateResult.success("SCAN_FOUND_APK", "APK candidate found", candidate);
    }
}
