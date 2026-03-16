/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick 2.7
import QtQuick.Controls 2.0

import QGroundControl.ScreenTools 1.0

Page {
    id: recoveryPage

    signal continueToLoginClicked()

    property string recoveryKeyText: ""
    property string messageText: ""
    property bool hasRecoveryKey: false
    property real _uiScale: ScreenTools.isMobile ? 1.1 : 0.6
    property int _dialogMaxWidth: _s(1019)

    background: Rectangle {
        color: "#222222"
        opacity: 0
        radius: 16
    }

    function generateRecoveryKeyIfNeeded() {
        if (hasRecoveryKey) {
            return
        }

        var generated = ""
        try {
            generated = securityManager.generateAndStoreRecoveryKey()
        } catch (e) {
            generated = ""
        }

        if (generated && generated.length > 0) {
            recoveryKeyText = generated
            hasRecoveryKey = true
            messageText = "Save this key offline. If you forget your PIN,\nthis is the only way to recover access."
        } else {
            recoveryKeyText = ""
            hasRecoveryKey = false
            messageText = "Failed to generate recovery key. Please restart registration."
        }
    }
    function _s(px) { return Math.round(px * _uiScale) }

    Component.onCompleted: generateRecoveryKeyIfNeeded()

    Item {
        id: content
        width: Math.min(recoveryPage._dialogMaxWidth, parent.width - _s(24))
        height: _s(627)
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(_s(12), Math.round((parent.height - height) / 2))

        Rectangle {
            anchors.fill: parent
            radius: _s(20)
            color: "#2D2D2D"
            border.width: 1
            border.color: "#707070"
        }

        Rectangle {
            id: titleBar
            x: 0
            y: 0
            radius: _s(20)
            width: parent.width
            height: _s(84)
            color: "#202528"
            border.width: 1
            border.color: "#707070"

            Image {
                x: _s(33)
                y: _s(19)
                width: _s(52)
                height: _s(43)
                source: "/custom/img/caution.svg"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                x: _s(94)
                anchors.verticalCenter: parent.verticalCenter
                text: "Recovery Key Generated"
                color: "#FFFFFF"
                font.family: "Roboto"
                font.pixelSize: _s(40)
                font.bold: true
            }

      Image {
                x: _s(952)
                anchors.verticalCenter: parent.verticalCenter
                width: _s(32)
                height: _s(32)
                source: "/custom/img/cancel.svg"
                fillMode: Image.PreserveAspectFit

                MouseArea {
                    anchors.centerIn: parent
                    width: _s(70)
                    height: _s(70)
                    onClicked: recoveryPage.continueToLoginClicked()
                }
            }

            // Keep only top/sides rounded border in the title bar.
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width - 2
                x: 1
                height: _s(20)
                color: parent.color
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width - 2
                x: 1
                height: 1
                color: parent.border.color
            }
            
        }

        Text {
            id: infoText
            x: 0
            y: _s(135)
            width: parent.width
            height: _s(76)
            text: messageText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: "#AEAEAE"
            font.family: "Roboto"
            font.pixelSize: _s(32)
            wrapMode: Text.WordWrap
        }

        Text {
            x: _s(81)
            y: _s(247)
            text: qsTr("Recovery Key")
            color: "#AEAEAE"
            font.family: "Roboto"
            font.pixelSize: _s(24)
        }

        Rectangle {
            id: keyBox
            x: _s(81)
            y: _s(285)
            width: Math.min(_s(858), parent.width - _s(162))
            height: _s(80)
            radius: 4
            color: "#2D2D2D"
            border.width: 2
            border.color: "#FFFFFF"

            TextInput {
                id: recoveryKeyField
                anchors.fill: parent
                anchors.centerIn: parent
                readOnly: true
                selectByMouse: true
                text: recoveryKeyText
                color: "#E8EDF3"
                font.family: "Roboto"
                font.pixelSize: _s(34)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Rectangle {
            id: copyButton
            x: _s(256)
            y: _s(397)
            width: Math.min(_s(508), parent.width - _s(24))
            height: _s(71)
            radius: 4
            color: copyMouse.pressed ? "#4a5260" : "#3d4450"
            opacity: hasRecoveryKey ? 1.0 : 0.6

            Text {
                anchors.centerIn: parent
                text: qsTr("Copy to Clipboard")
                color: "#FFFFFF"
                font.styleName: "Medium"
                font.family: "Roboto"
                font.pixelSize: _s(28)
            }

            MouseArea {
                id: copyMouse
                anchors.fill: parent
                enabled: hasRecoveryKey
                onClicked: {
                    recoveryKeyField.selectAll()
                    recoveryKeyField.copy()
                    recoveryKeyField.deselect()
                }
            }
        }

        Rectangle {
            id: saveButton
            x: _s(256)
            y: _s(501)
            width: Math.min(_s(508), parent.width - _s(24))
            height: _s(71)
            radius: 4
            color: saveMouse.pressed ? "#0b8a7a" : "#00826F"
            opacity: hasRecoveryKey ? 1.0 : 0.5

            Text {
                anchors.centerIn: parent
                text: qsTr("I have saved the Key")
                color: "#FFFFFF"
                font.styleName: "Medium"
                font.family: "Roboto"
                font.pixelSize: _s(28)
            }

            MouseArea {
                id: saveMouse
                anchors.fill: parent
                enabled: hasRecoveryKey
                onClicked: recoveryPage.continueToLoginClicked()
            }
        }
    }
}
