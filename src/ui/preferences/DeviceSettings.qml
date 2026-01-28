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
    anchors.leftMargin:   ScreenTools.defaultFontPixelWidth
    anchors.rightMargin:  ScreenTools.defaultFontPixelWidth
    anchors.bottomMargin: ScreenTools.defaultFontPixelWidth
    anchors.topMargin:    0

    QGCPalette { id: qgcPal }

    property var _ys:             QGroundControl.corePlugin.ysManager
    property bool _showDetails:   false
    property bool _showParameters:false
    property real _paramLabelWidth: ScreenTools.defaultFontPixelWidth * 18
    property real _paramFieldWidth: ScreenTools.defaultFontPixelWidth * 12

    function requestAllParameters() {
        if (!_ys) {
            return
        }
        _ys.requestParameter(0)
        _ys.requestParameter(1)
        _ys.requestParameter(2)
        _ys.requestParameter(3)
        _ys.requestParameter(4)
        _ys.requestParameter(5)
    }

    function setAllParameters() {
        if (!_ys) {
            return
        }
        _ys.setParameter(0, scannerHighSensitivityCombo.currentIndex === 0 ? 1 : 0)
        _ys.setParameter(1, scannerPatternCombo.currentIndex)
        _ys.setParameter(2, embeddedCameraCombo.currentIndex)
        var initHeightValue = parseInt(embCamInitHeightField.text)
        if (!isNaN(initHeightValue)) {
            _ys.setParameter(3, initHeightValue)
        }
        _ys.setParameter(4, embCamTriggerModeCombo.currentIndex)
    }

    ColumnLayout {
        anchors.top:    parent.top
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing:        ScreenTools.defaultFontPixelHeight * 0.35

        RowLayout {
            Layout.fillWidth:   true
            spacing:            ScreenTools.defaultFontPixelWidth * 2

            Rectangle {
                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 32
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 12
                radius:                 ScreenTools.defaultFontPixelHeight * 0.4
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
                                id: statusIndicator
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
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        _showDetails = !_showDetails
                                        if (_showDetails) {
                                            _showParameters = false
                                        }
                                        if (_showDetails && _ys) {
                                            _ys.requestStatus()
                                        }
                                    }
                                }
                            }
                            QGCButton {
                                text: qsTr("Configure")
                                enabled: _ys ? true : false
                                onClicked: {
                                    _showParameters = true
                                    _showDetails = false
                                    requestAllParameters()
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible:            _showDetails || _showParameters
                Layout.fillWidth:   true
                Layout.preferredHeight: _showDetails || _showParameters ? ScreenTools.defaultFontPixelHeight * 12 : 0
                radius:             ScreenTools.defaultFontPixelHeight * 0.4
                color:              qgcPal.windowShade
                border.color:       qgcPal.text

                Column {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelWidth
                    spacing: ScreenTools.defaultFontPixelHeight * 0.4

                    Column {
                        visible: _showDetails
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

                    ColumnLayout {
                        visible: _showParameters
                        spacing: ScreenTools.defaultFontPixelHeight * 0.4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: ScreenTools.defaultFontPixelWidth
                            QGCLabel { text: qsTr("Parameters") }
                            Item { Layout.fillWidth: true }
                            QGCButton {
                                text: qsTr("Get Param")
                                enabled: _ys ? true : false
                                onClicked: requestAllParameters()
                            }
                            QGCButton {
                                text: qsTr("Set Param")
                                enabled: _ys ? true : false
                                onClicked: setAllParameters()
                            }
                        }

                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 2
                            QGCLabel {
                                text: qsTr("Scanner High Sensitivity")
                                width: _paramLabelWidth
                                horizontalAlignment: Text.AlignRight
                            }
                            QGCComboBox {
                                id: scannerHighSensitivityCombo
                                model: [qsTr("On"), qsTr("Off")]
                                currentIndex: _ys ? (_ys.scannerHighSensitivity ? 0 : 1) : 0
                                onActivated: if (_ys) { _ys.setParameter(0, currentIndex === 0 ? 1 : 0) }
                                Layout.preferredWidth: _paramFieldWidth
                            }
                        }
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 2
                            QGCLabel {
                                text: qsTr("Scanner Pattern")
                                width: _paramLabelWidth
                                horizontalAlignment: Text.AlignRight
                            }
                            QGCComboBox {
                                id: scannerPatternCombo
                                model: [qsTr("None"), qsTr("Repetition")]
                                currentIndex: _ys ? _ys.scannerPattern : 0
                                onActivated: if (_ys) { _ys.setParameter(1, currentIndex) }
                                Layout.preferredWidth: _paramFieldWidth
                            }
                        }
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 2
                            QGCLabel {
                                text: qsTr("Emb. Camera")
                                width: _paramLabelWidth
                                horizontalAlignment: Text.AlignRight
                            }
                            QGCComboBox {
                                id: embeddedCameraCombo
                                model: [qsTr("Disable"), qsTr("Enable")]
                                currentIndex: _ys ? _ys.embeddedCamera : 0
                                onActivated: if (_ys) { _ys.setParameter(2, currentIndex) }
                                Layout.preferredWidth: _paramFieldWidth
                            }
                        }
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 2
                            QGCLabel {
                                text: qsTr("Emb. Cam. Init. Height")
                                width: _paramLabelWidth
                                horizontalAlignment: Text.AlignRight
                            }
                            QGCTextField {
                                id: embCamInitHeightField
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
                                Layout.preferredWidth: _paramFieldWidth
                            }
                        }
                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth * 2
                            QGCLabel {
                                text: qsTr("Emb. Cam. Trigger Mode")
                                width: _paramLabelWidth
                                horizontalAlignment: Text.AlignRight
                            }
                            QGCComboBox {
                                id: embCamTriggerModeCombo
                                model: [qsTr("Time"), qsTr("Distance")]
                                currentIndex: _ys ? _ys.embCamTriggerMode : 0
                                onActivated: if (_ys) { _ys.setParameter(4, currentIndex) }
                                Layout.preferredWidth: _paramFieldWidth
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth:   true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4.2
            radius:             ScreenTools.defaultFontPixelHeight * 0.4
            color:              qgcPal.windowShade
            border.color:       qgcPal.text

            Column {
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth
                spacing: ScreenTools.defaultFontPixelHeight * 0.4

                QGCLabel { text: qsTr("Message Monitor") }

                RowLayout {
                    width: parent.width
                    spacing: ScreenTools.defaultFontPixelWidth
                    QGCLabel { text: qsTr("Sent:") }
                    TextArea {
                        readOnly: true
                        wrapMode: TextArea.WrapAnywhere
                        text: _ys ? _ys.lastSentMessage : ""
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.2
                        Layout.fillWidth: true
                        color: qgcPal.text
                        background: Rectangle {
                            color: qgcPal.window
                            border.color: qgcPal.text
                            radius: ScreenTools.defaultFontPixelHeight * 0.2
                        }
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: ScreenTools.defaultFontPixelWidth
                    QGCLabel { text: qsTr("Received:") }
                    TextArea {
                        readOnly: true
                        wrapMode: TextArea.WrapAnywhere
                        text: _ys ? _ys.lastReceivedMessage : ""
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.2
                        Layout.fillWidth: true
                        color: qgcPal.text
                        background: Rectangle {
                            color: qgcPal.window
                            border.color: qgcPal.text
                            radius: ScreenTools.defaultFontPixelHeight * 0.2
                        }
                    }
                }
            }
        }

    }
}
