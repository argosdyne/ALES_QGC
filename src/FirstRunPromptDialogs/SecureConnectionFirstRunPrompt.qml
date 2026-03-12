/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.12
import QtQuick.Layouts  1.12

import QGroundControl           1.0
import QGroundControl.Controls  1.0
import QGroundControl.ScreenTools 1.0

FirstRunPrompt {
    title:      qsTr("Secure Setup")
    promptId:   QGroundControl.corePlugin.secureConnectionFirstRunPromptId
    buttons:    StandardButton.NoButton
    readonly property real _labelColumnWidth: ScreenTools.defaultFontPixelWidth * 23
    readonly property real _videoLabelColumnWidth: ScreenTools.defaultFontPixelWidth * 28
    readonly property real _portFieldWidth: ScreenTools.defaultFontPixelWidth * 7
    readonly property real _bindFieldWidth: ScreenTools.defaultFontPixelWidth * 11

    ColumnLayout {
        width:      ScreenTools.defaultFontPixelWidth * 56
        spacing:    ScreenTools.defaultFontPixelHeight * 0.6

        QGCFlickable {
            Layout.fillWidth:       true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 22
            clip:                   true
            contentHeight:          formColumn.height
            contentWidth:           formColumn.width

            ColumnLayout {
                id:         formColumn
                width:      parent.width
                spacing:    ScreenTools.defaultFontPixelHeight * 0.55

                QGCLabel {
                    text:               qsTr("Configure Connections (Secure by Default)")
                    font.family:        ScreenTools.demiboldFontFamily
                    font.pointSize:     ScreenTools.largeFontPointSize
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                }

                QGCLabel {
                    text:               qsTr("No network services are enabled by default. Enable only what you need.")
                    color:              qgcPal.colorGrey
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                }

                Rectangle {
                    Layout.fillWidth: true
                    color: "#2f3946"
                    radius: 3
                    height: udpColumn.implicitHeight + ScreenTools.defaultFontPixelWidth * 1.2

                    ColumnLayout {
                        id: udpColumn
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelWidth * 0.6
                        spacing: ScreenTools.defaultFontPixelHeight * 0.25

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth * 0.6
                            QGCCheckBox {
                                text: qsTr("MAVLink UDP Listener")
                                checked: true
                                Layout.preferredWidth: _labelColumnWidth
                            }
                            QGCLabel { text: qsTr("Port:") }
                            QGCTextField { text: "14550"; Layout.preferredWidth: _portFieldWidth }
                            QGCLabel { text: qsTr("Bind:") }
                            QGCComboBox {
                                model: [ "127.0.0.1", "0.0.0.0" ]
                                currentIndex: 0
                                Layout.preferredWidth: _bindFieldWidth
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    color: "#344151"
                    radius: 3
                    height: tcpColumn.implicitHeight + ScreenTools.defaultFontPixelWidth * 1.2

                    ColumnLayout {
                        id: tcpColumn
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelWidth * 0.6
                        spacing: ScreenTools.defaultFontPixelHeight * 0.25

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth * 0.6
                            QGCCheckBox {
                                text: qsTr("MAVLink TCP Server")
                                checked: true
                                Layout.preferredWidth: _labelColumnWidth
                            }
                            QGCLabel { text: qsTr("Port:") }
                            QGCTextField { text: "5760"; Layout.preferredWidth: _portFieldWidth }
                            QGCLabel { text: qsTr("Bind:") }
                            QGCComboBox {
                                model: [ "127.0.0.1", "0.0.0.0" ]
                                currentIndex: 0
                                Layout.preferredWidth: _bindFieldWidth
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    color: "#2b3542"
                    radius: 3
                    height: videoColumn.implicitHeight + ScreenTools.defaultFontPixelWidth * 1.2

                    ColumnLayout {
                        id: videoColumn
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelWidth * 0.6
                        spacing: ScreenTools.defaultFontPixelHeight * 0.25

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth * 0.6
                            QGCCheckBox {
                                text: qsTr("Video Streaming (GStreamer)")
                                checked: true
                                Layout.preferredWidth: _videoLabelColumnWidth
                            }
                            QGCLabel { text: qsTr("URI:") }
                            QGCTextField {
                                text: "udp://@:5600"
                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 18
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    color: "#313c4a"
                    radius: 3
                    height: securityColumn.implicitHeight + ScreenTools.defaultFontPixelWidth * 1.2

                    ColumnLayout {
                        id: securityColumn
                        anchors.fill: parent
                        anchors.margins: ScreenTools.defaultFontPixelWidth * 0.6
                        spacing: ScreenTools.defaultFontPixelHeight * 0.2

                        QGCLabel {
                            text: qsTr("Security (recommended)")
                            font.family: ScreenTools.demiboldFontFamily
                        }
                        QGCCheckBox { text: qsTr("Strict MAVLink validation"); checked: true }
                        QGCCheckBox { text: qsTr("Allowlist Vehicle IDs (SYSID/COMPID)"); checked: false }
                    }
                }

                QGCLabel {
                    text:               qsTr("Learn more: Network services & ports")
                    color:              qgcPal.colorBlue
                    Layout.fillWidth:   true
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            QGCButton {
                text: qsTr("Continue offline")
                onClicked: close()
            }
            Item { Layout.fillWidth: true }
            QGCButton {
                text: qsTr("Start (Enable Selected Services)")
                primary: true
                onClicked: close()
            }
        }
    }
}
