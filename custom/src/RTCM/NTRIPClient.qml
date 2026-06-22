import QtQuick          2.3
import QtQuick.Controls 2.4
import QtQuick.Layouts  1.11
import QtQuick.Dialogs  1.3

import QGroundControl                       1.0
import QGroundControl.Controllers           1.0
import QGroundControl.Controls              1.0
import QGroundControl.FactControls          1.0
import QGroundControl.FactSystem            1.0
import QGroundControl.Palette               1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.SettingsManager       1.0

import CustomQmlInterface                   1.0

Column {
    id: root
    clip: true

    property real _margins: ScreenTools.defaultFontPixelHeight * 0.5
    property var  _ntripSource: CustomQmlInterface.codevRTCMManager.rtcmSource

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }

    function validateNtripServerHost(hostText) {
        return /^[a-zA-Z0-9.-]{1,253}$/.test(hostText) ? "" : qsTr("NTRIP Server Host must be a valid hostname or IP address.")
    }

    MessageDialog {
        id:                 ntripHostErrorDialog
        title:              qsTr("Invalid NTRIP Server Host")
        text:               qsTr("NTRIP Server Host must be a valid hostname or IP address.")
        standardButtons:    StandardButton.Ok
    }

    GridLayout {
        id:     outerItem
        anchors.margins:    ScreenTools.defaultFontPixelHeight
        columnSpacing:      ScreenTools.defaultFontPixelHeight
        anchors.horizontalCenter: parent.horizontalCenter
        columns: 2
        QGCLabel {
            text:           qsTr("Host:")
            Layout.minimumWidth: _labelWidth
        }
        FactTextField {
            id:             hostField
            fact:           _ntripSource.host
            Layout.minimumWidth: _valueWidth
            customValidateFunction: validateNtripServerHost
        }
        QGCLabel {
            text:           qsTr("Port:")
            Layout.minimumWidth: _labelWidth
        }
        FactTextField {
            fact:           _ntripSource.port
            Layout.minimumWidth: _valueWidth

            onAccepted: {
                if (validateNtripServerHost(hostField.text) !== "") {
                    ntripHostErrorDialog.open()
                    return
                }
                _ntripSource.onReadyRead()
            }
        }
        QGCLabel {
            text:           qsTr("Mountpoint:")
            Layout.minimumWidth: _labelWidth
        }
        //FactTextField {
        //    fact:           _ntripSource.mountpoint
        //    Layout.minimumWidth: _valueWidth
        //}

        //QGCCombobox
         QGCComboBox {
            id: cbMountPoint
            Layout.minimumWidth: _labelWidth
            model : _ntripSource.contentList
            //model: _ntripSource.mountPointList

            //When Selected Item changed call this function
            onActivated: {
                    if (index !== -1) {
                        var selectedItem = model[index]; // ���õ� ������ ��������
                        // C++�� ���õ� ������ ������
                        _ntripSource.mountpoint.value = selectedItem;
                    }
                }
        }
        QGCLabel {
            text:           qsTr("User:")
            Layout.minimumWidth: _labelWidth
        }
        FactTextField {
            fact:           _ntripSource.user
            Layout.minimumWidth: _valueWidth
        }
        QGCLabel {
            text:           qsTr("Password:")
            Layout.minimumWidth: _labelWidth
        }
        FactTextField {
            fact:           _ntripSource.passwd
            Layout.minimumWidth: _valueWidth
        }
        RowLayout {
            Layout.columnSpan: 2
            QGCButton {
                text: _ntripSource.isLogIn ? qsTr("Log out") : qsTr("Log in")
                Layout.fillWidth: true
                enabled: hostField.text !== "" &&
                         _ntripSource.mountpoint.valueString !== "" &&
                         _ntripSource.user.valueString !== "" &&
                         _ntripSource.passwd.valueString !== "" &&
                         !_ntripSource.isLogIning
                onClicked: {
                    if(!_ntripSource.isLogIn) {
                        if (validateNtripServerHost(hostField.text) !== "") {
                            ntripHostErrorDialog.open()
                            return
                        }
                        _ntripSource.logIn()
                    } else {
                        _ntripSource.logOut()
                    }
                }
            }
            QGCColoredImage {
                id:                 busyIndicator
                height:             ScreenTools.defaultFontPixelHeight
                width:              height
                source:             "/qmlimages/MapSync.svg"
                sourceSize.height:  height
                fillMode:           Image.PreserveAspectFit
                mipmap:             true
                smooth:             true
                color:              qgcPal.colorGreen
                visible:            _ntripSource.isLogIning
                RotationAnimation on rotation {
                    loops:          Animation.Infinite
                    from:           360
                    to:             0
                    duration:       740
                    running:        busyIndicator.visible
                }
            }
            QGCColoredImage {
                width: ScreenTools.defaultFontPixelHeight
                height: width
                visible: !_ntripSource.isLogIning
                source: _ntripSource.isLogIn ? "qrc:/custom/img/yes.svg" : "qrc:/custom/img/no.svg"
                color: _ntripSource.isLogIn ? qgcPal.colorGreen : qgcPal.colorRed
                sourceSize.height: height
                sourceSize.width:  width
            }
        }

        QGCLabel {
            text:           qsTr("GPGGA Hz:")
            Layout.minimumWidth: _labelWidth
        }
        FactComboBox {
            fact:           _ntripSource.gpggamessageHz
            indexModel:     false
            Layout.minimumWidth: _valueWidth
        }

        QGCTextField {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            enabled: !_ntripSource.autoUpdateGPGGA.rawValue
            text: _ntripSource.gpggamessage.valueString
            onEditingFinished: {
                _ntripSource.gpggamessage.rawValue = text
            }
        }

        RowLayout {
            Layout.columnSpan: 2
            QGCCheckBox {
                Layout.fillWidth: true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight
                text:           _ntripSource.autoUpdateGPGGA.shortDescription
                checked:        _ntripSource.autoUpdateGPGGA.rawValue
                visible:        true
                onClicked:      _ntripSource.autoUpdateGPGGA.rawValue = checked
            }
            QGCButton {
                text: qsTr("Get from Vehicle")
                Layout.fillWidth: true
                enabled: !_ntripSource.autoUpdateGPGGA.rawValue
                onClicked: {
                    _ntripSource.getFromVehicle()
                }
            }
        }

//        ColumnLayout {
//            id:                         settingsColumn
//            anchors.horizontalCenter:   parent.horizontalCenter

//            // ----- GPGGA & RTCM Message ------
//            GCLabel {
//                text:       qsTr("GPGGA & RTCM Message")
//            }
//            Rectangle {
//                Layout.preferredHeight: gpggaColumn.height + (ScreenTools.defaultFontPixelWidth * 2)
//                Layout.preferredWidth:  gpggaColumn.width + (ScreenTools.defaultFontPixelWidth * 2)
//                color:                  gcPal.windowShade
//                Layout.fillWidth:       true

//                ColumnLayout {
//                    id:                         gpggaColumn
//                    anchors.topMargin:          ScreenTools.defaultFontPixelWidth
//                    anchors.top:                parent.top
//                    Layout.fillWidth:           false
//                    anchors.horizontalCenter:   parent.horizontalCenter

//                    FactItemEditor {
//                        Layout.preferredWidth:  _fieldWidth
//                        fact:                   _ntripSource.sendMaxRTCMHz
//                        titleLabelW:            _fieldWidth * 0.5
//                    }

//                    FactItemEditor {
//                        Layout.preferredWidth:  _fieldWidth
//                        fact:                   _ntripSource.gpggamessageHz
//                        titleLabelW:            _fieldWidth * 0.5
//                    }

//                    QGCTextField {
//                        Layout.preferredWidth: _fieldWidth
//                        enabled: !_ntripSource.autoUpdateGPGGA.rawValue
//                        text: _ntripSource.gpggamessage.valueString
//                        onEditingFinished: {
//                            _ntripSource.gpggamessage.rawValue = text
//                        }
//                    }

//                    RowLayout {
//                        QGCCheckBox {
//                            Layout.fillWidth: true
//                            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight
//                            text:           _ntripSource.autoUpdateGPGGA.description
//                            checked:        _ntripSource.autoUpdateGPGGA.rawValue
//                            visible:        true
//                            onClicked:      _ntripSource.autoUpdateGPGGA.rawValue = checked
//                        }
//                        QGCButton {
//                            text: qsTr("Get from Vehicle")
//                            Layout.fillWidth: true
//                            enabled: !_ntripSource.autoUpdateGPGGA.rawValue
//                            onClicked: {
//                                _ntripSource.getFromVehicle()
//                            }
//                        }
//                    }
//                }
//            }
//        }
    }
}
