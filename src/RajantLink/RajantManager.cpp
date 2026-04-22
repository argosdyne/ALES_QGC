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
    if (address.isEmpty() || !_socket) return;

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
    qInfo() << "RajantManager: ignoring SSL errors (self-signed cert):" << errors.size();
    _socket->ignoreSslErrors();
}

void RajantManager::_onSocketEncrypted()
{
    qInfo() << "RajantManager: SSL handshake complete on" << _nodeAddress;
    _setConnected(true);
    _reconnectAttempts = 0; // reset on successful connection
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

    // Air unit: do NOT auto-retry. CustomPlugin kicks reconnect() when the
    // ground unit sees the peer return. Repeatedly attempting SSL on an
    // unreachable scoped-IPv6 address destabilizes Qt 5.15.2 on Windows.
    if (_isAirUnit) return;

    if (!_reconnTimer->isActive()) {
        _reconnTimer->start();
    }
}

void RajantManager::_onSocketError(QAbstractSocket::SocketError error)
{
    Q_UNUSED(error);
    if (!_socket) return;
    qWarning() << "RajantManager: socket error:" << _socket->errorString();
    _setStatusText("Error: " + _socket->errorString());

    // Air unit waits for peer-return kick (see _onSocketDisconnected).
    if (_isAirUnit) return;

    if (!_reconnTimer->isActive()) {
        _reconnTimer->start();
    }
}

void RajantManager::_reconnectTimer()
{
    if (_connected) {
        _reconnTimer->stop();
        _reconnectAttempts = 0;
        return;
    }
    if (_reconnectAttempts >= _maxReconnectAttempts) {
        _reconnTimer->stop();
        qWarning() << "RajantManager: max reconnect attempts reached, stopping.";
        _setStatusText("Disconnected - max retries reached");
        return;
    }
    _reconnectAttempts++;
    qInfo() << "RajantManager: reconnect attempt" << _reconnectAttempts
        << "of" << _maxReconnectAttempts << "to" << _nodeAddress;
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
        qInfo() << "RajantManager: received auth challenge (" << msg.authChallenge.size() << "bytes), sending SHA-384 response";
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
        bool firstState = !_firstStateEmitted;
        if (firstState) {

            // Print full node info like the Java QuickTest output
            qInfo() << "";
            qInfo() << "=== Rajant Node:" << _nodeAddress << "===";
            qInfo() << "  Wireless radios:" << _radioCount;

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
                    qInfo() << "        Signal: " << p.signal << "dBm";
                    qInfo() << "        RSSI:   " << p.rssi << "dB (SNR)";
                    qInfo() << "        Rate:   " << (p.rate * 10) << "Mbps";
                    qInfo() << "        Enabled:" << p.enabled;
                    if (!p.ipv4Address.isEmpty())
                        qInfo() << "        IPv4:   " << p.ipv4Address;
                    if (!p.linkLocalAddress.isEmpty())
                        qInfo() << "        LinkLocal:" << p.linkLocalAddress;
                }
            }
            qInfo() << "";
        }

        for (const auto& w : msg.state.wireless) {
            if (w.peers.isEmpty()) continue;

            // Use the first radio that has peers (active link)
            const auto& peer = w.peers.first();

            int newSignal  = peer.signal;
            int newNoise   = w.noise;
            int newSnr     = peer.rssi;
            int newRate    = peer.rate * 10; // stored as 10s of Mbps

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
            }
            break; // use first active radio
        }
        // Emit firstStateReceived once we have at least one active peer
        // (CustomPlugin uses this to trigger air-unit connection).
        if (!_firstStateEmitted && _peerCount > 0) {
            _firstStateEmitted = true;
            emit firstStateReceived(_radioCount);
        }

        // Always log current RSSI (every poll)
        QString direction = _isAirUnit ? "air<-ground" : "ground<-air";
        QString safeAddr = _nodeAddress;
        safeAddr.replace('%', "%%"); // escape % in IPv6 scope ID so QString::arg doesn't misparse
        qInfo() << QString("[%1] RSSI: %2 / %3 dBm (%4)")
            .arg(safeAddr)
            .arg(_signal).arg(_noise).arg(direction);

        if (dataChanged) {
            _setStatusText(QString("RSSI: %1 dBm / Noise: %2 dBm / SNR: %3 dB")
                           .arg(_signal).arg(_noise).arg(_snr));
            emit radioDataChanged();
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
