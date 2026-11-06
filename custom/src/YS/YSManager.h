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

    // LiDAR Setup > Connection [Test]
    enum TestState {
        TestIdle = 0,
        TestRunning,
        TestOk,
        TestFailed
    };
    Q_ENUM(TestState)
    Q_PROPERTY(int     testState               READ testState               NOTIFY testChanged)
    Q_PROPERTY(QString testMessage             READ testMessage             NOTIFY testChanged)

    // YS-03 Fly View toolbar indicator / toolstrip / LiDAR panel.
    // All Get Status bit decoding and state decisions for these live here; QML only displays.
    enum LidarState {
        StateDisabled = 0,  // ysEnable off - all LiDAR UI hidden
        StateNoLink,        // no active vehicle, or vehicle link lost
        StateNoResponse,    // vehicle link OK but no valid Get Status reply
        StatePoweredOff,    // Power Off accepted by LiDAR, no status since
        StateNotReady,      // Get Status OK, one or more pre-checks not met
        StateReady,         // Get Status OK, all decoded pre-checks met
        StateStarting,      // Start sent, waiting for COMMAND_ACK
        StateRecording,     // acquisition running
        StateStopping       // Stop sent, waiting for COMMAND_ACK
    };
    Q_ENUM(LidarState)

    enum PreCheckState {
        PreCheckOk = 0,
        PreCheckFail,
        PreCheckUnknown,    // no valid status, or bit not decoded yet
        PreCheckNotUsed     // e.g. camera set to None
    };
    Q_ENUM(PreCheckState)

    enum UsbState {
        UsbUnknown = 0,
        UsbOk,
        UsbMissing,
        UsbFull
    };
    Q_ENUM(UsbState)

    // embCamTriggerMode values (same order as LiDAR Setup > Device "Emb. Cam. Trigger Mode")
    enum TriggerMode {
        TriggerModeTime = 0,
        TriggerModeDistance = 1
    };
    Q_ENUM(TriggerMode)

    Q_PROPERTY(int          lidarState              READ lidarState             NOTIFY lidarStateChanged)
    /// Six rows: [{ name, state (PreCheckState), detail }] - INS/GNSS, Scanner, System time, USB stick, Camera, Temperature
    Q_PROPERTY(QVariantList preChecks               READ preChecks              NOTIFY lidarStateChanged)
    Q_PROPERTY(int          unmetPreCheckCount      READ unmetPreCheckCount     NOTIFY lidarStateChanged)
    Q_PROPERTY(bool         internalError           READ internalError          NOTIFY lidarStateChanged)
    Q_PROPERTY(int          usbState                READ usbState               NOTIFY lidarStateChanged)
    /// HH:mm:ss when the alarm row content (unmet count / internal error) last changed
    Q_PROPERTY(QString      alarmSinceTime          READ alarmSinceTime         NOTIFY lidarStateChanged)
    Q_PROPERTY(int          recordingSeconds        READ recordingSeconds       NOTIFY recordingSecondsChanged)
    Q_PROPERTY(bool         cameraParamsKnown       READ cameraParamsKnown      NOTIFY parameterChanged)
    Q_PROPERTY(int          statusPollIntervalMs    READ statusPollIntervalMs   CONSTANT)

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
    quint8 insErr(void) const { return _insErr || (_insInfo & 0x01); }
    quint8 scnErr(void) const { return _scnErr || (_scnInfo & 0x01); }
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

    int testState(void) const { return _testState; }
    QString testMessage(void) const { return _testMessage; }

    int          lidarState(void) const { return _lidarState; }
    QVariantList preChecks(void) const { return _preChecks; }
    int          unmetPreCheckCount(void) const { return _unmetPreCheckCount; }
    bool         internalError(void) const { return _statusValid && _intErr != 0; }
    int          usbState(void) const;
    QString      alarmSinceTime(void) const { return _alarmSinceTime; }
    int          recordingSeconds(void) const;
    bool         cameraParamsKnown(void) const;
    int          statusPollIntervalMs(void) const { return kStatusPollIntervalMs; }

    /// Sends one Get Status (YS_STA_00 + YS_STA_01) and reports the result through testState/testMessage
    Q_INVOKABLE void testConnection(void);

    Q_INVOKABLE void startAcquisition(void);
    Q_INVOKABLE void stopAcquisition(void);
    Q_INVOKABLE void powerOff(void);
    Q_INVOKABLE void requestStatus(void);
    Q_INVOKABLE void setParameter(int paramIndex, float value);
    Q_INVOKABLE void requestParameter(int paramIndex);
    /// Reads the embedded camera parameters used by the Fly View LiDAR panel camera summary
    Q_INVOKABLE void requestCameraParameters(void);

    // Overrides from QGCTool
    void setToolbox(QGCToolbox* toolbox) override;

signals:
    void statusChanged(void);
    void statusValidChanged(void);
    void parameterChanged(void);
    void messageChanged(void);
    void paramSetFailedChanged(void);
    void testChanged(void);
    void lidarStateChanged(void);
    void recordingSecondsChanged(void);

private slots:
    void _setActiveVehicle(Vehicle* vehicle);
    void _mavlinkReceived(const mavlink_message_t& message);
    void _checkStatusTimeout(void);
    void _restorePowerStatus(void);
    void _testTimeout(void);
    void _statusPollTick(void);
    void _refreshLidarState(void);

private:
    static constexpr int kYellowScanSysId = 1;
    static constexpr int kYellowScanDefaultCompId = MAV_COMP_ID_USER1;
    uint8_t _compId(void) const;
    void _finishTest(TestState state, const QString& message);
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
    bool _ysEnabled(void) const;
    bool _cameraInstalled(void) const;
    LidarState _computeLidarState(void) const;
    void _rebuildPreChecks(void);

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
    QList<bool> _acqRequests;           // Start (true) / Stop (false) sent and not yet ACKed, oldest first
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

    QTimer _testTimer;
    TestState _testState{TestIdle};
    QString _testMessage;
    bool _testGotSta00{false};
    bool _testGotSta01{false};
    // Get Status = YS_STA_00 then YS_STA_01, each with a 2 s reply window
    static constexpr int kTestTimeoutMs = 4000;

    // YS-03 state machine
    enum AcqTransition { AcqNone, AcqStarting, AcqStopping };
    QTimer        _getStatusPollTimer;
    LidarState    _lidarState{StateDisabled};
    QVariantList  _preChecks;
    int           _unmetPreCheckCount{0};
    QString       _alarmSinceTime;
    bool          _poweredOff{false};
    AcqTransition _acqTransition{AcqNone};
    QElapsedTimer _acqTransitionTimer;
    QElapsedTimer _acqAckHintTimer;     // started on an accepted Start/Stop ACK; Get Status does not override the flag until it expires
    QElapsedTimer _recordingTimer;
    bool          _wasRecording{false};
    int           _lastRecordingSeconds{0};
    bool          _paramReceived[6]{false, false, false, false, false, false};

    // Get Status poll rate required by YS-03 (1 Hz)
    static constexpr int    kStatusPollIntervalMs = 1000;
    // How long STARTING / STOPPING is shown when no COMMAND_ACK arrives
    static constexpr qint64 kAcqCommandAckTimeoutMs = 5000;

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
    static constexpr quint8 kGenInfoDataLogging = 1 << 3;
    static constexpr quint8 kIntErrOverheat     = 1 << 0;   // internal computer >= 70 C
    static constexpr quint8 kIntErrTempWarning  = 1 << 1;   // internal computer > 65 C

    enum YSParameterIndex {
        ParamScannerHighSensitivity = 0,
        ParamScannerPattern         = 1,
        ParamEmbeddedCameraEnable   = 2,
        ParamEmbCamInitHeight       = 3,
        ParamEmbCamTriggerMode      = 4,
        ParamEmbCamTriggerValue     = 5
    };
};