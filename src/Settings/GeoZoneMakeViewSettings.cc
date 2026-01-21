/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "GeoZoneMakeViewSettings.h"

#include <QQmlEngine>
#include <QtQml>
#include <QGeoCoordinate>
#include <QList>
#include <QPointF>
#include <QSizeF>
#include <QtMath>
#include <QtConcurrent>
#include <QFileDialog>
#include <QStandardPaths>
#include <QDateTime>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>

#include "QGroundControlQmlGlobal.h"
#include "SettingsManager.h"

// DECLARE_SETTINGGROUP(GeoZoneMakeView, "PlanView")
// {
//     qmlRegisterUncreatableType<GeoZoneMakeViewSettings>("QGroundControl.SettingsManager", 1, 0, "GeoZoneMakeViewSettings", "Reference only");

//     manager = new QNetworkAccessManager(this);
//     connect(manager, &QNetworkAccessManager::finished, this, &GeoZoneMakeViewSettings::onReplyFinished);

//     _toolbox = qgcApp()->toolbox();
//     _settingsManager = _toolbox->settingsManager();
//     qInfo() << "Start GEoZoneMakeViewSettings";

// }

QJsonDocument _latestJsonDoc;

GeoZoneMakeViewSettings::GeoZoneMakeViewSettings(QObject* parent)  // 직접 그룹명 전달
{
    qmlRegisterUncreatableType<GeoZoneMakeViewSettings>(
        "QGroundControl.SettingsManager", 1, 0, "GeoZoneMakeViewSettings", "Reference only");

    manager = new QNetworkAccessManager(this);
    connect(manager, &QNetworkAccessManager::finished, this, &GeoZoneMakeViewSettings::onReplyFinished);

    _toolbox = qgcApp()->toolbox();
    _settingsManager = _toolbox->settingsManager();

    qInfo() << "Start GeoZoneMakeViewSettings";
}

void GeoZoneMakeViewSettings::selectGeoZone(){
    qInfo() << "GeoZoneMakeViewSettings Test";

    if(_polygons.count() == 0) {
        QGCMapPolygon* polygon = new QGCMapPolygon(this);

        QGeoCoordinate mapCoord = qGroundControlQmlGlobal->flightMapPosition();

        polygon->appendVertices(defaultPolygonVertices(mapCoord, 2000, 1200));
        polygon->setTraceMode(false);

        _polygons.append(polygon);

        printPolygonSize();
    }
}

void GeoZoneMakeViewSettings::deleteGeoZone(){
    qInfo() << "Delete All Areas";

    if(_polygons.count() > 0){
        _polygons.clearAndDeleteContents();
    }
}

void GeoZoneMakeViewSettings::setVerticalSize(double targetSize)
{

    qInfo() << "Vertical Target Size = " << targetSize;
    if (_polygons.count() == 0) return;

    QGCMapPolygon* polygon = _polygons.value<QGCMapPolygon*>(0);
    if (!polygon) return;

    QList<QVariant> variantCoords = polygon->path();
    if (variantCoords.count() < 4) return;

    QList<QGeoCoordinate> coords;
    for (const QVariant& v : variantCoords) {
        coords.append(v.value<QGeoCoordinate>());
    }

    sortRectangleVertices(coords);
    double currentHeight = coords[0].distanceTo(coords[3]);            // BottomLeft → TopLeft
    double azimuth = coords[0].azimuthTo(coords[3]);                   // 실제 세로 방향 (사용자가 회전시켜도 반영됨)
    double diff = targetSize - currentHeight;

    QList<QGeoCoordinate> newCoords;
    for (int i = 0; i < coords.count(); ++i) {
        const QGeoCoordinate& coord = coords[i];

        // Top 두 점(index 2, 3)이 세로 방향일 경우만 이동
        if (i == 2 || i == 3) {
            QGeoCoordinate moved = coord.atDistanceAndAzimuth(diff, azimuth);
            newCoords.append(moved);
        } else {
            newCoords.append(coord);
        }
    }


    polygon->clear();
    for (const QGeoCoordinate& coord : newCoords) {
        polygon->appendVertex(coord);
    }
}

void GeoZoneMakeViewSettings::sortRectangleVertices(QList<QGeoCoordinate>& coords) {
    if (coords.size() != 4)
        return;

    // 중심 좌표 계산
    double avgLat = 0.0;
    double avgLon = 0.0;
    for (const QGeoCoordinate& c : coords) {
        avgLat += c.latitude();
        avgLon += c.longitude();
    }
    avgLat /= 4.0;
    avgLon /= 4.0;

    QGeoCoordinate center(avgLat, avgLon);

    // 중심 기준 각도 계산 후 정렬
    std::sort(coords.begin(), coords.end(), [center](const QGeoCoordinate& a, const QGeoCoordinate& b) {
        double angleA = atan2(a.latitude() - center.latitude(), a.longitude() - center.longitude());
        double angleB = atan2(b.latitude() - center.latitude(), b.longitude() - center.longitude());
        return angleA < angleB;  // 반시계 방향 정렬
    });
}

void GeoZoneMakeViewSettings::setHorizontalSize(double targetSize)
{
    if (_polygons.count() == 0) return;

    QGCMapPolygon* polygon = _polygons.value<QGCMapPolygon*>(0);
    if (!polygon) return;

    QList<QVariant> variantCoords = polygon->path();
    if (variantCoords.count() < 4) return;

    QList<QGeoCoordinate> coords;
    for (const QVariant& v : variantCoords) {
        coords.append(v.value<QGeoCoordinate>());
    }

    // 가로 길이 계산 (좌상단에서 우상단)

    sortRectangleVertices(coords);
    double currentWidth = coords[0].distanceTo(coords[1]);  // TopLeft → TopRight
    double azimuth = coords[0].azimuthTo(coords[1]);
    double diff = targetSize - currentWidth;

    QList<QGeoCoordinate> newCoords;
    for (int i = 0; i < coords.count(); ++i) {
        const QGeoCoordinate& coord = coords[i];
        // 오른쪽 꼭짓점(index 1, 2)이 가로 방향일 경우만 이동
        if (i == 1 || i == 2) {
            QGeoCoordinate moved = coord.atDistanceAndAzimuth(diff, azimuth);
            newCoords.append(moved);
        } else {
            newCoords.append(coord);
        }

    }

    polygon->clear();
    for (const QGeoCoordinate& coord : newCoords) {
        polygon->appendVertex(coord);
    }
}

void GeoZoneMakeViewSettings::printPolygonSize()
{
    if (_polygons.count() == 0) return;

    QGCMapPolygon* polygon = _polygons.value<QGCMapPolygon*>(0);
    if (!polygon) return;

    QList<QVariant> variantCoords = polygon->path();
    if (variantCoords.count() < 4) return;

    QList<QGeoCoordinate> coords;
    for (const QVariant& v : variantCoords) {
        coords.append(v.value<QGeoCoordinate>());
    }

    // 꼭짓점이 [TopLeft, TopRight, BottomRight, BottomLeft] 순이라고 가정
    double width = coords[0].distanceTo(coords[1]);   // TopLeft → TopRight (가로)
    double height = coords[0].distanceTo(coords[3]);  // TopLeft → BottomLeft (세로)

    setVerticalArea(height);
    setHorizontalArea(width);

    _horizontalLength = width;
    _verticalLength = height;

    qInfo() << "Polygon Size:";
    qInfo() << "  Width (m):" << width;
    qInfo() << "  Height (m):" << height;
}


QList<QGeoCoordinate> GeoZoneMakeViewSettings::defaultPolygonVertices(const QGeoCoordinate& centerCoord,
                                             double pixelWidthMeters,
                                             double pixelHeightMeters)
{
    QList<QGeoCoordinate> coords;

    // 최대 3000m 제한
    double halfWidth =  qMin(pixelWidthMeters, 3000.0) / 2.0;
    double halfHeight = qMin(pixelHeightMeters, 3000.0) / 2.0;

    // 방향 기준:
    // - 0° = 북
    // - 90° = 동
    // - 180° = 남
    // - 270° = 서

    QGeoCoordinate topLeft =
        centerCoord.atDistanceAndAzimuth(halfWidth, 270).atDistanceAndAzimuth(halfHeight, 0);
    QGeoCoordinate topRight =
        centerCoord.atDistanceAndAzimuth(halfWidth, 90).atDistanceAndAzimuth(halfHeight, 0);
    QGeoCoordinate bottomRight =
        centerCoord.atDistanceAndAzimuth(halfWidth, 90).atDistanceAndAzimuth(halfHeight, 180);
    QGeoCoordinate bottomLeft =
        centerCoord.atDistanceAndAzimuth(halfWidth, 270).atDistanceAndAzimuth(halfHeight, 180);

    qInfo() << "Top Left = " << topLeft << "Top Right = " << topRight << "Bottom Right = " << bottomRight << "Bottom Left = " << bottomLeft;

    coords << topLeft << topRight << bottomRight << bottomLeft;

    return coords;
}

void GeoZoneMakeViewSettings::adjustRectangleByVertex(int index, const QGeoCoordinate& newCoord)
{
    if (_polygons.count() == 0) return;
    QGCMapPolygon* polygon = _polygons.value<QGCMapPolygon*>(0);
    if (!polygon) return;

    QList<QVariant> variantCoords = polygon->path();
    if (variantCoords.count() != 4) return;

    QList<QGeoCoordinate> coords;
    for (const QVariant& v : variantCoords)
        coords.append(v.value<QGeoCoordinate>());

    QGeoCoordinate oldCoord = coords[index];

    // 위도/경도 차이 계산
    double latDiff = newCoord.latitude() - oldCoord.latitude();
    double lonDiff = newCoord.longitude() - oldCoord.longitude();

    QList<QGeoCoordinate> newCoords = coords;

    // index에 따라 꼭짓점 조정
    switch (index) {
    case 0: // TopLeft
        newCoords[0] = newCoord;
        newCoords[1].setLatitude(newCoords[1].latitude() + latDiff);
        newCoords[3].setLongitude(newCoords[3].longitude() + lonDiff);
        break;
    case 1: // TopRight
        newCoords[1] = newCoord;
        newCoords[0].setLatitude(newCoords[0].latitude() + latDiff);
        newCoords[2].setLongitude(newCoords[2].longitude() + lonDiff);
        break;
    case 2: // BottomRight
        newCoords[2] = newCoord;
        newCoords[3].setLatitude(newCoords[3].latitude() + latDiff);
        newCoords[1].setLongitude(newCoords[1].longitude() + lonDiff);
        break;
    case 3: // BottomLeft
        newCoords[3] = newCoord;
        newCoords[2].setLatitude(newCoords[2].latitude() + latDiff);
        newCoords[0].setLongitude(newCoords[0].longitude() + lonDiff);
        break;
    default:
        return;
    }

    // 사각형 갱신
    polygon->clear();
    for (const QGeoCoordinate& coord : newCoords)
        polygon->appendVertex(coord);
}

// void GeoZoneMakeViewSettings::downloadGeoZone(){
//     qInfo() << "Download";

//     if (_polygons.count() == 0) return;

//     for (int i = 0; i < _polygons.count(); ++i) {
//         QObject* polygonObject = _polygons[i];
//         QGCMapPolygon* polygon = qobject_cast<QGCMapPolygon*>(polygonObject);
//         if (!polygon) {
//             qWarning() << "Invalid polygon object at index" << i;
//             continue;
//         }

//         const QVariantList path = polygon->path();
//         qInfo() << "Polygon" << i << "has" << path.count() << "vertices:";

//         for (int j = 0; j < path.count(); ++j) {
//             QGeoCoordinate coord = path[j].value<QGeoCoordinate>();
//             qInfo() << QString("  [%1] lat: %2, lon: %3, alt: %4")
//                            .arg(j)
//                            .arg(coord.latitude(), 0, 'f', 8)
//                            .arg(coord.longitude(), 0, 'f', 8)
//                            .arg(coord.altitude(), 0, 'f', 2);
//         }
//     }

//     //1. 온라인에서 데이터 가져오기
//     //2. 가져온 데이터정보를 Json 형식으로 바꾸기
//     //3. Json 형식의 데이터를 파일로 저장하기

//     sendGeoZoneRequest(1,1,1,1);
// }

void GeoZoneMakeViewSettings::downloadGeoZone(){
    qInfo() << "Download";

    if (_polygons.count() == 0) return;

    double north = -90.0;
    double south = 90.0;
    double east = -180.0;
    double west = 180.0;

    for (int i = 0; i < _polygons.count(); ++i) {
        QObject* polygonObject = _polygons[i];
        QGCMapPolygon* polygon = qobject_cast<QGCMapPolygon*>(polygonObject);
        if (!polygon) {
            qWarning() << "Invalid polygon object at index" << i;
            continue;
        }

        const QVariantList path = polygon->path();
        qInfo() << "Polygon" << i << "has" << path.count() << "vertices:";

        for (int j = 0; j < path.count(); ++j) {
            QGeoCoordinate coord = path[j].value<QGeoCoordinate>();
            double lat = coord.latitude();
            double lon = coord.longitude();

            // 로그 출력
            qInfo() << QString("  [%1] lat: %2, lon: %3, alt: %4")
                           .arg(j)
                           .arg(lat, 0, 'f', 8)
                           .arg(lon, 0, 'f', 8)
                           .arg(coord.altitude(), 0, 'f', 2);

            // 최댓값/최솟값 갱신
            if (lat > north) north = lat;
            if (lat < south) south = lat;
            if (lon > east)  east  = lon;
            if (lon < west)  west  = lon;
        }
    }

    qInfo() << QString("Bounding box -> N: %1, E: %2, S: %3, W: %4")
                   .arg(north).arg(east).arg(south).arg(west);

    // 1. 온라인에서 데이터 가져오기
    // 2. 가져온 데이터정보를 Json 형식으로 바꾸기
    // 3. Json 형식의 데이터를 파일로 저장하기

    sendGeoZoneRequest(north, east, south, west);
}

void GeoZoneMakeViewSettings::onReplyFinished(QNetworkReply *reply){
    if (reply->error() == QNetworkReply::NoError) {
        QByteArray responseData = reply->readAll();
        QJsonDocument jsonDoc = QJsonDocument::fromJson(responseData);

        if (!jsonDoc.isNull()) {
            QtConcurrent::run([=]() {
                try {
                    saveGeoZoneFile(jsonDoc);
                }
                catch(const std::exception& e) {
                    qWarning() << "Exception in onReplyFinished QtConcurrent::run:" << e.what();
                } catch (...) {
                    qWarning() << "Unknown exception onReplyFinished in QtConcurrent::run";
                }
                //processJsonFile(jsonDoc);
            });
        }
    }
    reply->deleteLater();
}

void GeoZoneMakeViewSettings::sendGeoZoneRequest(double n, double e, double s, double w){
    QString onlineUrl = _settingsManager->flyViewSettings()->onlinePath()->rawValueString();
    QString onlineLicenseKey = _settingsManager->flyViewSettings()->onlineLicenseKey()->rawValueString();
    QString authorizationHeader = "X-AA-ApiKey " + onlineLicenseKey;
    QUrl fullUrl(onlineUrl);

    QUrlQuery query;
    query.addQueryItem("n", QString::number(n)); // 북쪽 위도
    query.addQueryItem("e", QString::number(e)); // 동쪽 경도
    query.addQueryItem("s", QString::number(s)); // 남쪽 위도
    query.addQueryItem("w", QString::number(w)); // 서쪽 경도
    fullUrl.setQuery(query);

    QNetworkRequest request(fullUrl);

    // Add headers
    request.setRawHeader("Authorization", authorizationHeader.toUtf8());
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    // Send GET request
    manager->get(request);

}

// void GeoZoneMakeViewSettings::saveGeoZoneFile(const QJsonDocument& jsonDoc){

//     const QJsonArray features = jsonDoc["features"].toArray();
//     for (const QJsonValue& featureVal : features){
//         const QJsonObject feature = featureVal.toObject();
//         const QJsonObject geometry = feature["geometry"].toObject();
//         const QString type = geometry["type"].toString();
//         const QString id = feature["id"].toString();
//         QJsonObject properties = feature.value("properties").toObject();
//         QString strokeColor = properties.value("strokeColor").toString();
//         QString strokeOpacity = properties.value("strokeOpacity").toString();
//         QString category = properties.value("category").toString();

//         QJsonObject altitudeCeiling = properties.value("altitudeCeiling").toObject();
//         double ceilingMeters = altitudeCeiling.value("meters").toDouble();
//         QJsonObject altitudeFloor = properties.value("altitudeFloor").toObject();
//         double floorMeters = altitudeFloor.value("meters").toDouble();

//         if (type == "Polygon") {
//             if(category == "airspace") continue;
//             if (ceilingMeters > 500) continue;

//             QJsonArray coordinates = geometry["coordinates"].toArray();
//             QList<QGeoCoordinate> polygon;
//             for (const QJsonValue& ringVal : coordinates) {
//                 QJsonArray ring = ringVal.toArray();
//                 for (const QJsonValue& coordVal : ring) {
//                     QJsonArray coordPair = coordVal.toArray();
//                     double lon = coordPair[0].toDouble();
//                     double lat = coordPair[1].toDouble();
//                     polygon.append(QGeoCoordinate(lat, lon));
//                 }
//             }

//             qInfo() << "category = " << category;
//             qInfo() << "strokeColor = " << strokeColor;
//             qInfo() << "strokeOpacity = " << strokeOpacity;
//             qInfo() << "ceilingMeters = " << ceilingMeters;
//             qInfo() << "floorMeters = " << floorMeters;

//             for(QGeoCoordinate coordsss : polygon){
//                 qInfo() << "COords  lat = " << coordsss.latitude() << "lon = " << coordsss.longitude();
//             }
//         }
//     }
// }
void GeoZoneMakeViewSettings::saveGeoZoneFile(const QJsonDocument& jsonDoc) {
    QJsonArray newFeatures;
    int idCounter = 0;

    const QJsonArray features = jsonDoc["features"].toArray();
    QDateTime now = QDateTime::currentDateTime();
    QString validFromLocal = now.toString("yyyy-MM-dd HH:mm:ss");
    QString validToLocal = now.addYears(1).toString("yyyy-MM-dd HH:mm:ss");
    for (const QJsonValue& featureVal : features){
        const QJsonObject feature = featureVal.toObject();
        const QJsonObject geometry = feature["geometry"].toObject();
        const QString type = geometry["type"].toString();
        QJsonObject properties = feature["properties"].toObject();
        // 유효 시간 표시
        QJsonObject airac = properties.value("airac").toObject();
        QString operationalFrom = airac.value("from").toString();
        QString operationalTo = airac.value("to").toString();
        QDateTime validFrom = QDateTime::fromString(operationalFrom, "yyyy-MM-dd");
        QDateTime validTo = QDateTime::fromString(operationalTo, "yyyy-MM-dd");

        if (type != "Polygon")
            continue;

        QString category = properties.value("category").toString();
        if (category == "airspace")
            continue;

        QJsonObject altitudeCeiling = properties.value("altitudeCeiling").toObject();
        double ceilingMeters = altitudeCeiling.value("meters").toDouble();
        if (ceilingMeters > 500)
            continue;

        QJsonObject altitudeFloor = properties.value("altitudeFloor").toObject();
        double floorMeters = altitudeFloor.value("meters").toDouble();

        // 좌표 파싱
        QJsonArray coordinates = geometry["coordinates"].toArray();
        QJsonArray outerArray;

        for (const QJsonValue& ringVal : coordinates) {
            QJsonArray ring = ringVal.toArray();
            QJsonArray ringArray;
            for (const QJsonValue& coordVal : ring) {
                QJsonArray coordPair = coordVal.toArray();
                double lon = coordPair[0].toDouble();
                double lat = coordPair[1].toDouble();
                QJsonArray point;
                point.append(lon);
                point.append(lat);
                ringArray.append(point);
            }
            outerArray.append(ringArray);
        }

        // 새 feature 객체 생성
        QJsonObject newFeature;
        newFeature["type"] = "Feature";
        newFeature["id"] = idCounter++;

        // 새 properties
        QJsonObject newProperties;
        newProperties["zone_type"] = "Restricted";
        if(validFrom.toString() == "" && validTo.toString() == "") {
            newProperties["valid_from"] = validFromLocal;
            newProperties["valid_to"] = validToLocal;
        }
        else {
            newProperties["valid_from"] = validFrom.toString();//"2025-02-10 16:50:00";
            newProperties["valid_to"] = validTo.toString();//"2025-05-10 17:40:00";
        }
        newProperties["altitudeFloor"] = floorMeters;
        newProperties["altitudeCeiling"] = ceilingMeters;
        newFeature["properties"] = newProperties;

        // geometry
        QJsonObject newGeometry;
        newGeometry["type"] = "Polygon";
        newGeometry["coordinates"] = outerArray;
        newFeature["geometry"] = newGeometry;

        newFeatures.append(newFeature);
    }

    // 최종 FeatureCollection 생성
    QJsonObject finalJson;
    QString createdAt = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss");
    finalJson["created_at"] = createdAt;

    finalJson["type"] = "FeatureCollection";
    finalJson["features"] = newFeatures;

    QJsonDocument outputDoc(finalJson);    
    _latestJsonDoc = outputDoc;

}

// void GeoZoneMakeViewSettings::getDownloadPath(QString filePath) {
//     qInfo() << "Download Path = " << filePath;
//     QFile file(QUrl(filePath).toLocalFile());
//     if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
//         file.write(_latestJsonDoc.toJson(QJsonDocument::Indented));
//         file.close();
//         qInfo() << "Saved to:" << filePath;
//     } else {
//         qWarning() << "File open failed:" << filePath;
//     }
// }

void GeoZoneMakeViewSettings::getDownloadPath(QString filePath) {
    qInfo() << "Download Path (raw): " << filePath;
    QString localFilePath = filePath;
    // file:/// 형식이면 제거
    if (filePath.startsWith("file://"))
        localFilePath = QUrl(filePath).toLocalFile();

    qInfo() << "Local file path: " << localFilePath;

    // QFile file(localFilePath);
    // if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
    //     file.write(_latestJsonDoc.toJson(QJsonDocument::Indented));
    //     file.close();
    //     qInfo() << "Saved to:" << localFilePath;
    // } else {
    //     qWarning() << "File open failed:" << localFilePath << "Error:" << file.errorString();
    // }
    QFile file(filePath);
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        file.write(_latestJsonDoc.toJson(QJsonDocument::Indented));
        file.close();
        qInfo() << "Saved to:" << filePath;
    } else {
        qWarning() << "File open failed:" << filePath;
    }
}


void GeoZoneMakeViewSettings::openSaveFileDialogAndSaveJson(const QJsonDocument& jsonDoc)
{

#ifdef Q_OS_ANDROID
#else
    QMetaObject::invokeMethod(this, [=]() {
        QString defaultFileName = QString("GeoZone_%1.geojson")
        .arg(QDateTime::currentDateTime().toString("yyyyMMdd_hhmmss"));

        QString defaultPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation)
                              + "/" + defaultFileName;

        QString selectedFile = QFileDialog::getSaveFileName(
            nullptr,
            "Save GeoZone File",
            defaultPath,
            "JSON Files (*.json);;All Files (*)"
            );

        if (!selectedFile.isEmpty()) {
            QFile file(selectedFile);
            if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
                file.write(jsonDoc.toJson(QJsonDocument::Indented));
                file.close();
                qInfo() << "Saved to:" << selectedFile;
            } else {
                qWarning() << "File open failed:" << selectedFile;
            }
        }
    }, Qt::QueuedConnection);
#endif
}

void GeoZoneMakeViewSettings::saveToFile(const QString& filename)
{
    if (filename.isEmpty()) {
        return;
    }

    QString planFilename = filename;
    if (!QFileInfo(filename).fileName().contains(".")) {
        planFilename += QString(".%1").arg(fileExtension());
    }

    QFile file(planFilename);

    if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        qgcApp()->showAppMessage(tr("GeoZOne save error %1 : %2").arg(filename).arg(file.errorString()));
        _currentGeoZoneFile.clear();
        emit currentGeoZoneChanged();
    } else {
        QJsonDocument saveDoc = _latestJsonDoc; //.toJson(QJsonDocument::Indented);
        file.write(saveDoc.toJson());
        if(_currentGeoZoneFile != planFilename) {
            _currentGeoZoneFile = planFilename;
            emit currentGeoZoneChanged();

            qInfo() << "currentGeoZone File = " << _currentGeoZoneFile;
        }
    }
}

QString GeoZoneMakeViewSettings::fileExtension(void) const
{
    return AppSettings::geoZoneExtension;
}

void GeoZoneMakeViewSettings::loadFromFile(const QString& filename){
    QString errorString;
    QString errorMessage = tr("Error loading Plan file (%1). %2").arg(filename).arg("%1");

    if (filename.isEmpty()) {
        return;
    }

    QFileInfo fileInfo(filename);
    QFile file(filename);

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        errorString = file.errorString() + QStringLiteral(" ") + filename;
        qgcApp()->showAppMessage(errorMessage.arg(errorString));
        return;
    }

    qInfo() << "loadFromFile file name = " << filename;

    _settingsManager->flyViewSettings()->setFilePathRawValue(filename);

    qInfo() << "Load File last modified = " << fileInfo.lastModified() ;

    qInfo() << "GeoZone folder Location = " << _settingsManager->appSettings()->geoZoneSavePath();
}

QStringList GeoZoneMakeViewSettings::saveNameFilters(void) const
{
    QStringList filters;

    filters << tr("GeoZone Files (*.%1)").arg(fileExtension()) << tr("All Files (*)");
    return filters;
}

QStringList GeoZoneMakeViewSettings::loadNameFilters(void) const
{
    QStringList filters;

    filters << tr("Supported types (*.%1)").arg(AppSettings::geoZoneExtension)
            << tr("JSON Files (*.json)")
            << tr("All Files (*)");

    return filters;
}




