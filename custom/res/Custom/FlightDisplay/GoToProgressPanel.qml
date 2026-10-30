import QtQuick                  2.12
import QtQuick.Layouts          1.12
import QtPositioning            5.3

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0

// G-04: telemetry and state for an already dispatched GoTo command.
Item {
    id: root

    property var mapControl
    property var vehicle
    property int altitudeMode: QGroundControl.AltitudeModeRelative

    readonly property real margin: ScreenTools.defaultFontPixelHeight / 2
    readonly property var units: QGroundControl.unitsConversion
    readonly property var targetCoordinate: mapControl ? mapControl.gotoProgressCoordinate : QtPositioning.coordinate()
    readonly property bool targetValid: targetCoordinate && targetCoordinate.isValid
    readonly property bool linkLost: vehicle && vehicle.vehicleLinkManager && vehicle.vehicleLinkManager.communicationLost
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
    readonly property string status: termination === "rtl" ? qsTr("RTL command sent") :
                                     termination === "land" ? qsTr("Landing command sent") :
                                     termination === "takeControl" ? qsTr("Control handed over") :
                                     arrived ? qsTr("Arrived") : paused ? qsTr("Paused") :
                                     (obstacleDetected && (!isFinite(groundSpeed) || groundSpeed <= 0.3) ? qsTr("Stopped by Obstacle") :
                                      (obstacleDetected && vehicle.objectAvoidance.enabled ? qsTr("Avoiding") : qsTr("Moving")))
    readonly property color statusColor: status === qsTr("Arrived") ? qgcPal.colorGreen :
                                         status === qsTr("Paused") || terminating ? qgcPal.colorOrange :
                                         status === qsTr("Moving") ? qgcPal.colorBlue : qgcPal.colorOrange
    readonly property string obstacleResponse: vehicle && vehicle.objectAvoidance &&
                                                vehicle.objectAvoidance.available && vehicle.objectAvoidance.enabled ?
                                                qsTr("Level 1") : qsTr("Unavailable")

    property bool commandAcceptedVisible: true
    readonly property var startCoordinate: mapControl ? mapControl.gotoProgressStartCoordinate : QtPositioning.coordinate()
    property double tripStartedAt: 0
    property int obstacleEventCount: 0
    property bool _obstacleWasDetected: false
    readonly property real tripDistance: startCoordinate && startCoordinate.isValid && targetValid ?
                                        startCoordinate.distanceTo(targetCoordinate) : NaN
    property real elapsedSeconds: NaN
    // Preserve the last telemetry received before a link loss. Do not keep showing
    // live-looking values after the vehicle has stopped reporting.
    property real lastKnownRemainingDistance: NaN
    property real lastKnownAltitude: NaN
    property real lastKnownGroundSpeed: NaN
    property string lastKnownFlightMode: ""
    property double linkLostAt: 0
    property int linkLostSeconds: 0
    // All value labels use this same column, so their right edge never moves.
    readonly property real valueColumnWidth: ScreenTools.defaultFontPixelWidth * 9

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

    Timer {
        interval: 1000
        repeat: true
        running: !root.arrived
        triggeredOnStart: true
        onTriggered: root.elapsedSeconds = root.tripStartedAt > 0 ? (Date.now() - root.tripStartedAt) / 1000 : NaN
    }

    Component.onCompleted: {
        tripStartedAt = Date.now()
        elapsedSeconds = 0
        if (linkLost) {
            captureLastKnownTelemetry()
        }
        _obstacleWasDetected = obstacleDetected
        if (_obstacleWasDetected && vehicle && vehicle.objectAvoidance.enabled) {
            obstacleEventCount = 1
        }
    }

    onObstacleDetectedChanged: {
        if (obstacleDetected && !_obstacleWasDetected && vehicle && vehicle.objectAvoidance.enabled) {
            obstacleEventCount++
        }
        _obstacleWasDetected = obstacleDetected
    }

    onLinkLostChanged: {
        if (linkLost) {
            captureLastKnownTelemetry()
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.linkLost
        triggeredOnStart: true
        onTriggered: root.linkLostSeconds = root.linkLostAt > 0 ? Math.max(0, Math.floor((Date.now() - root.linkLostAt) / 1000)) : 0
    }

    Timer {
        interval: 4500
        repeat: false
        running: root.commandAcceptedVisible
        onTriggered: root.commandAcceptedVisible = false
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

    function displayEta(seconds) {
        if (!isFinite(seconds)) {
            return "--:--"
        }
        var rounded = Math.ceil(seconds)
        return Math.floor(rounded / 60) + ":" + (rounded % 60 < 10 ? "0" : "") + (rounded % 60)
    }

    function captureLastKnownTelemetry() {
        lastKnownRemainingDistance = remainingDistance
        lastKnownAltitude = currentAltitude
        lastKnownGroundSpeed = groundSpeed
        lastKnownFlightMode = vehicle ? vehicle.flightMode : ""
        linkLostAt = Date.now()
        linkLostSeconds = 0
    }

    function displayLastReceived(seconds) {
        return seconds < 60 ? qsTr("%1 s ago").arg(seconds) :
                              qsTr("%1 min ago").arg(Math.floor(seconds / 60))
    }

    implicitWidth: ScreenTools.defaultFontPixelWidth * 20
    implicitHeight: toastSlot.height + margin + panel.implicitHeight

    Rectangle {
        id: toast
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: toastSlot.height
        color: qgcPal.missionItemEditor
        visible: !root.linkLost && (root.commandAcceptedVisible || root.arrived)
        opacity: visible ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 180 } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: root.margin
            spacing: root.margin

            Rectangle {
                Layout.preferredWidth: ScreenTools.defaultFontPixelHeight * 1.5
                Layout.preferredHeight: width
                radius: width / 2
                color: root.arrived ? qgcPal.colorGreen : qgcPal.colorBlue
            }
            QGCLabel {
                Layout.fillWidth: true
                text: root.arrived ? qsTr("GoTo: arrived at target,\nhovering") : qsTr("GoTo command accepted")
                color: qgcPal.primaryButtonText
                wrapMode: Text.WordWrap
            }
        }
    }

    Item {
        id: toastSlot
        anchors.left: parent.left
        anchors.right: parent.right
        height: ScreenTools.defaultFontPixelHeight * 3
    }

    Rectangle {
        id: panel
        anchors.top: toastSlot.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        implicitHeight: (root.linkLost ? linkLostContent.implicitHeight :
                         root.arrived ? arrivedContent.implicitHeight : panelContent.implicitHeight) + root.margin * 2
        color: qgcPal.windowShadeDark
        radius: ScreenTools.defaultFontPixelWidth / 3
        DeadMouseArea { anchors.fill: parent }

        ColumnLayout {
            id: panelContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.margin
            spacing: root.margin
            visible: !root.arrived && !root.linkLost

            RowLayout {
                Layout.fillWidth: true

                QGCLabel {
                    text: qsTr("GoTo")
                    font.pointSize: ScreenTools.mediumFontPointSize
                    color: qgcPal.primaryButtonText
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: statusPill.implicitWidth + root.margin * 2
                    Layout.preferredHeight: statusPill.implicitHeight + root.margin / 2
                    radius: height / 2
                    color: root.statusColor
                    QGCLabel {
                        id: statusPill
                        anchors.centerIn: parent
                        text: root.status.toUpperCase()
                        color: qgcPal.primaryButtonText
                        font.bold: true
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }
            }

            QGCLabel {
                Layout.fillWidth: true
                text: vehicle ? qsTr("Guided") : qsTr("Vehicle unavailable")
                color: qgcPal.buttonText
                opacity: 0.65
                font.pointSize: ScreenTools.smallFontPointSize
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: qgcPal.text; opacity: 0.18 }

            QGCLabel {
                text: qsTr("PROGRESS")
                color: qgcPal.buttonText
                opacity: 0.65
                font.bold: true
                font.pointSize: ScreenTools.smallFontPointSize
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: root.margin
                rowSpacing: root.margin / 3

                QGCLabel { Layout.fillWidth: true; text: qsTr("Remaining"); color: qgcPal.buttonText; opacity: 0.65 }
                QGCLabel { Layout.preferredWidth: root.valueColumnWidth; Layout.minimumWidth: root.valueColumnWidth; Layout.maximumWidth: root.valueColumnWidth; horizontalAlignment: Text.AlignRight; text: root.displayDistance(root.remainingDistance); font.bold: true }
                Rectangle {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    height: ScreenTools.defaultFontPixelHeight / 3
                    color: qgcPal.text
                    opacity: 0.8
                    Rectangle {
                        width: parent.width * (isFinite(root.remainingDistance) && isFinite(root.tripDistance) && root.tripDistance > 0 ?
                                                   Math.max(0, Math.min(1, 1 - root.remainingDistance / root.tripDistance)) : 0)
                        height: parent.height
                        color: qgcPal.colorBlue
                    }
                }
                QGCLabel { Layout.fillWidth: true; text: qsTr("ETA"); color: qgcPal.buttonText; opacity: 0.65 }
                QGCLabel { Layout.preferredWidth: root.valueColumnWidth; Layout.minimumWidth: root.valueColumnWidth; Layout.maximumWidth: root.valueColumnWidth; horizontalAlignment: Text.AlignRight; text: root.displayEta(root.etaSeconds); font.bold: true }
                QGCLabel { Layout.fillWidth: true; text: qsTr("Ground speed"); color: qgcPal.buttonText; opacity: 0.65 }
                QGCLabel { Layout.preferredWidth: root.valueColumnWidth; Layout.minimumWidth: root.valueColumnWidth; Layout.maximumWidth: root.valueColumnWidth; horizontalAlignment: Text.AlignRight; text: isFinite(root.groundSpeed) ? root.groundSpeed.toFixed(1) + " m/s" : "--"; font.bold: true }
                QGCLabel {
                    Layout.fillWidth: true
                    text: qsTr("Altitude (%1)").arg(QGroundControl.altitudeModeShortDescription(root.altitudeMode))
                    color: qgcPal.buttonText
                    opacity: 0.65
                }
                QGCLabel { Layout.preferredWidth: root.valueColumnWidth; Layout.minimumWidth: root.valueColumnWidth; Layout.maximumWidth: root.valueColumnWidth; horizontalAlignment: Text.AlignRight; text: root.displayAltitude(root.currentAltitude); font.bold: true }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: qgcPal.text; opacity: 0.18 }
            QGCLabel {
                text: qsTr("TARGET")
                color: qgcPal.buttonText
                opacity: 0.65
                font.bold: true
                font.pointSize: ScreenTools.smallFontPointSize
            }
            QGCLabel {
                Layout.fillWidth: true
                text: root.targetValid ? root.targetCoordinate.latitude.toFixed(6) + ", " + root.targetCoordinate.longitude.toFixed(6) : "--"
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.fillWidth: true
                QGCLabel { text: qsTr("Obstacle response"); color: qgcPal.buttonText; opacity: 0.65 }
                Item { Layout.fillWidth: true }
                QGCLabel {
                    Layout.preferredWidth: root.valueColumnWidth
                    Layout.minimumWidth: root.valueColumnWidth
                    Layout.maximumWidth: root.valueColumnWidth
                    horizontalAlignment: Text.AlignRight
                    text: root.obstacleResponse
                    color: root.obstacleResponse === qsTr("Unavailable") ? qgcPal.warningText : qgcPal.colorGreen
                    font.bold: true
                }
            }
            QGCLabel {
                Layout.fillWidth: true
                text: root.arrived ? qsTr("Arrival confirmed. The vehicle is hovering at the target.") :
                      root.paused ? qsTr("Paused. Use Continue GoTo to resume from the current position.") :
                      qsTr("Tap the map to change the target (confirm again).")
                color: qgcPal.buttonText
                opacity: 0.65
                wrapMode: Text.WordWrap
                font.pointSize: ScreenTools.smallFontPointSize
            }
        }

        ColumnLayout {
            id: arrivedContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.margin
            spacing: root.margin
            visible: root.arrived && !root.linkLost

            RowLayout {
                Layout.fillWidth: true
                QGCLabel {
                    text: qsTr("GoTo")
                    font.pointSize: ScreenTools.mediumFontPointSize
                    color: qgcPal.primaryButtonText
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: arrivedPill.implicitWidth + root.margin * 2
                    Layout.preferredHeight: arrivedPill.implicitHeight + root.margin / 2
                    radius: height / 2
                    color: qgcPal.colorGreen
                    QGCLabel {
                        id: arrivedPill
                        anchors.centerIn: parent
                        text: qsTr("ARRIVED")
                        color: qgcPal.primaryButtonText
                        font.bold: true
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }
            }
            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("Guided")
                color: qgcPal.buttonText
                opacity: 0.65
                font.pointSize: ScreenTools.smallFontPointSize
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: qgcPal.text; opacity: 0.18 }
            QGCLabel {
                text: qsTr("RESULT")
                color: qgcPal.buttonText
                opacity: 0.65
                font.bold: true
                font.pointSize: ScreenTools.smallFontPointSize
            }
            QGCLabel {
                Layout.fillWidth: true
                text: root.targetValid ? root.targetCoordinate.latitude.toFixed(6) + ", " + root.targetCoordinate.longitude.toFixed(6) : "--"
                elide: Text.ElideRight
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: root.margin
                rowSpacing: root.margin / 3
                QGCLabel { Layout.fillWidth: true; text: qsTr("Altitude (%1)").arg(QGroundControl.altitudeModeShortDescription(root.altitudeMode)); color: qgcPal.buttonText; opacity: 0.65 }
                QGCLabel { Layout.preferredWidth: root.valueColumnWidth; Layout.minimumWidth: root.valueColumnWidth; Layout.maximumWidth: root.valueColumnWidth; horizontalAlignment: Text.AlignRight; text: root.displayAltitude(root.currentAltitude); font.bold: true }
                QGCLabel { Layout.fillWidth: true; text: qsTr("Trip"); color: qgcPal.buttonText; opacity: 0.65 }
                QGCLabel { Layout.preferredWidth: root.valueColumnWidth; Layout.minimumWidth: root.valueColumnWidth; Layout.maximumWidth: root.valueColumnWidth; horizontalAlignment: Text.AlignRight; text: root.displayDistance(root.tripDistance) + " · " + root.displayEta(root.elapsedSeconds); font.bold: true }
                QGCLabel { Layout.fillWidth: true; text: qsTr("Obstacle events"); color: qgcPal.buttonText; opacity: 0.65 }
                QGCLabel {
                    Layout.preferredWidth: root.valueColumnWidth
                    Layout.minimumWidth: root.valueColumnWidth
                    Layout.maximumWidth: root.valueColumnWidth
                    horizontalAlignment: Text.AlignRight
                    text: root.obstacleEventCount > 0 ? qsTr("%1 (avoided)").arg(root.obstacleEventCount) : qsTr("None")
                    color: root.obstacleEventCount > 0 ? qgcPal.colorOrange : qgcPal.buttonText
                    font.bold: true
                }
            }
            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("The vehicle holds position. Tap the map to choose the next target.")
                color: qgcPal.buttonText
                opacity: 0.65
                wrapMode: Text.WordWrap
                font.pointSize: ScreenTools.smallFontPointSize
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: root.margin
                QGCButton {
                    Layout.fillWidth: true
                    text: qsTr("Return")
                    onClicked: globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionRTL)
                }
                QGCButton {
                    Layout.fillWidth: true
                    text: qsTr("Land")
                    onClicked: globals.guidedControllerFlyView.confirmAction(globals.guidedControllerFlyView.actionLand)
                }
            }
        }

        // Keep this within the same GoTo progress panel so its placement and width
        // remain identical while telemetry is unavailable.
        ColumnLayout {
            id: linkLostContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: root.margin
            spacing: root.margin
            visible: root.linkLost

            RowLayout {
                Layout.fillWidth: true

                QGCLabel {
                    text: qsTr("GoTo")
                    font.pointSize: ScreenTools.mediumFontPointSize
                    color: qgcPal.primaryButtonText
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: noLinkPill.implicitWidth + root.margin * 2
                    Layout.preferredHeight: noLinkPill.implicitHeight + root.margin / 2
                    radius: height / 2
                    color: qgcPal.window
                    border.color: qgcPal.colorRed
                    border.width: 1
                    QGCLabel {
                        id: noLinkPill
                        anchors.centerIn: parent
                        text: qsTr("NO LINK")
                        color: qgcPal.colorRed
                        font.bold: true
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }
            }

            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("Last known mode: %1").arg(root.lastKnownFlightMode.length ? root.lastKnownFlightMode : qsTr("Unknown"))
                color: qgcPal.buttonText
                opacity: 0.65
                font.pointSize: ScreenTools.smallFontPointSize
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: qgcPal.text; opacity: 0.18 }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: linkLossWarning.implicitHeight + root.margin * 2
                color: qgcPal.windowShadeDark
                border.color: qgcPal.colorRed
                border.width: 1
                radius: ScreenTools.defaultFontPixelWidth / 3

                ColumnLayout {
                    id: linkLossWarning
                    anchors.fill: parent
                    anchors.margins: root.margin
                    spacing: root.margin / 3
                    QGCLabel {
                        Layout.fillWidth: true
                        text: qsTr("Communication lost")
                        color: qgcPal.colorRed
                        font.bold: true
                    }
                    QGCLabel {
                        Layout.fillWidth: true
                        text: qsTr("The flight controller will apply its configured data-link-loss failsafe. GoTo commands are unavailable until the link is restored.")
                        color: qgcPal.primaryButtonText
                        wrapMode: Text.WordWrap
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }
            }

            QGCLabel {
                text: qsTr("LAST RECEIVED · %1").arg(root.displayLastReceived(root.linkLostSeconds).toUpperCase())
                color: qgcPal.buttonText
                opacity: 0.65
                font.bold: true
                font.pointSize: ScreenTools.smallFontPointSize
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: root.margin
                rowSpacing: root.margin / 3
                QGCLabel { Layout.fillWidth: true; text: qsTr("Remaining"); color: qgcPal.buttonText; opacity: 0.65 }
                QGCLabel { Layout.preferredWidth: root.valueColumnWidth; Layout.minimumWidth: root.valueColumnWidth; Layout.maximumWidth: root.valueColumnWidth; horizontalAlignment: Text.AlignRight; text: root.displayDistance(root.lastKnownRemainingDistance); font.bold: true; color: qgcPal.buttonText; opacity: 0.65 }
                QGCLabel { Layout.fillWidth: true; text: qsTr("Altitude (%1)").arg(QGroundControl.altitudeModeShortDescription(root.altitudeMode)); color: qgcPal.buttonText; opacity: 0.65 }
                QGCLabel { Layout.preferredWidth: root.valueColumnWidth; Layout.minimumWidth: root.valueColumnWidth; Layout.maximumWidth: root.valueColumnWidth; horizontalAlignment: Text.AlignRight; text: root.displayAltitude(root.lastKnownAltitude); font.bold: true; color: qgcPal.buttonText; opacity: 0.65 }
                QGCLabel { Layout.fillWidth: true; text: qsTr("Ground speed"); color: qgcPal.buttonText; opacity: 0.65 }
                QGCLabel { Layout.preferredWidth: root.valueColumnWidth; Layout.minimumWidth: root.valueColumnWidth; Layout.maximumWidth: root.valueColumnWidth; horizontalAlignment: Text.AlignRight; text: isFinite(root.lastKnownGroundSpeed) ? root.lastKnownGroundSpeed.toFixed(1) + " m/s" : "--"; font.bold: true; color: qgcPal.buttonText; opacity: 0.65 }
            }

            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("Values update again when the link is restored.")
                color: qgcPal.buttonText
                opacity: 0.65
                wrapMode: Text.WordWrap
                font.pointSize: ScreenTools.smallFontPointSize
            }
        }
    }
}
