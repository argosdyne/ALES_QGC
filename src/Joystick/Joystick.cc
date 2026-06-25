/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


#include "Joystick.h"
#include "QGC.h"
#include "AutoPilotPlugin.h"
#include "UAS.h"
#include "QGCApplication.h"
#include "VideoManager.h"
#include "QGCCameraControl.h"
#include "GimbalController.h"
#include "QGCToolbox.h"
#include "SettingsManager.h"
#include "AppSettings.h"

#include <QSettings>
#include <QDateTime>
#include <QFile>
#include <QDir>
#include <QFileInfo>
#include <QXmlStreamWriter>
#include <QXmlStreamReader>
#include <algorithm>
#include <cmath>
#include <limits>

// JoystickLog Category declaration moved to QGCLoggingCategory.cc to allow access in Vehicle
QGC_LOGGING_CATEGORY(JoystickValuesLog, "JoystickValuesLog")

const char* Joystick::_settingsGroup =                  "Joysticks";
const char* Joystick::_calibratedSettingsKey =          "Calibrated4"; // Increment number to force recalibration
const char* Joystick::_buttonActionNameKey =            "ButtonActionName%1";
const char* Joystick::_buttonActionRepeatKey =          "ButtonActionRepeat%1";
const char* Joystick::_throttleModeSettingsKey =        "ThrottleMode";
const char* Joystick::_negativeThrustSettingsKey =      "NegativeThrust";
const char* Joystick::_exponentialSettingsKey =         "Exponential";
const char* Joystick::_accumulatorSettingsKey =         "Accumulator";
const char* Joystick::_deadbandSettingsKey =            "Deadband";
const char* Joystick::_circleCorrectionSettingsKey =    "Circle_Correction";
const char* Joystick::_axisFrequencySettingsKey =       "AxisFrequency";
const char* Joystick::_buttonFrequencySettingsKey =     "ButtonFrequency";
const char* Joystick::_txModeSettingsKey =              nullptr;
const char* Joystick::_fixedWingTXModeSettingsKey =     "TXMode_FixedWing";
const char* Joystick::_multiRotorTXModeSettingsKey =    "TXMode_MultiRotor";
const char* Joystick::_roverTXModeSettingsKey =         "TXMode_Rover";
const char* Joystick::_vtolTXModeSettingsKey =          "TXMode_VTOL";
const char* Joystick::_submarineTXModeSettingsKey =     "TXMode_Submarine";

const char* Joystick::_buttonActionNone =               QT_TR_NOOP("No Action");
const char* Joystick::_buttonActionArm =                QT_TR_NOOP("Arm");
const char* Joystick::_buttonActionDisarm =             QT_TR_NOOP("Disarm");
const char* Joystick::_buttonActionToggleArm =          QT_TR_NOOP("Toggle Arm");
const char* Joystick::_buttonActionVTOLFixedWing =      QT_TR_NOOP("VTOL: Fixed Wing");
const char* Joystick::_buttonActionVTOLMultiRotor =     QT_TR_NOOP("VTOL: Multi-Rotor");
const char* Joystick::_buttonActionContinuousZoomIn =   QT_TR_NOOP("Continuous Zoom In");
const char* Joystick::_buttonActionContinuousZoomOut =  QT_TR_NOOP("Continuous Zoom Out");
const char* Joystick::_buttonActionStepZoomIn =         QT_TR_NOOP("Step Zoom In");
const char* Joystick::_buttonActionStepZoomOut =        QT_TR_NOOP("Step Zoom Out");
const char* Joystick::_buttonActionNextStream =         QT_TR_NOOP("Next Video Stream");
const char* Joystick::_buttonActionPreviousStream =     QT_TR_NOOP("Previous Video Stream");
const char* Joystick::_buttonActionNextCamera =         QT_TR_NOOP("Next Camera");
const char* Joystick::_buttonActionPreviousCamera =     QT_TR_NOOP("Previous Camera");
const char* Joystick::_buttonActionTriggerCamera =      QT_TR_NOOP("Trigger Camera");
const char* Joystick::_buttonActionStartVideoRecord =   QT_TR_NOOP("Start Recording Video");
const char* Joystick::_buttonActionStopVideoRecord =    QT_TR_NOOP("Stop Recording Video");
const char* Joystick::_buttonActionToggleVideoRecord =  QT_TR_NOOP("Toggle Recording Video");
const char* Joystick::_buttonActionGimbalDown =         QT_TR_NOOP("Gimbal Down");
const char* Joystick::_buttonActionGimbalUp =           QT_TR_NOOP("Gimbal Up");
const char* Joystick::_buttonActionGimbalLeft =         QT_TR_NOOP("Gimbal Left");
const char* Joystick::_buttonActionGimbalRight =        QT_TR_NOOP("Gimbal Right");
const char* Joystick::_buttonActionGimbalCenter =       QT_TR_NOOP("Gimbal Center");
const char* Joystick::_buttonActionGimbalYawLock =      QT_TR_NOOP("Gimbal Yaw Lock");
const char* Joystick::_buttonActionGimbalYawFollow =    QT_TR_NOOP("Gimbal Yaw Follow");
const char* Joystick::_buttonActionEmergencyStop =      QT_TR_NOOP("Emergency Stop");
const char* Joystick::_buttonActionGripperGrab =        QT_TR_NOOP("Gripper Close");
const char* Joystick::_buttonActionGripperRelease =     QT_TR_NOOP("Gripper Open");
const char* Joystick::_buttonActionLandingGearDeploy=   QT_TR_NOOP("Landing gear deploy");
const char* Joystick::_buttonActionLandingGearRetract=  QT_TR_NOOP("Landing gear retract");

const char* Joystick::_rgFunctionSettingsKey[Joystick::maxFunction] = {
    "RollAxis",
    "PitchAxis",
    "YawAxis",
    "ThrottleAxis",
    "GimbalPitchAxis",
    "GimbalYawAxis"
};

int Joystick::_transmitterMode = 2;

const float Joystick::_defaultAxisFrequencyHz   = 25.0f;
const float Joystick::_defaultButtonFrequencyHz = 5.0f;
const float Joystick::_minAxisFrequencyHz       = 0.25f;
const float Joystick::_maxAxisFrequencyHz       = 200.0f;
const float Joystick::_minButtonFrequencyHz     = 0.25f;
const float Joystick::_maxButtonFrequencyHz     = 50.0f;

AssignedButtonAction::AssignedButtonAction(QObject* parent, const QString name)
    : QObject(parent)
    , action(name)
{
}

AssignableButtonAction::AssignableButtonAction(QObject* parent, QString action_, bool canRepeat_)
    : QObject(parent)
    , _action(action_)
    , _repeat(canRepeat_)
{
}

Joystick::Joystick(const QString& name, int axisCount, int buttonCount, int hatCount, MultiVehicleManager* multiVehicleManager)
    : _name(name)
    , _axisCount(axisCount)
    , _buttonCount(buttonCount)
    , _hatCount(hatCount)
    , _hatButtonCount(4 * hatCount)
    , _axisVirtualButtonCount(qMax(0, _axisCount - _axisVirtualButtonStartAxis) * 2)
    , _totalButtonCount(_buttonCount + _hatButtonCount + _axisVirtualButtonCount)
    , _multiVehicleManager(multiVehicleManager)
{
    qRegisterMetaType<GRIPPER_ACTIONS>();

    _rgAxisValues   = new int[static_cast<size_t>(_axisCount)];
    _rgLastAxisValues = new int[static_cast<size_t>(_axisCount)];
    _rgAxisNeutralValues = new int[static_cast<size_t>(_axisCount)];
    _rgAxisNeutralInited = new bool[static_cast<size_t>(_axisCount)];
    _rgCalibration  = new Calibration_t[static_cast<size_t>(_axisCount)];
    _rgButtonValues = new uint8_t[static_cast<size_t>(_totalButtonCount)];
    _rgVirtualButtonReleaseMSecs = new qint64[static_cast<size_t>(_axisVirtualButtonCount)];
    for (int i = 0; i < _axisCount; i++) {
        _rgAxisValues[i] = 0;
        _rgLastAxisValues[i] = 0;
        _rgAxisNeutralValues[i] = 0;
        _rgAxisNeutralInited[i] = false;
    }
    for (int i = 0; i < _axisVirtualButtonCount; i++) {
        _rgVirtualButtonReleaseMSecs[i] = 0;
    }
    for (int i = 0; i < _totalButtonCount; i++) {
        _rgButtonValues[i] = BUTTON_UP;
        _buttonActionArray.append(nullptr);
    }
    _buildActionList(_multiVehicleManager->activeVehicle());
    _updateTXModeSettingsKey(_multiVehicleManager->activeVehicle());
    _loadSettings();
    connect(_multiVehicleManager, &MultiVehicleManager::activeVehicleChanged, this, &Joystick::_activeVehicleChanged);
    connect(qgcApp()->toolbox()->multiVehicleManager()->vehicles(), &QmlObjectListModel::countChanged, this, &Joystick::_vehicleCountChanged);

    _customMavCommands = JoystickMavCommand::load("JoystickMavCommands.json");
}

void Joystick::stop()
{
    _exitThread = true;
    wait();
}

Joystick::~Joystick()
{
    if (!_exitThread) {
        qWarning() << "Joystick thread still running!";
    }
    delete[] _rgAxisValues;
    delete[] _rgLastAxisValues;
    delete[] _rgAxisNeutralValues;
    delete[] _rgAxisNeutralInited;
    delete[] _rgVirtualButtonReleaseMSecs;
    delete[] _rgCalibration;
    delete[] _rgButtonValues;
    _assignableButtonActions.clearAndDeleteContents();
    for (int button = 0; button < _totalButtonCount; button++) {
        if(_buttonActionArray[button]) {
            _buttonActionArray[button]->deleteLater();
        }
    }
}

void Joystick::_setDefaultCalibration(void) {
    QSettings settings;
    settings.beginGroup(_settingsGroup);
    settings.beginGroup(_name);
    _calibrated = settings.value(_calibratedSettingsKey, false).toBool();

    // Only set default calibrations if we do not have a calibration for this gamecontroller
    if(_calibrated) return;

    for(int axis = 0; axis < _axisCount; axis++) {
        Joystick::Calibration_t calibration;
        _rgCalibration[axis] = calibration;
    }

    _rgCalibration[1].reversed = true;
    _rgCalibration[3].reversed = true;

    // Default TX Mode 2 axis assignments for gamecontrollers
    _rgFunctionAxis[rollFunction]       = 2;
    _rgFunctionAxis[pitchFunction]      = 3;
    _rgFunctionAxis[yawFunction]        = 0;
    _rgFunctionAxis[throttleFunction]   = 1;

    _rgFunctionAxis[gimbalPitchFunction]= 4;
    _rgFunctionAxis[gimbalYawFunction]  = 5;

    _exponential        = 0;
    _accumulator        = false;
    _deadband           = false;
    _axisFrequencyHz    = _defaultAxisFrequencyHz;
    _buttonFrequencyHz  = _defaultButtonFrequencyHz;
    _throttleMode       = ThrottleModeDownZero;
    _calibrated         = true;
    _circleCorrection   = true;

    // These are auto-applied defaults (e.g. for recognized game controllers). Persist them
    // to QSettings but do NOT overwrite the user's persistent XML backup with them, otherwise
    // a restored configuration could be clobbered on the next startup.
    _suppressConfigBackup = true;
    _saveSettings();
    _suppressConfigBackup = false;
}

void Joystick::_updateTXModeSettingsKey(Vehicle* activeVehicle)
{
    if(activeVehicle) {
        if(activeVehicle->fixedWing()) {
            _txModeSettingsKey = _fixedWingTXModeSettingsKey;
        } else if(activeVehicle->multiRotor()) {
            _txModeSettingsKey = _multiRotorTXModeSettingsKey;
        } else if(activeVehicle->rover()) {
            _txModeSettingsKey = _roverTXModeSettingsKey;
        } else if(activeVehicle->vtol()) {
            _txModeSettingsKey = _vtolTXModeSettingsKey;
        } else if(activeVehicle->sub()) {
            _txModeSettingsKey = _submarineTXModeSettingsKey;
        } else {
            _txModeSettingsKey = nullptr;
            qWarning() << "No valid joystick TXmode settings key for selected vehicle";
            return;
        }
    } else {
        _txModeSettingsKey = nullptr;
    }
}

void Joystick::_activeVehicleChanged(Vehicle* activeVehicle)
{
    _updateTXModeSettingsKey(activeVehicle);
    if(activeVehicle) {
        QSettings settings;
        settings.beginGroup(_settingsGroup);
        int mode = settings.value(_txModeSettingsKey, activeVehicle->firmwarePlugin()->defaultJoystickTXMode()).toInt();
        setTXMode(mode);
    }
}
void Joystick::_flightModesChanged()
{
    _buildActionList(_activeVehicle);
}

void Joystick::_vehicleCountChanged(int count)
{
    if(count == 0)
    {
        // then the last vehicle has been deleted
        qCDebug(JoystickLog) << "Stopping joystick thread due to last active vehicle deletion";
        this->stopPolling();
    }
}

void Joystick::_loadSettings()
{
    QSettings settings;
    settings.beginGroup(_settingsGroup);

    // If this joystick has no stored settings on this install (e.g. fresh install or
    // after the app was reinstalled) but a backup XML exists in the persistent save
    // folder, restore it into QSettings before loading so the user does not lose
    // calibration and button assignments. The restore writes through the SAME QSettings
    // instance used below so the restored values are guaranteed to be visible.
    settings.beginGroup(_name);
    const bool hasStoredSettings = settings.contains(_calibratedSettingsKey);
    settings.endGroup();
    qCDebug(JoystickLog) << "_loadSettings" << _name << "hasStoredSettings" << hasStoredSettings;
    if (!hasStoredSettings) {
        _restoreSettingsFromFile(settings);
    }

    Vehicle* activeVehicle = _multiVehicleManager->activeVehicle();

    if(_txModeSettingsKey && activeVehicle)
        _transmitterMode = settings.value(_txModeSettingsKey, activeVehicle->firmwarePlugin()->defaultJoystickTXMode()).toInt();

    settings.beginGroup(_name);

    bool badSettings = false;
    bool convertOk;

    qCDebug(JoystickLog) << "_loadSettings " << _name;

    _calibrated         = settings.value(_calibratedSettingsKey,        false).toBool();
    _exponential        = settings.value(_exponentialSettingsKey,       0).toFloat();
    _accumulator        = settings.value(_accumulatorSettingsKey,       false).toBool();
    _deadband           = settings.value(_deadbandSettingsKey,          false).toBool();
    _axisFrequencyHz    = settings.value(_axisFrequencySettingsKey,     _defaultAxisFrequencyHz).toFloat();
    _buttonFrequencyHz  = settings.value(_buttonFrequencySettingsKey,   _defaultButtonFrequencyHz).toFloat();
    _circleCorrection   = settings.value(_circleCorrectionSettingsKey,  false).toBool();
    _negativeThrust     = settings.value(_negativeThrustSettingsKey,    false).toBool();


    _throttleMode   = static_cast<ThrottleMode_t>(settings.value(_throttleModeSettingsKey, ThrottleModeDownZero).toInt(&convertOk));
    badSettings |= !convertOk;

    qCDebug(JoystickLog) << "_loadSettings calibrated:txmode:throttlemode:exponential:deadband:badsettings" << _calibrated << _transmitterMode << _throttleMode << _exponential << _deadband << badSettings;

    QString minTpl      ("Axis%1Min");
    QString maxTpl      ("Axis%1Max");
    QString trimTpl     ("Axis%1Trim");
    QString revTpl      ("Axis%1Rev");
    QString deadbndTpl  ("Axis%1Deadbnd");

    for (int axis = 0; axis < _axisCount; axis++) {
        Calibration_t* calibration = &_rgCalibration[axis];

        calibration->center = settings.value(trimTpl.arg(axis), 0).toInt(&convertOk);
        badSettings |= !convertOk;

        calibration->min = settings.value(minTpl.arg(axis), -32768).toInt(&convertOk);
        badSettings |= !convertOk;

        calibration->max = settings.value(maxTpl.arg(axis), 32767).toInt(&convertOk);
        badSettings |= !convertOk;

        calibration->deadband = settings.value(deadbndTpl.arg(axis), 0).toInt(&convertOk);
        badSettings |= !convertOk;

        calibration->reversed = settings.value(revTpl.arg(axis), false).toBool();

        qCDebug(JoystickLog) << "_loadSettings axis:min:max:trim:reversed:deadband:badsettings" << axis << calibration->min << calibration->max << calibration->center << calibration->reversed << calibration->deadband << badSettings;
    }

    int workingAxis = 0;
    for (int function = 0; function < maxFunction; function++) {
        int functionAxis;
        functionAxis = settings.value(_rgFunctionSettingsKey[function], -1).toInt(&convertOk);
        badSettings |= !convertOk || (functionAxis >= _axisCount);
        if(functionAxis >= 0) {
            workingAxis++;
        }
        if(functionAxis < _axisCount) {
            _rgFunctionAxis[function] = functionAxis;
        }
        qCDebug(JoystickLog) << "_loadSettings function:axis:badsettings" << function << functionAxis << badSettings;
    }
    badSettings |= workingAxis < 4;

    // FunctionAxis mappings are always stored in TX mode 2
    // Remap to stored TX mode in settings
    _remapAxes(2, _transmitterMode, _rgFunctionAxis);

    for (int button = 0; button < _totalButtonCount; button++) {
        QString a = settings.value(QString(_buttonActionNameKey).arg(button), QString()).toString();
        if(!a.isEmpty() && a != _buttonActionNone) {
            if(_buttonActionArray[button]) {
                _buttonActionArray[button]->deleteLater();
            }
            AssignedButtonAction* ap = new AssignedButtonAction(this, a);
            ap->repeat = settings.value(QString(_buttonActionRepeatKey).arg(button), false).toBool();
            _buttonActionArray[button] = ap;
            _buttonActionArray[button]->buttonTime.start();
            qCDebug(JoystickLog) << "_loadSettings button:action" << button << _buttonActionArray[button]->action << _buttonActionArray[button]->repeat;
        }
    }

    if (badSettings) {
        _calibrated = false;
        settings.setValue(_calibratedSettingsKey, false);
    }
}

void Joystick::_saveButtonSettings()
{
    QSettings settings;
    settings.beginGroup(_settingsGroup);
    settings.beginGroup(_name);
    for (int button = 0; button < _totalButtonCount; button++) {
        if(_buttonActionArray[button]) {
            settings.setValue(QString(_buttonActionNameKey).arg(button),        _buttonActionArray[button]->action);
            settings.setValue(QString(_buttonActionRepeatKey).arg(button),      _buttonActionArray[button]->repeat);
            qCDebug(JoystickLog) << "_saveButtonSettings button:action" << button <<  _buttonActionArray[button]->action << _buttonActionArray[button]->repeat;
        }
    }
}

void Joystick::_saveSettings()
{
    QSettings settings;
    settings.beginGroup(_settingsGroup);

    // Transmitter mode is static
    // Save the mode we are using
    if(_txModeSettingsKey)
        settings.setValue(_txModeSettingsKey,       _transmitterMode);

    settings.beginGroup(_name);
    settings.setValue(_calibratedSettingsKey,       _calibrated);
    settings.setValue(_exponentialSettingsKey,      _exponential);
    settings.setValue(_accumulatorSettingsKey,      _accumulator);
    settings.setValue(_deadbandSettingsKey,         _deadband);
    settings.setValue(_axisFrequencySettingsKey,    _axisFrequencyHz);
    settings.setValue(_buttonFrequencySettingsKey,  _buttonFrequencyHz);
    settings.setValue(_throttleModeSettingsKey,     _throttleMode);
    settings.setValue(_negativeThrustSettingsKey,   _negativeThrust);
    settings.setValue(_circleCorrectionSettingsKey, _circleCorrection);

    qCDebug(JoystickLog) << "_saveSettings calibrated:throttlemode:deadband:txmode" << _calibrated << _throttleMode << _deadband << _circleCorrection << _transmitterMode;

    QString minTpl      ("Axis%1Min");
    QString maxTpl      ("Axis%1Max");
    QString trimTpl     ("Axis%1Trim");
    QString revTpl      ("Axis%1Rev");
    QString deadbndTpl  ("Axis%1Deadbnd");

    for (int axis = 0; axis < _axisCount; axis++) {
        Calibration_t* calibration = &_rgCalibration[axis];
        settings.setValue(trimTpl.arg(axis), calibration->center);
        settings.setValue(minTpl.arg(axis), calibration->min);
        settings.setValue(maxTpl.arg(axis), calibration->max);
        settings.setValue(revTpl.arg(axis), calibration->reversed);
        settings.setValue(deadbndTpl.arg(axis), calibration->deadband);
        qCDebug(JoystickLog) << "_saveSettings name:axis:min:max:trim:reversed:deadband"
                             << _name
                             << axis
                             << calibration->min
                             << calibration->max
                             << calibration->center
                             << calibration->reversed
                             << calibration->deadband;
    }

    // Always save function Axis mappings in TX Mode 2
    // Write mode 2 mappings without changing mapping currently in use
    int temp[maxFunction];
    _remapAxes(_transmitterMode, 2, temp);
    for (int function = 0; function < maxFunction; function++) {
        settings.setValue(_rgFunctionSettingsKey[function], temp[function]);
        qCDebug(JoystickLog) << "_saveSettings name:function:axis" << _name << function << _rgFunctionSettingsKey[function];
    }
    _saveButtonSettings();

    // Mirror the full configuration to a persistent XML backup that survives app reinstall.
    settings.sync();
    _backupSettingsToFile();
}

QString Joystick::_configBackupFilePath() const
{
    SettingsManager* settingsManager = qgcApp()->toolbox()->settingsManager();
    if (!settingsManager || !settingsManager->appSettings()) {
        return QString();
    }
    // Use the same persistent folder the camera definition cache lives in. The user has
    // verified this folder survives app reinstall (it is not removed with the app data).
    const QString dir = settingsManager->appSettings()->parameterSavePath();
    if (dir.isEmpty()) {
        return QString();
    }

    QString safeName = _name;
    for (QChar& ch : safeName) {
        if (!ch.isLetterOrNumber() && ch != '_' && ch != '-' && ch != '.') {
            ch = QLatin1Char('_');
        }
    }
    return QDir(dir).filePath(QStringLiteral("Joystick_%1.xml").arg(safeName));
}

void Joystick::_backupSettingsToFile()
{
    if (_suppressConfigBackup) {
        return;     // Auto-applied defaults must not overwrite a real user backup.
    }

    const QString filePath = _configBackupFilePath();
    if (filePath.isEmpty()) {
        return;
    }

    QSettings settings;
    settings.beginGroup(_settingsGroup);
    const int txMode = _txModeSettingsKey ? settings.value(_txModeSettingsKey, _transmitterMode).toInt()
                                          : _transmitterMode;
    settings.beginGroup(_name);
    const QStringList keys = settings.allKeys();
    if (keys.isEmpty()) {
        return;     // Nothing configured yet; don't create an empty backup.
    }

    QDir().mkpath(QFileInfo(filePath).absolutePath());
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qCWarning(JoystickLog) << "Joystick config backup: cannot write" << filePath << file.errorString();
        return;
    }

    QXmlStreamWriter xml(&file);
    xml.setAutoFormatting(true);
    xml.writeStartDocument();
    xml.writeStartElement(QStringLiteral("JoystickConfig"));
    xml.writeAttribute(QStringLiteral("name"),        _name);
    xml.writeAttribute(QStringLiteral("axisCount"),   QString::number(_axisCount));
    xml.writeAttribute(QStringLiteral("buttonCount"), QString::number(_buttonCount));
    xml.writeAttribute(QStringLiteral("txMode"),      QString::number(txMode));
    // Back up calibration only. Button assignments (ButtonActionName%1 / ButtonActionRepeat%1)
    // are intentionally NOT persisted, so a restore never carries over button mappings.
    const QString buttonNamePrefix   = QString(_buttonActionNameKey).remove(QStringLiteral("%1"));
    const QString buttonRepeatPrefix = QString(_buttonActionRepeatKey).remove(QStringLiteral("%1"));
    for (const QString& key : keys) {
        if (key.startsWith(buttonNamePrefix) || key.startsWith(buttonRepeatPrefix)) {
            continue;
        }
        xml.writeStartElement(QStringLiteral("s"));
        xml.writeAttribute(QStringLiteral("k"), key);
        xml.writeAttribute(QStringLiteral("v"), settings.value(key).toString());
        xml.writeEndElement();
    }
    xml.writeEndElement();
    xml.writeEndDocument();
    file.close();

    qCDebug(JoystickLog) << "Joystick config backed up to" << filePath;
}

// Restores a previously backed-up configuration into `settings`, which must be positioned
// at the top-level joystick settings group (_settingsGroup). Using the caller's QSettings
// instance guarantees the restored values are immediately visible to the subsequent load.
bool Joystick::_restoreSettingsFromFile(QSettings& settings)
{
    const QString filePath = _configBackupFilePath();
    if (filePath.isEmpty()) {
        qCWarning(JoystickLog) << "Joystick config restore: persistent save path not available";
        return false;
    }
    if (!QFile::exists(filePath)) {
        qCDebug(JoystickLog) << "Joystick config restore: no backup file at" << filePath;
        return false;
    }

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        qCWarning(JoystickLog) << "Joystick config restore: cannot read" << filePath << file.errorString();
        return false;
    }

    QMap<QString, QString> values;
    int  txMode      = -1;
    bool nameMatched = false;

    QXmlStreamReader xml(&file);
    while (!xml.atEnd() && !xml.hasError()) {
        if (xml.readNext() != QXmlStreamReader::StartElement) {
            continue;
        }
        if (xml.name() == QLatin1String("JoystickConfig")) {
            nameMatched = (xml.attributes().value(QStringLiteral("name")).toString() == _name);
            txMode      = xml.attributes().value(QStringLiteral("txMode")).toInt();
        } else if (xml.name() == QLatin1String("s")) {
            const QString k = xml.attributes().value(QStringLiteral("k")).toString();
            // Ignore button assignments that may exist in older backup files — calibration only.
            const bool isButtonAssignment =
                k.startsWith(QString(_buttonActionNameKey).remove(QStringLiteral("%1"))) ||
                k.startsWith(QString(_buttonActionRepeatKey).remove(QStringLiteral("%1")));
            if (!k.isEmpty() && !isButtonAssignment) {
                values.insert(k, xml.attributes().value(QStringLiteral("v")).toString());
            }
        }
    }
    file.close();

    if (!nameMatched || values.isEmpty()) {
        qCWarning(JoystickLog) << "Joystick config restore: backup not applicable" << filePath
                               << "nameMatched" << nameMatched << "keyCount" << values.count();
        return false;       // Backup is for a different joystick or is empty/corrupt.
    }

    // settings is positioned at _settingsGroup.
    if (_txModeSettingsKey && txMode > 0) {
        settings.setValue(_txModeSettingsKey, txMode);
    }
    settings.beginGroup(_name);
    for (auto it = values.constBegin(); it != values.constEnd(); ++it) {
        settings.setValue(it.key(), it.value());
    }
    settings.endGroup();
    settings.sync();

    qCDebug(JoystickLog) << "Joystick config restored from" << filePath << "keyCount" << values.count();
    return true;
}

// Relative mappings of axis functions between different TX modes
int Joystick::_mapFunctionMode(int mode, int function) {
    static const int mapping[][6] = {
                                     { yawFunction, pitchFunction, rollFunction, throttleFunction, gimbalPitchFunction, gimbalYawFunction },
                                     { yawFunction, throttleFunction, rollFunction, pitchFunction, gimbalPitchFunction, gimbalYawFunction },
                                     { rollFunction, pitchFunction, yawFunction, throttleFunction, gimbalPitchFunction, gimbalYawFunction },
                                     { rollFunction, throttleFunction, yawFunction, pitchFunction, gimbalPitchFunction, gimbalYawFunction }};
    return mapping[mode-1][function];
}

// Remap current axis functions from current TX mode to new TX mode
void Joystick::_remapAxes(int currentMode, int newMode, int (&newMapping)[maxFunction]) {
    int temp[maxFunction];
    for(int function = 0; function < maxFunction; function++) {
        temp[_mapFunctionMode(newMode, function)] = _rgFunctionAxis[_mapFunctionMode(currentMode, function)];
    }
    for(int function = 0; function < maxFunction; function++) {
        newMapping[function] = temp[function];
    }
}

void Joystick::setTXMode(int mode) {
    if(mode > 0 && mode <= 4) {
        _remapAxes(_transmitterMode, mode, _rgFunctionAxis);
        _transmitterMode = mode;
        _saveSettings();
    } else {
        qCWarning(JoystickLog) << "Invalid mode:" << mode;
    }
}

/// Adjust the raw axis value to the -1:1 range given calibration information
float Joystick::_adjustRange(int value, Calibration_t calibration, bool withDeadbands)
{
    float valueNormalized;
    float axisLength;
    float axisBasis;

    if (value > calibration.center) {
        axisBasis = 1.0f;
        valueNormalized = value - calibration.center;
        axisLength =  calibration.max - calibration.center;
    } else {
        axisBasis = -1.0f;
        valueNormalized = calibration.center - value;
        axisLength =  calibration.center - calibration.min;
    }

    float axisPercent;

    if (withDeadbands) {
        if (valueNormalized>calibration.deadband) {
            axisPercent = (valueNormalized - calibration.deadband) / (axisLength - calibration.deadband);
        } else if (valueNormalized<-calibration.deadband) {
            axisPercent = (valueNormalized + calibration.deadband) / (axisLength - calibration.deadband);
        } else {
            axisPercent = 0.f;
        }
    }
    else {
        axisPercent = valueNormalized / axisLength;
    }

    float correctedValue = axisBasis * axisPercent;

    if (calibration.reversed) {
        correctedValue *= -1.0f;
    }

#if 0
    qCDebug(JoystickLog) << "_adjustRange corrected:value:min:max:center:reversed:deadband:basis:normalized:length"
                            << correctedValue
                            << value
                            << calibration.min
                            << calibration.max
                            << calibration.center
                            << calibration.reversed
                            << calibration.deadband
                            << axisBasis
                            << valueNormalized
                            << axisLength;
#endif

    return std::max(-1.0f, std::min(correctedValue, 1.0f));
}


void Joystick::run()
{
    //-- Joystick thread
    _open();
    //-- Reset timers
    _axisTime.start();
    for (int buttonIndex = 0; buttonIndex < _totalButtonCount; buttonIndex++) {
        if(_buttonActionArray[buttonIndex]) {
            _buttonActionArray[buttonIndex]->buttonTime.start();
        }
    }
    while (!_exitThread) {
        _update();
        _handleButtons();
        if (axisCount() != 0) {
            _handleAxis();
        }
        QGC::SLEEP::msleep(qMin(static_cast<int>(1000.0f / _maxAxisFrequencyHz), static_cast<int>(1000.0f / _maxButtonFrequencyHz)) / 2);
    }
    _close();
}

void Joystick::_handleButtons()
{
    int lastBbuttonValues[256];
    std::fill_n(lastBbuttonValues, 256, static_cast<int>(BUTTON_UP));
    //-- Update button states
    for (int buttonIndex = 0; buttonIndex < _buttonCount; buttonIndex++) {
        bool newButtonValue = _getButton(buttonIndex);
        if(buttonIndex < 256)
            lastBbuttonValues[buttonIndex] = _rgButtonValues[buttonIndex];
        if (newButtonValue && _rgButtonValues[buttonIndex] == BUTTON_UP) {
            _rgButtonValues[buttonIndex] = BUTTON_DOWN;
            emit rawButtonPressedChanged(buttonIndex, newButtonValue);
        } else if (!newButtonValue && _rgButtonValues[buttonIndex] != BUTTON_UP) {
            _rgButtonValues[buttonIndex] = BUTTON_UP;
            emit rawButtonPressedChanged(buttonIndex, newButtonValue);
        }
    }
    //-- Update hat - append hat buttons to the end of the normal button list
    int numHatButtons = 4;
    for (int hatIndex = 0; hatIndex < _hatCount; hatIndex++) {
        for (int hatButtonIndex = 0; hatButtonIndex<numHatButtons; hatButtonIndex++) {
            // Create new index value that includes the normal button list
            int rgButtonValueIndex = hatIndex*numHatButtons + hatButtonIndex + _buttonCount;
            // Get hat value from joystick
            bool newButtonValue = _getHat(hatIndex, hatButtonIndex);
            if(rgButtonValueIndex < 256)
                lastBbuttonValues[rgButtonValueIndex] = _rgButtonValues[rgButtonValueIndex];
            if (newButtonValue && _rgButtonValues[rgButtonValueIndex] == BUTTON_UP) {
                _rgButtonValues[rgButtonValueIndex] = BUTTON_DOWN;
                emit rawButtonPressedChanged(rgButtonValueIndex, newButtonValue);
            } else if (!newButtonValue && _rgButtonValues[rgButtonValueIndex] != BUTTON_UP) {
                _rgButtonValues[rgButtonValueIndex] = BUTTON_UP;
                emit rawButtonPressedChanged(rgButtonValueIndex, newButtonValue);
            }
        }
    }
    //-- Update virtual axis-buttons (for dial/extra axes): each axis contributes 2 virtual buttons.
    //   virtualIndex+0: axis negative direction
    //   virtualIndex+1: axis positive direction
    const int axisVirtualStartIndex = _buttonCount + _hatButtonCount;
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    for (int axisIndex = _axisVirtualButtonStartAxis; axisIndex < _axisCount; axisIndex++) {
        const int rgAxisButtonBaseIndex = axisVirtualStartIndex + (axisIndex - _axisVirtualButtonStartAxis) * 2;
        if (rgAxisButtonBaseIndex + 1 >= _totalButtonCount) {
            break;
        }
        const int virtualAxisOffset = (axisIndex - _axisVirtualButtonStartAxis) * 2;
        if (virtualAxisOffset + 1 >= _axisVirtualButtonCount) {
            break;
        }

        // Use calibrated/normalized value with deadband for stable triggering.
        const float axisValue = _adjustRange(_rgAxisValues[axisIndex], _rgCalibration[axisIndex], _deadband);
        const int axisRawValue = _rgAxisValues[axisIndex];
        const int axisDeltaRaw = axisRawValue - _rgLastAxisValues[axisIndex];
        _rgLastAxisValues[axisIndex] = axisRawValue;
        if (!_rgAxisNeutralInited[axisIndex]) {
            // First sample is usually at rest; use it as initial neutral guess.
            _rgAxisNeutralValues[axisIndex] = axisRawValue;
            _rgAxisNeutralInited[axisIndex] = true;
        }

        const int axisMinRaw = _rgCalibration[axisIndex].min;
        const int axisMaxRaw = _rgCalibration[axisIndex].max;
        const int axisCenterRaw = _rgCalibration[axisIndex].center;
        int axisRangeRaw = axisMaxRaw - axisMinRaw;
        if (axisRangeRaw <= 0) {
            axisRangeRaw = 65535;
        }
        const float axisDeltaNorm = static_cast<float>(axisDeltaRaw) / static_cast<float>(axisRangeRaw);
        const bool axisNearCenter = std::fabs(axisValue) < _axisVirtualButtonOnThreshold;
        const float centerRatio = static_cast<float>(axisCenterRaw - axisMinRaw) / static_cast<float>(axisRangeRaw);
        const bool dialLikeByCalibration = (centerRatio <= 0.2f || centerRatio >= 0.8f);
        // Unsigned-like axis fallback: runtime neutral far from zero while calibration center is near zero.
        const bool inferredUnsignedDial = (std::abs(axisCenterRaw) < static_cast<int>(axisRangeRaw * 0.05f))
                                          && (_rgAxisNeutralValues[axisIndex] > static_cast<int>(axisRangeRaw * 0.02f));
        const bool dialLikeAxis = dialLikeByCalibration || inferredUnsignedDial;
        const float motionThreshold = dialLikeAxis ? (_axisVirtualMotionOnThreshold * 1.2f) : _axisVirtualMotionOnThreshold;
        // For dial buttons with firmware-fixed center, keep neutral fixed during runtime.
        // Unsigned-like axes still use first-sample neutral initialized above.
        const int neutralRaw = dialLikeAxis ? (inferredUnsignedDial ? _rgAxisNeutralValues[axisIndex] : axisCenterRaw) : axisCenterRaw;
        int centeredRaw = axisRawValue - neutralRaw;
        int sideRangeRaw = qMax(axisMaxRaw - neutralRaw, neutralRaw - axisMinRaw);
        if (sideRangeRaw <= 0) {
            sideRangeRaw = axisRangeRaw / 2;
        }
        if (sideRangeRaw <= 0) {
            sideRangeRaw = 32767;
        }
        float centeredNorm = std::max(-1.0f, std::min(1.0f,
                                                      static_cast<float>(axisRawValue - neutralRaw) / static_cast<float>(sideRangeRaw)));
        if (dialLikeAxis) {
            // Suppress jitter around center to avoid false direction toggles.
            const bool nearCenter = std::fabs(centeredNorm) <= (_axisVirtualDialOffThreshold * 0.8f);
            const bool lowMotion = std::fabs(axisDeltaNorm) <= (motionThreshold * 0.6f);
            if (nearCenter && lowMotion) {
                centeredNorm = 0.0f;
            }
        }

        // Negative direction button
        bool negButtonDown = false;
        const int rgAxisButtonPosIndex = rgAxisButtonBaseIndex + 1;
        bool posButtonDown = false;
        if (dialLikeAxis) {
            // Dial-like axis: position-based hysteresis state machine.
            // 1) immediate response when crossing ON threshold
            // 2) stays active while held
            // 3) releases when returning to center zone
            const float dialOn  = _axisVirtualDialOnThreshold * 0.85f;
            const float dialOff = _axisVirtualDialOffThreshold;
            // Raw-count guard to reject center jitter seen on some dials.
            const int rawOnThreshold  = qMax(8, static_cast<int>(axisRangeRaw * 0.004f));
            const int rawOffThreshold = qMax(8,  rawOnThreshold / 2);
            const bool negWasDown = _rgButtonValues[rgAxisButtonBaseIndex] != BUTTON_UP;
            const bool posWasDown = _rgButtonValues[rgAxisButtonPosIndex] != BUTTON_UP;
            // Treat a center RANGE as neutral (not a single value).
            // Use hysteresis so neutral does not chatter around the boundary.
            const int neutralBandRaw = qMax(rawOffThreshold, static_cast<int>(axisRangeRaw * 0.020f));
            const int neutralBandReleaseRaw = qMax(neutralBandRaw + 4, static_cast<int>(axisRangeRaw * 0.035f));
            const int activeNeutralBandRaw = (negWasDown || posWasDown) ? neutralBandReleaseRaw : neutralBandRaw;
            const bool inNeutral = (std::abs(centeredRaw) <= activeNeutralBandRaw) || (std::fabs(centeredNorm) <= dialOff);
            const int rawHoldThreshold = qMax(rawOffThreshold, neutralBandRaw);
            const bool negOnCond = (centeredRaw <= -rawOnThreshold) && (centeredNorm <= -dialOn);
            const bool posOnCond = (centeredRaw >=  rawOnThreshold) && (centeredNorm >=  dialOn);
            const bool negHoldCond = (centeredRaw <= -rawHoldThreshold) && (centeredNorm <= -dialOff);
            const bool posHoldCond = (centeredRaw >=  rawHoldThreshold) && (centeredNorm >=  dialOff);

            if (inNeutral) {
                // Requirement #3: no signal while stick/dial is released near center.
                negButtonDown = false;
                posButtonDown = false;
            } else if (negWasDown) {
                // Requirement #4: do not flip directly to opposite side without neutral.
                negButtonDown = negHoldCond;
                posButtonDown = false;
            } else if (posWasDown) {
                // Requirement #4: symmetric lockout for opposite direction.
                negButtonDown = false;
                posButtonDown = posHoldCond;
            } else {
                negButtonDown = negOnCond;
                posButtonDown = posOnCond;
            }
        } else if (axisNearCenter && axisDeltaNorm <= -motionThreshold) {
            // Relative-like behavior around center: trigger by movement direction.
            negButtonDown = true;
        } else if (_rgButtonValues[rgAxisButtonBaseIndex] == BUTTON_UP) {
            negButtonDown = axisValue <= -_axisVirtualButtonOnThreshold;
        } else {
            negButtonDown = axisValue <= -_axisVirtualButtonOffThreshold;
        }
        if (rgAxisButtonBaseIndex < 256) {
            lastBbuttonValues[rgAxisButtonBaseIndex] = _rgButtonValues[rgAxisButtonBaseIndex];
        }
        if (!dialLikeAxis) {
            if (negButtonDown) {
                _rgVirtualButtonReleaseMSecs[virtualAxisOffset] = nowMs + _axisVirtualButtonHoldMs;
            }
            if (!negButtonDown && nowMs < _rgVirtualButtonReleaseMSecs[virtualAxisOffset]) {
                negButtonDown = true;
            }
        }
        if (negButtonDown && _rgButtonValues[rgAxisButtonBaseIndex] == BUTTON_UP) {
            _rgButtonValues[rgAxisButtonBaseIndex] = BUTTON_DOWN;
            emit rawButtonPressedChanged(rgAxisButtonBaseIndex, true);
        } else if (!negButtonDown && _rgButtonValues[rgAxisButtonBaseIndex] != BUTTON_UP) {
            _rgButtonValues[rgAxisButtonBaseIndex] = BUTTON_UP;
            emit rawButtonPressedChanged(rgAxisButtonBaseIndex, false);
        }

        // Positive direction button
        if (!dialLikeAxis) {
            // Dial-like axis: position-based hysteresis state machine.
            if (axisNearCenter && axisDeltaNorm >= motionThreshold) {
                // Relative-like behavior around center: trigger by movement direction.
                posButtonDown = true;
            } else if (_rgButtonValues[rgAxisButtonPosIndex] == BUTTON_UP) {
                posButtonDown = axisValue >= _axisVirtualButtonOnThreshold;
            } else {
                posButtonDown = axisValue >= _axisVirtualButtonOffThreshold;
            }
        }
        if (rgAxisButtonPosIndex < 256) {
            lastBbuttonValues[rgAxisButtonPosIndex] = _rgButtonValues[rgAxisButtonPosIndex];
        }

        if (!dialLikeAxis) {
            if (posButtonDown) {
                _rgVirtualButtonReleaseMSecs[virtualAxisOffset + 1] = nowMs + _axisVirtualButtonHoldMs;
            }
            if (!posButtonDown && nowMs < _rgVirtualButtonReleaseMSecs[virtualAxisOffset + 1]) {
                posButtonDown = true;
            }
        }
        if (posButtonDown && _rgButtonValues[rgAxisButtonPosIndex] == BUTTON_UP) {
            _rgButtonValues[rgAxisButtonPosIndex] = BUTTON_DOWN;
            emit rawButtonPressedChanged(rgAxisButtonPosIndex, true);
        } else if (!posButtonDown && _rgButtonValues[rgAxisButtonPosIndex] != BUTTON_UP) {
            _rgButtonValues[rgAxisButtonPosIndex] = BUTTON_UP;
            emit rawButtonPressedChanged(rgAxisButtonPosIndex, false);
        }
    }
    //-- Process button press/release
    for (int buttonIndex = 0; buttonIndex < _totalButtonCount; buttonIndex++) {
        if(_rgButtonValues[buttonIndex] == BUTTON_DOWN || _rgButtonValues[buttonIndex] == BUTTON_REPEAT) {
            // TEMP DIAGNOSTIC (remove after): log once per press to diagnose buttons 0/1.
            if (_rgButtonValues[buttonIndex] == BUTTON_DOWN) {
                qWarning() << "JSBTN_DIAG down idx=" << buttonIndex
                           << "hasAction=" << (_buttonActionArray[buttonIndex] != nullptr)
                           << "action=" << (_buttonActionArray[buttonIndex] ? _buttonActionArray[buttonIndex]->action : QString())
                           << "repeat=" << (_buttonActionArray[buttonIndex] ? _buttonActionArray[buttonIndex]->repeat : false);
            }
            if(_buttonActionArray[buttonIndex]) {
                QString buttonAction = _buttonActionArray[buttonIndex]->action;
                if(buttonAction.isEmpty() || buttonAction == _buttonActionNone)
                    continue;
                if(!_buttonActionArray[buttonIndex]->repeat) {
                    //-- This button just went down
                    if(_rgButtonValues[buttonIndex] == BUTTON_DOWN) {
                        // Check for a multi-button action
                        QList<int> rgButtons = { buttonIndex };
                        bool executeButtonAction = true;
                        for (int multiIndex = 0; multiIndex < _totalButtonCount; multiIndex++) {
                            if (multiIndex != buttonIndex) {
                                if (_buttonActionArray[multiIndex] && _buttonActionArray[multiIndex]->action == buttonAction) {
                                    // We found a multi-button action
                                    if (_rgButtonValues[multiIndex] == BUTTON_DOWN || _rgButtonValues[multiIndex] == BUTTON_REPEAT) {
                                        // So far so good
                                        rgButtons.append(multiIndex);
                                        continue;
                                    } else {
                                        // We are missing a press we need
                                        executeButtonAction = false;
                                        break;
                                    }
                                }
                            }
                        }
                        if (executeButtonAction) {
                            qCDebug(JoystickLog) << "Action triggered" << rgButtons << buttonAction;
                            _executeButtonAction(buttonAction, true);
                        }
                    }
                } else {
                    //-- Process repeat buttons
                    int buttonDelay = static_cast<int>(1000.0f / _buttonFrequencyHz);
                    if(_buttonActionArray[buttonIndex]->buttonTime.elapsed() > buttonDelay) {
                        _buttonActionArray[buttonIndex]->buttonTime.start();
                        qCDebug(JoystickLog) << "Repeat button triggered" << buttonIndex << buttonAction;
                        _executeButtonAction(buttonAction, true);
                    }
                }
            }
            //-- Flag it as processed
            _rgButtonValues[buttonIndex] = BUTTON_REPEAT;
        } else if(_rgButtonValues[buttonIndex] == BUTTON_UP) {
            //-- Button up transition
            if(buttonIndex < 256) {
                if(lastBbuttonValues[buttonIndex] == BUTTON_DOWN || lastBbuttonValues[buttonIndex] == BUTTON_REPEAT) {
                    if(_buttonActionArray[buttonIndex]) {
                        QString buttonAction = _buttonActionArray[buttonIndex]->action;
                        if(buttonAction.isEmpty() || buttonAction == _buttonActionNone)
                            continue;
                        qCDebug(JoystickLog) << "Button up" << buttonIndex << buttonAction;
                        _executeButtonAction(buttonAction, false);
                    }
                }
            }
        }
    }
}

void Joystick::_handleAxis()
{
    //-- Get frequency
    int axisDelay = static_cast<int>(1000.0f / _axisFrequencyHz);
    //-- Check elapsed time since last run
    if(_axisTime.elapsed() > axisDelay) {
        _axisTime.start();
        //-- Update axis
        for (int axisIndex = 0; axisIndex < _axisCount; axisIndex++) {
            int newAxisValue = _getAxis(axisIndex);
            // Calibration code requires signal to be emitted even if value hasn't changed
            _rgAxisValues[axisIndex] = newAxisValue;
            emit rawAxisValueChanged(axisIndex, newAxisValue);
        }
        if (_activeVehicle->joystickEnabled() && !_calibrationMode && _calibrated) {
            int     axis = _rgFunctionAxis[rollFunction];
            float   roll = _adjustRange(_rgAxisValues[axis],    _rgCalibration[axis], _deadband);

            axis = _rgFunctionAxis[pitchFunction];
            float   pitch = _adjustRange(_rgAxisValues[axis],   _rgCalibration[axis], _deadband);

            axis = _rgFunctionAxis[yawFunction];
            float   yaw = _adjustRange(_rgAxisValues[axis],     _rgCalibration[axis],_deadband);

            axis = _rgFunctionAxis[throttleFunction];
            float   throttle = _adjustRange(_rgAxisValues[axis],_rgCalibration[axis], _throttleMode==ThrottleModeDownZero?false:_deadband);

            if (_accumulator) {
                static float throttle_accu = 0.f;
                throttle_accu += throttle * (40 / 1000.f); //for throttle to change from min to max it will take 1000ms (40ms is a loop time)
                throttle_accu = std::max(static_cast<float>(-1.f), std::min(throttle_accu, static_cast<float>(1.f)));
                throttle = throttle_accu;
            }

            if (_circleCorrection) {
                float roll_limited      = std::max(static_cast<float>(-M_PI_4), std::min(roll,      static_cast<float>(M_PI_4)));
                float pitch_limited     = std::max(static_cast<float>(-M_PI_4), std::min(pitch,     static_cast<float>(M_PI_4)));
                float yaw_limited       = std::max(static_cast<float>(-M_PI_4), std::min(yaw,       static_cast<float>(M_PI_4)));
                float throttle_limited  = std::max(static_cast<float>(-M_PI_4), std::min(throttle,  static_cast<float>(M_PI_4)));

                // Map from unit circle to linear range and limit
                roll =      std::max(-1.0f, std::min(tanf(asinf(roll_limited)),     1.0f));
                pitch =     std::max(-1.0f, std::min(tanf(asinf(pitch_limited)),    1.0f));
                yaw =       std::max(-1.0f, std::min(tanf(asinf(yaw_limited)),      1.0f));
                throttle =  std::max(-1.0f, std::min(tanf(asinf(throttle_limited)), 1.0f));
            }

            if ( _exponential < -0.01f) {
                // Exponential (0% to -50% range like most RC radios)
                // _exponential is set by a slider in joystickConfigAdvanced.qml
                // Calculate new RPY with exponential applied
                roll =  -_exponential*powf(roll, 3) + (1+_exponential)*roll;
                pitch = -_exponential*powf(pitch,3) + (1+_exponential)*pitch;
                yaw =   -_exponential*powf(yaw,  3) + (1+_exponential)*yaw;
            }

            // Adjust throttle to 0:1 range
            if (_throttleMode == ThrottleModeCenterZero && _activeVehicle->supportsThrottleModeCenterZero()) {
                if (!_activeVehicle->supportsNegativeThrust() || !_negativeThrust) {
                    throttle = std::max(0.0f, throttle);
                }
            } else {
                throttle = (throttle + 1.0f) / 2.0f;
            }
            qCDebug(JoystickValuesLog) << "name:roll:pitch:yaw:throttle" << name() << roll << -pitch << yaw << throttle;
            // NOTE: The buttonPressedBits going to MANUAL_CONTROL are currently used by ArduSub (and it only handles 16 bits)
            // Set up button bitmap
            quint64 buttonPressedBits = 0;  // Buttons pressed for manualControl signal
            const int maxButtonBits = qMin(_totalButtonCount, 64);
            for (int buttonIndex = 0; buttonIndex < maxButtonBits; buttonIndex++) {
                quint64 buttonBit = static_cast<quint64>(1LL << buttonIndex);
                if (_rgButtonValues[buttonIndex] != BUTTON_UP) {
                    // Mark the button as pressed as long as its pressed
                    buttonPressedBits |= buttonBit;
                }
            }
            emit axisValues(roll, pitch, yaw, throttle);

            uint16_t shortButtons = static_cast<uint16_t>(buttonPressedBits & 0xFFFF);
            _activeVehicle->sendJoystickDataThreadSafe(roll, pitch, yaw, throttle, shortButtons);
        }
    }
}

void Joystick::startPolling(Vehicle* vehicle)
{
    if (vehicle) {
        // If a vehicle is connected, disconnect it
        if (_activeVehicle) {
            disconnect(this, &Joystick::setArmed,           _activeVehicle, &Vehicle::setArmedShowError);
            disconnect(this, &Joystick::setVtolInFwdFlight, _activeVehicle, &Vehicle::setVtolInFwdFlight);
            disconnect(this, &Joystick::setFlightMode,      _activeVehicle, &Vehicle::setFlightMode);
            disconnect(this, &Joystick::gimbalYawLock,      _activeVehicle->gimbalController(), &GimbalController::gimbalYawLock);
            disconnect(this, &Joystick::emergencyStop,      _activeVehicle, &Vehicle::emergencyStop);
            disconnect(this, &Joystick::gripperAction,      _activeVehicle, &Vehicle::setGripperAction);
            disconnect(this, &Joystick::landingGearDeploy,  _activeVehicle, &Vehicle::landingGearDeploy);
            disconnect(this, &Joystick::landingGearRetract, _activeVehicle, &Vehicle::landingGearRetract);
            disconnect(_activeVehicle, &Vehicle::flightModesChanged, this, &Joystick::_flightModesChanged);
        }
        // Always set up the new vehicle
        _activeVehicle = vehicle;
        // If joystick is not calibrated, disable it
        if ( axisCount() != 0 && !_calibrated ) {
            vehicle->setJoystickEnabled(false);
        }
        // Update qml in case of joystick transition
        emit calibratedChanged(_calibrated);
        // Build action list
        _buildActionList(vehicle);
        // Only connect the new vehicle if it wants joystick data
        if (vehicle->joystickEnabled()) {
            _pollingStartedForCalibration = false;
            connect(this, &Joystick::setArmed,           _activeVehicle, &Vehicle::setArmedShowError);
            connect(this, &Joystick::setVtolInFwdFlight, _activeVehicle, &Vehicle::setVtolInFwdFlight);
            connect(this, &Joystick::setFlightMode,      _activeVehicle, &Vehicle::setFlightMode);
            connect(this, &Joystick::gimbalYawLock,      _activeVehicle->gimbalController(), &GimbalController::gimbalYawLock);
            connect(this, &Joystick::emergencyStop,      _activeVehicle, &Vehicle::emergencyStop);
            connect(this, &Joystick::gripperAction,      _activeVehicle, &Vehicle::setGripperAction);
            connect(this, &Joystick::landingGearDeploy,  _activeVehicle, &Vehicle::landingGearDeploy);
            connect(this, &Joystick::landingGearRetract, _activeVehicle, &Vehicle::landingGearRetract);
            connect(_activeVehicle, &Vehicle::flightModesChanged, this, &Joystick::_flightModesChanged);
        }
    }
    if (!isRunning()) {
        _exitThread = false;
        start();
    }
}

void Joystick::stopPolling(void)
{
    if (isRunning()) {
        if (_activeVehicle && _activeVehicle->joystickEnabled()) {
            disconnect(this, &Joystick::setArmed,           _activeVehicle, &Vehicle::setArmedShowError);
            disconnect(this, &Joystick::setVtolInFwdFlight, _activeVehicle, &Vehicle::setVtolInFwdFlight);
            disconnect(this, &Joystick::setFlightMode,      _activeVehicle, &Vehicle::setFlightMode);
            disconnect(this, &Joystick::gimbalYawLock,      _activeVehicle->gimbalController(), &GimbalController::gimbalYawLock);
            disconnect(this, &Joystick::gripperAction,      _activeVehicle, &Vehicle::setGripperAction);
            disconnect(this, &Joystick::landingGearDeploy,  _activeVehicle, &Vehicle::landingGearDeploy);
            disconnect(this, &Joystick::landingGearRetract, _activeVehicle, &Vehicle::landingGearRetract);
            disconnect(_activeVehicle, &Vehicle::flightModesChanged, this, &Joystick::_flightModesChanged);
        }
        _exitThread = true;
    }
    _activeVehicle = nullptr;
}

void Joystick::setCalibration(int axis, Calibration_t& calibration)
{
    if (!_validAxis(axis)) {
        return;
    }
    _calibrated = true;
    _rgCalibration[axis] = calibration;
    _saveSettings();
    emit calibratedChanged(_calibrated);
}

Joystick::Calibration_t Joystick::getCalibration(int axis)
{
    if (!_validAxis(axis)) {
        return Calibration_t();
    }
    return _rgCalibration[axis];
}

void Joystick::setFunctionAxis(AxisFunction_t function, int axis)
{
    if (!_validAxis(axis)) {
        return;
    }
    _calibrated = true;
    _rgFunctionAxis[function] = axis;
    _saveSettings();
    emit calibratedChanged(_calibrated);
    if (function == gimbalPitchFunction || function == gimbalYawFunction) {
        emit rcDialAxisChanged();
    }
}

int Joystick::getFunctionAxis(AxisFunction_t function)
{
    if (static_cast<int>(function) < 0 || function >= maxFunction) {
        qCWarning(JoystickLog) << "Invalid function" << function;
    }
    return _rgFunctionAxis[function];
}

void Joystick::setButtonRepeat(int button, bool repeat)
{
    if (!_validButton(button) || !_buttonActionArray[button]) {
        return;
    }
    _buttonActionArray[button]->repeat = repeat;
    _buttonActionArray[button]->buttonTime.start();
    //-- Save to settings
    QSettings settings;
    settings.beginGroup(_settingsGroup);
    settings.beginGroup(_name);
    settings.setValue(QString(_buttonActionRepeatKey).arg(button), _buttonActionArray[button]->repeat);
}

bool Joystick::getButtonRepeat(int button)
{
    if (!_validButton(button) || !_buttonActionArray[button]) {
        return false;
    }
    return _buttonActionArray[button]->repeat;
}

void Joystick::setButtonAction(int button, const QString& action)
{
    if (!_validButton(button)) {
        return;
    }
    qCWarning(JoystickLog) << "setButtonAction:" << button << action;
    QSettings settings;
    settings.beginGroup(_settingsGroup);
    settings.beginGroup(_name);
    if(action.isEmpty() || action == _buttonActionNone) {
        if(_buttonActionArray[button]) {
            _buttonActionArray[button]->deleteLater();
            _buttonActionArray[button] = nullptr;
            //-- Clear from settings
            settings.remove(QString(_buttonActionNameKey).arg(button));
            settings.remove(QString(_buttonActionRepeatKey).arg(button));
        }
    } else {
        if(!_buttonActionArray[button]) {
            _buttonActionArray[button] = new AssignedButtonAction(this, action);
        } else {
            _buttonActionArray[button]->action = action;
            //-- Make sure repeat is off if this action doesn't support repeats
            int idx = _findAssignableButtonAction(action);
            if(idx >= 0) {
                AssignableButtonAction* p = qobject_cast<AssignableButtonAction*>(_assignableButtonActions[idx]);
                if(!p->canRepeat()) {
                    _buttonActionArray[button]->repeat = false;
                }
            }
        }
        //-- Save to settings
        settings.setValue(QString(_buttonActionNameKey).arg(button),   _buttonActionArray[button]->action);
        settings.setValue(QString(_buttonActionRepeatKey).arg(button), _buttonActionArray[button]->repeat);
    }
    settings.sync();
    // Mirror to persistent XML backup (button assignments are saved here directly).
    _backupSettingsToFile();
    emit buttonActionsChanged();
}

QString Joystick::getButtonAction(int button)
{
    if (_validButton(button)) {
        if(_buttonActionArray[button]) {
            return _buttonActionArray[button]->action;
        }
    }
    return QString(_buttonActionNone);
}

QStringList Joystick::buttonActions()
{
    QStringList list;
    for (int button = 0; button < _totalButtonCount; button++) {
        list << getButtonAction(button);
    }
    return list;
}

int Joystick::throttleMode()
{
    return _throttleMode;
}

void Joystick::setThrottleMode(int mode)
{
    if (mode < 0 || mode >= ThrottleModeMax) {
        qCWarning(JoystickLog) << "Invalid throttle mode" << mode;
        return;
    }
    _throttleMode = static_cast<ThrottleMode_t>(mode);
    if (_throttleMode == ThrottleModeDownZero) {
        setAccumulator(false);
    }
    _saveSettings();
    emit throttleModeChanged(_throttleMode);
}

bool Joystick::negativeThrust() const
{
    return _negativeThrust;
}

void Joystick::setNegativeThrust(bool allowNegative)
{
    if (_negativeThrust == allowNegative) {
        return;
    }
    _negativeThrust = allowNegative;
    _saveSettings();
    emit negativeThrustChanged(_negativeThrust);
}

float Joystick::exponential() const
{
    return _exponential;
}

void Joystick::setExponential(float expo)
{
    _exponential = expo;
    _saveSettings();
    emit exponentialChanged(_exponential);
}

bool Joystick::accumulator() const
{
    return _accumulator;
}

void Joystick::setAccumulator(bool accu)
{
    _accumulator = accu;
    _saveSettings();
    emit accumulatorChanged(_accumulator);
}

bool Joystick::deadband() const
{
    return _deadband;
}

void Joystick::setDeadband(bool deadband)
{
    _deadband = deadband;
    _saveSettings();
}

bool Joystick::circleCorrection() const
{
    return _circleCorrection;
}

void Joystick::setCircleCorrection(bool circleCorrection)
{
    _circleCorrection = circleCorrection;
    _saveSettings();
    emit circleCorrectionChanged(_circleCorrection);
}

void Joystick::setAxisFrequency(float val)
{
    //-- Arbitrary limits
    val = qMax(_minAxisFrequencyHz, val);
    val = qMin(_maxAxisFrequencyHz, val);
    _axisFrequencyHz = val;
    _saveSettings();
    emit axisFrequencyHzChanged();
}

void Joystick::setButtonFrequency(float val)
{
    //-- Arbitrary limits
    val = qMax(_minButtonFrequencyHz, val);
    val = qMin(_maxButtonFrequencyHz, val);
    _buttonFrequencyHz = val;
    _saveSettings();
    emit buttonFrequencyHzChanged();
}

void Joystick::setCalibrationMode(bool calibrating)
{
    _calibrationMode = calibrating;
    if (calibrating && !isRunning()) {
        _pollingStartedForCalibration = true;
        startPolling(_multiVehicleManager->activeVehicle());
    }
    else if (_pollingStartedForCalibration) {
        stopPolling();
    }
}


void Joystick::_executeButtonAction(const QString& action, bool buttonDown)
{
    // TEMP DIAGNOSTIC (remove after): surfaces which action reached here and the gating state.
    qWarning() << "JSBTN_DIAG execute action=" << action << "down=" << buttonDown
               << "vehicle=" << (_activeVehicle != nullptr)
               << "jsEnabled=" << (_activeVehicle ? _activeVehicle->joystickEnabled() : false);
    if (!_activeVehicle || !_activeVehicle->joystickEnabled() || action == _buttonActionNone) {
        return;
    }
    if (action == _buttonActionArm) {
        if (buttonDown) emit setArmed(true);
    } else if (action == _buttonActionDisarm) {
        if (buttonDown) emit setArmed(false);
    } else if (action == _buttonActionToggleArm) {
        if (buttonDown) emit setArmed(!_activeVehicle->armed());
    } else if (action == _buttonActionVTOLFixedWing) {
        if (buttonDown) emit setVtolInFwdFlight(true);
    } else if (action == _buttonActionVTOLMultiRotor) {
        if (buttonDown) emit setVtolInFwdFlight(false);
    } else if (_activeVehicle->flightModes().contains(action)) {
        if (buttonDown) emit setFlightMode(action);
    } else if(action == _buttonActionContinuousZoomIn || action == _buttonActionContinuousZoomOut) {
        if (buttonDown) {
            emit startContinuousZoom(action == _buttonActionContinuousZoomIn ? 1 : -1);
        } else {
            emit stopContinuousZoom();
        }
    } else if(action == _buttonActionStepZoomIn || action == _buttonActionStepZoomOut) {
        if (buttonDown) emit stepZoom(action == _buttonActionStepZoomIn ? 1 : -1);
    } else if(action == _buttonActionNextStream || action == _buttonActionPreviousStream) {
        if (buttonDown) emit stepStream(action == _buttonActionNextStream ? 1 : -1);
    } else if(action == _buttonActionNextCamera || action == _buttonActionPreviousCamera) {
        if (buttonDown) emit stepCamera(action == _buttonActionNextCamera ? 1 : -1);
    } else if(action == _buttonActionTriggerCamera) {
        if (buttonDown) emit triggerCamera();
    } else if(action == _buttonActionStartVideoRecord) {
        if (buttonDown) emit startVideoRecord();
    } else if(action == _buttonActionStopVideoRecord) {
        if (buttonDown) emit stopVideoRecord();
    } else if(action == _buttonActionToggleVideoRecord) {
        if (buttonDown) emit toggleVideoRecord();
    } else if(action == _buttonActionGimbalUp) {
        // Hold-to-move: press starts the slew, release (direction 0) stops it.
        emit gimbalPitchStep(buttonDown ? 1 : 0);
    } else if(action == _buttonActionGimbalDown) {
        emit gimbalPitchStep(buttonDown ? -1 : 0);
    } else if(action == _buttonActionGimbalLeft) {
        emit gimbalYawStep(buttonDown ? -1 : 0);
    } else if(action == _buttonActionGimbalRight) {
        emit gimbalYawStep(buttonDown ? 1 : 0);
    } else if(action == _buttonActionGimbalCenter) {
        if (buttonDown) emit centerGimbal();
    } else if(action == _buttonActionGimbalYawLock) {
        if (buttonDown) emit gimbalYawLock(true);
    } else if(action == _buttonActionGimbalYawFollow) {
        if (buttonDown) emit gimbalYawLock(false);
    } else if(action == _buttonActionEmergencyStop) {
        if (buttonDown) emit emergencyStop();
    } else if(action == _buttonActionGripperGrab) {
        if(buttonDown) {
            emit gripperAction(GRIPPER_ACTION_GRAB);
        }
    } else if(action == _buttonActionGripperRelease) {
        if(buttonDown) {
            emit gripperAction(GRIPPER_ACTION_RELEASE);
        }
    } else if(action == _buttonActionLandingGearDeploy) {
        if (buttonDown) emit landingGearDeploy();
    } else if(action == _buttonActionLandingGearRetract) {
        if (buttonDown) emit landingGearRetract();
    } else {
        if (buttonDown && _activeVehicle) {
            for (auto& item : _customMavCommands) {
                if (action == item.name()) {
                    item.send(_activeVehicle);
                    return;
                }
            }
        }
    }
}

bool Joystick::_validAxis(int axis) const
{
    if(axis >= 0 && axis < _axisCount) {
        return true;
    }
    //qCWarning(JoystickLog) << "Invalid axis index" << axis;
    return false;
}

bool Joystick::_validButton(int button) const
{
    if(button >= 0 && button < _totalButtonCount)
        return true;
    qCWarning(JoystickLog) << "Invalid button index" << button;
    return false;
}

int Joystick::_findAssignableButtonAction(const QString& action)
{
    for(int i = 0; i < _assignableButtonActions.count(); i++) {
        AssignableButtonAction* p = qobject_cast<AssignableButtonAction*>(_assignableButtonActions[i]);
        if(p->action() == action)
            return i;
    }
    return -1;
}

void Joystick::_buildActionList(Vehicle* activeVehicle)
{
    if(_assignableButtonActions.count())
        _assignableButtonActions.clearAndDeleteContents();
    _availableActionTitles.clear();
    //-- Available Actions
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionNone));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionArm));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionDisarm));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionToggleArm));
    if (activeVehicle) {
        QStringList list = activeVehicle->flightModes();
        foreach(auto mode, list) {
            _assignableButtonActions.append(new AssignableButtonAction(this, mode));
        }
    }
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionVTOLFixedWing));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionVTOLMultiRotor));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionContinuousZoomIn, true));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionContinuousZoomOut, true));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionStepZoomIn,  true));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionStepZoomOut, true));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionNextStream));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionPreviousStream));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionNextCamera));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionPreviousCamera));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionTriggerCamera));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionStartVideoRecord));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionStopVideoRecord));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionToggleVideoRecord));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionGimbalDown,    true));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionGimbalUp,      true));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionGimbalLeft,    true));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionGimbalRight,   true));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionGimbalCenter));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionGimbalYawLock));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionGimbalYawFollow));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionEmergencyStop));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionGripperGrab));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionGripperRelease));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionLandingGearDeploy));
    _assignableButtonActions.append(new AssignableButtonAction(this, _buttonActionLandingGearRetract));

    for (auto& item : _customMavCommands) {
        _assignableButtonActions.append(new AssignableButtonAction(this, item.name()));
    }

    for(int i = 0; i < _assignableButtonActions.count(); i++) {
        AssignableButtonAction* p = qobject_cast<AssignableButtonAction*>(_assignableButtonActions[i]);
        _availableActionTitles << p->action();
    }
    emit assignableActionsChanged();
}
