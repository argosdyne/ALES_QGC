/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.11
import QtQuick.Controls 2.4
import QtQuick.Layouts  1.11

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0

Rectangle {
    id:                 root
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    QGCPalette { id: qgcPal }

    property bool lidarPowered:   false
    property bool acquisitionOn:  false
    property bool statusOk:       true

    ColumnLayout {
        anchors.fill:   parent
        spacing:        ScreenTools.defaultFontPixelHeight * 0.8

        RowLayout {
            Layout.fillWidth:   true
            spacing:            ScreenTools.defaultFontPixelWidth * 2

            Rectangle {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 40
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 16
                radius:                 ScreenTools.defaultFontPixelHeight * 0.5
                color:                  qgcPal.windowShade
                border.color:           qgcPal.text

                Column {
                    anchors.centerIn: parent
                    spacing: ScreenTools.defaultFontPixelHeight * 0.6

                    QGCLabel {
                        text: qsTr("YellowScan 3D LiDAR")
                        font.pointSize: ScreenTools.defaultFontPointSize + 2
                    }

                    Row {
                        spacing: ScreenTools.defaultFontPixelWidth * 2

                        Column {
                            spacing: ScreenTools.defaultFontPixelHeight * 0.6
                            QGCButton {
                                text: lidarPowered ? qsTr("PWR ON") : qsTr("PWR OFF")
                                onClicked: lidarPowered = !lidarPowered
                            }
                            QGCButton {
                                text: acquisitionOn ? qsTr("Acquisition ON") : qsTr("Acquisition OFF")
                                onClicked: acquisitionOn = !acquisitionOn
                            }
                        }

                        Column {
                            spacing: ScreenTools.defaultFontPixelHeight * 0.6
                            Rectangle {
                                width:  ScreenTools.defaultFontPixelHeight * 2
                                height: width
                                radius: width * 0.5
                                color:  statusOk ? qgcPal.colorGreen : qgcPal.colorRed
                                Text {
                                    anchors.centerIn: parent
                                    text: "!"
                                    color: "white"
                                    font.bold: true
                                }
                            }
                            QGCButton {
                                text: qsTr("Get Status")
                                onClicked: statusOk = !statusOk
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth:   true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 16
                radius:             ScreenTools.defaultFontPixelHeight * 0.4
                color:              qgcPal.windowShade
                border.color:       qgcPal.text

                Column {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelWidth
                    spacing: ScreenTools.defaultFontPixelHeight * 0.4

                    Row {
                        spacing: ScreenTools.defaultFontPixelWidth
                        QGCLabel { text: qsTr("Details") }
                    }

                    Repeater {
                        model: [
                            { label: "Acquisition Running", ok: true },
                            { label: "Time Not Set", ok: true },
                            { label: "Scanner Not Ready", ok: true },
                            { label: "INS Not Locked", ok: true },
                            { label: "Scanner Error", ok: false },
                            { label: "INS Error", ok: true },
                            { label: "No USB", ok: true },
                            { label: "USB Full", ok: true },
                            { label: "Camera Error", ok: true }
                        ]
                        delegate: Row {
                            spacing: ScreenTools.defaultFontPixelWidth
                            Rectangle {
                                width:  ScreenTools.defaultFontPixelHeight * 0.6
                                height: width
                                radius: width * 0.5
                                color:  modelData.ok ? qgcPal.colorGreen : qgcPal.colorRed
                            }
                            QGCLabel { text: modelData.label }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth:   true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 10
            radius:             ScreenTools.defaultFontPixelHeight * 0.4
            color:              qgcPal.windowShade
            border.color:       qgcPal.text

            Column {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth
                spacing: ScreenTools.defaultFontPixelHeight * 0.4

                QGCLabel { text: qsTr("Parameters") }

                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth * 6

                    ColumnLayout {
                        spacing: ScreenTools.defaultFontPixelHeight * 0.4

                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 2
                            QGCLabel { text: qsTr("Scanner High Sensitivity") }
                            QGCComboBox { model: [qsTr("On"), qsTr("Off")] }
                        }
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 2
                            QGCLabel { text: qsTr("Scanner Pattern") }
                            QGCComboBox { model: [qsTr("None"), qsTr("Repetition")] }
                        }
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 2
                            QGCLabel { text: qsTr("Emb. Camera") }
                            QGCComboBox { model: [qsTr("Disable"), qsTr("Enable")] }
                        }
                    }

                    ColumnLayout {
                        spacing: ScreenTools.defaultFontPixelHeight * 0.4

                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 2
                            QGCLabel { text: qsTr("Emb. Cam. Init. Height") }
                            QGCTextField { placeholderText: qsTr("Integer") }
                        }
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 2
                            QGCLabel { text: qsTr("Emb. Cam. Trigger Mode") }
                            QGCComboBox { model: [qsTr("Time"), qsTr("Distance")] }
                        }
                    }
                }
            }
        }
    }
}
