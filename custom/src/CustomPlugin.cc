/****************************************************************************
 *
 * (c) 2009-2019 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 *   @brief Custom QGCCorePlugin Implementation
 *   @author Gus Grubba <gus@auterion.com>
 */

#include <QtQml>
#include <QQmlEngine>
#include <QDateTime>
#include <QSettings>
#include <cstring>
#include "QGCSettings.h"
#include "MAVLinkLogManager.h"

#include "CustomPlugin.h"

#include "MultiVehicleManager.h"
#include "QGCApplication.h"
#include "SettingsManager.h"
#include "AppMessages.h"
#include "QmlComponentInfo.h"
#include "QGCPalette.h"
#include "CodevRTCMManager.h"
#include "CustomSettings.h"
#include "YS/YSManager.h"

#include "M2Manager.h"
#include "RajantManager.h"
#include "QGroundControlQmlGlobal.h"
#include <QFile>
#include <QNetworkInterface>
#include <QtConcurrent>

#if defined(Q_OS_ANDROID)
#include <sys/socket.h>
#include <linux/netlink.h>
#include <linux/rtnetlink.h>
#include <linux/neighbour.h>
#include <net/if.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <cerrno>
#endif

QGC_LOGGING_CATEGORY(CustomLog, "CustomLog")

static const char *kSlaveMode = "SlaveMode";

CustomFlyViewOptions::CustomFlyViewOptions(CustomOptions* options, QObject* parent)
    : QGCFlyViewOptions(options, parent)
{

}

// This custom build does not support conecting multiple vehicles to it. This in turn simplifies various parts of the QGC ui.
bool CustomFlyViewOptions::showMultiVehicleList(void) const
{
    return false;
}

// This custom build has it's own custom instrument panel. Don't show regular one.
bool CustomFlyViewOptions::showInstrumentPanel(void) const
{
    return false;
}

CustomOptions::CustomOptions(CustomPlugin*, QObject* parent)
    : QGCOptions(parent)
{
}

QGCFlyViewOptions* CustomOptions::flyViewOptions(void)
{
    if (!_flyViewOptions) {
        _flyViewOptions = new CustomFlyViewOptions(this, this);
    }
    return _flyViewOptions;
}

// Firmware upgrade page is only shown in Advanced Mode.
bool CustomOptions::showFirmwareUpgrade() const
{
    return qgcApp()->toolbox()->corePlugin()->showAdvancedUI();
}

// Normal QGC needs to work with an ESP8266 WiFi thing which is remarkably crappy. This in turns causes PX4 Pro calibration to fail
// quite often. There is a warning in regular QGC about this. Overriding the and returning true means that your custom vehicle has
// a reliable WiFi connection so don't show that warning.
bool CustomOptions::wifiReliableForCalibration(void) const
{
    return true;
}

CustomPlugin::CustomPlugin(QGCApplication *app, QGCToolbox* toolbox)
    : QGCCorePlugin(app, toolbox)
{
    _options = new CustomOptions(this, this);
    _siyiManager = new SiYiManager(app,toolbox);
    _codevRTCMManager = new CodevRTCMManager(app, toolbox);
    _ysManager = new YSManager(app, toolbox);
    _showAdvancedUI = false;
}

CustomPlugin::~CustomPlugin()
{
}

void CustomPlugin::setSlaveMode(bool mode)
{
    if(_slaveMode != mode) {
        _slaveMode = mode;
        QSettings settings;
        settings.setValue(kSlaveMode, _slaveMode);
        emit slaveModeChanged(_slaveMode);
    }
}

void CustomPlugin::setToolbox(QGCToolbox* toolbox)
{
    QGCCorePlugin::setToolbox(toolbox);

    _siyiManager->setToolbox(toolbox);
    _ysManager->setToolbox(toolbox);
    if(_codevSettings == nullptr) {
        _codevSettings = new CodevSettings(this);
    }

    _settings = new CustomSettings(this);
    _codevRTCMManager->setToolbox(toolbox);

    // Allows us to be notified when the user goes in/out out advanced mode
    connect(qgcApp()->toolbox()->corePlugin(), &QGCCorePlugin::showAdvancedUIChanged, this, &CustomPlugin::_advancedChanged);

    _aviatorInterface = new AVIATORInterface();
    qInfo() << "_aviatorInterface = new AVIATORInterface();";
#if defined (Q_OS_ANDROID)
    connect(_aviatorInterface, &AVIATORInterface::rcChannelValuesChanged, this, &CustomPlugin::_handleRCChannelValues);
#endif

    qmlRegisterSingletonInstance<AVIATORInterface>("CustomQmlInterface", 1, 0, "AVIATORInterface", _aviatorInterface);
}

void CustomPlugin::_handleRCChannelValues(const quint16* channels, int count)
{    
    static quint16 inlChannels[18];
    memcpy(inlChannels, channels, 18 * 2);
    emit rcChannelValuesChanged(inlChannels, count);
}

void CustomPlugin::_advancedChanged(bool changed)
{
    // Firmware Upgrade page is only show in Advanced mode
    emit _options->showFirmwareUpgradeChanged(changed);
}

//-----------------------------------------------------------------------------
void CustomPlugin::_addSettingsEntry(const QString& title, const char* qmlFile, const char* iconFile)
{
    Q_CHECK_PTR(qmlFile);
    // 'this' instance will take ownership on the QmlComponentInfo instance
    _customSettingsList.append(QVariant::fromValue(
        new QmlComponentInfo(title,
                QUrl::fromUserInput(qmlFile),
                iconFile == nullptr ? QUrl() : QUrl::fromUserInput(iconFile),
                this)));
}

//-----------------------------------------------------------------------------
QVariantList&
CustomPlugin::settingsPages()
{
    if(_customSettingsList.isEmpty()) {
        _addSettingsEntry(tr("General"),     "qrc:/qml/GeneralSettings.qml",     "qrc:/res/gear-white.svg");
        _addSettingsEntry(tr("Comm Links"),  "qrc:/qml/LinkSettings.qml",        "qrc:/res/waves.svg");
        _addSettingsEntry(tr("Offline Maps"),"qrc:/qml/OfflineMap.qml",          "qrc:/res/waves.svg");
        _addSettingsEntry(tr("Yellow Scan"), "qrc:/qml/DeviceSettings.qml",   "qrc:/res/cameraSetting.svg");
        _addSettingsEntry(tr("MAVLink"),     "qrc:/qml/MavlinkSettings.qml",     "qrc:/res/waves.svg");
        _addSettingsEntry(tr("Console"),     "qrc:/qml/QGroundControl/Controls/AppMessages.qml");
        _addSettingsEntry(tr("RTCM"), "qrc:/custom/RTCMSettings.qml");

        if(_m2Manager != nullptr) {
            qInfo() << "M2Manager Not null";
            _addSettingsEntry(tr("M2Link"), "qrc:/qml/M2Settings.qml");
        }
        else {
            bool isDoodle = _qmlInterface && _qmlInterface->arManager()
                && _qmlInterface->arManager()->usingDoodleApi();

            qInfo() << "M2Manager is null, isDoodle:" << isDoodle;
            // Show Rajant settings if available, otherwise Enpulse/DoodleLab
            if (_rajantManager != nullptr) {
                _addSettingsEntry(tr("Rajant"), "qrc:/qml/RajantSettings.qml");
            }
            else {
                _addSettingsEntry(isDoodle ? tr("DoodleLab") : tr("Enpulse"), "qrc:/qml/ARSettings.qml");
            }
        }
        _addSettingsEntry(tr("GeoAwareness"), "qrc:/qml/geoFenceSettings.qml");
#if defined(QT_DEBUG)
        //-- These are always present on Debug builds
        _addSettingsEntry(tr("Mock Link"),   "qrc:/qml/MockLink.qml");
#endif
    }
    return _customSettingsList;
}

QGCOptions* CustomPlugin::options()
{
    return _options;
}

QString CustomPlugin::brandImageIndoor(void) const
{
    return QStringLiteral("/custom/img/CustomAppIcon.png");
}

QString CustomPlugin::brandImageOutdoor(void) const
{
    return QStringLiteral("/custom/img/CustomAppIconOutdoor.png");
}

bool CustomPlugin::overrideSettingsGroupVisibility(QString name)
{
    // We have set up our own specific brand imaging. Hide the brand image settings such that the end user
    // can't change it.
    if (name == BrandImageSettings::name) {
        return false;
    }
    return true;
}

// This allows you to override/hide QGC Application settings
bool CustomPlugin::adjustSettingMetaData(const QString& settingsGroup, FactMetaData& metaData)
{
    bool parentResult = QGCCorePlugin::adjustSettingMetaData(settingsGroup, metaData);

    if (settingsGroup == AppSettings::settingsGroup) {
        // This tells QGC than when you are creating Plans while not connected to a vehicle
        // the specific firmware/vehicle the plan is for.
        if (metaData.name() == AppSettings::offlineEditingFirmwareClassName) {
            metaData.setRawDefaultValue(QGCMAVLink::FirmwareClassPX4);
            return false;
        } else if (metaData.name() == AppSettings::offlineEditingVehicleClassName) {
            metaData.setRawDefaultValue(QGCMAVLink::VehicleClassMultiRotor);
            return false;
        }
    }

    return parentResult;
}

// This modifies QGC colors palette to match possible custom corporate branding
void CustomPlugin::paletteOverride(QString colorName, QGCPalette::PaletteColorInfo_t& colorInfo)
{
    if (colorName == QStringLiteral("window")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#212529");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#212529");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#ffffff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#f8f9fa");
    }
    else if (colorName == QStringLiteral("windowShade")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#343a40");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#343a40");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#f1f3f5");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#d9d9d9");
    }
    else if (colorName == QStringLiteral("windowShadeDark")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#1a1c1f");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#1a1c1f");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#e9ecef");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#bdbdbd");
    }
    else if (colorName == QStringLiteral("text")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#ffffff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#777c89");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#212529");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#9d9d9d");
    }
    else if (colorName == QStringLiteral("warningText")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#e03131");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#e03131");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#cc0808");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#cc0808");
    }
    else if (colorName == QStringLiteral("button")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#495057");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#495057");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#ffffff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#ffffff");
    }
    else if (colorName == QStringLiteral("buttonText")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#ffffff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#777c89");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#212529");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#9d9d9d");
    }
    else if (colorName == QStringLiteral("buttonHighlight")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#07916d");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#495057");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#aeebd0");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#e4e4e4");
    }
    else if (colorName == QStringLiteral("buttonHighlightText")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#ffffff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#777c89");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#212529");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#2c2c2c");
    }
    else if (colorName == QStringLiteral("primaryButton")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#12b886");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#495057");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#aeebd0");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#585858");
    }
    else if (colorName == QStringLiteral("primaryButtonText")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#ffffff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#ffffff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#212529");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#cad0d0");
    }
    else if (colorName == QStringLiteral("textField")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#212529");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#495057");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#f1f3f5");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#ffffff");
    }
    else if (colorName == QStringLiteral("textFieldText")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#ffffff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#777c89");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#212529");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#808080");
    }
    else if (colorName == QStringLiteral("mapButton")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#000000");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#585858");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#212529");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#585858");
    }
    else if (colorName == QStringLiteral("mapButtonHighlight")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#07916d");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#585858");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#be781c");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#585858");
    }
    else if (colorName == QStringLiteral("mapIndicator")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#9dda4f");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#585858");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#be781c");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#585858");
    }
    else if (colorName == QStringLiteral("mapIndicatorChild")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#527942");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#585858");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#766043");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#585858");
    }
    else if (colorName == QStringLiteral("colorGreen")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#27bf89");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#0ca678");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#009431");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#009431");
    }
    else if (colorName == QStringLiteral("colorOrange")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#f7b24a");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#f6921e");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#b95604");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#b95604");
    }
    else if (colorName == QStringLiteral("colorRed")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#e1544c");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#e03131");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#ed3939");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#ed3939");
    }
    else if (colorName == QStringLiteral("colorGrey")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#8b90a0");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#8b90a0");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#808080");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#808080");
    }
    else if (colorName == QStringLiteral("colorBlue")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#228be6");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#228be6");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#1a72ff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#1a72ff");
    }
    else if (colorName == QStringLiteral("alertBackground")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#d4b106");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#d4b106");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#fffb8f");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#b45d48");
    }
    else if (colorName == QStringLiteral("alertBorder")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#876800");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#876800");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#808080");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#808080");
    }
    else if (colorName == QStringLiteral("alertText")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#000000");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#fff9ed");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#212529");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#fff9ed");
    }
    else if (colorName == QStringLiteral("missionItemEditor")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#212529");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#0b1420");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#ffffff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#585858");
    }
    else if (colorName == QStringLiteral("hoverColor")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#07916d");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#33c494");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#aeebd0");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#464f5a");
    }
    else if (colorName == QStringLiteral("mapWidgetBorderLight")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#ffffff");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#ffffff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#f1f3f5");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#ffffff");
    }
    else if (colorName == QStringLiteral("mapWidgetBorderDark")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#000000");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#000000");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#212529");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#000000");
    }
    else if (colorName == QStringLiteral("brandingPurple")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#4a2c6d");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#4a2c6d");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#4a2c6d");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#4a2c6d");
    }
    else if (colorName == QStringLiteral("brandingBlue")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#6045c5");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#48d6ff");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#6045c5");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#48d6ff");
    }
}

// We override this so we can get access to QQmlApplicationEngine and use it to register our qml module
QQmlApplicationEngine* CustomPlugin::createQmlApplicationEngine(QObject* parent)
{
    QQmlApplicationEngine* qmlEngine = QGCCorePlugin::createQmlApplicationEngine(parent);
    qmlEngine->addImportPath("qrc:/Custom/Widgets");
    _qmlInterface = new CustomQmlInterface(qgcApp(), qgcApp()->toolbox());
    CustomQmlInterface::setInstance(_qmlInterface);
    qmlEngine->rootContext()->setContextProperty("CustomQmlInterface", _qmlInterface);

    if(_aviatorInterface) {
        qDebug() << "Connect with handleCustomButtonFunc";
        //connect(_aviatorInterface, &AVIATORInterface::buttonPressed, _qmlInterface, &CustomQmlInterface::handleCustomButtonFunction);
    }

    // Initialize M2 broadcast socket
    _m2boardcastSocket = new QUdpSocket(this);
    if(_m2boardcastSocket->bind(QHostAddress::AnyIPv4, 10010, QUdpSocket::ShareAddress)) {
        connect(_m2boardcastSocket, &QUdpSocket::readyRead, this, [this]() {
            if(_m2boardcastSocket->hasPendingDatagrams()) {
                QByteArray datagram;
                datagram.resize(_m2boardcastSocket->pendingDatagramSize());

                QHostAddress sender;
                quint16 senderPort;

                _m2boardcastSocket->readDatagram(datagram.data(), datagram.size(), &sender, &senderPort);
                QString message = QString::fromUtf8(datagram);

                qDebug() << "Received multicast message from" << sender.toString() << ":" << message;

                QRegExp rx("AP:\\d+\\.\\d+\\.\\d+");
                if(rx.exactMatch(message)) {
                    qDebug() << "Found matching version format, leaving multicast group";

                    QString ipStr = sender.toString();
                    if(_m2Manager == nullptr) {
                        qInfo() << "new M2Manager";
                        _m2Manager = new M2Manager(ipStr, this);
                        emit m2ManagerChanged();
                    }

                    _m2boardcastSocket->disconnect();
                    _m2boardcastSocket->close();
                    _m2boardcastSocket->deleteLater();
                    _m2boardcastSocket = nullptr;
                }
            }
        });
    } else {
        qWarning() << "Failed to bind multicast socket:" << _m2boardcastSocket->errorString();
        _m2boardcastSocket->deleteLater();
        _m2boardcastSocket = nullptr;
    }
    // Initialize Rajant BCAPI connection
    // Discovers Rajant nodes via IPv6 link-local neighbor scan,
    // then connects via TCP:2300 for RSSI monitoring.
    _initRajantDiscovery();

    // Rebuild settings list when Rajant connects/disconnects
    // so Rajant entry replaces Enpulse
    connect(this, &CustomPlugin::rajantManagerChanged, this, [this]() {
        _customSettingsList.clear();
    });

    return qmlEngine;
}

QString CustomPlugin::_activeNonRajantLinkName() const
{
    // Enpulse M2 — _m2Manager exists ⇒ M2 link is in use.
    // Note: we treat existence as "in use" because M2Manager is only created
    // after a discovery broadcast confirms an M2 board is on the network.
    if (_m2Manager != nullptr) {
        return QStringLiteral("Enpulse M2");
    }
    // Enpulse M1 / DoodleLab — same QObject (CustomQmlInterface::arManager),
    // distinguished by the version string. Only block if it's actually connected.
    if (_qmlInterface && _qmlInterface->arManager() &&
        _qmlInterface->arManager()->connected()) {
        const bool isDoodle = _qmlInterface->arManager()->usingDoodleApi();
        return isDoodle ? QStringLiteral("DoodleLab") : QStringLiteral("Enpulse M1");
    }
    return QString();   // empty → no other link active, Rajant may proceed
}

void CustomPlugin::_initRajantDiscovery()
{
    // Auto-discover Rajant nodes on the network.
    //
    // Method:
    //   1. Collect fe80:: link-local IPv6 neighbors (SUP multicast on Android,
    //      system neighbor table on desktop, netlink fallback on Android).
    //   2. Probe TCP:2300 on each candidate. The TCP probe is the real gate:
    //      only Rajant BCAPI nodes listen on 2300, so non-Rajant neighbors
    //      fall out naturally — no hardcoded MAC OUI list to maintain.
    //   3. Connect to the first candidate that responds.
    //
    // Works on both Windows (netsh) and Android/Linux (ip -6 neigh).

    // Skip if another radio link is already connected — Rajant should never
    // compete for the link with Enpulse M1/M2 or DoodleLab.
    QString blocking = _activeNonRajantLinkName();
    if (!blocking.isEmpty()) {
        qInfo() << "RajantDiscovery:" << blocking << "is active — skipping Rajant scan.";
        return;
    }

    // Stop retrying after max attempts (no Rajant hardware present)
#if defined(Q_OS_ANDROID)
    static const int maxRetries = 5;   // 5 x 10s = 50 seconds
#else
    static const int maxRetries = 5;   // 5 x 10s = 50 seconds
#endif
    if (_rajantDiscoveryRetries >= maxRetries) {
        qInfo() << "RajantDiscovery: no Rajant hardware found after"
            << _rajantDiscoveryRetries << "attempts. Stopping discovery.";
        return;
    }
    _rajantDiscoveryRetries++;

    // Allow password override via env var
    QByteArray envPass = qgetenv("RAJANT_PASSWORD");
    if (!envPass.isEmpty()) {
        _rajantPassword = QString::fromUtf8(envPass);
    }

    // Allow manual override via env var (skips auto-discovery)
    QByteArray envAddr = qgetenv("RAJANT_NODE");
    if (!envAddr.isEmpty()) {
        QString addr = QString::fromUtf8(envAddr);
        qInfo() << "RajantDiscovery: using RAJANT_NODE env override:" << addr;
        _rajantManager = new RajantManager(addr, _rajantPassword, this);
        emit rajantManagerChanged();
        return;
    }

    qInfo() << "RajantDiscovery: starting auto-discovery...";

#if defined(Q_OS_ANDROID)
    // Android: apps are sandboxed — "ip" command and /proc/net files are blocked.
    // Rajant BCAPI only listens on IPv6 link-local.
    //
    // The blocking work (usleep pauses, recvfrom, netlink dumps) runs on a
    // worker thread from Qt's thread pool — otherwise the UI would freeze
    // for 1-3 s on every discovery attempt. Results are posted back to the
    // main thread before we touch _rajantCandidates, schedule a retry, or
    // start any QTcpSocket probes.
    //
    // Strategy (runs on worker thread):
    //   1. Find eth0/USB-Ethernet interface and its IPv4 gateway
    //   2. Send UDP poke to gateway to ensure ARP entry exists in kernel
    //   3. Send SUP multicast to discover Rajant nodes via their own protocol
    //   4. Query kernel neighbor table via Netlink to get MAC addresses
    //   5. Construct fe80:: EUI-64 addresses from every neighbor MAC
    //      (no OUI filter — TCP:2300 probe is the real gate)
    //   6. Probe TCP:2300 on candidates (on main thread, after marshalling)
    QtConcurrent::run([this]() {
        QStringList foundCandidates;
        const auto interfaces = QNetworkInterface::allInterfaces();

    // --- Step 1: Find gateways and poke them via UDP to populate ARP cache ---
    // Track Ethernet (non-wlan) gateways separately — those are Rajant ground units
    QStringList gatewayIPs;
    QStringList ethernetGatewayIPs; // only eth0/usb etc, not wlan
    for (const auto& iface : interfaces) {
        if (!(iface.flags() & QNetworkInterface::IsUp)) continue;
        if (iface.flags() & QNetworkInterface::IsLoopBack) continue;

        qInfo() << "RajantDiscovery: interface" << iface.name()
            << "index:" << iface.index() << "flags:" << iface.flags();

        bool isWifi = iface.name().startsWith("wlan", Qt::CaseInsensitive) ||
            iface.name().startsWith("wifi", Qt::CaseInsensitive);

        for (const auto& entry : iface.addressEntries()) {
            QHostAddress addr = entry.ip();
            if (addr.protocol() != QAbstractSocket::IPv4Protocol) continue;
            if (addr.isLoopback()) continue;
            quint32 ip4 = addr.toIPv4Address();
            quint32 mask = entry.netmask().toIPv4Address();
            quint32 gw = (ip4 & mask) | 1;
            if (gw == ip4) continue;
            QString gwStr = QHostAddress(gw).toString();
            qInfo() << "RajantDiscovery:" << iface.name() << "ip:" << addr.toString()
                << "gateway:" << gwStr << (isWifi ? "(wifi)" : "(ethernet)");
            if (!gatewayIPs.contains(gwStr))
                gatewayIPs.append(gwStr);
            if (!isWifi && !ethernetGatewayIPs.contains(gwStr))
                ethernetGatewayIPs.append(gwStr);
        }
    }

    // Poke each gateway with UDP to force ARP resolution — send twice for reliability
    for (int attempt = 0; attempt < 2; attempt++) {
        for (const QString& gw : gatewayIPs) {
            int pokeSock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
            if (pokeSock >= 0) {
                struct sockaddr_in dst;
                memset(&dst, 0, sizeof(dst));
                dst.sin_family = AF_INET;
                dst.sin_port = htons(1);
                inet_pton(AF_INET, gw.toLatin1().constData(), &dst.sin_addr);
                char poke = 0;
                sendto(pokeSock, &poke, 1, 0,
                    reinterpret_cast<struct sockaddr*>(&dst), sizeof(dst));
                ::close(pokeSock);
            }
        }
        if (attempt == 0) usleep(100000); // 100ms between pokes
    }
    qInfo() << "RajantDiscovery: ARP poke sent to" << gatewayIPs;
    // Wait for ARP to complete
    usleep(500000); // 500ms

    // --- Step 2: SUP multicast discovery (Rajant's own protocol) ---
    // Send SUP REQUEST to ff02::1 port 35057 on all interfaces
    QByteArray supRequest;
    supRequest.append(BcapiProtocol::encodeTag(1, BcapiProtocol::VARINT));
    supRequest.append(BcapiProtocol::encodeVarint(0x73757000));
    supRequest.append(BcapiProtocol::encodeTag(2, BcapiProtocol::VARINT));
    supRequest.append(BcapiProtocol::encodeVarint(0)); // REQUEST
    QByteArray svcName = "com.rajant.breadcrumb.v11";
    supRequest.append(BcapiProtocol::encodeTag(3, BcapiProtocol::LENGTH_DELIMITED));
    supRequest.append(BcapiProtocol::encodeVarint(svcName.size()));
    supRequest.append(svcName);
    supRequest.append(BcapiProtocol::encodeTag(5, BcapiProtocol::VARINT));
    supRequest.append(BcapiProtocol::encodeVarint(500));

    int supSock = socket(AF_INET6, SOCK_DGRAM, IPPROTO_UDP);
    if (supSock >= 0) {
        struct sockaddr_in6 bindAddr;
        memset(&bindAddr, 0, sizeof(bindAddr));
        bindAddr.sin6_family = AF_INET6;
        bindAddr.sin6_addr = in6addr_any;
        ::bind(supSock, reinterpret_cast<struct sockaddr*>(&bindAddr), sizeof(bindAddr));

        struct timeval tv = { 2, 0 }; // 2s receive timeout
        setsockopt(supSock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

        for (const auto& iface : interfaces) {
            if (!(iface.flags() & QNetworkInterface::IsUp)) continue;
            if (iface.flags() & QNetworkInterface::IsLoopBack) continue;
            unsigned int ifidx = iface.index();
            if (ifidx == 0) continue;

            setsockopt(supSock, IPPROTO_IPV6, IPV6_MULTICAST_IF, &ifidx, sizeof(ifidx));

            struct sockaddr_in6 dst;
            memset(&dst, 0, sizeof(dst));
            dst.sin6_family = AF_INET6;
            dst.sin6_port = htons(35057);
            dst.sin6_scope_id = ifidx;
            inet_pton(AF_INET6, "ff02::1", &dst.sin6_addr);

            ssize_t sent = sendto(supSock, supRequest.constData(), supRequest.size(), 0,
                reinterpret_cast<struct sockaddr*>(&dst), sizeof(dst));
            qInfo() << "RajantDiscovery: SUP on" << iface.name()
                << (sent > 0 ? "OK" : strerror(errno));
        }

        // Collect SUP responses
        char respBuf[548];
        struct sockaddr_in6 srcAddr;
        while (true) {
            socklen_t srcLen = sizeof(srcAddr);
            ssize_t n = recvfrom(supSock, respBuf, sizeof(respBuf), 0,
                reinterpret_cast<struct sockaddr*>(&srcAddr), &srcLen);
            if (n <= 0) break;

            char addrBuf[INET6_ADDRSTRLEN];
            inet_ntop(AF_INET6, &srcAddr.sin6_addr, addrBuf, sizeof(addrBuf));
            QString senderAddr = QString::fromLatin1(addrBuf);
            if (!senderAddr.startsWith("fe80", Qt::CaseInsensitive)) continue;

            char ifnameBuf[IF_NAMESIZE] = {};
            QString ifname = (srcAddr.sin6_scope_id > 0 && if_indextoname(srcAddr.sin6_scope_id, ifnameBuf))
                ? QString::fromLatin1(ifnameBuf) : QString::number(srcAddr.sin6_scope_id);
            QString addr6 = senderAddr + "%" + ifname;

            // Verify SUP RESPONSE (field 2 = 1)
            QByteArray resp = QByteArray::fromRawData(respBuf, n);
            int pos = 0;
            bool isResponse = false;
            while (pos < resp.size()) {
                BcapiProtocol::Tag tag = BcapiProtocol::decodeTag(resp, pos);
                if (tag.fieldNumber == 0) break;
                if (tag.wireType == BcapiProtocol::VARINT) {
                    quint64 val = BcapiProtocol::decodeVarint(resp, pos);
                    if (tag.fieldNumber == 2 && val == 1) isResponse = true;
                }
                else if (tag.wireType == BcapiProtocol::LENGTH_DELIMITED) {
                    pos += BcapiProtocol::decodeVarint(resp, pos);
                }
                else break;
            }
            if (!isResponse) continue;

            if (!foundCandidates.contains(addr6)) {
                foundCandidates.append(addr6);
                qInfo() << "RajantDiscovery: SUP response from" << addr6;
            }
        }
        ::close(supSock);
    }
    else {
        qInfo() << "RajantDiscovery: UDP6 socket failed:" << strerror(errno);
    }

    // --- Step 2b: Identify the ground unit (Ethernet gateway's MAC) and put it first ---
    // The gateway on eth0 (not wlan0) is the directly-connected Rajant ground unit.
    // Match its MAC (from ARP/netlink) to the SUP fe80:: candidates.
    if (foundCandidates.size() > 1 && !ethernetGatewayIPs.isEmpty()) {
        qInfo() << "RajantDiscovery: identifying ground unit from ethernet gateways:" << ethernetGatewayIPs;
        int nlSock = socket(AF_NETLINK, SOCK_DGRAM, NETLINK_ROUTE);
        if (nlSock >= 0) {
            struct { struct nlmsghdr nlh; struct ndmsg ndm; } req;
            memset(&req, 0, sizeof(req));
            req.nlh.nlmsg_len = sizeof(req);
            req.nlh.nlmsg_type = RTM_GETNEIGH;
            req.nlh.nlmsg_flags = NLM_F_REQUEST | NLM_F_DUMP;
            req.nlh.nlmsg_seq = 1;
            req.ndm.ndm_family = AF_INET;
            if (::send(nlSock, &req, sizeof(req), 0) >= 0) {
                char buf[16384];
                bool nlDone = false;
                while (!nlDone) {
                    int len = ::recv(nlSock, buf, sizeof(buf), 0);
                    if (len <= 0) break;
                    for (struct nlmsghdr* nh = reinterpret_cast<struct nlmsghdr*>(buf);
                        NLMSG_OK(nh, static_cast<unsigned>(len));
                        nh = NLMSG_NEXT(nh, len)) {
                        if (nh->nlmsg_type == NLMSG_DONE) { nlDone = true; break; }
                        if (nh->nlmsg_type == NLMSG_ERROR) { nlDone = true; break; }
                        if (nh->nlmsg_type != RTM_NEWNEIGH) continue;
                        struct ndmsg* ndm = static_cast<struct ndmsg*>(NLMSG_DATA(nh));
                        if (ndm->ndm_family != AF_INET) continue;
                        unsigned char* macAddr = nullptr;
                        void* dstAddr = nullptr;
                        struct rtattr* rta = reinterpret_cast<struct rtattr*>(
                            reinterpret_cast<char*>(ndm) + NLMSG_ALIGN(sizeof(*ndm)));
                        int attrLen = nh->nlmsg_len - NLMSG_LENGTH(sizeof(*ndm));
                        for (; RTA_OK(rta, attrLen); rta = RTA_NEXT(rta, attrLen)) {
                            if (rta->rta_type == NDA_DST)    dstAddr = RTA_DATA(rta);
                            if (rta->rta_type == NDA_LLADDR) macAddr = static_cast<unsigned char*>(RTA_DATA(rta));
                        }
                        if (!dstAddr || !macAddr) continue;
                        char ip4Buf[INET_ADDRSTRLEN];
                        inet_ntop(AF_INET, dstAddr, ip4Buf, sizeof(ip4Buf));
                        if (!ethernetGatewayIPs.contains(QString::fromLatin1(ip4Buf))) continue;

                        // Construct fe80:: EUI-64 from gateway MAC
                        unsigned char eui[16] = { 0xfe,0x80,0,0,0,0,0,0,0,0,0,0,0,0,0,0 };
                        eui[8] = macAddr[0] ^ 0x02;
                        eui[9] = macAddr[1]; eui[10] = macAddr[2];
                        eui[11] = 0xFF; eui[12] = 0xFE;
                        eui[13] = macAddr[3]; eui[14] = macAddr[4]; eui[15] = macAddr[5];
                        char euiBuf[INET6_ADDRSTRLEN];
                        inet_ntop(AF_INET6, eui, euiBuf, sizeof(euiBuf));
                        QString groundPrefix = QString::fromLatin1(euiBuf);

                        qInfo() << "RajantDiscovery: gateway" << ip4Buf
                            << "MAC -> ground unit fe80::" << groundPrefix;

                        // Move matching candidate to front of the list
                        for (int i = 0; i < foundCandidates.size(); i++) {
                            if (foundCandidates[i].startsWith(groundPrefix, Qt::CaseInsensitive)) {
                                QString ground = foundCandidates.takeAt(i);
                                foundCandidates.prepend(ground);
                                qInfo() << "RajantDiscovery: prioritized ground unit:" << ground;
                                break;
                            }
                        }
                    }
                }
            }
            ::close(nlSock);
        }
    }

    // --- Step 3: Netlink neighbor table fallback (if no SUP responses) ---
    if (foundCandidates.isEmpty()) {
        qInfo() << "RajantDiscovery: no SUP response, reading neighbor table via netlink...";

        int nlSock = socket(AF_NETLINK, SOCK_DGRAM, NETLINK_ROUTE);
        if (nlSock >= 0) {
            struct { struct nlmsghdr nlh; struct ndmsg ndm; } req;
            memset(&req, 0, sizeof(req));
            req.nlh.nlmsg_len = sizeof(req);
            req.nlh.nlmsg_type = RTM_GETNEIGH;
            req.nlh.nlmsg_flags = NLM_F_REQUEST | NLM_F_DUMP;
            req.nlh.nlmsg_seq = 1;
            req.ndm.ndm_family = AF_UNSPEC;

            if (::send(nlSock, &req, sizeof(req), 0) >= 0) {
                char buf[16384];
                bool nlDone = false;
                while (!nlDone) {
                    int len = ::recv(nlSock, buf, sizeof(buf), 0);
                    if (len <= 0) break;
                    for (struct nlmsghdr* nh = reinterpret_cast<struct nlmsghdr*>(buf);
                        NLMSG_OK(nh, static_cast<unsigned>(len));
                        nh = NLMSG_NEXT(nh, len)) {
                        if (nh->nlmsg_type == NLMSG_DONE) { nlDone = true; break; }
                        if (nh->nlmsg_type == NLMSG_ERROR) { nlDone = true; break; }
                        if (nh->nlmsg_type != RTM_NEWNEIGH) continue;

                        struct ndmsg* ndm = static_cast<struct ndmsg*>(NLMSG_DATA(nh));
                        unsigned char* macAddr = nullptr;
                        int macLen = 0;
                        void* dstAddr = nullptr;
                        struct rtattr* rta = reinterpret_cast<struct rtattr*>(
                            reinterpret_cast<char*>(ndm) + NLMSG_ALIGN(sizeof(*ndm)));
                        int attrLen = nh->nlmsg_len - NLMSG_LENGTH(sizeof(*ndm));
                        for (; RTA_OK(rta, attrLen); rta = RTA_NEXT(rta, attrLen)) {
                            if (rta->rta_type == NDA_DST)    dstAddr = RTA_DATA(rta);
                            if (rta->rta_type == NDA_LLADDR) {
                                macAddr = static_cast<unsigned char*>(RTA_DATA(rta));
                                macLen = RTA_PAYLOAD(rta);
                            }
                        }
                        if (!macAddr || macLen < 6) continue;

                        // Log ALL neighbor entries for debugging
                        QString mac = QString("%1:%2:%3:%4:%5:%6")
                            .arg(macAddr[0], 2, 16, QChar('0')).arg(macAddr[1], 2, 16, QChar('0'))
                            .arg(macAddr[2], 2, 16, QChar('0')).arg(macAddr[3], 2, 16, QChar('0'))
                            .arg(macAddr[4], 2, 16, QChar('0')).arg(macAddr[5], 2, 16, QChar('0'));
                        char ifnBuf[IF_NAMESIZE] = {};
                        QString ifn = if_indextoname(ndm->ndm_ifindex, ifnBuf)
                            ? QString::fromLatin1(ifnBuf) : QString::number(ndm->ndm_ifindex);

                        char ipBuf[INET6_ADDRSTRLEN] = {};
                        if (dstAddr) {
                            if (ndm->ndm_family == AF_INET6)
                                inet_ntop(AF_INET6, dstAddr, ipBuf, sizeof(ipBuf));
                            else if (ndm->ndm_family == AF_INET)
                                inet_ntop(AF_INET, dstAddr, ipBuf, sizeof(ipBuf));
                        }
                        qInfo() << "RajantDiscovery: neigh" << ipBuf << "MAC:" << mac
                            << "iface:" << ifn << "family:" << ndm->ndm_family;

                        // No OUI filter: every fe80:: neighbor with a MAC is a candidate.
                        // Non-Rajant devices will simply fail the TCP:2300 probe.

                        if (ndm->ndm_family == AF_INET6 && dstAddr) {
                            // Only fe80:: link-local addresses can host a Rajant BCAPI peer
                            QString ip6Str = QString::fromLatin1(ipBuf);
                            if (!ip6Str.startsWith("fe80", Qt::CaseInsensitive)) continue;
                            QString addr6 = QString("%1%%%2").arg(ip6Str, ifn);
                            if (!foundCandidates.contains(addr6)) {
                                foundCandidates.append(addr6);
                                qInfo() << "RajantDiscovery: candidate IPv6:" << addr6 << "MAC:" << mac;
                            }
                        }
                        else if (ndm->ndm_family == AF_INET && dstAddr) {
                            // Construct fe80:: EUI-64 from MAC
                            unsigned char eui[16] = { 0xfe,0x80,0,0,0,0,0,0,0,0,0,0,0,0,0,0 };
                            eui[8] = macAddr[0] ^ 0x02;
                            eui[9] = macAddr[1]; eui[10] = macAddr[2];
                            eui[11] = 0xFF; eui[12] = 0xFE;
                            eui[13] = macAddr[3]; eui[14] = macAddr[4]; eui[15] = macAddr[5];
                            char euiBuf[INET6_ADDRSTRLEN];
                            inet_ntop(AF_INET6, eui, euiBuf, sizeof(euiBuf));
                            // Try all IPv6 scope IDs we can find
                            for (const auto& iface : interfaces) {
                                if (!(iface.flags() & QNetworkInterface::IsUp)) continue;
                                if (iface.flags() & QNetworkInterface::IsLoopBack) continue;
                                // Only use interfaces that have the same index or have fe80::
                                for (const auto& entry : iface.addressEntries()) {
                                    if (entry.ip().protocol() == QAbstractSocket::IPv6Protocol &&
                                        entry.ip().toString().startsWith("fe80", Qt::CaseInsensitive)) {
                                        QString sid = entry.ip().scopeId();
                                        if (sid.isEmpty()) sid = iface.name();
                                        QString addr6 = QString("%1%%%2").arg(euiBuf, sid);
                                        if (!foundCandidates.contains(addr6)) {
                                            foundCandidates.append(addr6);
                                            qInfo() << "RajantDiscovery: candidate ARP->IPv6:" << addr6
                                                << "(from" << ipBuf << "MAC:" << mac << ")";
                                        }
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }
            }
            else {
                qWarning() << "RajantDiscovery: netlink send failed:" << strerror(errno);
            }
            ::close(nlSock);
        }
        else {
            qWarning() << "RajantDiscovery: netlink socket failed:" << strerror(errno);
        }
    }

        // Hand results back to the main thread for UI-touching work
        // (QTcpSocket probes, QTimer scheduling, emitting signals).
        QMetaObject::invokeMethod(this, [this, foundCandidates]() {
            // Re-check: another link may have come online while the worker was running.
            QString blocking = _activeNonRajantLinkName();
            if (!blocking.isEmpty()) {
                qInfo() << "RajantDiscovery:" << blocking
                        << "came online during scan — discarding candidates.";
                return;
            }
            _rajantCandidates = foundCandidates;
            if (_rajantCandidates.isEmpty()) {
                qWarning() << "RajantDiscovery: no Rajant nodes found. Retrying in 10s...";
                QTimer::singleShot(10000, this, &CustomPlugin::_initRajantDiscovery);
                return;
            }
            qInfo() << "RajantDiscovery: probing" << _rajantCandidates.size() << "candidates via TCP:2300...";
            _tryNextRajantCandidate();
        }, Qt::QueuedConnection);
    }); // end QtConcurrent::run

#else
    // Desktop: Query IPv6 neighbor table via system command
    QProcess* process = new QProcess(this);
    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
        this, &CustomPlugin::_onRajantScanFinished);

#if defined(Q_OS_WIN)
    // Windows: netsh interface ipv6 show neighbors
    process->start("netsh", QStringList() << "interface" << "ipv6" << "show" << "neighbors");
#else
    // Linux: ip -6 neigh show
    process->start("ip", QStringList() << "-6" << "neigh" << "show");
#endif

#endif // Q_OS_ANDROID
}

void CustomPlugin::_onRajantScanFinished(int exitCode, QProcess::ExitStatus exitStatus)
{
    QProcess* process = qobject_cast<QProcess*>(sender());
    if (!process) return;

    QString output = QString::fromLocal8Bit(process->readAllStandardOutput());
    process->deleteLater();

    if (exitCode != 0 || exitStatus != QProcess::NormalExit) {
        qWarning() << "RajantDiscovery: neighbor scan failed, exit code:" << exitCode;
        // Retry after 10 seconds
        QTimer::singleShot(10000, this, &CustomPlugin::_initRajantDiscovery);
        return;
    }

    // Collect every fe80:: link-local neighbor as a candidate.
    // We no longer filter by MAC OUI — the TCP:2300 probe is the real gate,
    // so this works with any Rajant hardware variant (old, OEM, re-branded)
    // regardless of which manufacturer prefix the MAC uses.
    _rajantCandidates.clear();

    const QStringList lines = output.split('\n');
    for (const QString& line : lines) {
        QString trimmed = line.trimmed();
        if (!trimmed.contains("fe80", Qt::CaseInsensitive)) continue;

        // Skip entries the OS has marked as stale / unreachable
        if (trimmed.contains("Unreachable", Qt::CaseInsensitive)) continue;

        // Extract the fe80:: address
        // Windows format: "fe80::848d:84ff:fe42:bc30     86-8d-84-42-bc-30  Reachable"
        // Linux format:   "fe80::848d:84ff:fe42:bc30 dev eth0 lladdr 86:8d:84:42:bc:30 REACHABLE"
        QStringList parts = trimmed.split(QRegExp("\\s+"));
        if (parts.isEmpty()) continue;

        QString ipv6Addr = parts.first();
        if (!ipv6Addr.startsWith("fe80", Qt::CaseInsensitive)) continue;

        // On Windows, we need to find the interface index for scoping
        // The address from netsh doesn't include the scope, we need to add it
        // We'll try connecting without scope first, then with detected interfaces
        if (!_rajantCandidates.contains(ipv6Addr)) {
            _rajantCandidates.append(ipv6Addr);
            qInfo() << "RajantDiscovery: candidate:" << ipv6Addr
                << "MAC:" << (parts.size() > 1 ? parts.at(1) : "unknown");
        }
    }

    if (_rajantCandidates.isEmpty()) {
        qInfo() << "RajantDiscovery: no Rajant nodes found on network."
            << "Make sure a Rajant node is connected via Ethernet.";

        // Retry discovery after 10 seconds
        QTimer::singleShot(10000, this, &CustomPlugin::_initRajantDiscovery);
        return;
    }

    // For Windows, we need to add the scope ID (interface index) to each candidate
    // Find all interfaces with fe80:: addresses and try each combination
#if defined(Q_OS_WIN)
    QStringList scopedCandidates;
    const auto interfaces = QNetworkInterface::allInterfaces();
    for (const auto& iface : interfaces) {
        if (!(iface.flags() & QNetworkInterface::IsUp)) continue;
        if (iface.flags() & QNetworkInterface::IsLoopBack) continue;

        for (const auto& entry : iface.addressEntries()) {
            QHostAddress addr = entry.ip();
            if (addr.protocol() == QAbstractSocket::IPv6Protocol &&
                addr.toString().startsWith("fe80", Qt::CaseInsensitive)) {
                // Get the scope ID from our own address
                QString scopeId = addr.scopeId();
                if (scopeId.isEmpty()) continue;

                for (const QString& candidate : _rajantCandidates) {
                    QString scoped = candidate + "%" + scopeId;
                    scopedCandidates.append(scoped);
                }
            }
        }
    }
    _rajantCandidates = scopedCandidates;
#endif

    qInfo() << "RajantDiscovery: probing" << _rajantCandidates.size() << "candidates via TCP:2300...";

    // Try connecting to each candidate
    _tryNextRajantCandidate();
}

void CustomPlugin::_tryNextRajantCandidate()
{
    // Re-check on every probe — another link may have come online between probes.
    QString blocking = _activeNonRajantLinkName();
    if (!blocking.isEmpty()) {
        qInfo() << "RajantDiscovery:" << blocking
                << "is active — aborting probe sequence.";
        _rajantCandidates.clear();
        return;
    }

    if (_rajantCandidates.isEmpty()) {
        qInfo() << "RajantDiscovery: no candidates responded on TCP:2300."
            << "Retrying in 10 seconds...";
        QTimer::singleShot(10000, this, &CustomPlugin::_initRajantDiscovery);
        return;
    }

    QString candidate = _rajantCandidates.takeFirst();
    qInfo() << "RajantDiscovery: probing" << candidate << "...";

    // Clean up previous probe socket
    if (_rajantProbeSocket) {
        _rajantProbeSocket->disconnect();
        _rajantProbeSocket->deleteLater();
    }

    _rajantProbeSocket = new QTcpSocket(this);
    _rajantProbeSocket->setProperty("address", candidate);

    connect(_rajantProbeSocket, &QTcpSocket::connected,
        this, &CustomPlugin::_onRajantProbeConnected);
    connect(_rajantProbeSocket, &QAbstractSocket::errorOccurred,
        this, &CustomPlugin::_onRajantProbeError);

    // 3 second timeout per candidate
    QTimer::singleShot(3000, this, [this, candidate]() {
        if (_rajantProbeSocket && _rajantProbeSocket->state() != QAbstractSocket::ConnectedState &&
            _rajantProbeSocket->property("address").toString() == candidate) {
            qInfo() << "RajantDiscovery: timeout probing" << candidate;
            _rajantProbeSocket->abort();
            _tryNextRajantCandidate();
        }
        });

    QHostAddress hostAddr(candidate);
    _rajantProbeSocket->connectToHost(hostAddr, 2300);
}

void CustomPlugin::_onRajantProbeConnected()
{
    QString address = _rajantProbeSocket->property("address").toString();
    qInfo() << "RajantDiscovery: TCP:2300 responded on" << address
        << "- connecting to identify node type...";

    // Clean up probe socket
    _rajantProbeSocket->disconnect();
    _rajantProbeSocket->close();
    _rajantProbeSocket->deleteLater();
    _rajantProbeSocket = nullptr;

    // The first node to respond is the directly-connected ground unit.
    // Ground unit's Peer.signal = signal ground receives from air (drone).
    // This is the RSSI value the pilot needs on the GCS toolbar.
    _rajantManager = new RajantManager(address, _rajantPassword, this);
    _rajantCandidates.clear();
    emit rajantManagerChanged();

    connect(_rajantManager, &RajantManager::firstStateReceived, this,
        [address](int radioCount) {
            qInfo() << "";
            qInfo() << "=== Rajant Discovery Complete ===";
            qInfo() << "  Ground unit:" << address;
            qInfo() << "  Radios:     " << radioCount;
            qInfo() << "  Displaying:  RSSI (ground <- air)";
            qInfo() << "";
        });
}

void CustomPlugin::_onRajantProbeError(QAbstractSocket::SocketError error)
{
    Q_UNUSED(error);
    QString address = _rajantProbeSocket->property("address").toString();
    qInfo() << "RajantDiscovery: probe failed on" << address << "-" << _rajantProbeSocket->errorString();
    _tryNextRajantCandidate();
}

void CustomPlugin::showMessage(const QString& message, SystemMessage::SystemMessageType type)
{
    qInfo() << "Show Message : "<< message;
    if(_qmlInterface) {
        _qmlInterface->showMessage(message, type);
    }
}
