/****************************************************************************
 *
 * YS-03 Fly View toolbar LiDAR indicator (UI Y-01 ①)
 * Line 1: state (READY / CHECK / REC mm:ss / NO LINK ...), line 2: USB.
 * Tap opens the LiDAR panel. State comes from YSManager only.
 *
 ****************************************************************************/

import QtQuick          2.11

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Palette       1.0
import CustomQuickInterface         1.0

Item {
    id:             _root
    width:          indicatorRow.width
    anchors.top:    parent.top
    anchors.bottom: parent.bottom

    property bool showIndicator: _settings ? _settings.ysEnable.rawValue : false

    property var  _settings:    QGroundControl.corePlugin.settings
    property var  _ys:          QGroundControl.corePlugin.ysManager
    property int  _state:       _ys ? _ys.lidarState : YSManager.StateDisabled
    property int  _usb:         _ys ? _ys.usbState : YSManager.UsbUnknown
    // YS-04 Y-02 ①: a Start rejected by the LiDAR shows CHECK even when all pre-checks pass
    property bool _check:       _state === YSManager.StateNotReady ||
                                (_state === YSManager.StateReady && !!mainWindow.lidarAcquisition && mainWindow.lidarAcquisition.startRejected)
    // YS-05: no-reply handling from LiDARAlerts (Y-05 ①: NO LINK after the no-response time)
    property var  _alerts:      mainWindow.lidarAlerts
    property bool _noResponse:  !!_alerts && _alerts.noResponse
    property bool _poweredOff:  !!_alerts && _alerts.poweredOff
    property bool _delayed:     !!_alerts && _alerts.delayed
    property bool _usbLow:      !!_alerts && _alerts.usbLow && !_noResponse

    QGCPalette { id: qgcPal }

    function _mmss(totalSeconds) {
        var m = Math.floor(totalSeconds / 60)
        var s = totalSeconds % 60
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
    }

    function _stateText() {
        if (_noResponse) {
            return qsTr("NO LINK")
        }
        if (_poweredOff) {
            return qsTr("POWERED OFF")
        }
        if (_check) {
            return qsTr("CHECK")
        }
        switch (_state) {
        case YSManager.StateReady:      return qsTr("READY")
        case YSManager.StateNotReady:   return qsTr("CHECK")
        case YSManager.StateRecording:  return qsTr("REC %1").arg(_mmss(_ys.recordingSeconds))
        case YSManager.StateStarting:   return qsTr("STARTING")
        case YSManager.StateStopping:   return qsTr("STOPPING")
        case YSManager.StateNoResponse: return qsTr("NO RESPONSE")
        case YSManager.StatePoweredOff: return qsTr("POWERED OFF")
        default:                        return qsTr("NO LINK")
        }
    }

    function _stateColor() {
        if (_noResponse || _poweredOff) {
            return qgcPal.colorGrey
        }
        if (_check || _delayed) {
            return qgcPal.colorOrange
        }
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

    function _usbText() {
        if (_noResponse) {
            return "—"
        }
        if (_usbLow && _usb === YSManager.UsbOk) {
            return qsTr("USB LOW")
        }
        switch (_usb) {
        case YSManager.UsbOk:       return qsTr("USB OK")
        case YSManager.UsbFull:     return qsTr("USB FULL")
        case YSManager.UsbMissing:  return qsTr("NO USB")
        default:                    return qsTr("USB --")
        }
    }

    Row {
        id:             indicatorRow
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        spacing:        ScreenTools.defaultFontPixelWidth / 4

        QGCColoredImage {
            id:                     lidarIcon
            height:                 parent.height * 0.7
            width:                  height
            anchors.verticalCenter: parent.verticalCenter
            source:                 "/custom/img/png/YSLidar.png"
            fillMode:               Image.PreserveAspectFit
            sourceSize.height:      height
            color:                  qgcPal.buttonText
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            QGCLabel {
                text:           _stateText()
                color:          _stateColor()
                font.pointSize: ScreenTools.smallFontPointSize
            }

            QGCLabel {
                text:           _usbText()
                color:          !_noResponse && (_usbLow || _usb === YSManager.UsbFull || _usb === YSManager.UsbMissing) ? qgcPal.colorOrange : qgcPal.buttonText
                font.pointSize: ScreenTools.smallFontPointSize
            }
        }
    }

    MouseArea {
        anchors.fill:   parent
        onClicked:      mainWindow.lidarPanelVisible = true
    }
}
