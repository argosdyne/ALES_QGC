/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#pragma once

#include "FactPanelController.h"

#include <QTimer>

class Fact;

/// Sets MIS_OPTIONS bit0 and bit2. Other bits are read back and preserved.
class APMMissionComponentController : public FactPanelController
{
    Q_OBJECT

public:
    enum Status {
        StatusNone = 0,
        StatusApplied,
        StatusFailed,
        StatusReadFailed
    };
    Q_ENUM(Status)

    APMMissionComponentController();

    Q_PROPERTY(bool valueKnown                  READ valueKnown                 NOTIFY stateChanged)
    Q_PROPERTY(bool clearOnReboot               READ clearOnReboot              NOTIFY stateChanged)
    Q_PROPERTY(bool continueAfterLand           READ continueAfterLand          NOTIFY stateChanged)
    Q_PROPERTY(bool continueAfterLandSupported READ continueAfterLandSupported NOTIFY stateChanged)
    Q_PROPERTY(int  currentValue                READ currentValue               NOTIFY stateChanged)
    Q_PROPERTY(bool busy                        READ busy                       NOTIFY stateChanged)
    Q_PROPERTY(bool dirty                       READ dirty                      NOTIFY stateChanged)
    Q_PROPERTY(int  status                      READ status                     NOTIFY stateChanged)
    Q_PROPERTY(bool lastApplyChangedClear       READ lastApplyChangedClear      NOTIFY stateChanged)
    Q_PROPERTY(bool lastApplyChangedContinue    READ lastApplyChangedContinue   NOTIFY stateChanged)

    bool valueKnown                 (void) const { return _valueKnown; }
    bool clearOnReboot              (void) const { return _clearOnReboot; }
    bool continueAfterLand          (void) const { return _continueAfterLand; }
    bool continueAfterLandSupported (void) const;
    int  currentValue               (void) const { return _currentValue; }
    bool busy                       (void) const { return _busy; }
    bool dirty                      (void) const;
    int  status                     (void) const { return _status; }
    bool lastApplyChangedClear      (void) const { return _lastApplyChangedClear; }
    bool lastApplyChangedContinue   (void) const { return _lastApplyChangedContinue; }

    Q_INVOKABLE void refresh(void);
    Q_INVOKABLE void setClearOnReboot(bool clearOnReboot);
    Q_INVOKABLE void setContinueAfterLand(bool continueAfterLand);
    Q_INVOKABLE void apply(void);
    Q_INVOKABLE void cancel(void);

signals:
    void stateChanged(void);

private slots:
    void _onVehicleUpdated(const QVariant& value);
    void _onTimeout(void);

private:
    enum State {
        Idle,
        WaitingInitialRead,
        WaitingApplyRead,
        WaitingWrite
    };

    void _requestRead(State state);
    void _failApply(void);
    void _setDraftFromValue(int value);
    int  _valueWithDraftBits(int reported) const;
    static int _reportedValue(const QVariant& value);

    Fact*   _fact                       = nullptr;
    QTimer  _timer;
    State   _state                      = Idle;
    bool    _valueKnown                 = false;
    bool    _clearOnReboot              = false;
    bool    _continueAfterLand          = false;
    bool    _busy                       = false;
    bool    _lastApplyChangedClear      = false;
    bool    _lastApplyChangedContinue   = false;
    int     _currentValue               = 0;
    int     _expectedValue              = 0;
    int     _status                     = StatusNone;

    static const int _clearMissionBit = 1;
    static const int _continueAfterLandBit = 4;
    static const int _responseTimeoutMs = 15000;
};
