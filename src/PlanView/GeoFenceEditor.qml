import QtQuick          2.3
import QtQuick.Controls 1.2
import QtQuick.Layouts  1.2
import QtPositioning    5.2

import QGroundControl               1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controls      1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0

QGCFlickable {
    id:             root
    contentHeight:  geoFenceEditorRect.height
    clip:           true

    property var    myGeoFenceController
    property var    myGeoCageController
    property var    flightMap
    property bool   show3DView: false
    property int    _breachStyle: Qt.SolidLine
    property real   fenceOpacity: 0.9
    property color  boundaryColor: "#ffb300"

    readonly property real  _editFieldWidth:    Math.min(width - _margin * 2, ScreenTools.defaultFontPixelWidth * 15)
    readonly property real  _margin:            ScreenTools.defaultFontPixelWidth / 2
    readonly property real  _radius:            ScreenTools.defaultFontPixelWidth / 2

    Rectangle {
        id:     geoFenceEditorRect
        anchors.left:   parent.left
        anchors.right:  parent.right
        height: geoFenceItems.y + geoFenceItems.height + (_margin * 2)
        radius: _radius
        color:  qgcPal.missionItemEditor

        QGCLabel {
            id:                 geoFenceLabel
            anchors.margins:    _margin
            anchors.left:       parent.left
            anchors.top:        parent.top
            text:               qsTr("GeoFence")
            anchors.leftMargin: ScreenTools.defaultFontPixelWidth
        }

        Rectangle {
            id:                 geoFenceItems
            anchors.margins:    _margin
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.top:        geoFenceLabel.bottom
            height:             fenceColumn.y + fenceColumn.height + (_margin * 2)
            color:              qgcPal.windowShadeDark
            radius:             _radius

            Column {
                id:                 fenceColumn
                anchors.margins:    _margin
                anchors.top:        parent.top
                anchors.left:       parent.left
                anchors.right:      parent.right
                spacing:            _margin

                QGCLabel {
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    wrapMode:           Text.WordWrap
                    font.pointSize:     myGeoFenceController.supported ? ScreenTools.smallFontPointSize : ScreenTools.defaultFontPointSize
                    text:               myGeoFenceController.supported ?
                                            qsTr("GeoFencing allows you to set a virtual fence around the area you want to fly in.") :
                                            qsTr("This vehicle does not support GeoFence.")
                }

                Column {
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    spacing:            _margin
                    visible:            myGeoFenceController.supported

                    Repeater {
                        model: myGeoFenceController.params

                        Item {
                            width:  fenceColumn.width
                            height: textField.height

                            property bool showCombo: modelData.enumStrings.length > 0

                            QGCLabel {
                                id:                 textFieldLabel
                                anchors.baseline:   textField.baseline
                                text:               myGeoFenceController.paramLabels[index]
                            }

                            FactTextField {
                                id:             textField
                                anchors.right:  parent.right
                                width:          _editFieldWidth
                                showUnits:      true
                                fact:           modelData
                                visible:        !parent.showCombo
                            }

                            FactComboBox {
                                id:             comboField
                                anchors.right:  parent.right
                                width:          _editFieldWidth
                                indexModel:     false
                                fact:           showCombo ? modelData : _nullFact
                                visible:        parent.showCombo

                                property var _nullFact: Fact { }
                            }
                        }
                    }

                    SectionHeader {
                        id:             insertSection
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        text:           qsTr("Insert GeoFence")
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Polygon Fence")

                        onClicked: {
                            var rect = Qt.rect(flightMap.centerViewport.x, flightMap.centerViewport.y, flightMap.centerViewport.width, flightMap.centerViewport.height)
                            var topLeftCoord = flightMap.toCoordinate(Qt.point(rect.x, rect.y), false /* clipToViewPort */)
                            var bottomRightCoord = flightMap.toCoordinate(Qt.point(rect.x + rect.width, rect.y + rect.height), false /* clipToViewPort */)
                            myGeoFenceController.addInclusionPolygon(topLeftCoord, bottomRightCoord)
                            if (myGeoCageController) {
                                myGeoCageController.addInclusionPolygon(topLeftCoord, bottomRightCoord)
                            }
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Circular Fence")

                        onClicked: {
                            var rect = Qt.rect(flightMap.centerViewport.x, flightMap.centerViewport.y, flightMap.centerViewport.width, flightMap.centerViewport.height)
                            var topLeftCoord = flightMap.toCoordinate(Qt.point(rect.x, rect.y), false /* clipToViewPort */)
                            var bottomRightCoord = flightMap.toCoordinate(Qt.point(rect.x + rect.width, rect.y + rect.height), false /* clipToViewPort */)
                            myGeoFenceController.addInclusionCircle(topLeftCoord, bottomRightCoord)
                        }
                    }

                    QGCCheckBox {
                        text:       qsTr("3D View")
                        checked:    show3DView
                        onClicked:  show3DView = checked
                    }

                    Row {
                        spacing: _margin / 2
                        visible: show3DView
                        QGCLabel { text: qsTr("Vertical cage") }
                    QGCRadioButton {
                            checked: _breachStyle === Qt.SolidLine
                            text: qsTr("Solid")
                            onClicked: _breachStyle = Qt.SolidLine
                        }
                        QGCRadioButton {
                            checked: _breachStyle === Qt.DotLine
                            text: qsTr("Dotted")
                            onClicked: _breachStyle = Qt.DotLine
                        }
                    }

                    Row {
                        spacing: _margin / 2
                        visible: show3DView
                        QGCLabel { text: qsTr("Opacity") }
                        QGCSlider {
                            id: opacitySlider
                            width: _editFieldWidth
                            minimumValue: 0.1
                            maximumValue: 1.0
                            stepSize: 0.05
                            value: fenceOpacity
                            onValueChanged: fenceOpacity = value
                        }
                    }

                    Row {
                        spacing: _margin / 2
                        visible: show3DView
                        QGCLabel { text: qsTr("Boundary Color") }
                        QGCComboBox {
                            model: [
                                { name: qsTr("Yellow"), color: "#ffb300" },
                                { name: qsTr("Orange"), color: "#ff7a00" },
                                { name: qsTr("Red"), color: "#e53935" },
                                { name: qsTr("Blue"), color: "#1976d2" },
                                { name: qsTr("Green"), color: "#2e7d32" }
                            ]
                            textRole: "name"
                            currentIndex: 0
                            onCurrentIndexChanged: boundaryColor = model[currentIndex].color
                        }
                    }

                    SectionHeader {
                        id:             polygonSection
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        text:           qsTr("Polygon Fences")
                    }

                    QGCLabel {
                        text:       qsTr("None")
                        visible:    polygonSection.checked && myGeoFenceController.polygons.count === 0
                    }

                    GridLayout {
                        Layout.fillWidth:   true
                        columns:            3
                        flow:               GridLayout.TopToBottom
                        visible:            polygonSection.checked && myGeoFenceController.polygons.count > 0

                        QGCLabel {
                            text:               qsTr("Inclusion")
                            Layout.column:      0
                            Layout.alignment:   Qt.AlignHCenter
                        }

                        Repeater {
                            model: myGeoFenceController.polygons

                            QGCCheckBox {
                                checked:            object.inclusion
                                onClicked:          object.inclusion = checked
                                Layout.alignment:   Qt.AlignHCenter
                            }
                        }

                        QGCLabel {
                            text:               qsTr("Edit")
                            Layout.column:      1
                            Layout.alignment:   Qt.AlignHCenter
                        }

                        Repeater {
                            model: myGeoFenceController.polygons

                            QGCRadioButton {
                                checked:            _interactive
                                Layout.alignment:   Qt.AlignHCenter

                                property bool _interactive: object.interactive

                                on_InteractiveChanged: checked = _interactive

                                onClicked: {
                                    myGeoFenceController.clearAllInteractive()
                                    object.interactive = checked
                                }
                            }
                        }

                        QGCLabel {
                            text:               qsTr("Delete")
                            Layout.column:      2
                            Layout.alignment:   Qt.AlignHCenter
                        }

                        Repeater {
                            model: myGeoFenceController.polygons

                            QGCButton {
                                text:               qsTr("Del")
                                Layout.alignment:   Qt.AlignHCenter
                                onClicked:          myGeoFenceController.deletePolygon(index)
                            }
                        }
                    } // GridLayout

                    SectionHeader {
                        id:             circleSection
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        text:           qsTr("Circular Fences")
                    }

                    QGCLabel {
                        text:       qsTr("None")
                        visible:    circleSection.checked && myGeoFenceController.circles.count === 0
                    }
                    // --- 헤더 라벨 줄 ---
                    // GridLayout {
                    //     columns: 4
                    //     width: parent.width
                    //     visible:            circleSection.checked && myGeoFenceController.circles.count > 0
                    //     QGCLabel {
                    //         text: qsTr("Inclusion")
                    //         Layout.column: 0
                    //         Layout.alignment: Qt.AlignHCenter
                    //     }

                    //     QGCLabel {
                    //         text: qsTr("Edit")
                    //         Layout.column: 1
                    //         Layout.alignment: Qt.AlignHCenter
                    //     }

                    //     QGCLabel {
                    //         text: qsTr("Radius")
                    //         Layout.column: 2
                    //         Layout.alignment: Qt.AlignHCenter
                    //     }

                    //     QGCLabel {
                    //         text: qsTr("Delete")
                    //         Layout.column: 3
                    //         Layout.alignment: Qt.AlignHCenter
                    //     }
                    // }

                    // --- circles 리스트 및 newInclusion 줄 포함 ListView ---
                    // ListView {
                    //     id: circleListView
                    //     width: parent.width
                    //     model: myGeoFenceController.circles
                    //     height: contentHeight   // 스크롤 없애고 전부 보이게
                    //     visible:            circleSection.checked && myGeoFenceController.circles.count > 0

                    //     delegate: ColumnLayout {
                    //         width: circleListView.width

                    //         // === 기존 항목 줄 ===
                    //         GridLayout {
                    //             columns: 4
                    //             width: parent.width

                    //             QGCCheckBox {
                    //                 checked: object.inclusion
                    //                 Layout.alignment: Qt.AlignHCenter
                    //                 onClicked: object.inclusion = checked
                    //             }

                    //             QGCRadioButton {
                    //                 property bool _interactive: object.interactive
                    //                 checked: _interactive
                    //                 Layout.alignment: Qt.AlignHCenter

                    //                 on_InteractiveChanged: checked = _interactive

                    //                 onClicked: {
                    //                     myGeoFenceController.clearAllInteractive()
                    //                     object.interactive = checked
                    //                 }
                    //             }

                    //             FactTextField {
                    //                 fact: object.radius
                    //                 Layout.fillWidth: true
                    //                 Layout.alignment: Qt.AlignHCenter
                    //             }

                    //             QGCButton {
                    //                 text: qsTr("Del")
                    //                 Layout.alignment: Qt.AlignHCenter
                    //                 onClicked: myGeoFenceController.deleteCircle(index)
                    //             }
                    //         }

                            // SectionHeader {
                            //     id:             circleSettingSection
                            //     Layout.fillWidth: true
                            //     text:           qsTr("Settings")
                            //     checked: false
                            // }

                            // === newInclusion 줄 ===
                            // GridLayout {
                            //     columns: 2
                            //     width: parent.width
                            //     visible: circleSettingSection.checked

                            //     Text {
                            //         text:               qsTr("Max Altitude:")
                            //         Layout.fillWidth:   true
                            //         color: qgcPal.text
                            //     }

                            //     FactTextField {
                            //         fact:               object.radius
                            //         Layout.fillWidth:   true
                            //     }

                            //     Text {
                            //         text:               qsTr("Min Altitude:")
                            //         Layout.fillWidth:   true
                            //         color: qgcPal.text
                            //     }

                            //     FactTextField {
                            //         fact: _fenceMinAlt
                            //         Layout.fillWidth: true
                            //     }

                            //     Text {
                            //         text:               qsTr("Start Time(h)")
                            //         Layout.fillWidth:   true
                            //         color: qgcPal.text
                            //     }

                            //     FactTextField {
                            //         fact: _fenceStartTime
                            //         Layout.fillWidth: true
                            //     }

                            //     Text {
                            //         text:               qsTr("Duration Time(h)")
                            //         Layout.fillWidth:   true
                            //         color: qgcPal.text
                            //     }

                            //     FactTextField {
                            //         fact: _fenceDurationTime
                            //         Layout.fillWidth: true
                            //     }

                            //     Text {
                            //         text:               qsTr("Time Zone(GMT)")
                            //         Layout.fillWidth:   true
                            //         color: qgcPal.text
                            //     }

                            //     FactTextField {
                            //         fact: _fenceTimeZone
                            //         Layout.fillWidth: true
                            //     }
                            // }

                            // Rectangle {
                            //     Layout.fillWidth:   true
                            //     height:             1
                            //     color:              qgcPal.text
                            // }

                    //     }
                    // }


                    GridLayout {
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        columns:            4
                        flow:               GridLayout.TopToBottom
                        visible:            polygonSection.checked && myGeoFenceController.circles.count > 0

                        QGCLabel {
                            text:               qsTr("Inclusion")
                            Layout.column:      0
                            Layout.alignment:   Qt.AlignHCenter
                        }

                        Repeater {
                            model: myGeoFenceController.circles

                            QGCCheckBox {
                                checked:            object.inclusion
                                onClicked:          object.inclusion = checked
                                Layout.alignment:   Qt.AlignHCenter
                            }
                        }

                        QGCLabel {
                            text:               qsTr("Edit")
                            Layout.column:      1
                            Layout.alignment:   Qt.AlignHCenter
                        }

                        Repeater {
                            model: myGeoFenceController.circles

                            QGCRadioButton {
                                checked:            _interactive
                                Layout.alignment:   Qt.AlignHCenter

                                property bool _interactive: object.interactive

                                on_InteractiveChanged: checked = _interactive

                                onClicked: {
                                    myGeoFenceController.clearAllInteractive()
                                    object.interactive = checked
                                }
                            }
                        }

                        QGCLabel {
                            text:               qsTr("Radius")
                            Layout.column:      2
                            Layout.alignment:   Qt.AlignHCenter
                        }

                        Repeater {
                            model: myGeoFenceController.circles

                            FactTextField {
                                fact:               object.radius
                                Layout.fillWidth:   true
                                Layout.alignment:   Qt.AlignHCenter
                            }
                        }

                        QGCLabel {
                            text:               qsTr("Delete")
                            Layout.column:      3
                            Layout.alignment:   Qt.AlignHCenter
                        }

                        Repeater {
                            model: myGeoFenceController.circles

                            QGCButton {
                                text:               qsTr("Del")
                                Layout.alignment:   Qt.AlignHCenter
                                onClicked:          myGeoFenceController.deleteCircle(index)
                            }
                        }
                    } // GridLayout

                    // ────────────────────────────────
                    // GridLayout {
                    //     anchors.left: parent.left
                    //     anchors.right: parent.right
                    //     columns: 4

                    //     QGCLabel {
                    //         text: qsTr("New Inclusion")
                    //         Layout.alignment: Qt.AlignHCenter
                    //     }

                    //     QGCRadioButton {
                    //         Layout.alignment: Qt.AlignHCenter
                    //         onClicked: {
                    //             // 새 항목에서 선택된 경우
                    //         }
                    //     }

                    //     FactTextField {
                    //         placeholderText: "New radius"
                    //         Layout.alignment: Qt.AlignHCenter
                    //         Layout.fillWidth: true
                    //     }

                    //     QGCButton {
                    //         text: qsTr("Add")
                    //         Layout.alignment: Qt.AlignHCenter
                    //         onClicked: {
                    //             myGeoFenceController.addNewCircle()
                    //         }
                    //     }
                    // }


                    //Make Repeater about geofence setting ui
                    // Repeater{
                    //     model: myGeoFenceController.circles

                    //     GridLayout{
                    //         QGCButton {
                    //             text: "test"
                    //         }
                    //     }
                    // }



                    SectionHeader {
                        id:             breachReturnSection
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        text:           qsTr("Breach Return Point")
                    }

                    QGCButton {
                        text:               qsTr("Add Breach Return Point")
                        visible:            breachReturnSection.visible && !myGeoFenceController.breachReturnPoint.isValid
                        anchors.left:       parent.left
                        anchors.right:      parent.right

                        onClicked: myGeoFenceController.breachReturnPoint = flightMap.center
                    }

                    QGCButton {
                        text:               qsTr("Remove Breach Return Point")
                        visible:            breachReturnSection.visible && myGeoFenceController.breachReturnPoint.isValid
                        anchors.left:       parent.left
                        anchors.right:      parent.right

                        onClicked: myGeoFenceController.breachReturnPoint = QtPositioning.coordinate()
                    }

                    ColumnLayout {
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        spacing:            _margin
                        visible:            breachReturnSection.visible && myGeoFenceController.breachReturnPoint.isValid

                        QGCLabel {
                            text: qsTr("Altitude")
                        }

                        FactTextField {
                            fact: myGeoFenceController.breachReturnAltitude
                        }
                    }

                }
            }
        }
    } // Rectangle
}
