#ifndef FLIGHTZONEMANAGER_H
#define FLIGHTZONEMANAGER_H

#include <QObject>
#include "GeoFenceManager.h"
//#include "Vehicle.h"
#include <QSet>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonDocument>
#include "SettingsManager.h"
#include "QGroundControlQmlGlobal.h"
//#include "MultiVehicleManager.h"
#include "PositionManager.h"
#include "ADSBVehicle.h"

class GeoFenceManager;

class FlightZoneManager : public QObject
{
    Q_OBJECT

public:
    FlightZoneManager();

    Q_PROPERTY(QmlObjectListModel*  polygons                READ polygons                                           CONSTANT)
    Q_PROPERTY(QmlObjectListModel*  circles                 READ circles                                            CONSTANT)


    void start();
    Q_INVOKABLE void updatePolygonVisibility();

    //Check zoom value
    void checkCurrentZoomValue();

    QString getFilePath();
    void processJsonFile(const QString& filePath);
    Q_INVOKABLE void deletePolygon(int index);

    QmlObjectListModel* polygons                (void) { return &_polygons; }
    QmlObjectListModel* circles                 (void) { return &_circles; }

    void removeAll();
    // Test


    void processJsonFile(QJsonDocument jsonDoc);
    void fetchGeoJsonDataForRegion(double n, double e, double s, double w);

    void getOnlineGeoJsonData();
    void calculateCornerCoordinates(double centerLat, double centerLon, double zoomLevel, double width, double height);

    void checkDistanceDroneAndGeoAwareness();

    void updateGeoAwareness();
signals:



private slots:
    //Test
    void onReplyFinished(QNetworkReply *reply);


public slots:


private:
    //Vehicle*            _managerVehicle; //=               nullptr;
    ADSBVehicle* adsbVehicle;
    GeoFenceManager*    _geoFenceManager =              nullptr;
    bool                _dirty =                        false;
    QmlObjectListModel  _polygons;
    QmlObjectListModel  _circles;

    QSet<int> _removedPolygonIndices;
    QSet<int> _addedPolygonIndices;


    //Timer

    QTimer _timer;

    QTimer _zoomTimer;

    QTimer* _debounceTimer = nullptr;
    double _lastZoom = 0;
    QGeoCoordinate _lastMapCoord;
    void _processZoomCheck();

    QTimer _distanceTimer;

    QTimer _updateTimer;

    //Test
    QNetworkAccessManager *manager;
    SettingsManager*    _settingsManager = nullptr;
    QGCToolbox*         _toolbox = nullptr;

    QGroundControlQmlGlobal* qGroundControlQmlGlobal;

    QMetaObject::Connection connection;
    //TEst
    double zoomLevel;

    //MultiVehicleManager* multiVehicleManager;
    QGCPositionManager* qgcpositionManager;
    bool _oneTime = false;
    bool _isGroundHazard = false;
};

class FlightValidTime {
public:
    qint64 polygonid;
    QDateTime validFrom;
    QDateTime validTo;
    bool isCreated = false;

    FlightValidTime(qint64 _polygonid, QDateTime _validFrom, QDateTime _validTo, bool _isCreated) :polygonid(_polygonid), validFrom(_validFrom), validTo(_validTo), isCreated(_isCreated) {}


};

class GeoJsonNameList {
public:
    QString name;

    GeoJsonNameList(QString _name) : name(_name) {}
    bool operator==(const GeoJsonNameList& other) const {
        return this->name == other.name;
    }
};

class NoFlyZone {
public:
    QGeoCoordinate coordinate;
    double altitudeFloor; //bottom of no fly zone
    double altitudeCeiling; // top of no fly zone

    NoFlyZone(const QGeoCoordinate& coord, double floor, double ceiling)
        : coordinate(coord), altitudeFloor(floor), altitudeCeiling(ceiling) {}

    bool operator==(const NoFlyZone& other) const {
        return coordinate == other.coordinate &&
               altitudeFloor == other.altitudeFloor &&
               altitudeCeiling == other.altitudeCeiling;
    }
};


#endif // FLIGHTZONEMANAGER_H
