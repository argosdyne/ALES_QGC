#include "CodevCameraControl.h"
#include "QGCCameraIO.h"
#include "QGCCameraManager.h"
#include <QTimeZone>
#include <QNetworkProxy>
#include <QNetworkReply>
#include <QNetworkAccessManager>
#include <QJsonDocument>
#include <QJsonObject>
#include "TargetObject.h"
#include "QGCApplication.h"
#include "QGCCorePlugin.h"
#include "CustomPlugin.h"
#include "VideoManager.h"

static const char *kIR_TEMP_POINT = "IR_TEMP_POINT";
static const char *kIR_TEMP_RECT = "IR_TEMP_RECT";
static const char *kIR_TEMP_DATA = "IR_TEMP_DATA";
static const char *kNV_STATUS = "NV_STATUS";
static const char *kEO_SPOTAE = "EO_SPOTAE";
static const char *kEO_DZOOM = "EO_DZOOM";
static const char *kAI_SOURCE = "AI_SOURCE";
static const char *kEO_ZOOM_MODE = "EO_ZOOM_MODE";
static const char *kTIME_ZONE = "TIME_ZONE";
static const char *kTRACK_ALGORITHM = "TRACK_ALGORITHM";
static const char *kDETECT_OBJECTS = "DETECT_OBJECTS";
static const char *kTRACK_PLUGINS = "TRACK_PLUGINS";
static const char *kDETECT_PLUGINS = "DETECT_PLUGINS";
static const char *kSMART_SELECT = "SMART_SELECT";
static const char *kAI_RESOLUTION = "AI_RESOLUTION";
static const char *kFACTORY_CALI = "FACTORY_CALI";
static const char *kFACTORY_DATA = "FACTORY_DATA";
static const char *kJSON_TR_REQ = "JSON_TR_REQ";
static const char *kCALIBRATE_FLAGS = "CALIBRATE_FLAGS";
static const char *kEO_RESOLUTION = "EO_RESOLUTION";
static const char *kCR_AF_AREA_POS = "CR_AF_AREA_POS";
static const char *kCAM_EXPMODEE = "CAM_EXPMODE";
static const char *kCR_AF_AREA = "CR_AF_AREA";
static const char *kDETECT_STATS = "DETECT_STATS";

QGC_LOGGING_CATEGORY(CodevCameraLog, "CodevCameraLog")
QGC_LOGGING_CATEGORY(CodevCameraVerboseLog, "CodevCameraVerboseLog")

static QStringList detected_labels_database = {
    "person", "car", "bus", "truck", "bike", "train", "boat", "aeroplane",
    "bicycle", "motorcycle", "airplane", "traffic light", "fire hydrant", "stop sign", "parking meter", "bench",
    "bird", "cat", "dog", "horse", "sheep", "cow", "elephant", "bear",
    "zebra", "giraffe", "backpack", "umbrella", "handbag", "tie", "suitcase", "frisbee",
    "skis", "snowboard", "sports ball", "kite", "baseball bat", "baseball glove", "skateboard", "surfboard",
    "tennis racket", "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl",
    "banana", "apple", "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza",
    "donut", "cake", "chair", "couch", "potted plant", "bed", "dining table", "toilet",
    "tv", "laptop", "mouse", "remote", "keyboard", "cell phone", "microwave", "oven",
    "toaster", "sink", "refrigerator", "book", "clock", "vase", "scissors", "teddy bear",
    "hair drier", "toothbrush", "unknown"
};

CodevCameraControl::CodevCameraControl(const mavlink_camera_information_t *info, Vehicle* vehicle, int compID, QObject* parent, LinkInterface* link)
    : CustomCameraControl(info, vehicle, compID, parent, link)
{
    connect(this, &CodevCameraControl::parametersReady, this, &CodevCameraControl::_parametersReady);
    memset(&_tempPacket, 0, sizeof(_tempPacket));
    memset(&_nvStatusPacket, 0, sizeof(_nvStatusPacket));
    _resetTempPacket.setSingleShot(true);
    _resetTempPacket.setInterval(1000);
    connect(&_resetTempPacket, &QTimer::timeout, [this]() {
        memset(&_tempPacket, 0, sizeof(_tempPacket));
    });
    _resetNVStatusPacket.setSingleShot(true);
    _resetNVStatusPacket.setInterval(5000);
    connect(&_resetNVStatusPacket, &QTimer::timeout, [this]() {
        memset(&_nvStatusPacket, 0, sizeof(_nvStatusPacket));
    });
    _trackingImageStatus.tracking_status = 2;
    _resetDetectObjectsPacket.setSingleShot(true);
    _resetDetectObjectsPacket.setInterval(1000);
    connect(&_resetDetectObjectsPacket, &QTimer::timeout, [this]() {
        _targetObjects.clearAndDeleteContents();
    });
}

void CodevCameraControl::setSpotTempPoint(float x, float y)
{
    // thermometry point
    Fact* fact = getFact(kIR_TEMP_POINT);
    if(fact) {
        float value[2] = { x, y };
        QByteArray array;
        array.append((char*)&value, sizeof(value));
        fact->forceSetRawValue(QVariant(array));
    }
}

void CodevCameraControl::setAreaTempRect(float x1, float y1, float x2, float y2)
{
    Fact* fact = getFact(kIR_TEMP_RECT);
    if(fact) {
        float value[4] = { x1, y1, x2, y2 };
        QByteArray array;
        array.append((char*)&value, sizeof(value));
        fact->forceSetRawValue(QVariant(array));
    }
}

QPointF CodevCameraControl::spotMeteringArea()
{
    Fact* fact = getFact(kEO_SPOTAE);
    if(fact) {
        uint value = fact->rawValue().toUInt();
        qreal x = ((value >> 8) & 0xff) / 100.0;
        qreal y = ((value) & 0xff) / 100.0;
        return QPointF(x, y);
    } else {
        return QPointF();
    }
}

void CodevCameraControl::setSpotMetering(float x, float y)
{
    Fact* fact = getFact(kEO_SPOTAE);
    if(fact) {
        if(x == 0.0f && y == 0.0f) {
            fact->forceSetRawValue(0);
        } else {
            int point = (static_cast<int>(x * 100) << 8) | static_cast<int>(y * 100);
            uint value = static_cast<uint>((1 << 16) | point);
            fact->forceSetRawValue(value);
        }
    }
}

QPointF CodevCameraControl::spotFocusArea()
{
    return QPointF();
}

void CodevCameraControl::setSpotFocus(float x, float y)
{
    Fact* fact = getFact(kCAM_EXPMODEE);
    if(fact && fact->enumIndex() > 0) {
        fact = getFact(kCR_AF_AREA);
        if(fact) {
            int type = fact->rawValue().toInt();
            if((type > 3 && type < 8) || (type > 16 && type < 24)) {
                fact = getFact(kCR_AF_AREA_POS);
                if(fact) {
                    if(x == 0.0f && y == 0.0f) {
                        fact->forceSetRawValue(0);
                    } else {
                        uint point = (static_cast<uint>(x * 639) << 16) | static_cast<uint>(y * 479);
                        fact->forceSetRawValue(point);
                    }
                }
            }
        }
    }
}

void CodevCameraControl::initTracker()
{
    Fact* fact = getFact(kTRACK_ALGORITHM);
    if(fact) {
        _trackingImageStatus.tracking_status = 2;
        fact->setEnumIndex(1);
    }
}

void CodevCameraControl::deinitTracker()
{
    Fact* fact = getFact(kTRACK_ALGORITHM);
    if(fact) {
        fact->setEnumIndex(0);
    }
}

void CodevCameraControl::shutterHalfPress(bool down)
{
    if(hasFocus() && _vehicle) {
        sendMavCommand(
            MAV_CMD_SET_CAMERA_FOCUS,
            FOCUS_TYPE_AUTO_CONTINUOUS,
            down ? 1 : 0);
    }
}

void CodevCameraControl::startTracking(QPointF point, double radius)
{
    qCDebug(CodevCameraLog) << "startTracking Point" << point.x() << point.y() << radius << hasTrackingPoint();
    if(hasTrackingPoint() && _vehicle) {
        float offset_x = 0.0f;
        float offset_y = 0.0f;
        if(_dZoomFact) {
            float dzoom = _dZoomFact->rawValue().toFloat();
            if(dzoom > 1.0f) {
                offset_x = (1.0f - 1.0f / dzoom) / 2.0f;
                offset_y = (1.0f - 1.0f / dzoom) / 2.0f;
            }
            if(offset_x != 0.0f && offset_y != 0.0f) {
                point.setX(point.x() * (1.0f - offset_x * 2.0f) + offset_x);
                point.setY(point.y() * (1.0f - offset_y * 2.0f) + offset_y);
            }
        }
        sendMavCommand(
            MAV_CMD_CAMERA_TRACK_POINT,             // Command id
            static_cast<float>(point.x()),          // Point X
            static_cast<float>(point.y()),          // Point Y
            static_cast<float>(radius));            // Radius
    }
}

void CodevCameraControl::startTracking(QRectF rec)
{
    qCDebug(CodevCameraLog) << "startTracking Rectangle" << rec.x() << rec.y() << (rec.x() + rec.width()) << (rec.y() + rec.height()) << hasTrackingRectangle();
    if(hasTrackingRectangle() && _vehicle) {
        float offset_x = 0.0f;
        float offset_y = 0.0f;
        if(_dZoomFact) {
            float dzoom = _dZoomFact->rawValue().toFloat();
            if(dzoom > 1.0f) {
                offset_x = (1.0f - 1.0f / dzoom) / 2.0f;
                offset_y = (1.0f - 1.0f / dzoom) / 2.0f;
            }
            if(offset_x != 0.0f && offset_y != 0.0f) {
                double x2 = rec.x() + rec.width();
                double y2 = rec.y() + rec.height();
                x2 = x2 * (1.0f - offset_x * 2.0f) + offset_x;
                y2 = y2 * (1.0f - offset_y * 2.0f) + offset_y;
                rec.setX(rec.x() * (1.0f - offset_x * 2.0f) + offset_x);
                rec.setY(rec.y() * (1.0f - offset_y * 2.0f) + offset_y);
                rec.setWidth(x2 - rec.x());
                rec.setHeight(y2 - rec.y());
            }
        }
        sendMavCommand(
            MAV_CMD_CAMERA_TRACK_RECTANGLE,               // Command id
            static_cast<float>(rec.x()),                  // Point1 X
            static_cast<float>(rec.y()),                  // Point1 Y
            static_cast<float>(rec.x() + rec.width()),    // Point2 X
            static_cast<float>(rec.y() + rec.height()),   // Point2 Y
            1);
    }
}

void CodevCameraControl::stopTracking()
{
    qCDebug(CodevCameraLog) << "stopTracking";
    if((hasTrackingPoint() || hasTrackingRectangle()) && _vehicle) {
        sendMavCommand(MAV_CMD_CAMERA_STOP_TRACKING);
    }
}

void CodevCameraControl::handleImageCaptured(const mavlink_camera_image_captured_t& ic)
{
    qCDebug(CodevCameraLog) << "handleImageCaptured:" << ic.image_index;
    if(ic.image_index > _photoIndex) {
        _photoIndex = ic.image_index;
        emit photoIndexChanged();
    }
}

void CodevCameraControl::setZoomLevel(qreal level)
{
    if(abs(level - 1.0) < 0.01) stepZoom(0);
    CustomCameraControl::setZoomLevel(level);
}

void CodevCameraControl::gimbalControlInImage(QPointF point)
{
    if(point.x() == 0.0 && point.x() == 0.0) return;
    qCDebug(CodevCameraLog) << "Gimbal Point:" << point;
    float dzoom = 1.0f;
    Fact* fact = getFact(kEO_DZOOM);
    if(fact) dzoom = fact->rawValue().toFloat();
    sendMavCommandWithTarget(
        MAV_CMD_DO_MOUNT_CONTROL,
        MAV_COMP_ID_GIMBAL,
        static_cast<float>(point.y()),  // Pitch 0 - 90
        0,                              // Roll (not used)
        static_cast<float>(point.x()),  // Yaw -180 - 180
        0,                              // Altitude (not used)
        static_cast<float>(_zoomLevel), // Latitude (not used)
        dzoom,                          // Longitude (not used)
        -1);                            // Custom offset Roll,Pitch,Yaw
}

void CodevCameraControl::handleCaptureStatus(const mavlink_camera_capture_status_t& cap)
{
    VehicleCameraControl::handleCaptureStatus(cap);
    _photoIndex = cap.image_count;
    emit photoIndexChanged();
}

void CodevCameraControl::stepZoom(int direction)
{
    qCDebug(CodevCameraLog) << "DZoom()" << direction;
    Fact* fact = getFact(kEO_DZOOM);
    if(fact) {
        if(direction > 0) {
            double value = fact->cookedValue().toDouble() + fact->cookedIncrement();
            if(value - fact->cookedMax().toDouble() > 0.01) {
                value = fact->cookedMax().toDouble();
            }
            fact->setRawValue(static_cast<float>(value));
        } else if(direction < 0) {
            double value = fact->cookedValue().toDouble() - fact->cookedIncrement();
            if(value - fact->cookedMin().toDouble() < 0.01) {
                value = fact->cookedMin().toDouble();
            }
            fact->setRawValue(static_cast<float>(value));
        } else {
            fact->setRawValue(1.0f);
        }
    }
}

QStringList CodevCameraControl::activeSettings()
{
    QStringList settings = _activeSettings;
    if(!_hasTrack) {
        settings.removeOne(kTRACK_ALGORITHM);
    }
    if(!_hasDetect) {
        settings.removeOne(kSMART_SELECT);
    }
    if(!qgcApp()->toolbox()->corePlugin()->showAdvancedUI() && !_is_factory_calibate) {
        settings.removeOne(kFACTORY_CALI);
    }
    return settings;
}

int CodevCameraControl::photoIndex()
{
    return _is_factory_calibate ? _factory_calibate_image_index : CustomCameraControl::photoIndex();
}

QGCVideoStreamInfo* CodevCameraControl::currentStreamInstance()
{
    if(_is_factory_calibate) {
        if(_factory_stream_info == nullptr) {
            mavlink_video_stream_information_t live_stream;
            VehicleCameraControl::currentStreamInstance()->get_stream_info(live_stream);
            QString url = QString("udp265://0.0.0.0:5004");
            memset(live_stream.uri, 0, sizeof(live_stream.uri));
            memcpy(live_stream.uri, url.toLatin1().data(), url.length());
            _factory_stream_info = new QGCVideoStreamInfo(this, &live_stream);
        }
        return _factory_stream_info;
    } else {
        return VehicleCameraControl::currentStreamInstance();
    }
}

QGCVideoStreamInfo* CodevCameraControl::thermalStreamInstance()
{
    return _is_factory_calibate ? nullptr : VehicleCameraControl::thermalStreamInstance();
}

void CodevCameraControl::_parametersReady()
{
    disconnect(this, &CodevCameraControl::parametersReady, this, &CodevCameraControl::_parametersReady);

    // nvidia system status
    Fact* fact = getFact(kNV_STATUS);
    if(fact) {
        connect(fact, &Fact::rawValueChanged, this, &CodevCameraControl::_handleNVStatus);
    }

    // thermometry data
    fact = getFact(kIR_TEMP_DATA);
    if(fact) {
        connect(fact, &Fact::rawValueChanged, this, &CodevCameraControl::_handleThermometryData);
    }

    // spot metering area
    fact = getFact(kEO_SPOTAE);
    if(fact) {
        connect(fact, &Fact::rawValueChanged, this, &CodevCameraControl::spotMeteringAreaChanged);
    }

    // time zones
    fact = getFact(kTIME_ZONE);
    if(fact) {
        QByteArray value = QTimeZone::systemTimeZone().id();
        if (value.size() < 128) {
            value.append(128 - value.size(), 0);
        }
        fact->setRawValue(QVariant(value));
    }

    // zoom mode
    fact = getFact(kEO_ZOOM_MODE);
    if(fact) {
        _zoomModeFact = fact;
    }

    // dzoom
    fact = getFact(kEO_DZOOM);
    if (fact) {
        _dZoomFact = fact;
        _dZoomInMaxChange();
        connect(this, &CodevCameraControl::zoomLevelChanged, this, &CodevCameraControl::_dZoomInMaxChange);
    }

    // ai source
    fact = getFact(kAI_SOURCE);
    if(fact) {
        _aiSourceFact = fact;
    }

    // detect objects
    fact = getFact(kDETECT_OBJECTS);
    if(fact) {
        connect(fact, &Fact::rawValueChanged, this, &CodevCameraControl::_handleDetectObjects);
    }
    fact = getFact(kDETECT_STATS);
    if(fact) {
        connect(fact, &Fact::rawValueChanged, this, &CodevCameraControl::_handleDetectStats);
    }

    // detect plugins
    fact = getFact(kDETECT_PLUGINS);
    if(fact) {
        Fact* detect = getFact(kSMART_SELECT);
        if(detect) {
            FactMetaData* meta = detect->metaData();
            QString value = fact->rawValueString().remove(QChar('\0'));
            QStringList plugins = value.trimmed().split(',');
            plugins.push_front("None");
            if(plugins.size() && meta) {
                QVariantList values;
                for(QString v : plugins) {
                    values.append(v);
                }
                meta->setEnumInfo(plugins, values);
                _hasDetect = true;
            }
        }
    }

    // track plugins
    fact = getFact(kTRACK_PLUGINS);
    if(fact) {
        Fact* track = getFact(kTRACK_ALGORITHM);
        if(track) {
            QStringList exclusions;
            exclusions << kSMART_SELECT << kAI_RESOLUTION;
            if(_aiSourceFact) exclusions << kAI_SOURCE;
            FactMetaData* meta = track->metaData();
            QString value = fact->rawValueString().remove(QChar('\0'));
            QStringList plugins = value.trimmed().split(',');
            plugins.push_front("None");
            if(plugins.size() && meta) {
                QVariantList values;
                for(QString v : plugins) {
                    values.append(v);
                    _originalOptNames[kTRACK_ALGORITHM] << v;
                    _originalOptValues[kTRACK_ALGORITHM] << v;
                    if(v != "None") {
                        QGCCameraOptionExclusion* pExc = new QGCCameraOptionExclusion(this, kTRACK_ALGORITHM, v, exclusions);
                        QQmlEngine::setObjectOwnership(pExc, QQmlEngine::CppOwnership);
                        _valueExclusions.append(pExc);
                    }
                }
                meta->setEnumInfo(plugins, values);
                _hasTrack = true;
            }
            if(track->cookedValue().toString() != "None") {
                _activeSettings.removeOne(kSMART_SELECT);
                _activeSettings.removeOne(kAI_RESOLUTION);
                if(_aiSourceFact) _activeSettings.removeOne(kAI_SOURCE);
            }
        }
    }

    // factory calibrate
    fact = getFact(kFACTORY_CALI);
    if(fact) {
        _is_factory_calibate = fact->rawValue().toBool();
        if(_is_factory_calibate) {
            _factoryCalibrateChanged(fact->rawValue());
        }
        connect(fact, &Fact::rawValueChanged, this, &CodevCameraControl::_factoryCalibrateChanged);

        fact = getFact(kFACTORY_DATA);
        if(fact) {
            connect(fact, &Fact::rawValueChanged, this, &CodevCameraControl::_handlefactoryCalibrateData);
        }
    }

    // json transfor request
    fact = getFact(kJSON_TR_REQ);
    if(fact) {
        _requestJSONTransfor(fact->rawValue());
        connect(fact, &Fact::rawValueChanged, this, &CodevCameraControl::_requestJSONTransfor);
    }

    // camera calibrate flags
    fact = getFact(kCALIBRATE_FLAGS);
    if(fact) {
        factChanged(fact);
        connect(fact, &Fact::rawValueChanged, this, &CodevCameraControl::_paramSlefChanged);
    }

    fact = getFact(kEO_RESOLUTION);
    if(fact) {
        connect(fact, &Fact::rawValueChanged, this, [](QVariant){
            QTimer::singleShot(1000, [](){
                qgcApp()->toolbox()->videoManager()->stopVideo(0);
            });
        });
    }

    // camera mode
    fact = getFact(kCAM_MODE);
    if(fact) {
        factChanged(fact);
    }
}

void CodevCameraControl::_paramSlefChanged()
{
    Fact* fact = qobject_cast<Fact*>(sender());
    if(fact) {
        factChanged(fact);
    }
}

void CodevCameraControl::_requestJSONTransfor(QVariant data)
{
    QString url = data.toString();
    qCDebug(CodevCameraLog) << "Request json:" << url;
    if(url.isEmpty()) return;
    if(!_netManager) {
        _netManager = new QNetworkAccessManager(this);
    }
    QNetworkProxy savedProxy = _netManager->proxy();
    QNetworkProxy tempProxy;
    tempProxy.setType(QNetworkProxy::DefaultProxy);
    _netManager->setProxy(tempProxy);
    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, true);
    QSslConfiguration conf = request.sslConfiguration();
    conf.setPeerVerifyMode(QSslSocket::VerifyNone);
    request.setSslConfiguration(conf);
    QNetworkReply* reply = _netManager->get(request);
    connect(reply, &QNetworkReply::finished,  this, &CodevCameraControl::_downloadJSONFinished);
    _netManager->setProxy(savedProxy);
}

void CodevCameraControl::_downloadJSONFinished()
{
    QNetworkReply* reply = qobject_cast<QNetworkReply*>(sender());
    if(!reply) {
        return;
    }
    int err = reply->error();
    int http_code = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    QByteArray data = reply->readAll();
    if(err == QNetworkReply::NoError && http_code == 200) {
        QJsonDocument jsonDocument = QJsonDocument::fromJson(data);
        if (jsonDocument.isNull()) {
            qCWarning(CodevCameraLog) << "Failed to parse Camera JSON";
            return;
        }
        QJsonObject jsonObject = jsonDocument.object();
        if(jsonObject.contains("AI_CONFIG.yaml")) {
            QStringList labelList;
            if(!jsonObject["AI_CONFIG.yaml"].isNull() && jsonObject["AI_CONFIG.yaml"].isObject()) {
                QJsonObject configObject = jsonObject["AI_CONFIG.yaml"].toObject();
                QString exLables = ".labels";
                Fact* fact = getFact(kSMART_SELECT);
                if(fact) exLables = fact->rawValueString() + exLables;
                for (const QString& key : configObject.keys()) {
                    if(key.endsWith(exLables)) {
                        if(configObject[key].isArray()) {
                            QJsonArray labels = configObject[key].toArray();
                            for (int i = 0; i< labels.count(); i++) {
                                QJsonValue jsonValue = labels.at(i);
                                if(jsonValue.isString()) {
                                    labelList.append(jsonValue.toString());
                                }
                            }
                        }
                        break;
                    }
                }
            }
            _targetObjectLabels.clear();
            _targetObjectLabels.append(labelList);
        }
    } else {
        data.clear();
        qCWarning(CodevCameraLog) << QString("Camera Json (%1) download error: %2 status: %3").arg(
            reply->url().toDisplayString(),
            reply->errorString(),
            reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toString()
            );
    }
}

void CodevCameraControl::_factoryCalibrateChanged(QVariant data)
{
    if(data.toBool()) {
        if(_is_factory_calibate == false) {
            _is_factory_calibate = true;
            _factory_calibate_image_index = 1;
            emit photoIndexChanged();
            emit _vehicle->cameraManager()->streamChanged();
        }
    } else {
        if(_is_factory_calibate == true) {
            _is_factory_calibate = false;
            // delete _factory_stream_info;
            emit _vehicle->cameraManager()->streamChanged();
        }
    }
}

void CodevCameraControl::_handlefactoryCalibrateData(QVariant data)
{
    qInfo() << data;
    CalibrateFeedback _packet;
    memcpy(&_packet, data.toByteArray().data(), sizeof(_packet));
    if(_packet.type > 0) {
        _factory_calibate_image_index = _packet.image_count + 1;
        emit photoIndexChanged();
        if(_packet.type == 2) {
            std::vector<uint8_t> success_ids;
            std::vector<uint8_t> un_ids;
            for(int i = 0; i < 60; i++) {
                if(_packet.oks[i] == 255) {
                    break;
                } else if(_packet.oks[i] == 1) {
                    success_ids.push_back(_packet.ids[i]);
                } else {
                    un_ids.push_back(_packet.ids[i]);
                }
            }
            if(success_ids.size() > 0 && un_ids.size() > 0) {
                QString miss_ids;
                for(auto id : un_ids) {
                    miss_ids += QString::number(id) + ",";
                }
                miss_ids.chop(1);
                qgcApp()->showAppMessage(tr("Missing markers information, IDs: %1.").arg(miss_ids), tr("Camera Calibration"));
            } else if(success_ids.size() > 0 && un_ids.size() == 0) {
                CustomPlugin* plugin = qobject_cast<CustomPlugin*>(qgcApp()->toolbox()->corePlugin());
                plugin->showMessage(tr("All marker information has been collected."));
            }
        }
    } else if(_packet.type == 0) {
        qgcApp()->showAppMessage(tr("Camera calibration successful!"), tr("Camera Calibration"));
    } else {
        qgcApp()->showAppMessage(tr("Camera calibration failed!"), tr("Camera Calibration"));
    }
}

void CodevCameraControl::_dZoomInMaxChange()
{
    double max_zoom = 29.5;
    if(_zoomModeFact && _zoomModeFact->rawValue().toInt() == 2) {
        max_zoom = 239.5;
    }
    if(_zoomLevel >= max_zoom) {
        if(!_dZoomInMax) {
            _dZoomInMax = true;
            emit dZoomInMaxChanged();
        }
    } else {
        if(_dZoomInMax) {
            _dZoomInMax = false;
            emit dZoomInMaxChanged();
        }
    }
}

void CodevCameraControl::_handleThermometryData(QVariant data)
{
    _resetTempPacket.stop();
    memcpy(&_tempPacket, data.toByteArray().data(), sizeof(_tempPacket));
    emit thermometryDataChanged();
    _resetTempPacket.start();
}

void CodevCameraControl::_handleNVStatus(QVariant data)
{
    _resetNVStatusPacket.stop();
    memcpy(&_nvStatusPacket, data.toByteArray().data(), sizeof(_nvStatusPacket));
    emit nvStatusChanged();
    _resetNVStatusPacket.start();
}

void CodevCameraControl::_handleDetectObjects(QVariant data)
{
    QStringList labels_database;
    if(_targetObjectLabels.size() > 0) {
        labels_database.append(_targetObjectLabels);
    } else {
        labels_database.append(detected_labels_database);
    }
    float offset_x = 0.0f;
    float offset_y = 0.0f;
    if(_dZoomFact && (_aiSourceFact == nullptr || _aiSourceFact->enumIndex() == 0)) {
        float dzoom = _dZoomFact->rawValue().toFloat();
        if(dzoom > 1.0f) {
            offset_x = (1.0f - 1.0f / dzoom) / 2.0f;
            offset_y = (1.0f - 1.0f / dzoom) / 2.0f;
        }
    }
    _resetDetectObjectsPacket.stop();
    DetectObjectsPacket _packet;
    memcpy(&_packet, data.toByteArray().data(), sizeof(_packet));
    QObjectList swaplist;
    for(int i = 0; i < _packet.size; i++) {
        if(_packet.objects[i].type >= labels_database.size()) continue;
        float x1 = _packet.objects[i].x / 10000.0f;
        float y1 = _packet.objects[i].y / 10000.0f;
        float x2 = (_packet.objects[i].x + _packet.objects[i].width) / 10000.0f;
        float y2 = (_packet.objects[i].y + _packet.objects[i].height) / 10000.0f;
        if(offset_x != 0.0f && offset_y != 0.0f) {
            x1 = (x1 - offset_x) / (1.0f - offset_x * 2.0f);
            y1 = (y1 - offset_y) / (1.0f - offset_y * 2.0f);
            x2 = (x2 - offset_x) / (1.0f - offset_x * 2.0f);
            y2 = (y2 - offset_y) / (1.0f - offset_y * 2.0f);
        }
        QString objectId = labels_database.size() > _packet.objects[i].type ? labels_database[_packet.objects[i].type]: "none";
        TargetObject* p = new TargetObject(x1, y1, x2, y2, objectId, _packet.objects[i].score / 10000.0f);
        p->setObjectName("");
        swaplist.append(p);
    }
    QObjectList oldlist = _targetObjects.swapObjectList(swaplist);
    foreach(QObject *obj, oldlist) {
        obj->deleteLater();
    }
    _resetDetectObjectsPacket.start();
}

void CodevCameraControl::_handleDetectStats(QVariant data)
{
    QStringList labels_database;
    if(_targetObjectLabels.size() > 0) {
        labels_database.append(_targetObjectLabels);
    } else {
        labels_database.append(detected_labels_database);
    }
    DetectStatsPacket packet;
    memcpy(&packet, data.toByteArray().data(), sizeof(packet));
    _detectStats.clear();
    for(int i = 0; i < packet.size; i++) {
        QString objectId = labels_database.size() > packet.objects[i].type ? labels_database[packet.objects[i].type]: "none";
        _detectStats.append(QString("%1").arg(objectId));
        _detectStats.append(QString("%1").arg(packet.objects[i].count));
    }
    emit detectStatsChanged();
}

void CodevCameraControl::handleTrackingImageStatus(const mavlink_camera_tracking_image_status_t *tis)
{
    mavlink_camera_tracking_image_status_t tracking_image_status;
    memcpy(&tracking_image_status, tis, sizeof(tracking_image_status));

    bool changed = false;
    if(tracking_image_status.tracking_status == 255) {
        if(!_busy_in_detect_setup) {
            _busy_in_detect_setup = true;
            changed = true;
        }
        if(_busy_in_track_setup) {
            _busy_in_track_setup = false;
            changed = true;
        }
    } else if(tracking_image_status.tracking_status == 254) {
        if(_busy_in_detect_setup) {
            _busy_in_detect_setup = false;
            changed = true;
        }
        if(!_busy_in_track_setup) {
            _busy_in_track_setup = true;
            changed = true;
        }
    } else if(tracking_image_status.tracking_status == 1) {
        if(_trackingImageStatus.tracking_mode == 2) {
            float offset_x = 0.0f;
            float offset_y = 0.0f;
            if(_dZoomFact) {
                float dzoom = _dZoomFact->rawValue().toFloat();
                if(dzoom > 1.0f) {
                    offset_x = (1.0f - 1.0f / dzoom) / 2.0f;
                    offset_y = (1.0f - 1.0f / dzoom) / 2.0f;
                }
                if(offset_x != 0.0f && offset_y != 0.0f) {
                    tracking_image_status.rec_top_x = (tracking_image_status.rec_top_x - offset_x) / (1.0f - offset_x * 2.0f);
                    tracking_image_status.rec_top_y = (tracking_image_status.rec_top_y - offset_y) / (1.0f - offset_y * 2.0f);
                    tracking_image_status.rec_bottom_x = (tracking_image_status.rec_bottom_x - offset_x) / (1.0f - offset_x * 2.0f);
                    tracking_image_status.rec_bottom_y = (tracking_image_status.rec_bottom_y - offset_y) / (1.0f - offset_y * 2.0f);
                }
            }
        }
        if(_busy_in_detect_setup) {
            _busy_in_detect_setup = false;
            changed = true;
        }
        if(_busy_in_track_setup) {
            _busy_in_track_setup = false;
            changed = true;
        }
    } else if(tracking_image_status.tracking_status == 0) {
        if(_busy_in_detect_setup) {
            _busy_in_detect_setup = false;
            changed = true;
        }
        if(_busy_in_track_setup) {
            _busy_in_track_setup = false;
            changed = true;
        }
    }
    if(changed) emit busyInSetupChanged();
    if(tracking_image_status.tracking_status < 3) {
        VehicleCameraControl::handleTrackingImageStatus(&tracking_image_status);
    }
}
