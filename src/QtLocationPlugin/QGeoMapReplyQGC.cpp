/****************************************************************************
**
** Copyright (C) 2013 Aaron McCarthy <mccarthy.aaron@gmail.com>
** Contact: http://www.qt-project.org/legal
**
** This file is part of the QtLocation module of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:LGPL$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and Digia.  For licensing terms and
** conditions see http://qt.digia.com/licensing.  For further information
** use the contact form at http://qt.digia.com/contact-us.
**
** GNU Lesser General Public License Usage
** Alternatively, this file may be used under the terms of the GNU Lesser
** General Public License version 2.1 as published by the Free Software
** Foundation and appearing in the file LICENSE.LGPL included in the
** packaging of this file.  Please review the following information to
** ensure the GNU Lesser General Public License version 2.1 requirements
** will be met: http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html.
**
** In addition, as a special exception, Digia gives you certain additional
** rights.  These rights are described in the Digia Qt LGPL Exception
** version 1.1, included in the file LGPL_EXCEPTION.txt in this package.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU
** General Public License version 3.0 as published by the Free Software
** Foundation and appearing in the file LICENSE.GPL included in the
** packaging of this file.  Please review the following information to
** ensure the GNU General Public License version 3.0 requirements will be
** met: http://www.gnu.org/copyleft/gpl.html.
**
**
** $QT_END_LICENSE$
**
** 2015.4.4
** Adapted for use with QGroundControl
**
** Gus Grubba <gus@auterion.com>
**
****************************************************************************/

#include "QGCMapEngine.h"
#include "QGeoMapReplyQGC.h"
#include "QGeoTileFetcherQGC.h"

#include <QtLocation/private/qgeotilespec_p.h>
#include <QtNetwork/QNetworkAccessManager>
#include <QFile>
#include <QCoreApplication>
#include "TerrainTile.h"
#include "CustomQmlInterface.h"
#include "MapProvider.h"
int         QGeoTiledMapReplyQGC::_requestCount = 0;
QByteArray  QGeoTiledMapReplyQGC::_bingNoTileImage;
static const int kTileDownloadTimeoutMs      = 10000;
static const int kTileDownloadTimeoutRetries = 2;

static bool tileBytesAreImage(const QByteArray& image)
{
    static const unsigned char pngSig[]  = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A};
    static const unsigned char jpegSig[] = {0xFF, 0xD8, 0xFF};
    static const unsigned char gifSig[]  = {0x47, 0x49, 0x46, 0x38};
    return image.startsWith(QByteArray(reinterpret_cast<const char*>(pngSig), int(sizeof(pngSig))))
        || image.startsWith(QByteArray(reinterpret_cast<const char*>(jpegSig), int(sizeof(jpegSig))))
        || image.startsWith(QByteArray(reinterpret_cast<const char*>(gifSig), int(sizeof(gifSig))));
}

static inline QString mapDownloadRequiredMessage()
{
    return QCoreApplication::translate("QGeoTiledMapReplyQGC", "Please download the map of the flight area.");
}

// VWorld returns these as HTTP 200 XML, not as a network error.
// The log text is English. The Korean literals below are the server's ExceptionText.
static QString vworldTileRejection(const QUrl& url, const QByteArray& body)
{
    if (!url.host().contains(QLatin1String("vworld.kr"), Qt::CaseInsensitive)) {
        return QString();
    }
    // <Exception locator="key"> means the API key is not registered.
    if (body.contains("locator=\"key\"")) {
        return QStringLiteral("VWorld: unregistered API key");
    }
    // Quota ExceptionText is Korean. "초과" = exceeded, together with
    // usage / traffic / calls / limit. OVER_REQUEST is VWorld's English code.
    const QString text = QString::fromUtf8(body);
    if (body.contains("OVER_REQUEST")
        || (text.contains(QStringLiteral("초과"))
            && (text.contains(QStringLiteral("활용"))
                || text.contains(QStringLiteral("트래픽"))
                || text.contains(QStringLiteral("호출"))
                || text.contains(QStringLiteral("제한"))))) {
        return QStringLiteral("VWorld: usage quota exceeded");
    }
    return QString();
}

static void logVworldTileRejectionOnce(const QString& message)
{
    static QStringList logged;
    if (logged.contains(message)) {
        return;
    }
    logged.append(message);
    qWarning().noquote() << message;
}

//-----------------------------------------------------------------------------
QGeoTiledMapReplyQGC::QGeoTiledMapReplyQGC(QNetworkAccessManager *networkManager, const QNetworkRequest &request, const QGeoTileSpec &spec, QObject *parent)
    : QGeoTiledMapReply(spec, parent)
    , _reply(nullptr)
    , _request(request)
    , _networkManager(networkManager)
    , _timeoutRetries(0)
    , _aborted(false)
    , _awaitingOverlay(false)
{
    if (_bingNoTileImage.count() == 0) {
        QFile file(":/res/BingNoTileBytes.dat");
        file.open(QFile::ReadOnly);
        _bingNoTileImage = file.readAll();
        file.close();
    }
    if(_request.url().isEmpty()) {
        if(!_badMapbox.size()) {
            QFile b(":/res/notile.png");
            if(b.open(QFile::ReadOnly))
                _badMapbox = b.readAll();
        }
        setMapImageData(_badMapbox);
        setMapImageFormat("png");
        setFinished(true);
        setCached(false);
    } else {
        QGCFetchTileTask* task = getQGCMapEngine()->createFetchTileTask(getQGCMapEngine()->urlFactory()->getTypeFromId(spec.mapId()), spec.x(), spec.y(), spec.zoom());
        connect(task, &QGCFetchTileTask::tileFetched, this, &QGeoTiledMapReplyQGC::cacheReply);
        connect(task, &QGCMapTask::error, this, &QGeoTiledMapReplyQGC::cacheError);
        getQGCMapEngine()->addTask(task);
    }
}

//-----------------------------------------------------------------------------
QGeoTiledMapReplyQGC::~QGeoTiledMapReplyQGC()
{
    _clearReply();
}

//-----------------------------------------------------------------------------
void
QGeoTiledMapReplyQGC::_clearReply()
{
    _timer.stop();
    if (_reply) {
        _reply->deleteLater();
        _reply = nullptr;
        _requestCount--;
    }
}

//-----------------------------------------------------------------------------
void
QGeoTiledMapReplyQGC::abort()
{
    _aborted = true;
    _timer.stop();
    if (_reply)
        _reply->abort();
    emit aborted();
}

//-----------------------------------------------------------------------------
bool
QGeoTiledMapReplyQGC::_beginOverlayDownload(const QUrl& url)
{
    if (_aborted || isFinished()) {
        return false;
    }
    if (_reply) {
        QNetworkReply* done = _reply;
        _reply = nullptr;
        done->disconnect(this);
        done->deleteLater();
        if (_requestCount > 0) {
            _requestCount--;
        }
    }
    QNetworkRequest request(url);
    request.setRawHeader(QByteArrayLiteral("Accept"), QByteArrayLiteral("*/*"));
    request.setRawHeader(QByteArrayLiteral("Referrer"), QByteArrayLiteral("www.vworld.kr"));
    request.setRawHeader(QByteArrayLiteral("User-Agent"), QByteArray());
    _request = request;
    _awaitingOverlay = true;
    _beginTileDownload();
    return true;
}

//-----------------------------------------------------------------------------
void
QGeoTiledMapReplyQGC::_finishHybridOverlay(const QByteArray& overlayBytes)
{
    if (!_awaitingOverlay || isFinished()) {
        return;
    }
    _awaitingOverlay = false;
    QByteArray image = _baseTileImage;
    QString format = getQGCMapEngine()->urlFactory()->getImageFormat(tileSpec().mapId(), image);
    const QByteArray composed = composeMapOverlay(_baseTileImage, overlayBytes);
    if (!composed.isEmpty()) {
        image = composed;
        format = QStringLiteral("png");
    } else {
        const QString rejection = vworldTileRejection(_request.url(), overlayBytes);
        if (!rejection.isEmpty()) {
            logVworldTileRejectionOnce(rejection);
        } else if (!overlayBytes.isEmpty()) {
            logVworldTileRejectionOnce(QStringLiteral("VWorld: hybrid overlay unavailable"));
        }
    }
    _baseTileImage.clear();
    setMapImageData(image);
    if (!format.isEmpty()) {
        setMapImageFormat(format);
        getQGCMapEngine()->cacheTile(getQGCMapEngine()->urlFactory()->getTypeFromId(tileSpec().mapId()),
                                      tileSpec().x(), tileSpec().y(), tileSpec().zoom(), image, format);
    }
    setFinished(true);
}

//-----------------------------------------------------------------------------
void
QGeoTiledMapReplyQGC::networkReplyFinished()
{
    QNetworkReply* reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply || reply != _reply) {
        return;
    }
    _timer.stop();
    if (reply->error() != QNetworkReply::NoError) {
        return;
    }
    QByteArray a = reply->readAll();
    if (_awaitingOverlay) {
        _finishHybridOverlay(a);
        _clearReply();
        return;
    }
    UrlFactory* urlFactory = getQGCMapEngine()->urlFactory();
    QString format = urlFactory->getImageFormat(tileSpec().mapId(), a);
    //-- Test for a specialized, elevation data (not map tile)
    if( getQGCMapEngine()->urlFactory()->isElevation(tileSpec().mapId())){
        a = TerrainTile::serializeFromAirMapJson(a);
        //-- Cache it if valid
        if(!a.isEmpty()) {
            getQGCMapEngine()->cacheTile(
                getQGCMapEngine()->urlFactory()->getTypeFromId(
                    tileSpec().mapId()),
                tileSpec().x(), tileSpec().y(), tileSpec().zoom(), a, format);
        }
        emit terrainDone(a, QNetworkReply::NoError);
    } else {
        MapProvider* mapProvider = urlFactory->getMapProviderFromId(tileSpec().mapId());
        const QString vworldRejection = vworldTileRejection(reply->url(), a);
        if (mapProvider && mapProvider->_isBingProvider() && a.size() && _bingNoTileImage.size() && a == _bingNoTileImage) {
            // Bing doesn't return an error if you request a tile above supported zoom level
            // It instead returns an image of a missing tile graphic. We need to detect that
            // and error out so Qt will deal with zooming correctly even if it doesn't have the tile.
            // This allows us to zoom up to level 23 even though the tiles don't actually exist
            //setError(QGeoTiledMapReply::CommunicationError, "Bing tile above zoom level");
            CustomQmlInterface::instance()->showMessage(mapDownloadRequiredMessage(), SystemMessage::Error);
            setFinished(true);
        } else if (!vworldRejection.isEmpty()) {
            logVworldTileRejectionOnce(vworldRejection);
            setError(QGeoTiledMapReply::CommunicationError, vworldRejection);
            setFinished(true);
        } else if (!tileBytesAreImage(a) || (_bingNoTileImage.size() && a == _bingNoTileImage)) {
            // XML/error pages and the empty-tile graphic are not map imagery.
            // Finishing them as success leaves a permanent hole, so retry first.
            if (_retryTileDownload()) {
                return;
            }
            setError(QGeoTiledMapReply::CommunicationError, QStringLiteral("Invalid tile image"));
            setFinished(true);
        } else {
            // VWorld Hybrid keeps the satellite tile and draws the label tile on top.
            const QString overlayUrl = mapProvider ? mapProvider->overlayTileUrl(tileSpec().x(), tileSpec().y(), tileSpec().zoom()) : QString();
            if (!overlayUrl.isEmpty()) {
                _baseTileImage = a;
                if (_beginOverlayDownload(QUrl(overlayUrl))) {
                    return;
                }
            }
            //-- This is a map tile. Process and cache it if valid.
            setMapImageData(a);
            if(!format.isEmpty()) {
                setMapImageFormat(format);
                getQGCMapEngine()->cacheTile(getQGCMapEngine()->urlFactory()->getTypeFromId(tileSpec().mapId()), tileSpec().x(), tileSpec().y(), tileSpec().zoom(), a, format);
            }
            setFinished(true);
        }
    }
    _clearReply();
}

//-----------------------------------------------------------------------------
void
QGeoTiledMapReplyQGC::networkReplyError(QNetworkReply::NetworkError error)
{
    QNetworkReply* reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply || reply != _reply) {
        return;
    }
    _timer.stop();
    if (_awaitingOverlay) {
        if (_aborted || error == QNetworkReply::OperationCanceledError) {
            _awaitingOverlay = false;
            _baseTileImage.clear();
            setFinished(true);
        } else {
            _finishHybridOverlay(QByteArray());
        }
        _clearReply();
        return;
    }
    //-- Test for a specialized, elevation data (not map tile)
    if( getQGCMapEngine()->urlFactory()->isElevation(tileSpec().mapId())){
        emit terrainDone(QByteArray(), error);
    } else if (error == QNetworkReply::OperationCanceledError) {
        setFinished(true);
    } else if (_retryTileDownload()) {
        return;
    } else {
        qWarning() << "Fetch tile error:" << reply->errorString();
        setError(QGeoTiledMapReply::CommunicationError, reply->errorString());
        CustomQmlInterface::instance()->showMessage(mapDownloadRequiredMessage(), SystemMessage::Error);
        setFinished(true);
    }
    _clearReply();
}

//-----------------------------------------------------------------------------
void
QGeoTiledMapReplyQGC::cacheError(QGCMapTask::TaskType type, QString /*errorString*/)
{
    if(!getQGCMapEngine()->isInternetActive()) {
        if( getQGCMapEngine()->urlFactory()->isElevation(tileSpec().mapId())){
            emit terrainDone(QByteArray(), QNetworkReply::NetworkSessionFailedError);
        } else {
            setError(QGeoTiledMapReply::CommunicationError, "Network not available");
            CustomQmlInterface::instance()->showMessage(mapDownloadRequiredMessage(), SystemMessage::Error);
            setFinished(true);
        }
    } else {
        if(type != QGCMapTask::taskFetchTile) {
            qWarning() << "QGeoTiledMapReplyQGC::cacheError() for wrong task";
        }
        //-- Tile not in cache. Get it off the Internet.
        _beginTileDownload();
    }
}

//-----------------------------------------------------------------------------
void
QGeoTiledMapReplyQGC::_beginTileDownload()
{
#if !defined(__mobile__)
    QNetworkProxy proxy = _networkManager->proxy();
    QNetworkProxy tProxy;
    tProxy.setType(QNetworkProxy::DefaultProxy);
    _networkManager->setProxy(tProxy);
#endif
    _reply = _networkManager->get(_request);
    _reply->setParent(nullptr);

    setIgnoreSSLErrorsIfNeeded(*_reply);

    connect(_reply, &QNetworkReply::finished, this, &QGeoTiledMapReplyQGC::networkReplyFinished);
    connect(_reply, SIGNAL(error(QNetworkReply::NetworkError)), this, SLOT(networkReplyError(QNetworkReply::NetworkError)));
#if !defined(__mobile__)
    _networkManager->setProxy(proxy);
#endif
    // Queued tiles share a small per-host connection pool, so a request can
    // still be waiting when this timer fires. Retry those instead of dropping the tile.
    connect(&_timer, &QTimer::timeout, this, &QGeoTiledMapReplyQGC::timeout, Qt::UniqueConnection);
    _timer.setSingleShot(true);
    _timer.start(kTileDownloadTimeoutMs);
    _requestCount++;
}

//-----------------------------------------------------------------------------
void
QGeoTiledMapReplyQGC::cacheReply(QGCCacheTile* tile)
{
    //-- Test for a specialized, elevation data (not map tile)
    if( getQGCMapEngine()->urlFactory()->isElevation(tileSpec().mapId())){
        emit terrainDone(tile->img(), QNetworkReply::NoError);
    } else {
        //-- Regular map tile
        setMapImageData(tile->img());
        setMapImageFormat(tile->format());
        setFinished(true);
        setCached(true);
    }
    tile->deleteLater();
}

//-----------------------------------------------------------------------------
bool
QGeoTiledMapReplyQGC::_retryTileDownload()
{
    if (_aborted || isFinished() || _timeoutRetries >= kTileDownloadTimeoutRetries) {
        return false;
    }
    _timeoutRetries++;
    if (_reply) {
        QNetworkReply* stalled = _reply;
        _reply = nullptr;
        stalled->disconnect(this);
        // abort() inside QNetworkReply::error() emits that error a second time
        // ("this method must only be called once") and then later tile requests stop.
        if (!stalled->isFinished() && stalled->error() == QNetworkReply::NoError) {
            stalled->abort();
        }
        stalled->deleteLater();
        if (_requestCount > 0) {
            _requestCount--;
        }
    }
    QTimer::singleShot(0, this, [this]() {
        if (!_aborted && !isFinished() && !_reply) {
            _beginTileDownload();
        }
    });
    return true;
}

//-----------------------------------------------------------------------------
void
QGeoTiledMapReplyQGC::timeout()
{
    if (_awaitingOverlay) {
        if (_reply) {
            QNetworkReply* stalled = _reply;
            _reply = nullptr;
            stalled->disconnect(this);
            if (!stalled->isFinished() && stalled->error() == QNetworkReply::NoError) {
                stalled->abort();
            }
            stalled->deleteLater();
            if (_requestCount > 0) {
                _requestCount--;
            }
        }
        _finishHybridOverlay(QByteArray());
        return;
    }
    if (getQGCMapEngine()->urlFactory()->isElevation(tileSpec().mapId())) {
        if(_reply) {
            _reply->abort();
        }
        emit aborted();
        return;
    }
    if (_retryTileDownload()) {
        return;
    }
    if (_reply) {
        QNetworkReply* stalled = _reply;
        _reply = nullptr;
        stalled->disconnect(this);
        stalled->abort();
        stalled->deleteLater();
        if (_requestCount > 0) {
            _requestCount--;
        }
    }
    setError(QGeoTiledMapReply::CommunicationError, QStringLiteral("Tile request timed out"));
    setFinished(true);
}

//-----------------------------------------------------------------------------
void QGeoTiledMapReplyQGC::setIgnoreSSLErrorsIfNeeded(QNetworkReply& networkReply)
{
    // Some systems (like Ubuntu 22.04) only ship with OpenSSL 3.x, however Qt 5.15.2 links against OpenSSL 1.x.
    // This results in unresolved symbols for EVP_PKEY_base_id and SSL_get_peer_certificate.
    // To still get a connection we have to ignore certificate verification (connection is still encrypted but open to MITM attacks)
    // See https://bugreports.qt.io/browse/QTBUG-115146
    const bool sslLibraryBuildIs1x = (QSslSocket::sslLibraryBuildVersionNumber() & 0xf0000000) == 0x10000000;
    const bool sslLibraryIs3x = (QSslSocket::sslLibraryVersionNumber() & 0xf0000000) == 0x30000000;
    if (sslLibraryBuildIs1x && sslLibraryIs3x) {
        //qWarning() << "Ignoring ssl certificates due to OpenSSL version mismatch";
        QList<QSslError> errorsThatCanBeIgnored;
        errorsThatCanBeIgnored << QSslError(QSslError::NoPeerCertificate);
        networkReply.ignoreSslErrors(errorsThatCanBeIgnored);
    }
}
