import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Layouts          1.2

import QGroundControl                       1.0
import QGroundControl.Controls              1.0
import QGroundControl.FactSystem            1.0
import QGroundControl.QGCPositionManager    1.0
import QGroundControl.Palette               1.0
import QGroundControl.ScreenTools           1.0

Rectangle {
    id:                 _root
    color:              _bg
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    property real _panelWidth:      _root.width * 0.96
    property real _margins:         ScreenTools.defaultFontPixelWidth * 1.5
    property real _rowHeight:       ScreenTools.defaultFontPixelHeight * 2.8
    property real _iconSize:        ScreenTools.defaultFontPixelHeight * 1.3
    property var  _customSettings:  QGroundControl.corePlugin.settings
    property Fact _telemetrySave:   QGroundControl.settingsManager.appSettings.telemetrySave
    property Fact _videoRecording:  _customSettings.privacyVideoRecordingEnabled
    property bool _gpsAvailable:    QGroundControl.qgcPositionManger.gcsPosition.isValid
    property bool _cameraAvailable: QGroundControl.videoManager.hasVideo
    property color _bg:             "#22262a"
    property color _card:           "#30363b"
    property color _cardHeader:     "#353c42"
    property color _border:         "#3b434a"
    property color _text:           "#f1f3f4"
    property color _muted:          "#a7adb3"
    property color _divider:        "#3a4249"
    property color _pillGreen:      "#0aa184"
    property color _pillOrange:     "#ff8a2a"
    property color _pillGrey:       "#6a7075"

    QGCPalette { id: qgcPal }

    function _statusLabel(used, optional) {
        if (used) return qsTr("Used")
        return optional ? qsTr("Optional") : qsTr("Not used")
    }

    function _statusIcon(used, optional) {
        return used ? "\u2714" : (optional ? "\u26A0" : "\u2714")
    }

    function _statusColor(used, optional) {
        if (used) return _pillGreen
        return optional ? _pillOrange : _pillGrey
    }

    QGCFlickable {
        anchors.fill:   parent
        clip:           true
        contentHeight:  mainColumn.implicitHeight + _margins * 2
        contentWidth:   mainColumn.width

        Column {
            id:      mainColumn
            width:   _root.width
            spacing: ScreenTools.defaultFontPixelHeight * 1.4

            // spacer for top padding
            Item { width: 1; height: _margins * 0.5 }

            //-- Page title
            Column {
                width:   _panelWidth
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: ScreenTools.defaultFontPixelHeight * 0.2

                QGCLabel {
                    text:           qsTr("External Sensing & Privacy")
                    font.family:    ScreenTools.demiboldFontFamily
                    font.pointSize: ScreenTools.largeFontPointSize
                    color:          _text
                }
                QGCLabel {
                    text:  qsTr("Operational transparency and data usage explanation")
                    color: _muted
                }
            }

            //-- EXTERNAL SENSING CAPABILITIES
            Column {
                width:   _panelWidth
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: ScreenTools.defaultFontPixelHeight * 0.6

                QGCLabel {
                    text:        qsTr("EXTERNAL SENSING CAPABILITIES")
                    font.family: ScreenTools.demiboldFontFamily
                    color:       _muted
                }

                // Card
                Rectangle {
                    width:        parent.width
                    height:       capTableCol.implicitHeight
                    color:        _card
                    border.color: _border
                    radius:       6
                    clip:         true

                    Column {
                        id:    capTableCol
                        width: parent.width

                        //-- Header row
                        Rectangle {
                            width:  parent.width
                            height: ScreenTools.defaultFontPixelHeight * 2.4
                            color:  _cardHeader

                            RowLayout {
                                anchors.fill:        parent
                                anchors.leftMargin:  _margins
                                anchors.rightMargin: _margins
                                spacing:             0

                                // align with icon+gap
                                Item { width: _iconSize + ScreenTools.defaultFontPixelWidth * 1.5; height: 1 }

                                QGCLabel {
                                    text:           qsTr("CAPABILITY")
                                    color:          _muted
                                    font.pointSize: ScreenTools.smallFontPointSize
                                    font.family:    ScreenTools.demiboldFontFamily
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 18
                                }
                                Item { Layout.fillWidth: true }
                                QGCLabel {
                                    text:           qsTr("STATUS")
                                    color:          _muted
                                    font.pointSize: ScreenTools.smallFontPointSize
                                    font.family:    ScreenTools.demiboldFontFamily
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
                                }
                                QGCLabel {
                                    text:           qsTr("DESCRIPTION")
                                    color:          _muted
                                    font.pointSize: ScreenTools.smallFontPointSize
                                    font.family:    ScreenTools.demiboldFontFamily
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        //-- Row: Camera
                        Rectangle {
                            width:  parent.width
                            height: _rowHeight
                            color:  "transparent"
                            RowLayout {
                                anchors.fill:        parent
                                anchors.leftMargin:  _margins
                                anchors.rightMargin: _margins
                                spacing:             0
                                Rectangle { width: _iconSize; height: _iconSize; radius: 3; color: "#3a4046"; border.color: "#4a5259" }
                                Item { width: ScreenTools.defaultFontPixelWidth * 1.5; height: 1 }
                                QGCLabel { text: qsTr("Camera"); color: _text; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 18 }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    color:  _root._statusColor(_cameraAvailable, false)
                                    radius: height / 2
                                    height: ScreenTools.defaultFontPixelHeight * 1.6
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
                                    QGCLabel {
                                        id: cameraStatusLbl
                                        anchors.centerIn: parent
                                        text:        _root._statusIcon(_cameraAvailable, false) + " " + _root._statusLabel(_cameraAvailable, false)
                                        color:       "#ffffff"
                                        font.family: ScreenTools.demiboldFontFamily
                                    }
                                }
                                QGCLabel { text: qsTr("Live video from vehicle payload"); color: _muted; Layout.fillWidth: true }
                            }
                            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: _divider }
                        }

                        //-- Row: Video Recording
                        Rectangle {
                            width:  parent.width
                            height: _rowHeight
                            color:  "transparent"
                            RowLayout {
                                anchors.fill:        parent
                                anchors.leftMargin:  _margins
                                anchors.rightMargin: _margins
                                spacing:             0
                                Rectangle { width: _iconSize; height: _iconSize; radius: 3; color: "#3a4046"; border.color: "#4a5259" }
                                Item { width: ScreenTools.defaultFontPixelWidth * 1.5; height: 1 }
                                QGCLabel { text: qsTr("Video Recording"); color: _text; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 18 }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    color:  _root._statusColor(_videoRecording.rawValue, true)
                                    radius: height / 2
                                    height: ScreenTools.defaultFontPixelHeight * 1.6
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
                                    QGCLabel {
                                        id: recordingStatusLbl
                                        anchors.centerIn: parent
                                        text:        _root._statusIcon(_videoRecording.rawValue, true) + " " + _root._statusLabel(_videoRecording.rawValue, true)
                                        color:       "#ffffff"
                                        font.family: ScreenTools.demiboldFontFamily
                                    }
                                }
                                QGCLabel { text: qsTr("Enabled only by user action"); color: _muted; Layout.fillWidth: true }
                            }
                            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: _divider }
                        }

                        //-- Row: GPS / Location
                        Rectangle {
                            width:  parent.width
                            height: _rowHeight
                            color:  "transparent"
                            RowLayout {
                                anchors.fill:        parent
                                anchors.leftMargin:  _margins
                                anchors.rightMargin: _margins
                                spacing:             0
                                Rectangle { width: _iconSize; height: _iconSize; radius: 3; color: "#3a4046"; border.color: "#4a5259" }
                                Item { width: ScreenTools.defaultFontPixelWidth * 1.5; height: 1 }
                                QGCLabel { text: qsTr("GPS / Location"); color: _text; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 18 }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    color:  _root._statusColor(_gpsAvailable, false)
                                    radius: height / 2
                                    height: ScreenTools.defaultFontPixelHeight * 1.6
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
                                    QGCLabel {
                                        id: gpsStatusLbl
                                        anchors.centerIn: parent
                                        text:        _root._statusIcon(_gpsAvailable, false) + " " + _root._statusLabel(_gpsAvailable, false)
                                        color:       "#ffffff"
                                        font.family: ScreenTools.demiboldFontFamily
                                    }
                                }
                                QGCLabel { text: qsTr("Navigation and mission planning"); color: _muted; Layout.fillWidth: true }
                            }
                            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: _divider }
                        }

                        //-- Row: Telemetry Log
                        Rectangle {
                            width:  parent.width
                            height: _rowHeight
                            color:  "transparent"
                            RowLayout {
                                anchors.fill:        parent
                                anchors.leftMargin:  _margins
                                anchors.rightMargin: _margins
                                spacing:             0
                                Rectangle { width: _iconSize; height: _iconSize; radius: 3; color: "#3a4046"; border.color: "#4a5259" }
                                Item { width: ScreenTools.defaultFontPixelWidth * 1.5; height: 1 }
                                QGCLabel { text: qsTr("Telemetry Log"); color: _text; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 18 }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    color:  _root._statusColor(_telemetrySave.rawValue, false)
                                    radius: height / 2
                                    height: ScreenTools.defaultFontPixelHeight * 1.6
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
                                    QGCLabel {
                                        id: telemetryStatusLbl
                                        anchors.centerIn: parent
                                        text:        _root._statusIcon(_telemetrySave.rawValue, false) + " " + _root._statusLabel(_telemetrySave.rawValue, false)
                                        color:       "#ffffff"
                                        font.family: ScreenTools.demiboldFontFamily
                                    }
                                }
                                QGCLabel { text: qsTr("Diagnostics and flight analysis"); color: _muted; Layout.fillWidth: true }
                            }
                            Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: _divider }
                        }

                        //-- Row: Microphone (last – no divider)
                        Rectangle {
                            width:  parent.width
                            height: _rowHeight
                            color:  "transparent"
                            RowLayout {
                                anchors.fill:        parent
                                anchors.leftMargin:  _margins
                                anchors.rightMargin: _margins
                                spacing:             0
                                Rectangle { width: _iconSize; height: _iconSize; radius: 3; color: "#3a4046"; border.color: "#4a5259" }
                                Item { width: ScreenTools.defaultFontPixelWidth * 1.5; height: 1 }
                                QGCLabel { text: qsTr("Microphone"); color: _text; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 18 }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    color:  _root._statusColor(false, false)
                                    radius: height / 2
                                    height: ScreenTools.defaultFontPixelHeight * 1.6
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
                                    QGCLabel {
                                        id: micStatusLbl
                                        anchors.centerIn: parent
                                        text:        "\u2714 " + _root._statusLabel(false, false)
                                        color:       "#ffffff"
                                        font.family: ScreenTools.demiboldFontFamily
                                    }
                                }
                                QGCLabel { text: qsTr("QGC does not record audio"); color: _muted; Layout.fillWidth: true }
                            }
                        }

                    } // Column capTableCol
                } // Rectangle card
            } // Column capabilities section

            //-- Bottom section
            RowLayout {
                width:   _panelWidth
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: _margins

                //-- DATA HANDLING SUMMARY
                Rectangle {
                    Layout.fillWidth:  true
                    Layout.alignment:  Qt.AlignTop
                    height:            summaryCol.implicitHeight + _margins * 2
                    color:             _card
                    border.color:      _border
                    radius:            6

                    Column {
                        id:              summaryCol
                        anchors.top:     parent.top
                        anchors.left:    parent.left
                        anchors.right:   parent.right
                        anchors.margins: _margins
                        spacing:         ScreenTools.defaultFontPixelHeight * 0.9

                        QGCLabel {
                            text:        qsTr("DATA HANDLING SUMMARY")
                            font.family: ScreenTools.demiboldFontFamily
                            color:       _muted
                        }

                        // Video Data
                        RowLayout {
                            width:   parent.width
                            spacing: ScreenTools.defaultFontPixelWidth * 1.2
                            Rectangle { width: _iconSize; height: _iconSize; radius: 3; color: "#3a4046"; border.color: "#4a5259"; Layout.alignment: Qt.AlignTop }
                            Column {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelHeight * 0.1
                                QGCLabel { text: qsTr("Video Data"); font.family: ScreenTools.demiboldFontFamily; color: _text }
                                QGCLabel { text: qsTr("Recorded only when user enables. Stored locally."); color: _muted; wrapMode: Text.WordWrap; width: parent.width }
                            }
                        }

                        // Telemetry & GPS
                        RowLayout {
                            width:   parent.width
                            spacing: ScreenTools.defaultFontPixelWidth * 1.2
                            Rectangle { width: _iconSize; height: _iconSize; radius: 3; color: "#3a4046"; border.color: "#4a5259"; Layout.alignment: Qt.AlignTop }
                            Column {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelHeight * 0.1
                                QGCLabel { text: qsTr("Telemetry & GPS"); font.family: ScreenTools.demiboldFontFamily; color: _text }
                                QGCLabel { text: qsTr("Stored as flight logs on local system for analysis."); color: _muted; wrapMode: Text.WordWrap; width: parent.width }
                            }
                        }

                        // Audio
                        RowLayout {
                            width:   parent.width
                            spacing: ScreenTools.defaultFontPixelWidth * 1.2
                            Rectangle { width: _iconSize; height: _iconSize; radius: 3; color: "#3a4046"; border.color: "#4a5259"; Layout.alignment: Qt.AlignTop }
                            Column {
                                Layout.fillWidth: true
                                spacing: ScreenTools.defaultFontPixelHeight * 0.1
                                QGCLabel { text: qsTr("Audio"); font.family: ScreenTools.demiboldFontFamily; color: _text }
                                QGCLabel { text: qsTr("No audio data is collected or recorded"); color: _muted; wrapMode: Text.WordWrap; width: parent.width }
                            }
                        }
                    }
                }

                //-- USER CONTROL
                Rectangle {
                    Layout.fillWidth:  true
                    Layout.alignment:  Qt.AlignTop
                    height:            ctrlCol.implicitHeight + _margins * 2
                    color:             _card
                    border.color:      _border
                    radius:            6

                    Column {
                        id:              ctrlCol
                        anchors.top:     parent.top
                        anchors.left:    parent.left
                        anchors.right:   parent.right
                        anchors.margins: _margins
                        spacing:         ScreenTools.defaultFontPixelHeight * 1.0

                        QGCLabel {
                            text:        qsTr("USER CONTROL")
                            font.family: ScreenTools.demiboldFontFamily
                            color:       _muted
                        }

                        RowLayout {
                            width: parent.width
                            QGCLabel { text: qsTr("Enable video recording"); font.family: ScreenTools.demiboldFontFamily; color: _text; Layout.fillWidth: true }
                            QGCSwitch {
                                checked:   _videoRecording.rawValue
                                onClicked: _videoRecording.rawValue = checked
                            }
                        }

                        RowLayout {
                            width: parent.width
                            QGCLabel { text: qsTr("Save telemetry logs"); font.family: ScreenTools.demiboldFontFamily; color: _text; Layout.fillWidth: true }
                            QGCSwitch {
                                checked:   _telemetrySave.rawValue
                                onClicked: _telemetrySave.rawValue = checked
                            }
                        }
                    }
                }
            } // RowLayout bottom

        } // Column mainColumn
    } // QGCFlickable
}
