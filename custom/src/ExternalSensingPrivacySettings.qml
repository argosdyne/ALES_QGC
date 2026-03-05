import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Layouts          1.2

import QGroundControl                       1.0
import QGroundControl.Controls              1.0
import QGroundControl.FactSystem            1.0
import QGroundControl.Palette               1.0
import QGroundControl.ScreenTools           1.0

Rectangle {
    id:                 _root
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    property real _panelWidth:      _root.width * 0.84
    property real _margins:         ScreenTools.defaultFontPixelWidth
    property var  _customSettings:  QGroundControl.corePlugin.settings
    property Fact _telemetrySave:   QGroundControl.settingsManager.appSettings.telemetrySave
    property Fact _videoRecording:  _customSettings.privacyVideoRecordingEnabled

    QGCPalette { id: qgcPal }

    function _statusLabel(used, optional) {
        if (used) {
            return qsTr("Used")
        }
        return optional ? qsTr("Optional") : qsTr("Not used")
    }

    function _statusColor(used, optional) {
        if (used) {
            return qgcPal.colorGreen
        }
        return optional ? qgcPal.colorOrange : qgcPal.colorGrey
    }

    QGCFlickable {
        anchors.fill:   parent
        clip:           true
        contentHeight:  contentColumn.height
        contentWidth:   contentColumn.width

        Column {
            id:                 contentColumn
            width:              _root.width
            spacing:            ScreenTools.defaultFontPixelHeight

            Item {
                width:  _panelWidth
                height: headerColumn.height
                anchors.horizontalCenter: parent.horizontalCenter

                Column {
                    id: headerColumn
                    spacing: ScreenTools.defaultFontPixelHeight * 0.2

                    QGCLabel {
                        text: qsTr("External Sensing & Privacy")
                        font.family: ScreenTools.demiboldFontFamily
                        font.pointSize: ScreenTools.largeFontPointSize
                    }

                    QGCLabel {
                        text: qsTr("Operational transparency and data usage explanation")
                        color: qgcPal.colorGrey
                    }
                }
            }

            Rectangle {
                width:                      _panelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                color:                      qgcPal.windowShade
                border.color:               qgcPal.windowShadeDark
                radius:                     4
                height:                     capabilityColumn.height + _margins * 2

                Column {
                    id:                     capabilityColumn
                    spacing:                ScreenTools.defaultFontPixelHeight * 0.5
                    anchors.left:           parent.left
                    anchors.right:          parent.right
                    anchors.top:            parent.top
                    anchors.margins:        _margins

                    QGCLabel {
                        text: qsTr("EXTERNAL SENSING CAPABILITIES")
                        color: qgcPal.colorBlue
                        font.family: ScreenTools.demiboldFontFamily
                    }

                    GridLayout {
                        columns:        3
                        rowSpacing:     ScreenTools.defaultFontPixelHeight * 0.35
                        columnSpacing:  ScreenTools.defaultFontPixelWidth * 2

                        QGCLabel { text: qsTr("Capability"); font.family: ScreenTools.demiboldFontFamily }
                        QGCLabel { text: qsTr("Status"); font.family: ScreenTools.demiboldFontFamily }
                        QGCLabel { text: qsTr("Description"); font.family: ScreenTools.demiboldFontFamily }

                        QGCLabel { text: qsTr("Camera") }
                        Rectangle {
                            color: _root._statusColor(true, false)
                            radius: height / 2
                            width: cameraStatus.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.5
                            height: cameraStatus.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.5
                            QGCLabel {
                                id: cameraStatus
                                anchors.centerIn: parent
                                text: _root._statusLabel(true, false)
                                color: "#ffffff"
                                font.family: ScreenTools.demiboldFontFamily
                            }
                        }
                        QGCLabel { text: qsTr("Live video from vehicle payload") }

                        QGCLabel { text: qsTr("Video Recording") }
                        Rectangle {
                            color: _root._statusColor(_videoRecording.rawValue, true)
                            radius: height / 2
                            width: recordingStatus.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.5
                            height: recordingStatus.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.5
                            QGCLabel {
                                id: recordingStatus
                                anchors.centerIn: parent
                                text: _root._statusLabel(_videoRecording.rawValue, true)
                                color: "#ffffff"
                                font.family: ScreenTools.demiboldFontFamily
                            }
                        }
                        QGCLabel { text: qsTr("Enabled only by user action") }

                        QGCLabel { text: qsTr("GPS / Location") }
                        Rectangle {
                            color: _root._statusColor(true, false)
                            radius: height / 2
                            width: gpsStatus.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.5
                            height: gpsStatus.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.5
                            QGCLabel {
                                id: gpsStatus
                                anchors.centerIn: parent
                                text: _root._statusLabel(true, false)
                                color: "#ffffff"
                                font.family: ScreenTools.demiboldFontFamily
                            }
                        }
                        QGCLabel { text: qsTr("Navigation and mission planning") }

                        QGCLabel { text: qsTr("Telemetry Log") }
                        Rectangle {
                            color: _root._statusColor(_telemetrySave.rawValue, false)
                            radius: height / 2
                            width: telemetryStatus.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.5
                            height: telemetryStatus.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.5
                            QGCLabel {
                                id: telemetryStatus
                                anchors.centerIn: parent
                                text: _root._statusLabel(_telemetrySave.rawValue, false)
                                color: "#ffffff"
                                font.family: ScreenTools.demiboldFontFamily
                            }
                        }
                        QGCLabel { text: qsTr("Diagnostics and flight analysis") }

                        QGCLabel { text: qsTr("Microphone") }
                        Rectangle {
                            color: _root._statusColor(false, false)
                            radius: height / 2
                            width: micStatus.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.5
                            height: micStatus.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.5
                            QGCLabel {
                                id: micStatus
                                anchors.centerIn: parent
                                text: _root._statusLabel(false, false)
                                color: "#ffffff"
                                font.family: ScreenTools.demiboldFontFamily
                            }
                        }
                        QGCLabel { text: qsTr("QGC does not record audio") }
                    }
                }
            }

            RowLayout {
                width:                      _panelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                spacing:                    _margins

                Rectangle {
                    Layout.fillWidth:   true
                    color:              qgcPal.windowShade
                    border.color:       qgcPal.windowShadeDark
                    radius:             4
                    height:             summaryColumn.height + _margins * 2

                    Column {
                        id:                     summaryColumn
                        spacing:                ScreenTools.defaultFontPixelHeight * 0.35
                        anchors.left:           parent.left
                        anchors.right:          parent.right
                        anchors.top:            parent.top
                        anchors.margins:        _margins

                        QGCLabel {
                            text: qsTr("DATA HANDLING SUMMARY")
                            color: qgcPal.colorBlue
                            font.family: ScreenTools.demiboldFontFamily
                        }
                        QGCLabel { text: qsTr("Video Data: recorded only when user enables.") }
                        QGCLabel { text: qsTr("Telemetry & GPS: stored as flight logs on local system.") }
                        QGCLabel { text: qsTr("Audio: no audio data is collected or recorded.") }
                    }
                }

                Rectangle {
                    Layout.fillWidth:   true
                    color:              qgcPal.windowShade
                    border.color:       qgcPal.windowShadeDark
                    radius:             4
                    height:             controlColumn.height + _margins * 2

                    Column {
                        id:                     controlColumn
                        spacing:                ScreenTools.defaultFontPixelHeight * 0.35
                        anchors.left:           parent.left
                        anchors.right:          parent.right
                        anchors.top:            parent.top
                        anchors.margins:        _margins

                        QGCLabel {
                            text: qsTr("USER CONTROL")
                            color: qgcPal.colorBlue
                            font.family: ScreenTools.demiboldFontFamily
                        }

                        RowLayout {
                            width: parent.width
                            QGCLabel { text: qsTr("Enable video recording"); Layout.fillWidth: true }
                            QGCSwitch {
                                checked: _videoRecording.rawValue
                                onClicked: _videoRecording.rawValue = checked
                            }
                        }

                        RowLayout {
                            width: parent.width
                            QGCLabel { text: qsTr("Save telemetry logs"); Layout.fillWidth: true }
                            QGCSwitch {
                                checked: _telemetrySave.rawValue
                                onClicked: _telemetrySave.rawValue = checked
                            }
                        }

                        QGCLabel {
                            text: qsTr("*Changes apply immediately and affect only local data.")
                            color: qgcPal.colorGrey
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
