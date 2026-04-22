#pragma once

#include <QByteArray>
#include <QCryptographicHash>
#include <QtEndian>
#include <QDebug>

/**
 * Minimal BCAPI wire protocol encoder/decoder.
 *
 * BCAPI wire format:
 *   [size: 4 bytes BE] [compression: 1 byte] [reserved: 3 bytes] [protobuf payload]
 *
 * Auth handshake:
 *   1. Server sends BCMessage with auth.challengeOrResponse = nonce
 *   2. Client sends BCMessage with auth(action=LOGIN, role=ADMIN,
 *      challengeOrResponse = SHA-384(password + nonce), userAgent="ALESQGC")
 *   3. Server sends BCMessage with authResult.status = SUCCESS(1)
 *
 * State query:
 *   Client sends BCMessage with empty state + stateFilterPath="wireless"
 *   Server responds with BCMessage containing State.wireless[] data
 *
 * Protobuf field reference:
 *   BCMessage.ack              = field 1, varint
 *   BCMessage.sequenceNumber   = field 2, varint (required)
 *   BCMessage.auth             = field 3, embedded
 *   BCMessage.state            = field 6, embedded
 *   BCMessage.authResult       = field 300, embedded
 *   BCMessage.stateFilterPath  = field 601, string
 *
 *   Auth.action                = field 1, varint (LOGIN=0)
 *   Auth.challengeOrResponse   = field 3, bytes
 *   Auth.userAgent             = field 4, string
 *   Auth.role                  = field 8, varint (ADMIN=2)
 *
 *   Result.status              = field 1, varint (FAILURE=0, SUCCESS=1)
 *
 *   State.wireless             = field 40, repeated embedded
 *   Wireless.name              = field 4, string
 *   Wireless.noise             = field 5, int32
 *   Wireless.channel           = field 6, uint32
 *   Wireless.txpower           = field 10, int32
 *   Wireless.peer              = field 16, repeated embedded
 *   Peer.rate                  = field 5, int32
 *   Peer.rssi                  = field 6, int32  (SNR)
 *   Peer.signal                = field 7, int32
 *   Peer.enabled               = field 3, bool
 *   Peer.ipv4Address           = field 11, string
 *   Peer.linkLocalAddress      = field 14, string
 */

namespace BcapiProtocol {

// --- Protobuf wire types ---
enum WireType { VARINT = 0, FIXED64 = 1, LENGTH_DELIMITED = 2, FIXED32 = 5 };

// --- Varint encode/decode ---

inline QByteArray encodeVarint(quint64 value)
{
    QByteArray result;
    while (value > 0x7F) {
        result.append(static_cast<char>((value & 0x7F) | 0x80));
        value >>= 7;
    }
    result.append(static_cast<char>(value & 0x7F));
    return result;
}

inline quint64 decodeVarint(const QByteArray& data, int& pos)
{
    quint64 result = 0;
    int shift = 0;
    while (pos < data.size()) {
        quint8 byte = static_cast<quint8>(data.at(pos++));
        result |= static_cast<quint64>(byte & 0x7F) << shift;
        if (!(byte & 0x80)) break;
        shift += 7;
        if (shift >= 64) break;
    }
    return result;
}

// Decode int32 from varint (handles negative values which are sign-extended to 64 bits)
inline qint32 decodeVarintInt32(const QByteArray& data, int& pos)
{
    return static_cast<qint32>(decodeVarint(data, pos));
}

// --- Tag helpers ---

inline QByteArray encodeTag(int fieldNumber, WireType wireType)
{
    return encodeVarint(static_cast<quint64>((fieldNumber << 3) | wireType));
}

struct Tag {
    int fieldNumber;
    WireType wireType;
};

inline Tag decodeTag(const QByteArray& data, int& pos)
{
    quint64 v = decodeVarint(data, pos);
    return { static_cast<int>(v >> 3), static_cast<WireType>(v & 0x07) };
}

// --- Field encoders ---

inline QByteArray encodeVarintField(int fieldNumber, quint64 value)
{
    return encodeTag(fieldNumber, VARINT) + encodeVarint(value);
}

inline QByteArray encodeBytesField(int fieldNumber, const QByteArray& value)
{
    return encodeTag(fieldNumber, LENGTH_DELIMITED) + encodeVarint(value.size()) + value;
}

inline QByteArray encodeStringField(int fieldNumber, const QString& value)
{
    return encodeBytesField(fieldNumber, value.toUtf8());
}

inline QByteArray encodeEmbeddedField(int fieldNumber, const QByteArray& message)
{
    return encodeTag(fieldNumber, LENGTH_DELIMITED) + encodeVarint(message.size()) + message;
}

// --- BCAPI wire frame (8-byte header + protobuf) ---

inline QByteArray frameMessage(const QByteArray& protobuf)
{
    QByteArray frame(8, '\0');
    quint32 size = static_cast<quint32>(protobuf.size());
    qToBigEndian(size, reinterpret_cast<uchar*>(frame.data()));
    // compression = 0 (NONE), reserved = 0
    frame.append(protobuf);
    return frame;
}

// --- Auth message builders ---

inline QByteArray buildAuthResponse(const QByteArray& challenge, const QString& password, qint64 seqNum)
{
    // SHA-384(password_bytes + challenge_bytes)
    QCryptographicHash hash(QCryptographicHash::Sha384);
    hash.addData(password.toUtf8());
    hash.addData(challenge);
    QByteArray response = hash.result();

    // Auth message: action=LOGIN(0), role=ADMIN(2), challengeOrResponse=hash, userAgent="ALESQGC"
    QByteArray auth;
    auth += encodeVarintField(1, 0);                   // action = LOGIN
    auth += encodeBytesField(3, response);             // challengeOrResponse
    auth += encodeStringField(4, "ALESQGC");           // userAgent
    auth += encodeVarintField(8, 2);                   // role = ADMIN

    // BCMessage: ack=true, sequenceNumber, auth
    QByteArray msg;
    msg += encodeVarintField(1, 1);                    // ack = true
    msg += encodeVarintField(2, static_cast<quint64>(seqNum)); // sequenceNumber
    msg += encodeEmbeddedField(3, auth);               // auth

    return frameMessage(msg);
}

inline QByteArray buildStateQuery(qint64 seqNum)
{
    // BCMessage: ack=true, sequenceNumber, state={}, stateFilterPath="wireless"
    QByteArray msg;
    msg += encodeVarintField(1, 1);                    // ack = true
    msg += encodeVarintField(2, static_cast<quint64>(seqNum)); // sequenceNumber
    msg += encodeEmbeddedField(6, QByteArray());       // state = {} (empty = get all)
    msg += encodeStringField(601, "wireless");         // stateFilterPath

    return frameMessage(msg);
}

// --- Parsed result structures ---

struct PeerInfo {
    qint32 signal   = 0;  // received signal strength at us, from peer (dBm)
    qint32 rssi     = 0;  // SNR at us, from peer (dB)
    qint32 rate     = 0;  // link rate (in 10s of Mbps)
    qint32 peerSnr  = 0;  // peer-reported SNR (dB) - what the far end hears from us
    bool   enabled  = false;
    QString ipv4Address;
    QString linkLocalAddress;
};

struct WirelessInfo {
    QString name;
    qint32  noise    = 0;   // noise floor (dBm)
    quint32 channel  = 0;
    qint32  txpower  = 0;   // dBm
    QString nodeName;        // hostname, e.g. "rajant-115877" (Wireless field 15 -> sub-field 3)
    QString firmwareVersion; // e.g. "10.4-4019-rajant.115.c0a11264" (Wireless field 34)
    QList<PeerInfo> peers;
};

struct StateResult {
    QList<WirelessInfo> wireless;
};

// --- Protobuf field skipper ---

inline void skipField(WireType wireType, const QByteArray& data, int& pos)
{
    switch (wireType) {
    case VARINT:
        decodeVarint(data, pos);
        break;
    case FIXED64:
        pos += 8;
        break;
    case LENGTH_DELIMITED: {
        int len = static_cast<int>(decodeVarint(data, pos));
        pos += len;
        break;
    }
    case FIXED32:
        pos += 4;
        break;
    default:
        break;
    }
}

// --- Decoders ---

inline PeerInfo decodePeer(const QByteArray& data, int offset, int len)
{
    PeerInfo peer;
    int pos = offset;
    int end = offset + len;
    while (pos < end) {
        Tag tag = decodeTag(data, pos);
        switch (tag.fieldNumber) {
        case 3:  peer.enabled = decodeVarint(data, pos) != 0; break;
        case 5:  peer.rate = decodeVarintInt32(data, pos); break;
        case 6:  peer.rssi = decodeVarintInt32(data, pos); break;
        case 7:  peer.signal = decodeVarintInt32(data, pos); break;
        case 11: { // ipv4Address (string)
            int slen = static_cast<int>(decodeVarint(data, pos));
            peer.ipv4Address = QString::fromUtf8(data.mid(pos, slen));
            pos += slen;
            break;
        }
        case 14: { // linkLocalAddress (string)
            int slen = static_cast<int>(decodeVarint(data, pos));
            peer.linkLocalAddress = QString::fromUtf8(data.mid(pos, slen));
            pos += slen;
            break;
        }
        case 15: peer.peerSnr = decodeVarintInt32(data, pos); break;
        default:
            skipField(tag.wireType, data, pos);
            break;
        }
    }
    return peer;
}

inline WirelessInfo decodeWireless(const QByteArray& data, int offset, int len)
{
    WirelessInfo w;
    int pos = offset;
    int end = offset + len;
    while (pos < end) {
        Tag tag = decodeTag(data, pos);
        switch (tag.fieldNumber) {
        case 4: { // name (string)
            int slen = static_cast<int>(decodeVarint(data, pos));
            w.name = QString::fromUtf8(data.mid(pos, slen));
            pos += slen;
            break;
        }
        case 5:  w.noise = decodeVarintInt32(data, pos); break;
        case 6:  w.channel = static_cast<quint32>(decodeVarint(data, pos)); break;
        case 10: w.txpower = decodeVarintInt32(data, pos); break;
        case 15: { // nodeInfo (embedded) — contains hostname at sub-field 3
            int nlen = static_cast<int>(decodeVarint(data, pos));
            int npos = pos;
            int nend = pos + nlen;
            while (npos < nend) {
                Tag ntag = decodeTag(data, npos);
                if (ntag.fieldNumber == 3 && ntag.wireType == LENGTH_DELIMITED) {
                    int slen = static_cast<int>(decodeVarint(data, npos));
                    w.nodeName = QString::fromUtf8(data.mid(npos, slen));
                    npos += slen;
                } else {
                    skipField(ntag.wireType, data, npos);
                }
            }
            pos += nlen;
            break;
        }
        case 16: { // peer (embedded, repeated)
            int plen = static_cast<int>(decodeVarint(data, pos));
            w.peers.append(decodePeer(data, pos, plen));
            pos += plen;
            break;
        }
        case 34: { // firmwareVersion (string)
            int slen = static_cast<int>(decodeVarint(data, pos));
            w.firmwareVersion = QString::fromUtf8(data.mid(pos, slen));
            pos += slen;
            break;
        }
        default:
            skipField(tag.wireType, data, pos);
            break;
        }
    }
    return w;
}

inline StateResult decodeState(const QByteArray& data, int offset, int len)
{
    StateResult result;
    int pos = offset;
    int end = offset + len;
    while (pos < end) {
        Tag tag = decodeTag(data, pos);
        switch (tag.fieldNumber) {
        case 40: { // wireless (embedded, repeated)
            int wlen = static_cast<int>(decodeVarint(data, pos));
            result.wireless.append(decodeWireless(data, pos, wlen));
            pos += wlen;
            break;
        }
        default:
            skipField(tag.wireType, data, pos);
            break;
        }
    }
    return result;
}

// --- BCMessage top-level parser ---

struct BcapiMessage {
    QByteArray authChallenge;     // from auth.challengeOrResponse
    int        authResultStatus = -1; // -1=no result, 0=FAILURE, 1=SUCCESS
    StateResult state;
    bool       hasState = false;
};

inline BcapiMessage parseBcMessage(const QByteArray& data)
{
    BcapiMessage msg;
    int pos = 0;
    int end = data.size();

    while (pos < end) {
        Tag tag = decodeTag(data, pos);
        switch (tag.fieldNumber) {
        case 3: { // auth (embedded)
            int alen = static_cast<int>(decodeVarint(data, pos));
            int aend = pos + alen;
            while (pos < aend) {
                Tag atag = decodeTag(data, pos);
                if (atag.fieldNumber == 3 && atag.wireType == LENGTH_DELIMITED) {
                    // challengeOrResponse (bytes)
                    int clen = static_cast<int>(decodeVarint(data, pos));
                    msg.authChallenge = data.mid(pos, clen);
                    pos += clen;
                } else {
                    skipField(atag.wireType, data, pos);
                }
            }
            break;
        }
        case 300: { // authResult (embedded)
            int rlen = static_cast<int>(decodeVarint(data, pos));
            int rend = pos + rlen;
            while (pos < rend) {
                Tag rtag = decodeTag(data, pos);
                if (rtag.fieldNumber == 1) {
                    msg.authResultStatus = static_cast<int>(decodeVarint(data, pos));
                } else {
                    skipField(rtag.wireType, data, pos);
                }
            }
            break;
        }
        case 6: { // state (embedded)
            int slen = static_cast<int>(decodeVarint(data, pos));
            msg.state = decodeState(data, pos, slen);
            msg.hasState = true;
            pos += slen;
            break;
        }
        default:
            skipField(tag.wireType, data, pos);
            break;
        }
    }
    return msg;
}

// --- Frame reader helper ---
// Returns true if a complete frame is available in buffer, extracts the protobuf payload
inline bool readFrame(QByteArray& buffer, QByteArray& payload)
{
    if (buffer.size() < 8) return false;

    quint32 size = qFromBigEndian<quint32>(reinterpret_cast<const uchar*>(buffer.constData()));
    int totalFrame = 8 + static_cast<int>(size);

    if (buffer.size() < totalFrame) return false;

    payload = buffer.mid(8, static_cast<int>(size));
    buffer.remove(0, totalFrame);
    return true;
}

} // namespace BcapiProtocol
