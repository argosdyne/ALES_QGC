#include "FlightZoneManager.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QObject>
#include <QFile>
#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QList>
#include <QDateTime>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QUrl>
#include <QSet>
#include <QRectF>
#include <QStandardPaths>
#include <QTextStream>
#include <QFile>
#include <QPolygonF>
#include <climits>
#include <memory>
#include <QVariantMap>
#include "SettingsManager.h"
#include <QJsonParseError>
#include <QFileInfo>

#include "JsonHelper.h"
#include "FlyViewSettings.h"
#include "QGCApplication.h"
#include "GeoFenceController.h"
#include <QLineF>
#include "QGCFenceCircle.h"
#include "QGCFencePolygon.h"
#include "QGCCorePlugin.h"
#include "AudioOutput.h"
#include "QGroundControlQmlGlobal.h"
#include "Vehicle.h"
#include "MultiVehicleManager.h"
#include "QGCMapEngine.h"
#include "QmlObjectListModel.h"
#include <QQuickWindow>
#include <QScreen>

#include <CGAL/Simple_cartesian.h>
#include <CGAL/Polyhedron_3.h>
#include <CGAL/AABB_tree.h>
#include <CGAL/AABB_traits_3.h>
#include <CGAL/AABB_face_graph_triangle_primitive.h>
#include <iostream>

// AQGC Simple UI: zone name / class / details for the Simple map legend, zone details and warnings.
// ED-318 / ED-269: properties.restriction (PROHIBITED, REQ_AUTHORISATION, CONDITIONAL, NO_RESTRICTION) and name.
// Altitude Angel: properties.category / detailedCategory / name. Unknown = information (3).
static int aqgcZoneClass(const QJsonObject& props)
{
    const QString r = props.value("restriction").toString().toUpper();
    if (r.contains("PROHIBIT")) return 1;
    if (r.contains("AUTHORI") || r.contains("CONDITIONAL")) return 2;
    if (r.contains("NO_RESTRICTION")) return 3;
    const QString c = (props.value("category").toString() + " " + props.value("detailedCategory").toString()
                       + " " + props.value("type").toString()).toLower();
    if (c.contains("prohibit") || c.contains("no-fly") || c.contains("nofly") || c.contains("forbidden")) return 1;
    if (c.contains("restrict") || c.contains("controlled") || c.contains("airport") || c.contains("aerodrome")
            || c.contains("danger") || c.contains("military") || c.contains("ctr") || c.contains("atz")) return 2;
    return 3;
}
static void aqgcSetZoneInfo(QObject* shape, const QJsonObject& props, const QString& id)
{
    if (!shape) return;
    QString name = props.value("name").toString();
    if (name.isEmpty()) name = props.value("Name").toString();
    if (name.isEmpty()) name = props.value("title").toString();
    if (name.isEmpty()) name = id;
    QStringList detail;
    const QString authority = props.value("zoneAuthority").isArray()
            ? props.value("zoneAuthority").toArray().at(0).toObject().value("name").toString()
            : props.value("authority").toString();
    if (!authority.isEmpty()) detail << authority;
    const QString reason = props.value("reason").isArray()
            ? props.value("reason").toArray().at(0).toString() : props.value("reason").toString();
    if (!reason.isEmpty()) detail << reason;
    const QString category = props.value("detailedCategory").toString().isEmpty()
            ? props.value("category").toString() : props.value("detailedCategory").toString();
    if (!category.isEmpty()) detail << category;
    shape->setProperty("zoneName",   name);
    shape->setProperty("zoneClass",  aqgcZoneClass(props));
    shape->setProperty("zoneDetail", detail.join(QStringLiteral(" · ")));
}
#include <fstream>
#include <cmath>
#include <QDir>

#include "CustomQmlInterface.h"
#include "AppSettings.h"

//new Add Function
#include <CGAL/Polyhedron_incremental_builder_3.h>
#include <CGAL/Side_of_triangle_mesh.h>
#include <vector>

#include <CGAL/Delaunay_triangulation_3.h>
#include <QtConcurrent>

#include <QReadWriteLock>
#include <CGAL/Triangle_3.h>


QGC_LOGGING_CATEGORY(FlightZoneManagerLog, "FlightZoneManagerLog")


typedef CGAL::Simple_cartesian<double> Kernel;
typedef Kernel::Point_3 Point_3;
typedef CGAL::Polyhedron_3<Kernel> Polyhedron;
typedef CGAL::AABB_face_graph_triangle_primitive<Polyhedron> Primitive;
typedef CGAL::AABB_traits_3<Kernel, Primitive> AABB_traits;
typedef CGAL::AABB_tree<AABB_traits> AABB_tree;

typedef CGAL::Side_of_triangle_mesh<Polyhedron, Kernel> Point_inside;

typedef CGAL::Delaunay_triangulation_3<Kernel> Delaunay;

typedef Kernel::Triangle_3 Triangle_3;

// 지구 둘레 (미터)
double EarthCircumference = 40075017.0;
QGeoCoordinate geoCoordinate;
QList<FlightValidTime> validTimeList;
QList<GeoJsonNameList> geoJsonNameList;


QList<Polyhedron> _noFlyZoneList;
// AQGC Simple UI: name and class of each entry in _noFlyZoneList (same order; empty / 0 when unknown)
QList<AqgcZoneMeta> _noFlyZoneMeta;
//QList<AABB_tree> _AABBZoneList;

QReadWriteLock _zoneLock; // 클래스 멤버로 선언

struct GeoZone {
    Polyhedron polyhedron;
    std::shared_ptr<AABB_tree> tree; // 캐시된 트리
};

QList<GeoZone> _geoZoneList;  // _noFlyZoneList 대체

std::vector<Triangle_3> _zoneTriangles;
std::vector<std::shared_ptr<AABB_tree>> _zoneAABBTree;

//모든 그룹
QList<QList<NoFlyZone>> allNoFlyZones;

// Forward declarations for geometry helpers
static QRectF boundingRectFor(const QList<QGeoCoordinate>& verts);
static double rectArea(const QRectF& r);
static double rectIntersectionArea(const QRectF& a, const QRectF& b);

static void buildZoneTrees(const QList<Polyhedron>& src, std::vector<std::shared_ptr<AABB_tree>>& dst)
{
    dst.clear();
    dst.reserve(src.size());
    for (const auto& poly : src) {
        if (poly.empty()) {
            continue;
        }
        auto range = faces(poly);
        auto tree = std::make_shared<AABB_tree>(range.begin(), range.end(), poly);
        tree->accelerate_distance_queries();
        dst.push_back(tree);
    }
}

// static QString resolveLogsDir(SettingsManager* settings)
// {
//     QString logsDir = settings && settings->appSettings() ? settings->appSettings()->logSavePath() : QString();
//     if (logsDir.isEmpty()) {
//         logsDir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) + "/Ales QGC Daily/Logs";
//     }
//     return logsDir;
// }

// --- Douglas–Peucker simplify helpers ---
// Return true if candidate polygon lies entirely inside any polygon in existing
static bool isZoneDuplicate(const QList<QGeoCoordinate>& candidate, const QList<QList<QGeoCoordinate>>& existing)
{
    if (candidate.size() < 3) {
        return false;
    }
    QPolygonF candPoly;
    candPoly.reserve(candidate.size());
    for (const auto& c : candidate) {
        candPoly << QPointF(c.longitude(), c.latitude());
    }
    const QRectF candRect = candPoly.boundingRect();

    for (const auto& verts : existing) {
        if (verts.size() < 3) {
            continue;
        }
        QPolygonF otherPoly;
        otherPoly.reserve(verts.size());
        for (const auto& c : verts) {
            otherPoly << QPointF(c.longitude(), c.latitude());
        }
        if (!otherPoly.boundingRect().contains(candRect)) {
            continue;
        }
        bool allInside = true;
        for (const QPointF& p : candPoly) {
            if (!otherPoly.containsPoint(p, Qt::OddEvenFill)) {
                allInside = false;
                break;
            }
        }
        if (allInside) {
            return true;
        }
    }
    return false;
}

// Rough overlap check: if bounding boxes overlap >80% of the smaller one, treat as mostly duplicate
static bool isZoneMostlyDuplicate(const QList<QGeoCoordinate>& candidate, const QList<QList<QGeoCoordinate>>& existing)
{
    if (candidate.size() < 3) {
        return false;
    }
    const QRectF candRect = boundingRectFor(candidate);
    const double candArea = rectArea(candRect);
    if (candArea <= 0.0) {
        return false;
    }

    for (const auto& verts : existing) {
        if (verts.size() < 3) {
            continue;
        }
        const QRectF otherRect = boundingRectFor(verts);
        const double otherArea = rectArea(otherRect);
        if (otherArea <= 0.0) {
            continue;
        }
        const double inter = rectIntersectionArea(candRect, otherRect);
        const double overlap = inter / std::min(candArea, otherArea);
        if (overlap > 0.8) {
            return true;
        }
    }
    return false;
}

// Douglas–Peucker simplification; toleranceMeters is max allowed deviation
static QList<QGeoCoordinate> decimateVertices(const QList<QGeoCoordinate>& in, int maxPoints, double toleranceMeters = 5.0)
{
    if (maxPoints <= 0 || in.size() <= maxPoints) {
        return in;
    }

    // If toleranceMeters <= 0, fall back to uniform sampling
    if (toleranceMeters <= 0.0) {
        QList<QGeoCoordinate> out;
        out.reserve(maxPoints);
        const double step = static_cast<double>(in.size() - 1) / static_cast<double>(maxPoints - 1);
        for (int i = 0; i < maxPoints; ++i) {
            int idx = static_cast<int>(std::round(i * step));
            if (idx >= in.size()) {
                idx = in.size() - 1;
            }
            out.append(in.at(idx));
        }
        return out;
    }

    // DP implementation using local ENU projection around first point
    const double lat0 = qDegreesToRadians(in.first().latitude());
    auto toXY = [lat0](const QGeoCoordinate& c) {
        const double x = qDegreesToRadians(c.longitude()) * cos(lat0) * 6371000.0;
        const double y = qDegreesToRadians(c.latitude()) * 6371000.0;
        return QPointF(x, y);
    };

    const int n = in.size();
    QVector<QPointF> pts;
    pts.reserve(n);
    for (const auto& c : in) {
        pts.append(toXY(c));
    }

    QVector<bool> keep(n, false);
    keep[0] = keep[n - 1] = true;

    struct Seg { int s; int e; };
    QVector<Seg> stack;
    stack.append({0, n - 1});

    auto perpDist = [&](const QPointF& p, const QPointF& a, const QPointF& b) -> double {
        const QPointF ab = b - a;
        const double abLen2 = QPointF::dotProduct(ab, ab);
        double t = 0.0;
        if (abLen2 > 0.0) {
            t = QPointF::dotProduct(p - a, ab) / abLen2;
            t = std::clamp(t, 0.0, 1.0);
        }
        const QPointF proj = a + ab * t;
        const QPointF diff = p - proj;
        return std::sqrt(QPointF::dotProduct(diff, diff));
    };

    while (!stack.isEmpty()) {
        Seg seg = stack.back();
        stack.pop_back();
        double maxD = 0.0;
        int idx = -1;
        for (int i = seg.s + 1; i < seg.e; ++i) {
            double d = perpDist(pts[i], pts[seg.s], pts[seg.e]);
            if (d > maxD) {
                maxD = d;
                idx = i;
            }
        }
        if (idx >= 0 && maxD > toleranceMeters) {
            keep[idx] = true;
            stack.append({seg.s, idx});
            stack.append({idx, seg.e});
        }
    }

    QList<QGeoCoordinate> simplified;
    simplified.reserve(n);
    for (int i = 0; i < n; ++i) {
        if (keep[i]) {
            simplified.append(in[i]);
        }
    }

    // If still too many points, fallback to uniform sampling
    if (simplified.size() > maxPoints) {
        QList<QGeoCoordinate> out;
        out.reserve(maxPoints);
        const double step = static_cast<double>(simplified.size() - 1) / static_cast<double>(maxPoints - 1);
        for (int i = 0; i < maxPoints; ++i) {
            int idx = static_cast<int>(std::round(i * step));
            if (idx >= simplified.size()) idx = simplified.size() - 1;
            out.append(simplified.at(idx));
        }
        return out;
    }
    return simplified;
}

static QRectF boundingRectFor(const QList<QGeoCoordinate>& verts)
{
    if (verts.isEmpty()) {
        return QRectF();
    }
    double minLon = verts.first().longitude();
    double maxLon = minLon;
    double minLat = verts.first().latitude();
    double maxLat = minLat;

    for (const auto& v : verts) {
        minLon = std::min(minLon, v.longitude());
        maxLon = std::max(maxLon, v.longitude());
        minLat = std::min(minLat, v.latitude());
        maxLat = std::max(maxLat, v.latitude());
    }
    return QRectF(QPointF(minLon, minLat), QPointF(maxLon, maxLat));
}

static double rectArea(const QRectF& r)
{
    return std::abs(r.width() * r.height());
}

static double rectIntersectionArea(const QRectF& a, const QRectF& b)
{
    QRectF inter = a.intersected(b);
    if (inter.isNull()) {
        return 0.0;
    }
    return rectArea(inter);
}

FlightZoneManager::FlightZoneManager() : manager(new QNetworkAccessManager(this))
{
    qInfo(FlightZoneManagerLog) << "FlightZoneManager Start";
    // 0 = USB, 1 = Online

    _toolbox = qgcApp()->toolbox();
    _settingsManager = _toolbox->settingsManager();

    //24시간 지나면 파일 자동삭제하는 부분
    autoDeleteUSBFile();

    // connect(&_timer, &QTimer::timeout, this, &FlightZoneManager::updatePolygonVisibility);
    // _timer.start(1000);

    connect(manager, &QNetworkAccessManager::finished, this, &FlightZoneManager::onReplyFinished);
    //Start Read GeoJson data from internet

    //Check Zoom Value
    connect(&_zoomTimer, &QTimer::timeout, this, &FlightZoneManager::checkCurrentZoomValue);
    _zoomTimer.start(1000);

    geoCoordinate = qGroundControlQmlGlobal->flightMapPosition();

    qInfo(FlightZoneManagerLog) << "init flightmapPos = " << qGroundControlQmlGlobal->flightMapPosition().latitude() << "," << qGroundControlQmlGlobal->flightMapPosition().longitude();
    qInfo(FlightZoneManagerLog) << "init geoCoord = " << geoCoordinate.latitude() << "," << geoCoordinate.longitude();


    connect(&_distanceTimer, &QTimer::timeout, this, [this]() {
        MultiVehicleManager* manager = qgcApp()->toolbox()->multiVehicleManager();
        if (!manager || !manager->activeVehicle()) return;

        double droneLat = manager->activeVehicle()->latitude();
        double droneLon = manager->activeVehicle()->longitude();
        double droneAlt = manager->activeVehicle()->altitudeRelative()->rawValue().toDouble();

        double alarmDistance = _settingsManager->flyViewSettings()->alarmDistance()->rawValue().toDouble();

        QList<Polyhedron> noFlyZones;
        QList<AqgcZoneMeta> zoneMeta;
        {
            QReadLocker locker(&_zoneLock);     // both lists from the same reload (AQGC: index-based name / class)
            noFlyZones = _noFlyZoneList;
            zoneMeta = _noFlyZoneMeta;        // Polyhedron 리스트 복사
        }

        // 백그라운드에서 거리 계산
        QtConcurrent::run([=]() {
            try {
                checkDroneAndGeoZoneSafe(noFlyZones, zoneMeta, droneLat, droneLon, droneAlt, alarmDistance);
            }catch (const std::exception& e) {
                qWarning() << "Exception in checkDroneAndGeoZoneSafe QtConcurrent::run:" << e.what();
            } catch (...) {
                qWarning() << "Unknown exception in checkDroneAndGeoZoneSafe QtConcurrent::run";
            }
        });
    });


    MultiVehicleManager* manager = qgcApp()->toolbox()->multiVehicleManager();
    connect(manager, &MultiVehicleManager::activeVehicleChanged, this, [this]() {
        Vehicle* vehicle = qgcApp()->toolbox()->multiVehicleManager()->activeVehicle();
        if (!vehicle)
            return;

        if (!_distanceTimer.isActive()) {
            qInfo(FlightZoneManagerLog) << "Starting _distanceTimer after Vehicle connected.";
            _distanceTimer.start(1000);
        }
    });

    //시작시 한번 호출

    QTimer::singleShot(10000, this, [=]() { // 테스트용으로 10초 딜레이
        start();
    });
    //    start();

    // Cap map tile memory cache to reduce RAM
    getQGCMapEngine()->setMaxMemCache(64); // MB

    setReduceVerticesEnabled(false);
}

void FlightZoneManager::autoDeleteUSBFile()
{
    qInfo() << "AutoDelete USB File";

    QString rootPath = _settingsManager->appSettings()->geoZoneSavePath();
    QDir rootDir(rootPath);

    if (!rootDir.exists()) {
        qWarning() << "폴더가 존재하지 않습니다:" << rootPath;
        return;
    }

    // 검사 대상 폴더 목록 (화이트리스트)
    const QSet<QString> targetDirs = {
        "Custom"
    };

    QDateTime currentTime = QDateTime::currentDateTime();

    QFileInfoList subDirs = rootDir.entryInfoList(
        QDir::Dirs | QDir::NoDotAndDotDot
        );

    for (const QFileInfo& dirInfo : subDirs) {

        const QString dirName = dirInfo.fileName();

        // 대상 폴더가 아니면 스킵
        if (!targetDirs.contains(dirName)) {
            qInfo() << "스킵됨 (대상 아님):" << dirName;
            continue;
        }

        QDir subDir(dirInfo.absoluteFilePath());
        qInfo() << "검사 중 폴더:" << subDir.absolutePath();

        QFileInfoList files = subDir.entryInfoList(QDir::Files | QDir::NoSymLinks);

        for (const QFileInfo& fileInfo : files) {
            qint64 diffSecs = fileInfo.lastModified().secsTo(currentTime);

            if (diffSecs >= 86400) {
                if (QFile::remove(fileInfo.absoluteFilePath())) {
                    qInfo() << "삭제됨:" << fileInfo.fileName();
                } else {
                    qWarning() << "삭제 실패:" << fileInfo.fileName();
                }
            }
        }
    }
}

void FlightZoneManager::onReplyFinished(QNetworkReply *reply) {
    if (reply->error() == QNetworkReply::NoError) {
        QByteArray responseData = reply->readAll();
        QJsonDocument jsonDoc = QJsonDocument::fromJson(responseData);

        if (!jsonDoc.isNull()) {
            _setZoneError(QString());
            QtConcurrent::run([=]() {
                try {
                }
                catch(const std::exception& e) {
                    qWarning() << "Exception in onReplyFinished QtConcurrent::run:" << e.what();
                } catch (...) {
                    qWarning() << "Unknown exception onReplyFinished in QtConcurrent::run";
                }
                processJsonFile(jsonDoc);
            });
        } else {
            _setZoneError(tr("The zone server sent data that cannot be read."));
            QString msg = tr("Cannot access GeoZone data.<br>Please check local files or internet connection.");
            CustomQmlInterface::instance()->geoAwarenessMessage(msg);
        }
    } else {
        // AQGC Simple UI shows this in Settings > Map & flight zones (the classic message box is not used there)
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        _setZoneError(http == 401 || http == 403 ? tr("The zone server refused the API key.")
                                                 : tr("Zones cannot be downloaded: %1").arg(reply->errorString()));
        QString msg = tr("Cannot access GeoZone data.<br>Please check local files or internet connection.");
        CustomQmlInterface::instance()->geoAwarenessMessage(msg);
    }
    reply->deleteLater();
}



// Helper 함수: 위경고도와 고도를 Cartesian 좌표로 변환
Point_3 latLonAltToCartesian(double lat, double lon, double alt) {
    constexpr double earthRadius = 6371000.0; // 평균 지구 반지름 (미터)
    double radLat = lat * M_PI / 180.0;
    double radLon = lon * M_PI / 180.0;
    double x = (earthRadius + alt) * cos(radLat) * cos(radLon);
    double y = (earthRadius + alt) * cos(radLat) * sin(radLon);
    double z = (earthRadius + alt) * sin(radLat);
    return Point_3(x, y, z);
}

// Polyhedron 내부 확인 및 로그 출력
bool checkPointInsidePolyhedron(const Polyhedron& polyhedron, const Point_3& point) {

    bool ret = false;
    try {

        Point_inside inside(polyhedron);
        if (inside(point) == CGAL::ON_BOUNDED_SIDE) {
            ret = true;
            //qInfo() << "The point is inside the polyhedron.";
        } else {
            ret = false;
            //qInfo() << "The point is outside the polyhedron.";
        }
        return ret;
    }
    catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return ret;
    }
}

void createPolyhedron(const std::vector<Point_3>& vertices, Polyhedron& polyhedron) {
    if (vertices.size() < 8 || vertices.size() % 2 != 0) {
        throw std::runtime_error("Vertices must be even and at least 8 to form a closed polyhedron.");
    }

    CGAL::Polyhedron_incremental_builder_3<Polyhedron::HalfedgeDS> builder(polyhedron.hds(), true);
    builder.begin_surface(vertices.size(), vertices.size());

    std::vector<size_t> v_indices;

    // 정점 추가
    for (size_t i = 0; i < vertices.size(); ++i) {
        builder.add_vertex(vertices[i]);
        v_indices.push_back(i);
    }

    size_t half_size = vertices.size() / 2;

    // ?? 윗면 (삼각형으로 구성)
    for (size_t i = 1; i < half_size - 1; ++i) {
        builder.begin_facet();
        builder.add_vertex_to_facet(v_indices[0]);
        builder.add_vertex_to_facet(v_indices[i + 1]);
        builder.add_vertex_to_facet(v_indices[i]);
        builder.end_facet();
    }

    // ?? 아랫면 (삼각형으로 구성)
    for (size_t i = 1; i < half_size - 1; ++i) {
        builder.begin_facet();
        builder.add_vertex_to_facet(v_indices[half_size]);
        builder.add_vertex_to_facet(v_indices[half_size + i]);
        builder.add_vertex_to_facet(v_indices[half_size + i + 1]);
        builder.end_facet();
    }

    // ?? 측면 (각 변을 두 개의 삼각형으로 구성)
    for (size_t i = 0; i < half_size; ++i) {
        size_t next = (i + 1) % half_size;

        // // 삼각형 1
        builder.begin_facet();
        builder.add_vertex_to_facet(v_indices[i]);
        builder.add_vertex_to_facet(v_indices[next]);
        builder.add_vertex_to_facet(v_indices[next + half_size]);
        builder.end_facet();

        // 삼각형 2
        builder.begin_facet();
        builder.add_vertex_to_facet(v_indices[i]);
        builder.add_vertex_to_facet(v_indices[next + half_size]);
        builder.add_vertex_to_facet(v_indices[i + half_size]);
        builder.end_facet();


    }

    builder.end_surface();

    if (!polyhedron.is_valid() || !polyhedron.is_closed()) {
        qInfo() << "Error: Invalid or non-closed polyhedron.";
        throw std::runtime_error("Error: Invalid or non-closed polyhedron.");
    }
}

static Polyhedron createPolyhedronFromZone(const QList<NoFlyZone>& zone)
{
    Polyhedron poly;
    if (zone.size() < 3) {
        return poly;
    }

    std::vector<Point_3> baseVertices;
    std::vector<Point_3> topVertices;
    baseVertices.reserve(zone.size());
    topVertices.reserve(zone.size());

    for (const NoFlyZone& z : zone) {
        double floor = z.altitudeFloor;
        double ceiling = z.altitudeCeiling;
        if (floor == 0 && ceiling == 0) {
            ceiling = 100000;
        }
        baseVertices.push_back(latLonAltToCartesian(z.coordinate.latitude(), z.coordinate.longitude(), floor));
        topVertices.push_back(latLonAltToCartesian(z.coordinate.latitude(), z.coordinate.longitude(), ceiling));
    }

    if (baseVertices.size() < 3 || topVertices.size() < 3) {
        return poly;
    }

    std::vector<Point_3> vertices;
    vertices.reserve(baseVertices.size() + topVertices.size());
    vertices.insert(vertices.end(), baseVertices.begin(), baseVertices.end());
    vertices.insert(vertices.end(), topVertices.begin(), topVertices.end());

    try {
        createPolyhedron(vertices, poly);
    } catch (...) {
        poly.clear();
    }
    return poly;
}



void FlightZoneManager::generateNoFlyZones(QList<std::tuple<QList<QGeoCoordinate>, double, double>> parsedPolygons, QList<AqgcZoneMeta> metas)
{
    try {
        if (parsedPolygons.count() > 0) {
            int metaIdx = -1;
            for (const auto& polyData : parsedPolygons) {
                ++metaIdx;
                const QList<QGeoCoordinate>& coords = std::get<0>(polyData);

                std::vector<Point_3> vertices;
                std::vector<Point_3> baseVertices;
                std::vector<Point_3> topVertices;
                Polyhedron P; // 거리측정
                Polyhedron polyhedron; // 내부 측정

                double floor = std::get<1>(polyData);
                double ceiling = std::get<2>(polyData);
                if (floor == 0 && ceiling == 0) {
                    floor = 0;
                    ceiling = 100000;
                }

                for (const QGeoCoordinate& coord : coords) {

                    if (!coord.isValid()) continue;

                    double lat = coord.latitude();
                    double lon = coord.longitude();

                    if (!coord.isValid() || std::isnan(lat) || std::isnan(lon)) {
                        qWarning() << "Invalid coordinate skipped:" << coord;
                        continue;
                    }

                    baseVertices.push_back(latLonAltToCartesian(lat, lon, floor));
                    topVertices.push_back(latLonAltToCartesian(lat, lon, ceiling));

                }

                if(baseVertices.size() > 0 && topVertices.size() > 0) {
                    // 거리 측정
                    // Create bottom face (base polygon)

                    if (baseVertices.size() < 3 || topVertices.size() < 3) {
                        qWarning() << "Not enough vertices to form polyhedron.";
                        continue;
                    }


                    for (size_t i = 0; i < baseVertices.size() - 2; ++i) {
                        P.make_triangle(baseVertices[0], baseVertices[i + 1], baseVertices[i + 2]);
                    }

                    // Create top face (top polygon)
                    for (size_t i = 0; i < topVertices.size() - 2; ++i) {
                        P.make_triangle(topVertices[0], topVertices[i + 1], topVertices[i + 2]);
                    }

                    // Create side faces (connect base and top vertices)
                    for (size_t i = 0; i < baseVertices.size(); ++i) {
                        size_t next = (i + 1) % baseVertices.size(); // Wrap around to the first vertex
                        P.make_triangle(baseVertices[i], baseVertices[next], topVertices[i]); // Side triangle 1
                        P.make_triangle(baseVertices[next], topVertices[next], topVertices[i]); // Side triangle 2
                    }

                    // AABB_tree tree(faces(P).first, faces(P).second, P);
                    // tree.accelerate_distance_queries();

                    // auto tree = QSharedPointer<AABB_tree>::create(faces(P).first, faces(P).second, P);
                    // tree->accelerate_distance_queries();

                    // ? 밑면을 먼저 추가
                    vertices.insert(vertices.end(), baseVertices.begin(), baseVertices.end());

                    // ? 윗면을 나중에 추가
                    vertices.insert(vertices.end(), topVertices.begin(), topVertices.end());

                    createPolyhedron(vertices, polyhedron);

                    if (polyhedron.empty()) {
                        qWarning() << "빈 폴리곤입니다.";
                        return;
                    }

                    QWriteLocker locker(&_zoneLock);
                    if (!containsPolyhedron(_noFlyZoneList, polyhedron)) {
                        _noFlyZoneList.append(polyhedron);
                        _noFlyZoneMeta.append(metaIdx < metas.size() ? metas[metaIdx] : AqgcZoneMeta());
                    }
                }
            }
        }
    } catch (const std::exception& e) {
        qWarning() << "generateNoFlyZones 내부 예외:" << e.what();
    } catch (...) {
        qWarning() << "generateNoFlyZones 내부 알 수 없는 예외";
    }
}

bool FlightZoneManager::containsPolyhedron(const QList<Polyhedron>& list, const Polyhedron& poly) {
    for (const auto& p : list) {
        if (isSamePolyhedron(p, poly))
            return true;
    }
    return false;
}

bool FlightZoneManager::isSamePolyhedron(const Polyhedron& a, const Polyhedron& b) {
    if (a.size_of_vertices() != b.size_of_vertices()) return false;

    // 아주 간단하게 각 vertex 좌표가 일치하는지 비교 (순서 무시)
    std::set<Point_3> verticesA, verticesB;

    for (auto v = a.vertices_begin(); v != a.vertices_end(); ++v)
        verticesA.insert(v->point());

    for (auto v = b.vertices_begin(); v != b.vertices_end(); ++v)
        verticesB.insert(v->point());

    return verticesA == verticesB;
}

std::vector<AABB_tree> _noFlyZoneTrees;
typedef Polyhedron::Facet_const_iterator Face_iterator;
void FlightZoneManager::buildAABBTreeForAllZones()
{
    _zoneAABBTree.clear();

    for (const Polyhedron& poly : _noFlyZoneList) {
        if (poly.empty()) {
            qWarning() << "Empty polyhedron found, skipping.";
            continue;
        }

        // 여기서 Facet_const_iterator 타입 명확히 지정
        // Polyhedron::Facet_const_iterator faces_begin = poly.facets_begin();
        // Polyhedron::Facet_const_iterator faces_end = poly.facets_end();

        auto faces_begin = poly.faces_begin();
        auto faces_end = poly.faces_end();

        if (faces_begin == faces_end) {
            qWarning() << "Polyhedron has no faces, skipping.";
            continue;
        }

        // AABB_tree 생성
        //AABB_tree tree(faces_begin, faces_end, poly);
        //Tree tree(faces_begin, faces_end, poly);

        auto range = faces(poly);
        auto tree = std::make_shared<AABB_tree>(range.begin(), range.end(), poly);
        tree->accelerate_distance_queries();

        int faceCount = std::distance(poly.faces_begin(), poly.faces_end());
        qDebug() << "poly face count:" << faceCount;

        if (tree->size() == 0) {
            qWarning() << "AABB tree contains no primitives, skipping.";
            continue;
        }


        _zoneAABBTree.push_back(tree);
    }
}



Point_3 FlightZoneManager::approximatePolyhedronCenter(const Polyhedron& poly) {
    CGAL::Bbox_3 bbox = CGAL::bbox_3(poly.points_begin(), poly.points_end());
    double cx = (bbox.xmin() + bbox.xmax()) / 2.0;
    double cy = (bbox.ymin() + bbox.ymax()) / 2.0;
    double cz = (bbox.zmin() + bbox.zmax()) / 2.0;
    return Point_3(cx, cy, cz);
}



void FlightZoneManager::checkDroneAndGeoZoneSafe(const QList<Polyhedron>& zoneList, const QList<AqgcZoneMeta>& meta,
                                                 double lat, double lon, double alt,
                                                 double alarmDistance)
{
    QtConcurrent::run([=]() {
        try {
            MultiVehicleManager* manager = qgcApp()->toolbox()->multiVehicleManager();
            if(manager){
                if(manager->activeVehicle()){
                    double droneLat = 0.0;  // Drone's latitude
                    double droneLon = 0.0; // Drone's longitude
                    double droneAlt = 0.0;  // Drone's altitude

                    droneLat = manager->activeVehicle()->latitude();
                    droneLon = manager->activeVehicle()->longitude();
                    droneAlt = manager->activeVehicle()->altitudeRelative()->rawValue().toDouble();

                    if (std::isnan(droneLat) || std::isnan(droneLon) || std::isnan(droneAlt)) {
                        //qWarning() << "Received NaN for vehicle position. Using default values.";
                        droneLat = 0.0; // Default values to handle the NaN case
                        droneLon = 0.0;
                        droneAlt = 0.0;
                    }

                    // 등록한 드론의 위치를 가져와야함

                    // Convert drone's position to Cartesian coordinates
                    const Point_3 dronePointRel = latLonAltToCartesian(droneLat, droneLon, droneAlt);

                    // AQGC Simple UI: one structured result per check (zoneStatus signal)
                    // AMSL bands (ED-318 AMSL / WGS84) are compared with the drone's altitude above sea level
                    double droneAmsl = manager->activeVehicle()->altitudeAMSL()->rawValue().toDouble();
                    if (std::isnan(droneAmsl)) droneAmsl = droneAlt;
                    const Point_3 dronePointAmsl = latLonAltToCartesian(droneLat, droneLon, droneAmsl);
                    auto rankOf = [&meta](int idx) {
                        if (idx < 0 || idx >= meta.size()) return 3;
                        const AqgcZoneMeta& m = meta[idx];
                        return (m.cls == 1 || m.noEntry) ? 0 : m.cls == 2 ? 1 : m.cls == 4 ? 2 : 3;
                    };
                    int insideIdx = -1, nearIdx = -1;
                    double nearDist = std::numeric_limits<double>::max();
                    int zoneIdx = -1;

                    for (const Polyhedron& poly : zoneList) {
                        ++zoneIdx;
                        const double zoneAlarm = zoneIdx < meta.size() && meta[zoneIdx].warn > 0 ? meta[zoneIdx].warn : alarmDistance;
                        const Point_3& dronePoint = zoneIdx < meta.size() && meta[zoneIdx].amsl ? dronePointAmsl : dronePointRel;

                        bool inside = checkPointInsidePolyhedron(poly, dronePoint);
                        if (inside) {
                            if (insideIdx < 0 || rankOf(zoneIdx) < rankOf(insideIdx)) {
                                insideIdx = zoneIdx;
                            }
                            QMetaObject::invokeMethod(CustomQmlInterface::instance(), [=]() {
                                CustomQmlInterface::instance()->geoAwarenessMessage("Drone is inside GeoZone!");
                            }, Qt::QueuedConnection);
                            continue; // 이미 알림 줬으면 거리 체크는 스킵 가능
                        }

                        // 꼭짓점들간의 최소거리 확인
                        double minSquaredDist = std::numeric_limits<double>::max();
                        for (auto v = poly.vertices_begin(); v != poly.vertices_end(); ++v) {
                            double d = CGAL::squared_distance(dronePoint, v->point());
                            if (d < minSquaredDist) minSquaredDist = d;
                        }
                        double minDist = std::sqrt(minSquaredDist);

                        if(minDist > std::max(alarmDistance, zoneAlarm) + 200) {
                            continue;
                        }

                        //qInfo() << "minDist == " << minDist;

                        // 4. 진짜로 가까운 경우에만 AABB_tree 생성
                        AABB_tree tree(faces(poly).first, faces(poly).second, poly);
                        tree.accelerate_distance_queries();

                        double exactDist = std::sqrt(tree.squared_distance(dronePoint));

                        // the most restrictive zone within its warning distance, then the closest one
                        if (exactDist <= zoneAlarm && (nearIdx < 0 || rankOf(zoneIdx) < rankOf(nearIdx)
                                                       || (rankOf(zoneIdx) == rankOf(nearIdx) && exactDist < nearDist))) {
                            nearDist = exactDist;
                            nearIdx = zoneIdx;
                        }
                        if (exactDist <= alarmDistance) {
                            QString msg = QString("The distance between the aircraft and GeoZone is close. Distance : %1M").arg(exactDist);
                            QMetaObject::invokeMethod(CustomQmlInterface::instance(), [msg]() {
                                CustomQmlInterface::instance()->geoAwarenessMessage(msg);
                            }, Qt::QueuedConnection);
                        }
                    }
                    {
                        const int idx = insideIdx >= 0 ? insideIdx : nearIdx;
                        const int level = insideIdx >= 0 ? 2 : nearIdx >= 0 ? 1 : 0;
                        const QString name = idx >= 0 && idx < meta.size() ? meta[idx].name : QString();
                        const int cls = idx >= 0 && idx < meta.size() ? meta[idx].cls : 0;
                        const bool noEntry = idx >= 0 && idx < meta.size() && meta[idx].noEntry;
                        const double dist = level == 1 ? nearDist : 0.0;
                        QMetaObject::invokeMethod(this, [this, level, dist, name, cls, noEntry]() {
                            _setZoneStatus(level, dist, name, cls, noEntry);
                        }, Qt::QueuedConnection);
                    }
                }
            }
        }catch (const std::exception& e) {
            qWarning() << "Exception in checkDroneAndGeoZoneSafe Method QtConcurrent::run:" << e.what();
        } catch (...) {
            qWarning() << "Unknown exception in checkDroneAndGeoZoneSafe Method QtConcurrent::run";
        }
    });
}

void FlightZoneManager::checkDroneAndGeoZone() {
    try {
        double alarmDistance = _settingsManager->flyViewSettings()->alarmDistance()->rawValue().toDouble();
        MultiVehicleManager* manager = qgcApp()->toolbox()->multiVehicleManager();
        if(manager){
            if(manager->activeVehicle()){
                if(_noFlyZoneList.count() > 0) {
                    _zoneLock.lockForRead();
                    for (const Polyhedron& p : _noFlyZoneList) {

                        //const Polyhedron& p = zone.polyhedron;

                        // Drone's position (lat/lon/alt) for example
                        double droneLat = 0.0;  // Drone's latitude
                        double droneLon = 0.0; // Drone's longitude
                        double droneAlt = 0.0;  // Drone's altitude

                        droneLat = manager->activeVehicle()->latitude();
                        droneLon = manager->activeVehicle()->longitude();

                        droneAlt = manager->activeVehicle()->altitudeRelative()->rawValue().toDouble();

                        if (std::isnan(droneLat) || std::isnan(droneLon) || std::isnan(droneAlt)) {
                            //qWarning() << "Received NaN for vehicle position. Using default values.";
                            droneLat = 0.0; // Default values to handle the NaN case
                            droneLon = 0.0;
                            droneAlt = 0.0;
                        }

                        // 등록한 드론의 위치를 가져와야함

                        AABB_tree tree(faces(p).first, faces(p).second, p);
                        tree.accelerate_distance_queries();

                        // Convert drone's position to Cartesian coordinates
                        Point_3 dronePosition = latLonAltToCartesian(droneLat, droneLon, droneAlt);

                        // Query the distance between the drone's position and the polyhedron
                        double distance = std::sqrt(tree.squared_distance(dronePosition)); // distance in meters
                        if (std::isnan(dronePosition.x()) || std::isnan(dronePosition.y()) || std::isnan(dronePosition.z())) {
                            qWarning() << "Invalid dronePosition coordinates";
                            continue;
                        }

                        bool inside = checkPointInsidePolyhedron(p, dronePosition);

                        if(inside == true) // Drone is Inside polyhedron
                        {
                            QString msg  = "Drone is inside GeoZone!";
                            //CustomQmlInterface::instance()->geoAwarenessMessage(msg);

                            QMetaObject::invokeMethod(CustomQmlInterface::instance(), [msg]() {
                                CustomQmlInterface::instance()->geoAwarenessMessage(msg);
                            }, Qt::QueuedConnection);
                        }
                        else // Drone is out side polyhedron
                        {
                            if(distance <= alarmDistance) // 지정한 거리값 안에 들어오면 알람을 띄워야됨
                            {
                                //qInfo() << "Inside Index = " << i;
                                QString msg = tr("The distance between the aircraft and GeoZone is close. Distance : %1M").arg(distance);
                                //CustomQmlInterface::instance()->geoAwarenessMessage(msg);

                                QMetaObject::invokeMethod(CustomQmlInterface::instance(), [msg]() {
                                    CustomQmlInterface::instance()->geoAwarenessMessage(msg);
                                }, Qt::QueuedConnection);
                            }
                        }
                    }
                    _zoneLock.unlock();
                }
            }
        }
    }
    catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return;
    }
}

void FlightZoneManager::checkDistanceDroneAndGeoAwareness(){

    try {
        double alarmDistance = _settingsManager->flyViewSettings()->alarmDistance()->rawValue().toDouble();

        QList<Polyhedron> zoneList;
        std::vector<std::shared_ptr<AABB_tree>> zoneTrees;
        {
            QReadLocker locker(&_zoneLock);
            zoneList = _noFlyZoneList;
            zoneTrees = _zoneAABBTree;
        }

        if (zoneTrees.size() < static_cast<size_t>(zoneList.size())) {
            QWriteLocker w(&_zoneLock);
            buildZoneTrees(_noFlyZoneList, _zoneAABBTree);
            zoneTrees = _zoneAABBTree;
        }

        MultiVehicleManager* manager = qgcApp()->toolbox()->multiVehicleManager();
        if (!manager || !manager->activeVehicle()) {
            return;
        }

        // Reload if drone moved >3km to keep 3km view window
        // QGeoCoordinate droneCoord(manager->activeVehicle()->latitude(),
        //                           manager->activeVehicle()->longitude());
        // if (.isValid() && droneCoord.isValid()) {
        //     if (.distanceTo(droneCoord) > 10000) {
        //          = droneCoord;
        //         removeAll();
        //         geoCoordinate = droneCoord;
        //         start();
        //         return;
        //     }
        // } else if (droneCoord.isValid()) {
        //      = droneCoord;
        // }

        Point_3 dronePosition = latLonAltToCartesian(manager->activeVehicle()->latitude(),
                                                     manager->activeVehicle()->longitude(),
                                                     manager->activeVehicle()->altitudeRelative()->rawValue().toDouble());

        for (int idx = 0; idx < zoneList.size(); ++idx) {
            const Polyhedron& poly = zoneList.at(idx);
            if (poly.empty() || idx >= static_cast<int>(zoneTrees.size())) {
                continue;
            }

            const std::shared_ptr<AABB_tree>& tree = zoneTrees.at(idx);
            if (!tree || tree->size() == 0) {
                continue;
            }

            const double distance = std::sqrt(tree->squared_distance(dronePosition));
            const auto inside = CGAL::Side_of_triangle_mesh<Polyhedron, Kernel>(poly);

            if (inside(dronePosition) == CGAL::ON_BOUNDED_SIDE) {
                QString msg  = "Drone is inside GeoZone!";
                QMetaObject::invokeMethod(CustomQmlInterface::instance(), [msg]() {
                    CustomQmlInterface::instance()->geoAwarenessMessage(msg);
                }, Qt::QueuedConnection);
            } else if (distance <= alarmDistance) {
                QString msg = tr("The distance between the aircraft and GeoZone is close. Distance : %1M").arg(distance);
                QMetaObject::invokeMethod(CustomQmlInterface::instance(), [msg]() {
                    CustomQmlInterface::instance()->geoAwarenessMessage(msg);
                }, Qt::QueuedConnection);
            }
        }


    }
    catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return;
    }
}


void FlightZoneManager::fetchGeoJsonDataForRegion(double n, double e, double s, double w)
{
    QString onlineUrl = _settingsManager->flyViewSettings()->onlinePath()->rawValueString();
    QString onlineLicenseKey =_settingsManager->flyViewSettings()->onlineLicenseKey()->rawValueString();
    QString authorizationHeader = "X-AA-ApiKey " + onlineLicenseKey;
    //qInfo(FlightZoneManagerLog) << "online Url : " << onlineUrl;
    QString url = "https://api.altitudeangel.com/v2/mapdata/geojson";
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

QString getExternalStoragePath() {
    // Get the directory for storing external files.
    return QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
}
QString FlightZoneManager::getFilePath() {

    QString savePath = _settingsManager->flyViewSettings()->filePath()->rawValueString();
    //qInfo() << "FlightZoneManger savePath : " << savePath;

#ifdef Q_OS_ANDROID
    // Android에서 파일 경로
    //QString filePath = getExternalStoragePath() + "/map.geojson";
    //QString filePath = "content://com.android.providers.downloads.documents/document/msf%3A87334";
    QString filePath = savePath;
    return filePath;
#else
    // Windows에서 사용자 Documents 폴더 경로
    //QString documentsPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) + "/map.geojson";
    QString documentsPath = savePath;
    return documentsPath ;
#endif
}

void FlightZoneManager::deletePolygon(int index)
{
    //qInfo() << "deletepolygon index" << index;
    if (index < 0 || index > _polygons.count() - 1) {
        return;
    }

    QGCFencePolygon* polygon = qobject_cast<QGCFencePolygon*>(_polygons.removeAt(index));
    if (polygon) {
        polygon->deleteLater(); // 메모리 해제
    }
}

void FlightZoneManager::removeAll(void)
{
    _polygons.clearAndDeleteContents();
    _circles.clearAndDeleteContents();
    geoJsonNameList.clear();
    validTimeList.clear();
    
    QWriteLocker locker(&_zoneLock);
    _noFlyZoneList.clear();
    _noFlyZoneMeta.clear();
    _zoneAABBTree.clear();
    _zoneTriangles.clear();

}

void FlightZoneManager::updateGeoAwareness(){
    QString dataType = _settingsManager->flyViewSettings()->dataType()->rawValueString();
    // Only for online
    if(dataType == "1"){
        if(_polygons.count() > 0) {
            removeAll();
            qInfo(FlightZoneManagerLog) << "updateGeoAwareness";
            start();
        }
    }
}
void FlightZoneManager::checkCurrentZoomValue() {

    double zoom = qGroundControlQmlGlobal->flightMapZoom();

    //qInfo() << "current Zoom value = " << zoom;

    //내가 있는 지도의 가운데 좌표
    QGeoCoordinate mapCoord = qGroundControlQmlGlobal->flightMapPosition();
    QString dataType = _settingsManager->flyViewSettings()->dataType()->rawValueString();
    //  가운데 좌표, zoom값

    //qInfo() << "lat : " << mapCoord.latitude() << "lon : " << mapCoord.longitude();
    //0 = USB, 1 = Online

    if(dataType == "0")
    {
        if(_polygons.count() == 0) { // 이미 생성되어 있음

            //왜 여러번 실행되는지 확인필요
            //qInfo()<< "init polygons";
            geoCoordinate = qGroundControlQmlGlobal->flightMapPosition();
            //start();
        }
    }
    else {
        if(zoom >= 14)  { // 테스트용으로 8 원래는 13
            //qInfo(FlightZoneManagerLog) << "FlightMap zoom Over 12: " << qGroundControlQmlGlobal->flightMapZoom();
            if(_officialPolygonCount() == 0) { // 이미 생성되어 있음 (AQGC: My zones do not count)

                //왜 여러번 실행되는지 확인필요

                // if (_oneTime) {
                //     // 단, isGroundHazard가 false면 한번 더 실행 가능
                //     if (!_isGroundHazard) {
                //         qInfo() << "init polygons (isGroundHazard override)";
                //         geoCoordinate = mapCoord;
                //         start();

                //         // 한 번 실행했으므로 다시 true로 설정
                //         _oneTime = true;
                //     }
                //     return;
                // }

                _oneTime = true;
                //qInfo()<< "init polygons";
                geoCoordinate = mapCoord;
                start();
            }
            // 여기서 화면 이동시 조건도 추가 필요함

            double distanceMeters = qGroundControlQmlGlobal->flightMapPosition().distanceTo(geoCoordinate);
            if(distanceMeters > 2000) // 2Km 이상 이동 시
            {
                if(_officialPolygonCount() > 0){                // 위치 새로고침 후 생성
                    //removeAll();
                    QGeoCoordinate flightmapPos = qGroundControlQmlGlobal->flightMapPosition();
                    QGeoCoordinate geoCoord = geoCoordinate;
                    geoCoordinate = qGroundControlQmlGlobal->flightMapPosition();
                    start();
                }
            }

            // if(qGroundControlQmlGlobal->flightMapPosition() != geoCoordinate) // 위치가 바뀌면
            // {
            //     if(_polygons.count() > 0){                // 위치 새로고침 후 생성
            //         //removeAll();
            //         QGeoCoordinate flightmapPos = qGroundControlQmlGlobal->flightMapPosition();
            //         QGeoCoordinate geoCoord = geoCoordinate;
            //         // qInfo() << "flightmapPos = " << flightmapPos.latitude() << "," << flightmapPos.longitude();
            //         // qInfo() << "geoCoord = " << geoCoordinate.latitude() << "," << geoCoordinate.longitude();
            //         //드론의 로딩이 다 끝나면 불러와야할듯함
            //         geoCoordinate = qGroundControlQmlGlobal->flightMapPosition();
            //         start();
            //     }
            // }
        }
        else if(zoom < 11){
            //qInfo(FlightZoneManagerLog) << "FlightMap zoom less 10: " << qGroundControlQmlGlobal->flightMapZoom();
            // 생성된거 전부 삭제
            if (_officialPolygonCount() > 0) {
                _removeOfficialZones();     // AQGC: keep the My zones (they still block and warn)
            }

            _oneTime = false;
            _isGroundHazard = false;
        }
    }

// 이거는 qgc를 킨 위치인듯함
#if false
    if(qgcpositionManager) {
        qInfo() << "qgcpositionManager is not null";
        QGeoCoordinate gcsPosition = qgcApp()->toolbox()->qgcPositionManager()->gcsPosition();

        qInfo() << "gcsPosition = " << gcsPosition.latitude() << "," << gcsPosition.longitude() << "," << gcsPosition.altitude();
    }
    else {
        qInfo() << "qgcpositionManager is null";
    }
#endif
}

// 화면 이동 시

void FlightZoneManager::updatePolygonVisibility() {

    // validTimeList valid_from과 valid_to는 이 리스트에 저장되어 있음

    // 읽어온 파일과 현재 시간과 비교
    // 만약 validto를 넘으면 넘은 polygon을 삭제
    // 만약 validfrom 시간에 들어오면 그 들어온 polygon을 생성

    // 현재 시간
    QDateTime currentTime = QDateTime::currentDateTime();

    QString dataType = _settingsManager->flyViewSettings()->dataType()->rawValueString();

    //USB일때만 동작하도록.
    if(dataType == "0"){
        for(int i = 0; i < validTimeList.size(); ++i){
            auto& timeData = validTimeList[i];

            QDateTime validFrom = timeData.validFrom;
            QDateTime validTo = timeData.validTo;
            //qInfo() << timeData.polygonid;
            //qInfo() << "currentTime : " << currentTime <<"validFrom : " << validFrom << "validTo : " << validTo;

            // 유효기간을 넘었으면 Polygon 삭제
            // 아직 보여주는 시간이 안되었어도 Polygon 삭제
            if(currentTime > validTo) {
                qInfo(FlightZoneManagerLog) << "Delete Index : " << i;
                deletePolygon(i);
                validTimeList.removeAt(i);
                
                --i;
                timeData.isCreated = false;
                qInfo(FlightZoneManagerLog) << "After Delete Polygon count: " << _polygons.count();
                continue;
            }

            //현재 시간이 validFrom에 해당하면 생성
            if (!timeData.isCreated && currentTime >= validFrom && currentTime <= validTo) {
                qInfo(FlightZoneManagerLog) << "Create Polygon for ID: " << timeData.polygonid;
                qInfo(FlightZoneManagerLog) << "시간 지남 index : " << i ;
                //Delete All
                removeAll();
                // AddNew
                processJsonFile(getFilePath());

                timeData.isCreated = true; // 생성 완료 상태 설정
            }
        }
    }
}

QJsonValue findJsonValue(const QJsonValue& value, const QString& key) {
    // 현재 값이 객체인 경우
    if (value.isObject()) {
        QJsonObject obj = value.toObject();

        // 현재 레벨에 키가 있는지 확인
        if (obj.contains(key)) {
            return obj.value(key);
        }

        // 없으면 모든 하위 객체를 재귀 검색
        for (const QString& k : obj.keys()) {
            QJsonValue found = findJsonValue(obj.value(k), key);
            if (!found.isNull() && !found.isUndefined()) {
                return found;
            }
        }
    }
    // 현재 값이 배열인 경우
    else if (value.isArray()) {
        QJsonArray arr = value.toArray();
        for (const QJsonValue& item : arr) {
            QJsonValue found = findJsonValue(item, key);
            if (!found.isNull() && !found.isUndefined()) {
                return found;
            }
        }
    }

    return QJsonValue(); // 못 찾음
}

QVariantList convertToVariantList(const QList<QPointF>& points) {
    QVariantList list;
    for (const QPointF& p : points) {
        list << QVariant::fromValue(QPointF(p.x(), p.y())); // QML에서 Qt.point(x, y)로 받음
    }
    return list;
}

QPointF computeCentroid(const QList<QPointF>& points) {
    if (points.isEmpty())
        return QPointF();

    double sumLat = 0;
    double sumLon = 0;

    for (const QPointF& pt : points) {
        sumLat += pt.y(); // QPointF(x=lon, y=lat)
        sumLon += pt.x();
    }

    return QPointF(sumLon / points.size(), sumLat / points.size());
}

void FlightZoneManager::parseGeometryAndSave(
    const QJsonObject& geometry,
    QGCFencePolygon* polygon,
    QList<NoFlyZone>& noFlyZone,
    double altitudeFloor,
    double altitudeCeiling,
    const QString& validFrom,
    const QString& validTo)
{
    QString type = geometry.value("type").toString();
    QJsonValue coordValue = geometry.value("coordinates");

    if (!coordValue.isArray()) {
        qWarning() << "Invalid geometry: coordinates is not array";
        return;
    }

    QJsonArray coordinates = coordValue.toArray();


    // -----------------------------
    // 1) Polygon 처리
    // -----------------------------
    if (type == "Polygon") {
        for (const QJsonValue& ringValue : coordinates) {
            if (!ringValue.isArray()) continue;
            QJsonArray ring = ringValue.toArray();

            for (const QJsonValue& pointValue : ring) {
                if (!pointValue.isArray()) continue;
                QJsonArray point = pointValue.toArray();
                if (point.size() < 2) continue;

                double lon = point[0].toDouble();
                double lat = point[1].toDouble();

                QGeoCoordinate coord(lat, lon);

                if (!validFrom.isEmpty() && !validTo.isEmpty()) {
                    polygon->appendVertex(coord);
                    noFlyZone.append(NoFlyZone(coord, altitudeFloor, altitudeCeiling));
                }
            }
        }
        return;
    }

// -----------------------------
// 2) MultiPolygon 처리
// -----------------------------

#if false
    if (type == "MultiPolygon") {
        //int polyIndex = 0;

        MultiVehicleManager* manager = qgcApp()->toolbox()->multiVehicleManager();

        if(manager) {
            qInfo() << "Manager lat = " << manager->activeVehicle()->latitude() << " lng = " << manager->activeVehicle()->longitude();
        }
        QGCFencePolygon* subPolygon;
        QVariantList polygonList;
        for (const QJsonValue& polyValue : coordinates) {
            if (!polyValue.isArray()) continue;
            QJsonArray polygonArray = polyValue.toArray();   // polygon 하나

            // **각 polygon마다 새로운 QGCFencePolygon 생성**
            subPolygon = new QGCFencePolygon(false, polygon->parent());
            //subPolygon->setInclusion(polygon->inclusion());
            subPolygon->setcolorInclusion("red");
            subPolygon->setstrokeOpacity(0.7);

            for (const QJsonValue& ringValue : polygonArray) {
                if (!ringValue.isArray()) continue;
                QJsonArray ring = ringValue.toArray();

                for (const QJsonValue& pointValue : ring) {
                    if (!pointValue.isArray()) continue;
                    QJsonArray point = pointValue.toArray();
                    if (point.size() < 2) continue;

                    double lon = point[0].toDouble();
                    double lat = point[1].toDouble();

                    QGeoCoordinate coord(lat, lon);

                    if (!validFrom.isEmpty() && !validTo.isEmpty()) {
                        subPolygon->appendVertex(coord);
                        noFlyZone.append(NoFlyZone(coord, altitudeFloor, altitudeCeiling));

                    }
                }
            }

            // if(allNoFlyZones.count() > 200)
            //     continue;

            
            // **FlightZoneManager의 _polygons 리스트에 추가**
            if (!_polygons.contains(subPolygon))
                _polygons.append(subPolygon);
        }
        return;
    }
#endif
#if true
    if (type == "MultiPolygon") {

        // 드론 위치 가져오기
        MultiVehicleManager* manager = qgcApp()->toolbox()->multiVehicleManager();
        QGeoCoordinate dronePos;

        if (manager && manager->activeVehicle()) {
            dronePos = QGeoCoordinate(manager->activeVehicle()->latitude(),
                                      manager->activeVehicle()->longitude());
        }

        double maxDistanceMeters = 10000;   // 10 km

        for (const QJsonValue& polyValue : coordinates) {
            if (!polyValue.isArray()) continue;
            QJsonArray polygonArray = polyValue.toArray();

            bool isInside10km = false;
            QList<QGeoCoordinate> tempVertices;

            // ----- 먼저 거리 체크용으로 vertex만 읽기 -----
            for (const QJsonValue& ringValue : polygonArray) {
                if (!ringValue.isArray()) continue;
                QJsonArray ring = ringValue.toArray();

                for (const QJsonValue& pointValue : ring) {
                    if (!pointValue.isArray()) continue;
                    QJsonArray point = pointValue.toArray();
                    if (point.size() < 2) continue;

                    double lon = point[0].toDouble();
                    double lat = point[1].toDouble();

                    QGeoCoordinate coord(lat, lon);
                    tempVertices.append(coord);

                    if (dronePos.isValid()) {
                        double dist = dronePos.distanceTo(coord);
                        if (dist <= maxDistanceMeters)
                            isInside10km = true;
                    }
                }
            }

            // ----- 10km 밖이면 polygon 아예 생성하지 않음 -----
            if (!isInside10km)
                continue;

            // ----- 여기서부터 실제 객체 생성 (10km 안일 때만) -----
            QGCFencePolygon* subPolygon = new QGCFencePolygon(false, polygon->parent());
            subPolygon->setcolorInclusion("red");
            subPolygon->setstrokeOpacity(0.7);

            //QVector<NoFlyZone> noFlyZone;

            for (const QGeoCoordinate& v : tempVertices) {
                subPolygon->appendVertex(v);
                noFlyZone.append(NoFlyZone(v, altitudeFloor, altitudeCeiling));
            }

            

            if (!_polygons.contains(subPolygon))
                _polygons.append(subPolygon);
        }


        return;
    }


#endif

    qWarning() << "Unsupported geometry type:" << type;
}

// ------------------------------------------------------------------------------------ Read From File

#if true
void FlightZoneManager::processJsonFile(const QString& filePath) {

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        _setZoneError(tr("The zone file cannot be opened: %1").arg(QFileInfo(filePath).fileName()));
        QString msg = tr("Cannot access GeoZone data.<br>Please check local files or internet connection.");
        CustomQmlInterface::instance()->geoAwarenessMessage(msg);
        return;
    }

    const QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) {
        _setZoneError(tr("The zone file is not valid GeoJSON: %1").arg(QFileInfo(filePath).fileName()));
        qWarning() << "Invalid JSON format";
        QString msg = tr("Cannot access GeoZone data.<br>Please check local files or internet connection.");
        CustomQmlInterface::instance()->geoAwarenessMessage(msg);
        return;
    }

    const QJsonArray features = findJsonValue(doc.isObject() ? QJsonValue(doc.object()) : QJsonValue(doc.array()), "features").toArray();
    if (features.isEmpty()) {
        qWarning() << "No features found in GeoZone file";
        return;
    }

    _setZoneError(QString());
    // Clear existing polygons to start fresh and show batches incrementally
    removeAll();

    // Prepare fresh containers to avoid unbounded growth between runs
    QList<QList<NoFlyZone>> newNoFlyZones;
    QList<AqgcZoneMeta> newZoneMeta;            // AQGC Simple UI
    QSet<QString> seenIds;
    QList<QList<QGeoCoordinate>> keptVertices;
    QList<QGCFencePolygon*> batchPolys;

    validTimeList.clear();
    
    const QDateTime currentTime = QDateTime::currentDateTime();
    const int kMaxZones = INT_MAX; // no cap on number of features
    const double simplifyToleranceMeters = 0.0; // simplify disabled to keep shape integrity
    // Only decimate when reduction is enabled; otherwise keep full resolution
    const int kMaxVerticesPerZone = _reduceVerticesEnabled ? 180 : 300;
    int duplicateZones = 0; // unused now
    int skippedEmpty = 0;
    int skippedFar = 0;
    const int logInterval = 50;
    const int batchSize = 100;
    auto flushBatch = [&]() {
        if (batchPolys.isEmpty()) {
            return;
        }
        // Append batch to model and let UI update between batches
        for (auto* p : batchPolys) {
            _polygons.append(p);
        }
        batchPolys.clear();
        QCoreApplication::processEvents(QEventLoop::AllEvents, 10);
    };

    int processed = 0;
    for (int featureIndex = 0; featureIndex < features.size(); ++featureIndex) {
        const QJsonValue feature = features.at(featureIndex);
        if (!feature.isObject()) {
            continue;
        }

        const QJsonObject featureObj = feature.toObject();
        const QJsonObject geometry = featureObj.value("geometry").toObject();
        const QJsonObject properties = featureObj.value("properties").toObject();
        const QString type = geometry.value("type").toString();
        const QString id = featureObj.value("id").toString();

        if (type != "Polygon" && type != "MultiPolygon") {
            continue;
        }
        if (!id.isEmpty() && seenIds.contains(id)) {
            continue;
        }

        const QJsonArray coordinates = geometry.value("coordinates").toArray();
        if (coordinates.isEmpty()) {
            ++skippedEmpty;
            continue;
        }

        const QJsonObject layer = geometry.value("layer").toObject();

        double altitudeFloor = 0.0;
        double altitudeCeiling = 99999.0;

        const QString lowerRef = layer.value("lowerReference").toString().toUpper();
        const QString upperRef = layer.value("upperReference").toString().toUpper();
        const bool bandAmsl = lowerRef == "AMSL" || lowerRef == "WGS84" || upperRef == "AMSL" || upperRef == "WGS84";
        if (!layer.isEmpty()) {     // was "layer.isEmpty()": the ED-318 height band was never read
            const double unit = layer.value("uom").toString().toLower() == "ft" ? 0.3048 : 1.0;
            if (layer.contains("lower") && layer.value("lower").isDouble()) {
                altitudeFloor = layer.value("lower").toDouble() * unit;
            }

            if (layer.contains("upper") && layer.value("upper").isDouble()) {
                altitudeCeiling = layer.value("upper").toDouble() * unit;
            }
        }

        // const double altitudeFloor = layer.value("lower").toDouble();
        // const double altitudeCeiling = layer.value("upper").toDouble();        

        auto makePolygon = [&](const QList<QGeoCoordinate>& vertices) {
            if (vertices.size() < 3) {
                return static_cast<QGCFencePolygon*>(nullptr);
            }

            auto* poly = new QGCFencePolygon(false /* inclusion */, this);
            poly->setcolorInclusion("red");
            poly->setstrokeOpacity(0.7);
            for (const auto& v : vertices) {
                poly->appendVertex(v);
            }
            if (!id.isEmpty()) {
                poly->setObjectName(id);
            }
            poly->setAltitudeMin(altitudeFloor);
            poly->setAltitudeMax(altitudeCeiling);
            aqgcSetZoneInfo(poly, properties, id);
            if (bandAmsl) {
                poly->setProperty("zoneDetail", (poly->property("zoneDetail").toString() + QStringLiteral(" · ") + tr("heights above sea level")).trimmed());
                poly->setAltitudeFrame(MAV_FRAME_GLOBAL);
            }
            return poly;
        };

        auto makeNoFlyList = [&](const QList<QGeoCoordinate>& vertices) {
            QList<NoFlyZone> out;
            out.reserve(vertices.size());
            for (const auto& v : vertices) {
                out.append(NoFlyZone(v, altitudeFloor, altitudeCeiling));
            }
            return out;
        };

        auto addResult = [&](QGCFencePolygon* poly, QList<NoFlyZone>&& zones) {
            if (!poly || zones.isEmpty()) {
                if (poly) {
                    delete poly;
                }
                return false;
            }
            newNoFlyZones.append(zones);
            newZoneMeta.append({poly->property("zoneName").toString(), poly->property("zoneClass").toInt(), 0, false, bandAmsl});
            ++processed;
            if (!id.isEmpty()) {
                seenIds.insert(id);
            }
            batchPolys.append(poly);
            if (batchPolys.size() >= batchSize) {
                flushBatch();
            }
            return true;
        };

        auto simplifyAndAdd = [&](QList<QGeoCoordinate>& verts) {
        if (verts.isEmpty()) {
            ++skippedFar;
            return;
        }
        if (kMaxVerticesPerZone < INT_MAX) {
            verts = decimateVertices(verts, kMaxVerticesPerZone, simplifyToleranceMeters);
        }
        if (_useOverlapDuplicateCheck && isZoneMostlyDuplicate(verts, keptVertices)) {
            ++duplicateZones;
            return;
        }
        if (isZoneDuplicate(verts, keptVertices)) {
            ++duplicateZones;
            return;
        }
        auto nfz = makeNoFlyList(verts);
        if (addResult(makePolygon(verts), std::move(nfz))) {
            keptVertices.append(verts);
        }
    };

        if (type == "Polygon") {
            QList<QGeoCoordinate> verts;
            for (const QJsonValue& ringValue : coordinates) {
                if (!ringValue.isArray()) continue;
                const QJsonArray ring = ringValue.toArray();
                for (const QJsonValue& pointValue : ring) {
                    if (!pointValue.isArray()) continue;
                    const QJsonArray point = pointValue.toArray();
                    if (point.size() < 2) continue;
                    verts.append(QGeoCoordinate(point[1].toDouble(), point[0].toDouble()));
                }
            }
            simplifyAndAdd(verts);
        } else if (type == "MultiPolygon") {
            for (const QJsonValue& polyValue : coordinates) {
                if (!polyValue.isArray()) continue;
                const QJsonArray polygonArray = polyValue.toArray();

                QList<QGeoCoordinate> verts;
                for (const QJsonValue& ringValue : polygonArray) {
                    if (!ringValue.isArray()) continue;
                    const QJsonArray ring = ringValue.toArray();
                    for (const QJsonValue& pointValue : ring) {
                        if (!pointValue.isArray()) continue;
                        const QJsonArray point = pointValue.toArray();
                        if (point.size() < 2) continue;
                        verts.append(QGeoCoordinate(point[1].toDouble(), point[0].toDouble()));
                    }
                }

                simplifyAndAdd(verts);
                if (processed >= kMaxZones) {
                    break;
                }
            }
        }

        if ((featureIndex + 1) % logInterval == 0) {
            const QString progress = QStringLiteral("GeoParse progress feat=%1/%2 added=%3 dup=%4 empty=%5 far=%6")
                    .arg(featureIndex + 1)
                    .arg(features.size())
                    .arg(processed)
                    .arg(duplicateZones)
                    .arg(skippedEmpty)
                    .arg(skippedFar);
            qInfo(FlightZoneManagerLog) << progress;
            //writeGeoLogLine(progress, _settingsManager);
            
        } else if (featureIndex + 1 == features.size()) {
            // Ensure last batch is logged even if not on interval
            
        }
    }

    // release stored vertices used for duplicate detection
    keptVertices.clear();

    // flush any remaining batch to UI
    flushBatch();

    // Build polyhedra once and free temporary lists
    QList<Polyhedron> newPolyList;
    QList<AqgcZoneMeta> newPolyMeta;
    for (int zi = 0; zi < newNoFlyZones.size(); ++zi) {
        Polyhedron poly = createPolyhedronFromZone(newNoFlyZones[zi]);
        if (!poly.empty()) {
            newPolyList.append(std::move(poly));
            newPolyMeta.append(zi < newZoneMeta.size() ? newZoneMeta[zi] : AqgcZoneMeta());
        }
    }

    {
        QWriteLocker locker(&_zoneLock);
        _noFlyZoneList = newPolyList;
        _noFlyZoneMeta = newPolyMeta;
        buildZoneTrees(_noFlyZoneList, _zoneAABBTree);
    }

    newNoFlyZones.clear();

    logGeoMemoryUsage(QStringLiteral("GeoMem done"));
}


void FlightZoneManager::analyzeMemoryUsage()
{
    qDebug() << "=== Memory Analysis ===";
    qDebug() << "allNoFlyZones cleared/unused";
}

#endif

void FlightZoneManager::logGeoMemoryUsage(const QString& label)
{
    int polyCount = 0;
    int polyOver150 = 0;
    qint64 polyVertices = 0;
    const qint64 bytesPerCoord = static_cast<qint64>(sizeof(QGeoCoordinate));

    for (int i = 0; i < _polygons.count(); ++i) {
        QGCFencePolygon* poly = qobject_cast<QGCFencePolygon*>(_polygons.get(i));
        if (!poly) {
            continue;
        }
        const int v = poly->count();
        polyVertices += v;
        if (v > 150) {
            ++polyOver150;
        }
        ++polyCount;
    }

    int phOver150 = 0;
    qint64 phVertices = 0;
    const qint64 bytesPerPoint3 = static_cast<qint64>(sizeof(Point_3));
    
    for (const auto& ph : _noFlyZoneList) {
        const int v = static_cast<int>(ph.size_of_vertices());
        phVertices += v;
        if (v > 150) {
            ++phOver150;
        }
    }

    const double polyMB = (polyVertices * bytesPerCoord) / (1024.0 * 1024.0);
    const double phMB   = (phVertices * bytesPerPoint3) / (1024.0 * 1024.0);

    qInfo(FlightZoneManagerLog) << label
                                << "| polygons" << polyCount
                                << "verts" << polyVertices
                                << "approxMB" << QString::number(polyMB, 'f', 2)
                                << "over150" << polyOver150
                                << "| polyhedra" << _noFlyZoneList.size()
                                << "verts" << phVertices
                                << "approxMB" << QString::number(phMB, 'f', 2)
                                << "over150" << phOver150;
}

// Build QVariant meshes for QSG renderer
// static bool polygonIntersectsViewport(const QGCFencePolygon* poly, const QRectF& viewportLonLat)
// {
//     if (!poly || viewportLonLat.isNull() || viewportLonLat.width() <= 0 || viewportLonLat.height() <= 0) {
//         return true; // no viewport filtering
//     }
//     double minLon = 180.0, maxLon = -180.0, minLat = 90.0, maxLat = -90.0;
//     for (int v = 0; v < poly->count(); ++v) {
//         QGeoCoordinate c = poly->vertexCoordinate(v);
//         minLon = std::min(minLon, c.longitude());
//         maxLon = std::max(maxLon, c.longitude());
//         minLat = std::min(minLat, c.latitude());
//         maxLat = std::max(maxLat, c.latitude());
//     }
//     QRectF polyRect(minLon, maxLat, maxLon - minLon, maxLat - minLat);
//     return viewportLonLat.intersects(polyRect);
// }


// ------------------------------------------------------------------------------------ Read From Online
void FlightZoneManager::processJsonFile(const QJsonDocument& jsonDoc)
{
    QList<std::tuple<QList<QGeoCoordinate>, QString, QString, QString>> parsedPolygons; // 마지막 QString: id
    QHash<QString, QJsonObject> zonePropsById;                  // AQGC Simple UI: zone name / class
    QHash<QString, QPair<double, double>> zoneBandById;         // floor / ceiling (m)
    QList<std::tuple<QGeoCoordinate, double, QString, QString, QString>> parsedCircles; // 마지막 QString: id

    QList<std::tuple<QList<QGeoCoordinate>, double, double>> parsedNoFlyZone;
    QList<AqgcZoneMeta> parsedNoFlyMeta;                        // AQGC Simple UI: name / class per zone

    const QJsonArray features = jsonDoc["features"].toArray();
    for (const QJsonValue& featureVal : features) {
        const QJsonObject feature = featureVal.toObject();
        const QJsonObject geometry = feature["geometry"].toObject();
        const QString type = geometry["type"].toString();
        const QString id = feature["id"].toString();

        QJsonObject properties = feature.value("properties").toObject();
        QString strokeColor = properties.value("strokeColor").toString();
        QString strokeOpacity = properties.value("strokeOpacity").toString();
        QString category = properties.value("category").toString();

        QJsonObject altitudeCeiling = properties.value("altitudeCeiling").toObject();
        double ceilingMeters = altitudeCeiling.value("meters").toDouble();
        QJsonObject altitudeFloor = properties.value("altitudeFloor").toObject();
        double floorMeters = altitudeFloor.value("meters").toDouble();

        if (type == "Polygon") {
            if(category == "airspace") continue;
            if (ceilingMeters > 500) continue;
            //if(parsedPolygons.count() > 30) continue;

            QJsonArray coordinates = geometry["coordinates"].toArray();
            QList<QGeoCoordinate> polygon;
            for (const QJsonValue& ringVal : coordinates) {
                QJsonArray ring = ringVal.toArray();
                for (const QJsonValue& coordVal : ring) {
                    QJsonArray coordPair = coordVal.toArray();
                    double lon = coordPair[0].toDouble();
                    double lat = coordPair[1].toDouble();
                    polygon.append(QGeoCoordinate(lat, lon));
                }
            }

            // 중복 체크
            bool isDuplicate = false;
            for (const auto& existing : parsedPolygons) {
                const QList<QGeoCoordinate>& existingCoords = std::get<0>(existing);
                const QString& existingColor = std::get<1>(existing);
                const QString& existingOpacity = std::get<2>(existing);
                const QString& existingId = std::get<3>(existing);

                if (id == existingId) {
                    isDuplicate = true;
                    break;
                }

                if (existingCoords.size() != polygon.size() || existingColor != strokeColor || existingOpacity != strokeOpacity)
                    continue;

                bool same = true;
                for (int i = 0; i < polygon.size(); ++i) {
                    if (polygon[i] != existingCoords[i]) {
                        same = false;
                        break;
                    }
                }

                if (same) {
                    isDuplicate = true;
                    break;
                }
            }

            if (!isDuplicate) {
                // qInfo() << "Polygons altitudeFloor === " << floorMeters;
                // qInfo() << "Polygons altitudeCeiliing === " << ceilingMeters;
                parsedPolygons.append(std::make_tuple(polygon, strokeColor, strokeOpacity, id));
                zonePropsById.insert(id, properties);
                zoneBandById.insert(id, qMakePair(floorMeters, ceilingMeters));

                // Add CreatePolyhedron
                parsedNoFlyZone.append(std::make_tuple(polygon, floorMeters, ceilingMeters));
                {
                    AqgcZoneMeta zm;
                    QObject probe;
                    aqgcSetZoneInfo(&probe, properties, id);
                    zm.name = probe.property("zoneName").toString();
                    zm.cls  = probe.property("zoneClass").toInt();
                    parsedNoFlyMeta.append(zm);
                }

            }
        }

#if false
        else if (type == "Point") {
            QJsonArray coordPair = geometry["coordinates"].toArray();
            if (coordPair.size() < 2) continue;

            double lon = coordPair[0].toDouble();
            double lat = coordPair[1].toDouble();
            QGeoCoordinate center(lat, lon);

            double radiusMeters = 0.0;
            if (properties.contains("radius")) {
                radiusMeters = properties.value("radius").toString().toDouble();
            } else if (geometry.contains("radius")) {
                radiusMeters = geometry.value("radius").toString().toDouble();
            }

            // 중복 체크
            bool isDuplicate = false;
            for (const auto& existing : parsedCircles) {
                const QGeoCoordinate& existingCenter = std::get<0>(existing);
                double existingRadius = std::get<1>(existing);
                const QString& existingColor = std::get<2>(existing);
                const QString& existingOpacity = std::get<3>(existing);
                const QString& existingId = std::get<4>(existing);

                if (id == existingId) {
                    isDuplicate = true;
                    break;
                }

                if (existingCenter == center &&
                    qFuzzyCompare(existingRadius + 1, radiusMeters + 1) &&
                    existingColor == strokeColor &&
                    existingOpacity == strokeOpacity)
                {
                    isDuplicate = true;
                    break;
                }
            }

            if (!isDuplicate) {
                //qInfo() << "circle AltitudeCeiling === " << ceilingMeters;
                parsedCircles.append(std::make_tuple(center, radiusMeters, strokeColor, strokeOpacity, id));
            }
        }
#endif
    }

    QtConcurrent::run([=]() {
        try {
            generateNoFlyZones(parsedNoFlyZone, parsedNoFlyMeta);
        } catch (const std::exception& e) {
            qWarning() << "generateNoFlyZones Exception:" << e.what();
        } catch (...) {
            qWarning() << "generateNoFlyZones Unknown Exception";
        }
    });


    QMetaObject::invokeMethod(this, [=]() {
        for (const auto& polyData : parsedPolygons) {
            const QList<QGeoCoordinate>& coords = std::get<0>(polyData);
            const QString& strokeColor = std::get<1>(polyData);
            const QString& strokeOpacity = std::get<2>(polyData);
            const QString& id = std::get<3>(polyData);

            // _polygons 중복 확인 (id 기준)
            bool alreadyDrawn = false;
            for (int i = 0; i < _polygons.count(); ++i) {
                QGCFencePolygon* existing = qobject_cast<QGCFencePolygon*>(_polygons.get(i));
                if (!existing || existing->count() != coords.size())
                    continue;

                if (existing->objectName() == id) {
                    alreadyDrawn = true;
                    break;
                }

                bool same = true;
                for (int j = 0; j < coords.size(); ++j) {
                    if (existing->vertexCoordinate(j) != coords[j]) {
                        same = false;
                        break;
                    }
                }

                if (same) {
                    alreadyDrawn = true;
                    break;
                }
            }

            if (!alreadyDrawn) {
                QGCFencePolygon* polygon = new QGCFencePolygon(false, this);
                polygon->setObjectName(id);
                for (const QGeoCoordinate& coord : coords)
                    polygon->appendVertex(coord);
                polygon->setcolorInclusion(strokeColor);
                polygon->setstrokeOpacity(strokeOpacity.toDouble() / 2);
                aqgcSetZoneInfo(polygon, zonePropsById.value(id), id);
                if (zoneBandById.contains(id)) {
                    polygon->setAltitudeMin(zoneBandById.value(id).first);
                    polygon->setAltitudeMax(zoneBandById.value(id).second);
                }
                _polygons.append(polygon);
                qInfo() << "_polygons count == " << _polygons.count();
            }
        }
#if false
        for (const auto& tuple : parsedCircles) {
            const QGeoCoordinate& center = std::get<0>(tuple);
            double radius = std::get<1>(tuple);
            const QString& strokeColor = std::get<2>(tuple);
            const QString& strokeOpacity = std::get<3>(tuple);
            const QString& id = std::get<4>(tuple);

            bool alreadyDrawn = false;
            for (int i = 0; i < _circles.count(); ++i) {
                QGCFenceCircle* existing = qobject_cast<QGCFenceCircle*>(_circles.get(i));
                if (!existing)
                    continue;

                if (existing->objectName() == id) {
                    alreadyDrawn = true;
                    break;
                }

                if (qFuzzyCompare(static_cast<double>(existing->radius()->rawValue().toDouble()), static_cast<double>(radius)))
                {
                    alreadyDrawn = true;
                    break;
                }
            }

            if (!alreadyDrawn) {
                QGCFenceCircle* circle = new QGCFenceCircle(center, radius, false, this);
                circle->setObjectName(id);
                circle->setCenter(center);
                circle->setcolorInclusion(strokeColor);
                circle->setstrokeOpacity(strokeOpacity.toDouble() / 2);
                _circles.append(circle);
            }
        }
#endif
    }, Qt::QueuedConnection);

    logGeoMemoryUsage();
}


void FlightZoneManager::start(void){

    //Index 번호를 가져오는 듯함 0 = USB, 1 = Online
    QString dataType = _settingsManager->flyViewSettings()->dataType()->rawValueString();

    // AQGC Simple UI: always start from an empty set, then add the official data and the user's own zones (S32)
    removeAll();
    _setZoneError(QString());
    if(dataType == "0") // USB
    {
        if (!_settingsManager->flyViewSettings()->filePath()->rawValueString().isEmpty()) {
            processJsonFile(getFilePath());
        }
    }
    else // Online
    {
        getOnlineGeoJsonData();
    }
    _loadMyZones();
}

// Calculate -----------------------------------------------------------------------------------------------------------------------------------------------

// 줌 레벨 기반 1픽셀당 거리 계산
double calculateMetersPerPixel(double zoomLevel) {
    return EarthCircumference / (256 * std::pow(2, zoomLevel));
}

void FlightZoneManager::calculateCornerCoordinates(double centerLat, double centerLon, double zoomLevel,double width, double height) {

    // 1픽셀당 거리 계산
    double metersPerPixel = calculateMetersPerPixel(zoomLevel);

    // 위도와 경도 범위 계산
    double latitudeDelta = (width * metersPerPixel) / 111000.0; // 위도 범위
    double longitudeDelta = (height * metersPerPixel) / (111000.0 * std::cos(centerLat * M_PI / 180.0)); // 경도 범위

    // 꼭짓점 좌표 계산
    double topRightLat = centerLat + (latitudeDelta / 2);
    double topRightLon = centerLon + (longitudeDelta / 2);

    double bottomLeftLat = centerLat - (latitudeDelta / 2);
    double bottomLeftLon = centerLon - (longitudeDelta / 2);

    // 중심 ~ 꼭짓점 거리 측정
    QGeoCoordinate center(centerLat, centerLon);
    QGeoCoordinate topRight(topRightLat, topRightLon);
    double distanceToCorner = center.distanceTo(topRight);  // 미터 단위
    const double maxRadiusMeters = 20000.0;

    if (distanceToCorner > maxRadiusMeters) {
        qWarning() << "요청 범위가 너무 큽니다. 자동 축소 중...";

        // 축소 비율 계산
        double scale = maxRadiusMeters / distanceToCorner;

        // width/height 재계산 후 재귀 호출
        double scaledWidth = width * scale;
        double scaledHeight = height * scale;

        // 재귀 호출로 축소된 범위로 재시도
        calculateCornerCoordinates(centerLat, centerLon, zoomLevel, scaledWidth, scaledHeight);
        return;
    }

    //Draw Line
    fetchGeoJsonDataForRegion(topRightLat, topRightLon, bottomLeftLat, bottomLeftLon);
}

void FlightZoneManager::getOnlineGeoJsonData() {

    //지도의 현재위치에 따른 지도의 꼭짓점 좌표를 가져온다

    //현재 지도 좌표
    QGeoCoordinate mapCoord = qGroundControlQmlGlobal->flightMapPosition();

    //현재 줌값
    double zoom = qGroundControlQmlGlobal->flightMapZoom();

    //계산식

    QQuickWindow* rootWindow = qgcApp()->mainRootWindow();
    double rootWindowWidth = rootWindow->width();
    double rootWindowHeight = rootWindow->height();

    calculateCornerCoordinates(mapCoord.latitude(), mapCoord.longitude(), zoom, rootWindowWidth, rootWindowHeight);
}

// ---------------------------------------------------------------------------------------------- AQGC Simple UI (S46)

static QString aqgcOfficialZoneDir()
{
    return qgcApp()->toolbox()->settingsManager()->appSettings()->geoZoneSavePath() + QStringLiteral("/Official");
}

void FlightZoneManager::reload()
{
    removeAll();
    start();
}

QString FlightZoneManager::importZoneFile(const QString& path)
{
    const QString src = path.startsWith(QStringLiteral("file:")) ? QUrl(path).toLocalFile() : path;
    QFile file(src);
    if (!file.open(QIODevice::ReadOnly)) {
        return tr("The file cannot be opened.");
    }
    const QByteArray data = file.readAll();
    file.close();

    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &err);
    if (doc.isNull() || !doc.isObject()) {
        return tr("This is not a GeoJSON file (%1).").arg(err.errorString());
    }
    const QJsonArray features = doc.object().value("features").toArray();
    int areas = 0;
    for (const QJsonValue& f : features) {
        const QString t = f.toObject().value("geometry").toObject().value("type").toString();
        if (t == QStringLiteral("Polygon") || t == QStringLiteral("MultiPolygon")) {
            areas++;
        }
    }
    if (areas == 0) {
        return tr("The file has no zone areas (GeoJSON Polygon or MultiPolygon features).");
    }

    QDir().mkpath(aqgcOfficialZoneDir());
    const QString dst = aqgcOfficialZoneDir() + QStringLiteral("/") + QFileInfo(src).fileName();
    if (QFileInfo(src).absoluteFilePath() != QFileInfo(dst).absoluteFilePath()) {
        QFile::remove(dst);
        if (!QFile::copy(src, dst)) {
            return tr("The file cannot be copied to the app folder.");
        }
    }
    {
        QFile stamp(dst);                   // "updated" date = import date (setFileTime needs an open file)
        if (stamp.open(QIODevice::ReadWrite)) {
            stamp.setFileTime(QDateTime::currentDateTime(), QFileDevice::FileModificationTime);
            stamp.close();
        }
    }

    // remove the previous imported file if it was another one in the same folder
    const QString previous = _settingsManager->flyViewSettings()->filePath()->rawValueString();
    if (!previous.isEmpty() && QFileInfo(previous).absolutePath() == QFileInfo(dst).absolutePath()
            && QFileInfo(previous).absoluteFilePath() != QFileInfo(dst).absoluteFilePath()) {
        QFile::remove(previous);
    }
    _settingsManager->flyViewSettings()->filePath()->setRawValue(dst);
    _settingsManager->flyViewSettings()->dataType()->setRawValue(0);
    reload();
    return QString();
}

void FlightZoneManager::deleteZoneData()
{
    const QString current = _settingsManager->flyViewSettings()->filePath()->rawValueString();
    if (!current.isEmpty() && QFileInfo(current).absolutePath() == QFileInfo(aqgcOfficialZoneDir() + "/x").absolutePath()) {
        QFile::remove(current);
    }
    _settingsManager->flyViewSettings()->filePath()->setRawValue(QString());
    reload();                               // empty official data, My zones loaded again
}

QDateTime FlightZoneManager::zoneFileTime() const
{
    const QString current = _settingsManager->flyViewSettings()->filePath()->rawValueString();
    const QFileInfo fi(current);
    return fi.exists() ? fi.lastModified() : QDateTime();
}

void FlightZoneManager::_setZoneStatus(int level, double distance, const QString& name, int zoneClass, bool noEntry)
{
    const bool changed = level != _zoneLevel || name != _zoneStatusName || zoneClass != _zoneStatusClass || noEntry != _zoneStatusNoEntry;
    _zoneLevel = level;
    _zoneDistance = distance;
    _zoneStatusName = name;
    _zoneStatusClass = zoneClass;
    _zoneStatusNoEntry = noEntry;
    emit zoneStatusChanged();
    if (changed) {
        qInfo() << "Flight zone status: level" << level << "distance" << distance << "zone" << name << "class" << zoneClass << "noEntry" << noEntry;
    }
    // Simple UI: speak in flight when the warning gets stronger (inside > near, then prohibited > other)
    const bool prohibited = zoneClass == 1 || noEntry;
    const int rank = level == 0 ? 99 : (level == 2 ? 0 : 10) + (prohibited ? 0 : 1);
    if (level == 0) {
        _spokenRank = 99;
        return;
    }
    Vehicle* vehicle = qgcApp()->toolbox()->multiVehicleManager()->activeVehicle();
    if (rank < _spokenRank && vehicle && vehicle->flying() && !qgcApp()->toolbox()->corePlugin()->showAdvancedUI()) {
        _spokenRank = rank;
        qgcApp()->toolbox()->audioOutput()->say(level == 2
            ? (prohibited ? tr("Inside a prohibited zone") : tr("Inside a flight zone"))
            : (prohibited ? tr("Prohibited zone ahead") : tr("Flight zone ahead")));
    }
}

// ---------------------------------------------------------------------------------------------- AQGC Simple UI checks
// 2D checks for S02 (drone position) and S39 (mission path). Order: prohibited / no-entry my zone, authorisation,
// warn-only my zone, information. noEntry marks a "do not enter" zone (red like prohibited).

static int aqgcCheckRank(int cls, bool noEntry) { return (cls == 1 || noEntry) ? 0 : cls == 2 ? 1 : cls == 4 ? 2 : 3; }

static QPolygonF aqgcPolygonF(const QGCFencePolygon* p)
{
    QPolygonF poly;
    for (const QGeoCoordinate& c : p->coordinateList()) {
        poly << QPointF(c.longitude(), c.latitude());
    }
    return poly;
}

static bool aqgcSegmentTouchesPolygon(const QPolygonF& poly, const QPointF& a, const QPointF& b)
{
    if (poly.size() < 3) return false;
    if (poly.containsPoint(a, Qt::OddEvenFill) || poly.containsPoint(b, Qt::OddEvenFill)) return true;
    const QLineF seg(a, b);
    for (int i = 0; i < poly.size(); ++i) {
        const QLineF edge(poly[i], poly[(i + 1) % poly.size()]);
        QPointF ip;
        if (seg.intersects(edge, &ip) == QLineF::BoundedIntersection) return true;
    }
    return false;
}

static double aqgcSegmentDistanceToPoint(const QGeoCoordinate& a, const QGeoCoordinate& b, const QGeoCoordinate& p)
{
    // local flat approximation (fine for zone sized distances)
    const double k = std::cos(p.latitude() * M_PI / 180.0);
    const QPointF A((a.longitude() - p.longitude()) * k * 111320.0, (a.latitude() - p.latitude()) * 111320.0);
    const QPointF B((b.longitude() - p.longitude()) * k * 111320.0, (b.latitude() - p.latitude()) * 111320.0);
    const QPointF d = B - A;
    const double len2 = d.x() * d.x() + d.y() * d.y();
    double t = len2 > 0 ? -(A.x() * d.x() + A.y() * d.y()) / len2 : 0;
    t = std::max(0.0, std::min(1.0, t));
    const QPointF q = A + t * d;
    return std::sqrt(q.x() * q.x() + q.y() * q.y());
}

static QVariantMap aqgcZoneResult(QObject* z)
{
    QVariantMap m;
    m["zoneClass"] = z ? z->property("zoneClass").toInt() : 0;
    m["zoneName"]  = z ? z->property("zoneName").toString() : QString();
    m["noEntry"]   = z ? z->property("zoneNoEntry").toBool() : false;
    return m;
}

QVariantMap FlightZoneManager::zoneAt(const QGeoCoordinate& coordinate)
{
    QObject* best = nullptr;
    int bestRank = 99;
    if (coordinate.isValid()) {
        const QPointF pt(coordinate.longitude(), coordinate.latitude());
        for (int i = 0; i < _polygons.count(); ++i) {
            auto* p = qobject_cast<QGCFencePolygon*>(_polygons.get(i));
            if (!p || !aqgcPolygonF(p).containsPoint(pt, Qt::OddEvenFill)) continue;
            const int r = aqgcCheckRank(p->property("zoneClass").toInt(), p->property("zoneNoEntry").toBool());
            if (r < bestRank) { bestRank = r; best = p; }
        }
        for (int i = 0; i < _circles.count(); ++i) {
            auto* ci = qobject_cast<QGCFenceCircle*>(_circles.get(i));
            if (!ci || ci->center().distanceTo(coordinate) > ci->radius()->rawValue().toDouble()) continue;
            const int r = aqgcCheckRank(ci->property("zoneClass").toInt(), ci->property("zoneNoEntry").toBool());
            if (r < bestRank) { bestRank = r; best = ci; }
        }
    }
    return aqgcZoneResult(best);
}

QVariantMap FlightZoneManager::zoneOnPath(const QVariantList& path)
{
    QList<QGeoCoordinate> pts;
    for (const QVariant& v : path) {
        const QGeoCoordinate c = v.value<QGeoCoordinate>();
        if (c.isValid()) pts << c;
    }
    QObject* best = nullptr;
    int bestRank = 99;
    for (int i = 0; i < _polygons.count(); ++i) {
        auto* p = qobject_cast<QGCFencePolygon*>(_polygons.get(i));
        if (!p) continue;
        const int r = aqgcCheckRank(p->property("zoneClass").toInt(), p->property("zoneNoEntry").toBool());
        if (r >= bestRank) continue;
        const QPolygonF poly = aqgcPolygonF(p);
        bool hit = false;
        for (int j = 0; j < pts.size() && !hit; ++j) {
            const QPointF a(pts[j].longitude(), pts[j].latitude());
            const QPointF b = j + 1 < pts.size() ? QPointF(pts[j + 1].longitude(), pts[j + 1].latitude()) : a;
            hit = aqgcSegmentTouchesPolygon(poly, a, b);
        }
        if (hit) { bestRank = r; best = p; }
    }
    for (int i = 0; i < _circles.count(); ++i) {
        auto* ci = qobject_cast<QGCFenceCircle*>(_circles.get(i));
        if (!ci) continue;
        const int r = aqgcCheckRank(ci->property("zoneClass").toInt(), ci->property("zoneNoEntry").toBool());
        if (r >= bestRank) continue;
        const double rad = ci->radius()->rawValue().toDouble();
        for (int j = 0; j < pts.size(); ++j) {
            const QGeoCoordinate& a = pts[j];
            const QGeoCoordinate& b = j + 1 < pts.size() ? pts[j + 1] : pts[j];
            if (aqgcSegmentDistanceToPoint(a, b, ci->center()) <= rad) { bestRank = r; best = ci; break; }
        }
    }
    return aqgcZoneResult(best);
}

// ---------------------------------------------------------------------------------------------- AQGC Simple UI: My zones (S32)
// Stored as GeoJSON in <GeoZone>/MyZones/my-zones.geojson (not the Custom folder, which is deleted after 24 h).
// properties: name, aqgcAction ("noEntry" | "warn"), warnDistance (m); geometry.layer lower / upper (m, AGL).

static QString aqgcMyZonesFile()
{
    return qgcApp()->toolbox()->settingsManager()->appSettings()->geoZoneSavePath() + QStringLiteral("/MyZones/my-zones.geojson");
}

QVariantList FlightZoneManager::myZones()
{
    QVariantList out;
    QFile f(aqgcMyZonesFile());
    if (!f.open(QIODevice::ReadOnly)) return out;
    const QJsonArray features = QJsonDocument::fromJson(f.readAll()).object().value("features").toArray();
    for (const QJsonValue& fv : features) {
        const QJsonObject feat = fv.toObject();
        const QJsonObject props = feat.value("properties").toObject();
        const QJsonObject geom = feat.value("geometry").toObject();
        const QJsonArray ring = geom.value("coordinates").toArray().at(0).toArray();
        QVariantList path;
        for (int i = 0; i < ring.size(); ++i) {
            const QJsonArray pt = ring.at(i).toArray();
            if (i == ring.size() - 1 && ring.size() > 3 && pt == ring.at(0).toArray()) break;   // closing point
            path << QVariant::fromValue(QGeoCoordinate(pt.at(1).toDouble(), pt.at(0).toDouble()));
        }
        if (path.size() < 3) continue;
        const QJsonObject layer = geom.value("layer").toObject();
        QVariantMap z;
        z["name"]        = props.value("name").toString();
        z["noEntry"]     = props.value("aqgcAction").toString() == QStringLiteral("noEntry");
        z["warnDistance"]= props.value("warnDistance").toDouble(30);
        z["floor"]       = layer.value("lower").toDouble(0);
        z["ceiling"]     = layer.value("upper").toDouble(120);
        z["path"]        = path;
        out << z;
    }
    return out;
}

bool FlightZoneManager::saveMyZones(const QVariantList& zones)
{
    QJsonArray features;
    int n = 0;
    for (const QVariant& zv : zones) {
        const QVariantMap z = zv.toMap();
        const QVariantList path = z.value("path").toList();
        if (path.size() < 3) continue;
        QJsonArray ring;
        for (const QVariant& pv : path) {
            const QGeoCoordinate c = pv.value<QGeoCoordinate>();
            ring.append(QJsonArray{c.longitude(), c.latitude()});
        }
        ring.append(ring.at(0));
        QJsonObject props{{"name", z.value("name").toString()},
                          {"aqgcAction", z.value("noEntry").toBool() ? "noEntry" : "warn"},
                          {"warnDistance", z.value("warnDistance").toDouble()}};
        QJsonObject layer{{"lower", z.value("floor").toDouble()}, {"upper", z.value("ceiling").toDouble()},
                          {"uom", "m"}, {"lowerReference", "AGL"}, {"upperReference", "AGL"}};
        QJsonArray rings;               // GeoJSON Polygon: array of rings (QJsonArray{ring} would copy the ring itself)
        rings.append(ring);
        QJsonObject geom{{"type", "Polygon"}, {"coordinates", rings}, {"layer", layer}};
        features.append(QJsonObject{{"type", "Feature"}, {"id", QStringLiteral("MYZONE-%1").arg(++n)},
                                    {"properties", props}, {"geometry", geom}});
    }
    QDir().mkpath(QFileInfo(aqgcMyZonesFile()).absolutePath());
    QFile f(aqgcMyZonesFile());
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return false;
    f.write(QJsonDocument(QJsonObject{{"type", "FeatureCollection"}, {"features", features}}).toJson());
    f.close();
    _reloadMyZones();                       // the official data stays as it is
    return true;
}

void FlightZoneManager::_loadMyZones()
{
    const QVariantList zones = myZones();
    _myZoneCache = zones;
    emit myZonesChanged();
    QList<Polyhedron> polys;
    QList<AqgcZoneMeta> metas;
    for (const QVariant& zv : zones) {
        const QVariantMap z = zv.toMap();
        const QVariantList path = z.value("path").toList();
        auto* poly = new QGCFencePolygon(false, this);
        QList<NoFlyZone> nfz;
        for (const QVariant& pv : path) {
            const QGeoCoordinate c = pv.value<QGeoCoordinate>();
            poly->appendVertex(c);
            nfz.append(NoFlyZone(c, z.value("floor").toDouble(), z.value("ceiling").toDouble()));
        }
        poly->setAltitudeMin(z.value("floor").toDouble());
        poly->setAltitudeMax(z.value("ceiling").toDouble());
        poly->setProperty("zoneName", z.value("name").toString());
        poly->setProperty("zoneClass", 4);
        poly->setProperty("zoneNoEntry", z.value("noEntry").toBool());
        poly->setProperty("zoneDetail", z.value("noEntry").toBool() ? tr("Do not enter") : tr("Warn only"));
        poly->setcolorInclusion(z.value("noEntry").toBool() ? QColor("#c9353d") : QColor("#f5a524"));
        poly->setstrokeOpacity(0.5);
        _polygons.append(poly);
        Polyhedron ph = createPolyhedronFromZone(nfz);
        if (!ph.empty()) {
            polys.append(std::move(ph));
            metas.append({z.value("name").toString(), 4, z.value("warnDistance").toDouble(), z.value("noEntry").toBool(), false});
        }
    }
    if (!polys.isEmpty()) {
        QWriteLocker locker(&_zoneLock);
        _noFlyZoneList.append(polys);
        _noFlyZoneMeta.append(metas);
        buildZoneTrees(_noFlyZoneList, _zoneAABBTree);
    }
}

int FlightZoneManager::applyMyZonesToFence(QObject* geoFenceController)
{
    auto* fence = qobject_cast<GeoFenceController*>(geoFenceController);
    if (!fence) return -1;
    QmlObjectListModel* polys = fence->polygons();
    for (int i = polys->count() - 1; i >= 0; --i) {
        auto* p = qobject_cast<QGCFencePolygon*>(polys->get(i));
        if (p && !p->inclusion()) {
            fence->deletePolygon(i);
        }
    }
    int n = 0;
    for (const QVariant& zv : myZones()) {
        const QVariantMap z = zv.toMap();
        if (!z.value("noEntry").toBool()) continue;
        auto* p = new QGCFencePolygon(false /* exclusion */, fence);
        for (const QVariant& pv : z.value("path").toList()) {
            p->appendVertex(pv.value<QGeoCoordinate>());
        }
        // keep the zone's height band: ARGOSDYNE firmware supports 3D exclusion polygons (relative to home)
        p->setAltitudeFrame(MAV_FRAME_GLOBAL_RELATIVE_ALT);
        p->setAltitudeMin(z.value("floor").toDouble());
        p->setAltitudeMax(z.value("ceiling").toDouble());
        p->setAltitudeBandEnabled(true);
        polys->append(p);
        ++n;
    }
    return n;
}

int FlightZoneManager::uploadMyZonesFence(QObject* geoFenceController)
{
    auto* fence = qobject_cast<GeoFenceController*>(geoFenceController);
    if (!fence || fence->syncInProgress()) {
        return -2;                          // busy (e.g. still loading the fence after connecting): try again
    }
    const int n = applyMyZonesToFence(geoFenceController);
    if (n >= 0) {
        qobject_cast<GeoFenceController*>(geoFenceController)->sendToVehicle();
    }
    return n;
}

int FlightZoneManager::_officialPolygonCount()
{
    int n = 0;
    for (int i = 0; i < _polygons.count(); ++i) {
        QObject* p = _polygons.get(i);
        if (p && p->property("zoneClass").toInt() != 4) n++;
    }
    return n + _circles.count();
}

static void aqgcRemoveZones(QmlObjectListModel& polys, QList<Polyhedron>& list, QList<AqgcZoneMeta>& meta, bool myZones)
{
    for (int i = polys.count() - 1; i >= 0; --i) {
        QObject* p = polys.get(i);
        if (p && (p->property("zoneClass").toInt() == 4) == myZones) {
            polys.removeAt(i)->deleteLater();
        }
    }
    for (int i = qMin(list.size(), meta.size()) - 1; i >= 0; --i) {
        if ((meta[i].cls == 4) == myZones) {
            list.removeAt(i);
            meta.removeAt(i);
        }
    }
}

void FlightZoneManager::_reloadMyZones()
{
    {
        QWriteLocker locker(&_zoneLock);
        aqgcRemoveZones(_polygons, _noFlyZoneList, _noFlyZoneMeta, true);
        buildZoneTrees(_noFlyZoneList, _zoneAABBTree);
    }
    _loadMyZones();
}

void FlightZoneManager::_removeOfficialZones()
{
    QWriteLocker locker(&_zoneLock);
    aqgcRemoveZones(_polygons, _noFlyZoneList, _noFlyZoneMeta, false);
    _circles.clearAndDeleteContents();
    buildZoneTrees(_noFlyZoneList, _zoneAABBTree);
}

void FlightZoneManager::_setZoneError(const QString& error)
{
    if (error != _zoneError) {
        _zoneError = error;
        emit zoneErrorChanged();
    }
}

