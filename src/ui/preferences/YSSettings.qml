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
import QtQuick.Controls.Styles 1.4
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
    anchors.topMargin:    ScreenTools.defaultFontPixelHeight * 0.2

    QGCPalette { id: qgcPal }

    Timer {
        id: statusPollTimer
        interval: 4000
        repeat: true
        running: root.visible && _ys

        onTriggered: {
            _ys.requestStatus()
        }
    }
    property var _ys:             QGroundControl.corePlugin.ysManager
    property bool _showDetails:   false
    property bool _showParameters:false

    onVisibleChanged: {
        if (visible) {
            _showDetails = false
            _showParameters = false
        }
    }
    property real _paramLabelWidth: ScreenTools.defaultFontPixelWidth * 18
    property real _paramFieldWidth: ScreenTools.defaultFontPixelWidth * 12
    property real _paramFieldWideWidth: ScreenTools.defaultFontPixelWidth * 14

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
        var highSensitivityValue = scannerHighSensitivityCombo.currentIndex === 0 ? 1 : 0
        var scannerPatternValue = scannerPatternCombo.currentIndex
        var embeddedCameraValue = embeddedCameraCombo.currentIndex
        var initHeightValue = parseFloat(embCamInitHeightField.text)
        var triggerModeValue = embCamTriggerModeCombo.currentIndex
        var triggerValue = parseFloat(embCamTriggerValueField.text)

        _ys.setParameter(0, highSensitivityValue)
        _ys.setParameter(1, scannerPatternValue)
        _ys.setParameter(2, embeddedCameraValue)
        if (!isNaN(initHeightValue)) {
            _ys.setParameter(3, initHeightValue)
        }
        _ys.setParameter(4, triggerModeValue)
        if (!isNaN(triggerValue)) {
            _ys.setParameter(5, triggerValue)
        }
    }

    function syncParametersFromManager() {
        if (!_ys) {
            return
        }
        scannerHighSensitivityCombo.currentIndex = _ys.scannerHighSensitivity ? 0 : 1
        scannerPatternCombo.currentIndex = _ys.scannerPattern
        embeddedCameraCombo.currentIndex = _ys.embeddedCamera
        embCamTriggerModeCombo.currentIndex = _ys.embCamTriggerMode
        if (!embCamInitHeightField.activeFocus) {
            embCamInitHeightField.text = _ys.embCamInitHeight.toString()
        }
        if (!embCamTriggerValueField.activeFocus) {
            embCamTriggerValueField.text = _ys.embCamTriggerValue.toString()
        }
    }

    Connections {
        target: _ys
        function onParameterChanged() { syncParametersFromManager() }
    }

    Component.onCompleted: syncParametersFromManager()

    ColumnLayout {
        anchors.fill:   parent
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
                                enabled: _ys && _ys.statusValid
                                onClicked: if (_ys) { _ys.powerOff() }
                            }
                            QGCButton {
                                text: _ys && _ys.acquisitionRunning && _ys.statusValid ? qsTr("Acquisition OFF") : qsTr("Acquisition ON")
                                enabled: _ys && _ys.statusValid
                                onClicked: {
                                    if (_ys) {
                                        if (_ys.acquisitionRunning && _ys.statusValid) {
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
                                visible: false // Configuration is currently not supported, so hide button for now. Can be re-enabled when configuration functionality is added.
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
                Layout.preferredHeight: (_showDetails || _showParameters) ? (detailsParamsCol.implicitHeight + (ScreenTools.defaultFontPixelWidth * 2)) : 0
                radius:             ScreenTools.defaultFontPixelHeight * 0.4
                color:              qgcPal.windowShade
                border.color:       qgcPal.text

                Column {
                    id: detailsParamsCol
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
                                { label: "Acquisition Running", ok: _ys && _ys.acquisitionRunning, valid: _ys && _ys.statusValid },
                                { label: "Time Not Set", ok: _ys && !_ys.timeNotSet, valid: _ys && _ys.statusValid },
                                { label: "Scanner Not Ready", ok: _ys && !_ys.scannerNotReady, valid: _ys && _ys.statusValid },
                                { label: "INS Not Locked", ok: _ys && !_ys.insNotLocked, valid: _ys && _ys.statusValid },
                                { label: "Scanner Error", ok: _ys && _ys.scnErr === 0, valid: _ys && _ys.statusValid },
                                { label: "INS Error", ok: _ys && _ys.insErr === 0, valid: _ys && _ys.statusValid },
                                { label: "No USB", ok: _ys && !_ys.noUsb, valid: _ys && _ys.statusValid },
                                { label: "USB Full", ok: _ys && !_ys.usbFull, valid: _ys && _ys.statusValid },
                                { label: "Camera Error", ok: _ys && _ys.camErr === 0, valid: _ys && _ys.statusValid }
                            ]
                            delegate: Row {
                                spacing: ScreenTools.defaultFontPixelWidth
                                Rectangle {
                                    width:  ScreenTools.defaultFontPixelHeight * 0.6
                                    height: width
                                    radius: width * 0.5
                                    color:  modelData.valid ? (modelData.ok ? qgcPal.colorGreen : qgcPal.colorRed) : qgcPal.colorRed
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

                        GridLayout {
    id: paramsGrid
    columns: 3
    Layout.fillWidth: true
    columnSpacing: ScreenTools.defaultFontPixelWidth * 2
    rowSpacing: ScreenTools.defaultFontPixelHeight * 0.4

    // Column sizing: [Label] [Control] [Optional value]
    // - Labels are right-aligned and elide if space is tight
    // - Controls expand/shrink within bounds to avoid overflow

    // Scanner High Sensitivity (Param 0)
    QGCLabel {
        text: qsTr("Scanner High Sensitivity")
        Layout.preferredWidth: _paramLabelWidth
        Layout.maximumWidth: _paramLabelWidth
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    QGCComboBox {
        id: scannerHighSensitivityCombo
        model: [qsTr("On"), qsTr("Off")]
        currentIndex: 0
        Layout.fillWidth: true
        Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 10
        Layout.maximumWidth: _paramFieldWideWidth
        Layout.columnSpan: 2
        background: Rectangle {
            implicitWidth:  ScreenTools.implicitComboBoxWidth
            implicitHeight: ScreenTools.implicitComboBoxHeight
            color:          qgcPal.window
            border.color:   (_ys && _ys.scannerHighSensitivitySetFailed) ? qgcPal.colorRed : qgcPal.text
        }
    }

    // Scanner Pattern (Param 1)
    QGCLabel {
        text: qsTr("Scanner Pattern")
        Layout.preferredWidth: _paramLabelWidth
        Layout.maximumWidth: _paramLabelWidth
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    QGCComboBox {
        id: scannerPatternCombo
        model: [qsTr("None"), qsTr("Repetition")]
        currentIndex: 0
        Layout.fillWidth: true
        Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 10
        Layout.maximumWidth: _paramFieldWideWidth
        Layout.columnSpan: 2
        background: Rectangle {
            implicitWidth:  ScreenTools.implicitComboBoxWidth
            implicitHeight: ScreenTools.implicitComboBoxHeight
            color:          qgcPal.window
            border.color:   (_ys && _ys.scannerPatternSetFailed) ? qgcPal.colorRed : qgcPal.text
        }
    }

    // Embedded Camera (Param 2)
    QGCLabel {
        text: qsTr("Emb. Camera")
        Layout.preferredWidth: _paramLabelWidth
        Layout.maximumWidth: _paramLabelWidth
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    QGCComboBox {
        id: embeddedCameraCombo
        model: [qsTr("Disable"), qsTr("Enable")]
        currentIndex: 0
        Layout.fillWidth: true
        Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 10
        Layout.maximumWidth: _paramFieldWideWidth
        Layout.columnSpan: 2
        background: Rectangle {
            implicitWidth:  ScreenTools.implicitComboBoxWidth
            implicitHeight: ScreenTools.implicitComboBoxHeight
            color:          qgcPal.window
            border.color:   (_ys && _ys.embeddedCameraSetFailed) ? qgcPal.colorRed : qgcPal.text
        }
    }

    // Embedded Camera Init Height (Param 3)
    QGCLabel {
        text: qsTr("Emb. Cam. Init. Height")
        Layout.preferredWidth: _paramLabelWidth
        Layout.maximumWidth: _paramLabelWidth
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    QGCTextField {
        id: embCamInitHeightField
        placeholderText: qsTr("Float")
        text: ""
        numericValuesOnly: true
        Layout.fillWidth: true
        Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 10
        Layout.maximumWidth: _paramFieldWideWidth
        Layout.columnSpan: 2
        style: TextFieldStyle {
            background: Rectangle {
                border.width: enabled ? 1 : 0
                border.color: (_ys && _ys.embCamInitHeightSetFailed) ? qgcPal.colorRed : (control.activeFocus ? "#47b" : "#999")
                color: qgcPal.textField
            }
        }
    }

    // Embedded Camera Trigger Mode (Param 4) + Trigger Value (Param 5)
    QGCLabel {
        text: qsTr("Emb. Cam. Trigger Mode")
        Layout.preferredWidth: _paramLabelWidth
        Layout.maximumWidth: _paramLabelWidth
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    QGCComboBox {
        id: embCamTriggerModeCombo
        model: [qsTr("Time"), qsTr("Distance")]
        currentIndex: 0
        Layout.fillWidth: true
        Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 10
        Layout.maximumWidth: _paramFieldWideWidth
        background: Rectangle {
            implicitWidth:  ScreenTools.implicitComboBoxWidth
            implicitHeight: ScreenTools.implicitComboBoxHeight
            color:          qgcPal.window
            border.color:   (_ys && _ys.embCamTriggerModeSetFailed) ? qgcPal.colorRed : qgcPal.text
        }
    }
    QGCTextField {
        id: embCamTriggerValueField
        placeholderText: qsTr("Float")
        text: ""
        numericValuesOnly: true
        Layout.fillWidth: true
        Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 8
        Layout.maximumWidth: _paramFieldWideWidth
        style: TextFieldStyle {
            background: Rectangle {
                border.width: enabled ? 1 : 0
                border.color: (_ys && _ys.embCamTriggerValueSetFailed) ? qgcPal.colorRed : (control.activeFocus ? "#47b" : "#999")
                color: qgcPal.textField
            }
        }
    }
}

                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth:   true
            Layout.preferredHeight: messageMonitorCol.implicitHeight + (ScreenTools.defaultFontPixelWidth * 2)
            radius:             ScreenTools.defaultFontPixelHeight * 0.4
            color:              qgcPal.windowShade
            border.color:       qgcPal.text

            Column {
                id: messageMonitorCol
                anchors.fill: parent
                anchors.margins: ScreenTools.defaultFontPixelWidth
                spacing: ScreenTools.defaultFontPixelHeight * 0.4

                QGCLabel { text: qsTr("Message Monitor") }

                GridLayout {
                    id: messageGrid
                    columns: 2
                    Layout.fillWidth: true
                    columnSpacing: ScreenTools.defaultFontPixelWidth
                    rowSpacing: ScreenTools.defaultFontPixelHeight * 0.4
                    property real _labelWidth: ScreenTools.defaultFontPixelWidth * 9

                    QGCLabel {
                        text: qsTr("Sent:")
                        Layout.alignment: Qt.AlignTop | Qt.AlignRight
                        Layout.preferredWidth: messageGrid._labelWidth
                    }
                    TextArea {
                        readOnly: true
                        wrapMode: TextArea.WrapAnywhere
                        text: _ys ? _ys.lastSentMessage : ""
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.2
                        Layout.fillWidth: true
                        Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 80
                        color: qgcPal.text
                        background: Rectangle {
                            color: qgcPal.window
                            border.color: qgcPal.text
                            radius: ScreenTools.defaultFontPixelHeight * 0.2
                        }
                    }

                    QGCLabel {
                        text: qsTr("Received:")
                        Layout.alignment: Qt.AlignTop | Qt.AlignRight
                        Layout.preferredWidth: messageGrid._labelWidth
                    }
                    TextArea {
                        readOnly: true
                        wrapMode: TextArea.WrapAnywhere
                        text: _ys ? _ys.lastReceivedMessage : ""
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 3.2
                        Layout.fillWidth: true
                        Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 80
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
