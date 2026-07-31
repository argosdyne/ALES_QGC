#include "SerialPortRTCMSource.h"
#include "RtcmStreamValidator.h"
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
    const QByteArray data = _serial->readAll();
    if (data.isEmpty()) {
        return;
    }

    int droppedBytes = 0;
    bool overflowGuardTriggered = false;
    const QList<QByteArray> validatedFrames = RtcmStreamValidator::appendAndExtractValidatedFrames(
        _rtcmStreamBuffer,
        data,
        &droppedBytes,
        &overflowGuardTriggered,
        [](const QByteArray& frame, quint32 expectedCrc, quint32 actualCrc) {
            qCWarning(SerialPortRTCMSourceLog)
                << "RTCM CRC mismatch"
                << "expected=0x" << QString::number(expectedCrc, 16).toUpper().rightJustified(6, '0')
                << "actual=0x" << QString::number(actualCrc, 16).toUpper().rightJustified(6, '0')
                << "frameLen=" << frame.size();
        });
    if (overflowGuardTriggered) {
        qCWarning(SerialPortRTCMSourceLog) << "RTCM stream buffer overflow guard triggered";
    } else if (droppedBytes > 0 && validatedFrames.isEmpty()) {
        qCDebug(SerialPortRTCMSourceLog) << "RTCM parser dropped bytes:" << droppedBytes
                                         << "buffer remain:" << _rtcmStreamBuffer.size();
    }

    for (const QByteArray& frame : validatedFrames) {
        send_rtcm_package(frame.constData(), static_cast<unsigned>(frame.size()));
    }
}

void SerialPortRTCMSource::_openSerial(QString port, int baud)
{
    if(_serial->isOpen()) {
        _serial->close();
    }
    _rtcmStreamBuffer.clear();
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
