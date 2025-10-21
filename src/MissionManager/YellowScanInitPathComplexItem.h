/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include "TransectStyleComplexItem.h"
#include "MissionItem.h"
#include "SettingsFact.h"
#include "QGCLoggingCategory.h"
#include "QGCMapPolyline.h"
#include "QGCMapPolygon.h"
#include "SpeedSection.h"

using namespace std;

Q_DECLARE_LOGGING_CATEGORY(YellowScanInitPathLog)

class YellowScanInitPathComplexItem : public TransectStyleComplexItem
{
    Q_OBJECT

public:
    /// @param flyView true: Created for use in the Fly View, false: Created for use in the Plan View
    /// @param kmlFile Polyline comes from this file, empty for default polyline
    YellowScanInitPathComplexItem(PlanMasterController* masterController, bool flyView, const QString& kmlFile);

    Q_PROPERTY(QGCMapPolyline*  corridorPolyline    READ corridorPolyline   CONSTANT)
    Q_PROPERTY(Fact*            corridorWidth       READ corridorWidth      CONSTANT)
    Q_PROPERTY(Fact*            angle               READ angle              CONSTANT)
    Q_PROPERTY(Fact*            turnRadius          READ turnRadius         CONSTANT)
    Q_PROPERTY(QObject*         speedSection        READ speedSection       CONSTANT)

    Fact*           corridorWidth   (void) { return &_corridorWidthFact; }
    Fact*           angle           (void) { return &_angleFact; }
    Fact*           turnRadius      (void) { return &_turnRadiusFact; }
    SpeedSection*   speedSection                (void) { return &_speedSection; }

    QGCMapPolyline* corridorPolyline(void) { return &_corridorPolyline; }

    Q_INVOKABLE void rotateEntryPoint(void);

    // Overrides from TransectStyleComplexItem
    QString patternName         (void) const final { return name; }
    void    save                (QJsonArray&  planItems) final;
    bool    specifiesCoordinate (void) const final;
    double  timeBetweenShots    (void) final;

    // Overrides from ComplexMissionItem
    bool    load                (const QJsonObject& complexObject, int sequenceNumber, QString& errorString) final;
    QString mapVisualQML        (void) const final { return QStringLiteral("YellowScanInitPathMapVisual.qml"); }
    QString presetsSettingsGroup(void) { return settingsGroup; }
    void    savePreset          (const QString& name);
    void    loadPreset          (const QString& name);

    // Overrides from VisualMissionionItem
    QString             commandDescription  (void) const final { return tr("YS Init Path"); }
    QString             commandName         (void) const final { return tr("YS Init Path"); }
    QString             abbreviation        (void) const final { return tr("C"); }
    ReadyForSaveState   readyForSaveState   (void) const final;
    double              additionalTimeDelay (void) const final { return 0; }

    static const QString name;

    static const char* jsonComplexItemTypeValue;

    static const char* settingsGroup;
    static const char* corridorWidthName;

    static const char* angleName;
    static const char* turnRadiusName;

    vector<pair<double,double>> generate_semicircle_from_origin(double lat_origin, double lon_origin,
                                                                 double radius_m, int num_points, double theta_deg);

private slots:
    void _polylineDirtyChanged          (bool dirty);
    void _rebuildCorridorPolygon        (void);
    void _updateWizardMode              (void);

    // Overrides from TransectStyleComplexItem
    void _rebuildTransectsPhase1    (void) final;
    void _recalcCameraShots         (void) final;

private:
    double  _calcTransectSpacing    (void) const;
    int     _calcTransectCount      (void) const;
    void    _saveCommon             (QJsonObject& complexObject);
    bool    _loadWorker              (const QJsonObject& complexObject, int sequenceNumber, QString& errorString, bool forPresets);

    QGCMapPolyline                  _corridorPolyline;
    QList<QList<QGeoCoordinate>>    _transectSegments;      ///< Internal transect segments including grid exit, turnaround and internal camera points

    int                             _entryPoint;

    QMap<QString, FactMetaData*>    _metaDataMap;
    SettingsFact                    _corridorWidthFact;
    SettingsFact                    _angleFact;
    SettingsFact                    _turnRadiusFact;
    SpeedSection                    _speedSection;

    static const char* _jsonEntryPointKey;
};
