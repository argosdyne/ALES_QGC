/****************************************************************************
 *
 * (c) 2009-2019 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 * @file
 *   @author Gus Grubba <gus@auterion.com>
 */

import QtQuick          2.12
import QtQuick.Controls 2.4
import QtQuick.Layouts  1.11
import QtGraphicalEffects 1.12

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.FlightMap     1.0

import Custom.Widgets 1.0
import CustomQmlInterface 1.0

Item {
    property var parentToolInsets                       // These insets tell you what screen real estate is available for positioning the controls in your overlay
    property var totalToolInsets:   _totalToolInsets    // The insets updated for the custom overlay additions
    property var mapControl

    readonly property string noGPS:         qsTr("NO GPS")
    readonly property real   indicatorValueWidth:   ScreenTools.defaultFontPixelWidth * 7

    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property real   _indicatorDiameter:     ScreenTools.defaultFontPixelWidth * 18
    property real   _indicatorsHeight:      ScreenTools.defaultFontPixelHeight
    property var    _sepColor:              qgcPal.globalTheme === QGCPalette.Light ? Qt.rgba(0,0,0,0.5) : Qt.rgba(1,1,1,0.5)
    property color  _indicatorsColor:       qgcPal.text
    property bool   _isVehicleGps:          _activeVehicle ? _activeVehicle.gps.count.rawValue > 1 && _activeVehicle.gps.hdop.rawValue < 1.4 : false
    property string _altitude:              _activeVehicle ? (isNaN(_activeVehicle.altitudeRelative.value) ? "0.0" : _activeVehicle.altitudeRelative.value.toFixed(1)) + ' ' + _activeVehicle.altitudeRelative.units : "0.0"
    property string _distanceStr:           isNaN(_distance) ? "0" : _distance.toFixed(0) + ' ' + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString
    property real   _heading:               _activeVehicle   ? _activeVehicle.heading.rawValue : 0
    property real   _distance:              _activeVehicle ? _activeVehicle.distanceToHome.rawValue : 0
    property string _messageTitle:          ""
    property string _messageText:           ""
    property real   _toolsMargin:           ScreenTools.defaultFontPixelWidth * 0.75
    property bool   _showTelemetryPanel:    false

    function secondsToHHMMSS(timeS) {
        var sec_num = parseInt(timeS, 10);
        var hours   = Math.floor(sec_num / 3600);
        var minutes = Math.floor((sec_num - (hours * 3600)) / 60);
        var seconds = sec_num - (hours * 3600) - (minutes * 60);
        if (hours   < 10) {hours   = "0"+hours;}
        if (minutes < 10) {minutes = "0"+minutes;}
        if (seconds < 10) {seconds = "0"+seconds;}
        return hours+':'+minutes+':'+seconds;
    }

    Component.onCompleted: {
        CustomQmlInterface.defaultFontPixelWidth = Qt.binding(function() { return ScreenTools.defaultFontPixelWidth })
        CustomQmlInterface.defaultFontPixelHeight = Qt.binding(function() { return ScreenTools.defaultFontPixelHeight })
    }

    QGCToolInsets {
        id:                     _totalToolInsets
//        topEdgeCenterInset:     compassArrowIndicator.y + compassArrowIndicator.height
//        rightEdgeBottomInset:   parent.width - compassBackground.x
        bottomEdgeCenterInset:  parent.height
    }

    // Item {
    //     id: attitudeWidgetArea
    //     visible: false
    //     width: attitudeWidget.width + ScreenTools.defaultFontPixelHeight * 10
    //     height: attitudeWidget.height + ScreenTools.defaultFontPixelHeight * 3
    //     anchors.horizontalCenter: parent.horizontalCenter
    //     anchors.horizontalCenterOffset: -ScreenTools.defaultFontPixelWidth * 0.5
    //     anchors.bottom: parent.bottom
    //     anchors.bottomMargin: guidedActionConfirmPanel.visible ? guidedActionConfirmPanel.height : 0
    //     CustomVehicleAttitude {
    //         id: attitudeWidget
    //         size: parent.parent.width / 8
    //         anchors.left: parent.left
    //         anchors.leftMargin: ScreenTools.defaultFontPixelHeight * 5
    //         anchors.bottom: parent.bottom
    //         anchors.bottomMargin: ScreenTools.defaultFontPixelHeight
    //     }
    // }

    // DropShadow {
    //     anchors.fill: attitudeWidgetArea
    //     horizontalOffset: 0
    //     verticalOffset: 0
    //     radius: 8
    //     spread: 0.5
    //     samples: 10
    //     color: "#90000000"
    //     source: attitudeWidgetArea
    //     visible: !_showTelemetryPanel
    //     Rectangle {
    //         id: flightTimeRect
    //         anchors.left: parent.right
    //         anchors.bottom: parent.bottom
    //         anchors.bottomMargin: ScreenTools.defaultFontPixelWidth
    //         anchors.leftMargin: -ScreenTools.defaultFontPixelHeight * 4
    //         color: "#222222"
    //         opacity: 0.8
    //         radius: ScreenTools.defaultFontPixelWidth
    //         width: flightTimeCol.width + ScreenTools.defaultFontPixelWidth * 2
    //         height: flightTimeCol.height + ScreenTools.defaultFontPixelWidth
    //     }
    //     Column {
    //         id: flightTimeCol
    //         anchors.centerIn: flightTimeRect
    // //        QGCLabel {
    // //            text: qsTr("Flight Time")
    // //            horizontalAlignment: Text.AlignRight
    // //            anchors.horizontalCenter: parent.horizontalCenter
    // //        }
    //         QGCLabel {
    //             color: attitudeWidget.color
    //             text:   _activeVehicle ? _activeVehicle.getFact("flightTime").valueString : "00:00:00"
    //             font.pointSize: ScreenTools.mediumFontPointSize
    //             font.bold: true
    //             horizontalAlignment: Text.AlignRight
    //             anchors.horizontalCenter: parent.horizontalCenter
    //         }
    //         QGCLabel {
    //             color: attitudeWidget.color
    //             text: _activeVehicle ? _activeVehicle.coordinate.longitude.toFixed(7) : "--.--"
    //             font.pointSize: ScreenTools.smallFontPointSize
    //             horizontalAlignment: Text.AlignRight
    //             anchors.right: parent.right
    //         }
    //         QGCLabel {
    //             color: attitudeWidget.color
    //             text: _activeVehicle ? _activeVehicle.coordinate.latitude.toFixed(7) : "--.--"
    //             font.pointSize: ScreenTools.smallFontPointSize
    //             horizontalAlignment: Text.AlignRight
    //             anchors.right: parent.right
    //         }
    //     }
    //     MouseArea {
    //         anchors.fill: parent
    //         preventStealing:true
    //         hoverEnabled:   true
    //         onDoubleClicked: {
    //             _showTelemetryPanel = !_showTelemetryPanel
    //         }
    //     }
    // }

    Rectangle {
        id:                 telemetryPanel
        height:             telemetryLayout.height + (_toolsMargin * 2)
        width:              telemetryLayout.width + (_toolsMargin * 2)
        color:              qgcPal.window
        radius:             ScreenTools.defaultFontPixelWidth / 2
        visible:            _showTelemetryPanel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        //anchors.bottomMargin: guidedActionConfirmPanel.visible ? guidedActionConfirmPanel.height : 0

        ColumnLayout {
            id:                 telemetryLayout
            anchors.margins:    _toolsMargin
            anchors.bottom:     parent.bottom
            anchors.left:       parent.left

             RowLayout {
                visible: mouseArea.containsMouse || valueArea.settingsUnlocked

                QGCColoredImage {
                    source:             valueArea.settingsUnlocked ? "/res/LockOpen.svg" : "/res/pencil.svg"
                    mipmap:             true
                    width:              ScreenTools.minTouchPixels * 0.75
                    height:             width
                    sourceSize.width:   width
                    color:              qgcPal.text
                    fillMode:           Image.PreserveAspectFit

                    QGCMouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    valueArea.settingsUnlocked = !valueArea.settingsUnlocked
                    }
                }
            }

            QGCMouseArea {
                id:                         mouseArea
                x:                          telemetryLayout.x
                y:                          telemetryLayout.y
                width:                      telemetryLayout.width
                height:                     telemetryLayout.height
                hoverEnabled:               true
                propagateComposedEvents:    true
                preventStealing:            true
                onDoubleClicked: {
                    _showTelemetryPanel = !_showTelemetryPanel
                }
            }

            HorizontalFactValueGrid {
                id:                     valueArea
                userSettingsGroup:      telemetryBarUserSettingsGroup
                defaultSettingsGroup:   telemetryBarDefaultSettingsGroup
            }
        }
    }

    //-------------------------------------------------------------------------
    //-- System Messages
    Repeater {
        id: systemMessageRepeater
        model: CustomQmlInterface.systemMessages
        Rectangle {
            id:                 systemMessageArea
            width:              object.width
            height:             object.height
            focus:              true
            visible:            true
            color:              qgcPal.windowShade
            radius:             1
            border.color:       qgcPal.window
            border.width:       1
            opacity:            object.opacity
            x:                  Math.round((mainWindow.width - width) * 0.5)
            y:                  object.y

            Image {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                width: ScreenTools.defaultFontPixelHeight * 1.5
                height: width
                source: object.icon
                visible: false
            }

            QGCLabel {
                id: dumyPrefix
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                text: qsTr("CRITICAL:")
                visible: false
            }

            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                color: object.color
                text: {
                    if(object.icon === "qrc:/custom/img/png/info.png") return qsTr("INFO:")
                    else if(object.icon === "qrc:/custom/img/png/error.png") return qsTr("CRITICAL:");
                    else if(object.icon === "qrc:/custom/img/png/warning.png") return qsTr("WARNING:");
                    else if(object.icon === "qrc:/custom/img/png/success.png") return qsTr("SUCCESS:");
                    else return qsTr("NONE:");
                }
            }

            TextEdit {
                id:             systemMessageText
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 2 + dumyPrefix.width
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 2
                anchors.verticalCenter: systemMessageArea.verticalCenter
                readOnly:       true
                textFormat:     TextEdit.RichText
                font.pointSize: ScreenTools.defaultFontPointSize
                font.family:    ScreenTools.demiboldFontFamily
                wrapMode:       TextEdit.WordWrap
                color:          object.color
                text:           object.context
            }

            //-- Dismiss Critical Message
            QGCColoredImage {
                id:                 systemMessageClose
                anchors.margins:    ScreenTools.defaultFontPixelWidth
                anchors.top:        parent.top
                anchors.right:      parent.right
                width:              ScreenTools.defaultFontPixelHeight
                height:             width
                sourceSize.height:  width
                source:             "qrc:/res/XDelete.svg"
                fillMode:           Image.PreserveAspectFit
                color:              qgcPal.buttonText
                MouseArea {
                    anchors.fill:       parent
                    anchors.margins:    -ScreenTools.defaultFontPixelHeight
                    onClicked: {
                        object.closeItstyle()
                    }
                }
            }
        }
    }

    //-------------------------------------------------------------------------
    //-- Status Messages
    Column {
        id: statusMessageCol
        width: Math.min(parent.width * 0.25, ScreenTools.defaultFontPixelWidth * 40)
        anchors.top:        parent.top
        anchors.topMargin:  ScreenTools.defaultFontPixelWidth
        anchors.right:      parent.right
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth
        Repeater {
            model: _activeVehicle ? _activeVehicle.statusMessages : null
            Rectangle {
                id:                 statusMessageArea
                focus:              true
                visible:            true
                color:              qgcPal.windowShade
                radius:             1
                border.color:       qgcPal.window
                border.width:       1
                opacity:            object.opacity
                width:              statusMessageCol.width
                height:             Math.max(ScreenTools.defaultFontPixelHeight * 1.5, statusTextEdit.height) + ScreenTools.defaultFontPixelHeight
                x:                  width + ScreenTools.defaultFontPixelWidth * 2
                XAnimator {
                    target: statusMessageArea
                    from: width + ScreenTools.defaultFontPixelWidth * 2
                    to: 0
                    duration: 100
                    running: true
                }
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                    width: ScreenTools.defaultFontPixelHeight * 1.5
                    height: width
                    source: object.icon
                }

                TextEdit {
                    id: statusTextEdit
                    anchors.left:   parent.left
                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 2 + ScreenTools.defaultFontPixelHeight * 1.5
                    anchors.verticalCenter: statusMessageArea.verticalCenter
                    width: statusMessageCol.width - ScreenTools.defaultFontPixelWidth * 2
                    readOnly:       true
                    textFormat:     TextEdit.RichText
                    font.pointSize: ScreenTools.defaultFontPointSize
                    font.family:    ScreenTools.demiboldFontFamily
                    wrapMode:       TextEdit.WordWrap
                    color:          object.color
                    text:           object.context
                }
            }
        }
    }
    //-------------------------------------------------------------------------
    //-- Heading Indicator
//    Rectangle {
//        id:                         compassBar
//        height:                     ScreenTools.defaultFontPixelHeight * 1.5
//        width:                      ScreenTools.defaultFontPixelWidth  * 50
//        color:                      "#DEDEDE"
//        radius:                     2
//        clip:                       true
//        anchors.top:                headingIndicator.bottom
//        anchors.topMargin:          -headingIndicator.height / 2
//        anchors.horizontalCenter:   parent.horizontalCenter
//        Repeater {
//            model: 720
//            QGCLabel {
//                function _normalize(degrees) {
//                    var a = degrees % 360
//                    if (a < 0) a += 360
//                    return a
//                }
//                property int _startAngle: modelData + 180 + _heading
//                property int _angle: _normalize(_startAngle)
//                anchors.verticalCenter: parent.verticalCenter
//                x:              visible ? ((modelData * (compassBar.width / 360)) - (width * 0.5)) : 0
//                visible:        _angle % 45 == 0
//                color:          "#75505565"
//                font.pointSize: ScreenTools.smallFontPointSize
//                text: {
//                    switch(_angle) {
//                    case 0:     return "N"
//                    case 45:    return "NE"
//                    case 90:    return "E"
//                    case 135:   return "SE"
//                    case 180:   return "S"
//                    case 225:   return "SW"
//                    case 270:   return "W"
//                    case 315:   return "NW"
//                    }
//                    return ""
//                }
//            }
//        }
//    }
//    Rectangle {
//        id:                         headingIndicator
//        height:                     ScreenTools.defaultFontPixelHeight
//        width:                      ScreenTools.defaultFontPixelWidth * 4
//        color:                      qgcPal.windowShadeDark
//        anchors.top:                parent.top
//        anchors.topMargin:          _toolsMargin
//        anchors.horizontalCenter:   parent.horizontalCenter
//        QGCLabel {
//            text:                   _heading
//            color:                  qgcPal.text
//            font.pointSize:         ScreenTools.smallFontPointSize
//            anchors.centerIn:       parent
//        }
//    }
//    Image {
//        id:                         compassArrowIndicator
//        height:                     _indicatorsHeight
//        width:                      height
//        source:                     "/custom/img/compass_pointer.svg"
//        fillMode:                   Image.PreserveAspectFit
//        sourceSize.height:          height
//        anchors.top:                compassBar.bottom
//        anchors.topMargin:          -height / 2
//        anchors.horizontalCenter:   parent.horizontalCenter
//    }

//    Rectangle {
//        id:                     compassBackground
//        anchors.bottom:         attitudeIndicator.bottom
//        anchors.right:          attitudeIndicator.left
//        anchors.rightMargin:    -attitudeIndicator.width / 2
//        width:                  -anchors.rightMargin + compassBezel.width + (_toolsMargin * 2)
//        height:                 attitudeIndicator.height * 0.75
//        radius:                 2
//        color:                  qgcPal.window

//        Rectangle {
//            id:                     compassBezel
//            anchors.verticalCenter: parent.verticalCenter
//            anchors.leftMargin:     _toolsMargin
//            anchors.left:           parent.left
//            width:                  height
//            height:                 parent.height - (northLabelBackground.height / 2) - (headingLabelBackground.height / 2)
//            radius:                 height / 2
//            border.color:           qgcPal.text
//            border.width:           1
//            color:                  Qt.rgba(0,0,0,0)
//        }

//        Rectangle {
//            id:                         northLabelBackground
//            anchors.top:                compassBezel.top
//            anchors.topMargin:          -height / 2
//            anchors.horizontalCenter:   compassBezel.horizontalCenter
//            width:                      northLabel.contentWidth * 1.5
//            height:                     northLabel.contentHeight * 1.5
//            radius:                     ScreenTools.defaultFontPixelWidth  * 0.25
//            color:                      qgcPal.windowShade

//            QGCLabel {
//                id:                 northLabel
//                anchors.centerIn:   parent
//                text:               "N"
//                color:              qgcPal.text
//                font.pointSize:     ScreenTools.smallFontPointSize
//            }
//        }

//        Image {
//            id:                 headingNeedle
//            anchors.centerIn:   compassBezel
//            height:             compassBezel.height * 0.75
//            width:              height
//            source:             "/custom/img/compass_needle.svg"
//            fillMode:           Image.PreserveAspectFit
//            sourceSize.height:  height
//            transform: [
//                Rotation {
//                    origin.x:   headingNeedle.width  / 2
//                    origin.y:   headingNeedle.height / 2
//                    angle:      _heading
//                }]
//        }

//        Rectangle {
//            id:                         headingLabelBackground
//            anchors.top:                compassBezel.bottom
//            anchors.topMargin:          -height / 2
//            anchors.horizontalCenter:   compassBezel.horizontalCenter
//            width:                      headingLabel.contentWidth * 1.5
//            height:                     headingLabel.contentHeight * 1.5
//            radius:                     ScreenTools.defaultFontPixelWidth  * 0.25
//            color:                      qgcPal.windowShade

//            QGCLabel {
//                id:                 headingLabel
//                anchors.centerIn:   parent
//                text:               _heading
//                color:              qgcPal.text
//                font.pointSize:     ScreenTools.smallFontPointSize
//            }
//        }
//    }

//    Rectangle {
//        id:                     attitudeIndicator
//        anchors.bottomMargin:   _toolsMargin
//        anchors.rightMargin:    _toolsMargin
//        anchors.bottom:         parent.bottom
//        anchors.right:          parent.right
//        height:                 ScreenTools.defaultFontPixelHeight * 6
//        width:                  height
//        radius:                 height * 0.5
//        color:                  qgcPal.windowShade

//        CustomAttitudeWidget {
//            size:               parent.height * 0.95
//            vehicle:            _activeVehicle
//            showHeading:        false
//            anchors.centerIn:   parent
//        }
//    }
}
