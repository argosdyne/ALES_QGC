/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "APMMissionComponentController.h"

#include "Fact.h"
#include "FactSystem.h"
#include "ParameterManager.h"
#include "Vehicle.h"

APMMissionComponentController::APMMissionComponentController()
    : _timer(this)
{
    _timer.setSingleShot(true);
    _timer.setInterval(_responseTimeoutMs);
    connect(&_timer, &QTimer::timeout, this, &APMMissionComponentController::_onTimeout);

    if (_vehicle) {
        connect(_vehicle, &Vehicle::firmwareVersionChanged, this, &APMMissionComponentController::stateChanged);
    }

    if (_vehicle && _vehicle->parameterManager()->parameterExists(FactSystem::defaultComponentId, QStringLiteral("MIS_OPTIONS"))) {
        _fact = getParameterFact(FactSystem::defaultComponentId, QStringLiteral("MIS_OPTIONS"));
        if (_fact) {
            connect(_fact, &Fact::vehicleUpdated, this, &APMMissionComponentController::_onVehicleUpdated);
        }
    }
}

bool APMMissionComponentController::continueAfterLandSupported(void) const
{
    // ContinueAfterLand is MIS_OPTIONS bit2, added in Copter 4.1.
    return _vehicle && _vehicle->versionCompare(4, 1, 0) >= 0;
}

bool APMMissionComponentController::dirty(void) const
{
    if (!_valueKnown || _busy) {
        return false;
    }
    const bool clearDirty = _clearOnReboot != ((_currentValue & _clearMissionBit) != 0);
    const bool continueDirty = continueAfterLandSupported()
            && (_continueAfterLand != ((_currentValue & _continueAfterLandBit) != 0));
    return clearDirty || continueDirty;
}

void APMMissionComponentController::refresh(void)
{
    if (_busy || _valueKnown) {
        return;
    }
    if (!_fact || !_vehicle) {
        _status = StatusReadFailed;
        emit stateChanged();
        return;
    }
    _status = StatusNone;
    _requestRead(WaitingInitialRead);
}

void APMMissionComponentController::setClearOnReboot(bool clearOnReboot)
{
    if (_busy || !_valueKnown || !_vehicle || _vehicle->armed() || _clearOnReboot == clearOnReboot) {
        return;
    }
    _clearOnReboot = clearOnReboot;
    _status = StatusNone;
    emit stateChanged();
}

void APMMissionComponentController::setContinueAfterLand(bool continueAfterLand)
{
    if (!continueAfterLandSupported() || _busy || !_valueKnown || !_vehicle || _vehicle->armed() || _continueAfterLand == continueAfterLand) {
        return;
    }
    _continueAfterLand = continueAfterLand;
    _status = StatusNone;
    emit stateChanged();
}

void APMMissionComponentController::apply(void)
{
    if (_busy || !_valueKnown || !_fact || !_vehicle || _vehicle->armed() || !dirty()) {
        return;
    }
    _status = StatusNone;
    _requestRead(WaitingApplyRead);
}

void APMMissionComponentController::cancel(void)
{
    if (_busy || !_valueKnown) {
        return;
    }
    _setDraftFromValue(_currentValue);
    _status = StatusNone;
    emit stateChanged();
}

void APMMissionComponentController::_requestRead(State state)
{
    _state = state;
    _busy = true;
    _timer.start();
    emit stateChanged();
    _vehicle->parameterManager()->refreshParameter(FactSystem::defaultComponentId, QStringLiteral("MIS_OPTIONS"));
}

void APMMissionComponentController::_onVehicleUpdated(const QVariant& value)
{
    if (_state == Idle) {
        return;
    }

    const int reported = _reportedValue(value);

    if (_state == WaitingInitialRead) {
        _timer.stop();
        _state = Idle;
        _busy = false;
        _valueKnown = true;
        _setDraftFromValue(reported);
        _status = StatusNone;
        emit stateChanged();
        return;
    }

    if (_state == WaitingApplyRead) {
        if (!_vehicle || _vehicle->armed()) {
            _failApply();
            return;
        }
        _lastApplyChangedClear = _clearOnReboot != ((reported & _clearMissionBit) != 0);
        _lastApplyChangedContinue = continueAfterLandSupported() && (_continueAfterLand != ((reported & _continueAfterLandBit) != 0));
        _expectedValue = _valueWithDraftBits(reported);
        _state = WaitingWrite;
        _timer.start();
        _fact->forceSetRawValue(_expectedValue);
        return;
    }

    if (_state == WaitingWrite) {
        if (reported != _expectedValue) {
            _failApply();
            return;
        }
        _timer.stop();
        _state = Idle;
        _busy = false;
        _valueKnown = true;
        _setDraftFromValue(reported);
        _status = StatusApplied;
        emit stateChanged();
    }
}

void APMMissionComponentController::_onTimeout(void)
{
    if (_state == WaitingInitialRead) {
        _state = Idle;
        _busy = false;
        _status = StatusReadFailed;
        emit stateChanged();
        return;
    }
    if (_state == WaitingApplyRead || _state == WaitingWrite) {
        _failApply();
    }
}

void APMMissionComponentController::_failApply(void)
{
    _state = Idle;
    _timer.stop();
    _busy = false;
    if (_valueKnown) {
        _setDraftFromValue(_currentValue);
    }
    _status = StatusFailed;
    emit stateChanged();
}

void APMMissionComponentController::_setDraftFromValue(int value)
{
    _currentValue = value;
    _clearOnReboot = (value & _clearMissionBit) != 0;
    _continueAfterLand = (value & _continueAfterLandBit) != 0;
}

int APMMissionComponentController::_valueWithDraftBits(int reported) const
{
    int value = reported & ~_clearMissionBit;
    if (continueAfterLandSupported()) {
        value &= ~_continueAfterLandBit;
        if (_continueAfterLand) {
            value |= _continueAfterLandBit;
        }
    }
    if (_clearOnReboot) {
        value |= _clearMissionBit;
    }
    return value;
}

int APMMissionComponentController::_reportedValue(const QVariant& value)
{
    return qRound(value.toDouble());
}
