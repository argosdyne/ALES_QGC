#pragma once

#include <QObject>
#include <QHostAddress>
#include <QUdpSocket>
#include <QTimer>
#include <QVariantMap>
#include <QPointer>
class Vehicle;

// SAFE-T Extended V1 UDP client. The control frame is sent at 5 Hz to keep
// remote authority alive; monitoring frames are decoded into QML properties.
class ElistairStationManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString stationAddress READ stationAddress WRITE setStationAddress NOTIFY connectionSettingsChanged)
    Q_PROPERTY(int stationPort READ stationPort WRITE setStationPort NOTIFY connectionSettingsChanged)
    Q_PROPERTY(QString frameVersion READ frameVersion WRITE setFrameVersion NOTIFY connectionSettingsChanged)
    Q_PROPERTY(QString activeFrameVersion READ activeFrameVersion NOTIFY connectionSettingsChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(bool noReply READ noReply NOTIFY connectedChanged)
    Q_PROPERTY(bool linkLost READ linkLost NOTIFY connectedChanged)
    Q_PROPERTY(bool hasMonitoring READ hasMonitoring NOTIFY connectionStatusChanged)
    Q_PROPERTY(int reconnectAttempt READ reconnectAttempt NOTIFY connectionStatusChanged)
    Q_PROPERTY(QString lastMonitoringTime READ lastMonitoringTime NOTIFY connectionStatusChanged)
    Q_PROPERTY(bool powerRemote READ powerRemote NOTIFY controlChanged)
    Q_PROPERTY(bool powerOn READ powerOn NOTIFY controlChanged)
    Q_PROPERTY(bool powerOffPending READ powerOffPending NOTIFY controlChanged)
    Q_PROPERTY(qulonglong powerOffRequestId READ powerOffRequestId NOTIFY controlChanged)
    Q_PROPERTY(bool powerOffRequiresConfirmation READ powerOffRequiresConfirmation NOTIFY flightStateChanged)
    Q_PROPERTY(bool torqueRemote READ torqueRemote NOTIFY controlChanged)
    Q_PROPERTY(int torquePercent READ torquePercent NOTIFY controlChanged)
    Q_PROPERTY(int powerWatts READ powerWatts NOTIFY telemetryChanged)
    Q_PROPERTY(double cableLength READ cableLength NOTIFY telemetryChanged)
    Q_PROPERTY(double cableSpeed READ cableSpeed NOTIFY telemetryChanged)
    Q_PROPERTY(int spoolTemperature READ spoolTemperature NOTIFY telemetryChanged)
    Q_PROPERTY(double voltage READ voltage NOTIFY telemetryChanged)
    Q_PROPERTY(double current READ current NOTIFY telemetryChanged)
    Q_PROPERTY(int appliedTorquePercent READ appliedTorquePercent NOTIFY telemetryChanged)
    Q_PROPERTY(QString alarmSummary READ alarmSummary NOTIFY telemetryChanged)
    Q_PROPERTY(bool noPower READ noPower NOTIFY noPowerChanged)
    Q_PROPERTY(bool noPowerPrompt READ noPowerPrompt NOTIFY noPowerChanged)
    Q_PROPERTY(int noPowerFailsafe READ noPowerFailsafe WRITE setNoPowerFailsafe NOTIFY noPowerChanged)
    Q_PROPERTY(qulonglong noPowerIncident READ noPowerIncident NOTIFY noPowerChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(QVariantMap stationSettings READ stationSettings NOTIFY stationSettingsChanged)
    Q_PROPERTY(bool settingsBusy READ settingsBusy NOTIFY settingsTransactionChanged)
    Q_PROPERTY(QString settingsResult READ settingsResult NOTIFY settingsTransactionChanged)
    Q_PROPERTY(QString settingsReadTime READ settingsReadTime NOTIFY stationSettingsChanged)

public:
    explicit ElistairStationManager(QObject* parent = nullptr);

    QString stationAddress() const { return _stationAddress; }
    int stationPort() const { return _stationPort; }
    QString frameVersion() const;
    QString activeFrameVersion() const;
    bool connected() const { return _connected; }
    bool noReply() const { return _noReply; }
    bool linkLost() const { return _linkLost; }
    bool hasMonitoring() const { return _hasMonitoring; }
    int reconnectAttempt() const { return _reconnectAttempt; }
    QString lastMonitoringTime() const { return _lastMonitoringTime; }
    bool powerRemote() const { return _powerRemote; }
    bool powerOn() const { return _powerOn; }
    bool torqueRemote() const { return _torqueRemote; }
    int torquePercent() const { return _torquePercent; }
    int powerWatts() const { return _powerWatts; }
    double cableLength() const { return _cableLength; }
    double cableSpeed() const { return _cableSpeed; }
    int spoolTemperature() const { return _spoolTemperature; }
    double voltage() const { return _voltage; }
    double current() const { return _current; }
    int appliedTorquePercent() const { return _appliedTorquePercent; }
    QString alarmSummary() const { return _alarmSummary; }
    bool noPower() const { return _noPower; }
    bool noPowerPrompt() const { return _noPower && !_noPowerDismissed && _noPowerFailsafe == 0; }
    int noPowerFailsafe() const { return _noPowerFailsafe; } // Recommend, Warn only, Auto land
    qulonglong noPowerIncident() const { return _noPowerIncident; }
    void setNoPowerFailsafe(int value);
    Q_INVOKABLE void dismissNoPower();
    Q_INVOKABLE void requestNoPowerAction(bool rtl);
    Q_INVOKABLE bool executeNoPowerAction(qulonglong incident, bool rtl);
    QString lastError() const { return _lastError; }
    QVariantMap stationSettings() const { return _stationSettings; }
    bool settingsBusy() const { return _configOperation != 0; }
    QString settingsResult() const { return _settingsResult; }
    QString settingsReadTime() const { return _settingsReadTime; }

    void setStationAddress(const QString& address);
    void setStationPort(int port);
    void setFrameVersion(const QString& version);
    bool powerOffPending() const { return _powerOffPending; }
    qulonglong powerOffRequestId() const { return _powerOffRequestId; }
    bool powerOffRequiresConfirmation() const;

    Q_INVOKABLE void connectStation();
    Q_INVOKABLE void disconnectStation();
    Q_INVOKABLE void setPowerRemote(bool remote);
    Q_INVOKABLE void setPowerOn(bool on);
    Q_INVOKABLE bool confirmPowerOff(qulonglong requestId);
    Q_INVOKABLE void cancelPowerOff();
    Q_INVOKABLE void setTorqueRemote(bool remote);
    Q_INVOKABLE void setTorquePercent(int percent);
    Q_INVOKABLE void readSettings();
    Q_INVOKABLE bool writeSettings(const QVariantMap& values);

signals:
    void connectionSettingsChanged();
    void connectedChanged();
    void controlChanged();
    void telemetryChanged();
    void lastErrorChanged();
    void connectionStatusChanged();
    void stationSettingsChanged();
    void settingsTransactionChanged();
    void powerOffConfirmationRequested();
    void flightStateChanged();
    void noPowerChanged();
    void noPowerActionRequested(bool rtl, qulonglong incident);

private slots:
    void _sendControl();
    void _readDatagrams();
    void _checkTimeout();

private:
    static quint8 _crc8(const QByteArray& data);
    void _setError(const QString& error);
    void _setConnected(bool connected);
    bool _decodeMonitoring(const QByteArray& frame);
    static quint16 _u16be(const QByteArray& data, int offset);
    static quint16 _u16le(const QByteArray& data, int offset);
    void _setActiveFrameVersion(int version);
    void _publishTelemetry();
    void _logAlarmTransition();
    void _logPowerSession();
    void _logStationFlightTime();
    void _showLinkLostMessage();
    QString _settingsInterlockReason() const;
    bool _decodeConfiguration(const QByteArray& frame);
    void _requestConfigRead(int operation);
    void _applyPowerOn(bool on);
    bool _canControlPower() const;
    void _bindFlightVehicle();
    void _updateNoPower(int integrity);
    void _announceNoPower();
    bool _noPower = false, _noPowerDismissed = false, _noPowerActionSent = false;
    int _noPowerFailsafe = 0, _decodedIntegrity = -1;
    qulonglong _noPowerIncident = 0;
    QPointer<Vehicle> _noPowerVehicle;
    QTimer _noPowerAlarmTimer;
    bool _powerOffPending = false;
    bool _powerCommandKnown = false;
    qulonglong _powerOffRequestId = 0;
    QMetaObject::Connection _armedConnection, _flyingConnection, _vehicleLinkConnection;

    QUdpSocket _socket;
    QTimer _controlTimer;
    QTimer _timeoutTimer;
    QTimer _settingsReconnectTimer;
    QTimer _configTimer;
    QByteArray _configSnapshot;
    QVariantMap _stationSettings;
    QString _settingsResult, _settingsReadTime;
    int _configOperation = 0; // 1: read, 2: write, 3: verify after successful write
    QString _stationAddress;
    int _stationPort = 7158;
    int _configuredFrameVersion = 0; // Auto, Extended V1, Extended V0, Standard
    int _activeFrameVersion = 1;
    int _autoAttempt = 0;
    qint64 _lastAutoProbeMsecs = 0;
    qint64 _lastMonitoringMsecs = 0;
    qint64 _lastReconnectAttemptMsecs = 0;
    QString _lastMonitoringTime;
    int _reconnectAttempt = 0;
    bool _connected = false;
    bool _hasMonitoring = false;
    bool _noReply = true;
    bool _linkLost = false;
    bool _powerRemote = false;
    bool _powerOn = false;
    bool _torqueRemote = false;
    int _torquePercent = 50;
    int _powerWatts = 0;
    double _cableLength = 0;
    double _tetherRemaining = qQNaN();
    double _cableSpeed = 0;
    int _spoolTemperature = 0;
    double _voltage = 0;
    double _current = 0;
    int _appliedTorquePercent = 0;
    QString _alarmSummary = QStringLiteral("No alarms");
    QString _lastError;
    QString _lastLoggedAlarmSummary;
    qint64 _powerOnSinceMsecs = 0;
    int _stationFlightTimeSeconds = -1;
    int _lastLoggedStationFlightTimeSeconds = -1;
};

Q_DECLARE_METATYPE(ElistairStationManager*)
