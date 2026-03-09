/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.12
import QtQuick.Dialogs  1.3
import QtQuick.Layouts  1.12

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.ScreenTools   1.0

FirstRunPrompt {
    title:      qsTr("Secure Setup")
    promptId:   QGroundControl.corePlugin.secureConnectionFirstRunPromptId
    buttons:    StandardButton.NoButton

    property real _margins:         ScreenTools.defaultFontPixelWidth
    property real _blockPadding:    ScreenTools.defaultFontPixelWidth
    property var  _customSettings:  QGroundControl.corePlugin.settings
    readonly property var _bindAddressOptions: [ "127.0.0.1", "0.0.0.0" ]
    readonly property string _networkDocUrl: "https://mavlink.io/en/services/"

    property Fact _udpEnabled:      _customSettings ? _customSettings.networkUdpListenerEnabled : null
    property Fact _tcpEnabled:      _customSettings ? _customSettings.networkTcpServerEnabled : null
    property Fact _videoEnabled:    _customSettings ? _customSettings.networkVideoStreamingEnabled : null
    property Fact _udpPort:         _customSettings ? _customSettings.networkUdpPort : null
    property Fact _tcpPort:         _customSettings ? _customSettings.networkTcpPort : null
    property Fact _udpBind:         _customSettings ? _customSettings.networkUdpBindAddress : null
    property Fact _tcpBind:         _customSettings ? _customSettings.networkTcpBindAddress : null
    property Fact _videoUrl:        _customSettings ? _customSettings.networkVideoUrl : null
    property Fact _strictValid:     _customSettings ? _customSettings.securityStrictMavlinkValidation : null
    property Fact _allowlist:       _customSettings ? _customSettings.securityAllowlistVehicleIds : null
    property Fact _wizardDone:      _customSettings ? _customSettings.securityWizardCompleted : null
    readonly property bool _settingsReady: _udpEnabled && _tcpEnabled && _videoEnabled && _udpPort && _tcpPort && _udpBind && _tcpBind && _videoUrl && _strictValid && _allowlist && _wizardDone

    function bindAddressToIndex(bindAddress) {
        var index = _bindAddressOptions.indexOf(bindAddress)
        return index >= 0 ? index : 0
    }

    function _saveSelections(markWizardDone) {
        if (!_settingsReady) {
            return
        }
        _udpEnabled.rawValue = udpCheck.checked
        _tcpEnabled.rawValue = tcpCheck.checked
        _videoEnabled.rawValue = videoCheck.checked
        _strictValid.rawValue = strictCheck.checked
        _allowlist.rawValue = allowlistCheck.checked
        if (markWizardDone) {
            _wizardDone.rawValue = true
        }
    }

    ColumnLayout {
        width:      ScreenTools.defaultFontPixelWidth * 78
        spacing:    ScreenTools.defaultFontPixelHeight

        QGCLabel {
            text:       qsTr("Configure Connections (Secure by Default)")
            font.family: ScreenTools.demiboldFontFamily
            font.pointSize: ScreenTools.largeFontPointSize
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        QGCLabel {
            text: qsTr("No network services are enabled by default. Enable only what you need.")
            color: qgcPal.colorGrey
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth:   true
            color:              qgcPal.windowShade
            radius:             3
            height:             udpConfig.height + _blockPadding * 1.2

            ColumnLayout {
                id:                     udpConfig
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins:        _blockPadding
                spacing:                ScreenTools.defaultFontPixelHeight * 0.3

                QGCCheckBox { id: udpCheck; text: qsTr("MAVLink UDP Listener"); checked: _udpEnabled ? _udpEnabled.rawValue : false }
                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth
                    QGCLabel { text: qsTr("Port:") }
                    FactTextField { fact: _udpPort; enabled: _settingsReady && udpCheck.checked; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10 }
                    QGCLabel { text: qsTr("Bind:") }
                    QGCComboBox {
                        model: _bindAddressOptions
                        enabled: _settingsReady && udpCheck.checked
                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
                        currentIndex: _udpBind ? bindAddressToIndex(_udpBind.rawValue) : 0
                        onActivated: _udpBind.rawValue = _bindAddressOptions[index]
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth:   true
            color:              qgcPal.windowShade
            radius:             3
            height:             tcpConfig.height + _blockPadding * 1.2

            ColumnLayout {
                id:                     tcpConfig
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins:        _blockPadding
                spacing:                ScreenTools.defaultFontPixelHeight * 0.3

                QGCCheckBox { id: tcpCheck; text: qsTr("MAVLink TCP Server"); checked: _tcpEnabled ? _tcpEnabled.rawValue : false }
                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth
                    QGCLabel { text: qsTr("Port:") }
                    FactTextField { fact: _tcpPort; enabled: _settingsReady && tcpCheck.checked; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10 }
                    QGCLabel { text: qsTr("Bind:") }
                    QGCComboBox {
                        model: _bindAddressOptions
                        enabled: _settingsReady && tcpCheck.checked
                        Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
                        currentIndex: _tcpBind ? bindAddressToIndex(_tcpBind.rawValue) : 0
                        onActivated: _tcpBind.rawValue = _bindAddressOptions[index]
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth:   true
            color:              qgcPal.windowShade
            radius:             3
            height:             videoConfig.height + _blockPadding * 1.2

            ColumnLayout {
                id:                     videoConfig
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins:        _blockPadding
                spacing:                ScreenTools.defaultFontPixelHeight * 0.3

                QGCCheckBox { id: videoCheck; text: qsTr("Video Streaming (GStreamer)"); checked: _videoEnabled ? _videoEnabled.rawValue : false }
                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth
                    QGCLabel { text: qsTr("URI:") }
                    FactTextField { fact: _videoUrl; enabled: _settingsReady && videoCheck.checked; Layout.fillWidth: true }
                }
            }
        }

        Rectangle {
            Layout.fillWidth:   true
            color:              qgcPal.windowShade
            radius:             3
            height:             securityColumn.height + _blockPadding * 1.2

            ColumnLayout {
                id:                     securityColumn
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins:        _blockPadding
                spacing:                ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    text: qsTr("Security (recommended)")
                    font.family: ScreenTools.demiboldFontFamily
                }
                QGCCheckBox { id: strictCheck; text: qsTr("Strict MAVLink validation"); checked: _strictValid ? _strictValid.rawValue : false }
                QGCCheckBox { id: allowlistCheck; text: qsTr("Allowlist Vehicle IDs (SYSID/COMPID)"); checked: _allowlist ? _allowlist.rawValue : false }
            }
        }

        QGCLabel {
            textFormat: Text.RichText
            text: qsTr("<a href='%1'>Learn more: Network services & ports</a>").arg(_networkDocUrl)
            onLinkActivated: Qt.openUrlExternally(link)
            color: qgcPal.colorBlue
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            QGCButton {
                text: qsTr("Continue offline")
                enabled: _settingsReady
                onClicked: {
                    _wizardDone.rawValue = true
                    close()
                }
            }
            Item { Layout.fillWidth: true }
            QGCButton {
                text: qsTr("Start (Enable Selected Services)")
                primary: true
                enabled: _settingsReady
                onClicked: {
                    _saveSelections(true)
                    close()
                }
            }
        }

        QGCLabel {
            visible: !_settingsReady
            text: qsTr("Loading secure settings...")
            color: qgcPal.colorGrey
            Layout.fillWidth: true
        }
    }
}
