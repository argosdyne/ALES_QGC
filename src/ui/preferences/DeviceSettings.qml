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

    property var _ys:             QGroundControl.corePlugin.ysManager

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
                                text: qsTr("PWR OFF")
                                onClicked: if (_ys) { _ys.powerOff() }
                            }
                            QGCButton {
                                text: _ys && _ys.acquisitionRunning ? qsTr("Acquisition OFF") : qsTr("Acquisition ON")
                                onClicked: {
                                    if (_ys) {
                                        if (_ys.acquisitionRunning) {
                                            _ys.stopAcquisition()
                                        } else {
                                            _ys.startAcquisition()
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            spacing: ScreenTools.defaultFontPixelHeight * 0.6
                            Rectangle {
                                width:  ScreenTools.defaultFontPixelHeight * 2
                                height: width
                                radius: width * 0.5
                                color:  _ys && _ys.statusValid ? (_ys.anyError ? qgcPal.colorRed : qgcPal.colorGreen) : qgcPal.button
                                opacity: _ys && _ys.statusValid ? 1.0 : 0.4
                                Text {
                                    anchors.centerIn: parent
                                    text: "!"
                                    color: "white"
                                    font.bold: true
                                }
                            }
                            QGCButton {
                                text: qsTr("Get Status")
                                enabled: _ys ? true : false
                                onClicked: if (_ys) { _ys.requestStatus() }
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
                            { label: "Acquisition Running", ok: _ys && _ys.acquisitionRunning },
                            { label: "Time Not Set", ok: _ys ? !_ys.timeNotSet : true },
                            { label: "Scanner Not Ready", ok: _ys ? !_ys.scannerNotReady : true },
                            { label: "INS Not Locked", ok: _ys ? !_ys.insNotLocked : true },
                            { label: "Scanner Error", ok: _ys ? _ys.scnErr === 0 : true },
                            { label: "INS Error", ok: _ys ? _ys.insErr === 0 : true },
                            { label: "No USB", ok: _ys ? !_ys.noUsb : true },
                            { label: "USB Full", ok: _ys ? !_ys.usbFull : true },
                            { label: "Camera Error", ok: _ys ? _ys.camErr === 0 : true }
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
                            QGCComboBox {
                                model: [qsTr("On"), qsTr("Off")]
                                currentIndex: _ys ? (_ys.scannerHighSensitivity ? 0 : 1) : 0
                                onActivated: if (_ys) { _ys.setParameter(0, currentIndex === 0 ? 1 : 0) }
                            }
                        }
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 2
                            QGCLabel { text: qsTr("Scanner Pattern") }
                            QGCComboBox {
                                model: [qsTr("None"), qsTr("Repetition")]
                                currentIndex: _ys ? _ys.scannerPattern : 0
                                onActivated: if (_ys) { _ys.setParameter(1, currentIndex) }
                            }
                        }
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 2
                            QGCLabel { text: qsTr("Emb. Camera") }
                            QGCComboBox {
                                model: [qsTr("Disable"), qsTr("Enable")]
                                currentIndex: _ys ? _ys.embeddedCamera : 0
                                onActivated: if (_ys) { _ys.setParameter(2, currentIndex) }
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: ScreenTools.defaultFontPixelHeight * 0.4

                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 2
                            QGCLabel { text: qsTr("Emb. Cam. Init. Height") }
                            QGCTextField {
                                placeholderText: qsTr("Integer")
                                text: _ys ? _ys.embCamInitHeight.toString() : ""
                                onEditingFinished: {
                                    if (_ys) {
                                        var v = parseInt(text)
                                        if (!isNaN(v)) {
                                            _ys.setParameter(3, v)
                                        }
                                    }
                                }
                            }
                        }
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 2
                            QGCLabel { text: qsTr("Emb. Cam. Trigger Mode") }
                            QGCComboBox {
                                model: [qsTr("Time"), qsTr("Distance")]
                                currentIndex: _ys ? _ys.embCamTriggerMode : 0
                                onActivated: if (_ys) { _ys.setParameter(4, currentIndex) }
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth:   true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 6
            radius:             ScreenTools.defaultFontPixelHeight * 0.4
            color:              qgcPal.windowShade
            border.color:       qgcPal.text

            Column {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth
                spacing: ScreenTools.defaultFontPixelHeight * 0.4

                QGCLabel { text: qsTr("Message Monitor") }

                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth
                    QGCLabel { text: qsTr("Sent:") }
                    TextArea {
                        readOnly: true
                        wrapMode: TextArea.WrapAnywhere
                        text: _ys ? _ys.lastSentMessage : ""
                        height: ScreenTools.defaultFontPixelHeight * 1.8
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth
                    QGCLabel { text: qsTr("Received:") }
                    TextArea {
                        readOnly: true
                        wrapMode: TextArea.WrapAnywhere
                        text: _ys ? _ys.lastReceivedMessage : ""
                        height: ScreenTools.defaultFontPixelHeight * 1.8
                        Layout.fillWidth: true
                    }
                }
            }
        }

    }
}
