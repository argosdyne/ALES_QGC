/*!
 * @file
 *   @brief Camera Controller
 *   @author Gus Grubba <gus@auterion.com>
 *
 */

#include "QGCApplication.h"
#include "QGCCameraManager.h"
#include "JoystickManager.h"
#include "CodevCameraControl.h"
#include "SettingsManager.h"
#include "VideoSettings.h"

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPointer>
#include <QRegularExpression>
#include <QTcpServer>
#include <QTcpSocket>
#include <QUrl>

QGC_LOGGING_CATEGORY(CameraManagerLog, "CameraManagerLog")

namespace {

static constexpr quint16 kCameraDefinitionLocalPort = 38081;
static const char* kCameraDefinitionPathFormat = "/camera/%1/caminfo.xml";
static constexpr uint8_t kCodevFallbackDefinitionVersion = 23;

static bool _populateCodevFallbackCameraInfo(int compID, const QByteArray& definitionUri, mavlink_camera_information_t& info)
{
    if (compID != MAV_COMP_ID_CAMERA) {
        return false;
    }

    const QByteArray vendor = QByteArrayLiteral("Codev");
    const QByteArray modelName = QByteArrayLiteral("R3");

    memset(&info, 0, sizeof(info));
    memcpy(info.vendor_name, vendor.constData(), qMin(static_cast<int>(sizeof(info.vendor_name)) - 1, vendor.size()));
    memcpy(info.model_name, modelName.constData(), qMin(static_cast<int>(sizeof(info.model_name)) - 1, modelName.size()));
    memcpy(info.cam_definition_uri, definitionUri.constData(), qMin(static_cast<int>(sizeof(info.cam_definition_uri)) - 1, definitionUri.size()));
    // Match FlyDynamics3 behavior: fallback only supplies a definition profile.
    // Firmware version must come from a real CAMERA_INFORMATION payload, not be synthesized from the XML/profile revision.
    info.firmware_version = 0;
    info.cam_definition_version = kCodevFallbackDefinitionVersion;
    info.flags = 0x75f; // Matches the real Codev CAMERA_INFORMATION seen in FlyDynamics3 logs.

    return true;
}

static bool _packSynthesizedCameraInformationMessage(Vehicle* vehicle, int compID, const QByteArray& definitionUri, mavlink_message_t& message)
{
    mavlink_camera_information_t info{};
    if (!_populateCodevFallbackCameraInfo(compID, definitionUri, info)) {
        return false;
    }

    mavlink_msg_camera_information_encode(vehicle->id(), static_cast<uint8_t>(compID), &message, &info);
    return true;
}

} // namespace

//-----------------------------------------------------------------------------
QGCCameraManager::CameraStruct::CameraStruct(QObject* parent, uint8_t compID_)
    : QObject(parent)
    , compID(compID_)
{
}

//-----------------------------------------------------------------------------
QGCCameraManager::QGCCameraManager(Vehicle *vehicle)
    : _vehicle(vehicle)
{
    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
    qCDebug(CameraManagerLog) << "QGCCameraManager Created";
    qInfo() << "[CameraManager]" << "BUILD_TAG ales-fallback-v5-no-hardcoded-definition-url 2026-04-15";
    connect(qgcApp()->toolbox()->multiVehicleManager(), &MultiVehicleManager::parameterReadyVehicleAvailableChanged, this, &QGCCameraManager::_vehicleReady);
    connect(_vehicle, &Vehicle::mavlinkMessageReceived, this, &QGCCameraManager::_mavlinkMessageReceived);
    connect(&_cameraTimer, &QTimer::timeout, this, &QGCCameraManager::_cameraTimeout);
    _cameraTimer.setSingleShot(false);
    _lastZoomChange.start();
    _lastCameraChange.start();
    _cameraTimer.start(500);
}

//-----------------------------------------------------------------------------
QGCCameraManager::~QGCCameraManager()
{
}

bool
QGCCameraManager::_ensureCameraDefinitionHttpServer()
{
    if (_cameraDefinitionHttpServer) {
        return _cameraDefinitionHttpServer->isListening();
    }

    _cameraDefinitionHttpServer = new QTcpServer(this);
    if (!_cameraDefinitionHttpServer->listen(QHostAddress::LocalHost, kCameraDefinitionLocalPort)) {
        qWarning() << "[CameraManager]"
                   << "camera definition local server failed on port" << kCameraDefinitionLocalPort
                   << "error" << _cameraDefinitionHttpServer->errorString()
                   << "retrying with ephemeral port";
        if (!_cameraDefinitionHttpServer->listen(QHostAddress::LocalHost, 0)) {
            qWarning() << "[CameraManager]"
                       << "camera definition local server failed"
                       << _cameraDefinitionHttpServer->errorString();
            _cameraDefinitionHttpServer->deleteLater();
            _cameraDefinitionHttpServer = nullptr;
            return false;
        }
    }

    _cameraDefinitionHttpServer->setMaxPendingConnections(2);
    _cameraDefinitionHttpPort = _cameraDefinitionHttpServer->serverPort();
    connect(_cameraDefinitionHttpServer, &QTcpServer::newConnection, this, &QGCCameraManager::_newCameraDefinitionHttpConnection);
    qInfo() << "[CameraManager]"
            << "camera definition local server listening"
            << "port" << _cameraDefinitionHttpPort;
    return true;
}

QString
QGCCameraManager::_cameraDefinitionLocalUrl(int compID) const
{
    if (_cameraDefinitionHttpPort == 0) {
        qWarning() << "[CameraManager]"
                   << "camera definition local url unavailable"
                   << "compId" << compID
                   << "reason" << "local_http_server_not_listening";
        return QString();
    }

    return QStringLiteral("http://127.0.0.1:%1%2")
        .arg(_cameraDefinitionHttpPort)
        .arg(QString::fromLatin1(kCameraDefinitionPathFormat).arg(compID));
}

QString
QGCCameraManager::_cameraDefinitionUpstreamUrl(int compID) const
{
    if (compID != MAV_COMP_ID_CAMERA) {
        return QString();
    }

    const QString rtspUrl = qgcApp()->toolbox()->settingsManager()->videoSettings()->rtspUrl()->rawValue().toString();
    const QUrl videoUrl(rtspUrl);
    if (!videoUrl.host().isEmpty()) {
        QString path = videoUrl.path();
        QString lastSegment = path.section('/', -1);

        qInfo() << "[CameraManager] Path =" << path
                << "LastSegment =" << lastSegment
                << "RTSPURL =" << rtspUrl;

        if (lastSegment.compare("eo", Qt::CaseInsensitive) == 0) {
            return QStringLiteral("http://%1/Codev_R3_023.xml").arg(videoUrl.host());   // EO → R3
        }
        else if (lastSegment.compare("cr", Qt::CaseInsensitive) == 0) {
            return QStringLiteral("http://%1/Codev_RLR1_013.xml").arg(videoUrl.host()); // CR → LR1
        }
        else {
            return QStringLiteral("http://%1/Codev_RLR1_013.xml").arg(videoUrl.host());
        }
    }

    qWarning() << "[CameraManager]"
               << "camera definition upstream unavailable"
               << "compId" << compID
               << "reason" << "rtsp_host_missing"
               << "rtspUrl" << rtspUrl;
    return QString();
}

void
QGCCameraManager::_replyCameraDefinitionHttp(QTcpSocket* socket, int statusCode, const QByteArray& body, const QByteArray& contentType) const
{
    if (!socket) {
        return;
    }

    QByteArray statusText = "OK";
    if (statusCode == 404) {
        statusText = "Not Found";
    } else if (statusCode >= 500) {
        statusText = "Bad Gateway";
    }

    QByteArray header;
    header += "HTTP/1.1 " + QByteArray::number(statusCode) + ' ' + statusText + "\r\n";
    header += "Server: ALESCameraDefinitionProxy\r\n";
    header += "Content-Type: " + contentType + "\r\n";
    header += "Connection: close\r\n";
    header += "Content-Length: " + QByteArray::number(body.size()) + "\r\n\r\n";

    socket->write(header);
    if (!body.isEmpty()) {
        socket->write(body);
    }
    socket->disconnectFromHost();
}

void
QGCCameraManager::_newCameraDefinitionHttpConnection()
{
    while (_cameraDefinitionHttpServer && _cameraDefinitionHttpServer->hasPendingConnections()) {
        QTcpSocket* socket = _cameraDefinitionHttpServer->nextPendingConnection();
        connect(socket, &QTcpSocket::readyRead, this, &QGCCameraManager::_handleCameraDefinitionHttpRequest);
    }
}

void
QGCCameraManager::_handleCameraDefinitionHttpRequest()
{
    QTcpSocket* socket = qobject_cast<QTcpSocket*>(sender());
    if (!socket) {
        return;
    }

    const QByteArray requestData = socket->readAll();
    const QList<QByteArray> requestLines = requestData.split('\n');
    if (requestLines.isEmpty()) {
        _replyCameraDefinitionHttp(socket, 400, QByteArrayLiteral("empty request"), QByteArrayLiteral("text/plain"));
        return;
    }

    const QRegularExpression requestRegex(QStringLiteral("^GET\\s+(/camera/(\\d+)/caminfo\\.xml)\\s+HTTP/"));
    const QString requestLine = QString::fromLatin1(requestLines.first()).trimmed();
    const QRegularExpressionMatch match = requestRegex.match(requestLine);
    if (!match.hasMatch()) {
        qWarning() << "[CameraManager]"
                   << "camera definition local server unsupported request"
                   << requestLine;
        _replyCameraDefinitionHttp(socket, 404, QByteArrayLiteral("not found"), QByteArrayLiteral("text/plain"));
        return;
    }

    const int compID = match.captured(2).toInt();
    const QString upstreamUrl = _cameraDefinitionUpstreamUrl(compID);
    if (upstreamUrl.isEmpty()) {
        _replyCameraDefinitionHttp(socket, 404, QByteArrayLiteral("no upstream"), QByteArrayLiteral("text/plain"));
        return;
    }

    if (!_cameraDefinitionNetworkManager) {
        _cameraDefinitionNetworkManager = new QNetworkAccessManager(this);
    }

    qInfo() << "[CameraManager]"
            << "camera definition local server proxy request"
            << "compId" << compID
            << "upstreamUrl" << upstreamUrl;

    QNetworkRequest request{QUrl(upstreamUrl)};
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, true);
    QNetworkReply* reply = _cameraDefinitionNetworkManager->get(request);
    QPointer<QTcpSocket> guardedSocket(socket);
    connect(reply, &QNetworkReply::finished, this, [this, guardedSocket, reply, compID, upstreamUrl]() {
        const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QByteArray body;
        int responseStatus = 502;

        if (reply->error() == QNetworkReply::NoError && statusCode == 200) {
            body = reply->readAll();
            responseStatus = 200;
            qInfo() << "[CameraManager]"
                    << "camera definition local server proxy response"
                    << "compId" << compID
                    << "upstreamUrl" << upstreamUrl
                    << "bytes" << body.size();
        } else {
            qWarning() << "[CameraManager]"
                       << "camera definition local server upstream error"
                       << "compId" << compID
                       << "upstreamUrl" << upstreamUrl
                       << "status" << statusCode
                       << "error" << reply->errorString();
        }

        if (guardedSocket) {
            _replyCameraDefinitionHttp(guardedSocket, responseStatus, body, QByteArrayLiteral("application/xml; charset=utf-8"));
        }
        reply->deleteLater();
    });
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::setCurrentCamera(int sel)
{
    if(sel != _currentCamera && sel >= 0 && sel < _cameras.count()) {
        _currentCamera = sel;
        emit currentCameraChanged();
        emit streamChanged();
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_vehicleReady(bool ready)
{
    qCDebug(CameraManagerLog) << "_vehicleReady(" << ready << ")";
    if(ready) {
        if(qgcApp()->toolbox()->multiVehicleManager()->activeVehicle() == _vehicle) {
            _vehicleReadyState = true;
            JoystickManager *pJoyMgr = qgcApp()->toolbox()->joystickManager();
            _activeJoystickChanged(pJoyMgr->activeJoystick());
            connect(pJoyMgr, &JoystickManager::activeJoystickChanged, this, &QGCCameraManager::_activeJoystickChanged);
        }
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_mavlinkMessageReceived(const mavlink_message_t& message, LinkInterface* link)
{
    const bool sysMatch = message.sysid == _vehicle->id();
    const bool compMatch = (message.compid >= MAV_COMP_ID_CAMERA && message.compid <= MAV_COMP_ID_CAMERA6);

    if (message.msgid == MAVLINK_MSG_ID_HEARTBEAT ||
        message.msgid == MAVLINK_MSG_ID_CAMERA_INFORMATION ||
        message.msgid == MAVLINK_MSG_ID_CAMERA_SETTINGS ||
        message.msgid == MAVLINK_MSG_ID_PARAM_EXT_VALUE ||
        message.msgid == MAVLINK_MSG_ID_PARAM_EXT_ACK ||
        message.msgid == MAVLINK_MSG_ID_COMMAND_ACK) {
        qInfo() << "[CameraManager]"
                << "_mavlinkMessageReceived"
                << "sysid" << message.sysid
                << "vehicleId" << _vehicle->id()
                << "compid" << message.compid
                << "msgid" << message.msgid
                << "sysMatch" << sysMatch
                << "compMatch" << compMatch;
    }

    //-- Only pay attention to camera components, as identified by their compId
    if(sysMatch && compMatch) {
        switch (message.msgid) {
        case MAVLINK_MSG_ID_CAMERA_CAPTURE_STATUS:
            _handleCaptureStatus(message);
            break;
        case MAVLINK_MSG_ID_STORAGE_INFORMATION:
            _handleStorageInfo(message);
            break;
        case MAVLINK_MSG_ID_HEARTBEAT:
            _handleHeartbeat(message, link);
            break;
        case MAVLINK_MSG_ID_CAMERA_INFORMATION:
            _handleCameraInfo(message, link);
            break;
        case MAVLINK_MSG_ID_CAMERA_SETTINGS:
            _handleCameraSettings(message, link);
            break;
        case MAVLINK_MSG_ID_PARAM_EXT_ACK:
            _handleParamAck(message);
            break;
        case MAVLINK_MSG_ID_PARAM_EXT_VALUE:
            _handleParamValue(message);
            break;
        case MAVLINK_MSG_ID_VIDEO_STREAM_INFORMATION:
            _handleVideoStreamInfo(message);
            break;
        case MAVLINK_MSG_ID_VIDEO_STREAM_STATUS:
            _handleVideoStreamStatus(message);
            break;
        case MAVLINK_MSG_ID_CAMERA_TRACKING_GEO_STATUS:
            _handleTrackingGeoStatus(message);
            break;
        case MAVLINK_MSG_ID_COMMAND_ACK:
            _handleCommandAck(message);
            break;
        case MAVLINK_MSG_ID_RC_CHANNELS:
            _handleRCChannels(message);
            break;
        case MAVLINK_MSG_ID_CAMERA_IMAGE_CAPTURED:
            _handleImageCaptured(message);
            break;
        case MAVLINK_MSG_ID_BATTERY_STATUS:
            _handleBatteryStatus(message);
            break;
        case MAVLINK_MSG_ID_CAMERA_TRACKING_IMAGE_STATUS:
            _handleTrackingImageStatus(message);
            break;
        }
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleHeartbeat(const mavlink_message_t &message, LinkInterface* link)
{
    qInfo() << "[CameraManager]"
            << "_handleHeartbeat"
            << "sysid" << message.sysid
            << "compid" << message.compid;
    //-- First time hearing from this one?
    QString sCompID = QString::number(message.compid);
    if(!_cameraInfoRequest.contains(sCompID)) {
        qInfo() << "[CameraManager]" << "First heartbeat from compid" << message.compid;
        CameraStruct* pInfo = new CameraStruct(this, message.compid);
        pInfo->lastHeartbeat.start();
        _cameraInfoRequest[sCompID] = pInfo;
        //-- Request camera info
        _requestCameraInfo(message.compid, pInfo->tryCount, link);
    } else {
        if(_cameraInfoRequest[sCompID]) {
            CameraStruct* pInfo = _cameraInfoRequest[sCompID];
            //-- Check if we have indeed received the camera info
            if(pInfo->infoReceived || pInfo->cameraCreated) {
                //-- We have it. Just update the heartbeat timeout
                pInfo->lastHeartbeat.start();
            } else {
                //-- Try again. Maybe.
                if(pInfo->lastHeartbeat.elapsed() > 2000) {
                    if(pInfo->tryCount > 10) {
                        if(!pInfo->gaveUp) {
                            pInfo->gaveUp = true;
                            qInfo() << "[CameraManager]"
                                    << "Giving up requesting camera info from vehicle"
                                    << _vehicle->id()
                                    << "compid" << message.compid;
                        }
                    } else {
                        pInfo->tryCount++;
                        qInfo() << "[CameraManager]"
                                << "Retry request camera info"
                                << "compid" << message.compid
                                << "try" << pInfo->tryCount;
                        //-- Request camera info again.
                        _requestCameraInfo(message.compid, pInfo->tryCount, link);
                    }
                }
            }
        } else {
            qWarning() << "_cameraInfoRequest[" << sCompID << "] is null";
        }
    }
}

//-----------------------------------------------------------------------------
bool
QGCCameraManager::_injectSynthesizedCameraInformation(int compID, LinkInterface* link, const char* reason)
{
    const QString sCompID = QString::number(compID);
    if (!_cameraInfoRequest.contains(sCompID) || !_cameraInfoRequest[sCompID]) {
        qWarning() << "[CameraManager]"
                   << "_injectSynthesizedCameraInformation skipped no request"
                   << "compId" << compID
                   << "reason" << reason;
        return false;
    }

    if (_cameraInfoRequest[sCompID]->infoReceived || _findCamera(compID)) {
        qInfo() << "[CameraManager]"
                << "_injectSynthesizedCameraInformation skipped existing camera/info"
                << "compId" << compID
                << "reason" << reason;
        return false;
    }

    mavlink_message_t synthesizedMessage{};
    if (!_ensureCameraDefinitionHttpServer()) {
        qWarning() << "[CameraManager]"
                   << "_injectSynthesizedCameraInformation failed"
                   << "compId" << compID
                   << "reason" << reason
                   << "error" << "local_http_server_unavailable";
        return false;
    }

    const QString definitionUrl = _cameraDefinitionLocalUrl(compID);
    if (definitionUrl.isEmpty()) {
        qWarning() << "[CameraManager]"
                   << "_injectSynthesizedCameraInformation failed"
                   << "compId" << compID
                   << "reason" << reason
                   << "error" << "definition_url_empty";
        return false;
    }

    if (!_packSynthesizedCameraInformationMessage(_vehicle, compID, definitionUrl.toLatin1(), synthesizedMessage)) {
        qInfo() << "[CameraManager]"
                << "_injectSynthesizedCameraInformation no synth profile"
                << "compId" << compID
                << "reason" << reason;
        return false;
    }

    qInfo() << "[CameraManager]"
            << "_injectSynthesizedCameraInformation"
            << "compId" << compID
            << "reason" << reason
            << "definitionUrl" << definitionUrl
            << "msgid" << synthesizedMessage.msgid
            << "link" << link;

    _mavlinkMessageReceived(synthesizedMessage, link);
    return true;
}

//-----------------------------------------------------------------------------
QGCCameraControl*
QGCCameraManager::currentCameraInstance()
{
    qInfo() << "[CameraManager]"
            << "currentCameraInstance currentCamera" << _currentCamera
            << "cameraCount" << _cameras.count();
    if(_currentCamera < _cameras.count() && _cameras.count()) {
        QGCCameraControl* pCamera = qobject_cast<QGCCameraControl*>(_cameras[_currentCamera]);
        qInfo() << "[CameraManager]"
                << "currentCameraInstance result"
                << (pCamera ? pCamera->modelName() : QStringLiteral("null"))
                << "paramComplete" << (pCamera ? pCamera->paramComplete() : false);
        return pCamera;
    }
    qInfo() << "[CameraManager]" << "currentCameraInstance returning null";
    return nullptr;
}

//-----------------------------------------------------------------------------
QGCVideoStreamInfo*
QGCCameraManager::currentStreamInstance()
{
    QGCCameraControl* pCamera = currentCameraInstance();
    if(pCamera) {
        QGCVideoStreamInfo* pInfo = pCamera->currentStreamInstance();
        return pInfo;
    }
    return nullptr;
}

//-----------------------------------------------------------------------------
QGCVideoStreamInfo*
QGCCameraManager::thermalStreamInstance()
{
    QGCCameraControl* pCamera = currentCameraInstance();
    if(pCamera) {
        QGCVideoStreamInfo* pInfo = pCamera->thermalStreamInstance();
        return pInfo;
    }
    return nullptr;
}

//-----------------------------------------------------------------------------
QGCCameraControl*
QGCCameraManager::_findCamera(int id)
{
    for(int i = 0; i < _cameras.count(); i++) {
        if(_cameras[i]) {
            QGCCameraControl* pCamera = qobject_cast<QGCCameraControl*>(_cameras[i]);
            if(pCamera) {
                if(pCamera->compID() == id) {
                    return pCamera;
                }
            } else {
                qCritical() << "Null QGCCameraControl instance";
            }
        }
    }
    //qWarning() << "Camera component id not found:" << id;
    return nullptr;
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_addCameraControlToLists(QGCCameraControl* cameraControl)
{
    qInfo() << "[CameraManager]"
            << "_addCameraControlToLists camera"
            << cameraControl->modelName()
            << "compId" << cameraControl->compID()
            << "initial active settings" << cameraControl->activeSettings();
    QQmlEngine::setObjectOwnership(cameraControl, QQmlEngine::CppOwnership);
    _cameras.append(cameraControl);
    _cameraLabels << cameraControl->modelName();
    emit camerasChanged();
    emit cameraLabelsChanged();
    emit currentCameraChanged();
    emit streamChanged();
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_removeCameraControlFromLists(QGCCameraControl* cameraControl)
{
    if (!cameraControl) {
        return;
    }

    qInfo() << "[CameraManager]"
            << "_removeCameraControlFromLists camera"
            << cameraControl->modelName()
            << "compId" << cameraControl->compID();

    int idx = _cameraLabels.indexOf(cameraControl->modelName());
    if (idx >= 0) {
        _cameraLabels.removeAt(idx);
    }
    idx = _cameras.indexOf(cameraControl);
    if (idx >= 0) {
        _cameras.removeAt(idx);
    }

    emit cameraLabelsChanged();
    emit camerasChanged();

    if (_currentCamera >= _cameras.count()) {
        _currentCamera = qMax(0, _cameras.count() - 1);
    }
    emit currentCameraChanged();
    emit streamChanged();
}

//-----------------------------------------------------------------------------
QGCCameraControl*
QGCCameraManager::_createCameraControlFromSettingsFallback(int compID, LinkInterface* link)
{
    mavlink_camera_information_t info{};
    const QString definitionUrl = _cameraDefinitionLocalUrl(compID);
    const bool useCodevProfile = !definitionUrl.isEmpty() &&
                                 _populateCodevFallbackCameraInfo(compID, definitionUrl.toLatin1(), info);
    if (!useCodevProfile) {
        const QByteArray vendor = QByteArrayLiteral("Unknown");
        const QByteArray modelName = QStringLiteral("Camera %1").arg(compID).toLatin1();

        memcpy(info.vendor_name, vendor.constData(), qMin(static_cast<int>(sizeof(info.vendor_name)) - 1, vendor.size()));
        memcpy(info.model_name, modelName.constData(), qMin(static_cast<int>(sizeof(info.model_name)) - 1, modelName.size()));
        info.flags = CAMERA_CAP_FLAGS_CAPTURE_IMAGE |
                     CAMERA_CAP_FLAGS_CAPTURE_VIDEO |
                     CAMERA_CAP_FLAGS_HAS_MODES |
                     CAMERA_CAP_FLAGS_HAS_BASIC_ZOOM |
                     CAMERA_CAP_FLAGS_HAS_BASIC_FOCUS |
                     CAMERA_CAP_FLAGS_HAS_VIDEO_STREAM;
    }

    qInfo() << "[CameraManager]"
            << "_createCameraControlFromSettingsFallback request"
            << "compId" << compID
            << "profile" << (useCodevProfile ? "codev-r3" : "generic")
            << "vendor" << reinterpret_cast<const char*>(info.vendor_name)
            << "model" << reinterpret_cast<const char*>(info.model_name)
            << "flags" << Qt::hex << info.flags << Qt::dec
            << "definitionUri" << reinterpret_cast<const char*>(info.cam_definition_uri)
            << "link" << link;

    QGCCameraControl* pCamera = nullptr;
    if (useCodevProfile) {
        pCamera = new CodevCameraControl(&info, _vehicle, compID, link, this);
    } else {
        pCamera = _vehicle->firmwarePlugin()->createCameraControl(&info, _vehicle, compID, link, this);
    }
    if (pCamera) {
        qInfo() << "[CameraManager]"
                << "_createCameraControlFromSettingsFallback created camera"
                << pCamera->modelName()
                << "compId" << pCamera->compID();
        _addCameraControlToLists(pCamera);
    } else {
        qWarning() << "[CameraManager]"
                   << "_createCameraControlFromSettingsFallback failed"
                   << "compId" << compID
                   << "link" << link;
    }

    return pCamera;
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleCameraInfo(const mavlink_message_t& message, LinkInterface* link)
{
    qInfo() << "[CameraManager]" << "_handleCameraInfo compId" << message.compid;
    //-- Have we requested it?
    QString sCompID = QString::number(message.compid);
    if(_cameraInfoRequest.contains(sCompID) && !_cameraInfoRequest[sCompID]->infoReceived) {
        mavlink_camera_information_t info;
        mavlink_msg_camera_information_decode(&message, &info);
        qInfo() << "[CameraManager]"
                << "_handleCameraInfo decoded"
                << reinterpret_cast<const char*>(info.model_name)
                << reinterpret_cast<const char*>(info.vendor_name)
                << "compId" << message.compid
                << "flags" << Qt::hex << info.flags << Qt::dec
                << "camDefVersion" << info.cam_definition_version
                << "camDefUri" << reinterpret_cast<const char*>(info.cam_definition_uri)
                << "firmwareVersion" << info.firmware_version
                << "link" << link;
        QGCCameraControl* pCamera = nullptr;
        if (QGCCameraControl* existingCamera = _findCamera(message.compid)) {
            if (_cameraInfoRequest[sCompID]->fallbackCreated) {
                qCInfo(CameraManagerLog) << "[CameraFlow]"
                        << "replacing fallback camera with real CAMERA_INFORMATION"
                        << "compId" << message.compid
                        << "model" << existingCamera->modelName();
                _removeCameraControlFromLists(existingCamera);
                existingCamera->deleteLater();
            } else {
                _cameraInfoRequest[sCompID]->infoReceived = true;
                qInfo() << "[CameraManager]"
                        << "_handleCameraInfo camera already exists"
                        << existingCamera->modelName()
                        << "compId" << message.compid;
                return;
            }
        }
        QString vendor = QString(reinterpret_cast<const char*>(info.vendor_name));
        if (vendor.toUpper().compare("CODEV") == 0) {
            qCInfo(CameraManagerLog) << "[CameraFlow]"
                    << "creating CodevCameraControl from CAMERA_INFORMATION"
                    << "compId" << message.compid;
            pCamera = new CodevCameraControl(&info, _vehicle, message.compid, link, this);
        } else {
            qCInfo(CameraManagerLog) << "[CameraFlow]"
                    << "creating firmware camera control from CAMERA_INFORMATION"
                    << "compId" << message.compid
                    << "vendor" << vendor;
            pCamera = _vehicle->firmwarePlugin()->createCameraControl(&info, _vehicle, message.compid, link, this);
        }
        if(pCamera) {
            _cameraInfoRequest[sCompID]->infoReceived = true;
            _cameraInfoRequest[sCompID]->cameraCreated = true;
            _cameraInfoRequest[sCompID]->fallbackCreated = false;
            qCInfo(CameraManagerLog) << "[CameraFlow]"
                    << "camera control created"
                    << "compId" << message.compid
                    << "camera" << pCamera->modelName()
                    << "paramComplete" << pCamera->paramComplete();
            _addCameraControlToLists(pCamera);
        } else {
            qWarning() << "[CameraManager]"
                       << "_handleCameraInfo createCameraControl returned null"
                       << "compId" << message.compid
                       << "vendor" << reinterpret_cast<const char*>(info.vendor_name)
                       << "model" << reinterpret_cast<const char*>(info.model_name)
                       << "link" << link;
        }
    } else {
        qInfo() << "[CameraManager]"
                << "_handleCameraInfo ignored"
                << "compId" << message.compid
                << "hasRequest" << _cameraInfoRequest.contains(sCompID)
                << "infoAlreadyReceived" << (_cameraInfoRequest.contains(sCompID) && _cameraInfoRequest[sCompID] ? _cameraInfoRequest[sCompID]->infoReceived : false);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_cameraTimeout()
{
    //-- Iterate cameras
    foreach(QString sCompID, _cameraInfoRequest.keys()) {
        if(_cameraInfoRequest[sCompID]) {
            CameraStruct* pInfo = _cameraInfoRequest[sCompID];
            //-- Have we received a camera info message?
            if(pInfo->infoReceived || pInfo->cameraCreated) {
                //-- Has the camera stopped talking to us?
                if(pInfo->lastHeartbeat.elapsed() > 5000) {
                    //-- Camera is gone. Remove it.
                    bool autoStream = false;
                    QGCCameraControl* pCamera = _findCamera(pInfo->compID);
                    if(pCamera) {
                        qWarning() << "Camera" << pCamera->modelName() << "stopped transmitting. Removing from list.";
                        autoStream = pCamera->autoStream();
                        _removeCameraControlFromLists(pCamera);
                        pCamera->deleteLater();
                        delete pInfo;
                    }
                    _cameraInfoRequest.remove(sCompID);
                    //-- If we have another camera, switch current camera.
                    if(_cameras.count()) {
                        setCurrentCamera(0);
                    } else {
                        //-- We're out of cameras
                        emit camerasChanged();
                        if(autoStream) {
                            emit streamChanged();
                        }
                    }
                    //-- Exit loop.
                    return;
                }
            }
        }
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleCaptureStatus(const mavlink_message_t &message)
{
    QGCCameraControl* pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_camera_capture_status_t cap;
        mavlink_msg_camera_capture_status_decode(&message, &cap);
        pCamera->handleCaptureStatus(cap);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleStorageInfo(const mavlink_message_t& message)
{
    QGCCameraControl* pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_storage_information_t st;
        mavlink_msg_storage_information_decode(&message, &st);
        pCamera->handleStorageInfo(st);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleCameraSettings(const mavlink_message_t& message, LinkInterface* link)
{
    qInfo() << "[CameraManager]" << "BUILD_TAG _handleCameraSettings ales-fallback-v2-codev-profile";
    QGCCameraControl* pCamera = _findCamera(message.compid);
    const QString sCompID = QString::number(message.compid);
    qCInfo(CameraManagerLog) << "[CameraFlow]"
            << "_handleCameraSettings entry"
            << "compId" << message.compid
            << "hasCamera" << (pCamera != nullptr)
            << "hasRequest" << _cameraInfoRequest.contains(sCompID)
            << "link" << link;
    if (!pCamera && _cameraInfoRequest.contains(sCompID)) {
        qCInfo(CameraManagerLog) << "[CameraFlow]"
                << "_handleCameraSettings creating fallback camera"
                << "compId" << message.compid;
        pCamera = _createCameraControlFromSettingsFallback(message.compid, link);
        if (pCamera) {
            CameraStruct* pInfo = _cameraInfoRequest[sCompID];
            pInfo->cameraCreated = true;
            pInfo->fallbackCreated = true;
            pInfo->lastHeartbeat.start();
            qCInfo(CameraManagerLog) << "[CameraFlow]"
                    << "_handleCameraSettings fallback camera registered"
                    << "compId" << message.compid
                    << "camera" << pCamera->modelName()
                    << "cameraCreated" << pInfo->cameraCreated
                    << "fallbackCreated" << pInfo->fallbackCreated;
        }
    }
    if(pCamera) {
        mavlink_camera_settings_t settings;
        mavlink_msg_camera_settings_decode(&message, &settings);
        qCInfo(CameraManagerLog) << "[CameraFlow]"
                << "_handleCameraSettings compId" << message.compid
                << "camera" << pCamera->modelName()
                << "mode" << settings.mode_id
                << "zoom" << settings.zoomLevel
                << "focus" << settings.focusLevel
                << "paramComplete" << pCamera->paramComplete()
                << "active settings before handle" << pCamera->activeSettings();
        pCamera->handleSettings(settings);
        qCInfo(CameraManagerLog) << "[CameraFlow]"
                << "_handleCameraSettings compId" << message.compid
                << "camera" << pCamera->modelName()
                << "paramComplete" << pCamera->paramComplete()
                << "active settings after handle" << pCamera->activeSettings();
    } else {
        qWarning() << "[CameraManager]"
                   << "_handleCameraSettings no camera to handle settings"
                   << "compId" << message.compid
                   << "hasRequest" << _cameraInfoRequest.contains(sCompID)
                   << "cameraCount" << _cameras.count();
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleParamAck(const mavlink_message_t& message)
{
    QGCCameraControl* pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_param_ext_ack_t ack;
        mavlink_msg_param_ext_ack_decode(&message, &ack);
        pCamera->handleParamAck(ack);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleParamValue(const mavlink_message_t& message)
{
    QGCCameraControl* pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_param_ext_value_t value;
        mavlink_msg_param_ext_value_decode(&message, &value);
        pCamera->handleParamValue(value);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleVideoStreamInfo(const mavlink_message_t& message)
{
    QGCCameraControl* pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_video_stream_information_t streamInfo;
        mavlink_msg_video_stream_information_decode(&message, &streamInfo);
        pCamera->handleVideoInfo(&streamInfo);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleVideoStreamStatus(const mavlink_message_t& message)
{
    QGCCameraControl* pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_video_stream_status_t streamStatus;
        mavlink_msg_video_stream_status_decode(&message, &streamStatus);
        pCamera->handleVideoStatus(&streamStatus);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleTrackingGeoStatus(const mavlink_message_t& message)
{
    QGCCameraControl* pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_camera_tracking_geo_status_t trackingGeoStatus;
        mavlink_msg_camera_tracking_geo_status_decode(&message, &trackingGeoStatus);
        pCamera->handleTrackingGeoStatus(trackingGeoStatus);
    }
}

void
QGCCameraManager::_handleCommandAck(const mavlink_message_t& message)
{
    mavlink_command_ack_t ack;
    mavlink_msg_command_ack_decode(&message, &ack);
    qCInfo(CameraManagerLog) << "[CameraFlow]"
            << "_handleCommandAck"
            << "compid" << message.compid
            << "command" << ack.command
            << "result" << ack.result;
    for(int i = 0; i < _cameras.count(); i++) {
        QGCCameraControl* pCamera = qobject_cast<QGCCameraControl*>(_cameras[i]);
        if(pCamera) {
            pCamera->handleCommandAck(ack);
        }
    }
}

void
QGCCameraManager::_handleRCChannels(const mavlink_message_t& message)
{
    QGCCameraControl* pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_rc_channels_t rcChannels;
        mavlink_msg_rc_channels_decode(&message, &rcChannels);
        pCamera->handleRCChannels(rcChannels);
    }
}

void
QGCCameraManager::handleAviatorRCChannelValues(const quint16* channels, int count)
{
    if (!channels || count < 10) {
        return;
    }

    QGCCameraControl* pCamera = currentCameraInstance();
    if (!pCamera) {
        qCInfo(CameraManagerLog) << "[RCFlow]"
                << "camera manager aviator rc ignored"
                << "reason" << "no current camera"
                << "count" << count;
        return;
    }

    mavlink_rc_channels_t rcChannels;
    memset(&rcChannels, 0, sizeof(rcChannels));
    const int copyCount = qMin(count, 18);
    memcpy(&rcChannels.chan1_raw, channels, static_cast<size_t>(copyCount) * sizeof(quint16));
    rcChannels.time_boot_ms = static_cast<uint32_t>(QGC::groundTimeMilliseconds());
    rcChannels.chancount = static_cast<uint8_t>(copyCount);
    rcChannels.rssi = 255;

    qCInfo(CameraManagerLog) << "[RCFlow]"
            << "camera manager aviator rc dispatch"
            << "cameraCompId" << pCamera->compID()
            << "count" << copyCount
            << "ch9" << rcChannels.chan9_raw
            << "ch10" << rcChannels.chan10_raw
            << "ch11" << rcChannels.chan11_raw;

    pCamera->handleRCChannels(rcChannels);
}

void
QGCCameraManager::_handleImageCaptured(const mavlink_message_t& message)
{
    QGCCameraControl* pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_camera_image_captured_t imageCaptured;
        mavlink_msg_camera_image_captured_decode(&message, &imageCaptured);
        pCamera->handleImageCaptured(imageCaptured);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleBatteryStatus(const mavlink_message_t& message)
{
    QGCCameraControl* pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_battery_status_t batteryStatus;
        mavlink_msg_battery_status_decode(&message, &batteryStatus);
        pCamera->handleBatteryStatus(batteryStatus);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_handleTrackingImageStatus(const mavlink_message_t& message)
{
    QGCCameraControl* pCamera = _findCamera(message.compid);
    if(pCamera) {
        mavlink_camera_tracking_image_status_t tis;
        mavlink_msg_camera_tracking_image_status_decode(&message, &tis);
        pCamera->handleTrackingImageStatus(&tis);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_requestCameraInfo(int compID, int tryCount, LinkInterface* link)
{
    qInfo() << "[CameraManager]"
            << "_requestCameraInfo"
            << "compid" << compID
            << "try" << tryCount
            << "method" << "REQUEST_CAMERA_INFORMATION";
    if(_vehicle) {
        _vehicle->sendMavCommand(
            compID,                                 // target component
            MAV_CMD_REQUEST_CAMERA_INFORMATION,     // command id
            false,                                  // showError
            1);                                     // Do Request

        // FlyDynamics3 receives a CAMERA_INFORMATION response through TeamModeRouter.
        // ALES does not have that router path, so synthesize the same message locally.
        _injectSynthesizedCameraInformation(compID, link, "request_camera_info");
    }
}

//----------------------------------------------------------------------------------------
void
QGCCameraManager::_activeJoystickChanged(Joystick* joystick)
{
    qCDebug(CameraManagerLog) << "Joystick changed";
    if(_activeJoystick) {
        disconnect(_activeJoystick, &Joystick::stepZoom,            this, &QGCCameraManager::_stepZoom);
        disconnect(_activeJoystick, &Joystick::startContinuousZoom, this, &QGCCameraManager::_startZoom);
        disconnect(_activeJoystick, &Joystick::stopContinuousZoom,  this, &QGCCameraManager::_stopZoom);
        disconnect(_activeJoystick, &Joystick::stepCamera,          this, &QGCCameraManager::_stepCamera);
        disconnect(_activeJoystick, &Joystick::stepStream,          this, &QGCCameraManager::_stepStream);
        disconnect(_activeJoystick, &Joystick::triggerCamera,       this, &QGCCameraManager::_triggerCamera);
        disconnect(_activeJoystick, &Joystick::startVideoRecord,    this, &QGCCameraManager::_startVideoRecording);
        disconnect(_activeJoystick, &Joystick::stopVideoRecord,     this, &QGCCameraManager::_stopVideoRecording);
        disconnect(_activeJoystick, &Joystick::toggleVideoRecord,   this, &QGCCameraManager::_toggleVideoRecording);
    }
    _activeJoystick = joystick;
    if(_activeJoystick) {
        connect(_activeJoystick, &Joystick::stepZoom,               this, &QGCCameraManager::_stepZoom);
        connect(_activeJoystick, &Joystick::startContinuousZoom,    this, &QGCCameraManager::_startZoom);
        connect(_activeJoystick, &Joystick::stopContinuousZoom,     this, &QGCCameraManager::_stopZoom);
        connect(_activeJoystick, &Joystick::stepCamera,             this, &QGCCameraManager::_stepCamera);
        connect(_activeJoystick, &Joystick::stepStream,             this, &QGCCameraManager::_stepStream);
        connect(_activeJoystick, &Joystick::triggerCamera,          this, &QGCCameraManager::_triggerCamera);
        connect(_activeJoystick, &Joystick::startVideoRecord,       this, &QGCCameraManager::_startVideoRecording);
        connect(_activeJoystick, &Joystick::stopVideoRecord,        this, &QGCCameraManager::_stopVideoRecording);
        connect(_activeJoystick, &Joystick::toggleVideoRecord,      this, &QGCCameraManager::_toggleVideoRecording);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_triggerCamera()
{
    QGCCameraControl* pCamera = currentCameraInstance();
    if(pCamera) {
        pCamera->takePhoto();
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_startVideoRecording()
{
    QGCCameraControl* pCamera = currentCameraInstance();
    if(pCamera) {
        pCamera->startVideo();
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_stopVideoRecording()
{
    QGCCameraControl* pCamera = currentCameraInstance();
    if(pCamera) {
        pCamera->stopVideo();
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_toggleVideoRecording()
{
    QGCCameraControl* pCamera = currentCameraInstance();
    if(pCamera) {
        pCamera->toggleVideo();
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_stepZoom(int direction)
{
    if(_lastZoomChange.elapsed() > 40) {
        _lastZoomChange.start();
        qCDebug(CameraManagerLog) << "Step Camera Zoom" << direction;
        QGCCameraControl* pCamera = currentCameraInstance();
        if(pCamera) {
            pCamera->stepZoom(direction);
        }
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_startZoom(int direction)
{
    qCDebug(CameraManagerLog) << "Start Camera Zoom" << direction;
    QGCCameraControl* pCamera = currentCameraInstance();
    if(pCamera) {
        pCamera->startZoom(direction);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_stopZoom()
{
    qCDebug(CameraManagerLog) << "Stop Camera Zoom";
    QGCCameraControl* pCamera = currentCameraInstance();
    if(pCamera) {
        pCamera->stopZoom();
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_stepCamera(int direction)
{
    if(_lastCameraChange.elapsed() > 1000) {
        _lastCameraChange.start();
        qCDebug(CameraManagerLog) << "Step Camera" << direction;
        int c = _currentCamera + direction;
        if(c < 0) c = _cameras.count() - 1;
        if(c >= _cameras.count()) c = 0;
        setCurrentCamera(c);
    }
}

//-----------------------------------------------------------------------------
void
QGCCameraManager::_stepStream(int direction)
{
    if(_lastCameraChange.elapsed() > 1000) {
        _lastCameraChange.start();
        QGCCameraControl* pCamera = currentCameraInstance();
        if(pCamera) {
            qCDebug(CameraManagerLog) << "Step Camera Stream" << direction;
            int c = pCamera->currentStream() + direction;
            if(c < 0) c = pCamera->streams()->count() - 1;
            if(c >= pCamera->streams()->count()) c = 0;
            pCamera->setCurrentStream(c);
        }
    }
}
