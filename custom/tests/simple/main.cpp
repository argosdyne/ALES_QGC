// Qt Quick Test runner for the Simple UI. Provides the `globals` context property the app sets in MainRootWindow.
#include <QtQuickTest>
#include <QQmlEngine>
#include <QQmlContext>
#include <QQmlPropertyMap>

#include <cstring>
#include "MAVLinkSigning.h"

// QGCApplication.cc owns the channel status array in the app (MAVLINK_EXTERNAL_RX_STATUS)
mavlink_status_t m_mavlink_status[MAVLINK_COMM_NUM_BUFFERS];

// MAVLink signing (S66) test hooks for tst_signing.qml
class SigningTest : public QObject
{
    Q_OBJECT
public:
    using QObject::QObject;
    static QByteArray keyOf(int b) { return QByteArray(32, static_cast<char>(b)); }
    Q_INVOKABLE void    setKey      (int b)     { MAVLinkSigning::instance()->setKey(keyOf(b)); }
    Q_INVOKABLE void    removeKey   ()          { MAVLinkSigning::instance()->removeKey(); }
    Q_INVOKABLE bool    hasKey      ()          { return MAVLinkSigning::instance()->hasKey(); }
    Q_INVOKABLE QString fingerprint ()          { return MAVLinkSigning::instance()->fingerprint(); }
    Q_INVOKABLE QString fingerprintOf(int b)    { return MAVLinkSigning::fingerprintOf(keyOf(b)); }
    Q_INVOKABLE double  timestampNow()          { return static_cast<double>(MAVLinkSigning::timestampNow()); }
    Q_INVOKABLE void    initChannel (int c)     { MAVLinkSigning::initChannel(static_cast<uint8_t>(c)); }
    Q_INVOKABLE void    clearChannel(int c)     { MAVLinkSigning::clearChannel(static_cast<uint8_t>(c)); }
    Q_INVOKABLE int     state       (int c)     { return MAVLinkSigning::channelState(static_cast<uint8_t>(c)); }
    /// a packet from the drone (system 1): msgId 0 = HEARTBEAT, 109 = RADIO_STATUS; signKey 0 = unsigned,
    /// else signed with keyOf(signKey); droneAgeSec = how far the drone signing clock is behind ours
    Q_INVOKABLE bool    feed(int chan, int msgId, int signKey, double droneAgeSec = 0)
    {
        const uint8_t packChan = MAVLINK_COMM_NUM_BUFFERS - 1;     // a spare channel to pack the drone's packet
        mavlink_status_t* st = mavlink_get_channel_status(packChan);
        std::memset(st, 0, sizeof(*st));
        mavlink_signing_t sg;
        std::memset(&sg, 0, sizeof(sg));
        if (signKey) {
            sg.flags = MAVLINK_SIGNING_FLAG_SIGN_OUTGOING; sg.link_id = 0;
            sg.timestamp = MAVLinkSigning::timestampNow() - static_cast<uint64_t>(droneAgeSec * 1e5);
            const QByteArray k = keyOf(signKey); std::memcpy(sg.secret_key, k.constData(), 32);
            st->signing = &sg;
        }
        mavlink_message_t msg;
        if (msgId == MAVLINK_MSG_ID_RADIO_STATUS) {
            mavlink_msg_radio_status_pack_chan(1, 68, packChan, &msg, 200, 190, 100, 90, 10, 0, 0);
        } else {
            mavlink_msg_heartbeat_pack_chan(1, 1, packChan, &msg, MAV_TYPE_QUADROTOR, MAV_AUTOPILOT_ARDUPILOTMEGA, 0, 0, MAV_STATE_STANDBY);
        }
        st->signing = nullptr;
        // as received: the parser fills msg.ck, packing does not
        msg.ck[0] = static_cast<uint8_t>(msg.checksum & 0xFF);
        msg.ck[1] = static_cast<uint8_t>(msg.checksum >> 8);
        return MAVLinkSigning::packetReceived(static_cast<uint8_t>(chan), msg);
    }
};


class Setup : public QObject
{
    Q_OBJECT
public slots:
    void qmlEngineAvailable(QQmlEngine* engine)
    {
        auto* globals = new QQmlPropertyMap(engine);
        globals->insert(QStringLiteral("planMasterControllerFlyView"), QVariant());
        globals->insert(QStringLiteral("guidedControllerFlyView"), QVariant());    // tests set a double (S35 Go here)
        engine->rootContext()->setContextProperty(QStringLiteral("globals"), globals);
        engine->rootContext()->setContextProperty(QStringLiteral("signingTest"), new SigningTest(engine));
    }
};

QUICK_TEST_MAIN_WITH_SETUP(simple, Setup)

#include "main.moc"
