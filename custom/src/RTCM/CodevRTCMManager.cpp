#include "CodevRTCMManager.h"
#include "QGCApplication.h"
#include "NTRIPRTCMSource.h"
#include "SerialPortRTCMSource.h"
#include "Vehicle.h"
#include "CustomPlugin.h"
#include "codevsettings.h"
#include "CustomSettings.h"
#include "QGCLoggingCategory.h"

QGC_LOGGING_CATEGORY(CodevRTCMManagerLog, "CodevRTCMManagerLog")

CodevRTCMManager::CodevRTCMManager(QGCApplication *app, QGCToolbox *toolbox)
    : QGCTool(app, toolbox)
{

}

void CodevRTCMManager::setToolbox(QGCToolbox *toolbox)
{
    QGCTool::setToolbox(toolbox);

    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
    qmlRegisterUncreatableType<CodevRTCMManager>("CustomQuickInterface", 1, 0, "CodevRTCMManager", "Reference only");
    qmlRegisterUncreatableType<RTCMBase>("CustomQuickInterface", 1, 0, "RTCMBase", "Reference only");

    MultiVehicleManager *manager = _toolbox->multiVehicleManager();
    _setActiveVehicle(manager->activeVehicle());
    connect(manager, &MultiVehicleManager::activeVehicleChanged, this, &CodevRTCMManager::_setActiveVehicle);

    //Fact* rtcmSourceFact = dynamic_cast<CustomPlugin*>(_toolbox->corePlugin())->codevSettings()->rtcmSource();
    Fact* rtcmSourceFact = dynamic_cast<CustomPlugin*>(_toolbox->corePlugin())->settings()->rtcmSource();
    _setRTCMSource(rtcmSourceFact->rawValue());
    connect(rtcmSourceFact, &Fact::rawValueChanged, this, &CodevRTCMManager::_setRTCMSource);
}

void CodevRTCMManager::_setActiveVehicle(Vehicle* vehicle)
{
    if(_vehicle) {
        disconnect(_vehicle, &Vehicle::mavlinkMessageReceived, this, &CodevRTCMManager::_mavlinkReceived);
    }
    _vehicle = vehicle;

    if (_vehicle) {
        connect(_vehicle, &Vehicle::mavlinkMessageReceived, this, &CodevRTCMManager::_mavlinkReceived);
        qInfo() << "RTCM: active vehicle set for GPS_RTCM send, sysid" << _vehicle->id();
    } else {
        qWarning() << "RTCM: active vehicle cleared — GPS_RTCM will not be sent until a vehicle is active";
    }
}

void CodevRTCMManager::_mavlinkReceived(const mavlink_message_t &message)
{
    if(message.msgid == MAVLINK_MSG_ID_GPS_RAW_INT) {
        emit received_gps_raw_int_status(message);
    }
}

void CodevRTCMManager::_sendMavlinkRTCM(mavlink_gps_rtcm_data_t message)
{
    MAVLinkProtocol* mavlinkProtocol = _toolbox->mavlinkProtocol();
    if (!mavlinkProtocol) {
        qWarning() << "RTCM: drop GPS_RTCM chunk — MAVLinkProtocol is null";
        return;
    }
    if (!_vehicle) {
        qWarning() << "RTCM: drop GPS_RTCM chunk — no active vehicle (len" << message.len << ")";
        return;
    }
    WeakLinkInterfacePtr weakLink = _vehicle->vehicleLinkManager()->primaryLink();
    if (weakLink.expired()) {
        qWarning() << "RTCM: drop GPS_RTCM chunk — primary link expired (len" << message.len << ")";
        return;
    }
    mavlink_message_t msg;
    SharedLinkInterfacePtr sharedLink = weakLink.lock();
    mavlink_msg_gps_rtcm_data_encode(mavlinkProtocol->getSystemId(),
                                     mavlinkProtocol->getComponentId(),
                                     &msg,
                                     &message);
    _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), msg);
}

void CodevRTCMManager::_setRTCMSource(QVariant value)
{
    if(_rtcmSource) {
        _rtcmSource->deleteLater();
        _rtcmSource = nullptr;
    }
    switch (value.toInt()) {
    case 1:
        _rtcmSource = new NTRIPRTCMSource(this);
        connect(this, &CodevRTCMManager::received_gps_raw_int_status, _rtcmSource, &NTRIPRTCMSource::handle_gps_raw_int_status);
        break;
    case 2:
        _rtcmSource = new SerialPortRTCMSource(this);
        break;
    default:
        break;
    }
    if(_rtcmSource)
        connect(_rtcmSource, &RTCMBase::sendMavlinkRTCM, this, &CodevRTCMManager::_sendMavlinkRTCM);
    emit rtcmSourceChanged();
}
