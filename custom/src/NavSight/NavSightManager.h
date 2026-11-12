#pragma once

#include "QGCMAVLink.h"
#include "QGCToolbox.h"

#include <QByteArray>
#include <QBitArray>
#include <QElapsedTimer>
#include <QGeoCoordinate>
#include <QMap>
#include <QMetaObject>
#include <QPointer>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVector>

class Vehicle;
class LinkInterface;

/// QGC-side backend contract for NavSight GCS control and status UI.
class NavSightManager : public QGCTool
{
    Q_OBJECT

public:
    static constexpr int kDefaultSystemId = 10;
    static constexpr int kDefaultComponentId = 192;

    enum NavSightStatusSeverity {
        NavSightStatusSeverityNone = 0,
        NavSightStatusSeverityWarning,
        NavSightStatusSeverityCritical,
        NavSightStatusSeverityNormal,
    };
    Q_ENUM(NavSightStatusSeverity)

    enum NavSightOutputState {
        NavSightOutputStateUnknown = 0,
        NavSightOutputStateEnabled,
        NavSightOutputStateDisabled,
    };
    Q_ENUM(NavSightOutputState)

    explicit NavSightManager(QGCApplication* app, QGCToolbox* toolbox);

    Q_PROPERTY(bool     navSightOnline                 READ navSightOnline                 NOTIFY navSightStatusChanged)
    Q_PROPERTY(double   navSightConfidence             READ navSightConfidence             NOTIFY navSightStatusChanged)
    Q_PROPERTY(bool     navSightConfidenceValid        READ navSightConfidenceValid        NOTIFY navSightStatusChanged)
    Q_PROPERTY(QString  navSightStatusText             READ navSightStatusText             NOTIFY navSightStatusChanged)
    Q_PROPERTY(QStringList navSightActiveStatuses      READ navSightActiveStatuses         NOTIFY navSightStatusChanged)
    Q_PROPERTY(QString  navSightDiagnosticText         READ navSightDiagnosticText         NOTIFY navSightStatusChanged)
    Q_PROPERTY(quint32  navSightStatusBitmask          READ navSightStatusBitmask          NOTIFY navSightStatusChanged)
    Q_PROPERTY(int      navSightStatusSeverity         READ navSightStatusSeverity         NOTIFY navSightStatusChanged)
    Q_PROPERTY(bool     navSightDeadReckoningActive    READ navSightDeadReckoningActive    NOTIFY navSightStatusChanged)
    Q_PROPERTY(bool     navSightGpsActive              READ navSightGpsActive              NOTIFY navSightStatusChanged)
    Q_PROPERTY(bool     navSightVisualNavigationActive READ navSightVisualNavigationActive NOTIFY navSightStatusChanged)
    Q_PROPERTY(QString  navSightLocationSource         READ navSightLocationSource         NOTIFY navSightStatusChanged)
    Q_PROPERTY(bool     initialLocationAccepted      READ initialLocationAccepted      NOTIFY navSightStatusChanged)
    Q_PROPERTY(bool     updateLocationInProgress       READ updateLocationInProgress       NOTIFY updateLocationStateChanged)
    Q_PROPERTY(QString  lastUpdateLocationResult       READ lastUpdateLocationResult       NOTIFY updateLocationStateChanged)
    Q_PROPERTY(int      navSightOutputState            READ navSightOutputState            NOTIFY outputSignalCommandStateChanged)
    Q_PROPERTY(bool     outputSignalCommandInProgress  READ outputSignalCommandInProgress  NOTIFY outputSignalCommandStateChanged)
    Q_PROPERTY(QString  lastOutputSignalResult         READ lastOutputSignalResult         NOTIFY outputSignalCommandStateChanged)
    Q_PROPERTY(int      activeEkfSourceSet             READ activeEkfSourceSet             NOTIFY ekfSourceStateChanged)
    Q_PROPERTY(bool     ekfSourceChangeInProgress      READ ekfSourceChangeInProgress      NOTIFY ekfSourceStateChanged)
    // NavSight defaults to sysid 10, but the unit may be configured to use
    // another system id (including the vehicle's sysid). The address is
    // learned from its component-192 heartbeat on the active vehicle link.
    Q_PROPERTY(int      targetSystemId                 READ targetSystemId                 NOTIFY navSightAddressChanged)
    Q_PROPERTY(bool     visualNavigationSourceConfigured READ visualNavigationSourceConfigured NOTIFY externalNavConfigurationChanged)
    Q_PROPERTY(bool     deadReckoningSourceConfigured     READ deadReckoningSourceConfigured     NOTIFY externalNavConfigurationChanged)
    // Raw physical-GPS samples captured only while FC source set 2 (VIS) is
    // active. This is a comparison overlay, not the vehicle's primary path.
    Q_PROPERTY(QVariantList gpsComparisonTrajectory READ gpsComparisonTrajectory NOTIFY gpsComparisonTrajectoryChanged)
    Q_PROPERTY(int      targetComponentId              READ targetComponentId              CONSTANT)

    bool navSightOnline() const { return _navSightOnline; }
    double navSightConfidence() const { return _navSightConfidence; }
    bool navSightConfidenceValid() const { return _navSightConfidenceValid; }
    QString navSightStatusText() const { return _navSightStatusText; }
    QStringList navSightActiveStatuses() const { return _navSightActiveStatuses; }
    QString navSightDiagnosticText() const { return _navSightDiagnosticText; }
    quint32 navSightStatusBitmask() const { return _navSightStatusBitmask; }
    int navSightStatusSeverity() const { return _navSightStatusSeverity; }
    bool navSightDeadReckoningActive() const { return _navSightDeadReckoningActive; }
    bool navSightGpsActive() const { return _navSightGpsActive; }
    bool navSightVisualNavigationActive() const { return _navSightVisualNavigationActive; }
    QString navSightLocationSource() const { return _navSightLocationSource; }
    bool initialLocationAccepted() const { return _initialLocationAccepted; }
    bool updateLocationInProgress() const { return _updateLocationInProgress; }
    QString lastUpdateLocationResult() const { return _lastUpdateLocationResult; }
    int navSightOutputState() const { return _navSightOutputState; }
    bool outputSignalCommandInProgress() const { return _outputSignalCommandInProgress; }
    QString lastOutputSignalResult() const { return _lastOutputSignalResult; }
    int activeEkfSourceSet() const { return _activeEkfSourceSet; }
    bool ekfSourceChangeInProgress() const { return _ekfSourceChangeInProgress; }
    int targetSystemId() const { return _navSightSystemId; }
    bool visualNavigationSourceConfigured() const { return _visualNavigationSourceConfigured; }
    bool deadReckoningSourceConfigured() const { return _deadReckoningSourceConfigured; }
    QVariantList gpsComparisonTrajectory() const { return _gpsComparisonTrajectory; }
    int targetComponentId() const { return kDefaultComponentId; }

    Q_INVOKABLE bool sendUpdateLocation(double latitude, double longitude);
    Q_INVOKABLE bool setEkfSourceSet(int sourceSet);
    /// Enables/disables NavSight visual-navigation output to the Flight Controller.
    /// This is a level command: true sends param1=0 (resume), false sends param1=1 (stop).
    Q_INVOKABLE bool setNavSightOutputEnabled(bool enabled);

    void setToolbox(QGCToolbox* toolbox) override;

signals:
    void navSightStatusChanged();
    void updateLocationStateChanged();
    void ekfSourceStateChanged();
    void outputSignalCommandStateChanged();
    void updateLocationSent(double latitude, double longitude);
    void externalNavConfigurationChanged();
    void navSightAddressChanged();
    void gpsComparisonTrajectoryChanged();

private slots:
    void _setActiveVehicle(Vehicle* vehicle);
    void _mavlinkMessageReceived(const mavlink_message_t& message);
    void _rawMavlinkMessageReceived(LinkInterface* link, mavlink_message_t message);
    void _checkHeartbeatTimeout();
    void _updateLocationAckTimeout();
    void _ekfSourceAckTimeout();
    void _outputSignalCommandTimeout();
    void _schemaFtpTimeout();
    void _schemaRetryTimeout();

private:
    void _setOffline();
    void _setNavSightSystemId(int systemId);
    void _setUpdateLocationResult(const QString& result);
    bool _queuePendingUpdateLocation();
    void _finishUpdateLocation(const QString& result);
    void _finishEkfSourceSet();
    bool _queuePendingOutputSignalCommand();
    void _finishOutputSignalCommand(const QString& result);
    void _setOutputSignalResult(const QString& result);
    void _updateOutputStateFromData64();
    void _handleNavSightMessage(const mavlink_message_t& message);
    void _handleSchemaFtpMessage(const mavlink_message_t& message);
    void _resetStatusSchemaState();
    void _startStatusSchemaDownload();
    void _sendSchemaFtpRequest(uint8_t opcode, uint8_t session, uint32_t offset, uint8_t size, const QByteArray& data = QByteArray());
    void _handleSchemaFtpFailure(const QString& error);
    void _finishStatusSchemaDownload();
    bool _parseStatusSchema(const QByteArray& json, QString* error);
    void _applyStatusText(const QString& text);
    void _applyData64Status(const mavlink_data64_t& data64);
    void _checkStatusTimeout();
    void _refreshExternalNavPositionSourceConfigured();
    void _disconnectExternalNavFactSignals();
    void _appendGpsComparisonPoint(const mavlink_gps_raw_int_t& gpsRawInt);
    void _clearGpsComparisonTrajectory();
    static QString _ekfSourceSetName(int sourceSet);
    static QString _mavlinkString(const char* text, int textLength);
    static quint32 _lowStatusWord(const QByteArray& statusBytes);
    static NavSightStatusSeverity _statusSeverity(const QStringList& statusNames);

    enum class NavSightStatusSource {
        None,
        StatusText,
        Data64,
    };

    enum class SchemaFtpState {
        Idle,
        Opening,
        Bursting,
        Reading,
        Terminating,
    };

    struct NavSightStatusSchema {
        bool valid{false};
        uint8_t data64Type{0};
        int payloadLength{16};
        int bitCount{128};
        QMap<int, QString> flags;
    };

    bool    _navSightOnline{false};
    double  _navSightConfidence{0.0};
    bool    _navSightConfidenceValid{false};
    QString _navSightStatusText;
    QStringList _navSightActiveStatuses;
    QString _navSightDiagnosticText;
    quint32 _navSightStatusBitmask{0};
    bool    _hasData64Status{false};
    NavSightStatusSource _navSightStatusSource{NavSightStatusSource::None};
    bool    _statusTextFallbackActive{true};
    NavSightStatusSeverity _navSightStatusSeverity{NavSightStatusSeverityNone};
    bool    _navSightDeadReckoningActive{false};
    bool    _navSightGpsActive{false};
    bool    _navSightVisualNavigationActive{false};
    QString _navSightLocationSource{QStringLiteral("N/A")};
    bool    _initialLocationAccepted{false};
    bool    _updateLocationInProgress{false};
    QString _lastUpdateLocationResult;
    double  _pendingLatitude{0.0};
    double  _pendingLongitude{0.0};
    int     _updateLocationRetryCount{0};
    NavSightOutputState _navSightOutputState{NavSightOutputStateUnknown};
    bool    _outputSignalCommandInProgress{false};
    bool    _outputSignalAckReceived{false};
    bool    _requestedOutputEnabled{true};
    int     _outputSignalRetryCount{0};
    QString _lastOutputSignalResult;
    int     _activeEkfSourceSet{0};
    int     _pendingEkfSourceSet{0};
    bool    _ekfSourceChangeInProgress{false};
    bool    _visualNavigationSourceConfigured{false};
    bool    _deadReckoningSourceConfigured{false};
    QMetaObject::Connection _externalNavParametersReadyConnection;
    QMetaObject::Connection _vehicleArmedConnection;
    QMetaObject::Connection _navSightFeatureSettingConnection;
    QMetaObject::Connection _gpsComparisonSettingConnection;
    QVector<QMetaObject::Connection> _externalNavFactConnections;
    Vehicle* _vehicle{nullptr};
    int _navSightSystemId{0}; // Unknown until a component-192 HEARTBEAT is received.
    QPointer<LinkInterface> _navSightLink;
    QElapsedTimer _lastHeartbeatTimer;
    QElapsedTimer _lastStatusTimer;
    quint64 _lastVisionPositionEstimateUsec{0};
    QVariantList _gpsComparisonTrajectory;
    QGeoCoordinate _lastGpsComparisonPoint;
    double _lastGpsComparisonAzimuth{0.0};
    bool _gpsComparisonAzimuthValid{false};
    QTimer _heartbeatWatchdog;
    QTimer _updateLocationAckTimer;
    QTimer _ekfSourceAckTimer;
    QTimer _outputSignalCommandTimer;
    QTimer _schemaFtpTimer;
    QTimer _schemaRetryTimer;

    NavSightStatusSchema _statusSchema;
    SchemaFtpState _schemaFtpState{SchemaFtpState::Idle};
    QByteArray _schemaDownloadData;
    QBitArray _schemaDownloadReceived;
    uint32_t _schemaReadOffset{0};
    uint8_t _schemaFtpSession{0};
    uint16_t _schemaExpectedSequence{0};
    int _schemaRetryCount{0};
    bool _schemaRequested{false};
    bool _schemaRejected{false};

    static constexpr int kHeartbeatTimeoutMs = 3000;
    static constexpr int kStatusStaleTimeoutMs = 10000;
    static constexpr int kSchemaFtpTimeoutMs = 5000;
    static constexpr int kSchemaRetryDelayMs = 2000;
    static constexpr int kMaxSchemaRetries = 3;
    static constexpr int kMaxSchemaSizeBytes = 64 * 1024;
    static constexpr uint8_t kFtpPayloadSize = 239;
    static constexpr uint8_t kFtpOpenFileRO = 4;
    static constexpr uint8_t kFtpReadFile = 5;
    static constexpr uint8_t kFtpTerminateSession = 1;
    static constexpr uint8_t kFtpBurstReadFile = 15;
    static constexpr uint8_t kFtpAck = 128;
    static constexpr uint8_t kFtpNak = 129;
    static constexpr uint8_t kFtpErrUnknownCommand = 7;
    static constexpr int kUpdateLocationAckTimeoutMs = 3000;
    static constexpr int kMaxUpdateLocationRetries = 2;
    static constexpr int kEkfSourceAckTimeoutMs = 3000;
    static constexpr int kOutputSignalCommandTimeoutMs = 3000;
    static constexpr int kMaxOutputSignalRetries = 2;
    static constexpr uint16_t kUpdateLocationCommand = 44444;
    static constexpr uint16_t kToggleOutputSignalCommand = 44445;
    // NavSight ICD/sequence uses 5; standard MAVLink uses 1 for this result.
    static constexpr uint8_t kNavSightTemporaryRejectedResult = 5;
};
