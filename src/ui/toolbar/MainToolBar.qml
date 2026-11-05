/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.12
import QtQuick.Controls 2.4
import QtQuick.Layouts  1.11
import QtQuick.Dialogs  1.3

import QGroundControl                       1.0
import QGroundControl.Controls              1.0
import QGroundControl.Palette               1.0
import QGroundControl.MultiVehicleManager   1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.Controllers           1.0

Rectangle {
    id:     _root
    color:  qgcPal.toolbarBackground

    property int currentToolbar: flyViewToolbar

    readonly property int flyViewToolbar:   0
    readonly property int planViewToolbar:  1
    readonly property int simpleToolbar:    2

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool   _communicationLost: _activeVehicle ? _activeVehicle.vehicleLinkManager.communicationLost : false
    property color  _mainStatusBGColor: qgcPal.brandingPurple

    // Fly view fit: when status + indicators + logo + link indicator are wider than the toolbar, every
    // item is scaled down by the same factor so all of them stay visible.
    // Below the minimum scale the indicators scroll and the logo hides (old behavior)
    readonly property real  _minFitScale:       0.75
    readonly property real  _toolsLeftMargin:   ScreenTools.defaultFontPixelWidth * ScreenTools.largeFontPointRatio * 1.5
    readonly property real  _linkMargin:        ScreenTools.defaultFontPixelHeight * 0.66
    readonly property real  _logoGap:           ScreenTools.defaultFontPixelHeight - _linkMargin    // logo to link indicator gap (unchanged)
    readonly property real  _logoMinGap:        ScreenTools.defaultFontPixelWidth                   // indicators to logo gap (unchanged)
    property var            _linkLoader:        rajantLinkIndicator.visible ? rajantLinkIndicator : arLinkIndicator
    property real           _linkWidth:         _linkLoader.item ? _linkLoader.item.width : 0
    property bool           _logoWanted:        currentToolbar !== planViewToolbar && !!_activeVehicle && !_communicationLost && brandingLogo._fullWidth > 0
    // Widths at scale 1: the scaled parts, and the fixed gaps that do not scale
    property real           _scaledPartsWidth:  viewButtonRow.width + _toolsLeftMargin + indicatorLoader.width +
                                                (_logoWanted ? brandingLogo._fullWidth + _logoGap : 0) + _linkWidth
    property real           _fixedPartsWidth:   _logoMinGap + _linkMargin
    property real           _fitScale:          (currentToolbar === flyViewToolbar && _scaledPartsWidth > 0 && (_scaledPartsWidth + _fixedPartsWidth) > width) ?
                                                    Math.max(_minFitScale, (width - _fixedPartsWidth) / _scaledPartsWidth) : 1

    function dropMessageIndicatorTool() {
        if (currentToolbar === flyViewToolbar) {
            indicatorLoader.item.dropMessageIndicatorTool();
        }
    }

    QGCPalette { id: qgcPal }

    /// Bottom single pixel divider
    Rectangle {
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        height:         1
        color:          "black"
        visible:        qgcPal.globalTheme === QGCPalette.Light
    }

    Rectangle {
        anchors.left:   viewButtonRow.left
        anchors.top:    viewButtonRow.top
        anchors.bottom: viewButtonRow.bottom
        width:          viewButtonRow.width * _fitScale
        visible:        currentToolbar === flyViewToolbar

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0;                                     color: _mainStatusBGColor }
            GradientStop { position: currentButton.x + currentButton.width; color: _mainStatusBGColor }
            GradientStop { position: 1;                                     color: _root.color }
        }
    }

    RowLayout {
        id:                     viewButtonRow
        anchors.bottomMargin:   1
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        spacing:                ScreenTools.defaultFontPixelWidth / 2
        transformOrigin:        Item.Left
        scale:                  _fitScale

        QGCToolBarButton {
            id:                     currentButton
            Layout.preferredHeight: viewButtonRow.height
            icon.source:            "/res/QGCLogoFull"
            logo:                   true
            onClicked:              mainWindow.showToolSelectDialog()
        }

        MainStatusIndicator {
            Layout.preferredHeight: viewButtonRow.height
            visible:                currentToolbar === flyViewToolbar
        }

        QGCButton {
            id:                 disconnectButton
            text:               qsTr("Disconnect")
            onClicked:          { if (_activeVehicle) _activeVehicle.closeVehicle() }  // guard: vehicle may be nulled by link-loss before click lands
            visible:            _activeVehicle && _communicationLost && currentToolbar === flyViewToolbar
        }
    }

    QGCFlickable {
        id:                     toolsFlickable
        // viewButtonRow is scaled from its left edge, so pull in by the width it no longer occupies
        anchors.leftMargin:     (_toolsLeftMargin * _fitScale) - (viewButtonRow.width * (1 - _fitScale))
        anchors.left:           viewButtonRow.right
        anchors.bottomMargin:   1
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        anchors.right:          parent.right
        contentWidth:           indicatorLoader.x + (indicatorLoader.width * _fitScale)
        flickableDirection:     Flickable.HorizontalFlick

        Loader {
            id:                 indicatorLoader
            anchors.left:       parent.left
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            transformOrigin:    Item.Left
            scale:              _fitScale
            source:             currentToolbar === flyViewToolbar ?
                                    "qrc:/toolbar/MainToolBarIndicators.qml" :
                                    (currentToolbar == planViewToolbar ? "qrc:/qml/PlanToolBarIndicators.qml" : "")
        }
    }

    //-------------------------------------------------------------------------
    //-- Branding Logo
    // Scaled with the rest of the toolbar (_fitScale). Hidden only when it still does not fit at the minimum scale.
    Image {
        id:                     brandingLogo
        anchors.rightMargin:    _linkMargin + ((_linkWidth + _logoGap) * _fitScale)
        anchors.right:          parent.right
        anchors.verticalCenter: parent.verticalCenter
        width:                  _fullWidth * _fitScale
        height:                 _fullHeight * _fitScale
        visible:                _logoWanted &&
                                (_root.width - anchors.rightMargin - width) >= (toolsFlickable.x + toolsFlickable.contentWidth + _logoMinGap - 1)
        fillMode:               Image.PreserveAspectFit
        source:                 _outdoorPalette ? _brandImageOutdoor : _brandImageIndoor
        mipmap:                 true

        // Full size = same as before: toolbar height minus the link indicator margins, image proportions kept
        property real   _fullHeight:            _root.height - (_linkMargin * 2)
        property real   _fullWidth:             implicitHeight > 0 ? _fullHeight * implicitWidth / implicitHeight : 0

        property bool   _outdoorPalette:        qgcPal.globalTheme === QGCPalette.Light
        property bool   _corePluginBranding:    QGroundControl.corePlugin.brandImageIndoor.length != 0
        property string _userBrandImageIndoor:  QGroundControl.settingsManager.brandImageSettings.userBrandImageIndoor.value
        property string _userBrandImageOutdoor: QGroundControl.settingsManager.brandImageSettings.userBrandImageOutdoor.value
        property bool   _userBrandingIndoor:    _userBrandImageIndoor.length != 0
        property bool   _userBrandingOutdoor:   _userBrandImageOutdoor.length != 0
        property string _brandImageIndoor:      brandImageIndoor()
        property string _brandImageOutdoor:     brandImageOutdoor()

        function brandImageIndoor() {
            if (_userBrandingIndoor) {
                return _userBrandImageIndoor
            } else {
                if (_userBrandingOutdoor) {
                    return _userBrandingOutdoor
                } else {
                    if (_corePluginBranding) {
                        return QGroundControl.corePlugin.brandImageIndoor
                    } else {
                        return _activeVehicle ? _activeVehicle.brandImageIndoor : ""
                    }
                }
            }
        }

        function brandImageOutdoor() {
            if (_userBrandingOutdoor) {
                return _userBrandingOutdoor
            } else {
                if (_userBrandingIndoor) {
                    return _userBrandingIndoor
                } else {
                    if (_corePluginBranding) {
                        return QGroundControl.corePlugin.brandImageOutdoor
                    } else {
                        return _activeVehicle ? _activeVehicle.brandImageOutdoor : ""
                    }
                }
            }
        }
    }

    //Add ARLink/M2 Indicator
    Loader {
        id:                 arLinkIndicator
        anchors.right:      parent.right
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        anchors.margins:    _linkMargin
        transformOrigin:    Item.Right
        scale:              _fitScale
        visible:            !QGroundControl.corePlugin.rajantManager
        source:             QGroundControl.corePlugin.m2Manager ? "qrc:/qml/M2LinkIndicator.qml" : "qrc:/toolbar/ARLinkIndicator.qml"
    }
    
    // Rajant BCAPI Link Indicator (shown when Rajant is connected, replaces ARLink/M2)
    Loader {
        id:                 rajantLinkIndicator
        anchors.right:      parent.right
        anchors.top:        parent.top
        anchors.bottom:     parent.bottom
        anchors.margins:    _linkMargin
        transformOrigin:    Item.Right
        scale:              _fitScale
        visible:            QGroundControl.corePlugin.rajantManager ? true : false
        source:             visible ? "qrc:/toolbar/RajantLinkIndicator.qml" : ""
    }

    // Small parameter download progress bar
    Rectangle {
        anchors.bottom: parent.bottom
        height:         _root.height * 0.05
        width:          _activeVehicle ? _activeVehicle.loadProgress * parent.width : 0
        color:          qgcPal.colorGreen
        visible:        !largeProgressBar.visible
    }

    // Large parameter download progress bar
    Rectangle {
        id:             largeProgressBar
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        height:         parent.height
        color:          qgcPal.window
        visible:        _showLargeProgress

        property bool _initialDownloadComplete: _activeVehicle ? _activeVehicle.initialConnectComplete : true
        property bool _userHide:                false
        property bool _showLargeProgress:       !_initialDownloadComplete && !_userHide && qgcPal.globalTheme === QGCPalette.Light

        Connections {
            target:                 QGroundControl.multiVehicleManager
            function onActiveVehicleChanged(activeVehicle) { largeProgressBar._userHide = false }
        }

        Rectangle {
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width:          _activeVehicle ? _activeVehicle.loadProgress * parent.width : 0
            color:          qgcPal.colorGreen
        }

        QGCLabel {
            anchors.centerIn:   parent
            text:               qsTr("Downloading")
            font.pointSize:     ScreenTools.largeFontPointSize
        }

        QGCLabel {
            anchors.margins:    _margin
            anchors.right:      parent.right
            anchors.bottom:     parent.bottom
            text:               qsTr("Click anywhere to hide")

            property real _margin: ScreenTools.defaultFontPixelWidth / 2
        }

        MouseArea {
            anchors.fill:   parent
            onClicked:      largeProgressBar._userHide = true
        }
    }
}
