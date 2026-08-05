#ifndef SERIALPORTRTCMSOURCE_H
#define SERIALPORTRTCMSOURCE_H
#include "RTCMBase.h"
#ifdef __android__
#include "qserialport.h"
#else
#include <QSerialPort>
#endif
#include <QTimer>
#include "QGCLoggingCategory.h"
Q_DECLARE_LOGGING_CATEGORY(SerialPortRTCMSourceLog)

class SerialPortRTCMSource : public RTCMBase
{
    Q_OBJECT
public:
    SerialPortRTCMSource(QObject* parent = nullptr);
    ~SerialPortRTCMSource();

    QString url() final { return "qrc:/RTCM/SerialPortRTCMClient.qml"; }

    DEFINE_SETTINGFACT(port)
    DEFINE_SETTINGFACT(baud)

signals:
    void updatePortAndBaud(QString port, int baud);

private slots:
    void _updateSerialPortConnection();
    void _onSerialPortReplied();
    void _openSerial(QString port, int baud);
    void _serialError(QSerialPort::SerialPortError erro);

private:
    QTimer _timer;
    QSerialPort* _serial{nullptr};
};

#endif // SERIALPORTRTCMSOURCE_H
