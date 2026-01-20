import QtQuick                  2.12
import QtQuick.Controls         2.12

import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controls      1.0

SpinBox {
    id: control
    editable: true
    antialiasing: true
    focusPolicy: Qt.NoFocus
    inputMethodHints: Qt.ImhFormattedNumbersOnly
    Component.onCompleted: {
        textField.activeFocusOnTab = false
    }

    property alias  unitsLabel: textField.unitsLabel
    property bool   showBorder: qgcPal.globalTheme === QGCPalette.Light
    contentItem: QGCTextField {
        id: textField
        z: 2
        text: control.textFromValue(control.value, control.locale)
        readOnly: !control.editable
        validator: control.validator
        numericValuesOnly: true
        showUnits: unitsLabel.length != 0
        horizontalAlignment: TextInput.AlignHCenter
    }
    up.indicator: Rectangle {
        x: control.mirrored ? 0 : parent.width - width
        height: parent.height
        implicitWidth: ScreenTools.implicitButtonHeight
        implicitHeight: ScreenTools.implicitButtonHeight
        color: control.up.pressed ? qgcPal.buttonHighlight : qgcPal.button
        border.color: qgcPal.buttonBorder
        border.width: showBorder ? 1 : 0
        Text {
            text: "+"
            font.pixelSize: control.font.pixelSize * 2
            color: control.up.pressed ? qgcPal.buttonHighlightText : qgcPal.buttonText
            anchors.fill: parent
            fontSizeMode: Text.Fit
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
    down.indicator: Rectangle {
        x: control.mirrored ? parent.width - width : 0
        height: parent.height
        implicitWidth: ScreenTools.implicitButtonHeight
        implicitHeight: ScreenTools.implicitButtonHeight
        color: control.down.pressed ? qgcPal.buttonHighlight : qgcPal.button
        border.color: qgcPal.buttonBorder
        border.width: showBorder ? 1 : 0
        Text {
            text: "-"
            font.pixelSize: control.font.pixelSize * 2
            color: control.down.pressed ? qgcPal.buttonHighlightText : qgcPal.buttonText
            anchors.fill: parent
            fontSizeMode: Text.Fit
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
    background: Rectangle {
        implicitWidth: ScreenTools.implicitButtonWidth
        // border.color: qgcPal.buttonBorder
        color: qgcPal.textField
    }
}

