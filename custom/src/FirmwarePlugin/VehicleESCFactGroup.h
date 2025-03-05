#pragma once

#include "FactGroup.h"
#include "QGCMAVLink.h"

class VehicleESCFactGroup : public FactGroup
{
    Q_OBJECT

public:
    VehicleESCFactGroup(QObject* parent = nullptr);

    Q_PROPERTY(Fact* temperature0   READ    temperature0    CONSTANT)
    Q_PROPERTY(Fact* temperature1   READ    temperature1    CONSTANT)
    Q_PROPERTY(Fact* temperature2   READ    temperature2    CONSTANT)
    Q_PROPERTY(Fact* temperature3   READ    temperature3    CONSTANT)
    Q_PROPERTY(Fact* rpm0           READ    rpm0            CONSTANT)
    Q_PROPERTY(Fact* rpm1           READ    rpm1            CONSTANT)
    Q_PROPERTY(Fact* rpm2           READ    rpm2            CONSTANT)
    Q_PROPERTY(Fact* rpm3           READ    rpm3            CONSTANT)

    Fact* temperature0      () { return &_temperature0Fact; }
    Fact* temperature1      () { return &_temperature1Fact; }
    Fact* temperature2      () { return &_temperature2Fact; }
    Fact* temperature3      () { return &_temperature3Fact; }
    Fact* rpm0              () { return &_rpm0Fact; }
    Fact* rpm1              () { return &_rpm1Fact; }
    Fact* rpm2              () { return &_rpm2Fact; }
    Fact* rpm3              () { return &_rpm3Fact; }

    // Overrides from FactGroup
    virtual void handleMessage(Vehicle* vehicle, mavlink_message_t& message) override;

    static const char* _temperature0FactName;
    static const char* _temperature1FactName;
    static const char* _temperature2FactName;
    static const char* _temperature3FactName;
    static const char* _rpm0FactName;
    static const char* _rpm1FactName;
    static const char* _rpm2FactName;
    static const char* _rpm3FactName;

protected:
    void _handleESCInfo   (mavlink_message_t& message);
    void _handleESCStatus (mavlink_message_t& message);

    Fact _temperature0Fact;
    Fact _temperature1Fact;
    Fact _temperature2Fact;
    Fact _temperature3Fact;
    Fact _rpm0Fact;
    Fact _rpm1Fact;
    Fact _rpm2Fact;
    Fact _rpm3Fact;
};
