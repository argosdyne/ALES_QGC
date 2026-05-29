#include "CustomQmlInterface.h"
#include "CustomPlugin.h"
#include "LinkManager.h"
#include "CodevRTCMManager.h"
#include "Login/SecurityLogModel.h"
#include "SettingsManager.h"
#include "AppSettings.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStringList>
#include <QTextStream>
#include <QRegularExpression>
#if defined(Q_OS_ANDROID)
#include <QtAndroidExtras/QtAndroid>
#include <QtAndroidExtras/QAndroidJniEnvironment>
#include <QtAndroidExtras/QAndroidJniObject>
#endif

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
        QString msg = "Map tiles updated at " + lastModified.toString();
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

QString CustomQmlInterface::exportTextReport(const QString& fileName, const QString& contents)
{
    QString exportDir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (exportDir.isEmpty()) {
        exportDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    }

    if (exportDir.isEmpty()) {
        logSecurityEvent(QStringLiteral("Failed to resolve export directory for security export"));
        return QString();
    }

    QDir dir(exportDir);
    if (!dir.exists() && !dir.mkpath(QStringLiteral("."))) {
        logSecurityEvent(QStringLiteral("Failed to create export directory: %1").arg(exportDir));
        return QString();
    }

    const QString fullPath = dir.filePath(fileName);
    if (!exportTextReportToPath(fullPath, contents)) {
        return QString();
    }

    return fullPath;
}

bool CustomQmlInterface::exportTextReportToPath(const QString& filePath, const QString& contents)
{
    const QString trimmedPath = filePath.trimmed();
    if (trimmedPath.isEmpty()) {
        logSecurityEvent(QStringLiteral("Failed to export report: destination path is empty"));
        return false;
    }

    QFileInfo fileInfo(trimmedPath);
    QDir dir = fileInfo.dir();
    if (!dir.exists() && !dir.mkpath(QStringLiteral("."))) {
        logSecurityEvent(QStringLiteral("Failed to create export directory: %1").arg(dir.absolutePath()));
        return false;
    }

    QFile file(trimmedPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        logSecurityEvent(QStringLiteral("Failed to open export file %1: %2").arg(trimmedPath, file.errorString()));
        return false;
    }

    QTextStream out(&file);
    out << contents;
    file.close();

    logSecurityEvent(QStringLiteral("Exported report to %1").arg(trimmedPath));
    return true;
}

void CustomQmlInterface::logSecurityEvent(const QString& message)
{
    const QString trimmed = message.trimmed();
    if (trimmed.isEmpty()) {
        return;
    }

    SecurityLog::logEvent(trimmed);
    qInfo().noquote() << "SECURITY:" << trimmed;
}

void CustomQmlInterface::clearUserLogs()
{
    SecurityLogModel* securityLogModel = SecurityLog::getModel();
    if (securityLogModel) {
        securityLogModel->clearLog();
    }

    if (!_toolbox || !_toolbox->settingsManager() || !_toolbox->settingsManager()->appSettings()) {
        return;
    }

    const QStringList logDirs = {
        _toolbox->settingsManager()->appSettings()->telemetrySavePath(),
        _toolbox->settingsManager()->appSettings()->logSavePath(),
        _toolbox->settingsManager()->appSettings()->crashSavePath()
    };

    for (const QString& logDirPath: logDirs) {
        if (logDirPath.trimmed().isEmpty()) {
            continue;
        }

        QDir logDir(logDirPath);
        if (!logDir.exists()) {
            continue;
        }

        const QFileInfoList entries = logDir.entryInfoList(QDir::Files | QDir::NoDotAndDotDot);
        for (const QFileInfo& entry: entries) {
            QFile::remove(entry.absoluteFilePath());
        }
    }
}

void CustomQmlInterface::notifyFactoryResetCompleted()
{
    emit factoryResetCompleted();
}

bool CustomQmlInterface::setDpcKioskEnabled(bool enabled)
{
    return setDpcKioskEnabledWithPin(enabled, QString());
}

bool CustomQmlInterface::setDpcKioskEnabledWithPin(bool enabled, const QString& pin)
{
#if defined(Q_OS_ANDROID)
    if (pin.length() != 8) {
        logSecurityEvent(QStringLiteral("DPC kiosk request denied: invalid PIN length"));
        return false;
    }

    qInfo() << "CustomQmlInterface setDPC " << enabled << pin;
    const QRegularExpression pinRegex(QStringLiteral("^\\d{8}$"));
    if (!pinRegex.match(pin).hasMatch()) {
        logSecurityEvent(QStringLiteral("DPC kiosk request denied: PIN must be 8 digits"));
        return false;
    }

    QAndroidJniObject activity = QtAndroid::androidActivity();
    if (!activity.isValid()) {
        logSecurityEvent(QStringLiteral("DPC kiosk request failed: no Android activity"));
        return false;
    }

    const QAndroidJniObject action = QAndroidJniObject::fromString(QStringLiteral("com.easygripper.dpc.action.SET_KIOSK_ENABLED"));
    const QAndroidJniObject dpcPackage = QAndroidJniObject::fromString(QStringLiteral("com.easygripper.dpc"));
    const QAndroidJniObject dpcReceiver = QAndroidJniObject::fromString(QStringLiteral("com.easygripper.dpc.DpcControlReceiver"));
    const QAndroidJniObject enabledKey = QAndroidJniObject::fromString(QStringLiteral("enabled"));
    const QAndroidJniObject pinKey = QAndroidJniObject::fromString(QStringLiteral("pin"));
    const QAndroidJniObject jpin = QAndroidJniObject::fromString(pin);

    QAndroidJniObject component(
        "android/content/ComponentName",
        "(Ljava/lang/String;Ljava/lang/String;)V",
        dpcPackage.object<jstring>(),
        dpcReceiver.object<jstring>());

    QAndroidJniObject explicitIntent(
        "android/content/Intent",
        "(Ljava/lang/String;)V",
        action.object<jstring>());
    explicitIntent.callObjectMethod(
        "setComponent",
        "(Landroid/content/ComponentName;)Landroid/content/Intent;",
        component.object());
    explicitIntent.callObjectMethod(
        "putExtra",
        "(Ljava/lang/String;Z)Landroid/content/Intent;",
        enabledKey.object<jstring>(),
        static_cast<jboolean>(enabled));
    explicitIntent.callObjectMethod(
        "putExtra",
        "(Ljava/lang/String;Ljava/lang/String;)Landroid/content/Intent;",
        pinKey.object<jstring>(),
        jpin.object<jstring>());
    activity.callMethod<void>(
        "sendBroadcast",
        "(Landroid/content/Intent;)V",
        explicitIntent.object());

    QAndroidJniObject packageIntent(
        "android/content/Intent",
        "(Ljava/lang/String;)V",
        action.object<jstring>());
    packageIntent.callObjectMethod(
        "setPackage",
        "(Ljava/lang/String;)Landroid/content/Intent;",
        dpcPackage.object<jstring>());
    packageIntent.callObjectMethod(
        "putExtra",
        "(Ljava/lang/String;Z)Landroid/content/Intent;",
        enabledKey.object<jstring>(),
        static_cast<jboolean>(enabled));
    packageIntent.callObjectMethod(
        "putExtra",
        "(Ljava/lang/String;Ljava/lang/String;)Landroid/content/Intent;",
        pinKey.object<jstring>(),
        jpin.object<jstring>());
    activity.callMethod<void>(
        "sendBroadcast",
        "(Landroid/content/Intent;)V",
        packageIntent.object());

    QAndroidJniEnvironment env;
    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        logSecurityEvent(QStringLiteral("DPC kiosk request JNI exception while sending broadcast"));
        return false;
    }

    logSecurityEvent(QStringLiteral("DPC kiosk %1 request broadcast sent")
                         .arg(enabled ? QStringLiteral("enabled") : QStringLiteral("disabled")));
    return true;
#else
    Q_UNUSED(enabled)
    return false;
#endif
}

bool CustomQmlInterface::isDpcControlSupported() const
{
#if defined(Q_OS_ANDROID)
    QAndroidJniObject activity = QtAndroid::androidActivity();
    if (!activity.isValid()) {
        return false;
    }

    QAndroidJniObject packageManager = activity.callObjectMethod(
        "getPackageManager",
        "()Landroid/content/pm/PackageManager;");
    if (!packageManager.isValid()) {
        return false;
    }

    const QAndroidJniObject dpcPackage = QAndroidJniObject::fromString(QStringLiteral("com.easygripper.dpc"));
    const jint flags = 0;

    packageManager.callObjectMethod(
        "getPackageInfo",
        "(Ljava/lang/String;I)Landroid/content/pm/PackageInfo;",
        dpcPackage.object<jstring>(),
        flags);

    QAndroidJniEnvironment env;
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        return false;
    }
    return true;
#else
    return false;
#endif
}

bool CustomQmlInterface::requestDpcKioskState()
{
#if defined(Q_OS_ANDROID)
    const jboolean requested = QAndroidJniObject::callStaticMethod<jboolean>(
        "org/mavlink/qgroundcontrol/QGCActivity",
        "requestDpcKioskState",
        "()Z");

    QAndroidJniEnvironment env;
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        return false;
    }
    return requested;
#else
    return false;
#endif
}

bool CustomQmlInterface::hasKnownDpcKioskState() const
{
#if defined(Q_OS_ANDROID)
    const jboolean known = QAndroidJniObject::callStaticMethod<jboolean>(
        "org/mavlink/qgroundcontrol/QGCActivity",
        "hasKnownDpcKioskState",
        "()Z");

    QAndroidJniEnvironment env;
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        return false;
    }
    return known;
#else
    return false;
#endif
}

bool CustomQmlInterface::getKnownDpcKioskStateEnabled() const
{
#if defined(Q_OS_ANDROID)
    const jboolean enabled = QAndroidJniObject::callStaticMethod<jboolean>(
        "org/mavlink/qgroundcontrol/QGCActivity",
        "getKnownDpcKioskStateEnabled",
        "()Z");

    QAndroidJniEnvironment env;
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        return false;
    }
    return enabled;
#else
    return false;
#endif
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
    if (message.contains("Please download the map")) {
        if (mapMessageShown)
            return;
        mapMessageShown = true;
    }

    SystemMessage* m = new SystemMessage(this);
    m->setContext(message);
    m->setType(type);

    if (message.contains("Please download the map")) {
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
    if(_context.contains("Please download the map")){
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

void CustomQmlInterface::geoAwarenessMessage(const QString& message)
{

    // qInfo() << "geoAwareness Messag e== " << message;
    // qInfo() << "_geoAwarenessMessageShown == " << _geoAwarenessInsideMessageShown;
    // qInfo() << "_geoAwarenessNearMessageShown == " << _geoAwarenessNearMessageShown;
    // qInfo() << "_geoAwarenessNoDataMessageShown == " << _geoAwarenessNoDataMessageShown;

    enum MessageType {
        None,
        Inside,
        Near,
        NoData
    };

    MessageType type = None;

    if (message.contains("Drone is inside")) {
        type = Inside;
    } else if (message.contains("The distance between the aircraft")) {
        type = Near;
    } else if (message.contains("Cannot access GeoZone data")) {
        type = NoData;
    }

    // 이미 보여줬다면 return
    switch (type) {
    case Inside:
        if (_geoAwarenessInsideMessageShown)
            return;
        _geoAwarenessInsideMessageShown = true;
        break;
    case Near:
        if (_geoAwarenessNearMessageShown)
            return;
        _geoAwarenessNearMessageShown = true;
        break;
    case NoData:
        if (_geoAwarenessNoDataMessageShown)
            return;
        _geoAwarenessNoDataMessageShown = true;
        break;
    default:
        return; // 처리할 수 없는 메시지
    }

    SystemMessage* m = new SystemMessage(this);
    m->setGeoAwarenessContext(message);
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
    if (_geoAwarenessContext.contains("Drone is inside")) {
        _geoAwarenessInsideMessageShown = false;
    } else if (_geoAwarenessContext.contains("The distance between the aircraft")) {
        _geoAwarenessNearMessageShown = false;
    } else if (_geoAwarenessContext.contains("Cannot access GeoZone data")) {
        _geoAwarenessNoDataMessageShown = false;
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
