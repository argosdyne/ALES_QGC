#include "CustomVehicle.h"
#include "ParameterManager.h"
#include "QGCApplication.h"
#include "CustomPlugin.h"
#include "QGCCameraManager.h"

const char* CustomVehicle::_escFactGroupName = "esc";
static const char* kGPSPrimeParam = "SENS_GPS_PRIME";
static const char* kRTLBakHomeLatFact = "RTL_BAK_HOME_LAT";
static const char* kRTLBakHomeLonFact = "RTL_BAK_HOME_LON";

static bool _isR3CameraModel(const QString& modelName)
{
    return modelName.contains(QStringLiteral("R3"), Qt::CaseInsensitive)
            || modelName.contains(QStringLiteral("RHYTHM"), Qt::CaseInsensitive);
}

static const char* kSYS_LIDAR_ODOM = "SYS_LIDAR_ODOM";

CustomVehicle::CustomVehicle(LinkInterface*             link,
                             int                        vehicleId,
                             int                        defaultComponentId,
                             MAV_AUTOPILOT              firmwareType,
                             MAV_TYPE                   vehicleType,
                             FirmwarePluginManager*     firmwarePluginManager,
                             JoystickManager*           joystickManager)
    : Vehicle(link, vehicleId, defaultComponentId, firmwareType, vehicleType, firmwarePluginManager, joystickManager)
    , _escFactGroup(this)
    , _plugin(qobject_cast<CustomPlugin*>(qgcApp()->toolbox()->corePlugin()))
{
  //  qInfo() << "CutomVehicle Start!!";
    connect(this, &CustomVehicle::capabilityBitsChanged, this, &CustomVehicle::supportMissionChanged);
    connect(parameterManager(), &ParameterManager::parametersReadyChanged, this, &CustomVehicle::vehicleFactChanged);
    connect(parameterManager(), &ParameterManager::parametersReadyChanged, this, &CustomVehicle::flightModesChanged);
    connect(parameterManager(), &ParameterManager::parametersReadyChanged, this, &CustomVehicle::forcedPositionChanged);
    connect(this, &CustomVehicle::mavlinkMessageReceived, this, &CustomVehicle::_mavlinkMessageReceived);
    connect(qgcApp()->toolbox()->uasMessageHandler(), &UASMessageHandler::textMessageReceived,      this, &CustomVehicle::_handletextMessageReceivedCustom);
    connect(distanceToHome(), &Fact::rawValueChanged, this, &CustomVehicle::_handledistanceToHomeChanged);
    if (_plugin && cameraManager()) {
        connect(_plugin, &CustomPlugin::rcChannelValuesChanged,
                cameraManager(), &QGCCameraManager::handleAviatorRCChannelValues,
                Qt::UniqueConnection);
    }

    _addFactGroup(&_escFactGroup, _escFactGroupName);

    if(_plugin->forceSendRC()) {
       // qInfo() << "CustomVehicle.cc forDceSendRC true";
        connect(_plugin, &CustomPlugin::rcChannelValuesChanged, this, &CustomVehicle::_sendRcChannelValues, Qt::UniqueConnection);
    } else {
      //  qInfo() << "CustomVehicle.cc else";
        _rcChannelsTimer.setSingleShot(true);
        connect(&_rcChannelsTimer, &QTimer::timeout, this, &CustomVehicle::_rcChannelsTimeOut);
        _initRcChannelsTimer(false);
        connect(vehicleLinkManager(), &VehicleLinkManager::communicationLostChanged, this, &CustomVehicle::_initRcChannelsTimer);
    }
    connect(vehicleLinkManager(), &VehicleLinkManager::primaryLinkChanged, this, &CustomVehicle::mainLinkChanged);
}

void CustomVehicle::_initRcChannelsTimer(bool lost)
{
    _rcChannelsTimer.stop();
    if(lost) {
       // qInfo() << "_initRcChannelsTimer lost";
        disconnect(_plugin, &CustomPlugin::rcChannelValuesChanged, this, &CustomVehicle::_sendRcChannelValues);
       // qInfo() << "CustomVehicle.cc disconnect rcChannelValuesChanged";
    } else {
        //qInfo() << "lost is false _rcChannelTimer Start";
        _rcChannelsTimer.start(2000);
        connect(this, &CustomVehicle::rcChannelsChanged, this, &CustomVehicle::_rcChannelsComing, Qt::UniqueConnection);
    }
}

void CustomVehicle::_rcChannelsComing()
{
    if(_rcChannelsTimer.remainingTime() < 1000 && !_plugin->forceSendRC()) {
        disconnect(this, &CustomVehicle::rcChannelsChanged, this, &CustomVehicle::_rcChannelsComing);

        connect(_plugin, &CustomPlugin::rcChannelValuesChanged, this, &CustomVehicle::_sendRcChannelValues, Qt::UniqueConnection);

        _rcChannelsTimer.stop();
        _rcOnUDP = false;
        emit rcOnUDPChanged();
    }
}

void CustomVehicle::_rcChannelsTimeOut()
{
    qInfo(VehicleLog) << "The rc channels from the aircraft is not received, and local rc channels is sent actively.";
    QString text = tr("RC Channels are sending byself.");
//    _plugin->showMessage(text, SystemMessage::Warning);
    qgcApp()->toolbox()->audioOutput()->say(text);
    disconnect(this, &CustomVehicle::rcChannelsChanged, this, &CustomVehicle::_rcChannelsComing);
    //qInfo() << "CustomVehicle.cc _rcChannelsTimeout Connect";
    connect(_plugin, &CustomPlugin::rcChannelValuesChanged, this, &CustomVehicle::_sendRcChannelValues, Qt::UniqueConnection);
    _rcOnUDP = true;
    emit rcOnUDPChanged();
}

void CustomVehicle::_sendRcChannelValues(const quint16* channels, int count)
{
    quint16 sendChannels[18];
    memcpy(sendChannels, channels, sizeof(sendChannels));

    const bool neutralizeR3GimbalRC = false;
    bool isR3GimbalRC = false;
    bool px4MountManualMappingDisabled = false;
    QString rcCameraModel;
    QString rcCameraVendor;
    if (count >= 10 && firmwareType() == MAV_AUTOPILOT_PX4 && cameraManager()) {
        if (QGCCameraControl* camera = cameraManager()->currentCameraInstance()) {
            rcCameraModel = camera->modelName();
            rcCameraVendor = camera->vendor();
            isR3GimbalRC = camera->compID() == MAV_COMP_ID_CAMERA
                    && _isR3CameraModel(rcCameraModel);
        }
    }

    if (isR3GimbalRC) {
        auto px4MountParamValue = [this](const char* paramName, int& value) -> bool {
            if (!parameterManager()->parametersReady()) {
                return false;
            }
            if (!parameterManager()->parameterExists(defaultComponentId(), paramName)) {
                return false;
            }

            value = parameterManager()->getParameter(defaultComponentId(), paramName)->rawValue().toInt();
            return true;
        };

        bool checkedMountManualParam = false;
        bool mountManualParamMapped = false;
        const char* mountManualParams[] = {
            "MNT_MAN_PITCH",
            "MNT_MAN_YAW",
            "MNT_MAN_ROLL",
        };
        for (const char* mountManualParam : mountManualParams) {
            int paramValue = 0;
            if (px4MountParamValue(mountManualParam, paramValue)) {
                checkedMountManualParam = true;
                if (paramValue != 0) {
                    mountManualParamMapped = true;
                    break;
                }
            }
        }

        px4MountManualMappingDisabled = checkedMountManualParam && !mountManualParamMapped;
    }

    if (neutralizeR3GimbalRC) {
        sendChannels[8] = 1500;
        sendChannels[9] = 1500;
    }

    qInfo(VehicleLog) << "[RCFlow]"
                      << "send rc channels"
                      << "vehicleId" << id()
                      << "count" << count
                      << "slaveMode" << _plugin->slaveMode()
                      << "forceSendRC" << _plugin->forceSendRC()
                      << "isR3GimbalRC" << isR3GimbalRC
                      << "px4MountManualMappingDisabled" << px4MountManualMappingDisabled
                      << "neutralizeR3GimbalRC" << neutralizeR3GimbalRC
                      << "cameraModel" << rcCameraModel
                      << "cameraVendor" << rcCameraVendor
                      << "rawCh9-12"
                      << channels[8] << channels[9] << channels[10] << channels[11]
                      << "ch1-4"
                      << sendChannels[0] << sendChannels[1] << sendChannels[2] << sendChannels[3]
                      << "ch5-8"
                      << sendChannels[4] << sendChannels[5] << sendChannels[6] << sendChannels[7]
                      << "ch9-12"
                      << sendChannels[8] << sendChannels[9] << sendChannels[10] << sendChannels[11]
                      << "ch13-18"
                      << sendChannels[12] << sendChannels[13] << sendChannels[14]
                      << sendChannels[15] << sendChannels[16] << sendChannels[17];
    static MAVLinkProtocol* mavlink = qgcApp()->toolbox()->mavlinkProtocol();
    if(count >= 14) {
        mavlink_message_t msg;
        if(_plugin->slaveMode()) {
            //qInfo() << "_plugin->slaveMode()";
            mavlink_msg_rc_channels_override_pack(
                static_cast<uint8_t>(mavlink->getSystemId()),
                static_cast<uint8_t>(mavlink->getComponentId()),
                &msg,
                static_cast<uint8_t>(id()),
                0,
                sendChannels[0],
                sendChannels[1],
                sendChannels[2],
                sendChannels[3],
                sendChannels[4],
                sendChannels[5],
                sendChannels[6],
                sendChannels[7],
                sendChannels[8],
                sendChannels[9],
                sendChannels[10],
                sendChannels[11],
                sendChannels[12],
                sendChannels[13],
                sendChannels[14],
                sendChannels[15],
                sendChannels[16],
                sendChannels[17]
            );
        } else {
           //qInfo()<< "else slave mode";
            mavlink_rc_channels_t rc_channels;
            memcpy(&rc_channels.chan1_raw, sendChannels, 18 * 2);
            rc_channels.time_boot_ms = static_cast<uint32_t>(QGC::groundTimeMilliseconds());
            rc_channels.chancount = static_cast<uint8_t>(count);
            rc_channels.rssi = 255;
            mavlink_msg_rc_channels_encode(
                static_cast<uint8_t>(mavlink->getSystemId()),
                static_cast<uint8_t>(mavlink->getComponentId()),
                &msg,
                &rc_channels);
        }
        WeakLinkInterfacePtr weakLink = vehicleLinkManager()->primaryLink();
        if (!weakLink.expired()) {
            SharedLinkInterfacePtr sharedLink = weakLink.lock();
            //qInfo() << "!weakLink.expired";
            sendMessageOnLinkThreadSafe(sharedLink.get(), msg);
            //qInfo() << "sendMessageOnLinkThreadSafe Success";
            //qInfo() << "CustomVehicle.cc Msg = " << msg.sysid;
        }
        else {
            qInfo() << "weakLink.expired";
        }
    }
}

QString CustomVehicle::mainLinkName()
{
    //qInfo() << "Main Link Name ";
    if (!vehicleLinkManager()->primaryLink().expired()) {
        LinkConfiguration::LinkType type = vehicleLinkManager()->primaryLink().lock()->linkConfiguration()->type();
        if(type == LinkConfiguration::TypeUdp) {
            return tr("UDP");
        } else if(type == LinkConfiguration::TypeSerial) {
            return tr("Serial");
        } else {
            return tr("Other");
        }
    }

    return tr("Unknow");
}

Fact* CustomVehicle::gpsPrimeFact()
{
    if (parameterManager()->parameterExists(defaultComponentId(), kGPSPrimeParam)) {
        Fact* fact = parameterManager()->getParameter(defaultComponentId(), kGPSPrimeParam);
        QQmlEngine::setObjectOwnership(fact, QQmlEngine::CppOwnership);
        return fact;
    }
    return nullptr;
}

Fact* CustomVehicle::rtlBakHomeLatFact()
{
    if (parameterManager()->parameterExists(defaultComponentId(), kRTLBakHomeLatFact)) {
        Fact* fact = parameterManager()->getParameter(defaultComponentId(), kRTLBakHomeLatFact);
        QQmlEngine::setObjectOwnership(fact, QQmlEngine::CppOwnership);
        return fact;
    }
    return nullptr;
}

Fact* CustomVehicle::rtlBakHomeLonFact()
{
    if (parameterManager()->parameterExists(defaultComponentId(), kRTLBakHomeLonFact)) {
        Fact* fact = parameterManager()->getParameter(defaultComponentId(), kRTLBakHomeLonFact);
        QQmlEngine::setObjectOwnership(fact, QQmlEngine::CppOwnership);
        return fact;
    }
    return nullptr;
}

Fact* CustomVehicle::sysLidarOdomFact()
{
    if (parameterManager()->parameterExists(defaultComponentId(), kSYS_LIDAR_ODOM)) {
        Fact* fact = parameterManager()->getParameter(defaultComponentId(), kSYS_LIDAR_ODOM);
        QQmlEngine::setObjectOwnership(fact, QQmlEngine::CppOwnership);
        return fact;
    }
    return nullptr;
}

void CustomVehicle::applyCurrentPositionRTLbakHome()
{
    VehicleGPSFactGroup* gps = !_isSecondGPS ? qobject_cast<VehicleGPSFactGroup*>(gpsFactGroup()) : qobject_cast<VehicleGPSFactGroup*>(gps2FactGroup());
    Fact* latFact = rtlBakHomeLatFact();
    Fact* lonFact = rtlBakHomeLonFact();
    if(latFact && lonFact && gps) {
        int lat = static_cast<int>(gps->lat()->rawValue().toDouble() * 1E7);
        int lon = static_cast<int>(gps->lon()->rawValue().toDouble() * 1E7);
        latFact->forceSetRawValue(lat);
        lonFact->forceSetRawValue(lon);
        QTimer::singleShot(500, [lat, lon, latFact, lonFact, this]() {
            if(lonFact->rawValue().toInt() == lon && latFact->rawValue().toInt() == lat) {
                _plugin->showMessage(tr("Set the forced landing point successfully."), SystemMessage::Success);
            } else {
                _plugin->showMessage(tr("Set the forced landing point failed!"), SystemMessage::Warning);
            }
            emit forcedPositionChanged();
        });
    } else {
        _plugin->showMessage(tr("Setting of forced landing points is not supported."), SystemMessage::Warning);
    }
}

void CustomVehicle::removeRTLbakHome()
{
    Fact* latFact = rtlBakHomeLatFact();
    Fact* lonFact = rtlBakHomeLonFact();
    if(latFact && lonFact) {
        int lat = 0;
        int lon = 0;
        latFact->forceSetRawValue(lat);
        lonFact->forceSetRawValue(lon);
        QTimer::singleShot(500, [lat, lon, latFact, lonFact, this]() {
            if(lonFact->rawValue().toInt() == lon && latFact->rawValue().toInt() == lat) {
                _plugin->showMessage(tr("Remove the forced landing point successfully."), SystemMessage::Success);
            } else {
                _plugin->showMessage(tr("Remove the forced landing point failed!"), SystemMessage::Warning);
            }
            emit forcedPositionChanged();
        });
    } else {
        _plugin->showMessage(tr("Setting of forced landing points is not supported."), SystemMessage::Warning);
    }
}

QGeoCoordinate CustomVehicle::forcedPosition()
{
    Fact* latFact = rtlBakHomeLatFact();
    Fact* lonFact = rtlBakHomeLonFact();
    if(latFact && lonFact) {
        int lat = latFact->rawValue().toInt();
        int lon = lonFact->rawValue().toInt();
        if(lat != 0 && lon != 0)
            return QGeoCoordinate(static_cast<double>(lat) / 1E7,  static_cast<double>(lon) / 1E7);
    }
    return QGeoCoordinate();
}

void CustomVehicle::_handletextMessageReceivedCustom(UASMessage* message)
{
    if (message && _plugin) {
        SystemMessage::SystemMessageType type = SystemMessage::Info;
        if(message->severityIsError()) {
            type = SystemMessage::Error;
        } else if(message->getSeverity() == MAV_SEVERITY_WARNING) {
            type = SystemMessage::Warning;
        } else if(message->getSeverity() == MAV_SEVERITY_NOTICE) {
            type = SystemMessage::Warning;
        }
        if(type != SystemMessage::Info) {
            _plugin->showMessage(message->getText(), type);
        }
    }
}

void CustomVehicle::_mavlinkMessageReceived(const mavlink_message_t& message)
{
    //qInfo() << "CustomVehicle.cc _mavlinkMessageReceived";
    switch (message.msgid) {
    case MAVLINK_MSG_ID_ODOMETRY:
        _handleOdometry(message);
        break;
    case MAVLINK_MSG_ID_GPS_RAW_INT:
        _handleGpsRawInt2(message);
        break;
    case MAVLINK_MSG_ID_LANDING_TARGET:
        _handleLandingTarget(message);
        break;
    case MAVLINK_MSG_ID_MANUAL_CONTROL:
        _handleManualControl(message);
        break;
    case MAVLINK_MSG_ID_PING:
        if(message.compid == MAV_COMP_ID_UDP_BRIDGE) {
            _handleBrigePing(message);
        }
        break;
    default:
        break;
    }
}

void CustomVehicle::_handleOdometry(const mavlink_message_t &message)
{
    //qInfo() << "_handleOdometry";
    mavlink_odometry_t odometry_msg;
    mavlink_msg_odometry_decode(&message, &odometry_msg);

    quint64 time_diff = (odometry_msg.time_usec - _lastTime) / 1000; // ms
    if(time_diff < 1000) {
        if(fabs(odometry_msg.vz) > 0.1f) {
            _heightDiff += (_lastVz + odometry_msg.vz) / 2.0f * (static_cast<float>(time_diff) / 1000.0f);
        } else {
            _heightDiff = 0;
        }
        if(fabs(odometry_msg.vx) <= 0.1f && fabs(odometry_msg.vy) <= 0.1f) {
            _distanceDiff = 0;
        }
    } else {
        _heightDiff = 0;
        _distanceDiff = 0;
    }

    _lastVx = odometry_msg.vx;
    _lastVy = odometry_msg.vy;
    _lastVz = odometry_msg.vz;
    _lastTime = odometry_msg.time_usec;

    emit vehicleDiffChanged();
}

void CustomVehicle::_handleGpsRawInt2(const mavlink_message_t& message)
{
    mavlink_gps_raw_int_t gpsRawInt;
    mavlink_msg_gps_raw_int_decode(&message, &gpsRawInt);

    bool isSecondGPS = (gpsRawInt.cog == 255);
    if(_isSecondGPS != isSecondGPS) {
        _isSecondGPS = isSecondGPS;
        emit isSecondGPSChanged();
    }
}

void CustomVehicle::_handleLandingTarget(const mavlink_message_t& message)
{
    mavlink_landing_target_t landingTarget;
    mavlink_msg_landing_target_decode(&message, &landingTarget);

    QString messageText = tr("LandTarget X:%1, Y:%2, Size:%3").arg(static_cast<int>(landingTarget.x), 4, 10, QLatin1Char('0'))
                                                      .arg(static_cast<int>(landingTarget.y), 4, 10, QLatin1Char('0'))
                                                      .arg(static_cast<int>(landingTarget.z), 3, 10, QLatin1Char('0'));

    showStatusMessage(messageText, "Landing Target");
}

void CustomVehicle::_handleManualControl(const mavlink_message_t& message)
{
    mavlink_manual_control_t manualControl;
    mavlink_msg_manual_control_decode(&message, &manualControl);

    bool rcInControl = (manualControl.buttons2 < 2);
    if(rcInControl != _rcInControl) {
        _rcInControl = rcInControl;
        emit rcInControlChanged();
    }
}

void CustomVehicle::_handleBrigePing(const mavlink_message_t& message)
{
    //qInfo() << "CustomVehicle.cc _handleBrigePing";
    mavlink_ping_t ping;
    mavlink_msg_ping_decode(&message, &ping);

    int id = ((ping.seq >> 24) & 0xff);
    int channel = (ping.seq & 0xff);
    if(id == this->id() && channel > 0) {
        uint delay = (ping.time_usec >> 32) & 0xffffffff;
        ushort delay_main = (delay & 0xffff);
        ushort delay_sub = ((delay >> 16) & 0xffff);
        if(_channel_id != channel) {
            if(channel == 1) {
                QString text = tr("Switch to Local Link.");
                _plugin->showMessage(text, SystemMessage::Info);
                qgcApp()->toolbox()->audioOutput()->say(text);
            } else {
                QString text = tr("Switch to LTE Link.");
                _plugin->showMessage(text, SystemMessage::Info);
                qgcApp()->toolbox()->audioOutput()->say(text);
            }
            _channel_id = channel;
            emit onLTEChanged();
        }
        if(delay_main < 500 && delay_sub < 500) {
            _linkdelay = QString("%1/%2 ms").arg(delay_main).arg(delay_sub);
        } else {
            _linkdelay = QString("%1 ms").arg(qMin(delay_main, delay_sub));
        }
        emit linkdelayChanged();
    }
}

void CustomVehicle::showStatusMessage(const QString& message, const QString& name)
{
    StatusMessage* status = nullptr;
    for(int i = 0; i < _statusMessages.count(); i++) {
        if(_statusMessages.get(i)->objectName().compare(name) == 0) {
            status = _statusMessages.value<StatusMessage*>(i);
            break;
        }
    }

    if(status) {
        status->setContext(message);
    } else {
        status = new StatusMessage(this);
        connect(status, &StatusMessage::closeItstyle, this, &CustomVehicle::_deleteStatusMessage);
        status->setObjectName(name);
        _statusMessages.append(status);
        status->setContext(message);
    }
}

void CustomVehicle::_handledistanceToHomeChanged(QVariant distance)
{
    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();
    qint64 time_diff = currentTime - _distanceLastTime; // ms
    float distance_diff = distance.toFloat() - _lastDistance;
    if(time_diff < 1000 && fabs(distance_diff) < 25) {
        if(fabs(distance_diff) > 0.3) {
            _distanceDiff += distance_diff;
        }
    }

    _lastDistance = distance.toFloat();
    _distanceLastTime = currentTime;

    emit vehicleDiffChanged();
}

void CustomVehicle::_deleteStatusMessage()
{
    int index = _statusMessages.indexOf(sender());
    _statusMessages.removeAt(index)->deleteLater();
}

StatusMessage::StatusMessage(QObject* parent)
    : QObject(parent)
    , _opacity(1)
{
    QPropertyAnimation *opacityAnimation = new QPropertyAnimation(this, "opacity", this);
    opacityAnimation->setDuration(100);
    opacityAnimation->setStartValue(0);
    opacityAnimation->setEndValue(1);
    opacityAnimation->start();

    _timer.setSingleShot(true);
    connect(&_timer, &QTimer::timeout, this, &StatusMessage::startCloseItstyle);
}

void StatusMessage::startCloseItstyle()
{
    if(_animation) {
        _animation->stop();
        _animation->deleteLater();
        _animation = nullptr;
    }
    _animation = new QPropertyAnimation(this, "opacity", this);
    _animation->setDuration(2000);
    _animation->setStartValue(1);
    _animation->setEndValue(0);
    connect(_animation, &QPropertyAnimation::finished, this, &StatusMessage::closeItstyle);
    _animation->start();
}

QString StatusMessage::icon() const
{
    return QString("qrc:/custom/img/png/info.png");
}

QString StatusMessage::color() const
{
    return QString("#00DA90");
}

void StatusMessage::setContext(const QString &context)
{
    if(_timer.isActive()) _timer.stop();
    if(_animation) {
        _animation->stop();
        _animation->deleteLater();
        _animation = nullptr;
        setOpacity(1.0);
    }
    _context = context;
    _timer.start(1000);
    emit contextChanged(_context);
}

void StatusMessage::setOpacity(const float &opacity)
{
    _opacity = opacity;
    emit opacityChanged(_opacity);
}
