package org.mavlink.qgroundcontrol.update;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.net.Uri;
import android.os.ParcelFileDescriptor;
import android.util.Log;

import java.io.File;
import java.io.FileNotFoundException;

public final class USBUpdateFileProvider extends ContentProvider {
    public static final String AUTHORITY = "org.Agosdyne.alesqgc.updatefile";

    private static final String TAG = USBUpdateManager.LOG_TAG;

    @Override
    public boolean onCreate() {
        return true;
    }

    public static Uri uriForFile(File file) {
        return new Uri.Builder()
                .scheme("content")
                .authority(AUTHORITY)
                .appendPath("file")
                .appendQueryParameter("path", file.getAbsolutePath())
                .build();
    }

    @Override
    public ParcelFileDescriptor openFile(Uri uri, String mode) throws FileNotFoundException {
        if (!"r".equals(mode)) {
            throw new FileNotFoundException("Only read mode is supported");
        }

        String path = uri.getQueryParameter("path");
        if (path == null) {
            throw new FileNotFoundException("Missing file path");
        }

        File file = new File(path);
        if (!isAllowedUpdateFile(file)) {
            Log.w(TAG, "PROVIDER: rejected file request path=" + path);
            throw new FileNotFoundException("File is not an allowed QGC update artifact");
        }
        if (!file.isFile()) {
            throw new FileNotFoundException("File not found: " + path);
        }

        Log.i(TAG, "PROVIDER: opening update file path=" + path);
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY);
    }

    private boolean isAllowedUpdateFile(File file) {
        String name = file.getName();
        return name.startsWith(USBUpdateManager.APK_NAME_PREFIX)
                && (name.endsWith(".apk") || name.endsWith(".apk.sha256"));
    }

    @Override
    public String getType(Uri uri) {
        String path = uri != null ? uri.getQueryParameter("path") : null;
        if (path != null && path.endsWith(".apk")) {
            return "application/vnd.android.package-archive";
        }
        return "text/plain";
    }

    @Override
    public Cursor query(Uri uri, String[] projection, String selection,
                        String[] selectionArgs, String sortOrder) {
        return null;
    }

    @Override
    public Uri insert(Uri uri, ContentValues values) {
        return null;
    }

    @Override
    public int delete(Uri uri, String selection, String[] selectionArgs) {
        return 0;
    }

    @Override
    public int update(Uri uri, ContentValues values, String selection,
                      String[] selectionArgs) {
        return 0;
    }
}
