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
import QtQuick.Dialogs 1.3

import QGroundControl.ScreenTools 1.0

Page {
    id: registerPage

    signal pinRegistered()

    property string enterPasswordText:   ""
    property string confirmPasswordText: ""
    property string errorMessage:   ""
    property bool   showError:      false
    property bool   showEnterPassword: false
    property bool   showConfirmPassword: false
    property string messageColor:   "#ff5c5c"
    property real _uiScale: ScreenTools.isMobile ? 1.20 : 0.65
    property int _contentBlockHeight: _s(687)
    readonly property int _passwordMaskVerticalOffset: ScreenTools.isAndroid ? _s(6) : 0
    property string activePassword:        ""   // "enter" | "confirm" | ""

    background: Rectangle {
        color: "#222222"
        opacity: 0
        radius: 16
    }

    // ─── helpers ──────────────────────────────────────────────────────────────
    function showPasswordError(message) {
        errorMessage = message
        messageColor = "#ff5c5c"
        showError = true
        mainWindow.showMessageDialog("Invalid Password", message, StandardButton.Ok, function() {
            enterInput.forceActiveFocus()
        })
    }

    function validatePassword() {
        var p1 = enterPasswordText
        var p2 = confirmPasswordText

        if (p1.length === 0 || p2.length === 0) {
            showPasswordError("Enter and confirm your admin password")
            return false
        }

        var strengthError = securityManager.validatePasswordStrength(p1)
        if (strengthError) {
            showPasswordError(strengthError)
            return false
        }

        if (p1 !== p2) {
            showPasswordError("Passwords do not match")
            return false
        }

        showError = false
        return true
    }
    function _s(px) { return Math.round(px * _uiScale) }

    // ─── header (icon + title + subtitle) ────────────────────────────────────
    Item {
        id: headerSection
        width:  parent.width
        height: _s(192)
        y: Math.max(_s(20), Math.round((parent.height - registerPage._contentBlockHeight) / 2))

        Column {
            anchors.centerIn: parent
            spacing: _s(16)
            width: parent.width

            Image {
                source: "/res/QGCLogoFull"
                width:  _s(92)
                height: _s(92)
                anchors.horizontalCenter: parent.horizontalCenter
            }

        // ===== TITLE =====
        Item {
            width: parent.width
            height: _s(84)
            Text {
                text: "Set Your Admin Password"
                color: "#ffffff"
                font.family:    "Roboto"
                font.pixelSize: _s(40)
                font.bold:      true
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Create a secure password to protect your profile"
                color: "#AEAEAE"
                font.family:    "Roboto"
                y: _s(57)
                font.pixelSize: _s(22)
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
        }
    }

    // ─── Enter Password ───────────────────────────────────────────────────────
    Item {
        id: enterSection
        width:  Math.min(_s(508), parent.width - _s(24))
        height: _s(119)
        y:      headerSection.y + headerSection.height + _s(28)
        anchors.horizontalCenter: parent.horizontalCenter

        Column {
            spacing: _s(10)
            width: parent.width

            Text {
                text: "Enter Password"
                color: "#AEAEAE"
                font.family:    "Roboto"
                font.pixelSize: _s(24)
                anchors.left: parent.left
            }

            Rectangle {
                id: enterBox
                width:  parent.width
                height: _s(80)
                radius: 4
                color:  "#222222"
                border.width: 2
                border.color: registerPage.activePassword === "enter" ? "#00826F" : "#ffffff"

                MouseArea {
                    id: enterHover
                    anchors.fill: parent
                    hoverEnabled: false
                    onClicked: {
                        registerPage.activePassword = "enter"
                        enterInput.forceActiveFocus()
                        if (!Qt.inputMethod.visible) Qt.inputMethod.show()
                    }
                }

                TextInput {
                    id: enterInput
                    anchors.left: parent.left
                    anchors.right: enterPasswordToggle.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: registerPage.showEnterPassword ? 0 : registerPage._passwordMaskVerticalOffset
                    anchors.leftMargin: _s(18)
                    anchors.rightMargin: _s(12)
                    height: Math.min(parent.height, Math.max(_s(36), implicitHeight))
                    clip: true
                    color: "#ffffff"
                    selectedTextColor: "#ffffff"
                    selectionColor: "#00826F"
                    font.family: "Roboto"
                    font.pixelSize: _s(24)
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: registerPage.showEnterPassword ? TextInput.Normal : TextInput.Password
                    focus: false
                    maximumLength: 64
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                    onActiveFocusChanged: {
                        if (activeFocus) registerPage.activePassword = "enter"
                    }
                    onTextChanged: {
                        enterPasswordText = text
                        showError = false
                    }
                }

                Text {
                    id: enterPasswordToggle
                    text: registerPage.showEnterPassword ? "Hide" : "Show"
                    color: "#00826F"
                    font.family: "Roboto"
                    font.pixelSize: _s(20)
                    font.bold: true
                    anchors.right: parent.right
                    anchors.rightMargin: _s(18)
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.centerIn: parent
                        width: parent.width + registerPage._s(32)
                        height: parent.height + registerPage._s(28)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            registerPage.showEnterPassword = !registerPage.showEnterPassword
                            enterInput.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }

    // ─── Confirm Password ─────────────────────────────────────────────────────
    Item {
        id: confirmSection
        width:  Math.min(_s(508), parent.width - _s(24))
        height: _s(119)
        y:      enterSection.y + enterSection.height + _s(22)
        anchors.horizontalCenter: parent.horizontalCenter

        Column {
            spacing: _s(10)
            width: parent.width

            Text {
                text: "Confirm Password"
                color: "#AEAEAE"
                font.family:    "Roboto"
                font.pixelSize: _s(24)
                anchors.left:   parent.left
            }

            Rectangle {
                id: confirmBox
                width:  parent.width
                height: _s(80)
                radius: 4
                color:  "#222222"
                border.width: 2
                border.color: registerPage.activePassword === "confirm" ? "#00826F" : "#ffffff"

                MouseArea {
                    id: confirmHover
                    anchors.fill: parent
                    hoverEnabled: false
                    onClicked: {
                        registerPage.activePassword = "confirm"
                        confirmInput.forceActiveFocus()
                        if (!Qt.inputMethod.visible) Qt.inputMethod.show()
                    }
                }

                TextInput {
                    id: confirmInput
                    anchors.left: parent.left
                    anchors.right: confirmPasswordToggle.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: registerPage.showConfirmPassword ? 0 : registerPage._passwordMaskVerticalOffset
                    anchors.leftMargin: _s(18)
                    anchors.rightMargin: _s(12)
                    height: Math.min(parent.height, Math.max(_s(36), implicitHeight))
                    clip: true
                    color: "#ffffff"
                    selectedTextColor: "#ffffff"
                    selectionColor: "#00826F"
                    font.family: "Roboto"
                    font.pixelSize: _s(24)
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: registerPage.showConfirmPassword ? TextInput.Normal : TextInput.Password
                    focus: false
                    maximumLength: 64
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                    onActiveFocusChanged: {
                        if (activeFocus) registerPage.activePassword = "confirm"
                    }
                    onTextChanged: {
                        confirmPasswordText = text
                        showError = false
                    }
                }

                Text {
                    id: confirmPasswordToggle
                    text: registerPage.showConfirmPassword ? "Hide" : "Show"
                    color: "#00826F"
                    font.family: "Roboto"
                    font.pixelSize: _s(20)
                    font.bold: true
                    anchors.right: parent.right
                    anchors.rightMargin: _s(18)
                    anchors.verticalCenter: parent.verticalCenter

                    MouseArea {
                        anchors.centerIn: parent
                        width: parent.width + registerPage._s(32)
                        height: parent.height + registerPage._s(28)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            registerPage.showConfirmPassword = !registerPage.showConfirmPassword
                            confirmInput.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }

    // ─── hint / error text ────────────────────────────────────────────────────
    Text {
        id: hintText
        y:     confirmSection.y + confirmSection.height + _s(26)
        width: Math.min(_s(508), parent.width - _s(24))
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Use 8-32 chars with letters, numbers, and !@#$%^&*"
        color: "#AEAEAE"
        font.family:    "Roboto"
        font.pixelSize: _s(22)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }

    // ─── Continue button ──────────────────────────────────────────────────────
    Rectangle {
        y:      hintText.y + _s(55)
        width:  Math.min(_s(508), parent.width - _s(24))
        height: _s(71)
        radius: 4
        color:  continueBtnArea.pressed ? "#006657" : "#00826F"
        anchors.horizontalCenter: parent.horizontalCenter

        Text {
            anchors.centerIn: parent
            text:           "Continue"
            color:          "#ffffff"
            font.family:    "Roboto"
            font.pixelSize: _s(28)
            font.bold:      true
        }

        MouseArea {
            id: continueBtnArea
            anchors.fill: parent
            onClicked: {
                if (validatePassword()) {
                    var ok = false
                    try { ok = securityManager.setPassword(enterPasswordText) } catch(e) { ok = false }
                    if (ok) {
                        registerPage.pinRegistered()
                    } else {
                        showPasswordError("Failed to store password. Check password requirements.")
                    }
                }
            }
        }
    }

}
