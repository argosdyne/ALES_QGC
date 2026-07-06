#include "PayloadManager.h"

#include <QQmlEngine>

#include "QGCApplication.h"
#include "QGCToolbox.h"
#include "JoystickManager.h"
#include "Joystick.h"
#include "SettingsManager.h"
#include "VideoSettings.h"
#include "VideoManager.h"

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
