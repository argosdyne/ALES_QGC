/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick                  2.11
import QtQuick.Controls         2.4
import QtQuick.Layouts          1.11

import QGroundControl                       1.0
import QGroundControl.FactSystem            1.0
import QGroundControl.FactControls          1.0
import QGroundControl.Controls              1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.Palette               1.0
import QGroundControl.QGCMapEngineManager   1.0

Rectangle {
    id:                 root
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    property string _mapProvider:       QGroundControl.settingsManager.flightMapSettings.mapProvider.value
    property string _mapType:           QGroundControl.settingsManager.flightMapSettings.mapType.value
    property Fact   _mapboxFact:        QGroundControl.settingsManager.appSettings.mapboxToken
    property Fact   _mapboxAccountFact: QGroundControl.settingsManager.appSettings.mapboxAccount
    property Fact   _mapboxStyleFact:   QGroundControl.settingsManager.appSettings.mapboxStyle
    property Fact   _esriFact:          QGroundControl.settingsManager.appSettings.esriToken
    property Fact   _vworldFact:        QGroundControl.settingsManager.appSettings.vworldToken
    property Fact   _customURLFact:     QGroundControl.settingsManager.appSettings.customURL

    property bool   editorOpen:         false

    property real   _comboFieldWidth:   ScreenTools.defaultFontPixelWidth * 52
    property real   _mapComboWidth:     ScreenTools.defaultFontPixelWidth * 32
    property real   _margins:           ScreenTools.defaultFontPixelWidth

    readonly property bool _mapTransferBusy:    QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionImporting
                                                || QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionExporting
    readonly property bool _vworldTokenMissing: _vworldFact && String(_vworldFact.rawValue).length === 0
    readonly property bool _showVworldTokenWarning: _vworldFact && _vworldFact.visible && _mapProvider === "VWorld" && _vworldTokenMissing
    readonly property bool _showTokens:         (_mapboxFact && _mapboxFact.visible) || (_esriFact && _esriFact.visible) || (_vworldFact && _vworldFact.visible)
    readonly property bool _showMapboxLogin:    (_mapboxAccountFact && _mapboxAccountFact.visible) || (_mapboxStyleFact && _mapboxStyleFact.visible)
    readonly property bool _showCustomUrl:      _customURLFact && _customURLFact.visible

    QGCPalette { id: qgcPal }

    Component.onCompleted: QGroundControl.mapEngineManager.loadTileSets()

    function openAdd() {
        editorOpen = true
        offlineEditor.addNewSet()
    }

    function openEdit(tileSet) {
        editorOpen = true
        offlineEditor._currentSelection = tileSet
        offlineEditor.showInfo()
    }

    function openExport() {
        editorOpen = true
        offlineEditor.showExport()
    }

    QGCFlickable {
        id:                 settingsView
        anchors.fill:       parent
        clip:               true
        visible:            !editorOpen
        z:                  editorOpen ? 0 : 1
        contentWidth:       outerItem.width
        contentHeight:      outerItem.height

        Item {
            id:     outerItem
            width:  Math.max(settingsView.width, settingsColumn.width)
            height: settingsColumn.height

            ColumnLayout {
                id:                         settingsColumn
                anchors.horizontalCenter:   parent.horizontalCenter
                spacing:                    _margins

                QGCLabel { text: qsTr("Map") }

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredWidth:  _comboFieldWidth + (ScreenTools.defaultFontPixelWidth * 22)
                    Layout.preferredHeight: providerGrid.height + (_margins * 2)
                    color:                  qgcPal.windowShade

                    GridLayout {
                        id:                         providerGrid
                        anchors.top:                parent.top
                        anchors.topMargin:          _margins
                        anchors.left:               parent.left
                        anchors.right:              parent.right
                        anchors.leftMargin:        _margins
                        anchors.rightMargin:       _margins
                        columns:                    2
                        columnSpacing:              _margins
                        rowSpacing:                 _margins

                        QGCLabel { text: qsTr("Provider"); Layout.fillWidth: true }
                        QGCComboBox {
                            id:                     mapCombo
                            Layout.preferredWidth: _mapComboWidth
                            Layout.alignment:      Qt.AlignRight
                            model:                  QGroundControl.mapEngineManager.mapProviderList
                            onActivated: {
                                var provider = textAt(index)
                                var types = QGroundControl.mapEngineManager.mapTypeList(provider)
                                _mapProvider = provider
                                _mapType = types.length ? types[0] : ""
                                QGroundControl.settingsManager.flightMapSettings.mapProvider.value = provider
                                QGroundControl.settingsManager.flightMapSettings.mapType.value = _mapType
                                mapTypeCombo.currentIndex = 0
                            }
                            Component.onCompleted: {
                                var index = mapCombo.find(_mapProvider)
                                if (index < 0) index = 0
                                mapCombo.currentIndex = index
                            }
                        }

                        QGCLabel { text: qsTr("Type"); Layout.fillWidth: true }
                        QGCComboBox {
                            id:                     mapTypeCombo
                            Layout.preferredWidth: _mapComboWidth
                            Layout.alignment:      Qt.AlignRight
                            model:                  QGroundControl.mapEngineManager.mapTypeList(_mapProvider)
                            onActivated: {
                                _mapType = textAt(index)
                                QGroundControl.settingsManager.flightMapSettings.mapType.value = textAt(index)
                            }
                            Component.onCompleted: {
                                var index = mapTypeCombo.find(_mapType)
                                if (index < 0) index = 0
                                mapTypeCombo.currentIndex = index
                            }
                        }

                        QGCLabel { text: qsTr("Elevation Provider"); Layout.fillWidth: true }
                        QGCComboBox {
                            id:                     elevationCombo
                            Layout.preferredWidth: _mapComboWidth
                            Layout.alignment:      Qt.AlignRight
                            model:                  QGroundControl.mapEngineManager.elevationProviderList
                            Component.onCompleted: {
                                var index = elevationCombo.find(QGroundControl.elevationProviderName)
                                if (index < 0) index = 0
                                elevationCombo.currentIndex = index
                            }
                        }
                    }
                }

                QGCLabel { text: qsTr("Offline Maps") }
                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    text:               qsTr("Download map tiles for use when offline")
                }

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredWidth:  Math.max(providerGrid.width, offlineColumn.implicitWidth) + (_margins * 2)
                    Layout.preferredHeight: offlineColumn.height + (_margins * 2)
                    color:                  qgcPal.windowShade

                    ColumnLayout {
                        id:                         offlineColumn
                        anchors.top:                parent.top
                        anchors.topMargin:          _margins
                        anchors.left:               parent.left
                        anchors.right:              parent.right
                        anchors.leftMargin:        _margins
                        anchors.rightMargin:       _margins
                        spacing:                    _margins

                        Repeater {
                            model: QGroundControl.mapEngineManager.tileSets
                            delegate: RowLayout {
                                Layout.fillWidth:   true
                                spacing:            _margins

                                QGCLabel {
                                    Layout.fillWidth:   true
                                    text:               object.name
                                    elide:              Text.ElideRight
                                }
                                QGCLabel {
                                    text: object.downloadStatus + (object.totalTileCount > 0 ? " (" + object.totalTileCount + " " + qsTr("tiles") + ")" : "")
                                }
                                Rectangle {
                                    Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.45
                                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.45
                                    radius:                 width / 2
                                    color:                  object.complete ? "#31f55b" : "#fc5656"
                                }
                                QGCButton {
                                    text:                   qsTr("Edit")
                                    Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 8
                                    enabled:                !object.deleting && !_mapTransferBusy
                                    onClicked:              openEdit(object)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            QGCLabel { text: qsTr("Add New Set"); Layout.fillWidth: true }
                            QGCButton {
                                text:                   qsTr("Add")
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 8
                                enabled:                !_mapTransferBusy
                                onClicked:              openAdd()
                            }
                        }
                        RowLayout {
                            Layout.fillWidth:   true
                            visible:            QGroundControl.corePlugin.options.showOfflineMapImport
                            QGCLabel { text: qsTr("Import Map Tiles"); Layout.fillWidth: true }
                            QGCButton {
                                text:                   qsTr("Import")
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 8
                                enabled:                !_mapTransferBusy
                                onClicked:              offlineEditor.openImport()
                            }
                        }
                        RowLayout {
                            Layout.fillWidth:   true
                            visible:            QGroundControl.corePlugin.options.showOfflineMapExport
                            QGCLabel { text: qsTr("Export Map Tiles"); Layout.fillWidth: true }
                            QGCButton {
                                text:                   qsTr("Export")
                                Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 8
                                enabled:                !_mapTransferBusy
                                onClicked:              openExport()
                            }
                        }
                    }
                }

                QGCLabel {
                    text:       qsTr("Tokens")
                    visible:    _showTokens
                }
                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    visible:            _showTokens
                    text:               qsTr("Allows access to additional providers")
                }

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredWidth:  tokenGrid.width + (_margins * 2)
                    Layout.preferredHeight: tokenGrid.height + (_margins * 2)
                    color:                  qgcPal.windowShade
                    visible:                _showTokens

                    GridLayout {
                        id:                         tokenGrid
                        anchors.top:                parent.top
                        anchors.topMargin:          _margins
                        anchors.horizontalCenter:   parent.horizontalCenter
                        columns:                    2
                        columnSpacing:              _margins
                        rowSpacing:                 _margins

                        QGCLabel { text: qsTr("Mapbox"); visible: _mapboxFact && _mapboxFact.visible }
                        FactTextField {
                            fact:                   _mapboxFact
                            visible:                _mapboxFact && _mapboxFact.visible
                            maximumLength:          256
                            Layout.preferredWidth:  _comboFieldWidth
                        }

                        QGCLabel { text: qsTr("Esri"); visible: _esriFact && _esriFact.visible }
                        FactTextField {
                            fact:                   _esriFact
                            visible:                _esriFact && _esriFact.visible
                            maximumLength:          256
                            Layout.preferredWidth:  _comboFieldWidth
                        }

                        QGCLabel { text: qsTr("VWorld"); visible: _vworldFact && _vworldFact.visible }
                        FactTextField {
                            fact:                   _vworldFact
                            visible:                _vworldFact && _vworldFact.visible
                            maximumLength:          256
                            Layout.preferredWidth:  _comboFieldWidth
                        }
                        QGCLabel {
                            Layout.columnSpan:      2
                            Layout.fillWidth:       true
                            color:                  qgcPal.warningText
                            font.bold:              true
                            text:                   qsTr("To enable VWorld maps, enter your access token.")
                            visible:                _showVworldTokenWarning
                        }
                    }
                }

                QGCLabel {
                    text:       qsTr("Mapbox Login")
                    visible:    _showMapboxLogin
                }

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredWidth:  mapboxLoginGrid.width + (_margins * 2)
                    Layout.preferredHeight: mapboxLoginGrid.height + (_margins * 2)
                    color:                  qgcPal.windowShade
                    visible:                _showMapboxLogin

                    GridLayout {
                        id:                         mapboxLoginGrid
                        anchors.top:                parent.top
                        anchors.topMargin:          _margins
                        anchors.horizontalCenter:   parent.horizontalCenter
                        columns:                    2
                        columnSpacing:              _margins
                        rowSpacing:                 _margins

                        QGCLabel { text: qsTr("Account"); visible: _mapboxAccountFact && _mapboxAccountFact.visible }
                        FactTextField {
                            fact:                   _mapboxAccountFact
                            visible:                _mapboxAccountFact && _mapboxAccountFact.visible
                            maximumLength:          256
                            Layout.preferredWidth:  _comboFieldWidth
                        }
                        QGCLabel { text: qsTr("Map Style"); visible: _mapboxStyleFact && _mapboxStyleFact.visible }
                        FactTextField {
                            fact:                   _mapboxStyleFact
                            visible:                _mapboxStyleFact && _mapboxStyleFact.visible
                            maximumLength:          256
                            Layout.preferredWidth:  _comboFieldWidth
                        }
                    }
                }

                QGCLabel {
                    text:       qsTr("Custom Map URL")
                    visible:    _showCustomUrl
                }
                QGCLabel {
                    Layout.fillWidth:   true
                    wrapMode:           Text.WordWrap
                    visible:            _showCustomUrl
                    text:               qsTr("URL with {x} {y} {z} or {zoom} substitutions")
                }

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredWidth:  customUrlGrid.width + (_margins * 2)
                    Layout.preferredHeight: customUrlGrid.height + (_margins * 2)
                    color:                  qgcPal.windowShade
                    visible:                _showCustomUrl

                    GridLayout {
                        id:                         customUrlGrid
                        anchors.top:                parent.top
                        anchors.topMargin:          _margins
                        anchors.horizontalCenter:   parent.horizontalCenter
                        columns:                    2
                        columnSpacing:              _margins
                        rowSpacing:                 _margins

                        QGCLabel { text: qsTr("Server URL") }
                        FactTextField {
                            fact:                   _customURLFact
                            visible:                _customURLFact && _customURLFact.visible
                            maximumLength:          256
                            Layout.preferredWidth:  _comboFieldWidth
                        }
                    }
                }

                QGCLabel { text: qsTr("Tile Cache") }

                Rectangle {
                    Layout.fillWidth:       true
                    Layout.preferredWidth:  cacheGrid.width + (_margins * 2)
                    Layout.preferredHeight: cacheGrid.height + (_margins * 2)
                    color:                  qgcPal.windowShade

                    GridLayout {
                        id:                         cacheGrid
                        anchors.top:                parent.top
                        anchors.topMargin:          _margins
                        anchors.horizontalCenter:   parent.horizontalCenter
                        columns:                    3
                        columnSpacing:              _margins
                        rowSpacing:                 _margins

                        QGCLabel { text: qsTr("Max disk cache") }
                        QGCTextField {
                            id:                     maxCacheSize
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 10
                            maximumLength:          6
                            inputMethodHints:       Qt.ImhDigitsOnly
                            validator:              IntValidator { bottom: 1; top: 262144 }
                            text:                   QGroundControl.mapEngineManager.maxDiskCache
                            onEditingFinished: {
                                var value = parseInt(text)
                                if (!isNaN(value) && value >= 1) {
                                    QGroundControl.mapEngineManager.maxDiskCache = value
                                }
                                text = QGroundControl.mapEngineManager.maxDiskCache
                            }
                        }
                        QGCLabel { text: qsTr("MB") }

                        QGCLabel { text: qsTr("Max memory cache") }
                        QGCTextField {
                            id:                     maxCacheMemSize
                            Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 10
                            maximumLength:          4
                            inputMethodHints:       Qt.ImhDigitsOnly
                            validator:              IntValidator { bottom: 1; top: 1024 }
                            text:                   QGroundControl.mapEngineManager.maxMemCache
                            onEditingFinished: {
                                var value = parseInt(text)
                                if (!isNaN(value) && value >= 1) {
                                    QGroundControl.mapEngineManager.maxMemCache = value
                                }
                                text = QGroundControl.mapEngineManager.maxMemCache
                            }
                        }
                        QGCLabel { text: qsTr("MB") }
                    }
                }
            }
        }
    }

    OfflineMap {
        id:                 offlineEditor
        anchors.fill:       parent
        hostedByMapsPage:   true
        enabled:            editorOpen
        opacity:            editorOpen ? 1 : 0
        z:                  editorOpen ? 1 : 0
        onReturned:         editorOpen = false
    }
}
