/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "APMMissionResetMonitor.h"

#include "APMFirmwarePlugin.h"
#include "Fact.h"
#include "FactSystem.h"
#include "MissionManager.h"
#include "ParameterManager.h"
#include "QGC.h"
#include "QGCApplication.h"
#include "QGCMAVLink.h"
#include "Vehicle.h"

#include <QHash>
#include <QStringList>

namespace {
QHash<int, uint32_t> s_lastBootMsByVehicleId;
}

APMMissionResetMonitor::APMMissionResetMonitor(Vehicle* vehicle, QObject* parent)
    : QObject(parent)
    , _vehicle(vehicle)
    , _probeTimer(this)
{
    _probeTimer.setSingleShot(true);
    connect(&_probeTimer, &QTimer::timeout, this, &APMMissionResetMonitor::_probeTimedOut);

    if (!_vehicle) {
        return;
    }

    if (_vehicle->parameterManager()) {
        connect(_vehicle->parameterManager(), &ParameterManager::parametersReadyChanged, this, &APMMissionResetMonitor::_parametersReady);
        if (_vehicle->parameterManager()->parametersReady()) {
            _parametersReady(true);
        }
    }
    if (_vehicle->missionManager()) {
        connect(_vehicle->missionManager(), &MissionManager::sendComplete, this, &APMMissionResetMonitor::_missionSendComplete);
        connect(_vehicle->missionManager(), &MissionManager::newMissionItemsAvailable, this, &APMMissionResetMonitor::_missionItemsChanged);
        connect(_vehicle->missionManager(), &MissionManager::removeAllComplete, this, &APMMissionResetMonitor::_missionItemsChanged);
        _updateMissionItemState();
    }
}

bool APMMissionResetMonitor::bannerVisible() const
{
    // Connect and reboot notices only. An empty mission has nothing to warn about.
    return _bitBannerRequested && _valueKnown && _hasMissionItems;
}

bool APMMissionResetMonitor::rebootBannerVisible() const
{
    return _rebootBannerVisible;
}

QString APMMissionResetMonitor::bannerText() const
{
    if (_clearOnReboot) {
        return tr("The stored mission is cleared when the vehicle reboots. Re-upload the mission after a reboot.");
    }
    return tr("The previous mission is retained on the vehicle after reboot. Verify the mission before starting it.");
}

QString APMMissionResetMonitor::rebootBannerText() const
{
    return tr("Vehicle reboot detected. Check the mission on the vehicle again.");
}

QString APMMissionResetMonitor::rebootDetectedTime() const
{
    return _rebootDetectedAt.isValid() ? _rebootDetectedAt.toString(Qt::ISODate) : QString();
}

void APMMissionResetMonitor::dismissBanner()
{
    if (!_bitBannerRequested) {
        return;
    }
    _bitBannerRequested = false;
    emit bannerChanged();
}

void APMMissionResetMonitor::dismissRebootBanner()
{
    if (!_rebootBannerVisible) {
        return;
    }
    _rebootBannerVisible = false;
    emit rebootStateChanged();
}

void APMMissionResetMonitor::handleSystemTime(uint32_t timeBootMs)
{
    // time_boot_ms moving backwards is a reboot. The last sample is kept by
    // vehicle id so a recreated Vehicle, after the link returns, can still see
    // the reboot. A link drop that comes back with a larger boot time is not a
    // reboot. A drop of less than two seconds is treated as a reordered sample.
    // time_boot_ms of 0 is the unset value QGC itself sends. A sample that
    // matches this process's uptime is QGC or camera time sync, which restarts
    // when QGC restarts and is not a flight-controller reboot.
    if (!_vehicle || timeBootMs == 0) {
        return;
    }
    const auto apart = [](uint32_t a, uint32_t b) {
        return a > b ? a - b : b - a;
    };
    const uint32_t qgcBootMs = static_cast<uint32_t>(QGC::groundTimeMilliseconds());
    const bool sampleIsQgcClock = apart(timeBootMs, qgcBootMs) < 3000;
    const int vehicleId = _vehicle->id();
    const bool havePrevious = s_lastBootMsByVehicleId.contains(vehicleId);
    const uint32_t previousBootMs = havePrevious ? s_lastBootMsByVehicleId.value(vehicleId) : 0;
    const bool previousIsFcClock = havePrevious && apart(previousBootMs, qgcBootMs) >= 3000;
    if (sampleIsQgcClock && previousIsFcClock) {
        return;
    }
    if (havePrevious && timeBootMs + _rebootDropMs < previousBootMs) {
        _noteReboot();
    }
    s_lastBootMsByVehicleId.insert(vehicleId, timeBootMs);
}

void APMMissionResetMonitor::handleStatusText(const QString& text)
{
    if (_captureStartStatus && !text.isEmpty()) {
        _startFailureStatusText = text;
    }
    if (_sawClearingMission || !text.contains(QStringLiteral("Clearing Mission"))) {
        return;
    }
    _sawClearingMission = true;
    emit rebootStateChanged();
}

void APMMissionResetMonitor::_parametersReady(bool parametersReady)
{
    if (!parametersReady || !_vehicle) {
        return;
    }

    ParameterManager* parameterManager = _vehicle->parameterManager();
    if (!parameterManager->parameterExists(FactSystem::defaultComponentId, QStringLiteral("MIS_OPTIONS"))) {
        return;
    }

    if (!_misOptions) {
        _misOptions = parameterManager->getParameter(FactSystem::defaultComponentId, QStringLiteral("MIS_OPTIONS"));
        connect(_misOptions, &Fact::rawValueChanged, this, &APMMissionResetMonitor::_misOptionsChanged);
        _requestSystemTime();
    }
    _applyValue(qRound(_misOptions->rawValue().toDouble()));
}

void APMMissionResetMonitor::_misOptionsChanged(QVariant value)
{
    _applyValue(qRound(value.toDouble()));
}

void APMMissionResetMonitor::_missionSendComplete(bool error)
{
    if (error) {
        _updateMissionItemState();
        return;
    }
    // A mission the operator just uploaded closes the reboot notice.
    // A mission download that follows the upload must not open it again.
    _bitBannerRequested = false;
    _rebootDetected = false;
    _missionUnconfirmed = false;
    _rebootBannerVisible = false;
    _updateMissionItemState();
    emit bannerChanged();
    emit rebootStateChanged();
}

void APMMissionResetMonitor::_missionItemsChanged(bool success)
{
    Q_UNUSED(success)
    _updateMissionItemState();
}

void APMMissionResetMonitor::_updateMissionItemState()
{
    const bool hasMissionItems = _vehicleHasMissionItems();
    if (hasMissionItems == _hasMissionItems) {
        return;
    }
    _hasMissionItems = hasMissionItems;
    emit bannerChanged();
}

bool APMMissionResetMonitor::_vehicleHasMissionItems() const
{
    MissionManager* missionManager = _vehicle ? _vehicle->missionManager() : nullptr;
    if (!missionManager || !missionManager->lastMissionReadSucceeded()) {
        return false;
    }
    // Item 0 is home. Copter treats the mission as present only when another item exists.
    return missionManager->missionItems().count() > 1;
}

void APMMissionResetMonitor::_applyValue(int value)
{
    const bool clearOnReboot = (value & _clearMissionBit) != 0;
    const bool changed = !_valueKnown || clearOnReboot != _clearOnReboot;
    _valueKnown = true;
    _clearOnReboot = clearOnReboot;
    if (changed) {
        emit bannerChanged();
    }
}

void APMMissionResetMonitor::_noteReboot()
{
    _rebootDetected = true;
    _missionUnconfirmed = true;
    _rebootDetectedAt = QDateTime::currentDateTime();
    _bitBannerRequested = true;
    _rebootBannerVisible = true;
    emit bannerChanged();
    emit rebootStateChanged();
    _requestSystemTime();
    if (_vehicle && _vehicle->parameterManager()) {
        _vehicle->parameterManager()->refreshAllParameters();
    }
}

void APMMissionResetMonitor::dismissStartFailure()
{
    if (_startFailureMode == StartFailureNone) {
        return;
    }
    _startFailureMode = StartFailureNone;
    emit startFailureChanged();
}

void APMMissionResetMonitor::beginMissionStart()
{
    if (!_vehicle || _probeActive || _startFailureMode != StartFailureNone) {
        return;
    }
    if (_vehicle->missionManager() && _vehicle->missionManager()->inProgress()) {
        qgcApp()->showAppMessage(tr("A mission transfer is already in progress. The start command was not sent."));
        return;
    }
    _beginCountProbe(ProbeBeforeStart);
}

void APMMissionResetMonitor::noteMissionStartCommand()
{
    _captureStartStatus = true;
    _startFailureStatusText.clear();
}

void APMMissionResetMonitor::handleMissionStartResult(int mavResult, int failureCode)
{
    _captureStartStatus = false;
    if (failureCode == Vehicle::MavCmdResultCommandResultOnly && mavResult == MAV_RESULT_ACCEPTED) {
        _startFailureStatusText.clear();
        return;
    }
    _rejectedMavResult = mavResult;
    _rejectedFailureCode = failureCode;
    if (!_vehicle || _probeActive) {
        return;
    }
    if (_vehicle->missionManager() && _vehicle->missionManager()->inProgress()) {
        _presentOtherStartFailure();
        return;
    }
    _beginCountProbe(ProbeAfterReject);
}

void APMMissionResetMonitor::_beginCountProbe(int purpose)
{
    if (!_vehicle) {
        return;
    }
    _probePurpose = purpose;
    _probeRetries = 0;
    _probeActive = true;
    connect(_vehicle, &Vehicle::mavlinkMessageReceived, this, &APMMissionResetMonitor::_probeMavlinkMessage);
    _sendMissionCountRequest();
    _probeTimer.start(3000);
}

void APMMissionResetMonitor::_sendMissionCountRequest()
{
    if (!_vehicle) {
        return;
    }
    WeakLinkInterfacePtr weakLink = _vehicle->vehicleLinkManager()->primaryLink();
    if (weakLink.expired()) {
        return;
    }
    SharedLinkInterfacePtr sharedLink = weakLink.lock();
    mavlink_message_t message;
    mavlink_msg_mission_request_list_pack_chan(qgcApp()->toolbox()->mavlinkProtocol()->getSystemId(),
                                               qgcApp()->toolbox()->mavlinkProtocol()->getComponentId(),
                                               sharedLink->mavlinkChannel(),
                                               &message,
                                               _vehicle->id(),
                                               MAV_COMP_ID_AUTOPILOT1,
                                               MAV_MISSION_TYPE_MISSION);
    _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), message);
}

void APMMissionResetMonitor::_cancelMissionRead()
{
    // End the list transfer without downloading items. A normal download of an
    // empty list would clear the plan that still needs to be uploaded.
    if (!_vehicle) {
        return;
    }
    WeakLinkInterfacePtr weakLink = _vehicle->vehicleLinkManager()->primaryLink();
    if (weakLink.expired()) {
        return;
    }
    SharedLinkInterfacePtr sharedLink = weakLink.lock();
    mavlink_message_t message;
    mavlink_msg_mission_ack_pack_chan(qgcApp()->toolbox()->mavlinkProtocol()->getSystemId(),
                                      qgcApp()->toolbox()->mavlinkProtocol()->getComponentId(),
                                      sharedLink->mavlinkChannel(),
                                      &message,
                                      _vehicle->id(),
                                      MAV_COMP_ID_AUTOPILOT1,
                                      MAV_MISSION_OPERATION_CANCELLED,
                                      MAV_MISSION_TYPE_MISSION);
    _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), message);
}

void APMMissionResetMonitor::_stopProbe()
{
    _probeTimer.stop();
    _probeActive = false;
    _probePurpose = ProbeNone;
    _probeRetries = 0;
    if (_vehicle) {
        disconnect(_vehicle, &Vehicle::mavlinkMessageReceived, this, &APMMissionResetMonitor::_probeMavlinkMessage);
    }
}

void APMMissionResetMonitor::_probeMavlinkMessage(const mavlink_message_t& message)
{
    if (!_probeActive || !_vehicle || message.sysid != _vehicle->id() || message.msgid != MAVLINK_MSG_ID_MISSION_COUNT) {
        return;
    }
    mavlink_mission_count_t missionCount;
    mavlink_msg_mission_count_decode(&message, &missionCount);
    if (missionCount.mission_type != MAV_MISSION_TYPE_MISSION) {
        return;
    }
    _cancelMissionRead();
    _finishProbe(missionCount.count);
}

void APMMissionResetMonitor::_probeTimedOut()
{
    if (!_probeActive) {
        return;
    }
    if (_probeRetries < 1) {
        _probeRetries++;
        _sendMissionCountRequest();
        _probeTimer.start(3000);
        return;
    }
    const int purpose = _probePurpose;
    _stopProbe();
    if (purpose == ProbeAfterReject) {
        _presentOtherStartFailure();
        return;
    }
    qgcApp()->showAppMessage(tr("Unable to read the mission from the vehicle. The start command was not sent."));
}

void APMMissionResetMonitor::_finishProbe(int count)
{
    const int purpose = _probePurpose;
    _stopProbe();
    if (count <= 1) {
        _presentEmptyStart(count, purpose);
        return;
    }
    if (purpose == ProbeBeforeStart) {
        auto* plugin = qobject_cast<APMFirmwarePlugin*>(_vehicle ? _vehicle->firmwarePlugin() : nullptr);
        if (plugin && _vehicle) {
            plugin->startMissionAfterCountCheck(_vehicle);
        }
        return;
    }
    _presentOtherStartFailure();
}

void APMMissionResetMonitor::_presentEmptyStart(int count, int purpose)
{
    const QString stage = purpose == ProbeAfterReject
            ? tr("Diagnosed after flight controller rejection")
            : tr("Pre-start check");
    QStringList lines;
    lines << tr("MISSION_COUNT: %1").arg(count);
    if (_rebootDetected && _rebootDetectedAt.isValid()) {
        lines << tr("Reboot detected: %1").arg(_rebootDetectedAt.toString(Qt::ISODate));
    }
    lines << tr("Blocked at: %1").arg(stage);
    _emptyStartDetails = lines.join(QStringLiteral("\n"));
    _startFailureMode = StartFailureEmpty;
    emit startFailureChanged();
}

void APMMissionResetMonitor::_presentOtherStartFailure()
{
    QString fcText = _startFailureStatusText;
    if (fcText.isEmpty()) {
        if (_rejectedFailureCode == Vehicle::MavCmdResultFailureNoResponseToCommand) {
            fcText = tr("Vehicle did not respond");
        } else {
            fcText = QGCMAVLink::mavResultToString(static_cast<MAV_RESULT>(_rejectedMavResult));
        }
    }
    _otherStartFailureText = tr("Mission start failed: %1").arg(fcText);
    _startFailureMode = StartFailureOther;
    emit startFailureChanged();
}

void APMMissionResetMonitor::_requestSystemTime()
{
    if (!_vehicle) {
        return;
    }
    _vehicle->sendMavCommand(MAV_COMP_ID_AUTOPILOT1,
                             MAV_CMD_SET_MESSAGE_INTERVAL,
                             false /* showError */,
                             MAVLINK_MSG_ID_SYSTEM_TIME,
                             1000000);
}
