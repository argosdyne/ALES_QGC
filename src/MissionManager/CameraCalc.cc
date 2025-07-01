/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "CameraCalc.h"
#include "JsonHelper.h"
#include "Vehicle.h"
#include "CameraMetaData.h"
#include "PlanMasterController.h"

#include "TransectStyleComplexItem.h"

#include <QQmlEngine>

const char* CameraCalc::cameraNameName                  = "CameraName";
const char* CameraCalc::valueSetIsDistanceName          = "ValueSetIsDistance";
const char* CameraCalc::distanceToSurfaceName           = "DistanceToSurface";
const char* CameraCalc::distanceModeName                = "DistanceMode";
const char* CameraCalc::imageDensityName                = "ImageDensity";
const char* CameraCalc::frontalOverlapName              = "FrontalOverlap";
const char* CameraCalc::sideOverlapName                 = "SideOverlap";
const char* CameraCalc::adjustedFootprintFrontalName    = "AdjustedFootprintFrontal";
const char* CameraCalc::adjustedFootprintSideName       = "AdjustedFootprintSide";

const char* CameraCalc::_jsonCameraSpecTypeKeyDeprecated            = "CameraSpecType";
const char* CameraCalc::_jsonDistanceToSurfaceRelativeKeyDeprecated = "DistanceToSurfaceRelative";

//Yellow Scan
const char* CameraCalc::yellowScanFOVFactName           = "YellowScanFOV";
const char* CameraCalc::yellowScanOverlapName           = "YellowScanOverlap";

CameraCalc::CameraCalc(PlanMasterController* masterController, const QString& settingsGroup, QObject* parent)
    : CameraSpec                    (settingsGroup, parent)
    , _distanceMode                 (masterController->missionController()->globalAltitudeModeDefault())
    , _knownCameraList              (masterController->controllerVehicle()->staticCameraList())
    , _metaDataMap                  (FactMetaData::createMapFromJsonFile(QStringLiteral(":/json/CameraCalc.FactMetaData.json"), this))
    , _cameraNameFact               (settingsGroup, _metaDataMap[cameraNameName])
    , _valueSetIsDistanceFact       (settingsGroup, _metaDataMap[valueSetIsDistanceName])
    , _distanceToSurfaceFact        (settingsGroup, _metaDataMap[distanceToSurfaceName])
    , _imageDensityFact             (settingsGroup, _metaDataMap[imageDensityName])
    , _frontalOverlapFact           (settingsGroup, _metaDataMap[frontalOverlapName])
    , _sideOverlapFact              (settingsGroup, _metaDataMap[sideOverlapName])
    , _adjustedFootprintSideFact    (settingsGroup, _metaDataMap[adjustedFootprintSideName])
    , _adjustedFootprintFrontalFact (settingsGroup, _metaDataMap[adjustedFootprintFrontalName])
    , _yellowScanFact               (settingsGroup, _metaDataMap[cameraNameName])
    , _yellowScanFOVFact            (settingsGroup, _metaDataMap[yellowScanFOVFactName])
    , _yellowScanOverlapFact        (settingsGroup, _metaDataMap[yellowScanOverlapName])
{
    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);

    connect(&_valueSetIsDistanceFact,       &Fact::valueChanged,                this, &CameraCalc::_setDirty);
    connect(&_distanceToSurfaceFact,        &Fact::valueChanged,                this, &CameraCalc::_setDirty);
    connect(&_imageDensityFact,             &Fact::valueChanged,                this, &CameraCalc::_setDirty);
    connect(&_frontalOverlapFact,           &Fact::valueChanged,                this, &CameraCalc::_setDirty);
    connect(&_sideOverlapFact,              &Fact::valueChanged,                this, &CameraCalc::_setDirty);
    connect(&_adjustedFootprintSideFact,    &Fact::valueChanged,                this, &CameraCalc::_setDirty);
    connect(&_adjustedFootprintFrontalFact, &Fact::valueChanged,                this, &CameraCalc::_setDirty);
    connect(&_cameraNameFact,               &Fact::valueChanged,                this, &CameraCalc::_setDirty);
    connect(this,                           &CameraCalc::distanceModeChanged,   this, &CameraCalc::_setDirty);

    connect(&_cameraNameFact, &Fact::valueChanged, this, &CameraCalc::_cameraNameChanged);
    connect(&_cameraNameFact, &Fact::valueChanged, this, &CameraCalc::isManualCameraChanged);
    connect(&_cameraNameFact, &Fact::valueChanged, this, &CameraCalc::isCustomCameraChanged);

    //Yellow Scan
    connect(&_yellowScanFact,               &Fact::valueChanged,                this, &CameraCalc::isYSLidarChanged);
    connect(&_yellowScanFact,               &Fact::valueChanged,                this, &CameraCalc::_setDirty);
    connect(&_yellowScanFOVFact,            &Fact::valueChanged,                this, &CameraCalc::_setDirty);
    connect(&_yellowScanOverlapFact,        &Fact::valueChanged,                this, &CameraCalc::_setDirty);    

    //Checkbox
    connect(&_yellowScanAltitude,           & Fact::valueChanged,               this, &CameraCalc::_setDirty);
    connect(&_yellowScanSpacing,            & Fact::valueChanged,               this, &CameraCalc::_setDirty);
    connect(&_yellowScanOverlap,            & Fact::valueChanged,               this, &CameraCalc::_setDirty);
    connect(&_yellowScanFOV,                & Fact::valueChanged,               this, &CameraCalc::_setDirty);

    //Enable Check
    //connect(&_yellowScanAltitudeEnable, & Fact::valueChanged,               this, &CameraCalc::_setDirty);
    connect(&_yellowScanSpacingEnable, & Fact::valueChanged,               this, &CameraCalc::_setDirty);
    connect(&_yellowScanOverlapEnable, & Fact::valueChanged,               this, &CameraCalc::_setDirty);
    connect(&_yellowScanFOVEnable, & Fact::valueChanged,               this, &CameraCalc::_setDirty);

    connect(&_distanceToSurfaceFact,    &Fact::rawValueChanged, this, &CameraCalc::_recalcTriggerDistance);
    connect(&_imageDensityFact,         &Fact::rawValueChanged, this, &CameraCalc::_recalcTriggerDistance);
    connect(&_frontalOverlapFact,       &Fact::rawValueChanged, this, &CameraCalc::_recalcTriggerDistance);
    connect(&_sideOverlapFact,          &Fact::rawValueChanged, this, &CameraCalc::_recalcTriggerDistance);
    connect(sensorWidth(),              &Fact::rawValueChanged, this, &CameraCalc::_recalcTriggerDistance);
    connect(sensorHeight(),             &Fact::rawValueChanged, this, &CameraCalc::_recalcTriggerDistance);
    connect(imageWidth(),               &Fact::rawValueChanged, this, &CameraCalc::_recalcTriggerDistance);
    connect(imageHeight(),              &Fact::rawValueChanged, this, &CameraCalc::_recalcTriggerDistance);
    connect(focalLength(),              &Fact::rawValueChanged, this, &CameraCalc::_recalcTriggerDistance);
    connect(landscape(),                &Fact::rawValueChanged, this, &CameraCalc::_recalcTriggerDistance);

    // Build the brand list from known cameras
    _cameraBrandList.append(xlatManualCameraName());
    _cameraBrandList.append(xlatCustomCameraName());
    for (int cameraIndex=0; cameraIndex<_knownCameraList.count(); cameraIndex++) {
        CameraMetaData* cameraMetaData = _knownCameraList[cameraIndex].value<CameraMetaData*>();
        if (!_cameraBrandList.contains(cameraMetaData->brand)) {
            _cameraBrandList.append(cameraMetaData->brand);
        }
    }

    _cameraNameChanged();
    _setBrandModelFromCanonicalName(_cameraNameFact.rawValue().toString());

    setDirty(false);

    //Checkbox default value
    qInfo() << "Checkbox default value";
    _yellowScanAltitude.setRawValue(true);
    _yellowScanOverlap.setRawValue(true);
    _yellowScanFOV.setRawValue(true);
}
// Constants
constexpr double DEG_TO_RAD = M_PI / 180.0;
constexpr double RAD_TO_DEG = 180.0 / M_PI;

// Compute horizontal field of view (FOV) in degrees given altitude (H), overlap ratio (O), and line spacing (S)
double computeFOV(double H, double O, double S) {
    // Convert percent input to ratio
    if (O > 1.0) {
        O = O / 100.0;
    }
    if (H <= 0 || O >= 1.0 || O < 0 || S <= 0) {
        throw std::invalid_argument("Invalid input for computing FOV");
    }
    // Ground footprint corrected for overlap
    double footprint = S / (1.0 - O);
    // Compute half-angle in radians
    double halfAngleRad = std::atan((footprint * 0.5) / H);
    // Return full horizontal FOV in degrees
    return 2.0 * halfAngleRad * RAD_TO_DEG;
}

// Compute altitude (H) given overlap (O), line spacing (S), and FOV in degrees
double computeAltitude(double O, double S, double fovDeg) {
    if (O > 1.0) {
        O = O / 100.0;
    }
    if (O >= 1.0 || O < 0 || S <=   0) {
        throw std::invalid_argument("Invalid input for computing altitude");
    }
    double fovRad = fovDeg * DEG_TO_RAD;
    double footprint = S / (1.0 - O);
    return (footprint * 0.5) / std::tan(fovRad * 0.5);
}

// Compute overlap ratio (O) given altitude (H), line spacing (S), and FOV in degrees
double computeOverlap(double H, double S, double fovDeg) {
    if (H <= 0 || S <= 0) {
        throw std::invalid_argument("Invalid input for computing overlap");
    }
    double fovRad = fovDeg * DEG_TO_RAD;
    double footprint = 2.0 * H * std::tan(fovRad * 0.5);
    double overlapRatio = 1.0 - (S / footprint);
    return overlapRatio * 100.0; // return as percentage
}

// Compute line spacing (S) given altitude (H), overlap (O), and FOV in degrees
double computeSpacing(double H, double O, double fovDeg) {
    if (O > 1.0) {
        O = O / 100.0;
    }
    if (H <= 0 || O >= 1.0 || O < 0) {
        throw std::invalid_argument("Invalid input for computing spacing");
    }
    double fovRad = fovDeg * DEG_TO_RAD;
    double footprint = 2.0 * H * std::tan(fovRad * 0.5);
    return footprint * (1.0 - O);
}

void CameraCalc::calcSpacing() {
    if (_transectItem) {
        _transectItem->replaceSpacing();
    }
}

void CameraCalc::calculate(){
    qInfo() << "calculate CameraCalc";
    //Calc value
    double alt = _distanceToSurfaceFact.rawValue().toDouble();
    double overlap = _yellowScanOverlapFact.rawValue().toDouble();
    double spacing = _adjustedFootprintSideFact.rawValue().toDouble();
    double fov = _yellowScanFOVFact.rawValue().toDouble();

    //Enable Check
    bool altEnable = _yellowScanAltitude.rawValue().toBool();
    bool spacingEnable = _yellowScanSpacing.rawValue().toBool();
    bool overlapEnable = _yellowScanOverlap.rawValue().toBool();
    bool fovEnable = _yellowScanFOV.rawValue().toBool();

    int enabledCount = altEnable + spacingEnable + overlapEnable + fovEnable;
    if (enabledCount == 3) {
        if (!altEnable) {
            alt = computeAltitude(overlap, spacing, fov);
            _distanceToSurfaceFact.setRawValue(alt);
            qDebug() << "False: Altitude";
        }
        else if (!spacingEnable) {
            spacing = computeSpacing(alt, overlap, fov);
            _adjustedFootprintSideFact.setRawValue(spacing);
            qDebug() << "False: Spacing";
        }
        else if (!overlapEnable) {
            overlap = computeOverlap(alt, spacing, fov);
            _yellowScanOverlapFact.setRawValue(overlap);
            qDebug() << "False: Overlap";
        }
        else /* if (!fovEnable) */ {
            fov = computeFOV(alt, overlap, spacing);
            _yellowScanFOVFact.setRawValue(fov);
            qDebug() << "False: FOV";
        }
    }

    calcSpacing();

    return;
}

void CameraCalc::_cameraNameChanged(void)
{
    if (_disableRecalc) {
        return;
    }

    QString cameraName = _cameraNameFact.rawValue().toString();

    if (isManualCamera() || isCustomCamera()) {
        fixedOrientation()->setRawValue(false);
        minTriggerInterval()->setRawValue(0);
        if (isManualCamera() && !valueSetIsDistance()->rawValue().toBool()) {
            valueSetIsDistance()->setRawValue(true);
        }
    } else {
        // Look for known camera
        CameraMetaData* knownCameraMetaData = nullptr;
        for (int cameraIndex=0; cameraIndex<_knownCameraList.count(); cameraIndex++) {
            CameraMetaData* cameraMetaData = _knownCameraList[cameraIndex].value<CameraMetaData*>();
            if (cameraName == cameraMetaData->canonicalName) {
                knownCameraMetaData = cameraMetaData;
                break;
            }
        }

        _yellowScanFact.setRawValue(cameraName);

        qInfo() << "CameraName = " << cameraName;
        qInfo() << "_yelloScanFact rawVAlue = " << _yellowScanFact.rawValue().toString();
        qInfo() << "_cameraNameFact rawValue = " << _cameraNameFact.rawValue().toString();
        qInfo() << "contains Yello Scan";
        qInfo() << "isYSLidar = " << isYSLidar();
        emit isYSLidarChanged();

        if(cameraName.contains("Yellow Scan"))  {

            qInfo() << "yellowScanFOVChange";
            qInfo() << "isYSAltitudeUse = " << _yellowScanAltitude.rawValue().toBool();
            qInfo() << "_yellowScanSpacing = " << _yellowScanSpacing.rawValue().toBool();
            qInfo() << "_yellowScanOverlap = " << _yellowScanOverlap.rawValue().toBool();
            qInfo() << "_yellowScanFOV = " << _yellowScanFOV.rawValue().toBool();

            _cameraNameFact.setRawValue(canonicalManualCameraName());
            _yellowScanAltitudeEnable = _yellowScanAltitude.rawValue().toBool();
            emit isYSAltitudeEnableChanged();
            return;
        }

        if (!knownCameraMetaData) {
            // Lookup failed. Force to custom as fallback.
            // This will cause another camera changed signal which will recurse back into this routine
            _cameraNameFact.setRawValue(canonicalCustomCameraName());
            return;
        }

        _disableRecalc = true;

        sensorWidth()->setRawValue          (knownCameraMetaData->sensorWidth);
        sensorHeight()->setRawValue         (knownCameraMetaData->sensorHeight);
        imageWidth()->setRawValue           (knownCameraMetaData->imageWidth);
        imageHeight()->setRawValue          (knownCameraMetaData->imageHeight);
        focalLength()->setRawValue          (knownCameraMetaData->focalLength);
        landscape()->setRawValue            (knownCameraMetaData->landscape);
        fixedOrientation()->setRawValue     (knownCameraMetaData->fixedOrientation);
        minTriggerInterval()->setRawValue   (knownCameraMetaData->minTriggerInterval);

        _disableRecalc = false;
    }

    _recalcTriggerDistance();
    if (!isManualCamera() && distanceMode() == QGroundControlQmlGlobal::AltitudeModeAbsolute) {
        // Manual grids support absolute alts whereas nothing else does. Make sure we are not left in absolute
        setDistanceMode(QGroundControlQmlGlobal::AltitudeModeRelative);
    }
}

void CameraCalc::_recalcTriggerDistance(void)
{
    if (_disableRecalc || isManualCamera()) {
        return;
    }

    _disableRecalc = true;

    double focalLength =    this->focalLength()->rawValue().toDouble();
    double sensorWidth =    this->sensorWidth()->rawValue().toDouble();
    double sensorHeight =   this->sensorHeight()->rawValue().toDouble();
    double imageWidth =     this->imageWidth()->rawValue().toDouble();
    double imageHeight =    this->imageHeight()->rawValue().toDouble();
    double imageDensity =   _imageDensityFact.rawValue().toDouble();

    if (focalLength <= 0 || sensorWidth <= 0 || sensorHeight <= 0 || imageWidth <= 0 || imageHeight <= 0 || imageDensity <= 0) {
        return;
    }

    if (_valueSetIsDistanceFact.rawValue().toBool()) {
        _imageDensityFact.setRawValue((_distanceToSurfaceFact.rawValue().toDouble() * sensorWidth * 100.0) / (imageWidth * focalLength));
    } else {
        _distanceToSurfaceFact.setRawValue((imageWidth * _imageDensityFact.rawValue().toDouble() * focalLength) / (sensorWidth * 100.0));
    }

    imageDensity = _imageDensityFact.rawValue().toDouble();

    if (landscape()->rawValue().toBool()) {
        _imageFootprintSide =       (imageWidth  * imageDensity) / 100.0;
        _imageFootprintFrontal =    (imageHeight * imageDensity) / 100.0;
    } else {
        _imageFootprintSide  =      (imageHeight * imageDensity) / 100.0;
        _imageFootprintFrontal =    (imageWidth  * imageDensity) / 100.0;
    }
    _adjustedFootprintSideFact.setRawValue      (_imageFootprintSide * ((100.0 - _sideOverlapFact.rawValue().toDouble()) / 100.0));
    _adjustedFootprintFrontalFact.setRawValue   (_imageFootprintFrontal * ((100.0 - _frontalOverlapFact.rawValue().toDouble()) / 100.0));

    emit imageFootprintSideChanged      (_imageFootprintSide);
    emit imageFootprintFrontalChanged   (_imageFootprintFrontal);

    _disableRecalc = false;
}

void CameraCalc::save(QJsonObject& json) const
{
    json[JsonHelper::jsonVersionKey]    = 2;
    json[adjustedFootprintSideName]     = _adjustedFootprintSideFact.rawValue().toDouble();
    json[adjustedFootprintFrontalName]  = _adjustedFootprintFrontalFact.rawValue().toDouble();
    json[distanceToSurfaceName]         = _distanceToSurfaceFact.rawValue().toDouble();
    json[distanceModeName]              = _distanceMode;
    json[cameraNameName]                = _cameraNameFact.rawValue().toString();

    //YellowScan
    json[yellowScanFOVFactName]         = _yellowScanFOVFact.rawValue().toDouble();
    json[yellowScanOverlapName]         = _yellowScanOverlapFact.rawValue().toDouble();

    if (!isManualCamera()) {
        CameraSpec::save(json);
        json[valueSetIsDistanceName] = _valueSetIsDistanceFact.rawValue().toBool();
        json[imageDensityName] =       _imageDensityFact.rawValue().toDouble();
        json[frontalOverlapName] =     _frontalOverlapFact.rawValue().toDouble();
        json[sideOverlapName] =        _sideOverlapFact.rawValue().toDouble();
    }
}

bool CameraCalc::load(const QJsonObject& originalJson, bool deprecatedFollowTerrain, QString& errorString, bool forPresets)
{
    qInfo() << "load cameraCalc";
    QJsonObject json = originalJson;

    int version = 0;
    if (json.contains(JsonHelper::jsonVersionKey)) {
        version = json[JsonHelper::jsonVersionKey].toInt();
    }

    if (version == 0) {
        // Version 0->1 differences:
        //  - JsonHelper::jsonVersionKey not stored
        //  - _jsonCameraSpecTypeKeyDeprecated is only in v0 files and stores CameraSpecType. V2 files store same info in cameraNameName.
        //  - _jsonCameraNameKey only set if CameraSpecKnown
        int cameraSpec = json[_jsonCameraSpecTypeKeyDeprecated].toInt(CameraSpecNone);
        qInfo() << "cameraSpec No = " << cameraSpec;
        if (cameraSpec == CameraSpecCustom) {
            qInfo() << "Camera Custom Spec";
            json[cameraNameName] = canonicalCustomCameraName();
        } else if (cameraSpec == CameraSpecNone) {
            qInfo() << "Camera None Spec";
            json[cameraNameName] = canonicalManualCameraName();
        }
        json.remove(_jsonCameraSpecTypeKeyDeprecated);
        version = 1;
    }
    if (version == 1) {
        // Version 1->2 differences:
        //  - _jsonDistanceToSurfaceRelativeKeyDeprecated changed to distanceMode
        //  - deprecatedFollowTerrain value was loaded from upper level callers and represents AltitudeModeCalcAboveTerrain. AtitudeModeTerrainFrame was not supported yet.
        if (deprecatedFollowTerrain) {
            json[distanceModeName] = QGroundControlQmlGlobal::AltitudeModeCalcAboveTerrain;
        } else {
            json[distanceModeName] = json[_jsonDistanceToSurfaceRelativeKeyDeprecated].toBool() ? QGroundControlQmlGlobal::AltitudeModeRelative : QGroundControlQmlGlobal::AltitudeModeAbsolute;
        }
        json.remove(_jsonDistanceToSurfaceRelativeKeyDeprecated);
        version = 2;
    }
    if (version != 2) {
        errorString = tr("CameraCalc section version %1 not supported").arg(version);
        return false;
    }

    QList<JsonHelper::KeyValidateInfo> keyInfoList1 = {
        { cameraNameName,                   QJsonValue::String, true },
        { adjustedFootprintSideName,        QJsonValue::Double, true },
        { adjustedFootprintFrontalName,     QJsonValue::Double, true },
        { distanceToSurfaceName,            QJsonValue::Double, true },
        { distanceModeName,                 QJsonValue::Double, true },
        { yellowScanFOVFactName,            QJsonValue::Double, true },
        { yellowScanOverlapName,            QJsonValue::Double, true },
    };
    if (!JsonHelper::validateKeys(json, keyInfoList1, errorString)) {
        return false;
    }

    _disableRecalc = !forPresets;

    // We have to clean up camera names. Older builds incorrectly used translated the camera names in the persisted plan file.
    // Newer builds use a canonical english camera name in plan files.
    QString canonicalCameraName = _validCanonicalCameraName(json[cameraNameName].toString());
    _cameraNameFact.setRawValue(canonicalCameraName);

    setDistanceMode(static_cast<QGroundControlQmlGlobal::AltMode>(json[distanceModeName].toInt()));

    _adjustedFootprintSideFact.setRawValue      (json[adjustedFootprintSideName].toDouble());
    _adjustedFootprintFrontalFact.setRawValue   (json[adjustedFootprintFrontalName].toDouble());
    _distanceToSurfaceFact.setRawValue          (json[distanceToSurfaceName].toDouble());

    //Yellow Scan
    _yellowScanFOVFact.setRawValue              (json[yellowScanFOVFactName].toDouble());
    _yellowScanOverlapFact.setRawValue          (json[yellowScanOverlapName].toDouble());

    if (!isManualCamera()) {
        QList<JsonHelper::KeyValidateInfo> keyInfoList2 = {
            { valueSetIsDistanceName,   QJsonValue::Bool,   true },
            { imageDensityName,         QJsonValue::Double, true },
            { frontalOverlapName,       QJsonValue::Double, true },
            { sideOverlapName,          QJsonValue::Double, true },
        };
        if (!JsonHelper::validateKeys(json, keyInfoList2, errorString)) {
            _disableRecalc = false;
            return false;
        }

        _valueSetIsDistanceFact.setRawValue (json[valueSetIsDistanceName].toBool());
        _frontalOverlapFact.setRawValue     (json[frontalOverlapName].toDouble());
        _sideOverlapFact.setRawValue        (json[sideOverlapName].toDouble());
        _imageDensityFact.setRawValue       (json[imageDensityName].toDouble());

        if (!CameraSpec::load(json, errorString)) {
            _disableRecalc = false;
            return false;
        }
    }

    _disableRecalc = false;

    _setBrandModelFromCanonicalName(canonicalCameraName);

    return true;
}


QString CameraCalc::canonicalCustomCameraName(void)
{

    // This string should NOT be translated
    return "Custom Camera";
}

QString CameraCalc::canonicalManualCameraName(void)
{
    // This string should NOT be translated
    qInfo() << "canonicalManualCamera";

    //if(_cameraNameFact.rawValue().toString().contains)
    return "Manual (no camera specs)";
}

QString CameraCalc::xlatCustomCameraName(void)
{
    return tr("Custom Camera");
}

QString CameraCalc::xlatManualCameraName(void)
{
    qInfo() << "xlatManualCameraName";
    return tr("Manual (no camera specs)");
}

void CameraCalc::setDistanceMode(QGroundControlQmlGlobal::AltMode altMode)
{
    if (altMode != _distanceMode) {
        _distanceMode = altMode;
        emit distanceModeChanged(_distanceMode);
    }
}

void CameraCalc::_setDirty(void)
{
    setDirty(true);
}

void CameraCalc::setCameraBrand(const QString& cameraBrand)
{
    // Note that cameraBrand can also be manual or custom camera

    if (cameraBrand != _cameraBrand) {
        QString newCameraName = cameraBrand;

        _cameraBrand = cameraBrand;
        _cameraModel.clear();

        if (_cameraBrand != xlatManualCameraName() && _cameraBrand != xlatCustomCameraName()) {
            CameraMetaData* firstCameraMetaData = nullptr;
            for (int cameraIndex=0; cameraIndex<_knownCameraList.count(); cameraIndex++) {
                firstCameraMetaData = _knownCameraList[cameraIndex].value<CameraMetaData*>();
                if (firstCameraMetaData->brand == _cameraBrand) {
                    break;
                }
            }
            newCameraName = firstCameraMetaData->canonicalName;
            _cameraModel = firstCameraMetaData->model;
        }
        emit cameraBrandChanged();
        emit cameraModelChanged();

        _rebuildCameraModelList();

        _cameraNameFact.setRawValue(newCameraName);
    }
}

void CameraCalc::setCameraModel(const QString& cameraModel)
{
    if (cameraModel != _cameraModel) {
        _cameraModel = cameraModel;
        emit cameraModelChanged();

        for (int cameraIndex=0; cameraIndex<_knownCameraList.count(); cameraIndex++) {
            CameraMetaData* cameraMetaData = _knownCameraList[cameraIndex].value<CameraMetaData*>();
            if (cameraMetaData->brand == _cameraBrand && cameraMetaData->model == _cameraModel) {
                _cameraNameFact.setRawValue(cameraMetaData->canonicalName);
                break;
            }
        }

    }
}

void CameraCalc::_setBrandModelFromCanonicalName(const QString& cameraName)
{
    _cameraBrand = cameraName;
    _cameraModel.clear();
    _cameraModelList.clear();

    qInfo() << "setBrandModelFromeCanonicalName";

    if(cameraName == canonicalManualCameraName()){
        qInfo() << "This is Manual Camera = "<< cameraName;
        calcSpacing();
    }

    if (cameraName != canonicalManualCameraName() && cameraName != canonicalCustomCameraName() && cameraName.contains("Yellow Scan") == false) {
        for (int cameraIndex=0; cameraIndex<_knownCameraList.count(); cameraIndex++) {
            CameraMetaData* cameraMetaData = _knownCameraList[cameraIndex].value<CameraMetaData*>();
            if (cameraMetaData->canonicalName == cameraName) {
                _cameraBrand = cameraMetaData->brand;
                _cameraModel = cameraMetaData->model;
                break;
            }
        }
    }
    emit cameraBrandChanged();
    emit cameraModelChanged();

    _rebuildCameraModelList();
}

void CameraCalc::_rebuildCameraModelList(void)
{
    _cameraModelList.clear();

    for (int cameraIndex=0; cameraIndex<_knownCameraList.count(); cameraIndex++) {
        CameraMetaData* cameraMetaData = _knownCameraList[cameraIndex].value<CameraMetaData*>();
        if (cameraMetaData->brand == _cameraBrand) {
            _cameraModelList.append(cameraMetaData->model);
        }
    }

    emit cameraModelListChanged();
}

void CameraCalc::_setCameraNameFromV3TransectLoad(const QString& cameraName)
{
    // We don't recalc here since the rest of the camera values are already loaded from the json
    _disableRecalc = true;
    QString canonicalCameraName = _validCanonicalCameraName(cameraName);
    _cameraNameFact.setRawValue(cameraName);
    _disableRecalc = true;

    _setBrandModelFromCanonicalName(canonicalCameraName);
}

QString CameraCalc::_validCanonicalCameraName(const QString& cameraName)
{
    QString canonicalCameraName = cameraName;
    qInfo() << "Cmaera Name Name = "<< canonicalCameraName;
    if (canonicalCameraName != canonicalCustomCameraName() && canonicalCameraName != canonicalManualCameraName()) {

        if(cameraName.contains("Yellow Scan")){
            canonicalCameraName = canonicalManualCameraName();               
        }

        if (cameraName == xlatManualCameraName()) {
            canonicalCameraName = canonicalManualCameraName();
        } else if (cameraName == xlatCustomCameraName()) {
            canonicalCameraName = canonicalCustomCameraName();
        } else {
            // Look for known camera
            for (int cameraIndex=0; cameraIndex<_knownCameraList.count(); cameraIndex++) {
                CameraMetaData* cameraMetaData = _knownCameraList[cameraIndex].value<CameraMetaData*>();
                if (cameraName == cameraMetaData->canonicalName || cameraName == cameraMetaData->deprecatedTranslatedName) {
                    return cameraMetaData->canonicalName;
                }
            }

            canonicalCameraName = canonicalCustomCameraName();
        }
    }

    return canonicalCameraName;
}
