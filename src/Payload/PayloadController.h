/// @file PayloadController.h
/// @brief Abstract base for self-contained payload controllers.
///
/// A payload controller owns its OWN UDP/MAVLink link straight to the payload
/// device and is completely independent of the QGC Vehicle / autopilot link.
/// This mirrors the standalone reference apps (GremsyPayloadApp, NextVisionGimbalMaui):
/// the payload is reached directly over its network, so payload control does not
/// require (and does not touch) the active Vehicle.
///
/// Subclasses implement the device-specific protocol; the base provides the shared
/// UDP socket, MAVLink send helper and a reentrant RX parser.

#pragma once

#include <QObject>
#include <QString>
#include <QHostAddress>

#include "QGCMAVLink.h"

class QUdpSocket;

class PayloadController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString displayName READ displayName        CONSTANT)
    Q_PROPERTY(QString ip          READ ip WRITE setIp     NOTIFY ipChanged)
    Q_PROPERTY(QString rtspUrl     READ rtspUrl            NOTIFY rtspUrlChanged)
    Q_PROPERTY(bool    connected   READ connected          NOTIFY connectedChanged)
    Q_PROPERTY(bool    connecting  READ connecting         NOTIFY connectingChanged)

public:
    explicit PayloadController(QObject* parent = nullptr);
    ~PayloadController() override;

    virtual QString displayName() const = 0;

    QString ip() const          { return _ip; }
    void    setIp(const QString& ip);

    QString rtspUrl() const     { return _rtspUrl; }
    bool    connected() const   { return _connected; }
    bool    connecting() const  { return _connecting; }

    /// Open the link to the payload.
    Q_INVOKABLE virtual void connectPayload() = 0;
    /// Close the link.
    Q_INVOKABLE virtual void disconnectPayload();

    /// Generic direction control shared by every payload UI.
    /// @param pan  -1 = left, 0 = hold, +1 = right
    /// @param tilt -1 = down, 0 = hold, +1 = up
    Q_INVOKABLE virtual void gimbalMove(int pan, int tilt) = 0;
    Q_INVOKABLE void         gimbalStop() { gimbalMove(0, 0); }
    /// Optional recenter / home. No-op unless the device supports it.
    Q_INVOKABLE virtual void gimbalHome() {}

signals:
    void ipChanged();
    void rtspUrlChanged();
    void connectedChanged();
    void connectingChanged();
    void logMessage(const QString& message);

protected:
    // --- Shared UDP / MAVLink plumbing -------------------------------------
    /// Create + bind the UDP socket. localBindPort 0 means an ephemeral port.
    bool _openSocket(quint16 localBindPort = 0);
    void _closeSocket();
    void _sendMessage(const mavlink_message_t& message);

    void setConnected(bool connected);
    void setConnecting(bool connecting);
    void setRtspUrl(const QString& url);

    /// Called for every fully-framed inbound MAVLink message. Default: nothing.
    virtual void _handleMavlinkMessage(const mavlink_message_t& message) { Q_UNUSED(message) }
    /// Called after setIp() changes the address. Subclass may refresh rtspUrl.
    virtual void _onIpChanged() {}

    QString      _ip;
    QString      _rtspUrl;
    bool         _connected  = false;
    bool         _connecting = false;

    QUdpSocket*  _socket        = nullptr;
    QHostAddress _targetAddress;
    quint16      _targetPort    = 0;

    // Sender identity. NOTE: many devices (e.g. ArduPilot SYSID_MYGCS) gate on the
    // sender system id, so this defaults to 1 rather than QGC's global GCS id (255).
    uint8_t      _senderSysId   = 1;
    uint8_t      _senderCompId  = MAV_COMP_ID_MISSIONPLANNER; // 190

private slots:
    void _readPendingDatagrams();

private:
    // Reentrant parser state (isolated from QGC's global MAVLink channels).
    mavlink_message_t _rxMsg;
    mavlink_status_t  _rxStatus;
};
