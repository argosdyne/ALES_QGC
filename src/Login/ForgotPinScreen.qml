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
    id: forgotPinPage

    signal backClicked()
    signal recoveryVerified()

    property int keyLength: 24
    property string keyText: ""
    property bool locked: false
    readonly property string _lockoutScope: "forgot_pin"

    background: Rectangle {
        color: "#222222"
        opacity: 0
        radius: 16
    }

    Timer {
        id: lockoutTimer
        interval: 1000
        running: locked
        repeat: true

        onTriggered: {
            locked = securityManager.isLockedForScope(forgotPinPage._lockoutScope)
            if (locked) {
                var until = securityManager.lockoutUntilForScope(forgotPinPage._lockoutScope)
                var remaining = Math.max(0, Math.ceil((until - Date.now()) / 1000))
                errorText.text = "Locked. Try in " + remaining + "s"
                errorText.visible = true
                errorText.color = "#ff5c5c"
            } else {
                lockoutTimer.stop()
                errorText.visible = false
            }
        }
    }

    Connections {
        target: securityManager

        function onLockoutStartedForScope(scope, until) {
            if (scope === forgotPinPage._lockoutScope) {
                locked = true
                lockoutTimer.start()
            }
        }

        function onLockoutClearedForScope(scope) {
            if (scope === forgotPinPage._lockoutScope) {
                locked = false
                lockoutTimer.stop()
                errorText.visible = false
            }
        }
    }

    function _normalizedKey(raw) {
        var upper = raw.toUpperCase()
        var out = ""
        for (var i = 0; i < upper.length; i++) {
            var c = upper.charAt(i)
            if (c >= "A" && c <= "Z") {
                out += c
            }
        }
        return out
    }

    function _displayKey() {
        var n = _normalizedKey(keyText)
        var chunks = []
        for (var i = 0; i < n.length; i += 4) {
            chunks.push(n.slice(i, i + 4))
        }
        return chunks.join(" - ")
    }

    function verifyRecovery() {
        if (securityManager.isLockedForScope(forgotPinPage._lockoutScope)) {
            locked = true
            lockoutTimer.start()
            return
        }

        var normalized = _normalizedKey(keyText)
        if (normalized.length !== keyLength) {
            securityManager.recordFailedAttemptForScope(forgotPinPage._lockoutScope)
            if (securityManager.isLockedForScope(forgotPinPage._lockoutScope)) {
                locked = true
                lockoutTimer.start()
            } else {
                errorText.text = "In correct PIN"
                errorText.visible = true
                errorText.color = "#ff5c5c"
            }
            return
        }

        var ok = false
        try {
            ok = securityManager.verifyRecoveryKey(normalized)
        } catch (e) {
            ok = false
        }

        if (ok) {
            securityManager.resetFailedAttemptsForScope(forgotPinPage._lockoutScope)
            errorText.visible = false
            forgotPinPage.recoveryVerified()
        } else {
            securityManager.recordFailedAttemptForScope(forgotPinPage._lockoutScope)
            if (securityManager.isLockedForScope(forgotPinPage._lockoutScope)) {
                locked = true
                lockoutTimer.start()
            } else {
                errorText.text = "In correct PIN"
                errorText.visible = true
                errorText.color = "#ff5c5c"
            }
        }
    }

    Item {
        id: content
        width: 740
        height: 500
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(20, Math.round((parent.height - 620) / 2))

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "#1C2435"
            border.width: 1
            border.color: "#33425A"
            opacity: 0.96
        }

        Text {
            x: 24
            y: 22
            text: qsTr("< Back")
            color: "#8FB5D5"
            font.family: "Roboto"
            font.pixelSize: 24
            font.bold: false

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: forgotPinPage.backClicked()
            }
        }

        Text {
            x: 24
            y: 86
            text: qsTr("Forgot PIN")
            color: "#EAF1FF"
            font.family: "Roboto"
            font.pixelSize: 42
            font.bold: true
        }

        Text {
            x: 24
            y: 150
            width: 690
            text: qsTr("Enter the 24-character Recovery Key provided during initial setup.")
            color: "#AEBED7"
            font.family: "Roboto"
            font.pixelSize: 23
            wrapMode: Text.WordWrap
        }

        Rectangle {
            id: inputBox
            x: 24
            y: 210
            width: 692
            height: 64
            radius: 8
            color: "#1A2231"
            border.width: 1
            border.color: hiddenInput.activeFocus ? "#2A9DFF" : "#3E4C63"

            TextInput {
                id: hiddenInput
                width: 1
                height: 1
                opacity: 0
                focus: true
                maximumLength: 24
                onTextChanged: keyText = text
                Keys.onPressed: {
                    if (event.text.length === 1) {
                        var upper = event.text.toUpperCase()
                        if (upper >= "A" && upper <= "Z") {
                            if (_normalizedKey(keyText).length < 24) {
                                keyText = _normalizedKey(keyText) + upper
                                hiddenInput.text = _normalizedKey(keyText)
                            }
                            event.accepted = true
                            return
                        }
                    }

                    if (event.key === Qt.Key_Backspace) {
                        var n = _normalizedKey(keyText)
                        if (n.length > 0) {
                            n = n.slice(0, n.length - 1)
                            keyText = n
                            hiddenInput.text = n
                        }
                        event.accepted = true
                    }
                }
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignLeft
                text: _displayKey().length > 0 ? _displayKey() : "____ - ____ - ____ - ____ - ____ - ____"
                color: _displayKey().length > 0 ? "#EAF1FF" : "#8A96AA"
                font.family: "Roboto"
                font.pixelSize: 28
                MouseArea {
                    anchors.fill: parent
                    onClicked: hiddenInput.forceActiveFocus()
                }
            }
        }

        Rectangle {
            x: 24
            y: 308
            width: 692
            height: 56
            radius: 6
            color: verifyMouse.pressed ? "#226EBD" : "#2B82D8"
            opacity: locked ? 0.5 : 1.0

            Text {
                anchors.centerIn: parent
                text: qsTr("VERIFY KEY")
                color: "#EAF1FF"
                font.family: "Roboto"
                font.pixelSize: 26
                font.bold: true
            }

            MouseArea {
                id: verifyMouse
                anchors.fill: parent
                enabled: !locked
                onClicked: verifyRecovery()
            }
        }

        Text {
            id: errorText
            x: 24
            y: 378
            width: 692
            visible: false
            text: ""
            color: "#ff5c5c"
            font.family: "Roboto"
            font.pixelSize: 22
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            x: 24
            y: 420
            width: 692
            height: 60
            radius: 6
            color: "#1E2A3B"
            border.width: 1
            border.color: "#2F3E56"

            Text {
                anchors.centerIn: parent
                width: 660
                wrapMode: Text.WordWrap
                text: qsTr("If you lost the Recovery Key, contact system admin for a Factory Security Reset.")
                color: "#C2CDE0"
                font.family: "Roboto"
                font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Component.onCompleted: {
        if (securityManager.isLockedForScope(forgotPinPage._lockoutScope)) {
            locked = true
            lockoutTimer.start()
        }
        hiddenInput.forceActiveFocus()
    }
}
