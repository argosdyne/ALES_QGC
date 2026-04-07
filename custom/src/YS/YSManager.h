#pragma once

#include "QGCToolbox.h"
#include "Vehicle.h"

#include <QElapsedTimer>
#include <QTimer>

class YSManager : public QGCTool
{
    Q_OBJECT
public:
    explicit YSManager(QGCApplication* app, QGCToolbox* toolbox);

    Q_PROPERTY(bool    statusValid         READ statusValid         NOTIFY statusValidChanged)
    Q_PROPERTY(bool    anyError            READ anyError            NOTIFY statusChanged)
    Q_PROPERTY(bool    acquisitionRunning  READ acquisitionRunning  NOTIFY statusChanged)
    Q_PROPERTY(bool    timeNotSet          READ timeNotSet          NOTIFY statusChanged)
    Q_PROPERTY(bool    scannerNotReady     READ scannerNotReady     NOTIFY statusChanged)
    Q_PROPERTY(bool    insNotLocked        READ insNotLocked        NOTIFY statusChanged)
    Q_PROPERTY(bool    noUsb               READ noUsb               NOTIFY statusChanged)
    Q_PROPERTY(bool    usbFull             READ usbFull             NOTIFY statusChanged)

    Q_PROPERTY(quint8  insInfo             READ insInfo             NOTIFY statusChanged)
    Q_PROPERTY(quint8  scnInfo             READ scnInfo             NOTIFY statusChanged)
    Q_PROPERTY(quint8  genInfo             READ genInfo             NOTIFY statusChanged)
    Q_PROPERTY(quint8  insErr              READ insErr              NOTIFY statusChanged)
    Q_PROPERTY(quint8  scnErr              READ scnErr              NOTIFY statusChanged)
    Q_PROPERTY(quint8  intErr              READ intErr              NOTIFY statusChanged)
    Q_PROPERTY(quint8  camErr              READ camErr              NOTIFY statusChanged)

    Q_PROPERTY(int     scannerHighSensitivity  READ scannerHighSensitivity  NOTIFY parameterChanged)
    Q_PROPERTY(int     scannerPattern          READ scannerPattern          NOTIFY parameterChanged)
    Q_PROPERTY(int     embeddedCamera          READ embeddedCamera          NOTIFY parameterChanged)
    Q_PROPERTY(float   embCamInitHeight        READ embCamInitHeight        NOTIFY parameterChanged)
    Q_PROPERTY(int     embCamTriggerMode       READ embCamTriggerMode       NOTIFY parameterChanged)
    Q_PROPERTY(float   embCamTriggerValue      READ embCamTriggerValue      NOTIFY parameterChanged)

    Q_PROPERTY(bool    scannerHighSensitivitySetFailed READ scannerHighSensitivitySetFailed NOTIFY paramSetFailedChanged)
    Q_PROPERTY(bool    scannerPatternSetFailed        READ scannerPatternSetFailed        NOTIFY paramSetFailedChanged)
    Q_PROPERTY(bool    embeddedCameraSetFailed        READ embeddedCameraSetFailed        NOTIFY paramSetFailedChanged)
    Q_PROPERTY(bool    embCamInitHeightSetFailed      READ embCamInitHeightSetFailed      NOTIFY paramSetFailedChanged)
    Q_PROPERTY(bool    embCamTriggerModeSetFailed     READ embCamTriggerModeSetFailed     NOTIFY paramSetFailedChanged)
    Q_PROPERTY(bool    embCamTriggerValueSetFailed    READ embCamTriggerValueSetFailed    NOTIFY paramSetFailedChanged)

    Q_PROPERTY(QString lastSentMessage         READ lastSentMessage         NOTIFY messageChanged)
    Q_PROPERTY(QString lastReceivedMessage     READ lastReceivedMessage     NOTIFY messageChanged)

    bool statusValid(void) const { return _statusValid; }
    bool anyError(void) const { return timeNotSet() || scannerNotReady() || insNotLocked() || noUsb() || usbFull() || _insErr || _scnErr || _intErr || _camErr; }

    bool acquisitionRunning(void) const { return kGenInfoAcqRunning; }
    bool timeNotSet(void) const { return (_insErr  & kInsInfoTimeNotSet) != 0; }
    bool scannerNotReady(void) const { return (_scnInfo & kScnInfoNotReady) == 0; }
    bool insNotLocked(void) const { return (_insInfo & kInsInfoNotLocked) == 0; }
    bool noUsb(void) const { return (_genInfo & kGenInfoNoUsb) == 0; }
    bool usbFull(void) const { return (_genInfo & kGenInfoUsbFull) != 0; }

    quint8 insInfo(void) const { return _insInfo; }
    quint8 scnInfo(void) const { return _scnInfo; }
    quint8 genInfo(void) const { return _genInfo; }
    quint8 insErr(void) const { return _insErr; }
    quint8 scnErr(void) const { return _scnErr; }
    quint8 intErr(void) const { return _intErr; }
    quint8 camErr(void) const { return _camErr; }

    int scannerHighSensitivity(void) const { return _scannerHighSensitivity; }
    int scannerPattern(void) const { return _scannerPattern; }
    int embeddedCamera(void) const { return _embeddedCamera; }
    float embCamInitHeight(void) const { return _embCamInitHeight; }
    int embCamTriggerMode(void) const { return _embCamTriggerMode; }
    float embCamTriggerValue(void) const { return _embCamTriggerValue; }

    bool scannerHighSensitivitySetFailed(void) const { return _paramSetFailed[ParamScannerHighSensitivity]; }
    bool scannerPatternSetFailed(void) const { return _paramSetFailed[ParamScannerPattern]; }
    bool embeddedCameraSetFailed(void) const { return _paramSetFailed[ParamEmbeddedCameraEnable]; }
    bool embCamInitHeightSetFailed(void) const { return _paramSetFailed[ParamEmbCamInitHeight]; }
    bool embCamTriggerModeSetFailed(void) const { return _paramSetFailed[ParamEmbCamTriggerMode]; }
    bool embCamTriggerValueSetFailed(void) const { return _paramSetFailed[ParamEmbCamTriggerValue]; }

    QString lastSentMessage(void) const { return _lastSentMessage; }
    QString lastReceivedMessage(void) const { return _lastReceivedMessage; }

    Q_INVOKABLE void startAcquisition(void);
    Q_INVOKABLE void stopAcquisition(void);
    Q_INVOKABLE void powerOff(void);
    Q_INVOKABLE void requestStatus(void);
    Q_INVOKABLE void setParameter(int paramIndex, float value);
    Q_INVOKABLE void requestParameter(int paramIndex);

    // Overrides from QGCTool
    void setToolbox(QGCToolbox* toolbox) override;

signals:
    void statusChanged(void);
    void statusValidChanged(void);
    void parameterChanged(void);
    void messageChanged(void);
    void paramSetFailedChanged(void);

private slots:
    void _setActiveVehicle(Vehicle* vehicle);
    void _mavlinkReceived(const mavlink_message_t& message);
    void _checkStatusTimeout(void);
    void _restorePowerStatus(void);

private:
    static constexpr int kYellowScanSysId = 1;
    static constexpr int kYellowScanCompId = MAV_COMP_ID_USER1;
    QString _mavResultToString(uint8_t result) const;
    QString _formatMavlinkHex(const mavlink_message_t& message) const;
    void _sendNamedValueInt(const char* name, int32_t value);
    bool _shouldDebounceCommand(MAV_CMD command, float param1, float param2);
    void _updateSentMessage(const QString& message);
    void _enqueueStatusRequest(const char* name);
    void _startNextStatus(void);
    void _enqueueGetParameter(int paramIndex);
    void _enqueueSetParameter(int paramIndex, float value);
    void _startNextGet(void);
    void _startNextSet(void);
    void _setParamSetFailed(int paramIndex, bool failed);
    void _updateStatus(quint8 insInfo, quint8 scnInfo, quint8 genInfo,
                       quint8 insErr, quint8 scnErr, quint8 intErr, quint8 camErr);
    void _sendCommand(MAV_CMD command, float param1 = 0.0f, float param2 = 0.0f);
    void _flushPendingControlCommand(void);
    void _setParameterValue(int paramIndex, float value);

    Vehicle* _vehicle{nullptr};
    QElapsedTimer _statusTimer;
    QElapsedTimer _statusRequestTimer;
    QElapsedTimer _paramRequestTimer;
    QTimer _statusPollTimer;
    QTimer _powerStatusResetTimer;
    qint64 _lastStatusMs{-1};
    qint64 _lastStatusRequestMs{-1000};
    qint64 _lastParamRequestMs{-1000};
    qint64 _lastSetRequestMs{-1000};
    bool _statusValid{false};
    bool _awaitingFreshStatus{false};
    QElapsedTimer _commandTimer;
    MAV_CMD _lastCommand{static_cast<MAV_CMD>(0)};
    float _lastCommandParam1{0.0f};
    float _lastCommandParam2{0.0f};
    qint64 _lastCommandMs{-1000};
    qint64 _lastSentMs{-1000};

    bool _hasPendingControlCommand{false};
    MAV_CMD _pendingControlCommand{static_cast<MAV_CMD>(0)};
    float _pendingControlParam1{0.0f};
    float _pendingControlParam2{0.0f};

    enum PendingOp {
        PendingNone,
        PendingGet,
        PendingSet
    };
    PendingOp _pendingOp{PendingNone};
    QList<int> _pendingGetQueue;
    QList<QPair<int, float>> _pendingSetQueue;
    float _pendingSetValue{0.0f};
    bool _paramSetFailed[6]{false, false, false, false, false, false};
    bool _pendingStatus{false};
    bool _pwrStatus{true};
    bool kGenInfoAcqRunning = false;
    QStringList _pendingStatusQueue;

    quint8 _insInfo{0};
    quint8 _scnInfo{0};
    quint8 _genInfo{0};
    quint8 _insErr{0};
    quint8 _scnErr{0};
    quint8 _intErr{0};
    quint8 _camErr{0};

    int _scannerHighSensitivity{0};
    int _scannerPattern{0};
    int _embeddedCamera{0};
    float _embCamInitHeight{0.0f};
    int _embCamTriggerMode{0};
    float _embCamTriggerValue{0.0f};
    int _pendingParamIndex{-1};

    QString _lastSentMessage;
    QString _lastReceivedMessage;

    static constexpr qint64 kStatusTimeoutMs = 7000;
    static constexpr qint64 kStatusResponseTimeoutMs = 2000;
    static constexpr qint64 kParamResponseTimeoutMs = 2000;
    static constexpr qint64 kSetResponseTimeoutMs = 2000;
    // Assumed bit mapping for info bytes (can be adjusted when spec is confirmed)
    static constexpr quint8 kInsInfoTimeNotSet = 1 << 5;  
    static constexpr quint8 kInsInfoNotLocked = 1 << 1;   
    static constexpr quint8 kScnInfoNotReady  = 1 << 1;
    static constexpr quint8 kGenInfoNoUsb     = 1 << 0;
    static constexpr quint8 kGenInfoUsbFull   = 1 << 2;

    enum YSParameterIndex {
        ParamScannerHighSensitivity = 0,
        ParamScannerPattern         = 1,
        ParamEmbeddedCameraEnable   = 2,
        ParamEmbCamInitHeight       = 3,
        ParamEmbCamTriggerMode      = 4,
        ParamEmbCamTriggerValue     = 5
    };
};