/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
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

import Custom.Widgets                       1.0
import CustomQuickInterface                 1.0

//-------------------------------------------------------------------------
//-- GPS Indicator
Item {
    id:             _root
    width:          gpsRow.width         //(gpsValuesColumn.x + gpsValuesColumn.width) * 1.1
    anchors.top:    parent.top
    anchors.bottom: parent.bottom

    property bool showIndicator: true

    property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    function getGPSSignal() {
        if(!_activeVehicle || _activeVehicle.gps.count.rawValue < 1 || _activeVehicle.gps.hdop.rawValue > 1.4) {
            return 0;
        } else if(_activeVehicle.gps.hdop.rawValue < 1.0) {
            return 100;
        } else if(_activeVehicle.gps.hdop.rawValue < 1.1) {
            return 75;
        } else if(_activeVehicle.gps.hdop.rawValue < 1.2) {
            return 50;
        } else {
            return 25;
        }
    }


    Component {
        id: gpsInfo

        Rectangle {
            // Figma "GPS Status card" (frame 09): 21.6 x 34.2 design px padding, radius 17.1
            width:  gpsCol.width   + (ScreenTools.figmaPx * 21.6 * 2)
            height: gpsCol.height  + (ScreenTools.figmaPx * 34.2 * 2)
            radius: ScreenTools.figmaPx * 17.1
            color:  qgcPal.window
            border.color:   qgcPal.text

            // Figma toolbar popup cards: 25.2 px text on 34.2 px lines (the standard popup drawn at 0.9)
            property real _popupFontPointSize:  ScreenTools.figmaFontPointSize(25.2)
            property real _popupLineHeight:     ScreenTools.figmaPx * 34.2

            Column {
                id:                 gpsCol
                spacing:            ScreenTools.figmaPx * 17.1
                width:              Math.max(gpsGrid.width, gpsLabel.width)
                anchors.margins:    ScreenTools.defaultFontPixelHeight
                anchors.centerIn:   parent

                QGCLabel {
                    id:             gpsLabel
                    text:           (_activeVehicle && _activeVehicle.gps.count.value >= 0) ? qsTr("GPS Status") : qsTr("GPS Data Unavailable")
                    font.family:    ScreenTools.demiboldFontFamily
                    font.pointSize: _popupFontPointSize
                    lineHeightMode: Text.FixedHeight
                    lineHeight:     _popupLineHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                GridLayout {
                    id:                 gpsGrid
                    visible:            (_activeVehicle && _activeVehicle.gps.count.value >= 0)
                    anchors.margins:    ScreenTools.defaultFontPixelHeight
                    columnSpacing:      ScreenTools.figmaPx * 14.4
                    rowSpacing:         ScreenTools.figmaPx * 4.5
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 2

                    QGCLabel { font.pointSize: _popupFontPointSize; lineHeightMode: Text.FixedHeight; lineHeight: _popupLineHeight; text: qsTr("GPS Count:") }
                    QGCLabel { font.pointSize: _popupFontPointSize; lineHeightMode: Text.FixedHeight; lineHeight: _popupLineHeight; text: _activeVehicle ? _activeVehicle.gps.count.valueString : qsTr("N/A", "No data to display") }
                    QGCLabel { font.pointSize: _popupFontPointSize; lineHeightMode: Text.FixedHeight; lineHeight: _popupLineHeight; text: qsTr("GPS Lock:") }
                    QGCLabel { font.pointSize: _popupFontPointSize; lineHeightMode: Text.FixedHeight; lineHeight: _popupLineHeight; text: _activeVehicle ? _activeVehicle.gps.lock.enumStringValue : qsTr("N/A", "No data to display") }
                    QGCLabel { font.pointSize: _popupFontPointSize; lineHeightMode: Text.FixedHeight; lineHeight: _popupLineHeight; text: qsTr("HDOP:") }
                    QGCLabel { font.pointSize: _popupFontPointSize; lineHeightMode: Text.FixedHeight; lineHeight: _popupLineHeight; text: _activeVehicle ? _activeVehicle.gps.hdop.valueString : qsTr("--.--", "No data to display") }
                    QGCLabel { font.pointSize: _popupFontPointSize; lineHeightMode: Text.FixedHeight; lineHeight: _popupLineHeight; text: qsTr("VDOP:") }
                    QGCLabel { font.pointSize: _popupFontPointSize; lineHeightMode: Text.FixedHeight; lineHeight: _popupLineHeight; text: _activeVehicle ? _activeVehicle.gps.vdop.valueString : qsTr("--.--", "No data to display") }
                    QGCLabel { font.pointSize: _popupFontPointSize; lineHeightMode: Text.FixedHeight; lineHeight: _popupLineHeight; text: qsTr("Course Over Ground:") }
                    QGCLabel { font.pointSize: _popupFontPointSize; lineHeightMode: Text.FixedHeight; lineHeight: _popupLineHeight; text: _activeVehicle ? _activeVehicle.gps.courseOverGround.valueString : qsTr("--.--", "No data to display") }
                }
            }
        }
    }

    // QGCColoredImage {
    //     id:                 gpsIcon
    //     width:              height
    //     anchors.top:        parent.top
    //     anchors.bottom:     parent.bottom
    //     source:             "/qmlimages/Gps.svg"
    //     fillMode:           Image.PreserveAspectFit
    //     sourceSize.height:  height
    //     opacity:            (_activeVehicle && _activeVehicle.gps.count.value >= 0) ? 1 : 0.5
    //     color:              qgcPal.buttonText
    // }

    // Column {
    //     id:                     gpsValuesColumn
    //     anchors.verticalCenter: parent.verticalCenter
    //     anchors.leftMargin:     ScreenTools.defaultFontPixelWidth / 2
    //     anchors.left:           gpsIcon.right

    //     QGCLabel {
    //         anchors.horizontalCenter:   hdopValue.horizontalCenter
    //         visible:                    _activeVehicle && !isNaN(_activeVehicle.gps.hdop.value)
    //         color:                      qgcPal.buttonText
    //         text:                       _activeVehicle ? _activeVehicle.gps.count.valueString : ""
    //     }

    //     QGCLabel {
    //         id:         hdopValue
    //         visible:    _activeVehicle && !isNaN(_activeVehicle.gps.hdop.value)
    //         color:      qgcPal.buttonText
    //         text:       _activeVehicle ? _activeVehicle.gps.hdop.value.toFixed(1) : ""
    //     }
    // }

    Row {
        id:             gpsRow
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        spacing:        ScreenTools.defaultFontPixelWidth * 0.25
        QGCColoredImage {
            width:              height
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            sourceSize.height:  height
            source: {
                switch (_activeVehicle.gps.lock.rawValue) {
                case 0:
                case 1:
                    "qrc:/custom/img/toolBar_GPSUnuse.svg"
                    break;
                case 2:
                    "qrc:/custom/img/toolBar_GPSCount0.svg"
                    break;
                case 3:
                case 4:
                case 5:
                    "qrc:/custom/img/toolBar_GPSFactor0.svg"
                    break;
                case 6:
                case 7:
                    "qrc:/custom/img/toolBar_GPSType0.svg"
                    break;
                default:
                    "qrc:/custom/img/toolBar_GPSUnuse.svg"
                }
            }
            color: {
                switch (_activeVehicle.gps.lock.rawValue) {
                case 0:
                case 1:
                    qgcPal.colorRed
                    break;
                case 2:
                    qgcPal.colorOrange
                    break;
                case 3:
                case 4:
                case 5:
                    qgcPal.text
                    break;
                case 6:
                case 7:
                    qgcPal.colorGreen
                    break;
                default:
                    qgcPal.text
                }
            }
            fillMode:           Image.PreserveAspectFit
            opacity:            getGPSSignal() > 0 ? 1 : 0.5
            QGCColoredImage {
                height:             parent.height / 2
                width:              height
                anchors.top:        parent.top
                anchors.topMargin:  -8
                anchors.left:       parent.right
                anchors.leftMargin: -width / 2
                sourceSize.height:  height
                fillMode:           Image.PreserveAspectFit
                opacity:            1
                color:              qgcPal.colorGreen
                source:             "qrc:/qmlimages/ArrowDirection.svg"
                visible:            true// QGroundControl.corePlugin.codevRTCMManager.rtcmSource ? QGroundControl.corePlugin.codevRTCMManager.rtcmSource.streaming : false
            }
        }

        CustomSignalStrength {
            anchors.verticalCenter: parent.verticalCenter
            size:                   parent.height * 0.5
            percent:                getGPSSignal()
        }
    }

    MouseArea {
        anchors.fill:   parent
        onClicked: {
            mainWindow.showIndicatorPopup(_root, gpsInfo)
        }
    }
}
