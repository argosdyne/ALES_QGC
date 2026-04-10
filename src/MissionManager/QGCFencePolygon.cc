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

const char* QGCFencePolygon::_jsonInclusionKey = "inclusion";

QGCFencePolygon::QGCFencePolygon(bool inclusion, QObject* parent)
    : QGCMapPolygon (parent)
    , _inclusion    (inclusion)
{
    _init();
}

QGCFencePolygon::QGCFencePolygon(const QGCFencePolygon& other, QObject* parent)
    : QGCMapPolygon (other, parent)
    , _inclusion    (other._inclusion)
{
    _init();
}

void QGCFencePolygon::_init(void)
{
    connect(this, &QGCFencePolygon::inclusionChanged, this, &QGCFencePolygon::_setDirty);
    //Test
    connect(this, &QGCFencePolygon::colorInclusionChanged, this, &QGCFencePolygon::_setDirty);
    connect(this, &QGCFencePolygon::strokeOpcaityChanged, this, &QGCFencePolygon::_setDirty);
}

const QGCFencePolygon& QGCFencePolygon::operator=(const QGCFencePolygon& other)
{
    QGCMapPolygon::operator=(other);

    setInclusion(other._inclusion);

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
    QGCMapPolygon::saveToJson(json);
}

bool QGCFencePolygon::loadFromJson(const QJsonObject& json, bool required, QString& errorString)
{
    errorString.clear();

    QList<JsonHelper::KeyValidateInfo> keyInfoList = {
        { JsonHelper::jsonVersionKey,   QJsonValue::Double, true },
        { _jsonInclusionKey,            QJsonValue::Bool,   true },
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
