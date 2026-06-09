package org.mavlink.qgroundcontrol;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public class QgcBootReceiver extends BroadcastReceiver {
    private static final String TAG = "QGC_QgcBootReceiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || intent.getAction() == null) {
            return;
        }
        final String action = intent.getAction();
        if (!Intent.ACTION_BOOT_COMPLETED.equals(action)
                && !Intent.ACTION_LOCKED_BOOT_COMPLETED.equals(action)) {
            return;
        }

        Log.e(TAG, "Device boot completed; mark pending reboot for next QGC start");
        QGCActivity.markBootRequiresDpcKioskOn(context);
    }
}
