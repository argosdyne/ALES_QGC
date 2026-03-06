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

Page {
    id: recoveryPage

    signal continueToLoginClicked()

    property string recoveryKeyText: ""
    property string messageText: ""
    property bool hasRecoveryKey: false
    property int _contentBlockHeight: 560

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
            messageText = "Save this key offline. This is the ONLY way to recover access if you forget your PIN."
        } else {
            recoveryKeyText = ""
            hasRecoveryKey = false
            messageText = "Failed to generate recovery key. Please restart registration."
        }
    }

    Component.onCompleted: generateRecoveryKeyIfNeeded()

    Item {
        id: content
        width: 640
        height: 390
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(20, Math.round((parent.height - recoveryPage._contentBlockHeight) / 2))

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: "#3A3E4A"
            border.width: 1
            border.color: "#555B67"
        }

        Row {
            id: titleRow
            x: 24
            y: 18
            spacing: 12

            Text {
                text: "!"
                color: "#FFC13D"
                font.pixelSize: 26
            }
            Text {
                text: "RECOVERY KEY GENERATED"
                color: "#F1F3F7"
                font.family: "Roboto"
                font.pixelSize: 30
                font.bold: true
            }
        }

        Text {
            id: infoText
            x: 24
            y: 78
            width: 592
            text: messageText
            color: "#D7DBE3"
            font.family: "Roboto"
            font.pixelSize: 23
            wrapMode: Text.WordWrap
        }

        Rectangle {
            id: keyBox
            x: 24
            y: 158
            width: 592
            height: 72
            radius: 4
            color: "#434855"
            border.width: 1
            border.color: "#5E6574"

            TextInput {
                id: recoveryKeyField
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                readOnly: true
                selectByMouse: true
                text: recoveryKeyText
                color: "#F1F3F7"
                font.family: "Roboto"
                font.pixelSize: 28
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Rectangle {
            id: copyButton
            x: (content.width - width) / 2
            y: 250
            width: 300
            height: 58
            radius: 4
            color: copyMouse.pressed ? "#4A5E88" : "#6078AA"
            border.width: 1
            border.color: "#7A91BF"

            Text {
                anchors.centerIn: parent
                text: qsTr("Copy to Clipboard")
                color: "#F7FAFF"
                font.family: "Roboto"
                font.pixelSize: 24
                font.bold: true
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
            id: continueButton
            x: 24
            y: 325
            width: 592
            height: 52
            radius: 4
            color: continueMouse.pressed ? "#5A892B" : "#74A93A"
            border.width: 1
            border.color: "#9ACC59"
            opacity: hasRecoveryKey ? 1.0 : 0.5

            Text {
                anchors.centerIn: parent
                text: qsTr("I HAVE SAVED THE KEY - ENTER Login Page")
                color: "#FFFFFF"
                font.family: "Roboto"
                font.pixelSize: 20
                font.bold: true
            }

            MouseArea {
                id: continueMouse
                anchors.fill: parent
                enabled: hasRecoveryKey
                onClicked: recoveryPage.continueToLoginClicked()
            }
        }
    }
}
