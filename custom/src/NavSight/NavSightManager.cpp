#include "NavSightManager.h"

#include "MAVLinkProtocol.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"
#include "VehicleLinkManager.h"

#include <QQmlEngine>
#include <QtQml>

#include <cmath>

NavSightManager::NavSightManager(QGCApplication* app, QGCToolbox* toolbox)
    : QGCTool(app, toolbox)
{
}

void NavSightManager::setToolbox(QGCToolbox* toolbox)
{
    QGCTool::setToolbox(toolbox);

    QQmlEngine::setObjectOwnership(this, QQmlEngine::CppOwnership);
    qmlRegisterUncreatableType<NavSightManager>("CustomQuickInterface", 1, 0,
                                                 "NavSightManager", "Reference only");

    MultiVehicleManager* vehicleManager = _toolbox->multiVehicleManager();
    _setActiveVehicle(vehicleManager->activeVehicle());
    connect(vehicleManager, &MultiVehicleManager::activeVehicleChanged,
            this, &NavSightManager::_setActiveVehicle);
}

void NavSightManager::_setActiveVehicle(Vehicle* vehicle)
{
    _vehicle = vehicle;
}

void NavSightManager::_setUpdateLocationResult(const QString& result)
{
    if (_lastUpdateLocationResult != result) {
        _lastUpdateLocationResult = result;
    }
    emit updateLocationStateChanged();
}

bool NavSightManager::sendUpdateLocation(double latitude, double longitude)
{
    _updateLocationInProgress = true;
    emit updateLocationStateChanged();

    if (!_vehicle) {
        _updateLocationInProgress = false;
        _setUpdateLocationResult(QStringLiteral("No active vehicle"));
        return false;
    }
    if (!std::isfinite(latitude) || !std::isfinite(longitude) ||
        latitude < -90.0 || latitude > 90.0 || longitude < -180.0 || longitude > 180.0) {
        _updateLocationInProgress = false;
        _setUpdateLocationResult(QStringLiteral("Invalid location"));
        return false;
    }

    SharedLinkInterfacePtr link = _vehicle->vehicleLinkManager()->primaryLink().lock();
    if (!link) {
        _updateLocationInProgress = false;
        _setUpdateLocationResult(QStringLiteral("No primary telemetry link"));
        return false;
    }

    mavlink_command_long_t command{};
    command.target_system = static_cast<uint8_t>(kDefaultSystemId);
    command.target_component = static_cast<uint8_t>(kDefaultComponentId);
    command.command = 44444; // NavSight UPDATE_LOCATION
    command.confirmation = 0;
    command.param1 = static_cast<float>(latitude);
    command.param2 = static_cast<float>(longitude);

    mavlink_message_t message{};
    MAVLinkProtocol* mavlinkProtocol = _toolbox->mavlinkProtocol();
    mavlink_msg_command_long_encode(mavlinkProtocol->getSystemId(), mavlinkProtocol->getComponentId(),
                                    &message, &command);
    _vehicle->sendMessageOnLinkThreadSafe(link.get(), message);

    // ACK processing is added in the next task. The command has been queued
    // to the primary link, so it is no longer locally in progress.
    _updateLocationInProgress = false;
    _setUpdateLocationResult(QStringLiteral("UPDATE_LOCATION sent; awaiting ACK"));
    emit updateLocationSent(latitude, longitude);
    return true;
}