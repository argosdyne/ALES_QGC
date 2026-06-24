import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Layouts          1.2
import Qt.labs.settings         1.0

import QGroundControl                       1.0
import QGroundControl.Controls              1.0
import QGroundControl.FactSystem            1.0
import QGroundControl.Palette               1.0
import QGroundControl.ScreenTools           1.0

Rectangle {
    id:                 _root
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    property real _panelWidth:      _root.width * 0.84
    property real _margins:         ScreenTools.defaultFontPixelWidth
    property var  _customSettings:  QGroundControl.corePlugin.settings
    property Fact _dpcEnabled:      _customSettings.dpcKioskEnabled
    property bool _dpcSupported:    CustomQmlInterface.isDpcControlSupported()
    property bool _dpcStateKnown:   false
    property bool _dpcStateEnabled: false
    property bool _dpcStateFallback: false
    property bool _isSyncing:       true
    property bool _syncFailed:      false
    property string _diagText:      ""
    property bool _pinDialogVisible: false
    property bool _pendingDpcState: false
    property double _lockoutUntilMs: 0       // absolute epoch ms the lockout ends, 0 if none
    property int  _lastAttemptsRemaining: -1 // wrong-PIN attempts left before lockout, -1 if N/A
    property int  _nowTick: 0                // bumped every second to refresh the countdown text

    readonly property bool _isPinLockedOut: _lockoutUntilMs > 0 && _lockoutRemainingSec() > 0

    function _hasPinGateBanner() {
        return _isPinLockedOut || _lastAttemptsRemaining >= 0
    }

    QGCPalette { id: qgcPal }

    // Locally persisted lockout deadline (absolute epoch ms). Captured the moment a PIN
    // attempt reveals the lockout, so the countdown can be shown on page open / restart
    // without depending on the cross-process DPC query round-trip (which is unreliable here).
    Settings {
        id: lockoutPersist
        category: "DpcKioskLockout"
        property double persistedLockoutUntilMs: 0
    }

    Connections {
        target: CustomQmlInterface
        onDpcPinGateStateChanged: _root._applyPinGateUiFromCache()
    }

    function _lockoutRemainingSec() {
        _nowTick // depend on the 1s tick so _isPinLockedOut re-evaluates over time
        if (_lockoutUntilMs <= 0)
            return 0
        var rem = Math.ceil((_lockoutUntilMs - Date.now()) / 1000)
        return rem > 0 ? rem : 0
    }

    function _lockoutText() {
        _nowTick // create a binding dependency so this re-evaluates every second
        if (_lockoutUntilMs > 0) {
            var s = _lockoutRemainingSec()
            var mm = Math.floor(s / 60)
            var ss = s % 60
            return qsTr("Locked out — try again in %1:%2").arg(mm).arg(ss < 10 ? "0" + ss : "" + ss)
        }
        if (_lastAttemptsRemaining >= 0)
            return qsTr("Incorrect PIN — %1 attempt(s) remaining before lockout").arg(_lastAttemptsRemaining)
        return ""
    }

    function _loadPinGateFromStorage() {
        CustomQmlInterface.refreshDpcPinGateStateFromStorage()
    }

    function _restorePersistedLockout() {
        // Show a still-active lockout immediately on page open, sourced from QGC's own settings.
        if (lockoutPersist.persistedLockoutUntilMs > Date.now()) {
            _lockoutUntilMs = lockoutPersist.persistedLockoutUntilMs
            _lastAttemptsRemaining = 0
            _nowTick++
        } else if (lockoutPersist.persistedLockoutUntilMs > 0) {
            lockoutPersist.persistedLockoutUntilMs = 0  // stale/expired — clear it
        }
    }

    function _applyPinGateUiFromCache() {
        // Read Java in-memory cache only — refreshDpcPinGateStateFromStorage() here used to
        // clobber a fresh DPC broadcast before async prefs were flushed.
        var until = CustomQmlInterface.dpcLockoutUntilMs()
        var now = Date.now()
        if (until > now) {
            _lockoutUntilMs = until
            _lastAttemptsRemaining = 0
            _nowTick++
            return
        }
        if (_lockoutUntilMs > now) {
            return
        }
        var attempts = CustomQmlInterface.dpcAttemptsRemaining()
        _lockoutUntilMs = 0
        if (attempts >= 0) {
            _lastAttemptsRemaining = attempts
        }
        // Do not clear a visible attempts warning when the cache has no value yet.
    }

    function _activatePinGatePanel() {
        _loadPinGateFromStorage()
        _applyPinGateUiFromCache()
        CustomQmlInterface.requestDpcKioskState()
        pinGateSyncTimer.restart()
        if (_lockoutUntilMs > Date.now()) {
            _nowTick++
        }
    }

    function _setKnownState(enabled, isFallback) {
        _dpcStateEnabled = enabled
        _dpcStateKnown = true
        _dpcStateFallback = isFallback
        _dpcEnabled.rawValue = enabled
        dpcCheckbox.checked = enabled
        _isSyncing = false
        _syncFailed = false
    }

    function _refreshUiState() {
        CustomQmlInterface.reconcilePostRebootKioskState()
        CustomQmlInterface.refreshDpcKioskStateFromStorage()

        if (CustomQmlInterface.isBootForcedDpcKioskOn()) {
            _setKnownState(true, false)
            return true
        }

        if (CustomQmlInterface.hasKnownDpcKioskState()) {
            _setKnownState(CustomQmlInterface.getKnownDpcKioskStateEnabled(), false)
            return true
        }

        _dpcStateKnown = false
        _isSyncing = true
        _syncFailed = false
        return false
    }

    function _requestStateRefresh() {
        CustomQmlInterface.requestDpcKioskState()
        _isSyncing = true
        _syncFailed = false
        dpcStateRefreshTimer.restart()
        _activatePinGatePanel()
    }

    function _requestDpcStateChange(enabled) {
        if (_isPinLockedOut) {
            CustomQmlInterface.showMessage(
                qsTr("Admin PIN is locked out — wait for the countdown to finish."), 1) // Error
            return
        }
        _pendingDpcState = enabled
        pinField.text = ""
        _pinDialogVisible = true
    }

    function _applyDpcStateWithPin(enabled, pin) {
        // Clear any previous reason so the next one reflects THIS command's result.
        CustomQmlInterface.clearDpcReason()
        var ok = CustomQmlInterface.setDpcKioskEnabledWithPin(enabled, pin)
        if (!ok) {
            dpcCheckbox.checked = _dpcStateEnabled
            CustomQmlInterface.showMessage(qsTr("Failed to send command to DPC (PIN must be 8 digits, or receiver error)"), 1) // Error
            return
        }
        // The command was sent. The DPC verifies the PIN asynchronously and publishes a
        // result reason ("set" / "invalid_pin" / "locked_out"); poll for it to give feedback.
        _pinDialogVisible = false
        dpcReasonPollTimer.ticks = 0
        dpcReasonPollTimer.restart()
    }

    QGCFlickable {
        anchors.fill:   parent
        clip:           true
        contentHeight:  settingsColumn.height
        contentWidth:   settingsColumn.width

        ColumnLayout {
            id:                         settingsColumn
            anchors.horizontalCenter:   parent.horizontalCenter
            width:                      _panelWidth
            spacing:                    ScreenTools.defaultFontPixelHeight * 0.5

            QGCLabel {
                text:           qsTr("DPC Kiosk Control")
                font.family:    ScreenTools.demiboldFontFamily
            }

            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: content.height + (_margins * 3)
                color:                  qgcPal.windowShade

                Column {
                    id:                 content
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    anchors.margins:    _margins * 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    spacing:            ScreenTools.defaultFontPixelHeight * 0.6

                    QGCLabel {
                        width: parent.width
                        text: qsTr("Turn DPC kiosk mode on/off. When ON, DPC keeps QGC protected and relaunched.")
                        wrapMode: Text.WordWrap
                    }

                    QGCLabel {
                        width: parent.width
                        color: _dpcSupported ? qgcPal.colorGreen : qgcPal.colorRed
                        text: _dpcSupported
                            ? qsTr("Connection to DPC: Ready")
                            : qsTr("Connection to DPC: Not detected")
                        wrapMode: Text.WordWrap
                    }

                    QGCLabel {
                        width: parent.width
                        color: _isSyncing
                               ? qgcPal.colorOrange
                               : (_syncFailed
                                  ? qgcPal.warningText
                                  : (_dpcStateEnabled ? qgcPal.colorGreen : qgcPal.warningText))
                        text: _isSyncing
                            ? qsTr("Current DPC mode: Syncing...")
                            : (_syncFailed
                                ? (_diagText.indexOf("javaDiag=OLD_APK") >= 0 || _diagText.indexOf("initBridgeMethod=no") >= 0
                                    ? qsTr("Current DPC mode: QGC Android rebuild required")
                                    : qsTr("Current DPC mode: Unable to read DPC state"))
                                : (_dpcStateFallback
                                    ? qsTr("Current DPC mode (local): %1").arg(_dpcStateEnabled ? qsTr("ON") : qsTr("OFF"))
                                    : qsTr("Current DPC mode: %1").arg(_dpcStateEnabled ? qsTr("ON") : qsTr("OFF"))))
                        wrapMode: Text.WordWrap
                    }

                    QGCLabel {
                        width: parent.width
                        visible: _syncFailed && _diagText.length > 0
                        color: qgcPal.warningText
                        font.pointSize: ScreenTools.smallFontPointSize
                        text: _diagText
                        wrapMode: Text.WordWrap
                    }

                    // Admin-PIN feedback: lockout countdown always visible on this tab while active.
                    QGCLabel {
                        width: parent.width
                        visible: _root._isPinLockedOut
                                || (!_root._isPinLockedOut && _root._lastAttemptsRemaining >= 0)
                        color: _root._isPinLockedOut ? qgcPal.colorRed : qgcPal.colorOrange
                        font.family: ScreenTools.demiboldFontFamily
                        text: _root._lockoutText()
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        width: parent.width
                        spacing: _margins

                        QGCLabel {
                            Layout.fillWidth: true
                            text: qsTr("Enable DPC Kiosk Mode")
                        }

                        QGCCheckBox {
                            id: dpcCheckbox
                            checked: _dpcStateEnabled
                            enabled: (_dpcStateKnown || !_isSyncing) && !_root._isPinLockedOut
                            onClicked: {
                                var requested = checked
                                checked = _dpcStateEnabled
                                _root._requestDpcStateChange(requested)
                            }
                        }
                    }

                }
            }
        }
    }

    Timer {
        id: dpcStateRefreshTimer
        interval: 500
        repeat: true
        property int _ticks: 0
        onTriggered: {
            if (_root._refreshUiState()) {
                _root._applyPinGateUiFromCache()
                stop()
                _ticks = 0
                return
            }

            _ticks = _ticks + 1
            if (_ticks % 2 === 0) {
                CustomQmlInterface.requestDpcKioskState()
            }

            if (_ticks >= 16) {
                CustomQmlInterface.reconcilePostRebootKioskState()
                CustomQmlInterface.refreshDpcKioskStateFromStorage()
                if (CustomQmlInterface.isBootForcedDpcKioskOn()) {
                    _root._setKnownState(true, false)
                } else if (CustomQmlInterface.hasKnownDpcKioskState()) {
                    _root._setKnownState(CustomQmlInterface.getKnownDpcKioskStateEnabled(), false)
                } else {
                    _root._isSyncing = false
                    _root._syncFailed = true
                    _root._dpcStateKnown = false
                    _root._diagText = CustomQmlInterface.getDpcKioskDiagnostics()
                    dpcCheckbox.checked = false
                }
                stop()
                _ticks = 0
            }
        }
    }

    Timer {
        id: dpcStateSyncTimer
        interval: 2000
        repeat: true
        running: _dpcStateKnown
        onTriggered: {
            _root._refreshUiState()
            if (!_root._hasPinGateBanner()) {
                _root._loadPinGateFromStorage()
            }
            _root._applyPinGateUiFromCache()
            if (!_root._hasPinGateBanner()) {
                CustomQmlInterface.requestDpcKioskState()
            }
        }
    }

    // After tab open / state refresh, poll until DPC query response updates PIN gate cache.
    Timer {
        id: pinGateSyncTimer
        interval: 300
        repeat: true
        property int ticks: 0
        onTriggered: {
            ticks += 1
            var reason = CustomQmlInterface.lastDpcReason()
            if (reason.length > 0) {
                _root._applyPinGateUiFromCache()
            } else if (ticks % 2 === 0) {
                _root._applyPinGateUiFromCache()
            }

            if (!_root._hasPinGateBanner() && ticks % 4 === 0) {
                CustomQmlInterface.requestDpcKioskState()
            }

            if (_root._hasPinGateBanner()) {
                if (reason.length > 0) {
                    CustomQmlInterface.clearDpcReason()
                }
                stop()
                ticks = 0
                return
            }

            if (ticks >= 60) {
                stop()
                ticks = 0
            }
        }
        onRunningChanged: {
            if (!running)
                ticks = 0
        }
    }

    // Polls the DPC's verification result after a PIN-protected command and shows feedback
    // (incorrect PIN / locked out / updated). Times out quietly after ~4s.
    Timer {
        id: dpcReasonPollTimer
        interval: 300
        repeat: true
        property int ticks: 0
        onTriggered: {
            ticks += 1
            var reason = CustomQmlInterface.lastDpcReason()
            if (reason === "invalid_pin") {
                _root._applyPinGateUiFromCache()
                var attemptsLeft = _root._lastAttemptsRemaining
                if (attemptsLeft < 0) {
                    attemptsLeft = CustomQmlInterface.dpcAttemptsRemaining()
                    if (attemptsLeft >= 0) {
                        _root._lastAttemptsRemaining = attemptsLeft
                    }
                }
                CustomQmlInterface.clearDpcReason()
                dpcCheckbox.checked = _root._dpcStateEnabled
                CustomQmlInterface.showMessage(attemptsLeft >= 0
                    ? qsTr("Incorrect admin PIN — %1 attempt(s) remaining.").arg(attemptsLeft)
                    : qsTr("Incorrect admin PIN."), 2) // Warning
                stop()
            } else if (reason === "locked_out") {
                _root._applyPinGateUiFromCache()
                var until = CustomQmlInterface.dpcLockoutUntilMs()
                if (until <= 0 && ticks < 20) {
                    return
                }
                CustomQmlInterface.clearDpcReason()
                dpcCheckbox.checked = _root._dpcStateEnabled
                _root._lastAttemptsRemaining = 0
                if (until > 0) {
                    _root._lockoutUntilMs = until
                    lockoutPersist.persistedLockoutUntilMs = until  // persist for page-open display
                }
                _root._nowTick++
                CustomQmlInterface.showMessage(qsTr("Too many incorrect attempts. Locked out — see the countdown."), 1) // Error
                stop()
            } else if (reason === "query") {
                _root._applyPinGateUiFromCache()
                if (_root._lockoutUntilMs > Date.now() || _root._lastAttemptsRemaining >= 0) {
                    CustomQmlInterface.clearDpcReason()
                    stop()
                }
            } else if (reason === "set") {
                CustomQmlInterface.clearDpcReason()
                _root._lockoutUntilMs = 0
                _root._lastAttemptsRemaining = -1
                lockoutPersist.persistedLockoutUntilMs = 0
                CustomQmlInterface.logSecurityEvent("DPC kiosk state change accepted from QGC settings")
                _root._refreshUiState()
                CustomQmlInterface.showMessage(qsTr("DPC kiosk mode updated."), 3) // Success
                stop()
            } else if (reason === "set_failed") {
                CustomQmlInterface.clearDpcReason()
                dpcCheckbox.checked = _root._dpcStateEnabled
                CustomQmlInterface.showMessage(qsTr("DPC could not change kiosk state."), 1) // Error
                stop()
            } else if (ticks >= 13) {
                // ~4s with no conclusive reason: reconcile state and give up quietly.
                _root._refreshUiState()
                stop()
            }
        }
    }

    // Drives the live lockout countdown and auto-clears when the lockout elapses.
    Timer {
        id: lockoutTicker
        interval: 1000
        repeat: true
        running: _root._lockoutUntilMs > 0
        onTriggered: {
            _root._nowTick++
            if (_root._lockoutRemainingSec() <= 0) {
                _root._lockoutUntilMs = 0
                _root._lastAttemptsRemaining = -1
                lockoutPersist.persistedLockoutUntilMs = 0
                CustomQmlInterface.requestDpcKioskState()
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#88000000"
        visible: _pinDialogVisible
        z: 1000

        Rectangle {
            width: Math.min(_root.width * 0.8, 420)
            color: qgcPal.window
            border.color: qgcPal.text
            border.width: 1
            anchors.centerIn: parent
            radius: 6
            height: pinColumn.height + (_margins * 3)

            Column {
                id: pinColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: _margins * 1.5
                spacing: _margins

                QGCLabel {
                    text: qsTr("Admin PIN Verification")
                    font.family: ScreenTools.demiboldFontFamily
                }

                QGCLabel {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    visible: _root._isPinLockedOut
                    color: qgcPal.colorRed
                    text: _root._lockoutText()
                }

                QGCLabel {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    visible: !_root._isPinLockedOut
                    text: qsTr("Enter 8-digit admin PIN to turn DPC kiosk mode %1.")
                        .arg(_pendingDpcState ? qsTr("ON") : qsTr("OFF"))
                }

                QGCTextField {
                    id: pinField
                    width: parent.width
                    visible: !_root._isPinLockedOut
                    enabled: !_root._isPinLockedOut
                    inputMethodHints: Qt.ImhDigitsOnly
                    echoMode: TextInput.Password
                    maximumLength: 8
                    placeholderText: qsTr("8-digit PIN")
                }

                Row {
                    spacing: _margins

                    QGCButton {
                        text: qsTr("Cancel")
                        onClicked: {
                            _pinDialogVisible = false
                            dpcCheckbox.checked = _dpcStateEnabled
                        }
                    }

                    QGCButton {
                        text: qsTr("Apply")
                        enabled: !_root._isPinLockedOut
                        onClicked: {
                            if (!/^\d{8}$/.test(pinField.text)) {
                                CustomQmlInterface.showMessage(qsTr("PIN must be exactly 8 digits"), 2) // Warning
                                return
                            }
                            _root._applyDpcStateWithPin(_pendingDpcState, pinField.text)
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        _restorePersistedLockout()
        _activatePinGatePanel()
        if (!_refreshUiState()) {
            _requestStateRefresh()
        }
    }

    onVisibleChanged: {
        if (visible) {
            _restorePersistedLockout()
            _activatePinGatePanel()
        }
    }
}
