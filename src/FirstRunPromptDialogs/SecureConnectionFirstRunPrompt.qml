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
import QtQuick.Dialogs  1.3

import QGroundControl           1.0
import QGroundControl.Controls  1.0
import QGroundControl.FactSystem 1.0
import QGroundControl.ScreenTools 1.0

FirstRunPrompt {
    id:         root
    title:      qsTr("Secure Setup")
    promptId:   QGroundControl.corePlugin.secureConnectionFirstRunPromptId
    buttons:    StandardButton.NoButton
    readonly property real _labelColumnWidth: ScreenTools.defaultFontPixelWidth * 23
    readonly property real _videoLabelColumnWidth: ScreenTools.defaultFontPixelWidth * 28
    readonly property real _portFieldWidth: ScreenTools.defaultFontPixelWidth * 7
    readonly property real _bindFieldWidth: ScreenTools.defaultFontPixelWidth * 11
    readonly property var _customSettings:   QGroundControl.corePlugin.settings
    readonly property var _videoSettings:    QGroundControl.settingsManager.videoSettings

    property bool _udpChecked: true
    property bool _tcpChecked: true
    property bool _videoChecked: true

    property Fact _udpEnabled:       _customSettings.networkUdpListenerEnabled
    property Fact _tcpEnabled:       _customSettings.networkTcpServerEnabled
    property Fact _videoEnabled:     _customSettings.networkVideoStreamingEnabled
    property Fact _udpPort:          _customSettings.networkUdpPort
    property Fact _tcpPort:          _customSettings.networkTcpPort
    property Fact _udpBind:          _customSettings.networkUdpBindAddress
    property Fact _tcpBind:          _customSettings.networkTcpBindAddress
    property Fact _videoUrl:         _customSettings.networkVideoUrl
    property Fact _strictValidation: _customSettings.securityStrictMavlinkValidation
    property Fact _allowlistIds:     _customSettings.securityAllowlistVehicleIds
    property Fact _wizardCompleted:  _customSettings.securityWizardCompleted

    function _comboIndexForBind(address) {
        return address === "0.0.0.0" ? 1 : 0
    }

    function _bindForComboIndex(index) {
        return index === 1 ? "0.0.0.0" : "127.0.0.1"
    }

    function _parsePort(text) {
        var value = parseInt(text, 10)
        return isNaN(value) ? -1 : value
    }

    function _applyVideoSource(uri) {
        var trimmedUri = uri.trim()
        if (trimmedUri.indexOf("rtsp://") === 0) {
            _videoSettings.videoSource.rawValue = _videoSettings.rtspVideoSource
            _videoSettings.rtspUrl.rawValue = trimmedUri
            return
        } else if (trimmedUri.indexOf("tcp://") === 0) {
            _videoSettings.videoSource.rawValue = _videoSettings.tcpVideoSource
            _videoSettings.tcpUrl.rawValue = trimmedUri
            return
        } else if (trimmedUri.indexOf("udp265://") === 0) {
            _videoSettings.videoSource.rawValue = _videoSettings.udp265VideoSource
        } else if (trimmedUri.indexOf("mpegts://") === 0) {
            _videoSettings.videoSource.rawValue = _videoSettings.mpegtsVideoSource
        } else {
            _videoSettings.videoSource.rawValue = _videoSettings.udp264VideoSource
        }

        var portMatch = trimmedUri.match(/:(\d+)\s*$/)
        if (portMatch && portMatch.length > 1) {
            _videoSettings.udpPort.rawValue = parseInt(portMatch[1], 10)
        }
    }

    function _saveConfiguration(enableSelectedServices) {
        var udpPortValue = _parsePort(udpPortField.text)
        var tcpPortValue = _parsePort(tcpPortField.text)
        var videoUriValue = videoUriField.text.trim()

        if (enableSelectedServices) {
            if (udpCheckbox.checked && (udpPortValue < 1 || udpPortValue > 65535)) {
                validationDialog.text = qsTr("UDP port must be between 1 and 65535.")
                validationDialog.open()
                return
            }
            if (tcpCheckbox.checked && (tcpPortValue < 1 || tcpPortValue > 65535)) {
                validationDialog.text = qsTr("TCP port must be between 1 and 65535.")
                validationDialog.open()
                return
            }
            if (videoCheckbox.checked && videoUriValue.length === 0) {
                validationDialog.text = qsTr("Video URI cannot be empty when video streaming is enabled.")
                validationDialog.open()
                return
            }
        }

        _udpEnabled.rawValue = enableSelectedServices && _udpChecked
        _tcpEnabled.rawValue = enableSelectedServices && _tcpChecked
        _videoEnabled.rawValue = enableSelectedServices && _videoChecked
        _videoSettings.streamEnabled.rawValue = enableSelectedServices && _videoChecked

        _udpPort.rawValue = udpPortValue > 0 ? udpPortValue : _udpPort.rawValue
        _tcpPort.rawValue = tcpPortValue > 0 ? tcpPortValue : _tcpPort.rawValue
        _udpBind.rawValue = _bindForComboIndex(udpBindCombo.currentIndex)
        _tcpBind.rawValue = _bindForComboIndex(tcpBindCombo.currentIndex)
        _videoUrl.rawValue = videoUriValue.length ? videoUriValue : _videoUrl.rawValue
        _strictValidation.rawValue = strictValidationCheckbox.checked
        _allowlistIds.rawValue = allowlistIdsCheckbox.checked
        _wizardCompleted.rawValue = true

        CustomQmlInterface.logSecurityEvent("Secure setup applied. UDP=" + _udpEnabled.rawValue
                                            + " TCP=" + _tcpEnabled.rawValue
                                            + " Video=" + _videoEnabled.rawValue
                                            + " StrictValidation=" + _strictValidation.rawValue
                                            + " Allowlist=" + _allowlistIds.rawValue)

        if (_videoEnabled.rawValue) {
            _applyVideoSource(_videoUrl.rawValue.toString())
        }

        if (!_udpEnabled.rawValue && !_tcpEnabled.rawValue && !_videoEnabled.rawValue) {
            CustomQmlInterface.logSecurityEvent("Continue offline applied. Network services disabled.")
            QGroundControl.linkManager.disconnectNetworkLinks()
        }

        close()
    }

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
                                id: udpCheckbox
                                text: qsTr("MAVLink UDP Listener")
                                checked: _udpChecked
                                onClicked: _udpChecked = checked
                                Layout.preferredWidth: _labelColumnWidth
                            }
                            QGCLabel { text: qsTr("Port:") }
                            QGCTextField {
                                id: udpPortField
                                text: _udpPort.rawValue.toString()
                                validator: IntValidator { bottom: 1; top: 65535 }
                                Layout.preferredWidth: _portFieldWidth
                            }
                            QGCLabel { text: qsTr("Bind:") }
                            QGCComboBox {
                                id: udpBindCombo
                                model: [ "127.0.0.1", "0.0.0.0" ]
                                currentIndex: _comboIndexForBind(_udpBind.rawValue)
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
                                id: tcpCheckbox
                                text: qsTr("MAVLink TCP Connection")
                                checked: _tcpChecked
                                onClicked: _tcpChecked = checked
                                Layout.preferredWidth: _labelColumnWidth
                            }
                            QGCLabel { text: qsTr("Port:") }
                            QGCTextField {
                                id: tcpPortField
                                text: _tcpPort.rawValue.toString()
                                validator: IntValidator { bottom: 1; top: 65535 }
                                Layout.preferredWidth: _portFieldWidth
                            }
                            QGCLabel { text: qsTr("Bind:") }
                            QGCComboBox {
                                id: tcpBindCombo
                                model: [ "127.0.0.1", "0.0.0.0" ]
                                currentIndex: _comboIndexForBind(_tcpBind.rawValue)
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
                                id: videoCheckbox
                                text: qsTr("Video Streaming (GStreamer)")
                                checked: _videoChecked
                                onClicked: _videoChecked = checked
                                Layout.preferredWidth: _videoLabelColumnWidth
                            }
                            QGCLabel { text: qsTr("URI:") }
                            QGCTextField {
                                id: videoUriField
                                text: _videoUrl.rawValue.toString()
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
                        QGCCheckBox {
                            id: strictValidationCheckbox
                            text: qsTr("Strict MAVLink validation")
                            checked: _strictValidation.rawValue
                        }
                        QGCCheckBox {
                            id: allowlistIdsCheckbox
                            text: qsTr("Allowlist Vehicle IDs (SYSID/COMPID)")
                            checked: _allowlistIds.rawValue
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            QGCButton {
                text: qsTr("Continue offline")
                onClicked: _saveConfiguration(false)
            }
            Item { Layout.fillWidth: true }
            QGCButton {
                text: qsTr("Start (Enable Selected Services)")
                primary: true
                onClicked: _saveConfiguration(true)
            }
        }
    }

    QGCSimpleMessageDialog {
        id: validationDialog
        title: qsTr("Invalid Secure Setup")
        text: ""
    }
}
