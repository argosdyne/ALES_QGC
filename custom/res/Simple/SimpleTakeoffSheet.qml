/****************************************************************************
 * AQGC Simple UI — S03 take-off: height presets + slide to take off (Arm + Takeoff in one step)
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

SPanel {
    id: sheet
    property real altitude: 10
    readonly property real _max: Number(QGroundControl.settingsManager.flyViewSettings.guidedMaximumAltitude.rawValue)
    signal confirmed()

    width:  SimpleTheme.px(980)
    height: SimpleTheme.px(400)
    title:  qsTr("Take off")
    titleIcon: "takeoff"
    onVisibleChanged: if (visible) slider.reset()

    Column {
        anchors.fill: parent
        spacing: SimpleTheme.px(22)
        Row {
            spacing: SimpleTheme.px(24)
            SStepper {
                id: stepper
                value: sheet.altitude; from: 2; to: sheet._max; step: 1; unit: "m"
                onEdited: sheet.altitude = value
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: SimpleTheme.px(10)
                Repeater {
                    model: [5, 10, 20, 30, 50]
                    SButton {
                        width: (sheet.bodyItem.width - stepper.width - SimpleTheme.px(24 + 40)) / 5
                        designHeight: 72; textSize: 24
                        text: modelData + " m"
                        kind: sheet.altitude === modelData ? "primary" : "secondary"
                        onClicked: sheet.altitude = Math.min(modelData, sheet._max)
                    }
                }
            }
        }
        SText {
            width: parent.width
            text: qsTr("The drone arms its motors, climbs to %1 m and holds position. Maximum %2 m.").arg(sheet.altitude).arg(sheet._max)
            size: 24; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap
        }
        SSlideConfirm {
            id: slider
            width: parent.width
            text: qsTr("Slide to take off")
            onConfirmed: sheet.confirmed()
        }
    }
}
