/****************************************************************************
 * AQGC Simple UI — S38 change altitude in flight (tap ALTITUDE in the telemetry bar)
 * Big number + − / + (5 m steps, hold to repeat) + presets; the change from now in green (up) / orange (down).
 * Limits: Fly view settings guidedMinimumAltitude … guidedMaximumAltitude (120 m). Slide to confirm.
 * Sends GuidedActionsController.actionChangeAlt (change in metres; ArduPilot switches to Guided and holds).
 * Not during a mission / return / landing: the classic guided bar has the same rule (showChangeAlt).
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

SPanel {
    id: sheet
    property var  vehicle: null
    property real targetM: NaN
    signal confirmed(real changeM)

    readonly property var  _units: QGroundControl.unitsConversion
    readonly property var  _fly:   QGroundControl.settingsManager.flyViewSettings
    readonly property real _minM:  Number(_fly.guidedMinimumAltitude.rawValue)
    readonly property real _maxM:  Number(_fly.guidedMaximumAltitude.rawValue)
    readonly property real _nowM:  vehicle ? Number(vehicle.altitudeRelative.rawValue) : NaN
    readonly property string _vu:  _units.appSettingsVerticalDistanceUnitsString
    readonly property bool  _metric: _vu === "m"
    readonly property real _stepD: _metric ? 5 : 15           // 5 m or 15 ft
    function _toDisp(m) { return Number(_units.metersToAppSettingsVerticalDistanceUnits(m)) }
    function _toM(d)    { return Number(_units.appSettingsVerticalDistanceUnitsToMeters(d)) }

    readonly property real targetD: Math.round(_toDisp(targetM))
    readonly property real changeD: Math.round(_toDisp(targetM) - _toDisp(_nowM))
    readonly property real _minD:  Math.ceil(_toDisp(_minM))
    readonly property real _maxD:  Math.floor(_toDisp(_maxM))

    function _set(d) {
        if (!isFinite(d)) d = isFinite(targetD) ? targetD : _minD
        d = Math.max(_minD, Math.min(_maxD, d))
        targetM = _toM(d)
    }
    function _step(dir) {
        // snap to the step grid first (e.g. 47 → 50 with +, 45 with −)
        var cur = targetD, g = _stepD
        var next = dir > 0 ? Math.floor(cur / g) * g + g : Math.ceil(cur / g) * g - g
        _set(next)
    }

    width:  SimpleTheme.px(1020)
    height: col.implicitHeight + SimpleTheme.px(136)
    title:  qsTr("Change altitude")
    titleIcon: "takeoff"
    // start at the current height (rounded); called when the sheet opens
    function _init() {
        slider.reset()
        targetM = isFinite(_nowM) ? _toM(Math.max(_minD, Math.min(_maxD, Math.round(_toDisp(_nowM))))) : _minM
    }
    onVisibleChanged: if (visible) _init()
    Component.onCompleted: _init()

    Column {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        spacing: SimpleTheme.px(20)

        Row {
            spacing: SimpleTheme.px(36)
            Rectangle {
                width: SimpleTheme.px(120); height: width; radius: width / 2
                color: minusMa.pressed ? Qt.darker(SimpleTheme.surfaceControl, 1.3) : SimpleTheme.surfaceControl
                opacity: sheet.targetD > sheet._minD ? 1 : 0.4
                SIcon { anchors.centerIn: parent; name: "minus"; size: 48 }
                MouseArea {
                    id: minusMa; anchors.fill: parent; enabled: sheet.targetD > sheet._minD
                    onPressed: sheet._step(-1)
                    onPressAndHold: repeat.start()
                    onReleased: repeat.stop(); onCanceled: repeat.stop()
                    Timer { id: repeat; interval: 150; repeat: true; onTriggered: sheet._step(-1) }
                }
            }
            Column {
                width: SimpleTheme.px(300)
                anchors.verticalCenter: parent.verticalCenter
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: SimpleTheme.px(8)
                    SText { id: big; text: isFinite(sheet.targetD) ? sheet.targetD : "—"; size: 96; bold: true }
                    SText { text: sheet._vu; size: 34; color: SimpleTheme.textSecondary; anchors.baseline: big.baseline }
                }
                SText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: 24
                    color: sheet.changeD > 0 ? SimpleTheme.ok : sheet.changeD < 0 ? SimpleTheme.warn : SimpleTheme.textSecondary
                    text: qsTr("now %1").arg(isFinite(sheet._nowM) ? Math.round(sheet._toDisp(sheet._nowM)) + " " + sheet._vu : "—")
                          + (isFinite(sheet.changeD) && sheet.changeD !== 0 ? " · " + (sheet.changeD > 0 ? "+" : "−") + Math.abs(sheet.changeD) + " " + sheet._vu : "")
                }
            }
            Rectangle {
                width: SimpleTheme.px(120); height: width; radius: width / 2
                color: plusMa.pressed ? Qt.darker(SimpleTheme.surfaceControl, 1.3) : SimpleTheme.surfaceControl
                opacity: sheet.targetD < sheet._maxD ? 1 : 0.4
                SIcon { anchors.centerIn: parent; name: "plus"; size: 48 }
                MouseArea {
                    id: plusMa; anchors.fill: parent; enabled: sheet.targetD < sheet._maxD
                    onPressed: sheet._step(1)
                    onPressAndHold: repeatUp.start()
                    onReleased: repeatUp.stop(); onCanceled: repeatUp.stop()
                    Timer { id: repeatUp; interval: 150; repeat: true; onTriggered: sheet._step(1) }
                }
            }
        }

        Row {
            spacing: SimpleTheme.px(14)
            Repeater {
                model: sheet._metric ? [30, 50, 80, 100, 120] : [100, 150, 250, 300, 400]
                SButton {
                    visible: modelData <= sheet._maxD && modelData >= sheet._minD
                    width: SimpleTheme.px(150); designHeight: 80; textSize: 26
                    text: modelData + " " + sheet._vu
                    kind: sheet.targetD === modelData ? "primary" : "secondary"
                    onClicked: sheet._set(modelData)
                }
            }
        }

        Row {
            spacing: SimpleTheme.px(10)
            SIcon { name: "info"; size: 28; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            SText {
                size: 22; color: SimpleTheme.textSecondary
                text: qsTr("Height above the home point · allowed %1 – %2 %3 · the drone then holds position")
                      .arg(sheet._minD).arg(sheet._maxD).arg(sheet._vu)
            }
        }

        SSlideConfirm {
            id: slider
            width: parent.width
            text: sheet.changeD === 0 ? qsTr("Already at %1 %2").arg(sheet.targetD).arg(sheet._vu)
                                      : qsTr("Slide to change to %1 %2").arg(sheet.targetD).arg(sheet._vu)
            onConfirmed: {
                if (sheet.changeD === 0 || !isFinite(sheet._nowM)) { slider.reset(); return }
                sheet.confirmed(sheet.targetM - sheet._nowM)
            }
        }
    }
}
