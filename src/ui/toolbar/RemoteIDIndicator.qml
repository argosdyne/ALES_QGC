/****************************************************************************
 *
 * (c) 2009-2022 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.11
import QtQuick.Layouts  1.11

import QGroundControl                       1.0
import QGroundControl.Controls              1.0
import QGroundControl.MultiVehicleManager   1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.Palette               1.0

//-------------------------------------------------------------------------
//-- Remote ID Indicator
Item {
    id:             _root
    width:          remoteIDIcon.width * 1.1
    anchors.top:    parent.top
    anchors.bottom: parent.bottom

    property bool showIndicator: QGroundControl.settingsManager.remoteIDSettings.enable.value

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property int    remoteIDState:      getRemoteIDState()

    property bool   gpsFlag:            _activeVehicle && _activeVehicle.remoteIDManager ? _activeVehicle.remoteIDManager.gcsGPSGood         : false
    property bool   basicIDFlag:        _activeVehicle && _activeVehicle.remoteIDManager ? _activeVehicle.remoteIDManager.basicIDGood        : false
    property bool   armFlag:            _activeVehicle && _activeVehicle.remoteIDManager ? _activeVehicle.remoteIDManager.armStatusGood      : false
    property bool   commsFlag:          _activeVehicle && _activeVehicle.remoteIDManager ? _activeVehicle.remoteIDManager.commsGood          : false
    property bool   emergencyDeclared:  _activeVehicle && _activeVehicle.remoteIDManager ? _activeVehicle.remoteIDManager.emergencyDeclared  : false
    property bool   operatorIDFlag:     _activeVehicle && _activeVehicle.remoteIDManager ? _activeVehicle.remoteIDManager.operatorIDGood     : false
    
    property int    _regionOperation:   QGroundControl.settingsManager.remoteIDSettings.region.value

    // Flags visual properties
    property real   flagsWidth:         ScreenTools.defaultFontPixelWidth * 10
    property real   flagsHeight:        ScreenTools.defaultFontPixelWidth * 5
    property int    radiusFlags:        5

    // Visual properties
    property real   _margins:           ScreenTools.defaultFontPixelWidth
    property real   _popupPadding:      ScreenTools.defaultFontPixelHeight * 0.67
    property color  _goodColor:         "#40c057"
    property color  _badColor:          "#e03131"
    property color  _hintColor:         "#adb5bd"
    property color  _dividerColor:      "#495057"
    property color  _emergencyColor:            "#e03131"
    property color  _emergencyHighlightColor:   "#ff6b6b"

    enum RIDState {
        HEALTHY,
        WARNING,
        ERROR,
        UNAVAILABLE
    }

    enum RegionOperation {
        FAA,
        EU
    }

    function getRIDIcon() {
        switch (remoteIDState) {
            case RemoteIDIndicator.RIDState.HEALTHY: 
                return "/qmlimages/RidIconGreen.svg"
                break
            case RemoteIDIndicator.RIDState.WARNING: 
                return "/qmlimages/RidIconYellow.svg"
                break
            case RemoteIDIndicator.RIDState.ERROR: 
                return "/qmlimages/RidIconRed.svg"
                break
            case RemoteIDIndicator.RIDState.UNAVAILABLE: 
                return "/qmlimages/RidIconGrey.svg"
                break
            default:
                return "/qmlimages/RidIconGrey.svg"
        }
    }

    function getRemoteIDState() {
        if (!_activeVehicle) {
            return RemoteIDIndicator.RIDState.UNAVAILABLE
        }
        // We need to have comms and arm healthy to even be in any other state other than ERROR
        if (!commsFlag || !armFlag || emergencyDeclared) {
            return RemoteIDIndicator.RIDState.ERROR
        }
        if (!gpsFlag || !basicIDFlag) {
            return RemoteIDIndicator.RIDState.WARNING
        }
        if (_regionOperation == RemoteIDIndicator.RegionOperation.EU || QGroundControl.settingsManager.remoteIDSettings.sendOperatorID.value) {
            if (!operatorIDFlag) {
                return RemoteIDIndicator.RIDState.WARNING
            }
        }
        return RemoteIDIndicator.RIDState.HEALTHY
    }

    function goToSettings() {
        if (!mainWindow.preventViewSwitch()) {
            globals.commingFromRIDIndicator = true
            mainWindow.showSettingsTool()
        }
    }

    Component {
        id: remoteIDInfo

        Rectangle {
            width:          ScreenTools.defaultFontPixelHeight * 10.6
            height:         remoteIDCol.height + (_popupPadding * 2)
            radius:         ScreenTools.defaultFontPixelHeight * 0.45
            color:          qgcPal.window

            Column {
                id:                 remoteIDCol
                anchors.top:        parent.top
                anchors.left:       parent.left
                anchors.right:      parent.right
                anchors.margins:    _popupPadding
                spacing:            ScreenTools.defaultFontPixelHeight * 0.45

                QGCLabel {
                    width:                  parent.width
                    text:                   qsTr("RemoteID Status")
                    font.family:            ScreenTools.demiboldFontFamily
                    font.pointSize:         ScreenTools.defaultFontPointSize * 0.9
                    horizontalAlignment:    Text.AlignHCenter
                }

                Column {
                    width:      parent.width
                    spacing:    ScreenTools.defaultFontPixelHeight * 0.28

                    Repeater {
                        model: [
                            { label: qsTr("ARM STATUS"),  flag: "arm" },
                            { label: qsTr("RID COMMS"),   flag: "comms" },
                            { label: qsTr("GCS GPS"),     flag: "gps" },
                            { label: qsTr("BASIC ID"),    flag: "basicID" },
                            { label: qsTr("OPERATOR ID"), flag: "operatorID" }
                        ]

                        Item {
                            width:          parent.width
                            implicitHeight: rowLabel.implicitHeight
                            height:         visible ? implicitHeight : 0
                            visible: {
                                switch (modelData.flag) {
                                case "comms":       return true
                                case "operatorID":  return commsFlag && _activeVehicle ? (QGroundControl.settingsManager.remoteIDSettings.sendOperatorID.value || _regionOperation == RemoteIDIndicator.RegionOperation.EU) : false
                                default:            return commsFlag
                                }
                            }

                            property bool _good: {
                                switch (modelData.flag) {
                                case "arm":         return armFlag
                                case "comms":       return commsFlag
                                case "gps":         return gpsFlag
                                case "basicID":     return basicIDFlag
                                default:            return operatorIDFlag
                                }
                            }

                            QGCLabel {
                                id:                     rowLabel
                                anchors.left:           parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text:                   modelData.label
                                font.pointSize:         ScreenTools.defaultFontPointSize * 0.83
                            }

                            Row {
                                anchors.right:          parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing:                ScreenTools.defaultFontPixelHeight * 0.22

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width:                  ScreenTools.defaultFontPixelHeight * 0.28
                                    height:                 width
                                    radius:                 width / 2
                                    color:                  rowValue.color
                                }

                                QGCLabel {
                                    id:             rowValue
                                    text:           parent.parent._good ? qsTr("OK") : (modelData.flag === "comms" ? qsTr("NOT CONNECTED") : qsTr("Failed"))
                                    color:          parent.parent._good ? _goodColor : _badColor
                                    font.family:    ScreenTools.demiboldFontFamily
                                    font.pointSize: ScreenTools.defaultFontPointSize * 0.83
                                }
                            }

                            QGCMouseArea {
                                anchors.fill:   parent
                                onClicked:      goToSettings()
                            }
                        }
                    }
                }

                Rectangle {
                    width:      parent.width
                    height:     1
                    color:      _dividerColor
                    visible:    commsFlag
                }

                QGCLabel {
                    width:                  parent.width
                    text:                   emergencyDeclared ? qsTr("EMERGENCY HAS BEEN DECLARED, Press and Hold for 3 seconds to cancel") : qsTr("Press and Hold below button to declare emergency")
                    color:                  _hintColor
                    font.pointSize:         ScreenTools.defaultFontPointSize * 0.76
                    wrapMode:               Text.WordWrap
                    horizontalAlignment:    Text.AlignHCenter
                    visible:                commsFlag
                }

                Rectangle {
                    id:         emergencyButton
                    width:      parent.width
                    height:     emergencyLabel.implicitHeight + (ScreenTools.defaultFontPixelHeight * 0.78)
                    radius:     ScreenTools.defaultFontPixelHeight * 0.22
                    color:      _highlighted ? _emergencyHighlightColor : _emergencyColor
                    visible:    commsFlag

                    property bool _highlighted: false

                    QGCLabel {
                        id:                 emergencyLabel
                        anchors.centerIn:   parent
                        text:               emergencyDeclared ? qsTr("Clear Emergency") : qsTr("EMERGENCY")
                        color:              "white"
                        font.bold:          true
                        font.pointSize:     ScreenTools.defaultFontPointSize * 0.83
                    }

                    Timer {
                        id:             emergencyButtonTimer
                        interval:       350
                        onTriggered:    emergencyButton._highlighted = !emergencyButton._highlighted
                    }

                    MouseArea {
                        anchors.fill:           parent
                        hoverEnabled:           true
                        onEntered:              emergencyButton._highlighted = true
                        onExited:               emergencyButton._highlighted = false
                        pressAndHoldInterval:   emergencyDeclared ? 3000 : 800
                        onPressAndHold: {
                            emergencyButton._highlighted = !emergencyButton._highlighted
                            emergencyButtonTimer.restart()
                            if (_activeVehicle) {
                                _activeVehicle.remoteIDManager.setEmergency(!emergencyDeclared)
                            }
                        }
                    }
                }
            }
        }
    }

    Image {
        id:                 remoteIDIcon
        width:              height
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        source:             getRIDIcon()
        fillMode:           Image.PreserveAspectFit
        sourceSize.height:  height
    }

    MouseArea {
        anchors.fill:   parent
        onClicked: {
            mainWindow.showIndicatorPopup(_root, remoteIDInfo)
        }
    }
}
