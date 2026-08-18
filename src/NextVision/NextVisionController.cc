#include "NextVisionController.h"

#include <cstdint>
#include <cstring>
#include <limits>

#include <QtMath>

#include "GimbalController.h"
#include "MAVLinkProtocol.h"
#include "QGCApplication.h"
#include "QGCToolbox.h"
#include "SettingsManager.h"
#include "VideoManager.h"
#include "VideoSettings.h"
#include "Vehicle.h"

#include <QUdpSocket>

const char* NextVisionController::_dragonEyeIp = "192.168.2.28";
const char* NextVisionController::_dragonEyeRtspUrl = "rtsp://192.168.2.28:8554/live0";
const char* NextVisionController::_dragonEyeRcIp = "192.168.2.28";

NextVisionController::NextVisionController(Vehicle* vehicle, QObject* parent)
    : QObject(parent)
    , _vehicle(vehicle)
    , _rcAddress(QString::fromLatin1(_dragonEyeRcIp))
{
    if (_vehicle) {
        _targetSystem = _vehicle->id();
        connect(_vehicle, &Vehicle::mavlinkMessageReceived,
                this, &NextVisionController::_mavlinkMessageReceived);
    }

    _timeoutTimer.setInterval(3000);
    _timeoutTimer.setSingleShot(true);
    connect(&_timeoutTimer, &QTimer::timeout, this, &NextVisionController::_connectionTimeout);
}

QString NextVisionController::ipAddress() const
{
    return QString::fromLatin1(_dragonEyeIp);
}

QString NextVisionController::rtspUrl() const
{
    return QString::fromLatin1(_dragonEyeRtspUrl);
}

void NextVisionController::configureVideoStream()
{
    VideoSettings* videoSettings = qgcApp()->toolbox()->settingsManager()->videoSettings();
    videoSettings->videoSource()->setRawValue(VideoSettings::videoSourceRTSP);
    videoSettings->setRtspUrlUserSet(true);
    videoSettings->rtspUrl()->setRawValue(rtspUrl());
    videoSettings->streamEnabled()->setRawValue(true);
    qgcApp()->toolbox()->videoManager()->startVideo(0);
}

void NextVisionController::setRcIpAddress(const QString& ipAddress)
{
    const QHostAddress address(ipAddress);
    if (address.isNull()) {
        emit commandFailed(QStringLiteral("rcIpAddress"),
                           QStringLiteral("Invalid IP address: %1").arg(ipAddress));
        return;
    }

    if (_rcAddress == address) {
        return;
    }

    _rcAddress = address;
    emit rcSettingsChanged();
}

void NextVisionController::setRcTarget(int systemId, int componentId)
{
    const int boundedSystemId = qBound(1, systemId, 255);
    const int boundedComponentId = qBound(0, componentId, 255);
    if (_rcTargetSystem == boundedSystemId && _rcTargetComponent == boundedComponentId) {
        return;
    }

    _rcTargetSystem = boundedSystemId;
    _rcTargetComponent = boundedComponentId;
    emit rcSettingsChanged();
}

void NextVisionController::setRcChannels(int pitchChannel, int yawChannel, int zoomChannel, int sensorChannel)
{
    const int boundedPitchChannel = qBound(1, pitchChannel, 18);
    const int boundedYawChannel = qBound(1, yawChannel, 18);
    const int boundedZoomChannel = qBound(1, zoomChannel, 18);
    const int boundedSensorChannel = qBound(1, sensorChannel, 18);
    if (_pitchChannel == boundedPitchChannel &&
            _yawChannel == boundedYawChannel &&
            _zoomChannel == boundedZoomChannel &&
            _sensorChannel == boundedSensorChannel) {
        return;
    }

    _pitchChannel = boundedPitchChannel;
    _yawChannel = boundedYawChannel;
    _zoomChannel = boundedZoomChannel;
    _sensorChannel = boundedSensorChannel;
    emit rcSettingsChanged();
}

void NextVisionController::sendRcOverride(float pitch, float yaw, float zoom, float sensor)
{
    uint16_t channels[18];
    for (uint16_t& channel : channels) {
        channel = std::numeric_limits<uint16_t>::max();
    }

    _setRcChannel(channels, _pitchChannel, _axisToPwm(pitch));
    _setRcChannel(channels, _yawChannel, _axisToPwm(yaw));
    _setRcChannel(channels, _zoomChannel, _axisToPwm(zoom));
    _setRcChannel(channels, _sensorChannel, _axisToPwm(sensor));
    _sendRcOverrideChannels(channels);
}

void NextVisionController::stopRcOverride()
{
    sendRcOverride(0.0f, 0.0f, 0.0f, 0.0f);
}

void NextVisionController::setAngle(float pitchDeg, float yawDeg)
{
    if (!_vehicle) {
        emit commandFailed(QStringLiteral("setAngle"), QStringLiteral("Vehicle is not available"));
        return;
    }

    _sendGimbalAngleCommand(pitchDeg, yawDeg);
}

void NextVisionController::setRate(float pitchRate, float yawRate)
{
    if (!_vehicle) {
        emit commandFailed(QStringLiteral("setRate"), QStringLiteral("Vehicle is not available"));
        return;
    }

    const float boundedPitchRate = qBound(-1.0f, pitchRate, 1.0f);
    const float boundedYawRate = qBound(-1.0f, yawRate, 1.0f);

    sendRcOverride(boundedPitchRate, boundedYawRate, 0.0f, 0.0f);
}

void NextVisionController::centerGimbal()
{
    if (!_vehicle) {
        emit commandFailed(QStringLiteral("centerGimbal"), QStringLiteral("Vehicle is not available"));
        return;
    }

    stopRcOverride();
}

void NextVisionController::zoomIn()
{
    sendRcOverride(0.0f, 0.0f, 0.45f, 0.0f);
}

void NextVisionController::zoomOut()
{
    sendRcOverride(0.0f, 0.0f, -0.45f, 0.0f);
}

void NextVisionController::stopZoom()
{
    stopRcOverride();
}

void NextVisionController::setZoom(double level)
{
    const float percentage = qBound(0.0f, static_cast<float>(level), 100.0f);
    _sendCameraCommand(MAV_CMD_SET_CAMERA_ZOOM, ZOOM_TYPE_RANGE, percentage);
}

void NextVisionController::selectEo()
{
    _sensorMode = QStringLiteral("EO");
    emit sensorModeChanged();
    sendRcOverride(0.0f, 0.0f, 0.0f, -0.6f);
}

void NextVisionController::selectIr()
{
    _sensorMode = QStringLiteral("IR");
    emit sensorModeChanged();
    sendRcOverride(0.0f, 0.0f, 0.0f, 0.6f);
}

void NextVisionController::takePhoto()
{
    _sendCameraCommand(MAV_CMD_IMAGE_START_CAPTURE,
                       0.0f,
                       0.0f,
                       1.0f,
                       0.0f);
}

void NextVisionController::startRecording()
{
    _sendCameraCommand(MAV_CMD_VIDEO_START_CAPTURE, 0.0f, 0.0f);
}

void NextVisionController::stopRecording()
{
    _sendCameraCommand(MAV_CMD_VIDEO_STOP_CAPTURE, 0.0f);
}

void NextVisionController::_mavlinkMessageReceived(const mavlink_message_t& message, LinkInterface* link)
{
    Q_UNUSED(link)

    _discoverComponent(message);

    if (message.msgid == MAVLINK_MSG_ID_COMMAND_ACK) {
        mavlink_command_ack_t ack;
        mavlink_msg_command_ack_decode(&message, &ack);
        if (ack.result != MAV_RESULT_ACCEPTED && ack.result != MAV_RESULT_IN_PROGRESS) {
            emit commandFailed(QString::number(ack.command),
                               QStringLiteral("MAV_RESULT=%1").arg(ack.result));
        }
    }
}

void NextVisionController::_connectionTimeout()
{
    _setConnected(false);
}

void NextVisionController::_setConnected(bool connected)
{
    if (_connected == connected) {
        return;
    }

    _connected = connected;
    emit connectedChanged();
}

void NextVisionController::_discoverComponent(const mavlink_message_t& message)
{
    if (!_vehicle || message.sysid != _vehicle->id()) {
        return;
    }

    bool targetComponentChanged = false;
    const bool cameraComponent =
        message.compid >= MAV_COMP_ID_CAMERA && message.compid <= MAV_COMP_ID_CAMERA6;
    const bool gimbalMessage =
        message.compid == MAV_COMP_ID_GIMBAL ||
        message.msgid == MAVLINK_MSG_ID_GIMBAL_MANAGER_INFORMATION ||
        message.msgid == MAVLINK_MSG_ID_GIMBAL_MANAGER_STATUS ||
        message.msgid == MAVLINK_MSG_ID_GIMBAL_DEVICE_ATTITUDE_STATUS;
    const bool cameraMessage =
        cameraComponent ||
        message.msgid == MAVLINK_MSG_ID_CAMERA_INFORMATION ||
        message.msgid == MAVLINK_MSG_ID_CAMERA_SETTINGS ||
        message.msgid == MAVLINK_MSG_ID_CAMERA_CAPTURE_STATUS ||
        message.msgid == MAVLINK_MSG_ID_VIDEO_STREAM_INFORMATION;

    if (cameraMessage && _cameraComponent != message.compid) {
        _cameraComponent = message.compid;
        targetComponentChanged = true;
    }
    if (cameraMessage) {
        _cameraComponentDiscovered = true;
    }

    if (gimbalMessage && _gimbalComponent != message.compid) {
        _gimbalComponent = message.compid;
        targetComponentChanged = true;
    }
    if (gimbalMessage) {
        _gimbalComponentDiscovered = true;
    }

    if (cameraMessage || gimbalMessage) {
        _targetSystem = message.sysid;
        _setConnected(true);
        _timeoutTimer.start();
    }

    if (targetComponentChanged) {
        emit targetChanged();
    }
}

void NextVisionController::_sendCameraCommand(MAV_CMD command,
                                              float param1,
                                              float param2,
                                              float param3,
                                              float param4,
                                              float param5,
                                              float param6,
                                              float param7)
{
    if (!_vehicle) {
        emit commandFailed(QString::number(command), QStringLiteral("Vehicle is not available"));
        return;
    }

    _vehicle->sendMavCommand(_bestCameraComponent(),
                             command,
                             false,
                             param1,
                             param2,
                             param3,
                             param4,
                             param5,
                             param6,
                             param7);
}

void NextVisionController::_sendGimbalAngleCommand(float pitchDeg, float yawDeg)
{
    if (!_vehicle) {
        return;
    }

    SharedLinkInterfacePtr sharedLink = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (!sharedLink) {
        emit commandFailed(QStringLiteral("gimbalAngle"), QStringLiteral("Primary link is not available"));
        return;
    }

    uint targetComponent = _gimbalComponentDiscovered ? static_cast<uint>(_gimbalComponent) : MAV_COMP_ID_GIMBAL;
    uint deviceId = 1;

    GimbalController* gimbalController = _vehicle->gimbalController();
    Gimbal* activeGimbal = gimbalController ? gimbalController->activeGimbal() : nullptr;
    if (activeGimbal) {
        const uint managerCompId = activeGimbal->managerCompid()->rawValue().toUInt();
        const uint activeDeviceId = activeGimbal->deviceId()->rawValue().toUInt();
        if (managerCompId != 0 && activeDeviceId != 0) {
            targetComponent = managerCompId;
            deviceId = activeDeviceId;
        }
    }

    const uint32_t flags = GIMBAL_MANAGER_FLAGS_ROLL_LOCK |
                           GIMBAL_MANAGER_FLAGS_PITCH_LOCK |
                           GIMBAL_MANAGER_FLAGS_YAW_IN_VEHICLE_FRAME;

    mavlink_message_t message;
    mavlink_command_long_t command;
    memset(&command, 0, sizeof(command));
    command.target_system = static_cast<uint8_t>(_targetSystem > 0 ? _targetSystem : _vehicle->id());
    command.target_component = static_cast<uint8_t>(targetComponent);
    command.command = MAV_CMD_DO_GIMBAL_MANAGER_PITCHYAW;
    command.confirmation = 0;
    command.param1 = pitchDeg;
    command.param2 = yawDeg;
    command.param3 = NAN;
    command.param4 = NAN;
    command.param5 = static_cast<float>(flags);
    command.param6 = 0.0f;
    command.param7 = static_cast<float>(deviceId);
    mavlink_msg_command_long_encode(qgcApp()->toolbox()->mavlinkProtocol()->getSystemId(),
                                    qgcApp()->toolbox()->mavlinkProtocol()->getComponentId(),
                                    &message,
                                    &command);

    _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), message);
}

void NextVisionController::_sendGimbalRateCommand(float pitchRateDegS, float yawRateDegS)
{
    if (!_vehicle) {
        return;
    }

    SharedLinkInterfacePtr sharedLink = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (!sharedLink) {
        emit commandFailed(QStringLiteral("gimbalRate"), QStringLiteral("Primary link is not available"));
        return;
    }

    uint targetComponent = _gimbalComponentDiscovered ? static_cast<uint>(_gimbalComponent) : MAV_COMP_ID_GIMBAL;
    uint deviceId = 1;
    float pitchParam = NAN;
    float yawParam = NAN;
    float pitchRateParam = pitchRateDegS;
    float yawRateParam = yawRateDegS;

    GimbalController* gimbalController = _vehicle->gimbalController();
    Gimbal* activeGimbal = gimbalController ? gimbalController->activeGimbal() : nullptr;
    if (activeGimbal) {
        const uint managerCompId = activeGimbal->managerCompid()->rawValue().toUInt();
        const uint activeDeviceId = activeGimbal->deviceId()->rawValue().toUInt();
        if (managerCompId != 0 && activeDeviceId != 0) {
            targetComponent = managerCompId;
            deviceId = activeDeviceId;

            // Several AP/gimbal combinations ignore rate params. Small repeated angle
            // targets match QGC's existing click-drag workaround.
            pitchParam = activeGimbal->absolutePitch()->rawValue().toFloat() + (pitchRateDegS * 0.1f);
            yawParam = activeGimbal->bodyYaw()->rawValue().toFloat() + (yawRateDegS * 0.1f);
            pitchRateParam = NAN;
            yawRateParam = NAN;
        }
    }

    const uint32_t flags = GIMBAL_MANAGER_FLAGS_ROLL_LOCK |
                           GIMBAL_MANAGER_FLAGS_PITCH_LOCK |
                           GIMBAL_MANAGER_FLAGS_YAW_IN_VEHICLE_FRAME;

    mavlink_message_t message;
    mavlink_command_long_t command;
    memset(&command, 0, sizeof(command));
    command.target_system = static_cast<uint8_t>(_targetSystem > 0 ? _targetSystem : _vehicle->id());
    command.target_component = static_cast<uint8_t>(targetComponent);
    command.command = MAV_CMD_DO_GIMBAL_MANAGER_PITCHYAW;
    command.confirmation = 0;
    command.param1 = pitchParam;
    command.param2 = yawParam;
    command.param3 = pitchRateParam;
    command.param4 = yawRateParam;
    command.param5 = static_cast<float>(flags);
    command.param6 = 0.0f;
    command.param7 = static_cast<float>(deviceId);
    mavlink_msg_command_long_encode(qgcApp()->toolbox()->mavlinkProtocol()->getSystemId(),
                                    qgcApp()->toolbox()->mavlinkProtocol()->getComponentId(),
                                    &message,
                                    &command);

    _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), message);
}

bool NextVisionController::_ensureRcSocket()
{
    if (_rcSocket) {
        return true;
    }

    _rcSocket = new QUdpSocket(this);
    const bool bound = _rcSocket->bind(QHostAddress::AnyIPv4,
                                       _dragonEyeRcPort,
                                       QAbstractSocket::ShareAddress | QAbstractSocket::ReuseAddressHint);
    if (!bound) {
        emit commandFailed(QStringLiteral("rcSocket"),
                           QStringLiteral("Could not bind UDP %1: %2")
                           .arg(_dragonEyeRcPort)
                           .arg(_rcSocket->errorString()));
    }

    return true;
}

void NextVisionController::_sendRcOverrideChannels(const uint16_t channels[18])
{
    if (!_ensureRcSocket()) {
        return;
    }

    mavlink_message_t message;
    mavlink_msg_rc_channels_override_pack(qgcApp()->toolbox()->mavlinkProtocol()->getSystemId(),
                                          qgcApp()->toolbox()->mavlinkProtocol()->getComponentId(),
                                          &message,
                                          static_cast<uint8_t>(_rcTargetSystem),
                                          static_cast<uint8_t>(_rcTargetComponent),
                                          channels[0],
                                          channels[1],
                                          channels[2],
                                          channels[3],
                                          channels[4],
                                          channels[5],
                                          channels[6],
                                          channels[7],
                                          channels[8],
                                          channels[9],
                                          channels[10],
                                          channels[11],
                                          channels[12],
                                          channels[13],
                                          channels[14],
                                          channels[15],
                                          channels[16],
                                          channels[17]);

    uint8_t buffer[MAVLINK_MAX_PACKET_LEN];
    const int length = mavlink_msg_to_send_buffer(buffer, &message);
    const qint64 bytesSent = _rcSocket->writeDatagram(reinterpret_cast<const char*>(buffer),
                                                      length,
                                                      _rcAddress,
                                                      _dragonEyeRcPort);
    if (bytesSent != length) {
        emit commandFailed(QStringLiteral("rcOverride"),
                           QStringLiteral("UDP send failed: %1").arg(_rcSocket->errorString()));
    }
}

uint16_t NextVisionController::_axisToPwm(float axis) const
{
    const float boundedAxis = qBound(-1.0f, axis, 1.0f);
    return static_cast<uint16_t>(qRound(1500.0f + (boundedAxis * 500.0f)));
}

void NextVisionController::_setRcChannel(uint16_t channels[18], int channel, uint16_t value) const
{
    if (channel < 1 || channel > 18) {
        return;
    }

    channels[channel - 1] = value;
}

int NextVisionController::_bestCameraComponent() const
{
    if (_cameraComponentDiscovered) {
        return _cameraComponent;
    }

    if (_gimbalComponentDiscovered) {
        return _gimbalComponent;
    }

    return MAV_COMP_ID_CAMERA;
}
