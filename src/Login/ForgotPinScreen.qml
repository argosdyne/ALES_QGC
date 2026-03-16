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
    id: forgotPinPage

    signal backClicked()
    signal recoveryVerified()

    property int keyLength: 24
    property string keyText: ""
    property bool locked: false
    property bool keyBoxFocused: false
    readonly property string _lockoutScope: "forgot_pin"
    property real _uiScale: ScreenTools.isMobile ? 1.1 : 0.6

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
        var template = "____ - ____ - ____ - ____ - ____ - ____"
        var chars = template.split("")
        var cursor = 0

        for (var i = 0; i < chars.length; i++) {
            if (chars[i] === "_" && cursor < n.length) {
                chars[i] = n.charAt(cursor)
                cursor++
            }
        }

        return chars.join("")
    }

    // Formatted text with " - " separators matching the display layout exactly
    function _formattedKey(normalized) {
        if (normalized.length === 0) return ""
        var result = ""
        for (var i = 0; i < normalized.length; i++) {
            if (i > 0 && i % 4 === 0) result += " - "
            result += normalized.charAt(i)
        }
        return result
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
                errorText.text = "Incorrect recovery key"
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
                errorText.text = "Incorrect recovery key"
                errorText.visible = true
                errorText.color = "#ff5c5c"
            }
        }
    }
    function _s(px) { return Math.round(px * _uiScale) }

    Item {
        id: content
        width: Math.min(_s(1019), parent.width - _s(24))
        height: _s(622)
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
            width: parent.width
            height: _s(84)
            radius: _s(20)
            color: "#202528"
            border.width: 1
            border.color: "#707070"

            Image {
                x: _s(29)
                y: _s(18)
                width: _s(48)
                height: _s(48)
                source: "/res/QGCLogoFull"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                x: _s(94)
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Forgot PIN")
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
                    onClicked: forgotPinPage.backClicked()
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
            id: introText
            x: 0
            y: _s(135)
            width: parent.width
            height: _s(96)
            text: qsTr("Enter the 24-character Recovery Key \nprovided during initial setup.")
            color: "#AEAEAE"
            font.family: "Roboto"
            font.pixelSize: _s(32)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
        }

        Rectangle {
            id: inputBox
            x: _s(69)
            y: _s(252)
            width: Math.min(_s(858), parent.width - _s(138))
            height: _s(80)
            radius: 4
            color: "#2D2D2D"
            border.width: 2
            border.color: forgotPinPage.keyBoxFocused ? "#00C2AD" : "#ffffff"

            // Placeholder: only visible when nothing typed yet
            Text {
                anchors.fill: parent
                anchors.leftMargin: _s(16)
                anchors.rightMargin: _s(16)
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: "____ - ____ - ____ - ____ - ____ - ____"
                color: "#9AA2AD"
                font.family: "Roboto"
                font.pixelSize: _s(34)
                visible: keyText.length === 0
                enabled: false
            }

            TextInput {
                id: hiddenInput
                anchors.fill: parent
                anchors.leftMargin: _s(16)
                anchors.rightMargin: _s(16)
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                // Transparent when empty so placeholder shows; opaque when typing
                opacity: keyText.length > 0 ? 1.0 : 0.0
                color: locked ? "#AEAEAE" : "#FFFFFF"
                font.family: "Roboto"
                font.pixelSize: _s(34)
                maximumLength: 128
                selectByMouse: true
                enabled: !forgotPinPage.locked
                inputMethodHints: Qt.ImhUppercaseOnly | Qt.ImhNoPredictiveText
                onTextChanged: {
                    var normalized = _normalizedKey(text)
                    if (normalized.length > keyLength) {
                        normalized = normalized.slice(0, keyLength)
                    }
                    var formatted = _formattedKey(normalized)
                    if (text !== formatted) {
                        text = formatted
                        cursorPosition = formatted.length
                        return
                    }
                    keyText = normalized
                }
                onActiveFocusChanged: {
                    forgotPinPage.keyBoxFocused = activeFocus
                    if (activeFocus) Qt.inputMethod.show()
                }
                Keys.onPressed: {
                    if (locked) { event.accepted = true; return }
                    if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
                        hiddenInput.paste()
                        event.accepted = true
                        return
                    }

                    if (event.text.length === 1) {
                        var upper = event.text.toUpperCase()
                        if (upper >= "A" && upper <= "Z") {
                            var nCur = _normalizedKey(keyText)
                            if (nCur.length < keyLength) {
                                nCur = nCur + upper
                                keyText = nCur
                                hiddenInput.text = _formattedKey(nCur)
                                hiddenInput.cursorPosition = hiddenInput.text.length
                            }
                            event.accepted = true
                            return
                        }
                    }

                    if (event.key === Qt.Key_Backspace) {
                        var nBack = _normalizedKey(keyText)
                        if (nBack.length > 0) {
                            nBack = nBack.slice(0, nBack.length - 1)
                            keyText = nBack
                            hiddenInput.text = _formattedKey(nBack)
                            hiddenInput.cursorPosition = hiddenInput.text.length
                        }
                        event.accepted = true
                    }
                }
            }
        }

        Rectangle {
            id: verifyButton
            x: (content.width - width) / 2
            y: _s(365)
            width: Math.min(_s(508), parent.width - _s(24))
            height: _s(71)
            radius: 4
            color: verifyMouse.pressed ? "#0B8A7A" : "#00826F"
            opacity: locked ? 0.5 : 1.0

            Text {
                anchors.centerIn: parent
                text: qsTr("Verify Key")
                color: locked ? "#AEAEAE" : "#FFFFFF"
                font.family: "Roboto"
                font.pixelSize: _s(28)
                font.styleName: "Medium"
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
            x: 0
            y: _s(446)
            width: parent.width
            visible: false
            text: ""
            color: "#ff5c5c"
            font.family: "Roboto"
            font.pixelSize: _s(24)
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            x: _s(69)
            y: _s(480)
            width: Math.min(_s(858), parent.width - _s(138))
            height: _s(93)
            radius: 4
            color: "#485058"

            Text {
                x: _s(147)
                y: _s(13)
                width: parent.width - _s(132)
                wrapMode: Text.WordWrap
                text: qsTr("If you lost the Recovery Key, contact system admin \nfor a Factory Security Reset.")
                color: "#AEAEAE"
                font.family: "Roboto"
                font.pixelSize: _s(28)
                horizontalAlignment: Text.AlignLeft
            }

            Image {
                x: _s(75)
                y: _s(22)
                width: _s(52)
                height: _s(43)
                source: "/custom/img/caution.svg"
                fillMode: Image.PreserveAspectFit
            }
        }
    }

    Component.onCompleted: {
        if (securityManager.isLockedForScope(forgotPinPage._lockoutScope)) {
            locked = true
            lockoutTimer.start()
        }
    }
}
