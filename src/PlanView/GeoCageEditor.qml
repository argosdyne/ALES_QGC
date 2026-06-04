import QtQuick          2.3
import QtQuick.Controls 1.2
import QtQuick.Layouts  1.2

import QGroundControl               1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controls      1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0

QGCFlickable {
    id:             root
    contentHeight:  cageRect.height
    clip:           true

    property var    myGeoCageController
    property var    flightMap
    property var    cageVisuals: null

    readonly property real  _editFieldWidth:    Math.min(width - _margin * 2, ScreenTools.defaultFontPixelWidth * 15)
    readonly property real  _margin:            ScreenTools.defaultFontPixelWidth * 1.1
    readonly property real  _radius:            ScreenTools.defaultFontPixelWidth / 2
    readonly property Fact  _nullFact:          Fact { }
    property real            _opacity:          0.45
    property color           _boundaryColor:    "#ffb300"
    property bool            _showVertical:     true
    property int             _breachStyle:      Qt.SolidLine
    readonly property real  _buttonWidth:      _editFieldWidth * 0.8

    function _syncVisuals() {
        if (!cageVisuals) {
            return
        }
        cageVisuals.cageOpacity = _opacity
        cageVisuals.boundaryColor = _boundaryColor
        cageVisuals.showVertical = _showVertical
        cageVisuals.breachStyle = _breachStyle
    }

    Rectangle {
        id:             cageRect
        anchors.left:   parent.left
        anchors.right:  parent.right
        height:         cageItems.y + cageItems.height + (_margin * 2)
        radius:         _radius
        color:          qgcPal.missionItemEditor

        QGCLabel {
            id:                 cageLabel
            anchors.margins:    _margin
            anchors.left:       parent.left
            anchors.top:        parent.top
            text:               qsTr("Cage")
            anchors.leftMargin: ScreenTools.defaultFontPixelWidth
        }

        Rectangle {
            id:                 cageItems
            anchors.margins:    _margin
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.top:        cageLabel.bottom
            height:             cageColumn.y + cageColumn.height + (_margin * 2)
            color:              qgcPal.windowShadeDark
            radius:             _radius

            Column {
                id:                 cageColumn
                anchors.margins:    _margin
                anchors.top:        parent.top
                anchors.left:       parent.left
                anchors.right:      parent.right
                spacing:            _margin * 0.8

                QGCLabel {
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    wrapMode:           Text.WordWrap
                    font.pointSize:     ScreenTools.smallFontPointSize
                    text:               qsTr("Cage constrains the vehicle inside a 3D keep-in volume. Local-only, not uploaded.")
                }

                Column {
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    spacing:            _margin * 0.6
                    visible:            true

                    SectionHeader {
                        text: qsTr("Cage Mode")
                        showSpacer: false
                        width: parent.width
                    }

                    Item { height: _margin / 3 }

                    Column {
                        spacing: _margin / 3
                        QGCRadioButton {
                            checked: true
                            text: qsTr("Horizontal + Vertical")
                            onClicked: {
                                _showVertical = true
                                _syncVisuals()
                            }
                        }
                        QGCRadioButton {
                            text: qsTr("Horizontal Only")
                            onClicked: {
                                _showVertical = false
                                _syncVisuals()
                            }
                        }
                        QGCRadioButton {
                            text: qsTr("Vertical Only")
                            onClicked: {
                                _showVertical = true
                                // radius stays; could hide base face
                                if (cageVisuals) {
                                    cageVisuals.cageOpacity = 0.0
                                }
                            }
                        }
                    }

                    SectionHeader {
                        text: qsTr("Horizontal Cage")
                    }

                    Column {
                        spacing: _margin / 3
                        QGCLabel {
                            text: qsTr("Radius from home")
                        }
                        FactTextField {
                            id:             radiusField
                            width:          _editFieldWidth
                            showUnits:      true
                            fact:           myGeoCageController ? myGeoCageController.cageRadius : _nullFact
                            enabled:        myGeoCageController
                            visible:        myGeoCageController
                        }
                    }

                    Row {
                        spacing: _margin / 2
                        QGCButton {
                            width: _buttonWidth
                            text: qsTr("Polygon")
                            onClicked: {
                                var rect = Qt.rect(flightMap.centerViewport.x, flightMap.centerViewport.y, flightMap.centerViewport.width, flightMap.centerViewport.height)
                                var topLeftCoord = flightMap.toCoordinate(Qt.point(rect.x, rect.y), false /* clipToViewPort */)
                                var bottomRightCoord = flightMap.toCoordinate(Qt.point(rect.x + rect.width, rect.y + rect.height), false /* clipToViewPort */)
                                myGeoCageController.addInclusionPolygon(topLeftCoord, bottomRightCoord)
                            }
                        }
                        QGCButton {
                            width: _buttonWidth
                            text: qsTr("Rectangle")
                            onClicked: {
                                var rect = Qt.rect(flightMap.centerViewport.x, flightMap.centerViewport.y, flightMap.centerViewport.width, flightMap.centerViewport.height)
                                var topLeftCoord = flightMap.toCoordinate(Qt.point(rect.x, rect.y), false /* clipToViewPort */)
                                var bottomRightCoord = flightMap.toCoordinate(Qt.point(rect.x + rect.width, rect.y + rect.height), false /* clipToViewPort */)
                                myGeoCageController.addInclusionPolygon(topLeftCoord, bottomRightCoord)
                            }
                        }
                        QGCButton {
                            text: qsTr("KML")
                            enabled: false
                        }
                    }

                    Row {
                        spacing: _margin / 2
                        QGCButton {
                            text: qsTr("Edit")
                            onClicked: myGeoCageController.clearAllInteractive()
                        }
                        QGCButton {
                            text: qsTr("Delete")
                            onClicked: myGeoCageController.removeAll()
                        }
                    }

                    QGCLabel {
                        text:       qsTr("Horizontal radius preview\nuses the circular fence drawn around home.")
                        wrapMode:   Text.WordWrap
                        visible:    myGeoCageController.cageRadius
                    }

                    SectionHeader {
                        text: qsTr("Vertical Limits")
                    }

                    Column {
                        spacing: _margin / 3
                        QGCLabel { text: qsTr("Max altitude") }
                        FactTextField {
                            id:             maxAltField
                            width:          _editFieldWidth
                            showUnits:      true
                            fact:           myGeoCageController ? myGeoCageController.cageMaxAltitude : _nullFact
                            enabled:        myGeoCageController
                            visible:        myGeoCageController
                        }
                    }

                    Column {
                        spacing: _margin / 3
                        QGCLabel { text: qsTr("Min altitude") }
                        FactTextField {
                            id:             minAltField
                            width:          _editFieldWidth
                            showUnits:      true
                            fact:           myGeoCageController ? myGeoCageController.cageMinAltitude : _nullFact
                            enabled:        myGeoCageController
                            visible:        myGeoCageController
                        }
                    }

                    QGCLabel {
                        text:       qsTr("If only max altitude is available, ground level is used as floor.")
                        wrapMode:   Text.WordWrap
                        visible:    true
                    }

                    SectionHeader {
                        text: qsTr("Display")
                    }

                    Row {
                        spacing: _margin / 2
                        QGCLabel { text: qsTr("Opacity") }
                        QGCSlider {
                            id: opacitySlider
                            width:          _editFieldWidth
                            minimumValue:   0.1
                            maximumValue:   0.9
                            stepSize:       0.05
                            value:          _opacity
                            onValueChanged: {
                                _opacity = value
                                _syncVisuals()
                            }
                        }
                    }

                    Row {
                        spacing: _margin / 2
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
                            onCurrentIndexChanged: {
                                _boundaryColor = model[currentIndex].color
                                _syncVisuals()
                            }
                        }
                    }

                    QGCCheckBox {
                        text: qsTr("Show vertical cage")
                        checked: _showVertical
                        onClicked: {
                            _showVertical = checked
                            _syncVisuals()
                        }
                    }

                    SectionHeader {
                        text: qsTr("On Cage Breach")
                    }

                    Row {
                        spacing: _margin
                        QGCRadioButton {
                            checked: _breachStyle === Qt.SolidLine
                            text: qsTr("Solid")
                            onClicked: { _breachStyle = Qt.SolidLine; _syncVisuals() }
                        }
                        QGCRadioButton {
                            checked: _breachStyle === Qt.DashLine
                            text: qsTr("Wireframe")
                            onClicked: { _breachStyle = Qt.DashLine; _syncVisuals() }
                        }
                        QGCRadioButton {
                            checked: _breachStyle === Qt.DotLine
                            text: qsTr("Dotted")
                            onClicked: { _breachStyle = Qt.DotLine; _syncVisuals() }
                        }
                    }

                }
            }
        }
    }
}
