import QtQuick                  2.12
import QtQuick.Layouts          1.12
import QtPositioning            5.3

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0

// Editing never sends commands. A separate confirmation must be completed to execute.
Item {
    id: root
    property var mapControl
    property var vehicle
    property int altitudeMode: QGroundControl.AltitudeModeRelative
    property bool altitudeEdited: false
    property bool _updatingAltitude: false
    readonly property real enteredLatitude: parseNumber(latitudeField.text)
    readonly property real enteredLongitude: parseNumber(longitudeField.text)
    readonly property bool coordinatesValid: isFinite(enteredLatitude) && enteredLatitude >= -90 && enteredLatitude <= 90 &&
        isFinite(enteredLongitude) && enteredLongitude >= -180 && enteredLongitude <= 180
    readonly property string latitudeError: !isFinite(enteredLatitude) || enteredLatitude < -90 || enteredLatitude > 90 ?
        qsTr("Latitude must be between -90 and 90.") : ""
    readonly property string longitudeError: !isFinite(enteredLongitude) || enteredLongitude < -180 || enteredLongitude > 180 ?
        qsTr("Longitude must be between -180 and 180.") : ""
    readonly property string coordinateError: latitudeError || longitudeError
    enabled: !mapControl || !mapControl.gotoConfirmationPending
    readonly property real margin: ScreenTools.defaultFontPixelHeight / 2
    readonly property color validationColor: "#c74946"
    readonly property var units: QGroundControl.unitsConversion
    readonly property string altitudeUnits: units.appSettingsVerticalDistanceUnitsString
    readonly property bool altitudeSupported: altitudeMode === QGroundControl.AltitudeModeRelative || altitudeMode === QGroundControl.AltitudeModeAbsolute
    readonly property real currentAltitude: !vehicle || !altitudeSupported ? NaN :
        Number((altitudeMode === QGroundControl.AltitudeModeAbsolute ? vehicle.altitudeAMSL : vehicle.altitudeRelative).rawValue)
    readonly property real targetAltitude: parseNumber(altitudeField.text)
    readonly property real targetAltitudeMeters: isFinite(targetAltitude) ? Number(units.appSettingsVerticalDistanceUnitsToMeters(targetAltitude)) : NaN
    readonly property real distanceMeters: coordinatesValid && vehicle && vehicle.coordinate.isValid ?
        vehicle.coordinate.distanceTo(QtPositioning.coordinate(enteredLatitude, enteredLongitude)) : NaN
    readonly property var flySettings: QGroundControl.settingsManager.flyViewSettings
    readonly property var geoFenceController: mapControl && mapControl.planMasterController ? mapControl.planMasterController.geoFenceController : null
    readonly property bool geoFenceLoaded: geoFenceController ? geoFenceController.fenceLoaded : false
    readonly property real homeAltitudeAMSL: vehicle ? Number(vehicle.altitudeAMSL.rawValue) - Number(vehicle.altitudeRelative.rawValue) : NaN
    readonly property real targetAMSL: altitudeMode === QGroundControl.AltitudeModeAbsolute ? targetAltitudeMeters : targetAltitudeMeters + homeAltitudeAMSL
    readonly property real minimumAltitudeMeters: Number(flySettings.guidedMinimumAltitude.rawValue) + (altitudeMode === QGroundControl.AltitudeModeAbsolute ? homeAltitudeAMSL : 0)
    readonly property real maximumAltitudeMeters: Number(flySettings.guidedMaximumAltitude.rawValue) + (altitudeMode === QGroundControl.AltitudeModeAbsolute ? homeAltitudeAMSL : 0)
    readonly property string altitudeError: !isFinite(targetAltitudeMeters) ? qsTr("Enter a valid target altitude.") :
        (!altitudeSupported || !isFinite(currentAltitude) || !isFinite(homeAltitudeAMSL) || !isFinite(targetAMSL) ? qsTr("Current altitude is unavailable.") :
         (targetAltitudeMeters < minimumAltitudeMeters || targetAltitudeMeters > maximumAltitudeMeters ?
          qsTr("Altitude must be between %1 and %2 %3 - %4.")
            .arg(Number(units.metersToAppSettingsVerticalDistanceUnits(minimumAltitudeMeters)).toFixed(1))
            .arg(Number(units.metersToAppSettingsVerticalDistanceUnits(maximumAltitudeMeters)).toFixed(1))
            .arg(altitudeUnits).arg(QGroundControl.altitudeModeShortDescription(altitudeMode)) : ""))
    readonly property string distanceError: !coordinatesValid ? "" : (!isFinite(distanceMeters) ? qsTr("Current position is unavailable.") :
        (distanceMeters > Number(flySettings.maxGoToLocationDistance.rawValue) ?
         qsTr("Target exceeds the maximum GoTo distance (%1 %2).")
            .arg(Number(units.metersToAppSettingsHorizontalDistanceUnits(flySettings.maxGoToLocationDistance.rawValue)).toFixed(0))
            .arg(units.appSettingsHorizontalDistanceUnitsString) : ""))
    readonly property string geoFenceError: {
        if (!coordinatesValid || !geoFenceController || !geoFenceLoaded) {
            return ""
        }
        return geoFenceController.goToTargetBlockReason(QtPositioning.coordinate(enteredLatitude, enteredLongitude))
    }
    readonly property bool targetValid: coordinatesValid && altitudeError === "" && distanceError === "" && geoFenceError === "" && isFinite(distanceMeters)
    readonly property real altitudeDifference: targetAltitudeMeters - currentAltitude
    // The same configurable planning speeds used by Mission. This is an estimate, not measured progress.
    readonly property real planningSpeed: Number(QGroundControl.settingsManager.appSettings.offlineEditingHoverSpeed.rawValue)
    readonly property real verticalSpeed: Number((altitudeDifference >= 0 ? QGroundControl.settingsManager.appSettings.offlineEditingAscentSpeed : QGroundControl.settingsManager.appSettings.offlineEditingDescentSpeed).rawValue)
    readonly property real etaSeconds: isFinite(distanceMeters) && isFinite(altitudeDifference) && planningSpeed > 0 && verticalSpeed > 0 ? distanceMeters / planningSpeed + Math.abs(altitudeDifference) / verticalSpeed : NaN

    QGCPalette { id: qgcPal; colorGroupEnabled: root.enabled }

    function parseNumber(text) {
        var value = text.trim()
        return /^[-+]?(?:\d+(?:\.\d*)?|\.\d+)$/.test(value) ? Number(value) : NaN
    }

    function initializeAltitude() {
        if (!altitudeEdited) {
            _updatingAltitude = true
            altitudeField.text = isFinite(currentAltitude) ? Number(units.metersToAppSettingsVerticalDistanceUnits(currentAltitude)).toFixed(1) : ""
            _updatingAltitude = false
        }
    }

    function updateCoordinateFields() {
        var coordinate = mapControl ? mapControl.gotoDraftCoordinate : null
        if (coordinate && coordinate.isValid) {
            latitudeField.text = coordinate.latitude.toFixed(7)
            longitudeField.text = coordinate.longitude.toFixed(7)
        }
    }

    function applyCoordinates() {
        if (!coordinatesValid || distanceError !== "") {
            return false
        }
        mapControl.setGotoDraftCoordinate(QtPositioning.coordinate(enteredLatitude, enteredLongitude), true)
        return true
    }

    function rejectionMessage() {
        if (geoFenceError.length) {
            return qsTr("Target is outside the allowed area.")
        }
        return coordinateError || altitudeError || distanceError || qsTr("The target is not valid.")
    }

    function displayDistance(distance) {
        if (!isFinite(distance)) {
            return "--"
        }
        return distance >= 1000 ? (distance / 1000).toFixed(1) + " km" : distance.toFixed(0) + " m"
    }

    function displayEta(seconds) {
        if (!isFinite(seconds) || seconds < 0) {
            return "--"
        }
        var roundedSeconds = Math.round(seconds)
        var remainingSeconds = (roundedSeconds % 60).toString()
        return Math.floor(roundedSeconds / 60) + ":" + (remainingSeconds.length < 2 ? "0" : "") + remainingSeconds
    }

    onCurrentAltitudeChanged: initializeAltitude()
    onMapControlChanged: updateCoordinateFields()
    // Validation bindings can briefly be incomplete while this dialog opens.
    // Only the Go button reports a rejection; a valid target clears an earlier one.
    onTargetValidChanged: {
        if (targetValid && mapControl) {
            mapControl.gotoRejectionMessage = ""
        }
    }
    onAltitudeModeChanged: {
        // An edited value must not silently change meaning when the reference changes.
        altitudeEdited = false
        initializeAltitude()
    }

    Connections {
        target: root.mapControl ? root.mapControl : null
        function onGotoDraftCoordinateChanged() { root.updateCoordinateFields() }
    }

    // 30 character-widths renders at about 230 px on the 432 px mobile reference.
    implicitWidth: ScreenTools.defaultFontPixelWidth * 30
    implicitHeight: dialog.implicitHeight

    Rectangle {
        id: dialog
        anchors.fill: parent
        implicitHeight: header.height + content.implicitHeight
        color: qgcPal.windowShadeDark
        border.color: qgcPal.text
        border.width: 1
        radius: ScreenTools.defaultFontPixelWidth / 3
        DeadMouseArea { anchors.fill: parent }

        RowLayout {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: ScreenTools.implicitComboBoxHeight + root.margin
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: qgcPal.missionItemEditor
                QGCLabel {
                    anchors.left: parent.left
                    anchors.leftMargin: root.margin
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Go to coordinates")
                    color: qgcPal.primaryButtonText
                    font.pointSize: ScreenTools.defaultFontPointSize
                }
            }
            QGCButton {
                text: qsTr("Cancel")
                Layout.fillHeight: true
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 6
                onClicked: root.mapControl.cancelGotoSelection()
            }
            QGCButton {
                text: qsTr("Go")
                objectName: "gotoExecuteButton"
                primary: true
                Layout.fillHeight: true
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 5
                // Keep the flight-safety gate intact. Target validation is handled on press
                // so the operator receives a visible rejection instead of a silent disabled button.
                enabled: root.mapControl && root.mapControl.gotoAvailable && root.vehicle && root.vehicle.armed && root.vehicle.flying && !root.vehicle.vehicleLinkManager.communicationLost
                onClicked: {
                    if (!root.targetValid) {
                        root.mapControl.showGotoRejection(root.rejectionMessage())
                        return
                    }
                    if (!root.applyCoordinates()) {
                        return
                    }
                    var target = root.mapControl.gotoDraftCoordinate
                    var controller = globals.guidedControllerFlyView
                    controller.confirmAction(controller.actionGoto, {
                        coordinate: QtPositioning.coordinate(target.latitude, target.longitude, root.targetAMSL),
                        vehicle: root.vehicle,
                        map: root.mapControl,
                        altitudeMode: root.altitudeMode,
                        altitudeText: root.targetAltitude + " " + root.altitudeUnits,
                        gotoSummary: qsTr("Go to location: %1 · ETA %2").arg(root.displayDistance(root.distanceMeters)).arg(root.displayEta(root.etaSeconds))
                    })
                    root.mapControl.hideGotoTargetEditorForConfirmation()
                }
            }
        }

        ColumnLayout {
            id: content
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: root.margin
            spacing: root.margin

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: root.margin
                rowSpacing: root.margin / 2

                QGCLabel {
                    text: qsTr("Latitude")
                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
                    Layout.alignment: Qt.AlignTop
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: latitudeField.implicitHeight + 2
                        color: "transparent"
                        border.width: root.latitudeError.length ? 1 : 0
                        border.color: root.validationColor
                        QGCTextField {
                            id: latitudeField
                            objectName: "gotoLatitudeField"
                            anchors.fill: parent
                            anchors.margins: root.latitudeError.length ? 1 : 0
                            numericValuesOnly: true
                            validationError: root.latitudeError.length > 0
                            validationErrorColor: root.validationColor
                            placeholderText: qsTr("-90 to 90")
                            onEditingFinished: if (longitudeField.text.trim().length) root.applyCoordinates()
                        }
                    }
                    QGCLabel {
                        Layout.fillWidth: true
                        visible: root.latitudeError.length > 0
                        text: root.latitudeError
                        color: root.validationColor
                        wrapMode: Text.WordWrap
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }

                QGCLabel { text: qsTr("Longitude"); Layout.alignment: Qt.AlignTop }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: longitudeField.implicitHeight + 2
                        color: "transparent"
                        border.width: root.longitudeError.length ? 1 : 0
                        border.color: root.validationColor
                        QGCTextField {
                            id: longitudeField
                            objectName: "gotoLongitudeField"
                            anchors.fill: parent
                            anchors.margins: root.longitudeError.length ? 1 : 0
                            numericValuesOnly: true
                            validationError: root.longitudeError.length > 0
                            validationErrorColor: root.validationColor
                            placeholderText: qsTr("-180 to 180")
                            onEditingFinished: if (latitudeField.text.trim().length) root.applyCoordinates()
                        }
                    }
                    QGCLabel {
                        Layout.fillWidth: true
                        visible: root.longitudeError.length > 0
                        text: root.longitudeError
                        color: root.validationColor
                        wrapMode: Text.WordWrap
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }

                QGCLabel { text: qsTr("Altitude"); Layout.alignment: Qt.AlignTop }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: altitudeField.implicitHeight + 2
                        color: "transparent"
                        border.width: root.altitudeError.length ? 1 : 0
                        border.color: root.validationColor
                        QGCTextField {
                            id: altitudeField
                            objectName: "gotoAltitudeField"
                            anchors.fill: parent
                            anchors.margins: root.altitudeError.length ? 1 : 0
                            numericValuesOnly: true
                            validationError: root.altitudeError.length > 0
                            validationErrorColor: root.validationColor
                            showUnits: true
                            unitsLabel: root.altitudeUnits
                            enabled: root.altitudeSupported
                            onTextChanged: {
                                if (activeFocus && !root._updatingAltitude) {
                                    root.altitudeEdited = true
                                }
                            }
                        }
                    }
                    QGCLabel {
                        Layout.fillWidth: true
                        visible: root.altitudeError.length > 0
                        text: root.altitudeError
                        color: root.validationColor
                        wrapMode: Text.WordWrap
                        font.pointSize: ScreenTools.smallFontPointSize
                    }
                }

                QGCLabel { text: qsTr("Altitude reference") }
                QGCLabel {
                    Layout.fillWidth: true
                    text: qsTr("%1 (Application Settings)").arg(QGroundControl.altitudeModeShortDescription(root.altitudeMode))
                    color: qgcPal.buttonText
                    opacity: 0.65
                    elide: Text.ElideRight
                }
            }

            QGCLabel {
                visible: root.distanceError.length > 0
                Layout.fillWidth: true
                text: root.distanceError
                color: qgcPal.warningText
                wrapMode: Text.WordWrap
                font.pointSize: ScreenTools.smallFontPointSize
            }
            QGCLabel {
                visible: root.geoFenceError.length > 0
                Layout.fillWidth: true
                text: root.geoFenceError
                color: qgcPal.warningText
                wrapMode: Text.WordWrap
                font.pointSize: ScreenTools.smallFontPointSize
            }
            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("Decimal degrees (WGS84). The altitude reference follows the GCS setting and cannot be changed here.")
                color: qgcPal.buttonText
                opacity: 0.65
                wrapMode: Text.WordWrap
                font.pointSize: ScreenTools.smallFontPointSize
            }
            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("Tip: the same values are prefilled when the dialog is opened from a map tap.")
                color: qgcPal.buttonText
                opacity: 0.65
                wrapMode: Text.WordWrap
                font.pointSize: ScreenTools.smallFontPointSize
            }
        }
    }
}
