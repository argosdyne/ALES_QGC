#include "VehicleESCFactGroup.h"

const char* VehicleESCFactGroup::_temperature0FactName = "temperature0";
const char* VehicleESCFactGroup::_temperature1FactName = "temperature1";
const char* VehicleESCFactGroup::_temperature2FactName = "temperature2";
const char* VehicleESCFactGroup::_temperature3FactName = "temperature3";
const char* VehicleESCFactGroup::_rpm0FactName = "rpm0";
const char* VehicleESCFactGroup::_rpm1FactName = "rpm1";
const char* VehicleESCFactGroup::_rpm2FactName = "rpm2";
const char* VehicleESCFactGroup::_rpm3FactName = "rpm3";

VehicleESCFactGroup::VehicleESCFactGroup(QObject* parent)
    : FactGroup(1000, ":/json/Vehicle/ESCFact.json", parent)
    , _temperature0Fact(0, _temperature0FactName, FactMetaData::valueTypeInt32)
    , _temperature1Fact(0, _temperature1FactName, FactMetaData::valueTypeInt32)
    , _temperature2Fact(0, _temperature2FactName, FactMetaData::valueTypeInt32)
    , _temperature3Fact(0, _temperature3FactName, FactMetaData::valueTypeInt32)
    , _rpm0Fact(0, _rpm0FactName, FactMetaData::valueTypeInt32)
    , _rpm1Fact(0, _rpm1FactName, FactMetaData::valueTypeInt32)
    , _rpm2Fact(0, _rpm2FactName, FactMetaData::valueTypeInt32)
    , _rpm3Fact(0, _rpm3FactName, FactMetaData::valueTypeInt32)
{
    _addFact(&_temperature0Fact, _temperature0FactName);
    _addFact(&_temperature1Fact, _temperature1FactName);
    _addFact(&_temperature2Fact, _temperature2FactName);
    _addFact(&_temperature3Fact, _temperature3FactName);
    _addFact(&_rpm0Fact, _rpm0FactName);
    _addFact(&_rpm1Fact, _rpm1FactName);
    _addFact(&_rpm2Fact, _rpm2FactName);
    _addFact(&_rpm3Fact, _rpm3FactName);
}

void VehicleESCFactGroup::handleMessage(Vehicle* /* vehicle */, mavlink_message_t& message)
{
    switch (message.msgid) {
    case MAVLINK_MSG_ID_ESC_INFO:
        _handleESCInfo(message);
        break;
    case MAVLINK_MSG_ID_ESC_STATUS:
        _handleESCStatus(message);
        break;
    default:
        break;
    }
}

void VehicleESCFactGroup::_handleESCInfo(mavlink_message_t& message)
{
    mavlink_esc_info_t esc_info;
    mavlink_msg_esc_info_decode(&message, &esc_info);

    temperature0()->setRawValue(esc_info.temperature[0]);
    temperature1()->setRawValue(esc_info.temperature[1]);
    temperature2()->setRawValue(esc_info.temperature[2]);
    temperature3()->setRawValue(esc_info.temperature[3]);
}

void VehicleESCFactGroup::_handleESCStatus(mavlink_message_t& message)
{
    mavlink_esc_status_t esc_status;
    mavlink_msg_esc_status_decode(&message, &esc_status);

    rpm0()->setRawValue(esc_status.rpm[0]);
    rpm1()->setRawValue(esc_status.rpm[1]);
    rpm2()->setRawValue(esc_status.rpm[2]);
    rpm3()->setRawValue(esc_status.rpm[3]);
}
