/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include "SettingsGroup.h"
#include "QGroundControlQmlGlobal.h"
//#include "SettingsManager.h"

class SettingsManager;

class GeoZoneMakeViewSettings : public QObject
{
    Q_OBJECT

public:
    GeoZoneMakeViewSettings(QObject* parent = nullptr);

    //DEFINE_SETTING_NAME_GROUP()

    // Most individual settings related to PlanView are still in AppSettings due to historical reasons.

    Q_PROPERTY(QmlObjectListModel*  polygons                READ polygons            CONSTANT)

    //Create Selectable Area
    Q_INVOKABLE void selectGeoZone();

    //Delete Area
    Q_INVOKABLE void deleteGeoZone();

    //Changeable values
    Q_PROPERTY(QGeoCoordinate   centerCoord         READ centerCoord        WRITE setCenterCoord        NOTIFY centerCoordChanged)
    Q_PROPERTY(double           centerLat           READ centerLat          WRITE setCenterLat          NOTIFY centerLatChanged)
    Q_PROPERTY(double           centerLng           READ centerLng          WRITE setCenterLng          NOTIFY centerLngChanged)
    Q_PROPERTY(double           verticalArea        READ verticalArea       WRITE setVerticalArea       NOTIFY verticalAreaChanged)
    Q_PROPERTY(double           horizontalArea      READ horizontalArea     WRITE setHorizontalArea     NOTIFY horizontalAreaChanged)

    //가로 세로 길이 저장용
    Q_PROPERTY(double           verticalLength        READ verticalLength         WRITE setVerticalLength         NOTIFY verticalLengthChanged)
    Q_PROPERTY(double           horizontalLength      READ horizontalLength       WRITE setHorizontalLength       NOTIFY horizontalLengthChanged)
    double verticalLength()       {return _verticalLength; }
    double horizontalLength()     {return _horizontalLength; }
    void setVerticalLength(double verti)      { if(verti != _verticalLength) { _verticalLength = verti; emit verticalLengthChanged(); }}
    void setHorizontalLength(double hori)     { if(hori != _horizontalLength) { _horizontalLength = hori; emit horizontalLengthChanged(); }}


    QGeoCoordinate centerCoord()        {return _centerCoord; }
    double centerLat()          {return _centerLat; }
    double centerLng()          {return _centerLng; }
    double verticalArea()       {return _verticalArea; }
    double horizontalArea()     {return _horizontalArea; }

    void setCenterCoord(QGeoCoordinate centerCoord) { if(centerCoord != _centerCoord) { _centerCoord = centerCoord; emit centerCoordChanged(); }}
    void setCenterLat(double lat)           { if(lat != _centerLat) { _centerLat = lat; emit centerLatChanged(); }}
    void setCenterLng(double lng)           { if(lng != _centerLng) { _centerLng = lng; emit centerLngChanged(); }}
    void setVerticalArea(double verti)      { if(verti != _verticalArea) { _verticalArea = verti; emit verticalAreaChanged(); }}
    void setHorizontalArea(double hori)     { if(hori != _horizontalArea) { _horizontalArea = hori; emit horizontalAreaChanged(); }}


    QmlObjectListModel* polygons                (void) { return &_polygons; }

    QList<QGeoCoordinate> defaultPolygonVertices(const QGeoCoordinate& centerCoord,
                                                 double pixelWidthMeters,
                                                 double pixelHeightMeters);


    void sortRectangleVertices(QList<QGeoCoordinate>& coords);

    Q_INVOKABLE void printPolygonSize();
    Q_INVOKABLE void adjustRectangleByVertex(int index, const QGeoCoordinate& newCoord);
    Q_INVOKABLE void setHorizontalSize(double size);
    Q_INVOKABLE void setVerticalSize(double size);

    Q_INVOKABLE void downloadGeoZone();

    Q_INVOKABLE void getDownloadPath(QString path);

    void sendGeoZoneRequest(double n, double e, double s, double w);
    void saveGeoZoneFile(const QJsonDocument& jsonDoc);
    void openSaveFileDialogAndSaveJson(const QJsonDocument& jsonDoc);


    Q_INVOKABLE void saveToFile(const QString& filename);
    Q_INVOKABLE void loadFromFile(const QString& filename);
    QString     fileExtension   (void) const;

    Q_PROPERTY(QString currentGeoZone READ currentGeoZone NOTIFY currentGeoZoneChanged)
    QString currentGeoZone (void) const { return _currentGeoZoneFile;}

    Q_PROPERTY(QStringList              saveNameFilters         READ saveNameFilters                        CONSTANT)
    QStringList saveNameFilters (void) const;

    Q_PROPERTY(QStringList              loadNameFilters         READ loadNameFilters                        CONSTANT)
    QStringList loadNameFilters (void) const;


private:
    QmlObjectListModel  _polygons;
    QGroundControlQmlGlobal* qGroundControlQmlGlobal;

    QGeoCoordinate _centerCoord{ 0, 0};
    double _centerLat{0};
    double _centerLng{0};
    double _verticalArea{0};
    double _horizontalArea{0};
    double _verticalLength{0};
    double _horizontalLength{0};
    QNetworkAccessManager *manager;
    SettingsManager*    _settingsManager = nullptr;
    QGCToolbox*         _toolbox = nullptr;
    QString _currentGeoZoneFile;


signals:
    void centerCoordChanged();
    void centerLatChanged();
    void centerLngChanged();
    void verticalAreaChanged();
    void horizontalAreaChanged();
    void verticalLengthChanged();
    void horizontalLengthChanged();
    void currentGeoZoneChanged(void);


private slots:
    void onReplyFinished(QNetworkReply *reply);

};




