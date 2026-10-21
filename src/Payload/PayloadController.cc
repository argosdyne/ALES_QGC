#include "PayloadController.h"

#include <cstring>

#include <QTimer>
#include <QUdpSocket>

PayloadController::PayloadController(QObject* parent)
    : QObject(parent)
{
    memset(&_rxMsg, 0, sizeof(_rxMsg));
    memset(&_rxStatus, 0, sizeof(_rxStatus));
}

PayloadController::~PayloadController()
{
    _closeSocket();
}

void PayloadController::setIp(const QString& ip)
{
    if (_ip == ip) {
        return;
    }
    _ip = ip;
    _targetAddress = QHostAddress(ip);
    _onIpChanged();
    emit ipChanged();
}

void PayloadController::disconnectPayload()
{
    if (_linkTimer) {
        _linkTimer->stop();
    }
    _closeSocket();
    setConnected(false);
    setConnecting(false);
    _setLinkFailed(false);
}

void PayloadController::_beginConnecting()
{
    if (!_linkTimer) {
        _linkTimer = new QTimer(this);
        _linkTimer->setSingleShot(true);
        connect(_linkTimer, &QTimer::timeout, this, &PayloadController::_onLinkTimeout);
    }
    setConnected(false);
    _setLinkFailed(false);
    setConnecting(true);
    _linkTimer->start(_linkTimeoutMs);
}

void PayloadController::_noteLinkActivity()
{
    setConnecting(false);
    _setLinkFailed(false);
    setConnected(true);
    if (_linkTimer) {
        _linkTimer->start(_linkTimeoutMs); // rolling keep-alive
    }
}

void PayloadController::_onLinkTimeout()
{
    // No traffic came back from the payload within the window. The UDP socket + timers keep
    // running (so it auto-recovers if the payload appears), but the status is honest: not linked.
    setConnecting(false);
    setConnected(false);
    _setLinkFailed(true);
}

void PayloadController::_setLinkFailed(bool failed)
{
    if (_linkFailed == failed) {
        return;
    }
    _linkFailed = failed;
    emit linkFailedChanged();
}

bool PayloadController::_openSocket(quint16 localBindPort)
{
    if (_socket) {
        return true;
    }

    _socket = new QUdpSocket(this);
    const bool bound = _socket->bind(QHostAddress::AnyIPv4,
                                     localBindPort,
                                     QAbstractSocket::ShareAddress | QAbstractSocket::ReuseAddressHint);
    if (!bound) {
        emit logMessage(QStringLiteral("Payload UDP bind failed on port %1: %2")
                            .arg(localBindPort)
                            .arg(_socket->errorString()));
        // A failed bind still allows sending from an ephemeral port; keep going.
    }

    connect(_socket, &QUdpSocket::readyRead, this, &PayloadController::_readPendingDatagrams);
    return true;
}

void PayloadController::_closeSocket()
{
    if (!_socket) {
        return;
    }
    _socket->close();
    _socket->deleteLater();
    _socket = nullptr;
}

void PayloadController::_sendMessage(const mavlink_message_t& message)
{
    if (!_socket || _targetAddress.isNull() || _targetPort == 0) {
        return;
    }

    uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
    const int length = mavlink_msg_to_send_buffer(buffer, &message);
    _socket->writeDatagram(reinterpret_cast<const char*>(buffer), length, _targetAddress, _targetPort);
}

void PayloadController::_readPendingDatagrams()
{
    if (!_socket) {
        return;
    }

    while (_socket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(static_cast<int>(_socket->pendingDatagramSize()));
        _socket->readDatagram(datagram.data(), datagram.size());

        for (char byte : datagram) {
            mavlink_message_t message;
            mavlink_status_t status;
            const uint8_t framed = mavlink_frame_char_buffer(&_rxMsg,
                                                             &_rxStatus,
                                                             static_cast<uint8_t>(byte),
                                                             &message,
                                                             &status);
            if (framed == MAVLINK_FRAMING_OK) {
                _handleMavlinkMessage(message);
            }
        }
    }
}

void PayloadController::setConnected(bool connected)
{
    if (_connected == connected) {
        return;
    }
    _connected = connected;
    emit connectedChanged();
}

void PayloadController::setConnecting(bool connecting)
{
    if (_connecting == connecting) {
        return;
    }
    _connecting = connecting;
    emit connectingChanged();
}

void PayloadController::setRtspUrl(const QString& url)
{
    if (_rtspUrl == url) {
        return;
    }
    _rtspUrl = url;
    emit rtspUrlChanged();
}
