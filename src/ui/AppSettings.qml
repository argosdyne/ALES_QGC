/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
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
    id:     settingsView
    color:  qgcPal.window
    z:      QGroundControl.zOrderTopMost

    readonly property real _defaultTextHeight:  ScreenTools.defaultFontPixelHeight
    readonly property real _defaultTextWidth:   ScreenTools.defaultFontPixelWidth
    readonly property real _horizontalMargin:   _defaultTextWidth / 2
    readonly property real _verticalMargin:     _defaultTextHeight / 2
    readonly property real _buttonHeight:       ScreenTools.isTinyScreen ? ScreenTools.defaultFontPixelHeight * 3 : ScreenTools.defaultFontPixelHeight * 2

    property bool   _first:                  true
    property bool   _commingFromRIDSettings: false
    property string _pendingRestrictedUrl:   ""

    function _syncAllButtonsFromSource() {
        for (var i = 0; i < settingsRepeater.count; i++) {
            var btn = settingsRepeater.itemAt(i)
            if (btn && btn._syncCheckedFromSource) {
                btn._syncCheckedFromSource()
            }
        }
    }

    // URLs that require re-authentication when in view-only mode
    readonly property var _restrictedUrls: [
        "qrc:/qml/GeneralSettings.qml",
        "qrc:/qml/ARSettings.qml",
        "qrc:/qml/MavlinkSettings.qml",
        "qrc:/qml/LinkSettings.qml"
    ]

    QGCPalette { id: qgcPal }

    Connections {
        target: mainWindow
        onViewOnlyModeChanged: {
            if (mainWindow.viewOnlyMode) {
                // Just entered view-only mode — if the current panel is restricted, hide it
                var currentSrc = String(__rightPanel.source)
                var isRestricted = false
                for (var i = 0; i < _restrictedUrls.length; i++) {
                    var fname = _restrictedUrls[i].split("/").pop()
                    if (currentSrc.indexOf(fname) !== -1) { isRestricted = true; break }
                }
                if (isRestricted) {
                    __rightPanel.source = "qrc:/qml/OfflineMap.qml"
                }
            } else if (_pendingRestrictedUrl !== "") {
                // Just unlocked — navigate to the page user originally wanted
                __rightPanel.source = _pendingRestrictedUrl
                _pendingRestrictedUrl = ""
            }
        }
    }

    Component.onCompleted: {
        //-- Default Settings
        if (globals.commingFromRIDIndicator) {
            __rightPanel.source = "qrc:/qml/RemoteIDSettings.qml"
            globals.commingFromRIDIndicator = false
        } else if (mainWindow.viewOnlyMode) {
            __rightPanel.source = "qrc:/qml/OfflineMap.qml"
        } else {
            __rightPanel.source = QGroundControl.corePlugin.settingsPages[QGroundControl.corePlugin.defaultSettings].url
        }
    }

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

            property real _maxButtonWidth: 0

            Repeater {
                id: settingsRepeater
                model:  QGroundControl.corePlugin.settingsPages
                QGCButton {
                    height:             _buttonHeight
                    text:               modelData.title
                    autoExclusive:      true
                    Layout.fillWidth:   true
                    visible:            modelData.url != "qrc:/qml/RemoteIDSettings.qml" ? true : QGroundControl.settingsManager.remoteIDSettings.enable.rawValue

                    function _syncCheckedFromSource() {
                        var loadedSrc = String(__rightPanel.source)
                        var btnFile = String(modelData.url).split("/").pop()
                        checked = loadedSrc.indexOf(btnFile) !== -1
                    }

                    onClicked: {
                        if (mainWindow.preventViewSwitch()) {
                            return
                        }
                        // Restricted pages require full login when in view-only mode
                        var isRestricted = false
                        for (var i = 0; i < _restrictedUrls.length; i++) {
                            if (String(modelData.url) === _restrictedUrls[i]) { isRestricted = true; break }
                        }
                        if (mainWindow.viewOnlyMode && isRestricted) {
                            _pendingRestrictedUrl = modelData.url
                            sessionManager.onAppBackground()
                            Qt.callLater(function() {
                                settingsView._syncAllButtonsFromSource()
                            })
                            return
                        }
                        if (__rightPanel.source !== modelData.url) {
                            __rightPanel.source = modelData.url
                        }
                        checked = true
                    }

                    Connections {
                        target: mainWindow
                        onViewOnlyModeChanged: {
                            if (mainWindow.viewOnlyMode) {
                                // Entered view-only → highlight OfflineMap
                                if (String(modelData.url) === "qrc:/qml/OfflineMap.qml") {
                                    checked = true
                                } 
                            } else {
                                Qt.callLater(function() {
                                    _syncCheckedFromSource()
                                })
                            }
                        }
                    }

                    Component.onCompleted: {
                        if (globals.commingFromRIDIndicator) {
                            _commingFromRIDSettings = true
                        }
                        if(_first) {
                            if (mainWindow.viewOnlyMode) {
                                // In view-only mode, check OfflineMapas the default
                                if (String(modelData.url) === "qrc:/qml/OfflineMap.qml") {
                                    _first = false
                                    checked = true
                                }
                            } else {
                                _first = false
                                checked = true
                            }
                        }
                        if (_commingFromRIDSettings) {
                            checked = false
                            _commingFromRIDSettings = false
                            if (modelData.url == "qrc:/qml/RemoteIDSettings.qml") {
                                checked = true
                            }
                        }
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

    //-- Panel Contents
    Loader {
        id:                     __rightPanel
        anchors.leftMargin:     _horizontalMargin
        anchors.rightMargin:    _horizontalMargin
        anchors.topMargin:      _verticalMargin
        anchors.bottomMargin:   _verticalMargin
        anchors.left:           divider.right
        anchors.right:          parent.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
    }
}

