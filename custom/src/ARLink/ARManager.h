#pragma once
#include <QThread>
#include <QJsonObject>
#include <QNetworkAccessManager>     // http client
#include <QNetworkReply>             // response object
#include <QTimer>                    // loop/pooling
#include "QGCToolbox.h"
#include "ARConnection.h"

class ARManager : public QGCTool
{
    Q_OBJECT
public:
    Q_PROPERTY(bool     mounted         READ mounted        WRITE setMounted        NOTIFY mountedChanged)
    Q_PROPERTY(bool     connected       READ connected      WRITE setConnected      NOTIFY connectedChanged)
    Q_PROPERTY(bool     binding         READ binding        WRITE setBinding        NOTIFY bindingChanged)
    Q_PROPERTY(bool     bindTimeout     READ bindTimeout    WRITE setBindTimeout    NOTIFY bindTimeoutChanged)
    bool                mounted()       { return _mounted; }
    bool                connected()     { return _connected; }
    bool                binding()       { return _binding; }
    bool                bindTimeout()   { return _bindTimeout; }
    bool                 usingDoodleApi() const { return _usingDoodleApi; }

    Q_PROPERTY(QVariant rssiA           READ rssiA          NOTIFY rssiChanged)
    Q_PROPERTY(QVariant rssiB           READ rssiB          NOTIFY rssiChanged)
    Q_PROPERTY(QVariant snr             READ snr            NOTIFY rssiChanged)
    Q_PROPERTY(QVariant mcs             READ mcs            NOTIFY rssiChanged)

    Q_PROPERTY(QVariant skyRssiA        READ skyRssiA       NOTIFY rssiChanged)
    Q_PROPERTY(QVariant skyRssiB        READ skyRssiB       NOTIFY rssiChanged)
    Q_PROPERTY(QVariant skySnr          READ skySnr         NOTIFY rssiChanged)
    Q_PROPERTY(QVariant skyMcs          READ skyMcs         NOTIFY rssiChanged)

    Q_PROPERTY(QVariant brRssiA         READ brRssiA        NOTIFY rssiChanged)
    Q_PROPERTY(QVariant brRssiB         READ brRssiB        NOTIFY rssiChanged)
    Q_PROPERTY(QVariant brSnr           READ brSnr          NOTIFY rssiChanged)

    Q_PROPERTY(QVariant rxFrequency     READ rxFrequency    NOTIFY rssiChanged)
    Q_PROPERTY(QVariant txFrequency     READ txFrequency    NOTIFY rssiChanged)
    Q_PROPERTY(QVariant brFrequency     READ brFrequency    NOTIFY rssiChanged)

    Q_PROPERTY(QVariant upRate          READ upRate         NOTIFY rssiChanged)
    Q_PROPERTY(QVariant flow            READ flow           NOTIFY rssiChanged)

    Q_PROPERTY(QVariant is24G           READ is24G          NOTIFY rssiChanged)
    Q_PROPERTY(QVariant version         READ version        NOTIFY rssiChanged)
    Q_PROPERTY(QVariant temperature     READ temperature    NOTIFY rssiChanged)
    Q_PROPERTY(QVariant skyTemperature  READ skyTemperature NOTIFY rssiChanged)

    QVariant rssiA()         { return _jsonObject[_aRssi].toVariant(); }
    QVariant rssiB()         { return _jsonObject[_bRssi].toVariant(); }
    QVariant snr()           { return _jsonObject[_snr].toVariant(); }
    QVariant mcs()           { return _jsonObject[_mcs].toVariant(); }

    QVariant skyRssiA()      { return _jsonObject[_aPeerSlotRssi].toVariant(); }
    QVariant skyRssiB()      { return _jsonObject[_bPeerSlotRssi].toVariant(); }
    QVariant skySnr()        { return _jsonObject[_peerSlotSnr].toVariant(); }
    QVariant skyMcs()        { return _jsonObject[_peerSlotMcs].toVariant(); }

    QVariant brRssiA()       { return _jsonObject[_peerBrRssi0].toVariant(); }
    QVariant brRssiB()       { return _jsonObject[_peerBrRssi1].toVariant(); }
    QVariant brSnr()         { return _jsonObject[_peerBrSnr].toVariant(); }

    QVariant rxFrequency()   { return _jsonObject[_slotRxFreq].toVariant(); }
    QVariant txFrequency()   { return _jsonObject[_slotTxFreq].toVariant(); }
    QVariant brFrequency()   { return _jsonObject[_brFreq].toVariant(); }

    QVariant upRate()        { return _jsonObject[_slotTxBitRate].toVariant(); }
    QVariant flow()          { return _jsonObject[_targetBitRate].toVariant(); }

    QVariant is24G()         { return _jsonObject[_is24G].toVariant(); }
    QVariant version()       { return _jsonObject[_apiVersion].toVariant(); }
    QVariant temperature()   { return _jsonObject[_selfTemperature].toVariant(); }
    QVariant skyTemperature(){ return _jsonObject[_skyTemperature].toVariant(); }

    void                setMounted(bool mounted)        { if (mounted != _mounted) { _mounted = mounted; emit mountedChanged(); } }
    void                setConnected(bool connected)    { if (connected != _connected) { _connected = connected; emit connectedChanged(); } }
    void                setBinding(bool binding)        { if (binding != _binding) { _binding = binding; emit bindingChanged(); } }
    void                setBindTimeout(bool bindTimeout){ if (bindTimeout != _bindTimeout) { _bindTimeout = bindTimeout; emit bindTimeoutChanged(); } }
    
    ARManager(QGCApplication* app, QGCToolbox* toolbox);
    ~ARManager() override;

    QString deviceIP() const { return _deviceIP; }

    // Override from QGCTool
    void setToolbox(QGCToolbox* toolbox) override;

    Q_INVOKABLE void pair();
    Q_INVOKABLE void restartDevice();
    Q_INVOKABLE void enable24G();
    Q_INVOKABLE void enable58G();
    Q_INVOKABLE void restartRemoteDevice();
    Q_INVOKABLE void enableRemote24G();
    Q_INVOKABLE void enableRemote58G();

    // Permanently stops Doodle API polling. Called when another radio link
    // (Rajant / M2) is detected — avoids continuous failed HTTPS requests
    // that have been observed to cause heap corruption in Qt 5.15.2.
    void stopDoodlePolling(const char* reason);

signals:
    void                mountedChanged();
    void                connectedChanged();
    void                bindingChanged();
    void                bindTimeoutChanged();
    void                rssiChanged();
    void                distanceChanged();
    void                ackFromDevice(quint16 cmd);

private slots:
    void _received_message(quint16 cmd, QByteArray message);
    // Methods
    void _bindTimerout();
    void _pollDoodleInfo();                          // timer callback, decides login vs info request
    void _handleDoodleReply(QNetworkReply* reply);   // prcoess all HTTP responses
    void _handleLegacyMountedChanged(bool mounted);  // Prevents conflicting state updates between old and new systems

private:
    void _handle_device_info(const QByteArray& message);
    void _requestDoodleLogin();                     // sends ubus login post request
    void _requestDoodleRadioInfo();                 // sends request for radio status signal      
    void _setMountedFromDoodle(bool mounted);       // sends api coming result to internal state
    // void _handle_osd_info(const QByteArray& message);

    // variables
    bool                _mounted{false};
    bool                _connected{false};
    bool                _auto{false};
    bool                _binding{false};
    bool                _bindTimeout{false};
    bool                _usingDoodleApi{false};        // falg to indicate doodle api usage
    bool                _doodleRequestInFlight{false}; // prevents overlapping HTTP request
    bool                _doodlePollingStopped{false}; // true once stopDoodlePolling() has been called
    int                 _doodleConsecutiveFailures{0};

    bool                _pairTriggered{false};

    // QThread workerThread;
    ARConnection* _connection{nullptr};
    QJsonObject _jsonObject;
    QTimer _bindTimer;
    QString _deviceIP;
    QNetworkAccessManager* _networkManager{nullptr};  // Core Qt object used to send HTTP network requests
    QTimer _doodlePollTimer;                            // Timer for periodically polling Doodle device status
    QString _doodleDeviceIP;                              // Loaded from settings (default: 192.168.2.72)
    QString _rpcSession;                                // Session/token used for authenticated API communication
            
    static const char* _bbConn;
    static const char* _brFreq;
    static const char* _slotTxFreq;
    static const char* _slotRxFreq;
    static const char* _slotTxBitRate;
    static const char* _targetBitRate;
    static const char* _mcs;
    static const char* _snr;
    static const char* _aRssi;
    static const char* _bRssi;
    static const char* _chan0Power;
    static const char* _chan1Power;
    static const char* _chan2Power;
    static const char* _chan3Power;
    static const char* _chan4Power;
    static const char* _chan5Power;
    static const char* _chan6Power;
    static const char* _aPeerSlotRssi;
    static const char* _bPeerSlotRssi;
    static const char* _peerSlotMcs;
    static const char* _peerSlotSnr;
    static const char* _peerBrRssi0;
    static const char* _peerBrRssi1;
    static const char* _peerBrSnr;
    static const char* _apiVersion;
    static const char* _is24G;
    static const char* _selfTemperature;
    static const char* _skyTemperature;
    static const char* _signal;
    static const char* _noise;
    static const char* _bitrate;
    static const char* _channel;
    static const char* _frequency;
};
