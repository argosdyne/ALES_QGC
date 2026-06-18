/****************************************************************************
 *
 *   (c) 2019 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include "QGCToolbox.h"
#include "QGCLoggingCategory.h"
#include "MicrohardSettings.h"
#include "Fact.h"

#include <QTimer>
#include <QTime>
#include <QMap>
#include <QList>
#include <QUdpSocket>
#include <QtGlobal>

class AppSettings;
class QGCApplication;

//-----------------------------------------------------------------------------
class MicrohardManager : public QGCTool
{
    Q_OBJECT
public:

    Q_PROPERTY(int          connected           READ connected                                  NOTIFY connectedChanged)
    Q_PROPERTY(int          linkConnected       READ linkConnected                              NOTIFY linkConnectedChanged)
    Q_PROPERTY(int          uplinkRSSI          READ uplinkRSSI                                 NOTIFY linkChanged)
    Q_PROPERTY(int          downlinkRSSI        READ downlinkRSSI                               NOTIFY linkChanged)
    Q_PROPERTY(bool         statsConnected      READ statsConnected                             NOTIFY statsChanged)
    Q_PROPERTY(QString      groundRSSI          READ groundRSSI                                 NOTIFY statsChanged)
    Q_PROPERTY(QString      skyRSSI             READ skyRSSI                                    NOTIFY statsChanged)
    Q_PROPERTY(QString      snr                 READ snr                                        NOTIFY statsChanged)
    Q_PROPERTY(QString      txRate              READ txRate                                     NOTIFY statsChanged)
    Q_PROPERTY(QString      rxRate              READ rxRate                                     NOTIFY statsChanged)
    Q_PROPERTY(QString      txThroughput        READ txThroughput                               NOTIFY statsChanged)
    Q_PROPERTY(QString      rxThroughput        READ rxThroughput                               NOTIFY statsChanged)
    Q_PROPERTY(QString      txBytes             READ txBytes                                    NOTIFY statsChanged)
    Q_PROPERTY(QString      rxBytes             READ rxBytes                                    NOTIFY statsChanged)
    Q_PROPERTY(QString      queueLength         READ queueLength                                NOTIFY statsChanged)
    Q_PROPERTY(QString      frequency           READ frequency                                  NOTIFY statsChanged)
    Q_PROPERTY(QString      temperature         READ temperature                                NOTIFY statsChanged)
    Q_PROPERTY(QString      version             READ version                                    NOTIFY statsChanged)
    Q_PROPERTY(QString      mainLink            READ mainLink                                   NOTIFY statsChanged)
    Q_PROPERTY(uint         statsPacketCount    READ statsPacketCount                           NOTIFY statsChanged)
    Q_PROPERTY(uint         masterStatsPacketCount READ masterStatsPacketCount                   NOTIFY statsChanged)
    Q_PROPERTY(uint         slaveStatsPacketCount  READ slaveStatsPacketCount                    NOTIFY statsChanged)
    Q_PROPERTY(QString      statsLastSource     READ statsLastSource                            NOTIFY statsChanged)
    Q_PROPERTY(QString      statsSources        READ statsSources                               NOTIFY statsChanged)
    Q_PROPERTY(QString      statsLastMode       READ statsLastMode                              NOTIFY statsChanged)
    Q_PROPERTY(QString      statsRawText        READ statsRawText                               NOTIFY statsChanged)
    Q_PROPERTY(QString      localIPAddr         READ localIPAddr      WRITE setLocalIPAddr      NOTIFY localIPAddrChanged)
    Q_PROPERTY(QString      remoteIPAddr        READ remoteIPAddr     WRITE setRemoteIPAddr     NOTIFY remoteIPAddrChanged)
    Q_PROPERTY(QString      netMask             READ netMask                                    NOTIFY netMaskChanged)
    Q_PROPERTY(QString      configUserName      READ configUserName                             NOTIFY configUserNameChanged)
    Q_PROPERTY(QString      configPassword      READ configPassword                             NOTIFY configPasswordChanged)
    Q_PROPERTY(QString      encryptionKey       READ encryptionKey                              NOTIFY encryptionKeyChanged)

    Q_INVOKABLE bool setIPSettings              (QString localIP, QString remoteIP, QString netMask, QString cfgUserName, QString cfgPassword, QString encyrptionKey);
    Q_INVOKABLE void refreshStats               ();

    explicit MicrohardManager                   (QGCApplication* app, QGCToolbox* toolbox);
    ~MicrohardManager                           () override;

    void        setToolbox                      (QGCToolbox* toolbox) override;

    int         connected                       () { return _connectedStatus; }
    int         linkConnected                   () { return _linkConnectedStatus; }
    int         uplinkRSSI                      () { return _uplinkRSSI; }
    int         downlinkRSSI                    () { return _downlinkRSSI; }
    bool        statsConnected                  () const { return _statsConnected; }
    QString     groundRSSI                      () const { return _groundRSSI; }
    QString     skyRSSI                         () const { return _skyRSSI; }
    QString     snr                             () const { return _snr; }
    QString     txRate                          () const { return _txRate; }
    QString     rxRate                          () const { return _rxRate; }
    QString     txThroughput                    () const { return _txThroughput; }
    QString     rxThroughput                    () const { return _rxThroughput; }
    QString     txBytes                         () const { return _txBytes; }
    QString     rxBytes                         () const { return _rxBytes; }
    QString     queueLength                     () const { return _queueLength; }
    QString     frequency                       () const { return _frequency; }
    QString     temperature                     () const { return _temperature; }
    QString     version                         () const { return _version; }
    QString     mainLink                        () const { return _mainLink; }
    uint        statsPacketCount                () const { return _statsPacketCount; }
    uint        masterStatsPacketCount          () const { return _masterStatsPacketCount; }
    uint        slaveStatsPacketCount           () const { return _slaveStatsPacketCount; }
    QString     statsLastSource                 () const { return _statsLastSource; }
    QString     statsSources                    () const;
    QString     statsLastMode                   () const { return _statsLastMode; }
    QString     statsRawText                    () const { return _statsRawText; }
    QString     localIPAddr                     () { return _localIPAddr; }
    QString     remoteIPAddr                    () { return _remoteIPAddr; }
    QString     netMask                         () { return _netMask; }
    QString     configUserName                  () { return _configUserName; }
    QString     configPassword                  () { return _configPassword; }
    QString     encryptionKey                   () { return _encryptionKey; }

    void        setLocalIPAddr                  (QString val) { _localIPAddr = val; emit localIPAddrChanged(); }
    void        setRemoteIPAddr                 (QString val) { _remoteIPAddr = val; emit remoteIPAddrChanged(); }
    void        setConfigUserName               (QString val) { _configUserName = val; emit configUserNameChanged(); }
    void        setConfigPassword               (QString val) { _configPassword = val; emit configPasswordChanged(); }
    void        setEncryptionKey                (QString val) { _encryptionKey = val; emit encryptionKeyChanged(); }
    void        updateSettings                  ();
    void        setEncryptionKey                ();
    void        switchToPairingEncryptionKey    ();
    void        switchToConnectionEncryptionKey (QString encryptionKey);

signals:
    void    linkChanged                     ();
    void    linkConnectedChanged            ();
    void    connectedChanged                ();
    void    localIPAddrChanged              ();
    void    remoteIPAddrChanged             ();
    void    netMaskChanged                  ();
    void    configUserNameChanged           ();
    void    configPasswordChanged           ();
    void    encryptionKeyChanged            ();
    void    statsChanged                    ();

private slots:
    void    _connectedLoc                   (int status);
    void    _rssiUpdatedLoc                 (int rssi);
    void    _connectedRem                   (int status);
    void    _rssiUpdatedRem                 (int rssi);
    void    _checkMicrohard                 ();
    void    _setEnabled                     ();
    void    _locTimeout                     ();
    void    _remTimeout                     ();
    void    _statsReadyRead                 ();
    void    _statsTimeout                   ();

private:
    void    _close                          ();
    void    _reset                          ();
    void    _startStatsSocket               ();
    void    _stopStatsSocket                ();
    void    _parseStatsDatagram             (const QByteArray& bytes, const QHostAddress& sender, quint16 localPort);
    void    _setStatsValue                  (QString& field, const QString& value, bool& changed);
    void    _resetStatsValues               ();
    FactMetaData *_createMetadata           (const char *name, QStringList enums);

private:
    enum {
        _statsPort = 20202,
        _statsPortSecondary = 20203,
        _statsTimeoutMs = 15000
    };

    int                _connectedStatus = 0;
    AppSettings*       _appSettings = nullptr;
    MicrohardSettings* _mhSettingsLoc = nullptr;
    MicrohardSettings* _mhSettingsRem = nullptr;
    QList<QUdpSocket*> _statsSockets;
    bool               _enabled  = true;
    int                _linkConnectedStatus = 0;
    QTimer             _workTimer;
    QTimer             _locTimer;
    QTimer             _remTimer;
    QTimer             _statsTimer;
    int                _downlinkRSSI = 0;
    int                _uplinkRSSI = 0;
    bool               _statsConnected = false;
    QString            _groundRSSI = QStringLiteral("--");
    QString            _skyRSSI = QStringLiteral("--");
    QString            _snr = QStringLiteral("--");
    QString            _txRate = QStringLiteral("--");
    QString            _rxRate = QStringLiteral("--");
    QString            _txThroughput = QStringLiteral("--");
    QString            _rxThroughput = QStringLiteral("--");
    QString            _txBytes = QStringLiteral("--");
    QString            _rxBytes = QStringLiteral("--");
    QString            _queueLength = QStringLiteral("--");
    QString            _frequency = QStringLiteral("--");
    QString            _temperature = QStringLiteral("--");
    QString            _version = QStringLiteral("--");
    QString            _mainLink = QStringLiteral("UDP");
    uint               _statsPacketCount = 0;
    uint               _masterStatsPacketCount = 0;
    uint               _slaveStatsPacketCount = 0;
    QString            _statsLastSource = QStringLiteral("--");
    QString            _statsLastMode = QStringLiteral("--");
    QString            _statsRawText;
    QMap<QString, uint> _statsSourceCounts;
    QString            _localIPAddr;
    QString            _remoteIPAddr;
    QString            _netMask;
    QString            _configUserName;
    QString            _configPassword;
    QString            _encryptionKey;
    bool               _useCommunicationEncryptionKey = false;
    QString            _communicationEncryptionKey;
    QTime              _timeoutTimer;
};
