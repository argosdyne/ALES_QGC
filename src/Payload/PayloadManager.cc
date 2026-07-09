#include "PayloadManager.h"

#include <QQmlEngine>
#include <QTimer>
#include <QUrl>

#include "QGCApplication.h"
#include "QGCToolbox.h"
#include "JoystickManager.h"
#include "Joystick.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"
#include "SettingsManager.h"
#include "VideoSettings.h"
#include "VideoManager.h"
#include "Fact.h"

PayloadManager::PayloadManager(QObject* parent)
    : QObject(parent)
{
    _gremsy     = new GremsyLynxPayloadController(this);
    _nextvision = new NextVisionPayloadController(this);

    // When a payload connects, auto-fill QGC's video RTSP URL (General settings) to match it.
    connect(_gremsy, &PayloadController::connectedChanged, this, [this]() {
        if (_gremsy->connected()) {
            _applyRtspToVideoSettings(_gremsy->rtspUrl());
        }
    });
    connect(_nextvision, &PayloadController::connectedChanged, this, [this]() {
        if (_nextvision->connected()) {
            _applyRtspToVideoSettings(_nextvision->rtspUrl());
        }
    });

    // Route the USB joystick's analog gimbal axis to the active + connected payload, in C++
    // so it keeps working on any screen (not tied to the payload settings page being open).
    JoystickManager* jm = qgcApp()->toolbox()->joystickManager();
    if (jm) {
        connect(jm, &JoystickManager::activeJoystickChanged, this, &PayloadManager::_onActiveJoystickChanged);
        _bindJoystick(jm->activeJoystick());
    }

    // Also drive the payload from the vehicle's RC radio channels (aviator radio: CH9/CH10),
    // so a payload connected here is controllable whether the operator uses a USB joystick or the radio.
    MultiVehicleManager* mvm = qgcApp()->toolbox()->multiVehicleManager();
    if (mvm) {
        connect(mvm, &MultiVehicleManager::activeVehicleChanged, this, &PayloadManager::_onActiveVehicleChanged);
        _bindVehicle(mvm->activeVehicle());
    }

    VideoSettings* videoSettings = qgcApp()->toolbox()->settingsManager()->videoSettings();
    if (videoSettings && videoSettings->rtspUrl()) {
        connect(videoSettings->rtspUrl(), &Fact::rawValueChanged, this, [this]() {
            _tryConnectPayloadFromVideoRtsp();
        });
    }
    QTimer::singleShot(0, this, &PayloadManager::_tryConnectPayloadFromVideoRtsp);
}

PayloadManager* PayloadManager::instance()
{
    static PayloadManager* s_instance = nullptr;
    if (!s_instance) {
        s_instance = new PayloadManager();
    }
    return s_instance;
}

QObject* PayloadManager::qmlSingletonFactory(QQmlEngine* /*engine*/, QJSEngine* /*scriptEngine*/)
{
    PayloadManager* manager = instance();
    QQmlEngine::setObjectOwnership(manager, QQmlEngine::CppOwnership);
    return manager;
}

PayloadController* PayloadManager::active()
{
    return _activeType == 1 ? static_cast<PayloadController*>(_nextvision)
                            : static_cast<PayloadController*>(_gremsy);
}

void PayloadManager::setActiveType(int type)
{
    type = (type == 1) ? 1 : 0;
    if (_activeType == type) {
        return;
    }
    _activeType = type;
    // Only one payload should stream at a time.
    if (type == 0) {
        _nextvision->disconnectPayload();
    } else {
        _gremsy->disconnectPayload();
    }
    emit activeTypeChanged();
}

void PayloadManager::_onActiveJoystickChanged(Joystick* joystick)
{
    _bindJoystick(joystick);
}

void PayloadManager::_bindJoystick(Joystick* joystick)
{
    if (_joystick == joystick) {
        return;
    }
    if (_joystick) {
        disconnect(_joystick, &Joystick::gimbalAxisControl, this, &PayloadManager::_onGimbalAxis);
    }
    _joystick = joystick;
    if (_joystick) {
        connect(_joystick, &Joystick::gimbalAxisControl, this, &PayloadManager::_onGimbalAxis);
    }
}

void PayloadManager::_onGimbalAxis(float pitch, float yaw)
{
    PayloadController* payload = active();
    if (payload && payload->connected()) {
        // Joystick reports (pitch, yaw); payload gimbalAxis takes (pan = yaw, tilt = pitch).
        payload->gimbalAxis(yaw, pitch);
    }
}

void PayloadManager::_onActiveVehicleChanged(Vehicle* vehicle)
{
    _bindVehicle(vehicle);
}

void PayloadManager::_bindVehicle(Vehicle* vehicle)
{
    if (_vehicle == vehicle) {
        return;
    }
    if (_vehicle) {
        disconnect(_vehicle, &Vehicle::rcChannelsChanged, this, &PayloadManager::_onRcChannels);
    }
    _vehicle = vehicle;
    if (_vehicle) {
        connect(_vehicle, &Vehicle::rcChannelsChanged, this, &PayloadManager::_onRcChannels);
    }
}

void PayloadManager::_onRcChannels(int channelCount, int pwmValues[18])
{
    PayloadController* payload = active();
    if (!payload || !payload->connected()) {
        _rcWasActive = false;
        return;
    }
    if (channelCount < _rcPanChannel || channelCount < _rcTiltChannel) {
        return; // radio doesn't provide those channels
    }

    // PWM [1000..2000] center 1500 -> axis [-1..+1] with a small deadzone; reverse on the radio if inverted.
    auto toAxis = [](int pwm) -> double {
        if (pwm < 900 || pwm > 2100) {
            return 0.0; // unavailable / invalid channel value
        }
        const double axis = qBound(-1.0, (pwm - 1500.0) / 500.0, 1.0);
        return (qAbs(axis) < 0.05) ? 0.0 : axis; // deadzone around center
    };

    const double pan  = toAxis(pwmValues[_rcPanChannel  - 1]); // CH9  -> pan / yaw
    const double tilt = toAxis(pwmValues[_rcTiltChannel - 1]); // CH10 -> tilt / pitch

    // Only drive while a stick is off-center; send one final (0,0) on release to stop, then stay
    // quiet so the on-screen d-pad still works when the radio sticks are centered.
    const bool activeNow = (pan != 0.0 || tilt != 0.0);
    if (activeNow || _rcWasActive) {
        payload->gimbalAxis(pan, tilt);
    }
    _rcWasActive = activeNow;
}

int PayloadManager::_payloadTypeFromRtspUrl(const QString& urlString) const
{
    const QUrl url(urlString);
    const QString host = url.host();
    const QString path = url.path().toLower();

    if (host.isEmpty() || url.scheme().toLower() != QStringLiteral("rtsp")) {
        return -1;
    }

    if (host == QStringLiteral("192.168.2.28") ||
            path.contains(QStringLiteral("video0"))) {
        return 1; // NextVision DragonEye2
    }

    if (host == QStringLiteral("192.168.2.240") ||
            path.contains(QStringLiteral("payload"))) {
        return 0; // Gremsy Lynx
    }

    return -1;
}

void PayloadManager::_tryConnectPayloadFromVideoRtsp()
{
    VideoSettings* videoSettings = qgcApp()->toolbox()->settingsManager()->videoSettings();
    if (!videoSettings || !videoSettings->rtspUrl()) {
        return;
    }

    const QString rtspUrl = videoSettings->rtspUrl()->rawValue().toString().trimmed();
    const int payloadType = _payloadTypeFromRtspUrl(rtspUrl);
    if (payloadType < 0) {
        return;
    }

    QUrl url(rtspUrl);
    const QString host = url.host();
    if (host.isEmpty()) {
        return;
    }

    setActiveType(payloadType);
    PayloadController* payload = active();
    if (!payload || payload->connected() || payload->connecting()) {
        return;
    }

    payload->setIp(host);
    payload->connectPayload();
}

void PayloadManager::_applyRtspToVideoSettings(const QString& url)
{
    if (url.isEmpty()) {
        return;
    }
    VideoSettings* videoSettings = qgcApp()->toolbox()->settingsManager()->videoSettings();
    if (!videoSettings) {
        return;
    }
    videoSettings->videoSource()->setRawValue(videoSettings->rtspVideoSource());
    videoSettings->rtspUrl()->setRawValue(url);
    videoSettings->streamEnabled()->setRawValue(true);
    qgcApp()->toolbox()->videoManager()->startVideo();
}
