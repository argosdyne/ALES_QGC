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
    readonly property string coordinateError: !isFinite(enteredLatitude) || enteredLatitude < -90 || enteredLatitude > 90 ?
        qsTr("Latitude must be a number between -90 and 90.") :
        (!isFinite(enteredLongitude) || enteredLongitude < -180 || enteredLongitude > 180 ? qsTr("Longitude must be a number between -180 and 180.") : "")
    enabled: !mapControl || !mapControl.gotoConfirmationPending
    readonly property real margin: ScreenTools.defaultFontPixelHeight / 2
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

    onCurrentAltitudeChanged: initializeAltitude()
    onMapControlChanged: updateCoordinateFields()
    onAltitudeModeChanged: {
        // An edited value must not silently change meaning when the reference changes.
        altitudeEdited = false
        initializeAltitude()
    }

    Connections {
        target: root.mapControl ? root.mapControl : null
        function onGotoDraftCoordinateChanged() { root.updateCoordinateFields() }
    }

    implicitHeight: editorHeader.height + editorColumn.height + footer.height + margin * 3 + 4

    Rectangle {
        anchors.fill: parent
        color: qgcPal.missionItemEditor
        radius: ScreenTools.defaultFontPixelWidth / 2
        DeadMouseArea { anchors.fill: parent }
    }

    Item {
        id: editorHeader
        anchors.top: parent.top
        width: parent.width
        height: ScreenTools.implicitComboBoxHeight + root.margin
        QGCLabel {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: ScreenTools.defaultFontPixelWidth / 2
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("GoTo - Target")
            color: qgcPal.primaryButtonText
            font.pointSize: ScreenTools.defaultFontPointSize
        }
    }

    Rectangle {
        anchors.top: editorHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 2
        color: qgcPal.windowShadeDark
        radius: ScreenTools.defaultFontPixelWidth / 2

        QGCFlickable {
            id: editorFlickable
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footer.top
            anchors.margins: root.margin
            contentWidth: width
            contentHeight: editorColumn.height
            clip: true

            ColumnLayout {
                id: editorColumn
                width: editorFlickable.width
                spacing: root.margin

                QGCLabel {
                    text: qsTr("Select on the map, drag the target, or enter coordinates.")
                    font.pointSize: ScreenTools.smallFontPointSize
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                QGCLabel { text: qsTr("Latitude (deg)"); font.pointSize: ScreenTools.smallFontPointSize }
                QGCTextField {
                    id: latitudeField
                    objectName: "gotoLatitudeField"
                    Layout.fillWidth: true
                    numericValuesOnly: true
                    placeholderText: qsTr("-90 to 90")
                    onEditingFinished: if (longitudeField.text.trim().length) root.applyCoordinates()
                }
                QGCLabel { text: qsTr("Longitude (deg)"); font.pointSize: ScreenTools.smallFontPointSize }
                QGCTextField {
                    id: longitudeField
                    objectName: "gotoLongitudeField"
                    Layout.fillWidth: true
                    numericValuesOnly: true
                    placeholderText: qsTr("-180 to 180")
                    onEditingFinished: if (latitudeField.text.trim().length) root.applyCoordinates()
                }
                QGCLabel {
                    visible: root.coordinateError.length > 0
                    text: root.coordinateError
                    color: qgcPal.warningText
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    font.pointSize: ScreenTools.smallFontPointSize
                }
                QGCLabel {
                    visible: root.distanceError.length > 0
                    text: root.distanceError
                    color: qgcPal.warningText
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    font.pointSize: ScreenTools.smallFontPointSize
                }
                QGCLabel {
                    visible: root.geoFenceError.length > 0
                    text: root.geoFenceError
                    color: qgcPal.warningText
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    font.pointSize: ScreenTools.smallFontPointSize
                }
                QGCLabel {
                    text: qsTr("Altitude - %1").arg(QGroundControl.altitudeModeShortDescription(root.altitudeMode))
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    font.pointSize: ScreenTools.smallFontPointSize
                }
                QGCTextField {
                    id: altitudeField
                    objectName: "gotoAltitudeField"
                    Layout.fillWidth: true
                    numericValuesOnly: true
                    showUnits: true
                    unitsLabel: root.altitudeUnits
                    enabled: root.altitudeSupported
                    onTextChanged: {
                        if (activeFocus && !root._updatingAltitude) {
                            root.altitudeEdited = true
                        }
                    }
                }
                QGCLabel {
                    text: !root.altitudeSupported ? qsTr("Current altitude is unavailable for this reference.") :
                        qsTr("Current: %1 %2").arg(isFinite(root.currentAltitude) ? Number(root.units.metersToAppSettingsVerticalDistanceUnits(root.currentAltitude)).toFixed(1) : "--").arg(root.altitudeUnits)
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    font.pointSize: ScreenTools.smallFontPointSize
                }
                QGCLabel {
                    visible: root.altitudeError.length > 0
                    text: root.altitudeError
                    color: qgcPal.warningText
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pointSize: ScreenTools.smallFontPointSize
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: qgcPal.text; opacity: 0.2 }
                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    columnSpacing: root.margin
                    rowSpacing: root.margin / 2
                    QGCLabel { text: qsTr("Distance"); Layout.fillWidth: true; font.pointSize: ScreenTools.defaultFontPointSize }
                    QGCLabel { Layout.alignment: Qt.AlignRight; text: (isFinite(root.distanceMeters) ? Number(root.units.metersToAppSettingsHorizontalDistanceUnits(root.distanceMeters)).toFixed(0) : "--") + " " + root.units.appSettingsHorizontalDistanceUnitsString }
                    QGCLabel { text: qsTr("Est. ETA"); Layout.fillWidth: true; font.pointSize: ScreenTools.defaultFontPointSize }
                    QGCLabel { Layout.alignment: Qt.AlignRight; text: (isFinite(root.etaSeconds) ? Math.ceil(root.etaSeconds) : "--") + " s" }
                    QGCLabel { text: qsTr("Altitude change"); Layout.fillWidth: true; font.pointSize: ScreenTools.defaultFontPointSize }
                    QGCLabel { Layout.alignment: Qt.AlignRight; text: (isFinite(root.altitudeDifference) ? (root.altitudeDifference > 0 ? "+" : "") + Number(root.units.metersToAppSettingsVerticalDistanceUnits(root.altitudeDifference)).toFixed(1) : "--") + " " + root.altitudeUnits }
                }
            }
        }

        GridLayout {
            id: footer
            columns: root.width < ScreenTools.defaultFontPixelWidth * 27 ? 1 : 2
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: root.margin
            columnSpacing: ScreenTools.defaultFontPixelWidth / 2
            rowSpacing: ScreenTools.defaultFontPixelWidth / 2
            QGCButton {
                text: qsTr("Cancel")
                Layout.fillWidth: true
                onClicked: root.mapControl.cancelGotoSelection()
            }
            QGCButton {
                text: qsTr("Execute")
                objectName: "gotoExecuteButton"
                primary: true
                Layout.fillWidth: true
                enabled: root.mapControl && root.mapControl.gotoAvailable && root.vehicle && root.vehicle.armed && root.vehicle.flying && !root.vehicle.vehicleLinkManager.communicationLost && root.targetValid
                onClicked: {
                    if (root.targetValid && root.applyCoordinates()) {
                        var target = root.mapControl.gotoDraftCoordinate
                        var controller = globals.guidedControllerFlyView
                        controller.confirmAction(controller.actionGoto, {
                            coordinate: QtPositioning.coordinate(target.latitude, target.longitude, root.targetAMSL),
                            vehicle: root.vehicle,
                            map: root.mapControl,
                            altitudeMode: root.altitudeMode,
                            altitudeText: root.targetAltitude + " " + root.altitudeUnits
                        })
                        root.mapControl.hideGotoTargetEditorForConfirmation()
                    }
                }
            }
        }
    }

}
