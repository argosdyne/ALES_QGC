/****************************************************************************
 *
 * LiDAR Setup > Device (YS-07, UI Y-08)
 *   ① Get Status source + last status time
 *   ② Power card: acquisition / logging / USB / computer temp + Power off (disabled while recording or armed)
 *   ③ Confirmation dialog before Power Off
 *   ④ Status card: Get Status bits as readable text + Copy status
 *   ⑤ Power Off has no reply on success - shows POWERED OFF after 5 s, error ACK = critical message
 * UI only: uses the existing YSManager status bytes and powerOff().
 *
 ****************************************************************************/

import QtQuick          2.11
import QtQuick.Controls 2.4
import QtQuick.Dialogs  1.3
import QtQuick.Layouts  1.11

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0
import CustomQuickInterface         1.0

Rectangle {
    id:     root
    color:  qgcPal.window

    property var  _settings:        QGroundControl.corePlugin.settings
    property var  _ys:              QGroundControl.corePlugin.ysManager
    property var  _activeVehicle:   QGroundControl.multiVehicleManager.activeVehicle
    property real _cardMargin:      ScreenTools.defaultFontPixelWidth
    property real _rowSpacing:      ScreenTools.defaultFontPixelHeight * 0.3
    property real _colSpacing:      ScreenTools.defaultFontPixelWidth * 1.5
    // Y-08 card widths (Power narrower than Status)
    property real _powerCardWidth:  ScreenTools.defaultFontPixelWidth * 38
    property real _statusCardWidth: ScreenTools.defaultFontPixelWidth * 46
    property string _sep:           " · "

    // MAV_CMD_USER_2 = YellowScan Power Off (YSManager sends it; MAV_CMD enum is not exposed to QML)
    readonly property int _cmdPowerOff:     31011
    // YS-07 ⑤: Power Off success has no reply - POWERED OFF after this long without an error ACK
    readonly property int _powerOffWaitMs:  5000
    readonly property int _powerOffWaitSec: _powerOffWaitMs / 1000
    readonly property real _pollHz:         _ys && _ys.statusPollIntervalMs > 0 ? 1000 / _ys.statusPollIntervalMs : 0

    property bool _valid:           _ys && _ys.statusValid
    property bool _armed:           _activeVehicle ? _activeVehicle.armed : false
    property bool _recording:       _ys && (_ys.acquisitionRunning || _ys.lidarState === YSManager.StateRecording
                                            || _ys.lidarState === YSManager.StateStarting || _ys.lidarState === YSManager.StateStopping)
    property bool _linkUp:          _ys && _ys.lidarState !== YSManager.StateNoLink && _ys.lidarState !== YSManager.StateDisabled
    property bool _powerOffPending: powerOffTimer.running
    property bool _poweredOffLocal: false   // Get Status stopped answering within _powerOffWaitMs after Power Off
    // Birdcom ACKs Power Off with FAILED even on success (the LiDAR sends nothing back on success), so the ACK alone
    // is not trusted. Birdcom only forwards a Get Status reply when the LiDAR answered, so a status reply after the
    // ACK means the LiDAR is still on.
    property bool   _powerOffAckSeen:       false
    property string _powerOffAckResult:     ""
    property bool   _statusAfterPowerOff:   false
    property bool _poweredOff:      _poweredOffLocal || (_ys && _ys.lidarState === YSManager.StatePoweredOff)
    property bool _canPowerOff:     _linkUp && !_poweredOff && !_powerOffPending && !_recording && !_armed
    property string _lastStatusTime: ""

    QGCPalette { id: qgcPal }

    //-------------------------------------------------------------------------
    // Get Status bit positions (YellowScan Serial Interface Control v4.0; same as Birdcom ConstForLidar_YS.h)

    // INS info (YS_STA_00 byte 0)
    readonly property int _insInfoError:        0
    readonly property int _insInfoLocked:       1
    readonly property int _insInfoDgnss:        2
    readonly property int _insInfoT04Download:  3
    readonly property int _insInfoLogging:      4
    // Scanner info (YS_STA_00 byte 1)
    readonly property int _scnInfoError:        0
    readonly property int _scnInfoReady:        1
    readonly property int _scnInfoInitPhase:    2
    readonly property int _scnInfoLogging:      3
    readonly property int _scnInfoStarted:      4
    // General info (YS_STA_00 byte 2)
    readonly property int _genInfoUsbPresent:   0
    readonly property int _genInfoUsbSpaceLow:  1
    readonly property int _genInfoUsbFull:      2
    readonly property int _genInfoDataLogging:  3
    // INS errors (YS_STA_00 byte 3)
    readonly property int _insErrNotPinged:     0
    readonly property int _insErrConnection:    1
    readonly property int _insErrNoData:        2
    readonly property int _insErrCommand:       3
    readonly property int _insErrWrite:         4
    readonly property int _insErrTimeNotSet:    5
    // Scanner errors (YS_STA_01 byte 0)
    readonly property int _scnErrDataDropped:   0
    readonly property int _scnErrNoData:        1
    readonly property int _scnErrNoTimeSync:    2
    readonly property int _scnErrOverheat:      3
    readonly property int _scnErrTempWarning:   4
    // Internal computer errors (YS_STA_01 byte 1)
    readonly property int _intErrOverheat:      0
    readonly property int _intErrTempWarning:   1
    // Camera errors (YS_STA_01 byte 2)
    readonly property int _camErrConnection:    0
    readonly property int _camErrAdjustSetting: 1
    readonly property int _camErrTakePhoto:     2

    // Thresholds each flag stands for (same spec). The LiDAR sends only the flag, not a measured temperature / free space.
    readonly property int _usbSpaceLowGb:       30
    readonly property int _usbFullGb:           1
    readonly property int _intOverheatC:        70
    readonly property int _intTempWarningC:     65

    // Byte position of the INS / scanner error bytes inside the NAMED_VALUE_INT value (YS_STA_00 byte 3, YS_STA_01 byte 0)
    readonly property int _insErrByteIndex:     3
    readonly property int _scnErrByteIndex:     0
    readonly property int _mavResultAccepted:   0   // MAV_RESULT_ACCEPTED

    // Full INS / scanner error bytes. YSManager.insErr / scnErr are only 0/1 (any error), so the raw bytes are taken
    // from the Get Status reply in YSManager.lastReceivedMessage. -1 until the first reply.
    property int _insErrRaw:        -1
    property int _scnErrRaw:        -1

    function _bit(v, b) { return (v & (1 << b)) !== 0 }
    function _list(items) { return items.length ? items.join(", ") : qsTr("None") }
    function _hex(v) { return "0x" + ("0" + v.toString(16).toUpperCase()).slice(-2) }

    property string _acqText:       _poweredOff ? qsTr("POWERED OFF") : (!_valid ? "--" : (_ys.acquisitionRunning ? qsTr("Running") : qsTr("Stopped")))
    property string _loggingText:   !_valid ? "--" : (_bit(_ys.genInfo, _genInfoDataLogging) ? qsTr("Yes") : qsTr("No"))
    property string _usbText: {
        if (!_valid)                                    return "--"
        if (!_bit(_ys.genInfo, _genInfoUsbPresent))     return qsTr("Not present")
        if (_bit(_ys.genInfo, _genInfoUsbFull))         return qsTr("Present") + _sep + qsTr("full (≤ %1 GB)").arg(_usbFullGb)
        if (_bit(_ys.genInfo, _genInfoUsbSpaceLow))     return qsTr("Present") + _sep + qsTr("low (≤ %1 GB)").arg(_usbSpaceLowGb)
        return qsTr("Present") + _sep + qsTr("space OK")
    }
    property string _tempText: {
        if (!_valid)                                    return "--"
        if (_bit(_ys.intErr, _intErrOverheat))          return qsTr("Overheating (≥ %1 °C)").arg(_intOverheatC)
        if (_bit(_ys.intErr, _intErrTempWarning))       return qsTr("Warning (> %1 °C)").arg(_intTempWarningC)
        return qsTr("OK (< %1 °C)").arg(_intTempWarningC)
    }
    property string _insText: {
        if (!_valid) return "--"
        var p = [ _bit(_ys.insInfo, _insInfoLocked)  ? qsTr("Locked")  : qsTr("Not locked"),
                  _bit(_ys.insInfo, _insInfoDgnss)   ? qsTr("DGNSS")   : qsTr("no DGNSS"),
                  _bit(_ys.insInfo, _insInfoLogging) ? qsTr("logging") : qsTr("not logging") ]
        if (_bit(_ys.insInfo, _insInfoT04Download)) p.push(qsTr("T04 download"))
        if (_bit(_ys.insInfo, _insInfoError))       p.push(qsTr("error"))
        return p.join(_sep)
    }
    property string _scnText: {
        if (!_valid) return "--"
        var p = [ _bit(_ys.scnInfo, _scnInfoInitPhase) ? qsTr("Initializing") : (_bit(_ys.scnInfo, _scnInfoReady) ? qsTr("Ready") : qsTr("Not ready")),
                  _bit(_ys.scnInfo, _scnInfoStarted)   ? qsTr("spinning")     : qsTr("not spinning") ]
        if (_bit(_ys.scnInfo, _scnInfoLogging)) p.push(qsTr("logging"))
        if (_bit(_ys.scnInfo, _scnInfoError))   p.push(qsTr("error"))
        return p.join(_sep)
    }
    property string _insErrText: {
        if (!_valid || _insErrRaw < 0) return "--"
        var p = []
        if (_bit(_insErrRaw, _insErrNotPinged))     p.push(qsTr("Not pinged at boot"))
        if (_bit(_insErrRaw, _insErrConnection))    p.push(qsTr("Connection error"))
        if (_bit(_insErrRaw, _insErrNoData))        p.push(qsTr("No data"))
        if (_bit(_insErrRaw, _insErrCommand))       p.push(qsTr("Command failed"))
        if (_bit(_insErrRaw, _insErrWrite))         p.push(qsTr("File write error"))
        if (_bit(_insErrRaw, _insErrTimeNotSet))    p.push(qsTr("Time not set"))
        return _list(p)
    }
    property string _scnErrText: {
        if (!_valid || _scnErrRaw < 0) return "--"
        var p = []
        if (_bit(_scnErrRaw, _scnErrDataDropped))   p.push(qsTr("Data dropped (USB too slow)"))
        if (_bit(_scnErrRaw, _scnErrNoData))        p.push(qsTr("No data"))
        if (_bit(_scnErrRaw, _scnErrNoTimeSync))    p.push(qsTr("No time sync"))
        if (_bit(_scnErrRaw, _scnErrOverheat))      p.push(qsTr("Overheating"))
        if (_bit(_scnErrRaw, _scnErrTempWarning))   p.push(qsTr("Temperature warning"))
        return _list(p)
    }
    property string _camErrText: {
        if (!_valid) return "--"
        var p = []
        if (_bit(_ys.camErr, _camErrConnection))    p.push(qsTr("Connection error"))
        if (_bit(_ys.camErr, _camErrAdjustSetting)) p.push(qsTr("Settings error"))
        if (_bit(_ys.camErr, _camErrTakePhoto))     p.push(qsTr("Photo error"))
        return _list(p)
    }
    property string _compErrText: {
        if (!_valid) return "--"
        var p = []
        if (_bit(_ys.intErr, _intErrOverheat))      p.push(qsTr("Overheating (≥ %1 °C)").arg(_intOverheatC))
        if (_bit(_ys.intErr, _intErrTempWarning))   p.push(qsTr("Above %1 °C").arg(_intTempWarningC))
        return _list(p)
    }

    function _statusReport() {
        var lines = [
            "YellowScan LiDAR status",
            "Last status: " + (_lastStatusTime !== "" ? _lastStatusTime : "--"),
            "Acquisition: " + _acqText,
            "Data logging: " + _loggingText,
            "USB stick: " + _usbText,
            "Computer temp.: " + _tempText,
            "INS: " + _insText,
            "Scanner: " + _scnText,
            "INS errors: " + _insErrText,
            "Scanner errors: " + _scnErrText,
            "Camera errors: " + _camErrText,
            "Computer errors: " + _compErrText
        ]
        if (_ys) {
            lines.push("Raw: INS " + _hex(_ys.insInfo) + " SCN " + _hex(_ys.scnInfo) + " GEN " + _hex(_ys.genInfo)
                       + " INSERR " + (_insErrRaw < 0 ? "--" : _hex(_insErrRaw))
                       + " SCNERR " + (_scnErrRaw < 0 ? "--" : _hex(_scnErrRaw))
                       + " INTERR " + _hex(_ys.intErr) + " CAMERR " + _hex(_ys.camErr))
        }
        return lines.join("\n")
    }

    function _copyStatus() {
        clipboardHelper.text = _statusReport()
        clipboardHelper.selectAll()
        clipboardHelper.copy()
        clipboardHelper.text = ""
    }

    function _powerOffNote() {
        if (_powerOffPending)   return qsTr("Power off sent — checking for %1 s that Get Status stops…").arg(_powerOffWaitSec)
        if (_poweredOff)        return qsTr("POWERED OFF — restart the LiDAR at the drone (power button).")
        if (!_linkUp)           return qsTr("No vehicle link.")
        if (_recording)         return qsTr("Disabled while acquiring — stop acquisition first.")
        if (_armed)             return qsTr("Disabled while the vehicle is armed.")
        return ""
    }

    function _sendPowerOff() {
        if (!_canPowerOff) {
            return
        }
        _poweredOffLocal = false
        _powerOffAckSeen = false
        _powerOffAckResult = ""
        _statusAfterPowerOff = false
        powerOffTimer.restart()
        _ys.powerOff()
    }

    //-------------------------------------------------------------------------
    // ⑤ Power Off: no reply on success -> POWERED OFF after 5 s; error ACK -> critical message

    Timer {
        id:         powerOffTimer
        interval:   _powerOffWaitMs
        repeat:     false
        onTriggered: {
            if (!_statusAfterPowerOff) {
                _poweredOffLocal = true
            } else {
                mainWindow.showMessageDialog(qsTr("LiDAR power off failed"),
                                             (_powerOffAckResult !== "" ? qsTr("Power Off reply: %1. ").arg(_powerOffAckResult) : "")
                                             + qsTr("The LiDAR still answers Get Status, so it is still on."))
            }
        }
    }

    Connections {
        target: _ys
        onStatusChanged: {
            if (_ys.statusValid) {
                _lastStatusTime = Qt.formatTime(new Date(), "hh:mm:ss")
                // LiDAR answered after the power-off window, so it is on again
                if (_poweredOffLocal && !powerOffTimer.running) {
                    _poweredOffLocal = false
                }
            }
        }
        onMessageChanged: {
            var msg = _ys.lastReceivedMessage

            // Get Status reply: "NAMED_VALUE_INT YS_STA_0x VALUE=0X<8 hex>" (YSManager upper-cases it)
            var s = msg.match(/^NAMED_VALUE_INT (YS_STA_0[01]) VALUE=0X([0-9A-F]+)/i)
            if (s) {
                var v = parseInt(s[2], 16)
                if (s[1].toUpperCase() === "YS_STA_00") {
                    _insErrRaw = (v >>> (8 * _insErrByteIndex)) & 0xFF
                } else {
                    _scnErrRaw = (v >>> (8 * _scnErrByteIndex)) & 0xFF
                }
                // A reply after the Power Off ACK came from a LiDAR that is still on
                if (powerOffTimer.running && _powerOffAckSeen) {
                    _statusAfterPowerOff = true
                }
                return
            }

            // Power Off reply: "COMMAND_ACK cmd=<cmd> result=<n> (<name>)"
            if (!powerOffTimer.running) {
                return
            }
            var m = msg.match(/^COMMAND_ACK cmd=(\d+) result=(\d+) \(([^)]*)\)/)
            if (!m || parseInt(m[1]) !== _cmdPowerOff) {
                return
            }
            _powerOffAckSeen = true
            _powerOffAckResult = m[3]
            if (parseInt(m[2]) === _mavResultAccepted) {
                powerOffTimer.stop()
                _poweredOffLocal = true
            }
            // Any other result: decided when powerOffTimer ends, from whether Get Status still answers
        }
    }

    // Lets Copy status reach the system clipboard without C++ support
    TextEdit {
        id:         clipboardHelper
        visible:    false
    }

    //-------------------------------------------------------------------------
    // Layout (Y-08)

    QGCFlickable {
        anchors.fill:       parent
        contentWidth:       width
        contentHeight:      mainColumn.height
        clip:               true

        ColumnLayout {
            id:         mainColumn
            width:      parent.width
            spacing:    _colSpacing

            //-- ① Source + last status
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: infoLabel.contentHeight + ScreenTools.defaultFontPixelHeight * 0.4
                radius:                 ScreenTools.defaultFontPixelWidth / 2
                color:                  qgcPal.colorBlue

                QGCLabel {
                    id:                     infoLabel
                    anchors.left:           parent.left
                    anchors.right:          parent.right
                    anchors.margins:        ScreenTools.defaultFontPixelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    color:                  "white"
                    wrapMode:               Text.WordWrap
                    font.pointSize:         ScreenTools.smallFontPointSize
                    text:                   qsTr("ⓘ Device status from Get Status (%1 Hz).").arg(_pollHz) + _sep
                                            + (_lastStatusTime !== "" ? qsTr("Last status %1").arg(_lastStatusTime) : qsTr("No status yet"))
                }
            }

            RowLayout {
                Layout.fillWidth:   true
                spacing:            _colSpacing

                //-------------------------------------------------------------
                //-- ② Power + Model
                ColumnLayout {
                    Layout.preferredWidth:  _powerCardWidth
                    Layout.maximumWidth:    _powerCardWidth
                    Layout.alignment:       Qt.AlignTop
                    spacing:                _rowSpacing

                    SectionTitle { text: qsTr("Power") }

                    Card {
                        GridLayout {
                            width:          parent.width
                            columns:        2
                            rowSpacing:     _rowSpacing
                            columnSpacing:  _colSpacing

                            QGCLabel { text: qsTr("Acquisition"); Layout.fillWidth: true }
                            ValueLabel { text: _acqText }
                            QGCLabel { text: qsTr("Data logging"); Layout.fillWidth: true }
                            ValueLabel { text: _loggingText }
                            QGCLabel { text: qsTr("USB stick"); Layout.fillWidth: true }
                            ValueLabel { text: _usbText }
                            QGCLabel { text: qsTr("Computer temp."); Layout.fillWidth: true }
                            ValueLabel { text: _tempText }
                        }

                        QGCButton {
                            text:       qsTr("Power off LiDAR…")
                            enabled:    _canPowerOff
                            onClicked:  powerOffDialogComponent.createObject(mainWindow).open()
                        }

                        NoteLabel {
                            visible:    text !== ""
                            text:       _powerOffNote()
                        }
                    }

                    SectionTitle { text: qsTr("Model"); Layout.topMargin: _rowSpacing }

                    Card {
                        GridLayout {
                            width:          parent.width
                            columns:        2
                            rowSpacing:     _rowSpacing
                            columnSpacing:  _colSpacing

                            QGCLabel { text: qsTr("LiDAR"); Layout.fillWidth: true }
                            ValueLabel { text: _settings ? _settings.ysModel.enumStringValue : "" }
                            QGCLabel { text: qsTr("Camera"); Layout.fillWidth: true }
                            ValueLabel { text: _settings ? _settings.ysCamera.enumStringValue : "" }
                        }

                        NoteLabel {
                            text: qsTr("Chosen in Connection — the serial protocol has no model query, so unsupported items are disabled.")
                        }
                    }
                }

                //-------------------------------------------------------------
                //-- ④ Status (Get Status bits)
                ColumnLayout {
                    Layout.preferredWidth:  _statusCardWidth
                    Layout.maximumWidth:    _statusCardWidth
                    Layout.alignment:       Qt.AlignTop
                    spacing:                _rowSpacing

                    SectionTitle { text: qsTr("Status (Get Status bits)") }

                    Card {
                        GridLayout {
                            width:          parent.width
                            columns:        2
                            rowSpacing:     _rowSpacing
                            columnSpacing:  _colSpacing

                            QGCLabel { text: qsTr("INS"); Layout.fillWidth: true }
                            ValueLabel { text: _insText }
                            QGCLabel { text: qsTr("Scanner"); Layout.fillWidth: true }
                            ValueLabel { text: _scnText }
                            QGCLabel { text: qsTr("INS errors"); Layout.fillWidth: true }
                            ValueLabel { text: _insErrText }
                            QGCLabel { text: qsTr("Camera errors"); Layout.fillWidth: true }
                            ValueLabel { text: _camErrText }
                            QGCLabel { text: qsTr("Scanner errors"); Layout.fillWidth: true }
                            ValueLabel { text: _scnErrText }
                            QGCLabel { text: qsTr("Computer errors"); Layout.fillWidth: true }
                            ValueLabel { text: _compErrText }
                        }

                        QGCButton {
                            text:       qsTr("Copy status")
                            enabled:    _valid
                            onClicked:  _copyStatus()
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    //-- ③ Confirmation
    Component {
        id: powerOffDialogComponent

        // Own Cancel / Power off row at the bottom (Y-08) - the standard header buttons only offer "Ok"
        QGCPopupDialog {
            id:         powerOffDialog
            title:      qsTr("Power off LiDAR?")
            buttons:    0

            ColumnLayout {
                width:      ScreenTools.defaultFontPixelWidth * 42
                spacing:    ScreenTools.defaultFontPixelHeight

                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    text:               qsTr("The LiDAR shuts down and must be restarted at the drone (power button) to record again.")
                }
                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    text:               qsTr("Acquisition is stopped — data on the USB stick is closed safely.")
                }
                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    font.pointSize:     ScreenTools.smallFontPointSize
                    opacity:            0.6
                    text:               qsTr("No reply on success — QGC shows \"Powered off\" when status stops (%1 s). Disabled while acquiring or armed.").arg(_powerOffWaitSec)
                }
                RowLayout {
                    Layout.alignment:   Qt.AlignRight
                    spacing:            ScreenTools.defaultFontPixelWidth

                    QGCButton {
                        text:       qsTr("Cancel")
                        onClicked:  powerOffDialog.close()
                    }
                    QGCButton {
                        text:       qsTr("Power off")
                        primary:    true
                        onClicked: {
                            powerOffDialog.close()
                            _sendPowerOff()
                        }
                    }
                }
            }
        }
    }

    //-------------------------------------------------------------------------
    // Local components (same look as LidarSettingsPage)

    component SectionTitle: QGCLabel {
        font.family: ScreenTools.demiboldFontFamily
    }

    component NoteLabel: QGCLabel {
        width:          parent ? parent.width : 0
        wrapMode:       Text.WordWrap
        font.pointSize: ScreenTools.smallFontPointSize
        opacity:        0.6
    }

    component ValueLabel: QGCLabel {
        font.family:            ScreenTools.demiboldFontFamily
        font.bold:              true
        color:                  qgcPal.text
        horizontalAlignment:    Text.AlignRight
        Layout.alignment:       Qt.AlignRight
    }

    // Shaded card; children are stacked in a column
    component Card: Rectangle {
        default property alias contents: cardCol.data
        Layout.fillWidth:       true
        Layout.preferredHeight: cardCol.height + (_cardMargin * 2)
        color:                  qgcPal.windowShade

        Column {
            id:                 cardCol
            anchors.margins:    _cardMargin
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.top:        parent.top
            spacing:            _rowSpacing
        }
    }
}
