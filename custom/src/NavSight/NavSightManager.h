#pragma once

#include "QGCMAVLink.h"
#include "QGCToolbox.h"

#include <QElapsedTimer>
#include <QTimer>

class Vehicle;

/// QGC-side backend contract for NavSight GCS control and status UI.
class NavSightManager : public QGCTool
{
    Q_OBJECT

public:
    static constexpr int kDefaultSystemId = 10;
    static constexpr int kDefaultComponentId = 192;
    // Set true only for UI-only preview without a NavSight device.
    static constexpr bool kUiPreviewEnabled = true;

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
    Q_PROPERTY(bool     initialLocationAccepted      READ initialLocationAccepted      NOTIFY navSightStatusChanged)
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
    bool initialLocationAccepted() const { return _initialLocationAccepted; }
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
    void _mavlinkMessageReceived(const mavlink_message_t& message);
    void _checkHeartbeatTimeout();
    void _updateLocationAckTimeout();

private:
    void _setOffline();
    void _setUpdateLocationResult(const QString& result);
    bool _queuePendingUpdateLocation();
    void _finishUpdateLocation(const QString& result);
    static QString _mavlinkString(const char* text, int textLength);

    bool    _navSightOnline{kUiPreviewEnabled};
    double  _navSightConfidence{kUiPreviewEnabled ? 3.2 : 0.0};
    bool    _navSightConfidenceValid{kUiPreviewEnabled};
    QString _navSightStatusText{kUiPreviewEnabled ? QStringLiteral("WAITING_FOR_START_MISSION") : QString()};
    quint32 _navSightStatusBitmask{0};
    bool    _navSightDeadReckoningActive{false};
    bool    _navSightGpsActive{kUiPreviewEnabled};
    bool    _navSightVisualNavigationActive{kUiPreviewEnabled};
    QString _navSightLocationSource{kUiPreviewEnabled ? QStringLiteral("GPS") : QStringLiteral("N/A")};
    bool    _initialLocationAccepted{false};
    bool    _updateLocationInProgress{false};
    QString _lastUpdateLocationResult;
    double  _pendingLatitude{0.0};
    double  _pendingLongitude{0.0};
    int     _updateLocationRetryCount{0};
    Vehicle* _vehicle{nullptr};
    QElapsedTimer _lastHeartbeatTimer;
    QTimer _heartbeatWatchdog;
    QTimer _updateLocationAckTimer;

    static constexpr int kHeartbeatTimeoutMs = 3000;
    static constexpr quint32 kWaitingForStartMissionMask = 0x00001000u;
    static constexpr int kUpdateLocationAckTimeoutMs = 3000;
    static constexpr int kMaxUpdateLocationRetries = 2;
    // NavSight ICD/sequence uses 5; standard MAVLink uses 1 for this result.
    static constexpr uint8_t kNavSightTemporaryRejectedResult = 5;
};