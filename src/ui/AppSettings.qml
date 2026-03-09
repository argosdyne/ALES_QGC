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

    property bool _privacyExpanded:         false
    readonly property string _privacyMainUrl: "qrc:/custom/ExternalSensingPrivacySettings.qml"
    readonly property var _privacyChildPages: [
        { title: qsTr("External Sensing"), url: "qrc:/custom/ExternalSensingPrivacySettings.qml" },
        { title: qsTr("Security Events"),  url: "qrc:/custom/SecurityValidationEventsSettings.qml" },
        { title: qsTr("Network Services"), url: "qrc:/custom/NetworkServicesPortsSettings.qml" },
        { title: qsTr("Connections"),      url: "qrc:/custom/ConnectionsOverrideSettings.qml" }
    ]

    QGCPalette { id: qgcPal }

    function _isPrivacyChild(url) {
        for (var i = 0; i < _privacyChildPages.length; i++) {
            if (_privacyChildPages[i].url === url) {
                return true
            }
        }
        return false
    }

    function _isPrivacySelection() {
        return _isPrivacyChild(String(__rightPanel.source))
    }

    Component.onCompleted: {
        //-- Default Settings
        if (globals.commingFromRIDIndicator) {
            __rightPanel.source = "qrc:/qml/RemoteIDSettings.qml"
            globals.commingFromRIDIndicator = false
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
                model:  QGroundControl.corePlugin.settingsPages
                ColumnLayout {
                    readonly property string _pageUrl: modelData.url.toString()
                    readonly property bool _isPrivacyMain: _pageUrl === _privacyMainUrl
                    readonly property bool _isPrivacyChild: settingsView._isPrivacyChild(_pageUrl)
                    readonly property bool _isRemoteId: _pageUrl === "qrc:/qml/RemoteIDSettings.qml"
                    Layout.fillWidth: true
                    spacing: _verticalMargin / 2
                    visible: (_isPrivacyMain || !_isPrivacyChild) && (!_isRemoteId || QGroundControl.settingsManager.remoteIDSettings.enable.rawValue)

                    QGCButton {
                        height:             _buttonHeight
                        text:               parent._isPrivacyMain ? qsTr("Privacy") : modelData.title
                        autoExclusive:      !parent._isPrivacyMain
                        Layout.fillWidth:   true
                        checked:            parent._isPrivacyMain ? settingsView._isPrivacySelection() : (String(__rightPanel.source) === parent._pageUrl)

                        onClicked: {
                            if (mainWindow.preventViewSwitch()) {
                                return
                            }

                            if (parent._isPrivacyMain) {
                                _privacyExpanded = !_privacyExpanded
                                if (_privacyExpanded && !settingsView._isPrivacySelection()) {
                                    __rightPanel.source = _privacyMainUrl
                                }
                            } else if (String(__rightPanel.source) !== parent._pageUrl) {
                                __rightPanel.source = parent._pageUrl
                            }
                        }
                    }

                    Repeater {
                        model: parent._isPrivacyMain && _privacyExpanded ? _privacyChildPages : []

                        QGCButton {
                            height:             _buttonHeight
                            text:               modelData.title
                            autoExclusive:      true
                            Layout.fillWidth:   true
                            Layout.leftMargin:  _horizontalMargin * 1.5
                            Layout.rightMargin: _horizontalMargin * 1.5
                            checked:            String(__rightPanel.source) === modelData.url

                            onClicked: {
                                if (mainWindow.preventViewSwitch()) {
                                    return
                                }
                                if (String(__rightPanel.source) !== modelData.url) {
                                    __rightPanel.source = modelData.url
                                }
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

