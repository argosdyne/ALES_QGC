/****************************************************************************
 * AQGC — link security (MAVLink signing pairing), see LinkSecurity.h
 ****************************************************************************/

#include "LinkSecurity.h"
#include "MAVLinkSigning.h"
#include "QGCApplication.h"
#include "MultiVehicleManager.h"
#include "MAVLinkProtocol.h"
#include "Vehicle.h"
#include "VehicleLinkManager.h"
#include "LinkInterface.h"
#include "LinkConfiguration.h"
#include "TCPLink.h"

LinkSecurity::LinkSecurity(QObject* parent)
    : QObject(parent)
{
    _timer.setSingleShot(true);
    _timer.setInterval(6000);
    connect(&_timer, &QTimer::timeout, this, &LinkSecurity::_pairTimeout);

    MAVLinkSigning* signing = MAVLinkSigning::instance();
    connect(signing, &MAVLinkSigning::keyChanged, this, &LinkSecurity::keyChanged);
    connect(signing, &MAVLinkSigning::keyChanged, this, &LinkSecurity::activeStateChanged);
    connect(signing, &MAVLinkSigning::channelStateChanged, this, &LinkSecurity::_channelStateChanged);

    MultiVehicleManager* mvm = qgcApp()->toolbox()->multiVehicleManager();
    connect(mvm, &MultiVehicleManager::activeVehicleChanged, this, &LinkSecurity::_activeVehicleChanged);
    _activeVehicleChanged(mvm->activeVehicle());
}

void LinkSecurity::_activeVehicleChanged(Vehicle* vehicle)
{
    if (_vehicle) {
        disconnect(_vehicle, nullptr, this, nullptr);
        disconnect(_vehicle->vehicleLinkManager(), nullptr, this, nullptr);
    }
    _vehicle = vehicle;
    if (_vehicle) {
        connect(_vehicle, &Vehicle::armedChanged, this, &LinkSecurity::pairBlockChanged);
        connect(_vehicle->vehicleLinkManager(), &VehicleLinkManager::primaryLinkChanged, this, &LinkSecurity::pairBlockChanged);
        connect(_vehicle->vehicleLinkManager(), &VehicleLinkManager::primaryLinkChanged, this, &LinkSecurity::activeStateChanged);
    }
    emit pairBlockChanged();
    emit activeStateChanged();
}

bool LinkSecurity::hasKey() const       { return MAVLinkSigning::instance()->hasKey(); }
QString LinkSecurity::fingerprint() const { return MAVLinkSigning::instance()->fingerprint(); }
QString LinkSecurity::securityLogPath() const { return MAVLinkSigning::instance()->securityLogPath(); }

QString LinkSecurity::keyDate() const
{
    const QDateTime d = MAVLinkSigning::instance()->keyDate();
    return d.isValid() ? d.date().toString(Qt::ISODate) : QString();
}

int LinkSecurity::_activeChannel() const
{
    if (!_vehicle) {
        return -1;
    }
    SharedLinkInterfacePtr link = _vehicle->vehicleLinkManager()->primaryLink().lock();
    return link ? static_cast<int>(link->mavlinkChannel()) : -1;
}

int LinkSecurity::activeState() const
{
    const int chan = _activeChannel();
    return chan < 0 ? -1 : static_cast<int>(MAVLinkSigning::channelState(static_cast<uint8_t>(chan)));
}

QString LinkSecurity::pairBlock() const
{
    if (!_vehicle) {
        return QStringLiteral("novehicle");
    }
    if (_vehicle->armed()) {
        return QStringLiteral("armed");
    }
    SharedLinkInterfacePtr link = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (!link) {
        return QStringLiteral("novehicle");
    }
    SharedLinkConfigurationPtr config = link->linkConfiguration();
    if (config && config->type() == LinkConfiguration::TypeSerial) {
        return QString();       // USB cable (or a serial radio: the operator connects the cable as told)
    }
    // A link to this computer only (SITL): the key never leaves the PC
    if (config && config->type() == LinkConfiguration::TypeTcp) {
        TCPConfiguration* tcp = qobject_cast<TCPConfiguration*>(config.get());
        if (tcp && (tcp->host() == QStringLiteral("127.0.0.1") || tcp->host() == QStringLiteral("localhost"))) {
            return QString();
        }
    }
    return QStringLiteral("usb");
}

bool LinkSecurity::_sendSetupSigning(const QByteArray& key, uint64_t timestamp)
{
    SharedLinkInterfacePtr link = _vehicle ? _vehicle->vehicleLinkManager()->primaryLink().lock() : SharedLinkInterfacePtr();
    if (!link) {
        return false;
    }
    MAVLinkProtocol* mavlink = qgcApp()->toolbox()->mavlinkProtocol();
    mavlink_message_t msg;
    MAVLinkSigning::packSetupSigning(link->mavlinkChannel(),
                                     static_cast<uint8_t>(mavlink->getSystemId()), static_cast<uint8_t>(mavlink->getComponentId()),
                                     static_cast<uint8_t>(_vehicle->id()), static_cast<uint8_t>(_vehicle->defaultComponentId()),
                                     key, timestamp, &msg);
    return _vehicle->sendMessageOnLinkThreadSafe(link.get(), msg);
}

void LinkSecurity::pair()
{
    if (_busy || !pairBlock().isEmpty()) {
        return;
    }
    MAVLinkSigning* signing = MAVLinkSigning::instance();
    const QByteArray newKey = signing->createKey();
    // a key change: keep the old key in memory until the drone confirms the new one
    _oldKey = signing->hasKey() ? signing->keyBytes() : QByteArray();
    _pairChan = _activeChannel();
    // Packed (and signed with the current key, if any) before the local key changes
    if (!_sendSetupSigning(newKey, MAVLinkSigning::timestampNow())) {
        _setResult(QStringLiteral("refused"));
        return;
    }
    signing->setKey(newKey);
    _setResult(QString());
    _setBusy(true);
    _timer.start();
}

void LinkSecurity::_channelStateChanged(int chan, int state)
{
    if (chan == _activeChannel()) {
        emit activeStateChanged();
    }
    if (_busy && chan == _pairChan && state == MAVLinkSigning::StateProtected) {
        _timer.stop();
        _setBusy(false);
        _oldKey.fill('\0');
        _oldKey.clear();
        _setResult(QStringLiteral("ok"));
    }
}

void LinkSecurity::_pairTimeout()
{
    _setBusy(false);
    MAVLinkSigning* signing = MAVLinkSigning::instance();
    signing->logEvent(QStringLiteral("the drone did not accept the key (no signed packets in 6 s)"));
    if (!_oldKey.isEmpty()) {
        // the drone still has the old key: without it we could not control the drone any more
        signing->setKey(_oldKey);
        _oldKey.fill('\0');
        _oldKey.clear();
        signing->logEvent(QStringLiteral("went back to the previous key"));
        _setResult(QStringLiteral("reverted"));
        return;
    }
    _setResult(QStringLiteral("refused"));
}

void LinkSecurity::removeKey()
{
    if (_busy || !pairBlock().isEmpty() || !hasKey()) {
        return;
    }
    // signed with the current key: ArduPilot ignores an unsigned SETUP_SIGNING once it has a key
    _sendSetupSigning(QByteArray(32, '\0'), 0);
    _setBusy(true);
    QTimer::singleShot(800, this, [this]() {
        MAVLinkSigning::instance()->removeKey();
        _setBusy(false);
        _setResult(QStringLiteral("removed"));
    });
}

void LinkSecurity::forgetLocalKey()
{
    if (!hasKey()) {
        return;
    }
    MAVLinkSigning::instance()->logEvent(QStringLiteral("key deleted here only (Delete my data); paired drones keep theirs"));
    MAVLinkSigning::instance()->removeKey();
    _setResult(QStringLiteral("forgotten"));
}

void LinkSecurity::_setBusy(bool busy)
{
    if (_busy != busy) {
        _busy = busy;
        emit busyChanged();
    }
}

void LinkSecurity::_setResult(const QString& result)
{
    if (_result != result) {
        _result = result;
        emit resultChanged();
    }
}
