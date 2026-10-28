#pragma once

#include <QObject>
#include <QHostAddress>
#include <QUdpSocket>
#include <QTimer>

// SAFE-T Extended V1 UDP client. The control frame is sent at 5 Hz to keep
// remote authority alive; monitoring frames are decoded into QML properties.
class ElistairStationManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString stationAddress READ stationAddress WRITE setStationAddress NOTIFY connectionSettingsChanged)
    Q_PROPERTY(int stationPort READ stationPort WRITE setStationPort NOTIFY connectionSettingsChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(bool noReply READ noReply NOTIFY connectedChanged)
    Q_PROPERTY(bool linkLost READ linkLost NOTIFY connectedChanged)
    Q_PROPERTY(bool powerRemote READ powerRemote NOTIFY controlChanged)
    Q_PROPERTY(bool powerOn READ powerOn NOTIFY controlChanged)
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
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit ElistairStationManager(QObject* parent = nullptr);

    QString stationAddress() const { return _stationAddress; }
    int stationPort() const { return _stationPort; }
    bool connected() const { return _connected; }
    bool noReply() const { return _noReply; }
    bool linkLost() const { return _linkLost; }
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
    QString lastError() const { return _lastError; }

    void setStationAddress(const QString& address);
    void setStationPort(int port);

    Q_INVOKABLE void connectStation();
    Q_INVOKABLE void disconnectStation();
    Q_INVOKABLE void setPowerRemote(bool remote);
    Q_INVOKABLE void setPowerOn(bool on);
    Q_INVOKABLE void setTorqueRemote(bool remote);
    Q_INVOKABLE void setTorquePercent(int percent);

signals:
    void connectionSettingsChanged();
    void connectedChanged();
    void controlChanged();
    void telemetryChanged();
    void lastErrorChanged();

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

    QUdpSocket _socket;
    QTimer _controlTimer;
    QTimer _timeoutTimer;
    QString _stationAddress;
    int _stationPort = 7158;
    qint64 _lastMonitoringMsecs = 0;
    bool _connected = false;
    bool _noReply = true;
    bool _linkLost = false;
    bool _powerRemote = false;
    bool _powerOn = false;
    bool _torqueRemote = false;
    int _torquePercent = 50;
    int _powerWatts = 0;
    double _cableLength = 0;
    double _cableSpeed = 0;
    int _spoolTemperature = 0;
    double _voltage = 0;
    double _current = 0;
    int _appliedTorquePercent = 0;
    QString _alarmSummary = QStringLiteral("No alarms");
    QString _lastError;
};

Q_DECLARE_METATYPE(ElistairStationManager*)
