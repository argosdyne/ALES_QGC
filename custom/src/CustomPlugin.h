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

#include "M2Manager.h"

class CustomOptions;
class CustomPlugin;
class CustomSettings;
class SiYiManager;
class CodevRTCMManager;

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

    CustomQmlInterface* qmlInterface() { return _qmlInterface; }

    // Overrides from QGCCorePlugin
    QVariantList&           settingsPages                   (void) final;
    QGCOptions*             options                         (void) final;
    QString                 brandImageIndoor                (void) const final;
    QString                 brandImageOutdoor               (void) const final;
    bool                    overrideSettingsGroupVisibility (QString name) final;
    bool                    adjustSettingMetaData           (const QString& settingsGroup, FactMetaData& metaData) final;
    void                    paletteOverride                 (QString colorName, QGCPalette::PaletteColorInfo_t& colorInfo) final;
    QQmlApplicationEngine*  createQmlApplicationEngine      (QObject* parent) final;


    Q_PROPERTY(CustomSettings* settings READ settings CONSTANT)
    CustomSettings* settings(){ return _settings; }

    SiYiManager* siyiManager(){return _siyiManager;};
    CodevSettings* codevSettings() { return _codevSettings; }
    CodevRTCMManager* codevRTCMManager() { return _codevRTCMManager; }

    // Overrides from QGCTool
    void                    setToolbox                      (QGCToolbox* toolbox);

    Q_PROPERTY(M2Manager*           m2Manager               READ m2Manager              NOTIFY m2ManagerChanged)
    M2Manager*              m2Manager           ()  { return _m2Manager; }

signals:
    void rcChannelValuesChanged(const quint16* channels, int count);
    void slaveModeChanged(bool slaveMode);
    void m2ManagerChanged               ();

public slots:
    void showMessage(const QString& message, SystemMessage::SystemMessageType type = SystemMessage::Info);

private slots:
    void _advancedChanged(bool advanced);
    void _handleRCChannelValues(const quint16* channels, int count);


private:
    void _addSettingsEntry(const QString& title, const char* qmlFile, const char* iconFile = nullptr);
    QGroundControlQmlGlobal* qGroundControlQmlGlobal;

    QUdpSocket*             _m2boardcastSocket      = nullptr;
    M2Manager*              _m2Manager              = nullptr;

private:
    SiYiManager* _siyiManager = nullptr;
    CodevSettings*      _codevSettings = nullptr;
    CustomSettings* _settings{nullptr};
    CodevRTCMManager*   _codevRTCMManager = nullptr;

    CustomOptions*  _options = nullptr;
    QVariantList    _customSettingsList; // Not to be mixed up with QGCCorePlugin implementation

    CustomQmlInterface* _qmlInterface{nullptr};
    AVIATORInterface* _aviatorInterface{nullptr};
    bool _coachMode{false};
    bool _slaveMode{false};
    bool _forceSendRC{false};

};
