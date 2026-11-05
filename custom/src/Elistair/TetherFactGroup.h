#pragma once

#include "FactGroup.h"

class TetherFactGroup : public FactGroup
{
    Q_OBJECT

public:
    explicit TetherFactGroup(QObject* parent = nullptr);

    Q_PROPERTY(Fact* tetherLength READ tetherLength CONSTANT)
    Q_PROPERTY(Fact* tetherRemaining READ tetherRemaining CONSTANT)
    Q_PROPERTY(Fact* tetherPower READ tetherPower CONSTANT)
    Q_PROPERTY(Fact* tetherVoltage READ tetherVoltage CONSTANT)
    Q_PROPERTY(Fact* tetherCurrent READ tetherCurrent CONSTANT)
    Q_PROPERTY(Fact* torqueApplied READ torqueApplied CONSTANT)
    Q_PROPERTY(Fact* spoolTemp READ spoolTemp CONSTANT)
    Q_PROPERTY(Fact* cableSpeed READ cableSpeed CONSTANT)

    Fact* tetherLength() { return &_tetherLengthFact; }
    Fact* tetherRemaining() { return &_tetherRemainingFact; }
    Fact* tetherPower() { return &_tetherPowerFact; }
    Fact* tetherVoltage() { return &_tetherVoltageFact; }
    Fact* tetherCurrent() { return &_tetherCurrentFact; }
    Fact* torqueApplied() { return &_torqueAppliedFact; }
    Fact* spoolTemp() { return &_spoolTempFact; }
    Fact* cableSpeed() { return &_cableSpeedFact; }

    void updateTelemetry(double length, double remaining, double power, double voltage,
                         double current, double torqueApplied, double spoolTemp, double speed);
    void setLinkAvailable(bool available);

private:
    Fact _tetherLengthFact;
    Fact _tetherRemainingFact;
    Fact _tetherPowerFact;
    Fact _tetherVoltageFact;
    Fact _tetherCurrentFact;
    Fact _torqueAppliedFact;
    Fact _spoolTempFact;
    Fact _cableSpeedFact;
};
