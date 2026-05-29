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
    property bool _dpcStateEnabled: _dpcEnabled.rawValue
    property bool _dpcStateFallback: false
    property bool _isSyncing:       false
    property bool _pinDialogVisible: false
    property bool _pendingDpcState: _dpcEnabled.rawValue

    QGCPalette { id: qgcPal }

    function _updateKnownStateFromBridge() {
        var bridgeKnown = CustomQmlInterface.hasKnownDpcKioskState()
        if (bridgeKnown) {
            _dpcStateEnabled = CustomQmlInterface.getKnownDpcKioskStateEnabled()
            _dpcEnabled.rawValue = _dpcStateEnabled
            _dpcStateKnown = true
            dpcCheckbox.checked = _dpcStateEnabled
            _dpcStateFallback = false
            _isSyncing = false
        }
    }

    function _requestStateRefresh() {
        CustomQmlInterface.requestDpcKioskState()
        _isSyncing = true
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
            // Apply optimistic state immediately so UI does not stay in "Syncing..."
            _dpcEnabled.rawValue = enabled
            _dpcStateEnabled = enabled
            _dpcStateKnown = true
            _dpcStateFallback = true
            dpcCheckbox.checked = enabled
            CustomQmlInterface.logSecurityEvent("DPC kiosk " + (enabled ? "enabled" : "disabled") + " from QGC settings")
            _pinDialogVisible = false
            _requestStateRefresh()
        } else {
            dpcCheckbox.checked = _dpcEnabled.rawValue
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
                               : (_dpcStateEnabled ? qgcPal.colorGreen : qgcPal.warningText)
                        text: _isSyncing
                            ? qsTr("Current DPC mode: Syncing...")
                            : (_dpcStateKnown
                            ? (_dpcStateFallback
                                ? qsTr("Current DPC mode (local): %1").arg(_dpcStateEnabled ? qsTr("ON") : qsTr("OFF"))
                                : qsTr("Current DPC mode: %1").arg(_dpcStateEnabled ? qsTr("ON") : qsTr("OFF")))
                            : qsTr("Current DPC mode (local): %1").arg(_dpcEnabled.rawValue ? qsTr("ON") : qsTr("OFF")))
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
                            checked: _dpcEnabled.rawValue
                            enabled: true
                            onClicked: {
                                var requested = checked
                                checked = _dpcEnabled.rawValue
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
            _root._updateKnownStateFromBridge()
            _ticks = _ticks + 1
            if (_root._dpcStateKnown || _ticks >= 6) {
                if (!_root._dpcStateKnown) {
                    // Bridge not available on this build. Fallback to local setting state.
                    _root._dpcStateKnown = true
                    _root._dpcStateEnabled = _root._dpcEnabled.rawValue
                    _root._dpcStateFallback = true
                    dpcCheckbox.checked = _root._dpcStateEnabled
                }
                _root._isSyncing = false
                stop()
                _ticks = 0
            }
        }
    }

    Timer {
        id: dpcStateSyncTimer
        interval: 1500
        repeat: true
        running: true
        onTriggered: _root._updateKnownStateFromBridge()
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
                            dpcCheckbox.checked = _dpcEnabled.rawValue
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
        _requestStateRefresh()
    }
}
