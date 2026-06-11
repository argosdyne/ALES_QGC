package org.mavlink.qgroundcontrol;

import android.util.Log;

import org.qtproject.qt5.android.bindings.QtApplication;

public class QGCApplication extends QtApplication {
    private static final String TAG = "QGC_QGCApplication";

    @Override
    public void onCreate() {
        super.onCreate();
        try {
            Log.e(TAG, "Application onCreate: init DPC kiosk bridge");
            QGCActivity.initDpcKioskBridge(getApplicationContext());
        } catch (Throwable t) {
            Log.e(TAG, "DPC kiosk bridge init failed", t);
        }
    }
}
