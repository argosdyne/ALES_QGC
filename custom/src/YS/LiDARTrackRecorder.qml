/****************************************************************************
 *
 * YS-08 LiDAR elapsed time and recorded track (UI Y-03 ① / ⑨)
 * Always loaded by MainRootWindow (the LiDAR panel is unloaded when closed), so the time and the
 * track keep running with the panel closed.
 *   ① Elapsed time counted by QGC from the accepted Start ACK (the protocol has no timing data)
 *   ⑨ Vehicle positions while the acquisition runs, one segment per Start / Stop, drawn by FlyViewMap
 * Uses the existing YSManager API only: statusChanged + acquisitionRunning. acquisitionRunning is set
 * by an accepted Start / Stop ACK (statusChanged is emitted right then) and by Get Status after a reconnect.
 *
 ****************************************************************************/

import QtQuick          2.11
import QtPositioning    5.3

import QGroundControl               1.0
import CustomQuickInterface         1.0

Item {
    id: _root

    property var  _ys:              QGroundControl.corePlugin.ysManager
    property var  _activeVehicle:   QGroundControl.multiVehicleManager.activeVehicle

    readonly property bool running:     _running
    property bool   _running:           false

    // ① Elapsed time
    property double _startMs:           0
    property int    elapsedSeconds:     0
    property string startedTime:        ""      ///< HH:mm:ss of the Start ACK

    // ⑨ Track: finished segments + the segment being recorded
    property var    segments:           []      ///< [[QtPositioning.coordinate, ...], ...]
    property var    currentSegment:     []
    signal segmentStarted
    signal pointAdded(var coordinate)

    // Same distance filter as Vehicle.trajectoryPoints (TrajectoryPoints::_distanceTolerance), which only runs
    // while armed; the LiDAR can record on the ground, so positions are sampled here.
    readonly property real _minPointDistanceM:  2.0
    readonly property int  _elapsedTickMs:      250

    function _startSegment() {
        _running        = true
        _startMs        = Date.now()
        startedTime     = Qt.formatTime(new Date(_startMs), "HH:mm:ss")
        elapsedSeconds  = 0
        elapsedTimer.start()
        currentSegment  = []
        segmentStarted()
        _addPoint(true)
    }

    function _endSegment() {
        _addPoint(true)     // last position at the Stop ACK
        _running = false
        elapsedTimer.stop()
        elapsedSeconds = 0
        startedTime = ""
        if (currentSegment.length > 1) {
            var list = segments.slice(0)
            list.push(currentSegment)
            segments = list
        }
        currentSegment = []
        segmentStarted()    // clears the live segment line; the finished one is now in segments
    }

    function _addPoint(force) {
        if (!_running || !_activeVehicle || !_activeVehicle.coordinate.isValid) {
            return
        }
        var c = _activeVehicle.coordinate
        var point = QtPositioning.coordinate(c.latitude, c.longitude, c.altitude)
        var n = currentSegment.length
        if (n > 0 && currentSegment[n - 1].distanceTo(point) <= (force ? 0.01 : _minPointDistanceM)) {
            return
        }
        currentSegment.push(point)
        pointAdded(point)
    }

    function _reset() {
        _running        = false
        elapsedTimer.stop()
        elapsedSeconds  = 0
        startedTime     = ""
        segments        = []
        currentSegment  = []
        segmentStarted()
    }

    Connections {
        target: _ys
        onStatusChanged: {
            var r = _ys.acquisitionRunning
            if (r && !_running) {
                _startSegment()
            } else if (!r && _running) {
                _endSegment()
            }
        }
    }

    Connections {
        target:                 _running ? _activeVehicle : null
        onCoordinateChanged:    _addPoint(false)
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        onActiveVehicleChanged: _reset()
    }

    Timer {
        id:         elapsedTimer
        interval:   _elapsedTickMs
        repeat:     true
        onTriggered: elapsedSeconds = Math.floor((Date.now() - _startMs) / 1000)
    }
}
