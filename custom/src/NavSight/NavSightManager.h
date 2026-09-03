#pragma once

#include "QGCToolbox.h"

class Vehicle;

/// QGC-side backend contract for NavSight GCS control and status UI.
class NavSightManager : public QGCTool
{
    Q_OBJECT

public:
    static constexpr int kDefaultSystemId = 10;
    static constexpr int kDefaultComponentId = 192;

    explicit NavSightManager(QGCApplication* app, QGCToolbox* toolbox);

    Q_PROPERTY(bool     navSightOnline                 READ navSightOnline                 NOTIFY navSightStatusChanged)
    Q_PROPERTY(double   navSightConfidence             READ navSightConfidence             NOTIFY navSightStatusChanged)
    Q_PROPERTY(bool     navSightConfidenceValid        READ navSightConfidenceValid        NOTIFY navSightStatusChanged)
    Q_PROPERTY(QString  navSightStatusText             READ navSightStatusText             NOTIFY navSightStatusChanged)
    Q_PROPERTY(quint32  navSightStatusBitmask          READ navSightStatusBitmask          NOTIFY navSightStatusChanged)
    Q_PROPERTY(bool     navSightDeadReckoningActive    READ navSightDeadReckoningActive    NOTIFY navSightStatusChanged)
    Q_PROPERTY(bool     navSightGpsActive              READ navSightGpsActive              NOTIFY navSightStatusChanged)
    Q_PROPERTY(bool     navSightVisualNavigationActive READ navSightVisualNavigationActive NOTIFY navSightStatusChanged)
    Q_PROPERTY(QString  navSightLocationSource         READ navSightLocationSource         NOTIFY navSightStatusChanged)
    Q_PROPERTY(bool     updateLocationInProgress       READ updateLocationInProgress       NOTIFY updateLocationStateChanged)
    Q_PROPERTY(QString  lastUpdateLocationResult       READ lastUpdateLocationResult       NOTIFY updateLocationStateChanged)
    Q_PROPERTY(int      targetSystemId                 READ targetSystemId                 CONSTANT)
    Q_PROPERTY(int      targetComponentId              READ targetComponentId              CONSTANT)

    bool navSightOnline() const { return _navSightOnline; }
    double navSightConfidence() const { return _navSightConfidence; }
    bool navSightConfidenceValid() const { return _navSightConfidenceValid; }
    QString navSightStatusText() const { return _navSightStatusText; }
    quint32 navSightStatusBitmask() const { return _navSightStatusBitmask; }
    bool navSightDeadReckoningActive() const { return _navSightDeadReckoningActive; }
    bool navSightGpsActive() const { return _navSightGpsActive; }
    bool navSightVisualNavigationActive() const { return _navSightVisualNavigationActive; }
    QString navSightLocationSource() const { return _navSightLocationSource; }
    bool updateLocationInProgress() const { return _updateLocationInProgress; }
    QString lastUpdateLocationResult() const { return _lastUpdateLocationResult; }
    int targetSystemId() const { return kDefaultSystemId; }
    int targetComponentId() const { return kDefaultComponentId; }

    Q_INVOKABLE bool sendUpdateLocation(double latitude, double longitude);

    void setToolbox(QGCToolbox* toolbox) override;

signals:
    void navSightStatusChanged();
    void updateLocationStateChanged();
    void updateLocationSent(double latitude, double longitude);

private slots:
    void _setActiveVehicle(Vehicle* vehicle);

private:
    void _setUpdateLocationResult(const QString& result);

    // Temporary UI values for Task-3/4 review. Heartbeat/status decoding will
    // replace them and make NavSight offline until a heartbeat is received.
    bool    _navSightOnline{true};
    double  _navSightConfidence{0.0};
    bool    _navSightConfidenceValid{true};
    QString _navSightStatusText{QStringLiteral("WAITING_FOR_START_MISSION")};
    quint32 _navSightStatusBitmask{0};
    bool    _navSightDeadReckoningActive{false};
    bool    _navSightGpsActive{true};
    bool    _navSightVisualNavigationActive{true};
    QString _navSightLocationSource{QStringLiteral("N/A")};
    bool    _updateLocationInProgress{false};
    QString _lastUpdateLocationResult;
    Vehicle* _vehicle{nullptr};
};