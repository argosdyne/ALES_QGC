/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "YellowScanInitPathComplexItem.h"
#include "JsonHelper.h"
#include "MissionController.h"
#include "QGCGeo.h"
#include "QGCQGeoCoordinate.h"
#include "SettingsManager.h"
#include "AppSettings.h"
#include "QGCQGeoCoordinate.h"
#include "PlanMasterController.h"
#include "QGCApplication.h"

#include <QPolygonF>

#include <iostream>
#include <cmath>
#include <vector>
#include <utility>

using namespace std;

QGC_LOGGING_CATEGORY(YellowScanInitPathLog, "YellowScanInitPathLog")

// Earth radius in meters
const double R = 6371000.0;
const double PI = 3.14159265358979323846;

const QString YellowScanInitPathComplexItem::name(YellowScanInitPathComplexItem::tr("Init Path"));

const char* YellowScanInitPathComplexItem::settingsGroup =            "CorridorScan";
const char* YellowScanInitPathComplexItem::corridorWidthName =        "CorridorWidth";
const char* YellowScanInitPathComplexItem::_jsonEntryPointKey =       "EntryPoint";

const char* YellowScanInitPathComplexItem::jsonComplexItemTypeValue = "CorridorScan";

const char* YellowScanInitPathComplexItem::angleName = "YSAngle";
const char* YellowScanInitPathComplexItem::turnRadiusName = "YSTurnRadius";

YellowScanInitPathComplexItem::YellowScanInitPathComplexItem(PlanMasterController* masterController, bool flyView, const QString& kmlFile)
    : TransectStyleComplexItem  (masterController, flyView, settingsGroup)
    , _entryPoint               (0)
    , _metaDataMap              (FactMetaData::createMapFromJsonFile(QStringLiteral(":/json/YellowScanInitPath.SettingsGroup.json"), this))
    , _corridorWidthFact        (settingsGroup, _metaDataMap[corridorWidthName])
    , _angleFact                (settingsGroup, _metaDataMap[angleName])
    , _turnRadiusFact           (settingsGroup, _metaDataMap[turnRadiusName])
    , _speedSection             (masterController)
{
    _editorQml = "qrc:/qml/YellowScanInitPathEditor.qml";

    _speedSection.setAvailable(true);

    // We override the altitude to the mission default
    if (_cameraCalc.isManualCamera() || !_cameraCalc.valueSetIsDistance()->rawValue().toBool()) {
        _cameraCalc.distanceToSurface()->setRawValue(qgcApp()->toolbox()->settingsManager()->appSettings()->defaultMissionItemAltitude()->rawValue());
    }    

    connect(&_angleFact,            &Fact::valueChanged,                            this, &YellowScanInitPathComplexItem::_setDirty);
    connect(&_turnRadiusFact,       &Fact::valueChanged,                            this, &YellowScanInitPathComplexItem::_setDirty);    
    connect(&_corridorPolyline,     &QGCMapPolyline::pathChanged,                   this, &YellowScanInitPathComplexItem::_setDirty);

    connect(&_corridorPolyline,     &QGCMapPolyline::dirtyChanged,                  this, &YellowScanInitPathComplexItem::_polylineDirtyChanged);

    connect(&_corridorPolyline,     &QGCMapPolyline::pathChanged,                   this, &YellowScanInitPathComplexItem::_rebuildCorridorPolygon);    

    connect(&_corridorPolyline,     &QGCMapPolyline::isValidChanged,                this, &YellowScanInitPathComplexItem::_updateWizardMode);
    connect(&_corridorPolyline,     &QGCMapPolyline::traceModeChanged,              this, &YellowScanInitPathComplexItem::_updateWizardMode);

    connect(&_angleFact,            &Fact::valueChanged,                            this, &YellowScanInitPathComplexItem::_rebuildTransects);
    connect(&_turnRadiusFact,       &Fact::valueChanged,                            this, &YellowScanInitPathComplexItem::_rebuildTransects);

    if (!kmlFile.isEmpty()) {
        _corridorPolyline.loadKMLFile(kmlFile);
        _corridorPolyline.setDirty(false);
    }
    setDirty(false);
}

void YellowScanInitPathComplexItem::save(QJsonArray&  planItems)
{
    QJsonObject saveObject;

    _saveCommon(saveObject);
    planItems.append(saveObject);
}

void YellowScanInitPathComplexItem::savePreset(const QString& name)
{
    QJsonObject saveObject;

    _saveCommon(saveObject);
    _savePresetJson(name, saveObject);
}

void YellowScanInitPathComplexItem::_saveCommon(QJsonObject& saveObject)
{
    TransectStyleComplexItem::_save(saveObject);

    saveObject[JsonHelper::jsonVersionKey] =                    2;
    saveObject[VisualMissionItem::jsonTypeKey] =                VisualMissionItem::jsonTypeComplexItemValue;
    saveObject[ComplexMissionItem::jsonComplexItemTypeKey] =    jsonComplexItemTypeValue;
    saveObject[corridorWidthName] =                             _corridorWidthFact.rawValue().toDouble();
    saveObject[angleName] =                                     _angleFact.rawValue().toDouble();
    saveObject[turnRadiusName] =                                _turnRadiusFact.rawValue().toDouble();
    saveObject[_jsonEntryPointKey] =                            _entryPoint;

    _corridorPolyline.saveToJson(saveObject);
}

void YellowScanInitPathComplexItem::loadPreset(const QString& name)
{
    QString errorString;

    QJsonObject presetObject = _loadPresetJson(name);
    if (!_loadWorker(presetObject, 0, errorString, true /* forPresets */)) {
        qgcApp()->showAppMessage(QStringLiteral("Internal Error: Preset load failed. Name: %1 Error: %2").arg(name).arg(errorString));
    }
    _rebuildTransects();
}

bool YellowScanInitPathComplexItem::_loadWorker(const QJsonObject& complexObject, int sequenceNumber, QString& errorString, bool forPresets)
{
    _ignoreRecalc = !forPresets;

    QList<JsonHelper::KeyValidateInfo> keyInfoList = {
        { JsonHelper::jsonVersionKey,                   QJsonValue::Double, true },
        { VisualMissionItem::jsonTypeKey,               QJsonValue::String, true },
        { ComplexMissionItem::jsonComplexItemTypeKey,   QJsonValue::String, true },
        { corridorWidthName,                            QJsonValue::Double, true },
        { _jsonEntryPointKey,                           QJsonValue::Double, true },
        { QGCMapPolyline::jsonPolylineKey,              QJsonValue::Array,  true },
    };
    if (!JsonHelper::validateKeys(complexObject, keyInfoList, errorString)) {
        _ignoreRecalc = false;
        return false;
    }

    QString itemType = complexObject[VisualMissionItem::jsonTypeKey].toString();
    QString complexType = complexObject[ComplexMissionItem::jsonComplexItemTypeKey].toString();
    if (itemType != VisualMissionItem::jsonTypeComplexItemValue || complexType != jsonComplexItemTypeValue) {
        errorString = tr("%1 does not support loading this complex mission item type: %2:%3").arg(qgcApp()->applicationName()).arg(itemType).arg(complexType);
        _ignoreRecalc = false;
        return false;
    }

    int version = complexObject[JsonHelper::jsonVersionKey].toInt();
    if (version != 2) {
        errorString = tr("%1 complex item version %2 not supported").arg(jsonComplexItemTypeValue).arg(version);
        _ignoreRecalc = false;
        return false;
    }

    if (!forPresets) {
        if (!_corridorPolyline.loadFromJson(complexObject, true, errorString)) {
            _ignoreRecalc = false;
            return false;
        }
    }

    setSequenceNumber(sequenceNumber);

    if (!_load(complexObject, forPresets, errorString)) {
        _ignoreRecalc = false;
        return false;
    }

    _corridorWidthFact.setRawValue(complexObject[corridorWidthName].toDouble());

    _angleFact.setRawValue(complexObject[angleName].toDouble());

    _turnRadiusFact.setRawValue(complexObject[turnRadiusName].toDouble());

    _entryPoint = complexObject[_jsonEntryPointKey].toInt();

    _ignoreRecalc = false;

    _recalcComplexDistance();
    if (_cameraShots == 0) {
        // Shot count was possibly not available from plan file
        _recalcCameraShots();
    }

    return true;
}

bool YellowScanInitPathComplexItem::load(const QJsonObject& complexObject, int sequenceNumber, QString& errorString)
{
    return _loadWorker(complexObject, sequenceNumber, errorString, false /* forPresets */);
}

bool YellowScanInitPathComplexItem::specifiesCoordinate(void) const
{
    return _corridorPolyline.count() > 1;
}

int YellowScanInitPathComplexItem::_calcTransectCount(void) const
{
    double fullWidth = _corridorWidthFact.rawValue().toDouble();
    return fullWidth > 0.0 ? qCeil(fullWidth / _calcTransectSpacing()) : 1;
}

void YellowScanInitPathComplexItem::_polylineDirtyChanged(bool dirty)
{
    if (dirty) {
        setDirty(true);
    }
}

void YellowScanInitPathComplexItem::rotateEntryPoint(void)
{
    _entryPoint++;
    if (_entryPoint > 3) {
        _entryPoint = 0;
    }

    _rebuildTransects();
}

void YellowScanInitPathComplexItem::_rebuildCorridorPolygon(void)
{
    if (_corridorPolyline.count() < 2) {
        _surveyAreaPolygon.clear();
        return;
    }

    double halfWidth = 0;//_corridorWidthFact.rawValue().toDouble() / 2.0;

    QList<QGeoCoordinate> firstSideVertices = _corridorPolyline.offsetPolyline(halfWidth);
    QList<QGeoCoordinate> secondSideVertices = _corridorPolyline.offsetPolyline(-halfWidth);

    _surveyAreaPolygon.clear();

    QList<QGeoCoordinate> rgCoord;
    for (const QGeoCoordinate& vertex: firstSideVertices) {
        rgCoord.append(vertex);
    }
    for (int i=secondSideVertices.count() - 1; i >= 0; i--) {
        rgCoord.append(secondSideVertices[i]);
    }
    _surveyAreaPolygon.appendVertices(rgCoord);
}

vector<pair<double,double>> YellowScanInitPathComplexItem::generate_semicircle_from_origin(double lat_origin, double lon_origin,
                                                             double radius_m, int num_points, double theta_deg)
{
    vector<pair<double,double>> waypoints;

    // Convert origin coordinates and angle to radians
    double lat_rad = lat_origin * PI / 180.0;
    double lon_rad = lon_origin * PI / 180.0;
    double theta_rad = theta_deg * PI / 180.0;

    for(int i = 0; i <= num_points; i++){
        // Calculate bearing for each point
        double bearing = theta_rad - PI/2 + (PI * i / num_points);

        // Compute latitude and longitude of waypoint
        double lat2 = asin(sin(lat_rad)*cos(radius_m/R) + cos(lat_rad)*sin(radius_m/R)*cos(bearing));
        double lon2 = lon_rad + atan2(sin(bearing)*sin(radius_m/R)*cos(lat_rad),
                                      cos(radius_m/R)-sin(lat_rad)*sin(lat2));

        // Store waypoint in degrees
        waypoints.push_back({lat2*180.0/PI, lon2*180.0/PI});
    }
    return waypoints;
}

void YellowScanInitPathComplexItem::_rebuildTransectsPhase1(void)
{
    _transects.clear();
    if (_corridorPolyline.count() < 2) {
        return;
    }

    QList<QGeoCoordinate> baseLine = _corridorPolyline.offsetPolyline(0.0);
    if (baseLine.count() < 2) return;

    QGeoCoordinate start = baseLine.first();

    // ★ 프로퍼티 값 사용 ★
    double lineLength = 30.0;//_pathLength;  // QML에서 조정 가능
    double bearing = _angleFact.rawValue().toDouble(); //80.0;//_pathBearing;    // QML에서 조정 가능
    double radius =  _turnRadiusFact.rawValue().toDouble();//20.0;//_turnRadius;      // QML에서 조정 가능

    // bearing이 0이면 polyline 방향 사용 (자동 모드)
    if (qFuzzyIsNull(bearing) && baseLine.count() > 1) {
        bearing = start.azimuthTo(baseLine[1]);
    }

    QGeoCoordinate end = start.atDistanceAndAzimuth(lineLength, bearing);

    double actualDistance = start.distanceTo(end);
     qInfo() << "=== YellowScan Path Info ===";
     qInfo() << "Target distance:" << lineLength << "m";
     qInfo() << "Actual distance:" << actualDistance << "m";
     qInfo() << "Bearing:" << bearing << "degrees";
     qInfo() << "Turn radius:" << radius << "m";

    setFixedYawDeg(bearing); // Save Current WP angle

    QList<TransectStyleComplexItem::CoordInfo_t> transect;

    // 시작 전 미션 속도 변경
    transect.append({start,CoordTypeYellowScanMaxSpeed});

    // 1회 왕복
    transect.append({start, CoordTypeYellowScan});
    transect.append({start, CoordTypeYellowScanChangeYaw});
    transect.append({end,   CoordTypeYellowScan});
    transect.append({end, CoordTypeYellowScanChangeYaw});

    // 2회 왕복
    transect.append({end,   CoordTypeYellowScan});
    transect.append({end, CoordTypeYellowScanChangeYaw});
    transect.append({start, CoordTypeYellowScan});
    transect.append({start, CoordTypeYellowScanChangeYaw});

    // 3회 왕복
    transect.append({start, CoordTypeYellowScan});    
    transect.append({end,   CoordTypeYellowScan});    
   // Reduce speed before entering the U-turn so the drone tracks the semicircle
    // more tightly instead of overshooting the turn.
    transect.append({end,   CoordTypeYellowScanTurnSpeed});
    // 반원 생성
    double rightAzimuth = bearing + 90.0;
    if (rightAzimuth >= 360.0) rightAzimuth -= 360.0;

    QGeoCoordinate semicircleCenter = end.atDistanceAndAzimuth(radius, rightAzimuth);

    vector<pair<double,double>> semicircle = generate_semicircle_from_origin(
        semicircleCenter.latitude(),
        semicircleCenter.longitude(),
        radius,
        radius,
        rightAzimuth - 90
        );

    for (const auto& p : semicircle) {
        TransectStyleComplexItem::CoordInfo_t coordInfo;
        coordInfo.coord = QGeoCoordinate(p.first, p.second);
        coordInfo.coordType = CoordTypeYellowScan;

        if (!transect.isEmpty() && transect.last().coord.isValid() && transect.last().coord.distanceTo(coordInfo.coord) < 0.05) {
            continue;
        }

        transect.append(coordInfo);
    }

    // 끝날때는 원래 속도로 원복해줘야함
    transect.append({transect.last().coord, CoordTypeYellowScanPreviousSpeed});

    _transects.append(transect);
    qInfo() << "ys transect count = " << _transects.count();
}

void YellowScanInitPathComplexItem::_recalcCameraShots(void)
{
    double triggerDistance = _cameraCalc.adjustedFootprintFrontal()->rawValue().toDouble();
    if (triggerDistance == 0) {
        _cameraShots = 0;
    } else {
        if (_cameraTriggerInTurnAroundFact.rawValue().toBool()) {
            _cameraShots = qCeil(_complexDistance / triggerDistance);
        } else {
            int singleTransectImageCount = qCeil(_corridorPolyline.length() / triggerDistance);
            _cameraShots = singleTransectImageCount * _calcTransectCount();
        }
    }
    emit cameraShotsChanged();
}

YellowScanInitPathComplexItem::ReadyForSaveState YellowScanInitPathComplexItem::readyForSaveState(void) const
{
    return TransectStyleComplexItem::readyForSaveState();
}

double YellowScanInitPathComplexItem::timeBetweenShots(void)
{
    return _vehicleSpeed == 0 ? 0 : _cameraCalc.adjustedFootprintFrontal()->rawValue().toDouble() / _vehicleSpeed;
}

double YellowScanInitPathComplexItem::_calcTransectSpacing(void) const
{
    double transectSpacing = _cameraCalc.adjustedFootprintSide()->rawValue().toDouble();
    if (transectSpacing < 0.5) {
        // We can't let spacing get too small otherwise we will end up with too many transects.
        // So we limit to 0.5 meter spacing as min and set to huge value which will cause a single
        // transect to be added.
        transectSpacing = 100000;
    }

    return transectSpacing;
}

void YellowScanInitPathComplexItem::_updateWizardMode(void)
{
    if (_corridorPolyline.isValid() && !_corridorPolyline.traceMode()) {
        setWizardMode(false);
    }
}
