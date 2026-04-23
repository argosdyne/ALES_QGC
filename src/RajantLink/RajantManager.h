#pragma once

#include <QObject>
#include <QSslSocket>
#include <QTimer>
#include <QElapsedTimer>
#include <QUdpSocket>
#include <QNetworkInterface>
#include "BcapiProtocol.h"

/**
 * RajantManager -- connects to a Rajant BreadCrumb node via BCAPI (SSL:2300)
 * and periodically reads radio signal information (RSSI, noise, SNR).
 *
 * Connection:
 *   SSL/TLS on port 2300 with BCAPI challenge-response auth (SHA-384).
 *   Rajant nodes use self-signed certificates, so SSL errors are ignored.
 *
 * Polling:
 *   Sends State query with filter "wireless" every _pollInterval ms.
 *   Parses Wireless.Peer.signal, Wireless.noise, Wireless.Peer.rssi from response.
 *
 * Exposed to QML via Q_PROPERTY for RajantLinkIndicator.qml.
 */
class RajantManager : public QObject
{
    Q_OBJECT

public:
    explicit RajantManager(const QString& nodeAddress, const QString& password, QObject* parent = nullptr);
    ~RajantManager() override;

    // Connection state
    Q_PROPERTY(bool     connected       READ connected      NOTIFY connectedChanged)
    Q_PROPERTY(bool     authenticated   READ authenticated  NOTIFY authenticatedChanged)
    Q_PROPERTY(bool     linkLive        READ linkLive       NOTIFY linkLiveChanged)
    Q_PROPERTY(QString  nodeAddress     READ nodeAddress     CONSTANT)

    // Ground-side radio data (what the ground node directly measures)
    Q_PROPERTY(int      signal          READ signal          NOTIFY radioDataChanged)
    Q_PROPERTY(int      noise           READ noise           NOTIFY radioDataChanged)
    Q_PROPERTY(int      snr             READ snr             NOTIFY radioDataChanged)
    Q_PROPERTY(int      linkRate        READ linkRate        NOTIFY radioDataChanged)
    Q_PROPERTY(QString  radioName       READ radioName       NOTIFY radioDataChanged)
    Q_PROPERTY(int      channel         READ channel         NOTIFY radioDataChanged)
    Q_PROPERTY(int      txPower         READ txPower         NOTIFY radioDataChanged)
    Q_PROPERTY(int      peerCount       READ peerCount       NOTIFY radioDataChanged)

    // Sky-side radio data (derived from ground session, no 2nd SSL needed):
    //   skySnr    = peer-reported SNR from Rajant Peer.field15 (measured by sky)
    //   skySignal = skySnr + noise  (estimated dBm, assumes sky noise ~= ground noise)
    Q_PROPERTY(int      skySignal       READ skySignal       NOTIFY skyDataChanged)
    Q_PROPERTY(int      skySnr          READ skySnr          NOTIFY skyDataChanged)

    // Node identity read from the radio State payload
    Q_PROPERTY(QString  nodeName        READ nodeName        NOTIFY radioDataChanged)
    Q_PROPERTY(QString  firmwareVersion READ firmwareVersion NOTIFY radioDataChanged)

    // Readable status string
    Q_PROPERTY(QString  statusText      READ statusText      NOTIFY statusTextChanged)

    bool    connected()     const { return _connected; }
    bool    authenticated() const { return _authenticated; }
    bool    linkLive()      const { return _linkLive; }
    QString nodeAddress()   const { return _nodeAddress; }

    int     signal()        const { return _signal; }
    int     noise()         const { return _noise; }
    int     snr()           const { return _snr; }
    int     linkRate()      const { return _linkRate; }
    QString radioName()     const { return _radioName; }
    int     channel()       const { return _channel; }
    int     txPower()       const { return _txPower; }
    int     peerCount()     const { return _peerCount; }

    int     skySignal()     const { return _skySignal; }
    int     skySnr()        const { return _skySnr; }

    QString nodeName()        const { return _nodeName; }
    QString firmwareVersion() const { return _firmwareVersion; }

    QString statusText()    const { return _statusText; }

    Q_INVOKABLE void connectToNode(const QString& address);
    Q_INVOKABLE void disconnect();
    Q_INVOKABLE void reconnect();

    int radioCount() const { return _radioCount; }
    QString peerLinkLocalAddress() const { return _peerLinkLocalAddress; }

signals:
    void connectedChanged();
    void authenticatedChanged();
    void linkLiveChanged();
    void radioDataChanged();
    void skyDataChanged();
    void statusTextChanged();
    void firstStateReceived(int radioCount);

private slots:
    void _onSocketEncrypted();
    void _onSocketDisconnected();
    void _onSocketError(QAbstractSocket::SocketError error);
    void _onSslErrors(const QList<QSslError>& errors);
    void _onDataReady();
    void _pollState();
    void _reconnectTimer();

private:
    void _processFrame(const QByteArray& payload);
    void _setConnected(bool v);
    void _setAuthenticated(bool v);
    void _setStatusText(const QString& text);

    // Connection
    QSslSocket*     _socket             = nullptr;
    QString         _nodeAddress;
    QString         _password;
    quint16         _port               = 2300;
    bool            _connected          = false;
    bool            _authenticated      = false;
    bool            _linkLive           = false;  // true when peer is reachable + data flowing
    int             _staleCount         = 0;      // consecutive polls with unchanged peer values
    QElapsedTimer   _lastPeerChange;              // wall-clock: last time peer data actually changed
    static const int _linkDeadTimeoutMs = 10000;  // 10 s of no peer change → link dead
    QByteArray      _recvBuffer;
    qint64          _seqNum             = 0;

    // Polling
    QTimer*         _pollTimer          = nullptr;
    QTimer*         _reconnTimer        = nullptr;
    static const int _pollInterval      = 1000;  // ms
    static const int _reconnectInterval = 5000;  // ms

    bool            _firstStateEmitted  = false;
    int             _radioCount         = 0;
    QString         _peerLinkLocalAddress;

    // Air unit radio data
    int     _signal     = 0;
    int     _noise      = 0;
    int     _snr        = 0;
    int     _linkRate   = 0;
    QString _radioName;
    int     _channel    = 0;
    int     _txPower    = 0;
    int     _peerCount  = 0;

    // Sky-side radio data (derived from peer-reported SNR + ground noise)
    int     _skySignal      = 0;  // estimated dBm = skySnr + noise
    int     _skySnr         = 0;  // peer-reported SNR (dB), direct from Peer.field15

    // Node identity (populated from State payload)
    QString _nodeName;            // hostname, e.g. "rajant-115877"
    QString _firmwareVersion;     // e.g. "10.4-4019-rajant.115.c0a11264"

    QString _statusText;

    // Auth state
    enum AuthState { AUTH_WAIT_CHALLENGE, AUTH_WAIT_RESULT, AUTH_DONE };
    AuthState _authState = AUTH_WAIT_CHALLENGE;
};
