#include "SerialPortRTCMSource.h"
QGC_LOGGING_CATEGORY(SerialPortRTCMSourceLog, "SerialPortRTCMSourceLog")

SerialPortRTCMSource::SerialPortRTCMSource(QObject* parent)
    : RTCMBase("SerialPortRTCM", parent)
    , _serial(new QSerialPort(this))
{
    connect(_serial, &QSerialPort::readyRead, this, &SerialPortRTCMSource::_onSerialPortReplied);

#ifdef __android__
    // connect(_serial, &QSerialPort::error, this, &SerialPortRTCMSource::_serialError);
#else
    connect(_serial, &QSerialPort::errorOccurred, this, &SerialPortRTCMSource::_serialError);
#endif

    connect(this, &SerialPortRTCMSource::updatePortAndBaud, this, &SerialPortRTCMSource::_openSerial);

    connect(&_timer, &QTimer::timeout, this, &SerialPortRTCMSource::_updateSerialPortConnection);
    _timer.setSingleShot(false);
    _timer.start(3000);
}

SerialPortRTCMSource::~SerialPortRTCMSource()
{
    _serial->close();
}

void SerialPortRTCMSource::_updateSerialPortConnection()
{
    if(port()->rawValue().toString().compare(_serial->portName()) != 0 ||
       baud()->rawValue().toInt() != _serial->baudRate()) {
        emit updatePortAndBaud(port()->rawValue().toString(), baud()->rawValue().toInt());
    } else if(!_serial->isOpen()) {
        emit updatePortAndBaud(port()->rawValue().toString(), baud()->rawValue().toInt());
    }
}

void SerialPortRTCMSource::_onSerialPortReplied()
{
    QByteArray data = _serial->readAll();
    if(_work_queue.size() == 0) {
        send_rtcm_package(data.data(), static_cast<unsigned>(data.size()));
    } else {
        qCWarning(SerialPortRTCMSourceLog) << "Send RTCM: Busy. You can improve RTCM transmission rate.";
    }
}

void SerialPortRTCMSource::_openSerial(QString port, int baud)
{
    if(_serial->isOpen()) {
        _serial->close();
    }
    _serial->setPortName(port);
    _serial->setBaudRate(baud);
    _serial->open(QIODevice::ReadWrite);
//    _serial->clearError();
//    _serial->clear();
}

void SerialPortRTCMSource::_serialError(QSerialPort::SerialPortError erro)
{
    if(erro != QSerialPort::NoError)
        qCWarning(SerialPortRTCMSourceLog) << "Error Code:" << erro;
}

DECLARE_SETTINGSFACT(SerialPortRTCMSource, port)
DECLARE_SETTINGSFACT(SerialPortRTCMSource, baud)
