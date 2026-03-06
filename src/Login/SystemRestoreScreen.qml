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
    id: restorePage

    signal cancelClicked()
    signal confirmRestoreClicked()

    property string _requiredPhrase: "RESTORE SYSTEM"
    property bool locked: false
    readonly property string _lockoutScope: "system_restore"

    background: Rectangle {
        color: "#0E1725"
        opacity: 0
        radius: 16
    }

    Timer {
        id: lockoutTimer
        interval: 1000
        running: locked
        repeat: true

        onTriggered: {
            locked = securityManager.isLockedForScope(restorePage._lockoutScope)
            if (locked) {
                var until = securityManager.lockoutUntilForScope(restorePage._lockoutScope)
                var remaining = Math.max(0, Math.ceil((until - Date.now()) / 1000))
                feedbackText.text = "Locked. Try in " + remaining + "s"
                feedbackText.visible = true
            } else {
                lockoutTimer.stop()
                feedbackText.visible = false
            }
        }
    }

    Connections {
        target: securityManager

        function onLockoutStartedForScope(scope, until) {
            if (scope === restorePage._lockoutScope) {
                locked = true
                lockoutTimer.start()
            }
        }

        function onLockoutClearedForScope(scope) {
            if (scope === restorePage._lockoutScope) {
                locked = false
                lockoutTimer.stop()
                feedbackText.visible = false
            }
        }
    }

    function _isPhraseValid() {
        return phraseInput.text.trim().toUpperCase() === _requiredPhrase
    }

    function _confirmRestore() {
        if (securityManager.isLockedForScope(restorePage._lockoutScope)) {
            locked = true
            lockoutTimer.start()
            return
        }

        if (_isPhraseValid()) {
            securityManager.resetFailedAttemptsForScope(restorePage._lockoutScope)
            feedbackText.visible = false
            confirmRestoreClicked()
        } else {
            securityManager.recordFailedAttemptForScope(restorePage._lockoutScope)
            if (securityManager.isLockedForScope(restorePage._lockoutScope)) {
                locked = true
                lockoutTimer.start()
            } else {
                feedbackText.text = "Incorrect phrase"
                feedbackText.visible = true
            }
        }
    }

    Item {
        id: content
        width: 760
        height: 560
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(20, Math.round((parent.height - 620) / 2))

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: "#101A2A"
            border.width: 1
            border.color: "#22334D"
            opacity: 0.98
        }

        Text {
            x: 20
            y: 20
            text: qsTr("[!] SYSTEM RESTORE")
            color: "#DDE7F7"
            font.family: "Roboto"
            font.pixelSize: 36
            font.bold: true
        }

        Rectangle {
            x: 20
            y: 72
            width: 720
            height: 1
            color: "#2A3C58"
        }

        Text {
            x: 20
            y: 94
            width: 720
            wrapMode: Text.WordWrap
            text: qsTr("You are performing an Admin-level security restore.\nThis action will perform the following:\n- Delete all currently configured PINs.\n- Delete all security keys in the Keystore.\n- Require a full initial setup again.")
            color: "#DBE6F9"
            font.family: "Roboto"
            font.pixelSize: 28
            lineHeight: 1.2
        }

        Text {
            x: 20
            y: 292
            width: 720
            text: qsTr("Please type the exact phrase from System Admin")
            color: "#D5E3FA"
            font.family: "Roboto"
            font.pixelSize: 25
        }

        Rectangle {
            id: phraseBox
            x: 20
            y: 370
            width: 720
            height: 56
            radius: 5
            color: "#0A1322"
            border.width: 2
            border.color: phraseInput.activeFocus ? "#34D0FF" : "#2F4E73"

            TextField {
                id: phraseInput
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                color: "#E8F3FF"
                placeholderText: qsTr("Type phrase here")
                placeholderTextColor: "#6F8EB4"
                font.family: "Roboto"
                font.pixelSize: 24
                background: Item {}
                onTextChanged: feedbackText.visible = false
            }
        }

        Text {
            id: feedbackText
            x: 20
            y: 435
            width: 720
            visible: false
            color: "#FF6E6E"
            font.family: "Roboto"
            font.pixelSize: 21
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            x: 180
            y: 480
            width: 170
            height: 48
            radius: 6
            color: cancelMouse.pressed ? "#565F71" : "#6E788C"

            Text {
                anchors.centerIn: parent
                text: qsTr("[ CANCEL ]")
                color: "#F2F5FF"
                font.family: "Roboto"
                font.pixelSize: 23
                font.bold: true
            }

            MouseArea {
                id: cancelMouse
                anchors.fill: parent
                onClicked: cancelClicked()
            }
        }

        Rectangle {
            x: 390
            y: 480
            width: 250
            height: 48
            radius: 6
            color: confirmMouse.pressed ? "#2BC2DF" : "#35D9F5"
            opacity: locked ? 0.5 : 1.0

            Text {
                anchors.centerIn: parent
                text: qsTr("[ CONFIRM DEFAULTS ]")
                color: "#08364A"
                font.family: "Roboto"
                font.pixelSize: 23
                font.bold: true
            }

            MouseArea {
                id: confirmMouse
                anchors.fill: parent
                enabled: !locked
                onClicked: _confirmRestore()
            }
        }
    }

    Component.onCompleted: {
        if (securityManager.isLockedForScope(restorePage._lockoutScope)) {
            locked = true
            lockoutTimer.start()
        }
    }
}
