#ifndef NTRIPRTCMSOURCE_H
#define NTRIPRTCMSOURCE_H
#include "RTCMBase.h"
#include <QTcpSocket>
#include <QByteArray>
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

    Q_PROPERTY(int rtcmFramesPerSecond READ rtcmFramesPerSecond NOTIFY rtcmStatsChanged)
    int rtcmFramesPerSecond() const { return _rtcmFramesPerSecond; }

    Q_PROPERTY(quint64 rtcmTotalFrames READ rtcmTotalFrames NOTIFY rtcmStatsChanged)
    quint64 rtcmTotalFrames() const { return _rtcmTotalFrames; }

    Q_PROPERTY(quint64 rtcmTotalBytes READ rtcmTotalBytes NOTIFY rtcmStatsChanged)
    quint64 rtcmTotalBytes() const { return _rtcmTotalBytes; }

    Q_PROPERTY(int rawBytesPerSecond READ rawBytesPerSecond NOTIFY rtcmStatsChanged)
    int rawBytesPerSecond() const { return _rawBytesPerSecond; }

    Q_PROPERTY(int droppedBytesPerSecond READ droppedBytesPerSecond NOTIFY rtcmStatsChanged)
    int droppedBytesPerSecond() const { return _droppedBytesPerSecond; }

    Q_PROPERTY(int mavlinkRtcmSentPerSecond READ mavlinkRtcmSentPerSecond NOTIFY rtcmStatsChanged)
    int mavlinkRtcmSentPerSecond() const { return _mavlinkRtcmSentPerSecond; }

    Q_PROPERTY(int crcErrorsPerSecond READ crcErrorsPerSecond NOTIFY rtcmStatsChanged)
    int crcErrorsPerSecond() const { return _crcErrorsPerSecond; }

    Q_PROPERTY(quint64 crcErrorsTotal READ crcErrorsTotal NOTIFY rtcmStatsChanged)
    quint64 crcErrorsTotal() const { return _crcErrorsTotal; }

    Q_PROPERTY(QString lastCrcErrorAt READ lastCrcErrorAt NOTIFY rtcmStatsChanged)
    QString lastCrcErrorAt() const { return _lastCrcErrorAt; }

    Q_PROPERTY(QString crcErrorLogPath READ crcErrorLogPath CONSTANT)
    QString crcErrorLogPath() const { return _crcErrorLogPath; }

    Q_PROPERTY(int lastRtcmReceivedSec READ lastRtcmReceivedSec NOTIFY rtcmStatsChanged)
    int lastRtcmReceivedSec() const { return _lastRtcmReceivedSec; }
    Q_PROPERTY(QString lastRawChunkHexPreview READ lastRawChunkHexPreview NOTIFY rtcmStatsChanged)
    QString lastRawChunkHexPreview() const { return _lastRawChunkHexPreview; }
    Q_PROPERTY(QString lastRtcmFrameHexPreview READ lastRtcmFrameHexPreview NOTIFY rtcmStatsChanged)
    QString lastRtcmFrameHexPreview() const { return _lastRtcmFrameHexPreview; }
    Q_PROPERTY(int lastRtcmMessageType READ lastRtcmMessageType NOTIFY rtcmStatsChanged)
    int lastRtcmMessageType() const { return _lastRtcmMessageType; }

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
    DEFINE_SETTINGFACT(mountpointManual)
    DEFINE_SETTINGFACT(mountpointManualValue)

signals:
    void isLogInChanged(bool isLogIn);
    void isLogIningChanged(bool isLogIning);
    void contentListChanged();
    void rtcmStatsChanged();

private slots:
    void _handle_send_gpgga_time_out();
    void _onSocketConnected();
    void _onSocketReplied();
    void _onSocketError(QAbstractSocket::SocketError error);
    void _onSocketDisconnected();

private:
    static quint32 _crc24q(const char* data, int length);
    void _logRtcmCrcError(const QByteArray& frame, quint32 expectedCrc, quint32 actualCrc);
    void _clearRtcmQueue();
    void _resetRtcmStats();
    bool _isPremiumCaster();
    QString _activeMountPointName();

    QTimer _sendGPGGATimer;
    QTcpSocket* _tcpSocket{nullptr};
    Fact _gpggamessageFact;
    bool _isLogIn{false};
    bool _isLogIning{false};
    QTimer _reconnectTimer;
    bool   _shouldReconnect{false};
    QStringList contentList;
    QByteArray _ntripHandshakeBuffer;
    bool _ntripResponseHeaderParsed{false};
    QByteArray _rtcmStreamBuffer;
    QTimer _rtcmStatsTimer;
    int _rtcmFramesCurrentSecond{0};
    int _rtcmFramesPerSecond{0};
    quint64 _rtcmTotalFrames{0};
    quint64 _rtcmTotalBytes{0};
    int _rawBytesCurrentSecond{0};
    int _rawBytesPerSecond{0};
    int _droppedBytesCurrentSecond{0};
    int _droppedBytesPerSecond{0};
    int _mavlinkRtcmSentCurrentSecond{0};
    int _mavlinkRtcmSentPerSecond{0};
    int _crcErrorsCurrentSecond{0};
    int _crcErrorsPerSecond{0};
    quint64 _crcErrorsTotal{0};
    QString _lastCrcErrorAt;
    QString _crcErrorLogPath;
    qint64 _lastRtcmReceivedMsec{-1};
    int _lastRtcmReceivedSec{-1};
    QString _lastRawChunkHexPreview;
    QString _lastRtcmFrameHexPreview;
    int _lastRtcmMessageType{-1};
};

#endif // NTRIPRTCMSOURCE_H
