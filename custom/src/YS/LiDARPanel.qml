/****************************************************************************
 *
 * YS-03 Fly View LiDAR panel (UI Y-01 / Y-02)
 *   ③ header: state chip + subtitle (model · link)
 *   ④ PRE-CHECK: six rows from 1 Hz Get Status
 *   ⑤ Acquisition Start / Stop (YS-04, Y-02 / Y-03 / Y-03b) - commands and reject handling in LiDARAcquisition.qml
 *   ⑥ camera summary
 *   ⑦ alarm row + LiDAR Setup link
 * Bit decoding and state decisions are in YSManager; this file only displays them.
 *
 ****************************************************************************/

import QtQuick          2.11
import QtQuick.Layouts  1.11

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Palette       1.0
import CustomQuickInterface         1.0

Rectangle {
    id:             _root
    width:          ScreenTools.defaultFontPixelWidth * 38
    height:         Math.min(mainColumn.height + (_margins * 2), maxHeight)
    radius:         ScreenTools.defaultFontPixelWidth / 2
    color:          qgcPal.window

    property real maxHeight     ///< Set by the parent: available height, panel scrolls beyond it

    property var  _settings:        QGroundControl.corePlugin.settings
    property var  _ys:              QGroundControl.corePlugin.ysManager
    property int  _state:           _ys ? _ys.lidarState : YSManager.StateDisabled
    property bool _statusValid:     _ys ? _ys.statusValid : false
    property bool _cameraInstalled: _settings ? _settings.ysCamera.rawValue !== 0 : false
    property real _margins:         ScreenTools.defaultFontPixelWidth * 1.5
    property real _rowSpacing:      ScreenTools.defaultFontPixelHeight * 0.4
    property string _sep:           " · "
    property bool _cameraParamsRequested: false
    property var  _acq:             mainWindow.lidarAcquisition
    property bool _startRejected:   _acq ? _acq.startRejected : false
    property int  _rejectRow:       _startRejected ? _acq.rejectRowIndex : -1
    property bool _recording:       _state === YSManager.StateRecording
    // YS-05 (Y-04 / Y-05): warning / critical / no-response from LiDARAlerts
    property var  _alerts:          mainWindow.lidarAlerts
    property bool _noResponse:      !!_alerts && _alerts.noResponse
    property bool _poweredOff:      !!_alerts && _alerts.poweredOff
    property bool _delayed:         !!_alerts && _alerts.delayed
    property int  _criticalCount:   _alerts ? _alerts.criticalCount : 0
    // YS-08 ①: elapsed time from the Start ACK (LiDARTrackRecorder)
    property var  _track:           mainWindow.lidarTrack
    property bool _trackRunning:    !!_track && _track.running
    property int  _elapsedSeconds:  _trackRunning ? _track.elapsedSeconds : (_ys ? _ys.recordingSeconds : 0)
    property string _startedTime:   _trackRunning ? _track.startedTime : (_acq ? _acq.startedTime : "")
    // YS-08 ④: General info bit 3 (Data logging), same bit as YSManager::kGenInfoDataLogging
    readonly property int _genInfoDataLoggingBit:   1 << 3
    readonly property int _rowUsb:                  3   // preChecks row order is fixed in YSManager::_rebuildPreChecks
    property bool _dataLogging:     _statusValid && _ys && (_ys.genInfo & _genInfoDataLoggingBit) !== 0

    QGCPalette { id: qgcPal }

    function _hhmmss(totalSeconds) {
        var h = Math.floor(totalSeconds / 3600)
        var m = Math.floor((totalSeconds % 3600) / 60)
        var s = totalSeconds % 60
        return (h < 10 ? "0" + h : h) + ":" + (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
    }

    function _acqStateText() {
        if (_noResponse) {
            return qsTr("UNKNOWN")
        }
        switch (_state) {
        case YSManager.StateRecording:  return qsTr("REC %1").arg(_hhmmss(_elapsedSeconds))
        case YSManager.StateStarting:   return qsTr("STARTING")
        case YSManager.StateStopping:   return qsTr("STOPPING")
        case YSManager.StateReady:
        case YSManager.StateNotReady:   return qsTr("IDLE")
        default:                        return "--"
        }
    }

    function _acqStateColor() {
        if (_noResponse) {
            return qgcPal.colorGrey
        }
        switch (_state) {
        case YSManager.StateRecording:  return qgcPal.colorRed
        case YSManager.StateStarting:
        case YSManager.StateStopping:   return qgcPal.colorOrange
        default:                        return qgcPal.text
        }
    }

    function _acqHintText() {
        if (_startRejected) {
            // Code 0 = Birdcom sent no Command status byte (see _reasonText in LiDARAcquisition.qml)
            var head = qsTr("✕ Start rejected by LiDAR")
            if (_acq.rejectReason !== "") {
                head += ": " + _acq.rejectReason + " (" + _acq.hexCode(_acq.rejectCode) + ")"
            } else if (_acq.rejectCode !== 0) {
                head += " (" + _acq.hexCode(_acq.rejectCode) + ")"
            }
            return head + _sep + _acq.rejectTime
        }
        if (_noResponse) {
            return qsTr("Check LiDAR power / UART cable") + _sep + qsTr("data stays on USB")
        }
        if (_criticalCount > 0) {
            var critical = _alerts.alerts.filter(function(a) { return a.critical }).map(function(a) { return a.text })
            return "‼ " + critical.join(_sep) + " → " + qsTr("Stop recommended")
        }
        if (_recording && _acq && _acq.loggingWarning) {
            return qsTr("! Data logging not reported by LiDAR")
        }
        // Y-04 ⑤: USB space low warning tells what the next level does
        if (_recording && _alerts && _alerts.usbLow) {
            return qsTr("USB full (≤ %1 GB) → critical message, plan to stop").arg(_alerts.usbFullGb)
        }
        if (_recording && _acq && _acq.flying) {
            return qsTr("In flight: Stop → slide to confirm (on ground: immediate)")
        }
        if (_recording && _startedTime !== "") {
            return qsTr("Started %1").arg(_startedTime) + _sep + qsTr("elapsed time counted by QGC")
        }
        return ""
    }

    function _acqHintColor() {
        if (_startRejected) {
            return qgcPal.colorRed
        }
        if (_noResponse) {
            return qgcPal.text
        }
        return _criticalCount > 0 || (_recording && _acq && _acq.loggingWarning) ? qgcPal.colorOrange : qgcPal.text
    }

    // Camera summary needs the LiDAR-side camera parameters: read them once per panel open,
    // as soon as the LiDAR answers (no retry loop if the LiDAR does not reply to Get Parameter)
    function _requestCameraParams() {
        if (!_cameraParamsRequested && _ys && _cameraInstalled && _statusValid && !_ys.cameraParamsKnown) {
            _cameraParamsRequested = true
            _ys.requestCameraParameters()
        }
    }

    Component.onCompleted:      _requestCameraParams()
    on_StatusValidChanged:      _requestCameraParams()

    // New vehicle: YSManager has cleared the old camera parameters, read them again
    Connections {
        target: QGroundControl.multiVehicleManager
        onActiveVehicleChanged: {
            _cameraParamsRequested = false
            _requestCameraParams()
        }
    }
    on_CameraInstalledChanged:  _requestCameraParams()

    function _chipText() {
        if (_noResponse) {
            return qsTr("NO RESPONSE")
        }
        if (_poweredOff) {
            return qsTr("POWERED OFF")
        }
        switch (_state) {
        case YSManager.StateReady:      return qsTr("READY")
        case YSManager.StateNotReady:   return qsTr("NOT READY")
        case YSManager.StateRecording:  return qsTr("● REC")
        case YSManager.StateStarting:   return qsTr("STARTING")
        case YSManager.StateStopping:   return qsTr("STOPPING")
        case YSManager.StateNoResponse: return qsTr("NO RESPONSE")
        case YSManager.StatePoweredOff: return qsTr("POWERED OFF")
        default:                        return qsTr("NO LINK")
        }
    }

    function _chipColor() {
        // Y-05 ③: NO RESPONSE chip is grey; 2 s without a reply turns the chip orange
        if (_noResponse || _poweredOff) {
            return qgcPal.colorGrey
        }
        if (_delayed) {
            return qgcPal.colorOrange
        }
        switch (_state) {
        case YSManager.StateReady:      return qgcPal.colorGreen
        case YSManager.StateNotReady:
        case YSManager.StateStarting:
        case YSManager.StateStopping:   return qgcPal.colorOrange
        case YSManager.StateRecording:
        case YSManager.StateNoResponse: return qgcPal.colorRed
        default:                        return qgcPal.colorGrey
        }
    }

    function _dotColor(preCheckState) {
        switch (preCheckState) {
        case YSManager.PreCheckOk:      return qgcPal.colorGreen
        case YSManager.PreCheckFail:    return qgcPal.colorOrange
        default:                        return qgcPal.colorGrey
        }
    }

    // Trigger value in s (Time) / m (Distance), init height in m
    function _cameraValueText() {
        if (!_cameraInstalled) {
            return qsTr("Not used")
        }
        if (!_ys || !_ys.cameraParamsKnown) {
            return "--"
        }
        if (_ys.embeddedCamera === 0) {
            return qsTr("Disabled")
        }
        var v = _ys.embCamTriggerValue.toFixed(1)
        return _ys.embCamTriggerMode === YSManager.TriggerModeDistance ? qsTr("Every %1 m").arg(v) : qsTr("Every %1 s").arg(v)
    }

    function _cameraDetailText() {
        if (!_cameraInstalled) {
            return qsTr("No camera set in LiDAR Setup")
        }
        if (!_ys || !_ys.cameraParamsKnown) {
            return qsTr("Camera settings not read from LiDAR yet")
        }
        if (_ys.embeddedCamera === 0) {
            return qsTr("Enable in LiDAR Setup › Settings")
        }
        var mode = _ys.embCamTriggerMode === YSManager.TriggerModeDistance ? qsTr("Distance trigger") : qsTr("Time trigger")
        var h = _ys.embCamInitHeight
        // Start height -1 = start immediately. Birdcom returns the LiDAR float as unsigned, so -1 reads back as 0;
        // 0 m above the acquisition start is the same thing, so <= 0 is shown as immediate.
        var start = h <= 0 ? qsTr("start immediately") : qsTr("start at %1 m").arg(h.toFixed(1))
        return mode + _sep + start + _sep + qsTr("edit in LiDAR Setup › Settings")
    }

    // Keep clicks off the map below
    DeadMouseArea {
        anchors.fill: parent
    }

    QGCFlickable {
        anchors.fill:       parent
        anchors.margins:    _margins
        contentHeight:      mainColumn.height
        flickableDirection: Flickable.VerticalFlick
        clip:               true

        ColumnLayout {
            id:         mainColumn
            width:      parent.width
            spacing:    _rowSpacing

            //-- ③ Header: title + state chip
            RowLayout {
                Layout.fillWidth: true

                QGCLabel {
                    text:               qsTr("LiDAR")
                    font.pointSize:     ScreenTools.mediumFontPointSize
                    font.family:        ScreenTools.demiboldFontFamily
                    Layout.fillWidth:   true
                }

                // Layout.preferred* so the RowLayout reserves the full chip (long states like NO RESPONSE)
                Rectangle {
                    Layout.preferredWidth:  chipLabel.contentWidth + ScreenTools.defaultFontPixelWidth * 2
                    Layout.preferredHeight: chipLabel.contentHeight + ScreenTools.defaultFontPixelHeight * 0.3
                    radius: height / 2
                    color:  _chipColor()

                    QGCLabel {
                        id:                 chipLabel
                        anchors.centerIn:   parent
                        text:               _chipText()
                        color:              "white"
                        font.family:        ScreenTools.demiboldFontFamily
                    }
                }
            }

            //-- ③ Subtitle: model · link
            QGCLabel {
                Layout.fillWidth:   true
                text:               _settings ? (_settings.ysModel.enumStringValue + _sep + _settings.ysLink.enumStringValue) : ""
                opacity:            0.6
                wrapMode:           Text.WordWrap
            }

            //-- ④ PRE-CHECK
            QGCLabel {
                Layout.fillWidth:   true
                text:               (_recording || _noResponse ? qsTr("STATUS") : qsTr("PRE-CHECK")) + _sep + qsTr("Get Status %1 Hz").arg(_ys ? 1000 / _ys.statusPollIntervalMs : 0)
                font.family:        ScreenTools.demiboldFontFamily
                opacity:            0.6
            }

            Repeater {
                model: _ys ? _ys.preChecks : []

                RowLayout {
                    Layout.fillWidth:   true
                    spacing:            ScreenTools.defaultFontPixelWidth

                    // YS-05: warning bits / no-response view on top of the YSManager row
                    property var  _view:   _alerts ? _alerts.rowView(index, modelData) : modelData
                    // Y-02: the row the Start reject code points to is shown as failed
                    property bool _failed: !_view.dimmed && (_view.state === YSManager.PreCheckFail || index === _rejectRow)

                    Rectangle {
                        width:      ScreenTools.defaultFontPixelHeight * 0.6
                        height:     width
                        radius:     width / 2
                        color:      parent._failed ? qgcPal.colorOrange : _dotColor(parent._view.state)
                    }

                    QGCLabel {
                        text:               modelData.name
                        Layout.fillWidth:   true
                        opacity:            parent._view.dimmed ? 0.6 : 1.0
                    }

                    // YS-08 ④: USB row also says whether data is being written (Data logging bit)
                    QGCLabel {
                        text:       index === _rowUsb && !parent._view.dimmed && _dataLogging ? parent._view.detail + _sep + qsTr("Logging") : parent._view.detail
                        color:      parent._failed ? qgcPal.colorOrange : qgcPal.text
                        opacity:    parent._failed ? 1.0 : 0.6
                    }
                }
            }

            Rectangle {
                Layout.fillWidth:   true
                height:             1
                color:              qgcPal.windowShade
            }

            //-- ⑤ Acquisition Start / Stop
            RowLayout {
                Layout.fillWidth: true

                QGCLabel {
                    text:               qsTr("Acquisition")
                    font.pointSize:     ScreenTools.mediumFontPointSize
                    opacity:            0.6
                    Layout.fillWidth:   true
                }

                QGCLabel {
                    text:           _acqStateText()
                    color:          _acqStateColor()
                    font.pointSize: ScreenTools.mediumFontPointSize
                    font.family:    ScreenTools.demiboldFontFamily
                }
            }

            RowLayout {
                Layout.fillWidth:   true
                spacing:            ScreenTools.defaultFontPixelWidth

                // Start only when every pre-check passes (READY); locked while waiting for the ACK
                QGCButton {
                    text:               qsTr("Start")
                    Layout.fillWidth:   true
                    enabled:            !!_acq && _state === YSManager.StateReady && !_startRejected && !_noResponse
                    primary:            enabled
                    onClicked:          _acq.start()
                }

                // Y-05 ⑤: with no reply the acquisition state is unknown, Stop (retry) sends Stop again directly
                QGCButton {
                    text:               _noResponse ? qsTr("Stop (retry)") : qsTr("Stop")
                    Layout.fillWidth:   true
                    enabled:            !!_acq && (_recording || _noResponse)
                    primary:            enabled
                    onClicked:          _noResponse ? _acq.stop() : _acq.requestStop()
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                text:               _acqHintText()
                color:              _acqHintColor()
                opacity:            _startRejected || (!_noResponse && (_criticalCount > 0 || (_acq && _acq.loggingWarning))) ? 1.0 : 0.6
                wrapMode:           Text.WordWrap
                visible:            text !== ""
            }

            Rectangle {
                Layout.fillWidth:   true
                height:             1
                color:              qgcPal.windowShade
            }

            //-- ⑥ Camera summary
            RowLayout {
                Layout.fillWidth: true

                QGCLabel {
                    text:               qsTr("Camera")
                    font.pointSize:     ScreenTools.mediumFontPointSize
                    opacity:            0.6
                    Layout.fillWidth:   true
                }

                QGCLabel {
                    text:           _cameraValueText()
                    font.pointSize: ScreenTools.mediumFontPointSize
                    font.family:    ScreenTools.demiboldFontFamily
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                text:               _cameraDetailText()
                wrapMode:           Text.WordWrap
                opacity:            0.6
            }

            Rectangle {
                Layout.fillWidth:   true
                height:             1
                color:              qgcPal.windowShade
            }

            //-- ⑦ Alarm row
            Rectangle {
                id:                     alarmRow
                Layout.fillWidth:       true
                Layout.preferredHeight: alarmLabel.contentHeight + ScreenTools.defaultFontPixelHeight * 0.6
                radius:                 ScreenTools.defaultFontPixelWidth / 2
                color:                  qgcPal.windowShade

                property bool _hasStatus:   _statusValid
                property int  _unmet:       _ys ? _ys.unmetPreCheckCount : 0
                property bool _intErr:      _ys ? _ys.internalError : false
                property int  _warnings:    _alerts ? _alerts.warningCount : 0
                property bool _showAlerts:  !_noResponse && _hasStatus && (_warnings + _criticalCount) > 0

                function alarmText() {
                    if (_noResponse) {
                        return qsTr("! No status from LiDAR (%1 s)").arg(_alerts.noResponseMs / 1000)
                    }
                    if (!_hasStatus) {
                        return qsTr("No status from LiDAR")
                    }
                    var parts = []
                    // Y-04 ⑦: warning / critical count
                    if (_showAlerts) {
                        if (_warnings > 0) {
                            parts.push(_warnings === 1 ? qsTr("! 1 warning") : qsTr("! %1 warnings").arg(_warnings))
                        }
                        if (_criticalCount > 0) {
                            parts.push(qsTr("%1 critical").arg(_criticalCount))
                        }
                        return parts.join(_sep)
                    }
                    if (_unmet > 0) {
                        parts.push(_unmet === 1 ? qsTr("! 1 pre-check not met") : qsTr("! %1 pre-checks not met").arg(_unmet))
                    }
                    if (_intErr) {
                        parts.push(qsTr("Internal error"))
                    }
                    return parts.length ? parts.join(_sep) : qsTr("✓ No active alarms")
                }

                function alarmColor() {
                    if (_noResponse || !_hasStatus) {
                        return qgcPal.colorGrey
                    }
                    if (_showAlerts) {
                        return qgcPal.colorOrange
                    }
                    if (_intErr) {
                        return qgcPal.colorRed
                    }
                    return _unmet > 0 ? qgcPal.colorOrange : qgcPal.colorGreen
                }

                QGCLabel {
                    id:                     alarmLabel
                    anchors.left:           parent.left
                    anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
                    anchors.right:          alarmTime.left
                    anchors.rightMargin:    ScreenTools.defaultFontPixelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   alarmRow.alarmText()
                    color:                  alarmRow.alarmColor()
                    font.family:            ScreenTools.demiboldFontFamily
                    wrapMode:               Text.WordWrap
                }

                QGCLabel {
                    id:                     alarmTime
                    anchors.right:          parent.right
                    anchors.rightMargin:    ScreenTools.defaultFontPixelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   _noResponse ? _alerts.noResponseSince :
                                            alarmRow._showAlerts ? _alerts.alertsSinceTime :
                                            _ys && alarmRow._hasStatus ? _ys.alarmSinceTime : ""
                    opacity:                0.6
                }
            }

            //-- ⑦ LiDAR Setup link
            QGCLabel {
                text:           qsTr("LiDAR Setup") + "  ›"
                color:          qgcPal.colorBlue
                font.family:    ScreenTools.demiboldFontFamily

                QGCMouseArea {
                    anchors.fill:   parent
                    onClicked: {
                        if (!mainWindow.preventViewSwitch()) {
                            mainWindow.showLidarSetupTool()
                        }
                    }
                }
            }
        }
    }
}
