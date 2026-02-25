/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "LinkInterface.h"
#include "LinkManager.h"
#include "QGCApplication.h"
#include "MAVLinkSigning.h"
#include "SettingsManager.h"
#include "AppSettings.h"

QGC_LOGGING_CATEGORY(LinkInterfaceLog, "LinkInterfaceLog")

// The LinkManager is only forward declared in the header, so the static_assert is here instead.
static_assert(LinkManager::invalidMavlinkChannel() == std::numeric_limits<uint8_t>::max(), "update LinkInterface::_mavlinkChannel");

LinkInterface::LinkInterface(SharedLinkConfigurationPtr& config, bool isPX4Flow)
    : QThread   (0)
    , _config   (config)
    , _isPX4Flow(isPX4Flow)
{
    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
    qRegisterMetaType<LinkInterface*>("LinkInterface*");

    // This will cause the writeBytes calls to end up on the thread of the link
    QObject::connect(this, &LinkInterface::_invokeWriteBytes, this, &LinkInterface::_writeBytes);
}

LinkInterface::~LinkInterface()
{
    if (_vehicleReferenceCount != 0) {
        qCWarning(LinkInterfaceLog) << "~LinkInterface still have vehicle references:" << _vehicleReferenceCount;
    }
    _config.reset();
}

uint8_t LinkInterface::mavlinkChannel(void) const
{
    if (!mavlinkChannelIsSet()) {
        qCWarning(LinkInterfaceLog) << "mavlinkChannel isSet() == false";
    }
    return _mavlinkChannel;
}

bool LinkInterface::mavlinkChannelIsSet(void) const
{
    return (LinkManager::invalidMavlinkChannel() != _mavlinkChannel);
}

bool LinkInterface::_allocateMavlinkChannel()
{
    // should only be called by the LinkManager during setup
    Q_ASSERT(!mavlinkChannelIsSet());
    if (mavlinkChannelIsSet()) {
        qCWarning(LinkInterfaceLog) << "_allocateMavlinkChannel already have " << _mavlinkChannel;
        return true;
    }

    auto mgr = qgcApp()->toolbox()->linkManager();
    _mavlinkChannel = mgr->allocateMavlinkChannel();
    if (!mavlinkChannelIsSet()) {
        qCWarning(LinkInterfaceLog) << "_allocateMavlinkChannel failed";
        return false;
    }
    qCDebug(LinkInterfaceLog) << "_allocateMavlinkChannel" << _mavlinkChannel;

    if (!initMavlinkSigning()) {
        qCWarning(LinkInterfaceLog) << "Failed to initialize MAVLink signing on channel" << _mavlinkChannel;
        return false;
    }

    return true;
}

void LinkInterface::_freeMavlinkChannel()
{
    qCDebug(LinkInterfaceLog) << "_freeMavlinkChannel" << _mavlinkChannel;
    if (LinkManager::invalidMavlinkChannel() == _mavlinkChannel) {
        return;
    }

    auto mgr = qgcApp()->toolbox()->linkManager();
    mgr->freeMavlinkChannel(_mavlinkChannel);
    _mavlinkChannel = LinkManager::invalidMavlinkChannel();
}

void LinkInterface::writeBytesThreadSafe(const char *bytes, int length)
{
    emit _invokeWriteBytes(QByteArray(bytes, length));
}

void LinkInterface::addVehicleReference(void)
{
    _vehicleReferenceCount++;
}

void LinkInterface::removeVehicleReference(void)
{
    if (_vehicleReferenceCount != 0) {
        _vehicleReferenceCount--;
        if (_vehicleReferenceCount == 0) {
            disconnect();
        }
    } else {
        qCWarning(LinkInterfaceLog) << "removeVehicleReference called with no vehicle references";
    }
}

bool LinkInterface::initMavlinkSigning(void)
{
    QByteArray signingKeyBytes;
    if (qgcApp() && qgcApp()->toolbox() && qgcApp()->toolbox()->settingsManager() &&
            qgcApp()->toolbox()->settingsManager()->appSettings()) {
        signingKeyBytes = qgcApp()->toolbox()->settingsManager()->appSettings()->mavlink2SigningKey()->rawValue().toByteArray();
    }

    const mavlink_accept_unsigned_t callback = isSecureConnection()
        ? MAVLinkSigning::secureConnectionAccceptUnsignedCallback
        : MAVLinkSigning::insecureConnectionAccceptUnsignedCallback;

    if (MAVLinkSigning::initSigning(static_cast<mavlink_channel_t>(_mavlinkChannel), signingKeyBytes, callback)) {
        if (signingKeyBytes.isEmpty()) {
            qCDebug(LinkInterfaceLog) << "Signing disabled on channel" << _mavlinkChannel;
        } else {
            qCDebug(LinkInterfaceLog) << "Signing enabled on channel" << _mavlinkChannel;
        }
        return true;
    }

    qCWarning(LinkInterfaceLog) << "Failed to enable signing on channel" << _mavlinkChannel;
    return false;
}

void LinkInterface::setSigningSignatureFailure(bool failure)
{
    if (_signingSignatureFailure != failure) {
        _signingSignatureFailure = failure;
        if (_signingSignatureFailure) {
            emit communicationError(tr("Signing Failure"), tr("Signing signature mismatch"));
        }
    }
}

void LinkInterface::_connectionRemoved(void)
{
    if (_vehicleReferenceCount == 0) {
        // Since there are no vehicles on the link we can disconnect it right now
        disconnect();
    } else {
        // If there are still vehicles on this link we allow communication lost to trigger and don't automatically disconect until all the vehicles go away
    }
}

#ifdef UNITTEST_BUILD
#include "MockLink.h"
bool LinkInterface::isMockLink(void)
{
    return dynamic_cast<MockLink*>(this);
}
#endif
