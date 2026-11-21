/****************************************************************************
 * MAVLink 2 signing for alesQGC (AQGC, 2026-11-17; CE RED 3.3(d) / EN 18031 "protected communication").
 * See custom/docs/TASK-security-mavlink-signing.md and Figma S66 / S22 / S27.
 *
 * - One app key (32 random bytes), shared by every drone paired with this app. Only a fingerprint is shown
 *   (first 4 + last 4 hex of SHA-256(key)); the key is never shown, logged or exported.
 * - When a key exists every MAVLink channel signs its outgoing MAVLink 2 packets. A drone without a key ignores the
 *   signature, so this is safe for unpaired drones.
 * - Incoming, per channel: unsigned packets are accepted until the first packet signed with our key arrives
 *   (unpaired drone = Not protected). After that unsigned packets are dropped except RADIO_STATUS / RADIO, which
 *   radios insert, and so are packets signed with another key (Protected). Signed with another key before that =
 *   Key mismatch. Only the key is checked on receive, not the timestamps: a drone without GPS time lets its signing
 *   clock fall behind (SITL: minutes), and the library's 1-minute rule would drop all its telemetry. The drone checks
 *   our timestamps, which follow the wall clock.
 * - The key is stored with Windows DPAPI (current user). Other platforms: app-private settings (TODO: Android Keystore).
 * - Every key event goes to a security log next to the app data (key set / changed / removed / refused / mismatch).
 *
 * Company ArduCopter (Z01.07.00EASA) facts, checked on SITL 2026-11-17: an unsigned SETUP_SIGNING is accepted only
 * while the drone has no key (on any port) and then applies to all its links; with a key set, unsigned commands are
 * ignored on the TCP ports and SETUP_SIGNING itself (new key or all-zero key = remove) must be signed with the old key.
 ****************************************************************************/
#pragma once

#include <QObject>
#include <QByteArray>
#include <QDateTime>
#include <QString>

#include "QGCMAVLink.h"

class MAVLinkSigning : public QObject
{
    Q_OBJECT
public:
    enum State {
        StateNoKey = 0,         ///< this app has no key: links are not protected (no warning shown)
        StateNotProtected,      ///< key present, but the drone on this channel sends unsigned packets (not paired)
        StateProtected,         ///< signed packets with our key received on this channel
        StateKeyMismatch,       ///< the drone signs with another key (or bad timestamps)
    };
    Q_ENUM(State)

    static MAVLinkSigning* instance();

    // Channel hooks (LinkManager / MAVLinkProtocol)
    static void initChannel     (uint8_t chan);                              ///< after mavlink_reset_channel_status
    static void clearChannel    (uint8_t chan);                              ///< when the channel is freed
    /// every decoded packet: false = drop it (protected link: unsigned, or signed with another key)
    static bool packetReceived  (uint8_t chan, const mavlink_message_t& msg);
    static State channelState   (uint8_t chan);

    // Key
    bool        hasKey          () const { return !_key.isEmpty(); }
    QByteArray  keyBytes        () const { return _key; }    ///< C++ only (going back after a refused key change); never show or log
    QString     fingerprint     () const;                                    ///< e.g. "4F2A…9C1D", empty without key
    QDateTime   keyDate         () const { return _keyDate; }
    static QString fingerprintOf(const QByteArray& key);

    /// SETUP_SIGNING for the vehicle. With a current key the packet is signed on the channel (required to change or
    /// remove a key on ArduPilot); without one it goes out unsigned (pairing a new drone).
    static void packSetupSigning(uint8_t chan, uint8_t ownSysId, uint8_t ownCompId, uint8_t targetSys, uint8_t targetComp,
                                 const QByteArray& key, uint64_t timestamp, mavlink_message_t* msg);

    /// MAVLink signing time: 10 microseconds since 2015-01-01 00:00 UTC
    static uint64_t timestampNow();

    /// Set (new random key) / remove the local key and apply it to every open channel. Returns the new key.
    QByteArray  createKey       ();
    void        setKey          (const QByteArray& key);
    void        removeKey       ();

    void        logEvent        (const QString& text);                       ///< security log line (never the key)
    QString     securityLogPath () const;

    /// Test hooks (unit tests): accept-unsigned rule for a message id on a channel
    static bool acceptUnsigned  (uint8_t chan, uint32_t msgId);

signals:
    void keyChanged     ();
    void channelStateChanged(int chan, int state);

private:
    MAVLinkSigning(QObject* parent = nullptr);
    void _loadKey       ();
    void _saveKey       ();
    void _applyToAllChannels();
    static void _setState(uint8_t chan, State state);

    QByteArray  _key;
    QDateTime   _keyDate;
};
