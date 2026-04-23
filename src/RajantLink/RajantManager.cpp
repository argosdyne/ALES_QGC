#include "RajantManager.h"
#include <QHostAddress>
#include <QQmlEngine>
#include <QSslConfiguration>

RajantManager::RajantManager(const QString& nodeAddress, const QString& password, QObject* parent)
    : QObject(parent)
    , _nodeAddress(nodeAddress)
    , _password(password)
{
    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);

    _socket = new QSslSocket(this);

    // Rajant nodes use self-signed certificates — ignore SSL errors
    connect(_socket, &QSslSocket::encrypted,    this, &RajantManager::_onSocketEncrypted);
    connect(_socket, &QSslSocket::disconnected, this, &RajantManager::_onSocketDisconnected);
    connect(_socket, &QSslSocket::readyRead,    this, &RajantManager::_onDataReady);
    connect(_socket, QOverload<const QList<QSslError>&>::of(&QSslSocket::sslErrors),
            this, &RajantManager::_onSslErrors);
    connect(_socket, &QAbstractSocket::errorOccurred,
            this, &RajantManager::_onSocketError);

    _pollTimer = new QTimer(this);
    connect(_pollTimer, &QTimer::timeout, this, &RajantManager::_pollState);

    _reconnTimer = new QTimer(this);
    _reconnTimer->setInterval(_reconnectInterval);
    connect(_reconnTimer, &QTimer::timeout, this, &RajantManager::_reconnectTimer);

    // Start connection
    connectToNode(_nodeAddress);
}

RajantManager::~RajantManager()
{
    _pollTimer->stop();
    _reconnTimer->stop();
    if (_socket) {
        _socket->close();
    }
}

void RajantManager::connectToNode(const QString& address)
{
    if (address.isEmpty()) return;

    _nodeAddress = address;
    _authState = AUTH_WAIT_CHALLENGE;
    _recvBuffer.clear();
    _seqNum = 0;
    _firstStateEmitted = false;

    _setStatusText("Connecting (SSL) to " + address + "...");
    qInfo() << "RajantManager: connecting SSL to" << address << "port" << _port;

    // Configure SSL to accept self-signed certs
    QSslConfiguration sslConfig = QSslConfiguration::defaultConfiguration();
    sslConfig.setPeerVerifyMode(QSslSocket::VerifyNone);
    sslConfig.setProtocol(QSsl::AnyProtocol);
    _socket->setSslConfiguration(sslConfig);

    _socket->connectToHostEncrypted(address, _port);

    // Detect silently-dead TCP connections faster (radio unplugged, cable pulled, etc.)
    _socket->setSocketOption(QAbstractSocket::KeepAliveOption, 1);
}

void RajantManager::disconnect()
{
    _pollTimer->stop();
    _reconnTimer->stop();
    if (_socket) {
        _socket->close();
    }
    _setConnected(false);
    _setAuthenticated(false);
    _setStatusText("Disconnected");
}

void RajantManager::reconnect()
{
    disconnect();
    connectToNode(_nodeAddress);
}

void RajantManager::_onSslErrors(const QList<QSslError>& errors)
{
    // Rajant nodes use self-signed certificates — this is expected
    // qInfo() << "RajantManager: ignoring SSL errors (self-signed cert):" << errors.size();
    _socket->ignoreSslErrors();
}

void RajantManager::_onSocketEncrypted()
{
    qInfo() << "RajantManager: SSL handshake complete on" << _nodeAddress;
    _setConnected(true);
    _setStatusText("SSL connected, waiting for auth challenge...");
    _authState = AUTH_WAIT_CHALLENGE;
    // Server will send the BCAPI auth challenge now that SSL is established
}

void RajantManager::_onSocketDisconnected()
{
    qWarning() << "RajantManager: disconnected from" << _nodeAddress;
    _pollTimer->stop();
    _setConnected(false);
    _setAuthenticated(false);
    _setStatusText("Disconnected");

    // Wipe cached values so UI immediately shows N/A instead of stale numbers
    _signal = 0; _noise = 0; _snr = 0; _linkRate = 0;
    _skySignal = 0; _skySnr = 0;
    _peerCount = 0;
    _staleCount = 0;
    _lastPeerChange.invalidate();
    if (_linkLive) { _linkLive = false; emit linkLiveChanged(); }
    emit radioDataChanged();
    emit skyDataChanged();

    // Auto-reconnect
    if (!_reconnTimer->isActive()) {
        _reconnTimer->start();
    }
}

void RajantManager::_onSocketError(QAbstractSocket::SocketError error)
{
    Q_UNUSED(error);
    qWarning() << "RajantManager: socket error:" << _socket->errorString();
    _setStatusText("Error: " + _socket->errorString());

    if (!_reconnTimer->isActive()) {
        _reconnTimer->start();
    }
}

void RajantManager::_reconnectTimer()
{
    if (_connected) {
        _reconnTimer->stop();
        return;
    }
    // qInfo() << "RajantManager: attempting reconnect to" << _nodeAddress;
    connectToNode(_nodeAddress);
}

void RajantManager::_onDataReady()
{
    _recvBuffer.append(_socket->readAll());

    QByteArray payload;
    while (BcapiProtocol::readFrame(_recvBuffer, payload)) {
        _processFrame(payload);
    }
}

void RajantManager::_processFrame(const QByteArray& payload)
{
    BcapiProtocol::BcapiMessage msg = BcapiProtocol::parseBcMessage(payload);

    // Handle auth challenge from server
    if (!msg.authChallenge.isEmpty() && _authState == AUTH_WAIT_CHALLENGE) {
        // qInfo() << "RajantManager: received auth challenge (" << msg.authChallenge.size() << "bytes), sending SHA-384 response";
        QByteArray authResp = BcapiProtocol::buildAuthResponse(
            msg.authChallenge, _password, ++_seqNum);
        _socket->write(authResp);
        _socket->flush();
        _authState = AUTH_WAIT_RESULT;
        return;
    }

    // Handle auth result
    if (msg.authResultStatus >= 0) {
        if (msg.authResultStatus == 1) { // SUCCESS
            qInfo() << "RajantManager: authentication successful on" << _nodeAddress;
            _setAuthenticated(true);
            _setStatusText("Authenticated - polling RSSI");
            // Start polling state
            _pollState(); // immediate first query
            _pollTimer->start(_pollInterval);
        } else {
            qWarning() << "RajantManager: authentication FAILED (status:" << msg.authResultStatus << ")";
            _setStatusText("Auth failed - check password");
            _socket->close();
        }
        _authState = AUTH_DONE;
        return;
    }

    // Handle state response
    if (msg.hasState) {
        bool dataChanged = false;

        // Report radio count on first State response (used for air unit identification)
        _radioCount = msg.state.wireless.size();
        if (!_firstStateEmitted) {
            _firstStateEmitted = true;

            // Print full node info like the Java QuickTest output
            qInfo() << "";
            qInfo() << "=== Rajant Node:" << _nodeAddress << "===";
            qInfo() << "  Wireless radios:" << _radioCount;
            for (const auto& w : msg.state.wireless) {
                if (!w.nodeName.isEmpty()) {
                    qInfo() << "  Hostname:       " << w.nodeName;
                    break;
                }
            }
            for (const auto& w : msg.state.wireless) {
                if (!w.firmwareVersion.isEmpty()) {
                    qInfo() << "  Firmware:       " << w.firmwareVersion;
                    break;
                }
            }

            for (int i = 0; i < msg.state.wireless.size(); i++) {
                const auto& w = msg.state.wireless[i];
                qInfo() << "  Radio" << i << ":";
                qInfo() << "    Name:   " << w.name;
                qInfo() << "    Channel:" << w.channel;
                qInfo() << "    Noise:  " << w.noise << "dBm";
                qInfo() << "    TxPower:" << w.txpower << "dBm";
                qInfo() << "    Peers:  " << w.peers.size();
                for (int j = 0; j < w.peers.size(); j++) {
                    const auto& p = w.peers[j];
                    qInfo() << "      Peer" << j << ":";
                    qInfo() << "        Signal: " << p.signal << "dBm  (ground <- sky)";
                    qInfo() << "        SNR:    " << p.rssi << "dB    (ground <- sky)";
                    qInfo() << "        PeerSNR:" << p.peerSnr << "dB    (sky <- ground, reported by sky)";
                    qInfo() << "        Rate:   " << (p.rate * 10) << "Mbps";
                    qInfo() << "        Enabled:" << p.enabled;
                    if (!p.ipv4Address.isEmpty())
                        qInfo() << "        IPv4:   " << p.ipv4Address;
                    if (!p.linkLocalAddress.isEmpty())
                        qInfo() << "        LinkLocal:" << p.linkLocalAddress;
                }
            }
            qInfo() << "";

            emit firstStateReceived(_radioCount);
        }

        bool skyChanged = false;
        bool peerChanged = false;

        // Capture node identity from any radio that reports it
        for (const auto& w : msg.state.wireless) {
            if (!w.nodeName.isEmpty() && w.nodeName != _nodeName) {
                _nodeName = w.nodeName;
                dataChanged = true;
            }
            if (!w.firmwareVersion.isEmpty() && w.firmwareVersion != _firmwareVersion) {
                _firmwareVersion = w.firmwareVersion;
                dataChanged = true;
            }
        }

        // Is there an enabled peer on any radio? If every peer says enabled=false,
        // the mesh link is down even if BCAPI/TCP is still up.
        bool hasEnabledPeer = false;
        for (const auto& w : msg.state.wireless) {
            for (const auto& p : w.peers) {
                if (p.enabled) { hasEnabledPeer = true; break; }
            }
            if (hasEnabledPeer) break;
        }

        for (const auto& w : msg.state.wireless) {
            if (w.peers.isEmpty()) continue;

            // Use the first radio that has peers (active link)
            const auto& peer = w.peers.first();

            int newSignal  = peer.signal;
            int newNoise   = w.noise;
            int newSnr     = peer.rssi;
            int newRate    = peer.rate * 10; // stored as 10s of Mbps

            // Sky-side values — derived, no 2nd SSL session needed.
            //   skySnr    = peer-reported SNR (what the sky radio measures from ground)
            //   skySignal = skySnr + noise  (estimate: assumes sky noise ~= ground noise)
            int newSkySnr    = peer.peerSnr;
            int newSkySignal = (peer.peerSnr > 0 && w.noise < 0)
                ? (peer.peerSnr + w.noise)
                : 0;

            if (newSignal != _signal || newNoise != _noise || newSnr != _snr ||
                newRate != _linkRate || w.name != _radioName ||
                static_cast<int>(w.channel) != _channel || w.txpower != _txPower ||
                w.peers.size() != _peerCount) {
                _signal    = newSignal;
                _noise     = newNoise;
                _snr       = newSnr;
                _linkRate  = newRate;
                _radioName = w.name;
                _channel   = static_cast<int>(w.channel);
                _txPower   = w.txpower;
                _peerCount = w.peers.size();
                dataChanged = true;
                peerChanged = true;
            }
            if (newSkySnr != _skySnr || newSkySignal != _skySignal) {
                _skySnr    = newSkySnr;
                _skySignal = newSkySignal;
                skyChanged = true;
                peerChanged = true;
            }
            break; // use first active radio
        }

        // Link-health detection — fixes stale values when the far end is powered off
        // while the local TCP session is still alive.
        //   1. peer.enabled == false on every peer → ground knows peer is gone.
        //   2. 10 consecutive polls (~10s) with no change in any peer value → no RF
        //      jitter means the ground is just replaying a cached entry.
        //   3. Wall-clock safety net: _linkDeadTimeoutMs (10s) since last peerChanged,
        //      regardless of poll count (catches edge cases where the counter
        //      somehow doesn't advance).
        if (peerChanged) {
            _staleCount = 0;
            _lastPeerChange.restart();
        } else {
            _staleCount++;
        }
        const bool elapsedOk = _lastPeerChange.isValid()
            && _lastPeerChange.elapsed() < _linkDeadTimeoutMs;
        const bool shouldBeLive = hasEnabledPeer && _staleCount < 10 && elapsedOk;
        if (shouldBeLive != _linkLive) {
            _linkLive = shouldBeLive;
            if (!_linkLive) {
                qWarning() << "RajantManager: link appears dead (hasEnabledPeer="
                           << hasEnabledPeer << ", staleCount=" << _staleCount
                           << ", elapsedMs=" << (_lastPeerChange.isValid() ? _lastPeerChange.elapsed() : -1)
                           << ") — clearing UI values";
                _signal = 0; _noise = 0; _snr = 0; _linkRate = 0;
                _skySignal = 0; _skySnr = 0; _peerCount = 0;
                dataChanged = true;
                skyChanged = true;
            } else {
                qInfo() << "RajantManager: link is live again";
            }
            emit linkLiveChanged();
        }

        // Per-poll RSSI log disabled to avoid 1-per-second log spam in production.
        // Re-enable locally for debugging signal/stale behavior:
        // if (_linkLive) {
        //     qInfo() << QString("[%1] Ground: %2 dBm / %3 dB | Sky: %4 dBm / %5 dB | Noise: %6 dBm | Rate: %7 Mbps | Ch: %8 | Radio: %9 | stale=%10")
        //                .arg(_nodeAddress)
        //                .arg(_signal).arg(_snr)
        //                .arg(_skySignal).arg(_skySnr)
        //                .arg(_noise)
        //                .arg(_linkRate).arg(_channel).arg(_radioName)
        //                .arg(_staleCount);
        // }

        if (dataChanged) {
            _setStatusText(QString("Ground: %1 dBm / %2 dB | Sky: %3 dBm / %4 dB")
                           .arg(_signal).arg(_snr)
                           .arg(_skySignal).arg(_skySnr));
            emit radioDataChanged();
        }
        if (skyChanged) {
            emit skyDataChanged();
        }
    }
}

void RajantManager::_pollState()
{
    if (!_authenticated || !_socket || _socket->state() != QAbstractSocket::ConnectedState) {
        return;
    }

    QByteArray query = BcapiProtocol::buildStateQuery(++_seqNum);
    _socket->write(query);
    _socket->flush();
}

void RajantManager::_setConnected(bool v)
{
    if (v != _connected) {
        _connected = v;
        emit connectedChanged();
    }
}

void RajantManager::_setAuthenticated(bool v)
{
    if (v != _authenticated) {
        _authenticated = v;
        emit authenticatedChanged();
    }
}

void RajantManager::_setStatusText(const QString& text)
{
    if (text != _statusText) {
        _statusText = text;
        emit statusTextChanged();
    }
}
