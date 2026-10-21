#include "RTCMBase.h"

using namespace std;

/* Decimal Degrees to Degrees Minutes (ddmm.mmmmm) */
double deg2dms(double n)
{
    double decimal = fabs(n);
    return copysign((std::floor(decimal) * 100.0 + (decimal - std::floor(decimal)) * 60.0), n);
}

RTCMBase::RTCMBase(QString name, QObject* parent)
    : SettingsGroup(name, "RTCM", parent)
{
    _streamTimer.setSingleShot(false);
    _streamTimer.setInterval(2000);
    connect(&_streamTimer, &QTimer::timeout, this, &RTCMBase::streamTimeout);
    Fact* interval = sendMaxRTCMHz();
    connect(&_sendRTCMTimer, &QTimer::timeout, this, &RTCMBase::handle_send_rtcm_time_out);
    if(interval->rawValue().toInt() > 0) {
        _sendRTCMTimer.setInterval(interval->rawValue().toInt());
        _sendRTCMTimer.start();
    }
    connect(interval, &Fact::rawValueChanged, this, [&](QVariant value){
        _sendRTCMTimer.stop();
        if(value.toInt() > 0) {
            _sendRTCMTimer.setInterval(value.toInt());
            _sendRTCMTimer.start();
        }
    });
}

RTCMBase::~RTCMBase()
{
}

void RTCMBase::setStreaming(const bool& streaming)
{
    if(streaming) {
        _streamTimer.start();
    } else {
        _streamTimer.stop();
    }
    if(streaming == _streaming) return;
    _streaming = streaming;
    emit streamingChanged(_streaming);
}

void RTCMBase::handle_gps_raw_int_status(const mavlink_message_t &message)
{
    mavlink_gps_raw_int_t gps_raw_int;
    mavlink_msg_gps_raw_int_decode(&message, &gps_raw_int);
    char str[256] = {'\0'};

    char lat_uint, lon_uint;
    if(gps_raw_int.lat > 0)
        lat_uint = 'N';
    else {
        gps_raw_int.lat = -gps_raw_int.lat;
        lat_uint = 'S';
    }
    if(gps_raw_int.lon > 0)
        lon_uint = 'E';
    else {
        gps_raw_int.lon = -gps_raw_int.lon;
        lon_uint = 'W';
    }
    double gps_eph;
    if(gps_raw_int.eph == UINT16_MAX)
        gps_eph = 99.9;
    else gps_eph = gps_raw_int.eph / 100.0;
    double lat, lon;
    lat = deg2dms(gps_raw_int.lat * 1e-7);
    lon = deg2dms(gps_raw_int.lon * 1e-7);

    std::string time = QDateTime::fromMSecsSinceEpoch(gps_raw_int.time_usec / 1000, Qt::UTC).toString("hhmmss.zzz").toStdString();
    snprintf(str, sizeof(str),
             "$GPGGA,%s,%09.04f,%c,%010.04f,%c,%d,%02d,%.1f,%.1f,M,0.0,M,5,0*",
             time.c_str(),
             lat,
             lat_uint,
             lon,
             lon_uint,
             gps_raw_int.fix_type,
             gps_raw_int.satellites_visible,
             gps_eph,
             gps_raw_int.alt / 1000.0);

    uint8_t result = static_cast<uint8_t>(str[1]);
    for(int i = 2; str[i] != '*'; i++)
    {
        result ^= static_cast<uint8_t>(str[i]);
    }

    char str_reslut[260] = {'\0'};

    snprintf(str_reslut, sizeof(str_reslut),
             "%s%02X",str,result);

    _gpggaFromVehicle = QString::fromStdString(str_reslut);
    emit pgggaMessageChanged(_gpggaFromVehicle);
}

void RTCMBase::handle_send_rtcm_time_out()
{
    LockedQueue<rtcm_data_t>::Guard work_queue_guard(_work_queue);
    auto work = work_queue_guard.get_front();

    if (!work) {
        return;
    }

    send_rtcm_data(work);

    work_queue_guard.pop_front();
}

void RTCMBase::streamTimeout()
{
    setStreaming(false);
}

void RTCMBase::send_rtcm_package(const char* buffer, unsigned length)
{
    if(length < 180) {
        rtcm_data_t rtcm_data;
        memset(&rtcm_data, 0, sizeof(rtcm_data_t));
        rtcm_data.flags.flags_bit.fragmented = 0;
        rtcm_data.flags.flags_bit.id = 0;
        rtcm_data.flags.flags_bit.sequence = sequence++;
        rtcm_data.len = static_cast<uint8_t>(length);
        memcpy(rtcm_data.data, buffer, length);
        if(!_sendRTCMTimer.isActive()) {
            send_rtcm_data(std::make_shared<rtcm_data_t>(rtcm_data));
        } else _work_queue.push_back(rtcm_data);
    } else {
        unsigned i;
        for(i = 0; (i + 1) * 180 < length; i++) {
            rtcm_data_t rtcm_data;
            memset(&rtcm_data, 0, sizeof(rtcm_data_t));
            rtcm_data.flags.flags_bit.fragmented = 1;
            rtcm_data.flags.flags_bit.id = i;
            rtcm_data.flags.flags_bit.sequence = sequence++;
            rtcm_data.len = 180;
            memcpy(rtcm_data.data, buffer + i * 180, 180);
            if(!_sendRTCMTimer.isActive()) {
                send_rtcm_data(std::make_shared<rtcm_data_t>(rtcm_data));
            } else _work_queue.push_back(rtcm_data);
        }
        unsigned len = length - i * 180;
        if(len > 0) {
            rtcm_data_t rtcm_data;
            memset(&rtcm_data, 0, sizeof(rtcm_data_t));
            rtcm_data.flags.flags_bit.fragmented = 1;
            rtcm_data.flags.flags_bit.id = i;
            rtcm_data.flags.flags_bit.sequence = sequence++;
            rtcm_data.len = static_cast<uint8_t>(len);
            memcpy(rtcm_data.data, buffer + i * 180, len);
            if(!_sendRTCMTimer.isActive()) {
                send_rtcm_data(std::make_shared<rtcm_data_t>(rtcm_data));
            } else _work_queue.push_back(rtcm_data);
        }
    }
}

void RTCMBase::send_rtcm_data(std::shared_ptr<rtcm_data_t> work)
{
    setStreaming(true);

    mavlink_gps_rtcm_data_t mavlink_gps_rtcm_data;
    mavlink_gps_rtcm_data.flags = work->flags.data;
    mavlink_gps_rtcm_data.len = work->len;
    memcpy(mavlink_gps_rtcm_data.data, work->data, 180);

    emit sendMavlinkRTCM(mavlink_gps_rtcm_data);
}

DECLARE_SETTINGSFACT(RTCMBase, sendMaxRTCMHz)
