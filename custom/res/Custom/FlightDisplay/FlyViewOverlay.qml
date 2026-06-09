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

import QtQuick          2.15
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
    id: _flyViewOverlay

    property var parentToolInsets                       // These insets tell you what screen real estate is available for positioning the controls in your overlay
    property var totalToolInsets:   _totalToolInsets    // The insets updated for the custom overlay additions
    property var mapControl

    readonly property string noGPS:         qsTr("NO GPS")
    readonly property real   indicatorValueWidth:   ScreenTools.defaultFontPixelWidth * 7

    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property var    _missionController:     globals.planMasterControllerFlyView ? globals.planMasterControllerFlyView.missionController : null
    property real   _rightPanelWidth:       ScreenTools.defaultFontPixelWidth * 22
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
                    if(object.icon === "qrc:/custom/img/png/info.png") return qsTranslate("FlyViewOverlay", "INFO:");
                    else if(object.icon === "qrc:/custom/img/png/error.png") return qsTranslate("FlyViewOverlay", "CRITICAL:");
                    else if(object.icon === "qrc:/custom/img/png/warning.png") return qsTranslate("FlyViewOverlay", "WARNING:");
                    else if(object.icon === "qrc:/custom/img/png/success.png") return qsTranslate("FlyViewOverlay", "SUCCESS:");
                    else return qsTranslate("FlyViewOverlay", "NONE:");
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
    //-- GeoAwareness Alert Messages
    Repeater {
        id: geoAwarenessMessageRepeater
        model: CustomQmlInterface.geoAwarenessMessages
        Rectangle {
            id:                 geoAwarenessMessageArea
            width:              object.geoAwarenessWidth
            height:             Math.max(object.geoAwarenessHeight, geoAwarenessMessageAreaMessageText.contentHeight)
            focus:              true
            visible:            true
            color:              "white"//qgcPal.windowShade
            radius:             ScreenTools.defaultFontPixelWidth * 1.5
            border.color:       qgcPal.window
            border.width:       1
            opacity:            object.geoAwarenessOpacity
            x:                  Math.round((mainWindow.width - width) * 0.5)
            y:                  object.geoAwarenessY

            QGCLabel {
                id: geoAwarenessdumyPrefix
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                text: qsTr("CRITICAL:")
                visible: false
            }

            //Draw Left half circle
            Canvas {
                id: blueSemicircleCanvas
                anchors.left: parent.left
                width: ScreenTools.defaultFontPixelWidth * 1.5
                height: parent.height // Canvas 높이 (반원의 지름이 될 크기)

                property real cornerRadius: parent.radius // 둥근 모서리의 반지름 (조절 가능)
                property color fillColor: "red" // 채우기 색상
                property color strokeColor: "red" // 선 색상 (옵션)
                property real strokeWidth: 2 // 선 두께 (옵션)

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height); // Canvas 초기화

                    // 도형의 각 점 좌표 계산
                    // 캔버스 내부에 도형을 그릴 것이므로, 캔버스의 (0,0)을 기준으로 합니다.
                    var x = 0;
                    var y = 0;
                    var w = width;
                    var h = height;
                    var r = cornerRadius; // 둥근 모서리 반지름

                    ctx.beginPath();
                    // 1. 왼쪽 하단 모서리 시작 (곡선 시작점)
                    // 현재 Canvas의 (0,0)은 왼쪽 위입니다.
                    // 왼쪽 아래 모서리 둥글게 시작: (x + r, h)
                    ctx.moveTo(x + r, h);

                    // 2. 아랫변 (오른쪽으로 직선 이동)
                    ctx.lineTo(x + w, h);

                    // 3. 오른쪽 하단 모서리 (직선, 둥글게 처리하지 않음)
                    // 오른쪽은 직각이므로, 단순하게 아래변 끝에서 윗변 끝으로 직선으로 올립니다.
                    // (x + w, h) -> (x + w, y)
                    ctx.lineTo(x + w, y);

                    // 4. 윗변 (왼쪽으로 직선 이동)
                    ctx.lineTo(x + r, y);

                    // 5. 왼쪽 상단 모서리 (곡선)
                    // arcTo(x1, y1, x2, y2, radius)
                    // (x+r, y)에서 (x,y)를 거쳐 (x, y+r)로 둥글게
                    ctx.arcTo(x, y, x, y + r, r);

                    // 6. 왼쪽 하단 모서리 (곡선, 경로 닫기)
                    // (x, y+r)에서 (x,h)를 거쳐 (x+r, h)로 둥글게
                    ctx.arcTo(x, h, x + r, h, r);


                    ctx.closePath(); // 경로 닫기

                    ctx.fillStyle = fillColor;
                    ctx.fill();
                }
            }

            Image {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 2
                source:             "qrc:/custom/img/res/Images/redWarning.svg"
                width:              ScreenTools.defaultFontPixelHeight * 2.5
                height:             width
            }

            TextEdit {
                id:             geoAwarenessMessageAreaMessageText
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 2 + geoAwarenessdumyPrefix.width
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 2
                anchors.verticalCenter: geoAwarenessMessageArea.verticalCenter
                readOnly:       true
                textFormat:     TextEdit.RichText
                font.pointSize: ScreenTools.defaultFontPointSize * 2
                font.family:    ScreenTools.demiboldFontFamily
                wrapMode:       TextEdit.WordWrap
                color:          "black"
                text:           object.geoAwarenessContext
            }
            //Seperator line
            Rectangle {
                color: "#9fa0a0"
                width: 1
                height: parent.height * 0.6
                anchors.left: geoAwarenessMessageClose.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 10
            }

            //-- Dismiss Critical Message
            QGCColoredImage {
                id:                 geoAwarenessMessageClose
                anchors.margins:    ScreenTools.defaultFontPixelWidth
                //anchors.top:        parent.top
                anchors.verticalCenter: parent.verticalCenter
                anchors.right:      parent.right
                width:              ScreenTools.defaultFontPixelHeight
                height:             width
                sourceSize.height:  width
                source:             "qrc:/res/XDelete.svg"
                fillMode:           Image.PreserveAspectFit
                color:              "#9fa0a0" //qgcPal.buttonText
                MouseArea {
                    anchors.fill:       parent
                    anchors.margins:    -ScreenTools.defaultFontPixelHeight
                    onClicked: {
                        object.geoAwarenessCloseItstyle()
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

    //-----------------------------------------------------------
    // Life Jacket panel (left-anchored, beside the toolStrip)
    Rectangle {
        id:                  lifeVestPanel
        anchors.left:        parent.left
        anchors.leftMargin:  ScreenTools.defaultFontPixelWidth * 10 + _toolsMargin
        anchors.top:         parent.top
        anchors.topMargin:   _toolsMargin + ScreenTools.defaultFontPixelHeight * 3
        width:               _rightPanelWidth
        height:              lifeVestColumn.implicitHeight
        color:               "transparent"
        // Hide on PX4 vehicles regardless of the setting value
        visible:             mainWindow.lifeVestPanelVisible && QGroundControl.corePlugin.settings.lifeJacketEnable.value &&
                             !(QGroundControl.multiVehicleManager.activeVehicle && QGroundControl.multiVehicleManager.activeVehicle.px4Firmware)
        z:                   QGroundControl.zOrderWidgets + 1

        onVisibleChanged: {
            if (visible && _missionController) {
                _missionController.getSearchlight()
            }
        }

        // Catch clicks on empty / black areas of the panel so they don't fall
        // through to the map below (which would trigger "Set Home" etc.)
        MouseArea {
            anchors.fill:    parent
            propagateComposedEvents: false
            preventStealing: true
            onClicked:       (mouse) => mouse.accepted = true
            onPressed:       (mouse) => mouse.accepted = true
        }

        Column {
            id:    lifeVestColumn
            width: parent.width

            // Title bar
            Row {
                width:  parent.width
                height: ScreenTools.defaultFontPixelHeight * 2

                Rectangle {
                    width:  parent.width * 0.7
                    height: parent.height
                    color:  "#00826F"

                    QGCLabel {
                        anchors.centerIn: parent
                        text:             qsTranslate("FlyViewOverlay", "Life Jacket")
                        color:            "white"
                    }
                }

                Rectangle {
                    width:  parent.width * 0.3
                    height: parent.height
                    color:  "#485058"

                    QGCLabel {
                        anchors.centerIn: parent
                        text:             qsTranslate("FlyViewOverlay", "Close")
                        color:            "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked:    mainWindow.lifeVestPanelVisible = false
                    }
                }
            }

            // Body
            Rectangle {
                id:     lifeVestRoot
                width:  parent.width
                height: lifeVestContent.implicitHeight + ScreenTools.defaultFontPixelHeight * 2
                color:  "#1a1a2e"

                property bool searchlightOn: false

                Connections {
                    target: _missionController
                    onSlStatusChanged: {
                        if (_missionController) {
                            lifeVestRoot.searchlightOn = _missionController.slStatus === 1
                        }
                    }
                }

                ColumnLayout {
                    id: lifeVestContent
                    anchors {
                        left:    parent.left
                        right:   parent.right
                        top:     parent.top
                        margins: ScreenTools.defaultFontPixelHeight * 0.6
                    }
                    spacing: ScreenTools.defaultFontPixelHeight * 0.6

                    Image {
                        source:                 "/qmlimages/LifeVest.svg"
                        fillMode:               Image.PreserveAspectFit
                        Layout.alignment:       Qt.AlignHCenter
                        Layout.preferredWidth:  72
                        Layout.preferredHeight: 84
                        sourceSize.width:       width
                        sourceSize.height:      height
                        smooth:                 true
                    }

                    // Drop Life Jacket button
                    Rectangle {
                        Layout.alignment:       Qt.AlignHCenter
                        Layout.preferredWidth:  lifeVestRoot.width * 0.75
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2
                        radius:                 4
                        color:                  dropMouseArea.pressed ? "#005f52" : "#00826F"

                        Text {
                            anchors.centerIn: parent
                            text:             qsTranslate("FlyViewOverlay", "Drop Life Jacket")
                            color:            "white"
                            font.pixelSize:   ScreenTools.defaultFontPointSize * 1.3
                            font.bold:        true
                        }

                        MouseArea {
                            id:           dropMouseArea
                            anchors.fill: parent
                            onClicked: {
                                console.log("Drop Life Jacket clicked")
                                if (_missionController) {
                                    _missionController.deployLifeVest()
                                }
                            }
                        }
                    }

                    // Searchlight label
                    Text {
                        text:              qsTranslate("FlyViewOverlay", "Searchlight")
                        color:             "white"
                        font.pixelSize:    ScreenTools.defaultFontPointSize * 1.4
                        font.bold:         true
                        Layout.alignment:  Qt.AlignHCenter
                        Layout.topMargin:  ScreenTools.defaultFontPixelHeight * 0.3
                    }

                    // ON / OFF toggle
                    Rectangle {
                        Layout.alignment:       Qt.AlignHCenter
                        Layout.preferredWidth:  lifeVestRoot.width * 0.5
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.6
                        radius:                 3
                        color:                  "#3a3f47"
                        border.color:           "#1a1a2e"
                        border.width:           1

                        Row {
                            anchors.fill: parent
                            Rectangle {
                                width:  parent.width / 2
                                height: parent.height
                                color:  lifeVestRoot.searchlightOn ? "#3a3f47" : "#9aa1a8"
                                Text {
                                    anchors.centerIn: parent
                                    text:             qsTr("OFF")
                                    color:            "white"
                                    font.pixelSize:   ScreenTools.defaultFontPointSize * 1.1
                                    font.bold:        true
                                }
                            }
                            Rectangle {
                                width:  parent.width / 2
                                height: parent.height
                                color:  lifeVestRoot.searchlightOn ? "#00826F" : "#3a3f47"
                                Text {
                                    anchors.centerIn: parent
                                    text:             qsTr("ON")
                                    color:            "white"
                                    font.pixelSize:   ScreenTools.defaultFontPointSize * 1.1
                                    font.bold:        true
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                lifeVestRoot.searchlightOn = !lifeVestRoot.searchlightOn
                                console.log("Searchlight:", lifeVestRoot.searchlightOn ? "ON" : "OFF")
                                if (_missionController) {
                                    _missionController.setSearchlight(lifeVestRoot.searchlightOn ? 1 : 0)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
