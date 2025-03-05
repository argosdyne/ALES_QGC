#pragma once
#include <QSerialPort>
#include <QObject>
#include <QLoggingCategory>
#include <mavlink.h>
#include <QVariant>
#include "FactGroup.h"

Q_DECLARE_LOGGING_CATEGORY(AVIATORInterfaceLog)
#define MAVLINK_AVIATOR_COMM_ID (MAVLINK_COMM_NUM_BUFFERS - 2)
class AVIATORInterface : public FactGroup
{
    Q_OBJECT
public:
    typedef enum {
        ButtonType_F1,
        ButtonType_F2,
        ButtonType_F3
    } ButtonType;

    Q_PROPERTY(QVariantList rcChannelValues MEMBER _rcChannelValues NOTIFY rcChannelValuesChanged)

    Q_PROPERTY(Fact* batteryVoltage   READ batteryVoltage   CONSTANT)
    Q_PROPERTY(Fact* batteryRemaining READ batteryRemaining CONSTANT)
    Q_PROPERTY(Fact* version          READ version          CONSTANT)
    Q_PROPERTY(Fact* temperature      READ temperature      CONSTANT)
    Q_PROPERTY(Fact* usbOut           READ usbOut           CONSTANT)
    Q_PROPERTY(Fact* batteryCurrent   READ batteryCurrent   CONSTANT)
    Q_PROPERTY(Fact* batteryCharging  READ batteryCharging  CONSTANT)

    AVIATORInterface(QObject* parent = nullptr);
    ~AVIATORInterface() override;

    Fact* batteryVoltage() { return &_batteryVoltageFact; }
    Fact* batteryRemaining() { return &_batteryRemainingFact; }
    Fact* version() { return &_versionFact; }
    Fact* temperature() { return &_temperatureFact; }
    Fact* usbOut() { return &_usbOutFact; }
    Fact* batteryCurrent() { return &_batteryCurrentFact; }
    Fact* batteryCharging() { return &_batteryChargingFact; }

signals:
    void write(const QByteArray data);
    void bytesReceived(const mavlink_message_t& message);
    void rcChannelValuesChanged(const quint16* channels, int count);
    void buttonPressed(int type, bool pressed);

private slots:
    void _writeBytes(const QByteArray data);
    void _readBytes(void);
    void _handlebytesReceived(const mavlink_message_t& message);

public slots:

private:
    void _init();
    void _handle_mavlink_rc_channels(const mavlink_message_t& message);
    void _handle_mavlink_param_value(const mavlink_message_t& message);

    Fact _batteryVoltageFact;
    Fact _batteryRemainingFact;
    Fact _versionFact;
    Fact _temperatureFact;
    Fact _usbOutFact;
    Fact _batteryCurrentFact;
    Fact _batteryChargingFact;

    static const char* _batteryVoltageFactName;
    static const char* _batteryRemainingFactName;
    static const char* _versionFactName;
    static const char* _temperatureFactName;
    static const char* _usbOutFactName;
    static const char* _batteryCurrentFactName;
    static const char* _batteryChargingFactName;

    QSerialPort* _port{nullptr};
    QString _portName;
    int _baudRate;

    QVariantList _rcChannelValues;
    quint16 _rawChannels[18];

    bool _f1Pressed{false};
    bool _f2Pressed{false};
    bool _f3Pressed{false};

    bool _cn1Pressed{false};
    bool _cn2Pressed{false};
    bool _cn3Pressed{false};
    bool _cn4Pressed{false};
    bool _cn5Pressed{false};
    bool _cn6Pressed{false};
    bool _cn7Pressed{false};
    bool _cn8Pressed{false};
    bool _cn9Pressed{false};
    bool _cn10Pressed{false};
    bool _cn11Pressed{false};
    bool _cn12Pressed{false};
    bool _cn13Pressed{false};
    bool _cn17Pressed{false};
    bool _cn18Pressed{false};

    QVector<uint16_t> _prevChannelValues = QVector<uint16_t>(18, 0);
};
