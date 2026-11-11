/****************************************************************************
 *
 * YS-05 LiDAR warning, critical and no-response handling (UI Y-04 / Y-05)
 * Always loaded by MainRootWindow (the LiDAR panel is unloaded when closed), so status bits and
 * lost replies are watched with the panel closed.
 *   Warning  (orange banner ⑨, acquisition continues): USB <= 30 GB, scanner temperature warning,
 *            computer > 65 C, camera error
 *   Critical (critical vehicle message, Stop recommended): USB <= 1 GB, scanner overheating,
 *            computer >= 70 C, data dropped, acquisition stopped without a Stop from QGC
 *   No reply: 2 s orange, 5 s NO RESPONSE with the last known state, POWERED OFF after Power Off
 * Uses the existing YSManager API only: statusChanged / messageChanged, genInfo, intErr, camErr,
 * lastReceivedMessage (YS_STA_01 text, for the scanner error byte), lastSentMessage, lidarState.
 *
 ****************************************************************************/

import QtQuick          2.11

import QGroundControl               1.0
import CustomQuickInterface         1.0

Item {
    id: _root

    property var  _ys:          QGroundControl.corePlugin.ysManager
    property var  _settings:    QGroundControl.corePlugin.settings
    property int  _state:       _ys ? _ys.lidarState : YSManager.StateDisabled

    // No-reply thresholds from the YS-05 task, counted from the last Get Status reply
    readonly property int statusDelayedMs:      2000
    readonly property int noResponseMs:         5000
    // How long a warning banner stays up. Not given by the story / mockup, chosen here.
    readonly property int _warningBannerMs:     10000

    // Limits fixed by the YellowScan Serial Interface Control v4.0 bit definitions
    readonly property int usbLowGb:             30
    readonly property int usbFullGb:            1
    readonly property int computerWarnC:        65
    readonly property int computerOverheatC:    70

    // General info byte (YS_STA_00 byte 2)
    readonly property int _genUsbPresentBit:    1 << 0
    readonly property int _genUsbSpaceLowBit:   1 << 1
    readonly property int _genUsbFullBit:       1 << 2
    // Scanner error byte (YS_STA_01 byte 0)
    readonly property int _scnDataDroppedBit:   1 << 0
    readonly property int _scnOverheatBit:      1 << 3
    readonly property int _scnTempWarningBit:   1 << 4
    // Internal computer error byte (YS_STA_01 byte 1)
    readonly property int _intOverheatBit:      1 << 0
    readonly property int _intTempWarningBit:   1 << 1
    // Camera error byte (YS_STA_01 byte 2)
    readonly property int _camConnectionBit:    1 << 0
    readonly property int _camAdjustBit:        1 << 1
    readonly property int _camPhotoBit:         1 << 2

    // YSManager::scnErr() is reduced to 0 / 1, so the scanner error byte is read from the YS_STA_01 reply text
    // written by YSManager::_mavlinkReceived (byte 0 of the value)
    readonly property var _sta01RegExp:         /^NAMED_VALUE_INT YS_STA_01 VALUE=0X([0-9A-F]{8})/i
    // MAV_CMD_USER_2 = YellowScan Power Off (YSManager::powerOff), as written by YSManager::_sendCommand
    readonly property var _powerOffSentRegExp:  /^CMD_LONG cmd=31011 /m

    // preChecks row order is fixed in YSManager::_rebuildPreChecks
    readonly property int _rowScanner:      1
    readonly property int _rowUsb:          3
    readonly property int _rowTemperature:  5

    property int    scnErr:             0       ///< Raw scanner error byte from the last YS_STA_01
    property string lastStatusTime:     ""      ///< HH:mm:ss of the last Get Status reply
    property string noResponseSince:    ""      ///< HH:mm:ss when NO RESPONSE started
    property string lastKnownState:     ""      ///< Acquisition state before the replies stopped (REC / IDLE)
    property bool   _stale2:            false
    property bool   _stale5:            false
    property bool   _powerOffSent:      false
    property int    _prevState:         YSManager.StateDisabled

    // Live = LiDAR state comes from Get Status. Starting / Stopping keep their own ACK timeout in YSManager.
    readonly property bool _live:       _state === YSManager.StateReady || _state === YSManager.StateNotReady ||
                                        _state === YSManager.StateRecording
    readonly property bool poweredOff:  _state === YSManager.StatePoweredOff ||
                                        (_powerOffSent && (_state === YSManager.StateNoResponse || (_stale5 && _live)))
    readonly property bool noResponse:  !poweredOff && (_state === YSManager.StateNoResponse || (_stale5 && _live))
    readonly property bool delayed:     !noResponse && !poweredOff && _stale2 && _live
    readonly property bool _recording:  _state === YSManager.StateRecording

    // Active warning / critical items: [{ key, text, rowText, critical }]
    property var    alerts:             []
    property int    warningCount:       0
    property int    criticalCount:      0
    property string alertsSinceTime:    ""
    property var    _prevKeys:          ({})
    readonly property bool usbLow:      _hasAlert("usbLow")

    property string _warningBanner:     ""
    readonly property string bannerText: noResponse ? _noResponseText() : _warningBanner

    function _now() {
        return Qt.formatTime(new Date(), "HH:mm:ss")
    }

    function _hasAlert(key) {
        for (var i = 0; i < alerts.length; i++) {
            if (alerts[i].key === key) {
                return true
            }
        }
        return false
    }

    function _noResponseText() {
        var text = qsTr("LiDAR not responding — no status for %1 s.").arg(noResponseMs / 1000)
        return text + " " + (lastKnownState !== "" ? qsTr("Acquisition state unknown (last known: %1).").arg(lastKnownState)
                                                   : qsTr("Acquisition state unknown."))
    }

    // Current items from the status bytes. A critical bit hides the warning of the same source.
    function _buildAlerts() {
        var list = []
        var gen = _ys.genInfo
        var intErr = _ys.intErr
        var camErr = _ys.camErr
        function add(key, text, rowText, critical) {
            list.push({ "key": key, "text": text, "rowText": rowText, "critical": critical })
        }
        if (gen & _genUsbPresentBit) {
            if (gen & _genUsbFullBit) {
                add("usbFull", qsTr("USB stick full (≤ %1 GB)").arg(usbFullGb), "", true)
            } else if (gen & _genUsbSpaceLowBit) {
                add("usbLow", qsTr("USB stick space low (≤ %1 GB)").arg(usbLowGb), qsTr("Space low (≤ %1 GB)").arg(usbLowGb), false)
            }
        }
        if (scnErr & _scnDataDroppedBit) {
            add("dataDropped", qsTr("Data dropped (USB too slow)"), "", true)
        }
        if (scnErr & _scnOverheatBit) {
            add("scnOverheat", qsTr("Scanner overheating"), qsTr("Scanner overheating"), true)
        } else if (scnErr & _scnTempWarningBit) {
            add("scnTempWarning", qsTr("Scanner temperature warning"), qsTr("Scanner temp. warning"), false)
        }
        if (intErr & _intOverheatBit) {
            add("intOverheat", qsTr("Computer overheating (≥ %1 °C)").arg(computerOverheatC), qsTr("Computer ≥ %1 °C").arg(computerOverheatC), true)
        } else if (intErr & _intTempWarningBit) {
            add("intTempWarning", qsTr("Computer temperature > %1 °C").arg(computerWarnC), qsTr("Computer > %1 °C").arg(computerWarnC), false)
        }
        // Camera only checked when a camera is installed (LiDAR Setup > Connection > Camera)
        if (_settings && _settings.ysCamera.rawValue !== 0) {
            if (camErr & _camConnectionBit) {
                add("camConnection", qsTr("Camera connection error"), "", false)
            }
            if (camErr & _camAdjustBit) {
                add("camAdjust", qsTr("Camera settings error"), "", false)
            }
            if (camErr & _camPhotoBit) {
                add("camPhoto", qsTr("Camera photo error"), "", false)
            }
        }
        return list
    }

    // One message per newly set bit; bits set in the same reply share one message
    function _evaluate() {
        var list = _buildAlerts()
        var keys = {}
        var newWarnings = []
        var newCriticals = []
        var warnings = 0
        for (var i = 0; i < list.length; i++) {
            keys[list[i].key] = true
            if (!list[i].critical) {
                warnings++
            }
            if (!_prevKeys[list[i].key]) {
                (list[i].critical ? newCriticals : newWarnings).push(list[i].text)
            }
        }
        var changed = JSON.stringify(Object.keys(keys).sort()) !== JSON.stringify(Object.keys(_prevKeys).sort())
        _prevKeys = keys
        alerts = list
        warningCount = warnings
        criticalCount = list.length - warnings
        if (changed) {
            alertsSinceTime = _now()
        }
        if (newWarnings.length) {
            _showWarningBanner(qsTr("LiDAR: %1.").arg(newWarnings.join(" · ")) + (_recording ? " " + qsTr("Recording continues.") : ""))
        }
        if (newCriticals.length) {
            _showCritical(newCriticals.join(" · "))
        }
    }

    function _showWarningBanner(text) {
        _warningBanner = text
        warningBannerTimer.restart()
    }

    function _showCritical(text) {
        mainWindow.showCriticalVehicleMessage(qsTr("LiDAR critical: %1.").arg(text) + (_recording ? " " + qsTr("Stop acquisition recommended.") : ""))
    }

    function dismissBanner() {
        warningBannerTimer.stop()
        _warningBanner = ""
    }

    // Panel ④ row as shown: [{ state, detail, dimmed }]. Adds the warning bits YSManager does not decode
    // (USB space low, scanner temperature) and the no-response view; other rows are shown as YSManager built them.
    function rowView(index, row) {
        if (noResponse) {
            return { "state": YSManager.PreCheckUnknown, "detail": "— " + qsTr("(last %1)").arg(lastStatusTime !== "" ? lastStatusTime : "--"), "dimmed": true }
        }
        if (!_ys || !_ys.statusValid) {
            return { "state": row.state, "detail": row.detail, "dimmed": false }
        }
        if (index === _rowUsb && usbLow) {
            return { "state": YSManager.PreCheckFail, "detail": alerts.filter(function(a) { return a.key === "usbLow" })[0].rowText, "dimmed": false }
        }
        if (index === _rowTemperature) {
            var temps = alerts.filter(function(a) { return a.rowText !== "" && a.key !== "usbLow" })
            if (temps.length) {
                return { "state": YSManager.PreCheckFail, "detail": temps.map(function(a) { return a.rowText }).join(" · "), "dimmed": false }
            }
        }
        // Scanner temperature bits are on the Temperature row: if they are the only scanner error flags,
        // the Scanner row shows ready / not ready as it would without them
        var scnTempBits = _scnOverheatBit | _scnTempWarningBit
        if (index === _rowScanner && (scnErr & scnTempBits) && (scnErr & ~scnTempBits) === 0 && (_ys.scnInfo & 0x01) === 0) {
            return _ys.scannerNotReady ? { "state": YSManager.PreCheckFail, "detail": qsTr("Not ready"), "dimmed": false }
                                       : { "state": YSManager.PreCheckOk,   "detail": qsTr("Ready"),     "dimmed": false }
        }
        return { "state": row.state, "detail": row.detail, "dimmed": false }
    }

    function _restartStatusTimers() {
        _stale2 = false
        _stale5 = false
        delayedTimer.restart()
        noResponseTimer.restart()
    }

    function _reset() {
        delayedTimer.stop()
        noResponseTimer.stop()
        _stale2 = false
        _stale5 = false
        _powerOffSent = false
        scnErr = 0
        lastStatusTime = ""
        lastKnownState = ""
        _prevKeys = {}
        alerts = []
        warningCount = 0
        criticalCount = 0
        dismissBanner()
    }

    onNoResponseChanged: {
        if (noResponse) {
            noResponseSince = _now()
            dismissBanner()
        }
    }

    Connections {
        target: _ys
        onStatusChanged: {
            // Emitted for each Get Status reply and accepted Start / Stop ACK (statusValid true), and for the
            // Power Off ACK (statusValid false). Request sends do not emit it.
            if (!_ys.statusValid) {
                return
            }
            _powerOffSent = false
            lastStatusTime = _now()
            _restartStatusTimers()
        }
        onMessageChanged: {
            if (_powerOffSentRegExp.test(_ys.lastSentMessage)) {
                _powerOffSent = true
            }
            var m = _sta01RegExp.exec(_ys.lastReceivedMessage)
            if (!m || _state === YSManager.StatePoweredOff) {
                return
            }
            // Evaluated once per Get Status cycle, after YS_STA_01 (YS_STA_00 has already updated genInfo)
            scnErr = parseInt(m[1], 16) & 0xFF
            _evaluate()
        }
        onLidarStateChanged: {
            var s = _ys.lidarState
            var linkDown = function(st) {
                return st === YSManager.StateDisabled || st === YSManager.StateNoLink || st === YSManager.StatePoweredOff
            }
            // Link back: count the no-reply time from now, not from before the link was lost
            if (linkDown(_prevState) && !linkDown(s)) {
                _restartStatusTimers()
            }
            if (s === YSManager.StateRecording) {
                lastKnownState = qsTr("REC")
            } else if (s === YSManager.StateReady || s === YSManager.StateNotReady) {
                lastKnownState = qsTr("IDLE")
            }
            // REC -> IDLE without passing STOPPING: acquisition stopped without a Stop from QGC
            if (_prevState === YSManager.StateRecording && (s === YSManager.StateReady || s === YSManager.StateNotReady)) {
                _showCritical(qsTr("acquisition stopped unexpectedly"))
            }
            _prevState = s
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        onActiveVehicleChanged: _reset()
    }

    Timer {
        id:             delayedTimer
        interval:       statusDelayedMs
        repeat:         false
        onTriggered:    _stale2 = true
    }

    Timer {
        id:             noResponseTimer
        interval:       noResponseMs
        repeat:         false
        onTriggered:    _stale5 = true
    }

    Timer {
        id:             warningBannerTimer
        interval:       _warningBannerMs
        repeat:         false
        onTriggered:    _warningBanner = ""
    }
}
