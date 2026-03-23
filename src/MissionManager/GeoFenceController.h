/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#ifndef GeoFenceController_H
#define GeoFenceController_H

#include "PlanElementController.h"
#include "GeoFenceManager.h"
#include "QGCFencePolygon.h"
#include "QGCFenceCircle.h"
#include "Vehicle.h"
#include "MultiVehicleManager.h"
#include "QGCLoggingCategory.h"

Q_DECLARE_LOGGING_CATEGORY(GeoFenceControllerLog)

class GeoFenceManager;

class GeoFenceController : public PlanElementController
{
    Q_OBJECT
    
public:
    GeoFenceController(PlanMasterController* masterController, QObject* parent = nullptr);
    ~GeoFenceController();

    Q_PROPERTY(QmlObjectListModel*  polygons                READ polygons                                           CONSTANT)
    Q_PROPERTY(QmlObjectListModel*  circles                 READ circles                                            CONSTANT)
    Q_PROPERTY(QGeoCoordinate       breachReturnPoint       READ breachReturnPoint      WRITE setBreachReturnPoint  NOTIFY breachReturnPointChanged)
    Q_PROPERTY(Fact*                breachReturnAltitude    READ breachReturnAltitude                               CONSTANT)

    // Radius of the "paramCircularFence" which is called the "Geofence Failsafe" in PX4 and the "Circular Geofence" on ArduPilot
    Q_PROPERTY(double               paramCircularFence      READ paramCircularFence                                 NOTIFY paramCircularFenceChanged)
    Q_PROPERTY(bool                 paramCircularFenceActive READ paramCircularFenceActive                          NOTIFY paramCircularFenceChanged)
    Q_PROPERTY(bool                 cageSupported           READ cageSupported                                      NOTIFY cageSupportChanged)
    Q_PROPERTY(Fact*                cageRadius              READ cageRadius                                        NOTIFY cageParamsChanged)
    Q_PROPERTY(Fact*                cageMaxAltitude         READ cageMaxAltitude                                   NOTIFY cageParamsChanged)
    Q_PROPERTY(Fact*                cageMinAltitude         READ cageMinAltitude                                   NOTIFY cageParamsChanged)
    Q_PROPERTY(Fact*                fenceMargin             READ fenceMargin                                       NOTIFY fenceMarginChanged)
    Q_PROPERTY(double               cvMaxSpeed              READ cvMaxSpeed              WRITE setCvMaxSpeed              NOTIFY cvParamsChanged)
    Q_PROPERTY(double               cvLatency               READ cvLatency               WRITE setCvLatency               NOTIFY cvParamsChanged)
    Q_PROPERTY(double               cvManeuverTime          READ cvManeuverTime          WRITE setCvManeuverTime          NOTIFY cvParamsChanged)
    Q_PROPERTY(double               cvWindSpeed             READ cvWindSpeed             WRITE setCvWindSpeed             NOTIFY cvParamsChanged)
    Q_PROPERTY(double               cvPositionError         READ cvPositionError         WRITE setCvPositionError         NOTIFY cvParamsChanged)
    Q_PROPERTY(double               cvReactionDistance      READ cvReactionDistance                                      NOTIFY cvParamsChanged)
    Q_PROPERTY(double               cvCorrectionDistance    READ cvCorrectionDistance                                    NOTIFY cvParamsChanged)
    Q_PROPERTY(double               cvWidthMeters           READ cvWidthMeters                                           NOTIFY cvParamsChanged)
    Q_PROPERTY(bool                 fenceLoaded             READ fenceLoaded                                       NOTIFY fenceLoadedChanged)
    Q_PROPERTY(bool                 fenceActive             READ fenceActive                                       NOTIFY fenceActiveChanged)
    Q_PROPERTY(bool                 fenceParamsMissing      READ fenceParamsMissing                                NOTIFY fenceParamsMissingChanged)

    /// Add a new inclusion polygon to the fence
    ///     @param topLeft: Top left coordinate or map viewport
    ///     @param bottomRight: Bottom right left coordinate or map viewport
    Q_INVOKABLE void addInclusionPolygon(QGeoCoordinate topLeft, QGeoCoordinate bottomRight);

    /// Add a new inclusion circle to the fence
    ///     @param topLeft: Top left coordinate or map viewport
    ///     @param bottomRight: Bottom right left coordinate or map viewport
    Q_INVOKABLE void addInclusionCircle(QGeoCoordinate topLeft, QGeoCoordinate bottomRight);

    /// Deletes the specified polygon from the polygon list
    ///     @param index: Index of poygon to delete
    Q_INVOKABLE void deletePolygon(int index);

    /// Deletes the specified circle from the circle list
    ///     @param index: Index of circle to delete
    Q_INVOKABLE void deleteCircle(int index);

    /// Clears the interactive bit from all fence items
    Q_INVOKABLE void clearAllInteractive(void);
    Q_INVOKABLE QString geoFenceSelfTestReport(void) const;

    double  paramCircularFence  (void);
    bool    paramCircularFenceActive(void) const;
    Fact*   breachReturnAltitude(void) { return &_breachReturnAltitudeFact; }

    // Overrides from PlanElementController
    bool supported                  (void) const final;
    void start                      (bool flyView) final;
    void save                       (QJsonObject& json) final;
    bool load                       (const QJsonObject& json, QString& errorString) final;
    void loadFromVehicle            (void) final;
    void sendToVehicle              (void) final;
    void removeAll                  (void) final;
    void removeAllFromVehicle       (void) final;
    bool syncInProgress             (void) const final;
    bool dirty                      (void) const final;
    void setDirty                   (bool dirty) final;
    bool containsItems              (void) const final;
    bool showPlanFromManagerVehicle (void) final;

    QmlObjectListModel* polygons                (void) { return &_polygons; }
    QmlObjectListModel* circles                 (void) { return &_circles; }
    QGeoCoordinate      breachReturnPoint       (void) const { return _breachReturnPoint; }

    void setBreachReturnPoint   (const QGeoCoordinate& breachReturnPoint);
    bool isEmpty                (void) const;
    bool cageSupported          (void) const { return _cageSupported; }
    Fact* cageRadius            (void);
    Fact* cageMaxAltitude       (void);
    Fact* cageMinAltitude       (void);
    Fact* fenceMargin           (void);
    double cvMaxSpeed           (void) const { return _cvMaxSpeed; }
    double cvLatency            (void) const { return _cvLatency; }
    double cvManeuverTime       (void) const { return _cvManeuverTime; }
    double cvWindSpeed          (void) const { return _cvWindSpeed; }
    double cvPositionError      (void) const { return _cvPositionError; }
    double cvReactionDistance   (void) const { return _cvMaxSpeed * _cvLatency; }
    double cvCorrectionDistance (void) const { return (_cvMaxSpeed * _cvManeuverTime) + (_cvWindSpeed * _cvManeuverTime); }
    double cvWidthMeters        (void) const { return cvReactionDistance() + cvCorrectionDistance() + _cvPositionError; }

    void setCvMaxSpeed          (double value);
    void setCvLatency           (double value);
    void setCvManeuverTime      (double value);
    void setCvWindSpeed         (double value);
    void setCvPositionError     (double value);
    bool fenceLoaded            (void) const { return _fenceLoaded; }
    bool fenceActive            (void) const { return _fenceActive; }
    bool fenceParamsMissing     (void) const { return _fenceParamsMissing; }

signals:
    void breachReturnPointChanged       (QGeoCoordinate breachReturnPoint);
    void editorQmlChanged               (QString editorQml);
    void loadComplete                   (void);
    void paramCircularFenceChanged      (void);
    void cageSupportChanged             (bool cageSupported);
    void cageParamsChanged              (void);
    void fenceMarginChanged             (void);
    void cvParamsChanged                (void);
    void fenceLoadedChanged             (bool loaded);
    void fenceActiveChanged             (bool active);
    void fenceParamsMissingChanged      (bool missing);

private slots:
    void _polygonDirtyChanged       (bool dirty);
    void _setDirty                  (void);
    void _setFenceFromManager       (const QList<QGCFencePolygon>& polygons, const QList<QGCFenceCircle>&  circles);
    void _setReturnPointFromManager (QGeoCoordinate breachReturnPoint);
    void _managerLoadComplete       (void);
    void _updateContainsItems       (void);
    void _managerSendComplete       (bool error);
    void _managerRemoveAllComplete  (bool error);
    void _parametersReady           (void);
    void _managerVehicleChanged      (Vehicle* managerVehicle);
    void _updateFenceActiveState     (void);
    void _updateFenceParamsMissing   (void);

private:
    void _init(void);

    Vehicle*            _managerVehicle =               nullptr;
    GeoFenceManager*    _geoFenceManager =              nullptr;
    bool                _dirty =                        false;
    QmlObjectListModel  _polygons;
    QmlObjectListModel  _circles;
    QGeoCoordinate      _breachReturnPoint;
    Fact                _breachReturnAltitudeFact;
    double              _breachReturnDefaultAltitude =  qQNaN();
    bool                _itemsRequested =               false;
    bool                _cageSupported =                false;
    bool                _fenceLoaded =                  false;
    bool                _fenceActive =                  false;
    bool                _fenceParamsMissing =           false;

    Fact*               _px4ParamCircularFenceFact =        nullptr;
    Fact*               _apmParamCircularFenceRadiusFact =  nullptr;
    Fact*               _apmParamCircularFenceEnabledFact = nullptr;
    Fact*               _apmParamCircularFenceTypeFact =    nullptr;
    Fact*               _px4ParamVerticalFenceFact =        nullptr;
    Fact*               _apmParamFenceAltMaxFact =          nullptr;
    Fact*               _apmParamFenceAltMinFact =          nullptr;
    Fact*               _apmParamFenceMarginFact =          nullptr;

    static QMap<QString, FactMetaData*> _metaDataMap;

    static const char* _px4ParamCircularFence;
    static const char* _apmParamCircularFenceRadius;
    static const char* _apmParamCircularFenceEnabled;
    static const char* _apmParamCircularFenceType;
    static const char* _px4ParamVerticalFence;
    static const char* _apmParamFenceAltMax;
    static const char* _apmParamFenceAltMin;
    static const char* _apmParamFenceMargin;

    static const int _jsonCurrentVersion = 2;

    static const char* _jsonFileTypeValue;
    static const char* _jsonBreachReturnKey;
    static const char* _jsonPolygonsKey;
    static const char* _jsonCirclesKey;

    static const char* _breachReturnAltitudeFactName;

    void _loadCvSettings(void);
    void _saveCvSettings(void);

    double _cvMaxSpeed = 15.0;
    double _cvLatency = 1.0;
    double _cvManeuverTime = 3.0;
    double _cvWindSpeed = 0.0;
    double _cvPositionError = 10.0;
};

#endif
