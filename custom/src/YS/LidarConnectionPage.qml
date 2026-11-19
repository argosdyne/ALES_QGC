/****************************************************************************
 *
 * LiDAR Setup > Connection (YS-01, UI Y-06)
 * All values are QGC SettingsGroup facts (Custom group) - they apply
 * immediately and persist across restarts, so there is no Save button.
 *
 ****************************************************************************/

import QtQuick          2.11
import QtQuick.Controls 1.2
import QtQuick.Layouts  1.11

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0

Rectangle {
    id:     root
    color:  qgcPal.window

    property var  _settings:        QGroundControl.corePlugin.settings
    property var  _ys:              QGroundControl.corePlugin.ysManager
    property bool _enabled:         _settings.ysEnable.rawValue
    property real _cardMargin:      ScreenTools.defaultFontPixelWidth
    property real _rowSpacing:      ScreenTools.defaultFontPixelHeight * 0.5
    property real _colSpacing:      ScreenTools.defaultFontPixelWidth * 2
    property real _fieldMinWidth:   ScreenTools.defaultFontPixelWidth * 16
    // Connection and GCS behavior side by side (Y-06); stack only on narrow screens
    property bool _sideBySide:      root.width >= ScreenTools.defaultFontPixelWidth * 90

    // YSManager.TestState
    readonly property int _testIdle:    0
    readonly property int _testRunning: 1
    readonly property int _testOk:      2
    readonly property int _testFailed:  3

    QGCPalette { id: qgcPal }

    QGCFlickable {
        anchors.fill:       parent
        contentWidth:       width
        contentHeight:      mainLayout.height
        clip:               true

        GridLayout {
            id:             mainLayout
            width:          parent.width
            columns:        _sideBySide ? 2 : 1
            columnSpacing:  _colSpacing
            rowSpacing:     _colSpacing

            //-----------------------------------------------------------------
            //-- Connection
            ColumnLayout {
                Layout.fillWidth:       true
                Layout.preferredWidth:  1   // equal split with GCS behavior
                Layout.alignment:       Qt.AlignTop
                spacing:                ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    text:           qsTr("Connection")
                    font.family:    ScreenTools.demiboldFontFamily
                }

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: connectionCol.height + (_cardMargin * 2)
                    color:                  qgcPal.windowShade

                    ColumnLayout {
                        id:                 connectionCol
                        anchors.margins:    _cardMargin
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        anchors.top:        parent.top
                        spacing:            _rowSpacing

                        FactCheckBox {
                            text:   qsTr("Enable YellowScan LiDAR")
                            fact:   _settings.ysEnable
                        }

                        FactCheckBox {
                            text:       qsTr("Open LiDAR panel on connect")
                            fact:       _settings.ysOpenPanelOnConnect
                            enabled:    _enabled
                        }

                        GridLayout {
                            Layout.fillWidth:   true
                            columns:            2
                            rowSpacing:         _rowSpacing
                            columnSpacing:      _colSpacing
                            enabled:            _enabled

                            QGCLabel { text: qsTr("Model") }
                            FactComboBox {
                                fact:                   _settings.ysModel
                                indexModel:             false
                                Layout.fillWidth:       true
                                Layout.minimumWidth:    _fieldMinWidth
                            }

                            QGCLabel { text: qsTr("Link") }
                            FactComboBox {
                                fact:                   _settings.ysLink
                                indexModel:             false
                                Layout.fillWidth:       true
                                Layout.minimumWidth:    _fieldMinWidth
                            }

                            QGCLabel { text: qsTr("MAVLink component") }
                            FactTextField {
                                fact:                   _settings.ysMavCompId
                                Layout.fillWidth:       true
                                Layout.minimumWidth:    _fieldMinWidth
                            }

                            QGCLabel { text: qsTr("Camera") }
                            FactComboBox {
                                fact:                   _settings.ysCamera
                                indexModel:             false
                                Layout.fillWidth:       true
                                Layout.minimumWidth:    _fieldMinWidth
                            }
                        }

                        //-- [Test]: one Get Status -> result chip
                        RowLayout {
                            Layout.fillWidth:   true
                            spacing:            ScreenTools.defaultFontPixelWidth

                            QGCButton {
                                text:       qsTr("Test")
                                primary:    true
                                enabled:    _enabled && _ys && _ys.testState !== _testRunning
                                onClicked:  _ys.testConnection()
                            }

                            Rectangle {
                                visible:        _ys && _ys.testState !== _testIdle
                                width:          chipLabel.width + ScreenTools.defaultFontPixelWidth * 2
                                height:         chipLabel.height + ScreenTools.defaultFontPixelHeight * 0.4
                                radius:         height / 2
                                color:          !_ys ? qgcPal.windowShadeDark
                                                     : (_ys.testState === _testOk ? qgcPal.colorGreen
                                                                                  : (_ys.testState === _testFailed ? qgcPal.colorRed : qgcPal.colorOrange))

                                QGCLabel {
                                    id:                 chipLabel
                                    anchors.centerIn:   parent
                                    font.family:        ScreenTools.demiboldFontFamily
                                    color:              "white"
                                    text:               !_ys ? "" : (_ys.testState === _testOk ? qsTr("OK")
                                                                                               : (_ys.testState === _testFailed ? qsTr("FAIL") : qsTr("...")))
                                }
                            }

                            QGCLabel {
                                visible:            _ys && _ys.testState !== _testIdle
                                text:               _ys ? _ys.testMessage : ""
                                Layout.fillWidth:   true
                                wrapMode:           Text.WordWrap
                            }
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            font.pointSize:     ScreenTools.smallFontPointSize
                            opacity:            0.6
                            text:               qsTr("LiDAR is on the drone: QGC → MAVLink → Companion Board → UART 115200 → YellowScan. " +
                                                     "The serial protocol has no model / firmware query, so the model is chosen here; unsupported settings are disabled.")
                        }
                    }
                }
            }

            //-----------------------------------------------------------------
            //-- GCS behavior
            ColumnLayout {
                Layout.fillWidth:       true
                Layout.preferredWidth:  1
                Layout.alignment:       Qt.AlignTop
                spacing:                ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    text:           qsTr("GCS behavior")
                    font.family:    ScreenTools.demiboldFontFamily
                }

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredHeight: behaviorCol.height + (_cardMargin * 2)
                    color:                  qgcPal.windowShade

                    ColumnLayout {
                        id:                 behaviorCol
                        anchors.margins:    _cardMargin
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        anchors.top:        parent.top
                        spacing:            _rowSpacing
                        enabled:            _enabled

                        GridLayout {
                            Layout.fillWidth:   true
                            columns:            2
                            rowSpacing:         _rowSpacing
                            columnSpacing:      _colSpacing

                            QGCLabel { text: qsTr("Status poll") }
                            FixedValueLabel { value: qsTr("1 Hz") }

                            QGCLabel { text: qsTr("No reply / Lost") }
                            FixedValueLabel { value: qsTr("2 s / 5 s") }

                            QGCLabel { text: qsTr("Mission start / stop") }
                            FactComboBox {
                                fact:                   _settings.ysMissionStartStop
                                indexModel:             false
                                Layout.fillWidth:       true
                                Layout.minimumWidth:    _fieldMinWidth
                            }

                            QGCLabel {
                                Layout.columnSpan:  2
                                Layout.fillWidth:   true
                                wrapMode:           Text.WordWrap
                                font.pointSize:     ScreenTools.smallFontPointSize
                                opacity:            0.6
                                text:               qsTr("Options: Manual only · Auto (start at first survey WP, stop at last)")
                            }

                            QGCLabel { text: qsTr("Stop in flight") }
                            FixedValueLabel { value: qsTr("Slide to confirm") }
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            font.pointSize:     ScreenTools.smallFontPointSize
                            opacity:            0.6
                            text:               qsTr("Values apply immediately and are kept after restart (QGC SettingsGroup, no Save button).")
                        }
                    }
                }
            }
        }
    }

    // "<value>  fixed" read-only row value
    component FixedValueLabel: Row {
        property alias value: valueLabel.text
        spacing: ScreenTools.defaultFontPixelWidth

        QGCLabel {
            id:             valueLabel
            font.family:    ScreenTools.demiboldFontFamily
        }
        QGCLabel {
            text:                   qsTr("fixed")
            font.pointSize:         ScreenTools.smallFontPointSize
            opacity:                0.6
            anchors.baseline:       valueLabel.baseline
        }
    }
}
