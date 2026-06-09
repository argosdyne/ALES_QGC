package org.mavlink.qgroundcontrol.update;

import android.content.Context;
import android.util.Log;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;

import org.mavlink.qgroundcontrol.QGCActivity;
import org.mavlink.qgroundcontrol.update.USBUpdateManager.UpdateCandidate;

public final class UpdateAuditLogger {
    private static final String TAG = USBUpdateManager.LOG_TAG;
    private static final String LOG_FILE_NAME = "update_audit.log";

    private UpdateAuditLogger() { }

    public static void log(Context context, String event, UpdateCandidate candidate, String reason) {
        if (context == null) {
            Log.w(TAG, "Cannot write update audit event without context: " + event);
            return;
        }

        File logFile = new File(context.getFilesDir(), LOG_FILE_NAME);
        FileWriter writer = null;
        try {
            Log.i(TAG, "AUDIT: writing event=" + event
                    + " path=" + logFile.getAbsolutePath()
                    + " reason=" + reason);
            writer = new FileWriter(logFile, true);
            writer.write(toJsonLine(event, candidate, reason));
            writer.write("\n");
        } catch (IOException e) {
            Log.e(TAG, "Failed to write update audit log", e);
        } finally {
            if (writer != null) {
                try {
                    writer.close();
                } catch (IOException ignored) {
                }
            }
        }
        String securityEventMessage = toSecurityEventMessage(event, candidate, reason);
        Log.i(TAG, "AUDIT: forwarding to Security Events message=" + securityEventMessage);
        QGCActivity.safeLogSecurityEvent(securityEventMessage);
    }

    private static String toSecurityEventMessage(String event, UpdateCandidate candidate, String reason) {
        StringBuilder builder = new StringBuilder("USB update ");
        builder.append(event != null ? event : "EVENT");
        if (candidate != null) {
            if (candidate.currentVersionName != null || candidate.versionName != null) {
                builder.append(" version ");
                builder.append(candidate.currentVersionName != null ? candidate.currentVersionName : "unknown");
                builder.append(" -> ");
                builder.append(candidate.versionName != null ? candidate.versionName : "unknown");
            }
            if (candidate.apkSha256 != null) {
                builder.append(" sha256=");
                builder.append(candidate.shortSha256());
            }
        }
        if (reason != null && reason.length() > 0) {
            builder.append(": ");
            builder.append(reason);
        }
        return builder.toString();
    }

    private static String toJsonLine(String event, UpdateCandidate candidate, String reason) {
        StringBuilder builder = new StringBuilder();
        builder.append('{');
        append(builder, "timestamp", utcNow());
        append(builder, "event", event);
        if (candidate != null) {
            append(builder, "from_version", candidate.currentVersionName);
            append(builder, "from_version_code", Long.toString(candidate.currentVersionCode));
            append(builder, "to_version", candidate.versionName);
            append(builder, "to_version_code", Long.toString(candidate.versionCode));
            append(builder, "package_name", candidate.packageName);
            append(builder, "apk_sha256", candidate.apkSha256);
            append(builder, "signed_by", candidate.signerDisplayName);
            append(builder, "apk_path", candidate.apkFile != null ? candidate.apkFile.getAbsolutePath() : null);
        }
        append(builder, "reason", reason);
        if (builder.charAt(builder.length() - 1) == ',') {
            builder.deleteCharAt(builder.length() - 1);
        }
        builder.append('}');
        return builder.toString();
    }

    private static void append(StringBuilder builder, String key, String value) {
        if (value == null) {
            return;
        }
        builder.append('"').append(escape(key)).append('"').append(':');
        builder.append('"').append(escape(value)).append('"').append(',');
    }

    private static String escape(String value) {
        return value.replace("\\", "\\\\").replace("\"", "\\\"");
    }

    private static String utcNow() {
        SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US);
        format.setTimeZone(TimeZone.getTimeZone("UTC"));
        return format.format(new Date());
    }
}
