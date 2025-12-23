/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.3
import QtQuick.Controls 2.15
import QtQuick.Dialogs  1.2
import QtLocation       5.3
import QtPositioning    5.3
import QtQuick.Layouts  1.2
import QtQuick.Window   2.2

import QGroundControl                   1.0
import QGroundControl.FlightMap         1.0
import QGroundControl.ScreenTools       1.0
import QGroundControl.Controls          1.0
import QGroundControl.FactSystem        1.0
import QGroundControl.FactControls      1.0
import QGroundControl.Palette           1.0
import QGroundControl.Controllers       1.0
import QGroundControl.ShapeFileHelper   1.0
import QGroundControl.MultiVehicleManager   1.0
import QGroundControl.Vehicle               1.0
import QGroundControl.QGCPositionManager    1.0

import QGroundControl.FlightDisplay     1.0

Item {
    id: _root

    property bool planControlColapsed: false

    readonly property int   _decimalPlaces:             8
    readonly property real  _margin:                    ScreenTools.defaultFontPixelHeight * 0.5
    readonly property real  _toolsMargin:               ScreenTools.defaultFontPixelWidth * 0.75
    readonly property real  _radius:                    ScreenTools.defaultFontPixelWidth  * 0.5
    readonly property real  _rightPanelWidth:           Math.min(parent.width / 3.5, ScreenTools.defaultFontPixelWidth * 30)
    readonly property var   _defaultVehicleCoordinate:  QtPositioning.coordinate(37.803784, -122.462276)
    readonly property bool  _waypointsOnlyMode:         QGroundControl.corePlugin.options.missionWaypointsOnly

    property var    _planMasterController:              planMasterController
    property var    _missionController:                 _planMasterController.missionController
    property var    _geoFenceController:                _planMasterController.geoFenceController
    property var    _rallyPointController:              _planMasterController.rallyPointController
    property var    _visualItems:                       _missionController.visualItems
    property bool   _lightWidgetBorders:                editorMap.isSatelliteMap
    property bool   _addROIOnClick:                     false
    property bool   _singleComplexItem:                 _missionController.complexMissionItemNames.length === 1
    property int    _editingLayer:                      _layers[0]
    property int    _toolStripBottom:                   toolStrip.height + toolStrip.y
    property var    _appSettings:                       QGroundControl.settingsManager.appSettings
    property var    _planViewSettings:                  QGroundControl.settingsManager.planViewSettings
    property bool   _promptForPlanUsageShowing:         false

    readonly property var       _layers:                [_layerMission, _layerGeoFence, _layerRallyPoints]

    readonly property int       _layerMission:              1
    readonly property int       _layerGeoFence:             2
    readonly property int       _layerRallyPoints:          3
    readonly property string    _armedVehicleUploadPrompt:  qsTr("Vehicle is currently armed. Do you want to upload the mission to the vehicle?")


    property var    _geoZoneViewSettings:           QGroundControl.settingsManager.geoZoneMakeViewSettings

    property var    _activeVehicle:             QGroundControl.multiVehicleManager.activeVehicle

    property string latText: _geoZoneViewSettings.centerCoord.latitude.toString()
    property string lonText: _geoZoneViewSettings.centerCoord.longitude.toString()

    property double verticalLength: _geoZoneViewSettings.verticalArea
    property double horizontalLength: _geoZoneViewSettings.horizontalArea

    property bool isVerticalMoving: false
    property bool isHorizontalMoving: false

    function mapCenter() {
        var coordinate = editorMap.center
        coordinate.latitude  = coordinate.latitude.toFixed(_decimalPlaces)
        coordinate.longitude = coordinate.longitude.toFixed(_decimalPlaces)
        coordinate.altitude  = coordinate.altitude.toFixed(_decimalPlaces)
        return coordinate
    }

    property bool _firstMissionLoadComplete:    false
    property bool _firstFenceLoadComplete:      false
    property bool _firstRallyLoadComplete:      false
    property bool _firstLoadComplete:           false

    MapFitFunctions {
        id:                         mapFitFunctions  // The name for this id cannot be changed without breaking references outside of this code. Beware!
        map:                        editorMap
        usePlannedHomePosition:     true
        planMasterController:       _planMasterController
    }

    onVisibleChanged: {
        if(visible) {
            editorMap.zoomLevel = QGroundControl.flightMapZoom
            editorMap.center    = QGroundControl.flightMapPosition
            if (!_planMasterController.containsItems) {
                toolStrip.simulateClick(toolStrip.fileButtonIndex)
            }
        }
    }

    function saveToSelectedFile() {
        // if (!checkReadyForSaveUpload(true /* save */)) {
        //     return
        // }
        fileDialog.title =          qsTr("Save GeoZone")
        fileDialog.selectExisting = false
        fileDialog.nameFilters =    _geoZoneViewSettings.saveNameFilters
        fileDialog.openForSave()
    }

    PlanMasterController {
        id:         planMasterController
        flyView:    false

        Component.onCompleted: {
            _planMasterController.start()
            _missionController.setCurrentPlanViewSeqNum(0, true)
            globals.planMasterControllerPlanView = _planMasterController
        }

        onPromptForPlanUsageOnVehicleChange: {
            if (!_promptForPlanUsageShowing) {
                _promptForPlanUsageShowing = true
                promptForPlanUsageOnVehicleChangePopupComponent.createObject(mainWindow).open()
            }
        }

    }

    Connections {
        target: _missionController

        function onNewItemsFromVehicle() {
            if (_visualItems && _visualItems.count !== 1) {
                mapFitFunctions.fitMapViewportToMissionItems()
            }
            _missionController.setCurrentPlanViewSeqNum(0, true)
        }
    }

    function insertROIAfterCurrent(coordinate) {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertROIMissionItem(coordinate, nextIndex, true /* makeCurrentItem */)
    }

    function insertComplexItemAfterCurrent(complexItemName) {
        var nextIndex = _missionController.currentPlanViewVIIndex + 1
        _missionController.insertComplexMissionItem(complexItemName, mapCenter(), nextIndex, true /* makeCurrentItem */)
    }

    function selectNextNotReady() {
        var foundCurrent = false
        for (var i=0; i<_missionController.visualItems.count; i++) {
            var vmi = _missionController.visualItems.get(i)
            if (vmi.readyForSaveState === VisualMissionItem.NotReadyForSaveData) {
                _missionController.setCurrentPlanViewSeqNum(vmi.sequenceNumber, true)
                break
            }
        }
    }

    QGCFileDialog {
        id:             fileDialog
        //folder:         _appSettings ? _appSettings.geoZoneSavePath : ""
        folder: _appSettings ? (_appSettings.geoZoneSavePath + "/Custom") : ""

        onAcceptedForSave: {

            _geoZoneViewSettings.saveToFile(file)
            close()
        }

        onAcceptedForLoad: {
            _geoZoneViewSettings.loadFromFile(file)
            // _planMasterController.fitViewportToItems()
            // _missionController.setCurrentPlanViewSeqNum(0, true)
            close()
        }
    }

    Item {
        id:             panel
        anchors.fill:   parent

        FlightMap {
            id:                         editorMap
            anchors.fill:               parent
            mapName:                    "MissionEditor"
            allowGCSLocationCenter:     true
            allowVehicleLocationCenter: true
            planView:                   false

            zoomLevel:                  QGroundControl.flightMapZoom
            center:                     QGroundControl.flightMapPosition

            // This is the center rectangle of the map which is not obscured by tools
            property rect centerViewport:   Qt.rect(_leftToolWidth + _margin,  _margin, editorMap.width - _leftToolWidth - _rightToolWidth - (_margin * 2), (height - _margin) - _margin)

            property real _leftToolWidth:       toolStrip.x + toolStrip.width
            property real _rightToolWidth:      rightPanel.width + rightPanel.anchors.rightMargin
            property real _nonInteractiveOpacity:  0.5

            // Initial map position duplicates Fly view position
            Component.onCompleted: editorMap.center = QGroundControl.flightMapPosition

            QGCMapPalette { id: mapPal; lightColors: editorMap.isSatelliteMap }

            onZoomLevelChanged: {
                QGroundControl.flightMapZoom = zoomLevel
            }
            onCenterChanged: {
                QGroundControl.flightMapPosition = center
            }

            // MouseArea {
            //     anchors.fill: parent
            //     onClicked: {
            //         // Take focus to close any previous editing
            //         editorMap.focus = true
            //         var coordinate = editorMap.toCoordinate(Qt.point(mouse.x, mouse.y), false /* clipToViewPort */)
            //         coordinate.latitude = coordinate.latitude.toFixed(_decimalPlaces)
            //         coordinate.longitude = coordinate.longitude.toFixed(_decimalPlaces)
            //         coordinate.altitude = coordinate.altitude.toFixed(_decimalPlaces)

            //         switch (_editingLayer) {
            //         case _layerMission:
            //             if (_addROIOnClick) {
            //                 insertROIAfterCurrent(coordinate)
            //                 _addROIOnClick = false
            //             }

            //             break
            //         case _layerRallyPoints:
            //             break
            //         }
            //     }
            // }

            // Add the mission item visuals to the map
            // Repeater {
            //     model: _missionController.visualItems
            //     delegate: MissionItemMapVisual {
            //         map:         editorMap
            //         onClicked:   _missionController.setCurrentPlanViewSeqNum(sequenceNumber, false)
            //         opacity:     _editingLayer == _layerMission ? 1 : editorMap._nonInteractiveOpacity
            //         interactive: _editingLayer == _layerMission
            //         vehicle:     _planMasterController.controllerVehicle
            //     }
            // }

            GeoZoneMakeViewMapVisuals {
                map: editorMap
                //planView: false
                myGeoFenceController:   _geoZoneViewSettings
                homePosition:           _activeVehicle && _activeVehicle.homePosition.isValid ? _activeVehicle.homePosition :  QtPositioning.coordinate()
                interactive: _editingLayer == _layerMission
            }

        }



        //-----------------------------------------------------------
        // Left tool strip
        ToolStrip {
            id:                 toolStrip
            anchors.margins:    _toolsMargin
            anchors.left:       parent.left
            anchors.top:        parent.top
            z:                  QGroundControl.zOrderWidgets
            maxHeight:          parent.height - toolStrip.y
            title:              qsTr("Plan")

            readonly property int flyButtonIndex:       0
            readonly property int fileButtonIndex:      1
            readonly property int takeoffButtonIndex:   2
            readonly property int waypointButtonIndex:  3
            readonly property int roiButtonIndex:       4
            readonly property int patternButtonIndex:   5
            readonly property int landButtonIndex:      6
            readonly property int centerButtonIndex:    7

            property bool _isRallyLayer:    _editingLayer == _layerRallyPoints
            property bool _isMissionLayer:  _editingLayer == _layerMission

            ToolStripActionList {
                id: toolStripActionList
                model: [
                    ToolStripAction {
                        text:           qsTr("Go to main")
                        iconSource:     "/qmlimages/PaperPlane.svg"
                        onTriggered:    mainWindow.showFlyView()
                    },
                    ToolStripAction {
                        text:               qsTr("Select Area")
                        iconSource:         "/qmlimages/MapDrawShape.svg"
                        enabled:            true
                        visible:            true
                        //dropPanelComponent: _singleComplexItem ? undefined : patternDropPanel
                        onTriggered: {
                            // toolStrip.allAddClickBoolsOff()
                            // if (_singleComplexItem) {
                            //     insertComplexItemAfterCurrent(_missionController.complexMissionItemNames[0])
                            // }
                            _geoZoneViewSettings.selectGeoZone();
                        }
                    },
                    ToolStripAction {
                        text:               qsTr("Delete Area")
                        iconSource:         "qrc:/res/TrashDelete.svg"
                        enabled:            true
                        visible:            true
                        onTriggered: {
                            _geoZoneViewSettings.deleteGeoZone();
                        }
                    }
                ]
            }

            model: toolStripActionList.model

        }

        //-----------------------------------------------------------
        // Right pane for mission editing controls
        Rectangle {
            id:                 rightPanel
            height:             parent.height
            width:              _rightPanelWidth
            color:              qgcPal.window
            opacity:            1
            anchors.bottom:     parent.bottom
            anchors.right:      parent.right
            //anchors.rightMargin: _toolsMargin
        }
        //-------------------------------------------------------
        // Right Panel Controls
        Item {
            anchors.fill:           rightPanel
            anchors.topMargin:      _toolsMargin
            DeadMouseArea {
                anchors.fill:   parent
            }
            Column {
                id:                 rightControls
                spacing:            ScreenTools.defaultFontPixelHeight * 0.5
                anchors.left:       parent.left
                anchors.right:      parent.right
                anchors.top:        parent.top
            }

            //-------------------------------------------------------
            // Mission Item Editor
            Item {
                id:                     missionItemEditor
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.top:            rightControls.bottom
                anchors.bottom:         parent.bottom
                visible:                _editingLayer == _layerMission && !planControlColapsed

                Rectangle {
                    anchors.fill: parent
                    color: "#d3d3d3"
                    radius: 8

                    ColumnLayout {
                        //anchors.centerIn: parent
                        anchors.top: parent.top
                        anchors.topMargin: ScreenTools.defaultFontPixelWidth
                        //spacing: 10

                        Label {
                            text: "GeoZone Download"
                            font.bold: true
                            font.pointSize: 14
                            Layout.alignment: Qt.AlignHCenter
                        }

                        GroupBox {
                            title: "Center"                            
                            Layout.preferredWidth: _rightPanelWidth

                            GridLayout {
                                columns: 2
                                rowSpacing: 10
                                columnSpacing: 10

                                Label { text: "Latitude" ; Layout.alignment: Qt.AlignRight}
                                TextField {
                                    id: latitudeField
                                    //text: _geoZoneViewSettings.centerCoord.latitude
                                    text: latText
                                    Layout.preferredWidth: _rightPanelWidth

                                    onTextChanged: {
                                        latText = latitudeField.text
                                        _geoZoneViewSettings.centerCoord = QtPositioning.coordinate(
                                                    parseFloat(latText),
                                                    parseFloat(lonText)
                                                    )
                                    }
                                }

                                Label { text: "Longitude"; Layout.alignment: Qt.AlignRight }
                                TextField {
                                    id: longitudeField
                                    //text: _geoZoneViewSettings.centerCoord.longitude
                                    text: lonText
                                    Layout.preferredWidth: _rightPanelWidth

                                    onTextChanged: {
                                        lonText = longitudeField.text
                                        _geoZoneViewSettings.centerCoord = QtPositioning.coordinate(
                                                    parseFloat(latText),
                                                    parseFloat(lonText)
                                                    )
                                    }
                                }
                            }
                        }

                        Connections {
                            target: _geoZoneViewSettings
                            onCenterCoordChanged: {
                                latText = _geoZoneViewSettings.centerCoord.latitude.toString()
                                lonText = _geoZoneViewSettings.centerCoord.longitude.toString()
                            }
                        }

                        GroupBox {
                            title: "Area"
                            Layout.preferredWidth: _rightPanelWidth

                            GridLayout {
                                columns: 3
                                columnSpacing: 10
                                rowSpacing: 10

                                // === Vertical ===
                                Label { text: "Vertical" }

                                SpinBox {
                                    id: verticalSpin
                                    property bool ignoreValueChange: false
                                    from: 0
                                    to: 200000
                                    stepSize: 50
                                    editable: true
                                    value: _geoZoneViewSettings.verticalArea
                                    Layout.preferredWidth: _rightPanelWidth / 2
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelWidth * 5

                                    onValueChanged: {
                                        if (!ignoreValueChange && value !== _geoZoneViewSettings.verticalArea) {
                                            _geoZoneViewSettings.setVerticalSize(value)
                                        }
                                    }

                                    contentItem: TextInput {
                                        id: verticalInput
                                        text: verticalSpin.displayText
                                        focus: true
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        inputMethodHints: Qt.ImhFormattedNumbersOnly

                                        onEditingFinished: {
                                            const cleaned = text.replace(/,/g, "")   // 모든 , 제거
                                            const parsed = parseFloat(cleaned)
                                            if (!isNaN(parsed)) {
                                                verticalSpin.value = parsed
                                            }
                                        }
                                    }

                                    up.indicator: Rectangle {
                                        height: parent.height / 2
                                        width: 40
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        color: verticalSpin.up.pressed ? "#e4e4e4" : "#f6f6f6"
                                        border.color: enabled ? "#21be2b" : "#bdbebf"
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: verticalSpin.value += verticalSpin.stepSize
                                        }
                                        Text { text: '+'; anchors.centerIn: parent }
                                    }

                                    down.indicator: Rectangle {
                                        height: parent.height / 2
                                        width: 40
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        color: verticalSpin.down.pressed ? "#e4e4e4" : "#f6f6f6"
                                        border.color: enabled ? "#21be2b" : "#bdbebf"
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: verticalSpin.value -= verticalSpin.stepSize
                                        }
                                        Text { text: '-'; anchors.centerIn: parent }
                                    }
                                }

                                Label { text: "m" }

                                // === Horizontal ===
                                Label { text: "Horizontal" }

                                SpinBox {
                                    id: horizontalSpin
                                    property bool ignoreValueChange: false
                                    from: 0
                                    to: 200000
                                    stepSize: 50
                                    editable: true
                                    value: _geoZoneViewSettings.horizontalArea
                                    Layout.preferredWidth: _rightPanelWidth / 2
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelWidth * 5

                                    onValueChanged: {
                                        if (!ignoreValueChange && value !== _geoZoneViewSettings.horizontalLength) {
                                            _geoZoneViewSettings.setHorizontalSize(value)
                                        }
                                    }

                                    contentItem: TextInput {
                                        id: horizontalInput
                                        text: horizontalSpin.displayText
                                        focus: true
                                        verticalAlignment: Text.AlignVCenter
                                        horizontalAlignment: Text.AlignHCenter
                                        inputMethodHints: Qt.ImhFormattedNumbersOnly

                                        onEditingFinished: {
                                            const cleaned = text.replace(/,/g, "")   // 모든 , 제거
                                            const parsed = parseFloat(cleaned)
                                            //const parsed = parseFloat(text)
                                            if (!isNaN(parsed)) {
                                                horizontalSpin.value = parsed
                                            }
                                        }
                                    }

                                    up.indicator: Rectangle {
                                        height: parent.height / 2
                                        width: 40
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        color: horizontalSpin.up.pressed ? "#e4e4e4" : "#f6f6f6"
                                        border.color: enabled ? "#21be2b" : "#bdbebf"
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: horizontalSpin.value += horizontalSpin.stepSize
                                        }
                                        Text { text: '+'; anchors.centerIn: parent }
                                    }

                                    down.indicator: Rectangle {
                                        height: parent.height / 2
                                        width: 40
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        color: horizontalSpin.down.pressed ? "#e4e4e4" : "#f6f6f6"
                                        border.color: enabled ? "#21be2b" : "#bdbebf"
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: horizontalSpin.value -= horizontalSpin.stepSize
                                        }
                                        Text { text: '-'; anchors.centerIn: parent }
                                    }
                                }

                                Label { text: "m" }

                                // === Connections ===
                                Connections {
                                    target: _geoZoneViewSettings

                                    onVerticalLengthChanged: {
                                        if (verticalSpin.value !== _geoZoneViewSettings.verticalLength) {
                                            verticalSpin.ignoreValueChange = true
                                            verticalSpin.value = _geoZoneViewSettings.verticalLength
                                            verticalSpin.ignoreValueChange = false
                                        }
                                    }

                                    onHorizontalLengthChanged: {
                                        if (horizontalSpin.value !== _geoZoneViewSettings.horizontalLength) {
                                            horizontalSpin.ignoreValueChange = true
                                            horizontalSpin.value = _geoZoneViewSettings.horizontalLength
                                            horizontalSpin.ignoreValueChange = false
                                        }
                                    }
                                }
                            }
                        }

                        Button {
                            text: qsTr("DOWNLOAD")
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: _rightPanelWidth / 2
                            Layout.preferredHeight:ScreenTools.defaultFontPixelWidth * 4
                            onClicked: {
                                _geoZoneViewSettings.downloadGeoZone()
                                //fileSaveDialog.open()

                               saveToSelectedFile()
                            }

                            // FileDialog {
                            //     id: fileSaveDialog
                            //     title: "geoZone.geojson"
                            //     folder: Qt.platform.os === "android" ? "/storage/emulated/0/" : fileUrl
                            //     nameFilters: ["GeoJSON Files (*.geojson)", "All files (*)"]
                            //     selectExisting: false
                            //     selectFolder: false
                            //     onAccepted: {
                            //         _geoZoneViewSettings.getDownloadPath(fileUrl.toString())
                            //     }
                            // }


                            // QGCFileDialog {
                            //     id: fileDialog
                            //     folder: _appSettings ? _appSettings.geoZoneSavePath : ""

                            //     onAcceptedForSave: {
                            //         _planMasterController.saveToFile(file)
                            //     }

                            //     onAcceptedForLoad: {
                            //         _planMasterController.loadFromFile(file)
                            //         // _planMasterController.fitViewportToItems()
                            //         // _missionController.setCurrentPlanViewSeqNum(0, true)
                            //         close()
                            //     }
                            // }


                        }
                    }
                }

            }
        }
    }

    //- ToolStrip DropPanel Components

    // Component {
    //     id: patternDropPanel

    //     ColumnLayout {
    //         spacing:    ScreenTools.defaultFontPixelWidth * 0.5

    //         QGCLabel { text: qsTr("Create complex pattern:") }

    //         Repeater {
    //             model: _missionController.complexMissionItemNames

    //             QGCButton {
    //                 text:               modelData
    //                 Layout.fillWidth:   true

    //                 onClicked: {
    //                     insertComplexItemAfterCurrent(modelData)
    //                     dropPanel.hide()
    //                 }
    //             }
    //         }
    //     } // Column
    // }


}
