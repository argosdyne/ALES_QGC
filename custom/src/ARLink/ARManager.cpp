#include "ARManager.h"
#include "JsonHelper.h"
#include <QQmlEngine>
#include <QJsonDocument>
#include <QNetworkInterface>
#include <QHostAddress>

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
        qWarning() << "Set Link Default IP:" << ipStr;
    } else {
        _auto = true;
        qInfo() << "Get Link IP:" << ipStr;
    }
    _deviceIP = ipStr;
    _connection = new ARConnection(ipStr);
    // _connection->moveToThread(&workerThread);
    // connect(&workerThread, &QThread::finished, _connection, &QObject::deleteLater);
    // workerThread.start();

    setMounted(_connection->isConnected());
    connect(_connection, &ARConnection::isConnectedChanged, this, &ARManager::setMounted);
    connect(_connection, &ARConnection::receivedMessage, this, &ARManager::_received_message);

    _bindTimer.setSingleShot(true);
    _bindTimer.setInterval(140000);
    connect(&_bindTimer, &QTimer::timeout, this, &ARManager::_bindTimerout);
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
#if !defined (Q_OS_ANDROID)
    if(_auto)
#endif
    emit _connection->enable();
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
                qWarning() << errorString;
                qInfo() << QString(message);
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
