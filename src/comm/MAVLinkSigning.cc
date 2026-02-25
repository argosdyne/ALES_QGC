#include "MAVLinkSigning.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDebug>
#include <QRandomGenerator>
#include <QSet>

namespace {

mavlink_signing_t* _getChannelSigning(uint8_t channel)
{
    mavlink_status_t* status = mavlink_get_channel_status(channel);
    if (!status) {
        return nullptr;
    }

    return status->signing;
}

mavlink_channel_t _getMessageChannel(const mavlink_message_t &message)
{
    return static_cast<mavlink_channel_t>(message.signature[0]);
}

void _setSigningKey(mavlink_signing_t *signing, const QByteArray &key, bool randomize = false)
{
    if (randomize) {
        const size_t keySize = sizeof(signing->secret_key) / 4;
        uint32_t secretKey[keySize];
        QRandomGenerator::global()->fillRange(secretKey, static_cast<int>(keySize));
        (void) memcpy(signing->secret_key, secretKey, sizeof(signing->secret_key));
    } else if (!key.isEmpty()) {
        const QByteArray hash = QCryptographicHash::hash(key, QCryptographicHash::Sha256);
        (void) memcpy(signing->secret_key, hash.constData(), sizeof(signing->secret_key));
    } else {
        (void) memset(signing->secret_key, 0, sizeof(signing->secret_key));
    }
}

void _setSigningTimestamp(mavlink_signing_t *signing)
{
    static const QDateTime offsetTime(QDate(2015, 1, 1), QTime(0, 0), Qt::UTC);
    const uint64_t currentTimestamp = static_cast<uint64_t>(offsetTime.msecsTo(QDateTime::currentDateTimeUtc()));
    signing->timestamp = currentTimestamp * 100;
}

} // namespace

namespace MAVLinkSigning {

bool secureConnectionAccceptUnsignedCallback(const mavlink_status_t *status, uint32_t message_id)
{
    Q_UNUSED(status);
    Q_UNUSED(message_id);
    return true;
}

bool insecureConnectionAccceptUnsignedCallback(const mavlink_status_t *status, uint32_t message_id)
{
    Q_UNUSED(status);

    static const QSet<uint32_t> unsignedMessages({ MAVLINK_MSG_ID_RADIO_STATUS });
    return unsignedMessages.contains(message_id);
}

bool initSigning(mavlink_channel_t channel, const QByteArray &key, mavlink_accept_unsigned_t callback)
{
    if (!key.isEmpty() && !callback) {
        qWarning() << Q_FUNC_INFO << "callback must be specified";
        return false;
    }

    mavlink_status_t* status = mavlink_get_channel_status(channel);
    if (!status) {
        qWarning() << Q_FUNC_INFO << "Invalid channel:" << channel;
        return false;
    }

    if (key.isEmpty()) {
        status->signing = nullptr;
        status->signing_streams = nullptr;
    } else {
        static mavlink_signing_t s_signing[MAVLINK_COMM_NUM_BUFFERS];
        static mavlink_signing_streams_t s_signing_streams;

        mavlink_signing_t* signing = &s_signing[channel];
        signing->link_id = static_cast<uint8_t>(channel);
        signing->flags |= MAVLINK_SIGNING_FLAG_SIGN_OUTGOING;
        signing->accept_unsigned_callback = callback;

        _setSigningKey(signing, key);
        _setSigningTimestamp(signing);

        status->signing = signing;
        status->signing_streams = &s_signing_streams;
    }

    return true;
}

bool checkSigningLinkId(mavlink_channel_t channel, const mavlink_message_t &message)
{
    const mavlink_signing_t* signing = _getChannelSigning(channel);
    if (!signing) {
        qWarning() << Q_FUNC_INFO << "Invalid signing pointer for channel:" << channel;
        return false;
    }

    return (signing->link_id == _getMessageChannel(message));
}

void createSetupSigning(mavlink_channel_t channel, mavlink_system_t target_system, mavlink_setup_signing_t &setup_signing)
{
    (void) memset(&setup_signing, 0, sizeof(setup_signing));
    setup_signing.target_system = target_system.sysid;
    setup_signing.target_component = target_system.compid;

    const mavlink_signing_t* signing = _getChannelSigning(channel);
    if (signing) {
        setup_signing.initial_timestamp = signing->timestamp;
        (void) memcpy(setup_signing.secret_key, signing->secret_key, sizeof(setup_signing.secret_key));
    }
}

} // namespace MAVLinkSigning

