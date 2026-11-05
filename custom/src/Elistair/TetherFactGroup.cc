#include "TetherFactGroup.h"

#include <QtMath>

namespace {
constexpr const char* kTetherLength = "tetherLength";
constexpr const char* kTetherRemaining = "tetherRemaining";
constexpr const char* kTetherPower = "tetherPower";
constexpr const char* kTetherVoltage = "tetherVoltage";
constexpr const char* kTetherCurrent = "tetherCurrent";
constexpr const char* kTorqueApplied = "torqueApplied";
constexpr const char* kSpoolTemp = "spoolTemp";
constexpr const char* kCableSpeed = "cableSpeed";
}

TetherFactGroup::TetherFactGroup(QObject* parent)
    : FactGroup(1000, ":/json/Vehicle/TetherFact.json", parent)
    , _tetherLengthFact(0, kTetherLength, FactMetaData::valueTypeDouble)
    , _tetherRemainingFact(0, kTetherRemaining, FactMetaData::valueTypeDouble)
    , _tetherPowerFact(0, kTetherPower, FactMetaData::valueTypeDouble)
    , _tetherVoltageFact(0, kTetherVoltage, FactMetaData::valueTypeDouble)
    , _tetherCurrentFact(0, kTetherCurrent, FactMetaData::valueTypeDouble)
    , _torqueAppliedFact(0, kTorqueApplied, FactMetaData::valueTypeDouble)
    , _spoolTempFact(0, kSpoolTemp, FactMetaData::valueTypeDouble)
    , _cableSpeedFact(0, kCableSpeed, FactMetaData::valueTypeDouble)
{
    _addFact(&_tetherLengthFact, kTetherLength);
    _addFact(&_tetherRemainingFact, kTetherRemaining);
    _addFact(&_tetherPowerFact, kTetherPower);
    _addFact(&_tetherVoltageFact, kTetherVoltage);
    _addFact(&_tetherCurrentFact, kTetherCurrent);
    _addFact(&_torqueAppliedFact, kTorqueApplied);
    _addFact(&_spoolTempFact, kSpoolTemp);
    _addFact(&_cableSpeedFact, kCableSpeed);

    const double unavailable = qQNaN();
    _tetherLengthFact.setRawValue(unavailable);
    _tetherRemainingFact.setRawValue(unavailable);
    _tetherPowerFact.setRawValue(unavailable);
    _tetherVoltageFact.setRawValue(unavailable);
    _tetherCurrentFact.setRawValue(unavailable);
    _torqueAppliedFact.setRawValue(unavailable);
    _spoolTempFact.setRawValue(unavailable);
    _cableSpeedFact.setRawValue(unavailable);
}

void TetherFactGroup::updateTelemetry(double length, double remaining, double power, double voltage,
                                      double current, double torqueApplied, double spoolTemp, double speed)
{
    _tetherLengthFact.setRawValue(length);
    _tetherRemainingFact.setRawValue(remaining);
    _tetherPowerFact.setRawValue(power);
    _tetherVoltageFact.setRawValue(voltage);
    _tetherCurrentFact.setRawValue(current);
    _torqueAppliedFact.setRawValue(torqueApplied);
    _spoolTempFact.setRawValue(spoolTemp);
    _cableSpeedFact.setRawValue(speed);
    _setTelemetryAvailable(true);
}

void TetherFactGroup::setLinkAvailable(bool available)
{
    _setTelemetryAvailable(available);
}
