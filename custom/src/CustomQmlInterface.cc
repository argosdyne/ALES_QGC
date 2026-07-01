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
#include <QMetaObject>
#if defined(Q_OS_ANDROID)
#include <QtAndroidExtras/QtAndroid>
#include <QtAndroidExtras/QAndroidJniEnvironment>
#include <QtAndroidExtras/QAndroidJniObject>
#include <QThread>
#include <atomic>

namespace {
constexpr const char* kQgcActivityClass = "org/mavlink/qgroundcontrol/QGCActivity";
constexpr jint kFlagReceiverForeground = 0x01000000;

jclass findQgcActivityClass(QAndroidJniEnvironment& env)
{
    jclass clazz = env->FindClass(kQgcActivityClass);
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        return nullptr;
    }
    return clazz;
}

jmethodID findStaticMethod(QAndroidJniEnvironment& env, jclass clazz, const char* name, const char* signature)
{
    if (clazz == nullptr) {
        return nullptr;
    }
    jmethodID method = env->GetStaticMethodID(clazz, name, signature);
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        return nullptr;
    }
    return method;
}

bool callStaticBooleanIfPresent(const char* methodName, const char* signature, bool defaultValue)
{
    QAndroidJniEnvironment env;
    jclass clazz = findQgcActivityClass(env);
    jmethodID method = findStaticMethod(env, clazz, methodName, signature);
    if (method == nullptr) {
        return defaultValue;
    }
    const jboolean value = env->CallStaticBooleanMethod(clazz, method);
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        return defaultValue;
    }
    return value;
}

void callStaticVoidIfPresent(const char* methodName, const char* signature)
{
    QAndroidJniEnvironment env;
    jclass clazz = findQgcActivityClass(env);
    jmethodID method = findStaticMethod(env, clazz, methodName, signature);
    if (method == nullptr) {
        return;
    }
    env->CallStaticVoidMethod(clazz, method);
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
    }
}

QString callStaticStringIfPresent(const char* methodName, const char* signature, const QString& defaultValue)
{
    QAndroidJniEnvironment env;
    jclass clazz = findQgcActivityClass(env);
    jmethodID method = findStaticMethod(env, clazz, methodName, signature);
    if (method == nullptr) {
        return defaultValue;
    }
    const jstring value = static_cast<jstring>(env->CallStaticObjectMethod(clazz, method));
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        return defaultValue;
    }
    if (value == nullptr) {
        return defaultValue;
    }
    return QAndroidJniObject(value).toString();
}

int callStaticIntIfPresent(const char* methodName, const char* signature, int defaultValue)
{
    QAndroidJniEnvironment env;
    jclass clazz = findQgcActivityClass(env);
    jmethodID method = findStaticMethod(env, clazz, methodName, signature);
    if (method == nullptr) {
        return defaultValue;
    }
    const jint value = env->CallStaticIntMethod(clazz, method);
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        return defaultValue;
    }
    return value;
}

qint64 callStaticLongIfPresent(const char* methodName, const char* signature, qint64 defaultValue)
{
    QAndroidJniEnvironment env;
    jclass clazz = findQgcActivityClass(env);
    jmethodID method = findStaticMethod(env, clazz, methodName, signature);
    if (method == nullptr) {
        return defaultValue;
    }
    const jlong value = env->CallStaticLongMethod(clazz, method);
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
        return defaultValue;
    }
    return static_cast<qint64>(value);
}

bool sendDpcWifiBroadcastCpp(const QString& action)
{
    QAndroidJniObject activity = QtAndroid::androidActivity();
    if (!activity.isValid()) {
        qWarning() << "sendDpcWifiBroadcastCpp: no activity";
        return false;
    }

    const QAndroidJniObject jAction = QAndroidJniObject::fromString(action);
    const QAndroidJniObject dpcPackage = QAndroidJniObject::fromString(QStringLiteral("com.easygripper.dpc"));
    const QAndroidJniObject dpcReceiver = QAndroidJniObject::fromString(QStringLiteral("com.easygripper.dpc.DpcControlReceiver"));
    QAndroidJniObject component(
        "android/content/ComponentName",
        "(Ljava/lang/String;Ljava/lang/String;)V",
        dpcPackage.object<jstring>(),
        dpcReceiver.object<jstring>());

    QAndroidJniObject explicitIntent(
        "android/content/Intent",
        "(Ljava/lang/String;)V",
        jAction.object<jstring>());
    explicitIntent = explicitIntent.callObjectMethod(
        "setComponent",
        "(Landroid/content/ComponentName;)Landroid/content/Intent;",
        component.object());
    explicitIntent = explicitIntent.callObjectMethod(
        "addFlags",
        "(I)Landroid/content/Intent;",
        kFlagReceiverForeground);

    activity.callMethod<void>(
        "sendBroadcast",
        "(Landroid/content/Intent;)V",
        explicitIntent.object());

    QAndroidJniEnvironment env;
    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        return false;
    }

    qInfo() << "DPC WiFi broadcast sent action=" << action;
    return true;
}

bool tryStartWifiIntentOnUiThread(const QString& action, const QString& packageName)
{
    std::atomic<bool> opened{false};
    QAndroidJniObject latch("java/util/concurrent/CountDownLatch", "(I)V", 1);
    const QAndroidJniObject secondsUnit = QAndroidJniObject::callStaticObjectMethod(
        "java/util/concurrent/TimeUnit",
        "SECONDS",
        "Ljava/util/concurrent/TimeUnit;");

    QtAndroid::runOnAndroidThread([action, packageName, &opened, latch]() {
        const QAndroidJniObject activity = QtAndroid::androidActivity();
        if (!activity.isValid()) {
            latch.callMethod<void>("countDown", "()V");
            return;
        }

        QAndroidJniObject intent(
            "android/content/Intent",
            "(Ljava/lang/String;)V",
            QAndroidJniObject::fromString(action).object<jstring>());
        if (!packageName.isEmpty()) {
            intent = intent.callObjectMethod(
                "setPackage",
                "(Ljava/lang/String;)Landroid/content/Intent;",
                QAndroidJniObject::fromString(packageName).object<jstring>());
        }

        activity.callMethod<void>(
            "startActivity",
            "(Landroid/content/Intent;)V",
            intent.object());

        QAndroidJniEnvironment env;
        if (env->ExceptionCheck()) {
            env->ExceptionDescribe();
            env->ExceptionClear();
        } else {
            qInfo() << "WiFi panel opened from C++ action=" << action
                    << "package=" << (packageName.isEmpty() ? QStringLiteral("default") : packageName);
            opened.store(true);
        }

        latch.callMethod<void>("countDown", "()V");
    });

    latch.callMethod<jboolean>(
        "await",
        "(JLjava/util/concurrent/TimeUnit;)Z",
        static_cast<jlong>(5),
        secondsUnit.object());
    return opened.load();
}

bool openWifiSettingsPanelCpp()
{
    const jint sdkInt = QAndroidJniObject::callStaticMethod<jint>(
        "android/os/Build$VERSION",
        "SDK_INT",
        "()I");

    QStringList actions;
    if (sdkInt >= 29) {
        actions << QStringLiteral("android.settings.panel.action.WIFI");
    }
    actions << QStringLiteral("android.settings.WIFI_SETTINGS")
            << QStringLiteral("android.settings.WIRELESS_SETTINGS");

    for (const QString& action : actions) {
        if (tryStartWifiIntentOnUiThread(action, QStringLiteral("com.android.settings"))) {
            return true;
        }
        if (tryStartWifiIntentOnUiThread(action, QString())) {
            return true;
        }
    }

    qWarning() << "openWifiSettingsPanelCpp: all WiFi panel attempts failed";
    return false;
}

bool requestDpcOpenWifiPanelCpp()
{
    sendDpcWifiBroadcastCpp(QStringLiteral("com.easygripper.dpc.action.OPEN_WIFI_PANEL"));
    if (callStaticBooleanIfPresent("getKnownDpcKioskStateEnabled", "()Z", false)) {
        qInfo() << "WiFi panel delegated to DPC (kiosk ON)";
        return true;
    }
    sendDpcWifiBroadcastCpp(QStringLiteral("com.easygripper.dpc.action.ENABLE_WIFI"));
    QThread::msleep(400);
    const bool opened = openWifiSettingsPanelCpp();
    if (opened) {
        callStaticVoidIfPresent("scheduleForegroundReturnAfterWifiPanel", "()V");
    }
    return opened;
}
} // namespace
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

#if defined(Q_OS_ANDROID)
    refreshDpcKioskStateFromStorage();
    requestDpcKioskState();
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

    // Delegate to QGCActivity so boot-forced kiosk state is cleared before the broadcast.
    QAndroidJniEnvironment env;
    jclass clazz = findQgcActivityClass(env);
    jmethodID method = findStaticMethod(env, clazz, "setDpcKioskEnabledWithPin", "(ZLjava/lang/String;)Ljava/lang/String;");
    if (method == nullptr) {
        logSecurityEvent(QStringLiteral("DPC kiosk request failed: Java bridge unavailable"));
        return false;
    }

    const QAndroidJniObject jpin = QAndroidJniObject::fromString(pin);
    const jstring result = static_cast<jstring>(
        env->CallStaticObjectMethod(clazz, method, static_cast<jboolean>(enabled), jpin.object<jstring>()));
    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
        logSecurityEvent(QStringLiteral("DPC kiosk request JNI exception while sending broadcast"));
        return false;
    }

    const QString status = result != nullptr ? QAndroidJniObject(result).toString() : QStringLiteral("ERROR");
    if (status == QLatin1String("OK")) {
        logSecurityEvent(QStringLiteral("DPC kiosk %1 request broadcast sent")
                             .arg(enabled ? QStringLiteral("enabled") : QStringLiteral("disabled")));
        return true;
    }

    logSecurityEvent(QStringLiteral("DPC kiosk request rejected by Java bridge: %1").arg(status));
    return false;
#else
    Q_UNUSED(enabled)
    Q_UNUSED(pin)
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
    return callStaticBooleanIfPresent("requestDpcKioskState", "()Z", false);
#else
    return false;
#endif
}

bool CustomQmlInterface::requestDpcEnableWifi()
{
#if defined(Q_OS_ANDROID)
    const bool sent = callStaticBooleanIfPresent("requestDpcEnableWifi", "()Z", false);
    if (sent) {
        logSecurityEvent(QStringLiteral("DPC WiFi enable requested via hidden gesture"));
    }
    return sent;
#else
    return false;
#endif
}

bool CustomQmlInterface::requestDpcOpenWifiPanel()
{
#if defined(Q_OS_ANDROID)
    QAndroidJniEnvironment env;
    jclass clazz = findQgcActivityClass(env);
    if (clazz != nullptr) {
        jmethodID openPanelMethod = findStaticMethod(env, clazz, "requestDpcOpenWifiPanel", "()Z");
        if (openPanelMethod != nullptr) {
            const jboolean value = env->CallStaticBooleanMethod(clazz, openPanelMethod);
            if (!env->ExceptionCheck() && value) {
                logSecurityEvent(QStringLiteral("WiFi panel opened via requestDpcOpenWifiPanel"));
                return true;
            }
            if (env->ExceptionCheck()) {
                env->ExceptionClear();
            }
            qWarning() << "requestDpcOpenWifiPanel: Java bridge returned false, trying C++ path";
        }
    }

    const bool opened = requestDpcOpenWifiPanelCpp();
    if (opened) {
        logSecurityEvent(QStringLiteral("WiFi panel opened via C++ bridge"));
    } else {
        qWarning() << "requestDpcOpenWifiPanel: C++ bridge failed";
    }
    return opened;
#else
    return false;
#endif
}

bool CustomQmlInterface::openWifiSettingsPanel()
{
#if defined(Q_OS_ANDROID)
    if (callStaticBooleanIfPresent("openWifiSettingsPanel", "()Z", false)) {
        return true;
    }
    return openWifiSettingsPanelCpp();
#else
    return false;
#endif
}

bool CustomQmlInterface::isBootForcedDpcKioskOn() const
{
#if defined(Q_OS_ANDROID)
    return callStaticBooleanIfPresent("isBootForcedDpcKioskOn", "()Z", false);
#else
    return false;
#endif
}

void CustomQmlInterface::refreshDpcKioskStateFromStorage()
{
#if defined(Q_OS_ANDROID)
    callStaticVoidIfPresent("refreshDpcKioskStateFromStorage", "()V");
#endif
}

void CustomQmlInterface::refreshDpcPinGateStateFromStorage()
{
#if defined(Q_OS_ANDROID)
    callStaticVoidIfPresent("refreshDpcPinGateStateFromStorage", "()V");
#endif
}

bool CustomQmlInterface::reconcilePostRebootKioskState()
{
#if defined(Q_OS_ANDROID)
    return callStaticBooleanIfPresent("reconcilePostRebootKioskState", "()Z", false);
#else
    return false;
#endif
}

QString CustomQmlInterface::getDpcKioskDiagnostics() const
{
#if defined(Q_OS_ANDROID)
    QStringList parts;
    parts << QStringLiteral("cppBuild=%1 %2").arg(QStringLiteral(__DATE__), QStringLiteral(__TIME__));

    QAndroidJniEnvironment env;
    jclass activityClass = env->FindClass("org/mavlink/qgroundcontrol/QGCActivity");
    if (activityClass == nullptr || env->ExceptionCheck()) {
        env->ExceptionClear();
        parts << QStringLiteral("QGCActivity=MISSING");
        parts << QStringLiteral("action=Clean+Rebuild+Deploy Android APK");
        return parts.join(QStringLiteral(" | "));
    }
    parts << QStringLiteral("QGCActivity=ok");

    const jmethodID diagMethod = env->GetStaticMethodID(
        activityClass, "getDpcKioskDiagnostics", "()Ljava/lang/String;");
    if (diagMethod != nullptr && !env->ExceptionCheck()) {
        const jstring jdiag = static_cast<jstring>(env->CallStaticObjectMethod(activityClass, diagMethod));
        if (jdiag != nullptr && !env->ExceptionCheck()) {
            return QAndroidJniObject(jdiag).toString();
        }
        env->ExceptionClear();
    } else {
        env->ExceptionClear();
        parts << QStringLiteral("javaDiag=OLD_APK");
    }

    const jmethodID bootForcedMethod = findStaticMethod(env, activityClass, "isBootForcedDpcKioskOn", "()Z");
    const jmethodID initBridgeMethod = findStaticMethod(env, activityClass, "initDpcKioskBridge", "(Landroid/content/Context;)V");
    parts << QStringLiteral("bootForcedMethod=%1").arg(bootForcedMethod != nullptr ? QStringLiteral("yes") : QStringLiteral("no"));
    parts << QStringLiteral("initBridgeMethod=%1").arg(initBridgeMethod != nullptr ? QStringLiteral("yes") : QStringLiteral("no"));
    parts << QStringLiteral("dpcSupported=%1").arg(isDpcControlSupported() ? QStringLiteral("yes") : QStringLiteral("no"));
    parts << QStringLiteral("hasKnown=%1").arg(hasKnownDpcKioskState() ? QStringLiteral("yes") : QStringLiteral("no"));
    parts << QStringLiteral("knownEnabled=%1").arg(getKnownDpcKioskStateEnabled() ? QStringLiteral("yes") : QStringLiteral("no"));
    parts << QStringLiteral("action=Clean+Rebuild+Deploy Android APK");
    return parts.join(QStringLiteral(" | "));
#else
    return QStringLiteral("not android");
#endif
}

QString CustomQmlInterface::lastDpcReason() const
{
#if defined(Q_OS_ANDROID)
    return callStaticStringIfPresent("getLastDpcReason", "()Ljava/lang/String;", QString());
#else
    return QString();
#endif
}

void CustomQmlInterface::clearDpcReason()
{
#if defined(Q_OS_ANDROID)
    callStaticVoidIfPresent("clearLastDpcReason", "()V");
#endif
}

int CustomQmlInterface::dpcAttemptsRemaining() const
{
#if defined(Q_OS_ANDROID)
    return callStaticIntIfPresent("getDpcAttemptsRemaining", "()I", -1);
#else
    return -1;
#endif
}

qint64 CustomQmlInterface::dpcLockoutUntilMs() const
{
#if defined(Q_OS_ANDROID)
    return callStaticLongIfPresent("getDpcLockoutUntilMs", "()J", 0);
#else
    return 0;
#endif
}

bool CustomQmlInterface::hasKnownDpcKioskState() const
{
#if defined(Q_OS_ANDROID)
    return callStaticBooleanIfPresent("hasKnownDpcKioskState", "()Z", false);
#else
    return false;
#endif
}

bool CustomQmlInterface::getKnownDpcKioskStateEnabled() const
{
#if defined(Q_OS_ANDROID)
    return callStaticBooleanIfPresent("getKnownDpcKioskStateEnabled", "()Z", false);
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
    if (_geoAwarenessTimer.isActive()) _geoAwarenessTimer.stop();
    _geoAwarenessTimer.start(10000);
}

#ifdef __ANDROID__
extern "C" JNIEXPORT void JNICALL
Java_org_mavlink_qgroundcontrol_QGCActivity_nativeNotifyDpcPinGateChanged(
        JNIEnv*, jclass)
{
    CustomQmlInterface* iface = CustomQmlInterface::instance();
    if (!iface) {
        return;
    }
    QMetaObject::invokeMethod(iface, "dpcPinGateStateChanged", Qt::QueuedConnection);
}
#endif
