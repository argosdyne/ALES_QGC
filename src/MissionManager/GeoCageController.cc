/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "GeoCageController.h"
#include "QGCLoggingCategory.h"

QGC_LOGGING_CATEGORY(GeoCageControllerLog, "GeoCageControllerLog")

GeoCageController::GeoCageController(QObject* parent)
    : QObject(parent)
    , _cageRadiusFact      (0, "CAGE_RADIUS",      FactMetaData::valueTypeDouble)
    , _cageMaxAltFact      (0, "CAGE_MAX_ALT",     FactMetaData::valueTypeDouble)
    , _cageMinAltFact      (0, "CAGE_MIN_ALT",     FactMetaData::valueTypeDouble)
{
    _initFacts();

    connect(&_polygons, &QmlObjectListModel::dirtyChanged, this, &GeoCageController::_setDirty);
    connect(&_circles,  &QmlObjectListModel::dirtyChanged, this, &GeoCageController::_setDirty);
    connect(&_polygons, &QmlObjectListModel::countChanged, this, &GeoCageController::_updateContainsItems);
    connect(&_circles,  &QmlObjectListModel::countChanged, this, &GeoCageController::_updateContainsItems);
}

void GeoCageController::_initFacts()
{
    auto* radiusMeta = new FactMetaData(FactMetaData::valueTypeDouble, &_cageRadiusFact);
    radiusMeta->setShortDescription(tr("Cage radius"));
    radiusMeta->setRawUnits(QStringLiteral("m"));
    radiusMeta->setRawMin(0.0);
    _cageRadiusFact.setMetaData(radiusMeta);
    _cageRadiusFact.setRawValue(100.0);

    auto* maxAltMeta = new FactMetaData(FactMetaData::valueTypeDouble, &_cageMaxAltFact);
    maxAltMeta->setShortDescription(tr("Cage max altitude"));
    maxAltMeta->setRawUnits(QStringLiteral("m"));
    maxAltMeta->setRawMin(0.0);
    _cageMaxAltFact.setMetaData(maxAltMeta);
    _cageMaxAltFact.setRawValue(120.0);

    auto* minAltMeta = new FactMetaData(FactMetaData::valueTypeDouble, &_cageMinAltFact);
    minAltMeta->setShortDescription(tr("Cage min altitude"));
    minAltMeta->setRawUnits(QStringLiteral("m"));
    _cageMinAltFact.setMetaData(minAltMeta);
    _cageMinAltFact.setRawValue(0.0);

    connect(&_cageRadiusFact, &Fact::rawValueChanged, this, &GeoCageController::_setDirty);
    connect(&_cageMaxAltFact, &Fact::rawValueChanged, this, &GeoCageController::_setDirty);
    connect(&_cageMinAltFact, &Fact::rawValueChanged, this, &GeoCageController::_setDirty);
}

bool GeoCageController::containsItems() const
{
    return _polygons.count() > 0 || _circles.count() > 0;
}

void GeoCageController::setDirty(bool dirty)
{
    if (_dirty != dirty) {
        _dirty = dirty;
        emit dirtyChanged(_dirty);
    }
}

void GeoCageController::_setDirty()
{
    setDirty(true);
}

void GeoCageController::_updateContainsItems()
{
    emit containsItemsChanged(containsItems());
}

void GeoCageController::addInclusionPolygon(QGeoCoordinate topLeft, QGeoCoordinate bottomRight)
{
    QGeoCoordinate topRight(topLeft.latitude(), bottomRight.longitude());
    QGeoCoordinate bottomLeft(bottomRight.latitude(), topLeft.longitude());

    double halfWidthMeters = topLeft.distanceTo(topRight) / 2.0;
    double halfHeightMeters = topLeft.distanceTo(bottomLeft) / 2.0;

    QGeoCoordinate centerLeftEdge = topLeft.atDistanceAndAzimuth(halfHeightMeters, 180);
    QGeoCoordinate centerTopEdge = topLeft.atDistanceAndAzimuth(halfWidthMeters, 90);
    QGeoCoordinate center(centerLeftEdge.latitude(), centerTopEdge.longitude());

    halfWidthMeters =   qMin(halfWidthMeters * 0.75, 1500.0);
    halfHeightMeters =  qMin(halfHeightMeters * 0.75, 1500.0);

    topLeft =           center.atDistanceAndAzimuth(halfWidthMeters, -90).atDistanceAndAzimuth(halfHeightMeters, 0);
    topRight =          center.atDistanceAndAzimuth(halfWidthMeters, 90).atDistanceAndAzimuth(halfHeightMeters, 0);
    bottomLeft =        center.atDistanceAndAzimuth(halfWidthMeters, -90).atDistanceAndAzimuth(halfHeightMeters, 180);
    bottomRight =       center.atDistanceAndAzimuth(halfWidthMeters, 90).atDistanceAndAzimuth(halfHeightMeters, 180);

    QGCFencePolygon* polygon = new QGCFencePolygon(true /* inclusion */, this);
    polygon->appendVertex(topLeft);
    polygon->appendVertex(topRight);
    polygon->appendVertex(bottomRight);
    polygon->appendVertex(bottomLeft);
    _polygons.append(polygon);

    clearAllInteractive();
    polygon->setInteractive(true);
    _setDirty();
}

void GeoCageController::addInclusionCircle(QGeoCoordinate topLeft, QGeoCoordinate bottomRight)
{
    QGeoCoordinate topRight(topLeft.latitude(), bottomRight.longitude());
    QGeoCoordinate bottomLeft(bottomRight.latitude(), topLeft.longitude());

    double halfWidthMeters = topLeft.distanceTo(topRight) / 2.0;
    double halfHeightMeters = topLeft.distanceTo(bottomLeft) / 2.0;
    double radius = qMin(qMin(halfWidthMeters, halfHeightMeters) * 0.75, 1500.0);

    QGeoCoordinate centerLeftEdge = topLeft.atDistanceAndAzimuth(halfHeightMeters, 180);
    QGeoCoordinate centerTopEdge = topLeft.atDistanceAndAzimuth(halfWidthMeters, 90);
    QGeoCoordinate center(centerLeftEdge.latitude(), centerTopEdge.longitude());

    QGCFenceCircle* circle = new QGCFenceCircle(center, radius, true /* inclusion */, this);
    _circles.append(circle);

    clearAllInteractive();
    circle->setInteractive(true);
    _setDirty();
}

void GeoCageController::deletePolygon(int index)
{
    if (index < 0 || index > _polygons.count() - 1) {
        return;
    }

    QGCFencePolygon* polygon = qobject_cast<QGCFencePolygon*>(_polygons.removeAt(index));
    polygon->deleteLater();
    _setDirty();
}

void GeoCageController::deleteCircle(int index)
{
    if (index < 0 || index > _circles.count() - 1) {
        return;
    }

    QGCFenceCircle* circle = qobject_cast<QGCFenceCircle*>(_circles.removeAt(index));
    circle->deleteLater();
    _setDirty();
}

void GeoCageController::clearAllInteractive(void)
{
    for (int i=0; i<_polygons.count(); i++) {
        _polygons.value<QGCFencePolygon*>(i)->setInteractive(false);
    }
    for (int i=0; i<_circles.count(); i++) {
        _circles.value<QGCFenceCircle*>(i)->setInteractive(false);
    }
}

void GeoCageController::removeAll(void)
{
    _polygons.clearAndDeleteContents();
    _circles.clearAndDeleteContents();
    setDirty(false);
}
