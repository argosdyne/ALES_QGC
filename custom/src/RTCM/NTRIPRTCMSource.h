#ifndef NTRIPRTCMSOURCE_H
#define NTRIPRTCMSOURCE_H
#include "RTCMBase.h"
#include <QTcpSocket>
#include "QGCLoggingCategory.h"
Q_DECLARE_LOGGING_CATEGORY(NTRIPRTCMSourceLog)

class NTRIPRTCMSource : public RTCMBase
{
    Q_OBJECT

    Q_PROPERTY(QStringList contentList READ getContentList NOTIFY contentListChanged)

public:
    Q_PROPERTY(bool isLogIning READ isLogIning WRITE setIsLogIning NOTIFY isLogIningChanged)
    bool isLogIning() const { return _isLogIning; }
    void setIsLogIning(const bool& isLogIning) {
        if(_isLogIning == isLogIning) return;
        _isLogIning = isLogIning;
        emit isLogIningChanged(_isLogIning);
    }

    Q_PROPERTY(bool isLogIn READ isLogIn WRITE setIsLogIn NOTIFY isLogInChanged)
    bool isLogIn() const { return _isLogIn; }
    void setIsLogIn(const bool& isLogIn) {
        if(_isLogIn == isLogIn) return;
        _isLogIn = isLogIn;
        emit isLogInChanged(_isLogIn);
    }

    Q_PROPERTY(Fact* gpggamessage READ gpggamessage CONSTANT)
    Fact* gpggamessage() { return &_gpggamessageFact; }

    NTRIPRTCMSource(QObject* parent = nullptr);
    ~NTRIPRTCMSource();

    QString url() final { return "qrc:/RTCM/NTRIPClient.qml"; }

    Q_INVOKABLE void refreshMountPoint();
    Q_INVOKABLE void logIn();
    Q_INVOKABLE void logOut();
    Q_INVOKABLE void getFromVehicle();

    //Ntrip caster
    Q_INVOKABLE void get_caster_xml();
    QStringList getContentList() const;
    void addItem(const QString &item);
    Q_INVOKABLE int onReadyRead();

    DEFINE_SETTINGFACT(host)
    DEFINE_SETTINGFACT(port)
    DEFINE_SETTINGFACT(user)
    DEFINE_SETTINGFACT(passwd)
    DEFINE_SETTINGFACT(autoUpdateGPGGA)
    DEFINE_SETTINGFACT(gpggamessageHz)
    DEFINE_SETTINGFACT(mountpoint)

signals:
    void isLogInChanged(bool isLogIn);
    void isLogIningChanged(bool isLogIning);
    void contentListChanged();

private slots:
    void _handle_send_gpgga_time_out();
    void _onSocketConnected();
    void _onSocketReplied();
    void _onSocketError(QAbstractSocket::SocketError error);
    void _onSocketDisconnected();

private:
    QTimer _sendGPGGATimer;
    QTcpSocket* _tcpSocket{nullptr};
    Fact _gpggamessageFact;
    bool _isLogIn{false};
    bool _isLogIning{false};
    // If true, socket errors/disconnects will trigger automatic reconnect attempts.
    QTimer _reconnectTimer;
    bool   _shouldReconnect{false};
    QStringList contentList;
};

#endif // NTRIPRTCMSOURCE_H
