/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include <QDateTime>
#include <QObject>
#include <QString>
#include <QTimer>
#include <QVariant>

#include "QGCMAVLink.h"

class Fact;
class Vehicle;

/// Copter-only connect banner and reboot detection for MIS_OPTIONS bit0.
class APMMissionResetMonitor : public QObject
{
    Q_OBJECT

public:
    explicit APMMissionResetMonitor(Vehicle* vehicle, QObject* parent = nullptr);

    Q_PROPERTY(bool     bannerVisible           READ bannerVisible          NOTIFY bannerChanged)
    Q_PROPERTY(bool     bannerIsWarning         READ bannerIsWarning        NOTIFY bannerChanged)
    Q_PROPERTY(QString  bannerText              READ bannerText             NOTIFY bannerChanged)
    Q_PROPERTY(bool     showMissionActions      READ showMissionActions     NOTIFY bannerChanged)
    Q_PROPERTY(bool     showConfirmButton       READ showConfirmButton      NOTIFY bannerChanged)
    Q_PROPERTY(bool     rebootBannerVisible     READ rebootBannerVisible    NOTIFY rebootStateChanged)
    Q_PROPERTY(QString  rebootBannerText        READ rebootBannerText       CONSTANT)
    Q_PROPERTY(bool     rebootDetected          READ rebootDetected         NOTIFY rebootStateChanged)
    Q_PROPERTY(bool     missionUnconfirmed      READ missionUnconfirmed     NOTIFY rebootStateChanged)
    Q_PROPERTY(bool     sawClearingMission      READ sawClearingMission     NOTIFY rebootStateChanged)
    Q_PROPERTY(QString  rebootDetectedTime      READ rebootDetectedTime     NOTIFY rebootStateChanged)
    Q_PROPERTY(int      startFailureMode        READ startFailureMode       NOTIFY startFailureChanged)
    Q_PROPERTY(bool     emptyStartShowCause     READ emptyStartShowCause    NOTIFY startFailureChanged)
    Q_PROPERTY(QString  emptyStartDetails       READ emptyStartDetails      NOTIFY startFailureChanged)
    Q_PROPERTY(QString  otherStartFailureText   READ otherStartFailureText  NOTIFY startFailureChanged)

    bool    bannerVisible       () const;
    bool    bannerIsWarning     () const { return !_clearOnReboot; }
    QString bannerText          () const;
    bool    showMissionActions  () const { return bannerVisible() && !_clearOnReboot; }
    bool    showConfirmButton   () const { return bannerVisible() && _clearOnReboot; }
    bool    rebootBannerVisible () const;
    QString rebootBannerText    () const;
    bool    rebootDetected      () const { return _rebootDetected; }
    bool    missionUnconfirmed  () const { return _missionUnconfirmed; }
    bool    sawClearingMission  () const { return _sawClearingMission; }
    QString rebootDetectedTime  () const;

    Q_INVOKABLE void dismissBanner();
    Q_INVOKABLE void dismissRebootBanner();
    Q_INVOKABLE void dismissStartFailure();

    void handleSystemTime(uint32_t timeBootMs);
    void handleStatusText(const QString& text);
    void beginMissionStart();
    void noteMissionStartCommand();
    void handleMissionStartResult(int mavResult, int failureCode);

    int     startFailureMode        () const { return _startFailureMode; }
    bool    emptyStartShowCause     () const { return _rebootDetected && _clearOnReboot; }
    QString emptyStartDetails       () const { return _emptyStartDetails; }
    QString otherStartFailureText   () const { return _otherStartFailureText; }

    static const int StartFailureNone = 0;
    static const int StartFailureEmpty = 1;
    static const int StartFailureOther = 2;

signals:
    void bannerChanged();
    void rebootStateChanged();
    void startFailureChanged();

private slots:
    void _parametersReady(bool parametersReady);
    void _misOptionsChanged(QVariant value);
    void _missionSendComplete(bool error);
    void _missionItemsChanged(bool success);
    void _probeMavlinkMessage(const mavlink_message_t& message);
    void _probeTimedOut();

private:
    void _applyValue(int value);
    void _noteReboot();
    void _requestSystemTime();
    void _updateMissionItemState();
    void _tryPresentConnectNotice();
    bool _missionListKnown() const;
    bool _vehicleHasMissionItems() const;
    void _beginCountProbe(int purpose);
    void _sendMissionCountRequest();
    void _cancelMissionRead();
    void _stopProbe();
    void _finishProbe(int count);
    void _presentEmptyStart(int count, int purpose);
    void _presentOtherStartFailure();

    static const int        _clearMissionBit = 1;
    static const uint32_t   _rebootDropMs = 2000;
    static const int        ProbeNone = 0;
    static const int        ProbeBeforeStart = 1;
    static const int        ProbeAfterReject = 2;

    Vehicle*    _vehicle = nullptr;
    Fact*       _misOptions = nullptr;
    bool        _valueKnown = false;
    bool        _clearOnReboot = false;
    bool        _hasMissionItems = false;
    bool        _bitBannerRequested = false;
    bool        _awaitingConnectNotice = false;
    bool        _connectNoticeStarted = false;
    bool        _blockConnectNotice = false;
    bool        _rebootBannerVisible = false;
    bool        _rebootDetected = false;
    bool        _missionUnconfirmed = false;
    bool        _sawClearingMission = false;
    QDateTime   _rebootDetectedAt;
    int         _startFailureMode = StartFailureNone;
    QString     _emptyStartDetails;
    QString     _otherStartFailureText;
    bool        _probeActive = false;
    int         _probePurpose = ProbeNone;
    int         _probeRetries = 0;
    bool        _captureStartStatus = false;
    QString     _startFailureStatusText;
    int         _rejectedMavResult = 0;
    int         _rejectedFailureCode = 0;
    QTimer      _probeTimer;
};
