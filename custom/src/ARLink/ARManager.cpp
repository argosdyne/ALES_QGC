#include "ARManager.h"
#include "JsonHelper.h"
#include "CustomPlugin.h"
#include "CustomSettings.h"
#include <QQmlEngine>
#include <QJsonDocument>
#include <QNetworkInterface>
#include <QHostAddress>
#include <QJsonArray>              // json array
#include <QNetworkRequest>         // http request
#include <QSslConfiguration>       // ssl protocol
#include <QSslSocket>              // secure network

QGC_LOGGING_CATEGORY(ARManagerLog, "ARManagerLog")

namespace {

    // Robust JSON value-to-int parser. Handles doubles, strings (with units like "54000 kbit/s"), and nested objects with rate/value/avg keys.
    int jsonIntValue(const QJsonValue& value, int defaultValue = 0)
    {
        if (value.isDouble()) {
            return value.toInt();
        }

        if (value.isString()) {
            const QString text = value.toString().trimmed();
            bool ok = false;
            const int intValue = text.toInt(&ok);
            if (ok) {
                return intValue;
            }

            const QString firstToken = text.section(' ', 0, 0);
            const double doubleValue = firstToken.toDouble(&ok);
            return ok ? static_cast<int>(doubleValue) : defaultValue;
        }

        if (value.isObject()) {
            const QJsonObject object = value.toObject();
            if (object.contains("rate")) {
                return jsonIntValue(object.value("rate"), defaultValue);
            }
            if (object.contains("value")) {
                return jsonIntValue(object.value("value"), defaultValue);
            }
            if (object.contains("avg")) {
                return jsonIntValue(object.value("avg"), defaultValue);
            }
        }

        return defaultValue;
    }

    // Convenience wrappers for nested lookups.
    int jsonObjectInt(const QJsonObject& object, const QString& key, int defaultValue = 0)
    {
        return jsonIntValue(object.value(key), defaultValue);
    }

    // Convenience wrappers for nested lookups.
    int jsonNestedInt(const QJsonObject& object, const QString& objectKey, const QString& valueKey, int defaultValue = 0)
    {
        const QJsonValue nestedValue = object.value(objectKey);
        if (!nestedValue.isObject()) {
            return defaultValue;
        }

        return jsonIntValue(nestedValue.toObject().value(valueKey), defaultValue);
    }

    // Safe array extraction.
    QJsonArray jsonObjectArray(const QJsonObject& object, const QString& key)
    {
        const QJsonValue value = object.value(key);
        return value.isArray() ? value.toArray() : QJsonArray{};
    }

    // Converts negative dBm to positive (takes qAbs).
    int rawSignalToMagnitude(int rawSignal)
    {
        return qAbs(rawSignal);
    }

    // Simple signal - noise SNR calculation.
    int snrFromSignalAndNoise(int signal, int noise)
    {
        if (signal == 0 && noise == 0) {
            return 0;
        }

        return signal - noise;
    }

}

const char* ARManager::_bbConn = "bb_conn"; //是否连接成功
const char* ARManager::_brFreq = "br_freq"; //当前收发频段
const char* ARManager::_slotTxFreq = "slot_tx_freq"; //当前收发频段
const char* ARManager::_slotRxFreq = "slot_rx_freq"; //当前收发频段
const char* ARManager::_slotTxBitRate = "slot_tx_bitrate"; //当前收发频段
const char* ARManager::_targetBitRate = "target_bitrate"; //当前收发频段
const char* ARManager::_mcs = "mcs"; //地面速率模式
const char* ARManager::_snr = "snr"; //地面信噪比
const char* ARManager::_aRssi = "rssi_0"; //地面A天线信号
const char* ARManager::_bRssi = "rssi_1"; //地面B天线信号
const char* ARManager::_chan0Power = "chan_0_power"; //扫频数据
const char* ARManager::_chan1Power = "chan_1_power";
const char* ARManager::_chan2Power = "chan_2_power";
const char* ARManager::_chan3Power = "chan_3_power";
const char* ARManager::_chan4Power = "chan_4_power";
const char* ARManager::_chan5Power = "chan_5_power";
const char* ARManager::_chan6Power = "chan_6_power";
const char* ARManager::_aPeerSlotRssi = "peer_slot_rssi_0"; //天空端A天线信号
const char* ARManager::_bPeerSlotRssi = "peer_slot_rssi_1"; //天空端B天线信号
const char* ARManager::_peerSlotMcs = "peer_slot_mcs"; //天空端速率模式
const char* ARManager::_peerSlotSnr = "peer_slot_snr"; //天空端信噪比
const char* ARManager::_peerBrRssi0 = "peer_br_rssi_0"; //信令通道强度
const char* ARManager::_peerBrRssi1 = "peer_br_rssi_1"; //信令通道强度
const char* ARManager::_peerBrSnr = "peer_br_snr"; //信号信噪比
const char* ARManager::_apiVersion = "api_ver";
const char* ARManager::_is24G = "is_2.4G";
const char* ARManager::_selfTemperature = "self_temperature";
const char* ARManager::_skyTemperature = "sky_temperature";
const char* ARManager::_signal = "signal";
const char* ARManager::_noise = "noise";
const char* ARManager::_bitrate = "bitrate";
const char* ARManager::_channel = "channel";
const char* ARManager::_frequency = "frequency";

ARManager::ARManager(QGCApplication* app, QGCToolbox* toolbox)
    : QGCTool(app, toolbox)
{
    QString ipStr;
    QList<QNetworkInterface> interfaces = QNetworkInterface::allInterfaces();
	for(auto it = interfaces.begin(); it != interfaces.end(); it++) {
		// IEEE 802.3 Ethernet interfaces, though on many systems other types of
		// IEEE 802 interfaces may also be detected as Ethernet (especially Wi-Fi).
		if(it->flags() & QNetworkInterface::IsLoopBack) { continue; }
		if(!(it->flags() & QNetworkInterface::IsRunning)) { continue; }
        #if !defined (Q_OS_ANDROID)
        if(!(it->flags() & QNetworkInterface::Ethernet)) { continue; }
        #else
        if(!it->humanReadableName().startsWith("eth0")) { continue; }
        #endif
		QList<QNetworkAddressEntry> entries = it->addressEntries();
		for(auto iter = entries.begin(); iter != entries.end(); iter++) {
			QHostAddress ip = iter->ip();
			QHostAddress mask = iter->netmask();
			if(ip.protocol() !=  QAbstractSocket::IPv4Protocol) { continue; }
			if(ip == QHostAddress::LocalHost) { continue; }
            QString localIP = ip.toString();
            #if !defined (Q_OS_ANDROID)
            if(!(localIP.startsWith("192.168.2.") || localIP.startsWith("192.168.241."))) { continue; }
            #endif
            QRegExp rx("(\\.\\d{1,3})");
            int pos = rx.lastIndexIn(localIP);
            if(rx.captureCount() > 0) {
                QString replace_str = rx.cap(1);
                ipStr = localIP.remove(pos, replace_str.size()) + ".100";
                break;
            }
        }
        if(!ipStr.isEmpty()) {
            break;
        }
	}
    if(ipStr.isEmpty()) {
        ipStr = "192.168.2.100";
        qCWarning(ARManagerLog) << "Set Link Default IP:" << ipStr;
    } else {
        _auto = true;
        qCInfo(ARManagerLog) << "Get Link IP:" << ipStr;
    }
    _deviceIP = ipStr;
    _connection = new ARConnection(ipStr);
    _networkManager = new QNetworkAccessManager(this);
    // _connection->moveToThread(&workerThread);
    // connect(&workerThread, &QThread::finished, _connection, &QObject::deleteLater);
    // workerThread.start();

    setMounted(_connection->isConnected());
    connect(_connection, &ARConnection::isConnectedChanged, this, &ARManager::setMounted);
    connect(_connection, &ARConnection::receivedMessage, this, &ARManager::_received_message);
    connect(_networkManager, &QNetworkAccessManager::finished, this, &ARManager::_handleDoodleReply);

    _bindTimer.setSingleShot(true);
    _bindTimer.setInterval(140000);
    connect(&_bindTimer, &QTimer::timeout, this, &ARManager::_bindTimerout);

    _doodlePollTimer.setSingleShot(false);
    _doodlePollTimer.setInterval(1000);
    connect(&_doodlePollTimer, &QTimer::timeout, this, &ARManager::_pollDoodleInfo);    // 1s interval, not single-shot
}

ARManager::~ARManager()
{
    // workerThread.quit();
    // workerThread.wait();
}

void ARManager::setToolbox(QGCToolbox* toolbox)
{
    QGCTool::setToolbox(toolbox);
    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
    qmlRegisterUncreatableType<ARManager>("CustomQmlInterface", 1, 0, "ARManager", "Reference only");

    // Read Doodle Labs IP from persistent settings
    CustomPlugin* plugin = dynamic_cast<CustomPlugin*>(_toolbox->corePlugin());
    if (plugin && plugin->settings()) {
        Fact* ipFact = plugin->settings()->doodleLabsIP();
        _doodleDeviceIP = ipFact->rawValue().toString();
        connect(ipFact, &Fact::rawValueChanged, this, [this](QVariant value) {
            _doodleDeviceIP = value.toString();
            _rpcSession.clear();
            qCInfo(ARManagerLog) << "[Doodle Labs] IP changed to:" << _doodleDeviceIP;
        });
    }

#if !defined (Q_OS_ANDROID)
    if(_auto)
#endif
    emit _connection->enable();
    _doodlePollTimer.start();      // is called here, so polling begins at app startup.
}

void ARManager::pair()
{
    _pairTriggered = true;
    _connection->triggerPair();
}

void ARManager::restartDevice()
{
    _connection->restartDevice();
}

void ARManager::enable24G()
{
    _connection->setWorkMode(0);
}

void ARManager::enable58G()
{
    _connection->setWorkMode(1);
}

void ARManager::restartRemoteDevice()
{
    _connection->restartRemoteDevice();
}

void ARManager::enableRemote24G()
{
    _connection->setRemoteWorkMode(0);
}

void ARManager::enableRemote58G()
{
    _connection->setRemoteWorkMode(1);
}

void ARManager::_received_message(quint16 cmd, QByteArray message)
{
    if (_usingDoodleApi && cmd == AR_CMD_ID_REQUEST_INFO) {
        return;
    }   // bypass other communciation systems

    switch (cmd) {
    case AR_CMD_ID_REQUEST_INFO:
        _handle_device_info(message);
        break;
    case AR_CMD_ID_TRIGGER_PAIR:
        if(_pairTriggered) {
            _pairTriggered = false;
            setBindTimeout(false);
            setBinding(true);
            if(_bindTimer.isActive()) {
                _bindTimer.stop();
            }
            _bindTimer.start();
        }
    default:
        emit ackFromDevice(cmd);
        break;
    }
}

void ARManager::_handle_device_info(const QByteArray& message)
{
    if (_usingDoodleApi) {
        return;
    }   // bypass other communication systems

    if(message.size() != 0) {
        QString errorString;
        QJsonParseError jsonParseError;
        QJsonDocument doc = QJsonDocument::fromJson(message, &jsonParseError);
        if (doc.isObject()) {
            QJsonObject jsonObject = doc.object();
            QList<JsonHelper::KeyValidateInfo> keyInfoList = {
                { _bbConn,          QJsonValue::Double, true },
                { _brFreq,          QJsonValue::Double, true },
                { _slotTxFreq,      QJsonValue::Double, true },
                { _slotRxFreq,      QJsonValue::Double, true },
                { _slotTxBitRate,   QJsonValue::Double, true },
                { _targetBitRate,   QJsonValue::Double, true },
                { _mcs,             QJsonValue::Double, true },
                { _snr,             QJsonValue::Double, true },
                { _aRssi,           QJsonValue::Double, true },
                { _bRssi,           QJsonValue::Double, true },
                { _chan0Power,      QJsonValue::String, false },
                { _chan1Power,      QJsonValue::String, false },
                { _chan2Power,      QJsonValue::String, false },
                { _chan3Power,      QJsonValue::String, false },
                { _chan4Power,      QJsonValue::String, false },
                { _chan5Power,      QJsonValue::String, false },
                { _chan6Power,      QJsonValue::String, false },
                { _aPeerSlotRssi,   QJsonValue::Double, true },
                { _bPeerSlotRssi,   QJsonValue::Double, true },
                { _peerSlotMcs,     QJsonValue::Double, true },
                { _peerSlotSnr,     QJsonValue::Double, true },
                { _peerBrRssi0,     QJsonValue::Double, true },
                { _peerBrRssi1,     QJsonValue::Double, true },
                { _peerBrSnr,       QJsonValue::Double, true },
                { _apiVersion,      QJsonValue::String, false },
                { _is24G,           QJsonValue::Double, false },
                { _selfTemperature, QJsonValue::Double, false },
                { _skyTemperature,  QJsonValue::Double, false }
            };
            if (!JsonHelper::validateKeys(jsonObject, keyInfoList, errorString)) {
                qCWarning(ARManagerLog) << errorString;
                qCInfo(ARManagerLog) << QString(message);
            } else {
                setConnected(jsonObject[_bbConn].toDouble() != 0);
                if(connected() && _bindTimer.isActive() && (_bindTimer.remainingTime() < (_bindTimer.interval() - 15000))) {
                    _bindTimer.stop();
                    setBindTimeout(false);
                    setBinding(false);
                }
                _jsonObject = jsonObject;
                emit rssiChanged();
            }
            // setConnected
        }
    }
}

void ARManager::_bindTimerout()
{
    setBindTimeout(true);
    setBinding(false);
}

void ARManager::_pollDoodleInfo()  // pool loop
{
    if (_doodlePollingStopped) {
        return;
    }
    if (_doodleRequestInFlight) {
        return;
    }

    // Doodle hardware is mutually exclusive with Enpulse M1, Enpulse M2, and
    // Rajant on the same LAN. If any of those links has already come up, stop
    // wasting HTTPS attempts trying to log in to a Doodle that isn't there.
    //   - Enpulse M1 is active when our own ARConnection reports connected
    //     while _usingDoodleApi is still false (shared _connected flag).
    //   - M2 and Rajant are owned by CustomPlugin, so we ask the plugin.
    if (_connected && !_usingDoodleApi) {
        _stopDoodlePolling("Enpulse M1 connected");
        return;
    }
    if (CustomPlugin* plugin = dynamic_cast<CustomPlugin*>(_toolbox->corePlugin())) {
        if (plugin->m2Manager() != nullptr) {
            _stopDoodlePolling("Enpulse M2 connected");
            return;
        }
        if (plugin->rajantManager() != nullptr) {
            _stopDoodlePolling("Rajant connected");
            return;
        }
    }

    if (_rpcSession.isEmpty()) {
        _requestDoodleLogin();
    }
    else {
        _requestDoodleRadioInfo();
    }
}

void ARManager::_stopDoodlePolling(const char* reason)
{
    if (_doodlePollingStopped) return;
    _doodlePollingStopped = true;
    _doodlePollTimer.stop();
    qCInfo(ARManagerLog) << "[Doodle API] polling stopped:" << (reason ? reason : "");
}

void ARManager::_requestDoodleLogin()  // ubus login
{
    const QUrl url(QString("https://%1/ubus/").arg(_doodleDeviceIP));
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setTransferTimeout(800);

    QSslConfiguration sslConfiguration = request.sslConfiguration();
    sslConfiguration.setPeerVerifyMode(QSslSocket::VerifyNone);
    request.setSslConfiguration(sslConfiguration);

    const QJsonObject body{
        { "jsonrpc", "2.0" },
        { "id", 1 },
        { "method", "call" },
        { "params", QJsonArray{
            "00000000000000000000000000000000",
            "session",
            "login",
            QJsonObject{
                { "username", "user" },
                { "password", "DoodleSmartRadio" }
            }
        } }
    };

    QNetworkReply* reply = _networkManager->post(request, QJsonDocument(body).toJson(QJsonDocument::Compact));
    reply->setProperty("doodleOp", "login");
    reply->ignoreSslErrors();
    _doodleRequestInFlight = true;
}

void ARManager::_requestDoodleRadioInfo()   // batched info request
{
    const QUrl url(QString("https://%1/ubus/").arg(_doodleDeviceIP));
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setTransferTimeout(800);

    QSslConfiguration sslConfiguration = request.sslConfiguration();
    sslConfiguration.setPeerVerifyMode(QSslSocket::VerifyNone);
    request.setSslConfiguration(sslConfiguration);

    const QJsonArray body{
        QJsonObject{
            { "jsonrpc", "2.0" },
            { "id", 1 },
            { "method", "call" },
            { "params", QJsonArray{
                _rpcSession,
                "iwinfo",
                "info",
                QJsonObject{
                    { "device", "wlan0" }
                }
            } }
        },
        QJsonObject{
            { "jsonrpc", "2.0" },
            { "id", 2 },
            { "method", "call" },
            { "params", QJsonArray{
                _rpcSession,
                "iwinfo",
                "assoclist",
                QJsonObject{
                    { "device", "wlan0" }
                }
            } }
        }
    };

    QNetworkReply* reply = _networkManager->post(request, QJsonDocument(body).toJson(QJsonDocument::Compact));
    reply->setProperty("doodleOp", "info");
    reply->ignoreSslErrors();
    _doodleRequestInFlight = true;
}

void ARManager::_handleDoodleReply(QNetworkReply* reply)  // response processing
{
    const QString operation = reply->property("doodleOp").toString();
    const QByteArray payload = reply->readAll();
    _doodleRequestInFlight = false;

    //if (!payload.isEmpty()) {
    //    qInfo().noquote() << QStringLiteral("[Doodle API][%1] %2")
    //        .arg(operation, QString::fromUtf8(payload));
    //}

    if (reply->error() != QNetworkReply::NoError) {
        qCWarning(ARManagerLog) << "[Doodle API]" << operation << "failed:" << reply->errorString();
        if (operation == "login" || operation == "info") {
            _rpcSession.clear();
            _setMountedFromDoodle(false);
            if (_usingDoodleApi) {
                setConnected(false);
            }
        }
        reply->deleteLater();
        return;
    }

    if (operation == "login") {
        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(payload, &parseError);
        if (parseError.error == QJsonParseError::NoError && document.isObject()) {
            const QJsonArray result = document.object().value("result").toArray();
            if (result.count() > 1 && result.at(1).isObject()) {
                const QString token = result.at(1).toObject().value("ubus_rpc_session").toString();
                if (!token.isEmpty()) {
                    qCInfo(ARManagerLog) << "[Doodle API] login success, token acquired";
                    _rpcSession = token;
                    _usingDoodleApi = true;
                    _setMountedFromDoodle(true);
                    _requestDoodleRadioInfo();
                }
            }
        }
    }
    else if (operation == "info") {
        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(payload, &parseError);
        if (parseError.error == QJsonParseError::NoError && document.isArray()) {
            const QJsonArray responses = document.array();
            if (responses.count() >= 2) {
                const QJsonArray infoResult = responses.at(0).toObject().value("result").toArray();
                const QJsonArray assocResult = responses.at(1).toObject().value("result").toArray();
                if (infoResult.count() > 1 && infoResult.at(1).isObject()) {
                    const QJsonObject infoObject = infoResult.at(1).toObject();
                    QJsonArray peers;
                    if (assocResult.count() > 1 && assocResult.at(1).isObject()) {
                        peers = assocResult.at(1).toObject().value("results").toArray();
                    }

                    const int localSignalRaw = jsonObjectInt(infoObject, _signal);
                    const int localNoiseRaw = jsonObjectInt(infoObject, _noise);
                    const QJsonArray localSignalAnts = jsonObjectArray(infoObject, "signal_ants");
                    const int localRssiA = localSignalAnts.count() > 0
                        ? rawSignalToMagnitude(jsonIntValue(localSignalAnts.at(0), localSignalRaw))
                        : rawSignalToMagnitude(localSignalRaw);
                    const int localRssiB = localSignalAnts.count() > 1
                        ? rawSignalToMagnitude(jsonIntValue(localSignalAnts.at(1), localSignalRaw))
                        : rawSignalToMagnitude(localSignalRaw);

                    int peerSignalRaw = 0;
                    int peerSignalAvgRaw = 0;
                    int peerNoiseRaw = 0;
                    int peerRxRate = 0;
                    int peerTxRate = 0;
                    int peerRssiA = 0;
                    int peerRssiB = 0;

                    // Find most active peer (skip stale > 5s)
                    QJsonObject activePeer;
                    bool hasActivePeer = false;
                    for (int i = 0; i < peers.count(); ++i) {
                        if (!peers.at(i).isObject()) continue;
                        const QJsonObject p = peers.at(i).toObject();
                        const int inactive = jsonObjectInt(p, "inactive");
                        if (inactive > 5000) continue;
                        if (!hasActivePeer || inactive < jsonObjectInt(activePeer, "inactive")) {
                            activePeer = p;
                            hasActivePeer = true;
                        }
                    }
                    if (hasActivePeer) {
                        const QJsonArray peerSignalAnts = jsonObjectArray(activePeer, "signal_ants");
                        peerSignalRaw = jsonObjectInt(activePeer, _signal);
                        peerSignalAvgRaw = jsonObjectInt(activePeer, "signal_avg");
                        peerNoiseRaw = jsonObjectInt(activePeer, _noise);
                        peerRxRate = jsonObjectInt(activePeer, "rx.rate", jsonNestedInt(activePeer, "rx", "rate"));
                        peerTxRate = jsonObjectInt(activePeer, "tx.rate", jsonNestedInt(activePeer, "tx", "rate"));
                        peerRssiA = peerSignalAnts.count() > 0
                            ? rawSignalToMagnitude(jsonIntValue(peerSignalAnts.at(0), peerSignalRaw))
                            : rawSignalToMagnitude(peerSignalRaw);
                        peerRssiB = peerSignalAnts.count() > 1
                            ? rawSignalToMagnitude(jsonIntValue(peerSignalAnts.at(1), peerSignalRaw))
                            : rawSignalToMagnitude(peerSignalRaw);
                    }

                    _jsonObject[_bbConn] = hasActivePeer ? 1 : 0;
                    _jsonObject[_aRssi] = localRssiA;
                    _jsonObject[_bRssi] = localRssiB;
                    _jsonObject[_aPeerSlotRssi] = peerRssiA;
                    _jsonObject[_bPeerSlotRssi] = peerRssiB;
                    _jsonObject[_snr] = snrFromSignalAndNoise(localSignalRaw, localNoiseRaw);
                    _jsonObject[_peerSlotSnr] = snrFromSignalAndNoise(peerSignalRaw, peerNoiseRaw);
                    _jsonObject[_slotTxBitRate] = jsonObjectInt(infoObject, _bitrate);
                    _jsonObject[_targetBitRate] = peerRxRate > 0 ? peerRxRate : peerTxRate;
                    _jsonObject[_slotTxFreq] = jsonObjectInt(infoObject, _frequency);
                    _jsonObject[_slotRxFreq] = jsonObjectInt(infoObject, _frequency);
                    _jsonObject[_brFreq] = jsonObjectInt(infoObject, _frequency);
                    _jsonObject[_peerBrRssi0] = rawSignalToMagnitude(peerSignalRaw);
                    _jsonObject[_peerBrRssi1] = rawSignalToMagnitude(peerSignalAvgRaw != 0 ? peerSignalAvgRaw : peerSignalRaw);
                    _jsonObject[_peerBrSnr] = peerSignalAvgRaw != 0
                        ? snrFromSignalAndNoise(peerSignalAvgRaw, peerNoiseRaw)
                        : snrFromSignalAndNoise(peerSignalRaw, peerNoiseRaw);
                    _jsonObject[_mcs] = 0;
                    _jsonObject[_peerSlotMcs] = 0;
                    _jsonObject[_is24G] = jsonObjectInt(infoObject, _frequency) < 3000 ? 1 : 0;
                    _jsonObject[_apiVersion] = QStringLiteral("DoodleLabs ubus");
                    _jsonObject[_selfTemperature] = 0;
                    _jsonObject[_skyTemperature] = 0;

                    _usingDoodleApi = true;
                    _setMountedFromDoodle(true);
                    setConnected(hasActivePeer);
                    //qInfo() << "[Doodle API] info parsed"
                    //    << "localSignalRaw:" << localSignalRaw
                    //    << "localNoiseRaw:" << localNoiseRaw
                    //    << "peerSignalRaw:" << peerSignalRaw
                    //    << "peerSignalAvgRaw:" << peerSignalAvgRaw
                    //    << "peerNoiseRaw:" << peerNoiseRaw
                    //    << "peerCount:" << peers.count()
                    //    << "connected:" << connected();
                    if (connected() && _bindTimer.isActive() && (_bindTimer.remainingTime() < (_bindTimer.interval() - 15000))) {
                        _bindTimer.stop();
                        setBindTimeout(false);
                        setBinding(false);
                    }
                    emit rssiChanged();
                }
            }
        }
    }

    reply->deleteLater();
}

void ARManager::_handleLegacyMountedChanged(bool mounted)
{
    if (_usingDoodleApi) {
        return;
    }

    setMounted(mounted);
}

void ARManager::_setMountedFromDoodle(bool mounted)
{
    if (!mounted && !_usingDoodleApi) {
        return;
    }

    setMounted(mounted);
}

// void ARManager::_handle_osd_info(const QByteArray& message)
// {
//     float vtSnr = osd_info.snr_value[1];

//     int vtScore = static_cast<int>(3.52f * vtSnr + 19.057f);
//     if (vtScore > 100)
//         vtScore = 100;
//     if (osd_info.errcnt1 >= 55) {
//         vtScore -= 55;
//     } else if (osd_info.errcnt1 >= 50 && osd_info.errcnt1 < 55) {
//         vtScore -= 50;
//     } else if (osd_info.errcnt1 >= 45 && osd_info.errcnt1 < 50) {
//         vtScore -= 40;
//     } else if (osd_info.errcnt1 >= 40 && osd_info.errcnt1 < 45) {
//         vtScore -= 40;
//     } else if (osd_info.errcnt1 >= 35 && osd_info.errcnt1 < 40) {
//         vtScore -= 30;
//     } else if (osd_info.errcnt1 >= 30 && osd_info.errcnt1 < 35) {
//         vtScore -= 30;
//     } else if (osd_info.errcnt1 >= 25 && osd_info.errcnt1 < 30) {
//         vtScore -= 20;
//     } else if (osd_info.errcnt1 >= 20 && osd_info.errcnt1 < 25) {
//         vtScore -= 20;
//     } else if (osd_info.errcnt1 >= 15 && osd_info.errcnt1 < 20) {
//         vtScore -= 10;
//     } else if (osd_info.errcnt1 >= 10 && osd_info.errcnt1 < 15) {
//         vtScore -= 10;
//     } else if (osd_info.errcnt1 >= 5 && osd_info.errcnt1 < 10) {
//         vtScore -= 5;
//     } else if (osd_info.errcnt1 > 0 && osd_info.errcnt1 < 5) {
//         vtScore -= 2;
//     }
//     if (vtScore <= 0)
//         vtScore = 2;
//     if(osd_info.lock_status == 0) {
//         vtScore = 0;
//         setConnected(false);
//     } else {
//         setConnected(true);
//     }

//     setRssi(vtScore);
//     if(_binding && _connected) {
//         setBinding(false);
//     }
//     if(_connected && _pairTimer.isActive()) {
//         _pairTimer.stop();
//     }
//     setDistance(osd_info.dist_value);
// }
