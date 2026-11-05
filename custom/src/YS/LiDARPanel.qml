/****************************************************************************
 *
 * YS-03 Fly View LiDAR panel (UI Y-01 / Y-02)
 *   ③ header: state chip + subtitle (model · link)
 *   ④ PRE-CHECK: six rows from 1 Hz Get Status
 *   ⑥ camera summary
 *   ⑦ alarm row + LiDAR Setup link
 * Acquisition Start / Stop (⑤) is not part of YS-03.
 * Bit decoding and state decisions are in YSManager; this file only displays them.
 *
 ****************************************************************************/

import QtQuick          2.11
import QtQuick.Layouts  1.11

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Palette       1.0
import CustomQuickInterface         1.0

Rectangle {
    id:             _root
    width:          ScreenTools.defaultFontPixelWidth * 38
    height:         Math.min(mainColumn.height + (_margins * 2), maxHeight)
    radius:         ScreenTools.defaultFontPixelWidth / 2
    color:          qgcPal.window

    property real maxHeight     ///< Set by the parent: available height, panel scrolls beyond it

    property var  _settings:        QGroundControl.corePlugin.settings
    property var  _ys:              QGroundControl.corePlugin.ysManager
    property int  _state:           _ys ? _ys.lidarState : YSManager.StateDisabled
    property bool _statusValid:     _ys ? _ys.statusValid : false
    property bool _cameraInstalled: _settings ? _settings.ysCamera.rawValue !== 0 : false
    property real _margins:         ScreenTools.defaultFontPixelWidth * 1.5
    property real _rowSpacing:      ScreenTools.defaultFontPixelHeight * 0.4
    property string _sep:           " · "
    property bool _cameraParamsRequested: false

    QGCPalette { id: qgcPal }

    // Camera summary needs the LiDAR-side camera parameters: read them once per panel open,
    // as soon as the LiDAR answers (no retry loop if the LiDAR does not reply to Get Parameter)
    function _requestCameraParams() {
        if (!_cameraParamsRequested && _ys && _cameraInstalled && _statusValid && !_ys.cameraParamsKnown) {
            _cameraParamsRequested = true
            _ys.requestCameraParameters()
        }
    }

    Component.onCompleted:      _requestCameraParams()
    on_StatusValidChanged:      _requestCameraParams()
    on_CameraInstalledChanged:  _requestCameraParams()

    function _chipText() {
        switch (_state) {
        case YSManager.StateReady:      return qsTr("READY")
        case YSManager.StateNotReady:   return qsTr("NOT READY")
        case YSManager.StateRecording:  return qsTr("● REC")
        case YSManager.StateStarting:   return qsTr("STARTING")
        case YSManager.StateStopping:   return qsTr("STOPPING")
        case YSManager.StateNoResponse: return qsTr("NO RESPONSE")
        case YSManager.StatePoweredOff: return qsTr("POWERED OFF")
        default:                        return qsTr("NO LINK")
        }
    }

    function _chipColor() {
        switch (_state) {
        case YSManager.StateReady:      return qgcPal.colorGreen
        case YSManager.StateNotReady:
        case YSManager.StateStarting:
        case YSManager.StateStopping:   return qgcPal.colorOrange
        case YSManager.StateRecording:
        case YSManager.StateNoResponse: return qgcPal.colorRed
        default:                        return qgcPal.colorGrey
        }
    }

    function _dotColor(preCheckState) {
        switch (preCheckState) {
        case YSManager.PreCheckOk:      return qgcPal.colorGreen
        case YSManager.PreCheckFail:    return qgcPal.colorOrange
        default:                        return qgcPal.colorGrey
        }
    }

    // Trigger value in s (Time) / m (Distance), init height in m
    function _cameraValueText() {
        if (!_cameraInstalled) {
            return qsTr("Not used")
        }
        if (!_ys || !_ys.cameraParamsKnown) {
            return "--"
        }
        if (_ys.embeddedCamera === 0) {
            return qsTr("Disabled")
        }
        var v = _ys.embCamTriggerValue.toFixed(1)
        return _ys.embCamTriggerMode === YSManager.TriggerModeDistance ? qsTr("Every %1 m").arg(v) : qsTr("Every %1 s").arg(v)
    }

    function _cameraDetailText() {
        if (!_cameraInstalled) {
            return qsTr("No camera set in LiDAR Setup")
        }
        if (!_ys || !_ys.cameraParamsKnown) {
            return qsTr("Camera settings not read from LiDAR yet")
        }
        if (_ys.embeddedCamera === 0) {
            return qsTr("Scanner settings in LiDAR Setup")
        }
        var mode = _ys.embCamTriggerMode === YSManager.TriggerModeDistance ? qsTr("Distance trigger") : qsTr("Time trigger")
        return mode + _sep + qsTr("start at %1 m").arg(_ys.embCamInitHeight.toFixed(0)) + _sep + qsTr("scanner settings in LiDAR Setup")
    }

    // Keep clicks off the map below
    DeadMouseArea {
        anchors.fill: parent
    }

    QGCFlickable {
        anchors.fill:       parent
        anchors.margins:    _margins
        contentHeight:      mainColumn.height
        flickableDirection: Flickable.VerticalFlick
        clip:               true

        ColumnLayout {
            id:         mainColumn
            width:      parent.width
            spacing:    _rowSpacing

            //-- ③ Header: title + state chip
            RowLayout {
                Layout.fillWidth: true

                QGCLabel {
                    text:               qsTr("LiDAR")
                    font.pointSize:     ScreenTools.mediumFontPointSize
                    font.family:        ScreenTools.demiboldFontFamily
                    Layout.fillWidth:   true
                }

                // Layout.preferred* so the RowLayout reserves the full chip (long states like NO RESPONSE)
                Rectangle {
                    Layout.preferredWidth:  chipLabel.contentWidth + ScreenTools.defaultFontPixelWidth * 2
                    Layout.preferredHeight: chipLabel.contentHeight + ScreenTools.defaultFontPixelHeight * 0.3
                    radius: height / 2
                    color:  _chipColor()

                    QGCLabel {
                        id:                 chipLabel
                        anchors.centerIn:   parent
                        text:               _chipText()
                        color:              "white"
                        font.family:        ScreenTools.demiboldFontFamily
                    }
                }
            }

            //-- ③ Subtitle: model · link
            QGCLabel {
                Layout.fillWidth:   true
                text:               _settings ? (_settings.ysModel.enumStringValue + _sep + _settings.ysLink.enumStringValue) : ""
                opacity:            0.6
                wrapMode:           Text.WordWrap
            }

            //-- ④ PRE-CHECK
            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("PRE-CHECK") + _sep + qsTr("Get Status %1 Hz").arg(_ys ? 1000 / _ys.statusPollIntervalMs : 0)
                font.family:        ScreenTools.demiboldFontFamily
                opacity:            0.6
            }

            Repeater {
                model: _ys ? _ys.preChecks : []

                RowLayout {
                    Layout.fillWidth:   true
                    spacing:            ScreenTools.defaultFontPixelWidth

                    Rectangle {
                        width:      ScreenTools.defaultFontPixelHeight * 0.6
                        height:     width
                        radius:     width / 2
                        color:      _dotColor(modelData.state)
                    }

                    QGCLabel {
                        text:               modelData.name
                        Layout.fillWidth:   true
                    }

                    QGCLabel {
                        text:       modelData.detail
                        color:      modelData.state === YSManager.PreCheckFail ? qgcPal.colorOrange : qgcPal.text
                        opacity:    modelData.state === YSManager.PreCheckFail ? 1.0 : 0.6
                    }
                }
            }

            Rectangle {
                Layout.fillWidth:   true
                height:             1
                color:              qgcPal.windowShade
            }

            //-- ⑥ Camera summary
            RowLayout {
                Layout.fillWidth: true

                QGCLabel {
                    text:               qsTr("Camera")
                    font.pointSize:     ScreenTools.mediumFontPointSize
                    opacity:            0.6
                    Layout.fillWidth:   true
                }

                QGCLabel {
                    text:           _cameraValueText()
                    font.pointSize: ScreenTools.mediumFontPointSize
                    font.family:    ScreenTools.demiboldFontFamily
                }
            }

            QGCLabel {
                Layout.fillWidth:   true
                text:               _cameraDetailText()
                wrapMode:           Text.WordWrap
                opacity:            0.6
            }

            Rectangle {
                Layout.fillWidth:   true
                height:             1
                color:              qgcPal.windowShade
            }

            //-- ⑦ Alarm row
            Rectangle {
                id:                     alarmRow
                Layout.fillWidth:       true
                Layout.preferredHeight: alarmLabel.contentHeight + ScreenTools.defaultFontPixelHeight * 0.6
                radius:                 ScreenTools.defaultFontPixelWidth / 2
                color:                  qgcPal.windowShade

                property bool _hasStatus:   _statusValid
                property int  _unmet:       _ys ? _ys.unmetPreCheckCount : 0
                property bool _intErr:      _ys ? _ys.internalError : false

                function alarmText() {
                    if (!_hasStatus) {
                        return qsTr("No status from LiDAR")
                    }
                    var parts = []
                    if (_unmet > 0) {
                        parts.push(_unmet === 1 ? qsTr("! 1 pre-check not met") : qsTr("! %1 pre-checks not met").arg(_unmet))
                    }
                    if (_intErr) {
                        parts.push(qsTr("Internal error"))
                    }
                    return parts.length ? parts.join(_sep) : qsTr("✓ No active alarms")
                }

                function alarmColor() {
                    if (!_hasStatus) {
                        return qgcPal.colorGrey
                    }
                    if (_intErr) {
                        return qgcPal.colorRed
                    }
                    return _unmet > 0 ? qgcPal.colorOrange : qgcPal.colorGreen
                }

                QGCLabel {
                    id:                     alarmLabel
                    anchors.left:           parent.left
                    anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
                    anchors.right:          alarmTime.left
                    anchors.rightMargin:    ScreenTools.defaultFontPixelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   alarmRow.alarmText()
                    color:                  alarmRow.alarmColor()
                    font.family:            ScreenTools.demiboldFontFamily
                    wrapMode:               Text.WordWrap
                }

                QGCLabel {
                    id:                     alarmTime
                    anchors.right:          parent.right
                    anchors.rightMargin:    ScreenTools.defaultFontPixelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   _ys && alarmRow._hasStatus ? _ys.alarmSinceTime : ""
                    opacity:                0.6
                }
            }

            //-- ⑦ LiDAR Setup link
            QGCLabel {
                text:           qsTr("LiDAR Setup") + "  ›"
                color:          qgcPal.colorBlue
                font.family:    ScreenTools.demiboldFontFamily

                QGCMouseArea {
                    anchors.fill:   parent
                    onClicked: {
                        if (!mainWindow.preventViewSwitch()) {
                            mainWindow.showLidarSetupTool()
                        }
                    }
                }
            }
        }
    }
}
