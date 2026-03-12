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
    id: restorePage

    signal cancelClicked()
    signal confirmRestoreClicked()

    property bool locked: false
    property bool phraseBoxFocused: false
    readonly property string _lockoutScope: "system_restore"
    property real _uiScale: ScreenTools.isMobile ? 1.1 : 0.6

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
        return securityManager.verifyRestorePhrase(phraseInput.text)
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
    function _s(px) { return Math.round(px * _uiScale) }

    Item {
        id: content
        width: Math.min(_s(1019), parent.width - _s(24))
        height: _s(745)
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
                x: _s(33)
                y: _s(20)
                width: _s(52)
                height: _s(43)
                source: "/custom/img/caution.svg"
                fillMode: Image.PreserveAspectFit
            }

            Text {
                x: _s(94)
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("SYSTEM Restore")
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
                    onClicked: cancelClicked()
                }
            }

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

        Rectangle {
            x: _s(80)
            y: _s(139)
            width: Math.min(_s(858), parent.width - _s(160))
            height: _s(243)
            radius: 4
            color: "#485058"

            Text {
                y: _s(20)
                width: parent.width
                text: qsTr("You are performing an Admin-level security restore.\nThis action will perform the following:")
                color: "#AEAEAE"
                font.family: "Roboto"
                font.pixelSize: _s(28)
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.2
            }

            Text {
                y: _s(109)
                width: parent.width
                text: qsTr("1. Delete all currently configured PINs.\n2. Delete all security key in the Keystore.\n3. Require a full initial setup.")
                color: "#FFFFFF"
                font.family: "Roboto"
                font.pixelSize: _s(28)
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.2
            }
        }

        Text {
            y: _s(428)
            width: parent.width
            text: qsTr("Please type the exact phrase from system admin:")
            color: "#FFFFFF"
            font.family: "Roboto"
            font.pixelSize: _s(32)
            horizontalAlignment: Text.AlignHCenter
        }

        Rectangle {
            id: phraseBox
            x: _s(80)
            y: _s(487)
            width: Math.min(_s(858), parent.width - _s(160))
            height: _s(80)
            radius: 4
            color: "#2D2D2D"
            border.width: 2
            border.color: restorePage.phraseBoxFocused ? "#00C2AD" : "#FFFFFF"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: false
                onClicked: {
                    if (restorePage.locked) return
                    restorePage.phraseBoxFocused = true
                    phraseInput.forceActiveFocus()
                    if (!Qt.inputMethod.visible) Qt.inputMethod.show()
                }
            }

            TextInput {
                id: phraseInput
                anchors.fill: parent
                anchors.leftMargin: _s(20)
                anchors.rightMargin: _s(20)
                verticalAlignment: Text.AlignVCenter
                color: locked ? "#AEAEAE" : "#FFFFFF"
                font.family: "Roboto"
                font.pixelSize: _s(34)
                inputMethodHints: Qt.ImhUppercaseOnly | Qt.ImhNoPredictiveText
                onActiveFocusChanged: restorePage.phraseBoxFocused = activeFocus
                onTextChanged: feedbackText.visible = false
                Keys.onPressed: {
                    if (locked) { event.accepted = true; return }
                }
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: _s(20)
                anchors.rightMargin: _s(20)
                verticalAlignment: Text.AlignVCenter
                text: phraseInput.text.length > 0 ? phraseInput.text : qsTr("Re-type the exact phrase here...")
                color: phraseInput.text.length > 0 ? "transparent" : "#AEAEAE"
                font.family: "Roboto"
                font.pixelSize: _s(34)

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (restorePage.locked) return
                        restorePage.phraseBoxFocused = true
                        phraseInput.forceActiveFocus()
                        if (!Qt.inputMethod.visible) Qt.inputMethod.show()
                    }
                }
            }
        }

        Rectangle {
            id: confirmButton
            x: (content.width - width) / 2
            y: _s(617)
            width: Math.min(_s(508), parent.width - _s(24))
            height: _s(71)
            radius: 4
            color: confirmMouse.pressed ? "#0B8A7A" : "#00826F"
            opacity: locked ? 0.5 : 1.0

            Text {
                anchors.centerIn: parent
                text: qsTr("Confirm")
                color: "#FFFFFF"
                font.family: "Roboto"
                font.pixelSize: _s(28)
                font.styleName: "Medium"
            }

            MouseArea {
                id: confirmMouse
                anchors.fill: parent
                enabled: !locked
                onClicked: _confirmRestore()
            }
        }

        Text {
            id: feedbackText
            x: 0
            y: _s(575)
            width: parent.width
            visible: false
            color: "#ff5c5c"
            font.family: "Roboto"
            font.pixelSize: _s(24)
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Component.onCompleted: {
        if (securityManager.isLockedForScope(restorePage._lockoutScope)) {
            locked = true
            lockoutTimer.start()
        }
    }
}
