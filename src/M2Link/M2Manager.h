#pragma once
#include <QThread>
#include <QJsonObject>
#include "QGCToolbox.h"
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QTimer>
#include <QColor>
#include "QmlObjectListModel.h"

class ChannelInfo : public QObject
{
    Q_OBJECT
public:
    ChannelInfo(int channel, int quality, int freq, int id)
        : _channel(channel)
        , _quality(quality)
        , _freq(freq)
        , _id(id)
    {
        _color = signalQualityColor();
    }
    Q_PROPERTY(int channel   READ channel          CONSTANT)
    Q_PROPERTY(int quality   READ quality          CONSTANT)
    Q_PROPERTY(int freq      READ freq             CONSTANT)
    Q_PROPERTY(int id        READ id               CONSTANT)
    Q_PROPERTY(QColor color  READ color            CONSTANT)

    int channel() { return _channel; }
    int quality() { return _quality; }
    int freq() { return _freq; }
    int id() { return _id; }
    QColor color() { return _color; }

    QColor signalQualityColor() const {
        int red = 255 * (100 - _quality) / 100;
        int green = 255 * _quality / 100;
        return QColor(red, green, 0);
    }

private:
    const int _channel;
    const int _quality;
    const int _freq;
    const int _id;
    QColor _color;
};

class M2Manager : public QObject
{
    Q_OBJECT
public:
    Q_PROPERTY(int      freqIndex       READ freqIndex      WRITE setFreqIndex      NOTIFY freqIndexChanged)
    Q_PROPERTY(bool     mounted         READ mounted        WRITE setMounted        NOTIFY mountedChanged)
    Q_PROPERTY(bool     connected       READ connected      WRITE setConnected      NOTIFY connectedChanged)
    Q_PROPERTY(bool     binding         READ binding        WRITE setBinding        NOTIFY bindingChanged)
    Q_PROPERTY(bool     scanning        READ scanning       WRITE setScanning       NOTIFY scanningChanged)
    int                 freqIndex()     { return _freqIndex; }
    bool                mounted()       { return _mounted; }
    bool                connected()     { return _connected; }
    bool                binding()       { return _binding; }
    bool                scanning()      { return _scanning; }

    Q_PROPERTY(QVariant ssid           READ ssid          NOTIFY infoChanged)
    Q_PROPERTY(QVariant freq           READ freq          NOTIFY infoChanged)
    Q_PROPERTY(QVariant rssi           READ rssi          NOTIFY infoChanged)
    Q_PROPERTY(QVariant linkspeed      READ linkspeed     NOTIFY infoChanged)
    Q_PROPERTY(QVariant rssiA          READ rssiA         NOTIFY infoChanged)
    Q_PROPERTY(QVariant rssiB          READ rssiB         NOTIFY infoChanged)
    Q_PROPERTY(QVariant cpuTemp        READ cpuTemp       NOTIFY infoChanged)
    Q_PROPERTY(QVariant rfTemp         READ rfTemp        NOTIFY infoChanged)
    Q_PROPERTY(QVariant version        READ version       NOTIFY infoChanged)

    Q_PROPERTY(QVariant skyFreq        READ skyFreq       NOTIFY skyInfoChanged)
    Q_PROPERTY(QVariant skyRssi        READ skyRssi       NOTIFY skyInfoChanged)
    Q_PROPERTY(QVariant skyLinkspeed   READ skyLinkspeed  NOTIFY skyInfoChanged)
    Q_PROPERTY(QVariant skyRssiA       READ skyRssiA      NOTIFY skyInfoChanged)
    Q_PROPERTY(QVariant skyRssiB       READ skyRssiB      NOTIFY skyInfoChanged)
    Q_PROPERTY(QVariant skyCpuTemp     READ skyCpuTemp    NOTIFY skyInfoChanged)
    Q_PROPERTY(QVariant skyRfTemp      READ skyRfTemp     NOTIFY skyInfoChanged)
    Q_PROPERTY(QVariant skyVersion     READ skyVersion    NOTIFY skyInfoChanged)

    Q_PROPERTY(QmlObjectListModel* scanedChannels     READ scanedChannels     CONSTANT)
    Q_PROPERTY(QmlObjectListModel* skyScanedChannels  READ skyScanedChannels  CONSTANT)

    QVariant ssid()         { return _jsonObject[_kSsid].toVariant(); }
    QVariant freq()         { return _jsonObject[_kFreq].toVariant(); }
    QVariant rssi()         { return _jsonObject[_kRssi].toVariant(); }
    QVariant linkspeed()    { return _jsonObject[_kLinkspeed].toVariant(); }
    QVariant rssiA()        { return _jsonObject[_kRssiA].toVariant(); }
    QVariant rssiB()        { return _jsonObject[_kRssiB].toVariant(); }
    QVariant cpuTemp()      { return _jsonObject[_kCpuTemp].toVariant(); }
    QVariant rfTemp()       { return _jsonObject[_kRfTemp].toVariant(); }
    QVariant version()      { return _jsonObject[_kVersion].toVariant(); }

    QVariant skyFreq()      { return _skyJsonObject[_kFreq].toVariant(); }
    QVariant skyRssi()     { return _skyJsonObject[_kRssi].toVariant(); }
    QVariant skyLinkspeed() { return _skyJsonObject[_kLinkspeed].toVariant(); }
    QVariant skyRssiA()    { return _skyJsonObject[_kRssiA].toVariant(); }
    QVariant skyRssiB()    { return _skyJsonObject[_kRssiB].toVariant(); }
    QVariant skyCpuTemp()  { return _skyJsonObject[_kCpuTemp].toVariant(); }
    QVariant skyRfTemp()   { return _skyJsonObject[_kRfTemp].toVariant(); }
    QVariant skyVersion()  { return _skyJsonObject[_kVersion].toVariant(); }

    QmlObjectListModel* scanedChannels()     { return &_scanedChannels; }
    QmlObjectListModel* skyScanedChannels()  { return &_skyScanedChannels; }

    void                setFreqIndex(int freqIndex)    { if (freqIndex != _freqIndex) { _freqIndex = freqIndex; emit freqIndexChanged(); } }
    void                setMounted(bool mounted)        { if (mounted != _mounted) { _mounted = mounted; emit mountedChanged(); } }
    void                setConnected(bool connected)    { if (connected != _connected) { _connected = connected; emit connectedChanged(); } }
    void                setBinding(bool binding)        { if (binding != _binding) { _binding = binding; emit bindingChanged(); } }
    void                setScanning(bool scanning)      { if (scanning != _scanning) { _scanning = scanning; emit scanningChanged(); } }

    M2Manager(QString deviceIP, QObject* parent = nullptr);
    ~M2Manager() override;

    QString deviceIP() const { return _deviceIP; }

    Q_INVOKABLE void pair();
    Q_INVOKABLE void scan();
    Q_INVOKABLE void setChannel(int channel);
    Q_INVOKABLE void reboot(bool reset = false);
    Q_INVOKABLE void rebootSky(bool reset = false);

signals:
    void                mountedChanged();
    void                connectedChanged();
    void                bindingChanged();
    void                infoChanged();
    void                skyInfoChanged();
    void                freqIndexChanged();
    void                scanningChanged();
private slots:
    void _pollInfo();
    void _handleNetworkReply(QNetworkReply* reply);
    void _pollSkyInfo();

private:
    int findChannelIndexByFreq();
    void _handle_info(const QByteArray& message);
    void _handle_scan(const QByteArray& message);

    bool                _mounted{false};
    bool                _connected{false};
    bool                _binding{false};
    int                 _freqIndex{0};
    bool                _scanning{false};

    QmlObjectListModel _scanedChannels;
    QmlObjectListModel _skyScanedChannels;
    QJsonObject _jsonObject;
    QJsonObject _skyJsonObject;
    QString _deviceIP;
    QString _skyDeviceIP;
    uint16_t _port{8000};

    static const char* _kSsid;
    static const char* _kFreq;
    static const char* _kRssi;
    static const char* _kLinkspeed;
    static const char* _kRssiA;
    static const char* _kRssiB;
    static const char* _kCpuTemp;
    static const char* _kRfTemp;
    static const char* _kConnected;
    static const char* _kBindStatus;
    static const char* _kMode;
    static const char* _kVersion;

    static const char* _kSuccess;
    static const char* _kInfos;
    static const char* _kChannel;
    static const char* _kQuality;
    static const char* _kId;

    QNetworkAccessManager* _networkManager{nullptr};
    QTimer* _pollTimer{nullptr};
    static const int _pollInterval{1000};
};
