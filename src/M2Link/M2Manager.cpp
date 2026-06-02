#include "M2Manager.h"
#include "JsonHelper.h"
#include <QQmlEngine>
#include <QJsonDocument>
#include <QNetworkInterface>
#include <QHostAddress>
#include <QTimer>
#include <QJsonArray>

const char* M2Manager::_kSsid = "ssid";
const char* M2Manager::_kFreq = "freq";
const char* M2Manager::_kRssi = "rssi";
const char* M2Manager::_kLinkspeed = "linkspeed";
const char* M2Manager::_kRssiA = "bb_rssi_a";
const char* M2Manager::_kRssiB = "bb_rssi_b";
const char* M2Manager::_kCpuTemp = "cpu_temp";
const char* M2Manager::_kRfTemp = "rf_temp";
const char* M2Manager::_kConnected = "connected";
const char* M2Manager::_kBindStatus = "bind_status";
const char* M2Manager::_kMode = "mode";
const char* M2Manager::_kVersion = "version";
const char* M2Manager::_kSuccess = "success";
const char* M2Manager::_kInfos = "infos";
const char* M2Manager::_kChannel = "channel";
const char* M2Manager::_kQuality = "quality";
const char* M2Manager::_kId = "id";

M2Manager::M2Manager(QString deviceIP, QObject* parent)
    : QObject(parent)
    , _deviceIP(deviceIP)
{
    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
    // 生成 skyDeviceIP (主机地址+1)
    QHostAddress hostAddress(deviceIP);
    if(deviceIP.compare("192.168.4.1") == 0) {
        _skyDeviceIP = "192.168.2.1";
    } else if(deviceIP.compare("192.168.2.103") == 0) {
        _skyDeviceIP = "192.168.2.101";
    } else {
        quint32 ipv4 = hostAddress.toIPv4Address();
        _skyDeviceIP = QHostAddress(ipv4 + 1).toString();
    }

    _networkManager = new QNetworkAccessManager(this);
    
    // 初始化并启动定时器
    _pollTimer = new QTimer(this);
    connect(_pollTimer, &QTimer::timeout, this, &M2Manager::_pollInfo);
    connect(_networkManager, &QNetworkAccessManager::finished, this, &M2Manager::_handleNetworkReply);
    _pollTimer->start(_pollInterval);
}

M2Manager::~M2Manager()
{
}

int M2Manager::findChannelIndexByFreq()
{
    int currentFreq = freq().toInt();
    for(int i = 0; i < _scanedChannels.count(); i++) {
        ChannelInfo* channel = qobject_cast<ChannelInfo*>(_scanedChannels.get(i));
        if(channel && channel->freq() == currentFreq) {
            return i;
        }
    }
    return -1;
}

void M2Manager::pair()
{
    QUrl url("http://" + _deviceIP + ":" + QString::number(_port) + "/wps");
    QNetworkRequest request(url);
    _networkManager->get(request);
}

void M2Manager::scan()
{
    _scanedChannels.clearAndDeleteContents();
    _skyScanedChannels.clearAndDeleteContents();
    QUrl url("http://" + _deviceIP + ":" + QString::number(_port) + "/scan");
    QNetworkRequest request(url);
    _networkManager->get(request);
    if(connected()) {
        QUrl url("http://" + _skyDeviceIP + ":" + QString::number(_port) + "/scan");
        QNetworkRequest request(url);
        _networkManager->get(request);
    }
    setScanning(true);
}

void M2Manager::setChannel(int channel)
{
    QUrl url("http://" + _deviceIP + ":" + QString::number(_port) + "/set?name=channel_id&int_value=" + QString::number(channel));
    QNetworkRequest request(url);
    _networkManager->get(request);
}

void M2Manager::reboot(bool reset)
{
    QUrl url("http://" + _deviceIP + ":" + QString::number(_port) + "/reboot?reset=" + QString::number(reset));
    QNetworkRequest request(url);
    _networkManager->get(request);
}

void M2Manager::rebootSky(bool reset)
{
    QUrl url("http://" + _skyDeviceIP + ":" + QString::number(_port) + "/reboot?reset=" + QString::number(reset));
    QNetworkRequest request(url);
    _networkManager->get(request);
}

void M2Manager::_handle_info(const QByteArray& message)
{
    if(message.size() != 0) {
        QString errorString;
        QJsonParseError jsonParseError;
        QJsonDocument doc = QJsonDocument::fromJson(message, &jsonParseError);
        if (doc.isObject()) {
            QJsonObject jsonObject = doc.object();
            QList<JsonHelper::KeyValidateInfo> keyInfoList = {
                { _kSsid,       QJsonValue::String, true },
                { _kFreq,       QJsonValue::Double, true },
                { _kRssi,       QJsonValue::Double, true },
                { _kLinkspeed,  QJsonValue::Double, true },
                { _kRssiA,      QJsonValue::Double, true },
                { _kRssiB,      QJsonValue::Double, true },
                { _kCpuTemp,    QJsonValue::Double, true },
                { _kRfTemp,     QJsonValue::Double, true },
                { _kConnected,  QJsonValue::Bool, true },
                { _kBindStatus, QJsonValue::Bool, true },
                { _kMode,       QJsonValue::String, true },
                { _kVersion,    QJsonValue::String, true }
            };
            if (!JsonHelper::validateKeys(jsonObject, keyInfoList, errorString)) {
                qWarning() << errorString;
                qInfo() << QString(message);
            } else {
                if(jsonObject[_kMode].toString().startsWith("DEV")) {
                    _skyJsonObject = jsonObject;
                    if(_skyJsonObject[_kRssi].toInt() == 0) {
                        _skyJsonObject[_kRssi] = qMax(_skyJsonObject[_kRssiA].toInt(), _skyJsonObject[_kRssiB].toInt());
                    }
                    emit skyInfoChanged();
                } else {
                    setConnected(jsonObject[_kConnected].toBool());
                    setBinding(jsonObject[_kBindStatus].toBool());
                    if(_scanedChannels.count()) {
                        setFreqIndex(findChannelIndexByFreq());
                    }
                    _jsonObject = jsonObject;
                    if(_jsonObject[_kRssi].toInt() == 0) {
                        _jsonObject[_kRssi] = qMax(_jsonObject[_kRssiA].toInt(), _jsonObject[_kRssiB].toInt());
                    }
                    emit infoChanged();
                    if (connected()) {
                        _pollSkyInfo();
                    }
                }
            }
        }
    }
}

void M2Manager::_handle_scan(const QByteArray& message)
{
    if(message.size() != 0) {
        QString errorString;
        QJsonParseError jsonParseError;
        QJsonDocument doc = QJsonDocument::fromJson(message, &jsonParseError);
        if (doc.isObject()) {
            QJsonObject jsonObject = doc.object();
            QList<JsonHelper::KeyValidateInfo> keyInfoList = {
                { _kMode,       QJsonValue::String, true },
                { _kSuccess,    QJsonValue::Bool, true },
                { _kInfos,      QJsonValue::Array, true }
            };
            if (!JsonHelper::validateKeys(jsonObject, keyInfoList, errorString)) {
                qWarning() << errorString;
                qInfo() << QString(message);
            } else if(jsonObject[_kInfos].isArray()) {
                QObjectList swaplist;
                foreach(QJsonValue channelValue, jsonObject[_kInfos].toArray()) {
                    if(channelValue.isObject()) {
                        QJsonObject channelObject = channelValue.toObject();
                        QList<JsonHelper::KeyValidateInfo> keysList = {
                                { _kChannel,   QJsonValue::Double, true },
                                { _kQuality,   QJsonValue::Double, true },
                                { _kFreq,      QJsonValue::Double, true },
                                { _kId,        QJsonValue::Double, true }
                        };
                        if (!JsonHelper::validateKeys(channelObject, keysList, errorString)) {
                            qWarning() << errorString;
                            qInfo() << QString(message);
                        } else {
                            swaplist.append(new ChannelInfo(channelObject[_kChannel].toInt(), channelObject[_kQuality].toInt(), channelObject[_kFreq].toInt(), channelObject[_kId].toInt()));
                        }
                    }
                }
                QObjectList oldlist;
                if(jsonObject[_kMode].toString().startsWith("DEV")) {
                    oldlist = _skyScanedChannels.swapObjectList(swaplist);
                } else {
                    oldlist = _scanedChannels.swapObjectList(swaplist);
                    setFreqIndex(findChannelIndexByFreq());
                    setScanning(false);
                }
                foreach(QObject *obj, oldlist) {
                    obj->deleteLater();
                }
            }
        }
    }
}

void M2Manager::_pollInfo()
{
    if (!_mounted && !_connected) {
        // Don't poll if we've never successfully connected
        // This prevents QIODevice::read spam when no M2 device is present
        static int skipCount = 0;
        if (++skipCount < 10) return; // only try every 10th poll (10 seconds)
        skipCount = 0;
    }
    QUrl url(QString("http://%1:%2/wifi_info").arg(_deviceIP).arg(_port));
    QNetworkRequest request(url);
    request.setTransferTimeout(400);
    _networkManager->get(request);
}

void M2Manager::_pollSkyInfo()
{
    QUrl url(QString("http://%1:%2/wifi_info").arg(_skyDeviceIP).arg(_port));
    QNetworkRequest request(url);
    request.setTransferTimeout(400);
    _networkManager->get(request);
}

void M2Manager::_handleNetworkReply(QNetworkReply* reply)
{
    if (reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();
        
        // 获取请求的URL
        QString urlPath = reply->url().path();
        
        // 根据不同的URL路径处理响应
        if (urlPath == "/wifi_info") {
            if(reply->url().host().contains(_deviceIP)) setMounted(true);
            _handle_info(data);
        } else if (urlPath == "/wps") {
            setBinding(true);
        } else if (urlPath == "/scan") {
            _handle_scan(data);
        }
    } else {
        // 请求失败处理
        if (reply->url().path() == "/wifi_info" && reply->url().host().contains(_deviceIP)) {
            setMounted(false);
        }
        qWarning() << "Network request failed:" << reply->errorString();
    }
    
    reply->deleteLater();
}
