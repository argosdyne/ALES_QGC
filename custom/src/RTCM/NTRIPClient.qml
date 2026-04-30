import QtQuick          2.3
import QtQuick.Controls 2.4
import QtQuick.Layouts  1.11
import QtQuick.Dialogs  1.3

import QGroundControl                       1.0
import QGroundControl.Controllers           1.0
import QGroundControl.Controls              1.0
import QGroundControl.FactControls          1.0
import QGroundControl.FactSystem            1.0
import QGroundControl.Palette               1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.SettingsManager       1.0

import CustomQmlInterface                   1.0

Column {
    id: root
    clip: true

    property real _margins: ScreenTools.defaultFontPixelHeight * 0.5
    property var  _ntripSource: CustomQmlInterface.codevRTCMManager.rtcmSource

    Connections {
        target: _ntripSource
        onContentListChanged: {
            root._syncSavedMountPointSelection()
        }
    }

    function _syncSavedMountPointSelection() {
        if (!_ntripSource || !_ntripSource.contentList || _ntripSource.contentList.length === 0) {
            return
        }

        var savedMountPoint = _ntripSource.mountpoint.rawValue
        if (savedMountPoint === undefined || savedMountPoint === null) {
            return
        }
        savedMountPoint = String(savedMountPoint)
        if (savedMountPoint === "") {
            return
        }

        var savedName = savedMountPoint.split(":")[0]
        var index = -1

        for (var i = 0; i < _ntripSource.contentList.length; i++) {
            var item = _ntripSource.contentList[i]
            if (item === savedMountPoint || item.split(":")[0] === savedName) {
                index = i
                break
            }
        }

        if (index >= 0) {
            cbMountPoint.currentIndex = index
        }
    }

    function _saveMountPointFromIndex(index) {
        if (!_ntripSource || !_ntripSource.contentList || index < 0 || index >= _ntripSource.contentList.length) {
            return
        }
        var selectedItem = String(_ntripSource.contentList[index])
        var mountPointName = selectedItem.split(":")[0]
        _ntripSource.mountpoint.rawValue = mountPointName
    }

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    GridLayout {
        id:     outerItem
        anchors.margins:    ScreenTools.defaultFontPixelHeight
        columnSpacing:      ScreenTools.defaultFontPixelHeight
        anchors.horizontalCenter: parent.horizontalCenter
        columns: 2
        QGCLabel {
            text:           qsTr("Host:")
            Layout.minimumWidth: _labelWidth
        }
        FactTextField {
            fact:           _ntripSource.host
            Layout.minimumWidth: _valueWidth
        }
        QGCLabel {
            text:           qsTr("Port:")
            Layout.minimumWidth: _labelWidth
        }
        FactTextField {
            fact:           _ntripSource.port
            Layout.minimumWidth: _valueWidth

            onAccepted: {
                _ntripSource.onReadyRead()
            }
        }
        QGCLabel {
            text:           qsTr("Mountpoint:")
            Layout.minimumWidth: _labelWidth
        }
        //FactTextField {
        //    fact:           _ntripSource.mountpoint
        //    Layout.minimumWidth: _valueWidth
        //}

        //QGCCombobox
         QGCComboBox {
            id: cbMountPoint
            Layout.minimumWidth: _labelWidth
            model : _ntripSource.contentList
            //model: _ntripSource.mountPointList
            onModelChanged: root._syncSavedMountPointSelection()
            Component.onCompleted: root._syncSavedMountPointSelection()

            // Save only mountpoint name (without ":format") for stable persistence.
            onActivated: root._saveMountPointFromIndex(index)
            onCurrentIndexChanged: root._saveMountPointFromIndex(currentIndex)
        }
        QGCLabel {
            text:           qsTr("User:")
            Layout.minimumWidth: _labelWidth
        }
        FactTextField {
            fact:           _ntripSource.user
            Layout.minimumWidth: _valueWidth
        }
        QGCLabel {
            text:           qsTr("Password:")
            Layout.minimumWidth: _labelWidth
        }
        FactTextField {
            fact:           _ntripSource.passwd
            Layout.minimumWidth: _valueWidth
        }
        RowLayout {
            Layout.columnSpan: 2
            QGCButton {
                text: _ntripSource.isLogIn ? qsTr("Log out") : qsTr("Log in")
                Layout.fillWidth: true
                enabled: _ntripSource.mountpoint.valueString !== "" &&
                         _ntripSource.user.valueString !== "" &&
                         _ntripSource.passwd.valueString !== "" &&
                         !_ntripSource.isLogIning
                onClicked: {
                    if(!_ntripSource.isLogIn)
                        _ntripSource.logIn()
                    else _ntripSource.logOut()
                }
            }
            QGCColoredImage {
                id:                 busyIndicator
                height:             ScreenTools.defaultFontPixelHeight
                width:              height
                source:             "/qmlimages/MapSync.svg"
                sourceSize.height:  height
                fillMode:           Image.PreserveAspectFit
                mipmap:             true
                smooth:             true
                color:              qgcPal.colorGreen
                visible:            _ntripSource.isLogIning
                RotationAnimation on rotation {
                    loops:          Animation.Infinite
                    from:           360
                    to:             0
                    duration:       740
                    running:        busyIndicator.visible
                }
            }
            QGCColoredImage {
                width: ScreenTools.defaultFontPixelHeight
                height: width
                visible: !_ntripSource.isLogIning
                source: _ntripSource.isLogIn ? "qrc:/custom/img/yes.svg" : "qrc:/custom/img/no.svg"
                color: _ntripSource.isLogIn ? qgcPal.colorGreen : qgcPal.colorRed
                sourceSize.height: height
                sourceSize.width:  width
            }
        }
        QGCLabel {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            text: qsTr("RTCM: %1 fps | total %2 frames | %3 KB")
                    .arg(_ntripSource.rtcmFramesPerSecond)
                    .arg(_ntripSource.rtcmTotalFrames)
                    .arg((_ntripSource.rtcmTotalBytes / 1024.0).toFixed(1))
            color: (_ntripSource.isLogIn && _ntripSource.rtcmFramesPerSecond > 0) ? qgcPal.colorGreen : qgcPal.text
        }
        QGCLabel {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            text: qsTr("Raw %1 B/s | Dropped %2 B/s | MAVLink sent %3/s | Last RTCM %4")
                    .arg(_ntripSource.rawBytesPerSecond)
                    .arg(_ntripSource.droppedBytesPerSecond)
                    .arg(_ntripSource.mavlinkRtcmSentPerSecond)
                    .arg(_ntripSource.lastRtcmReceivedSec >= 0 ? (_ntripSource.lastRtcmReceivedSec + qsTr("s ago")) : qsTr("N/A"))
            color: (_ntripSource.isLogIn && _ntripSource.rawBytesPerSecond > 0) ? qgcPal.text : qgcPal.colorOrange
        }
        QGCLabel {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            text: qsTr("CRC errors %1/s | total %2 | last %3")
                    .arg(_ntripSource.crcErrorsPerSecond)
                    .arg(_ntripSource.crcErrorsTotal)
                    .arg(_ntripSource.lastCrcErrorAt !== "" ? _ntripSource.lastCrcErrorAt : qsTr("N/A"))
            color: _ntripSource.crcErrorsPerSecond > 0 ? qgcPal.colorRed : qgcPal.text
        }
        QGCLabel {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            text: qsTr("CRC log file: %1").arg(_ntripSource.crcErrorLogPath)
            color: qgcPal.text
            wrapMode: Text.WrapAnywhere
        }
        QGCLabel {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            text: qsTr("Caster raw HEX (latest): %1")
                    .arg(_ntripSource.lastRawChunkHexPreview !== "" ? _ntripSource.lastRawChunkHexPreview : qsTr("N/A"))
            color: qgcPal.text
            wrapMode: Text.WrapAnywhere
        }
        QGCLabel {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            text: qsTr("Last RTCM type: %1 | frame HEX: %2")
                    .arg(_ntripSource.lastRtcmMessageType >= 0 ? _ntripSource.lastRtcmMessageType : qsTr("N/A"))
                    .arg(_ntripSource.lastRtcmFrameHexPreview !== "" ? _ntripSource.lastRtcmFrameHexPreview : qsTr("N/A"))
            color: (_ntripSource.lastRtcmMessageType >= 0) ? qgcPal.colorGreen : qgcPal.colorOrange
            wrapMode: Text.WrapAnywhere
        }
        QGCLabel {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            visible: _ntripSource.isLogIn
            color: (_ntripSource.droppedBytesPerSecond > 1024 || _ntripSource.lastRtcmReceivedSec > 5) ? qgcPal.colorRed : qgcPal.colorOrange
            text: {
                if (_ntripSource.lastRtcmReceivedSec < 0) {
                    return qsTr("RTCM warning: No RTCM frame received yet.")
                }
                if (_ntripSource.lastRtcmReceivedSec > 5) {
                    return qsTr("RTCM warning: RTCM stream stalled (%1s since last frame).").arg(_ntripSource.lastRtcmReceivedSec)
                }
                if (_ntripSource.droppedBytesPerSecond > 1024) {
                    return qsTr("RTCM warning: High dropped bytes (%1 B/s).").arg(_ntripSource.droppedBytesPerSecond)
                }
                if (_ntripSource.rawBytesPerSecond > 0 && _ntripSource.rtcmFramesPerSecond === 0) {
                    return qsTr("RTCM warning: Raw data exists but no RTCM frame parsed.")
                }
                return qsTr("RTCM status: stream looks healthy.")
            }
        }

        QGCLabel {
            text:           qsTr("GPGGA Hz:")
            Layout.minimumWidth: _labelWidth
        }
        FactComboBox {
            fact:           _ntripSource.gpggamessageHz
            indexModel:     false
            Layout.minimumWidth: _valueWidth
        }

        QGCTextField {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            enabled: !_ntripSource.autoUpdateGPGGA.rawValue
            text: _ntripSource.gpggamessage.valueString
            onEditingFinished: {
                _ntripSource.gpggamessage.rawValue = text
            }
        }

        RowLayout {
            Layout.columnSpan: 2
            QGCCheckBox {
                Layout.fillWidth: true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight
                text:           _ntripSource.autoUpdateGPGGA.shortDescription
                checked:        _ntripSource.autoUpdateGPGGA.rawValue
                visible:        true
                onClicked:      _ntripSource.autoUpdateGPGGA.rawValue = checked
            }
            QGCButton {
                text: qsTr("Get from Vehicle")
                Layout.fillWidth: true
                enabled: !_ntripSource.autoUpdateGPGGA.rawValue
                onClicked: {
                    _ntripSource.getFromVehicle()
                }
            }
        }

//        ColumnLayout {
//            id:                         settingsColumn
//            anchors.horizontalCenter:   parent.horizontalCenter

//            // ----- GPGGA & RTCM Message ------
//            GCLabel {
//                text:       qsTr("GPGGA & RTCM Message")
//            }
//            Rectangle {
//                Layout.preferredHeight: gpggaColumn.height + (ScreenTools.defaultFontPixelWidth * 2)
//                Layout.preferredWidth:  gpggaColumn.width + (ScreenTools.defaultFontPixelWidth * 2)
//                color:                  gcPal.windowShade
//                Layout.fillWidth:       true

//                ColumnLayout {
//                    id:                         gpggaColumn
//                    anchors.topMargin:          ScreenTools.defaultFontPixelWidth
//                    anchors.top:                parent.top
//                    Layout.fillWidth:           false
//                    anchors.horizontalCenter:   parent.horizontalCenter

//                    FactItemEditor {
//                        Layout.preferredWidth:  _fieldWidth
//                        fact:                   _ntripSource.sendMaxRTCMHz
//                        titleLabelW:            _fieldWidth * 0.5
//                    }

//                    FactItemEditor {
//                        Layout.preferredWidth:  _fieldWidth
//                        fact:                   _ntripSource.gpggamessageHz
//                        titleLabelW:            _fieldWidth * 0.5
//                    }

//                    QGCTextField {
//                        Layout.preferredWidth: _fieldWidth
//                        enabled: !_ntripSource.autoUpdateGPGGA.rawValue
//                        text: _ntripSource.gpggamessage.valueString
//                        onEditingFinished: {
//                            _ntripSource.gpggamessage.rawValue = text
//                        }
//                    }

//                    RowLayout {
//                        QGCCheckBox {
//                            Layout.fillWidth: true
//                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight
//                            text:           _ntripSource.autoUpdateGPGGA.description
//                            checked:        _ntripSource.autoUpdateGPGGA.rawValue
//                            visible:        true
//                            onClicked:      _ntripSource.autoUpdateGPGGA.rawValue = checked
//                        }
//                        QGCButton {
//                            text: qsTr("Get from Vehicle")
//                            Layout.fillWidth: true
//                            enabled: !_ntripSource.autoUpdateGPGGA.rawValue
//                            onClicked: {
//                                _ntripSource.getFromVehicle()
//                            }
//                        }
//                    }
//                }
//            }
//        }
    }
}
