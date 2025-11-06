/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Controls.Styles  1.4

import QGroundControl               1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Palette       1.0

Item {
    id:         _root
    visible:    false

    signal          clicked()
    property real   radius:             ScreenTools.isMobile ? ScreenTools.defaultFontPixelHeight * 1.75 : ScreenTools.defaultFontPixelHeight * 1.25
    property real   viewportMargins:    0
    property var    toolStrip

    // Should be an enum but that get's into the whole problem of creating a singleton which isn't worth the effort
    readonly property int dropLeft:     1
    readonly property int dropRight:    2
    readonly property int dropUp:       3
    readonly property int dropDown:     4

    readonly property real _arrowBaseHeight:    radius             // Height of vertical side of arrow
    readonly property real _arrowPointWidth:    radius * 0.666     // Distance from vertical side to point
    readonly property real _dropMargin:         ScreenTools.defaultFontPixelWidth

    property var    _dropEdgeTopPoint
    property alias  _dropDownComponent: panelLoader.sourceComponent
    property real   _viewportMaxTop:    0
    property real   _viewportMaxBottom: parent.parent.height - parent.y
    property real   _viewportMaxHeight: _viewportMaxBottom - _viewportMaxTop
    property var    _dropPanelCancel
    property var    _parentButton
    property int    dropDirection:     dropRight

    function show(panelEdgeTopPoint, panelComponent, parentButton) {
        _parentButton = parentButton
        _dropEdgeTopPoint = panelEdgeTopPoint
        _dropDownComponent = panelComponent
        _calcPositions()
        visible = true
        _dropPanelCancel = dropPanelCancelComponent.createObject(toolStrip.parent)
    }

    function hide() {
        if (_dropPanelCancel) {
            _dropPanelCancel.destroy()
            _parentButton.checked = false
            visible = false
            _dropDownComponent = undefined
        }
    }

    function _calcPositions() {
        var panelComponentWidth  = panelLoader.item.width
        var panelComponentHeight = panelLoader.item.height

        // dropDownItem.width  = panelComponentWidth  + (_dropMargin * 2) + _arrowPointWidth
        // dropDownItem.height = panelComponentHeight + (_dropMargin * 2)

        // Calculate width and height based on drop direction
        if (dropDirection === dropLeft || dropDirection === dropRight) {
            dropDownItem.width  = panelComponentWidth  + (_dropMargin * 2) + _arrowPointWidth
            dropDownItem.height = panelComponentHeight + (_dropMargin * 2)
        } else {
            dropDownItem.width  = panelComponentWidth  + (_dropMargin * 2)
            dropDownItem.height = panelComponentHeight + (_dropMargin * 2) + _arrowPointWidth
        }

        // dropDownItem.x = _dropEdgeTopPoint.x + _dropMargin
        // dropDownItem.y = _dropEdgeTopPoint.y -(dropDownItem.height / 2) + radius

        // Set position based on drop direction
        switch (dropDirection) {
        case dropLeft:
            dropDownItem.x = _dropEdgeTopPoint.x - dropDownItem.width - _dropMargin
            dropDownItem.y = _dropEdgeTopPoint.y - (dropDownItem.height / 2) + radius
            break
        case dropRight:
            dropDownItem.x = _dropEdgeTopPoint.x + _dropMargin
            dropDownItem.y = _dropEdgeTopPoint.y - (dropDownItem.height / 2) + radius
            break
        case dropUp:
            dropDownItem.x = _dropEdgeTopPoint.x - (dropDownItem.width / 2) + radius
            dropDownItem.y = _dropEdgeTopPoint.y - dropDownItem.height - _dropMargin
            break
        case dropDown:
        default:
            dropDownItem.x = _dropEdgeTopPoint.x - (dropDownItem.width / 2) + radius
            dropDownItem.y = _dropEdgeTopPoint.y + _dropMargin
            break
        }

        // Validate that dropdown is within viewport
        // dropDownItem.y = Math.min(dropDownItem.y + dropDownItem.height, _viewportMaxBottom) - dropDownItem.height
        // dropDownItem.y = Math.max(dropDownItem.y, _viewportMaxTop)

        if (dropDirection !== dropUp && dropDirection !== dropDown) {
            dropDownItem.y = Math.min(dropDownItem.y + dropDownItem.height, _viewportMaxBottom) - dropDownItem.height
            dropDownItem.y = Math.max(dropDownItem.y, _viewportMaxTop)
        }

        // Adjust height to not exceed viewport bounds
        dropDownItem.height = Math.min(dropDownItem.height, _viewportMaxHeight - dropDownItem.y)

        // Arrow points
        // arrowCanvas.arrowPoint.y = (_dropEdgeTopPoint.y + radius) - dropDownItem.y
        // arrowCanvas.arrowPoint.x = 0
        // arrowCanvas.arrowBase1.x = _arrowPointWidth
        // arrowCanvas.arrowBase1.y = arrowCanvas.arrowPoint.y - (_arrowBaseHeight / 2)
        // arrowCanvas.arrowBase2.x = arrowCanvas.arrowBase1.x
        // arrowCanvas.arrowBase2.y = arrowCanvas.arrowBase1.y + _arrowBaseHeight
        // arrowCanvas.requestPaint()

        if (dropDirection === dropLeft || dropDirection === dropRight) {
            arrowCanvas.arrowPoint.y = (_dropEdgeTopPoint.y + radius) - dropDownItem.y
            arrowCanvas.arrowPoint.x = (dropDirection === dropLeft) ? dropDownItem.width : 0
            arrowCanvas.arrowBase1.x = (dropDirection === dropLeft) ? dropDownItem.width - _arrowPointWidth : _arrowPointWidth
            arrowCanvas.arrowBase1.y = arrowCanvas.arrowPoint.y - (_arrowBaseHeight / 2)
            arrowCanvas.arrowBase2.x = arrowCanvas.arrowBase1.x
            arrowCanvas.arrowBase2.y = arrowCanvas.arrowBase1.y + _arrowBaseHeight
        } else {
            arrowCanvas.arrowPoint.x = (_dropEdgeTopPoint.x + radius) - dropDownItem.x
            arrowCanvas.arrowPoint.y = (dropDirection === dropUp) ? dropDownItem.height : 0
            arrowCanvas.arrowBase1.y = (dropDirection === dropUp) ? dropDownItem.height - _arrowPointWidth : _arrowPointWidth
            arrowCanvas.arrowBase1.x = arrowCanvas.arrowPoint.x - (_arrowBaseHeight / 2)
            arrowCanvas.arrowBase2.x = arrowCanvas.arrowBase1.x + _arrowBaseHeight
            arrowCanvas.arrowBase2.y = arrowCanvas.arrowBase1.y
        }
    } // function - _calcPositions

    QGCPalette { id: qgcPal }

    Component {
        // Overlay which is used to cancel the panel when the user clicks away
        id: dropPanelCancelComponent

        MouseArea {
            anchors.fill:   parent
            z:              toolStrip.z - 1
            onClicked:      dropPanel.hide()
        }
    }

    // This item is sized to hold the entirety of the drop panel including the arrow point
    Item {
        id: dropDownItem

        DeadMouseArea {
            anchors.fill: parent
        }

        Canvas {
            id:             arrowCanvas
            anchors.fill:   parent

            property point arrowPoint: Qt.point(0, 0)
            property point arrowBase1: Qt.point(0, 0)
            property point arrowBase2: Qt.point(0, 0)

            onPaint: {                

                var context = getContext("2d")
                context.reset()
                context.beginPath()

                switch (dropDirection) {
                case dropRight:
                    var panelX = _arrowPointWidth
                    var panelY = 0
                    var panelWidth = parent.width - _arrowPointWidth
                    var panelHeight = parent.height
                    context.moveTo(panelX, panelY)                              // top left
                    context.lineTo(panelX + panelWidth, panelY)                 // top right
                    context.lineTo(panelX + panelWidth, panelY + panelHeight)   // bottom right
                    context.lineTo(panelX, panelY + panelHeight)                // bottom left
                    context.lineTo(arrowBase2.x, arrowBase2.y)
                    context.lineTo(arrowPoint.x, arrowPoint.y)
                    context.lineTo(arrowBase1.x, arrowBase1.y)
                    context.lineTo(panelX, panelY)                              // top left
                    break
                case dropLeft:
                    var panelX = 0
                    var panelY = 0
                    var panelWidth = parent.width - _arrowPointWidth
                    var panelHeight = parent.height
                    context.moveTo(panelX, panelY)                              // top left
                    context.lineTo(panelX + panelWidth, panelY)                 // top right
                    context.lineTo(arrowBase1.x, arrowBase1.y)
                    context.lineTo(arrowPoint.x, arrowPoint.y)
                    context.lineTo(arrowBase2.x, arrowBase2.y)
                    context.lineTo(panelX + panelWidth, panelY + panelHeight)   // bottom right
                    context.lineTo(panelX, panelY + panelHeight)                // bottom left
                    context.lineTo(panelX, panelY)                              // top left
                    break
                case dropUp:
                    var panelX = 0
                    var panelY = 0
                    var panelWidth = parent.width
                    var panelHeight = parent.height - _arrowPointWidth
                    context.moveTo(panelX, panelY)                              // top left
                    context.lineTo(panelX + panelWidth, panelY)                 // top right
                    context.lineTo(panelX + panelWidth, panelY + panelHeight)   // bottom right
                    context.lineTo(arrowBase2.x, arrowBase2.y)
                    context.lineTo(arrowPoint.x, arrowPoint.y)
                    context.lineTo(arrowBase1.x, arrowBase1.y)
                    context.lineTo(panelX, panelY + panelHeight)                // bottom left
                    context.lineTo(panelX, panelY)                              // top left
                    break
                case dropDown:
                    var panelX = 0
                    var panelY = _arrowPointWidth
                    var panelWidth = parent.width
                    var panelHeight = parent.height - _arrowPointWidth
                    context.moveTo(panelX, panelY)                              // top left
                    context.lineTo(arrowBase1.x, arrowBase1.y)
                    context.lineTo(arrowPoint.x, arrowPoint.y)
                    context.lineTo(arrowBase2.x, arrowBase2.y)
                    context.lineTo(panelX + panelWidth, panelY)                 // top right
                    context.lineTo(panelX + panelWidth, panelY + panelHeight)   // bottom right
                    context.lineTo(panelX, panelY + panelHeight)                // bottom left
                    context.lineTo(panelX, panelY)                              // top left
                default:
                    break
                }

                context.closePath()
                context.fillStyle = qgcPal.windowShade
                context.fill()
            }
        } // Canvas - arrowCanvas

        QGCFlickable {
            id:                 panelItemFlickable
            anchors.leftMargin: (dropDirection === dropRight) ? _dropMargin + _arrowPointWidth : _dropMargin
            anchors.rightMargin: (dropDirection === dropLeft) ? _dropMargin + _arrowPointWidth : _dropMargin
            anchors.topMargin: (dropDirection === dropDown) ? _dropMargin + _arrowPointWidth : _dropMargin
            anchors.bottomMargin: (dropDirection === dropUp) ? _dropMargin + _arrowPointWidth : _dropMargin
            anchors.fill:       parent
            flickableDirection: Flickable.VerticalFlick
            contentWidth:       panelLoader.width
            contentHeight:      panelLoader.height

            Loader {
                id: panelLoader

                onHeightChanged:    _calcPositions()
                onWidthChanged:     _calcPositions()

                property var dropPanel: _root
            }
        }
    } // Item - dropDownItem
}
