package org.mavlink.qgroundcontrol;

/* Copyright 2013 Google Inc.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
 * USA.
 *
 * Project home page: http://code.google.com/p/usb-serial-for-android/
 */
///////////////////////////////////////////////////////////////////////////////////////////
//  Written by: Mike Goza April 2014
//
//  These routines interface with the Android USB Host devices for serial port communication.
//  The code uses the usb-serial-for-android software library.  The QGCActivity class is the
//  interface to the C++ routines through jni calls.  Do not change the functions without also
//  changing the corresponding calls in the C++ routines or you will break the interface.
//
////////////////////////////////////////////////////////////////////////////////////////////

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.ArrayList;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.Timer;
import java.util.TimerTask;
import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.ComponentName;
import android.content.Intent;
import android.content.IntentFilter;
import android.hardware.usb.UsbAccessory;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbDeviceConnection;
import android.hardware.usb.UsbManager;
import android.widget.Toast;
import android.util.Log;
import android.os.PowerManager;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.app.PendingIntent;
import android.view.KeyEvent;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.view.WindowManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.provider.Settings;
import android.bluetooth.BluetoothDevice;

import com.hoho.android.usbserial.driver.*;
import org.qtproject.qt5.android.bindings.QtActivity;
import org.qtproject.qt5.android.bindings.QtApplication;
import org.mavlink.qgroundcontrol.update.USBUpdateManager;

import java.io.File;

public class QGCActivity extends QtActivity
{
    public  static int                                  BAD_DEVICE_ID = 0;
    private static QGCActivity                          _instance = null;
    private static UsbManager                           _usbManager = null;
    private static List<UsbSerialDriver>                _drivers;
    private static HashMap<Integer, UsbIoManager>       m_ioManager;
    private static HashMap<Integer, Long>               _userDataHashByDeviceId;
    private static final String                         TAG = "QGC_QGCActivity";
    private static final String                         DPC_PACKAGE = "com.easygripper.dpc";
    private static final String                         DPC_CONTROL_RECEIVER = "com.easygripper.dpc.DpcControlReceiver";
    private static final String                         ACTION_DPC_SET_KIOSK_ENABLED = "com.easygripper.dpc.action.SET_KIOSK_ENABLED";
    private static final String                         ACTION_DPC_REQUEST_KIOSK_STATE = "com.easygripper.dpc.action.REQUEST_KIOSK_STATE";
    private static final String                         ACTION_DPC_KIOSK_STATE_CHANGED = "com.easygripper.dpc.action.KIOSK_STATE_CHANGED";
    private static final String                         EXTRA_DPC_ENABLED = "enabled";
    private static final String                         EXTRA_DPC_PIN = "pin";
    private static final String                         QGC_DPC_PREFS = "qgc_dpc_prefs";
    private static final String                         KEY_PENDING_REBOOT_FORCE_ON = "pending_reboot_force_on";
    private static final String                         KEY_LAST_SHUTDOWN_ELAPSED_RT = "last_shutdown_elapsed_rt";
    private static final String                         KEY_LAST_BOOT_COUNT = "last_boot_count";
    private static final String                         KEY_LAST_BOOT_ID = "last_boot_id";
    private static final String                         KEY_KIOSK_OFF_BOOT_ID = "kiosk_off_boot_id";
    private static final String                         KEY_KIOSK_OFF_ELAPSED_RT = "kiosk_off_elapsed_rt";
    private static final String                         KEY_PREFS_INITIALIZED = "prefs_initialized";
    private static final String                         KEY_BOOT_FORCED_KIOSK_ON = "boot_forced_kiosk_on";
    private static final String                         KEY_KNOWN_KIOSK_ENABLED = "known_kiosk_enabled";
    private static final String                         KEY_HAS_KNOWN_KIOSK_STATE = "has_known_kiosk_state";
    private static volatile boolean                     _bootForcedDpcKioskOn = false;
    private static volatile boolean                     _hasKnownDpcKioskState = false;
    private static volatile boolean                     _knownDpcKioskEnabled = false;
    private static volatile boolean                     _startupBootCheckDone = false;
    private static Context                              _appContext = null;
    private static volatile boolean                     _dpcReceiverRegistered = false;
    private static PowerManager.WakeLock                _wakeLock;
    private static final String                         ACTION_USB_PERMISSION = "org.mavlink.qgroundcontrol.action.USB_PERMISSION";
    private static PendingIntent                        _usbPermissionIntent = null;
    private TaiSync                                     taiSync = null;
    private Timer                                       probeAccessoriesTimer = null;
    private static WifiManager.MulticastLock            _wifiMulticastLock;
    
    public static Context m_context;

    private final static ExecutorService m_Executor = Executors.newSingleThreadExecutor();

    private final static UsbIoManager.Listener m_Listener =
            new UsbIoManager.Listener()
            {
                @Override
                public void onRunError(Exception eA, long userData)
                {
                    Log.e(TAG, "onRunError Exception");
                    nativeDeviceException(userData, eA.getMessage());
                }

                @Override
                public void onNewData(final byte[] dataA, long userData)
                {
                    nativeDeviceNewData(userData, dataA);
                }
            };

    private final BroadcastReceiver mOpenAccessoryReceiver =
        new BroadcastReceiver()
        {
            @Override
            public void onReceive(Context context, Intent intent) {
                String action = intent.getAction();
                if (ACTION_USB_PERMISSION.equals(action)) {
                    UsbAccessory accessory = intent.getParcelableExtra(UsbManager.EXTRA_ACCESSORY);
                    if (accessory != null && intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                        openAccessory(accessory);
                    }
                } else if (UsbManager.ACTION_USB_ACCESSORY_DETACHED.equals(action)) {
                    UsbAccessory accessory = intent.getParcelableExtra(UsbManager.EXTRA_ACCESSORY);
                    if (accessory != null) {
                        closeAccessory(accessory);
                    }
                }
            }
        };

    private static UsbSerialDriver _findDriverByDeviceId(int deviceId) {
        for (UsbSerialDriver driver: _drivers) {
            if (driver.getDevice().getDeviceId() == deviceId) {
                return driver;
            }
        }
        return null;
    }

    private static UsbSerialDriver _findDriverByDeviceName(String deviceName) {
        for (UsbSerialDriver driver: _drivers) {
            if (driver.getDevice().getDeviceName().equals(deviceName)) {
                return driver;
            }
        }
        return null;
    }

    private final static BroadcastReceiver _usbReceiver = new BroadcastReceiver() {
            public void onReceive(Context context, Intent intent) {
                String action = intent.getAction();
                Log.i(TAG, "BroadcastReceiver USB action " + action);

                if (ACTION_USB_PERMISSION.equals(action)) {
                    synchronized (_instance) {
                        UsbDevice device = (UsbDevice)intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
                        if (device != null) {
                            UsbSerialDriver driver = _findDriverByDeviceId(device.getDeviceId());

                            if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                                qgcLogDebug("Permission granted to " + device.getDeviceName());
                                driver.setPermissionStatus(UsbSerialDriver.permissionStatusSuccess);
                            } else {
                                qgcLogDebug("Permission denied for " + device.getDeviceName());
                                driver.setPermissionStatus(UsbSerialDriver.permissionStatusDenied);
                            }
                        }
                    }
                } else if (UsbManager.ACTION_USB_DEVICE_DETACHED.equals(action)) {
                    UsbDevice device = (UsbDevice)intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);
                    if (device != null) {
                        if (_userDataHashByDeviceId.containsKey(device.getDeviceId())) {
                            nativeDeviceHasDisconnected(_userDataHashByDeviceId.get(device.getDeviceId()));
                        }
                    }
                }

                try {
                    nativeUpdateAvailableJoysticks();
                } catch(Exception e) {
                    Log.e(TAG, "Exception nativeUpdateAvailableJoysticks()");
                }
            }
        };

    private static final BroadcastReceiver _globalDpcStateReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            Log.e(TAG, "Global DPC state receiver fired");
            applyDpcKioskStateFromIntent(context, intent);
        }
    };

    private static Context getAppContext() {
        if (_instance != null) {
            return _instance.getApplicationContext();
        }
        return _appContext;
    }

    public static void initDpcKioskBridge(Context context) {
        _appContext = context.getApplicationContext();
        Log.e(TAG, "DPC_REBOOT_CHECK initDpcKioskBridge");
        if (!_startupBootCheckDone) {
            runStartupBootCheck(_appContext);
        }
        ensureDpcStateReceiverRegistered(_appContext);
        scheduleDpcStateRequests(_appContext);
    }

    private static void ensureDpcStateReceiverRegistered(Context context) {
        if (context == null || _dpcReceiverRegistered) {
            return;
        }

        final IntentFilter dpcFilter = new IntentFilter();
        dpcFilter.addAction(ACTION_DPC_KIOSK_STATE_CHANGED);
        // API 33+ (TIRAMISU): use numeric literals so this compiles with Qt 5.15 compileSdk < 33.
        if (Build.VERSION.SDK_INT >= 33) {
            context.registerReceiver(_globalDpcStateReceiver, dpcFilter, 0x2); // Context.RECEIVER_EXPORTED
        } else {
            context.registerReceiver(_globalDpcStateReceiver, dpcFilter);
        }
        _dpcReceiverRegistered = true;
        Log.e(TAG, "DPC state receiver registered at application level");
    }

    private static android.content.SharedPreferences dpcPrefs(Context context) {
        return context.getSharedPreferences(QGC_DPC_PREFS, Context.MODE_PRIVATE);
    }

    private static String readBootId() {
        BufferedReader reader = null;
        try {
            reader = new BufferedReader(new FileReader("/proc/sys/kernel/random/boot_id"));
            final String line = reader.readLine();
            if (line != null && !line.trim().isEmpty()) {
                return line.trim();
            }
        } catch (Exception e) {
            Log.w(TAG, "Failed to read boot_id from proc", e);
        } finally {
            if (reader != null) {
                try {
                    reader.close();
                } catch (IOException ignored) {
                }
            }
        }

        java.io.InputStream inputStream = null;
        try {
            final Process process = new ProcessBuilder("cat", "/proc/sys/kernel/random/boot_id").start();
            inputStream = process.getInputStream();
            reader = new BufferedReader(new java.io.InputStreamReader(inputStream));
            final String line = reader.readLine();
            if (line != null && !line.trim().isEmpty()) {
                return line.trim();
            }
        } catch (Exception e) {
            Log.w(TAG, "Failed to read boot_id via cat", e);
        } finally {
            if (reader != null) {
                try {
                    reader.close();
                } catch (IOException ignored) {
                }
            }
            if (inputStream != null) {
                try {
                    inputStream.close();
                } catch (IOException ignored) {
                }
            }
        }
        return "";
    }

    private static void saveDpcKioskStateToPrefs(Context context) {
        final android.content.SharedPreferences.Editor editor = dpcPrefs(context).edit()
                .putBoolean(KEY_BOOT_FORCED_KIOSK_ON, _bootForcedDpcKioskOn)
                .putBoolean(KEY_KNOWN_KIOSK_ENABLED, _knownDpcKioskEnabled)
                .putBoolean(KEY_HAS_KNOWN_KIOSK_STATE, _hasKnownDpcKioskState);

        final String bootId = readBootId();
        final long elapsedRt = SystemClock.elapsedRealtime();
        if (_hasKnownDpcKioskState && !_knownDpcKioskEnabled) {
            editor.putLong(KEY_KIOSK_OFF_ELAPSED_RT, elapsedRt);
            if (!bootId.isEmpty()) {
                editor.putString(KEY_KIOSK_OFF_BOOT_ID, bootId);
            }
            Log.e(TAG, "DPC_REBOOT_CHECK saved OFF markers elapsed=" + elapsedRt + " bootId=" + bootId);
        } else if (_knownDpcKioskEnabled) {
            editor.remove(KEY_KIOSK_OFF_BOOT_ID);
            editor.remove(KEY_KIOSK_OFF_ELAPSED_RT);
        }

        editor.commit();
    }

    private static void loadDpcKioskStateFromPrefs(Context context) {
        final android.content.SharedPreferences prefs = dpcPrefs(context);
        _bootForcedDpcKioskOn = prefs.getBoolean(KEY_BOOT_FORCED_KIOSK_ON, false);
        _knownDpcKioskEnabled = prefs.getBoolean(KEY_KNOWN_KIOSK_ENABLED, false);
        _hasKnownDpcKioskState = prefs.getBoolean(KEY_HAS_KNOWN_KIOSK_STATE, false);
        Log.e(TAG, "Loaded DPC prefs: bootForced=" + _bootForcedDpcKioskOn
                + " known=" + _hasKnownDpcKioskState
                + " enabled=" + _knownDpcKioskEnabled);
    }

    public static void markBootRequiresDpcKioskOn(Context context) {
        dpcPrefs(context).edit()
                .putBoolean(KEY_PENDING_REBOOT_FORCE_ON, true)
                .commit();
        Log.e(TAG, "DPC_REBOOT_CHECK marked pending reboot flag");
    }

    private static boolean isFreshInstall(android.content.SharedPreferences prefs) {
        return !prefs.getBoolean(KEY_PREFS_INITIALIZED, false);
    }

    private static void initializeFreshInstall(Context context, android.content.SharedPreferences prefs) {
        final boolean pendingRebootForce = prefs.getBoolean(KEY_PENDING_REBOOT_FORCE_ON, false);

        prefs.edit()
                .putBoolean(KEY_PREFS_INITIALIZED, true)
                .commit();

        if (pendingRebootForce) {
            Log.e(TAG, "DPC_REBOOT_CHECK fresh install after device boot -> force ON");
            forceDpcKioskOnAfterReboot(context, "fresh_install_after_boot");
            updateBootMarkers(context, prefs);
            return;
        }

        _bootForcedDpcKioskOn = false;
        _hasKnownDpcKioskState = false;
        _knownDpcKioskEnabled = false;

        prefs.edit()
                .putBoolean(KEY_BOOT_FORCED_KIOSK_ON, false)
                .putBoolean(KEY_HAS_KNOWN_KIOSK_STATE, false)
                .putBoolean(KEY_KNOWN_KIOSK_ENABLED, false)
                .remove(KEY_KIOSK_OFF_BOOT_ID)
                .remove(KEY_KIOSK_OFF_ELAPSED_RT)
                .commit();

        updateBootMarkers(context, prefs);
        Log.e(TAG, "DPC_REBOOT_CHECK fresh install initialized; waiting for DPC state");
    }

    private void saveLastShutdownElapsed() {
        final long elapsedRt = SystemClock.elapsedRealtime();
        dpcPrefs(this).edit()
                .putLong(KEY_LAST_SHUTDOWN_ELAPSED_RT, elapsedRt)
                .commit();
    }

    private static int readBootCount(Context context) {
        try {
            return Settings.Global.getInt(context.getContentResolver(), Settings.Global.BOOT_COUNT);
        } catch (Settings.SettingNotFoundException e) {
            Log.w(TAG, "BOOT_COUNT not available", e);
            return -1;
        }
    }

    private static void forceDpcKioskOnAfterReboot(Context context, String reason) {
        _bootForcedDpcKioskOn = true;
        _hasKnownDpcKioskState = true;
        _knownDpcKioskEnabled = true;
        dpcPrefs(context).edit()
                .remove(KEY_KIOSK_OFF_BOOT_ID)
                .remove(KEY_KIOSK_OFF_ELAPSED_RT)
                .commit();
        saveDpcKioskStateToPrefs(context);
        Log.e(TAG, "DPC_REBOOT_CHECK DEVICE REBOOT -> force ON (" + reason + ")");
    }

    private static void updateBootMarkers(Context context, android.content.SharedPreferences prefs) {
        final String currentBootId = readBootId();
        final int currentBootCount = readBootCount(context);
        final android.content.SharedPreferences.Editor bootMarkerEditor = prefs.edit();
        if (currentBootCount >= 0) {
            bootMarkerEditor.putInt(KEY_LAST_BOOT_COUNT, currentBootCount);
        }
        if (!currentBootId.isEmpty()) {
            bootMarkerEditor.putString(KEY_LAST_BOOT_ID, currentBootId);
        }
        bootMarkerEditor.putBoolean(KEY_PENDING_REBOOT_FORCE_ON, false);
        bootMarkerEditor.commit();
    }

    private static String evaluateDeviceReboot(Context context, android.content.SharedPreferences prefs) {
        if (isFreshInstall(prefs)) {
            Log.e(TAG, "DPC_REBOOT_CHECK evaluate skipped: fresh install");
            return "";
        }

        final long currentElapsedRt = SystemClock.elapsedRealtime();
        final long lastShutdownElapsedRt = prefs.getLong(KEY_LAST_SHUTDOWN_ELAPSED_RT, -1L);
        final long kioskOffElapsedRt = prefs.getLong(KEY_KIOSK_OFF_ELAPSED_RT, -1L);
        final String currentBootId = readBootId();
        final String lastBootId = prefs.getString(KEY_LAST_BOOT_ID, "");
        final String kioskOffBootId = prefs.getString(KEY_KIOSK_OFF_BOOT_ID, "");
        final int currentBootCount = readBootCount(context);
        final int lastBootCount = prefs.getInt(KEY_LAST_BOOT_COUNT, -1);
        final boolean pendingRebootForce = prefs.getBoolean(KEY_PENDING_REBOOT_FORCE_ON, false);

        Log.e(TAG, "DPC_REBOOT_CHECK evaluate"
                + " currentElapsed=" + currentElapsedRt
                + " lastShutdown=" + lastShutdownElapsedRt
                + " offElapsed=" + kioskOffElapsedRt
                + " bootId=" + currentBootId
                + " lastBootId=" + lastBootId
                + " kioskOffBootId=" + kioskOffBootId
                + " bootCount=" + currentBootCount
                + " lastBootCount=" + lastBootCount
                + " pending=" + pendingRebootForce);

        if (pendingRebootForce) {
            return "pending_boot_receiver";
        }

        if (lastShutdownElapsedRt >= 0L && currentElapsedRt + 5000L < lastShutdownElapsedRt) {
            return "elapsed_realtime_reset";
        }

        if (!currentBootId.isEmpty() && !lastBootId.isEmpty() && !currentBootId.equals(lastBootId)) {
            return "boot_id_changed";
        }

        if (currentBootCount >= 0 && lastBootCount >= 0 && currentBootCount > lastBootCount) {
            return "boot_count_increased";
        }

        if (kioskOffElapsedRt >= 0L && currentElapsedRt + 5000L < kioskOffElapsedRt) {
            return "off_elapsed_reset";
        }

        if (!currentBootId.isEmpty()
                && !kioskOffBootId.isEmpty()
                && !currentBootId.equals(kioskOffBootId)) {
            return "off_boot_id_changed";
        }

        return "";
    }

    public static boolean reconcilePostRebootKioskState() {
        final Context context = getAppContext();
        if (context == null) {
            Log.e(TAG, "DPC_REBOOT_CHECK reconcile: no context");
            return false;
        }

        if (_bootForcedDpcKioskOn) {
            return true;
        }

        final android.content.SharedPreferences prefs = dpcPrefs(context);
        final String rebootReason = evaluateDeviceReboot(context, prefs);
        Log.e(TAG, "DPC_REBOOT_CHECK reconcile reason=" + rebootReason);

        if (!rebootReason.isEmpty()) {
            forceDpcKioskOnAfterReboot(context, rebootReason);
            updateBootMarkers(context, prefs);
            return true;
        }

        return false;
    }

    private static void runStartupBootCheck(Context context) {
        if (_startupBootCheckDone) {
            return;
        }
        _startupBootCheckDone = true;

        Log.e(TAG, "DPC_REBOOT_CHECK startup begin");
        final android.content.SharedPreferences prefs = dpcPrefs(context);

        if (isFreshInstall(prefs)) {
            initializeFreshInstall(context, prefs);
            return;
        }

        final String rebootReason = evaluateDeviceReboot(context, prefs);
        if (!rebootReason.isEmpty()) {
            forceDpcKioskOnAfterReboot(context, rebootReason);
        } else {
            _bootForcedDpcKioskOn = false;
            loadDpcKioskStateFromPrefs(context);
        }

        updateBootMarkers(context, prefs);
        Log.e(TAG, "DPC_REBOOT_CHECK startup done forced=" + _bootForcedDpcKioskOn
                + " known=" + _hasKnownDpcKioskState
                + " enabled=" + _knownDpcKioskEnabled);
    }

    private void applyStartupDpcKioskState() {
        initDpcKioskBridge(getApplicationContext());
    }

    public static void applyDpcKioskStateFromIntent(Intent intent) {
        applyDpcKioskStateFromIntent(null, intent);
    }

    public static void applyDpcKioskStateFromIntent(Context context, Intent intent) {
        if (intent == null || intent.getAction() == null) {
            return;
        }
        if (!ACTION_DPC_KIOSK_STATE_CHANGED.equals(intent.getAction())) {
            return;
        }

        final Context saveContext = context != null
                ? context.getApplicationContext()
                : getAppContext();

        final boolean reportedEnabled = intent.getBooleanExtra(EXTRA_DPC_ENABLED, false);
        if (_bootForcedDpcKioskOn && !reportedEnabled) {
            _hasKnownDpcKioskState = true;
            _knownDpcKioskEnabled = true;
            if (saveContext != null) {
                saveDpcKioskStateToPrefs(saveContext);
            }
            Log.e(TAG, "Ignoring DPC OFF while reboot force ON is active");
            return;
        }

        _knownDpcKioskEnabled = reportedEnabled;
        _hasKnownDpcKioskState = true;
        if (reportedEnabled) {
            _bootForcedDpcKioskOn = false;
        }
        if (saveContext != null) {
            saveDpcKioskStateToPrefs(saveContext);
        }
        Log.e(TAG, "Received DPC kiosk state update: enabled=" + _knownDpcKioskEnabled);
        if (_instance != null) {
            _instance.runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    _instance.updateKioskBackBlockPolicy();
                }
            });
        }
    }

    private static boolean isDpcKioskBackBlocked() {
        return _bootForcedDpcKioskOn || (_hasKnownDpcKioskState && _knownDpcKioskEnabled);
    }

    private void updateKioskBackBlockPolicy() {
        if (isDpcKioskBackBlocked()) {
            hideNavigationBarForKiosk();
        }
    }

    /** Hide nav bar back button on OEM builds that still show it under Lock Task. */
    private void hideNavigationBarForKiosk() {
        final View decorView = getWindow().getDecorView();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            getWindow().setDecorFitsSystemWindows(false);
            final WindowInsetsController controller = getWindow().getInsetsController();
            if (controller != null) {
                controller.hide(WindowInsets.Type.navigationBars());
                controller.setSystemBarsBehavior(WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
            }
        } else {
            decorView.setSystemUiVisibility(
                    View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                            | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                            | View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
        }
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        if (isDpcKioskBackBlocked() && event.getKeyCode() == KeyEvent.KEYCODE_BACK) {
            return true;
        }
        return super.dispatchKeyEvent(event);
    }

    @SuppressWarnings("deprecation")
    @Override
    public void onBackPressed() {
        if (isDpcKioskBackBlocked()) {
            return;
        }
        super.onBackPressed();
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            updateKioskBackBlockPolicy();
        }
    }

    public static boolean isBootForcedDpcKioskOn() {
        return _bootForcedDpcKioskOn;
    }

    public static void refreshDpcKioskStateFromStorage() {
        final Context context = getAppContext();
        if (context == null) {
            return;
        }
        if (!_startupBootCheckDone) {
            runStartupBootCheck(context);
            return;
        }

        if (reconcilePostRebootKioskState()) {
            return;
        }

        if (!_bootForcedDpcKioskOn) {
            loadDpcKioskStateFromPrefs(context);
        }
    }

    private static boolean isDpcPackageInstalled(Context context) {
        if (context == null) {
            return false;
        }
        try {
            context.getPackageManager().getPackageInfo(DPC_PACKAGE, 0);
            return true;
        } catch (PackageManager.NameNotFoundException e) {
            return false;
        }
    }

    public static String getDpcKioskDiagnostics() {
        final Context context = getAppContext();
        final StringBuilder sb = new StringBuilder();
        sb.append("activity=").append(_instance != null);
        sb.append(" appCtx=").append(context != null);
        sb.append(" dpcPkg=").append(isDpcPackageInstalled(context));
        sb.append(" receiver=").append(_dpcReceiverRegistered);
        sb.append(" bootForced=").append(_bootForcedDpcKioskOn);
        sb.append(" known=").append(_hasKnownDpcKioskState);
        sb.append(" enabled=").append(_knownDpcKioskEnabled);
        sb.append(" uptimeMs=").append(SystemClock.elapsedRealtime());
        if (context != null) {
            final android.content.SharedPreferences prefs = dpcPrefs(context);
            sb.append(" pending=").append(prefs.getBoolean(KEY_PENDING_REBOOT_FORCE_ON, false));
            sb.append(" lastShutdown=").append(prefs.getLong(KEY_LAST_SHUTDOWN_ELAPSED_RT, -1L));
            sb.append(" fresh=").append(isFreshInstall(prefs));
        }
        return sb.toString();
    }

    // Native C++ functions which connect back to QSerialPort code
    private static native void nativeDeviceHasDisconnected(long userData);
    private static native void nativeDeviceException(long userData, String messageA);
    private static native void nativeDeviceNewData(long userData, byte[] dataA);
    private static native void nativeUpdateAvailableJoysticks();

    // Native C++ functions called to log output
    public static native void qgcLogDebug(String message);
    public static native void qgcLogWarning(String message);
    public static native void nativeLogSecurityEvent(String message);

    public static void safeQgcLogDebug(String message) {
        try {
            qgcLogDebug(message);
        } catch (UnsatisfiedLinkError e) {
            Log.d(TAG, message + " (native log unavailable)");
        }
    }

    public static void safeQgcLogWarning(String message) {
        try {
            qgcLogWarning(message);
        } catch (UnsatisfiedLinkError e) {
            Log.w(TAG, message + " (native log unavailable)");
        }
    }

    public static void safeLogSecurityEvent(String message) {
        Log.i(TAG, "SECURITY_BRIDGE: calling nativeLogSecurityEvent message=" + message);
        try {
            nativeLogSecurityEvent(message);
            Log.i(TAG, "SECURITY_BRIDGE: nativeLogSecurityEvent returned");
        } catch (UnsatisfiedLinkError e) {
            Log.w(TAG, "SECURITY_BRIDGE: native method unavailable message=" + message, e);
        } catch (Throwable t) {
            Log.e(TAG, "SECURITY_BRIDGE: native call failed message=" + message, t);
        }
    }

    public static QGCActivity getInstance() {
        return _instance;
    }

    public static void testUsbUpdateScan(String rootPath) {
        if (_instance == null || rootPath == null) {
            Log.w(TAG, "USB update test scan ignored because activity or path is not available");
            return;
        }
        USBUpdateManager.scanAndValidate(
                _instance.getApplicationContext(), new File(rootPath), _instance);
    }

    public native void nativeInit();

    public static String setDpcKioskEnabled(boolean enabled) {
        return setDpcKioskEnabledWithPin(enabled, "");
    }

    public static String setDpcKioskEnabledWithPin(boolean enabled, String pin) {
        if (_instance == null) {
            return "NO_ACTIVITY";
        }

        try {
            if (pin == null || pin.length() != 8) {
                return "INVALID_PIN";
            }

            _bootForcedDpcKioskOn = false;
            _hasKnownDpcKioskState = true;
            _knownDpcKioskEnabled = enabled;
            saveDpcKioskStateToPrefs(_instance.getApplicationContext());

            Intent explicitIntent = new Intent(ACTION_DPC_SET_KIOSK_ENABLED);
            explicitIntent.setComponent(new ComponentName(DPC_PACKAGE, DPC_CONTROL_RECEIVER));
            explicitIntent.putExtra(EXTRA_DPC_ENABLED, enabled);
            explicitIntent.putExtra(EXTRA_DPC_PIN, pin);
            _instance.sendBroadcast(explicitIntent);

            Intent packageIntent = new Intent(ACTION_DPC_SET_KIOSK_ENABLED);
            packageIntent.setPackage(DPC_PACKAGE);
            packageIntent.putExtra(EXTRA_DPC_ENABLED, enabled);
            packageIntent.putExtra(EXTRA_DPC_PIN, pin);
            _instance.sendBroadcast(packageIntent);
            return "OK";
        } catch (Throwable t) {
            Log.e(TAG, "Failed to send DPC control broadcast", t);
            return "ERROR";
        }
    }

    public static boolean isDpcControlSupported() {
        if (_instance == null) {
            return false;
        }

        try {
            Intent queryIntent = new Intent(ACTION_DPC_SET_KIOSK_ENABLED);
            queryIntent.setPackage(DPC_PACKAGE);
            List<ResolveInfo> receivers = _instance.getPackageManager().queryBroadcastReceivers(queryIntent, 0);
            if (receivers != null && !receivers.isEmpty()) {
                return true;
            }

            _instance.getPackageManager().getPackageInfo(DPC_PACKAGE, PackageManager.GET_ACTIVITIES);
            return true;
        } catch (PackageManager.NameNotFoundException e) {
            return false;
        } catch (Throwable t) {
            // Some Android builds restrict package visibility and can cause false negatives.
            // Be permissive so UI can still allow manual control attempts.
            Log.w(TAG, "DPC support query uncertain; allowing manual control UI", t);
            return true;
        }
    }

    private static void sendDpcRequestKioskStateBroadcast() {
        final Context context = getAppContext();
        if (context == null) {
            Log.e(TAG, "DPC state request skipped: no context");
            return;
        }

        if (!isDpcPackageInstalled(context)) {
            Log.e(TAG, "DPC state request skipped: DPC package not installed");
            return;
        }

        try {
            Intent explicitIntent = new Intent(ACTION_DPC_REQUEST_KIOSK_STATE);
            explicitIntent.setComponent(new ComponentName(DPC_PACKAGE, DPC_CONTROL_RECEIVER));
            explicitIntent.addFlags(Intent.FLAG_RECEIVER_FOREGROUND);
            context.sendBroadcast(explicitIntent);

            Intent packageIntent = new Intent(ACTION_DPC_REQUEST_KIOSK_STATE);
            packageIntent.setPackage(DPC_PACKAGE);
            packageIntent.addFlags(Intent.FLAG_RECEIVER_FOREGROUND);
            context.sendBroadcast(packageIntent);

            Log.e(TAG, "DPC state request sent to " + DPC_PACKAGE);
        } catch (Throwable t) {
            Log.e(TAG, "Failed to request DPC kiosk state", t);
        }
    }

    public static boolean requestDpcKioskState() {
        if (getAppContext() == null) {
            return false;
        }
        sendDpcRequestKioskStateBroadcast();
        return true;
    }

    private static void scheduleDpcStateRequests(Context context) {
        if (context == null) {
            return;
        }
        final Handler handler = new Handler(Looper.getMainLooper());
        final long[] delaysMs = new long[] { 0L, 500L, 1500L, 3000L, 5000L, 8000L, 12000L, 20000L };
        for (final long delayMs : delaysMs) {
            handler.postDelayed(new Runnable() {
                @Override
                public void run() {
                    sendDpcRequestKioskStateBroadcast();
                }
            }, delayMs);
        }
    }

    public static boolean hasKnownDpcKioskState() {
        return _hasKnownDpcKioskState;
    }

    public static boolean getKnownDpcKioskStateEnabled() {
        if (_bootForcedDpcKioskOn) {
            return true;
        }
        return _knownDpcKioskEnabled;
    }

    // QGCActivity singleton
    public QGCActivity()
    {
        _instance =                 this;
        _drivers =                  new ArrayList<UsbSerialDriver>();
        _userDataHashByDeviceId =   new HashMap<Integer, Long>();
        m_ioManager =               new HashMap<Integer, UsbIoManager>();
    }

    @Override
    public void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        applyStartupDpcKioskState();

        nativeInit();
        PowerManager pm = (PowerManager)_instance.getSystemService(Context.POWER_SERVICE);
        _wakeLock = pm.newWakeLock(PowerManager.SCREEN_BRIGHT_WAKE_LOCK, "QGroundControl");
        if(_wakeLock != null) {
            _wakeLock.acquire();
        } else {
            Log.i(TAG, "SCREEN_BRIGHT_WAKE_LOCK not acquired!!!");
        }
        _instance.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        _usbManager = (UsbManager)_instance.getSystemService(Context.USB_SERVICE);

        // Register for USB Detach and USB Permission intent
        IntentFilter filter = new IntentFilter();
        filter.addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED);
        filter.addAction(UsbManager.ACTION_USB_DEVICE_DETACHED);
        filter.addAction(ACTION_USB_PERMISSION);
        filter.addAction(BluetoothDevice.ACTION_ACL_CONNECTED);
        filter.addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED);
        _instance.registerReceiver(_instance._usbReceiver, filter);

        // Create intent for usb permission request
        _usbPermissionIntent = PendingIntent.getBroadcast(_instance, 0, new Intent(ACTION_USB_PERMISSION), 0);

	// Workaround for QTBUG-73138
	if (_wifiMulticastLock == null)
            {
                WifiManager wifi = (WifiManager) _instance.getSystemService(Context.WIFI_SERVICE);
                _wifiMulticastLock = wifi.createMulticastLock("QGroundControl");
                _wifiMulticastLock.setReferenceCounted(true);
            }

	_wifiMulticastLock.acquire();
	Log.d(TAG, "Multicast lock: " + _wifiMulticastLock.toString());


        try {
            taiSync = new TaiSync();

            IntentFilter accessoryFilter = new IntentFilter(ACTION_USB_PERMISSION);
            filter.addAction(UsbManager.ACTION_USB_ACCESSORY_DETACHED);
            registerReceiver(mOpenAccessoryReceiver, accessoryFilter);

            probeAccessoriesTimer = new Timer();
            probeAccessoriesTimer.schedule(new TimerTask() {
                @Override
                public void run()
                {
                    probeAccessories();
                }
            }, 0, 3000);
        } catch(Exception e) {
           Log.e(TAG, "Exception: " + e);
        }

        requestDpcKioskState();
        handleUsbUpdateTestIntent(getIntent());
        updateKioskBackBlockPolicy();
    }

    @Override
    public void onResume() {
        super.onResume();

        // Plug in of USB ACCESSORY triggers only onResume event.
        // Then we scan if there is actually anything new
        probeAccessories();
        
        // Session Management: App comes to foreground
        nativeOnActivityResume();
        updateKioskBackBlockPolicy();
    }

    @Override
    public void onPause() {
        super.onPause();
        saveLastShutdownElapsed();

        // Session Management: App goes to background - lock immediately
        nativeOnActivityPause();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleUsbUpdateTestIntent(intent);
    }

    @Override
    protected void onDestroy()
    {
        saveLastShutdownElapsed();

        if (probeAccessoriesTimer != null) {
            probeAccessoriesTimer.cancel();
        }
        unregisterReceiver(mOpenAccessoryReceiver);
        try {
            if (_wifiMulticastLock != null) {
                _wifiMulticastLock.release();
                Log.d(TAG, "Multicast lock released.");
            }
            if(_wakeLock != null) {
                _wakeLock.release();
            }
        } catch(Exception e) {
           Log.e(TAG, "Exception onDestroy()");
        }
        super.onDestroy();
    }

    public void onInit(int status) {
    }

    private void handleUsbUpdateTestIntent(Intent intent) {
        if (intent == null || !USBUpdateManager.ACTION_TEST_SCAN.equals(intent.getAction())) {
            return;
        }
        String rootPath = intent.getStringExtra(USBUpdateManager.EXTRA_SCAN_PATH);
        testUsbUpdateScan(rootPath);
    }

    /// Incrementally updates the list of drivers connected to the device
    private static void updateCurrentDrivers()
    {
        List<UsbSerialDriver> currentDrivers = UsbSerialProber.findAllDevices(_usbManager);

        // Remove stale drivers
        for (int i=_drivers.size()-1; i>=0; i--) {
            boolean found = false;
            for (UsbSerialDriver currentDriver: currentDrivers) {
                if (_drivers.get(i).getDevice().getDeviceId() == currentDriver.getDevice().getDeviceId()) {
                    found = true;
                    break;
                }
            }

            if (!found) {
                qgcLogDebug("Remove stale driver " + _drivers.get(i).getDevice().getDeviceName());
                _drivers.remove(i);
            }
        }

        // Add new drivers
        for (int i=0; i<currentDrivers.size(); i++) {
            boolean found = false;
            for (int j=0; j<_drivers.size(); j++) {
                if (currentDrivers.get(i).getDevice().getDeviceId() == _drivers.get(j).getDevice().getDeviceId()) {
                    found = true;
                    break;
                }
            }

            if (!found) {
                UsbSerialDriver newDriver =     currentDrivers.get(i);
                UsbDevice       device =        newDriver.getDevice();
                String          deviceName =    device.getDeviceName();

                _drivers.add(newDriver);
                qgcLogDebug("Adding new driver " + deviceName);

                // Request permission if needed
                if (_usbManager.hasPermission(device)) {
                    qgcLogDebug("Already have permission to use device " + deviceName);
                    newDriver.setPermissionStatus(UsbSerialDriver.permissionStatusSuccess);
                } else {
                    qgcLogDebug("Requesting permission to use device " + deviceName);
                    newDriver.setPermissionStatus(UsbSerialDriver.permissionStatusRequested);
                    _usbManager.requestPermission(device, _usbPermissionIntent);
                }
            }
        }
    }

    /// Returns array of device info for each unopened device.
    /// @return Device info format DeviceName:Company:ProductId:VendorId
    public static String[] availableDevicesInfo()
    {
        updateCurrentDrivers();

        if (_drivers.size() <= 0) {
            return null;
        }

        List<String> deviceInfoList = new ArrayList<String>();

        for (int i=0; i<_drivers.size(); i++) {
            String          deviceInfo;
            UsbSerialDriver driver = _drivers.get(i);

            if (driver.permissionStatus() != UsbSerialDriver.permissionStatusSuccess) {
                continue;
            }

            UsbDevice device = driver.getDevice();

            deviceInfo = device.getDeviceName() + ":";

            if (driver instanceof FtdiSerialDriver) {
                deviceInfo = deviceInfo + "FTDI:";
            } else if (driver instanceof CdcAcmSerialDriver) {
                deviceInfo = deviceInfo + "Cdc Acm:";
            } else if (driver instanceof Cp2102SerialDriver) {
                deviceInfo = deviceInfo + "Cp2102:";
            } else if (driver instanceof ProlificSerialDriver) {
                deviceInfo = deviceInfo + "Prolific:";
            } else {
                deviceInfo = deviceInfo + "Unknown:";
            }

            deviceInfo = deviceInfo + Integer.toString(device.getProductId()) + ":";
            deviceInfo = deviceInfo + Integer.toString(device.getVendorId()) + ":";

            deviceInfoList.add(deviceInfo);
        }

        String[] rgDeviceInfo = new String[deviceInfoList.size()];
        for (int i=0; i<deviceInfoList.size(); i++) {
            rgDeviceInfo[i] = deviceInfoList.get(i);
        }

        return rgDeviceInfo;
    }

    /// Open the specified device
    ///     @param userData Data to associate with device and pass back through to native calls.
    /// @return Device id
    public static int open(Context parentContext, String deviceName, long userData)
    {
        int deviceId = BAD_DEVICE_ID;

        m_context = parentContext;

        UsbSerialDriver driver = _findDriverByDeviceName(deviceName);
        if (driver == null) {
            qgcLogWarning("Attempt to open unknown device " + deviceName);
            return BAD_DEVICE_ID;
        }

        if (driver.permissionStatus() != UsbSerialDriver.permissionStatusSuccess) {
            qgcLogWarning("Attempt to open device with incorrect permission status " + deviceName + " " + driver.permissionStatus());
            return BAD_DEVICE_ID;
        }

        UsbDevice device = driver.getDevice();
        deviceId = device.getDeviceId();

        try {
            driver.setConnection(_usbManager.openDevice(device));
            driver.open();
            driver.setPermissionStatus(UsbSerialDriver.permissionStatusOpen);

            _userDataHashByDeviceId.put(deviceId, userData);

            UsbIoManager ioManager = new UsbIoManager(driver, m_Listener, userData);
            m_ioManager.put(deviceId, ioManager);
            m_Executor.submit(ioManager);

            qgcLogDebug("Port open successful");
        } catch(IOException exA) {
            driver.setPermissionStatus(UsbSerialDriver.permissionStatusRequestRequired);
            _userDataHashByDeviceId.remove(deviceId);

            if(m_ioManager.get(deviceId) != null) {
                m_ioManager.get(deviceId).stop();
                m_ioManager.remove(deviceId);
            }
            qgcLogWarning("Port open exception: " + exA.getMessage());
            return BAD_DEVICE_ID;
        }

        return deviceId;
    }

    public static void startIoManager(int idA)
    {
        if (m_ioManager.get(idA) != null)
            return;

        UsbSerialDriver driverL = _findDriverByDeviceId(idA);

        if (driverL == null)
            return;

        UsbIoManager managerL = new UsbIoManager(driverL, m_Listener, _userDataHashByDeviceId.get(idA));
        m_ioManager.put(idA, managerL);
        m_Executor.submit(managerL);
    }

    public static void stopIoManager(int idA)
    {
        if(m_ioManager.get(idA) == null)
            return;

        m_ioManager.get(idA).stop();
        m_ioManager.remove(idA);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    //
    //  Sets the parameters on an open port.
    //
    //  Args:   idA - ID number from the open command
    //          baudRateA - Decimal value of the baud rate.  I.E. 9600, 57600, 115200, etc.
    //          dataBitsA - number of data bits.  Valid numbers are 5, 6, 7, 8
    //          stopBitsA - number of stop bits.  Valid numbers are 1, 2
    //          parityA - No Parity=0, Odd Parity=1, Even Parity=2
    //
    //  Returns:  T/F Success/Failure
    //
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    public static boolean setParameters(int idA, int baudRateA, int dataBitsA, int stopBitsA, int parityA)
    {
        UsbSerialDriver driverL = _findDriverByDeviceId(idA);

        if (driverL == null)
            return false;

        try
        {
            driverL.setParameters(baudRateA, dataBitsA, stopBitsA, parityA);
            return true;
        }
        catch(IOException eA)
        {
            return false;
        }
    }



    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    //
    //  Close the device.
    //
    //  Args:  idA - ID number from the open command
    //
    //  Returns:  T/F Success/Failure
    //
    ////////////////////////////////////////////////////////////////////////////////////////////////////////
    public static boolean close(int idA)
    {
        UsbSerialDriver driverL = _findDriverByDeviceId(idA);

        if (driverL == null)
            return false;

        try
        {
            stopIoManager(idA);
            _userDataHashByDeviceId.remove(idA);
            driverL.setPermissionStatus(UsbSerialDriver.permissionStatusRequestRequired);
            driverL.close();

            return true;
        }
        catch(IOException eA)
        {
            return false;
        }
    }



    //////////////////////////////////////////////////////////////////////////////////////////////////////
    //
    //  Write data to the device.
    //
    //  Args:   idA - ID number from the open command
    //          sourceA - byte array of data to write
    //          timeoutMsecA - amount of time in milliseconds to wait for the write to occur
    //
    //  Returns:  number of bytes written
    //
    /////////////////////////////////////////////////////////////////////////////////////////////////////
    public static int write(int idA, byte[] sourceA, int timeoutMSecA)
    {
        UsbSerialDriver driverL = _findDriverByDeviceId(idA);

        if (driverL == null)
            return 0;

        try
        {
            return driverL.write(sourceA, timeoutMSecA);
        }
        catch(IOException eA)
        {
            return 0;
        }
        /*
        UsbIoManager managerL = m_ioManager.get(idA);

        if(managerL != null)
        {
            managerL.writeAsync(sourceA);
            return sourceA.length;
        }
        else
            return 0;
        */
    }

    public static boolean isDeviceNameValid(String nameA)
    {
        for (UsbSerialDriver driver: _drivers) {
            if (driver.getDevice().getDeviceName() == nameA)
                return true;
        }

        return false;
    }

    public static boolean isDeviceNameOpen(String nameA)
    {
        for (UsbSerialDriver driverL: _drivers) {
            if (nameA.equals(driverL.getDevice().getDeviceName()) && driverL.permissionStatus() == UsbSerialDriver.permissionStatusOpen) {
                return true;
            }
        }

        return false;
    }



    /////////////////////////////////////////////////////////////////////////////////////////////////////
    //
    //  Set the Data Terminal Ready flag on the device
    //
    //  Args:   idA - ID number from the open command
    //          onA - on=T, off=F
    //
    //  Returns:  T/F Success/Failure
    //
    ////////////////////////////////////////////////////////////////////////////////////////////////////
    public static boolean setDataTerminalReady(int idA, boolean onA)
    {
        try
        {
            UsbSerialDriver driverL = _findDriverByDeviceId(idA);

            if (driverL == null)
                return false;

            driverL.setDTR(onA);
            return true;
        }
        catch(IOException eA)
        {
            return false;
        }
    }



    ////////////////////////////////////////////////////////////////////////////////////////////
    //
    //  Set the Request to Send flag
    //
    //  Args:   idA - ID number from the open command
    //          onA - on=T, off=F
    //
    //  Returns:  T/F Success/Failure
    //
    ////////////////////////////////////////////////////////////////////////////////////////////
    public static boolean setRequestToSend(int idA, boolean onA)
    {
        try
        {
            UsbSerialDriver driverL = _findDriverByDeviceId(idA);

            if (driverL == null)
                return false;

            driverL.setRTS(onA);
            return true;
        }
        catch(IOException eA)
        {
            return false;
        }
    }



    ///////////////////////////////////////////////////////////////////////////////////////////////
    //
    //  Purge the hardware buffers based on the input and output flags
    //
    //  Args:   idA - ID number from the open command
    //          inputA - input buffer purge.  purge=T
    //          outputA - output buffer purge.  purge=T
    //
    //  Returns:  T/F Success/Failure
    //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    public static boolean purgeBuffers(int idA, boolean inputA, boolean outputA)
    {
        try
        {
            UsbSerialDriver driverL = _findDriverByDeviceId(idA);

            if (driverL == null)
                return false;

            return driverL.purgeHwBuffers(inputA, outputA);
        }
        catch(IOException eA)
        {
            return false;
        }
    }



    //////////////////////////////////////////////////////////////////////////////////////////
    //
    //  Get the native device handle (file descriptor)
    //
    //  Args:   idA - ID number from the open command
    //
    //  Returns:  device handle
    //
    ///////////////////////////////////////////////////////////////////////////////////////////
    public static int getDeviceHandle(int idA)
    {
        UsbSerialDriver driverL = _findDriverByDeviceId(idA);

        if (driverL == null)
            return -1;

        UsbDeviceConnection connectL = driverL.getDeviceConnection();
        if (connectL == null)
            return -1;
        else
            return connectL.getFileDescriptor();
    }

    UsbAccessory openUsbAccessory = null;
    Object openAccessoryLock = new Object();

    private void openAccessory(UsbAccessory usbAccessory)
    {
        Log.i(TAG, "openAccessory: " + usbAccessory.getSerial());
        try {
            synchronized(openAccessoryLock) {
                if ((openUsbAccessory != null && !taiSync.isRunning()) || openUsbAccessory == null) {
                    openUsbAccessory = usbAccessory;
                    taiSync.open(_usbManager.openAccessory(usbAccessory));
                }
            }
        } catch (IOException e) {
            Log.e(TAG, "openAccessory exception: " + e);
            taiSync.close();
            closeAccessory(openUsbAccessory);
        }
    }

    private void closeAccessory(UsbAccessory usbAccessory)
    {
        Log.i(TAG, "closeAccessory");

        synchronized(openAccessoryLock) {
            if (openUsbAccessory != null && usbAccessory == openUsbAccessory && taiSync.isRunning()) {
                taiSync.close();
                openUsbAccessory = null;
            }
        }
    }

    Object probeAccessoriesLock = new Object();

    private void probeAccessories()
    {
        final PendingIntent pendingIntent = PendingIntent.getBroadcast(this, 0, new Intent(ACTION_USB_PERMISSION), 0);
        new Thread(new Runnable() {
            public void run() {
                synchronized(openAccessoryLock) {
//                    Log.i(TAG, "probeAccessories");
                    UsbAccessory[] accessories = _usbManager.getAccessoryList();
                    if (accessories != null) {
                       for (UsbAccessory usbAccessory : accessories) {
                           if (usbAccessory == null) {
                               continue;
                           }
                           if (_usbManager.hasPermission(usbAccessory)) {
                               openAccessory(usbAccessory);
                           }
                       }
                    }
                }
            }
        }).start();
    }

    // Session Management JNI callbacks
    private native void nativeOnActivityPause();
    private native void nativeOnActivityResume();
}

