import QtQuick 2.15

Rectangle {
    id: root
    width: 48
    height: 56
    radius: 8
    color: "#4a5568"
    border.width: 2
    border.color: input.activeFocus ? "#5a8cff" : "#808080"
    activeFocusOnTab: true

    property alias text: input.text
    property int index
    property bool enabled: true
    signal nextRequested(int index)
    signal prevRequested(int index)

    onActiveFocusChanged: {
        if (activeFocus && enabled) {
            input.forceActiveFocus()
        }
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.margins: 4
        horizontalAlignment: TextInput.AlignHCenter
        verticalAlignment: TextInput.AlignVCenter
        font.pixelSize: 32
        font.bold: true
        color: "white"
        selectedTextColor: "white"
        selectionColor: "#5a8cff"
        maximumLength: 1
        inputMethodHints: Qt.ImhDigitsOnly
        selectByMouse: false
        persistentSelection: true
        focus: true
        enabled: root.enabled

        onTextChanged: {
            if (text.length === 1) {
                root.nextRequested(root.index)
            }
        }

        Keys.onPressed: {
            if (event.key === Qt.Key_Backspace) {
                if (text.length === 0) {
                    root.prevRequested(root.index)
                    event.accepted = true
                } else {
                    text = ""
                    event.accepted = true
                }
            } else if (event.key === Qt.Key_Left) {
                if (cursorPosition === 0) {
                    root.prevRequested(root.index)
                    event.accepted = true
                }
            } else if (event.key === Qt.Key_Right) {
                if (cursorPosition === text.length) {
                    root.nextRequested(root.index)
                    event.accepted = true
                }
            }
        }
    }
}
