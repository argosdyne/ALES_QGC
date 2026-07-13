/// @file PayloadManager.h
/// @brief App-lifetime owner of the payload controllers (QML singleton).
///
/// The controllers live here, NOT inside a QML page, so a connected payload keeps
/// streaming (and the USB joystick keeps controlling it) no matter which screen is
/// showing. The joystick -> payload wiring is done in C++ for the same reason.

#pragma once

#include <QObject>

#include "GremsyLynxPayloadController.h"
#include "NextVisionPayloadController.h"

class QQmlEngine;
class QJSEngine;
class Joystick;
class Vehicle;

class PayloadManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(GremsyLynxPayloadController* gremsy     READ gremsy     CONSTANT)
    Q_PROPERTY(NextVisionPayloadController* nextvision READ nextvision CONSTANT)
    Q_PROPERTY(PayloadController*           active     READ active     NOTIFY activeTypeChanged)
    // 0 = Gremsy Lynx, 1 = NextVision DragonEye2
    Q_PROPERTY(int activeType READ activeType WRITE setActiveType NOTIFY activeTypeChanged)

public:
    explicit PayloadManager(QObject* parent = nullptr);

    static PayloadManager* instance();
    static QObject*        qmlSingletonFactory(QQmlEngine* engine, QJSEngine* scriptEngine);

    GremsyLynxPayloadController* gremsy()     { return _gremsy; }
    NextVisionPayloadController* nextvision() { return _nextvision; }
    PayloadController*           active();

    int  activeType() const { return _activeType; }
    void setActiveType(int type);

signals:
    void activeTypeChanged();

private slots:
    void _onActiveJoystickChanged(Joystick* joystick);
    void _onGimbalAxis(float pitch, float yaw);
    void _onActiveVehicleChanged(Vehicle* vehicle);
    void _onRcChannels(int channelCount, int pwmValues[18]);
    void _tryConnectPayloadFromVideoRtsp();

private:
    void _bindJoystick(Joystick* joystick);
    void _bindVehicle(Vehicle* vehicle);
    // On connect, point QGC's video (General settings) at the payload's RTSP stream.
    void _applyRtspToVideoSettings(const QString& url);
    int  _payloadTypeFromRtspUrl(const QString& url) const;

    GremsyLynxPayloadController* _gremsy     = nullptr;
    NextVisionPayloadController* _nextvision = nullptr;
    int       _activeType = 0;
    Joystick* _joystick   = nullptr;
    Vehicle*  _vehicle    = nullptr;

    // RC (radio) gimbal control: which 1-based RC channels drive pan/tilt (aviator radio).
    int  _rcPanChannel  = 10;  // pan / yaw
    int  _rcTiltChannel = 9;   // tilt / pitch
    bool _rcWasActive   = false; // was a stick off-center last frame (for one-shot stop on release)
};
