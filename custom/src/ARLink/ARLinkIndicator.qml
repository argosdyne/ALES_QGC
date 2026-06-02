import QtQuick          2.11
import QtQuick.Layouts  1.11
import QtQuick.Dialogs  1.2

import QGroundControl                       1.0
import QGroundControl.Controls              1.0
import QGroundControl.MultiVehicleManager   1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.Palette               1.0
import QGroundControl.FactSystem            1.0
import QGroundControl.FactControls          1.0

import CustomQmlInterface                   1.0
import Custom.Widgets                       1.0

Item {
    id:  _root
    width:          signalRow.width

    QGCPalette { id: qgcPal }
    property var arManager:     CustomQmlInterface.arManager
    property bool _connected:   arManager.connected && arManager.mounted && !arManager.binding
    property var  _rssiA:       arManager.rssiA
    property var  _rssiB:       arManager.rssiB
    property var  _skyRssiA:    arManager.skyRssiA
    property var  _skyRssiB:    arManager.skyRssiB
    property var  _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool _isDoodle: arManager.version == "DoodleLabs ubus"

    Component {
        id:                                     arRssiInfo
        Rectangle {
            id:                                 arInfoRect
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
                        text:                   qsTr("RSSI:")
                        color:                  qgcPal.text
                    }
                    QGCLabel {
                        text:                   _connected ? _rssiA * -1 + " / " + _rssiA * -1 + " dB" : qsTr("N/A")
                        color:                  qgcPal.text
                    }

                    QGCLabel {
                        text:                   _isDoodle ? qsTr("Peer RSSI:") : qsTr("Sky RSSI:")
                        color:                  qgcPal.text
                    }
                    QGCLabel {
                        text:                   _connected ? _skyRssiA * -1 + " / " + _skyRssiB * -1 + " dB" : qsTr("N/A")
                        color:                  qgcPal.text
                    }

                    QGCLabel {
                        text:                   qsTr("Main Link:")
                        color:                  qgcPal.text
                        visible:                _activeVehicle
                    }
                    QGCLabel {
                        text:                   _activeVehicle ? (_activeVehicle.mainLinkName + (_activeVehicle.rcOnUDP ? "+" : "")) : qsTr("N/A")
                        color:                  qgcPal.text
                        visible:                _activeVehicle
                    }
                }

                QGCButton {
                    text:                       qsTr("Start Pair")
                    visible:                    !_isDoodle
                    width:                      ScreenTools.defaultFontPixelWidth * 15
                    anchors.horizontalCenter:   parent.horizontalCenter
                    onClicked: {
                        mainWindow.hideIndicatorPopup()
                        mainWindow.showPopupDialogFromComponent(arPairGuideComponent)
                    }
                }
            }
        }
    }

function getSignalStrength(rssi) {
    if (_isDoodle) {
    if(rssi > 95) return 0;        // Link lost - 0 bars
    else if(rssi > 85) return 30;  // Poor - 1 bar
    else if(rssi > 78) return 40;  // Weak - 2 bars
    else if(rssi > 70) return 60;  // Fair - 3 bars
    else if(rssi > 50) return 85;  // Good - 4 bars
    else return 100;               // Excellent (≤50) + Too Strong (<30) - 5 bars
    }
    // Enpulse: original thresholds        if(rssi < 10) return 0;
    if(rssi < 10) return 0;
    if(rssi >= 108) return 30;
    else if(rssi >= 103) return 50;
    else if(rssi >= 98) return 70;
    else if(rssi >= 91) return 85;
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
            percent:                _connected ? getSignalStrength(Math.min(_rssiA, _rssiB)) : 0
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            QGCLabel {
                id:                     frequencyLable
                text:                   _isDoodle ? "2.4G" : (arManager.is24G ? "2.4G" : "5.8G")
                font.pointSize:         ScreenTools.defaultFontPointSize
            }
            QGCLabel {
                id:                     linkNameLable
                text:                   _isDoodle ? "DoodleLab" : "Enpulse"
                font.pointSize:         ScreenTools.defaultFontPointSize
            }
        }
    }

    Component {
        id: arPairGuideComponent
        QGCPopupDialog {
            id:         arPairGuide
            title:      qsTr("Data Link Pair")
            buttons:    StandardButton.Close
            property bool isTriggerBind: false
            Timer {
                id: arPairGuideCloseTimer
                interval: 500
                running: false
                repeat: false
                onTriggered: arPairGuide.hideDialog()
            }
            RowLayout {
                id:                                     arPairRect
                width:                                  mainWindow.width * 0.8
                height:                                 mainWindow.height * 0.6
                QGCLabel {
                    text:                   qsTr("Step 1")
                    font.bold:              true
                    Layout.alignment:       Qt.AlignLeft | Qt.AlignTop
                    font.pointSize:         ScreenTools.mediumFontPointSize
                }
                Item {
                    Layout.alignment:   Qt.AlignVCenter | Qt.AlignHCenter
                    Layout.fillWidth:   true
                    Layout.preferredHeight: parent.height
                    QGCLabel {
                        text: qsTr("Quick press 6 times in 3 second.")
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 1.5
                    }
                    Image {
                        id:                 aircraftBindTipImage
                        anchors.margins:    ScreenTools.defaultFontPixelHeight * 3
                        anchors.fill:       parent
                        source:             "qrc:/custom/img/png/aircraftBindTip.png"
                        mipmap:             true
                        fillMode:           Image.PreserveAspectFit
                        sourceSize.height:  height
                    }
                }
                QGCLabel {
                    text:                   qsTr("Step 2")
                    font.bold:              true
                    Layout.alignment:       Qt.AlignLeft | Qt.AlignTop
                    font.pointSize:         ScreenTools.mediumFontPointSize
                }
                Item {
                    Layout.alignment:   Qt.AlignVCenter | Qt.AlignHCenter
                    Layout.preferredWidth: parent.width * 0.35
                    Layout.preferredHeight: parent.height
                    QGCLabel {
                        wrapMode: TextEdit.WordWrap
                        text: qsTr("Press and hold this, the remote control will enter the binding state.")
                        width: parent.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: -ScreenTools.defaultFontPixelHeight
                        anchors.top: parent.top
                        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 1.5
                    }
                    CustomDelayButton {
                        id: pairDelayButton
                        text: qsTr("Trigger Bind")
                        anchors.centerIn: parent
                        iconSource: "qrc:/custom/img/PairingButton.svg"
                        anchors.horizontalCenterOffset: -ScreenTools.defaultFontPixelHeight
                        height: ScreenTools.defaultFontPixelWidth * 12
                        width: height
                        isMapButton: false
                        enabled: arManager.mounted && !arManager.binding
                        onActivated: {
                            isTriggerBind = true
                            arManager.pair()
                        }
                    }
                    Row {
                        anchors.top: pairDelayButton.bottom
                        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: -ScreenTools.defaultFontPixelHeight
                        spacing: ScreenTools.defaultFontPixelHeight
                        visible: arManager.binding
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
                        anchors.horizontalCenterOffset: -ScreenTools.defaultFontPixelHeight
                        spacing: ScreenTools.defaultFontPixelHeight
                        visible: (_connected || arManager.bindTimeout)
                        QGCLabel {
                            text:                   _connected ? qsTr("Bind Success") : qsTr("Bind Timeout")
                            font.pointSize:         ScreenTools.mediumFontPointSize
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        QGCColoredImage {
                            width: ScreenTools.defaultFontPixelHeight * 2
                            height: width
                            source: _connected ? "qrc:/custom/img/yes.svg" : "qrc:/custom/img/no.svg"
                            color: _connected ? qgcPal.colorGreen : qgcPal.colorRed
                            sourceSize.height: height
                            sourceSize.width:  width
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        onVisibleChanged: {
                            if(visible && _connected && isTriggerBind) {
                                arPairGuideCloseTimer.restart()
                            }
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
                mainWindow.showIndicatorPopup(_root, arRssiInfo)
            } else if (!_isDoodle) {                
                mainWindow.hideIndicatorPopup()
                mainWindow.showCustomMessageDialog(arPairGuideComponent)
            }
        }
    }
}
