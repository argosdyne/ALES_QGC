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

#include "JsonHelper.h"
#include "FlyViewSettings.h"
#include "QGCApplication.h"
#include "QGroundControlQmlGlobal.h"
#include <QQuickWindow>
#include <QScreen>

#include <CGAL/Simple_cartesian.h>
#include <CGAL/Polyhedron_3.h>
#include <CGAL/AABB_tree.h>
#include <CGAL/AABB_traits_3.h>
#include <CGAL/AABB_face_graph_triangle_primitive.h>
#include <iostream>
#include <fstream>
#include <cmath>
#include <QDir>

#include "CustomQmlInterface.h"

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
//QList<AABB_tree> _AABBZoneList;

QReadWriteLock _zoneLock; // 클래스 멤버로 선언

struct GeoZone {
    Polyhedron polyhedron;
    std::shared_ptr<AABB_tree> tree; // 캐시된 트리
};

QList<GeoZone> _geoZoneList;  // _noFlyZoneList 대체

std::vector<Triangle_3> _zoneTriangles;
std::vector<AABB_tree> _zoneAABBTree;

//모든 그룹
QList<QList<NoFlyZone>> allNoFlyZones;

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
        {
            QReadLocker locker(&_zoneLock);
            noFlyZones = _noFlyZoneList;        // Polyhedron 리스트 복사
        }

        // 백그라운드에서 거리 계산
        QtConcurrent::run([=]() {
            try {
                checkDroneAndGeoZoneSafe(noFlyZones, droneLat, droneLon, droneAlt, alarmDistance);
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
}

void FlightZoneManager::autoDeleteUSBFile() {

    QString folderPath = _settingsManager->appSettings()->geoZoneSavePath();
    QDir dir(folderPath);
    if (!dir.exists()) {
        qWarning() << "폴더가 존재하지 않습니다:" << folderPath;
        return;
    }

    // 폴더 내의 모든 파일 목록 가져오기
    QFileInfoList fileList = dir.entryInfoList(QDir::Files | QDir::NoSymLinks);
    QDateTime currentTime = QDateTime::currentDateTime();

    for (const QFileInfo& fileInfo : fileList) {
        QDateTime lastModified = fileInfo.lastModified();
        qint64 diffSecs = lastModified.secsTo(currentTime);

        if (diffSecs >= 86400) { // 24시간 이상 경과
            QString filePath = fileInfo.absoluteFilePath();
            if (QFile::remove(filePath)) {
                qInfo() << "삭제됨:" << filePath;
            } else {
                qInfo() << "삭제 실패:" << filePath;
            }
        } else {
            qInfo() << "유지됨(24시간 미만):" << fileInfo.fileName();
        }
    }
}

void FlightZoneManager::onReplyFinished(QNetworkReply *reply) {
    if (reply->error() == QNetworkReply::NoError) {
        QByteArray responseData = reply->readAll();
        QJsonDocument jsonDoc = QJsonDocument::fromJson(responseData);

        if (!jsonDoc.isNull()) {
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
            QString msg = "Cannot access GeoZone data.<br>Please check local files or internet connection.";
            CustomQmlInterface::instance()->geoAwarenessMessage(msg);
        }
    } else {
        QString msg = "Cannot access GeoZone data.<br>Please check local files or internet connection.";
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

    // ⬆️ 윗면 (삼각형으로 구성)
    for (size_t i = 1; i < half_size - 1; ++i) {
        builder.begin_facet();
        builder.add_vertex_to_facet(v_indices[0]);
        builder.add_vertex_to_facet(v_indices[i + 1]);
        builder.add_vertex_to_facet(v_indices[i]);
        builder.end_facet();
    }

    // ⬇️ 아랫면 (삼각형으로 구성)
    for (size_t i = 1; i < half_size - 1; ++i) {
        builder.begin_facet();
        builder.add_vertex_to_facet(v_indices[half_size]);
        builder.add_vertex_to_facet(v_indices[half_size + i]);
        builder.add_vertex_to_facet(v_indices[half_size + i + 1]);
        builder.end_facet();
    }

    // 🔄 측면 (각 변을 두 개의 삼각형으로 구성)
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

void FlightZoneManager::generateNoFlyZones(QList<std::tuple<QList<QGeoCoordinate>, double, double>> parsedPolygons)
{
    try {
        if (parsedPolygons.count() > 0) {
            for (const auto& polyData : parsedPolygons) {
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

                    // ✅ 밑면을 먼저 추가
                    vertices.insert(vertices.end(), baseVertices.begin(), baseVertices.end());

                    // ✅ 윗면을 나중에 추가
                    vertices.insert(vertices.end(), topVertices.begin(), topVertices.end());

                    createPolyhedron(vertices, polyhedron);

                    if (polyhedron.empty()) {
                        qWarning() << "빈 폴리곤입니다.";
                        return;
                    }

                    QWriteLocker locker(&_zoneLock);
                    if (!containsPolyhedron(_noFlyZoneList, polyhedron)) {
                        _noFlyZoneList.append(polyhedron);
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
    //_zoneAABBTree.clear();

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
        AABB_tree tree(range.begin(), range.end(), poly);
        //AABB_tree tree(faces(poly).begin(), faces(poly).end(), poly);
        tree.accelerate_distance_queries();

        int faceCount = std::distance(poly.faces_begin(), poly.faces_end());
        qDebug() << "poly face count:" << faceCount;

        if (tree.size() == 0) {
            qWarning() << "AABB tree contains no primitives, skipping.";
            continue;
        }


        _zoneAABBTree.push_back(std::move(tree));
    }
}



Point_3 FlightZoneManager::approximatePolyhedronCenter(const Polyhedron& poly) {
    CGAL::Bbox_3 bbox = CGAL::bbox_3(poly.points_begin(), poly.points_end());
    double cx = (bbox.xmin() + bbox.xmax()) / 2.0;
    double cy = (bbox.ymin() + bbox.ymax()) / 2.0;
    double cz = (bbox.zmin() + bbox.zmax()) / 2.0;
    return Point_3(cx, cy, cz);
}



void FlightZoneManager::checkDroneAndGeoZoneSafe(const QList<Polyhedron>& zoneList,
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
                    Point_3 dronePoint = latLonAltToCartesian(droneLat, droneLon, droneAlt);

                    //Point_3 dronePoint = latLonAltToCartesian(lat, lon, alt);

                    for (const Polyhedron& poly : zoneList) {

                        bool inside = checkPointInsidePolyhedron(poly, dronePoint);
                        if (inside) {
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

                        if(minDist > alarmDistance + 200) {
                            continue;
                        }

                        //qInfo() << "minDist == " << minDist;

                        // 4. 진짜로 가까운 경우에만 AABB_tree 생성
                        AABB_tree tree(faces(poly).first, faces(poly).second, poly);
                        tree.accelerate_distance_queries();

                        double exactDist = std::sqrt(tree.squared_distance(dronePoint));

                        if (exactDist <= alarmDistance) {
                            QString msg = QString("The distance between the aircraft and GeoZone is close. Distance : %1M").arg(exactDist);
                            QMetaObject::invokeMethod(CustomQmlInterface::instance(), [msg]() {
                                CustomQmlInterface::instance()->geoAwarenessMessage(msg);
                            }, Qt::QueuedConnection);
                        }
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
        MultiVehicleManager* manager = qgcApp()->toolbox()->multiVehicleManager();
        if(manager){
            if(manager->activeVehicle()){
                if(allNoFlyZones.count() > 0) {
                    for(int i = 0; i < allNoFlyZones.count(); i++) {
                        //qInfo() << "Group : " << i + 1;
                        std::vector<Point_3> vertices;
                        std::vector<Point_3> baseVertices; // Bottom
                        std::vector<Point_3> topVertices; //Top
                        Polyhedron P; // 거리측정
                        Polyhedron polyhedron; // 내부 측정

                        for(const NoFlyZone& zone: allNoFlyZones[i]){
                            // qInfo() << "  Coordinate:" << zone.coordinate.latitude() << zone.coordinate.longitude()
                            // << "Altitude Range:" << zone.altitudeFloor << "-" << zone.altitudeCeiling;
                            double lat = zone.coordinate.latitude();
                            double lon = zone.coordinate.longitude();
                            double floor = zone.altitudeFloor;
                            double ceiling = zone.altitudeCeiling;

                            if(floor == 0 && ceiling == 0) {
                                floor = 0;
                                ceiling = 100000;
                            }

                            baseVertices.push_back(latLonAltToCartesian(lat,lon,floor));

                            topVertices.push_back(latLonAltToCartesian(lat,lon,ceiling));
                        }

                        if(baseVertices.size() > 0 && topVertices.size() > 0) {

                            // 거리 측정
                            // Create bottom face (base polygon)
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

                            AABB_tree tree(faces(P).first, faces(P).second, P);
                            tree.accelerate_distance_queries();

                            // ✅ 밑면을 먼저 추가
                            vertices.insert(vertices.end(), baseVertices.begin(), baseVertices.end());

                            // ✅ 윗면을 나중에 추가
                            vertices.insert(vertices.end(), topVertices.begin(), topVertices.end());

                            createPolyhedron(vertices, polyhedron);

                            // Drone's position (lat/lon/alt) for example
                            double droneLat = 0.0;  // Drone's latitude
                            double droneLon = 0.0; // Drone's longitude
                            double droneAlt = 0.0;  // Drone's altitude

                            droneLat = manager->activeVehicle()->latitude();
                            droneLon = manager->activeVehicle()->longitude();
                            //droneAlt = manager->activeVehicle()->altitudeAMSL()->rawValue().toDouble();

                            droneAlt = manager->activeVehicle()->altitudeRelative()->rawValue().toDouble();

                            if (std::isnan(droneLat) || std::isnan(droneLon) || std::isnan(droneAlt)) {
                                //qWarning() << "Received NaN for vehicle position. Using default values.";
                                droneLat = 0.0; // Default values to handle the NaN case
                                droneLon = 0.0;
                                droneAlt = 0.0;
                            }

                            // 등록한 드론의 위치를 가져와야함

                            // Convert drone's position to Cartesian coordinates
                            Point_3 dronePosition = latLonAltToCartesian(droneLat, droneLon, droneAlt);

                            // Query the distance between the drone's position and the polyhedron
                            double distance = std::sqrt(tree.squared_distance(dronePosition)); // distance in meters
                            //std::cout << "Shortest distance from the drone to the polyhedron is: " << distance << " meters" << std::endl;

                            bool ret = checkPointInsidePolyhedron(polyhedron, dronePosition);

                            if(ret == true) // Drone is Inside polyhedron
                            {
                                //QString msg = tr("Drone is inside GeoAwareness! Group : %1").arg(i);
                                QString msg  = "Drone is inside GeoZone!";
                                //qgcApp()->showGeoAwarenessAlertMessage(msg, i);
                                CustomQmlInterface::instance()->geoAwarenessMessage(msg);
                            }
                            else // Drone is out side polyhedron
                            {
                                if(distance <= alarmDistance) // 지정한 거리값 안에 들어오면 알람을 띄워야됨
                                {
                                    //qInfo() << "Inside Index = " << i;
                                    QString msg = tr("The distance between the aircraft and GeoZone is close. Distance : %1M").arg(distance);
                                    //qgcApp()->showAppMessage(msg);
                                    //qgcApp()->showGeoAwarenessAlertMessage(msg, i);
                                    CustomQmlInterface::instance()->geoAwarenessMessage(msg);
                                }
                                else {
                                    //qInfo() << "FlightZoneManager Close AlertMessage Popup Index = " << i;
                                    //qgcApp()->closeGeoAwarenessAlertMessage(i);
                                }
                            }
                        }
                    }
                }
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
    allNoFlyZones.clear();
    QWriteLocker locker(&_zoneLock);
    _noFlyZoneList.clear();

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
            if(_polygons.count() == 0) { // 이미 생성되어 있음

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
                if(_polygons.count() > 0){                // 위치 새로고침 후 생성
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
            removeAll();

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
                allNoFlyZones.removeAt(i);
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

            if(!allNoFlyZones.contains(noFlyZone)){
                allNoFlyZones.append(noFlyZone);
            }
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

            if(!allNoFlyZones.contains(noFlyZone)) {
                allNoFlyZones.append(noFlyZone);
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

    //File이 없다면 온라인에서 읽어오도록 하는게 맞을듯함
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        QString msg = "Cannot access GeoZone data.<br>Please check local files or internet connection.";
        CustomQmlInterface::instance()->geoAwarenessMessage(msg);
        return;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) {
        qWarning() << "Invalid JSON format";
        QString msg = "Cannot access GeoZone data.<br>Please check local files or internet connection.";
        CustomQmlInterface::instance()->geoAwarenessMessage(msg);
        return;
    }

    QJsonObject root = doc.object();

    QJsonArray features = findJsonValue(doc.isObject() ? QJsonValue(doc.object()) : QJsonValue(doc.array()), "features").toArray();
    //qInfo() << "featuresValue Count = " << featuresValue.count();

    //QJsonArray features = root.value("features").toArray();

    validTimeList.clear();
    QDateTime currentTime = QDateTime::currentDateTime(); // 현재 시간

    QJsonArray reversedFeatures;
    for (int i = features.size() - 1; i >= 0; --i) {
        reversedFeatures.append(features[i]);
    }

    qInfo() << "features count = " << features.count();
    qInfo() << "reversedFeatures count = " << reversedFeatures.count();

    //int cnt = 0;
    for (const QJsonValue& feature : reversedFeatures) {

        if (!feature.isObject()) continue;

        // if(_polygons.count() > 191)
        //     continue;

        QJsonObject featureObj = feature.toObject();
        QJsonObject geometry = featureObj.value("geometry").toObject();
        QJsonObject properties = featureObj.value("properties").toObject();

        //qint64 polygonid = featureObj.value("id").toInt(); //Int 타입
        //qint64 polygonid = 0; // Test

        if (geometry.value("type").toString() != "Polygon" && geometry.value("type").toString() != "MultiPolygon") continue;

        QJsonArray coordinates = geometry.value("coordinates").toArray();
        //qInfo() << "Coord count = " << coordinates.count();
        //if (coordinates.isEmpty() || coordinates.count() > 5) continue;
        if(coordinates.isEmpty()) continue;

        if(coordinates.count() > 10) {
            for(int i = 0; i < coordinates.count(); i++){
                //   qInfo() << "Coord: " << coordinates[i];
            }
        }

        QString zoneType = properties.value("zone_type").toString();
        QString validFrom = properties.value("valid_from").toString() == "" ? currentTime.toString() : currentTime.toString();
        QString validTo = properties.value("valid_to").toString() == "" ? currentTime.addYears(1).toString() : currentTime.addYears(1).toString();
        // double altitudeFloor = properties.value("altitudeFloor").toDouble() ;
        // double altitudeCeiling = properties.value("altitudeCeiling").toDouble();

        // qInfo() << "validFrom = " << validFrom;
        // qInfo() << "validTo = " << validTo;

        QDateTime validFromDateTime = QDateTime::fromString(validFrom, "yyyy-MM-dd HH:mm:ss");
        QDateTime validToDateTime = QDateTime::fromString(validTo, "yyyy-MM-dd HH:mm:ss");

        QGCFencePolygon* polygon = new QGCFencePolygon(false /* inclusion */, this); // true = not fill , false = fill
        QList<NoFlyZone> noFlyZone;



#if false // 테스트용으로 읽어오는 부분 작성

        //테스트용 데이터
        double altitudeFloor = 0;
        double altitudeCeiling = 1000;

        QString type = geometry.value("type").toString();
        //qInfo() << "Type = "<< type;

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
        if(type == "MultiPolygon") {
            MultiVehicleManager* manager = qgcApp()->toolbox()->multiVehicleManager();

            if(manager){
                QVariantList polygonList;
                for (const QJsonValue& polyValue : coordinates) {
                    if (!polyValue.isArray()) continue;
                    QJsonArray polygonArray = polyValue.toArray();   // polygon 하나

                    //subPolygon->setInclusion(polygon->inclusion());

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
                                polygon->appendVertex(coord);
                                noFlyZone.append(NoFlyZone(coord, altitudeFloor, altitudeCeiling));

                            }
                        }
                    }


                    polygon->setcolorInclusion("red");
                    polygon->setstrokeOpacity(0.7);

                    if(!allNoFlyZones.contains(noFlyZone)){
                        allNoFlyZones.append(noFlyZone);
                    }
                    // **FlightZoneManager의 _polygons 리스트에 추가**
                    if (!_polygons.contains(polygon))
                        _polygons.append(polygon);

                    //qInfo() << "Add allNoFlyZones = " << allNoFlyZones.count();
                    //qInfo() << "Added MultiPolygon[" << polyIndex++ << "] vertex count =" << subPolygon->count();
                }
            }
        }
#endif

        parseGeometryAndSave(
            geometry,
            polygon,
            noFlyZone,
            0, //test
            1000, //test
            validFrom,
            validTo
            );


        //qInfo() << "Current Index = " << cnt++;


        // polygon->setcolorInclusion("red");

        // polygon->setstrokeOpacity(1);

        // if(!_polygons.contains(polygon)){

        //     _polygons.append(polygon);
        // }

        //qInfo() << "_polygons count = " << _polygons.count();

        // for (const QJsonValue& ring : coordinates) {
        //     if (!ring.isArray()) continue;

        //     QJsonArray points = ring.toArray();
        //     for (const QJsonValue& point : points) {
        //         if (!point.isArray()) continue;

        //         QJsonArray latLon = point.toArray();
        //         if (latLon.size() < 2) continue;

        //         double lon = latLon[0].toDouble();
        //         double lat = latLon[1].toDouble();

        //         QGeoCoordinate coordinate(lat, lon);

        //         if(validFrom != "" && validTo != ""){
        //             polygon->appendVertex(coordinate);
        //             noFlyZone.append(NoFlyZone(QGeoCoordinate(lat, lon), altitudeFloor, altitudeCeiling));

        //             qInfo(FlightZoneManagerLog) << "polygon count = " << polygon->count();
        //         }
        //     }
        // }
        //QMetaObject::invokeMethod(this, [=]() {
        if(validFrom != "" && validTo != "") {
            // Set polygon color based on zone type
            // if (zoneType == "Excluded") {
            //     polygon->setcolorInclusion("red");
            // } else if (zoneType == "Restricted") {
            //     polygon->setcolorInclusion("yellow");
            // } else if(zoneType == "Facilitated"){
            //     polygon->setcolorInclusion("green");
            // } else {
            //     polygon->setcolorInclusion("blue"); // Default color
            // }

            // polygon->setcolorInclusion("red");

            // polygon->setstrokeOpacity(1);

            // validFrom 시간과 현재 시간을 비교
            // if (currentTime < validFromDateTime) {
            //     qInfo(FlightZoneManagerLog) << "Polygon is not yet valid. Skipping. validFromDateTime : " << validFromDateTime << "," << validToDateTime;
            //     validTimeList.append(FlightValidTime(polygonid, validFromDateTime, validToDateTime, false));
            //     continue; // 유효하지 않으면 건너뛴다.
            // }
            // else {
            //     qInfo(FlightZoneManagerLog) << "Polygon valid. Skipping. validToDateTime" << validFromDateTime << "," << validToDateTime;
            //     validTimeList.append(FlightValidTime(polygonid, validFromDateTime, validToDateTime, true));
            // }

            // Add the completed polygon to the polygons list

            // if(!allNoFlyZones.contains(noFlyZone)){
            //     allNoFlyZones.append(noFlyZone);
            // }
        }
        //}, Qt::QueuedConnection);
        qInfo(FlightZoneManagerLog) << "allNoFlyZones Count = " <<allNoFlyZones.count();


        // qInfo(FlightZoneManagerLog) << "_polygons Count = " << _polygons.count();
        // qInfo(FlightZoneManagerLog) << "Polygon added successfully.";

        // qInfo(FlightZoneManagerLog) << "Zone Type:" << zoneType;
        // qInfo(FlightZoneManagerLog) << "Valid From:" << validFrom;
        // qInfo(FlightZoneManagerLog) << "Valid To:" << validTo;

        // //각 polygon마다 고유한 ID가 있는듯함. Index 번호로
        // // 그렇다면 고유한 ID로 비교해서
        // qInfo(FlightZoneManagerLog) << "polygon ID : " << polygonid;

    }
    analyzeMemoryUsage();
    qInfo() << "For 문 끝-------------";
}

void FlightZoneManager::analyzeMemoryUsage()
{
    qDebug() << "=== Memory Analysis ===";
    qDebug() << "Total lists:" << allNoFlyZones.size();

    int totalZones = 0;
    int maxZones = 0;
    int minZones = INT_MAX;

    for (const auto& list : allNoFlyZones) {
        int count = list.size();
        totalZones += count;
        maxZones = qMax(maxZones, count);
        minZones = qMin(minZones, count);
    }

    qDebug() << "Total zones:" << totalZones;
    qDebug() << "Average per list:" << (double)totalZones / allNoFlyZones.size();
    qDebug() << "Max zones in a list:" << maxZones;
    qDebug() << "Min zones in a list:" << minZones;

    // 예상 메모리 사용량
    qint64 estimatedBytes = totalZones * sizeof(NoFlyZone);
    qDebug() << "Estimated memory:" << estimatedBytes / 1024.0 / 1024.0 << "MB";
}

#endif

// ------------------------------------------------------------------------------------ Read From Online
void FlightZoneManager::processJsonFile(const QJsonDocument& jsonDoc)
{
    QList<std::tuple<QList<QGeoCoordinate>, QString, QString, QString>> parsedPolygons; // 마지막 QString: id
    QList<std::tuple<QGeoCoordinate, double, QString, QString, QString>> parsedCircles; // 마지막 QString: id

    QList<std::tuple<QList<QGeoCoordinate>, double, double>> parsedNoFlyZone;

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

                // Add CreatePolyhedron
                parsedNoFlyZone.append(std::make_tuple(polygon, floorMeters, ceilingMeters));

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
            generateNoFlyZones(parsedNoFlyZone);
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
}


void FlightZoneManager::start(void){

    //Index 번호를 가져오는 듯함 0 = USB, 1 = Online
    QString dataType = _settingsManager->flyViewSettings()->dataType()->rawValueString();
    //qInfo() << "FlightZoneManager dataType : " << dataType;

    // 읽어올 파일의 저장위치를 가져온다
    QString savePath = _settingsManager->flyViewSettings()->filePath()->rawValueString();
    //qInfo() << "FlightZoneManger savePath : " << savePath;

    if(dataType == "0") // USB
    {
        //qInfo() << "Make with USB dataType = " << dataType;
        processJsonFile(getFilePath());
    }
    else // Online
    {
        //qInfo(FlightZoneManagerLog) << "Make with Online dataType = " << dataType;
        //qInfo() << "Data Type == " << dataType;
        getOnlineGeoJsonData();
    }
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

