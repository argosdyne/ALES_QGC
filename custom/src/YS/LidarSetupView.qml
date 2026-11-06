/****************************************************************************
 *
 * LiDAR Setup (YellowScan) - Select Tool > LiDAR Setup
 * Pages: Connection / Settings / Device
 *
 ****************************************************************************/

import QtQuick          2.3
import QtQuick.Controls 1.2
import QtQuick.Layouts  1.2

import QGroundControl               1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0

Rectangle {
    id:     lidarSetupView
    color:  qgcPal.window
    z:      QGroundControl.zOrderTopMost

    readonly property real _defaultTextHeight:  ScreenTools.defaultFontPixelHeight
    readonly property real _defaultTextWidth:   ScreenTools.defaultFontPixelWidth
    readonly property real _horizontalMargin:   _defaultTextWidth / 2
    readonly property real _verticalMargin:     _defaultTextHeight / 2
    readonly property real _buttonHeight:       ScreenTools.isTinyScreen ? ScreenTools.defaultFontPixelHeight * 3 : ScreenTools.defaultFontPixelHeight * 2

    readonly property var _pages: [
        { title: qsTr("Connection"),    url: "qrc:/qml/LidarConnectionPage.qml" },
        { title: qsTr("Settings"),      url: "qrc:/qml/LidarSettingsPage.qml" },
        { title: qsTr("Device"),        url: "qrc:/qml/LidarDevicePage.qml" }
    ]

    property int _currentPage: 0

    QGCPalette { id: qgcPal }

    QGCFlickable {
        id:                 buttonList
        width:              buttonColumn.width
        anchors.topMargin:  _verticalMargin
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        anchors.leftMargin: _horizontalMargin
        anchors.left:       parent.left
        contentHeight:      buttonColumn.height + _verticalMargin
        flickableDirection: Flickable.VerticalFlick
        clip:               true

        ColumnLayout {
            id:         buttonColumn
            spacing:    _verticalMargin

            Repeater {
                model: _pages

                QGCButton {
                    height:             _buttonHeight
                    text:               modelData.title
                    autoExclusive:      true
                    checked:            index === _currentPage
                    Layout.fillWidth:   true
                    Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 16

                    onClicked: {
                        if (mainWindow.preventViewSwitch()) {
                            return
                        }
                        _currentPage = index
                        checked = true
                    }
                }
            }
        }
    }

    Rectangle {
        id:                     divider
        anchors.topMargin:      _verticalMargin
        anchors.bottomMargin:   _verticalMargin
        anchors.leftMargin:     _horizontalMargin
        anchors.left:           buttonList.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        width:                  1
        color:                  qgcPal.windowShade
    }

    //-- Page contents
    Loader {
        id:                     pageLoader
        anchors.leftMargin:     _horizontalMargin
        anchors.rightMargin:    _horizontalMargin
        anchors.topMargin:      _verticalMargin
        anchors.bottomMargin:   _verticalMargin
        anchors.left:           divider.right
        anchors.right:          parent.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        source:                 _pages[_currentPage].url
    }
}
