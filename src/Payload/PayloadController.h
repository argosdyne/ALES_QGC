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
class QTimer;

class PayloadController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString displayName READ displayName        CONSTANT)
    Q_PROPERTY(QString ip          READ ip WRITE setIp     NOTIFY ipChanged)
    Q_PROPERTY(QString rtspUrl     READ rtspUrl            NOTIFY rtspUrlChanged)
    Q_PROPERTY(bool    connected   READ connected          NOTIFY connectedChanged)
    Q_PROPERTY(bool    connecting  READ connecting         NOTIFY connectingChanged)
    Q_PROPERTY(bool    linkFailed  READ linkFailed         NOTIFY linkFailedChanged)

public:
    explicit PayloadController(QObject* parent = nullptr);
    ~PayloadController() override;

    virtual QString displayName() const = 0;

    QString ip() const          { return _ip; }
    void    setIp(const QString& ip);

    QString rtspUrl() const     { return _rtspUrl; }
    bool    connected() const   { return _connected; }
    bool    connecting() const  { return _connecting; }
    bool    linkFailed() const  { return _linkFailed; }

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

    /// Continuous axis control (e.g. USB joystick), pan/tilt in [-1,+1]. Default: threshold to
    /// the discrete gimbalMove; subclasses override for proportional (analog) speed.
    Q_INVOKABLE virtual void gimbalAxis(double pan, double tilt) {
        gimbalMove(pan  > 0.30 ? 1 : pan  < -0.30 ? -1 : 0,
                   tilt > 0.30 ? 1 : tilt < -0.30 ? -1 : 0);
    }

signals:
    void ipChanged();
    void rtspUrlChanged();
    void connectedChanged();
    void connectingChanged();
    void linkFailedChanged();
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

    /// Connect flow: call after opening the socket. Marks "connecting" and arms a watchdog;
    /// the payload only becomes "connected" once we actually hear back from it (real 2-way link).
    void _beginConnecting();
    /// Call from _handleMavlinkMessage when a message arrives FROM the payload: marks connected
    /// and refreshes the watchdog (rolling keep-alive).
    void _noteLinkActivity();

    /// Called for every fully-framed inbound MAVLink message. Default: nothing.
    virtual void _handleMavlinkMessage(const mavlink_message_t& message) { Q_UNUSED(message) }
    /// Called after setIp() changes the address. Subclass may refresh rtspUrl.
    virtual void _onIpChanged() {}

    QString      _ip;
    QString      _rtspUrl;
    bool         _connected  = false;
    bool         _connecting = false;
    bool         _linkFailed = false;
    int          _linkTimeoutMs = 3000; // no traffic within this window => not connected

    QUdpSocket*  _socket        = nullptr;
    QHostAddress _targetAddress;
    quint16      _targetPort    = 0;

    // Sender identity. NOTE: many devices (e.g. ArduPilot SYSID_MYGCS) gate on the
    // sender system id, so this defaults to 1 rather than QGC's global GCS id (255).
    uint8_t      _senderSysId   = 1;
    uint8_t      _senderCompId  = MAV_COMP_ID_MISSIONPLANNER; // 190

private slots:
    void _readPendingDatagrams();
    void _onLinkTimeout();

private:
    void _setLinkFailed(bool failed);

    QTimer* _linkTimer = nullptr;

    // Reentrant parser state (isolated from QGC's global MAVLink channels).
    mavlink_message_t _rxMsg;
    mavlink_status_t  _rxStatus;
};
