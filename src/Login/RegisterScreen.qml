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
    id: registerPage

    signal pinRegistered()

    property int    pinLength:      6
    property string enterPinText:   ""
    property string confirmPinText: ""
    property string errorMessage:   ""
    property bool   showError:      false
    property string messageColor:   "#ff5c5c"
    property real _uiScale: ScreenTools.isMobile ? 1.20 : 0.65
    property int _contentBlockHeight: _s(687)
    property string activePin:        ""   // "enter" | "confirm" | ""

    background: Rectangle {
        color: "#222222"
        opacity: 0
        radius: 16
    }

    // ─── helpers ──────────────────────────────────────────────────────────────
    function validatePIN() {
        var p1 = enterPinText
        var p2 = confirmPinText

        if (p1.length < 6 || p2.length < 6) {
            errorMessage = "Enter 6 digits for your PIN"
            messageColor = "#ff5c5c"
            showError = true
            return false
        }

        var strengthError = securityManager.validatePINStrength(p1)
        if (strengthError) {
            errorMessage = strengthError
            messageColor = "#ff5c5c"
            showError = true
            return false
        }

        if (p1 !== p2) {
            errorMessage = "PINs do not match"
            messageColor = "#ff5c5c"
            showError = true
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
                text: "Set Your Admin PIN"
                color: "#ffffff"
                font.family:    "Roboto"
                font.pixelSize: _s(40)
                font.bold:      true
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Create a secure 6 digits PIN to protect your profile"
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

    // ─── Enter PIN ────────────────────────────────────────────────────────────
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
                text: "Enter PIN"
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
                border.color: registerPage.activePin === "enter" ? "#00826F" : "#ffffff"

                property string pinValue: ""

                MouseArea {
                    id: enterHover
                    anchors.fill: parent
                    hoverEnabled: false
                    onClicked: {
                        registerPage.activePin = "enter"
                        enterInput.forceActiveFocus()
                        if (!Qt.inputMethod.visible) Qt.inputMethod.show()
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: _s(20)
                    Repeater {
                        model: pinLength
                        Rectangle {
                            width: _s(18); height: _s(18); radius: _s(9)
                            readonly property bool filled: index < enterBox.pinValue.length
                            color:        filled ? "#ffffff" : "transparent"
                            border.width: filled ? 0 : 2
                            border.color: "#ffffff"
                        }
                    }
                }

                TextInput {
                    id: enterInput
                    width: 1; height: 1; opacity: 0
                    focus: false
                    maximumLength: 8
                    inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                    onTextChanged: {
                        enterBox.pinValue = text
                        enterPinText      = text
                        var err = text.length >= 6 ? securityManager.validatePINStrength(text) : ""
                        if (err) { errorMessage = err; messageColor = "#ff5c5c"; showError = true }
                        else     { showError = false }
                    }
                    Keys.onPressed: {
                        if (event.text.length === 1 && event.text >= "0" && event.text <= "9") {
                            if (enterBox.pinValue.length < 6) {
                                enterBox.pinValue = enterBox.pinValue + event.text
                                enterInput.text   = enterBox.pinValue
                                // Auto-jump to Confirm PIN when 6th digit is entered
                                if (enterBox.pinValue.length === 6) {
                                    registerPage.activePin = "confirm"
                                    confirmInput.forceActiveFocus()
                                }
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Backspace) {
                            if (enterBox.pinValue.length > 0) {
                                enterBox.pinValue = enterBox.pinValue.slice(0, enterBox.pinValue.length - 1)
                                enterInput.text   = enterBox.pinValue
                            }
                            event.accepted = true
                        }
                    }
                }
            }
        }
    }

    // ─── Confirm PIN ──────────────────────────────────────────────────────────
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
                text: "Confirm PIN"
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
                border.color: registerPage.activePin === "confirm" ? "#00826F" : "#ffffff"

                property string pinValue: ""

                MouseArea {
                    id: confirmHover
                    anchors.fill: parent
                    hoverEnabled: false
                    onClicked: {
                        registerPage.activePin = "confirm"
                        confirmInput.forceActiveFocus()
                        if (!Qt.inputMethod.visible) Qt.inputMethod.show()
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: _s(20)
                    Repeater {
                        model: pinLength
                        Rectangle {
                            width: _s(18); height: _s(18); radius: _s(9)
                            readonly property bool filled: index < confirmBox.pinValue.length
                            color:        filled ? "#ffffff" : "transparent"
                            border.width: filled ? 0 : 2
                            border.color: "#ffffff"
                        }
                    }
                }

                TextInput {
                    id: confirmInput
                    width: 1; height: 1; opacity: 0
                    anchors.bottom: parent.bottom
                    focus: false
                    maximumLength: 6
                    inputMethodHints: Qt.ImhDigitsOnly | Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                    onTextChanged: {
                        confirmBox.pinValue = text
                        confirmPinText      = text
                    }
                    Keys.onPressed: {
                        if (event.text.length === 1 && event.text >= "0" && event.text <= "9") {
                            if (confirmBox.pinValue.length < 6) {
                                confirmBox.pinValue = confirmBox.pinValue + event.text
                                confirmInput.text   = confirmBox.pinValue
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Backspace) {
                            if (confirmBox.pinValue.length > 0) {
                                confirmBox.pinValue = confirmBox.pinValue.slice(0, confirmBox.pinValue.length - 1)
                                confirmInput.text   = confirmBox.pinValue
                            }
                            event.accepted = true
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
        text:  showError ? errorMessage : "Enter 6 digits for your PIN"
        color: showError ? messageColor : "#AEAEAE"
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
                if (validatePIN()) {
                    var ok = false
                    try { ok = securityManager.setPin(enterPinText) } catch(e) { ok = false }
                    if (ok) {
                        registerPage.pinRegistered()
                    } else {
                        errorMessage = "Failed to store PIN. Check PIN requirements."
                        messageColor = "#ff5c5c"
                        showError    = true
                    }
                }
            }
        }
    }
}
