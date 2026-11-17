/****************************************************************************
 * MAVLink 2 signing for alesQGC — see MAVLinkSigning.h
 ****************************************************************************/

#include "MAVLinkSigning.h"
#include <QLoggingCategory>

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRandomGenerator>
#include <QSettings>
#include <QStandardPaths>
#include <QTextStream>

#include <cstring>
#include <iterator>

#ifdef Q_OS_WIN
#include <windows.h>
#include <wincrypt.h>
#endif

// Qt logging category (not the QGC registry) so the Simple UI test runner can build this file alone
Q_LOGGING_CATEGORY(MAVLinkSigningLog, "MAVLinkSigningLog")

namespace {
    const char*     kGroup      = "MAVLinkSigning";
    const char*     kKeyKey     = "key";
    const char*     kProtectKey = "protect";
    const char*     kDateKey    = "date";
    const qint64    kEpoch2015Ms = Q_INT64_C(1420070400000);    // 2015-01-01 00:00:00 UTC
    const qint64    kLogMaxBytes = 1024 * 1024;

    mavlink_signing_t           s_signing[MAVLINK_COMM_NUM_BUFFERS];
    mavlink_signing_streams_t   s_streams;
    MAVLinkSigning::State       s_state[MAVLINK_COMM_NUM_BUFFERS];
    bool                        s_inUse[MAVLINK_COMM_NUM_BUFFERS] = {};
    bool                        s_mismatchLogged[MAVLINK_COMM_NUM_BUFFERS] = {};

    // The library's own receive checks are turned off (this callback accepts everything, so mavlink_helpers.h never
    // checks or drops a packet). MAVLinkSigning::packetReceived() decides instead: it checks the key (signature hash)
    // but not the timestamps, because a drone without GPS time lets its signing clock fall behind and the library
    // would then drop all its telemetry ("old timestamp" for a new stream). Replay protection of commands is done by
    // the drone, which checks our timestamps.
    bool acceptUnsignedCallback(const mavlink_status_t*, uint32_t)
    {
        return true;
    }

    // MAVLink 2 signature: SHA-256(key + header + payload + crc + link id + timestamp), first 6 bytes
    bool signatureMatches(const mavlink_message_t& msg, const uint8_t* key)
    {
        const uint8_t* p = reinterpret_cast<const uint8_t*>(&msg.magic);
        const uint8_t* psig = msg.signature;
        mavlink_sha256_ctx ctx;
        uint8_t signature[6];
        mavlink_sha256_init(&ctx);
        mavlink_sha256_update(&ctx, key, 32);
        mavlink_sha256_update(&ctx, p, MAVLINK_NUM_HEADER_BYTES);
        mavlink_sha256_update(&ctx, _MAV_PAYLOAD(&msg), msg.len);
        mavlink_sha256_update(&ctx, msg.ck, 2);
        mavlink_sha256_update(&ctx, psig, 1 + 6);
        mavlink_sha256_final_48(&ctx, signature);
        return std::memcmp(signature, psig + 7, 6) == 0;
    }

#ifdef Q_OS_WIN
    QByteArray protectBytes(const QByteArray& plain, bool encrypt)
    {
        DATA_BLOB in;
        in.pbData = reinterpret_cast<BYTE*>(const_cast<char*>(plain.constData()));
        in.cbData = static_cast<DWORD>(plain.size());
        DATA_BLOB out = {};
        const BOOL ok = encrypt
            ? CryptProtectData(&in, L"alesQGC MAVLink signing key", nullptr, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &out)
            : CryptUnprotectData(&in, nullptr, nullptr, nullptr, nullptr, CRYPTPROTECT_UI_FORBIDDEN, &out);
        if (!ok) {
            return QByteArray();
        }
        QByteArray result(reinterpret_cast<const char*>(out.pbData), static_cast<int>(out.cbData));
        SecureZeroMemory(out.pbData, out.cbData);
        LocalFree(out.pbData);
        return result;
    }
#endif
}

static bool configureChannel(uint8_t chan, const QByteArray& key);

MAVLinkSigning* MAVLinkSigning::instance()
{
    static MAVLinkSigning* s_instance = new MAVLinkSigning();
    return s_instance;
}

MAVLinkSigning::MAVLinkSigning(QObject* parent)
    : QObject(parent)
{
    std::memset(&s_streams, 0, sizeof(s_streams));
    for (int i = 0; i < MAVLINK_COMM_NUM_BUFFERS; i++) {
        s_state[i] = StateNoKey;
    }
    _loadKey();
    if (hasKey()) {
        configureChannel(MAVLINK_COMM_0, _key);  // see clearChannel: plain _pack() / _encode() use channel 0
    }
}

uint64_t MAVLinkSigning::timestampNow()
{
    const qint64 ms = QDateTime::currentMSecsSinceEpoch() - kEpoch2015Ms;
    return ms > 0 ? static_cast<uint64_t>(ms) * 100u : 0u;
}

QString MAVLinkSigning::fingerprintOf(const QByteArray& key)
{
    if (key.isEmpty()) {
        return QString();
    }
    const QString hex = QString::fromLatin1(QCryptographicHash::hash(key, QCryptographicHash::Sha256).toHex()).toUpper();
    return hex.left(4) + QChar(0x2026) + hex.right(4);
}

QString MAVLinkSigning::fingerprint() const
{
    return fingerprintOf(_key);
}

//-----------------------------------------------------------------------------
// Channels

// Signing state of a channel's mavlink_status_t (outgoing signing + incoming checks)
static bool configureChannel(uint8_t chan, const QByteArray& key)
{
    mavlink_status_t* status = mavlink_get_channel_status(chan);
    if (key.size() == 32) {
        mavlink_signing_t& sg = s_signing[chan];
        std::memset(&sg, 0, sizeof(sg));
        sg.flags = MAVLINK_SIGNING_FLAG_SIGN_OUTGOING;
        sg.link_id = chan;
        sg.timestamp = MAVLinkSigning::timestampNow();
        std::memcpy(sg.secret_key, key.constData(), 32);
        sg.accept_unsigned_callback = acceptUnsignedCallback;
        sg.last_status = MAVLINK_SIGNING_STATUS_NONE;
        status->signing = &sg;
        status->signing_streams = &s_streams;
        return true;
    }
    status->signing = nullptr;
    status->signing_streams = nullptr;
    return false;
}

void MAVLinkSigning::initChannel(uint8_t chan)
{
    if (chan >= MAVLINK_COMM_NUM_BUFFERS) {
        return;
    }
    MAVLinkSigning* self = instance();
    s_inUse[chan] = true;
    s_mismatchLogged[chan] = false;
    _setState(chan, configureChannel(chan, self->_key) ? StateNotProtected : StateNoKey);
}

void MAVLinkSigning::clearChannel(uint8_t chan)
{
    if (chan >= MAVLINK_COMM_NUM_BUFFERS) {
        return;
    }
    s_inUse[chan] = false;
    // Channel 0 keeps signing while a key exists: older code packs messages for the vehicle with the plain
    // mavlink_msg_*_pack() / _encode() (channel 0) and sends them on the vehicle link.
    if (chan == MAVLINK_COMM_0 && configureChannel(chan, instance()->_key)) {
        _setState(chan, StateNoKey);
        return;
    }
    mavlink_status_t* status = mavlink_get_channel_status(chan);
    status->signing = nullptr;
    status->signing_streams = nullptr;
    std::memset(&s_signing[chan], 0, sizeof(mavlink_signing_t));
    _setState(chan, StateNoKey);
}

bool MAVLinkSigning::packetReceived(uint8_t chan, const mavlink_message_t& msg)
{
    if (chan >= MAVLINK_COMM_NUM_BUFFERS) {
        return true;
    }
    MAVLinkSigning* self = instance();
    const bool isSigned = (msg.incompat_flags & MAVLINK_IFLAG_SIGNED) != 0;

    if (!self->hasKey()) {
        // No key here, but the drone signs its packets: it was paired with another app / key and ignores our
        // unsigned commands, so show it as a key mismatch. Its telemetry is still shown.
        if (isSigned && s_inUse[chan] && s_state[chan] != StateKeyMismatch) {
            _setState(chan, StateKeyMismatch);
            if (!s_mismatchLogged[chan]) {
                s_mismatchLogged[chan] = true;
                self->logEvent(QStringLiteral("link %1: the drone signs with a key this app does not have").arg(chan));
            }
        }
        return true;
    }

    // Our outgoing timestamps follow the wall clock (the library only adds 1 per packet)
    const uint64_t now = timestampNow();
    if (s_signing[chan].timestamp < now) {
        s_signing[chan].timestamp = now;
    }
    if (s_signing[MAVLINK_COMM_0].timestamp < now && mavlink_get_channel_status(MAVLINK_COMM_0)->signing) {
        s_signing[MAVLINK_COMM_0].timestamp = now;
    }

    if (isSigned) {
        if (signatureMatches(msg, s_signing[chan].secret_key)) {
            if (s_state[chan] != StateProtected) {
                _setState(chan, StateProtected);
                uint64_t ts = 0;
                std::memcpy(&ts, msg.signature + 1, 6);
                const double behind = (static_cast<double>(now) - static_cast<double>(ts)) / 1e5;
                self->logEvent(QStringLiteral("link %1 protected: signed packets from system %2 (drone signing time %3 s behind this tablet)")
                               .arg(chan).arg(msg.sysid).arg(behind, 0, 'f', 1));
            }
            return true;
        }
        // signed with another key
        if (s_state[chan] != StateProtected) {
            if (s_state[chan] != StateKeyMismatch) {
                _setState(chan, StateKeyMismatch);
                if (!s_mismatchLogged[chan]) {
                    s_mismatchLogged[chan] = true;
                    self->logEvent(QStringLiteral("link %1: key mismatch (the drone signs with another key)").arg(chan));
                }
            }
            return true;    // not paired: show the telemetry, the drone ignores our commands anyway
        }
        if (!s_mismatchLogged[chan]) {
            s_mismatchLogged[chan] = true;
            self->logEvent(QStringLiteral("link %1: packets with another key dropped (system %2)").arg(chan).arg(msg.sysid));
        }
        return false;
    }

    // unsigned
    return acceptUnsigned(chan, msg.msgid);
}

MAVLinkSigning::State MAVLinkSigning::channelState(uint8_t chan)
{
    return chan < MAVLINK_COMM_NUM_BUFFERS ? s_state[chan] : StateNoKey;
}

bool MAVLinkSigning::acceptUnsigned(uint8_t chan, uint32_t msgId)
{
    if (chan >= MAVLINK_COMM_NUM_BUFFERS || s_state[chan] != StateProtected) {
        return true;    // not paired yet (or no key): accept the drone's unsigned packets
    }
    // radios insert these unsigned
    return msgId == MAVLINK_MSG_ID_RADIO_STATUS || msgId == 166 /* RADIO (ardupilotmega) */;
}

void MAVLinkSigning::_setState(uint8_t chan, State state)
{
    if (s_state[chan] != state) {
        s_state[chan] = state;
        emit instance()->channelStateChanged(chan, state);
    }
}

void MAVLinkSigning::_applyToAllChannels()
{
    for (int i = 0; i < MAVLINK_COMM_NUM_BUFFERS; i++) {
        if (s_inUse[i]) {
            initChannel(static_cast<uint8_t>(i));
        } else if (i == MAVLINK_COMM_0) {
            clearChannel(MAVLINK_COMM_0);       // keeps channel-0 signing while a key exists (see clearChannel)
        }
    }
}

//-----------------------------------------------------------------------------
// SETUP_SIGNING

void MAVLinkSigning::packSetupSigning(uint8_t chan, uint8_t ownSysId, uint8_t ownCompId, uint8_t targetSys, uint8_t targetComp,
                                      const QByteArray& key, uint64_t timestamp, mavlink_message_t* msg)
{
    uint8_t keyBytes[32] = {};
    if (key.size() == 32) {
        std::memcpy(keyBytes, key.constData(), 32);
    }
    mavlink_msg_setup_signing_pack_chan(ownSysId, ownCompId, chan, msg, targetSys, targetComp, keyBytes, timestamp);
    std::memset(keyBytes, 0, sizeof(keyBytes));
}

//-----------------------------------------------------------------------------
// Key

QByteArray MAVLinkSigning::createKey()
{
    QByteArray key(32, Qt::Uninitialized);
    quint32 words[8];
    QRandomGenerator::system()->generate(std::begin(words), std::end(words));
    std::memcpy(key.data(), words, 32);
    std::memset(words, 0, sizeof(words));
    return key;
}

void MAVLinkSigning::setKey(const QByteArray& key)
{
    if (key.size() != 32) {
        return;
    }
    const bool change = hasKey();
    _key = key;
    _keyDate = QDateTime::currentDateTime();
    _saveKey();
    _applyToAllChannels();
    logEvent(QStringLiteral("key %1, fingerprint %2").arg(change ? QStringLiteral("changed") : QStringLiteral("set"), fingerprint()));
    emit keyChanged();
}

void MAVLinkSigning::removeKey()
{
    if (!hasKey()) {
        return;
    }
    const QString fp = fingerprint();
    _key.fill('\0');
    _key.clear();
    _keyDate = QDateTime();
    QSettings settings;
    settings.remove(QString::fromLatin1(kGroup));
    _applyToAllChannels();
    logEvent(QStringLiteral("key removed, fingerprint %1").arg(fp));
    emit keyChanged();
}

void MAVLinkSigning::_loadKey()
{
    QSettings settings;
    settings.beginGroup(QString::fromLatin1(kGroup));
    const QByteArray stored = QByteArray::fromBase64(settings.value(QString::fromLatin1(kKeyKey)).toByteArray());
    const QString protect = settings.value(QString::fromLatin1(kProtectKey)).toString();
    _keyDate = settings.value(QString::fromLatin1(kDateKey)).toDateTime();
    settings.endGroup();
    if (stored.isEmpty()) {
        return;
    }
    QByteArray key;
#ifdef Q_OS_WIN
    if (protect == QStringLiteral("dpapi")) {
        key = protectBytes(stored, false);
    }
#endif
    if (protect == QStringLiteral("none")) {
        key = stored;
    }
    if (key.size() == 32) {
        _key = key;
    } else {
        qCWarning(MAVLinkSigningLog) << "stored link key cannot be read (another user or PC?): links are not signed";
        logEvent(QStringLiteral("stored key cannot be read"));
    }
}

void MAVLinkSigning::_saveKey()
{
    QByteArray stored;
    QString protect;
#ifdef Q_OS_WIN
    stored = protectBytes(_key, true);
    protect = QStringLiteral("dpapi");
#endif
    if (stored.isEmpty()) {
        // TODO(AQGC): Android Keystore. Until then the key is in the app-private settings (per-app storage, no keystore).
        stored = _key;
        protect = QStringLiteral("none");
        qCWarning(MAVLinkSigningLog) << "no OS key store: the link key is kept in the app-private settings";
    }
    QSettings settings;
    settings.beginGroup(QString::fromLatin1(kGroup));
    settings.setValue(QString::fromLatin1(kKeyKey), stored.toBase64());
    settings.setValue(QString::fromLatin1(kProtectKey), protect);
    settings.setValue(QString::fromLatin1(kDateKey), _keyDate);
    settings.endGroup();
}

//-----------------------------------------------------------------------------
// Security log

QString MAVLinkSigning::securityLogPath() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/security.log");
}

void MAVLinkSigning::logEvent(const QString& text)
{
    const QString path = securityLogPath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    if (QFileInfo(path).size() > kLogMaxBytes) {
        QFile::remove(path + QStringLiteral(".1"));
        QFile::rename(path, path + QStringLiteral(".1"));
    }
    QFile file(path);
    if (file.open(QIODevice::Append | QIODevice::Text)) {
        QTextStream out(&file);
        out << QDateTime::currentDateTime().toString(Qt::ISODate) << " MAVLink signing: " << text << "\n";
    }
    qCDebug(MAVLinkSigningLog) << text;
}
