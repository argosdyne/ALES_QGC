import QtQuick          2.12
import QtQuick.Dialogs  1.3
import QtQuick.Layouts  1.2
import QtQuick.Controls 2.5

import QGroundControl                     1.0
import QGroundControl.Controls            1.0
import QGroundControl.MultiVehicleManager 1.0
import QGroundControl.ScreenTools         1.0
import QGroundControl.Palette             1.0
import QGroundControl.FactSystem          1.0
import QGroundControl.FactControls        1.0

import Custom.Widgets                     1.0

Item {
    id:  _root
    width:          signalRow.width

    QGCPalette { id: qgcPal }
    property var m2Manager:     QGroundControl.corePlugin.m2Manager
    property bool _connected:   m2Manager.connected && m2Manager.mounted
    property var  _rssiA:       m2Manager.rssiA
    property var  _rssiB:       m2Manager.rssiB
    property var  _skyRssiA:    m2Manager.skyRssiA
    property var  _skyRssiB:    m2Manager.skyRssiB
    property var  _linkSpeed:   m2Manager.linkspeed
    property var  _skyLinkSpeed: m2Manager.skyLinkspeed
    property bool _enableDelayTiggerWaiting: false

    Timer {
        id: enableDelayTiggerWaiting
        interval: 5000
        running: false
        repeat: false
        onTriggered: _enableDelayTiggerWaiting = false
    }

    Component {
        id:                                     m2RssiInfo
        Rectangle {
            id:                                 m2InfoRect
            width:                              rssiInfoCol.width  + ScreenTools.defaultFontPixelWidth * 4
            height:                             rssiInfoCol.height + ScreenTools.defaultFontPixelWidth * 4
            radius:                             ScreenTools.defaultFontPixelHeight * 0.5
            color:                              qgcPal.window
            border.color:                       qgcPal.text

            MouseArea {
                // This MouseArea prevents the Map below it from getting Mouse events. Without this
                // things like mousewheel will scroll the Flickable and then scroll the map as well.
                anchors.fill:                   parent
                preventStealing:                true
                onWheel:                        wheel.accepted = true
            }

            Column {
                id:                             rssiInfoCol
                spacing:                        ScreenTools.defaultFontPixelHeight
                anchors.margins:                ScreenTools.defaultFontPixelHeight
                anchors.centerIn:               parent

                QGCLabel {
                    id:                         rssiLabel
                    text:                       _connected ? qsTr("Link RSSI Status") : qsTr("Link Disconnected")
                    font.family:                ScreenTools.demiboldFontFamily
                    anchors.horizontalCenter:   parent.horizontalCenter
                }

                GridLayout {
                    id:                         rssiInfoGrid
                    visible:                    _connected
                    columnSpacing:              ScreenTools.defaultFontPixelWidth
                    columns:                    2
                    anchors.margins:            ScreenTools.defaultFontPixelHeight
                    anchors.horizontalCenter:   parent.horizontalCenter

                    QGCLabel {
                        text:                   qsTr("LinkSpeed:")
                        color:                  qgcPal.text
                    }
                    QGCLabel {
                        text:                   _connected ? _linkSpeed + " / " + _skyLinkSpeed + " Mbps" : qsTr("N/A")
                        color:                  qgcPal.text
                    }

                    QGCLabel {
                        text:                   qsTr("RSSI:")
                        color:                  qgcPal.text
                    }
                    QGCLabel {
                        text:                   _connected ? _rssiA + " / " + _rssiB + " dB" : qsTr("N/A")
                        color:                  qgcPal.text
                    }

                    QGCLabel {
                        text:                   qsTr("Sky RSSI:")
                        color:                  qgcPal.text
                    }
                    QGCLabel {
                        text:                   _connected ? _skyRssiA + " / " + _skyRssiB + " dB" : qsTr("N/A")
                        color:                  qgcPal.text
                    }
                }

                QGCButton {
                    text:                       qsTr("Start Pair")
                    width:                      ScreenTools.defaultFontPixelWidth * 15
                    anchors.horizontalCenter:   parent.horizontalCenter
                    onClicked: {
                        mainWindow.hideIndicatorPopup()
                        m2PairGuideComponent.createObject(mainWindow).open()
                    }
                }
            }
        }
    }

    function getSignalStrength(rssi) {
        if(rssi <= -100) return 0;
        if(rssi <= -92) return 30;
        else if(rssi <= -86) return 50;
        else if(rssi <= -80) return 70;
        else if(rssi <= -65) return 85;
        else return 100;
    }

    // Signal
    Row {
        id:                                     signalRow
        spacing:                                ScreenTools.defaultFontPixelWidth
        anchors.top:                            parent.top
        anchors.bottom:                         parent.bottom
        anchors.horizontalCenter:               parent.horizontalCenter
        SignalStrength {
            id: arLinkSignalStrength
            anchors.verticalCenter: parent.verticalCenter
            size:                   ScreenTools.defaultFontPixelHeight * 1.6
            percent:                _connected ? getSignalStrength(Math.min(m2Manager.rssi, m2Manager.skyRssi)) : 0
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            QGCLabel {
                id:                     frequencyLable
                text:                   "M2"
                font.pointSize:         ScreenTools.defaultFontPointSize
            }
            QGCLabel {
                id:                     linkNameLable
                text:                   "Enpulse"
                font.pointSize:         ScreenTools.defaultFontPointSize
            }
        }
    }

    Component {
        id: m2PairGuideComponent
        QGCPopupDialog {
            id:         m2PairGuide
            title:      qsTr("Data Link Pair")
            buttons:    StandardButton.Close
            property bool isTriggerBind: false
            Timer {
                id: m2PairGuideCloseTimer
                interval: 500
                running: false
                repeat: false
                onTriggered: m2PairGuide.close()
            }
            Item {
                width: mainWindow.width * 0.4
                height: mainWindow.height * 0.6
                QGCLabel {
                    wrapMode: TextEdit.WordWrap
                    text: qsTr("Press and hold this, the remote control will enter the binding state.")
                    width: parent.width * 0.9
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: ScreenTools.defaultFontPixelHeight * 1.5
                }
                CustomDelayButton {
                    id: pairDelayButton
                    text: qsTr("Trigger Bind")
                    anchors.centerIn: parent
                    iconSource: "qrc:/custom/img/PairingButton.svg"
                    height: ScreenTools.defaultFontPixelWidth * 12
                    width: height
                    isMapButton: false
                    enabled: m2Manager.mounted && !m2Manager.binding
                    onActivated: {
                        isTriggerBind = true
                        m2Manager.pair()
                        _enableDelayTiggerWaiting = true
                        enableDelayTiggerWaiting.restart()
                    }
                }
                Row {
                    anchors.top: pairDelayButton.bottom
                    anchors.topMargin: ScreenTools.defaultFontPixelHeight * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: ScreenTools.defaultFontPixelHeight
                    visible: !_connected && (m2Manager.binding || _enableDelayTiggerWaiting)
                    QGCLabel {
                        text:                   qsTr("Binding")
                        font.pointSize:         ScreenTools.mediumFontPointSize
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    CustomBusyIndicator {
                        width: ScreenTools.defaultFontPixelHeight * 2
                        height: ScreenTools.defaultFontPixelHeight * 2
                        anchors.verticalCenter: parent.verticalCenter
                        running: parent.visible
                        firstColor: qgcPal.text
                        secondColor: qgcPal.windowShade
                        pointColor: qgcPal.windowShade
                    }
                }
                Row {
                    anchors.top: pairDelayButton.bottom
                    anchors.topMargin: ScreenTools.defaultFontPixelHeight * 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: ScreenTools.defaultFontPixelHeight
                    visible: _connected
                    QGCLabel {
                        text:                   qsTr("Bind Success")
                        font.pointSize:         ScreenTools.mediumFontPointSize
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    QGCColoredImage {
                        width: ScreenTools.defaultFontPixelHeight * 2
                        height: width
                        source: _connected ? "qrc:/res/yes.svg" : "qrc:/res/no.svg"
                        color: _connected ? qgcPal.colorGreen : qgcPal.colorRed
                        sourceSize.height: height
                        sourceSize.width:  width
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    onVisibleChanged: {
                        if(visible && _connected && isTriggerBind) {
                            m2PairGuideCloseTimer.restart()
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill:                   parent
        anchors.margins:                -ScreenTools.defaultFontPixelHeight * 0.66
        onClicked: {
            if (_connected) {
                mainWindow.showIndicatorPopup(_root, m2RssiInfo)
            } else {
                mainWindow.hideIndicatorPopup()
                m2PairGuideComponent.createObject(mainWindow).open()
            }
        }
    }
}
