/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


#include <QQmlContext>
#include <QQmlEngine>
#include <QSettings>
#include <QUrl>
#include <QDir>
#include <QQuickWindow>

#ifdef Q_OS_ANDROID
#include <QtAndroidExtras/QAndroidJniObject>
#endif

#ifndef QGC_DISABLE_UVC
#include <QCameraInfo>
#endif

#include "ScreenToolsController.h"
#include "VideoManager.h"
#include "QGCToolbox.h"
#include "QGCCorePlugin.h"
#include "QGCOptions.h"
#include "MultiVehicleManager.h"
#include "Settings/SettingsManager.h"
#include "Vehicle.h"
#include "QGCCameraManager.h"

#if defined(QGC_GST_STREAMING)
#include "GStreamer.h"
#include "VideoSettings.h"
#else
#include "GLVideoItemStub.h"
#endif

#ifdef QGC_GST_TAISYNC_ENABLED
#include "TaisyncHandler.h"
#endif

QGC_LOGGING_CATEGORY(VideoManagerLog, "VideoManagerLog")

static bool isRockchipManufacturer()
{
#ifdef Q_OS_ANDROID
    const QAndroidJniObject manufacturer = QAndroidJniObject::getStaticObjectField(
            "android/os/Build", "MANUFACTURER", "Ljava/lang/String;");
    if (manufacturer.isValid()) {
        return manufacturer.toString().contains(QStringLiteral("rockchip"), Qt::CaseInsensitive);
    }
#endif
    return false;
}

#if defined(QGC_GST_STREAMING)
static const char* kFileExtension[VideoReceiver::FILE_FORMAT_MAX - VideoReceiver::FILE_FORMAT_MIN] = {
    "mkv",
    "mov",
    "mp4"
};
#endif

//-----------------------------------------------------------------------------
VideoManager::VideoManager(QGCApplication* app, QGCToolbox* toolbox)
    : QGCTool(app, toolbox)
{
#if !defined(QGC_GST_STREAMING)
    static bool once = false;
    if (!once) {
        qmlRegisterType<GLVideoItemStub>("org.freedesktop.gstreamer.GLVideoItem", 1, 0, "GstGLVideoItem");
        once = true;
    }
#endif
}

//-----------------------------------------------------------------------------
VideoManager::~VideoManager()
{
    for (int i = 0; i < 3; i++) {
        if (_videoReceiver[i] != nullptr) {
            delete _videoReceiver[i];
            _videoReceiver[i] = nullptr;
        }
#if defined(QGC_GST_STREAMING)
        if (_videoSink[i] != nullptr) {
            // FIXME: AV: we need some interaface for video sink with .release() call
            // Currently VideoManager is destroyed after corePlugin() and we are crashing on app exit
            // calling qgcApp()->toolbox()->corePlugin()->releaseVideoSink(_videoSink[i]);
            // As for now let's call GStreamer::releaseVideoSink() directly
            GStreamer::releaseVideoSink(_videoSink[i]);
            _videoSink[i] = nullptr;
        }
#endif
    }
}

//-----------------------------------------------------------------------------
void
VideoManager::setToolbox(QGCToolbox *toolbox)
{
   QGCTool::setToolbox(toolbox);
   QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
   qmlRegisterUncreatableType<VideoManager> ("QGroundControl.VideoManager", 1, 0, "VideoManager", "Reference only");
   qmlRegisterUncreatableType<VideoReceiver>("QGroundControl",              1, 0, "VideoReceiver","Reference only");

   // TODO: Those connections should be Per Video, not per VideoManager.
   _videoSettings = toolbox->settingsManager()->videoSettings();
   _legacyRockchipStreaming = isRockchipManufacturer();
   qCInfo(VideoManagerLog) << "[VideoManager]" << "deviceManufacturerMode"
                           << (_legacyRockchipStreaming ? "rockchip-legacy" : "default-low-latency");
   if (!_legacyRockchipStreaming && !_videoSettings->lowLatencyMode()->rawValue().toBool()) {
       qCInfo(VideoManagerLog) << "[VideoManager]" << "enabling lowLatencyMode by default";
       _videoSettings->lowLatencyMode()->setRawValue(true);
   }
   QString videoSource = _videoSettings->videoSource()->rawValue().toString();
   qCDebug(VideoManagerLog) << "[VideoManager]" << "setToolbox"
           << "videoSource" << videoSource
           << "rtspUrl" << _videoSettings->rtspUrl()->rawValue().toString()
           << "streamEnabled" << _videoSettings->streamEnabled()->rawValue().toBool();
   connect(_videoSettings->videoSource(),   &Fact::rawValueChanged, this, &VideoManager::_videoSourceChanged);
   connect(_videoSettings->udpPort(),       &Fact::rawValueChanged, this, &VideoManager::_udpPortChanged);
   connect(_videoSettings->rtspUrl(),       &Fact::rawValueChanged, this, &VideoManager::_rtspUrlChanged);
   connect(_videoSettings->tcpUrl(),        &Fact::rawValueChanged, this, &VideoManager::_tcpUrlChanged);
   connect(_videoSettings->aspectRatio(),   &Fact::rawValueChanged, this, &VideoManager::_aspectRatioChanged);
   connect(_videoSettings->lowLatencyMode(),&Fact::rawValueChanged, this, &VideoManager::_lowLatencyModeChanged);
   connect(_videoSettings->streamEnabled(), &Fact::rawValueChanged, this, &VideoManager::_streamEnabledChanged);
   MultiVehicleManager *pVehicleMgr = qgcApp()->toolbox()->multiVehicleManager();
   connect(pVehicleMgr, &MultiVehicleManager::activeVehicleChanged, this, &VideoManager::_setActiveVehicle);

#if defined(QGC_GST_STREAMING)
    GStreamer::blacklist(static_cast<VideoSettings::VideoDecoderOptions>(_videoSettings->forceVideoDecoder()->rawValue().toInt()));
#ifndef QGC_DISABLE_UVC
   // If we are using a UVC camera setup the device name
   _updateUVC();
#endif

    emit isGStreamerChanged();
    qCDebug(VideoManagerLog) << "New Video Source:" << videoSource;
#if defined(QGC_GST_STREAMING)
    _videoReceiver[0] = toolbox->corePlugin()->createVideoReceiver(this);
    _videoReceiver[1] = toolbox->corePlugin()->createVideoReceiver(this);
    _videoReceiver[2] = toolbox->corePlugin()->createVideoReceiver(this);

    connect(_videoReceiver[0], &VideoReceiver::streamingChanged, this, [this](bool active){
        qCDebug(VideoManagerLog) << "[VideoManager]" << "video0 streamingChanged" << active;
        _streaming = active;
        emit streamingChanged();
    });

    connect(_videoReceiver[0], &VideoReceiver::timeout, this, [this](){
        qCWarning(VideoManagerLog) << "[VideoManager]" << "video0 timeout"
                                   << "uri" << _videoUri[0]
                                   << "started" << _videoStarted[0]
                                   << "streaming" << _streaming
                                   << "decoding" << _decoding;
        _primaryTimeoutRecoveryPending = true;
    });

    connect(_videoReceiver[0], &VideoReceiver::onStartComplete, this, [this](VideoReceiver::STATUS status) {
        qCDebug(VideoManagerLog) << "[VideoManager]" << "video0 onStartComplete"
                << "status" << static_cast<int>(status)
                << "uri" << _videoUri[0]
                << "sinkReady" << (_videoSink[0] != nullptr);
        if (status == VideoReceiver::STATUS_OK) {
            _videoStarted[0] = true;
            if (_videoSink[0] != nullptr) {
                _deferPrimaryStartUntilSinkReady = false;
                _restartPrimaryOnSinkReady = false;
                qCDebug(VideoManagerLog) << "[VideoManager]" << "video0 startDecoding";
                // It is absolutely ok to have video receiver active (streaming) and decoding not active
                // It should be handy for cases when you have many streams and want to show only some of them
                // NOTE that even if decoder did not start it is still possible to record video
                _videoReceiver[0]->startDecoding(_videoSink[0]);
            } else {
                _restartPrimaryOnSinkReady = true;
                qCWarning(VideoManagerLog) << "[VideoManager]" << "video0 no sink available on start complete";
            }
        } else if (status == VideoReceiver::STATUS_INVALID_URL) {            
            // Invalid URL - don't restart
        } else if (status == VideoReceiver::STATUS_INVALID_STATE) {
            // Already running
        } else {
            _restartVideo(0);
        }
    });

    connect(_videoReceiver[0], &VideoReceiver::onStopComplete, this, [this](VideoReceiver::STATUS status) {
        qCDebug(VideoManagerLog) << "[VideoManager]" << "video0 onStopComplete"
                << "status" << static_cast<int>(status);
        _videoStarted[0] = false;
        if (status == VideoReceiver::STATUS_INVALID_URL) {
            qCDebug(VideoManagerLog) << "Invalid video URL. Not restarting";
        } else if (_primaryTimeoutRecoveryPending) {
            _primaryTimeoutRecoveryPending = false;
            _deferPrimaryStartUntilSinkReady = false;
            _restartPrimaryOnSinkReady = false;
            qCWarning(VideoManagerLog) << "[VideoManager]" << "video0 scheduling timeout recovery restart";
            QTimer::singleShot(1000, this, [this]() {
                qCWarning(VideoManagerLog) << "[VideoManager]" << "video0 timeout recovery restart firing";
                _startReceiver(0);
            });
        } else {
            _startReceiver(0);
        }
    });

    connect(_videoReceiver[0], &VideoReceiver::decodingChanged, this, [this](bool active){
        qCDebug(VideoManagerLog) << "[VideoManager]" << "video0 decodingChanged" << active;
        _decoding = active;
        emit decodingChanged();
    });

    connect(_videoReceiver[0], &VideoReceiver::recordingChanged, this, [this](bool active){
        qCDebug(VideoManagerLog) << "Video 0 recording changed, active: " << (active ? "yes" : "no");
        _recording = active;
        if (!active) {
            _subtitleWriter.stopCapturingTelemetry();
        }
        emit recordingChanged();
    });

    connect(_videoReceiver[0], &VideoReceiver::recordingStarted, this, [this](){
        qCDebug(VideoManagerLog) << "Video 0 recording started";
        _subtitleWriter.startCapturingTelemetry(_videoFile);
    });

    connect(_videoReceiver[0], &VideoReceiver::videoSizeChanged, this, [this](QSize size){
        qCDebug(VideoManagerLog) << "Video 0 resized. New resolution: " << size.width() << "x" << size.height();
        _videoSize = ((quint32)size.width() << 16) | (quint32)size.height();
        emit videoSizeChanged();
    });

    connect(_videoReceiver[0], &VideoReceiver::decoderNameChanged, this, [this](const QString& name){
        if (_decoderName != name) {
            _decoderName = name;
            emit decoderNameChanged();
        }
    });

    //connect(_videoReceiver, &VideoReceiver::onTakeScreenshotComplete, this, [this](VideoReceiver::STATUS status){
    //    if (status == VideoReceiver::STATUS_OK) {
    //    }
    //});

    // FIXME: AV: I believe _thermalVideoReceiver should be handled just like _videoReceiver in terms of event
    // and I expect that it will be changed during multiple video stream activity
    if (_videoReceiver[1] != nullptr) {
        connect(_videoReceiver[1], &VideoReceiver::streamingChanged, this, [this](bool active){
            qCDebug(VideoManagerLog) << "THERMAL_TRACE"
                    << "video1.streamingChanged"
                    << "active" << active
                    << "uri" << _videoUri[1]
                    << "sinkReady" << (_videoSink[1] != nullptr);
        });

        connect(_videoReceiver[1], &VideoReceiver::onStartComplete, this, [this](VideoReceiver::STATUS status) {
            qCDebug(VideoManagerLog) << "THERMAL_TRACE"
                    << "video1.onStartComplete"
                    << "status" << static_cast<int>(status)
                    << "uri" << _videoUri[1]
                    << "sinkReady" << (_videoSink[1] != nullptr);
            if (status == VideoReceiver::STATUS_OK) {
                _videoStarted[1] = true;
                if (_videoSink[1] != nullptr) {
                    _videoReceiver[1]->startDecoding(_videoSink[1]);
                }
            } else if (status == VideoReceiver::STATUS_INVALID_URL) {
                // Invalid URL - don't restart
            } else if (status == VideoReceiver::STATUS_INVALID_STATE) {
                // Already running
            } else {
                _restartVideo(1);
            }
        });

        connect(_videoReceiver[1], &VideoReceiver::onStopComplete, this, [this](VideoReceiver::STATUS) {
            qCDebug(VideoManagerLog) << "THERMAL_TRACE"
                    << "video1.onStopComplete"
                    << "uri" << _videoUri[1];
            _videoStarted[1] = false;
            _startReceiver(1);
        });

        connect(_videoReceiver[1], &VideoReceiver::decodingChanged, this, [this](bool active){
            qCDebug(VideoManagerLog) << "THERMAL_TRACE"
                    << "video1.decodingChanged"
                    << "active" << active
                    << "uri" << _videoUri[1]
                    << "sinkReady" << (_videoSink[1] != nullptr);
        });
    }

    if (_videoReceiver[2] != nullptr) {
        connect(_videoReceiver[2], &VideoReceiver::onStartComplete, this, [this](VideoReceiver::STATUS status) {
            if (status == VideoReceiver::STATUS_OK) {
                _videoStarted[2] = true;
                if (_videoSink[2] != nullptr) {
                    _videoReceiver[2]->startDecoding(_videoSink[2]);
                }
            } else if (status == VideoReceiver::STATUS_INVALID_URL) {
                // Invalid URL - don't restart
            } else if (status == VideoReceiver::STATUS_INVALID_STATE) {
                // Already running
            } else {
                _restartFPV();
            }
        });

        connect(_videoReceiver[2], &VideoReceiver::onStopComplete, this, [this](VideoReceiver::STATUS) {
            _videoStarted[2] = false;
            _restartFPV();
        });
    }
#endif
    _updateSettings(0);
    qCDebug(VideoManagerLog) << "[VideoManager]" << "after initial _updateSettings"
            << "videoUri0" << _videoUri[0]
            << "hasVideo" << hasVideo()
            << "isGStreamer" << isGStreamer();
    if(!_videoSettings->disableFPVVideo()->rawValue().toBool()) {
        _videoUri[2] = _videoSettings->fpvUrl()->rawValue().toString();
    } else {
        _videoUri[2] = "";
    }
    _lowLatencyStreaming[2] = false;
    if(isGStreamer()) {
        startVideo();
        _startReceiver(2);
    } else {
        stopVideo();
        _stopReceiver(2);
    }
    connect(_videoSettings->disableFPVVideo(), &Fact::rawValueChanged, this, &VideoManager::_fpvChanged);
    connect(_videoSettings->fpvUrl(), &Fact::rawValueChanged, this, &VideoManager::_fpvChanged);
    // _updateSettings(0);
    // _updateSettings(1);
    // if(isGStreamer()) {
    //     startVideo();
    // } else {
    //     stopVideo();
    // }

#endif
}

void VideoManager::_cleanupOldVideos()
{
#if defined(QGC_GST_STREAMING)
    //-- Only perform cleanup if storage limit is enabled
    if(!_videoSettings->enableStorageLimit()->rawValue().toBool()) {
        return;
    }
    QString savePath = qgcApp()->toolbox()->settingsManager()->appSettings()->videoSavePath();
    QDir videoDir = QDir(savePath);
    videoDir.setFilter(QDir::Files | QDir::Readable | QDir::NoSymLinks | QDir::Writable);
    videoDir.setSorting(QDir::Time);

    QStringList nameFilters;

    for(size_t i = 0; i < sizeof(kFileExtension) / sizeof(kFileExtension[0]); i += 1) {
        nameFilters << QString("*.") + kFileExtension[i];
    }

    videoDir.setNameFilters(nameFilters);
    //-- get the list of videos stored
    QFileInfoList vidList = videoDir.entryInfoList();
    if(!vidList.isEmpty()) {
        uint64_t total   = 0;
        //-- Settings are stored using MB
        uint64_t maxSize = _videoSettings->maxVideoSize()->rawValue().toUInt() * 1024 * 1024;
        //-- Compute total used storage
        for(int i = 0; i < vidList.size(); i++) {
            total += vidList[i].size();
        }
        //-- Remove old movies until max size is satisfied.
        while(total >= maxSize && !vidList.isEmpty()) {
            total -= vidList.last().size();
            qCDebug(VideoManagerLog) << "Removing old video file:" << vidList.last().filePath();
            QFile file (vidList.last().filePath());
            file.remove();
            vidList.removeLast();
        }
    }
#endif
}

//-----------------------------------------------------------------------------
void
VideoManager::startVideo(int id)
{
    if (qgcApp()->runningUnitTests()) {
        return;
    }

    const bool configured = _videoSettings->streamConfigured();
    qCDebug(VideoManagerLog) << "[VideoManager]" << "startVideo"
            << "id" << id
            << "source" << _videoSettings->videoSource()->rawValue().toString()
            << "rtsp" << _videoSettings->rtspUrl()->rawValue().toString()
            << "configured" << configured
            << "videoUri0" << _videoUri[0];
    if(!configured) {
        qCDebug(VideoManagerLog) << "[VideoManager]" << "startVideo skipped: stream not configured";
        return;
    }

    if(id < 0) {
        _startReceiver(0);
        _startReceiver(1);
    } else {
        _startReceiver(static_cast<uint>(id));
    }
}

//-----------------------------------------------------------------------------
void
VideoManager::stopVideo(int id)
{
    if (qgcApp()->runningUnitTests()) {
        return;
    }

    if(id < 0) {
        _stopReceiver(2);
        _stopReceiver(1);
        _stopReceiver(0);
    } else {
        _stopReceiver(static_cast<uint>(id));
    }
}

void
VideoManager::startRecording(const QString& videoFile)
{
    if (qgcApp()->runningUnitTests()) {
        return;
    }
#if defined(QGC_GST_STREAMING)
    if (!_videoReceiver[0]) {
        qgcApp()->showAppMessage(tr("Video receiver is not ready."));
        return;
    }

    const VideoReceiver::FILE_FORMAT fileFormat = static_cast<VideoReceiver::FILE_FORMAT>(_videoSettings->recordingFormat()->rawValue().toInt());

    if(fileFormat < VideoReceiver::FILE_FORMAT_MIN || fileFormat >= VideoReceiver::FILE_FORMAT_MAX) {
        qgcApp()->showAppMessage(tr("Invalid video format defined."));
        return;
    }
    QString ext = kFileExtension[fileFormat - VideoReceiver::FILE_FORMAT_MIN];

    //-- Disk usage maintenance
    _cleanupOldVideos();

    QString savePath = qgcApp()->toolbox()->settingsManager()->appSettings()->videoSavePath();

    if (savePath.isEmpty()) {
        qgcApp()->showAppMessage(tr("Unabled to record video. Video save path must be specified in Settings."));
        return;
    }

    _videoFile = savePath + "/"
            + (videoFile.isEmpty() ? QDateTime::currentDateTime().toString("yyyy-MM-dd_hh.mm.ss") : videoFile)
            + ".";
    QString videoFile2 = _videoFile + "2." + ext;
    _videoFile += ext;

    if (_videoReceiver[0] && _videoStarted[0]) {
        _videoReceiver[0]->startRecording(_videoFile, fileFormat);
    }
    if (_videoReceiver[1] && _videoStarted[1]) {
        _videoReceiver[1]->startRecording(videoFile2, fileFormat);
    }

#else
    Q_UNUSED(videoFile)
#endif
}

void
VideoManager::stopRecording()
{
    if (qgcApp()->runningUnitTests()) {
        return;
    }
#if defined(QGC_GST_STREAMING)

    for (int i = 0; i < 2; i++) {
        if (_videoReceiver[i]) {
            _videoReceiver[i]->stopRecording();
        }
    }
#endif
}

void
VideoManager::grabImage(const QString& imageFile)
{
    if (qgcApp()->runningUnitTests()) {
        return;
    }
#if defined(QGC_GST_STREAMING)
    if (!_videoReceiver[0]) {
        return;
    }

    if (imageFile.isEmpty()) {
        _imageFile = qgcApp()->toolbox()->settingsManager()->appSettings()->photoSavePath();
        _imageFile += + "/" + QDateTime::currentDateTime().toString("yyyy-MM-dd_hh.mm.ss.zzz") + ".jpg";
    } else {
        _imageFile = imageFile;
    }

    emit imageFileChanged();

    _videoReceiver[0]->takeScreenshot(_imageFile);
#else
    Q_UNUSED(imageFile)
#endif
}

//-----------------------------------------------------------------------------
double VideoManager::aspectRatio()
{
    if(_activeVehicle && _activeVehicle->cameraManager()) {
        QGCVideoStreamInfo* pInfo = _activeVehicle->cameraManager()->currentStreamInstance();
        if(pInfo) {
            qCDebug(VideoManagerLog) << "Primary AR: " << pInfo->aspectRatio();
            return pInfo->aspectRatio();
        }
    }
    // FIXME: AV: use _videoReceiver->videoSize() to calculate AR (if AR is not specified in the settings?)
    return _videoSettings->aspectRatio()->rawValue().toDouble();
}

//-----------------------------------------------------------------------------
double VideoManager::thermalAspectRatio()
{
    if(_activeVehicle && _activeVehicle->cameraManager()) {
        QGCVideoStreamInfo* pInfo = _activeVehicle->cameraManager()->thermalStreamInstance();
        if(pInfo) {
            qCDebug(VideoManagerLog) << "Thermal AR: " << pInfo->aspectRatio();
            return pInfo->aspectRatio();
        }
    }
    return 1.0;
}

//-----------------------------------------------------------------------------
double VideoManager::hfov()
{
    if(_activeVehicle && _activeVehicle->cameraManager()) {
        QGCVideoStreamInfo* pInfo = _activeVehicle->cameraManager()->currentStreamInstance();
        if(pInfo) {
            return pInfo->hfov();
        }
    }
    return 1.0;
}

//-----------------------------------------------------------------------------
double VideoManager::thermalHfov()
{
    if(_activeVehicle && _activeVehicle->cameraManager()) {
        QGCVideoStreamInfo* pInfo = _activeVehicle->cameraManager()->thermalStreamInstance();
        if(pInfo) {
            return pInfo->aspectRatio();
        }
    }
    return _videoSettings->aspectRatio()->rawValue().toDouble();
}

//-----------------------------------------------------------------------------
bool
VideoManager::hasThermal()
{
    if(_activeVehicle && _activeVehicle->cameraManager()) {
        QGCVideoStreamInfo* pInfo = _activeVehicle->cameraManager()->thermalStreamInstance();
        if(pInfo) {
            return true;
        }
    }
    return false;
}

//-----------------------------------------------------------------------------
QString
VideoManager::imageFile()
{
    return _imageFile;
}

//-----------------------------------------------------------------------------
bool
VideoManager::autoStreamConfigured()
{
#if defined(QGC_GST_STREAMING)
    if(_activeVehicle && _activeVehicle->cameraManager()) {
        QGCVideoStreamInfo* pInfo = _activeVehicle->cameraManager()->currentStreamInstance();
        if(pInfo) {
            return !pInfo->uri().isEmpty();
        }
    }
#endif
    return false;
}

//-----------------------------------------------------------------------------
void
VideoManager::_updateUVC()
{
#ifndef QGC_DISABLE_UVC
    QString oldUvcVideoSrcID = _uvcVideoSourceID;
    if (!hasVideo() || isGStreamer()) {
        _uvcVideoSourceID = "";
    } else {
        QString videoSource = _videoSettings->videoSource()->rawValue().toString();
        QList<QCameraInfo> cameras = QCameraInfo::availableCameras();
        for (const QCameraInfo &cameraInfo : cameras) {
            if (cameraInfo.description() == videoSource) {
                _uvcVideoSourceID = cameraInfo.deviceName();
                qCDebug(VideoManagerLog)
                    << "Found USB source:" << _uvcVideoSourceID << " Name:" << videoSource;
                break;
            }
        }
    }

    if (oldUvcVideoSrcID != _uvcVideoSourceID) {
        qCDebug(VideoManagerLog) << "UVC changed from [" << oldUvcVideoSrcID << "] to [" << _uvcVideoSourceID << "]";
        emit uvcVideoSourceIDChanged();
        emit isUvcChanged();
    }

#endif
}

//-----------------------------------------------------------------------------
void
VideoManager::_videoSourceChanged()
{
    qCDebug(VideoManagerLog) << "[VideoManager]" << "_videoSourceChanged"
            << "source" << _videoSettings->videoSource()->rawValue().toString()
            << "rtsp" << _videoSettings->rtspUrl()->rawValue().toString();
    _updateUVC();
    _updateSettings(0);
    emit hasVideoChanged();
    emit isGStreamerChanged();
    emit isUvcChanged();
    emit isAutoStreamChanged();
    if (hasVideo()) {
        _restartVideo(0);
    } else {
        stopVideo();
    }
}

//-----------------------------------------------------------------------------
void
VideoManager::_udpPortChanged()
{
    _restartVideo(0);
}

//-----------------------------------------------------------------------------
void
VideoManager::_rtspUrlChanged()
{
    const QString source = _videoSettings->videoSource()->rawValue().toString();
    const QString rtsp   = _videoSettings->rtspUrl()->rawValue().toString();

    qCDebug(VideoManagerLog) << "[VideoManager]" << "_rtspUrlChanged"
            << "source" << source
            << "rtsp" << rtsp
            << "currentUri" << _videoUri[0];
    _restartVideo(0);
}

//-----------------------------------------------------------------------------
void
VideoManager::_tcpUrlChanged()
{
    _restartVideo(0);
}

//-----------------------------------------------------------------------------
void
VideoManager::_lowLatencyModeChanged()
{
    _restartAllVideos();
}

void VideoManager::_fpvChanged()
{
    _restartFPV();
}

void VideoManager::_streamEnabledChanged()
{
    if(_videoSettings->streamEnabled()->rawValue().toBool()) {
        _restartVideo(0);
        _restartVideo(1);
        _restartFPV();
    } else {
        stopVideo(0);
        stopVideo(1);
        _stopReceiver(2);
    }
}

//-----------------------------------------------------------------------------
bool
VideoManager::hasVideo()
{
    if(autoStreamConfigured()) {
        return true;
    }
    QString videoSource = _videoSettings->videoSource()->rawValue().toString();
    return !videoSource.isEmpty() && videoSource != VideoSettings::videoSourceNoVideo && videoSource != VideoSettings::videoDisabled;
}

//-----------------------------------------------------------------------------
bool
VideoManager::isGStreamer()
{
#if defined(QGC_GST_STREAMING)
    QString videoSource = _videoSettings->videoSource()->rawValue().toString();
    return videoSource == VideoSettings::videoSourceUDPH264 ||
            videoSource == VideoSettings::videoSourceUDPH265 ||
            videoSource == VideoSettings::videoSourceRTSP ||
            videoSource == VideoSettings::videoSourceTCP ||
            videoSource == VideoSettings::videoSourceMPEGTS ||
            videoSource == VideoSettings::videoSource3DRSolo ||
            videoSource == VideoSettings::videoSourceParrotDiscovery ||
            videoSource == VideoSettings::videoSourceYuneecMantisG ||
            videoSource == VideoSettings::videoSourceHerelinkAirUnit ||
            videoSource == VideoSettings::videoSourceHerelinkHotspot ||
            autoStreamConfigured();
#else
    return false;
#endif
}

bool
VideoManager::isUvc()
{
#ifndef QGC_DISABLE_UVC
    auto isUvc = hasVideo() && !_uvcVideoSourceID.isEmpty();
    qCDebug(VideoManagerLog) << "Is Video source UVC: " << (isUvc ? "yes" : "no");
    return isUvc;
#else
    return false;
#endif
}

//-----------------------------------------------------------------------------
#ifndef QGC_DISABLE_UVC
bool
VideoManager::uvcEnabled()
{
    return QCameraInfo::availableCameras().count() > 0;
}
#endif

//-----------------------------------------------------------------------------
void
VideoManager::setfullScreen(bool f)
{
    if(f) {
        //-- No can do if no vehicle or connection lost
        if(!_activeVehicle || _activeVehicle->vehicleLinkManager()->communicationLost()) {
            f = false;
        }
    }
    _fullScreen = f;
    emit fullScreenChanged();
}

//-----------------------------------------------------------------------------
void
VideoManager::_initVideo()
{
#if defined(QGC_GST_STREAMING)
    QQuickWindow* root = qgcApp()->mainRootWindow();

    if (root == nullptr) {
        qCDebug(VideoManagerLog) << "mainRootWindow() failed. No root window";
        return;
    }

    QObject* widget = root->findChild<QObject*>("videoContent");

    if (widget != nullptr && _videoReceiver[0] != nullptr) {
        qCDebug(VideoManagerLog) << "[VideoManager]" << "initVideo" << "videoContent widget found";
        _videoSink[0] = qgcApp()->toolbox()->corePlugin()->createVideoSink(this, widget);
        if (_videoSink[0] != nullptr) {
            qCDebug(VideoManagerLog) << "[VideoManager]" << "initVideo" << "video0 sink created" << _videoSink[0];
            if (_deferPrimaryStartUntilSinkReady && !_videoStarted[0]) {
                qCDebug(VideoManagerLog) << "[VideoManager]" << "initVideo"
                        << "video0 starting deferred receiver now that sink is ready";
                _deferPrimaryStartUntilSinkReady = false;
                _startReceiver(0);
            } else if (_videoStarted[0]) {
                if (_restartPrimaryOnSinkReady) {
                    qCDebug(VideoManagerLog) << "[VideoManager]" << "initVideo"
                            << "video0 restarting receiver after late sink creation";
                    _restartPrimaryOnSinkReady = false;
                    _stopReceiver(0);
                } else {
                    qCDebug(VideoManagerLog) << "[VideoManager]" << "initVideo" << "video0 already started, begin decoding";
                    _videoReceiver[0]->startDecoding(_videoSink[0]);
                }
            }
        } else {
            qCWarning(VideoManagerLog) << "[VideoManager]" << "initVideo" << "video0 createVideoSink failed";
        }
    } else {
        qCWarning(VideoManagerLog) << "[VideoManager]" << "initVideo"
                   << "video0 receiver disabled"
                   << "widget" << widget
                   << "receiver" << _videoReceiver[0];
    }

    widget = root->findChild<QObject*>("thermalVideo");

    if (widget != nullptr && _videoReceiver[1] != nullptr) {
        qCDebug(VideoManagerLog) << "THERMAL_TRACE"
                << "initVideo.thermalWidget"
                << "widgetFound" << true
                << "receiver" << _videoReceiver[1]
                << "started" << _videoStarted[1]
                << "uri" << _videoUri[1];
        _videoSink[1] = qgcApp()->toolbox()->corePlugin()->createVideoSink(this, widget);
        if (_videoSink[1] != nullptr) {
            qCDebug(VideoManagerLog) << "THERMAL_TRACE"
                    << "initVideo.thermalSinkCreated"
                    << "sink" << _videoSink[1]
                    << "started" << _videoStarted[1];
            if (_videoStarted[1]) {
                _videoReceiver[1]->startDecoding(_videoSink[1]);
            }
        } else {
            qCDebug(VideoManagerLog) << "createVideoSink() failed";
            qCDebug(VideoManagerLog) << "THERMAL_TRACE" << "initVideo.thermalSinkCreated" << "sink" << nullptr;
        }
    } else {
        qCDebug(VideoManagerLog) << "thermal video receiver disabled";
        qCDebug(VideoManagerLog) << "THERMAL_TRACE"
                << "initVideo.thermalWidget"
                << "widgetFound" << (widget != nullptr)
                << "receiver" << _videoReceiver[1]
                << "started" << _videoStarted[1]
                << "uri" << _videoUri[1];
    }

    widget = root->findChild<QObject*>("fpvContent");

    if (widget != nullptr && _videoReceiver[2] != nullptr) {
        _videoSink[2] = qgcApp()->toolbox()->corePlugin()->createVideoSink(this, widget);
        if (_videoSink[2] != nullptr) {
            if (_videoStarted[2]) {
                _videoReceiver[2]->startDecoding(_videoSink[2]);
            }
        } else {
            qCDebug(VideoManagerLog) << "createVideoSink() failed";
        }
    } else {
        qCDebug(VideoManagerLog) << "fpv video receiver disabled";
    }
#endif
}

//-----------------------------------------------------------------------------
bool
VideoManager::_updateSettings(unsigned id)
{
    if(!_videoSettings)
        return false;

    const bool oldLowLatencyStreaming = _lowLatencyStreaming[id];
    const bool lowLatencyStreaming  = _videoSettings->lowLatencyMode()->rawValue().toBool();

    bool settingsChanged = oldLowLatencyStreaming != lowLatencyStreaming;

    _lowLatencyStreaming[id] = lowLatencyStreaming;
    if (id == 0 && oldLowLatencyStreaming != lowLatencyStreaming) {
        emit lowLatencyActiveChanged();
    }

    //-- Auto discovery

    if(_activeVehicle && _activeVehicle->cameraManager()) {
        QGCVideoStreamInfo* pInfo = _activeVehicle->cameraManager()->currentStreamInstance();
        if(pInfo) {
            if (id == 0) {
                qCDebug(VideoManagerLog) << "Configure primary stream:" << pInfo->uri();
                switch(pInfo->type()) {
                    case VIDEO_STREAM_TYPE_RTSP:
                    {
                        const QString discoveredRtspUrl = pInfo->uri();
                        if ((settingsChanged |= _updateVideoUri(id, discoveredRtspUrl))) {
                            _toolbox->settingsManager()->videoSettings()->videoSource()->setRawValue(VideoSettings::videoSourceRTSP);
                        }
                        if (!discoveredRtspUrl.isEmpty() &&
                            _toolbox->settingsManager()->videoSettings()->rtspUrl()->rawValue().toString() != discoveredRtspUrl) {
                            _toolbox->settingsManager()->videoSettings()->rtspUrl()->setRawValue(discoveredRtspUrl);
                        }
                        break;
                    }
                    case VIDEO_STREAM_TYPE_TCP_MPEG:
                        if ((settingsChanged |= _updateVideoUri(id, pInfo->uri()))) {
                            _toolbox->settingsManager()->videoSettings()->videoSource()->setRawValue(VideoSettings::videoSourceTCP);
                        }
                        break;
                    case VIDEO_STREAM_TYPE_RTPUDP:
                        if ((settingsChanged |= _updateVideoUri(
                                        id,
                                        pInfo->uri().contains("udp://")
                                            ? pInfo->uri() // Specced case
                                            : QStringLiteral("udp://0.0.0.0:%1").arg(pInfo->uri())))) {
                            _toolbox->settingsManager()->videoSettings()->videoSource()->setRawValue(VideoSettings::videoSourceUDPH264);
                        }
                        break;
                    case VIDEO_STREAM_TYPE_MPEG_TS_H264:
                        if ((settingsChanged |= _updateVideoUri(id, QStringLiteral("mpegts://0.0.0.0:%1").arg(pInfo->uri())))) {
                            _toolbox->settingsManager()->videoSettings()->videoSource()->setRawValue(VideoSettings::videoSourceMPEGTS);
                        }
                        break;
                    default:
                        settingsChanged |= _updateVideoUri(id, pInfo->uri());
                        break;
                }
            }
            else if (id == 1) { //-- Thermal stream (if any)
                QGCVideoStreamInfo* pTinfo = _activeVehicle->cameraManager()->thermalStreamInstance();
                if (pTinfo) {
                    qCDebug(VideoManagerLog) << "Configure secondary stream:" << pTinfo->uri();
                    qCDebug(VideoManagerLog) << "THERMAL_TRACE"
                            << "updateSettings.thermal"
                            << "streamId" << pTinfo->streamID()
                            << "type" << pTinfo->type()
                            << "uri" << pTinfo->uri()
                            << "started" << _videoStarted[id];
                    switch(pTinfo->type()) {
                        case VIDEO_STREAM_TYPE_RTSP:
                        case VIDEO_STREAM_TYPE_TCP_MPEG:
                            settingsChanged |= _updateVideoUri(id, pTinfo->uri());
                            break;
                        case VIDEO_STREAM_TYPE_RTPUDP:
                            settingsChanged |= _updateVideoUri(id, QStringLiteral("udp://0.0.0.0:%1").arg(pTinfo->uri()));
                            break;
                        case VIDEO_STREAM_TYPE_MPEG_TS_H264:
                            settingsChanged |= _updateVideoUri(id, QStringLiteral("mpegts://0.0.0.0:%1").arg(pTinfo->uri()));
                            break;
                        default:
                            settingsChanged |= _updateVideoUri(id, pTinfo->uri());
                            break;
                    }
                } else if (id == 1) {
                    qCDebug(VideoManagerLog) << "THERMAL_TRACE"
                            << "updateSettings.thermal"
                            << "streamId" << -1
                            << "type" << -1
                            << "uri" << QStringLiteral("null")
                            << "started" << _videoStarted[id];
                }
            }
            return settingsChanged;
        }
    }
    QString source = _videoSettings->videoSource()->rawValue().toString();
    if (source == VideoSettings::videoSourceUDPH264)
        settingsChanged |= _updateVideoUri(0, QStringLiteral("udp://0.0.0.0:%1").arg(_videoSettings->udpPort()->rawValue().toInt()));
    else if (source == VideoSettings::videoSourceUDPH265)
        settingsChanged |= _updateVideoUri(0, QStringLiteral("udp265://0.0.0.0:%1").arg(_videoSettings->udpPort()->rawValue().toInt()));
    else if (source == VideoSettings::videoSourceMPEGTS)
        settingsChanged |= _updateVideoUri(0, QStringLiteral("mpegts://0.0.0.0:%1").arg(_videoSettings->udpPort()->rawValue().toInt()));
    else if (source == VideoSettings::videoSourceRTSP)
        settingsChanged |= _updateVideoUri(0, _videoSettings->rtspUrl()->rawValue().toString());
    else if (source == VideoSettings::videoSourceTCP)
        settingsChanged |= _updateVideoUri(0, QStringLiteral("tcp://%1").arg(_videoSettings->tcpUrl()->rawValue().toString()));
    else if (source == VideoSettings::videoSource3DRSolo)
        settingsChanged |= _updateVideoUri(0, QStringLiteral("udp://0.0.0.0:5600"));
    else if (source == VideoSettings::videoSourceParrotDiscovery)
        settingsChanged |= _updateVideoUri(0, QStringLiteral("udp://0.0.0.0:8888"));
    else if (source == VideoSettings::videoSourceYuneecMantisG)
        settingsChanged |= _updateVideoUri(0, QStringLiteral("rtsp://192.168.42.1:554/live"));
    else if (source == VideoSettings::videoSourceHerelinkAirUnit)
        settingsChanged |= _updateVideoUri(0, QStringLiteral("rtsp://192.168.0.10:8554/H264Video"));
    else if (source == VideoSettings::videoSourceHerelinkHotspot)
        settingsChanged |= _updateVideoUri(0, QStringLiteral("rtsp://192.168.43.1:8554/fpv_stream"));
    else if (source == VideoSettings::videoDisabled || source == VideoSettings::videoSourceNoVideo)
        settingsChanged |= _updateVideoUri(0, "");
    else {
        settingsChanged |= _updateVideoUri(0, "");
        if (!isUvc()) {
            qCCritical(VideoManagerLog)
                << "Video source URI \"" << source << "\" is not supported. Please add support!";
        }
    }

    qCDebug(VideoManagerLog) << "[VideoManager]" << "_updateSettings"
            << "id" << id
            << "source" << source
            << "rtsp" << _videoSettings->rtspUrl()->rawValue().toString()
            << "videoUri" << _videoUri[0]
            << "settingsChanged" << settingsChanged;

    return settingsChanged;
}

//-----------------------------------------------------------------------------
bool
VideoManager::_updateVideoUri(unsigned id, const QString& uri)
{
// #if defined(QGC_GST_TAISYNC_ENABLED) && (defined(__android__) || defined(__ios__))
//     //-- Taisync on iOS or Android sends a raw h.264 stream
//     if (isTaisync()) {
//         if (id == 0) {
//             return _updateVideoUri(0, QString("tsusb://0.0.0.0:%1").arg(TAISYNC_VIDEO_UDP_PORT));
//         } if (id == 1) {
//             // FIXME: AV: TAISYNC_VIDEO_UDP_PORT is used by video stream, thermal stream should go via its own proxy
//             if (!_videoUri[1].isEmpty()) {
//                 _videoUri[1].clear();
//                 return true;
//             } else {
//                 return false;
//             }
//         }
//     }
// #endif
    if (uri == _videoUri[id]) {
        return false;
    }

    _videoUri[id] = uri;

    return true;
}

//-----------------------------------------------------------------------------
void
VideoManager::_restartVideo(unsigned id)
{
#if !defined(QGC_GST_STREAMING)
    Q_UNUSED(id);
#endif

    if (qgcApp()->runningUnitTests()) {
        return;
    }

#if defined(QGC_GST_STREAMING)
    bool oldLowLatencyStreaming = _lowLatencyStreaming[id];
    QString oldUri = _videoUri[id];
    _updateSettings(id);
    bool newLowLatencyStreaming = _lowLatencyStreaming[id];
    QString newUri = _videoUri[id];
    qCDebug(VideoManagerLog) << "[VideoManager]" << "_restartVideo"
            << "id" << id
            << "oldUri" << oldUri
            << "newUri" << newUri
            << "started" << _videoStarted[id]
            << "oldLowLatency" << oldLowLatencyStreaming
            << "newLowLatency" << newLowLatencyStreaming;
    if (id == 1) {
        qCDebug(VideoManagerLog) << "THERMAL_TRACE"
                << "restartVideo"
                << "id" << id
                << "oldUri" << oldUri
                << "newUri" << newUri
                << "started" << _videoStarted[id]
                << "sink" << _videoSink[id]
                << "receiver" << _videoReceiver[id];
    }
    qCDebug(VideoManagerLog) << "New Video URI " << newUri;
    // A camera unplug/replug can leave the backend stream dead even when the URI and mode
    // are unchanged, so a requested restart must always restart the receiver.

    qCDebug(VideoManagerLog) << "Restart video streaming"  << id;

    if (_videoStarted[id]) {
        _stopReceiver(id);
    } else {
        _startReceiver(id);
    }
#endif
}

void VideoManager::_restartFPV()
{
    if (qgcApp()->runningUnitTests()) {
        return;
    }

#if defined(QGC_GST_STREAMING)
    bool oldLowLatencyStreaming = _lowLatencyStreaming[2];
    QString oldUri = _videoUri[2];
    if(!_videoSettings->disableFPVVideo()->rawValue().toBool()) {
        _videoUri[2] = _videoSettings->fpvUrl()->rawValue().toString();
    } else {
        _videoUri[2] = "";
    }
    _lowLatencyStreaming[2] = false;
    bool newLowLatencyStreaming = _lowLatencyStreaming[2];
    QString newUri = _videoUri[2];

    // FIXME: AV: use _updateSettings() result to check if settings were changed
    if (oldUri == newUri && oldLowLatencyStreaming == newLowLatencyStreaming && _videoStarted[2]) {
        qCDebug(VideoManagerLog) << "No sense to restart video streaming, skipped"  << 2;
        return;
    }

    qCDebug(VideoManagerLog) << "Restart video streaming"  << 2;

    if (_videoStarted[2]) {
        _stopReceiver(2);
    } else {
        _startReceiver(2);
    }
#endif
}

//-----------------------------------------------------------------------------
void
VideoManager::_restartAllVideos()
{
    _restartVideo(0);
    _restartVideo(1);
    qCDebug(VideoManagerLog) << "THERMAL_TRACE"
            << "hasThermalChanged"
            << "value" << hasThermal();
    emit hasThermalChanged();
    emit aspectRatioChanged();
}

//----------------------------------------------------------------------------------------
void
VideoManager::_startReceiver(unsigned id)
{
#if defined(QGC_GST_STREAMING)
    if(!_videoSettings->streamEnabled()->rawValue().toBool()) return;
    const QString source = _videoSettings->videoSource()->rawValue().toString();
    const unsigned rtsptimeout = _videoSettings->rtspTimeout()->rawValue().toUInt();
    /* The gstreamer rtsp source will switch to tcp if udp is not available after 5 seconds.
       So we should allow for some negotiation time for rtsp */
    const unsigned timeout = (source == VideoSettings::videoSourceRTSP ? rtsptimeout : 10 );

    qCDebug(VideoManagerLog) << "[VideoManager]" << "_startReceiver"
            << "id" << id
            << "source" << source
            << "rtsp" << _videoSettings->rtspUrl()->rawValue().toString()
            << "uri" << _videoUri[id]
            << "timeout" << timeout
            << "lowLatency" << _lowLatencyStreaming[id];
    const int bufferSetting = _lowLatencyStreaming[id] ? (_legacyRockchipStreaming ? -1 : 80) : 0;
    if (id == 0 && _activeVideoBufferMs != bufferSetting) {
        _activeVideoBufferMs = bufferSetting;
        emit activeVideoBufferMsChanged();
    }
    if (id > 2) {
        qCDebug(VideoManagerLog) << "Unsupported receiver id" << id;
    } else if (_videoReceiver[id] != nullptr/* && _videoSink[id] != nullptr*/) {
        if (id == 0 && _videoSink[0] == nullptr) {
            _deferPrimaryStartUntilSinkReady = true;
            qCDebug(VideoManagerLog) << "[VideoManager]" << "_startReceiver"
                    << "id" << id
                    << "deferred until primary sink is ready";
            return;
        }
        if (!_videoUri[id].isEmpty()) {
            if (id == 0) {
                _deferPrimaryStartUntilSinkReady = false;
            }
            qCDebug(VideoManagerLog) << "[VideoManager]" << "_startReceiver"
                    << "id" << id
                    << "bufferSetting" << bufferSetting;
            _videoReceiver[id]->start(_videoUri[id], timeout, bufferSetting);
        }
    }
#else
    Q_UNUSED(id);
#endif
}

//----------------------------------------------------------------------------------------
void
VideoManager::_stopReceiver(unsigned id)
{
#if defined(QGC_GST_STREAMING)
    if (id > 2) {
        qCDebug(VideoManagerLog) << "Unsupported receiver id" << id;
    } else if (_videoReceiver[id] != nullptr) {
        if (id == 0) {
            _deferPrimaryStartUntilSinkReady = false;
        }
        _videoReceiver[id]->stop();
    }
#else
    Q_UNUSED(id);
#endif
}

//----------------------------------------------------------------------------------------
void
VideoManager::_setActiveVehicle(Vehicle* vehicle)
{
    if(_activeVehicle) {
        disconnect(_activeVehicle->vehicleLinkManager(), &VehicleLinkManager::communicationLostChanged, this, &VideoManager::_communicationLostChanged);
        if(_activeVehicle->cameraManager()) {
            auto pCamera = _activeVehicle->cameraManager()->currentCameraInstance();
            if(pCamera) {
                disconnect(pCamera, &QGCCameraControl::thermalModeChanged, this, &VideoManager::_thermalModeChanged);
                pCamera->stopStream();
            }
            disconnect(_activeVehicle->cameraManager(), &QGCCameraManager::streamChanged, this, &VideoManager::_restartAllVideos);
        }
    }
    _activeVehicle = vehicle;
    if(_activeVehicle) {
        connect(_activeVehicle->vehicleLinkManager(), &VehicleLinkManager::communicationLostChanged, this, &VideoManager::_communicationLostChanged);
        if(_activeVehicle->cameraManager()) {
            connect(_activeVehicle->cameraManager(), &QGCCameraManager::streamChanged, this, &VideoManager::_restartAllVideos);
            auto pCamera = _activeVehicle->cameraManager()->currentCameraInstance();
            if(pCamera) {
                qCDebug(VideoManagerLog) << "THERMAL_TRACE"
                        << "setActiveVehicle"
                        << "camera" << pCamera->modelName()
                        << "thermalMode" << static_cast<int>(pCamera->thermalMode())
                        << "hasThermalStream" << (pCamera->thermalStreamInstance() != nullptr)
                        << "currentStream" << (pCamera->currentStreamInstance() ? pCamera->currentStreamInstance()->streamID() : -1)
                        << "thermalStream" << (pCamera->thermalStreamInstance() ? pCamera->thermalStreamInstance()->streamID() : -1);
                connect(pCamera, &QGCCameraControl::thermalModeChanged, this, &VideoManager::_thermalModeChanged);
                pCamera->resumeStream();
            }
        }
    } else {
        //-- Disable full screen video if vehicle is gone
        setfullScreen(false);
    }
    emit autoStreamConfiguredChanged();
    qCDebug(VideoManagerLog) << "THERMAL_TRACE"
            << "hasThermalChanged"
            << "value" << hasThermal();
    emit hasThermalChanged();
    _restartAllVideos();
}

//----------------------------------------------------------------------------------------
void
VideoManager::_communicationLostChanged(bool connectionLost)
{
    if(connectionLost) {
        //-- Disable full screen video if connection is lost
        setfullScreen(false);
    }
}

//----------------------------------------------------------------------------------------
void
VideoManager::_thermalModeChanged()
{
#if defined(QGC_GST_STREAMING)
    if (!_activeVehicle || !_activeVehicle->cameraManager()) {
        return;
    }

    auto pCamera = _activeVehicle->cameraManager()->currentCameraInstance();
    if (!pCamera || pCamera->thermalMode() == QGCCameraControl::THERMAL_OFF) {
        return;
    }

    qCDebug(VideoManagerLog) << "[VideoManager]" << "_thermalModeChanged"
            << "mode" << static_cast<int>(pCamera->thermalMode())
            << "started" << _videoStarted[1]
            << "uri" << _videoUri[1];
    qCDebug(VideoManagerLog) << "THERMAL_TRACE"
            << "thermalModeChanged"
            << "mode" << static_cast<int>(pCamera->thermalMode())
            << "started" << _videoStarted[1]
            << "uri" << _videoUri[1]
            << "hasThermalStream" << (pCamera->thermalStreamInstance() != nullptr);

    if (_videoStarted[1]) {
        _stopReceiver(1);
    } else {
        _restartVideo(1);
    }
#endif
}

//----------------------------------------------------------------------------------------
void
VideoManager::_aspectRatioChanged()
{
    emit aspectRatioChanged();
}
