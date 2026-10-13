/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "QGCFencePolygon.h"
#include "JsonHelper.h"
#include "Vehicle.h"
#include "ParameterManager.h"
#include "QGCApplication.h"

#include <QtGlobal>

const char* QGCFencePolygon::_jsonInclusionKey = "inclusion";
const char* QGCFencePolygon::_jsonAltitudeBandEnabledKey = "altitudeBandEnabled";
const char* QGCFencePolygon::_jsonAltitudeMinKey = "altitudeMin";
const char* QGCFencePolygon::_jsonAltitudeMaxKey = "altitudeMax";
const char* QGCFencePolygon::_jsonAltitudeFrameKey = "altitudeFrame";
const char* QGCFencePolygon::_jsonInclusionGroupKey = "inclusionGroup";

QGCFencePolygon::QGCFencePolygon(bool inclusion, QObject* parent)
    : QGCMapPolygon (parent)
    , _inclusion    (inclusion)
{
    _init();
}

QGCFencePolygon::QGCFencePolygon(const QGCFencePolygon& other, QObject* parent)
    : QGCMapPolygon (other, parent)
    , _inclusion    (other._inclusion)
    , _altitudeBandEnabled(other._altitudeBandEnabled)
    , _altitudeMin  (other._altitudeMin)
    , _altitudeMax  (other._altitudeMax)
    , _altitudeFrame(other._altitudeFrame)
    , _inclusionGroup(other._inclusionGroup)
{
    _init();
}

void QGCFencePolygon::_init(void)
{
    connect(this, &QGCFencePolygon::inclusionChanged, this, &QGCFencePolygon::_setDirty);
    connect(this, &QGCFencePolygon::altitudeBandEnabledChanged, this, &QGCFencePolygon::_setDirty);
    connect(this, &QGCFencePolygon::altitudeMinChanged, this, &QGCFencePolygon::_setDirty);
    connect(this, &QGCFencePolygon::altitudeMaxChanged, this, &QGCFencePolygon::_setDirty);
    connect(this, &QGCFencePolygon::altitudeFrameChanged, this, &QGCFencePolygon::_setDirty);
    connect(this, &QGCFencePolygon::inclusionGroupChanged, this, &QGCFencePolygon::_setDirty);
    //Test
    connect(this, &QGCFencePolygon::colorInclusionChanged, this, &QGCFencePolygon::_setDirty);
    connect(this, &QGCFencePolygon::strokeOpcaityChanged, this, &QGCFencePolygon::_setDirty);
}

const QGCFencePolygon& QGCFencePolygon::operator=(const QGCFencePolygon& other)
{
    QGCMapPolygon::operator=(other);

    setInclusion(other._inclusion);
    setAltitudeBandEnabled(other._altitudeBandEnabled);
    setAltitudeMin(other._altitudeMin);
    setAltitudeMax(other._altitudeMax);
    setAltitudeFrame(other._altitudeFrame);
    setInclusionGroup(other._inclusionGroup);

    return *this;
}

void QGCFencePolygon::_setDirty(void)
{
    setDirty(true);
}

void QGCFencePolygon::saveToJson(QJsonObject& json)
{
    json[JsonHelper::jsonVersionKey] = _jsonCurrentVersion;
    json[_jsonInclusionKey] = _inclusion;
    json[_jsonAltitudeBandEnabledKey] = _altitudeBandEnabled;
    json[_jsonAltitudeMinKey] = _altitudeMin;
    json[_jsonAltitudeMaxKey] = _altitudeMax;
    json[_jsonAltitudeFrameKey] = _altitudeFrame;
    json[_jsonInclusionGroupKey] = _inclusionGroup;
    QGCMapPolygon::saveToJson(json);
}

bool QGCFencePolygon::loadFromJson(const QJsonObject& json, bool required, QString& errorString)
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
        errorString = tr("GeoFence Polygon only supports version %1").arg(_jsonCurrentVersion);
        return false;
    }

    if (!QGCMapPolygon::loadFromJson(json, required, errorString)) {
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

void QGCFencePolygon::setInclusion(bool inclusion)
{
    if (inclusion != _inclusion) {
        _inclusion = inclusion;
        //qInfo() << "inclusion Value = " << inclusion;
        emit inclusionChanged(inclusion);
        //qInfo() << "setInclusion circle value = " << inclusion;

        MultiVehicleManager* manager = qgcApp()->toolbox()->multiVehicleManager();
        if(manager){
            if(manager->activeVehicle()->firmwareType() != MAV_AUTOPILOT_ARDUPILOTMEGA) {
                //qInfo() << "This is PX4";
                Fact* inclusion = manager->activeVehicle()->parameterManager()->getParameter(-1, "GF_ALT_INSIDE");
                inclusion->setRawValue(_inclusion);
            }
        }
    }
}

void QGCFencePolygon::setAltitudeBandEnabled(bool altitudeBandEnabled)
{
    if (altitudeBandEnabled != _altitudeBandEnabled) {
        _altitudeBandEnabled = altitudeBandEnabled;
        emit altitudeBandEnabledChanged(altitudeBandEnabled);
    }
}

void QGCFencePolygon::setAltitudeMin(double altitudeMin)
{
    if (qAbs(_altitudeMin - altitudeMin) > 0.000001) {
        _altitudeMin = altitudeMin;
        emit altitudeMinChanged(altitudeMin);
    }
}

void QGCFencePolygon::setAltitudeMax(double altitudeMax)
{
    if (qAbs(_altitudeMax - altitudeMax) > 0.000001) {
        _altitudeMax = altitudeMax;
        emit altitudeMaxChanged(altitudeMax);
    }
}

void QGCFencePolygon::setAltitudeFrame(int altitudeFrame)
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
        qWarning() << "Unsupported 3D polygon fence altitude frame" << altitudeFrame;
        return;
    }

    if (_altitudeFrame != altitudeFrame) {
        _altitudeFrame = altitudeFrame;
        emit altitudeFrameChanged(altitudeFrame);
    }
}

void QGCFencePolygon::setInclusionGroup(int inclusionGroup)
{
    inclusionGroup = qMax(0, inclusionGroup);
    if (_inclusionGroup != inclusionGroup) {
        _inclusionGroup = inclusionGroup;
        emit inclusionGroupChanged(inclusionGroup);
    }
}

void QGCFencePolygon::setcolorInclusion(QColor colorinclusion) {
    if(colorinclusion != _colorInclusion){
        _colorInclusion = colorinclusion;
        //qInfo() << "Color Inclusion value = " << colorinclusion;
        emit colorInclusionChanged();
    }
}
void QGCFencePolygon::setstrokeOpacity(double opacity) {
    if(opacity != _strokeOpacity){
        _strokeOpacity = opacity;
        //qInfo() << "Stroke Opacity value = "<< opacity;
        emit strokeOpcaityChanged();
    }
}

QVariantList QGCFencePolygon::offsetPath(double distanceMeters) const
{
    if (count() < 3) {
        return QVariantList();
    }

    QGCFencePolygon temp(*this);
    temp.offset(distanceMeters);
    return temp.path();
}
