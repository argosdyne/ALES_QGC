/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "MissionFileValidator.h"
#include "JsonHelper.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QtMath>
#include <QtGlobal>

namespace {

static const char* kFileTypeKey = "fileType";
static const char* kPlanFileType = "Plan";
static const char* kMissionKey = "mission";
static const char* kItemsKey = "items";
static const char* kCoordinateKey = "coordinate";
static const char* kParamsKey = "params";
static const char* kLatitudeKey = "Lat";
static const char* kLongitudeKey = "Lon";
static const char* kAltitudeKey = "Alt";
static constexpr qint64 kBytesPerMB = 1024 * 1024;
static constexpr double kMinAltitudeMeters = -50.0;

bool doubleValueIsFinite(const QJsonValue& value, double& doubleValue)
{
    if (!value.isDouble()) {
        return false;
    }

    doubleValue = value.toDouble();
    return qIsFinite(doubleValue);
}

bool coordinateValuesAreValid(double lat, double lon, double alt)
{
    return qIsFinite(lat) &&
            qIsFinite(lon) &&
            qIsFinite(alt) &&
            qAbs(lat) <= 90.0 &&
            qAbs(lon) <= 180.0 &&
            alt >= kMinAltitudeMeters &&
            alt <= MissionFileValidator::MaxAltitudeMeters;
}

} // namespace

MissionFileValidator::ValidationResult MissionFileValidator::validate(const QString& missionFilename, const QString& missionBasePath, QString& errorString)
{
    errorString.clear();

    // Internal Qt resources are used by unit tests and are not externally supplied mission files.
    if (missionFilename.startsWith(QStringLiteral(":/"))) {
        return Accepted;
    }

    QFileInfo fileInfo(missionFilename);
    if (!fileInfo.exists() || !fileInfo.isFile() || !fileInfo.isReadable()) {
        return RejectedFormat;
    }

    if (fileInfo.size() > (MaxFileSizeMB * kBytesPerMB)) {
        return RejectedSize;
    }

    const QFileInfo baseInfo(missionBasePath);
    const QString basePath = QDir::cleanPath(baseInfo.canonicalFilePath());
    const QString targetPath = QDir::cleanPath(fileInfo.canonicalFilePath());

    if (basePath.isEmpty() || targetPath.isEmpty()) {
        return RejectedPath;
    }

    QDir baseDir(basePath);
    const QString relativePath = baseDir.relativeFilePath(targetPath);
    if (relativePath == QStringLiteral("..") ||
            relativePath.startsWith(QStringLiteral("../")) ||
            relativePath.startsWith(QStringLiteral("..\\")) ||
            QDir::isAbsolutePath(relativePath)) {
        return RejectedPath;
    }

    QFile file(missionFilename);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        errorString = file.errorString();
        return RejectedFormat;
    }

    QJsonDocument jsonDoc;
    QString jsonErrorString;
    const QByteArray bytes = file.readAll();
    if (!JsonHelper::isJsonFile(bytes, jsonDoc, jsonErrorString) || !jsonDoc.isObject()) {
        errorString = jsonErrorString;
        return RejectedFormat;
    }

    const QJsonObject plan = jsonDoc.object();
    if (plan.value(kFileTypeKey).toString() != QLatin1String(kPlanFileType)) {
        return RejectedFormat;
    }

    const QJsonValue missionValue = plan.value(kMissionKey);
    if (!missionValue.isObject()) {
        return RejectedFormat;
    }

    const QJsonValue itemsValue = missionValue.toObject().value(kItemsKey);
    if (!itemsValue.isArray()) {
        return RejectedFormat;
    }

    const QJsonArray items = itemsValue.toArray();
    if (items.count() > MaxWaypoints) {
        return RejectedCount;
    }

    for (const QJsonValue& itemValue: items) {
        if (!itemValue.isObject()) {
            return RejectedData;
        }

        const QJsonObject itemObject = itemValue.toObject();

        if (itemObject.contains(kLatitudeKey) || itemObject.contains(kLongitudeKey) || itemObject.contains(kAltitudeKey)) {
            double lat = 0.0;
            double lon = 0.0;
            double alt = 0.0;
            if (!doubleValueIsFinite(itemObject.value(kLatitudeKey), lat) ||
                    !doubleValueIsFinite(itemObject.value(kLongitudeKey), lon) ||
                    !doubleValueIsFinite(itemObject.value(kAltitudeKey), alt) ||
                    !coordinateValuesAreValid(lat, lon, alt)) {
                return RejectedData;
            }
        }

        const QJsonValue coordinateValue = itemObject.value(kCoordinateKey);
        if (coordinateValue.isUndefined() || coordinateValue.isNull()) {
            const QJsonValue paramsValue = itemObject.value(kParamsKey);
            if (paramsValue.isArray()) {
                const QJsonArray paramsArray = paramsValue.toArray();
                if (paramsArray.count() >= 7 && !_validateCoordinateArray(QJsonArray { paramsArray[4], paramsArray[5], paramsArray[6] })) {
                    return RejectedData;
                }
            }
            continue;
        }

        if (!coordinateValue.isArray() || !_validateCoordinateArray(coordinateValue.toArray())) {
            return RejectedData;
        }
    }

    return Accepted;
}

QString MissionFileValidator::validationResultToString(ValidationResult result)
{
    switch (result) {
    case Accepted:
        return QStringLiteral("accepted");
    case RejectedSize:
        return QStringLiteral("mission file exceeds the 10 MB size limit");
    case RejectedPath:
        return QStringLiteral("mission file is outside the configured mission directory");
    case RejectedFormat:
        return QStringLiteral("mission file format is invalid");
    case RejectedCount:
        return QStringLiteral("mission file contains more than 500 waypoints");
    case RejectedData:
        return QStringLiteral("mission file contains invalid waypoint data");
    }

    return QStringLiteral("mission file validation failed");
}

bool MissionFileValidator::_validateCoordinateArray(const QJsonArray& coordinateArray)
{
    if (coordinateArray.count() < 3) {
        return false;
    }

    double lat = 0.0;
    double lon = 0.0;
    double alt = 0.0;
    if (!doubleValueIsFinite(coordinateArray[0], lat) ||
            !doubleValueIsFinite(coordinateArray[1], lon) ||
            !doubleValueIsFinite(coordinateArray[2], alt)) {
        return false;
    }

    return coordinateValuesAreValid(lat, lon, alt);
}
