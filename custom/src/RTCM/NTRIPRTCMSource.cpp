#include "NTRIPRTCMSource.h"
QGC_LOGGING_CATEGORY(NTRIPRTCMSourceLog, "NTRIPRTCMSourceLog")
#include <iostream>
#include <fstream>
#include <QtNetwork>
#include <QStandardPaths>
#include <QElapsedTimer>
#include <QDir>
#include <QFile>
#include <QTextStream>

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

// Keep platform-specific path behavior aligned with rtk_data.xml handling.
#ifdef Q_OS_ANDROID
    QString logDir = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    if (logDir.isEmpty()) {
        logDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    }
    QDir().mkpath(logDir);
    _crcErrorLogPath = QDir(logDir).filePath("ntrip_rtcm_crc_errors.log");
#else
    _crcErrorLogPath = "ntrip_rtcm_crc_errors.log";
#endif

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

    _rtcmStatsTimer.setInterval(1000);
    connect(&_rtcmStatsTimer, &QTimer::timeout, this, [this]() {
        _rtcmFramesPerSecond = _rtcmFramesCurrentSecond;
        _rtcmFramesCurrentSecond = 0;
        _rawBytesPerSecond = _rawBytesCurrentSecond;
        _rawBytesCurrentSecond = 0;
        _droppedBytesPerSecond = _droppedBytesCurrentSecond;
        _droppedBytesCurrentSecond = 0;
        _mavlinkRtcmSentPerSecond = _mavlinkRtcmSentCurrentSecond;
        _mavlinkRtcmSentCurrentSecond = 0;
        _crcErrorsPerSecond = _crcErrorsCurrentSecond;
        _crcErrorsCurrentSecond = 0;
        if (_lastRtcmReceivedMsec >= 0) {
            const qint64 elapsedMs = QDateTime::currentMSecsSinceEpoch() - _lastRtcmReceivedMsec;
            _lastRtcmReceivedSec = static_cast<int>(qMax<qint64>(0, elapsedMs / 1000));
        } else {
            _lastRtcmReceivedSec = -1;
        }
        emit rtcmStatsChanged();
    });
    _rtcmStatsTimer.start();
    connect(this, &RTCMBase::rtcmChunkSent, this, [this]() {
        _mavlinkRtcmSentCurrentSecond++;
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
    static QElapsedTimer s_ggaDetailLogTimer;
    if (!s_socketFailLogTimer.isValid()) {
        s_socketFailLogTimer.start();
    }
    if (!s_fakeGgaWarnTimer.isValid()) {
        s_fakeGgaWarnTimer.start();
    }
    if (!s_ggaDetailLogTimer.isValid()) {
        s_ggaDetailLogTimer.start();
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

    QString line;
    QString ggaSource;
    const bool autoGgaEnabled = autoUpdateGPGGA()->rawValue().toBool();

    // In auto mode, never reuse a stale manually entered GGA.
    if (autoGgaEnabled) {
        line = _gpggaFromVehicle.trimmed();
        ggaSource = QStringLiteral("vehicle");
    } else {
        line = gpggamessage()->rawValueString().trimmed();
        ggaSource = QStringLiteral("manual/fact");
        if (line.isEmpty() && !_gpggaFromVehicle.isEmpty()) {
            line = _gpggaFromVehicle.trimmed();
            ggaSource = QStringLiteral("vehicle");
        }
    }

    if (line.isEmpty()) {
        if (s_fakeGgaWarnTimer.elapsed() >= 30000) {
            s_fakeGgaWarnTimer.restart();
            qCWarning(NTRIPRTCMSourceLog)
                << "GPGGA: no vehicle position yet — using built-in fallback coordinates. "
                   "Enable AutoUpdate GPGGA, connect vehicle, or use Get from Vehicle to avoid caster disconnects.";
        }
        // Lefebure-style fallback: valid ddmm.mmmm + whole-second UTC timestamp.
        line = QString("$GPGGA,%1,5507.0033,N,01455.9561,E,4,10,1.0,200.0,M,1.0,M,,*")
                   .arg(QDateTime::currentDateTimeUtc().toString("hhmmss"));
        ggaSource = QStringLiteral("fallback");
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
        if (s_ggaDetailLogTimer.elapsed() >= 10000) {
            s_ggaDetailLogTimer.restart();
            const QString payload = line.startsWith('$') ? line.mid(1) : line;
            const QStringList fields = payload.split(',');
            if (fields.size() >= 8 && fields.at(0).startsWith(QStringLiteral("GPGGA"))) {
                qCInfo(NTRIPRTCMSourceLog) << "GPGGA detail source:" << ggaSource
                                           << "lat:" << fields.at(2) << fields.at(3)
                                           << "lon:" << fields.at(4) << fields.at(5)
                                           << "fix:" << fields.at(6)
                                           << "sats:" << fields.at(7);
            } else {
                qCInfo(NTRIPRTCMSourceLog) << "GPGGA detail source:" << ggaSource
                                           << "(unparsed)" << line.trimmed();
            }
        }
    }
}

void NTRIPRTCMSource::refreshMountPoint()
{
    QTcpSocket* _socket = new QTcpSocket();
    connect(_socket, &QTcpSocket::connected, this, [_socket](){
        static QString request = QString("GET / HTTP/1.0\r\n"
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
    _ntripHandshakeBuffer.clear();
    _ntripResponseHeaderParsed = false;
    _rtcmStreamBuffer.clear();
    _clearRtcmQueue();
    _resetRtcmStats();
    setIsLogIning(true);
    _tcpSocket->connectToHost(host()->rawValueString(), static_cast<quint16>(port()->rawValue().toInt()));
}

void NTRIPRTCMSource::logOut()
{
    qCDebug(NTRIPRTCMSourceLog) << "Log Out";
    _shouldReconnect = false;
    _reconnectTimer.stop();
    _sendGPGGATimer.stop();
    _ntripHandshakeBuffer.clear();
    _ntripResponseHeaderParsed = false;
    _rtcmStreamBuffer.clear();
    _clearRtcmQueue();
    _resetRtcmStats();
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
    const QString username = user()->rawValueString();
    const QString password = passwd()->rawValueString();
    const QString userinfo_raw = QString("%1:%2").arg(username).arg(password);
    const QString userinfo = QString(userinfo_raw.toLatin1().toBase64());
    QStringList parts = mountpoint()->rawValue().toString().split(':');
    QString mountPoint = parts[0];
    QString request = QString("GET /%1 HTTP/1.0\r\n"
                              "User-Agent: NTRIP Source/v1.0\r\n"
                              "Accept: */*\r\n"
                              "Connection: close\r\n")
                          .arg(mountPoint);
    if (!username.isEmpty()) {
        request += QString("Authorization: Basic %1\r\n").arg(userinfo);
    }
    request += QString("\r\n");

    _tcpSocket->write(request.toUtf8());
    qCDebug(NTRIPRTCMSourceLog) << "Authorization...\n\r" << request;
}

void NTRIPRTCMSource::_onSocketReplied()
{
    QByteArray data = _tcpSocket->readAll();
    if (data.isEmpty()) {
        return;
    }
    _rawBytesCurrentSecond += data.size();

    if (!_ntripResponseHeaderParsed) {
        _ntripHandshakeBuffer.append(data);
        int headerTerminatorLen = 0;
        int headerEndIndex = -1;

        // ICY responses from many NTRIP v1 casters are often a single line
        // ("ICY 200 OK\r\n") followed directly by binary RTCM payload.
        if (_ntripHandshakeBuffer.startsWith("ICY ")) {
            headerTerminatorLen = 2;
            headerEndIndex = _ntripHandshakeBuffer.indexOf("\r\n");
            if (headerEndIndex < 0) {
                headerTerminatorLen = 1;
                headerEndIndex = _ntripHandshakeBuffer.indexOf('\n');
            }
        } else {
            headerTerminatorLen = 4;
            headerEndIndex = _ntripHandshakeBuffer.indexOf("\r\n\r\n");
            if (headerEndIndex < 0) {
                headerTerminatorLen = 2;
                headerEndIndex = _ntripHandshakeBuffer.indexOf("\n\n");
            }
        }
        if (headerEndIndex < 0) {
            return;
        }

        const int bodyStart = headerEndIndex + headerTerminatorLen;
        const QByteArray header = _ntripHandshakeBuffer.left(bodyStart);
        const QByteArray body = _ntripHandshakeBuffer.mid(bodyStart);
        _ntripHandshakeBuffer.clear();
        _ntripResponseHeaderParsed = true;

        const QString headerText = QString::fromLatin1(header);
        int lineEnd = headerText.indexOf("\r\n");
        if (lineEnd < 0) {
            lineEnd = headerText.indexOf('\n');
        }
        const QString firstHeaderLine = (lineEnd >= 0) ? headerText.left(lineEnd) : headerText;
        qCInfo(NTRIPRTCMSourceLog) << "NTRIP response first line:" << firstHeaderLine;
        const bool unauthorized = headerText.contains("Unauthorized", Qt::CaseInsensitive) ||
                                  headerText.contains(" 401 ");
        const bool sourceTableResponse = headerText.contains("SOURCETABLE 200 OK", Qt::CaseInsensitive);
        const bool loginOk = headerText.contains("ICY 200 OK") ||
                             headerText.contains("HTTP/1.0 200 OK") ||
                             headerText.contains("HTTP/1.1 200 OK");

        if (unauthorized) {
            _sendGPGGATimer.stop();
            setIsLogIning(false);
            setIsLogIn(false);
            _rtcmStreamBuffer.clear();
            _clearRtcmQueue();
            _resetRtcmStats();
            qCWarning(NTRIPRTCMSourceLog) << "NTRIP unauthorized response header:" << headerText.trimmed();
            return;
        }

        if (!loginOk || sourceTableResponse) {
            _sendGPGGATimer.stop();
            setIsLogIning(false);
            setIsLogIn(false);
            _rtcmStreamBuffer.clear();
            _clearRtcmQueue();
            _resetRtcmStats();
            qCWarning(NTRIPRTCMSourceLog) << "Unexpected NTRIP response header (not RTCM stream):"
                                          << headerText.trimmed();
            return;
        }

        if (!autoUpdateGPGGA()->rawValue().toBool()) {
            getFromVehicle();
        }
        setIsLogIning(false);
        setIsLogIn(true);
        _reconnectTimer.stop();
        if (_sendGPGGATimer.isActive()) {
            _sendGPGGATimer.stop();
        }
        _sendGPGGATimer.start();
        qCInfo(NTRIPRTCMSourceLog) << "NTRIP login OK, GPGGA timer started with interval(ms):"
                                   << _sendGPGGATimer.interval();
        _handle_send_gpgga_time_out();
        data = body;
        if (data.isEmpty()) {
            return;
        }
    }

    if (!isLogIn()) {
        return;
    }

    // Keep a short preview of the latest raw bytes from caster for troubleshooting.
    _lastRawChunkHexPreview = QString::fromLatin1(data.left(32).toHex(' ')).toUpper();

    _rtcmStreamBuffer.append(data);
    if (_rtcmStreamBuffer.size() > 65536) {
        int removed = 0;
        const int lastPreamble = _rtcmStreamBuffer.lastIndexOf(static_cast<char>(0xD3));
        if (lastPreamble >= 0) {
            removed = lastPreamble;
            _rtcmStreamBuffer.remove(0, lastPreamble);
        } else {
            removed = _rtcmStreamBuffer.size();
            _rtcmStreamBuffer.clear();
        }
        _droppedBytesCurrentSecond += removed;
        qCWarning(NTRIPRTCMSourceLog) << "RTCM stream buffer overflow guard triggered";
    }

    int parsedFrames = 0;
    int droppedBytes = 0;
    while (_rtcmStreamBuffer.size() >= 6) {
        const int preambleIndex = _rtcmStreamBuffer.indexOf(static_cast<char>(0xD3));
        if (preambleIndex < 0) {
            droppedBytes += _rtcmStreamBuffer.size();
            _rtcmStreamBuffer.clear();
            break;
        }
        if (preambleIndex > 0) {
            droppedBytes += preambleIndex;
            _rtcmStreamBuffer.remove(0, preambleIndex);
        }
        if (_rtcmStreamBuffer.size() < 3) {
            break;
        }

        const uint8_t b1 = static_cast<uint8_t>(_rtcmStreamBuffer.at(1));
        const uint8_t b2 = static_cast<uint8_t>(_rtcmStreamBuffer.at(2));
        const int payloadLen = ((b1 & 0x03) << 8) | b2;
        if (payloadLen <= 0 || payloadLen > 1023) {
            droppedBytes += 1;
            _rtcmStreamBuffer.remove(0, 1);
            continue;
        }

        const int frameLen = 3 + payloadLen + 3;
        if (_rtcmStreamBuffer.size() < frameLen) {
            break;
        }

        const QByteArray frame = _rtcmStreamBuffer.left(frameLen);
        const quint32 expectedCrc =
            (static_cast<quint32>(static_cast<uint8_t>(frame.at(frameLen - 3))) << 16) |
            (static_cast<quint32>(static_cast<uint8_t>(frame.at(frameLen - 2))) << 8) |
            static_cast<quint32>(static_cast<uint8_t>(frame.at(frameLen - 1)));
        const quint32 actualCrc = _crc24q(frame.constData(), frameLen - 3);
        if (expectedCrc != actualCrc) {
            _crcErrorsCurrentSecond++;
            _crcErrorsTotal++;
            _lastCrcErrorAt = QDateTime::currentDateTime().toString(Qt::ISODate);
            _logRtcmCrcError(frame, expectedCrc, actualCrc);
            droppedBytes += 1;
            _rtcmStreamBuffer.remove(0, 1);
            continue;
        }

        _rtcmStreamBuffer.remove(0, frameLen);
        _lastRtcmFrameHexPreview = QString::fromLatin1(frame.left(32).toHex(' ')).toUpper();
        if (frame.size() >= 5) {
            const uint8_t payload0 = static_cast<uint8_t>(frame.at(3));
            const uint8_t payload1 = static_cast<uint8_t>(frame.at(4));
            _lastRtcmMessageType = static_cast<int>((payload0 << 4) | (payload1 >> 4));
        } else {
            _lastRtcmMessageType = -1;
        }
        send_rtcm_package(frame.constData(), static_cast<unsigned>(frame.size()));
        _rtcmFramesCurrentSecond++;
        _rtcmTotalFrames++;
        _rtcmTotalBytes += static_cast<quint64>(frame.size());
        _lastRtcmReceivedMsec = QDateTime::currentMSecsSinceEpoch();
        _lastRtcmReceivedSec = 0;
        parsedFrames++;
    }
    _droppedBytesCurrentSecond += droppedBytes;

    if (parsedFrames > 0) {
        const size_t queueSize = _work_queue.size();
        qCDebug(NTRIPRTCMSourceLog) << "RTCM parsed frames:" << parsedFrames
                                    << "queue size:" << static_cast<quint64>(queueSize)
                                    << "buffer remain:" << _rtcmStreamBuffer.size();
        if (queueSize > 30) {
            qCWarning(NTRIPRTCMSourceLog) << "RTCM queue backlog is large:" << static_cast<quint64>(queueSize)
            << "(consider lowering sendMaxRTCMHz interval)";
        }
    } else if (droppedBytes > 0) {
        qCDebug(NTRIPRTCMSourceLog) << "RTCM parser dropped bytes:" << droppedBytes
                                    << "buffer remain:" << _rtcmStreamBuffer.size();
    }
}

quint32 NTRIPRTCMSource::_crc24q(const char* data, int length)
{
    quint32 crc = 0;
    for (int i = 0; i < length; ++i) {
        crc ^= static_cast<quint32>(static_cast<uint8_t>(data[i])) << 16;
        for (int bit = 0; bit < 8; ++bit) {
            crc <<= 1;
            if (crc & 0x1000000) {
                crc ^= 0x1864CFB;
            }
        }
    }
    return crc & 0xFFFFFF;
}

void NTRIPRTCMSource::_logRtcmCrcError(const QByteArray& frame, quint32 expectedCrc, quint32 actualCrc)
{
    QFile file(_crcErrorLogPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        qCWarning(NTRIPRTCMSourceLog) << "Failed to open CRC error log file:" << _crcErrorLogPath;
        return;
    }

    QTextStream out(&file);
    out << QDateTime::currentDateTime().toString(Qt::ISODate)
        << " | CRC mismatch"
        << " | expected=0x" << QString::number(expectedCrc, 16).toUpper().rightJustified(6, '0')
        << " | actual=0x" << QString::number(actualCrc, 16).toUpper().rightJustified(6, '0')
        << " | frameLen=" << frame.size()
        << " | frameHex=" << QString::fromLatin1(frame.left(64).toHex(' ')).toUpper()
        << '\n';
}

void NTRIPRTCMSource::_onSocketError(QAbstractSocket::SocketError error)
{
    _sendGPGGATimer.stop();
    qCWarning(NTRIPRTCMSourceLog) << "NTRIP TCP error:" << error << _tcpSocket->errorString()
                                  << "— GPGGA/RTCM from caster will stop until reconnect";
    qCDebug(NTRIPRTCMSourceLog) << QString("Socket Error:") << error;
    _tcpSocket->close();
    _ntripHandshakeBuffer.clear();
    _ntripResponseHeaderParsed = false;
    _rtcmStreamBuffer.clear();
    _clearRtcmQueue();
    _resetRtcmStats();
    setIsLogIn(false);
    setIsLogIning(false);
    if (_shouldReconnect && !_reconnectTimer.isActive()) {
        _reconnectTimer.start();
    }
}

void NTRIPRTCMSource::_onSocketDisconnected()
{
    _sendGPGGATimer.stop();
    qCWarning(NTRIPRTCMSourceLog) << "NTRIP TCP disconnected"
                                  << "shouldReconnect:" << _shouldReconnect << "peer:" << _tcpSocket->peerName();
    _ntripHandshakeBuffer.clear();
    _ntripResponseHeaderParsed = false;
    _rtcmStreamBuffer.clear();
    _clearRtcmQueue();
    _resetRtcmStats();
    setIsLogIn(false);
    setIsLogIning(false);
    // Same logic as error: schedule a reconnect only if user didn't explicitly log out.
    if (_shouldReconnect && !_reconnectTimer.isActive()) {
        qCInfo(NTRIPRTCMSourceLog) << "NTRIP: scheduling reconnect in" << _reconnectTimer.interval() << "ms";
        _reconnectTimer.start();
    }
}

void NTRIPRTCMSource::_clearRtcmQueue()
{
    LockedQueue<rtcm_data_t>::Guard queueGuard(_work_queue);
    while (queueGuard.get_front()) {
        queueGuard.pop_front();
    }
}

void NTRIPRTCMSource::_resetRtcmStats()
{
    _rtcmFramesCurrentSecond = 0;
    _rtcmFramesPerSecond = 0;
    _rtcmTotalFrames = 0;
    _rtcmTotalBytes = 0;
    _rawBytesCurrentSecond = 0;
    _rawBytesPerSecond = 0;
    _droppedBytesCurrentSecond = 0;
    _droppedBytesPerSecond = 0;
    _mavlinkRtcmSentCurrentSecond = 0;
    _mavlinkRtcmSentPerSecond = 0;
    _crcErrorsCurrentSecond = 0;
    _crcErrorsPerSecond = 0;
    _crcErrorsTotal = 0;
    _lastCrcErrorAt.clear();
    _lastRtcmReceivedMsec = -1;
    _lastRtcmReceivedSec = -1;
    _lastRawChunkHexPreview.clear();
    _lastRtcmFrameHexPreview.clear();
    _lastRtcmMessageType = -1;
    emit rtcmStatsChanged();
}

DECLARE_SETTINGSFACT(NTRIPRTCMSource, host)
DECLARE_SETTINGSFACT(NTRIPRTCMSource, port)
DECLARE_SETTINGSFACT(NTRIPRTCMSource, user)
DECLARE_SETTINGSFACT(NTRIPRTCMSource, passwd)
DECLARE_SETTINGSFACT(NTRIPRTCMSource, autoUpdateGPGGA)
DECLARE_SETTINGSFACT(NTRIPRTCMSource, gpggamessageHz)
DECLARE_SETTINGSFACT(NTRIPRTCMSource, mountpoint)
