/****************************************************************************
 *
 * YS-09 LiDAR mission auto Start / Stop (UI Y-06 ⑤, phase 3)
 * Always loaded by MainRootWindow, like LiDARAcquisition.qml.
 * LiDAR Setup > Connection > Mission start / stop = Auto:
 *   - Start when the vehicle reaches the first survey waypoint of the running mission
 *   - Stop when the vehicle reaches the last survey waypoint (on landing when that waypoint is the last mission item)
 *   - Before the auto Start the LiDAR pre-checks must be met (lidarState READY); otherwise the auto Start is
 *     skipped and a critical message names the unmet pre-checks
 *   - Auto Stop is sent directly; the in-flight slide-to-confirm applies to the manual Stop only. When the LiDAR is
 *     not in REC but its state is unknown or in transition, the stop stays pending (critical message) and is sent
 *     once the LiDAR reports REC; still pending on landing, a critical message asks for a manual Stop
 * Uses the existing YSManager API (lidarState, preChecks) and LiDARAcquisition start() / stop() only.
 *
 * Survey waypoints: the mission read back from the vehicle has only simple items, so the survey items
 * (items with transect points, same rule as LiDARAcquisition.remainingSurveyLines) come from the plan open in
 * Plan view, which must be the uploaded plan, not edited since. Otherwise (including a Plan view plan with no
 * survey items, e.g. the mission read back from the vehicle) the survey range is unknown, Auto does nothing and
 * a critical message says so when the mission starts.
 *
 ****************************************************************************/

import QtQuick          2.11

import QGroundControl               1.0
import CustomQuickInterface         1.0

Item {
    id: _root

    property var  _ys:              QGroundControl.corePlugin.ysManager
    property var  _settings:        QGroundControl.corePlugin.settings
    property var  _acq:             mainWindow.lidarAcquisition
    property var  _activeVehicle:   QGroundControl.multiVehicleManager.activeVehicle

    // Custom.SettingsGroup.json ysMissionStartStop enumValues
    readonly property int  _modeManualOnly: 0
    readonly property int  _modeAuto:       1

    readonly property bool autoEnabled:     !!_settings && _settings.ysEnable.rawValue && _settings.ysMissionStartStop.rawValue === _modeAuto
    readonly property bool _inMission:      !!_activeVehicle && _activeVehicle.flying && _activeVehicle.flightMode === _activeVehicle.missionFlightMode
    readonly property var  _flyMission:     globals.planMasterControllerFlyView ? globals.planMasterControllerFlyView.missionController : null

    // Per mission run: each action is taken (or skipped) once
    property bool _startHandled:        false
    property bool _stopHandled:         false
    property bool _rangeWarned:         false
    property bool _stopPending:         false   // Auto Stop due but the LiDAR was not in REC, retried on state change

    // { first, last }: sequence numbers of the first / last survey waypoint in the vehicle mission,
    // null when the survey waypoints are unknown. A Plan view plan without transect items is unknown too:
    // Plan view shows the mission read back from the vehicle (simple items only) after a vehicle connect
    function surveyWaypointRange() {
        var planView = globals.planMasterControllerPlanView
        var flyView = globals.planMasterControllerFlyView
        if (!planView || !flyView || planView.dirty) {
            return null
        }
        var planItems = planView.missionController.visualItems
        var flyItems = flyView.missionController.visualItems
        if (!planItems || !flyItems || planItems.count < 2 || flyItems.count < 2 ||
                planItems.get(planItems.count - 1).lastSequenceNumber !== flyItems.get(flyItems.count - 1).lastSequenceNumber) {
            return null
        }
        var firstSeq = -1
        var lastSeq = -1
        for (var i = 1; i < planItems.count; i++) {
            var item = planItems.get(i)
            if (!item.visualTransectPoints || item.visualTransectPoints.length === 0) {
                continue
            }
            if (firstSeq < 0) {
                firstSeq = item.sequenceNumber
            }
            lastSeq = item.lastSequenceNumber
        }
        if (firstSeq < 0) {
            return null
        }
        // A survey item can begin / end with commands (speed, yaw): use its first / last waypoint
        var first = -1
        var last = -1
        for (var j = 1; j < flyItems.count; j++) {
            var fly = flyItems.get(j)
            if (fly.sequenceNumber < firstSeq || fly.sequenceNumber > lastSeq || !fly.specifiesCoordinate) {
                continue
            }
            if (first < 0) {
                first = fly.sequenceNumber
            }
            last = fly.sequenceNumber
        }
        return first < 0 ? null : { "first": first, "last": last }
    }

    function _unmetPreChecks() {
        var names = []
        var rows = _ys.preChecks
        for (var i = 0; i < rows.length; i++) {
            if (rows[i].state === YSManager.PreCheckFail || rows[i].state === YSManager.PreCheckUnknown) {
                names.push(rows[i].name)
            }
        }
        return names
    }

    function _preCheckFailText() {
        switch (_ys.lidarState) {
        case YSManager.StateNoLink:         return qsTr("no link")
        case YSManager.StateNoResponse:     return qsTr("no response")
        case YSManager.StatePoweredOff:     return qsTr("powered off")
        case YSManager.StateNotReady:
            var names = _unmetPreChecks()
            return names.length > 0 ? qsTr("pre-check not met: %1").arg(names.join(", ")) : qsTr("not ready")
        default:                            return qsTr("not ready")
        }
    }

    function _autoStart() {
        _startHandled = true
        // Already recording, or a manual Start / Stop is waiting for its ACK
        if (!_ys || !_acq || _acq.recording || _ys.lidarState === YSManager.StateStarting || _ys.lidarState === YSManager.StateStopping) {
            return
        }
        if (_ys.lidarState !== YSManager.StateReady) {
            mainWindow.showLiDARCriticalMessage(qsTr("LiDAR: Auto Start skipped at first survey waypoint, %1").arg(_preCheckFailText()))
            return
        }
        // READY after an earlier reject: Start is sent again, a new reject is reported by LiDARAcquisition
        _acq.start()
    }

    function _stopWaitText() {
        switch (_ys.lidarState) {
        case YSManager.StateStarting:       return qsTr("Start waiting for ACK")
        case YSManager.StateStopping:       return qsTr("Stop waiting for ACK")
        default:                            return _preCheckFailText()
        }
    }

    // Stop is sent only from REC. While the state is unknown (no link / no response) or in transition
    // (Start / Stop waiting for ACK) the stop stays pending and is retried on each LiDAR state change.
    function _autoStop() {
        if (!_ys || !_acq) {
            return
        }
        if (_acq.recording) {
            _stopHandled = true
            _stopPending = false
            _acq.stop()
            return
        }
        switch (_ys.lidarState) {
        case YSManager.StateNoLink:
        case YSManager.StateNoResponse:
        case YSManager.StateStarting:
        case YSManager.StateStopping:
            if (!_stopPending) {
                _stopPending = true
                mainWindow.showLiDARCriticalMessage(qsTr("LiDAR: Auto Stop pending at last survey waypoint, %1").arg(_stopWaitText()))
            }
            return
        default:
            // READY / NOT READY / POWERED OFF: not recording, nothing to stop
            _stopHandled = true
            _stopPending = false
        }
    }

    function _reset() {
        _startHandled   = false
        _stopHandled    = false
        _stopPending    = false
        _rangeWarned    = false
    }

    function _update() {
        if (!autoEnabled || !_inMission || !_flyMission) {
            return
        }
        var range = surveyWaypointRange()
        if (!range) {
            if (!_rangeWarned) {
                _rangeWarned = true
                mainWindow.showLiDARCriticalMessage(qsTr("LiDAR: Auto Start / Stop off for this mission, survey waypoints unknown (open the uploaded plan in Plan view)"))
            }
            return
        }
        // currentMissionIndex is the waypoint being flown to: above a waypoint's sequence number = reached
        var current = _flyMission.currentMissionIndex
        if (current <= range.first) {
            // Before the survey (or mission restarted): arm both actions again
            _startHandled = false
            _stopHandled = false
            _stopPending = false
        } else if (current <= range.last) {
            if (!_startHandled) {
                _autoStart()
            }
        } else if (!_stopHandled) {
            _startHandled = true
            _autoStop()
        }
    }

    Connections {
        target:                     _flyMission
        onCurrentMissionIndexChanged: _update()
    }

    on_InMissionChanged:    _update()
    onAutoEnabledChanged:   _update()

    Connections {
        target: _ys
        onLidarStateChanged: {
            if (_stopPending && autoEnabled) {
                _autoStop()
            }
        }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        onActiveVehicleChanged: _reset()
    }

    Connections {
        target: _activeVehicle
        onFlyingChanged: {
            if (_activeVehicle.flying) {
                return
            }
            // Last survey waypoint = last mission item: the mission index never moves past it, so the
            // acquisition left running from the survey is stopped on landing
            if (autoEnabled && _startHandled && !_stopHandled) {
                _autoStop()
                // Still not sent: the pending stop ends with this mission run, the operator stops manually
                if (_stopPending) {
                    mainWindow.showLiDARCriticalMessage(qsTr("LiDAR: Auto Stop not sent after landing, %1. Stop acquisition manually").arg(_stopWaitText()))
                }
            }
            _reset()
        }
    }
}
