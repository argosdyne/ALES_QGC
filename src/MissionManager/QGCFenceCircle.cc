/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "QGCFenceCircle.h"
#include "JsonHelper.h"
#include "Vehicle.h"
#include "ParameterManager.h"
#include "QGCApplication.h"

#include <QtGlobal>

const char* QGCFenceCircle::_jsonInclusionKey = "inclusion";
const char* QGCFenceCircle::_jsonAltitudeBandEnabledKey = "altitudeBandEnabled";
const char* QGCFenceCircle::_jsonAltitudeMinKey = "altitudeMin";
const char* QGCFenceCircle::_jsonAltitudeMaxKey = "altitudeMax";
const char* QGCFenceCircle::_jsonAltitudeFrameKey = "altitudeFrame";
const char* QGCFenceCircle::_jsonInclusionGroupKey = "inclusionGroup";

QGCFenceCircle::QGCFenceCircle(QObject* parent)
    : QGCMapCircle  (parent)
    , _inclusion    (true)
{
    _init();
}

QGCFenceCircle::QGCFenceCircle(const QGeoCoordinate& center, double radius, bool inclusion, QObject* parent)
    : QGCMapCircle  (center, radius, false /* showRotation */, true /* clockwiseRotation */, parent)
    , _inclusion    (inclusion)
{
    _init();
}

QGCFenceCircle::QGCFenceCircle(const QGCFenceCircle& other, QObject* parent)
    : QGCMapCircle  (other, parent)
    , _inclusion    (other._inclusion)
    , _altitudeBandEnabled(other._altitudeBandEnabled)
    , _altitudeMin  (other._altitudeMin)
    , _altitudeMax  (other._altitudeMax)
    , _altitudeFrame(other._altitudeFrame)
    , _inclusionGroup(other._inclusionGroup)
{
    _init();
}

void QGCFenceCircle::_init(void)
{
    connect(this, &QGCFenceCircle::inclusionChanged, this, &QGCFenceCircle::_setDirty);
    connect(this, &QGCFenceCircle::altitudeBandEnabledChanged, this, &QGCFenceCircle::_setDirty);
    connect(this, &QGCFenceCircle::altitudeMinChanged, this, &QGCFenceCircle::_setDirty);
    connect(this, &QGCFenceCircle::altitudeMaxChanged, this, &QGCFenceCircle::_setDirty);
    connect(this, &QGCFenceCircle::altitudeFrameChanged, this, &QGCFenceCircle::_setDirty);
    connect(this, &QGCFenceCircle::inclusionGroupChanged, this, &QGCFenceCircle::_setDirty);
    connect(this, &QGCFenceCircle::colorInclusionChanged, this, &QGCFenceCircle::_setDirty);
    connect(this, &QGCFenceCircle::strokeOpcaityChanged, this, &QGCFenceCircle::_setDirty);
}

const QGCFenceCircle& QGCFenceCircle::operator=(const QGCFenceCircle& other)
{
    QGCMapCircle::operator=(other);

    setInclusion(other._inclusion);
    setAltitudeBandEnabled(other._altitudeBandEnabled);
    setAltitudeMin(other._altitudeMin);
    setAltitudeMax(other._altitudeMax);
    setAltitudeFrame(other._altitudeFrame);
    setInclusionGroup(other._inclusionGroup);

    return *this;
}

void QGCFenceCircle::_setDirty(void)
{
    setDirty(true);
}

void QGCFenceCircle::saveToJson(QJsonObject& json)
{
    json[JsonHelper::jsonVersionKey] = _jsonCurrentVersion;
    json[_jsonInclusionKey] = _inclusion;
    json[_jsonAltitudeBandEnabledKey] = _altitudeBandEnabled;
    json[_jsonAltitudeMinKey] = _altitudeMin;
    json[_jsonAltitudeMaxKey] = _altitudeMax;
    json[_jsonAltitudeFrameKey] = _altitudeFrame;
    json[_jsonInclusionGroupKey] = _inclusionGroup;
    QGCMapCircle::saveToJson(json);
}

bool QGCFenceCircle::loadFromJson(const QJsonObject& json, QString& errorString)
{
    errorString.clear();

    QList<JsonHelper::KeyValidateInfo> keyInfoList = {
        { JsonHelper::jsonVersionKey,   QJsonValue::Double, true },
        { _jsonInclusionKey,            QJsonValue::Bool,   true },
        { _jsonAltitudeBandEnabledKey,  QJsonValue::Bool,   false },
        { _jsonAltitudeMinKey,          QJsonValue::Double, false },
        { _jsonAltitudeMaxKey,          QJsonValue::Double, false },
        { _jsonAltitudeFrameKey,        QJsonValue::Double, false },
        { _jsonInclusionGroupKey,       QJsonValue::Double, false },
    };
    if (!JsonHelper::validateKeys(json, keyInfoList, errorString)) {
        return false;
    }

    if (json[JsonHelper::jsonVersionKey].toInt() != _jsonCurrentVersion) {
        errorString = tr("GeoFence Circle only supports version %1").arg(_jsonCurrentVersion);
        return false;
    }

    if (!QGCMapCircle::loadFromJson(json, errorString)) {
        return false;
    }

    setInclusion(json[_jsonInclusionKey].toBool());
    setAltitudeBandEnabled(json[_jsonAltitudeBandEnabledKey].toBool(false));
    setAltitudeMin(json[_jsonAltitudeMinKey].toDouble(0.0));
    setAltitudeMax(json[_jsonAltitudeMaxKey].toDouble(0.0));
    setAltitudeFrame(json[_jsonAltitudeFrameKey].toInt(MAV_FRAME_GLOBAL_RELATIVE_ALT));
    setInclusionGroup(json[_jsonInclusionGroupKey].toInt(0));

    return true;
}

void QGCFenceCircle::setInclusion(bool inclusion)
{
    if (inclusion != _inclusion) {
        _inclusion = inclusion;
        emit inclusionChanged(inclusion);
        qInfo() << "setInclusion circle value = " << inclusion;

        MultiVehicleManager* manager = qgcApp()->toolbox()->multiVehicleManager();
        if(manager){
            if(manager->activeVehicle()->firmwareType() != MAV_AUTOPILOT_ARDUPILOTMEGA) {
                qInfo() << "This is PX4";
                Fact* inclusion = manager->activeVehicle()->parameterManager()->getParameter(-1, "GF_ALT_INSIDE");
                inclusion->setRawValue(_inclusion);
            }
        }

    }
}

void QGCFenceCircle::setAltitudeBandEnabled(bool altitudeBandEnabled)
{
    if (_altitudeBandEnabled != altitudeBandEnabled) {
        _altitudeBandEnabled = altitudeBandEnabled;
        emit altitudeBandEnabledChanged(altitudeBandEnabled);
    }
}

void QGCFenceCircle::setAltitudeMin(double altitudeMin)
{
    if (qAbs(_altitudeMin - altitudeMin) > 0.000001) {
        _altitudeMin = altitudeMin;
        emit altitudeMinChanged(altitudeMin);
    }
}

void QGCFenceCircle::setAltitudeMax(double altitudeMax)
{
    if (qAbs(_altitudeMax - altitudeMax) > 0.000001) {
        _altitudeMax = altitudeMax;
        emit altitudeMaxChanged(altitudeMax);
    }
}

void QGCFenceCircle::setAltitudeFrame(int altitudeFrame)
{
    switch (altitudeFrame) {
    case MAV_FRAME_GLOBAL_INT:
        altitudeFrame = MAV_FRAME_GLOBAL;
        break;
    case MAV_FRAME_GLOBAL_RELATIVE_ALT_INT:
        altitudeFrame = MAV_FRAME_GLOBAL_RELATIVE_ALT;
        break;
    case MAV_FRAME_GLOBAL_TERRAIN_ALT_INT:
        altitudeFrame = MAV_FRAME_GLOBAL_TERRAIN_ALT;
        break;
    case MAV_FRAME_GLOBAL:
    case MAV_FRAME_GLOBAL_RELATIVE_ALT:
    case MAV_FRAME_GLOBAL_TERRAIN_ALT:
        break;
    default:
        qWarning() << "Unsupported 3D circle fence altitude frame" << altitudeFrame;
        return;
    }

    if (_altitudeFrame != altitudeFrame) {
        _altitudeFrame = altitudeFrame;
        emit altitudeFrameChanged(altitudeFrame);
    }
}

void QGCFenceCircle::setInclusionGroup(int inclusionGroup)
{
    inclusionGroup = qMax(0, inclusionGroup);
    if (_inclusionGroup != inclusionGroup) {
        _inclusionGroup = inclusionGroup;
        emit inclusionGroupChanged(inclusionGroup);
    }
}

void QGCFenceCircle::setcolorInclusion(QColor colorinclusion) {
    if(colorinclusion != _colorInclusion){
        _colorInclusion = colorinclusion;
        qInfo() << "Color Inclusion value = " << colorinclusion;
        emit colorInclusionChanged();
    }
}
void QGCFenceCircle::setstrokeOpacity(double opacity) {
    if(opacity != _strokeOpacity){
        _strokeOpacity = opacity;
        qInfo() << "Stroke Opacity value = "<< opacity;
        emit strokeOpcaityChanged();
    }
}
