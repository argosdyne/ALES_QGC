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
    QString bestValue;
    int     bestLength = -1;
    for (auto it = values.constBegin(); it != values.constEnd(); ++it) {
        const QString path = _normalizeJsonPath(it.key());
        bool matches = true;
        for (const QString& token : requiredTokens) {
            if (!path.contains(_normalizeJsonPath(token))) {
                matches = false;
                break;
            }
        }
        if (matches) {
            for (const QString& token : rejectedTokens) {
                if (path.contains(_normalizeJsonPath(token))) {
                    matches = false;
                    break;
                }
            }
        }
        if (matches && !it.value().isEmpty()) {
            //-- Prefer the most specific (shortest) matching path so an aggregate
            //   field like "tx bytes" wins over nested per-endpoint duplicates and
            //   the chosen counter stays stable between datagrams.
            if (bestLength < 0 || path.length() < bestLength) {
                bestValue  = it.value();
                bestLength = path.length();
            }
        }
    }
    return bestValue;
}

static quint64 _integerFromString(const QString& value)
{
    const QRegularExpression re(QStringLiteral("(\\d+)"));
    const QRegularExpressionMatch match = re.match(value);
    return match.hasMatch() ? match.captured(1).toULongLong() : 0;
}

static QString _formatByteCount(quint64 bytes)
{
    if (bytes >= 1024ULL * 1024ULL * 1024ULL) {
        return QString::number(static_cast<double>(bytes) / (1024.0 * 1024.0 * 1024.0), 'f', 2) + QStringLiteral(" GB");
    }
    if (bytes >= 1024ULL * 1024ULL) {
        return QString::number(static_cast<double>(bytes) / (1024.0 * 1024.0), 'f', 2) + QStringLiteral(" MB");
    }
    if (bytes >= 1024ULL) {
        return QString::number(static_cast<double>(bytes) / 1024.0, 'f', 1) + QStringLiteral(" KB");
    }
    return QString::number(bytes) + QStringLiteral(" B");
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

//-- The radio reports throughput as a raw bits/second counter; turn it into a
//   human-readable rate. Non-numeric strings are passed through untouched.
static QString _formatThroughput(const QString& value)
{
    if (value.isEmpty()) {
        return QString();
    }
    bool ok = false;
    const double bitsPerSecond = value.toDouble(&ok);
    return ok ? _formatBitRate(bitsPerSecond) : value;
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
    //-- Always listen on the stats UDP ports so a Microhard link is auto-detected
    //   even before the user ticks "Enable Microhard".
    _startStatsSocket();
    if(enable) {
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
        //-- Stop the active TCP probing but keep passively listening for stats so
        //   the link can still be auto-detected.
        _workTimer.stop();
        _locTimer.stop();
        _remTimer.stop();
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
        if(_connectedStatus != 0) {
            _connectedStatus = 0;
            emit connectedChanged();
        }
        if(_linkConnectedStatus != 0) {
            _linkConnectedStatus = 0;
            emit linkConnectedChanged();
        }
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
    if (!_statsSockets.isEmpty()) {
        return;
    }

    const QList<quint16> ports = QList<quint16>() << _statsPort << _statsPortSecondary;
    for (quint16 port : ports) {
        QUdpSocket* socket = new QUdpSocket(this);
        connect(socket, &QUdpSocket::readyRead, this, &MicrohardManager::_statsReadyRead);
        const bool bound = socket->bind(QHostAddress::AnyIPv4, port, QUdpSocket::ShareAddress | QUdpSocket::ReuseAddressHint);
        if (!bound) {
            qCWarning(MicrohardLog) << "Could not bind Microhard stats UDP port" << port << socket->errorString();
            socket->deleteLater();
            continue;
        }
        _statsSockets.append(socket);
    }
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_stopStatsSocket()
{
    _statsTimer.stop();
    for (QUdpSocket* socket : _statsSockets) {
        socket->close();
        socket->deleteLater();
    }
    _statsSockets.clear();
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_statsReadyRead()
{
    QUdpSocket* socket = qobject_cast<QUdpSocket*>(sender());
    if (!socket) {
        return;
    }

    while (socket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(static_cast<int>(socket->pendingDatagramSize()));
        QHostAddress sender;
        socket->readDatagram(datagram.data(), datagram.size(), &sender);
        _parseStatsDatagram(datagram, sender, socket->localPort());
    }
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_statsTimeout()
{
    if (_statsConnected) {
        _statsConnected = false;
        _resetStatsValues();
        emit statsChanged();
    }
}

//-----------------------------------------------------------------------------
void
MicrohardManager::_resetStatsValues()
{
    _groundRSSI   = QStringLiteral("--");
    _skyRSSI      = QStringLiteral("--");
    _snr          = QStringLiteral("--");
    _txRate       = QStringLiteral("--");
    _rxRate       = QStringLiteral("--");
    _txThroughput = QStringLiteral("--");
    _rxThroughput = QStringLiteral("--");
    _txBytes      = QStringLiteral("--");
    _rxBytes      = QStringLiteral("--");
    _queueLength  = QStringLiteral("--");
    _frequency    = QStringLiteral("--");
    _temperature  = QStringLiteral("--");
    _version      = QStringLiteral("--");
}

//-----------------------------------------------------------------------------
QString
MicrohardManager::statsSources() const
{
    QStringList parts;
    for (auto it = _statsSourceCounts.constBegin(); it != _statsSourceCounts.constEnd(); ++it) {
        parts << it.key() + QStringLiteral(" (%1)").arg(it.value());
    }
    return parts.isEmpty() ? QStringLiteral("--") : parts.join(QStringLiteral("\n"));
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
MicrohardManager::_parseStatsDatagram(const QByteArray& bytes, const QHostAddress& sender, quint16 localPort)
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
    const QString sourceText = senderText + QStringLiteral(":%1").arg(localPort);
    if (!senderText.isEmpty() && _statsLastSource != sourceText) {
        _statsLastSource = sourceText;
        changed = true;
    }
    if (!senderText.isEmpty()) {
        auto srcIt = _statsSourceCounts.find(sourceText);
        if (srcIt == _statsSourceCounts.end()) {
            _statsSourceCounts.insert(sourceText, 1);
            changed = true;
        } else {
            ++srcIt.value();
        }
    }
    const QString rawText = QString::fromUtf8(bytes.left(512)).trimmed();
    if (_statsRawText != rawText) {
        _statsRawText = rawText;
        changed = true;
    }

    const QString operationMode = _matchJsonValue(jsonValues, QStringList() << QStringLiteral("operation") << QStringLiteral("mode")).toLower();
    //-- Convention in this code: master = the ground unit, slave = the air unit.
    //   Both radios stream stats (often from the same address), each reporting
    //   figures from its OWN perspective, so a slave report is the far end and
    //   must be mapped into the ground-station frame.
    const bool isSlave = operationMode.contains(QStringLiteral("slave"));
    if (!operationMode.isEmpty()) {
        const QString displayMode = isSlave ? QStringLiteral("Slave") :
                                    operationMode.contains(QStringLiteral("master")) ? QStringLiteral("Master") :
                                    operationMode;
        if (_statsLastMode != displayMode) {
            _statsLastMode = displayMode;
            changed = true;
        }
        if (isSlave) {
            _slaveStatsPacketCount++;
        } else if (operationMode.contains(QStringLiteral("master"))) {
            _masterStatsPacketCount++;
        }
    }

    //-- rf.rssi is the reporting radio's own signal; endpoints.rssi is the far end.
    const QString ownRSSI      = _matchJsonValue(jsonValues, QStringList() << QStringLiteral("rf") << QStringLiteral("rssi"), QStringList() << QStringLiteral("endpoints"));
    const QString endpointRSSI = _matchJsonValue(jsonValues, QStringList() << QStringLiteral("endpoints") << QStringLiteral("rssi"));
    _setStatsValue(isSlave ? _skyRSSI : _groundRSSI, ownRSSI, changed);
    if (!endpointRSSI.isEmpty()) {
        _setStatsValue(isSlave ? _groundRSSI : _skyRSSI, endpointRSSI, changed);
    } else if (ownRSSI.isEmpty()) {
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
    //-- TX/RX are direction-dependent. A slave (air) report has them reversed from
    //   the ground view and uses a different counter base, so anchor the display to
    //   the ground (master) frame to stop the values from swapping back and forth.
    //   Only fall back to a slave report (swapped into the ground frame) when no
    //   master report has been seen at all.
    const bool useGroundFrame = !isSlave || _masterStatsPacketCount == 0;
    if (useGroundFrame) {
        QString txRate = _matchJsonValue(jsonValues, QStringList() << QStringLiteral("tx") << QStringLiteral("rate"));
        if (txRate.isEmpty()) {
            txRate = _matchStatValue(text, QStringList() << QStringLiteral("tx[\\w\\s/_-]*rate") << QStringLiteral("transmit[\\w\\s/_-]*rate"));
        }
        QString rxRate = _matchJsonValue(jsonValues, QStringList() << QStringLiteral("rx") << QStringLiteral("rate"));
        if (rxRate.isEmpty()) {
            rxRate = _matchStatValue(text, QStringList() << QStringLiteral("rx[\\w\\s/_-]*rate") << QStringLiteral("receive[\\w\\s/_-]*rate"));
        }
        _setStatsValue(isSlave ? _rxRate : _txRate, txRate, changed);
        _setStatsValue(isSlave ? _txRate : _rxRate, rxRate, changed);

        const QString txThroughputRaw = _matchJsonValue(jsonValues, QStringList() << QStringLiteral("tx") << QStringLiteral("throughput"));
        const QString rxThroughputRaw = _matchJsonValue(jsonValues, QStringList() << QStringLiteral("rx") << QStringLiteral("throughput"));
        const QString txThroughputText = txThroughputRaw.isEmpty() ? _matchStatValue(text, QStringList() << QStringLiteral("tx[\\w\\s/_-]*throughput") << QStringLiteral("transmit[\\w\\s/_-]*throughput")) : txThroughputRaw;
        const QString rxThroughputText = rxThroughputRaw.isEmpty() ? _matchStatValue(text, QStringList() << QStringLiteral("rx[\\w\\s/_-]*throughput") << QStringLiteral("receive[\\w\\s/_-]*throughput")) : rxThroughputRaw;
        _setStatsValue(isSlave ? _rxThroughput : _txThroughput, _formatThroughput(txThroughputText), changed);
        _setStatsValue(isSlave ? _txThroughput : _rxThroughput, _formatThroughput(rxThroughputText), changed);

        const QString txBytesRaw = _matchJsonValue(jsonValues, QStringList() << QStringLiteral("tx") << QStringLiteral("bytes"));
        const QString rxBytesRaw = _matchJsonValue(jsonValues, QStringList() << QStringLiteral("rx") << QStringLiteral("bytes"));
        const QString txBytesText = txBytesRaw.isEmpty() ? _matchStatValue(text, QStringList() << QStringLiteral("tx[\\w\\s/_-]*bytes") << QStringLiteral("transmit[\\w\\s/_-]*bytes")) : txBytesRaw;
        const QString rxBytesText = rxBytesRaw.isEmpty() ? _matchStatValue(text, QStringList() << QStringLiteral("rx[\\w\\s/_-]*bytes") << QStringLiteral("receive[\\w\\s/_-]*bytes")) : rxBytesRaw;
        const quint64 txBytesCounter = _integerFromString(txBytesText);
        const quint64 rxBytesCounter = _integerFromString(rxBytesText);
        if (txBytesCounter > 0) {
            _setStatsValue(isSlave ? _rxBytes : _txBytes, _formatByteCount(txBytesCounter), changed);
        }
        if (rxBytesCounter > 0) {
            _setStatsValue(isSlave ? _txBytes : _rxBytes, _formatByteCount(rxBytesCounter), changed);
        }
    }
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
