import QtQuick                  2.12
import QtQuick.Controls         1.2
import QtPositioning            5.3

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0

// GoTo owns target altitude, rather than the delta used by other guided actions.
// Keeping this control separate prevents changes to Change Altitude, Pause and Orbit.
Rectangle {
    id: root

    property var mapControl
    property var actionData
    property real targetAltitudeMeters: NaN
    property bool initialized: false
    property bool syncingInitialValue: false
    readonly property bool valid: actionData && actionData.map === mapControl && actionData.coordinate &&
                                  isFinite(actionData.targetAltitudeMeters) &&
                                  isFinite(actionData.minimumTargetAltitudeMeters) &&
                                  isFinite(actionData.maximumTargetAltitudeMeters)
    readonly property real minimumAltitudeMeters: valid ? Number(actionData.minimumTargetAltitudeMeters) : 0
    readonly property real maximumAltitudeMeters: valid ? Number(actionData.maximumTargetAltitudeMeters) : 0
    readonly property real margin: ScreenTools.defaultFontPixelWidth / 2

    color: qgcPal.window
    radius: ScreenTools.defaultFontPixelWidth / 2
    visible: valid

    QGCPalette { id: qgcPal }

    function syncFromActionData() {
        initialized = false
        syncingInitialValue = true
        if (valid) {
            targetAltitudeMeters = Number(actionData.targetAltitudeMeters)
            initialValueTimer.restart()
        }
    }

    function setTargetAltitude(value) {
        if (!initialized || !valid || !isFinite(value) || !isFinite(actionData.homeAltitudeAMSL)) {
            return
        }

        targetAltitudeMeters = Math.max(minimumAltitudeMeters, Math.min(maximumAltitudeMeters, value))
        var targetAMSL = actionData.altitudeMode === QGroundControl.AltitudeModeAbsolute ?
                    targetAltitudeMeters : targetAltitudeMeters + Number(actionData.homeAltitudeAMSL)
        actionData.targetAltitudeMeters = targetAltitudeMeters
        actionData.altitudeText = Number(QGroundControl.unitsConversion.metersToAppSettingsVerticalDistanceUnits(targetAltitudeMeters)).toFixed(1) +
                " " + QGroundControl.unitsConversion.appSettingsVerticalDistanceUnitsString
        actionData.coordinate = QtPositioning.coordinate(actionData.coordinate.latitude, actionData.coordinate.longitude, targetAMSL)
    }

    onActionDataChanged: syncFromActionData()
    onValidChanged: {
        if (valid) {
            syncFromActionData()
        }
    }
    Component.onCompleted: syncFromActionData()

    // QGCSlider first evaluates at its minimum before its value binding has
    // consumed targetAltitudeMeters. Wait one event-loop turn so that initial
    // evaluation cannot overwrite the GoTo target with the slider minimum.
    Timer {
        id: initialValueTimer
        interval: 0
        repeat: false
        onTriggered: {
            root.syncingInitialValue = false
            root.initialized = root.valid
        }
    }

    Column {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.margin
        spacing: root.margin / 3

        QGCLabel {
            width: parent.width
            text: qsTr("Altitude")
            horizontalAlignment: Text.AlignHCenter
        }
        QGCLabel {
            width: parent.width
            text: isFinite(root.targetAltitudeMeters) ?
                      Number(QGroundControl.unitsConversion.metersToAppSettingsVerticalDistanceUnits(root.targetAltitudeMeters)).toFixed(1) +
                      " " + QGroundControl.unitsConversion.appSettingsVerticalDistanceUnitsString : "--"
            horizontalAlignment: Text.AlignHCenter
            font.pointSize: ScreenTools.mediumFontPointSize
        }
    }

    QGCSlider {
        id: altitudeSlider
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.margin
        orientation: Qt.Vertical
        minimumValue: root.minimumAltitudeMeters
        maximumValue: root.maximumAltitudeMeters
        value: root.initialized && isFinite(root.targetAltitudeMeters) ? root.targetAltitudeMeters : root.minimumAltitudeMeters
        rotation: 180
        transform: Rotation {
            origin.x: altitudeSlider.width / 2
            origin.y: altitudeSlider.height / 2
            angle: 180
        }
        onValueChanged: {
            if (root.initialized && !root.syncingInitialValue) {
                root.setTargetAltitude(value)
            }
        }
    }
}
