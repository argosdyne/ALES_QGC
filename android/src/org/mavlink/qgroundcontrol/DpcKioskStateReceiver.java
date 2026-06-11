package org.mavlink.qgroundcontrol;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public class DpcKioskStateReceiver extends BroadcastReceiver {
    private static final String TAG = "QGC_DpcKioskStateReceiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        final boolean enabled = intent != null && intent.getBooleanExtra("enabled", false);
        Log.e(TAG, "Received DPC kiosk state broadcast enabled=" + enabled);
        QGCActivity.applyDpcKioskStateFromIntent(context, intent);
    }
}
