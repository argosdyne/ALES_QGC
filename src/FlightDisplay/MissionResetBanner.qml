/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.12
import QtQuick.Dialogs  1.3
import QtQuick.Layouts  1.12

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0

// Opens the standard QGC dialog when a Copter MIS_OPTIONS notice is active.
Item {
    id: bannerRoot

    property var    _vehicle:           QGroundControl.multiVehicleManager.activeVehicle
    property var    _monitor:           _vehicle ? _vehicle.missionResetMonitor : null
    property bool   _show:              _monitor ? (_monitor.rebootBannerVisible || _monitor.bannerVisible) : false
    property var    _dialog:            null
    property bool   _handlingClose:     false
    property int    _startMode:         _monitor ? _monitor.startFailureMode : 0
    property var    _startDialog:       null
    property bool   _handlingStartClose: false

    on_ShowChanged: _syncDialog()
    on_StartModeChanged: _syncStartDialog()

    function _syncDialog() {
        if (_handlingClose) {
            return
        }
        if (_show) {
            if (!_dialog) {
                _dialog = dialogComponent.createObject(mainWindow)
                _dialog.open()
            }
        } else if (_dialog) {
            var existing = _dialog
            _dialog = null
            existing.close()
        }
    }

    function _dismiss() {
        if (!_monitor) {
            return
        }
        // Clear the request even when the text is hidden. Otherwise an upload
        // that makes the mission list non-empty opens the notice again.
        _monitor.dismissBanner()
        _monitor.dismissRebootBanner()
    }

    function _syncStartDialog() {
        if (_handlingStartClose) {
            return
        }
        if (_startMode !== 0) {
            if (!_startDialog) {
                _startDialog = startDialogComponent.createObject(mainWindow)
                _startDialog.open()
            }
        } else if (_startDialog) {
            var existing = _startDialog
            _startDialog = null
            existing.close()
        }
    }

    function _dismissStart() {
        if (_monitor && _monitor.startFailureMode !== 0) {
            _monitor.dismissStartFailure()
        }
    }

    Component {
        id: dialogComponent

        QGCPopupDialog {
            id:         popup
            title:      _monitor && _monitor.rebootBannerVisible ? qsTr("Vehicle reboot detected") : qsTr("Mission")
            // Reboot notice and the clear-on-reboot notice both dismiss on Ok, so only Ok is shown.
            // buttons is applied once in onAboutToShow, so a later reboot has to apply it again.
            property bool _rebootNotice: _monitor && _monitor.rebootBannerVisible
            buttons:    _rebootNotice || (_monitor && _monitor.showConfirmButton)
                            ? StandardButton.Ok
                            : StandardButton.Close
            on_RebootNoticeChanged: {
                if (visible) {
                    setupDialogButtons(buttons)
                }
            }

            onClosed: {
                bannerRoot._handlingClose = true
                bannerRoot._dismiss()
                bannerRoot._dialog = null
                bannerRoot._handlingClose = false
            }

            ColumnLayout {
                width:      Math.min(ScreenTools.defaultFontPixelWidth * 42, popup._maxContentWidth)
                spacing:    ScreenTools.defaultFontPixelHeight * 0.6

                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    visible:            _monitor && _monitor.rebootBannerVisible
                    text:               _monitor ? _monitor.rebootBannerText : ""
                }

                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    visible:            _monitor && _monitor.bannerVisible
                    text:               _monitor ? _monitor.bannerText : ""
                }

                QGCButton {
                    Layout.fillWidth:   true
                    visible:            _monitor && _monitor.showMissionActions
                    text:               qsTr("Review Mission")
                    onClicked: {
                        mainWindow.showPlanView()
                        popup.close()
                    }
                }

                QGCButton {
                    Layout.fillWidth:   true
                    visible:            _monitor && _monitor.showMissionActions
                    text:               qsTr("Settings")
                    onClicked: {
                        mainWindow.showSetupMission()
                        popup.close()
                    }
                }
            }
        }
    }

    Component {
        id: startDialogComponent

        QGCPopupDialog {
            id:         startPopup
            title:      qsTr("Mission start failed")
            buttons:    StandardButton.Close

            onClosed: {
                bannerRoot._handlingStartClose = true
                bannerRoot._dismissStart()
                bannerRoot._startDialog = null
                bannerRoot._handlingStartClose = false
            }

            ColumnLayout {
                width:      Math.min(ScreenTools.defaultFontPixelWidth * 42, startPopup._maxContentWidth)
                spacing:    ScreenTools.defaultFontPixelHeight * 0.6

                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    visible:            bannerRoot._startMode === 1
                    text:               qsTr("No mission items on the vehicle (0).")
                }

                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    visible:            bannerRoot._startMode === 1 && _monitor && _monitor.emptyStartShowCause
                    text:               qsTr("Cause: the mission was cleared by a vehicle reboot (MIS_OPTIONS bit0 = 1).")
                }

                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    visible:            bannerRoot._startMode === 1
                    text:               qsTr("Re-upload the mission, then start it.")
                }

                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    font.pointSize:     ScreenTools.smallFontPointSize
                    visible:            bannerRoot._startMode === 1
                    text:               _monitor ? _monitor.emptyStartDetails : ""
                }

                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    visible:            bannerRoot._startMode === 2
                    text:               _monitor ? _monitor.otherStartFailureText : ""
                }

                QGCButton {
                    Layout.fillWidth:   true
                    visible:            bannerRoot._startMode === 1
                    text:               qsTr("Upload Mission")
                    onClicked: {
                        bannerRoot._dismiss()
                        mainWindow.showPlanMissionUpload()
                        startPopup.close()
                    }
                }
            }
        }
    }
}
