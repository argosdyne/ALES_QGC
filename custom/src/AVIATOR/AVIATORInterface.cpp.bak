#include "AVIATORInterface.h"
#include "QGCLoggingCategory.h"
#include <QQmlEngine>
#include <QString>
#include "CustomQmlInterface.h"

QGC_LOGGING_CATEGORY(AVIATORInterfaceLog, "AVIATORInterfaceLog")

const char* AVIATORInterface::_batteryVoltageFactName = "RC_BAT_VOLTAGE";
const char* AVIATORInterface::_batteryRemainingFactName = "RC_BAT_REMAINING";
const char* AVIATORInterface::_versionFactName = "RC_VERSION";
const char* AVIATORInterface::_temperatureFactName = "RC_TEMPERATURE";
const char* AVIATORInterface::_usbOutFactName = "RC_USB_OUT";
const char* AVIATORInterface::_batteryCurrentFactName = "RC_BAT_CURRENT";
const char* AVIATORInterface::_batteryChargingFactName = "RC_BAT_CHARGING";

AVIATORInterface::AVIATORInterface(QObject* parent)
    : FactGroup(1000, ":/json/AVIATORFact.json", parent)
    , _batteryVoltageFact(0, _batteryVoltageFactName, FactMetaData::valueTypeFloat)
    , _batteryRemainingFact(0, _batteryRemainingFactName, FactMetaData::valueTypeFloat)
    , _versionFact(0, _versionFactName, FactMetaData::valueTypeFloat)
    , _temperatureFact(0, _temperatureFactName, FactMetaData::valueTypeFloat)
    , _usbOutFact(0, _usbOutFactName, FactMetaData::valueTypeFloat)
    , _batteryCurrentFact(0, _batteryCurrentFactName, FactMetaData::valueTypeFloat)
    , _batteryChargingFact(0, _batteryChargingFactName, FactMetaData::valueTypeFloat)
    , _portName("/dev/ttysWK0")
    , _baudRate(115200)
{
    qmlRegisterUncreatableType<AVIATORInterface>("CustomQmlInterface", 1, 0, "AVIATORInterface", "Reference only");

    _addFact(&_batteryVoltageFact, _batteryVoltageFactName);
    _addFact(&_batteryRemainingFact, _batteryRemainingFactName);
    _addFact(&_versionFact, _versionFactName);
    _addFact(&_temperatureFact, _temperatureFactName);
    _addFact(&_usbOutFact, _usbOutFactName);
    _addFact(&_batteryCurrentFact, _batteryCurrentFactName);
    _addFact(&_batteryChargingFact, _batteryChargingFactName);

#if defined (Q_OS_ANDROID)
    QObject::connect(this, &AVIATORInterface::bytesReceived, this, &AVIATORInterface::_handlebytesReceived);
    QObject::connect(this, &AVIATORInterface::write, this, &AVIATORInterface::_writeBytes);
    _init();
#endif
}

AVIATORInterface::~AVIATORInterface()
{
    if (_port) {
        // This prevents stale signals from calling the link after it has been deleted
        QObject::disconnect(_port, &QIODevice::readyRead, this, &AVIATORInterface::_readBytes);
        _port->close();
        _port->deleteLater();
        _port = nullptr;
    }
}

void AVIATORInterface::_writeBytes(const QByteArray data)
{
    if(_port && _port->isOpen()) {
        _port->write(data);
    } else {
        // Error occurred
        qWarning() << "Serial port not writeable" << _portName;
    }
}

void AVIATORInterface::_readBytes()
{
    if (_port && _port->isOpen()) {
        qint64 byteCount = _port->bytesAvailable();
        if (byteCount) {
            QByteArray buffer;
            buffer.resize(byteCount);
            _port->read(buffer.data(), buffer.size());
            for (int position = 0; position < buffer.size(); position++) {
                mavlink_message_t message;
                mavlink_status_t status;
                if (mavlink_parse_char(MAVLINK_AVIATOR_COMM_ID, static_cast<uint8_t>(buffer[position]), &message, &status)) {
                    emit bytesReceived(message);
                }
            }
        }
    } else {
        // Error occurred
        qWarning() << "Serial port not readable" << _portName;
    }
}

void AVIATORInterface::_init()
{
    if(_port) {
        qCDebug(AVIATORInterfaceLog) << QString::number((qulonglong)this, 16) << "closing port";
        _port->close();

        delete _port;
        _port = nullptr;
    }

    qCDebug(AVIATORInterfaceLog) << "init " << _portName;
    _port = new QSerialPort(_portName, this);
    // QObject::connect(_port, static_cast<void (QSerialPort::*)(QSerialPort::SerialPortError)>(&QSerialPort::error), this, &AVIATORInterface::linkError);
    QObject::connect(_port, &QIODevice::readyRead, this, &AVIATORInterface::_readBytes);
    _port->open(QIODevice::ReadWrite);
    if (!_port->isOpen() ) {
        qWarning() << "open failed" << _port->errorString() << _port->error() << _portName;
        _port->close();
        delete _port;
        _port = nullptr;
    } else {
        _port->setDataTerminalReady(true);
        _port->setBaudRate(_baudRate);
    }
}

void AVIATORInterface::_handlebytesReceived(const mavlink_message_t& message)
{
    switch(message.msgid) {
    case MAVLINK_MSG_ID_RC_CHANNELS:
        _handle_mavlink_rc_channels(message);
        break;
    case MAVLINK_MSG_ID_PARAM_VALUE:
        _handle_mavlink_param_value(message);
        break;
    default:
        break;
    }
}

void AVIATORInterface::_handle_mavlink_rc_channels(const mavlink_message_t& message)
{
    _rcChannelValues.clear();
    mavlink_rc_channels_t channels;
    mavlink_msg_rc_channels_decode(&message, &channels);

    // _rcChannelValues.append(channels.chan1_raw);
    // _rcChannelValues.append(channels.chan2_raw);
    // _rcChannelValues.append(channels.chan3_raw);
    // _rcChannelValues.append(channels.chan4_raw);
    // _rcChannelValues.append(channels.chan5_raw);
    // _rcChannelValues.append(channels.chan6_raw);
    // _rcChannelValues.append(channels.chan7_raw);
    // _rcChannelValues.append(channels.chan8_raw);
    // _rcChannelValues.append(channels.chan9_raw);
    // _rcChannelValues.append(channels.chan10_raw);
    // _rcChannelValues.append(channels.chan11_raw);
    // _rcChannelValues.append(channels.chan12_raw);
    // _rcChannelValues.append(channels.chan13_raw);
    // _rcChannelValues.append(channels.chan14_raw);
    // _rcChannelValues.append(channels.chan15_raw);
    // _rcChannelValues.append(channels.chan16_raw);
    // _rcChannelValues.append(channels.chan17_raw);
    // _rcChannelValues.append(channels.chan18_raw);


    QVector<uint16_t> newChannelValues = {
        channels.chan1_raw, channels.chan2_raw, channels.chan3_raw, channels.chan4_raw,
        channels.chan5_raw, channels.chan6_raw, channels.chan7_raw, channels.chan8_raw,
        channels.chan9_raw, channels.chan10_raw, channels.chan11_raw, channels.chan12_raw,
        channels.chan13_raw, channels.chan14_raw, channels.chan15_raw, channels.chan16_raw,
        channels.chan17_raw, channels.chan18_raw
    };

    for (int i = 0; i < newChannelValues.size(); ++i) {
        if (_prevChannelValues[i] != newChannelValues[i]) {
            qCDebug(AVIATORInterfaceLog) << "채널" << (i + 1) << "값 변경됨: 이전 값 =" << _prevChannelValues[i] << ", 새로운 값 =" << newChannelValues[i];
        }
    }
    // 채널 값을 최신 값으로 업데이트
    _prevChannelValues = newChannelValues;

    // 기존 로직 수행
    for (uint16_t value : newChannelValues) {
        _rcChannelValues.append(QVariant::fromValue(value));
    }

    channels.chancount = 18;
    memset(_rawChannels, 0xff, 18 * 2);
    memcpy(_rawChannels, &channels.chan1_raw, channels.chancount * 2);

    emit rcChannelValuesChanged(_rawChannels, channels.chancount);

#if defined (Q_OS_ANDROID)
    bool f1 = channels.chan15_raw == 2000;
    bool f2 = channels.chan14_raw == 2000;
    bool f3 = channels.chan16_raw == 2000;


    // F1 버튼 처리
    if(f1 != _f1Pressed) {
        _f1Pressed = f1;
        qCDebug(AVIATORInterfaceLog) << "F1 버튼 상태 변경: " << (_f1Pressed ? "눌림" : "해제됨");
        emit buttonPressed(CustomQmlInterface::CUSTOM_FUNCTION_GIMBAL_RESET, _f1Pressed);
        qCDebug(AVIATORInterfaceLog) << "GIMBAL RESET 명령 전송: " << _f1Pressed;
    }

    // F2 버튼 처리
    if(f2 != _f2Pressed) {
        _f2Pressed = f2;
        qCDebug(AVIATORInterfaceLog) << "F2 버튼 상태 변경: " << (_f2Pressed ? "눌림" : "해제됨");
        emit buttonPressed(CustomQmlInterface::CUSTOM_FUNCTION_COACH_WAYPOINT, _f2Pressed); //ButtonType_F2
        qCDebug(AVIATORInterfaceLog) << "COACH WAYPOINT 명령 전송: " << _f2Pressed;
        emit buttonPressed(CustomQmlInterface::CUSTOM_FUNCTION_THERMAL_ZOOM, _f2Pressed);
        qCDebug(AVIATORInterfaceLog) << "THERMAL ZOOM 명령 전송: " << _f2Pressed;
    }

    // F3 버튼 처리
    static int f3Count = 0;
    if(f3) {
        f3Count++;
    } else {
        if(f3Count > 0 && f3Count < 50) { // 1s
            emit buttonPressed(CustomQmlInterface::CUSTOM_FUNCTION_IR_SWITCH, true);
            qCDebug(AVIATORInterfaceLog) << "IR SWITCH 명령 전송 (1초 이내): true";
        }
        f3Count = 0;
    }

    bool f3Pressed = (f3Count > 250); // 5s
    if(f3Pressed != _f3Pressed) {
        _f3Pressed = f3Pressed;
        qCDebug(AVIATORInterfaceLog) << "F3 버튼 상태 변경: " << (_f3Pressed ? "길게 눌림 (5초 이상)" : "해제됨");
        emit buttonPressed(CustomQmlInterface::CUSTOM_FUNCTION_START_MISSION, _f3Pressed);
        qCDebug(AVIATORInterfaceLog) << "START MISSION 명령 전송: " << _f3Pressed;
    }

    //해당 조건에 있을 경우 true를 반환함. 따라서 cn에 맞는 값들을 넣어줘야함
    bool cn1 = channels.chan1_raw ;//== 2000;
    bool cn2 = channels.chan2_raw ;//== 2000;
    bool cn3 = channels.chan3_raw ;//== 2000;
    bool cn4 = channels.chan4_raw ;//== 2000;
    bool cn5 = channels.chan5_raw ;//== 2000;
    bool cn6 = channels.chan6_raw ;//== 2000;
    bool cn7 = channels.chan7_raw ;//== 2000;
    bool cn8 = channels.chan8_raw ;//== 2000;
    bool cn9 = channels.chan9_raw ;//== 2000;
    bool cn10 = channels.chan10_raw ;//== 2000;
    bool cn11 = channels.chan11_raw ;//== 2000;
    bool cn12 = channels.chan12_raw ;//== 2000;
    bool cn13 = channels.chan13_raw ;//== 2000;
    bool cn17 = channels.chan17_raw ;//== 2000;
    bool cn18 = channels.chan18_raw ;//== 2000;

    if(cn1 != _cn1Pressed){
        _cn1Pressed = cn1;
        qCDebug(AVIATORInterfaceLog) << "cn1 버튼 상태 변경: " << (_cn1Pressed ? "눌림" : "해제됨");
    }

    if (cn2 != _cn2Pressed) {
        _cn2Pressed = cn2;
        qCDebug(AVIATORInterfaceLog) << "cn2 버튼 상태 변경: " << (_cn2Pressed ? "눌림" : "해제됨");
    }

    if (cn3 != _cn3Pressed) {
        _cn3Pressed = cn3;
        qCDebug(AVIATORInterfaceLog) << "cn3 버튼 상태 변경: " << (_cn3Pressed ? "눌림" : "해제됨");
    }

    if (cn4 != _cn4Pressed) {
        _cn4Pressed = cn4;
        qCDebug(AVIATORInterfaceLog) << "cn4 버튼 상태 변경: " << (_cn4Pressed ? "눌림" : "해제됨");
    }

    if (cn5 != _cn5Pressed) {
        _cn5Pressed = cn5;
        qCDebug(AVIATORInterfaceLog) << "cn5 버튼 상태 변경: " << (_cn5Pressed ? "눌림" : "해제됨");
    }

    if (cn6 != _cn6Pressed) {
        _cn6Pressed = cn6;
        qCDebug(AVIATORInterfaceLog) << "cn6 버튼 상태 변경: " << (_cn6Pressed ? "눌림" : "해제됨");
    }

    if (cn7 != _cn7Pressed) {
        _cn7Pressed = cn7;
        qCDebug(AVIATORInterfaceLog) << "cn7 버튼 상태 변경: " << (_cn7Pressed ? "눌림" : "해제됨");
    }

    if (cn8 != _cn8Pressed) {
        _cn8Pressed = cn8;
        qCDebug(AVIATORInterfaceLog) << "cn8 버튼 상태 변경: " << (_cn8Pressed ? "눌림" : "해제됨");
    }

    if (cn9 != _cn9Pressed) {
        _cn9Pressed = cn9;
        qCDebug(AVIATORInterfaceLog) << "cn9 버튼 상태 변경: " << (_cn9Pressed ? "눌림" : "해제됨");
    }

    if (cn10 != _cn10Pressed) {
        _cn10Pressed = cn10;
        qCDebug(AVIATORInterfaceLog) << "cn10 버튼 상태 변경: " << (_cn10Pressed ? "눌림" : "해제됨");
    }

    if (cn11 != _cn11Pressed) {
        _cn11Pressed = cn11;
        qCDebug(AVIATORInterfaceLog) << "cn11 버튼 상태 변경: " << (_cn11Pressed ? "눌림" : "해제됨");
    }

    if (cn12 != _cn12Pressed) {
        _cn12Pressed = cn12;
        qCDebug(AVIATORInterfaceLog) << "cn12 버튼 상태 변경: " << (_cn12Pressed ? "눌림" : "해제됨");
    }

    if (cn13 != _cn13Pressed) {
        _cn13Pressed = cn13;
        qCDebug(AVIATORInterfaceLog) << "cn13 버튼 상태 변경: " << (_cn13Pressed ? "눌림" : "해제됨");
    }

    if (cn17 != _cn17Pressed) {
        _cn17Pressed = cn17;
        qCDebug(AVIATORInterfaceLog) << "cn17 버튼 상태 변경: " << (_cn17Pressed ? "눌림" : "해제됨");
    }

    if (cn18 != _cn18Pressed) {
        _cn18Pressed = cn18;
        qCDebug(AVIATORInterfaceLog) << "cn18 버튼 상태 변경: " << (_cn18Pressed ? "눌림" : "해제됨");
    }
#endif

}
void AVIATORInterface::_handle_mavlink_param_value(const mavlink_message_t& message)
{
    mavlink_param_value_t param_value;
    mavlink_msg_param_value_decode(&message, &param_value);

    // This will null terminate the name string
    QByteArray bytes(param_value.param_id, MAVLINK_MSG_PARAM_VALUE_FIELD_PARAM_ID_LEN);
    QString parameterName(bytes);

    Fact* fact = getFact(parameterName);

    if(fact) {
        mavlink_param_union_t paramUnion;
        paramUnion.param_float = param_value.param_value;
        paramUnion.type = param_value.param_type;

        QVariant parameterValue;

        switch (paramUnion.type) {
        case MAV_PARAM_TYPE_REAL32:
            parameterValue = QVariant(paramUnion.param_float);
            break;
        case MAV_PARAM_TYPE_UINT8:
            parameterValue = QVariant(paramUnion.param_uint8);
            break;
        case MAV_PARAM_TYPE_INT8:
            parameterValue = QVariant(paramUnion.param_int8);
            break;
        case MAV_PARAM_TYPE_UINT16:
            parameterValue = QVariant(paramUnion.param_uint16);
            break;
        case MAV_PARAM_TYPE_INT16:
            parameterValue = QVariant(paramUnion.param_int16);
            break;
        case MAV_PARAM_TYPE_UINT32:
            parameterValue = QVariant(paramUnion.param_uint32);
            break;
        case MAV_PARAM_TYPE_INT32:
            parameterValue = QVariant(paramUnion.param_int32);
            break;
        default:
            qCritical() << "AVIATORInterface::_handle_mavlink_param_value - unsupported MAV_PARAM_TYPE" << paramUnion.type;
            break;
        }

        fact->setRawValue(parameterValue);
    }
}
