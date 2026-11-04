/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick 2.3

import QGroundControl               1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controls      1.0

/// No GPS lock / pre-arm failure warning, shown as a WarningToast at the top of the Fly view.
/// Closing it hides the current message only; a different message shows it again.
WarningToast {
    visible:        (_noGPSLockVisible || _prearmErrorVisible) && _messageKey !== _dismissedKey
    strongText:     _noGPSLockVisible ? qsTr("No GPS Lock for Vehicle") : (_prearmErrorVisible ? _prearmError : "")
    text:           _bodyText

    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property bool   _noGPSLockVisible:      _activeVehicle && _activeVehicle.requiresGpsFix && !_activeVehicle.coordinate.isValid
    property bool   _prearmErrorVisible:    _activeVehicle && !_activeVehicle.armed && _activeVehicle.prearmError && !_activeVehicle.healthAndArmingCheckReport.supported
    property string _prearmError:           _activeVehicle ? _activeVehicle.prearmError : ""
    property string _prearmHelp:            qsTr("The vehicle has failed a pre-arm check. In order to arm the vehicle, resolve the failure.")
    property string _bodyText: {
        if (!_prearmErrorVisible) {
            return ""
        }
        return _noGPSLockVisible ? _prearmError + ". " + _prearmHelp : _prearmHelp
    }
    property string _messageKey:            (_noGPSLockVisible ? "gps;" : "") + (_prearmErrorVisible ? _prearmError : "")
    property string _dismissedKey

    onCloseClicked: _dismissedKey = _messageKey
}
