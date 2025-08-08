import QtGraphicalEffects       1.0
import QtMultimedia             5.5
import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Controls.Styles  1.4
import QtQuick.Dialogs          1.2
import QtQuick.Layouts          1.2
import QtLocation               5.3
import QtPositioning            5.3

import QGroundControl                       1.0
import QGroundControl.Controllers           1.0
import QGroundControl.Controls              1.0
import QGroundControl.FactControls          1.0
import QGroundControl.FactSystem            1.0
import QGroundControl.Palette               1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.SettingsManager       1.0

import CustomQmlInterface                   1.0

Rectangle {
    id:                 _root
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    property real _labelWidth:                  ScreenTools.defaultFontPixelWidth * 26
    property real _valueWidth:                  ScreenTools.defaultFontPixelWidth * 20
    property real _panelWidth:                  _root.width * _internalWidthRatio
    property var  _rtcmSource:                  CustomQmlInterface.codevRTCMManager.rtcmSource

    readonly property real _internalWidthRatio:          0.8

    QGCFlickable {
        clip:               true
        anchors.fill:       parent
        contentHeight:      settingsColumn.height
        contentWidth:       settingsColumn.width
        Column {
            id:                 settingsColumn
            width:              _root.width
            spacing:            ScreenTools.defaultFontPixelHeight * 0.5
            anchors.margins:    ScreenTools.defaultFontPixelWidth
            //-----------------------------------------------------------------
            //-- General
            Item {
                width:                      _panelWidth
                height:                     generalLabel.height
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                QGCLabel {
                    id:             generalLabel
                    text:           qsTr("General")
                    font.family:    ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:                     generalRow.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:                      _panelWidth
                color:                      qgcPal.windowShade
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                Column {
                    id:                 generalRow
                    spacing:            ScreenTools.defaultFontPixelWidth * 4
                    anchors.centerIn:   parent
                    GridLayout {
                        anchors.margins:    ScreenTools.defaultFontPixelHeight
                        columnSpacing:      ScreenTools.defaultFontPixelWidth * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        columns: 2
                        QGCLabel {
                            text:           qsTr("RTCM Source:")
                            Layout.minimumWidth: _labelWidth
                        }
                        FactComboBox {
                            fact:           QGroundControl.corePlugin.codevSettings.rtcmSource
                            indexModel:     true
                            enabled:        true
                            Layout.minimumWidth: _valueWidth
                        }
                        QGCLabel {
                            text:           qsTr("RTCM Max Hz:")
                            visible:        _rtcmSource
                        }
                        FactComboBox {
                            fact:           _rtcmSource ? _rtcmSource.sendMaxRTCMHz : null
                            indexModel:     false
                            visible:        _rtcmSource
                            enabled:        _rtcmSource
                            Layout.minimumWidth: _valueWidth
                        }
                    }
                }
            }
            //-----------------------------------------------------------------
            //-- RTCM Source Loader
            Item {
                width:                      _panelWidth
                height:                     statusLabel.height
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                visible:                    _rtcmSource
                QGCLabel {
                    id:                     statusLabel
                    text:                   QGroundControl.corePlugin.codevSettings.rtcmSource.enumOrValueString + qsTr(" RTCM Source")
                    font.family:            ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:                     sourceLoader.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:                      _panelWidth
                color:                      qgcPal.windowShade
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                visible:                    _rtcmSource
                Loader {
                    id: sourceLoader
                    anchors.centerIn: parent
                    source: _rtcmSource ? _rtcmSource.url : ""
                }
            }
        }
    }
}
