#include "ElistairStationManager.h"

#include <QDateTime>
#include <QSettings>
#include <QtMath>

#include "QGCApplication.h"
#include "QGCToolbox.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"
#include "TetherFactGroup.h"
#include "QGCLoggingCategory.h"
#include "CustomPlugin.h"
#include "CustomQmlInterface.h"
#include "VehicleLinkManager.h"
#include "SafeTPowerOffPolicy.h"
#include "AudioOutput.h"
#include "SafeTNoPowerPolicy.h"

QGC_LOGGING_CATEGORY(SafeTLog, "SafeTLog")

namespace {
constexpr quint8 kStandardSync = 0xAA;
constexpr quint8 kExtendedV0Sync = 0x55;
constexpr quint8 kExtendedV1Sync = 0x56;
constexpr quint8 kLocal = 0xff;
constexpr int kControlIntervalMsecs = 200;
constexpr int kNoReplyTimeoutMsecs = 1000;
constexpr int kLinkLostTimeoutMsecs = 5000;

TetherFactGroup* activeTetherFactGroup()
{
    auto* vehicle = qgcApp()->toolbox()->multiVehicleManager()->activeVehicle();
    return vehicle ? qobject_cast<TetherFactGroup*>(vehicle->factGroups().value(QStringLiteral("tether"))) : nullptr;
}
}

namespace FrameVersion { enum Value { Auto, ExtendedV1, ExtendedV0, Standard }; }

ElistairStationManager::ElistairStationManager(QObject* parent)
    : QObject(parent)
{
    // CustomPlugin is constructed before QGCApplication publishes its toolbox.
    // Bind vehicle signals only after startup has returned to the event loop.
    QTimer::singleShot(0, this, [this]() {
        connect(qgcApp()->toolbox()->multiVehicleManager(), &MultiVehicleManager::activeVehicleChanged, this, [this](Vehicle*) {
            _handleActiveVehicleChanged();
            _bindFlightVehicle();
        });
        _bindFlightVehicle();
    });
    connect(this, &ElistairStationManager::telemetryChanged, this, &ElistairStationManager::flightStateChanged);
    connect(this, &ElistairStationManager::telemetryChanged, this, [this]() {
        if (!_powerCommandKnown && _powerOn != (_powerWatts > 0)) {
            _powerOn = _powerWatts > 0;
            emit controlChanged();
        }
    });
    QSettings settings;
    _alarmSummary = tr("No alarms");
    // Migrate only explicitly configured endpoints; a fresh install stays off.
    _enabled = settings.value(QStringLiteral("ElistairStation/enabled"),
        settings.contains(QStringLiteral("ElistairStation/address")) || settings.contains(QStringLiteral("ElistairStation/port"))).toBool();
    _autoConnect = settings.value(QStringLiteral("ElistairStation/autoConnect"), true).toBool();
    _noPowerFailsafe = qBound(0, settings.value(QStringLiteral("ElistairStation/noPowerFailsafe"), 0).toInt(), 2);
    _noPowerAlarmTimer.setInterval(15000);
    connect(&_noPowerAlarmTimer, &QTimer::timeout, this, &ElistairStationManager::_announceNoPower);
    // SAFE-T 2.3 defaults (verified on a real station over Wi-Fi): 192.168.4.1, TCP 23232.
    // Elistair: Ethernet 192.168.1.120; UDP; port 7158 or 23232 depending on configuration.
    _stationAddress = settings.value(QStringLiteral("ElistairStation/address"), QStringLiteral("192.168.4.1")).toString();
    _stationPort = settings.value(QStringLiteral("ElistairStation/port"), 23232).toInt();
    _useTcp = settings.value(QStringLiteral("ElistairStation/transport"), QStringLiteral("TCP")).toString() != QStringLiteral("UDP");
    _controlTimer.setInterval(kControlIntervalMsecs);
    connect(&_controlTimer, &QTimer::timeout, this, &ElistairStationManager::_sendControl);
    connect(&_udp, &QUdpSocket::readyRead, this, &ElistairStationManager::_readDatagrams);
    connect(&_tcp, &QTcpSocket::readyRead, this, &ElistairStationManager::_readTcp);
    connect(&_tcp, &QTcpSocket::connected, this, [this]() {
        _tcpConnectTimer.stop();
        _tcpConnectedMsecs = QDateTime::currentMSecsSinceEpoch();
        qCInfo(SafeTLog) << "SAFE-T TCP connected" << _stationAddress << _stationPort;
        // A new stream is a new session: probe the frame version again from Extended V1.
        _extractor.clear();
        if (_negotiation.confirmed) { // same rule as a negotiation restart: drop remote authority
            cancelPowerOff();
            _powerRemote = _torqueRemote = _powerCommandKnown = _torqueCommandKnown = false;
            emit controlChanged();
        }
        _negotiationClock.restart();
        _negotiation = SafeTFrameNegotiator(_configuredFrameVersion, 0);
        _setActiveFrameVersion(_negotiation.active);
        emit connectionStatusChanged();
        _sendControl();
    });
    connect(&_tcp, &QTcpSocket::disconnected, this, [this]() {
        if (!_controlTimer.isActive()) return;
        qCWarning(SafeTLog) << "SAFE-T TCP disconnected; retrying in 2 s";
        _tcpRetryTimer.start();
    });
    connect(&_tcp, &QAbstractSocket::errorOccurred, this, [this](QAbstractSocket::SocketError) {
        if (!_controlTimer.isActive() || _tcpRetryTimer.isActive()) return;
        qCWarning(SafeTLog) << "SAFE-T TCP error:" << _tcp.errorString();
        _tcpConnectTimer.stop();
        _tcp.abort();
        _tcpRetryTimer.start();
    });
    _tcpRetryTimer.setSingleShot(true);
    _tcpRetryTimer.setInterval(2000);
    connect(&_tcpRetryTimer, &QTimer::timeout, this, &ElistairStationManager::_retryTcp);
    _tcpConnectTimer.setSingleShot(true);
    _tcpConnectTimer.setInterval(3000);
    connect(&_tcpConnectTimer, &QTimer::timeout, this, [this]() {
        qCWarning(SafeTLog) << "SAFE-T TCP connect timed out (3 s); retrying in 2 s";
        _tcp.abort();
        _tcpRetryTimer.start();
    });
    _timeoutTimer.setInterval(250);
    connect(&_timeoutTimer, &QTimer::timeout, this, &ElistairStationManager::_checkTimeout);
    _settingsReconnectTimer.setSingleShot(true);
    _settingsReconnectTimer.setInterval(150);
    connect(&_settingsReconnectTimer, &QTimer::timeout, this, &ElistairStationManager::connectStation);
    _configTimer.setSingleShot(true);
    _configTimer.setInterval(1500);
    connect(&_configTimer, &QTimer::timeout, this, [this]() {
        _settingsResult = _configOperation == 2 ? tr("Save result unknown. No automatic retry; read settings again to verify.")
            : _configOperation == 3 ? tr("Write acknowledged, but re-read failed. Read settings again to verify.") : tr("Config Read timed out.");
        _configOperation = 0;
        emit settingsTransactionChanged();
    });
    setFrameVersion(settings.value(QStringLiteral("ElistairStation/frameVersion"), QStringLiteral("Auto")).toString());

    QTimer::singleShot(0, this, [this]() {
        if (_enabled && _autoConnect) connectStation();
    });
}

void ElistairStationManager::setEnabled(bool enabled)
{
    if (_enabled == enabled) return;
    _enabled = enabled;
    QSettings().setValue(QStringLiteral("ElistairStation/enabled"), enabled);
    emit connectionSettingsChanged();
    if (enabled) connectStation(); else disconnectStation();
}

void ElistairStationManager::setAutoConnect(bool enabled)
{
    if (_autoConnect == enabled) return;
    _autoConnect = enabled;
    QSettings().setValue(QStringLiteral("ElistairStation/autoConnect"), enabled);
    emit connectionSettingsChanged();
}

void ElistairStationManager::setStationAddress(const QString& address)
{
    if (_stationAddress == address.trimmed()) return;
    _updateNoPower(0); // A different endpoint is a different station/incident scope.
    cancelPowerOff();
    _powerCommandKnown = false;
    _stationAddress = address.trimmed();
    QSettings().setValue(QStringLiteral("ElistairStation/address"), _stationAddress);
    emit connectionSettingsChanged();
    if (_controlTimer.isActive()) _settingsReconnectTimer.start();
}

void ElistairStationManager::setStationPort(int port)
{
    if (port < 1 || port > 65535 || _stationPort == port) return;
    _updateNoPower(0);
    cancelPowerOff();
    _powerCommandKnown = false;
    _stationPort = port;
    QSettings().setValue(QStringLiteral("ElistairStation/port"), _stationPort);
    emit connectionSettingsChanged();
    if (_controlTimer.isActive()) _settingsReconnectTimer.start();
}

void ElistairStationManager::setTransport(const QString& transport)
{
    const bool tcp = transport.trimmed().toUpper() != QStringLiteral("UDP");
    if (_useTcp == tcp) return;
    _updateNoPower(0);
    cancelPowerOff();
    _powerCommandKnown = false;
    _useTcp = tcp;
    QSettings().setValue(QStringLiteral("ElistairStation/transport"), this->transport());
    emit connectionSettingsChanged();
    if (_controlTimer.isActive()) _settingsReconnectTimer.start();
}

QString ElistairStationManager::frameVersion() const
{
    static const QStringList names { QStringLiteral("Auto"), QStringLiteral("Extended V1"), QStringLiteral("Extended V0"), QStringLiteral("Standard") };
    return names.value(_configuredFrameVersion, names.first());
}

QString ElistairStationManager::activeFrameVersion() const
{
    static const QStringList names { QStringLiteral("Auto"), QStringLiteral("Extended V1"), QStringLiteral("Extended V0"), QStringLiteral("Standard") };
    return names.value(_activeFrameVersion, QStringLiteral("Extended V1"));
}

void ElistairStationManager::setFrameVersion(const QString& version)
{
    const QString value = version.trimmed();
    const int selected = value == QStringLiteral("Standard") ? FrameVersion::Standard : value == QStringLiteral("Extended V0") ? FrameVersion::ExtendedV0 : value == QStringLiteral("Extended V1") ? FrameVersion::ExtendedV1 : FrameVersion::Auto;
    if (_configuredFrameVersion == selected) return;
    cancelPowerOff();
    _configuredFrameVersion = selected;
    QSettings().setValue(QStringLiteral("ElistairStation/frameVersion"), frameVersion());
    _setActiveFrameVersion(selected == FrameVersion::Auto ? FrameVersion::ExtendedV1 : selected);
    emit connectionSettingsChanged();
    // Changing the selected version automatically starts a fresh monitoring
    // handshake. The Test button is optional, not a prerequisite for connection.
    if (_controlTimer.isActive()) _settingsReconnectTimer.start();
}

void ElistairStationManager::connectStation()
{
    if (!_enabled) return;
    cancelPowerOff();
    _powerCommandKnown = false;
    _settingsReconnectTimer.stop();
    const QHostAddress address(_stationAddress);
    if (address.isNull()) {
        _setError(tr("Invalid SAFE-T station address: %1").arg(_stationAddress));
        return;
    }
    _setError({});
    _configTimer.stop();
    _configOperation = 0;
    _configSnapshot.clear();
    _stationSettings.clear();
    _settingsReadTime.clear();
    _settingsResult.clear();
    emit stationSettingsChanged();
    emit settingsTransactionChanged();
    qCInfo(SafeTLog) << "Connecting SAFE-T station" << transport() << _stationAddress << _stationPort;
    _openTransport();
    const auto started = QDateTime::currentMSecsSinceEpoch();
    _negotiationClock.start();
    _negotiation = SafeTFrameNegotiator(_configuredFrameVersion, 0);
    _torqueCommandKnown = false;
    // A user initiated connection must receive a fresh Monitoring frame before
    // any station control can be enabled. Last values remain visible as history.
    _lastMonitoringMsecs = started;
    _lastMonitoringTime.clear();
    _hasMonitoring = false;
    _setConnected(false);
    if (_powerRemote || _torqueRemote) {
        _powerRemote = false;
        _torqueRemote = false;
        emit controlChanged();
    }
    _noReply = false;
    _linkLost = false;
    _reconnectAttempt = 0;
    emit connectedChanged();
    emit connectionStatusChanged();
    _setActiveFrameVersion(_configuredFrameVersion == FrameVersion::Auto ? FrameVersion::ExtendedV1 : _configuredFrameVersion);
    _controlTimer.start();
    _timeoutTimer.start();
    _sendControl();
}

void ElistairStationManager::disconnectStation()
{
    _negotiation = SafeTFrameNegotiator(_configuredFrameVersion, 0);
    _torqueCommandKnown = false;
    cancelPowerOff();
    _settingsReconnectTimer.stop();
    _controlTimer.stop();
    _timeoutTimer.stop();
    _configTimer.stop();
    if (_configOperation == 2) _settingsResult = tr("Save result unknown. No automatic retry; read settings again to verify.");
    _configOperation = 0;
    emit settingsTransactionChanged();
    _tcpRetryTimer.stop();
    _tcpConnectTimer.stop();
    _tcp.abort();
    _udp.close();
    _extractor.clear();
    _updateNoPower(0);
    _hasMonitoring = false;
    _noReply = false;
    _linkLost = false;
    _reconnectAttempt = 0;
    emit connectedChanged();
    emit connectionStatusChanged();
    _setConnected(false);
    _logPowerSession();
    qCInfo(SafeTLog) << "SAFE-T station disconnected by user";
}

void ElistairStationManager::setPowerRemote(bool remote)
{
    if (_linkLost || !_hasMonitoring || _powerRemote == remote) return;
    _powerRemote = remote;
    // Enabling the UI permission is not an OFF command. Preserve physical
    // station power until the user explicitly chooses ON/OFF (and confirms).
    _powerCommandKnown = false;
    if (!remote) cancelPowerOff();
    qCInfo(SafeTLog) << "SAFE-T power authority" << (remote ? "REMOTE" : "LOCAL");
    emit controlChanged();
    _sendControl();
}

void ElistairStationManager::setPowerOn(bool on)
{
    // Power has no separate UI permission switch. Claim authority only for an
    // explicit ON/OFF request, never simply because the panel was opened.
    if (!SafeTPowerOffPolicy::canControl(_hasMonitoring, _linkLost, true,
        QDateTime::currentMSecsSinceEpoch() - _lastMonitoringMsecs)) return;
    if (!_powerRemote) setPowerRemote(true); // sends neutral 0xFF, not a power change
    if (!_canControlPower() || (_powerCommandKnown && _powerOn == on)) return;
    if (!on && powerOffRequiresConfirmation()) {
        if (_powerOffPending) return;
        _powerOffPending = true;
        ++_powerOffRequestId;
        qCInfo(SafeTLog) << "SAFE-T power OFF confirmation requested" << _powerOffRequestId;
        emit controlChanged();
        emit powerOffConfirmationRequested();
        return; // The 5 Hz control loop continues to transmit the existing ON state.
    }
    cancelPowerOff();
    _applyPowerOn(on);
}

bool ElistairStationManager::_canControlPower() const
{
    return SafeTPowerOffPolicy::canControl(_hasMonitoring && _negotiation.confirmed, _linkLost, _powerRemote,
        QDateTime::currentMSecsSinceEpoch() - _lastMonitoringMsecs);
}

bool ElistairStationManager::powerOffRequiresConfirmation() const
{
    auto* vehicle = qgcApp()->toolbox()->multiVehicleManager()->activeVehicle();
    const bool fcAvailable = vehicle && !vehicle->vehicleLinkManager()->communicationLost();
    return SafeTPowerOffPolicy::needsConfirmation(fcAvailable, vehicle && vehicle->armed(), vehicle && vehicle->flying(), _powerWatts, _cableLength);
}

void ElistairStationManager::_bindFlightVehicle()
{
    disconnect(_armedConnection); disconnect(_flyingConnection); disconnect(_vehicleLinkConnection);
    auto* vehicle = qgcApp()->toolbox()->multiVehicleManager()->activeVehicle();
    if (vehicle) {
        _armedConnection = connect(vehicle, &Vehicle::armedChanged, this, &ElistairStationManager::flightStateChanged);
        _flyingConnection = connect(vehicle, &Vehicle::flyingChanged, this, &ElistairStationManager::flightStateChanged);
        _vehicleLinkConnection = connect(vehicle->vehicleLinkManager(), &VehicleLinkManager::communicationLostChanged, this, &ElistairStationManager::flightStateChanged);
    }
    emit flightStateChanged();
}

void ElistairStationManager::cancelPowerOff()
{
    if (!_powerOffPending) return;
    _powerOffPending = false;
    qCInfo(SafeTLog) << "SAFE-T power OFF confirmation cancelled" << _powerOffRequestId;
    emit controlChanged();
}

bool ElistairStationManager::confirmPowerOff(qulonglong requestId)
{
    if (!_powerOffPending || requestId != _powerOffRequestId) {
        return _refuseAction(tr("Power OFF not sent: confirmation expired or was cancelled. Request it again."));
    }
    if (!_canControlPower()) {
        cancelPowerOff();
        return _refuseAction(tr("Power OFF not sent: station link or control authority unavailable. Request it again after reconnecting."));
    }
    _powerOffPending = false; // One-shot; a repeated accept cannot resend OFF.
    qCInfo(SafeTLog) << "SAFE-T power OFF confirmed" << requestId;
    _applyPowerOn(false);
    return true;
}

void ElistairStationManager::_applyPowerOn(bool on)
{
    _powerCommandKnown = true;
    _powerOn = on;
    if (on) {
        _powerOnSinceMsecs = QDateTime::currentMSecsSinceEpoch();
    } else {
        _logPowerSession();
    }
    qCInfo(SafeTLog) << "SAFE-T power command" << (on ? "ON" : "OFF");
    emit controlChanged();
    _sendControl();
}

void ElistairStationManager::setTorqueRemote(bool remote)
{
    if (_linkLost || !_hasMonitoring || !_negotiation.confirmed || _torqueRemote == remote) return;
    _torqueRemote = remote;
    _torqueCommandKnown = false;
    if (remote && _activeFrameVersion == FrameVersion::ExtendedV1) _torquePercent = _appliedTorquePercent;
    qCInfo(SafeTLog) << "SAFE-T torque authority" << (remote ? "REMOTE" : "LOCAL");
    emit controlChanged();
    _sendControl();
}

void ElistairStationManager::setTorquePercent(int percent)
{
    percent = qBound(0, percent, 100);
    if (_linkLost || !_hasMonitoring || !_negotiation.confirmed || !_torqueRemote || (_torqueCommandKnown && _torquePercent == percent)) return;
    _torqueCommandKnown = true;
    _torquePercent = percent;
    qCInfo(SafeTLog) << "SAFE-T torque command" << percent << "%";
    emit controlChanged();
    _sendControl();
}

bool ElistairStationManager::_safeForDetectionRead() const
{
    auto* vehicle = qgcApp()->toolbox()->multiVehicleManager()->activeVehicle();
    const bool fc = vehicle && !vehicle->vehicleLinkManager()->communicationLost();
    if (fc && (vehicle->armed() || vehicle->flying())) return false;
    const bool fresh = _hasMonitoring && QDateTime::currentMSecsSinceEpoch() - _lastMonitoringMsecs < 1000;
    if (fresh && (_powerWatts > 200 || _noPower || _decodedIntegrity == 2)) return false;
    return fc || (fresh && _decodedIntegrity == 0 && _activeFrameVersion != FrameVersion::Standard);
}

void ElistairStationManager::_advanceNegotiation()
{
    const bool wasConfirmed = _negotiation.confirmed;
    if (_negotiation.tick(_negotiationClock.elapsed(), _safeForDetectionRead())) {
        const auto request = QByteArray::fromHex("a50400000d0a");
        if (_send(request)) qCInfo(SafeTLog) << "SAFE-T detection Config Read (ground verified)";
    }
    _setActiveFrameVersion(_negotiation.active);
    if (wasConfirmed && !_negotiation.confirmed) {
        cancelPowerOff();
        _powerRemote = _torqueRemote = _powerCommandKnown = _torqueCommandKnown = false;
        emit controlChanged();
    }
    if (wasConfirmed != _negotiation.confirmed) emit connectionStatusChanged();
}

void ElistairStationManager::_sendControl()
{
    if (!_controlTimer.isActive() || _settingsReconnectTimer.isActive()) return;
    // While TCP is (re)connecting nothing can be sent: keep the negotiation (and its
    // one-shot detection Config Read) for when the stream is up.
    if (_useTcp && _tcp.state() != QAbstractSocket::ConnectedState) return;
    _advanceNegotiation();
    const QHostAddress address(_stationAddress);
    if (address.isNull()) return;

    QByteArray frame;
    frame.reserve(6);
    const quint8 sync = _activeFrameVersion == FrameVersion::Standard ? kStandardSync : _activeFrameVersion == FrameVersion::ExtendedV0 ? kExtendedV0Sync : kExtendedV1Sync;
    frame.append(char(sync));
    frame.append(char(_negotiation.confirmed && _powerRemote && _powerCommandKnown ? (_powerOn ? 0x01 : 0x00) : kLocal));
    const int torqueScale = _activeFrameVersion == FrameVersion::ExtendedV1 ? 254 : 10;
    frame.append(char(_negotiation.confirmed && _torqueRemote && _torqueCommandKnown ? qRound(_torquePercent * torqueScale / 100.0) : kLocal));
    frame.append(char(_crc8(frame.mid(1, 2))));
    frame.append('\r');
    frame.append('\n');
    if (!_send(frame)) _setError(_transportError());
}

QString ElistairStationManager::_settingsInterlockReason() const
{
    auto* vehicle = qgcApp()->toolbox()->multiVehicleManager()->activeVehicle();
    if (vehicle && (vehicle->armed() || vehicle->flying())) return tr("Settings are read-only while vehicle is armed.");
    if (!_connected || !_hasMonitoring || _linkLost) return tr("Station link unavailable.");
    if (_powerWatts > 200) return tr("Settings are read-only while station power exceeds 200 W.");
    if (_noPower) return tr("Settings are read-only: station reports no power in flight.");
    if (_activeFrameVersion != FrameVersion::ExtendedV1) return tr("Settings require Extended V1.");
    return {};
}

void ElistairStationManager::_requestConfigRead(int operation)
{
    const auto reason = _settingsInterlockReason();
    if (!reason.isEmpty()) {
        _settingsResult = reason;
        _configOperation = 0;
        emit settingsTransactionChanged();
        return;
    }
    const QByteArray request = QByteArray::fromHex("a50400000d0a");
    _configOperation = operation;
    _settingsResult = operation == 3 ? tr("Write acknowledged. Re-reading settings...") : tr("Reading station settings...");
    if (!_send(request)) {
        _configOperation = 0;
        _settingsResult = _transportError();
    } else _configTimer.start();
    emit settingsTransactionChanged();
}

void ElistairStationManager::readSettings()
{
    if (!settingsBusy()) _requestConfigRead(1);
}

bool ElistairStationManager::writeSettings(const QVariantMap& values)
{
    if (settingsBusy()) return false;
    auto fail = [this](const QString& text) { _settingsResult = text; emit settingsTransactionChanged(); return false; };
    const auto reason = _settingsInterlockReason();
    if (!reason.isEmpty()) return fail(reason);
    if (_configSnapshot.size() != 81) return fail(tr("Read station settings before saving."));
    const auto integer = [&values](const char* key, int minimum, int maximum, int& result) {
        bool ok = false;
        const double number = values.value(QString::fromLatin1(key)).toDouble(&ok);
        if (!ok || !qIsFinite(number) || number < minimum || number > maximum || number != qFloor(number)) return false;
        result = int(number);
        return true;
    };
    int high, low, time, timeout, alert, length, protection, torque, trigger;
    if (!integer("highTrigger", 0, 5000, high) || !integer("lowTrigger", 0, 5000, low)) return fail(tr("High / Low: allowed 0-5000 W."));
    bool timeOk = false;
    const double seconds = values.value(QStringLiteral("timeTrigger")).toDouble(&timeOk);
    if (!timeOk || !qIsFinite(seconds) || seconds < .1 || seconds > 25.5)
        return fail(tr("Time trigger: allowed 0.1-25.5 s, in 0.1 s increments."));
    time = qRound(seconds * 10);
    if (qAbs(seconds * 10 - time) > .00001)
        return fail(tr("Time trigger: allowed 0.1-25.5 s, in 0.1 s increments."));
    if (!integer("controlTimeout", 200, 12750, timeout) || timeout % 50 != 0) return fail(tr("Control timeout: allowed 200-12750 ms in 50 ms increments."));
    if (!integer("powerAlert", 0, 100, alert) || !integer("lengthAlarm", 0, 200, length)
        || !integer("protectionLength", 0, 200, protection) || !integer("antiShockPercent", 0, 100, torque)
        || !integer("lengthTrigger", 0, 200, trigger)) return fail(tr("Correct the out-of-range settings."));
    QByteArray frame(51, '\0');
    frame[0] = char(0xd5); frame[1] = 49;
    frame.replace(4, 20, _configSnapshot.mid(20, 20));
    frame.replace(24, 10, _configSnapshot.mid(40, 10));
    for (const auto& key : {QStringLiteral("wifiSsid"), QStringLiteral("wifiPassword")}) {
        const QString text = values.value(key).toString();
        const int limit = key == QStringLiteral("wifiSsid") ? 20 : 10;
        if (text.toLatin1() != text.toUtf8() || text.contains(QChar('\0')) || text.size() >= limit)
            return fail(tr("%1: ASCII only, maximum %2 characters.").arg(limit == 20 ? tr("Wi-Fi SSID") : tr("Wi-Fi password")).arg(limit - 1));
        const int offset = limit == 20 ? 4 : 24;
        frame.replace(offset, limit, text.toLatin1().leftJustified(limit, '\0'));
    }
    // Preserve every unchanged/hidden field from the last complete EEPROM read.
    frame.replace(34, 7, _configSnapshot.mid(52, 7));
    frame.replace(41, 8, _configSnapshot.mid(67, 8));
    frame[34] = char(alert); frame[35] = char(length); frame[36] = char(protection); frame[37] = char(torque);
    frame[40] = char((values.value("protection").toBool() ? 1 : 0) | (values.value("antiShock").toBool() ? 2 : 0)
        | (values.value("antiEntrapment").toBool() ? 4 : 0) | (values.value("antiDragging").toBool() ? 8 : 0));
    frame[41] = char(timeout / 50); frame[42] = values.value("autoOff").toBool() ? 1 : 0;
    frame[43] = char(high >> 8); frame[44] = char(high & 255);
    frame[45] = char(low >> 8); frame[46] = char(low & 255);
    frame[47] = char(time); frame[48] = char(trigger);
    frame[2] = char(_crc8(frame.mid(3, 46))); frame[49] = '\r'; frame[50] = '\n';
    _configOperation = 2;
    _settingsResult = tr("Saving station settings...");
    if (!_send(frame)) {
        _configOperation = 0;
        return fail(tr("Save result unknown: %1").arg(_transportError()));
    }
    _configTimer.start();
    emit settingsTransactionChanged();
    return true;
}

bool ElistairStationManager::_decodeConfiguration(const QByteArray& frame)
{
    if (frame.isEmpty() || (quint8(frame[0]) != 0xa5 && quint8(frame[0]) != 0xd5)) return false;
    if ((_configOperation == 1 || _configOperation == 3 || _negotiation.configPending) && quint8(frame[0]) == 0xa5
        && frame.size() == 81 && quint8(frame[1]) == 79 && frame[3] == 0
        && quint8(frame[2]) == _crc8(frame.mid(3, 78))) {
        const bool verified = _configOperation == 3;
        if (_negotiation.configPending) {
            if (!_negotiation.configuration(quint8(frame[75]), quint8(frame[76]), _negotiationClock.elapsed(), _safeForDetectionRead())) return true;
            _setActiveFrameVersion(_negotiation.active);
        }
        _configTimer.stop();
        _configSnapshot = frame;
        auto ascii = [&frame](int offset, int count) { return QString::fromLatin1(frame.mid(offset, count).split('\0').first()); };
        auto byte = [&frame](int offset) { return int(quint8(frame[offset])); };
        _stationSettings = {{"serialNumber", ascii(4, 16)},
            {"interfaceFirmware", QStringLiteral("%1.%2").arg(byte(75)).arg(byte(76))},
            {"commandFirmware", QStringLiteral("%1.%2").arg(byte(77)).arg(byte(78))},
            {"powerFirmware", QStringLiteral("%1.%2").arg(byte(79)).arg(byte(80))},
            {"poweredHours", _u16be(frame, 61)}, {"flights", _u16be(frame, 63)},
            {"maintenanceHours", _u16be(frame, 65)},
            {"wifiSsid", ascii(20, 20)}, {"wifiPassword", ascii(40, 10)},
            {"powerAlarm", _u16be(frame, 50)}, {"powerAlert", byte(52)}, {"lengthAlarm", byte(53)},
            {"protectionLength", byte(54)}, {"antiShockPercent", byte(55)}, {"controlTimeout", byte(67) * 50},
            {"autoOff", byte(68) != 0}, {"highTrigger", _u16be(frame, 69)}, {"lowTrigger", _u16be(frame, 71)},
            {"timeTrigger", byte(73) / 10.0}, {"lengthTrigger", byte(74)},
            {"tetherLength", byte(59)}, {"tetherWeight", byte(60)},
            {"protection", bool(byte(58) & 1)}, {"antiShock", bool(byte(58) & 2)},
            {"antiEntrapment", bool(byte(58) & 4)}, {"antiDragging", bool(byte(58) & 8)}};
        _settingsReadTime = QDateTime::currentDateTime().toString(QStringLiteral("hh:mm:ss"));
        _configOperation = 0;
        _settingsResult = verified ? tr("Saved and re-read successfully.") : tr("Station settings read successfully.");
        emit stationSettingsChanged();
        emit settingsTransactionChanged();
    } else if (_configOperation == 2 && quint8(frame[0]) == 0xd5 && frame.size() == 6
        && quint8(frame[1]) == 4 && frame[3] == 0 && quint8(frame[2]) == _crc8(frame.mid(3, 3))) {
        _configTimer.stop();
        const int errors = _u16be(frame, 4);
        if (errors) {
            _configOperation = 0;
            _settingsResult = tr("Station rejected settings (error mask 0x%1). Changes kept.").arg(errors, 4, 16, QLatin1Char('0'));
            emit settingsTransactionChanged();
        } else _requestConfigRead(3);
    }
    return true;
}

void ElistairStationManager::_openTransport()
{
    _tcpRetryTimer.stop();
    _tcpConnectTimer.stop();
    _tcp.abort();
    _udp.close();
    _extractor.clear();
    if (_useTcp) {
        _tcp.connectToHost(QHostAddress(_stationAddress), quint16(_stationPort));
        _tcpConnectTimer.start();
        return;
    }
    // Older stations (spec A.17 p.6) do not learn the reply port and answer a fixed
    // port equal to the station port: listen there, fall back to any port if taken.
    // Not for a station on this machine (simulator): sharing its port would deliver
    // its replies back to itself.
    if (QHostAddress(_stationAddress).isLoopback()) {
        _udp.bind(QHostAddress(QHostAddress::AnyIPv4), quint16(0));
    } else if (!_udp.bind(QHostAddress::AnyIPv4, quint16(_stationPort))) {
        qCWarning(SafeTLog) << "SAFE-T UDP bind to local port" << _stationPort << "failed:" << _udp.errorString() << "- using any port";
        _udp.bind(QHostAddress(QHostAddress::AnyIPv4), quint16(0));
    }
}

void ElistairStationManager::_retryTcp()
{
    if (!_controlTimer.isActive() || !_useTcp) return;
    qCInfo(SafeTLog) << "SAFE-T TCP reconnecting" << _stationAddress << _stationPort;
    _tcp.abort();
    _tcp.connectToHost(QHostAddress(_stationAddress), quint16(_stationPort));
    _tcpConnectTimer.start();
}

bool ElistairStationManager::_send(const QByteArray& frame)
{
    if (_useTcp) return _tcp.state() == QAbstractSocket::ConnectedState && _tcp.write(frame) == frame.size();
    return _udp.writeDatagram(frame, QHostAddress(_stationAddress), quint16(_stationPort)) == frame.size();
}

QString ElistairStationManager::_transportError() const
{
    if (_useTcp && _tcp.state() != QAbstractSocket::ConnectedState) return tr("TCP not connected to %1:%2").arg(_stationAddress).arg(_stationPort);
    return _useTcp ? _tcp.errorString() : _udp.errorString();
}

void ElistairStationManager::_readTcp()
{
    _processBytes(_tcp.readAll());
}

void ElistairStationManager::_readDatagrams()
{
    while (_udp.hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(int(_udp.pendingDatagramSize()));
        QHostAddress sender;
        _udp.readDatagram(datagram.data(), datagram.size(), &sender);
        if (!sender.isEqual(QHostAddress(_stationAddress), QHostAddress::TolerantConversion)) continue;
        _processBytes(datagram);
    }
}

void ElistairStationManager::_processBytes(const QByteArray& data)
{
    const int crcErrors = _extractor.crcErrors;
    const auto frames = _extractor.push(reinterpret_cast<const std::uint8_t*>(data.constData()), std::size_t(data.size()),
                                        QDateTime::currentMSecsSinceEpoch());
    if (_extractor.crcErrors != crcErrors) qCWarning(SafeTLog) << "SAFE-T CRC error(s):" << _extractor.crcErrors - crcErrors << "total" << _extractor.crcErrors;
    for (const auto& parsed : frames) {
        const QByteArray frame(reinterpret_cast<const char*>(parsed.bytes.data()), int(parsed.bytes.size()));
        if (parsed.kind == SafeTFrameExtractor::ConfigRead || parsed.kind == SafeTFrameExtractor::ConfigWrite) {
            _decodeConfiguration(frame);
            continue;
        }
        if (_decodeMonitoring(frame, parsed.bigEndianStandard)) {
            if (_noPower && _decodedIntegrity < 0) {
                _alarmSummary = tr("CRITICAL: No power in flight (last reported)");
                emit telemetryChanged();
            }
            _lastMonitoringMsecs = QDateTime::currentMSecsSinceEpoch();
            const bool firstMonitoring = !_hasMonitoring;
            const bool wasConfirmed = _negotiation.confirmed;
            _hasMonitoring = true;
            _negotiation.monitoring(_negotiationClock.elapsed(), _safeForDetectionRead());
            _setActiveFrameVersion(_negotiation.active);
            const QString monitoringTime = QDateTime::currentDateTime().toString(QStringLiteral("hh:mm:ss"));
            const bool timeChanged = _lastMonitoringTime != monitoringTime;
            _lastMonitoringTime = monitoringTime;
            const bool linkStateChanged = _noReply || _linkLost;
            _noReply = false;
            _linkLost = false;
            if (linkStateChanged) {
                qCInfo(SafeTLog) << "SAFE-T monitoring restored after" << _reconnectAttempt << "retry attempts";
                _reconnectAttempt = 0;
                emit connectedChanged();
            }
            if (firstMonitoring || timeChanged || linkStateChanged || wasConfirmed != _negotiation.confirmed)
                emit connectionStatusChanged();
            if (firstMonitoring) emit controlChanged(); // Setpoint availability becomes known on V1.
            _setConnected(_negotiation.confirmed);
            _updateNoPower(_decodedIntegrity);
            _publishTelemetry();
            _logAlarmTransition();
            _logStationFlightTime();
        }
    }
}

void ElistairStationManager::_checkTimeout()
{
    const auto now = QDateTime::currentMSecsSinceEpoch();
    const auto elapsed = _lastMonitoringMsecs > 0 ? now - _lastMonitoringMsecs : kLinkLostTimeoutMsecs + 1;
    const bool noReply = elapsed > kNoReplyTimeoutMsecs;
    const bool linkLost = elapsed > kLinkLostTimeoutMsecs;

    if (_noReply != noReply || _linkLost != linkLost) {
        _noReply = noReply;
        _linkLost = linkLost;
        if (_linkLost) {
            _reconnectAttempt = 1;
            _lastReconnectAttemptMsecs = now;
            qCWarning(SafeTLog) << "SAFE-T link lost" << "after" << elapsed << "ms";
            _logPowerSession();
            if (_hasMonitoring) _showLinkLostMessage();
        } else if (_noReply) {
            qCWarning(SafeTLog) << "SAFE-T no reply" << "after" << elapsed << "ms";
        }
        if (_linkLost && (_powerRemote || _torqueRemote)) {
            cancelPowerOff();
            _powerRemote = false;
            _torqueRemote = false;
            emit controlChanged();
        }
        emit connectedChanged();
        emit connectionStatusChanged();
    }
    // A stalled TCP stream raises no error: after 5 s without monitoring on a connected
    // socket, drop it and reconnect (the station may also have accepted another client).
    if (_useTcp && _tcp.state() == QAbstractSocket::ConnectedState
        && now - qMax(_lastMonitoringMsecs, _tcpConnectedMsecs) > kLinkLostTimeoutMsecs) {
        qCWarning(SafeTLog) << "SAFE-T TCP stream silent for" << (now - qMax(_lastMonitoringMsecs, _tcpConnectedMsecs)) << "ms; reconnecting";
        _tcp.abort();
        _extractor.clear();
        _tcpRetryTimer.start();
    }
    if (linkLost && now - _lastReconnectAttemptMsecs >= 1000) {
        ++_reconnectAttempt;
        _lastReconnectAttemptMsecs = now;
        qCInfo(SafeTLog) << "SAFE-T reconnect attempt" << _reconnectAttempt;
        // _controlTimer keeps transmitting exactly at 5 Hz while reconnecting.
        emit connectionStatusChanged();
    }
    _setConnected(_hasMonitoring && _negotiation.confirmed && !noReply);
}

bool ElistairStationManager::_decodeMonitoring(const QByteArray& frame, bool bigEndianStandard)
{
    // Frames arrive from _extractor already CRC-validated and without CR/LF (core bytes only).
    // Only the frame type matching the active version is accepted (frame-version negotiation).
    // SAFE-T Extended Monitoring V1: 0x56, size=23, CRC, payload (version + bytes 4..24).
    // Multi-byte values are big-endian. Alarm bytes may be raw (0x00..) or ASCII ('0'..).
    if (_activeFrameVersion == FrameVersion::Standard) {
        if (frame.size() != 11 || quint8(frame.at(0)) != kStandardSync) return false;
        _powerSourceVolts = -1;
        _decodedIntegrity = -1; // Standard has no fresh integrity report.
        _alarmActive = false;
        // Spec §4.1.2 is little-endian; the SAFE-T 2.3 variant (tentative) is big-endian.
        const auto u16 = [&](int offset) { return bigEndianStandard ? _u16be(frame, offset) : _u16le(frame, offset); };
        _powerWatts = u16(2); _cableLength = u16(4) / 10.0; _tetherRemaining = qQNaN(); _cableSpeed = quint8(frame.at(6)) / 10.0; _spoolTemperature = qint8(frame.at(7)); _voltage = qQNaN(); _current = qQNaN(); _appliedTorquePercent = 0; _alarmSummary = tr("No alarms (Standard frame)"); emit telemetryChanged(); return true;
    }
    if (_activeFrameVersion == FrameVersion::ExtendedV0) {
        if (frame.size() != 16 || quint8(frame.at(0)) != kExtendedV0Sync) return false;
        _powerSourceVolts = -1;
        _powerWatts = _u16be(frame, 4); _cableLength = _u16be(frame, 6) / 10.0;
        _decodedIntegrity = SafeTNoPowerPolicy::decodeIntegrity(frame[15]);
        _alarmActive = false;
        for (int i = 12; i <= 15; ++i) _alarmActive |= SafeTNoPowerPolicy::decodeAlarm(frame[i]) != 0;
        _voltage = qQNaN(); _current = qQNaN(); _tetherRemaining = qQNaN(); _appliedTorquePercent = 0;
        _cableSpeed = quint8(frame.at(8)) / 10.0; _spoolTemperature = qint8(frame.at(9));
        _alarmSummary = _decodedIntegrity == 2 ? tr("CRITICAL: No power in flight") : _alarmActive ? tr("SAFE-T alarm active") : tr("Monitoring connected (Extended V0)"); emit telemetryChanged(); return true;
    }
    if (frame.size() != 25 || quint8(frame.at(0)) != kExtendedV1Sync || quint8(frame.at(3)) != 0x01) return false;

    _powerWatts = _u16be(frame, 4);
    _cableLength = _u16be(frame, 6) / 10.0;
    // Bytes 8-9 are the measured (total) tether length; remaining = measured - unwound.
    _tetherRemaining = qMax(0.0, _u16be(frame, 8) / 10.0 - _cableLength);
    _stationFlightTimeSeconds = quint8(frame.at(12)) * 3600 + quint8(frame.at(13)) * 60;
    _cableSpeed = quint8(frame.at(10)) / 10.0;
    _spoolTemperature = static_cast<qint8>(frame.at(11));
    _voltage = _u16be(frame, 14);
    _current = _u16be(frame, 16) / 1000.0;
    // V1 byte 24 identifies the nominal AC input source, not a voltage measurement.
    const quint8 powerSource = quint8(frame.at(24));
    _powerSourceVolts = powerSource == 0 ? 120 : powerSource == 1 ? 230 : -1;
    _appliedTorquePercent = qBound(0, qRound(quint8(frame.at(18)) * 100.0 / 255.0), 100);
    if (!_torqueRemote && !_torqueCommandKnown && _torquePercent != _appliedTorquePercent) {
        _torquePercent = _appliedTorquePercent;
        emit controlChanged();
    }
    const auto activeAlarm = [&frame](int offset) { return SafeTNoPowerPolicy::decodeAlarm(frame.at(offset)) != 0; };
    const bool alarm = activeAlarm(19) || activeAlarm(20) || activeAlarm(21) || activeAlarm(22) || activeAlarm(23);
    _alarmActive = alarm;
    _decodedIntegrity = SafeTNoPowerPolicy::decodeIntegrity(frame[22]);
    _alarmSummary = _decodedIntegrity == 2 ? tr("CRITICAL: No power in flight") : alarm ? tr("SAFE-T alarm active") : tr("No alarms");
    emit telemetryChanged();
    return true;
}

quint8 ElistairStationManager::_crc8(const QByteArray& data)
{
    quint8 crc = 0;
    for (const char value : data) {
        crc ^= quint8(value);
        for (int bit = 0; bit < 8; ++bit) crc = (crc & 0x80) ? quint8((crc << 1) ^ 0xd5) : quint8(crc << 1);
    }
    return crc;
}

quint16 ElistairStationManager::_u16be(const QByteArray& data, int offset)
{
    return (quint16(quint8(data.at(offset))) << 8) | quint16(quint8(data.at(offset + 1)));
}

quint16 ElistairStationManager::_u16le(const QByteArray& data, int offset)
{
    return quint16(quint8(data.at(offset))) | (quint16(quint8(data.at(offset + 1))) << 8);
}

void ElistairStationManager::_setActiveFrameVersion(int version)
{
    if (_activeFrameVersion == version) return;
    _activeFrameVersion = version;
    emit connectionSettingsChanged();
}

void ElistairStationManager::_setError(const QString& error)
{
    if (_lastError == error) return;
    _lastError = error;
    emit lastErrorChanged();
}

bool ElistairStationManager::_refuseAction(const QString& reason)
{
    _setError(reason);
    qCWarning(SafeTLog) << reason;
    if (auto* plugin = qobject_cast<CustomPlugin*>(parent())) plugin->showMessage(reason, SystemMessage::Warning);
    return false;
}

void ElistairStationManager::_publishTelemetry()
{
    if (auto* tether = activeTetherFactGroup()) {
        // The monitoring protocol has no maximum cable length, so remaining length is unavailable.
        tether->updateTelemetry(_cableLength, _tetherRemaining, _powerWatts, _voltage, _current,
                                _activeFrameVersion == FrameVersion::ExtendedV1 ? _appliedTorquePercent : qQNaN(), _spoolTemperature, _cableSpeed);
    }
}

void ElistairStationManager::setNoPowerFailsafe(int value)
{
    if (value < 0 || value > 2 || value == _noPowerFailsafe) return;
    _noPowerFailsafe = value;
    QSettings().setValue(QStringLiteral("ElistairStation/noPowerFailsafe"), value);
    // A preference change must never execute a command for an existing incident.
    emit noPowerChanged();
}

void ElistairStationManager::dismissNoPower()
{
    _noPowerDismissed = true;
    emit noPowerChanged();
}

void ElistairStationManager::_handleActiveVehicleChanged()
{
    cancelPowerOff();
    if (!_noPower || _noPowerActionSent) return;
    // Invalidate any slider already open for the previous target, but retain
    // the incident and its original QPointer. Never silently retarget Land/RTL.
    ++_noPowerIncident;
    _noPowerDismissed = false;
    if (_noPowerFailsafe == 2) _autoLandFailed = true;
    emit noPowerChanged();
}

bool ElistairStationManager::noPowerVehicleNeedsConfirmation() const
{
    auto* active = qgcApp()->toolbox()->multiVehicleManager()->activeVehicle();
    return _noPower && !_noPowerActionSent && (!_noPowerVehicle || active != _noPowerVehicle);
}

bool ElistairStationManager::associateNoPowerVehicle(qulonglong incident, Vehicle* candidate)
{
    auto* active = qgcApp()->toolbox()->multiVehicleManager()->activeVehicle();
    const auto age = QDateTime::currentMSecsSinceEpoch() - _lastMonitoringMsecs;
    if (!_noPower || _noPowerActionSent || incident != _noPowerIncident || !candidate || candidate != active
        || candidate->vehicleLinkManager()->communicationLost() || !connected() || noReply() || linkLost()
        || age < 0 || age >= 1000 || _decodedIntegrity != 2) {
        return _refuseAction(tr("Vehicle association rejected: incident or vehicle changed, or links are unavailable. Check the tethered vehicle and try again."));
    }
    _noPowerVehicle = candidate;
    ++_noPowerIncident; // Old target/incident confirmations can never dispatch.
    _noPowerDismissed = false;
    if (_noPowerFailsafe == 2) _autoLandFailed = true;
    qCWarning(SafeTLog) << "Operator associated no-power incident" << _noPowerIncident << "with vehicle" << candidate->id() << candidate->vehicleUIDStr();
    emit noPowerChanged();
    return true; // Association itself never sends Land/RTL or retries Auto land.
}

void ElistairStationManager::_announceNoPower()
{
    if (!_noPower) return;
    const QString message = tr("Tether power lost in flight. Drone on onboard battery.") +
        (_noPowerFailsafe == 1 ? QString() : tr(" Landing recommended. Select an action in the Tether panel."));
    if (auto* plugin = qobject_cast<CustomPlugin*>(parent())) plugin->showMessage(message, SystemMessage::Warning);
    qgcApp()->toolbox()->audioOutput()->say(message);
}

void ElistairStationManager::_updateNoPower(int integrity)
{
    if (integrity < 0 || (_noPower == (integrity == 2))) return;
    _noPower = integrity == 2;
    ++_noPowerIncident;
    _noPowerDismissed = false;
    _noPowerActionSent = false;
    _autoLandFailed = false;
    _noPowerVehicle = _noPower ? qgcApp()->toolbox()->multiVehicleManager()->activeVehicle() : nullptr;
    cancelPowerOff();
    emit noPowerChanged();
    emit telemetryChanged();
    if (!_noPower) { _noPowerAlarmTimer.stop(); return; }
    qCCritical(SafeTLog) << "Cable integrity=2, no-power incident" << _noPowerIncident << "policy" << _noPowerFailsafe;
    _announceNoPower();
    _noPowerAlarmTimer.start();
    if (_noPowerFailsafe == 2) {
        if (!executeNoPowerAction(_noPowerIncident, false)) {
            // One failed automatic attempt must leave a manual recovery path.
            // Never automatically retry a flight command on later telemetry.
            _autoLandFailed = true;
            emit noPowerChanged();
        }
    }
}

void ElistairStationManager::requestNoPowerAction(bool rtl)
{
    if (noPowerPrompt() && !_noPowerActionSent && !noPowerVehicleNeedsConfirmation() && _noPowerVehicle && connected() && !noReply() && !linkLost())
        emit noPowerActionRequested(rtl, _noPowerIncident);
    else _refuseAction(tr("Tether action unavailable: check vehicle and station links."));
}

bool ElistairStationManager::executeNoPowerAction(qulonglong incident, bool rtl)
{
    auto* vehicle = qgcApp()->toolbox()->multiVehicleManager()->activeVehicle();
    const qint64 age = QDateTime::currentMSecsSinceEpoch() - _lastMonitoringMsecs;
    if (!SafeTNoPowerPolicy::canDispatch(_noPower, _decodedIntegrity, incident == _noPowerIncident, _noPowerActionSent,
        connected() && !noReply() && !linkLost() && age >= 0 && age < 1000,
        vehicle && vehicle == _noPowerVehicle, vehicle && vehicle->armed(),
        vehicle && !vehicle->vehicleLinkManager()->communicationLost(), vehicle && vehicle->guidedModeSupported())) {
        return _refuseAction(tr("Tether action NOT sent: incident expired, action already sent, or a live armed vehicle and fresh station telemetry are unavailable. Check links and request the action again."));
    }
    _noPowerActionSent = true; // Latch before dispatch; no automatic retries on missing ACK.
    dismissNoPower();
    qCWarning(SafeTLog) << "No-power failsafe command" << (rtl ? "RTL to Home (station assumed)" : "Land") << "incident" << incident;
    if (rtl) vehicle->guidedModeRTL(false); else vehicle->guidedModeLand();
    if (auto* plugin = qobject_cast<CustomPlugin*>(parent())) plugin->showMessage(rtl ? tr("Tether: RTL command sent to Home (station assumed).") : tr("Tether: Land command sent."), SystemMessage::Warning);
    return true;
}

void ElistairStationManager::_logAlarmTransition()
{
    if (_lastLoggedAlarmSummary == _alarmSummary) return;
    _lastLoggedAlarmSummary = _alarmSummary;
    if (!alarmActive()) {
        qCInfo(SafeTLog) << "SAFE-T alarms cleared";
    } else {
        qCWarning(SafeTLog) << "SAFE-T alarm event:" << _alarmSummary;
    }
}

void ElistairStationManager::_logPowerSession()
{
    if (_powerOnSinceMsecs <= 0) return;
    const qint64 elapsedMsecs = QDateTime::currentMSecsSinceEpoch() - _powerOnSinceMsecs;
    _powerOnSinceMsecs = 0;
    qCInfo(SafeTLog) << "SAFE-T station powered session" << elapsedMsecs / 1000.0 << "s";
}

void ElistairStationManager::_logStationFlightTime()
{
    if (_stationFlightTimeSeconds < 0 || _stationFlightTimeSeconds == _lastLoggedStationFlightTimeSeconds) return;
    _lastLoggedStationFlightTimeSeconds = _stationFlightTimeSeconds;
    qCInfo(SafeTLog) << "SAFE-T reported station flight time" << _stationFlightTimeSeconds << "s";
}

void ElistairStationManager::_showLinkLostMessage()
{
    auto* plugin = qobject_cast<CustomPlugin*>(parent());
    if (!plugin) return;
    plugin->showMessage(tr("Tether station link lost (> 5 s) - values are last received - controls locked. Reconnecting... (%1)").arg(_reconnectAttempt), SystemMessage::Warning);
}

void ElistairStationManager::_setConnected(bool connected)
{
    if (_connected == connected) return;
    _connected = connected;
    if (auto* tether = activeTetherFactGroup()) {
        tether->setLinkAvailable(connected);
    }
    if (connected) {
        qCInfo(SafeTLog) << "SAFE-T station connected" << _stationAddress << _stationPort;
    } else {
        qCWarning(SafeTLog) << "SAFE-T station disconnected";
    }
    emit connectedChanged();
}
