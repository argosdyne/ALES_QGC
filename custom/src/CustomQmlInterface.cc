#include "CustomQmlInterface.h"
#include "CustomPlugin.h"
#include "LinkManager.h"
#include "CodevRTCMManager.h"
#include "AVIATORInterface.h"
#include "Vehicle.h"
#include "MultiVehicleManager.h"
#include "QGCCameraManager.h"
#include "CodevCameraControl.h"
#include <QCoreApplication>
#include <QLocale>

namespace {

CodevCameraControl* _activeCodevCamera(QGCToolbox* toolbox)
{
    if (!toolbox || !toolbox->multiVehicleManager()) {
        return nullptr;
    }
    Vehicle* vehicle = toolbox->multiVehicleManager()->activeVehicle();
    if (!vehicle || !vehicle->cameraManager()) {
        return nullptr;
    }
    return qobject_cast<CodevCameraControl*>(vehicle->cameraManager()->currentCameraInstance());
}

} // namespace

#define CHAR_NUMBER_EACH_ROW 30

CustomQmlInterface::CustomQmlInterface(QGCApplication* app, QGCToolbox* toolbox)
    : QGCTool(app, toolbox)
    , _plugin(qobject_cast<CustomPlugin*>(toolbox->corePlugin()))
    , _arManager(new ARManager(app, toolbox))
    , _codevRTCMManager(new CodevRTCMManager(app, toolbox))    
{

    // We clear the parent on this object since we run into shutdown problems caused by hybrid qml app. Instead we let it leak on shutdown.
    setParent(nullptr);
    setToolbox(toolbox);

    //Check latest map cache update date & time
    //showMapUpdateDate();

    qInfo() << "CusstomQmlInterface showmessage";



    QTimer::singleShot(3000, this, SLOT(showMapUpdateDate()));

}
static const char* kDbFileName = "qgcMapCache.db";
#define CACHE_PATH_VERSION  "300"

namespace {
bool _isMapDownloadMessage(const QString& message)
{
    static const char* kSourceText = "Please download the map of the flight area.";
    if (message.contains(QLatin1String(kSourceText))) {
        return true;
    }
    const QString translated = QCoreApplication::translate("QGeoTiledMapReplyQGC", kSourceText);
    return translated != QLatin1String(kSourceText) && message.contains(translated);
}
}

void CustomQmlInterface::showMapUpdateDate(){
#ifdef __mobile__
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)      + QLatin1String("/QGCMapCache" CACHE_PATH_VERSION);
#else
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + QStringLiteral("/QGCMapCache" CACHE_PATH_VERSION);
#endif
    _cachePath = cacheDir;
    if(!_cachePath.isEmpty()) {
        _cacheFile = kDbFileName;
    }

    QString fullCachePath = _cachePath + "/" + _cacheFile;
    QFileInfo cacheFileInfo(fullCachePath);
    if (cacheFileInfo.exists()) {
        QDateTime lastModified = cacheFileInfo.lastModified();
        QString msg = tr("Map tiles updated at %1").arg(QLocale().toString(lastModified, QLocale::ShortFormat));
        showMessage(msg, SystemMessage::Info);
    }
}

CustomQmlInterface::~CustomQmlInterface()
{
}

CustomQmlInterface* CustomQmlInterface::_instance = nullptr;

CustomQmlInterface* CustomQmlInterface::instance() {
    return _instance;
}
void CustomQmlInterface::setInstance(CustomQmlInterface* instance) {
    _instance = instance;
}

void CustomQmlInterface::setToolbox(QGCToolbox* toolbox)
{
    QGCTool::setToolbox(toolbox);
    qRegisterMetaType<SystemMessage::SystemMessageType>("SystemMessage::SystemMessageType");

    _arManager->setToolbox(toolbox);
    _codevRTCMManager->setToolbox(toolbox);

    //-- Check for persistent slave mode
    if(_plugin->slaveMode()) {
        _slaveModeChanged(true);
    } else {
        //-- Reset Slave Link
        _toolbox->settingsManager()->appSettings()->audioMuted()->setRawValue(false);
    }
    connect(_plugin, &CustomPlugin::slaveModeChanged, this, &CustomQmlInterface::_slaveModeChanged);

#if defined(ENABLE_WIFI_P2P)
    connect(qgcApp(), &QGCApplication::teamModeLocalNameChanged, _teamModeRouter, &TeamModeRouter::setLocalDeviceName);
    connect(qgcApp(), &QGCApplication::teamModeConnectionChanged, _teamModeRouter, &TeamModeRouter::p2pConnectStateChanged);
    connect(qgcApp(), &QGCApplication::teamModeDeviceListChanged, _teamModeRouter, &TeamModeRouter::newP2PDevices);
    connect(qgcApp(), &QGCApplication::teamModeConnectionChanged, this, &CustomQmlInterface::_p2pConnectionStateChanged);
#endif

}

void CustomQmlInterface::playActionSound()
{
    if(_actionSound.isPlaying()) return;
    _actionSound.setLoopCount(1);
    _actionSound.play();
}

void CustomQmlInterface::_slaveModeChanged(bool slaveMode)
{
    // _teamModeLinkconfig.reset();
    // if(slaveMode) {
    //     //-- Stop auto connect and disconnect all links
    //     LinkManager* pLinkMgr = _toolbox->linkManager();
    //     pLinkMgr->setConnectionsSuspended(QString(tr("Switching to Slave Mode")));
    //     pLinkMgr->disconnectAll();
    //     //-- Set Slave Link
    //     _toolbox->settingsManager()->appSettings()->audioMuted()->setRawValue(false);
    //     _toolbox->settingsManager()->autoConnectSettings()->autoConnectUDP()->setRawValue(false);
    //     _toolbox->settingsManager()->autoConnectSettings()->disableConnectSerial()->setRawValue(true);
    //     TeamModeConfiguration* teammodeConfig = new TeamModeConfiguration("TeamMode Link");
    //     //UDPConfiguration* udpConfig = new UDPConfiguration("UDP Link (AutoConnect)");
    //     teammodeConfig->setDynamic(true);
    //     teammodeConfig->setAutoConnect(true);
    //     teammodeConfig->setHighLatency(true);
    //     teammodeConfig->setLocalPort(DEFAULT_REMOTE_PORT_UDP_QGC_SLAVE);
    //     _teamModeLinkconfig = pLinkMgr->addConfiguration(teammodeConfig);
    //     //-- Enable slave link
    //     pLinkMgr->setConnectionsAllowed();
    //     pLinkMgr->createConnectedLink(_teamModeLinkconfig);
    // } else {
    //     //-- Disconnect all links
    //     LinkManager* pLinkMgr = _toolbox->linkManager();
    //     pLinkMgr->setConnectionsSuspended(QString(tr("Switching to Master Mode")));
    //     pLinkMgr->disconnectAll();
    //     //-- Reset Slave Link
    //     _toolbox->settingsManager()->appSettings()->audioMuted()->setRawValue(true);
    //     _toolbox->settingsManager()->autoConnectSettings()->autoConnectUDP()->setRawValue(true);
    //     _toolbox->settingsManager()->autoConnectSettings()->disableConnectSerial()->setRawValue(false);
    //     //-- Enable normal link
    //     pLinkMgr->setConnectionsAllowed();
    // }
    // emit teamModeLinkChanged();
}


void CustomQmlInterface::showMessage(const QString& message, SystemMessage::SystemMessageType type)
{
    static bool mapMessageShown = false;
    if (_isMapDownloadMessage(message)) {
        if (mapMessageShown)
            return;
        mapMessageShown = true;
    }

    SystemMessage* m = new SystemMessage(this);
    m->setContext(message);
    m->setType(type);

    if (_isMapDownloadMessage(message)) {
        _normalSystemMessages.append(m);
    }
    else if (type != SystemMessage::SystemMessageType::Warning && type != SystemMessage::SystemMessageType::Error) {
        bool alreadyExists = false;
        for (SystemMessage* existing : _normalSystemMessages) {
            if (existing->context() == message) {
                alreadyExists = true;
                break;
            }
        }
        if (!alreadyExists) {
            while (_normalSystemMessages.count() >= 5) {
                _normalSystemMessages.first()->closeItstyle();
            }
            _normalSystemMessages.append(m);
        } else {
            m->deleteLater();
            return;
        }
    }
    _systemMessages.append(m);
    _refreshSystemMessageUI(true);
}

void CustomQmlInterface::handleCustomButtonFunction(int type, bool pressed)
{
    qDebug() << "handleCustomButtonFunction : type = " << type;
    if(type == CUSTOM_FUNCTION_COACH_WAYPOINT) {
        if(_plugin->coachMode()) emit coachWaypointTigger(pressed);
    } else if(type == CUSTOM_FUNCTION_THERMAL_ZOOM) {
        emit thermalZoomTigger(pressed);
    } else if(type == CUSTOM_FUNCTION_IR_SWITCH) {
        emit irSwitchTigger(pressed);
    } else if(type == CUSTOM_FUNCTION_GIMBAL_RESET) {
        emit gimbalResetTigger(pressed);
    } else if(type == CUSTOM_FUNCTION_AIRCRAFT_RTL) {
        if(pressed) {
            Vehicle* vehicle = _toolbox->multiVehicleManager()->activeVehicle();
            if(vehicle) {
                vehicle->guidedModeRTL(false);
            }
        }
    } else if(type == CUSTOM_FUNCTION_START_MISSION) {
        qDebug() << "CUSTOM_FUNCTION_START_MISSION";
        if(pressed) {
            qDebug() << "CUSTOM_FUNCTION_START_MISSION pressed";
            Vehicle* vehicle = _toolbox->multiVehicleManager()->activeVehicle();
            if(vehicle) {
                qDebug() << "startMission";
                vehicle->startMission();
            }
        }
    } else if(type == CUSTOM_FUNCTION_CAMERA_CAPTURE) {
        if(pressed) {
            if (CodevCameraControl* camera = _activeCodevCamera(_toolbox)) {
                camera->buttonTakePhoto();
            } else {
                emit cameraCapture(true);
            }
        }
    } else if(type == CUSTOM_FUNCTION_CAMERA_TOGGLE_RECORD) {
        if(pressed) {
            if (CodevCameraControl* camera = _activeCodevCamera(_toolbox)) {
                camera->buttonToggleVideo();
            } else {
                emit cameraToggleRecord(true);
            }
        }
    }
}

void CustomQmlInterface::handleAviatorButton(int type, bool pressed)
{
    switch (type) {
    case AVIATORInterface::AVIATOR_FUNCTION_THERMAL_ZOOM:
        handleCustomButtonFunction(CUSTOM_FUNCTION_THERMAL_ZOOM, pressed);
        break;
    case AVIATORInterface::AVIATOR_FUNCTION_IR_SWITCH:
        handleCustomButtonFunction(CUSTOM_FUNCTION_IR_SWITCH, pressed);
        break;
    case AVIATORInterface::AVIATOR_FUNCTION_GIMBAL_RESET:
        handleCustomButtonFunction(CUSTOM_FUNCTION_GIMBAL_RESET, pressed);
        break;
    case AVIATORInterface::AVIATOR_FUNCTION_CAMERA_CAPTURE:
        handleCustomButtonFunction(CUSTOM_FUNCTION_CAMERA_CAPTURE, pressed);
        break;
    case AVIATORInterface::AVIATOR_FUNCTION_CAMERA_TOGGLE_RECORD:
        handleCustomButtonFunction(CUSTOM_FUNCTION_CAMERA_TOGGLE_RECORD, pressed);
        break;
    default:
        break;
    }
}

void CustomQmlInterface::_refreshSystemMessageUI(bool from)
{
    if(_group.state() == QAbstractAnimation::Running) _group.stop();
    _group.clear();
    float y = _defaultFontPixelHeight * 0.5;
    for(int i = _systemMessages.count() - 1; i >= 0; i--) {
        SystemMessage* m = _systemMessages.value<SystemMessage*>(i);
        QPropertyAnimation* animation = from ? m->createYAnimation(y - m->height(), y) : m->createYAnimation(m->y(), y);
        _group.addAnimation(animation);
        y += m->height() + _defaultFontPixelHeight * 0.5;
    }
    _group.start();
}

SystemMessage::SystemMessage(CustomQmlInterface* parent)
    : QObject(parent)
    , _width(0)
    , _height(0)
    , _opacity(1)
    , _customQmlInterface(parent)
    , _yAnimation(nullptr)
    , _geoAwarenessOpacity(1)
    , _geoAwarenessYAnimation(nullptr)
{
    QPropertyAnimation *opacityAnimation = new QPropertyAnimation(this, "opacity", this);
    opacityAnimation->setDuration(200);
    opacityAnimation->setStartValue(0);
    opacityAnimation->setEndValue(1);
    opacityAnimation->start();

    _timer.setSingleShot(true);
    connect(&_timer, &QTimer::timeout, this, &SystemMessage::startCloseItstyle);

    QPropertyAnimation *opacityAnimation2 = new QPropertyAnimation(this, "geoAwarenessOpacity", this);
    opacityAnimation2->setDuration(200);
    opacityAnimation2->setStartValue(0);
    opacityAnimation2->setEndValue(1);
    opacityAnimation2->start();

    _geoAwarenessTimer.setSingleShot(true);
    connect(&_geoAwarenessTimer, &QTimer::timeout, this, &SystemMessage::geoAwarnessStartCloseItstyle);
}

QPropertyAnimation* SystemMessage::createYAnimation(QVariant from, QVariant to)
{
    _yAnimation = new QPropertyAnimation(this, "y", this);
    _yAnimation->setDuration(200);
    _yAnimation->setStartValue(from);
    _yAnimation->setEndValue(to);

    return _yAnimation;
}

void SystemMessage::startCloseItstyle()
{
    QPropertyAnimation *animation = new QPropertyAnimation(this, "opacity", this);
    animation->setDuration(2000);
    animation->setStartValue(1);
    animation->setEndValue(0);
    connect(animation, &QPropertyAnimation::finished, this, &SystemMessage::closeItstyle);
    animation->start();
}

void SystemMessage::closeItstyle()
{
    if(_customQmlInterface->_group.indexOfAnimation(_yAnimation) > -1) {
        _customQmlInterface->_group.removeAnimation(_yAnimation);
        _yAnimation->deleteLater();
        _yAnimation = nullptr;
    }
    int index = _customQmlInterface->_systemMessages.indexOf(this);
    _customQmlInterface->_normalSystemMessages.removeOne(this);
    _customQmlInterface->_systemMessages.removeAt(index)->deleteLater();
    if(index > 0) {
        _customQmlInterface->_refreshSystemMessageUI(false);
    }
}

QString SystemMessage::icon() const
{
    switch (_type) {
    case SystemMessageType::Info:
        return QString("qrc:/custom/img/png/info.png");
    case SystemMessageType::Error:    
        return QString("qrc:/custom/img/png/error.png");
    case SystemMessageType::Warning:
        return QString("qrc:/custom/img/png/warning.png");
    case SystemMessageType::Success:
        return QString("qrc:/custom/img/png/success.png");;
    default:
        return QString();
    }
}

QString SystemMessage::color() const
{
    switch (_type) {
    case SystemMessageType::Info:
        return QString("#00DA90");
    case SystemMessageType::Error:    
        return QString("red");
    case SystemMessageType::Warning:
        return QString("#FFC21E");
    case SystemMessageType::Success:
        return QString("#00DA90");;
    default:
        return QString("white");
    }
}

void SystemMessage::setContext(const QString &context)
{
    _context = context;
    _width = _customQmlInterface->_defaultFontPixelWidth * 1 * (CHAR_NUMBER_EACH_ROW + 3) + _customQmlInterface->_defaultFontPixelHeight * 1 * 2;
    _height = _customQmlInterface->_defaultFontPixelWidth * 1 * 2 + _customQmlInterface->_defaultFontPixelHeight * 1 * (_context.length() / CHAR_NUMBER_EACH_ROW + 1);
}

void SystemMessage::setType(const SystemMessageType &type)
{
    _type = type;
    if(_timer.isActive()) _timer.stop();
    if(_isMapDownloadMessage(_context)){
    }
    else if(type == SystemMessageType::Error) {
        _timer.start(20000);    
    } else _timer.start(15000);
}

void SystemMessage::setOpacity(const float &opacity)
{
    _opacity = opacity;    
    emit opacityChanged(_opacity);
}

void SystemMessage::setY(const float &y)
{
    _y = y;
    emit yChanged(_y);
}


// GeoAwareness --------------------------------------------------------------------------------------------------------------------
static bool _geoAwarenessInsideMessageShown = false;
static bool _geoAwarenessNearMessageShown = false;
static bool _geoAwarenessNoDataMessageShown = false;

namespace {
bool _containsSourceOrTranslation(const QString& message, const char* sourceText)
{
    if (message.contains(QLatin1String(sourceText))) {
        return true;
    }

    const QString translated = QCoreApplication::translate("FlightZoneManager", sourceText);
    return translated != QLatin1String(sourceText) && message.contains(translated);
}
}

void CustomQmlInterface::geoAwarenessMessage(const QString& message)
{

    // qInfo() << "geoAwareness Messag e== " << message;
    // qInfo() << "_geoAwarenessMessageShown == " << _geoAwarenessInsideMessageShown;
    // qInfo() << "_geoAwarenessNearMessageShown == " << _geoAwarenessNearMessageShown;
    // qInfo() << "_geoAwarenessNoDataMessageShown == " << _geoAwarenessNoDataMessageShown;

    GeoAwarenessErrorId type = GeoAwarenessErrorId::Unknown;

    if (_containsSourceOrTranslation(message, "Drone is inside")) {
        type = GeoAwarenessErrorId::Inside;
    } else if (_containsSourceOrTranslation(message, "The distance between the aircraft and GeoZone is close. Distance : %1M")) {
        type = GeoAwarenessErrorId::Near;
    } else if (_containsSourceOrTranslation(message, "The distance between the aircraft and GeoZone is close.")) {
        type = GeoAwarenessErrorId::Near;
    } else if (_containsSourceOrTranslation(message, "Cannot access GeoZone data.<br>Please check local files or internet connection.")) {
        type = GeoAwarenessErrorId::NoData;
    }

    // 이미 보여줬다면 return
    switch (type) {
    case GeoAwarenessErrorId::Inside:
        if (_geoAwarenessInsideMessageShown)
            return;
        _geoAwarenessInsideMessageShown = true;
        break;
    case GeoAwarenessErrorId::Near:
        if (_geoAwarenessNearMessageShown)
            return;
        _geoAwarenessNearMessageShown = true;
        break;
    case GeoAwarenessErrorId::NoData:
        if (_geoAwarenessNoDataMessageShown)
            return;
        _geoAwarenessNoDataMessageShown = true;
        break;
    default:
        return; // 처리할 수 없는 메시지
    }

    SystemMessage* m = new SystemMessage(this);
    m->setGeoAwarenessContext(message);
    m->setGeoAwarenessErrorId(type);
    m->setGeoAwarenessType();


    _geoAwarenessMessages.append(m);    
    _geoAwarenessRefreshSystemMessageUI(true);
}

void SystemMessage::setGeoAwarenessContext(const QString &context)
{
    _geoAwarenessContext = context;
    _geoAwarenessWidth = _customQmlInterface->_defaultFontPixelWidth * 1 * (CHAR_NUMBER_EACH_ROW + 3) + _customQmlInterface->_defaultFontPixelHeight * 1 * 20;
    _geoAwarenessHeight = _customQmlInterface->_defaultFontPixelWidth * 1 * 5 + _customQmlInterface->_defaultFontPixelHeight * 1 * (_geoAwarenessContext.length() / CHAR_NUMBER_EACH_ROW + 1);
}

void SystemMessage::setGeoAwarenessOpacity(const float &opacity)
{
    _geoAwarenessOpacity = opacity;
    emit geoAwarenessOpacityChanged(_geoAwarenessOpacity);
}

void SystemMessage::setGeoAwarenessY(const float &geoy)
{
    _geoAwarenessY = geoy;    
    emit geoAwarenessYChagned(_geoAwarenessY);
}

void CustomQmlInterface::_geoAwarenessRefreshSystemMessageUI(bool from)
{
    if(_geoAwarenessGroup.state() == QAbstractAnimation::Running) _geoAwarenessGroup.stop();
    _geoAwarenessGroup.clear();
    float y = _defaultFontPixelHeight * 0.5;
    for(int i = _geoAwarenessMessages.count() - 1; i >= 0; i--) {
        SystemMessage* m = _geoAwarenessMessages.value<SystemMessage*>(i);
        QPropertyAnimation* animation = from ? m->geoAwarenessCreateYAnimation(y - m->geoAwarenessHeight(), y) : m->geoAwarenessCreateYAnimation(m->y(), y);
        _geoAwarenessGroup.addAnimation(animation);
        y += m->geoAwarenessHeight() + _defaultFontPixelHeight * 0.5;
    }
    _geoAwarenessGroup.start();
}

void SystemMessage::geoAwarnessStartCloseItstyle()
{
    QPropertyAnimation *animation = new QPropertyAnimation(this, "geoAwarenessOpacity", this);
    animation->setDuration(2000);
    animation->setStartValue(1);
    animation->setEndValue(0);
    connect(animation, &QPropertyAnimation::finished, this, &SystemMessage::geoAwarenessCloseItstyle);
    animation->start();
}

void SystemMessage::geoAwarenessCloseItstyle()
{
    if(_customQmlInterface->_geoAwarenessGroup.indexOfAnimation(_geoAwarenessYAnimation) > -1) {
        _customQmlInterface->_geoAwarenessGroup.removeAnimation(_geoAwarenessYAnimation);
        _geoAwarenessYAnimation->deleteLater();
        _geoAwarenessYAnimation = nullptr;
    }
    int index = _customQmlInterface->_geoAwarenessMessages.indexOf(this);
    _customQmlInterface->_geoAwarenessNormalSystemMessages.removeOne(this);
    _customQmlInterface->_geoAwarenessMessages.removeAt(index)->deleteLater();

    if(index > 0) {
        _customQmlInterface->_geoAwarenessRefreshSystemMessageUI(false);
    }
    switch (_geoAwarenessErrorId) {
    case GeoAwarenessErrorId::Inside:
        _geoAwarenessInsideMessageShown = false;
        break;
    case GeoAwarenessErrorId::Near:
        _geoAwarenessNearMessageShown = false;
        break;
    case GeoAwarenessErrorId::NoData:
        _geoAwarenessNoDataMessageShown = false;
        break;
    default:
        break;
    }
}

QPropertyAnimation* SystemMessage::geoAwarenessCreateYAnimation(QVariant from, QVariant to)
{
    _geoAwarenessYAnimation = new QPropertyAnimation(this, "geoAwarenessY", this);
    _geoAwarenessYAnimation->setDuration(200);
    _geoAwarenessYAnimation->setStartValue(from);
    _geoAwarenessYAnimation->setEndValue(to);

    return _geoAwarenessYAnimation;
}

void SystemMessage::setGeoAwarenessType()
{
    //Timer only show 10s
    if(_geoAwarenessTimer.isActive()) _geoAwarenessTimer.stop();
    _geoAwarenessTimer.start(10000);
}
