import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Layouts          1.2

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

    QGCPalette { id: qgcPal }

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
    }

    function _requestDpcStateChange(enabled) {
        _pendingDpcState = enabled
        pinField.text = ""
        _pinDialogVisible = true
    }

    function _applyDpcStateWithPin(enabled, pin) {
        var ok = CustomQmlInterface.setDpcKioskEnabledWithPin(enabled, pin)
        if (ok) {
            _setKnownState(enabled, true)
            CustomQmlInterface.logSecurityEvent("DPC kiosk " + (enabled ? "enabled" : "disabled") + " from QGC settings")
            _pinDialogVisible = false
            _requestStateRefresh()
        } else {
            dpcCheckbox.checked = _dpcStateEnabled
            CustomQmlInterface.showMessage(qsTr("Failed to control DPC app (invalid PIN or receiver error)"), 1) // Error
        }
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
                            enabled: _dpcStateKnown || !_isSyncing
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
                    _root.dpcCheckbox.checked = false
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
        onTriggered: _root._refreshUiState()
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
                    text: qsTr("Enter 8-digit admin PIN to turn DPC kiosk mode %1.")
                        .arg(_pendingDpcState ? qsTr("ON") : qsTr("OFF"))
                }

                QGCTextField {
                    id: pinField
                    width: parent.width
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
        if (!_refreshUiState()) {
            _requestStateRefresh()
        }
    }
}
