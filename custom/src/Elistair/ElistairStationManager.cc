#include "ElistairStationManager.h"

#include <QDateTime>
#include <QSettings>

namespace {
constexpr quint8 kSync = 0x56;
constexpr quint8 kLocal = 0xff;
constexpr int kControlIntervalMsecs = 200;
constexpr int kNoReplyTimeoutMsecs = 1000;
constexpr int kLinkLostTimeoutMsecs = 5000;
}

ElistairStationManager::ElistairStationManager(QObject* parent)
    : QObject(parent)
{
    QSettings settings;
    _stationAddress = settings.value(QStringLiteral("ElistairStation/address"), QStringLiteral("127.0.0.1")).toString();
    _stationPort = settings.value(QStringLiteral("ElistairStation/port"), 7158).toInt();

    _controlTimer.setInterval(kControlIntervalMsecs);
    connect(&_controlTimer, &QTimer::timeout, this, &ElistairStationManager::_sendControl);
    connect(&_socket, &QUdpSocket::readyRead, this, &ElistairStationManager::_readDatagrams);
    _timeoutTimer.setInterval(250);
    connect(&_timeoutTimer, &QTimer::timeout, this, &ElistairStationManager::_checkTimeout);

    // The saved station endpoint is automatically reconnected at application startup.
    QTimer::singleShot(0, this, &ElistairStationManager::connectStation);
}

void ElistairStationManager::setStationAddress(const QString& address)
{
    if (_stationAddress == address.trimmed()) return;
    _stationAddress = address.trimmed();
    QSettings().setValue(QStringLiteral("ElistairStation/address"), _stationAddress);
    emit connectionSettingsChanged();
}

void ElistairStationManager::setStationPort(int port)
{
    if (port < 1 || port > 65535 || _stationPort == port) return;
    _stationPort = port;
    QSettings().setValue(QStringLiteral("ElistairStation/port"), _stationPort);
    emit connectionSettingsChanged();
}

void ElistairStationManager::connectStation()
{
    const QHostAddress address(_stationAddress);
    if (address.isNull()) {
        _setError(tr("Invalid SAFE-T station address: %1").arg(_stationAddress));
        return;
    }
    _setError({});
    _controlTimer.start();
    _timeoutTimer.start();
    _sendControl();
}

void ElistairStationManager::disconnectStation()
{
    _controlTimer.stop();
    _timeoutTimer.stop();
    _setConnected(false);
}

void ElistairStationManager::setPowerRemote(bool remote)
{
    if (_powerRemote == remote) return;
    _powerRemote = remote;
    emit controlChanged();
    _sendControl();
}

void ElistairStationManager::setPowerOn(bool on)
{
    if (!_powerRemote || _powerOn == on) return;
    _powerOn = on;
    emit controlChanged();
    _sendControl();
}

void ElistairStationManager::setTorqueRemote(bool remote)
{
    if (_torqueRemote == remote) return;
    _torqueRemote = remote;
    emit controlChanged();
    _sendControl();
}

void ElistairStationManager::setTorquePercent(int percent)
{
    percent = qBound(0, percent, 100);
    if (!_torqueRemote || _torquePercent == percent) return;
    _torquePercent = percent;
    emit controlChanged();
    _sendControl();
}

void ElistairStationManager::_sendControl()
{
    if (!_controlTimer.isActive()) return;
    const QHostAddress address(_stationAddress);
    if (address.isNull()) return;

    QByteArray frame;
    frame.reserve(6);
    frame.append(char(kSync));
    frame.append(char(_powerRemote ? (_powerOn ? 0x01 : 0x00) : kLocal));
    frame.append(char(_torqueRemote ? qRound(_torquePercent * 254.0 / 100.0) : kLocal));
    frame.append(char(_crc8(frame.mid(1, 2))));
    frame.append('\r');
    frame.append('\n');
    if (_socket.writeDatagram(frame, address, static_cast<quint16>(_stationPort)) < 0) {
        _setError(_socket.errorString());
    }
}

void ElistairStationManager::_readDatagrams()
{
    while (_socket.hasPendingDatagrams()) {
        QByteArray frame;
        frame.resize(int(_socket.pendingDatagramSize()));
        _socket.readDatagram(frame.data(), frame.size());
        if (_decodeMonitoring(frame)) {
            _lastMonitoringMsecs = QDateTime::currentMSecsSinceEpoch();
            const bool linkStateChanged = _noReply || _linkLost;
            _noReply = false;
            _linkLost = false;
            if (linkStateChanged) emit connectedChanged();
            _setConnected(true);
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
        if (_linkLost && (_powerRemote || _torqueRemote)) {
            _powerRemote = false;
            _torqueRemote = false;
            emit controlChanged();
        }
        emit connectedChanged();
    }
    _setConnected(!noReply);
}

bool ElistairStationManager::_decodeMonitoring(const QByteArray& frame)
{
    // SAFE-T V2.1/V2.2 Extended Monitoring V1: 0x56, size=23, CRC,
    // payload (version + bytes 4..24), CR, LF. Multi-byte values are big-endian.
    if (frame.size() != 27 || quint8(frame.at(0)) != kSync || quint8(frame.at(1)) != 23 ||
        frame.at(25) != '\r' || frame.at(26) != '\n' || quint8(frame.at(3)) != 0x01) return false;
    if (quint8(frame.at(2)) != _crc8(frame.mid(3, 22))) return false;

    _powerWatts = _u16be(frame, 4);
    _cableLength = _u16be(frame, 6) / 10.0;
    _cableSpeed = quint8(frame.at(10)) / 10.0;
    _spoolTemperature = static_cast<qint8>(frame.at(11));
    _voltage = _u16be(frame, 14);
    _current = _u16be(frame, 16) / 1000.0;
    _appliedTorquePercent = qRound(quint8(frame.at(18)) * 100.0 / 254.0);
    const auto activeAlarm = [&frame](int offset) { return frame.at(offset) != '0' && frame.at(offset) != 0; };
    const bool alarm = activeAlarm(19) || activeAlarm(20) || activeAlarm(21) || activeAlarm(22) || activeAlarm(23);
    _alarmSummary = alarm ? tr("SAFE-T alarm active") : tr("No alarms");
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

void ElistairStationManager::_setError(const QString& error)
{
    if (_lastError == error) return;
    _lastError = error;
    emit lastErrorChanged();
}

void ElistairStationManager::_setConnected(bool connected)
{
    if (_connected == connected) return;
    _connected = connected;
    emit connectedChanged();
}
