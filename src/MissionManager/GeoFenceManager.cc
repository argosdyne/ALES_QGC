/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "GeoFenceManager.h"
#include "Vehicle.h"
#include "QmlObjectListModel.h"
#include "ParameterManager.h"
#include "QGCApplication.h"
#include "QGCMapPolygon.h"
#include "QGCMapCircle.h"

#include <QtGlobal>

QGC_LOGGING_CATEGORY(GeoFenceManagerLog, "GeoFenceManagerLog")

// ArduPilot 4.5 3D fence additions. Keep these values aligned with the
// matching ardupilotmega.xml used by the vehicle firmware.
static constexpr MAV_CMD kFencePolygonInclusion3D = static_cast<MAV_CMD>(42800);
static constexpr MAV_CMD kFencePolygonExclusion3D = static_cast<MAV_CMD>(42801);
static constexpr MAV_CMD kFenceCircleInclusion3D = static_cast<MAV_CMD>(42802);
static constexpr MAV_CMD kFenceCircleExclusion3D = static_cast<MAV_CMD>(42803);

static bool _is3DPolygonFenceCommand(MAV_CMD command)
{
    return command == kFencePolygonInclusion3D ||
           command == kFencePolygonExclusion3D;
}

static bool _is2DPolygonFenceCommand(MAV_CMD command)
{
    return command == MAV_CMD_NAV_FENCE_POLYGON_VERTEX_INCLUSION ||
           command == MAV_CMD_NAV_FENCE_POLYGON_VERTEX_EXCLUSION;
}

static bool _isPolygonFenceCommand(MAV_CMD command)
{
    return _is2DPolygonFenceCommand(command) || _is3DPolygonFenceCommand(command);
}

static bool _isInclusionPolygonFenceCommand(MAV_CMD command)
{
    return command == MAV_CMD_NAV_FENCE_POLYGON_VERTEX_INCLUSION ||
           command == kFencePolygonInclusion3D;
}

static bool _is3DCircleFenceCommand(MAV_CMD command)
{
    return command == kFenceCircleInclusion3D ||
           command == kFenceCircleExclusion3D;
}

static bool _is2DCircleFenceCommand(MAV_CMD command)
{
    return command == MAV_CMD_NAV_FENCE_CIRCLE_INCLUSION ||
           command == MAV_CMD_NAV_FENCE_CIRCLE_EXCLUSION;
}

static bool _isCircleFenceCommand(MAV_CMD command)
{
    return _is2DCircleFenceCommand(command) || _is3DCircleFenceCommand(command);
}

static bool _isInclusionCircleFenceCommand(MAV_CMD command)
{
    return command == MAV_CMD_NAV_FENCE_CIRCLE_INCLUSION ||
           command == kFenceCircleInclusion3D;
}

static bool _normalizeAltitudeFrame(MAV_FRAME frame, int& normalizedFrame)
{
    switch (frame) {
    case MAV_FRAME_GLOBAL:
    case MAV_FRAME_GLOBAL_INT:
        normalizedFrame = MAV_FRAME_GLOBAL;
        return true;
    case MAV_FRAME_GLOBAL_RELATIVE_ALT:
    case MAV_FRAME_GLOBAL_RELATIVE_ALT_INT:
        normalizedFrame = MAV_FRAME_GLOBAL_RELATIVE_ALT;
        return true;
    case MAV_FRAME_GLOBAL_TERRAIN_ALT:
    case MAV_FRAME_GLOBAL_TERRAIN_ALT_INT:
        normalizedFrame = MAV_FRAME_GLOBAL_TERRAIN_ALT;
        return true;
    default:
        return false;
    }
}

static MAV_FRAME _missionItemIntFrame(int normalizedFrame)
{
    switch (normalizedFrame) {
    case MAV_FRAME_GLOBAL:
        return MAV_FRAME_GLOBAL_INT;
    case MAV_FRAME_GLOBAL_TERRAIN_ALT:
        return MAV_FRAME_GLOBAL_TERRAIN_ALT_INT;
    case MAV_FRAME_GLOBAL_RELATIVE_ALT:
    default:
        return MAV_FRAME_GLOBAL_RELATIVE_ALT_INT;
    }
}

GeoFenceManager::GeoFenceManager(Vehicle* vehicle)
    : PlanManager       (vehicle, MAV_MISSION_TYPE_FENCE)
{
    connect(this, &PlanManager::inProgressChanged,          this, &GeoFenceManager::inProgressChanged);
    connect(this, &PlanManager::error,                      this, &GeoFenceManager::error);
    connect(this, &PlanManager::removeAllComplete,          this, &GeoFenceManager::removeAllComplete);
    connect(this, &PlanManager::sendComplete,               this, &GeoFenceManager::_sendComplete);
    connect(this, &PlanManager::newMissionItemsAvailable,   this, &GeoFenceManager::_planManagerLoadComplete);
}

GeoFenceManager::~GeoFenceManager()
{

}

void GeoFenceManager::sendToVehicle(const QGeoCoordinate&   breachReturn,
                                    QmlObjectListModel&     polygons,
                                    QmlObjectListModel&     circles)
{
    QList<MissionItem*> fenceItems;



    qInfo() << "Send GeoFence info";

    qInfo() << _vehicle->firmwareType();

    _sendPolygons.clear();
    _sendCircles.clear();

    for (int i=0; i<polygons.count(); i++) {
        _sendPolygons.append(*polygons.value<QGCFencePolygon*>(i));
    }
    for (int i=0; i<circles.count(); i++) {
        _sendCircles.append(*circles.value<QGCFenceCircle*>(i));
    }
    _breachReturnPoint = breachReturn;

    const auto rejectSend = [this](const QString& message) {
        qgcApp()->showAppMessage(message);
        _sendPolygons.clear();
        _sendCircles.clear();
        emit sendComplete(true);
    };

    bool has3DFence = false;
    for (int i = 0; i < _sendPolygons.count(); i++) {
        const QGCFencePolygon& polygon = _sendPolygons[i];
        if (polygon.altitudeBandEnabled()) {
            has3DFence = true;
            if (polygon.altitudeMax() <= polygon.altitudeMin()) {
                rejectSend(tr("3D polygon fence altitude max must be greater than altitude min."));
                return;
            }
        }
    }
    for (int i = 0; i < _sendCircles.count(); i++) {
        const QGCFenceCircle& circle = _sendCircles[i];
        if (circle.altitudeBandEnabled()) {
            has3DFence = true;
            if (circle.altitudeMax() <= circle.altitudeMin()) {
                rejectSend(tr("3D circular fence altitude max must be greater than altitude min."));
                return;
            }
        }
    }
    if (has3DFence && _vehicle->firmwareType() != MAV_AUTOPILOT_ARDUPILOTMEGA) {
        rejectSend(tr("3D geofence upload is only supported for ArduPilot vehicles."));
        return;
    }

    for (int i=0; i<_sendPolygons.count(); i++) {
        const QGCFencePolygon& polygon = _sendPolygons[i];
        const bool useAltitudeBand = polygon.altitudeBandEnabled();
        const MAV_CMD command = useAltitudeBand ?
                                    (polygon.inclusion() ? kFencePolygonInclusion3D : kFencePolygonExclusion3D) :
                                    (polygon.inclusion() ? MAV_CMD_NAV_FENCE_POLYGON_VERTEX_INCLUSION : MAV_CMD_NAV_FENCE_POLYGON_VERTEX_EXCLUSION);
        const double altitudeMin = useAltitudeBand ? polygon.altitudeMin() : 0.0;
        const double altitudeMax = useAltitudeBand ? polygon.altitudeMax() : 0.0;
        const double inclusionGroup = polygon.inclusion() ? polygon.inclusionGroup() : 0.0;
        const MAV_FRAME frame = useAltitudeBand ? _missionItemIntFrame(polygon.altitudeFrame()) : MAV_FRAME_GLOBAL;

        for (int j=0; j<polygon.count(); j++) {
            const QGeoCoordinate& vertex = polygon.path()[j].value<QGeoCoordinate>();

            MissionItem* item = new MissionItem(0,
                                                command,
                                                frame,
                                                polygon.count(),    // vertex count
                                                inclusionGroup,
                                                altitudeMin,
                                                altitudeMax,
                                                vertex.latitude(),
                                                vertex.longitude(),
                                                0,
                                                false,              // autocontinue
                                                false,              // isCurrentItem
                                                this);              // parent
            fenceItems.append(item);
        }
    }

    for (int i=0; i<_sendCircles.count(); i++) {
        QGCFenceCircle& circle = _sendCircles[i];
        const bool useAltitudeBand = circle.altitudeBandEnabled();
        const MAV_CMD command = useAltitudeBand ?
                                    (circle.inclusion() ? kFenceCircleInclusion3D : kFenceCircleExclusion3D) :
                                    (circle.inclusion() ? MAV_CMD_NAV_FENCE_CIRCLE_INCLUSION : MAV_CMD_NAV_FENCE_CIRCLE_EXCLUSION);
        const double inclusionGroup = circle.inclusion() ? circle.inclusionGroup() : 0.0;
        const MAV_FRAME frame = useAltitudeBand ? _missionItemIntFrame(circle.altitudeFrame()) : MAV_FRAME_GLOBAL;

        MissionItem* item = new MissionItem(0,
                                            command,
                                            frame,
                                            circle.radius()->rawValue().toDouble(),
                                            inclusionGroup,
                                            useAltitudeBand ? circle.altitudeMin() : 0.0,
                                            useAltitudeBand ? circle.altitudeMax() : 0.0,
                                            circle.center().latitude(),
                                            circle.center().longitude(),
                                            0,
                                            false,                      // autocontinue
                                            false,                      // isCurrentItem
                                            this);                      // parent
        fenceItems.append(item);
    }

    if (_breachReturnPoint.isValid()) {
        MissionItem* item = new MissionItem(0,
                                            MAV_CMD_NAV_FENCE_RETURN_POINT,
                                            MAV_FRAME_GLOBAL_RELATIVE_ALT,
                                            0, 0, 0, 0,                    // param 1-4 unused
                                            breachReturn.latitude(),
                                            breachReturn.longitude(),
                                            breachReturn.altitude(),
                                            false,                      // autocontinue
                                            false,                      // isCurrentItem
                                            this);                      // parent
        fenceItems.append(item);
    }

    // Plan manager takes control of MissionItems, so no need to delete
    writeMissionItems(fenceItems);


    MultiVehicleManager* manager = qgcApp()->toolbox()->multiVehicleManager();
    if(manager){
        if(manager->activeVehicle()->firmwareType() != MAV_AUTOPILOT_ARDUPILOTMEGA) {
            qInfo() << "This is PX4";

            ParameterManager* pm = _vehicle->parameterManager();

            //Check Geofence parameters are exist

            if(pm->parameterExists(-1, "GF_MIN_VER_DIST")){
                pm->getParameter(-1, "GF_MIN_VER_DIST")->setRawValue(0);
            }

            if(pm->parameterExists(-1, "GF_ST_CLK_TIM")) {
                pm->getParameter(-1, "GF_ST_CLK_TIM")->setRawValue(0);
            }

            if(pm->parameterExists(-1, "GF_SUSTAIN_HOR_T")){
                pm->getParameter(-1, "GF_SUSTAIN_HOR_T")->setRawValue(23);
            }

            if(pm->parameterExists(-1, "GF_OFF_ZONE_TIM")){
                pm->getParameter(-1, "GF_OFF_ZONE_TIM")->setRawValue(9);
            }
        }
    }

}

void GeoFenceManager::removeAll(void)
{
    _polygons.clear();
    _circles.clear();
    _breachReturnPoint = QGeoCoordinate();

    PlanManager::removeAll();
}

void GeoFenceManager::_sendComplete(bool error)
{
    if (error) {
        _polygons.clear();
        _circles.clear();
        _breachReturnPoint = QGeoCoordinate();
    } else {
        _polygons = _sendPolygons;
        _circles = _sendCircles;
    }
    _sendPolygons.clear();
    _sendCircles.clear();
    emit sendComplete(error);
}

void GeoFenceManager::_planManagerLoadComplete(bool removeAllRequested)
{
    qInfo() << "_planManagerLoadComplete";
    bool loadFailed = false;

    Q_UNUSED(removeAllRequested);

    _polygons.clear();
    _circles.clear();

    MAV_CMD expectedCommand = (MAV_CMD)0;
    int expectedVertexCount = 0;
    double expectedAltitudeMin = 0.0;
    double expectedAltitudeMax = 0.0;
    int expectedAltitudeFrame = MAV_FRAME_GLOBAL_RELATIVE_ALT;
    int expectedInclusionGroup = 0;
    QGCFencePolygon nextPolygon(true /* inclusion */);
    const QList<MissionItem*>& fenceItems = missionItems();

    for (int i=0; i<fenceItems.count(); i++) {
        MissionItem* item = fenceItems[i];

        MAV_CMD command = item->command();

        if (_isPolygonFenceCommand(command)) {
            int itemAltitudeFrame = MAV_FRAME_GLOBAL_RELATIVE_ALT;
            if (_is3DPolygonFenceCommand(command) &&
                    !_normalizeAltitudeFrame(item->frame(), itemAltitudeFrame)) {
                emit error(BadPolygonItemFormat, tr("GeoFence load: Unsupported 3D polygon altitude frame %1").arg(item->frame()));
                loadFailed = true;
                break;
            }

            if (nextPolygon.count() == 0) {
                // Starting a new polygon
                expectedVertexCount = item->param1();
                expectedCommand = command;
                expectedAltitudeMin = _is3DPolygonFenceCommand(command) ? item->param3() : 0.0;
                expectedAltitudeMax = _is3DPolygonFenceCommand(command) ? item->param4() : 0.0;
                expectedAltitudeFrame = itemAltitudeFrame;
                expectedInclusionGroup = _isInclusionPolygonFenceCommand(command) ? qMax(0, qRound(item->param2())) : 0;
            } else if (expectedVertexCount != item->param1()){
                // In the middle of a polygon, but count suddenly changed
                emit error(BadPolygonItemFormat, tr("GeoFence load: Vertex count change mid-polygon - actual:expected").arg(item->param1()).arg(expectedVertexCount));
                loadFailed = true;
                break;
            } else if (expectedCommand != command) {
                // Command changed before last polygon was completely loaded
                emit error(BadPolygonItemFormat, tr("GeoFence load: Polygon type changed before last load complete - actual:expected").arg(command).arg(expectedCommand));
                loadFailed = true;
                break;
            } else if (_is3DPolygonFenceCommand(command) &&
                       (qAbs(expectedAltitudeMin - item->param3()) > 0.000001 ||
                        qAbs(expectedAltitudeMax - item->param4()) > 0.000001 ||
                        expectedAltitudeFrame != itemAltitudeFrame ||
                        expectedInclusionGroup != (_isInclusionPolygonFenceCommand(command) ? qMax(0, qRound(item->param2())) : 0))) {
                emit error(BadPolygonItemFormat, tr("GeoFence load: 3D parameters changed mid-polygon"));
                loadFailed = true;
                break;
            }
            if (_is3DPolygonFenceCommand(command) && expectedAltitudeMax <= expectedAltitudeMin) {
                emit error(BadPolygonItemFormat, tr("GeoFence load: Invalid 3D polygon altitude band"));
                loadFailed = true;
                break;
            }
            nextPolygon.appendVertex(QGeoCoordinate(item->param5(), item->param6()));
            if (nextPolygon.count() == expectedVertexCount) {
                // Polygon is complete
                nextPolygon.setInclusion(_isInclusionPolygonFenceCommand(command));
                nextPolygon.setAltitudeBandEnabled(_is3DPolygonFenceCommand(command));
                nextPolygon.setAltitudeMin(expectedAltitudeMin);
                nextPolygon.setAltitudeMax(expectedAltitudeMax);
                nextPolygon.setAltitudeFrame(expectedAltitudeFrame);
                nextPolygon.setInclusionGroup(expectedInclusionGroup);
                _polygons.append(nextPolygon);
                nextPolygon.clear();
            }
        } else if (_isCircleFenceCommand(command)) {
            if (nextPolygon.count() != 0) {
                // Incomplete polygon
                emit error(IncompletePolygonLoad, tr("GeoFence load: Incomplete polygon loaded"));
                loadFailed = true;
                break;
            }

            int altitudeFrame = MAV_FRAME_GLOBAL_RELATIVE_ALT;
            if (_is3DCircleFenceCommand(command) &&
                    !_normalizeAltitudeFrame(item->frame(), altitudeFrame)) {
                emit error(UnsupportedCommand, tr("GeoFence load: Unsupported 3D circle altitude frame %1").arg(item->frame()));
                loadFailed = true;
                break;
            }
            if (_is3DCircleFenceCommand(command) && item->param4() <= item->param3()) {
                emit error(InvalidCircleRadius, tr("GeoFence load: Invalid 3D circle altitude band"));
                loadFailed = true;
                break;
            }

            const bool inclusion = _isInclusionCircleFenceCommand(command);
            QGCFenceCircle circle(QGeoCoordinate(item->param5(), item->param6()), item->param1(), inclusion);
            circle.setAltitudeBandEnabled(_is3DCircleFenceCommand(command));
            circle.setAltitudeMin(_is3DCircleFenceCommand(command) ? item->param3() : 0.0);
            circle.setAltitudeMax(_is3DCircleFenceCommand(command) ? item->param4() : 0.0);
            circle.setAltitudeFrame(altitudeFrame);
            circle.setInclusionGroup(inclusion ? qMax(0, qRound(item->param2())) : 0);
            _circles.append(circle);
        } else if (command == MAV_CMD_NAV_FENCE_RETURN_POINT) {
            _breachReturnPoint = QGeoCoordinate(item->param5(), item->param6(), item->param7());
        } else {
            emit error(UnsupportedCommand, tr("GeoFence load: Unsupported command %1").arg(item->command()));
            loadFailed = true;
            break;
        }
    }

    if (!loadFailed && nextPolygon.count() != 0) {
        emit error(IncompletePolygonLoad, tr("GeoFence load: Incomplete polygon loaded"));
        loadFailed = true;
    }

    if (loadFailed) {
        _polygons.clear();
        _circles.clear();
        _breachReturnPoint = QGeoCoordinate();
    }

    emit loadComplete();
}

bool GeoFenceManager::supported(void) const
{
    return (_vehicle->capabilityBits() & MAV_PROTOCOL_CAPABILITY_MISSION_FENCE) && (_vehicle->maxProtoVersion() >= 200);
}
