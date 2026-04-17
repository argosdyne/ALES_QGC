/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "TrajectoryPoints.h"
#include "Vehicle.h"

TrajectoryPoints::TrajectoryPoints(Vehicle* vehicle, QObject* parent)
    : QObject       (parent)
    , _vehicle      (vehicle)
    , _lastAzimuth  (qQNaN())
{
}

void TrajectoryPoints::_vehicleCoordinateChanged(QGeoCoordinate coordinate)
{
    // The goal of this algorithm is to limit the number of trajectory points whic represent the vehicle path.
    // Fewer points means higher performance of map display.
    if (!coordinate.isValid()) {
        return;
    }

    if (_lastPoint.isValid()) {
        double distance = _lastPoint.distanceTo(coordinate);
        if (distance > _distanceTolerance) {
            const double elapsedSeconds = _lastPointUpdateTimer.isValid() ? qMax(0.001, _lastPointUpdateTimer.elapsed() / 1000.0) : 0.0;
            const double impliedSpeed = elapsedSeconds > 0.0 ? (distance / elapsedSeconds) : 0.0;
            double currentGroundSpeed = _vehicle->groundSpeed()->rawValue().toDouble();
            if (!qIsFinite(currentGroundSpeed) || currentGroundSpeed < 0.0) {
                currentGroundSpeed = 0.0;
            }
            const double allowedJumpSpeed = qMax(_minAllowedJumpSpeedMetersPerSecond,
                                                 (currentGroundSpeed * _groundSpeedJumpFactor) + _groundSpeedJumpOffsetMetersPerSecond);
            const bool overDistanceLimit = distance > _maxJumpDistanceMeters;
            const bool overSpeedLimit = distance > _minJumpDistanceForSpeedCheckMeters &&
                                        elapsedSeconds > 0.0 &&
                                        impliedSpeed > allowedJumpSpeed;
            if (overDistanceLimit || overSpeedLimit) {
                qWarning() << "[TrajectoryPoints]"
                           << "ignore abnormal coordinate jump"
                           << "distance" << distance
                           << "elapsedSec" << elapsedSeconds
                           << "impliedSpeed" << impliedSpeed
                           << "groundSpeed" << currentGroundSpeed
                           << "allowedJumpSpeed" << allowedJumpSpeed
                           << "from" << _lastPoint
                           << "to" << coordinate;
                _lastPoint = coordinate;
                _lastAzimuth = qQNaN();
                if (_points.isEmpty()) {
                    _points.append(QVariant::fromValue(coordinate));
                    emit pointAdded(coordinate);
                } else {
                    _points[_points.count() - 1] = QVariant::fromValue(coordinate);
                    emit updateLastPoint(coordinate);
                }
                _lastPointUpdateTimer.restart();
                return;
            }

            //-- Update flight distance
            _vehicle->updateFlightDistance(distance);
            // Vehicle has moved far enough from previous point for an update
            double newAzimuth = _lastPoint.azimuthTo(coordinate);
            if (qIsNaN(_lastAzimuth) || qAbs(newAzimuth - _lastAzimuth) > _azimuthTolerance) {
                // The new position IS NOT colinear with the last segment. Append the new position to the list.
                _lastAzimuth = _lastPoint.azimuthTo(coordinate);
                _lastPoint = coordinate;
                _points.append(QVariant::fromValue(coordinate));
                emit pointAdded(coordinate);
            } else {
                // The new position IS colinear with the last segment. Don't add a new point, just update
                // the last point to be the new position.
                _lastPoint = coordinate;
                _points[_points.count() - 1] = QVariant::fromValue(coordinate);
                emit updateLastPoint(coordinate);
            }
        }
    } else {
        // Add the very first trajectory point to the list
        _lastPoint = coordinate;
        _points.append(QVariant::fromValue(coordinate));
        emit pointAdded(coordinate);
    }

    _lastPointUpdateTimer.restart();
}

void TrajectoryPoints::start(void)
{
    clear();
    connect(_vehicle, &Vehicle::coordinateChanged, this, &TrajectoryPoints::_vehicleCoordinateChanged);
}

void TrajectoryPoints::stop(void)
{
    disconnect(_vehicle, &Vehicle::coordinateChanged, this, &TrajectoryPoints::_vehicleCoordinateChanged);
}

void TrajectoryPoints::clear(void)
{
    _points.clear();
    _lastPoint = QGeoCoordinate();
    _lastAzimuth = qQNaN();
    _lastPointUpdateTimer.invalidate();
    emit pointsCleared();
}
