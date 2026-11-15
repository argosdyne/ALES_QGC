import QtQuick 2.12
import "."

// Text input (Figma S22 NTRIP fields): label above, value box below. password: shows dots.
// Emits edited(text) when the user finishes editing (Enter or focus lost) and the text changed.
Column {
    id: tf
    property string label:      ""
    property string text:       ""
    property bool   password:   false
    property bool   numeric:    false
    property string placeholder: ""
    property bool   enabled_:   true
    property real   designWidth: 300
    signal edited(string text)

    width:   SimpleTheme.px(designWidth)
    spacing: SimpleTheme.px(8)
    opacity: enabled_ ? 1 : 0.4

    SText { visible: tf.label !== ""; text: tf.label; size: 22; medium: true; color: SimpleTheme.textSecondary }
    Rectangle {
        width: parent.width; height: SimpleTheme.px(72)
        radius: SimpleTheme.px(14)
        color: SimpleTheme.surfaceControl
        border.width: input.activeFocus ? SimpleTheme.px(2) : 0
        border.color: SimpleTheme.brandGreen
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: SimpleTheme.px(18); anchors.rightMargin: SimpleTheme.px(18)
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            enabled: tf.enabled_
            color: SimpleTheme.textPrimary
            selectionColor: SimpleTheme.brandGreen
            font.family: SimpleTheme.fontFamily
            font.pixelSize: SimpleTheme.fs(26)
            echoMode: tf.password ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            inputMethodHints: tf.numeric ? Qt.ImhDigitsOnly : (tf.password ? Qt.ImhSensitiveData | Qt.ImhNoPredictiveText : Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase)
            validator: tf.numeric ? portValidator : null
            text: tf.text
            onEditingFinished: if (text !== tf.text) tf.edited(text)
            IntValidator { id: portValidator; bottom: 0; top: 65535 }
        }
        SText {
            visible: input.text === "" && !input.activeFocus && tf.placeholder !== ""
            anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(18); anchors.verticalCenter: parent.verticalCenter
            text: tf.placeholder; size: 26; color: SimpleTheme.textTertiary
        }
    }
}
