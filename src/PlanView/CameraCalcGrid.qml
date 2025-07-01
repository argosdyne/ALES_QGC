import QtQuick          2.3
import QtQuick.Controls 1.2
import QtQuick.Layouts  1.2

import QGroundControl                   1.0
import QGroundControl.ScreenTools       1.0
import QGroundControl.Controls          1.0
import QGroundControl.FactControls      1.0
import QGroundControl.Palette           1.0

// Camera calculator "Grid" section for mission item editors
Column {
    spacing: _margin

    property var    cameraCalc
    property bool   vehicleFlightIsFrontal:         true
    property string distanceToSurfaceLabel
    property string frontalDistanceLabel
    property string sideDistanceLabel

    property real   _margin:            ScreenTools.defaultFontPixelWidth / 2
    property real   _fieldWidth:        ScreenTools.defaultFontPixelWidth * 10.5
    property var    _cameraList:        [ ]
    property var    _vehicle:           QGroundControl.multiVehicleManager.activeVehicle ? QGroundControl.multiVehicleManager.activeVehicle : QGroundControl.multiVehicleManager.offlineEditingVehicle
    property var    _vehicleCameraList: _vehicle ? _vehicle.staticCameraList : []
    property bool   _cameraComboFilled: false

    readonly property int _gridTypeManual:          0
    readonly property int _gridTypeCustomCamera:    1
    readonly property int _gridTypeCamera:          2

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    Column {
        anchors.left:   parent.left
        anchors.right:  parent.right
        spacing:        _margin
        visible:        !cameraCalc.isManualCamera

        RowLayout {
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        _margin
            Item { Layout.fillWidth: true }
            QGCLabel {
                Layout.preferredWidth:  _root._fieldWidth
                text:                   qsTr("Front Lap")
            }
            QGCLabel {
                Layout.preferredWidth:  _root._fieldWidth
                text:                   qsTr("Side Lap")
            }
        }

        RowLayout {
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        _margin
            QGCLabel { text: qsTr("Overlap"); Layout.fillWidth: true }
            FactTextField {
                Layout.preferredWidth:  _root._fieldWidth
                fact:                   cameraCalc.frontalOverlap
            }
            FactTextField {
                Layout.preferredWidth:  _root._fieldWidth
                fact:                   cameraCalc.sideOverlap
            }
        }

        QGCLabel {
            wrapMode:               Text.WordWrap
            text:                   qsTr("Select one:")
            Layout.preferredWidth:  parent.width
            Layout.columnSpan:      2
        }

        GridLayout {
            anchors.left:   parent.left
            anchors.right:  parent.right
            columnSpacing:  _margin
            rowSpacing:     _margin
            columns:        2

            QGCRadioButton {
                id:                     fixedDistanceRadio
                leftPadding:            0
                text:                   distanceToSurfaceLabel
                checked:                !!cameraCalc.valueSetIsDistance.value
                onClicked:              cameraCalc.valueSetIsDistance.value = 1
            }

            AltitudeFactTextField {
                fact:                       cameraCalc.distanceToSurface
                altitudeMode:               cameraCalc.distanceMode
                enabled:                    fixedDistanceRadio.checked
                Layout.fillWidth:           true
            }

            QGCRadioButton {
                id:                     fixedImageDensityRadio
                leftPadding:            0
                text:                   qsTr("Grnd Res")
                checked:                !cameraCalc.valueSetIsDistance.value
                onClicked:              cameraCalc.valueSetIsDistance.value = 0
            }

            FactTextField {
                fact:                   cameraCalc.imageDensity
                enabled:                fixedImageDensityRadio.checked
                Layout.fillWidth:       true
            }
        }
    } // Column - Camera spec based ui

    // No camera spec ui
    GridLayout {
        anchors.left:   parent.left
        anchors.right:  parent.right
        columnSpacing:  _margin
        rowSpacing:     _margin
        columns:        2
        visible: {
            var visibleState = cameraCalc.isManualCamera
            if (cameraCalc.cameraBrand.includes("Yellow Scan")) {
                console.log("Yellow Scan camera detected")
                ysGrid.visible = true
                ysAltitudeCheckbox.visible = true
                ysSpacingCheckbox.visible = true
                ysCalcBtn.visible = true
                triggerDistLabel.visible = false
                ysDistanceLabel.visible = false
                triggerDistTextField.visible = false
                columns = 3
                if(ysAltitudeCheckbox.checked === true){
                    altitudeFactTextField.enabled = true
                }
                else {
                    altitudeFactTextField.enabled = false
                }
                if(ysSpacingCheckbox.checked === true){
                    spacingTextField.enabled = true
                }
                else {
                    spacingTextField.enabled = false
                }
                if(ysOverlapCheckbox.checked === true){
                    overlapTextField.enabled = true
                }
                else {
                    overlapTextField.enabled = false
                }
                if(ysFOVCheckbox.checked === true){
                    fovTextField.enabled = true
                }
                else {
                    fovTextField.enabled = false
                }
            }
            else {
                ysGrid.visible = false
                ysAltitudeCheckbox.visible = false
                ysSpacingCheckbox.visible = false
                ysDistanceLabel.visible = false
                ysCalcBtn.visible = false
                altitudeFactTextField.enabled = true
                spacingTextField.enabled = true

                triggerDistLabel.visible = true
                triggerDistTextField.visible = true

                cameraCalc.calcSpacing();
                columns = 2
            }

            console.log(cameraCalc.cameraBrand);
            return visibleState
        }


        QGCLabel { text: distanceToSurfaceLabel }

        FactCheckBox {
            Layout.fillWidth:  true
            id:             ysAltitudeCheckbox
            fact:           cameraCalc.isYSAltitudeUse
            visible:  true

            onCheckedChanged: {
                if(checked) {
                    altitudeFactTextField.enabled = true
                }
                else {
                    altitudeFactTextField.enabled = false
                }
            }
        }

        AltitudeFactTextField {
            id:                         altitudeFactTextField
            fact:                       cameraCalc.distanceToSurface
            altitudeMode:               cameraCalc.distanceMode
            Layout.fillWidth:           true
        }

        QGCLabel { id: triggerDistLabel; text: frontalDistanceLabel }
        QGCLabel { id: ysDistanceLabel }
        FactTextField {
            id:                 triggerDistTextField
            Layout.fillWidth:   true
            fact:               cameraCalc.adjustedFootprintFrontal
        }

        QGCLabel { text: sideDistanceLabel }

        FactCheckBox {
            Layout.fillWidth:  true
            id:             ysSpacingCheckbox
            fact:           cameraCalc.isYSSpacingUse
            visible:  true

            onCheckedChanged: {
                if(checked){
                    spacingTextField.enabled = true
                }
                else {
                    spacingTextField.enabled = false
                }
            }
        }

        FactTextField {
            id: spacingTextField
            Layout.fillWidth:   true
            fact:               cameraCalc.adjustedFootprintSide
        }
    } // GridLayout

    //Only for Yellow Scan Lidar
    GridLayout {
        id: ysGrid
        anchors.left: parent.left
        anchors.right: parent.right
        columnSpacing: _margin
        rowSpacing: _margin
        columns: 3
        visible : cameraCalc.isYSLidar

        QGCLabel { text: "Yellow Scan Overlap" }

        FactCheckBox {
            Layout.fillWidth:  true
            id:             ysOverlapCheckbox
            fact:           cameraCalc.isYSOverlapUse
            visible:  true

            onCheckedChanged: {
                if(checked){
                    overlapTextField.enabled = true
                }
                else {
                    overlapTextField.enabled = false
                }
            }
        }

        FactTextField {
            id: overlapTextField
            Layout.fillWidth:  true
            fact: cameraCalc.yellowScanOverlapFact
        }

        QGCLabel { text: "Yellow Scan FOV" }

        FactCheckBox {
            id: ysFOVCheckbox
            Layout.fillWidth:  true
            fact:           cameraCalc.isYSFOVuse
            visible:  true

            onCheckedChanged: {
                if(checked){
                    fovTextField.enabled = true
                }
                else {
                    fovTextField.enabled = false
                }
            }
        }

        FactTextField {
            id: fovTextField
            Layout.fillWidth: true
            fact: cameraCalc.yellowScanFOVFact
        }
    }
    QGCButton {
        id: ysCalcBtn
        anchors.left: parent.left
        text:                       qsTr("Calculate")
        width:                      ScreenTools.defaultFontPixelWidth * 15
        anchors.horizontalCenter:   parent.horizontalCenter

        property int checkedCount: (ysAltitudeCheckbox.checked ? 1 : 0)
                                  + (ysSpacingCheckbox.checked ? 1 : 0)
                                  + (ysOverlapCheckbox.checked ? 1 : 0)
                                  + (ysFOVCheckbox.checked ? 1 : 0)

        enabled: { if(checkedCount === 3){ return true } else { return false } }

        onClicked: {
            cameraCalc.calculate();
        }

    }
} // Column
