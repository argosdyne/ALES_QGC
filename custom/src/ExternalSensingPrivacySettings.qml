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
    property var  _activeVehicle:   QGroundControl.multiVehicleManager.activeVehicle
    property bool _cameraActive:    QGroundControl.videoManager.hasVideo && QGroundControl.settingsManager.videoSettings.streamEnabled.rawValue
    property bool _gpsActive:       _activeVehicle ? _activeVehicle.gps.count.rawValue > 0 : false
    property real _statusIconSize:  ScreenTools.defaultFontPixelWidth * 1.5

    QGCPalette { id: qgcPal }

    function _statusLabel(used, optional) {
        if (used) {
            return qsTr("Used")
        }
        return qsTr("Not used")
    }

    function _statusColor(used, optional) {
        if (used) {
            return qgcPal.colorGreen
        }
        return qgcPal.windowShadeLight
    }

    function _statusIcon(used) {
        return used ? "/custom/img/check_used.svg" : "/custom/img/png/check_used.png"
    }

    QGCFlickable {
        anchors.fill:   parent
        clip:           true
        contentHeight:  contentColumn.height
        contentWidth:   contentColumn.width

        Column {
            id:                 contentColumn
            width:              _root.width
            spacing:            ScreenTools.defaultFontPixelHeight * 0.5

            Item {
                width:  _panelWidth
                height: headerColumn.height + ScreenTools.defaultFontPixelHeight * 0.2
                anchors.horizontalCenter: parent.horizontalCenter

                Column {
                    id: headerColumn
                    spacing: ScreenTools.defaultFontPixelHeight * 0.1

                    QGCLabel {
                        text: qsTr("External Sensing & Privacy")
                        font.family: ScreenTools.demiboldFontFamily
                        font.pointSize: ScreenTools.mediumFontPointSize
                    }

                    QGCLabel {
                        text: qsTr("Operational transparency and data usage explanation")
                        color: qgcPal.colorGrey
                        font.pointSize: ScreenTools.mediumFontPointSize * ScreenTools.smallFontPointRatio
                    }
                }
            }

            Item {
                width: _panelWidth
                height: capabilitiesTitle.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.35 + capabilityFrame.height
                anchors.horizontalCenter: parent.horizontalCenter

                QGCLabel {
                    id: capabilitiesTitle
                    text: qsTr("External Sensing Capabilities")
                }

                    Rectangle {
                        id: capabilityFrame
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: capabilitiesTitle.bottom
                        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.4
                        height: capabilityTable.height + ScreenTools.defaultFontPixelWidth * 2
                        color:  qgcPal.windowShade

                    Column {
                        id: capabilityTable
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: ScreenTools.defaultFontPixelWidth * 0.5

                        property real capColWidth: width * 0.30
                        property real statusColWidth: width * 0.20
                        property real descColWidth: width - capColWidth - statusColWidth
                        property real rowHeight: ScreenTools.defaultFontPixelHeight * 1.55

                        Rectangle {
                            width: capabilityTable.width
                            height: capabilityTable.rowHeight
                            color: qgcPal.windowShade

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0

                                Item {
                                    Layout.preferredWidth: capabilityTable.capColWidth
                                    Layout.fillHeight: true
                                    QGCLabel {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 3.5 * ScreenTools.defaultFontPixelWidth
                                        text: qsTr("CAPABILITY")
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: capabilityTable.statusColWidth
                                    Layout.fillHeight: true
                                    QGCLabel {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                                        text: qsTr("STATUS")
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: capabilityTable.descColWidth
                                    Layout.fillHeight: true
                                    QGCLabel {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                                        text: qsTr("DESCRIPTION")
                                    }
                                }
                            }
                        }

                        Rectangle { width: capabilityTable.width - 6 * ScreenTools.defaultFontPixelWidth; height: 1; color: "#484848"; anchors.horizontalCenter: parent.horizontalCenter }

                        Rectangle {
                            width: capabilityTable.width
                            height: capabilityTable.rowHeight
                            color: qgcPal.windowShade

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0

                                Item {
                                    Layout.preferredWidth: capabilityTable.capColWidth
                                    Layout.fillHeight: true
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 2.4 * ScreenTools.defaultFontPixelWidth
                                        spacing: ScreenTools.defaultFontPixelWidth * 1.5
                                        Image {
                                            id: cameraIcon
                                            width: ScreenTools.defaultFontPixelWidth * 3.5
                                            height: width
                                            source: "/custom/img/png/camera.png"
                                        }
                                        QGCLabel {
                                            text: qsTr("Video Streaming")
                                            anchors.verticalCenter: cameraIcon.verticalCenter
                                        }
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: capabilityTable.statusColWidth
                                    Layout.fillHeight: true
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                                        color: _root._statusColor(_cameraActive, false)
                                        radius: 4
                                        width: cameraStatusContent.implicitWidth + ScreenTools.defaultFontPixelWidth
                                        height: cameraStatusContent.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.25
                                        Row {
                                            id: cameraStatusContent
                                            anchors.centerIn: parent
                                            spacing: ScreenTools.defaultFontPixelWidth * 0.45
                                            Image {
                                                y: 2
                                                width: _root._statusIconSize
                                                height: width
                                                source: _root._statusIcon(_cameraActive)
                                            }
                                            QGCLabel {
                                                id: cameraStatus
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: _root._statusLabel(_cameraActive, false)
                                                color: "#ffffff"
                                                font.family: ScreenTools.demiboldFontFamily
                                                font.pointSize: ScreenTools.mediumFontPointSize * ScreenTools.smallFontPointRatio
                                            }
                                        }
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: capabilityTable.descColWidth
                                    Layout.fillHeight: true
                                    QGCLabel {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                                        text: qsTr("Live video from vehicle payload")
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: capabilityTable.width
                            height: capabilityTable.rowHeight
                            color: qgcPal.windowShade

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0

                                Item {
                                    Layout.preferredWidth: capabilityTable.capColWidth
                                    Layout.fillHeight: true
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 2.5 * ScreenTools.defaultFontPixelWidth
                                        spacing: ScreenTools.defaultFontPixelWidth * 1.5
                                        Image {
                                            width: ScreenTools.defaultFontPixelWidth * 3.5
                                            height: width*0.8
                                            source: "/custom/img/png/video.png"
                                        }
                                        QGCLabel { text: qsTr("Video Recording") }
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: capabilityTable.statusColWidth
                                    Layout.fillHeight: true
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                                        color: _root._statusColor(_videoRecording.rawValue, true)
                                        radius: 4
                                        width: recordingStatusContent.implicitWidth + ScreenTools.defaultFontPixelWidth
                                        height: recordingStatusContent.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.25
                                        Row {
                                            id: recordingStatusContent
                                            anchors.centerIn: parent
                                            spacing: ScreenTools.defaultFontPixelWidth * 0.45
                                            Image {
                                                y: 2
                                                width: _root._statusIconSize
                                                height: width
                                                source: _root._statusIcon(_videoRecording.rawValue)
                                            }
                                            QGCLabel {
                                                id: recordingStatus
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: _root._statusLabel(_videoRecording.rawValue, true)
                                                color: "#ffffff"
                                                font.family: ScreenTools.demiboldFontFamily
                                                font.pointSize: ScreenTools.mediumFontPointSize * ScreenTools.smallFontPointRatio
                                            }
                                        }
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: capabilityTable.descColWidth
                                    Layout.fillHeight: true
                                    QGCLabel {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                                        text: qsTr("Enabled only by user action")
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: capabilityTable.width
                            height: capabilityTable.rowHeight
                            color: qgcPal.windowShade

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0

                                Item {
                                    Layout.preferredWidth: capabilityTable.capColWidth
                                    Layout.fillHeight: true
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 3 * ScreenTools.defaultFontPixelWidth
                                        spacing: ScreenTools.defaultFontPixelWidth * 2
                                        Image {
                                            width: ScreenTools.defaultFontPixelWidth * 2.3
                                            height: width
                                            source: "/custom/img/png/Location.png"
                                            fillMode: Image.PreserveAspectFit
                                            mipmap: true
                                        }
                                        QGCLabel { text: qsTr("GPS / Location") }
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: capabilityTable.statusColWidth
                                    Layout.fillHeight: true
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                                        color: _root._statusColor(_gpsActive, false)
                                        radius: 4
                                        width: gpsStatusContent.implicitWidth + ScreenTools.defaultFontPixelWidth
                                        height: gpsStatusContent.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.25
                                        Row {
                                            id: gpsStatusContent
                                            anchors.centerIn: parent
                                            spacing: ScreenTools.defaultFontPixelWidth * 0.45
                                            Image {
                                                y: 2
                                                width: _root._statusIconSize
                                                height: width
                                                source: _root._statusIcon(_gpsActive)
                                            }
                                            QGCLabel {
                                                id: gpsStatus
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: _root._statusLabel(_gpsActive, false)
                                                color: "#ffffff"
                                                font.family: ScreenTools.demiboldFontFamily
                                                font.pointSize: ScreenTools.mediumFontPointSize * ScreenTools.smallFontPointRatio
                                            }
                                        }
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: capabilityTable.descColWidth
                                    Layout.fillHeight: true
                                    QGCLabel {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                                        text: qsTr("Navigation and mission planning")
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: capabilityTable.width
                            height: capabilityTable.rowHeight
                            color: qgcPal.windowShade

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0

                                Item {
                                    Layout.preferredWidth: capabilityTable.capColWidth
                                    Layout.fillHeight: true
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 3 * ScreenTools.defaultFontPixelWidth
                                        spacing: ScreenTools.defaultFontPixelWidth * 2.2
                                        Image {
                                            width: ScreenTools.defaultFontPixelWidth * 2
                                            height: width
                                            source: "/custom/img/png/TelemetryLog.png"
                                            fillMode: Image.PreserveAspectFit
                                            mipmap: true
                                        }
                                        QGCLabel { text: qsTr("Telemetry Log") }
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: capabilityTable.statusColWidth
                                    Layout.fillHeight: true
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                                        color: _root._statusColor(_telemetrySave.rawValue, false)
                                        radius: 4
                                        width: telemetryStatusContent.implicitWidth + ScreenTools.defaultFontPixelWidth
                                        height: telemetryStatusContent.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.25
                                        Row {
                                            id: telemetryStatusContent
                                            anchors.centerIn: parent
                                            spacing: ScreenTools.defaultFontPixelWidth * 0.45
                                            Image {
                                                y: 2
                                                width: _root._statusIconSize
                                                height: width
                                                source: _root._statusIcon(_telemetrySave.rawValue)
                                            }
                                            QGCLabel {
                                                id: telemetryStatus
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: _root._statusLabel(_telemetrySave.rawValue, false)
                                                color: "#ffffff"
                                                font.family: ScreenTools.demiboldFontFamily
                                                font.pointSize: ScreenTools.mediumFontPointSize * ScreenTools.smallFontPointRatio
                                            }
                                        }
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: capabilityTable.descColWidth
                                    Layout.fillHeight: true
                                    QGCLabel {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                                        text: qsTr("Diagnostics and flight analysis")
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: capabilityTable.width
                            height: capabilityTable.rowHeight
                            color: qgcPal.windowShade

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0

                                Item {
                                    Layout.preferredWidth: capabilityTable.capColWidth
                                    Layout.fillHeight: true
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 3 * ScreenTools.defaultFontPixelWidth
                                        spacing: ScreenTools.defaultFontPixelWidth * 2
                                        Image {
                                            width: ScreenTools.defaultFontPixelWidth * 2.4
                                            height: width
                                            source: "/custom/img/png/Microphone.png"
                                            fillMode: Image.PreserveAspectFit
                                            mipmap: true
                                        }
                                        QGCLabel { text: qsTr("Microphone") }
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: capabilityTable.statusColWidth
                                    Layout.fillHeight: true
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                                        color: _root._statusColor(false, false)
                                        radius: 4
                                        width: micStatusContent.implicitWidth + ScreenTools.defaultFontPixelWidth
                                        height: micStatusContent.implicitHeight + ScreenTools.defaultFontPixelHeight * 0.25
                                        Row {
                                            id: micStatusContent
                                            anchors.centerIn: parent
                                            spacing: ScreenTools.defaultFontPixelWidth * 0.45
                                            Image {
                                                y: 2
                                                width: _root._statusIconSize
                                                height: width
                                                source: _root._statusIcon(false)
                                            }
                                            QGCLabel {
                                                id: micStatus
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: _root._statusLabel(false, false)
                                                color: "#ffffff"
                                                font.family: ScreenTools.demiboldFontFamily
                                                font.pointSize: ScreenTools.mediumFontPointSize * ScreenTools.smallFontPointRatio
                                            }
                                        }
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: capabilityTable.descColWidth
                                    Layout.fillHeight: true
                                    QGCLabel {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                                        text: qsTr("QGC does not record audio")
                                    }
                                }
                            }
                        }
                    }
                    }
                // }
            }

            RowLayout {
                width:                      _panelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                spacing:                    _margins * 6

                Item {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    height: summaryTitle.implicitHeight + ScreenTools.defaultFontPixelHeight + summaryFrame.height

                    QGCLabel {
                        id: summaryTitle
                        text: qsTr("Data Handling Summary")
                    }

                    Rectangle {
                        id: summaryFrame
                        anchors.top: summaryTitle.bottom
                        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.4
                        width: parent.width + _margins * 3
                        color: qgcPal.windowShade
                        height: summaryColumn.height * 1.4

                        Column {
                            id: summaryColumn
                            spacing: ScreenTools.defaultFontPixelHeight * 0.7
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            Row {
                                width: parent.width
                                spacing: ScreenTools.defaultFontPixelWidth * 1.5
                                anchors.left: parent.left
                                anchors.leftMargin: 2.5 * ScreenTools.defaultFontPixelWidth

                                Image {
                                    width: ScreenTools.defaultFontPixelWidth * 3.5
                                    height: width * 0.8
                                    source: "/custom/img/png/video.png"
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    width: parent.width - ScreenTools.defaultFontPixelWidth * 2.6
                                    spacing: ScreenTools.defaultFontPixelHeight * 0.1

                                    QGCLabel {
                                        text: qsTr("Video Data")
                                    }

                                    QGCLabel {
                                        width: parent.width
                                        text: qsTr("Recorded only when user enables. Stored locally.")
                                        font.pointSize: ScreenTools.smallFontPointSize
                                        color: qgcPal.colorGrey
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: ScreenTools.defaultFontPixelWidth * 2.2
                                anchors.left: parent.left
                                anchors.leftMargin: 3 * ScreenTools.defaultFontPixelWidth

                                Image {
                                    width: ScreenTools.defaultFontPixelWidth * 2.3
                                    height: width
                                    source: "/custom/img/png/TelemetryGPS.png"
                                    fillMode: Image.PreserveAspectFit
                                    mipmap: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    width: parent.width - ScreenTools.defaultFontPixelWidth * 2.6
                                    spacing: ScreenTools.defaultFontPixelHeight * 0.1

                                    QGCLabel {
                                        text: qsTr("Telemetry & GPS")
                                    }

                                    QGCLabel {
                                        width: parent.width
                                        text: qsTr("Stored as flight logs on local system for analysis.")
                                        font.pointSize: ScreenTools.smallFontPointSize
                                        color: qgcPal.colorGrey
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: ScreenTools.defaultFontPixelWidth * 2.2
                                anchors.left: parent.left
                                anchors.leftMargin: 3 * ScreenTools.defaultFontPixelWidth
                                Image {
                                    width: ScreenTools.defaultFontPixelWidth * 2.3
                                    height: width
                                    source: "/custom/img/png/Audio.png"
                                    fillMode: Image.PreserveAspectFit
                                    mipmap: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    width: parent.width - ScreenTools.defaultFontPixelWidth * 2.6
                                    spacing: ScreenTools.defaultFontPixelHeight * 0.1

                                    QGCLabel {
                                        text: qsTr("Audio")
                                    }

                                    QGCLabel {
                                        width: parent.width
                                        text: qsTr("No audio data is collected or recorded.")
                                        font.pointSize: ScreenTools.smallFontPointSize
                                        color: qgcPal.colorGrey
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    height: controlTitle.implicitHeight + ScreenTools.defaultFontPixelHeight + controlFrame.height

                    QGCLabel {
                        id: controlTitle
                        text: qsTr("User Control")
                    }

                    Rectangle {
                        id: controlFrame
                        anchors.top: controlTitle.bottom
                        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.4
                        width: summaryFrame.width - _margins * 3
                        color: qgcPal.windowShade
                        height: summaryFrame.height

                        Column {
                            id: controlColumn
                            spacing: ScreenTools.defaultFontPixelHeight 
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: ScreenTools.defaultFontPixelHeight * 2
                            anchors.margins: _margins

                            RowLayout {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - 5 * _margins

                                QGCLabel {
                                    text: qsTr("Enable video recording")
                                    Layout.fillWidth: true
                                }

                                QGCSwitch {
                                    checked: _videoRecording.rawValue
                                    onClicked: {
                                            if (!checked) {
                                                // 1. Stop GStreamer / software stream recording
                                                QGroundControl.videoManager.stopRecording()
                                                // 2. Stop MAVLink camera recording (stopVideo is safe: only stops if running)
                                                var vehicle = QGroundControl.multiVehicleManager.activeVehicle
                                                if (vehicle) {
                                                    var camMgr = vehicle.cameraManager
                                                    if (camMgr && camMgr.cameras.count > 0) {
                                                        var idx = camMgr.currentCamera
                                                        var cam = (idx >= 0) ? camMgr.cameras.get(idx) : null
                                                        if (cam) {
                                                            cam.stopVideo()
                                                        }
                                                    }
                                                }
                                            }
                                        _videoRecording.rawValue = checked
                                        CustomQmlInterface.logSecurityEvent("Privacy video recording " + (checked ? "enabled" : "disabled"))
                                    }
                                }
                            }

                            RowLayout {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - 5 * _margins

                                QGCLabel {
                                    text: qsTr("Save telemetry logs")
                                    Layout.fillWidth: true
                                }

                                QGCSwitch {
                                    checked: _telemetrySave.rawValue
                                    onClicked: {
                                        _telemetrySave.rawValue = checked
                                        CustomQmlInterface.logSecurityEvent("Telemetry log saving " + (checked ? "enabled" : "disabled"))
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
