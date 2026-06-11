#include "AVIATORInterface.h"
#include "QGCLoggingCategory.h"
#include <QQmlEngine>
#include <QString>
#include "CustomQmlInterface.h"
#include "QGCApplication.h"
#include "CustomPlugin.h"
#include "Vehicle.h"

#if defined(Q_OS_ANDROID)
#include <QSocketNotifier>
#include <errno.h>
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>
#include <string.h>
#endif

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
    , _plugin(qobject_cast<CustomPlugin*>(qgcApp()->toolbox()->corePlugin()))
    , _portName("/dev/ttysWK0")
    , _baudRate(115200)
{
    //qmlRegisterUncreatableType<AVIATORInterface>("CustomQmlInterface", 1, 0, "AVIATORInterface", "Reference only");

    _addFact(&_batteryVoltageFact, _batteryVoltageFactName);
    _addFact(&_batteryRemainingFact, _batteryRemainingFactName);
    _addFact(&_versionFact, _versionFactName);
    _addFact(&_temperatureFact, _temperatureFactName);
    _addFact(&_usbOutFact, _usbOutFactName);
    _addFact(&_batteryCurrentFact, _batteryCurrentFactName);
    _addFact(&_batteryChargingFact, _batteryChargingFactName);

    _emergencyHoldTimer.setSingleShot(true);
    _emergencyHoldTimer.setInterval(5000);
    connect(&_emergencyHoldTimer, &QTimer::timeout, this, &AVIATORInterface::_onEmergencyHoldTimeout);

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
#if defined(Q_OS_ANDROID)
    if (_fdNotifier) {
        _fdNotifier->deleteLater();
        _fdNotifier = nullptr;
    }
    if (_fd >= 0) {
        ::close(_fd);
        _fd = -1;
    }
#endif
}

void AVIATORInterface::_writeBytes(const QByteArray data)
{
    if(_port && _port->isOpen()) {
        _port->write(data);
#if defined(Q_OS_ANDROID)
    } else if (_fd >= 0) {
        const qint64 written = ::write(_fd, data.constData(), static_cast<size_t>(data.size()));
        if (written < 0) {
            qWarning() << "Native serial write failed" << strerror(errno) << _portName;
        }
#endif
    } else {
        // Error occurred
        qWarning() << "Serial port not writeable" << _portName;
    }
}

void AVIATORInterface::_readBytes()
{
#if defined(Q_OS_ANDROID)
    if (_fd >= 0) {
        char raw[256];
        ssize_t bytesRead = 0;
        while ((bytesRead = ::read(_fd, raw, sizeof(raw))) > 0) {
            QByteArray buffer(raw, static_cast<int>(bytesRead));
            for (int position = 0; position < buffer.size(); position++) {
                mavlink_message_t message;
                mavlink_status_t status;
                if (mavlink_parse_char(MAVLINK_AVIATOR_COMM_ID, static_cast<uint8_t>(buffer[position]), &message, &status)) {
                    emit bytesReceived(message);
                }
            }
        }
        if (bytesRead < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
            qWarning() << "Native serial read failed" << strerror(errno) << _portName;
        }
        return;
    }
#endif
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
#if defined(Q_OS_ANDROID)
    if (_fdNotifier) {
        _fdNotifier->deleteLater();
        _fdNotifier = nullptr;
    }
    if (_fd >= 0) {
        ::close(_fd);
        _fd = -1;
    }

    auto tryOpenNative = [&](const QString& portName) -> bool {
        const QByteArray pathBytes = portName.toLocal8Bit();
        const int fd = ::open(pathBytes.constData(), O_RDWR | O_NOCTTY | O_NONBLOCK);
        if (fd < 0) {
            qWarning() << "AVIATORInterface native open failed" << strerror(errno) << portName;
            return false;
        }

        termios tty;
        memset(&tty, 0, sizeof(tty));
        if (tcgetattr(fd, &tty) != 0) {
            qWarning() << "AVIATORInterface native tcgetattr failed" << strerror(errno) << portName;
            ::close(fd);
            return false;
        }

        cfmakeraw(&tty);
        cfsetispeed(&tty, B115200);
        cfsetospeed(&tty, B115200);
        tty.c_cflag |= (CLOCAL | CREAD);
        tty.c_cflag &= ~CSTOPB;
        tty.c_cflag &= ~CRTSCTS;
        tty.c_cflag &= ~PARENB;
        tty.c_cflag &= ~CSIZE;
        tty.c_cflag |= CS8;

        if (tcsetattr(fd, TCSANOW, &tty) != 0) {
            qWarning() << "AVIATORInterface native tcsetattr failed" << strerror(errno) << portName;
            ::close(fd);
            return false;
        }

        _fd = fd;
        _fdNotifier = new QSocketNotifier(_fd, QSocketNotifier::Read, this);
        QObject::connect(_fdNotifier, &QSocketNotifier::activated, this, &AVIATORInterface::_readBytes);
        _portName = portName;
        qInfo() << "AVIATORInterface native port opened" << portName;
        return true;
    };
#endif

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
#if defined(Q_OS_ANDROID)
        if (tryOpenNative(_portName)) {
            return;
        }
#endif
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
    //qInfo(AVIATORInterfaceLog) <<  "AVIATORInterface _handle_mavlink_rc_channels";
    {
        static int index = 0;
        //qInfo() << "Aviator _handle_Mavlink_rc_Channels rssi Value = " << channels.rssi;
        _plugin->setForceSendRC(channels.rssi == 254);        
        // Keep alive.
        if(index++ > 25) {
            index = 0;
            mavlink_message_t msg;
            mavlink_msg_rc_channels_encode(0,0,&msg,&channels);
            uint8_t buf[MAVLINK_MAX_PACKET_LEN];
            int len = mavlink_msg_to_send_buffer(buf, &msg);
            QByteArray buffer((const char*)buf, len);
            emit write(buffer);
        }
    }

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

    _updateEmergencyStopCombo(channels.chan7_raw, channels.chan15_raw);


    for (int i = 0; i < newChannelValues.size(); ++i) {
        if (_prevChannelValues[i] != newChannelValues[i]) {
            qCDebug(AVIATORInterfaceLog) << "Channel" << (i + 1) << "Changed: Previous Value =" << _prevChannelValues[i] << ", New Value1 =" << newChannelValues[i];
        }
    }

    if (_prevChannelValues != newChannelValues) {
        qCInfo(AVIATORInterfaceLog) << "[RCFlow]"
                                    << "aviator rc input"
                                    << "count" << channels.chancount
                                    << "rssi" << channels.rssi
                                    << "ch1-4"
                                    << newChannelValues.value(0) << newChannelValues.value(1) << newChannelValues.value(2) << newChannelValues.value(3)
                                    << "ch5-8"
                                    << newChannelValues.value(4) << newChannelValues.value(5) << newChannelValues.value(6) << newChannelValues.value(7)
                                    << "ch9-12"
                                    << newChannelValues.value(8) << newChannelValues.value(9) << newChannelValues.value(10) << newChannelValues.value(11)
                                    << "ch13-18"
                                    << newChannelValues.value(12) << newChannelValues.value(13) << newChannelValues.value(14)
                                    << newChannelValues.value(15) << newChannelValues.value(16) << newChannelValues.value(17);
    }

    _prevChannelValues = newChannelValues;


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
    bool capture = channels.chan12_raw == 2000;
    bool record = channels.chan13_raw == 2000;


    // F1 
    if(f1 != _f1Pressed) {
        _f1Pressed = f1;
        emit buttonPressed(AVIATOR_FUNCTION_GIMBAL_RESET, _f1Pressed);

        //Reset Digital Zoom
        Fact* dZoomFact =  getFact("EO_DZOOM");
        if(dZoomFact) {
            dZoomFact->setRawValue(1.0);
        }
    }

    // F2 
    if(f2 != _f2Pressed) {
        _f2Pressed = f2;
        emit buttonPressed(AVIATOR_FUNCTION_THERMAL_ZOOM, _f2Pressed);
    }

    // F3 
    static int f3Count = 0;
    if(f3) f3Count++;
    else {
        if(f3Count > 0 && f3Count < 50) { // 1s
            emit buttonPressed(AVIATOR_FUNCTION_IR_SWITCH, true);
        }
        f3Count = 0;
    }

    bool f3Pressed = (f3Count > 250); // 5s
    if(f3Pressed != _f3Pressed) {
        _f3Pressed = f3Pressed;
        qCDebug(AVIATORInterfaceLog) << "F3 Button State Changed: " << (_f3Pressed ? "길게 눌림 (5초 이상)" : "해제됨");
        emit buttonPressed(CustomQmlInterface::CUSTOM_FUNCTION_START_MISSION, _f3Pressed);
        qCDebug(AVIATORInterfaceLog) << "START MISSION 명령 전송: " << _f3Pressed;
    }

    //해당 조건에 있을 경우 true를 반환함. 따라서 cn에 맞는 값들을 넣어줘야함
    bool cn1 = channels.chan1_raw ;//== 2000;
    bool cn2 = channels.chan2_raw ;//== 2000;
    bool cn3 = channels.chan3_raw ;//== 2000;
    bool cn4 = channels.chan4_raw ;//== 2000;
    // bool cn5 = channels.chan5_raw ;//== 2000;
    // bool cn6 = channels.chan6_raw ;//== 2000;
    // bool cn7 = channels.chan7_raw ;//== 2000;
    // bool cn8 = channels.chan8_raw ;//== 2000;
    bool cn9 = channels.chan9_raw ;//== 2000;
    bool cn10 = channels.chan10_raw ;//== 2000;
    bool cn11 = channels.chan11_raw ;//== 2000;
    bool cn12 = channels.chan12_raw ;//== 2000;
    bool cn13 = channels.chan13_raw ;//== 2000;
    bool cn17 = channels.chan17_raw ;//== 2000;
    bool cn18 = channels.chan18_raw ;//== 2000;

    if(cn1 != _cn1Pressed){
        _cn1Pressed = cn1;
        qCDebug(AVIATORInterfaceLog) << "cn1 Button State Changed: " << (_cn1Pressed ? "눌림" : "해제됨");
    }

    if (cn2 != _cn2Pressed) {
        _cn2Pressed = cn2;
        qCDebug(AVIATORInterfaceLog) << "cn2 Button State Changed: " << (_cn2Pressed ? "눌림" : "해제됨");
    }

    if (cn3 != _cn3Pressed) {
        _cn3Pressed = cn3;
        qCDebug(AVIATORInterfaceLog) << "cn3 Button State Changed: " << (_cn3Pressed ? "눌림" : "해제됨");
    }

    if (cn4 != _cn4Pressed) {
        _cn4Pressed = cn4;
        qCDebug(AVIATORInterfaceLog) << "cn4 Button State Changed: " << (_cn4Pressed ? "눌림" : "해제됨");
    }

    if(capture != _capturePressed) {
        _capturePressed = capture;
        qInfo() << "Capture Btn Click";
        emit buttonPressed(AVIATOR_FUNCTION_CAMERA_CAPTURE, _capturePressed);
    }

    if(record != _recordPressed) {
        _recordPressed = record;
        qInfo() <<" Record Btn Click";
        emit buttonPressed(AVIATOR_FUNCTION_CAMERA_TOGGLE_RECORD, _recordPressed);
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

bool AVIATORInterface::_rcSwitchActive(uint16_t rawValue)
{
    return rawValue >= 1900;
}

void AVIATORInterface::_resetEmergencyStopComboState()
{
    _comboPaired = false;
    _rc7EdgeMs = -1;
    _rc15EdgeMs = -1;
    _emergencyHoldTimer.stop();
}

void AVIATORInterface::_updateEmergencyStopCombo(uint16_t chan7, uint16_t chan15)
{
    static constexpr int kComboPairWindowMs = 2000;

    _lastRc7Raw = chan7;
    _lastRc15Raw = chan15;

    if (!_comboClock.isValid()) {
        _comboClock.start();
    }

    const bool rc7Active = _rcSwitchActive(chan7);
    const bool rc15Active = _rcSwitchActive(chan15);

    if (rc7Active && !_rc7WasActive) {
        _rc7EdgeMs = _comboClock.elapsed();
        qCInfo(AVIATORInterfaceLog) << "[EmergencyStop] RC7 edge, ch7=" << chan7;
    }
    if (rc15Active && !_rc15WasActive) {
        _rc15EdgeMs = _comboClock.elapsed();
        qCInfo(AVIATORInterfaceLog) << "[EmergencyStop] RC15 edge, ch15=" << chan15;
    }

    _rc7WasActive = rc7Active;
    _rc15WasActive = rc15Active;

    const bool bothEdgesValid = (_rc7EdgeMs >= 0) && (_rc15EdgeMs >= 0);
    const qint64 edgeGapMs = bothEdgesValid ? qAbs(_rc7EdgeMs - _rc15EdgeMs) : (kComboPairWindowMs + 1);
    _comboPaired = rc7Active && rc15Active && bothEdgesValid && (edgeGapMs <= kComboPairWindowMs);

    if (_comboPaired && rc15Active) {
        if (!_emergencyHoldTimer.isActive() && !_emergencyStopComboActive) {
            qCInfo(AVIATORInterfaceLog) << "[EmergencyStop] combo paired, gapMs=" << edgeGapMs
                                        << "ch7=" << chan7 << "ch15=" << chan15;
            _emergencyHoldTimer.start();
        }
    } else if (_emergencyHoldTimer.isActive()) {
        qCInfo(AVIATORInterfaceLog) << "[EmergencyStop] combo cancelled, ch7=" << chan7
                                    << "ch15=" << chan15 << "paired=" << _comboPaired
                                    << "gapMs=" << edgeGapMs;
        _emergencyHoldTimer.stop();
    }

    if (!rc15Active && (_emergencyHoldTimer.isActive() || _comboPaired)) {
        _resetEmergencyStopComboState();
    }

    if (_emergencyStopComboActive && !rc15Active) {
        _emergencyStopComboActive = false;
        _resetEmergencyStopComboState();
    }
}

void AVIATORInterface::_onEmergencyHoldTimeout()
{
    const bool rc7StillActive = _rcSwitchActive(_lastRc7Raw);
    const bool rc15StillHeld = _rcSwitchActive(_lastRc15Raw);
    if (_emergencyStopComboActive || !_comboPaired || !rc7StillActive || !rc15StillHeld) {
        qCInfo(AVIATORInterfaceLog) << "[EmergencyStop] timeout ignored, active=" << _emergencyStopComboActive
                                    << "paired=" << _comboPaired
                                    << "lastCh7=" << _lastRc7Raw << "lastCh15=" << _lastRc15Raw;
        return;
    }

    _emergencyStopComboActive = true;
    qCInfo(AVIATORInterfaceLog) << "RC7+RC15 combo paired and held ~5s total - sending Emergency Stop";
    if (Vehicle* vehicle = qgcApp()->toolbox()->multiVehicleManager()->activeVehicle()) {
        vehicle->emergencyStop();
    } else {
        qCWarning(AVIATORInterfaceLog) << "Emergency Stop: no active vehicle";
    }

    _resetEmergencyStopComboState();
}
