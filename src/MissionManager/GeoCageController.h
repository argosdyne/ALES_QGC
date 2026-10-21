/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QObject>
#include <QGeoCoordinate>

#include "QmlObjectListModel.h"
#include "QGCFencePolygon.h"
#include "QGCFenceCircle.h"
#include "Fact.h"
#include "FactMetaData.h"
#include "QGCLoggingCategory.h"

Q_DECLARE_LOGGING_CATEGORY(GeoCageControllerLog)

/// Lightweight controller for GeoCage visuals/settings, independent from GeoFence
class GeoCageController : public QObject
{
    Q_OBJECT
public:
    explicit GeoCageController(QObject* parent = nullptr);
    ~GeoCageController() = default;

    Q_PROPERTY(QmlObjectListModel* polygons         READ polygons         CONSTANT)
    Q_PROPERTY(QmlObjectListModel* circles          READ circles          CONSTANT)
    Q_PROPERTY(Fact*                cageRadius      READ cageRadius       CONSTANT)
    Q_PROPERTY(Fact*                cageMaxAltitude READ cageMaxAltitude  CONSTANT)
    Q_PROPERTY(Fact*                cageMinAltitude READ cageMinAltitude  CONSTANT)
    Q_PROPERTY(bool                 dirty           READ dirty            WRITE setDirty NOTIFY dirtyChanged)
    Q_PROPERTY(bool                 supported       READ supported        CONSTANT)
    Q_PROPERTY(bool                 containsItems   READ containsItems    NOTIFY containsItemsChanged)

    QmlObjectListModel* polygons         () { return &_polygons; }
    QmlObjectListModel* circles          () { return &_circles; }
    Fact*                cageRadius      () { return &_cageRadiusFact; }
    Fact*                cageMaxAltitude () { return &_cageMaxAltFact; }
    Fact*                cageMinAltitude () { return &_cageMinAltFact; }

    bool dirty() const { return _dirty; }
    void setDirty(bool dirty);
    bool supported() const { return true; }
    bool containsItems() const;

    Q_INVOKABLE void addInclusionPolygon(QGeoCoordinate topLeft, QGeoCoordinate bottomRight);
    Q_INVOKABLE void addInclusionCircle(QGeoCoordinate topLeft, QGeoCoordinate bottomRight);
    Q_INVOKABLE void deletePolygon(int index);
    Q_INVOKABLE void deleteCircle(int index);
    Q_INVOKABLE void clearAllInteractive(void);
    Q_INVOKABLE void removeAll(void);

signals:
    void dirtyChanged(bool dirty);
    void containsItemsChanged(bool contains);

private slots:
    void _setDirty();
    void _updateContainsItems();

private:
    void _initFacts();

    QmlObjectListModel  _polygons;
    QmlObjectListModel  _circles;
    Fact                _cageRadiusFact;
    Fact                _cageMaxAltFact;
    Fact                _cageMinAltFact;
    bool                _dirty = false;
};
