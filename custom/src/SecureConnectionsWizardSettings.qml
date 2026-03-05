import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Layouts          1.2

import QGroundControl                       1.0
import QGroundControl.Controls              1.0
import QGroundControl.FactSystem            1.0
import QGroundControl.Palette               1.0
import QGroundControl.ScreenTools           1.0

Rectangle {
    id:                 _root
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    property real _panelWidth:      Math.min(_root.width * 0.90, ScreenTools.defaultFontPixelWidth * 92)
    property real _margins:         ScreenTools.defaultFontPixelWidth * 1.2
    property real _blockPadding:    ScreenTools.defaultFontPixelWidth
    property var  _customSettings:  QGroundControl.corePlugin.settings
    readonly property var _bindAddressOptions: [ "127.0.0.1", "0.0.0.0" ]
    readonly property string _networkDocUrl: "https://mavlink.io/en/services/"

    property Fact _udpEnabled:      _customSettings.networkUdpListenerEnabled
    property Fact _tcpEnabled:      _customSettings.networkTcpServerEnabled
    property Fact _videoEnabled:    _customSettings.networkVideoStreamingEnabled
    property Fact _udpPort:         _customSettings.networkUdpPort
    property Fact _tcpPort:         _customSettings.networkTcpPort
    property Fact _udpBind:         _customSettings.networkUdpBindAddress
    property Fact _tcpBind:         _customSettings.networkTcpBindAddress
    property Fact _videoUrl:        _customSettings.networkVideoUrl
    property Fact _strictValid:     _customSettings.securityStrictMavlinkValidation
    property Fact _allowlist:       _customSettings.securityAllowlistVehicleIds
    property Fact _wizardDone:      _customSettings.securityWizardCompleted

    QGCPalette { id: qgcPal }

    function bindAddressToIndex(bindAddress) {
        var index = _bindAddressOptions.indexOf(bindAddress)
        return index >= 0 ? index : 0
    }

    function saveSelections(markWizardDone) {
        _udpEnabled.rawValue = udpCheck.checked
        _tcpEnabled.rawValue = tcpCheck.checked
        _videoEnabled.rawValue = videoCheck.checked
        _strictValid.rawValue = strictCheck.checked
        _allowlist.rawValue = allowlistCheck.checked
        if (markWizardDone) {
            _wizardDone.rawValue = true
        }
    }

    QGCFlickable {
        anchors.fill:   parent
        clip:           true
        contentHeight:  contentColumn.height
        contentWidth:   contentColumn.width

        Column {
            id:                 contentColumn
            width:              _root.width
            spacing:            ScreenTools.defaultFontPixelHeight

            Rectangle {
                width:                      _panelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                color:                      "#1d2a3d"
                border.color:               "#31445f"
                radius:                     6
                height:                     wizardColumn.height + _margins * 2

                Column {
                    id:                     wizardColumn
                    anchors.left:           parent.left
                    anchors.right:          parent.right
                    anchors.top:            parent.top
                    anchors.margins:        _margins
                    spacing:                ScreenTools.defaultFontPixelHeight * 0.7

                    QGCLabel {
                        text: qsTr("Configure Connections (Secure by Default)")
                        font.family: ScreenTools.demiboldFontFamily
                        font.pointSize: ScreenTools.largeFontPointSize
                        color: "#f2f5fa"
                    }

                    QGCLabel {
                        text: qsTr("No network services are enabled by default. Enable only what you need.")
                        color: "#b8c3d4"
                    }

                    Rectangle {
                        width:          parent.width
                        color:          "#223146"
                        border.color:   "#3a4d69"
                        radius:         3
                        height:         udpConfig.height + _blockPadding * 1.2

                        Column {
                            id:                     udpConfig
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins:        _blockPadding
                            spacing:                ScreenTools.defaultFontPixelHeight * 0.3

                            QGCCheckBox { id: udpCheck; text: qsTr("MAVLink UDP Listener"); checked: _udpEnabled.rawValue; textColor: "#f2f5fa" }
                            RowLayout {
                                spacing: ScreenTools.defaultFontPixelWidth
                                QGCLabel { text: qsTr("Port:") }
                                FactTextField { fact: _udpPort; enabled: udpCheck.checked; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10 }
                                QGCLabel { text: qsTr("Bind:") }
                                QGCComboBox {
                                    model: _bindAddressOptions
                                    enabled: udpCheck.checked
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
                                    currentIndex: _root.bindAddressToIndex(_udpBind.rawValue)
                                    onActivated: _udpBind.rawValue = _bindAddressOptions[index]
                                }
                            }
                            QGCLabel {
                                text: qsTr("i Listens for MAVLink via UDP")
                                color: "#95a8c2"
                                font.pointSize: ScreenTools.smallFontPointSize
                            }
                        }
                    }

                    Rectangle {
                        width:          parent.width
                        color:          "#223146"
                        border.color:   "#3a4d69"
                        radius:         3
                        height:         tcpConfig.height + _blockPadding * 1.2

                        Column {
                            id:                     tcpConfig
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins:        _blockPadding
                            spacing:                ScreenTools.defaultFontPixelHeight * 0.3

                            QGCCheckBox { id: tcpCheck; text: qsTr("MAVLink TCP Server"); checked: _tcpEnabled.rawValue; textColor: "#f2f5fa" }
                            RowLayout {
                                spacing: ScreenTools.defaultFontPixelWidth
                                QGCLabel { text: qsTr("Port:") }
                                FactTextField { fact: _tcpPort; enabled: tcpCheck.checked; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10 }
                                QGCLabel { text: qsTr("Bind:") }
                                QGCComboBox {
                                    model: _bindAddressOptions
                                    enabled: tcpCheck.checked
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 14
                                    currentIndex: _root.bindAddressToIndex(_tcpBind.rawValue)
                                    onActivated: _tcpBind.rawValue = _bindAddressOptions[index]
                                }
                            }
                            QGCLabel {
                                text: qsTr("i Accepts MAVLink via TCP")
                                color: "#95a8c2"
                                font.pointSize: ScreenTools.smallFontPointSize
                            }
                        }
                    }

                    Rectangle {
                        width:          parent.width
                        color:          "#223146"
                        border.color:   "#3a4d69"
                        radius:         3
                        height:         videoConfig.height + _blockPadding * 1.2

                        Column {
                            id:                     videoConfig
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins:        _blockPadding
                            spacing:                ScreenTools.defaultFontPixelHeight * 0.3

                            QGCCheckBox { id: videoCheck; text: qsTr("Video Streaming (GStreamer)"); checked: _videoEnabled.rawValue; textColor: "#f2f5fa" }
                            RowLayout {
                                spacing: ScreenTools.defaultFontPixelWidth
                                QGCLabel { text: qsTr("URI:") }
                                FactTextField { fact: _videoUrl; enabled: videoCheck.checked; Layout.fillWidth: true }
                            }
                        }
                    }

                    Rectangle {
                        width:          parent.width
                        color:          "#223146"
                        border.color:   "#3a4d69"
                        radius:         3
                        height:         securityColumn.height + _blockPadding * 1.2

                        Column {
                            id:                     securityColumn
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins:        _blockPadding
                            spacing:                ScreenTools.defaultFontPixelHeight * 0.25

                            QGCLabel {
                                text: qsTr("Security (recommended)")
                                font.family: ScreenTools.demiboldFontFamily
                                color: "#f2f5fa"
                            }
                            QGCCheckBox { id: strictCheck; text: qsTr("Strict MAVLink validation"); checked: _strictValid.rawValue; textColor: "#f2f5fa" }
                            QGCCheckBox { id: allowlistCheck; text: qsTr("Allowlist Vehicle IDs (SYSID/COMPID)"); checked: _allowlist.rawValue; textColor: "#f2f5fa" }
                        }
                    }

                    QGCLabel {
                        textFormat: Text.RichText
                        text: qsTr("<a href='%1'>Learn more: Network services & ports</a>").arg(_networkDocUrl)
                        onLinkActivated: Qt.openUrlExternally(link)
                        color: "#f5c542"
                    }

                    RowLayout {
                        width: parent.width
                        QGCButton {
                            text: qsTr("Continue offline")
                            onClicked: {
                                _wizardDone.rawValue = true
                                skippedDialog.open()
                            }
                        }
                        Item { Layout.fillWidth: true }
                        QGCButton {
                            text: qsTr("Start (Enable Selected Services)")
                            primary: true
                            onClicked: {
                                saveSelections(true)
                                appliedDialog.open()
                            }
                        }
                    }
                }
            }
        }
    }

    QGCSimpleMessageDialog {
        id: appliedDialog
        title: qsTr("Secure Setup")
        text: qsTr("Selected services and security profile were applied.")
    }

    QGCSimpleMessageDialog {
        id: skippedDialog
        title: qsTr("Secure Setup")
        text: qsTr("You can configure services later from Privacy > Secure Setup.")
    }
}
