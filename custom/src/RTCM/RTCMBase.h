#ifndef RTCMBASE_H
#define RTCMBASE_H
#include "SettingsGroup.h"
#include "lockedqueue.h"

class RTCMBase : public SettingsGroup
{
    Q_OBJECT
public:
    typedef struct RTCM_DATA {
        union RTCM_HEAD {
            struct {
                unsigned fragmented:1;
                unsigned id:2;
                unsigned sequence:5;
            }flags_bit;
            uint8_t data;
        } flags;
        uint8_t len;
        uint8_t data[180];
    }rtcm_data_t;

    Q_PROPERTY(QString url READ url CONSTANT)
    Q_PROPERTY(bool streaming READ streaming NOTIFY streamingChanged)

    bool streaming() const { return _streaming; }
    void setStreaming(const bool& streaming);

    RTCMBase(QString name, QObject* parent = nullptr);
    ~RTCMBase() Q_DECL_OVERRIDE;

    virtual QString url() { return ""; }

    DEFINE_SETTINGFACT(sendMaxRTCMHz)

signals:
    void sendMavlinkRTCM(mavlink_gps_rtcm_data_t message);
    void pgggaMessageChanged(QVariant message);
    void streamingChanged(bool streaming);

public slots:
    void handle_gps_raw_int_status(const mavlink_message_t &message);

protected slots:
    void handle_send_rtcm_time_out();
    void send_rtcm_package(const char* buffer, unsigned length);
    void send_rtcm_data(std::shared_ptr<rtcm_data_t> work);
    void streamTimeout();

protected:
    QString _gpggaFromVehicle;

    uint8_t sequence{0};
    LockedQueue<rtcm_data_t> _work_queue;
    QTimer _sendRTCMTimer;
    QTimer _streamTimer;
    bool _streaming{false};
};

#endif // RTCMBASE_H
