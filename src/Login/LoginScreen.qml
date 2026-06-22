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
import Qt.labs.settings 1.0

import QGroundControl.ScreenTools 1.0

Page {
    id: loginPage

    signal unlockClicked()
    signal viewOnlyClicked()
    signal forgotPINClicked()
    signal systemRestoreRequested()

    property bool locked: false
    property real _uiScale: ScreenTools.isMobile ? 1.20 : 0.65
    property int _contentBlockHeight: _s(687)

    property string passwordText: ""
    property bool   showPassword: false
    property bool   pinBoxFocused: false
    property int    _logoTapCount: 0
    property bool   _rememberedLogin: false
    property bool   _rememberedLoginPinEdited: false
    property bool   _updatingPinFromCode: false
    readonly property int _defaultRememberedPasswordLength: 8
    readonly property int _passwordMaskVerticalOffset: ScreenTools.isAndroid ? _s(6) : 0
    readonly property bool _usingRememberedLogin: rememberBox.checked && _rememberedLogin && !_rememberedLoginPinEdited
    readonly property bool _showPasswordToggleEnabled: !locked && !_usingRememberedLogin
    readonly property string _lockoutScope: "login"

    Settings {
        id: rememberUiSettings
        category: "LoginFlow"
        property bool rememberMeChecked: false
        property int rememberedPasswordLength: 0
    }

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

    function getPasswordValue() { return passwordText }

    function _setPasswordValue(value) {
        _updatingPinFromCode = true
        passwordText = value
        hiddenInput.text = value
        _updatingPinFromCode = false
    }

    function _showRememberedPasswordMask() {
        _updatingPinFromCode = true
        passwordText = ""
        hiddenInput.text = _passwordMask(rememberUiSettings.rememberedPasswordLength)
        _updatingPinFromCode = false
    }

    function _passwordMask(length) {
        var maskLength = Number(length)
        if (!maskLength || maskLength < 1) {
            maskLength = _defaultRememberedPasswordLength
        }
        maskLength = Math.min(maskLength, hiddenInput.maximumLength)

        var mask = ""
        for (var i = 0; i < maskLength; i++) {
            mask += "*"
        }
        return mask
    }

    function _clearRememberedLogin() {
        rememberBox.checked = false
        _rememberedLogin = false
        _rememberedLoginPinEdited = false
        showPassword = false
        rememberUiSettings.rememberMeChecked = false
        rememberUiSettings.rememberedPasswordLength = 0
        try { securityManager.setRememberMeEnabled(false) } catch(e) {}
        _setPasswordValue("")
    }

    function _toggleRememberMe() {
        rememberBox.checked = !rememberBox.checked
        rememberUiSettings.rememberMeChecked = rememberBox.checked

        if (!rememberBox.checked) {
            _clearRememberedLogin()
        }
    }

    function _syncRememberMeUI() {
        try {
            _rememberedLogin = securityManager.rememberMeEnabled()
        } catch(e) {
            _rememberedLogin = false
        }

        rememberBox.checked = _rememberedLogin || rememberUiSettings.rememberMeChecked

        if (_rememberedLogin) {
            showPassword = false
            _showRememberedPasswordMask()
        } else {
            _setPasswordValue("")
        }
        _rememberedLoginPinEdited = false
    }

    function _useAnotherPassword() {
        _rememberedLoginPinEdited = true
        showPassword = false
        _setPasswordValue("")
        pinBoxFocused = true
        hiddenInput.forceActiveFocus()
        if (!Qt.inputMethod.visible) Qt.inputMethod.show()
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
                    text: "Enter your password to access admin functions"
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

    // ===== PASSWORD INPUT SECTION =====
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
                text: "Admin Password"
                color: "#AEAEAE"
                font.family: "Roboto"
                font.pixelSize: _s(24)
                anchors.left: parent.left
            }

            Rectangle {
                id: pinBox
                width: parent.width
                height: _s(80)
                radius: 4
                color: "#222222"
                border.color: loginPage.pinBoxFocused ? "#00826F" : "#ffffff"
                border.width: 2
                opacity: loginPage._usingRememberedLogin ? 0.65 : 1.0

                MouseArea {
                    id: pinBoxMouseArea
                    anchors.fill: parent
                    hoverEnabled: false
                    onClicked: {
                        if (loginPage.locked || loginPage._usingRememberedLogin) return
                        loginPage.pinBoxFocused = true
                        hiddenInput.forceActiveFocus()
                        if (!Qt.inputMethod.visible) Qt.inputMethod.show()
                    }
                }

                TextInput {
                    id: hiddenInput
                    anchors.left: parent.left
                    anchors.right: passwordToggle.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: loginPage.showPassword ? 0 : loginPage._passwordMaskVerticalOffset
                    anchors.leftMargin: _s(18)
                    anchors.rightMargin: _s(12)
                    height: Math.min(parent.height, Math.max(_s(36), implicitHeight))
                    clip: true
                    color: loginPage.locked ? "#AEAEAE" : "#ffffff"
                    selectedTextColor: "#ffffff"
                    selectionColor: "#00826F"
                    font.family: "Roboto"
                    font.pixelSize: _s(24)
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: loginPage.showPassword ? TextInput.Normal : TextInput.Password
                    focus: false
                    maximumLength: 64
                    enabled: !loginPage.locked && !loginPage._usingRememberedLogin
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                    onActiveFocusChanged: {
                        loginPage.pinBoxFocused = activeFocus
                    }
            
                    onTextChanged: {
                        if (_updatingPinFromCode) {
                            return
                        }
                        passwordText = text
                        if (_rememberedLogin && rememberBox.checked) {
                            _rememberedLoginPinEdited = true
                        }
                    }

                    Keys.onPressed: {
                        if (locked) { event.accepted = true; return }
                    }
                }

                Text {
                    id: passwordToggle
                    text: loginPage.showPassword ? "Hide" : "Show"
                    color: loginPage._showPasswordToggleEnabled ? "#00826F" : "#AEAEAE"
                    font.family: "Roboto"
                    font.pixelSize: _s(20)
                    font.bold: true
                    anchors.right: parent.right
                    anchors.rightMargin: _s(18)
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !loginPage._usingRememberedLogin
                    opacity: loginPage._showPasswordToggleEnabled ? 1.0 : 0.6

                    MouseArea {
                        anchors.centerIn: parent
                        width: parent.width + loginPage._s(32)
                        height: parent.height + loginPage._s(28)
                        enabled: loginPage._showPasswordToggleEnabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            loginPage.showPassword = !loginPage.showPassword
                            hiddenInput.forceActiveFocus()
                        }
                    }
                }
            }

            // Text {
            //     text: "Use another password"
            //     color: "#00826F"
            //     font.family: "Roboto"
            //     font.pixelSize: _s(20)
            //     font.bold: true
            //     visible: loginPage._usingRememberedLogin
            //     anchors.left: parent.left

            //     MouseArea {
            //         anchors.fill: parent
            //         cursorShape: Qt.PointingHandCursor
            //         onClicked: loginPage._useAnotherPassword()
            //     }
            // }
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
                        loginPage._toggleRememberMe()
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
                        loginPage._toggleRememberMe()
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

                if (rememberBox.checked && remembered && !loginPage._rememberedLoginPinEdited) {
                    unlockError.text  = "Remembered login. Loading..."
                    unlockError.color = "#0fa18f"
                    unlockError.visible = true
                    unlockTriggerTimer.action = "unlock"
                    unlockTriggerTimer.start()
                    return
                }

                var password = getPasswordValue()
                var ok = false
                try { ok = securityManager.verifyPassword(password) } catch(e) { ok = false }
                if (ok) {
                    try { securityManager.setRememberMeEnabled(rememberBox.checked) } catch(e) {}
                    rememberUiSettings.rememberMeChecked = rememberBox.checked
                    rememberUiSettings.rememberedPasswordLength = rememberBox.checked ? password.length : 0
                    loginPage._rememberedLogin = rememberBox.checked
                    unlockError.text  = "Password verified. Loading..."
                    unlockError.color = "#0fa18f"
                    unlockError.visible = true
                    unlockTriggerTimer.action = "unlock"
                    unlockTriggerTimer.start()
                } else {
                    if (remembered && loginPage._rememberedLoginPinEdited) {
                        try { securityManager.setRememberMeEnabled(false) } catch(e) {}
                        loginPage._rememberedLogin = false
                        loginPage._rememberedLoginPinEdited = false
                    }
                    // Clear entered password on failure so user can re-enter without manual delete
                    _setPasswordValue("")
                    unlockError.text    = "Invalid password"
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

    // ===== FORGOT PASSWORD LINK =====
    Text {
        y: rememberRow.y + rememberRow.height + _s(236)
        text: "Forgot Password?"
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
