/****************************************************************************
 *
 *   (c) 2019 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "MicrohardManager.h"
#include "MicrohardSettings.h"
#include "SettingsManager.h"
#include "QGCApplication.h"
#include "QGCCorePlugin.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonValue>
#include <QMap>
#include <QDateTime>
#include <QRegularExpression>
#include <QSettings>

#define SHORT_TIMEOUT 2500
#define LONG_TIMEOUT  5000

static const char *kMICROHARD_GROUP     = "Microhard";
static const char *kLOCAL_IP            = "LocalIP";
static const char *kREMOTE_IP           = "RemoteIP";
static const char *kNET_MASK            = "NetMask";
static const char *kCFG_USERNAME        = "ConfigUserName";
static const char *kCFG_PASSWORD        = "ConfigPassword";
static const char *kENC_KEY             = "EncryptionKey";

static QString _compactJson(const QJsonValue& value, const QString& prefix = QString())
{
    if (value.isObject()) {
        QStringList parts;
        const QJsonObject object = value.toObject();
        for (auto it = object.constBegin(); it != object.constEnd(); ++it) {
            const QString key = prefix.isEmpty() ? it.key() : prefix + QLatin1Char(' ') + it.key();
            if (it.value().isObject() || it.value().isArray()) {
                parts << _compactJson(it.value(), key);
            } else {
                parts << key + QStringLiteral(":") + _compactJson(it.value());
            }
        }
        return parts.join(QLatin1Char('\n'));
    }
    if (value.isArray()) {
        QStringList parts;
        const QJsonArray array = value.toArray();
        for (const QJsonValue& item : array) {
            parts << _compactJson(item, prefix);
        }
        return parts.join(QLatin1Char('\n'));
    }
    if (value.isString()) {
        return value.toString();
    }
    if (value.isDouble()) {
        return QString::number(value.toDouble());
    }
    if (value.isBool()) {
        return value.toBool() ? QStringLiteral("true") : QStringLiteral("false");
    }
    return QString();
}

static QString _normalizeStatsText(const QByteArray& bytes)
{
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(bytes, &parseError);
    if (parseError.error == QJsonParseError::NoError && !doc.isNull()) {
        return _compactJson(doc.isObject() ? QJsonValue(doc.object()) : QJsonValue(doc.array()));
    }
    return QString::fromUtf8(bytes);
}

static QString _matchStatValue(const QString& text, const QStringList& keys)
{
    for (const QString& key : keys) {
        const QStringList patterns = QStringList()
            << QStringLiteral("(?:^|[\\r\\n,;{])\\s*[\"']?(?:%1)[\"']?\\s*[:=]\\s*[\"']?([^\"'\\r\\n,;}]*)")
            << QStringLiteral("(?:^|[\\r\\n,;{])\\s*[\"']?(?:%1)[\"']?\\s+([^\"'\\r\\n,;}]*)");
        for (const QString& pattern : patterns) {
            const QRegularExpression re(pattern.arg(key), QRegularExpression::CaseInsensitiveOption);
            const QRegularExpressionMatch match = re.match(text);
            if (match.hasMatch()) {
                const QString value = match.captured(1).trimmed();
                if (!value.isEmpty()) {
                    return value;
                }
            }
        }
    }
    return QString();
}

static QString _matchPairValue(const QString& text, const QStringList& keys)
{
    const QString value = _matchStatValue(text, keys);
    if (value.isEmpty()) {
        return QString();
    }
    const QRegularExpression numbers(QStringLiteral("(-?\\d+(?:\\.\\d+)?)"));
    QRegularExpressionMatchIterator it = numbers.globalMatch(value);
    QStringList values;
    while (it.hasNext() && values.size() < 2) {
        values << it.next().captured(1);
    }
    return values.isEmpty() ? value : values.join(QStringLiteral(" / "));
}

static QString _normalizeJsonPath(const QString& path)
{
    QString normalized = path.toLower();
    normalized.remove(QRegularExpression(QStringLiteral("[^a-z0-9]+")));
    return normalized;
}

static QString _jsonValueToString(const QJsonValue& value)
{
    if (value.isString()) {
        return value.toString();
    }
    if (value.isDouble()) {
        return QString::number(value.toDouble(), 'f', 0);
    }
    if (value.isBool()) {
        return value.toBool() ? QStringLiteral("true") : QStringLiteral("false");
    }
    if (value.isObject()) {
        QStringList parts;
        const QJsonObject object = value.toObject();
        for (auto it = object.constBegin(); it != object.constEnd(); ++it) {
            parts << it.key() + QStringLiteral(":") + _jsonValueToString(it.value());
        }
        return parts.join(QStringLiteral(" "));
    }
    return QString();
}

static void _collectJsonValues(const QJsonValue& value, const QString& path, QMap<QString, QString>& values)
{
    if (value.isObject()) {
        const QJsonObject object = value.toObject();
        if (!path.isEmpty() && _normalizeJsonPath(path).endsWith(QStringLiteral("queuelength"))) {
            values.insert(path, _jsonValueToString(value));
        }
        for (auto it = object.constBegin(); it != object.constEnd(); ++it) {
            _collectJsonValues(it.value(), path.isEmpty() ? it.key() : path + QLatin1Char(' ') + it.key(), values);
        }
    } else if (value.isArray()) {
        const QJsonArray array = value.toArray();
        for (const QJsonValue& item : array) {
            _collectJsonValues(item, path, values);
        }
    } else if (!path.isEmpty()) {
        values.insert(path, _jsonValueToString(value));
    }
}

static QString _matchJsonValue(const QMap<QString, QString>& values, const QStringList& requiredTokens, const QStringList& rejectedTokens = QStringList())
{
    for (auto it = values.constBegin(); it != values.constEnd(); ++it) {
        const QString path = _normalizeJsonPath(it.key());
        bool matches = true;
        for (const QString& token : requiredTokens) {
            if (!path.contains(_normalizeJsonPath(token))) {
                matches = false;
                break;
            }
        }
        for (const QString& token : rejectedTokens) {
            if (path.contains(_normalizeJsonPath(token))) {
                matches = false;
                break;
            }
        }
        if (matches && !it.value().isEmpty()) {
            return it.value();
        }
    }
    return QString();
}

static quint64 _integerFromString(const QString& value)
{
    const QRegularExpression re(QStringLiteral("(\\d+)"));
    const QRegularExpressionMatch match = re.match(value);
    return match.hasMatch() ? match.captured(1).toULongLong() : 0;
}

static QString _formatBitRate(double bitsPerSecond)
{
    if (bitsPerSecond >= 1000000.0) {
        return QString::number(bitsPerSecond / 1000000.0, 'f', 2) + QStringLiteral(" Mbps");
    }
    if (bitsPerSecond >= 1000.0) {
        return QString::number(bitsPerSecond / 1000.0, 'f', 1) + QStringLiteral(" kbps");
    }
    return QString::number(bitsPerSecond, 'f', 0) + QStringLiteral(" bps");
}

//-----------------------------------------------------------------------------
MicrohardManager::MicrohardManager(QGCApplication* app, QGCToolbox* toolbox)
    : QGCTool(app, toolbox)
{
    connect(&_workTimer, &QTimer::timeout, this, &MicrohardManager::_checkMicrohard);
    _workTimer.setSingleShot(true);
    connect(&_locTimer, &QTimer::timeout, this, &MicrohardManager::_locTimeout);
    connect(&_remTimer, &QTimer::timeout, this, &MicrohardManager::_remTimeout);
    connect(&_statsTimer, &QTimer::timeout, this, &MicrohardManager::_statsTimeout);
    _statsTimer.setSingleShot(true);
    QSettings settings;
    settings.beginGroup(kMICROHARD_GROUP);
    _localIPAddr    = settings.value(kLOCAL_IP,       QString("192.168.168.1")).toString();
    _remoteIPAddr   = settings.value(kREMOTE_IP,      QString("192.168.168.2")).toString();
    _netMask        = settings.value(kNET_MASK,       QString("255.255.255.0")).toString();
    _configUserName = settings.value(kCFG_USERNAME,   QString("admin")).toString();
    _configPassword = settings.value(kCFG_PASSWORD,   QString("admin")).toString();
    _encryptionKey  = settings.value(kENC_KEY,        QString("1234567890")).toString();
    settings.endGroup();
}

//-----------------------------------------------------------------------------
MicrohardManager::~MicrohardManager()
{
    _close();
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_close()
{
    _workTimer.stop();
    _locTimer.stop();
    _remTimer.stop();
    _stopStatsSocket();
    if(_mhSettingsLoc) {
        _mhSettingsLoc->close();
        _mhSettingsLoc->deleteLater();
        _mhSettingsLoc = nullptr;
    }
    if(_mhSettingsRem) {
        _mhSettingsRem->close();
        _mhSettingsRem->deleteLater();
        _mhSettingsRem = nullptr;
    }
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_reset()
{
    _close();
    _connectedStatus = 0;
    emit connectedChanged();
    _linkConnectedStatus = 0;
    emit linkConnectedChanged();
    _statsConnected = false;
    emit statsChanged();
    if(!_appSettings) {
        _appSettings = _toolbox->settingsManager()->appSettings();
        connect(_appSettings->enableMicrohard(), &Fact::rawValueChanged, this, &MicrohardManager::_setEnabled);
    }
    _setEnabled();
}

//-----------------------------------------------------------------------------
FactMetaData*
MicrohardManager::_createMetadata(const char* name, QStringList enums)
{
    FactMetaData* metaData = new FactMetaData(FactMetaData::valueTypeUint32, name, this);
    QQmlEngine::setObjectOwnership(metaData, QQmlEngine::CppOwnership);
    metaData->setShortDescription(name);
    metaData->setLongDescription(name);
    metaData->setRawDefaultValue(QVariant(0));
    metaData->setHasControl(true);
    metaData->setReadOnly(false);
    for(int i = 0; i < enums.size(); i++) {
        metaData->addEnumInfo(enums[i], QVariant(i));
    }
    metaData->setRawMin(0);
    metaData->setRawMin(enums.size() - 1);
    return metaData;
}

//-----------------------------------------------------------------------------
void
MicrohardManager::setToolbox(QGCToolbox* toolbox)
{
    QGCTool::setToolbox(toolbox);
    //-- Start it all
    _reset();
}

//-----------------------------------------------------------------------------
void
MicrohardManager::switchToConnectionEncryptionKey(QString encryptionKey)
{
    _communicationEncryptionKey = encryptionKey;
    _useCommunicationEncryptionKey = true;
}

//-----------------------------------------------------------------------------
void
MicrohardManager::switchToPairingEncryptionKey()
{
    _useCommunicationEncryptionKey = false;
}

//-----------------------------------------------------------------------------
void
MicrohardManager::setEncryptionKey()
{
    if (_mhSettingsLoc) {
        _mhSettingsLoc->setEncryptionKey(_useCommunicationEncryptionKey ? _communicationEncryptionKey : _encryptionKey);
    }
}

//-----------------------------------------------------------------------------
void
MicrohardManager::updateSettings()
{
    setEncryptionKey();
    QSettings settings;
    settings.beginGroup(kMICROHARD_GROUP);
    settings.setValue(kLOCAL_IP, _localIPAddr);
    settings.setValue(kREMOTE_IP, _remoteIPAddr);
    settings.setValue(kNET_MASK, _netMask);
    settings.setValue(kCFG_PASSWORD, _configPassword);
    settings.setValue(kENC_KEY, _encryptionKey);
    settings.endGroup();

    _reset();
}

//-----------------------------------------------------------------------------
bool
MicrohardManager::setIPSettings(QString localIP_, QString remoteIP_, QString netMask_, QString cfgUserName_, QString cfgPassword_, QString encryptionKey_)
{
    if (_localIPAddr != localIP_ || _remoteIPAddr != remoteIP_ || _netMask != netMask_ ||
        _configUserName != cfgUserName_ || _configPassword != cfgPassword_ || _encryptionKey != encryptionKey_)
    {
        _localIPAddr    = localIP_;
        _remoteIPAddr   = remoteIP_;
        _netMask        = netMask_;
        _configUserName = cfgUserName_;
        _configPassword = cfgPassword_;
        _encryptionKey  = encryptionKey_;

        updateSettings();

        return true;
    }

    return false;
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_setEnabled()
{
    bool enable = _appSettings->enableMicrohard()->rawValue().toBool();
    if(enable) {
        _startStatsSocket();
        if(!_mhSettingsLoc) {
            _mhSettingsLoc = new MicrohardSettings(localIPAddr(), this, true);
            connect(_mhSettingsLoc, &MicrohardSettings::connected,      this, &MicrohardManager::_connectedLoc);
            connect(_mhSettingsLoc, &MicrohardSettings::rssiUpdated,    this, &MicrohardManager::_rssiUpdatedLoc);
        }
        if(!_mhSettingsRem) {
            _mhSettingsRem = new MicrohardSettings(remoteIPAddr(), this);
            connect(_mhSettingsRem, &MicrohardSettings::connected,      this, &MicrohardManager::_connectedRem);
            connect(_mhSettingsRem, &MicrohardSettings::rssiUpdated,    this, &MicrohardManager::_rssiUpdatedRem);
        }
        _workTimer.start(SHORT_TIMEOUT);
    } else {
        //-- Stop everything
        _close();
    }
    _enabled = enable;
}

//-----------------------------------------------------------------------------
void
MicrohardManager::refreshStats()
{
    _startStatsSocket();
    if (_enabled && _mhSettingsLoc && _connectedStatus > 0) {
        _mhSettingsLoc->getStatus();
    }
    if (_enabled && _mhSettingsRem && _linkConnectedStatus > 0) {
        _mhSettingsRem->getStatus();
    }
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_startStatsSocket()
{
    if (_statsSocket) {
        return;
    }

    _statsSocket = new QUdpSocket(this);
    connect(_statsSocket, &QUdpSocket::readyRead, this, &MicrohardManager::_statsReadyRead);
    const bool bound = _statsSocket->bind(QHostAddress::AnyIPv4, _statsPort, QUdpSocket::ShareAddress | QUdpSocket::ReuseAddressHint);
    if (!bound) {
        qCWarning(MicrohardLog) << "Could not bind Microhard stats UDP port" << _statsPort << _statsSocket->errorString();
        _statsSocket->deleteLater();
        _statsSocket = nullptr;
    }
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_stopStatsSocket()
{
    _statsTimer.stop();
    if (_statsSocket) {
        _statsSocket->close();
        _statsSocket->deleteLater();
        _statsSocket = nullptr;
    }
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_statsReadyRead()
{
    if (!_statsSocket) {
        return;
    }

    while (_statsSocket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(static_cast<int>(_statsSocket->pendingDatagramSize()));
        QHostAddress sender;
        _statsSocket->readDatagram(datagram.data(), datagram.size(), &sender);
        _parseStatsDatagram(datagram, sender);
    }
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_statsTimeout()
{
    if (_statsConnected) {
        _statsConnected = false;
        emit statsChanged();
    }
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_setStatsValue(QString& field, const QString& value, bool& changed)
{
    if (!value.isEmpty() && field != value) {
        field = value;
        changed = true;
    }
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_parseStatsDatagram(const QByteArray& bytes, const QHostAddress& sender)
{
    QMap<QString, QString> jsonValues;
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(bytes, &parseError);
    if (parseError.error == QJsonParseError::NoError && !doc.isNull()) {
        _collectJsonValues(doc.isObject() ? QJsonValue(doc.object()) : QJsonValue(doc.array()), QString(), jsonValues);
    }

    const QString text = _normalizeStatsText(bytes);
    bool changed = false;
    _statsPacketCount++;
    const QString senderText = sender.toString();
    if (!senderText.isEmpty() && _statsLastSource != senderText) {
        _statsLastSource = senderText;
        changed = true;
    }
    const QString rawText = QString::fromUtf8(bytes.left(512)).trimmed();
    if (_statsRawText != rawText) {
        _statsRawText = rawText;
        changed = true;
    }

    _setStatsValue(_groundRSSI, _matchJsonValue(jsonValues, QStringList() << QStringLiteral("rf") << QStringLiteral("rssi"), QStringList() << QStringLiteral("endpoints")), changed);
    const QString endpointRSSI = _matchJsonValue(jsonValues, QStringList() << QStringLiteral("endpoints") << QStringLiteral("rssi"));
    const QString operationMode = _matchJsonValue(jsonValues, QStringList() << QStringLiteral("operation") << QStringLiteral("mode")).toLower();
    if (!operationMode.isEmpty()) {
        const QString displayMode = operationMode.contains(QStringLiteral("slave")) ? QStringLiteral("Slave") :
                                    operationMode.contains(QStringLiteral("master")) ? QStringLiteral("Master") :
                                    operationMode;
        if (_statsLastMode != displayMode) {
            _statsLastMode = displayMode;
            changed = true;
        }
        if (operationMode.contains(QStringLiteral("slave"))) {
            _slaveStatsPacketCount++;
        } else if (operationMode.contains(QStringLiteral("master"))) {
            _masterStatsPacketCount++;
        }
    }
    if (!endpointRSSI.isEmpty()) {
        if (operationMode.contains(QStringLiteral("slave"))) {
            _setStatsValue(_groundRSSI, endpointRSSI, changed);
        } else {
            _setStatsValue(_skyRSSI, endpointRSSI, changed);
        }
    } else {
        _setStatsValue(_groundRSSI, _matchPairValue(text, QStringList()
                       << QStringLiteral("(?:ground|local|gnd)[\\w\\s/_-]*rssi")
                       << QStringLiteral("rssi[\\w\\s/_-]*(?:ground|local|gnd)")
                       << QStringLiteral("rssi")), changed);
        _setStatsValue(_skyRSSI, _matchPairValue(text, QStringList()
                       << QStringLiteral("(?:sky|air|remote|peer)[\\w\\s/_-]*rssi")
                       << QStringLiteral("rssi[\\w\\s/_-]*(?:sky|air|remote|peer)")), changed);
    }
    _setStatsValue(_snr, _matchJsonValue(jsonValues, QStringList() << QStringLiteral("snr")), changed);
    _setStatsValue(_snr, _matchStatValue(text, QStringList() << QStringLiteral("snr")), changed);
    _setStatsValue(_txRate, _matchJsonValue(jsonValues, QStringList() << QStringLiteral("tx") << QStringLiteral("rate")), changed);
    _setStatsValue(_txRate, _matchStatValue(text, QStringList() << QStringLiteral("tx[\\w\\s/_-]*rate") << QStringLiteral("transmit[\\w\\s/_-]*rate")), changed);
    _setStatsValue(_rxRate, _matchJsonValue(jsonValues, QStringList() << QStringLiteral("rx") << QStringLiteral("rate")), changed);
    _setStatsValue(_rxRate, _matchStatValue(text, QStringList() << QStringLiteral("rx[\\w\\s/_-]*rate") << QStringLiteral("receive[\\w\\s/_-]*rate")), changed);
    _setStatsValue(_txThroughput, _matchJsonValue(jsonValues, QStringList() << QStringLiteral("tx") << QStringLiteral("throughput")), changed);
    _setStatsValue(_txThroughput, _matchStatValue(text, QStringList() << QStringLiteral("tx[\\w\\s/_-]*throughput") << QStringLiteral("transmit[\\w\\s/_-]*throughput")), changed);
    _setStatsValue(_rxThroughput, _matchJsonValue(jsonValues, QStringList() << QStringLiteral("rx") << QStringLiteral("throughput")), changed);
    _setStatsValue(_rxThroughput, _matchStatValue(text, QStringList() << QStringLiteral("rx[\\w\\s/_-]*throughput") << QStringLiteral("receive[\\w\\s/_-]*throughput")), changed);
    _setStatsValue(_txBytes, _matchJsonValue(jsonValues, QStringList() << QStringLiteral("tx") << QStringLiteral("bytes")), changed);
    _setStatsValue(_txBytes, _matchStatValue(text, QStringList() << QStringLiteral("tx[\\w\\s/_-]*bytes") << QStringLiteral("transmit[\\w\\s/_-]*bytes")), changed);
    _setStatsValue(_rxBytes, _matchJsonValue(jsonValues, QStringList() << QStringLiteral("rx") << QStringLiteral("bytes")), changed);
    _setStatsValue(_rxBytes, _matchStatValue(text, QStringList() << QStringLiteral("rx[\\w\\s/_-]*bytes") << QStringLiteral("receive[\\w\\s/_-]*bytes")), changed);
    _setStatsValue(_queueLength, _matchJsonValue(jsonValues, QStringList() << QStringLiteral("queue") << QStringLiteral("length")), changed);
    _setStatsValue(_queueLength, _matchStatValue(text, QStringList() << QStringLiteral("queue[\\w\\s/_-]*(?:length|len)") << QStringLiteral("queue")), changed);
    _setStatsValue(_frequency, _matchJsonValue(jsonValues, QStringList() << QStringLiteral("frequency")), changed);
    _setStatsValue(_frequency, _matchStatValue(text, QStringList() << QStringLiteral("freq(?:uency)?")), changed);
    _setStatsValue(_temperature, _matchJsonValue(jsonValues, QStringList() << QStringLiteral("temperature")), changed);
    _setStatsValue(_temperature, _matchJsonValue(jsonValues, QStringList() << QStringLiteral("temp")), changed);
    _setStatsValue(_temperature, _matchStatValue(text, QStringList() << QStringLiteral("temp(?:erature)?")), changed);
    _setStatsValue(_version, _matchJsonValue(jsonValues, QStringList() << QStringLiteral("version")), changed);
    _setStatsValue(_version, _matchJsonValue(jsonValues, QStringList() << QStringLiteral("firmware")), changed);
    _setStatsValue(_version, _matchStatValue(text, QStringList() << QStringLiteral("version") << QStringLiteral("firmware")), changed);

    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    const quint64 txBytes = _integerFromString(_txBytes);
    const quint64 rxBytes = _integerFromString(_rxBytes);
    if (_lastByteCountersValid && _lastStatsRxMs > 0 && nowMs > _lastStatsRxMs) {
        const double elapsedSec = static_cast<double>(nowMs - _lastStatsRxMs) / 1000.0;
        if (txBytes >= _lastTxBytes && txBytes != _lastTxBytes) {
            _setStatsValue(_txRate, _formatBitRate(static_cast<double>(txBytes - _lastTxBytes) * 8.0 / elapsedSec), changed);
        }
        if (rxBytes >= _lastRxBytes && rxBytes != _lastRxBytes) {
            _setStatsValue(_rxRate, _formatBitRate(static_cast<double>(rxBytes - _lastRxBytes) * 8.0 / elapsedSec), changed);
        }
    }
    if (txBytes > 0 || rxBytes > 0) {
        _lastTxBytes = txBytes;
        _lastRxBytes = rxBytes;
        _lastStatsRxMs = nowMs;
        _lastByteCountersValid = true;
    }

    if (!_statsConnected) {
        _statsConnected = true;
        changed = true;
    }
    _statsTimer.start(_statsTimeoutMs);

    if (changed) {
        emit statsChanged();
    }
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_connectedLoc(int status)
{
    static const char* msg = "GND Microhard Settings: ";
    if(status > 0)
        qCDebug(MicrohardLog) << msg << "Connected";
    else if(status < 0)
        qCDebug(MicrohardLog) << msg << "Error";
    else
        qCDebug(MicrohardLog) << msg << "Not Connected";
    _connectedStatus = status;
    _locTimer.start(LONG_TIMEOUT);
    emit connectedChanged();
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_connectedRem(int status)
{
    static const char* msg = "AIR Microhard Settings: ";
    if(status > 0)
        qCDebug(MicrohardLog) << msg << "Connected";
    else if(status < 0)
        qCDebug(MicrohardLog) << msg << "Error";
    else
        qCDebug(MicrohardLog) << msg << "Not Connected";
    _linkConnectedStatus = status;
    _remTimer.start(LONG_TIMEOUT);
    emit linkConnectedChanged();
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_rssiUpdatedLoc(int rssi)
{
    _downlinkRSSI = rssi;
    _locTimer.stop();
    _locTimer.start(LONG_TIMEOUT);
    emit connectedChanged();
    emit linkChanged();
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_rssiUpdatedRem(int rssi)
{
    _uplinkRSSI = rssi;
    _remTimer.stop();
    _remTimer.start(LONG_TIMEOUT);
    emit linkConnectedChanged();
    emit linkChanged();
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_locTimeout()
{
    _locTimer.stop();
    _connectedStatus = 0;
    if(_mhSettingsLoc) {
        _mhSettingsLoc->close();
        _mhSettingsLoc->deleteLater();
        _mhSettingsLoc = nullptr;
    }
    emit connectedChanged();
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_remTimeout()
{
    _remTimer.stop();
    _linkConnectedStatus = 0;
    if(_mhSettingsRem) {
        _mhSettingsRem->close();
        _mhSettingsRem->deleteLater();
        _mhSettingsRem = nullptr;
    }
    emit linkConnectedChanged();
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_checkMicrohard()
{
    if(_enabled) {
        if(!_mhSettingsLoc || !_mhSettingsRem) {
            _setEnabled();
            return;
        }

        if(_connectedStatus <= 0) {
            _mhSettingsLoc->start();
        } else {
            _mhSettingsLoc->getStatus();
        }
        if(_linkConnectedStatus <= 0) {
            _mhSettingsRem->start();
        } else {
            _mhSettingsRem->getStatus();
        }
    }
    _workTimer.start(_connectedStatus > 0 ? SHORT_TIMEOUT : LONG_TIMEOUT);
}
