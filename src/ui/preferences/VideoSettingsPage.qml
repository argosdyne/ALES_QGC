/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Layouts          1.2

import QGroundControl               1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Palette       1.0

Rectangle {
    id:                 _root
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    property real   _margins:               ScreenTools.defaultFontPixelWidth
    property real   _comboFieldWidth:       ScreenTools.defaultFontPixelWidth * 30
    property var    _videoSettings:         QGroundControl.settingsManager.videoSettings
    property string _videoSource:           _videoSettings.videoSource.rawValue
    property bool   _isGst:                 QGroundControl.videoManager.isGStreamer
    property bool   _isUDP264:              _isGst && _videoSource === _videoSettings.udp264VideoSource
    property bool   _isUDP265:              _isGst && _videoSource === _videoSettings.udp265VideoSource
    property bool   _isRTSP:                _isGst && _videoSource === _videoSettings.rtspVideoSource
    property bool   _isTCP:                 _isGst && _videoSource === _videoSettings.tcpVideoSource
    property bool   _isMPEGTS:              _isGst && _videoSource === _videoSettings.mpegtsVideoSource
    property bool   _showSaveVideoSettings: _isGst || QGroundControl.videoManager.autoStreamConfigured

    QGCPalette { id: qgcPal }

    QGCFlickable {
        anchors.fill:       parent
        clip:               true
        contentHeight:      settingsColumn.height
        contentWidth:       settingsColumn.width

        ColumnLayout {
            id:                         settingsColumn
            anchors.horizontalCenter:   parent.horizontalCenter

            Rectangle {
                Layout.preferredHeight: videoGrid.height + (_margins * 2)
                Layout.preferredWidth:  videoGrid.width + (_margins * 2)
                Layout.fillWidth:       true
                color:                  qgcPal.windowShade
                visible:                _videoSettings.visible

                GridLayout {
                    id:                         videoGrid
                    anchors.top:                parent.top
                    anchors.horizontalCenter:   parent.horizontalCenter
                    anchors.margins:            _margins
                    columns:                    2
                    visible:                    _videoSettings.visible

                    QGCLabel {
                        text:               qsTr("Video Settings")
                        Layout.columnSpan:  2
                        Layout.alignment:   Qt.AlignHCenter
                    }

                    QGCLabel {
                        text:       qsTr("Source")
                        visible:    _videoSettings.videoSource.visible
                    }
                    FactComboBox {
                        Layout.preferredWidth:  _comboFieldWidth
                        indexModel:             false
                        fact:                   _videoSettings.videoSource
                        visible:                _videoSettings.videoSource.visible
                    }

                    QGCLabel {
                        text:       qsTr("UDP Port")
                        visible:    (_isUDP264 || _isUDP265 || _isMPEGTS) && _videoSettings.udpPort.visible
                    }
                    FactTextField {
                        Layout.preferredWidth:  _comboFieldWidth
                        fact:                   _videoSettings.udpPort
                        visible:                (_isUDP264 || _isUDP265 || _isMPEGTS) && _videoSettings.udpPort.visible
                    }

                    QGCLabel {
                        text:       qsTr("RTSP URL")
                        visible:    _isRTSP && _videoSettings.rtspUrl.visible
                    }
                    FactTextField {
                        Layout.preferredWidth:  _comboFieldWidth
                        fact:                   _videoSettings.rtspUrl
                        visible:                _isRTSP && _videoSettings.rtspUrl.visible
                    }

                    QGCLabel {
                        text:       qsTr("TCP URL")
                        visible:    _isTCP && _videoSettings.tcpUrl.visible
                    }
                    FactTextField {
                        Layout.preferredWidth:  _comboFieldWidth
                        fact:                   _videoSettings.tcpUrl
                        visible:                _isTCP && _videoSettings.tcpUrl.visible
                    }

                    QGCLabel {
                        text:       qsTr("Aspect Ratio")
                        visible:    _isGst && _videoSettings.aspectRatio.visible
                    }
                    FactTextField {
                        Layout.preferredWidth:  _comboFieldWidth
                        fact:                   _videoSettings.aspectRatio
                        visible:                _isGst && _videoSettings.aspectRatio.visible
                    }

                    QGCLabel {
                        text:       qsTr("Record File Format")
                        visible:    _showSaveVideoSettings && _videoSettings.recordingFormat.visible
                    }
                    FactComboBox {
                        Layout.preferredWidth:  _comboFieldWidth
                        fact:                   _videoSettings.recordingFormat
                        visible:                _showSaveVideoSettings && _videoSettings.recordingFormat.visible
                    }

                    QGCLabel {
                        text:       qsTr("Max Storage Usage")
                        visible:    _showSaveVideoSettings && _videoSettings.maxVideoSize.visible && _videoSettings.enableStorageLimit.value
                    }
                    FactTextField {
                        Layout.preferredWidth:  _comboFieldWidth
                        fact:                   _videoSettings.maxVideoSize
                        visible:                _showSaveVideoSettings && _videoSettings.maxVideoSize.visible && _videoSettings.enableStorageLimit.value
                    }

                    QGCLabel {
                        text:       qsTr("Video decode priority")
                        visible:    _videoSettings.forceVideoDecoder.visible
                    }
                    FactComboBox {
                        Layout.preferredWidth:  _comboFieldWidth
                        fact:                   _videoSettings.forceVideoDecoder
                        visible:                _videoSettings.forceVideoDecoder.visible
                        indexModel:             false
                    }

                    Item { width: 1; height: 1 }
                    FactCheckBox {
                        text:       qsTr("Disable When Disarmed")
                        fact:       _videoSettings.disableWhenDisarmed
                        visible:    _isGst && fact.visible
                    }

                    Item { width: 1; height: 1 }
                    FactCheckBox {
                        text:       qsTr("Low Latency Mode")
                        fact:       _videoSettings.lowLatencyMode
                        visible:    _isGst && fact.visible
                    }

                    Item { width: 1; height: 1 }
                    FactCheckBox {
                        text:       qsTr("Auto-Delete Saved Recordings")
                        fact:       _videoSettings.enableStorageLimit
                        visible:    _showSaveVideoSettings && fact.visible
                    }

                    Item { width: 1; height: 1 }
                    FactCheckBox {
                        text:       qsTr("Disable FPV Streaming")
                        fact:       _videoSettings.disableFPVVideo
                    }

                    QGCLabel {
                        text:       qsTr("FPV URL")
                        visible:    _videoSettings.disableFPVVideo.value
                    }
                    FactTextField {
                        Layout.preferredWidth:  _comboFieldWidth
                        fact:                   _videoSettings.fpvUrl
                        visible:                _videoSettings.disableFPVVideo.value
                    }
                }
            }
        }
    }
}
