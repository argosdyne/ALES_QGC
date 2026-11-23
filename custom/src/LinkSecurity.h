/****************************************************************************
 * AQGC — link security for the Simple UI (Figma S66 / S22 / S27, 2026-11-17): MAVLink 2 signing key pairing.
 * The signing itself is in src/comm/MAVLinkSigning (core, all modes). Exposed as corePlugin.linkSecurity.
 *
 * Pairing = send SETUP_SIGNING with a new random key to the active drone, then sign with it. Only over a USB cable
 * (SerialLink) or a link to this computer (localhost, SITL), drone disarmed: over the radio the key would travel in
 * clear. With an existing key the SETUP_SIGNING is signed with it (ArduPilot needs that to change or remove a key).
 * Success = signed packets from the drone within 6 s. A refused key change goes back to the old key (or the drone
 * would ignore us); a refused first key is kept (the drone ignores signatures) and shown as refused.
 ****************************************************************************/
#pragma once

#include <QObject>
#include <QPointer>
#include <QTimer>

class Vehicle;

class LinkSecurity : public QObject
{
    Q_OBJECT
public:
    explicit LinkSecurity(QObject* parent = nullptr);

    Q_PROPERTY(bool     hasKey          READ hasKey         NOTIFY keyChanged)
    Q_PROPERTY(QString  fingerprint     READ fingerprint    NOTIFY keyChanged)
    Q_PROPERTY(QString  keyDate         READ keyDate        NOTIFY keyChanged)
    /// MAVLinkSigning::State of the active drone's primary link (0 no key, 1 not protected, 2 protected,
    /// 3 key mismatch), -1 = no drone
    Q_PROPERTY(int      activeState     READ activeState    NOTIFY activeStateChanged)
    /// "" (can pair) | "novehicle" | "armed" | "usb" (not a USB cable / local link)
    Q_PROPERTY(QString  pairBlock       READ pairBlock      NOTIFY pairBlockChanged)
    Q_PROPERTY(bool     busy            READ busy           NOTIFY busyChanged)
    /// last pairing result: "" | "ok" | "refused" | "reverted" | "removed" | "forgotten"
    Q_PROPERTY(QString  result          READ result         NOTIFY resultChanged)
    Q_PROPERTY(QString  securityLogPath READ securityLogPath CONSTANT)

    Q_INVOKABLE void pair           ();     ///< set a new key on the drone (or change it)
    Q_INVOKABLE void removeKey      ();     ///< remove the key on the drone and here
    Q_INVOKABLE void forgetLocalKey ();     ///< S67 Delete my data: delete the key here only

    bool    hasKey      () const;
    QString fingerprint () const;
    QString keyDate     () const;
    int     activeState () const;
    QString pairBlock   () const;
    bool    busy        () const { return _busy; }
    QString result      () const { return _result; }
    QString securityLogPath() const;

signals:
    void keyChanged         ();
    void activeStateChanged ();
    void pairBlockChanged   ();
    void busyChanged        ();
    void resultChanged      ();

private slots:
    void _activeVehicleChanged  (Vehicle* vehicle);
    void _channelStateChanged   (int chan, int state);
    void _pairTimeout           ();

private:
    int  _activeChannel () const;
    bool _sendSetupSigning(const QByteArray& key, uint64_t timestamp);
    void _setBusy       (bool busy);
    void _setResult     (const QString& result);

    QPointer<Vehicle>   _vehicle;
    QTimer              _timer;
    bool                _busy = false;
    QString             _result;
    QByteArray          _oldKey;        // during a key change: the key to go back to if the drone refuses
    int                 _pairChan = -1;
};
