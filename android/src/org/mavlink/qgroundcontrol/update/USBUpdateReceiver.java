package org.mavlink.qgroundcontrol.update;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;

import org.mavlink.qgroundcontrol.QGCActivity;

import java.io.File;

public final class USBUpdateReceiver extends BroadcastReceiver {
    private static final String TAG = USBUpdateManager.LOG_TAG;

    @Override
    public void onReceive(Context context, Intent intent) {
        if (context == null || intent == null) {
            Log.w(TAG, "RECEIVER: ignored broadcast because context or intent is null");
            return;
        }

        String action = intent.getAction();
        File rootDir = null;
        Log.i(TAG, "RECEIVER: received action=" + action + " data=" + intent.getData());

        if (USBUpdateManager.ACTION_INSTALL_COMMIT_RESULT.equals(action)) {
            USBUpdateManager.handleInstallCommitResult(context.getApplicationContext(), intent);
            return;
        } else if (Intent.ACTION_MEDIA_MOUNTED.equals(action)) {
            Uri data = intent.getData();
            if (data != null) {
                rootDir = new File(data.getPath());
                Log.i(TAG, "RECEIVER: MEDIA_MOUNTED rootPath=" + rootDir.getAbsolutePath());
            } else {
                Log.w(TAG, "RECEIVER: MEDIA_MOUNTED did not include a file URI");
            }
        } else if (USBUpdateManager.ACTION_TEST_SCAN.equals(action)) {
            String path = intent.getStringExtra(USBUpdateManager.EXTRA_SCAN_PATH);
            if (path != null) {
                rootDir = new File(path);
                Log.i(TAG, "RECEIVER: TEST_SCAN rootPath=" + rootDir.getAbsolutePath());
            } else {
                Log.w(TAG, "RECEIVER: TEST_SCAN missing extra " + USBUpdateManager.EXTRA_SCAN_PATH);
            }
        } else {
            Log.d(TAG, "RECEIVER: ignoring action=" + action);
            return;
        }

        Activity activity = QGCActivity.getInstance();
        Log.i(TAG, "RECEIVER: foregroundActivityAvailable=" + (activity != null));
        USBUpdateManager.scanAndValidate(context.getApplicationContext(), rootDir, activity);
    }
}
