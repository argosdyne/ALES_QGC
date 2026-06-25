/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QString>

class QJsonArray;

class MissionFileValidator
{
public:
    enum ValidationResult {
        Accepted,
        RejectedSize,
        RejectedPath,
        RejectedFormat,
        RejectedCount,
        RejectedData,
    };

    static constexpr int    MaxFileSizeMB = 10;
    static constexpr int    MaxWaypoints = 500;
    static constexpr double MaxAltitudeMeters = 500.0;

    static ValidationResult validate(const QString& missionFilename, const QString& missionBasePath, QString& errorString);
    static QString validationResultToString(ValidationResult result);

private:
    static bool _validateCoordinateArray(const QJsonArray& coordinateArray);
};
