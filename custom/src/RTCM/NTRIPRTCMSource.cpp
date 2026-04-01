#include "NTRIPRTCMSource.h"
QGC_LOGGING_CATEGORY(NTRIPRTCMSourceLog, "NTRIPRTCMSourceLog")
#include <iostream>
#include <fstream>
#include <QtNetwork>
#include <QStandardPaths>
#include <QElapsedTimer>

NTRIPRTCMSource::NTRIPRTCMSource(QObject* parent)
    : RTCMBase ("NTRIPRTCM", parent)
    , _tcpSocket(new QTcpSocket(this))
    , _gpggamessageFact(0, "gpggamessage", FactMetaData::valueTypeString)
{
    // Help avoid idle-session drops on some networks (best-effort; cannot guarantee server behavior).
    _tcpSocket->setSocketOption(QAbstractSocket::KeepAliveOption, 1);

    connect(_tcpSocket, SIGNAL(connected()), this, SLOT(_onSocketConnected()));
    connect(_tcpSocket, SIGNAL(disconnected()), this, SLOT(_onSocketDisconnected()));
    connect(_tcpSocket, SIGNAL(error(QAbstractSocket::SocketError)), this, SLOT(_onSocketError(QAbstractSocket::SocketError)));
    connect(_tcpSocket, SIGNAL(readyRead()), this, SLOT(_onSocketReplied()));

    Fact* autoGPGGA = autoUpdateGPGGA();
    if(autoGPGGA->rawValue().toBool()) {
        connect(this, &NTRIPRTCMSource::pgggaMessageChanged, gpggamessage(), &Fact::setRawValue);
    } else {
        disconnect(this, &NTRIPRTCMSource::pgggaMessageChanged, gpggamessage(), &Fact::setRawValue);
    }
    connect(autoGPGGA, &Fact::rawValueChanged, this, [this](QVariant value){
        if(value.toBool()) {
            connect(this, &NTRIPRTCMSource::pgggaMessageChanged, gpggamessage(), &Fact::setRawValue);
        } else {
            disconnect(this, &NTRIPRTCMSource::pgggaMessageChanged, gpggamessage(), &Fact::setRawValue);
        }
    });

    Fact* gpggaHz = gpggamessageHz();
    connect(&_sendGPGGATimer, &QTimer::timeout, this, &NTRIPRTCMSource::_handle_send_gpgga_time_out);
    _sendGPGGATimer.setInterval(gpggaHz->rawValue().toInt());
    connect(gpggaHz, &Fact::rawValueChanged, this, [this](QVariant value){
        _sendGPGGATimer.setInterval(value.toInt());
        if(_sendGPGGATimer.isActive()) {
            _sendGPGGATimer.stop();
            _sendGPGGATimer.start();
        }
    });

    // Auto‑reconnect timer: used only when user requested to stay logged in.
    _reconnectTimer.setSingleShot(true);
    _reconnectTimer.setInterval(5000);   // 5s backoff before reconnect
    connect(&_reconnectTimer, &QTimer::timeout, this, [this]() {
        if (_shouldReconnect) {
            qCDebug(NTRIPRTCMSourceLog) << "NTRIP: attempting auto‑reconnect";
            _tcpSocket->abort();
            _tcpSocket->connectToHost(host()->rawValueString(),
                                      static_cast<quint16>(port()->rawValue().toInt()));
        }
    });
    if(host()->rawValue().toString() != "" && port()->rawValue().toString() != ""){ //�̹� ���� ä���� �ִٸ�
        onReadyRead();
    }
}

NTRIPRTCMSource::~NTRIPRTCMSource()
{

}

QStringList NTRIPRTCMSource::getContentList() const
{
    return contentList;
}
void NTRIPRTCMSource::addItem(const QString &item)
{
    contentList.append(item);    
    emit contentListChanged();
}

//Ntrip caster Source Code

size_t writeData(void* ptr, size_t size, size_t nmemb, FILE* stream) {
    return fwrite(ptr, size, nmemb, stream);
}
QString getExternalStoragePaths() {
    // Get the directory for storing external files.
    return QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
}

QTcpSocket* tcpSocket = new QTcpSocket;

int NTRIPRTCMSource::onReadyRead()
{
#ifdef Q_OS_ANDROID
    
    QString filePath = getExternalStoragePaths() + "/rtk_data.xml";
    qCDebug(NTRIPRTCMSourceLog) << "Android File Path : " << filePath;
#else

    QString filePath = "rtk_data.xml";
#endif

    QString userAgent = "MountPointScript";
    QString server = host()->rawValueString();
    int nport = port()->rawValue().toInt();

    qDebug() << "herre1";

    qDebug() << "herre2";
    tcpSocket->connectToHost(server, nport);

    if (!tcpSocket->waitForConnected(5000)) {
        qDebug() << "Connection failed!";
        return -1;
    }

    qDebug() << "herre3";
    QString requestHeader = "GET / HTTP/1.0\r\n"
                            "User-Agent: NTRIP Client/1.0\r\n"
                            "Connection: close\r\n"
                            "\r\n";

    qDebug() << "**********************";
    qDebug() << "*  request_header    *";
    qDebug() << "**********************";
    qDebug() << requestHeader;

    tcpSocket->write(requestHeader.toUtf8());
    if (!tcpSocket->waitForBytesWritten(5000)) {
        qDebug() << "Writing to socket failed!";
        return -1;
    }

    QByteArray response;
    while (tcpSocket->waitForReadyRead(5000)) {
        response.append(tcpSocket->readAll());
    }

    qDebug() << "**********************";
    qDebug() << "*     response       *";
    qDebug() << "**********************";
    qDebug() << response;

    contentList.clear();

    QFile file(filePath);
    if (file.open(QIODevice::WriteOnly)) {
        QTextStream stream(response);
        QTextStream out(&file);

        while (!stream.atEnd()) {
            QString line = stream.readLine();
            if (line.startsWith("STR")) {
                QStringList parts = line.split(';');
                QString mountpoint = parts.value(1);
                QString format = parts.value(3);
                QString both = mountpoint + ":" + format;
                addItem(both);

                out << line << "\n"; 
            }
        }
        file.close();
        std::cout << "RTK data received and saved to: " << filePath.toStdString() << std::endl;
        qCDebug(NTRIPRTCMSourceLog) << "RTK data received and saved to: " << filePath;
    } else {
        std::cerr << "Failed to open file for writing: " << filePath.toStdString() << std::endl;
        qCDebug(NTRIPRTCMSourceLog) << "Failed to open file for writing: " << filePath;
    }

    tcpSocket->close();

    return 0;
}

void NTRIPRTCMSource::get_caster_xml() {
#ifdef Q_OS_ANDROID
    
    QString filePath = getExternalStoragePaths() + "/rtk_data.xml";
    qCDebug(NTRIPRTCMSourceLog) << "Android File Path : " << filePath;
#else
    
    QString filePath = "rtk_data.xml";
#endif

    QUrl url("http://igs-ip.net:2101/");
    qCDebug(NTRIPRTCMSourceLog) << "get caster xml : " << url;
    QNetworkAccessManager manager;
    QNetworkRequest request(url);
    request.setRawHeader("Authorization", "Basic " + QByteArray("MP16804:746zew").toBase64());
    QNetworkReply* reply = manager.get(request);

    QEventLoop loop;
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    if (reply->error() != QNetworkReply::NoError) {
        std::cerr << "Failed to retrieve RTK data. Error: " << reply->errorString().toStdString() << std::endl;
        qCDebug(NTRIPRTCMSourceLog) << "Failed to retrieve RTK data. Error";
    }
    else {
        QFile file(filePath);
        if (file.open(QIODevice::WriteOnly)) {
            while (!reply->atEnd()) {
                QByteArray line = reply->readLine();
                QString strLine(line);

                QStringList parts = strLine.split(';');
                QString target = parts.value(1);
                contentList.append(target);

                file.write(line);
            }

            //file.write(reply->readAll());
            file.close();
            std::cout << "RTK data received and saved to: " << filePath.toStdString() << std::endl;
            qCDebug(NTRIPRTCMSourceLog) << "RTK data received and saved to: ";
        }
        else {
            std::cerr << "Failed to open file for writing: " << filePath.toStdString() << std::endl;
            qCDebug(NTRIPRTCMSourceLog) << "Failed to open file for writing: ";
        }
    }

    reply->deleteLater();
}


void NTRIPRTCMSource::_handle_send_gpgga_time_out()
{
    static QElapsedTimer s_socketFailLogTimer;
    static QElapsedTimer s_fakeGgaWarnTimer;
    if (!s_socketFailLogTimer.isValid()) {
        s_socketFailLogTimer.start();
    }
    if (!s_fakeGgaWarnTimer.isValid()) {
        s_fakeGgaWarnTimer.start();
    }

    if (!(_tcpSocket->isOpen() && _tcpSocket->isValid() && _tcpSocket->isWritable())) {
        if (s_socketFailLogTimer.elapsed() >= 5000) {
            s_socketFailLogTimer.restart();
            qCWarning(NTRIPRTCMSourceLog) << "GPGGA not sent: TCP not ready — open:"
                << _tcpSocket->isOpen() << "valid:" << _tcpSocket->isValid()
                << "writable:" << _tcpSocket->isWritable() << "state:" << _tcpSocket->state()
                << "error:" << _tcpSocket->errorString();
        }
        return;
    }

    // Prefer user/fact GPGGA, then last GGA built from vehicle GPS_RAW_INT (valid rover position).
    QString line = gpggamessage()->rawValueString().trimmed();
    if (line.isEmpty() && !_gpggaFromVehicle.isEmpty()) {
        line = _gpggaFromVehicle.trimmed();
    }
    if (line.isEmpty()) {
        if (s_fakeGgaWarnTimer.elapsed() >= 30000) {
            s_fakeGgaWarnTimer.restart();
            qCWarning(NTRIPRTCMSourceLog)
                << "GPGGA: no vehicle position yet — using built-in fallback coordinates. "
                   "Enable AutoUpdate GPGGA, connect vehicle, or use Get from Vehicle to avoid caster disconnects.";
        }
        line = QString("$GPGGA,%1,3080.7144,N,12134.3847,E,1,04,24.4,19.7,M,1,M,,*").arg(QDateTime::currentDateTimeUtc().toString("hhmmss.zzz"));
        QByteArray array = line.toLatin1();
        uint8_t result = static_cast<uint8_t>(array.at(1));
        for (int i = 2; array.at(i) != '*'; i++) {
            result ^= static_cast<uint8_t>(array.at(i));
        }
        QString res_str = QString::number(result, 16);
        line.append(res_str.count() == 2 ? res_str : QStringLiteral("0") + res_str);
    }

    if (!line.endsWith(QStringLiteral("\r\n"))) {
        line.append(QStringLiteral("\r\n"));
    }
    const qint64 w = _tcpSocket->write(line.toUtf8());
    if (w < 0) {
        qCWarning(NTRIPRTCMSourceLog) << "GPGGA write failed:" << _tcpSocket->errorString();
    } else {
        qCInfo(NTRIPRTCMSourceLog) << "Send GPGGA:" << line.trimmed();
    }
}

void NTRIPRTCMSource::refreshMountPoint()
{
    QTcpSocket* _socket = new QTcpSocket();
    connect(_socket, &QTcpSocket::connected, this, [_socket](){
        static QString request = QString("GET / HTTP/1.1\r\n"
                                         "User-Agent: NTRIPSource/v1.0\r\n"
                                         "Connection: close\r\n"
                                         "\r\n");

        qCDebug(NTRIPRTCMSourceLog) << "Request mount point source table.";
        _socket->write(request.toUtf8());
    });
    connect(_socket, &QTcpSocket::readyRead, this, [this, _socket](){
        QString ok = QString(_socket->readLine());
        if(ok.contains("SOURCETABLE 200 OK")) {
            QStringList enumStrings;
            QVariantList enumValues;
            enumStrings.append("AUTO");
            enumValues.append("AUTO");
            while (!_socket->atEnd()) {
                QString line = _socket->readLine();
                QStringList parameters = line.split(";");
                if(parameters.size() < 2) continue;
                if(parameters.at(0) == "STR" || parameters.at(0) == "CAS" || parameters.at(0) == "NET") {
                    enumStrings.append(parameters.at(1));
                    enumValues.append(parameters.at(1));
                    qCDebug(NTRIPRTCMSourceLog) << QString("Found %1:%2 mount point.").arg(parameters.at(0)).arg(parameters.at(1));
                }
            }
            mountpoint()->setEnumInfo(enumStrings, enumValues);
            emit mountpoint()->enumsChanged();
        }
        _socket->disconnectFromHost();
    });
    _socket->connectToHost(host()->rawValueString(), static_cast<quint16>(port()->rawValue().toInt()));
    connect(_socket, &QTcpSocket::disconnected, _socket, [_socket](){
        qCDebug(NTRIPRTCMSourceLog) << "Finish refreshing mount point.";
        _socket->deleteLater();
    });
    // connect(_socket, QOverload<QAbstractSocket::SocketError>::of(&QAbstractSocket::error), this, [_socket](QAbstractSocket::SocketError error){
    //     qCDebug(NTRIPRTCMSourceLog) << "Refresh mount point error: " << error;
    //     _socket->deleteLater();
    // });

    connect(_socket, &QAbstractSocket::errorOccurred, this, [_socket](QAbstractSocket::SocketError error){
        qCDebug(NTRIPRTCMSourceLog) << "Refresh mount point error: " << error;
        _socket->deleteLater();
    });
}

void NTRIPRTCMSource::getFromVehicle()
{
    gpggamessage()->setRawValue(_gpggaFromVehicle);
}

void NTRIPRTCMSource::logIn()
{
    qCDebug(NTRIPRTCMSourceLog) << "Log In...";
    _shouldReconnect = true;
    setIsLogIning(true);
    _tcpSocket->connectToHost(host()->rawValueString(), static_cast<quint16>(port()->rawValue().toInt()));
}

void NTRIPRTCMSource::logOut()
{
    qCDebug(NTRIPRTCMSourceLog) << "Log Out";
    _shouldReconnect = false;
    _reconnectTimer.stop();
    _sendGPGGATimer.stop();
    _tcpSocket->close();

    if (_tcpSocket->state() != QAbstractSocket::UnconnectedState) {
        qCDebug(NTRIPRTCMSourceLog) << "connectedState";
        _tcpSocket->disconnectFromHost();
        
        QEventLoop loop;
        QTimer timer;
        timer.setSingleShot(true);
        QElapsedTimer elapsedTimer;
        elapsedTimer.start();

        connect(_tcpSocket, &QTcpSocket::disconnected, &loop, &QEventLoop::quit);
        connect(&timer, &QTimer::timeout, &loop, &QEventLoop::quit);
        timer.start(5000);  // 5000ms 

        loop.exec();

        if (_tcpSocket->state() != QAbstractSocket::UnconnectedState) {
            qint64 elapsed = elapsedTimer.elapsed();
            qDebug() << "Time elapsed:" << elapsed << "ms";
            qCDebug(NTRIPRTCMSourceLog) << "Failed to disconnect within timeout, aborting";
            _tcpSocket->abort(); 
        } else {
            qCDebug(NTRIPRTCMSourceLog) << "Disconnected successfully";
        }
    } else {
        qCDebug(NTRIPRTCMSourceLog) << "UnconnectState";
    }
}

void NTRIPRTCMSource::_onSocketConnected()
{
    QString userinfo_raw = QString("%1:%2").arg(user()->rawValueString()).arg(passwd()->rawValueString());
    QString userinfo = QString(userinfo_raw.toLatin1().toBase64());
    QStringList parts = mountpoint()->rawValue().toString().split(':');
    QString mountPoint = parts[0];
    // keep-alive: many casters close the stream prematurely if "Connection: close" is used.
    QString request = QString("GET /%1 HTTP/1.1\r\n"
                              "User-Agent: NTRIPSource/v1.0\r\n"
                              "Accept: */*\r\n"
                              "Connection: keep-alive\r\n"
                              "Authorization: Basic %2\r\n"
                              "\r\n").arg(mountPoint).arg(userinfo);

    _tcpSocket->write(request.toUtf8());
    qCDebug(NTRIPRTCMSourceLog) << "Authorization...\n\r" << request;
}

void NTRIPRTCMSource::_onSocketReplied()
{
    QByteArray data = _tcpSocket->readAll();
    if(data.contains("ICY 200 OK")) {
        if(!autoUpdateGPGGA()->rawValue().toBool()) {
            getFromVehicle();
        }
        setIsLogIning(false);
        setIsLogIn(true);
        // Successful start of stream: cancel any pending reconnect.
        _reconnectTimer.stop();
        if(_sendGPGGATimer.isActive()) {
            _sendGPGGATimer.stop();
        }
        _sendGPGGATimer.start();
        qCInfo(NTRIPRTCMSourceLog) << "NTRIP login OK, GPGGA timer started with interval(ms):"
                                   << _sendGPGGATimer.interval();
        _handle_send_gpgga_time_out();
        qCDebug(NTRIPRTCMSourceLog) << "Socket ICY 200 OK";
    } else if(data.contains("Unauthorized")) {
        _sendGPGGATimer.stop();
        setIsLogIning(false);
        setIsLogIn(false);
        qCDebug(NTRIPRTCMSourceLog) << "Socket Unauthorized ";
    }
    else {
        qCDebug(NTRIPRTCMSourceLog) << "Socket Not contains ";
    }
    QString hexString;
    for (int i = 0; i < data.size(); ++i) {
        hexString.append(QString("%1 ").arg(static_cast<uint8_t>(data.at(i)), 2, 16, QChar('0')));
    }
    qCDebug(NTRIPRTCMSourceLog) << hexString;
    if(static_cast<uint8_t>(data.at(0)) == 0xd3 && static_cast<uint8_t>(data.at(1)) == 0x00) {
        if(isLogIn()) {
            if(_work_queue.size() == 0) {
                send_rtcm_package(data.data(), static_cast<unsigned>(data.size()));
            } else {
                qCWarning(NTRIPRTCMSourceLog) << "Send RTCM: Busy. You can improve RTCM transmission rate.";
            }
        }
        qCDebug(NTRIPRTCMSourceLog) << QString("Socket Replied: RTCM Data(size: %1 bytes)").arg(data.size());
    } else {
        qCDebug(NTRIPRTCMSourceLog) << "Socket Replied data value: ";

        QString hexString;
        for (int i = 0; i < data.size(); ++i) {
            hexString.append(QString("%1 ").arg(static_cast<uint8_t>(data.at(i)), 2, 16, QChar('0')));
        }

        qCDebug(NTRIPRTCMSourceLog) << hexString;


        //�׳� �������� �غ�
        if (host()->rawValueString().contains("igs-ip.net")) {
            if (isLogIn()) {
                if (_work_queue.size() == 0) {
                    send_rtcm_package(data.data(), static_cast<unsigned>(data.size()));
                }
                else {
                    qCWarning(NTRIPRTCMSourceLog) << "Send RTCM: Busy. You can improve RTCM transmission rate.";
                }
            }
        }
        //qCDebug(NTRIPRTCMSourceLog) << QString("Socket Replied: \n\r%1").arg(QString(data));
    }
}

void NTRIPRTCMSource::_onSocketError(QAbstractSocket::SocketError error)
{
    _sendGPGGATimer.stop();
    qCWarning(NTRIPRTCMSourceLog) << "NTRIP TCP error:" << error << _tcpSocket->errorString()
        << "— GPGGA/RTCM from caster will stop until reconnect";
    _tcpSocket->close();
    setIsLogIn(false);
    setIsLogIning(false);
    // If user wanted to stay logged in, try to reconnect after a short delay.
    if (_shouldReconnect && !_reconnectTimer.isActive()) {
        _reconnectTimer.start();
    }
}

void NTRIPRTCMSource::_onSocketDisconnected()
{
    _sendGPGGATimer.stop();
    qCWarning(NTRIPRTCMSourceLog) << "NTRIP TCP disconnected"
        << "shouldReconnect:" << _shouldReconnect << "peer:" << _tcpSocket->peerName();
    setIsLogIn(false);
    setIsLogIning(false);
    // Same logic as error: schedule a reconnect only if user didn't explicitly log out.
    if (_shouldReconnect && !_reconnectTimer.isActive()) {
        qCInfo(NTRIPRTCMSourceLog) << "NTRIP: scheduling reconnect in" << _reconnectTimer.interval() << "ms";
        _reconnectTimer.start();
    }
}

DECLARE_SETTINGSFACT(NTRIPRTCMSource, host)
DECLARE_SETTINGSFACT(NTRIPRTCMSource, port)
DECLARE_SETTINGSFACT(NTRIPRTCMSource, user)
DECLARE_SETTINGSFACT(NTRIPRTCMSource, passwd)
DECLARE_SETTINGSFACT(NTRIPRTCMSource, autoUpdateGPGGA)
DECLARE_SETTINGSFACT(NTRIPRTCMSource, gpggamessageHz)
DECLARE_SETTINGSFACT(NTRIPRTCMSource, mountpoint)
