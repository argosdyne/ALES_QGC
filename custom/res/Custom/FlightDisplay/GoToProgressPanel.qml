import QtQuick                  2.12
import QtQuick.Layouts          1.12
import QtPositioning            5.3

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0

// Displays telemetry for a GoTo command that has already been dispatched.
Item {
    id: root

    property var mapControl
    property var vehicle
    property int altitudeMode: QGroundControl.AltitudeModeRelative
    readonly property real margin: ScreenTools.defaultFontPixelHeight / 2
    readonly property var units: QGroundControl.unitsConversion
    readonly property var targetCoordinate: mapControl ? mapControl.gotoProgressCoordinate : QtPositioning.coordinate()
    readonly property bool targetValid: targetCoordinate && targetCoordinate.isValid
    readonly property real remainingDistance: vehicle && vehicle.coordinate.isValid && targetValid ?
                                                vehicle.coordinate.distanceTo(targetCoordinate) : NaN
    readonly property real currentAltitude: vehicle ? Number((altitudeMode === QGroundControl.AltitudeModeAbsolute ?
                                                               vehicle.altitudeAMSL : vehicle.altitudeRelative).rawValue) : NaN
    readonly property real groundSpeed: vehicle ? Number(vehicle.groundSpeed.rawValue) : NaN
    readonly property bool paused: mapControl && mapControl.gotoProgressPaused
    readonly property string termination: mapControl ? mapControl.gotoProgressTermination : ""
    readonly property bool terminating: termination.length > 0
    readonly property real etaSeconds: !paused && !terminating && isFinite(remainingDistance) && isFinite(groundSpeed) && groundSpeed > 0.1 ?
                                      remainingDistance / groundSpeed : NaN
    readonly property real arrivalRadiusMeters: 2
    readonly property bool atTarget: isFinite(remainingDistance) && remainingDistance <= arrivalRadiusMeters
    readonly property bool hoverCandidate: !paused && !terminating && atTarget && vehicle && vehicle.flightMode === vehicle.gotoFlightMode &&
                                           isFinite(groundSpeed) && groundSpeed <= 0.3
    readonly property bool arrived: mapControl && mapControl.gotoArrivalConfirmed
    readonly property real nearestObstacleMeters: obstacleDistanceMeters()
    readonly property bool obstacleDetected: isFinite(nearestObstacleMeters) && nearestObstacleMeters <= 3
    // OBSTACLE_DISTANCE does not include an explicit avoidance state. These two states are inferred from
    // the current obstacle telemetry and ground speed while this GoTo command is active.
    readonly property string status: termination === "rtl" ? qsTr("RTL command sent") :
                                     termination === "land" ? qsTr("Landing command sent") :
                                     termination === "takeControl" ? qsTr("Control handed over - %1").arg(vehicle ? vehicle.takeControlFlightMode : "") :
                                     arrived ? qsTr("Arrived") : paused ? qsTr("Paused") :
                                     (obstacleDetected && (!isFinite(groundSpeed) || groundSpeed <= 0.3) ?
                                      qsTr("Stopped by Obstacle") :
                                      (obstacleDetected && vehicle.objectAvoidance.enabled ? qsTr("Avoiding") : qsTr("Moving")))
    readonly property color statusColor: status === qsTr("Arrived") ? qgcPal.colorGreen : status === qsTr("Paused") || terminating ? qgcPal.colorOrange :
                                         (status === qsTr("Moving") ? qgcPal.colorBlue : qgcPal.colorOrange)

    QGCPalette { id: qgcPal }

    Timer {
        interval: 2000
        repeat: false
        running: root.hoverCandidate && !root.arrived
        onTriggered: {
            if (root.hoverCandidate) {
                root.mapControl.confirmGotoArrival()
            }
        }
    }

    function obstacleDistanceMeters() {
        if (!vehicle || !vehicle.objectAvoidance || !vehicle.objectAvoidance.available) {
            return NaN
        }
        var minimum = Number.POSITIVE_INFINITY
        var maximum = Number(vehicle.objectAvoidance.maxDistance)
        var distances = vehicle.objectAvoidance.distances
        for (var i = 0; i < distances.length; i++) {
            var distance = Number(distances[i])
            if (isFinite(distance) && distance >= 0 && distance < maximum) {
                minimum = Math.min(minimum, distance / 100.0)
            }
        }
        return minimum === Number.POSITIVE_INFINITY ? NaN : minimum
    }

    function displayDistance(distance) {
        return isFinite(distance) ? Number(units.metersToAppSettingsHorizontalDistanceUnits(distance)).toFixed(0) + " " +
                                    units.appSettingsHorizontalDistanceUnitsString : "--"
    }

    function displayAltitude(altitude) {
        return isFinite(altitude) ? Number(units.metersToAppSettingsVerticalDistanceUnits(altitude)).toFixed(1) + " " +
                                    units.appSettingsVerticalDistanceUnitsString : "--"
    }

    implicitHeight: header.height + content.implicitHeight + footer.height + margin * 3 + 4

    Rectangle {
        anchors.fill: parent
        color: qgcPal.missionItemEditor
        radius: ScreenTools.defaultFontPixelWidth / 2
        DeadMouseArea { anchors.fill: parent }
    }

    Item {
        id: header
        anchors.top: parent.top
        width: parent.width
        height: ScreenTools.implicitComboBoxHeight + root.margin

        QGCLabel {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: ScreenTools.defaultFontPixelWidth / 2
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("GoTo - Progress")
            color: qgcPal.primaryButtonText
            font.pointSize: ScreenTools.defaultFontPointSize
        }
    }

    Rectangle {
        id: contentBackground
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 2
        color: qgcPal.windowShadeDark
        radius: ScreenTools.defaultFontPixelWidth / 2
    }

    ColumnLayout {
        id: content
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.margin
        spacing: root.margin

        Rectangle {
            Layout.fillWidth: true
            height: statusLabel.implicitHeight + root.margin * 2
            radius: ScreenTools.defaultFontPixelWidth / 3
            color: root.statusColor
            opacity: 0.85

            QGCLabel {
                id: statusLabel
                anchors.centerIn: parent
                text: root.status
                color: qgcPal.primaryButtonText
                font.pointSize: ScreenTools.mediumFontPointSize
            }
        }

        GridLayout {
            columns: 2
            Layout.fillWidth: true
            columnSpacing: root.margin
            rowSpacing: root.margin

            QGCLabel { text: qsTr("Remaining distance"); font.pointSize: ScreenTools.defaultFontPointSize }
            QGCLabel { Layout.alignment: Qt.AlignRight; text: root.displayDistance(root.remainingDistance) }
            QGCLabel { text: qsTr("Est. ETA"); font.pointSize: ScreenTools.defaultFontPointSize }
            QGCLabel { Layout.alignment: Qt.AlignRight; text: isFinite(root.etaSeconds) ? Math.ceil(root.etaSeconds) + " s" : "--" }
            QGCLabel { text: qsTr("Current altitude"); font.pointSize: ScreenTools.defaultFontPointSize }
            QGCLabel { Layout.alignment: Qt.AlignRight; text: root.displayAltitude(root.currentAltitude) }
        }

        QGCLabel {
            Layout.fillWidth: true
            visible: root.status === qsTr("Avoiding") || root.status === qsTr("Stopped by Obstacle")
            text: qsTr("Nearest obstacle: %1").arg(root.displayDistance(root.nearestObstacleMeters))
            color: qgcPal.warningText
            wrapMode: Text.WordWrap
            font.pointSize: ScreenTools.smallFontPointSize
        }
    }

    QGCButton {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.margin
        text: qsTr("Close")
        visible: root.arrived
        height: visible ? implicitHeight : 0
        onClicked: root.mapControl.clearGotoProgress()
    }
}
