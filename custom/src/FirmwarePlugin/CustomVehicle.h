#pragma once

#include "Vehicle.h"
#include "VehicleESCFactGroup.h"
#include <QTimer>

class CustomPlugin;
class StatusMessage : public QObject
{
    Q_OBJECT
public:
    Q_PROPERTY(float opacity READ opacity WRITE setOpacity NOTIFY opacityChanged)
    Q_PROPERTY(QString context READ context NOTIFY contextChanged)
    Q_PROPERTY(QString icon READ icon CONSTANT)
    Q_PROPERTY(QString color READ color CONSTANT)
    StatusMessage(QObject* parent = nullptr);

    QString context(void) const { return _context; }
    QString icon(void) const;
    QString color(void) const;
    float opacity(void) const { return _opacity; }

    void setOpacity(const float& opacity);
    void setContext(const QString& context);

public slots:
    void startCloseItstyle();

signals:
    void closeItstyle();
    void opacityChanged(const float& opacity);
    void contextChanged(const QString& context);

private:
    QTimer _timer;
    QString _context;
    float _opacity;

    QPropertyAnimation *_animation{nullptr};
};
class CustomVehicle : public Vehicle
{
    Q_OBJECT
public:
    Q_PROPERTY(bool     supportMission   READ supportMission  NOTIFY supportMissionChanged)

    Q_PROPERTY(float    heightDiff       READ heightDiff      NOTIFY vehicleDiffChanged)
    Q_PROPERTY(float    distanceDiff     READ distanceDiff    NOTIFY vehicleDiffChanged)
    Q_PROPERTY(Fact*    gpsPrime         READ gpsPrimeFact    NOTIFY vehicleFactChanged)
    Q_PROPERTY(Fact*    rtlBakHomeLatFact READ rtlBakHomeLatFact NOTIFY vehicleFactChanged)
    Q_PROPERTY(Fact*    rtlBakHomeLonFact READ rtlBakHomeLonFact NOTIFY vehicleFactChanged)
    Q_PROPERTY(Fact*    sysLidarOdomFact  READ sysLidarOdomFact  NOTIFY vehicleFactChanged)

    Q_PROPERTY(QmlObjectListModel* statusMessages READ statusMessages CONSTANT)
    Q_PROPERTY(FactGroup* esc READ escFactGroup CONSTANT)
    Q_PROPERTY(QString mainLinkName READ mainLinkName NOTIFY mainLinkChanged)
    Q_PROPERTY(bool rcOnUDP MEMBER _rcOnUDP NOTIFY rcOnUDPChanged)
    Q_PROPERTY(bool isSecondGPS MEMBER _isSecondGPS NOTIFY isSecondGPSChanged)
    Q_PROPERTY(bool rcInControl MEMBER _rcInControl NOTIFY rcInControlChanged)
    Q_PROPERTY(bool onLTE READ onLTE NOTIFY onLTEChanged)
    Q_PROPERTY(QGeoCoordinate forcedPosition READ forcedPosition NOTIFY forcedPositionChanged)
    Q_PROPERTY(QString linkdelay MEMBER _linkdelay NOTIFY linkdelayChanged)

    CustomVehicle(LinkInterface*          link,
                  int                     vehicleId,
                  int                     defaultComponentId,
                  MAV_AUTOPILOT           firmwareType,
                  MAV_TYPE                vehicleType,
                  FirmwarePluginManager*  firmwarePluginManager,
                  JoystickManager*        joystickManager);

    bool supportMission() { return ((capabilityBits() & MAV_PROTOCOL_CAPABILITY_MISSION_INT) || (capabilityBits() & MAV_PROTOCOL_CAPABILITY_MISSION_FLOAT)); }
    float heightDiff() { return _heightDiff; }
    float distanceDiff() { return _distanceDiff; }
    bool onLTE() { return _channel_id > 1; }
    Fact* gpsPrimeFact();
    Fact* rtlBakHomeLatFact();
    Fact* rtlBakHomeLonFact();
    Fact* sysLidarOdomFact();
    QGeoCoordinate forcedPosition();

    Q_INVOKABLE void applyCurrentPositionRTLbakHome();
    Q_INVOKABLE void removeRTLbakHome();

    QmlObjectListModel* statusMessages(void) { return &_statusMessages; }
    FactGroup* escFactGroup() { return &_escFactGroup; }
    QString mainLinkName();

public slots:
    void showStatusMessage(const QString& message, const QString& name);

private slots:
    void _mavlinkMessageReceived(const mavlink_message_t& message);
    void _handletextMessageReceivedCustom(UASMessage* message);
    void _handledistanceToHomeChanged(QVariant distance);
    void _initRcChannelsTimer(bool lost);
    void _rcChannelsTimeOut();
    void _rcChannelsComing();
    void _sendRcChannelValues(const quint16* channels, int count);
    void _deleteStatusMessage();

signals:
    void supportMissionChanged();
    void rcInControlChanged();
    void vehicleFactChanged();
    void vehicleDiffChanged();
    void mainLinkChanged();
    void rcOnUDPChanged();
    void isSecondGPSChanged();
    void forcedPositionChanged();
    void onLTEChanged();
    void linkdelayChanged();

private:
    void _handleOdometry(const mavlink_message_t &message);
    void _handleGpsRawInt2(const mavlink_message_t& message);
    void _handleLandingTarget(const mavlink_message_t &message);
    void _handleManualControl(const mavlink_message_t& message);
    void _handleBrigePing(const mavlink_message_t& message);

    void _refreshStatusMessageUI(bool from);
    QParallelAnimationGroup _group;
    QmlObjectListModel _statusMessages;
    VehicleESCFactGroup _escFactGroup;
    bool _isSecondGPS{false};
    bool _rcInControl{true};

    float _heightDiff{0.0};
    float _distanceDiff{0.0};

    float _lastVx{0.0};
    float _lastVy{0.0};
    float _lastVz{0.0};
    quint64 _lastTime{0};

    float _lastDistance{0.0};
    qint64 _distanceLastTime{0};

    CustomPlugin* _plugin{nullptr};
    QTimer _rcChannelsTimer;
    bool _rcOnUDP{false};
    bool _blockedRcLatched{false};
    int _blockedRcCount{0};
    quint16 _blockedRcChannels[18]{};
    int _channel_id{0};
    QString _linkdelay;

    static const char* _escFactGroupName;
};
