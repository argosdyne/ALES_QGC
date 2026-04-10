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
import QtQuick.Layouts 1.1

import QGroundControl.ScreenTools 1.0

Page {
    id: loginPage

    signal unlockClicked()
    signal viewOnlyClicked()
    signal forgotPINClicked()
    signal systemRestoreRequested()

    property int pinLength: 6
    property bool locked: false
    property real _uiScale: ScreenTools.isMobile ? 1.20 : 0.65
    property int _contentBlockHeight: _s(687)

    property string pinText: ""
    property bool   pinBoxFocused: false
    property int    _logoTapCount: 0
    property bool   _rememberedLogin: false
    readonly property string _lockoutScope: "login"

    background: Rectangle {
        color: "#222222"
        opacity: 0
        radius: 16
    }

    // Timer to update lockout remaining time in realtime
    Timer {
        id: lockoutTimer
        interval: 1000 // update every second
        running: locked
        repeat: true

        onTriggered: {
            // Poll the C++ backend (notified updates aren't available), update local locked state
            locked = securityManager.isLockedForScope(loginPage._lockoutScope)
            if (locked) {
                var until = securityManager.lockoutUntilForScope(loginPage._lockoutScope)
                var remaining = Math.max(0, Math.ceil((until - Date.now()) / 1000))
                unlockError.text = "Locked. Try in " + remaining + "s"
                unlockError.visible = true
            } else {
                unlockError.visible = false
                lockoutTimer.stop()
            }
        }
    }

    // Single-shot timer to allow UI to update before emitting unlock signal
    Timer {
        id: unlockTriggerTimer
        property string action: ""
        interval: 50
        running: false
        repeat: false
        onTriggered: {
            if (action === "unlock") {
                loginPage.unlockClicked()
            } else if (action === "viewOnly") {
                loginPage.viewOnlyClicked()
            }
            action = ""
        }
    }

    // Listen for immediate lockout notifications from C++ backend
    Connections {
        target: securityManager

        function onLockoutStartedForScope(scope, until) {
            if (scope === loginPage._lockoutScope) {
                locked = true
                lockoutTimer.start()
            }
        }

        function onLockoutClearedForScope(scope) {
            if (scope === loginPage._lockoutScope) {
                locked = false
                unlockError.visible = false
                lockoutTimer.stop()
            }
        }
    }

    function getPINValue() { return pinText }

    function _syncRememberMeUI() {
        try {
            _rememberedLogin = securityManager.rememberMeEnabled()
        } catch(e) {
            _rememberedLogin = false
        }

        rememberBox.checked = _rememberedLogin

        if (_rememberedLogin) {
            pinText = "000000"
            hiddenInput.text = pinText
        } else {
            pinText = ""
            hiddenInput.text = ""
        }
    }

    function _s(px) { return Math.round(px * _uiScale) }

    Item {
        id: headerSection
        width: parent.width
        height: _s(194)
        y: Math.max(_s(20), Math.round((parent.height - loginPage._contentBlockHeight) / 2))

        Column {
            anchors.centerIn: parent
            spacing: _s(16)
            width: parent.width

            Image {
                id: loginLogo
                source: "/res/QGCLogoFull"
                width: _s(92)
                height: _s(92)
                anchors.horizontalCenter: parent.horizontalCenter

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        loginPage._logoTapCount += 1
                        if (loginPage._logoTapCount >= 5) {
                            loginPage._logoTapCount = 0
                            loginPage.systemRestoreRequested()
                        }
                    }
                }
            }

            // ===== TITLE =====
            Item {
                width: parent.width
                height: _s(86)
                Text {
                    text: "System Authentication"
                    color: "#ffffff"
                    font.family: "Roboto"
                    font.pixelSize: _s(40)
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Enter your PIN to access admin functions"
                    color: "#AEAEAE"
                    font.family: "Roboto"
                    font.pixelSize: _s(24)
                    horizontalAlignment: Text.AlignHCenter
                    y: _s(57)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    // ===== PIN INPUT SECTION =====
    Item {
        id: pinSection
        width: Math.min(_s(508), parent.width - _s(24))
        height: _s(119)
        y: headerSection.y + headerSection.height + _s(44)
        anchors.horizontalCenter: parent.horizontalCenter
        Column {
            spacing: _s(10)
            width: parent.width
            // anchors.horizontalCenter: parent.horizontalCenter

            Text {
                text: "Admin PIN"
                color: "#AEAEAE"
                font.family: "Roboto"
                font.pixelSize: _s(24)
                anchors.left: parent.left
            }

            // Single PIN input box, white bordered, dark fill
            // All placeholder dots always visible; filled dots grow from center as user types
            Rectangle {
                id: pinBox
                width: parent.width
                height: _s(80)
                radius: 4
                color: "#222222"
                border.color: loginPage.pinBoxFocused ? "#00826F" : "#ffffff"
                border.width: 2

                // Dot settings
                readonly property int dotD:      _s(18)
                readonly property int dotGap:    _s(21)
                readonly property int totalW:    pinLength * dotD + (pinLength - 1) * dotGap

                // How many chars entered; fill starts from the left
                readonly property int entered:   pinText.length
                readonly property int startIdx:  0

                MouseArea {
                    id: pinBoxMouseArea
                    anchors.fill: parent
                    hoverEnabled: false
                    onClicked: {
                        if (loginPage.locked) return
                        loginPage.pinBoxFocused = true
                        hiddenInput.forceActiveFocus()
                        if (!Qt.inputMethod.visible) Qt.inputMethod.show()
                    }
                }

                // Dots row — always pinLength dots, placeholder = hollow, filled = solid white
                Row {
                    anchors.centerIn: parent
                    spacing: pinBox.dotGap

                    Repeater {
                        model: pinLength
                        Rectangle {
                            width:  pinBox.dotD
                            height: pinBox.dotD
                            radius: pinBox.dotD / 2
                            // filled if this slot falls within the entered range (centered)
                            readonly property bool isFilled: pinBox.entered > 0
                                                             && index >= pinBox.startIdx
                                                             && index < pinBox.startIdx + pinBox.entered
                            color:        isFilled ? (loginPage.locked ? "#AEAEAE" : "#FFFFFF") : "transparent"
                            border.width: isFilled ? 0         : 2
                            border.color: loginPage.locked ? "#AEAEAE" : "#FFFFFF"
                        }
                    }
                }

                // Hidden TextInput — captures keyboard/IME input
                TextInput {
                    id: hiddenInput
                    width: 1; height: 1; opacity: 0
                    focus: false
                    maximumLength: pinLength
                    inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
            
                    onTextChanged: pinText = text

                    Keys.onPressed: {
                        if (locked) { event.accepted = true; return }
                        if (event.text.length === 1 && event.text >= "0" && event.text <= "9") {
                            if (pinText.length < pinLength) {
                                pinText = pinText + event.text
                                hiddenInput.text = pinText
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Backspace) {
                            if (pinText.length > 0) {
                                pinText = pinText.slice(0, pinText.length - 1)
                                hiddenInput.text = pinText
                            }
                            event.accepted = true
                        }
                    }
                }
            }
        }
    }

    // ===== REMEMBER ME ROW =====
    Item {
        id: rememberRow
        width: parent.width
        height: _s(36)
        anchors.left: pinSection.left
        y: pinSection.y + pinSection.height + _s(28)
        Row {
            spacing: _s(13)
            anchors.left: parent.left

            Rectangle {
                id: rememberBox
                width: _s(36); height: _s(36)
                radius: 4
                color:        "transparent"
                border.color: rememberBox.checked ? "#FFFFFF" : "#888888"
                border.width: 2
                property bool checked: false

                Image {
                    source: "qrc:/custom/img/checked.svg"
                    x: _s(5)
                    y: _s(2)
                    width: _s(28)
                    height: _s(28)
                    fillMode: Image.PreserveAspectFit
                    visible: rememberBox.checked
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        rememberBox.checked = !rememberBox.checked

                        if (!rememberBox.checked) {
                            loginPage._rememberedLogin = false
                            try { securityManager.setRememberMeEnabled(false) } catch(e) {}
                            pinText = ""
                            hiddenInput.text = ""
                        }
                    }
                }
            }

            Text {
                text: "Remember me"
                color: "#AEAEAE"
                font.family: "Roboto"
                font.pixelSize: _s(24)
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        rememberBox.checked = !rememberBox.checked

                        if (!rememberBox.checked) {
                            loginPage._rememberedLogin = false
                            try { securityManager.setRememberMeEnabled(false) } catch(e) {}
                            pinText = ""
                            hiddenInput.text = ""
                        }
                    }
                }
            }
        }
    }

    // ===== ERROR / STATUS TEXT =====
    Text {
        y: rememberRow.y + rememberRow.height + _s(7)
        id: unlockError
        text: ""
        color: "#ff5c5c"
        visible: false
        font.bold: true
        font.pixelSize: _s(24)
        anchors.horizontalCenter: parent.horizontalCenter
        horizontalAlignment: Text.AlignHCenter
    }

    // ===== UNLOCK BUTTON =====
    Rectangle {
        y: rememberRow.y + rememberRow.height + _s(44)
        width: Math.min(_s(508), parent.width - _s(24))
        height: _s(71)
        radius: 4
        color: unlockBtnArea.pressed ? "#0b8a7a" : "#00826F"
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: locked ? 0.5 : 1.0

        Text {
            anchors.centerIn: parent
            text: "Unlock System"
            color: "#ffffff"
            font.pixelSize: _s(28)
            font.family: "Roboto"
            font.styleName: "Medium"
        }

        MouseArea {
            id: unlockBtnArea
            anchors.fill: parent
            enabled: !locked
            onClicked: {
                if (securityManager.isLockedForScope(loginPage._lockoutScope)) {
                    locked = true
                    lockoutTimer.start()
                    return
                }

                var remembered = false
                try { remembered = securityManager.rememberMeEnabled() } catch(e) { remembered = false }

                if (rememberBox.checked && remembered) {
                    unlockError.text  = "Remembered login. Loading..."
                    unlockError.color = "#0fa18f"
                    unlockError.visible = true
                    unlockTriggerTimer.action = "unlock"
                    unlockTriggerTimer.start()
                    return
                }

                var pin = getPINValue()
                var ok = false
                try { ok = securityManager.verifyPin(pin) } catch(e) { ok = false }
                if (ok) {
                    try { securityManager.setRememberMeEnabled(rememberBox.checked) } catch(e) {}
                    loginPage._rememberedLogin = rememberBox.checked
                    unlockError.text  = "PIN verified. Loading..."
                    unlockError.color = "#0fa18f"
                    unlockError.visible = true
                    unlockTriggerTimer.action = "unlock"
                    unlockTriggerTimer.start()
                } else {
                    // Clear entered PIN on failure so user can re-enter without manual delete
                    pinText = ""
                    hiddenInput.text = ""
                    unlockError.text    = "Invalid PIN"
                    unlockError.color   = "#ff5c5c"
                    unlockError.visible = true
                }
            }
        }
    }

    // ===== VIEW-ONLY BUTTON =====
    Rectangle {
        y: rememberRow.y + rememberRow.height + _s(142)
        width: Math.min(_s(508), parent.width - _s(24))
        height: _s(71)
        radius: 4
        color: viewOnlyBtnArea.pressed ? "#4a5260" : "#3d4450"
        anchors.horizontalCenter: parent.horizontalCenter

        Text {
            anchors.centerIn: parent
            text: "Continue in View-only Mode"
            color: "#ffffff"
            font.pixelSize: _s(28)
            font.family: "Roboto"
            font.styleName: "Medium"
        }

        MouseArea {
            id: viewOnlyBtnArea
            anchors.fill: parent
            onClicked: {
                unlockError.text    = "Loading View-only Mode..."
                unlockError.color   = "#00826F"
                unlockError.visible = true
                unlockTriggerTimer.action = "viewOnly"
                unlockTriggerTimer.start()
            }
        }
    }

    // ===== FORGOT PIN LINK =====
    Text {
        y: rememberRow.y + rememberRow.height + _s(236)
        text: "Forgot PIN?"
        color: "#00826F"
        font.family: "Roboto"
        font.pixelSize: _s(24)
        font.bold: true
        anchors.left: rememberRow.left

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: loginPage.forgotPINClicked()
        }
    }


    Component.onCompleted: {
        // Don't auto-show keyboard, wait for user to click input field
        _syncRememberMeUI()

        if (securityManager.isLockedForScope(loginPage._lockoutScope)) {
            lockoutTimer.start()
        }
    }
}
