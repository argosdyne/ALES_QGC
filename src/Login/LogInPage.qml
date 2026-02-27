import QtQuick 2.7
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.1

Page {
    id: loginPage

    signal unlockClicked()
    signal viewOnlyClicked()
    signal forgotPINClicked()

    property int pinLength: 6
    property bool locked: false
    property int _contentBlockHeight: 687

    property string pinText: ""

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
            locked = securityManager.isLocked()
            if (locked) {
                var until = securityManager.lockoutUntil()
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

        function onLockoutStarted(until) {
            locked = true
            lockoutTimer.start()
        }

        function onLockoutCleared() {
            locked = false
            unlockError.visible = false
            lockoutTimer.stop()
        }
    }

    function getPINValue() { return pinText }

    Item {
        id: headerSection
        width: parent.width
        height: 194
        y: Math.max(20, Math.round((parent.height - loginPage._contentBlockHeight) / 2))

    Column {
        anchors.centerIn: parent
        spacing: 16
        width: parent.width

        Image {
            source: "qrc:/custom/img/lock_icon.svg"
            width: 92
            height: 92
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // ===== TITLE =====
        Item {
            width: parent.width
            height: 86
        Text {
            text: "System Authentication"
            color: "#ffffff"
            font.family: "Roboto"
            font.pixelSize: 40
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "Enter your PIN to access admin functions"
            color: "#AEAEAE"
            font.family: "Roboto"
            font.pixelSize: 24
            horizontalAlignment: Text.AlignHCenter
            y: 57
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
    }
    }

        // ===== PIN INPUT SECTION =====
        Item {
            id: pinSection
            width: 508
            height: 119
            y: headerSection.y + headerSection.height + 44
            anchors.horizontalCenter: parent.horizontalCenter
        Column {
            spacing: 10
            width: parent.width
            // anchors.horizontalCenter: parent.horizontalCenter

            Text {
                text: "Admin PIN"
                color: "#AEAEAE"
                font.family: "Roboto"
                font.pixelSize: 24
                anchors.left: parent.left
            }

            // Single PIN input box, white bordered, dark fill
            // All placeholder dots always visible; filled dots grow from center as user types
            Rectangle {
                id: pinBox
                width: 508
                height: 80
                radius: 4
                color: "#222222"
                border.color: pinBoxMouseArea.containsMouse ? "#00826F" : "#ffffff"
                border.width: 2

                // Dot settings
                readonly property int dotD:      18
                readonly property int dotGap:    21
                readonly property int totalW:    pinLength * dotD + (pinLength - 1) * dotGap

                // How many chars entered; fill starts from the left
                readonly property int entered:   pinText.length
                readonly property int startIdx:  0

                MouseArea {
                    id: pinBoxMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
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
                            color:        isFilled ? "#ffffff" : "transparent"
                            border.width: isFilled ? 0         : 2
                            border.color: "#ffffff"
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
            height: 36
            anchors.left: pinSection.left
            y: pinSection.y + pinSection.height + 28
        Row {
            spacing: 13
            anchors.left: parent.left

            Rectangle {
                id: rememberBox
                width: 36; height: 36
                radius: 4
                color:        "transparent"
                border.color: rememberBox.checked ? "#FFFFFF" : "#888888"
                border.width: 2
                property bool checked: false

                Image {
                source: "qrc:/custom/img/checked.svg"
                x: 5
                y: 2
                visible: rememberBox.checked
            }
                MouseArea {
                    anchors.fill: parent
                    onClicked: rememberBox.checked = !rememberBox.checked
                }
            }

            Text {
                text: "Remember me"
                color: "#AEAEAE"
                font.family: "Roboto"
                font.pixelSize: 24
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        }

        // ===== ERROR / STATUS TEXT =====
        Text {
            y: rememberRow.y + rememberRow.height + 7
            id: unlockError
            text: ""
            color: "#ff5c5c"
            visible: false
            font.bold: true
            font.pixelSize: 24
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
        }

        // ===== UNLOCK BUTTON =====
        Rectangle {
            y: rememberRow.y + rememberRow.height + 44
            width: 508
            height: 71
            radius: 4
            color: unlockBtnArea.pressed ? "#0b8a7a" : "#00826F"
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: locked ? 0.5 : 1.0

            Text {
                anchors.centerIn: parent
                text: "Unlock System"
                color: "#ffffff"
                font.pixelSize: 28
                font.family: "Roboto"
                font.styleName: "Medium"
            }

            MouseArea {
                id: unlockBtnArea
                anchors.fill: parent
                enabled: !locked
                onClicked: {
                    if (securityManager.isLocked()) {
                        locked = true
                        lockoutTimer.start()
                        return
                    }
                    var pin = getPINValue()
                    var ok = false
                    try { ok = securityManager.verifyPin(pin) } catch(e) { ok = false }
                    if (ok) {
                        unlockError.text  = "PIN verified. Loading..."
                        unlockError.color = "#0fa18f"
                        unlockError.visible = true
                        unlockTriggerTimer.action = "unlock"
                        unlockTriggerTimer.start()
                    } else {
                        unlockError.text    = "Invalid PIN"
                        unlockError.color   = "#ff5c5c"
                        unlockError.visible = true
                    }
                }
            }
        }

        // ===== VIEW-ONLY BUTTON =====
        Rectangle {
            y: rememberRow.y + rememberRow.height + 142
            width: 508
            height: 71
            radius: 4
            color: viewOnlyBtnArea.pressed ? "#4a5260" : "#3d4450"
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                anchors.centerIn: parent
                text: "Continue in View-only Mode"
                color: "#ffffff"
                font.pixelSize: 28
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
            y: rememberRow.y + rememberRow.height + 236
            text: "Forgot PIN?"
            color: "#00826F"
            font.family: "Roboto"
            font.pixelSize: 24
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
        if (securityManager.isLocked()) {
            lockoutTimer.start()
        }
    }
}
