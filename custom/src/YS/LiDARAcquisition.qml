/****************************************************************************
 *
 * YS-04 LiDAR acquisition Start / Stop (UI Y-02 / Y-03 / Y-03b)
 * Always loaded by MainRootWindow (the LiDAR panel is unloaded when closed), so the Start ACK,
 * the reject code and the 3 s Data logging check are seen even with the panel closed.
 * Uses the existing YSManager API only: startAcquisition / stopAcquisition, lidarState,
 * lastReceivedMessage (COMMAND_ACK text), acqRejectCode and genInfo.
 *
 ****************************************************************************/

import QtQuick          2.11

import QGroundControl               1.0
import CustomQuickInterface         1.0

Item {
    id: _root

    property var  _ys:              QGroundControl.corePlugin.ysManager
    property var  _activeVehicle:   QGroundControl.multiVehicleManager.activeVehicle

    readonly property bool recording:   _ys ? _ys.lidarState === YSManager.StateRecording : false
    readonly property bool flying:      _activeVehicle ? _activeVehicle.flying : false

    // Y-02: last Start rejected by the LiDAR. Start stays disabled until the LiDAR status changes.
    property bool   startRejected:      false
    property string rejectTime:         ""
    property int    rejectCode:         0       ///< YellowScan Command status byte, 0 = not sent by Birdcom
    property string rejectReason:       ""
    property int    rejectRowIndex:     -1      ///< YSManager.preChecks row the reject points to, -1 = none

    // Data logging not reported by Get Status within _dataLoggingTimeoutMs after the Start ACK
    property bool   loggingWarning:     false
    // Y-03 "Started HH:mm:ss": fixed when RECORDING begins, from YSManager's recording timer
    property string startedTime:        ""

    // MAV_CMD_USER_1 = YellowScan Acquisition ON / OFF (YSManager::startAcquisition / stopAcquisition)
    readonly property int _mavCmdAcquisition:       31010
    // Birdcom (MAVLink_Commands::Accquisition) answers only MAV_RESULT_ACCEPTED or MAV_RESULT_FAILED.
    // Command status 0x01 (acquisition already running) comes as ACCEPTED, so Get Status moves to RECORDING.
    readonly property int _ackAccepted:             0       // MAV_RESULT_ACCEPTED
    // Same bit as YSManager::kGenInfoDataLogging (General info byte, bit 3)
    readonly property int _genInfoDataLoggingBit:   1 << 3
    readonly property int _dataLoggingTimeoutMs:    3000
    // Text written by YSManager::_mavlinkReceived for a YellowScan COMMAND_ACK
    readonly property var _ackRegExp:               /^COMMAND_ACK cmd=(\d+) result=(\d+)/
    property string _rejectPreChecks:   ""      // preChecks when the reject arrived

    function start() {
        _clearReject()
        loggingWarning = false
        if (_ys) {
            _ys.startAcquisition()
        }
    }

    // Stop: in flight through the guided-action slider, on the ground immediately
    function requestStop() {
        var guided = globals.guidedControllerFlyView
        if (flying && guided) {
            guided.confirmAction(guided.actionLidarStop)
        } else {
            stop()
        }
    }

    function stop() {
        if (_ys) {
            _ys.stopAcquisition()
        }
    }

    // preChecks row order is fixed in YSManager::_rebuildPreChecks
    readonly property int _rowInsGnss:      0
    readonly property int _rowScanner:      1
    readonly property int _rowSystemTime:   2
    readonly property int _rowUsb:          3
    readonly property int _rowCamera:       4

    // Reject reason from YSManager.acqRejectCode (COMMAND_ACK.result_param2). Birdcom currently sends 0 there
    // (YSParser keeps only success / fail), so the generic "Start rejected" text is shown; the reason, code and
    // orange row appear only if Birdcom sends the Command status byte. Codes from Birdcom
    // YSParser::Check_Command_Acquisition_Status; 0x01 (acquisition running) is ACKed as ACCEPTED by Birdcom.
    function _reasonText(code) {
        switch (code) {
        case 0x02:  return qsTr("Scanner initializing")
        case 0x03:  return qsTr("System time not set")
        case 0x04:  return qsTr("Scanner not ready")
        case 0x05:  return qsTr("INS not locked")
        case 0x06:  return qsTr("Scanner error")
        case 0x07:  return qsTr("INS error")
        case 0x08:  return qsTr("USB full")
        case 0x0A:  return qsTr("Camera error")
        case 0x0B:  return qsTr("No USB")
        default:    return ""
        }
    }

    function _rowIndex(code) {
        switch (code) {
        case 0x02:
        case 0x04:
        case 0x06:  return _rowScanner
        case 0x03:  return _rowSystemTime
        case 0x05:
        case 0x07:  return _rowInsGnss
        case 0x08:
        case 0x0B:  return _rowUsb
        case 0x0A:  return _rowCamera
        default:    return -1
        }
    }

    function hexCode(code) {
        return "0x" + (code < 0x10 ? "0" : "") + code.toString(16).toUpperCase()
    }

    function _clearReject() {
        startRejected   = false
        rejectRowIndex  = -1
        _rejectPreChecks = ""
    }

    function _setRejected(code) {
        rejectCode      = code
        rejectReason    = _reasonText(code)
        rejectRowIndex  = _rowIndex(code)
        rejectTime      = Qt.formatTime(new Date(), "HH:mm:ss")
        _rejectPreChecks = JSON.stringify(_ys.preChecks)
        startRejected   = true
        var text = qsTr("LiDAR: Start rejected")
        if (rejectReason !== "") {
            text += ": " + rejectReason + " (" + hexCode(code) + ")"
        } else if (code !== 0) {
            text += " (" + hexCode(code) + ")"
        }
        mainWindow.showCriticalVehicleMessage(text)
    }

    // Remaining survey lines are an estimate. Needs the uploaded plan still open (not edited) in Plan view, because
    // the Fly View mission from the vehicle has no survey items. The current line is the one holding the
    // transect point nearest the vehicle, with the 2 / 4 points per line split used by YSTransectStyleMapVisuals.
    function remainingSurveyLines() {
        var planView = globals.planMasterControllerPlanView
        var flyView = globals.planMasterControllerFlyView
        if (!planView || !flyView || planView.dirty || !_activeVehicle) {
            return null
        }
        var planItems = planView.missionController.visualItems
        var flyItems = flyView.missionController.visualItems
        if (!planItems || !flyItems || planItems.count < 2 || flyItems.count < 2 ||
                planItems.get(planItems.count - 1).lastSequenceNumber !== flyItems.get(flyItems.count - 1).lastSequenceNumber) {
            return null
        }
        var current = flyView.missionController.currentMissionIndex
        var vehicleCoord = _activeVehicle.coordinate
        var total = 0
        var remaining = 0
        for (var i = 1; i < planItems.count; i++) {
            var item = planItems.get(i)
            var points = item.visualTransectPoints
            if (!points || points.length === 0) {
                continue
            }
            var stride = item.turnAroundDistance.rawValue !== 0 ? 4 : 2
            var lines = Math.floor(points.length / stride)
            total += lines
            if (current < item.sequenceNumber) {
                remaining += lines
            } else if (current <= item.lastSequenceNumber && vehicleCoord.isValid) {
                var nearest = 0
                var nearestDistance = Number.MAX_VALUE
                for (var p = 0; p < points.length; p++) {
                    var d = vehicleCoord.distanceTo(points[p])
                    if (d < nearestDistance) {
                        nearestDistance = d
                        nearest = p
                    }
                }
                remaining += Math.max(0, lines - Math.floor(nearest / stride))
            }
        }
        return total > 0 ? { "remaining": remaining, "total": total } : null
    }

    function stopConfirmMessage() {
        var lines = remainingSurveyLines()
        if (!lines) {
            return qsTr("Stop LiDAR acquisition in flight? Remaining survey lines unknown.")
        }
        return qsTr("Stop LiDAR acquisition in flight? %1 of %2 survey lines remaining.").arg(lines.remaining).arg(lines.total)
    }

    Connections {
        target: _ys
        onMessageChanged: {
            var m = _ackRegExp.exec(_ys.lastReceivedMessage)
            if (!m || Number(m[1]) !== _mavCmdAcquisition) {
                return
            }
            // YSManager emits messageChanged before it applies the ACK, so lidarState still says
            // which command this ACK answers. Only Start rejects are handled (Y-02).
            if (_ys.lidarState !== YSManager.StateStarting) {
                return
            }
            // A reject is handled in onAcqRejectCodeChanged: YSManager sets the code after this signal
            if (Number(m[2]) === _ackAccepted) {
                loggingWarning = false
                dataLoggingTimer.restart()
            }
        }
        onAcqRejectCodeChanged: {
            // Emitted for every rejected Start / Stop ACK, before lidarState leaves STARTING / STOPPING
            if (_ys.lidarState === YSManager.StateStarting) {
                _setRejected(_ys.acqRejectCode)
            }
        }
        onLidarStateChanged: {
            // New LiDAR status: the operator may try Start again
            if (startRejected && JSON.stringify(_ys.preChecks) !== _rejectPreChecks) {
                _clearReject()
            }
            // lidarState read directly: the `recording` binding may not have updated yet in this handler
            if (_ys.lidarState !== YSManager.StateRecording) {
                dataLoggingTimer.stop()
                loggingWarning = false
                startedTime = ""
            } else if (startedTime === "") {
                startedTime = Qt.formatTime(new Date(Date.now() - _ys.recordingSeconds * 1000), "HH:mm:ss")
            }
        }
        onStatusChanged: {
            if (loggingWarning && (_ys.genInfo & _genInfoDataLoggingBit)) {
                loggingWarning = false
            }
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        onActiveVehicleChanged: {
            _clearReject()
            dataLoggingTimer.stop()
            loggingWarning = false
        }
    }

    Timer {
        id:         dataLoggingTimer
        interval:   _dataLoggingTimeoutMs
        repeat:     false
        onTriggered: {
            if (_ys && recording && !(_ys.statusValid && (_ys.genInfo & _genInfoDataLoggingBit))) {
                loggingWarning = true
                mainWindow.showCriticalVehicleMessage(qsTr("LiDAR: Data logging not reported %1 s after Start").arg(_dataLoggingTimeoutMs / 1000))
            }
        }
    }
}
