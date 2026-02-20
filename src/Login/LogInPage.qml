import QtQuick 2.7
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.1

Page {
    id: loginPage

    signal unlockClicked(string pin)
    signal viewOnlyClicked()
    signal forgotPINClicked()

    property int pinLength: 8
    property bool locked: false
    property string pendingPin: ""

    background: Rectangle {
        color: "#ffffff"
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
        interval: 50
        running: false
        repeat: false
        onTriggered: {
            loginPage.unlockClicked(pendingPin)
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

    function getPINValue() {
        var value = ""
        for (var i = 0; i < pinLength; i++) {
            var pinBox = enterRepeater.itemAt(i)
            if (pinBox && pinBox.text !== undefined) {
                value += pinBox.text
            }
        }
        return value
    }

    Column {
        anchors.centerIn: parent
        spacing: 25
        width: parent.width * 0.9
        anchors.verticalCenterOffset: -40

        // ===== ICON & TITLE =====
        Rectangle {
            width: 80
            height: 80
            radius: 40
            anchors.horizontalCenter: parent.horizontalCenter
            gradient: Gradient {
                GradientStop { position: 0; color: "#4f7cff" }
                GradientStop { position: 1; color: "#7a5cff" }
            }

            Text {
                anchors.centerIn: parent
                text: "🔒"
                font.pixelSize: 40
            }
        }

        Text {
            text: "System Authentication"
            color: "#000000"
            font.pixelSize: 35
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "Enter your PIN to access admin functions"
            color: "#666666"
            font.pixelSize: 18
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // ===== PIN INPUT SECTION =====
        Column {
            id: pinRepeater
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                text: "Admin PIN"
                color: "#222222"
                anchors.left: parent.left
                font.pixelSize: 18
                font.bold: true
            }

            Row {
                spacing: 12
                anchors.horizontalCenter: parent.horizontalCenter

                Repeater {
                    id: enterRepeater
                    model: 8

                    PinBox {
                        index: model.index
                        enabled: !locked
                        opacity: enabled ? 1.0 : 0.5

                        onNextRequested: {
                            if (index < pinLength - 1)
                                enterRepeater.itemAt(index + 1).forceActiveFocus()
                        }

                        onPrevRequested: {
                            if (index > 0)
                                enterRepeater.itemAt(index - 1).forceActiveFocus()
                        }
                    }
                }
            }
        }


        // ===== REMEMBER ME & FORGOT PIN =====
        RowLayout {
            width: pinRepeater.width
            anchors.horizontalCenter: parent.horizontalCenter
            // Layout.alignment: Qt.AlignVCenter

            CheckBox {
                id: rememberCheckbox
                text: " Remember me"
                font.pixelSize: 18
                Layout.alignment: Qt.AlignVCenter
                contentItem: Text {
                    text: parent.text
                    color: "#666666"
                    font.bold: true
                    font.pixelSize: 18
                    leftPadding: parent.indicator.width + 2
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Forgot PIN?"
                color: "#4f7cff"
                font.pixelSize: 18
                font.bold: true
                font.underline: true
                Layout.alignment: Qt.AlignVCenter

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: securityManager.clearStored()
                }
            }
        }

        Text {
            id: unlockError
            text: ""
            color: "#ff5c5c"
            visible: false
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: 18
        }

        // ===== UNLOCK BUTTON =====
        Button {
            text: "Unlock System"
            width: pinRepeater.width
            height: 50
            anchors.horizontalCenter: parent.horizontalCenter
            enabled: !locked

            onClicked: {
                // check lockout first
                if (securityManager.isLocked()) {
                    // set local locked flag and start timer to show realtime countdown
                    locked = true
                    lockoutTimer.start()
                    return
                }

                var pin = getPINValue()
                var ok = false
                try {
                    ok = securityManager.verifyPin(pin)
                } catch(e) { ok = false }

                if (ok) {
                    unlockError.text = "PIN verified. Loading..."
                    unlockError.color = "green"
                    unlockError.visible = true
                    // delay emitting signal so the UI has time to render the Loading message
                    pendingPin = pin
                    unlockTriggerTimer.start()
                } else {
                    // Show immediate invalid PIN message
                    unlockError.text = "Invalid PIN"
                    unlockError.visible = true
                }
            }

            background: Rectangle {
                radius: 8
                color: "#4f7cff" //parent.enabled ? "#4f7cff" : "#cccccc"
            }

            contentItem: Text {
                text: parent.text
                color: "white"
                font.pixelSize: 18
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.centerIn: parent
            }
        }

        // ===== VIEW ONLY MODE BUTTON =====
        Button {
            text: "Continue in View-only Mode"
            width: pinRepeater.width
            height: 50
            anchors.horizontalCenter: parent.horizontalCenter

            onClicked: {
                loginPage.viewOnlyClicked()
            }

            background: Rectangle {
                radius: 8
                color: "#f0f0f0"
            }

            contentItem: Text {
                text: parent.text
                color: "#333333"
                font.bold: true
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.centerIn: parent
            }
        }

        // ===== SECURITY MESSAGE =====
        Text {
            text: "⚠ Your session will auto-lock after inactivity or when the app is \n backgrounded"
            color: "#d9534f"
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            wrapMode: Text.Wrap
        }
    }

    Component.onCompleted: {
        var first = enterRepeater.itemAt(0)
        if (first) {
            // PinBox is the repeater item (Rectangle) which forwards focus to its TextInput
            first.forceActiveFocus()
        }

        // Check if locked when page loads
        if (securityManager.isLocked()) {
            lockoutTimer.start()
        }
    }
}
