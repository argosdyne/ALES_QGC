/****************************************************************************
 *
 * (c) 2009-2019 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 *   @brief Custom QGCCorePlugin Declaration
 *   @author Gus Grubba <gus@auterion.com>
 */

#pragma once

#include "QGCCorePlugin.h"
#include "QGCOptions.h"
#include "QGCLoggingCategory.h"
#include "SettingsManager.h"
#include "CustomQmlInterface.h"
#include "AVIATORInterface.h"
#include "SiYiManager.h"
#include <QTranslator>
#include "codevsettings.h"

#include "QGroundControlQmlGlobal.h"
#include <QProcess>
#include <QTcpSocket>

#include "M2Manager.h"
#include "RajantManager.h"
#include "ElistairStationManager.h"
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

class CustomOptions;
class CustomPlugin;
class CustomSettings;
class SiYiManager;
class CodevRTCMManager;
class YSManager;

Q_DECLARE_LOGGING_CATEGORY(CustomLog)

class CustomFlyViewOptions : public QGCFlyViewOptions
{
public:
    CustomFlyViewOptions(CustomOptions* options, QObject* parent = nullptr);

    // Overrides from CustomFlyViewOptions
    bool                    showInstrumentPanel         (void) const final;
    bool                    showMultiVehicleList        (void) const final;
};

class CustomOptions : public QGCOptions
{
public:
    CustomOptions(CustomPlugin*, QObject* parent = nullptr);

    // Overrides from QGCOptions
    bool                    wifiReliableForCalibration  (void) const final;
    bool                    showFirmwareUpgrade         (void) const final;
    QGCFlyViewOptions*      flyViewOptions(void) final;

private:
    CustomFlyViewOptions* _flyViewOptions = nullptr;

};

class CustomPlugin : public QGCCorePlugin
{
    Q_OBJECT
public:
    Q_PROPERTY(CodevSettings* codevSettings READ codevSettings CONSTANT)
    Q_PROPERTY(CodevRTCMManager* codevRTCMManager READ codevRTCMManager CONSTANT)
    Q_PROPERTY(SiYiManager* siyiManager READ siyiManager CONSTANT)
    Q_PROPERTY(YSManager* ysManager READ ysManager CONSTANT)


    bool coachMode() { return _coachMode; }
    void setCoachMode(const bool& coachMode);

    Q_PROPERTY(bool slaveMode READ slaveMode WRITE setSlaveMode NOTIFY slaveModeChanged)
    bool slaveMode() { return _slaveMode; }
    void setSlaveMode(bool mode);
    bool forceSendRC() { return _forceSendRC; }
    void setForceSendRC(const bool& force) {
        _forceSendRC = force;
    }

    CustomPlugin(QGCApplication* app, QGCToolbox *toolbox);
    ~CustomPlugin();

    // Overrides from QGCCorePlugin
    QVariantList&           settingsPages                   (void) final;
    QGCOptions*             options                         (void) final;
    QString                 brandImageIndoor                (void) const final;
    QString                 brandImageOutdoor               (void) const final;
    bool                    getOfflineCameraDefinitionFile (QString cameraname, QFile& file) final;
    bool                    overrideSettingsGroupVisibility (QString name) final;
    bool                    adjustSettingMetaData           (const QString& settingsGroup, FactMetaData& metaData) final;
    void                    paletteOverride                 (QString colorName, QGCPalette::PaletteColorInfo_t& colorInfo) final;
    QQmlApplicationEngine*  createQmlApplicationEngine      (QObject* parent) final;


    Q_PROPERTY(CustomSettings* settings READ settings CONSTANT)
    CustomSettings* settings(){ return _settings; }

    // Simple UI saved missions (S24): number of mission items in a .plan, or -1 when the file cannot be read
    // (not a JSON object, fileType not "Plan", no "mission" object with an "items" array, empty or over 20 MB).
    // The preview loads only readable files of moderate size (the classic loader shows its own error popup).
    Q_INVOKABLE int     simplePlanItemCount(const QString& path) const {
        QFile f(path);
        if (f.size() <= 0 || f.size() > 20 * 1024 * 1024 || !f.open(QIODevice::ReadOnly)) return -1;
        QJsonParseError err;
        const QJsonDocument doc = QJsonDocument::fromJson(f.readAll(), &err);
        if (err.error != QJsonParseError::NoError || !doc.isObject()) return -1;
        const QJsonObject o = doc.object();
        const QJsonValue items = o.value(QStringLiteral("mission")).toObject().value(QStringLiteral("items"));
        if (o.value(QStringLiteral("fileType")).toString() != QStringLiteral("Plan") || !items.isArray()) return -1;
        return items.toArray().count();
    }

    SiYiManager* siyiManager(){return _siyiManager;};
    CodevSettings* codevSettings() { return _codevSettings; }
    CodevRTCMManager* codevRTCMManager() { return _codevRTCMManager; }
    YSManager* ysManager() { return _ysManager; }

    AVIATORInterface* aviatorInterface() const { return _aviatorInterface; }
    // Overrides from QGCTool
    void                    setToolbox                      (QGCToolbox* toolbox);

    Q_PROPERTY(M2Manager*           m2Manager               READ m2Manager              NOTIFY m2ManagerChanged)
    M2Manager*              m2Manager           ()  { return _m2Manager; }

    Q_PROPERTY(RajantManager* rajantManager           READ rajantManager          NOTIFY rajantManagerChanged)
    RajantManager* rajantManager() { return _rajantManager; }

    Q_PROPERTY(ElistairStationManager* elistairStationManager READ elistairStationManager CONSTANT)
    ElistairStationManager* elistairStationManager() { return _elistairStationManager; }

signals:
    void rcChannelValuesChanged(const quint16* channels, int count);
    void slaveModeChanged(bool slaveMode);
    void m2ManagerChanged               ();
    void rajantManagerChanged           ();

public slots:
    void showMessage(const QString& message, SystemMessage::SystemMessageType type = SystemMessage::Info);

private slots:
    void _advancedChanged(bool advanced);
    void _handleRCChannelValues(const quint16* channels, int count);


private:
    void _addSettingsEntry(const QString& title, const char* qmlFile, const char* iconFile = nullptr);
    void _initRajantDiscovery();
    void _onRajantScanFinished(int exitCode, QProcess::ExitStatus exitStatus);
    void _tryNextRajantCandidate();
    void _onRajantProbeConnected();
    void _onRajantProbeError(QAbstractSocket::SocketError error);
    // Returns the name of an active non-Rajant link, or empty if none.
    // Used to pre-empt Rajant discovery / probing whenever Enpulse M1, M2 or
    // DoodleLab are already running — Rajant should never compete for the link.
    QString _activeNonRajantLinkName() const;
    QGroundControlQmlGlobal* qGroundControlQmlGlobal;

    QUdpSocket*             _m2boardcastSocket      = nullptr;
    M2Manager*              _m2Manager              = nullptr;
    RajantManager* _rajantManager = nullptr;
    ElistairStationManager* _elistairStationManager = nullptr;
    QStringList             _rajantCandidates;
    QTcpSocket* _rajantProbeSocket = nullptr;
    QString                 _rajantPassword = "breadcrumb-admin";
    int                     _rajantDiscoveryRetries = 0;
    QString                 _pinnedRajantLocalNode;

private:
    SiYiManager* _siyiManager = nullptr;
    CodevSettings*      _codevSettings = nullptr;
    CustomSettings* _settings{nullptr};
    CodevRTCMManager*   _codevRTCMManager = nullptr;
    YSManager* _ysManager = nullptr;

    CustomOptions*  _options = nullptr;
    QVariantList    _customSettingsList; // Not to be mixed up with QGCCorePlugin implementation

    CustomQmlInterface* _qmlInterface{nullptr};
    AVIATORInterface* _aviatorInterface{nullptr};
    bool _coachMode{false};
    bool _slaveMode{false};
    bool _forceSendRC{false};

};
