/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.11
import QtQuick.Controls 2.4
import QtQuick.Dialogs  1.3
import QtQuick.Layouts  1.11
import QtQuick.Window   2.11

import QGroundControl               1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.FlightDisplay 1.0
import QGroundControl.FlightMap     1.0
import QGroundControl.Controllers           1.0

/// @brief Native QML top level window
/// All properties defined here are visible to all QML pages.
ApplicationWindow {
    id:             mainWindow
    minimumWidth:   ScreenTools.isMobile ? Screen.width  : Math.min(ScreenTools.defaultFontPixelWidth * 100, Screen.width)
    minimumHeight:  ScreenTools.isMobile ? Screen.height : Math.min(ScreenTools.defaultFontPixelWidth * 50, Screen.height)
    visible:        true

    Component.onCompleted: {
        //-- Full screen on mobile or tiny screens
        if (ScreenTools.isMobile || Screen.height / ScreenTools.realPixelDensity < 120) {
            mainWindow.showFullScreen()
        } else {
            width   = ScreenTools.isMobile ? Screen.width  : Math.min(250 * Screen.pixelDensity, Screen.width)
            height  = ScreenTools.isMobile ? Screen.height : Math.min(150 * Screen.pixelDensity, Screen.height)
        }
        // The classic first-run prompts are not used: the Simple UI shows its own welcome (SimpleWelcome.qml)
    }

    property var                _rgPreventViewSwitch:       [ false ]


    readonly property real      _topBottomMargins:          ScreenTools.defaultFontPixelHeight * 0.5

    /// AQGC: the Simple UI is the only UI (2026-11-18: the classic toolbar, tool pages and tool drawer are removed).
    /// Kept as a constant because core fly / plan files still check it.
    readonly property bool      simpleUI:                   true
    // AQGC Simple UI: Layers › Flight zones (S30 / S15), saved as SimpleShowFlightZones
    property bool               simpleShowFlightZones:      QGroundControl.loadBoolGlobalSetting("SimpleShowFlightZones", true)
    readonly property var       flightZoneManager:          _flightzoneManager
    // YS LiDAR phase 2 watchers (#318 / #319): always loaded while a YellowScan manager exists, so Start / Stop
    // ACKs, alerts, the recorded track and the mission auto Start / Stop work with any screen open. The Simple
    // fly screen shows them (Figma S17, S51, S102, S103, S53). No UI of their own.
    readonly property var       lidarAcquisition:           lidarAcquisitionLoader.item
    readonly property var       lidarAlerts:                lidarAlertsLoader.item
    readonly property var       lidarTrack:                 lidarTrackLoader.item
    readonly property var       lidarMissionAuto:           lidarMissionAutoLoader.item
    Loader { id: lidarAcquisitionLoader; active: !!QGroundControl.corePlugin.ysManager; source: "qrc:/qml/LiDARAcquisition.qml" }
    Loader { id: lidarAlertsLoader;      active: !!QGroundControl.corePlugin.ysManager; source: "qrc:/qml/LiDARAlerts.qml" }
    Loader { id: lidarTrackLoader;       active: !!QGroundControl.corePlugin.ysManager; source: "qrc:/qml/LiDARTrackRecorder.qml" }
    Loader { id: lidarMissionAutoLoader; active: !!QGroundControl.corePlugin.ysManager; source: "qrc:/qml/LiDARMissionAuto.qml" }

    //-------------------------------------------------------------------------
    //-- Global Scope Variables

    QtObject {
        id: globals

        readonly property var       activeVehicle:                  QGroundControl.multiVehicleManager.activeVehicle
        readonly property real      defaultTextHeight:              ScreenTools.defaultFontPixelHeight
        readonly property real      defaultTextWidth:               ScreenTools.defaultFontPixelWidth
        readonly property var       planMasterControllerFlyView:    flightView.planController
        readonly property var       guidedControllerFlyView:        flightView.guidedController

        property var                planMasterControllerPlanView:   null
        property var                currentPlanMissionItem:         planMasterControllerPlanView ? planMasterControllerPlanView.missionController.currentPlanViewItem : null

        // Property to manage RemoteID quick acces to settings page
        property bool               commingFromRIDIndicator:        false

        // GeoFence 3D visuals (session only)
        property bool               geoFenceShow3D:                 false
        property int                geoFenceBreachStyle:            Qt.SolidLine
        property real               geoFenceFenceOpacity:           0.9
        property color              geoFenceBoundaryColor:          "#ffb300"
        property bool               geoFenceFillTopFace:            true
        property bool               geoFenceFillSideFaces:          false
        property bool               geoFenceHideOccludedEdges:      true
        property bool               geoFenceShowOccludedEdgesDashed:false
        property real               geoFenceExtrudeScale:           1.0
        property real               geoFenceMinExtrudeScale:        0.6
        property real               geoFenceMaxExtrudeScale:        1.6
        property bool               geoFenceShowMinMaxAltitude:     false
        property int                geoFenceCircleSegments:         40
        property bool               geoFenceShowOperational:        true
        property bool               geoFenceShowBuffer:             true
        property bool               geoFenceShowContingency:        true
    }

    /// Default color palette used throughout the UI
    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    //-------------------------------------------------------------------------
    //-- Actions

    signal armVehicleRequest
    signal forceArmVehicleRequest
    signal disarmVehicleRequest
    signal vtolTransitionToFwdFlightRequest
    signal vtolTransitionToMRFlightRequest
    signal showPreFlightChecklistIfNeeded

    //-------------------------------------------------------------------------
    //-- Global Scope Functions

    /// Prevent view switching
    function pushPreventViewSwitch() {
        _rgPreventViewSwitch.push(true)
    }

    /// Allow view switching
    function popPreventViewSwitch() {
        if (_rgPreventViewSwitch.length == 1) {
            console.warn("mainWindow.popPreventViewSwitch called when nothing pushed")
            return
        }
        _rgPreventViewSwitch.pop()
    }

    /// @return true: View switches are not currently allowed
    function preventViewSwitch() {
        return _rgPreventViewSwitch[_rgPreventViewSwitch.length - 1]
    }

    function viewSwitch() {
        flightView.visible      = false
        planView.visible        = false
    }

    function showFlyView() {
        if (!flightView.visible) {
            mainWindow.showPreFlightChecklistIfNeeded()
        }
        viewSwitch()
        flightView.visible = true
    }

    function showPlanView() {
        viewSwitch()
        planView.visible = true
    }

    function showPlanMissionUpload() {
        showPlanView()
        var plan = globals.planMasterControllerPlanView
        if (plan && plan.currentPlanFile !== "" && !plan.dirty) {
            plan.loadFromFile(plan.currentPlanFile)
        }
    }

    // Called by the APM plugin when setup is not complete (QGCApplication::showSetupView, after its app message).
    // The Simple UI does not jump away from the fly screen: Vehicle setup › Summary (Advanced mode) shows what is
    // missing, and the drone's own pre-arm checks still refuse to arm.
    function showSetupTool() {
    }
    // Mission reset notice (MissionResetBanner "Settings") → Vehicle setup › Mission (S97)
    function showSetupMission() {
        if (simpleUILoader.item) simpleUILoader.item.showVehicleSetup("mission")
    }

    //-------------------------------------------------------------------------
    //-- Global simple message dialog

    function showMessageDialog(dialogTitle, dialogText, buttons = StandardButton.Ok, acceptFunction = null) {
        simpleMessageDialogComponent.createObject(mainWindow, { title: dialogTitle, text: dialogText, buttons: buttons, acceptFunction: acceptFunction }).open()
    }

    // -- Custom Simple message dialog

    function showCustomMessageDialog(dialogComponent) {
       var dialogInstance = dialogComponent.createObject(mainWindow, {});
       if (dialogInstance) {
           dialogInstance.open();
       } else {
           console.log("Failed to create dialog.");
       }
   }

    // This variant is only meant to be called by QGCApplication
    function _showMessageDialog(dialogTitle, dialogText) {
        showMessageDialog(dialogTitle, dialogText)
    }

    // Called by QGCApplication::showRebootNotice: a value that needs a drone / app restart was changed.
    // The Simple UI shows a short toast (Figma S60 / S101 notes, 2026-11-19); false = show the classic message.
    function _showRebootNotice(vehicle, name) {
        return simpleUILoader.item ? simpleUILoader.item.showRestartNotice(vehicle, name) : false
    }

    Component {
        id: simpleMessageDialogComponent

        QGCSimpleMessageDialog {
        }
    }

    /// Saves main window position and size
    MainWindowSavedState {
        window: mainWindow
    }

    property bool _forceClose: false

    function finishCloseProcess() {
        _forceClose = true
        // For some reason on the Qml side Qt doesn't automatically disconnect a signal when an object is destroyed.
        // So we have to do it ourselves otherwise the signal flows through on app shutdown to an object which no longer exists.
        QGroundControl.linkManager.shutdown()
        QGroundControl.videoManager.stopVideo();
        mainWindow.close()
    }

    // On attempting an application close we check for:
    //  Unsaved missions - then
    //  Pending parameter writes - then
    //  Active connections

    property string closeDialogTitle: qsTr("Close %1").arg(QGroundControl.appName)

    function checkForUnsavedMission() {
        if (globals.planMasterControllerPlanView && globals.planMasterControllerPlanView.dirty) {
            showMessageDialog(closeDialogTitle,
                              qsTr("You have a mission edit in progress which has not been saved/sent. If you close you will lose changes. Are you sure you want to close?"),
                              StandardButton.Yes | StandardButton.No,
                              function() { checkForPendingParameterWrites() })
        } else {
            checkForPendingParameterWrites()
        }
    }

    function checkForPendingParameterWrites() {
        for (var index=0; index<QGroundControl.multiVehicleManager.vehicles.count; index++) {
            if (QGroundControl.multiVehicleManager.vehicles.get(index).parameterManager.pendingWrites) {
                mainWindow.showMessageDialog(closeDialogTitle,
                    qsTr("You have pending parameter updates to a vehicle. If you close you will lose changes. Are you sure you want to close?"),
                    StandardButton.Yes | StandardButton.No,
                    function() { checkForActiveConnections() })
                return
            }
        }
        checkForActiveConnections()
    }

    function checkForActiveConnections() {
        if (QGroundControl.multiVehicleManager.activeVehicle) {
            mainWindow.showMessageDialog(closeDialogTitle,
                qsTr("There are still active connections to vehicles. Are you sure you want to exit?"),
                StandardButton.Yes | StandardButton.No,
                function() { finishCloseProcess() })
        } else {
            finishCloseProcess()
        }
    }

    onClosing: {
        if (!_forceClose) {
            close.accepted = false
            checkForUnsavedMission()
        }
    }

    //-------------------------------------------------------------------------
    /// Main, full window background (Fly View)
    background: Item {
        id:             rootBackground
        anchors.fill:   parent
    }

    footer: LogReplayStatusBar {
        visible: QGroundControl.settingsManager.flyViewSettings.showLogReplayStatusBar.rawValue
    }

    MissionResetBanner {
        width:  0
        height: 0
    }

    FlyView {
        id:             flightView
        anchors.fill:   parent
        simpleMode:     true
    }

    PlanView {
        id:             planView
        anchors.fill:   parent
        visible:        false
        simpleMode:     true
    }

    //-------------------------------------------------------------------------
    /// AQGC Simple UI (custom/res/Simple): the screens above the fly / plan views
    Loader {
        id:             simpleUILoader
        anchors.fill:   parent
        z:              QGroundControl.zOrderTopMost
        active:         true
        source:         "qrc:/simple/SimpleRoot.qml"
    }

    FlightZoneManager {
            id: _flightzoneManager

            Component.onCompleted: {

            }
        }

    //-------------------------------------------------------------------------
    //-- Critical Vehicle Message Popup

    function showCriticalVehicleMessage(message) {
        indicatorPopup.close()
        if (criticalVehicleMessagePopup.visible || QGroundControl.videoManager.fullScreen) {
            // We received additional wanring message while an older warning message was still displayed.
            // When the user close the older one drop the message indicator tool so they can see the rest of them.
            criticalVehicleMessagePopup.dropMessageIndicatorOnClose = true
        } else {
            criticalVehicleMessagePopup.criticalVehicleMessage      = message
            criticalVehicleMessagePopup.dropMessageIndicatorOnClose = false
            criticalVehicleMessagePopup.open()
        }
    }

    function closeCriticalVehicleMessage(){
        if(criticalVehicleMessagePopup.visible){
            criticalVehicleMessagePopup.close();
        }
    }

    // YS LiDAR critical messages share the critical popup but are not kept in the vehicle message list,
    // so instead of being dropped they are queued while the popup is open or the video is fullscreen
    property var _lidarCriticalQueue: []

    function showLiDARCriticalMessage(message) {
        // Simple UI: red LiDAR banner on the fly screen (Figma S102), queued there
        if (simpleUILoader.item && simpleUILoader.item.showLidarCritical(message)) {
            return
        }
        if (criticalVehicleMessagePopup.visible || QGroundControl.videoManager.fullScreen) {
            if (_lidarCriticalQueue.indexOf(message) === -1) {
                _lidarCriticalQueue.push(message)
            }
        } else {
            showCriticalVehicleMessage(message)
        }
    }

    // indicatorPopup is left open: it may be the message list dropped by the popup just closed
    function _showNextLiDARCriticalMessage() {
        if (_lidarCriticalQueue.length === 0 || criticalVehicleMessagePopup.visible || QGroundControl.videoManager.fullScreen) {
            return
        }
        criticalVehicleMessagePopup.criticalVehicleMessage      = _lidarCriticalQueue.shift()
        criticalVehicleMessagePopup.dropMessageIndicatorOnClose = false
        criticalVehicleMessagePopup.open()
    }

    Connections {
        target:             QGroundControl.videoManager
        onFullScreenChanged: Qt.callLater(_showNextLiDARCriticalMessage)
    }

    Popup {
        id:                 criticalVehicleMessagePopup
        y:                  ScreenTools.defaultFontPixelHeight
        x:                  Math.round((mainWindow.width - width) * 0.5)
        width:              mainWindow.width  * 0.55
        height:             criticalVehicleMessageText.contentHeight + ScreenTools.defaultFontPixelHeight * 2
        modal:              false
        focus:              true
        closePolicy:        Popup.CloseOnEscape

        property alias  criticalVehicleMessage:        criticalVehicleMessageText.text
        property bool   dropMessageIndicatorOnClose:   false

        // After the click handler has dropped the message indicator, if it had to
        onClosed: Qt.callLater(_showNextLiDARCriticalMessage)

        background: Rectangle {
            anchors.fill:   parent
            color:          qgcPal.alertBackground
            radius:         ScreenTools.defaultFontPixelHeight * 0.5
            border.color:   qgcPal.alertBorder
            border.width:   2

            Rectangle {
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.top:                parent.top
                anchors.topMargin:          -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      vehicleWarningLabel.contentWidth + _margins
                height:                     vehicleWarningLabel.contentHeight + _margins

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 vehicleWarningLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Vehicle Error")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }

            Rectangle {
                id:                         additionalErrorsIndicator
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.bottom:             parent.bottom
                anchors.bottomMargin:       -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      additionalErrorsLabel.contentWidth + _margins
                height:                     additionalErrorsLabel.contentHeight + _margins
                visible:                    criticalVehicleMessagePopup.dropMessageIndicatorOnClose

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 additionalErrorsLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Additional errors received")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }
        }

        QGCLabel {
            id:                 criticalVehicleMessageText
            width:              criticalVehicleMessagePopup.width - ScreenTools.defaultFontPixelHeight
            anchors.centerIn:   parent
            wrapMode:           Text.WordWrap
            color:              qgcPal.alertText
            textFormat:         TextEdit.RichText
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                criticalVehicleMessagePopup.close()
                if (criticalVehicleMessagePopup.dropMessageIndicatorOnClose) {
                    criticalVehicleMessagePopup.dropMessageIndicatorOnClose = false;
                    QGroundControl.multiVehicleManager.activeVehicle.resetErrorLevelMessages();
                }
            }
        }
    }

    //------------------------------------------------------------------------
       //-- GeoAwareness Alert Popup
       property var _geoAwarenessAlertQueue: []
       property string _geoAwarenessAlertMessage: ""
       property var _geoAwarenessAlertIndex: []
       function showGeoAwarenessAlertMessage(message, index) {
           //console.log("Popup status show:", index);
           if(geoAwarenessMessagePopup.visible || QGroundControl.videoManager.fullScreen){
               console.log("showGeoAwarenessAlertMessage = ", message);
               addMessageToQueue(message, index);
               //console.log("_geoAwarenessAlertQueue length : ", _geoAwarenessAlertQueue.length );
           } else {
               //console.log("showGeoAwarenessAlertMessage else = ", message);
               _geoAwarenessAlertMessage = message
               _geoAwarenessAlertIndex.push(index); // Add index to queue
               geoAwarenessMessagePopup.open()
           }
       }
       function closeGeoAwarenessAlertMessage(index) {
           //console.log("Popup status close:", index);
           const indexPos = _geoAwarenessAlertIndex.indexOf(index);
           if (indexPos !== -1) {
               // Remove specific index and corresponding message
               //console.log("Closing popup for index:", index);
               _geoAwarenessAlertIndex.splice(indexPos, 1); // Remove index
               _geoAwarenessAlertQueue.splice(indexPos, 1); // Remove corresponding message
               if (_geoAwarenessAlertIndex.length === 0) {
                   // If no more messages, close popup
                   geoAwarenessMessagePopup.close();
               } else {
                   // Update displayed message
                   updateAlertMessage();
               }
           } else {
               //console.log("Index not found in queue:", index);
           }
       }
       // Queue update
       function addMessageToQueue(message, index) {
           // Check for duplicates
           if (_geoAwarenessAlertQueue.indexOf(message) === -1) {
               console.log("Adding message to queue:", message);
               _geoAwarenessAlertQueue.push(message);
               _geoAwarenessAlertIndex.push(index); // Add index to queue
               updateAlertMessage(); // Update the displayed message
           } else {
               console.log("Duplicate message ignored:", message);
           }
       }
       // Message update
       function updateAlertMessage() {
           _geoAwarenessAlertMessage = ""; // Init
           for (var i = 0; i < _geoAwarenessAlertQueue.length; i++) {
               var text = _geoAwarenessAlertQueue[i];
               if (i) _geoAwarenessAlertMessage += "<br>";
               _geoAwarenessAlertMessage += text;
           }
           geoAwarenessMessageText.text = _geoAwarenessAlertMessage;
       }
       Popup {
           id: geoAwarenessMessagePopup
           y: ScreenTools.defaultFontPixelHeight
           x: Math.round((mainWindow.width - width) * 0.5)
           width: mainWindow.width * 0.55
           height: ScreenTools.defaultFontPixelHeight * 6
           modal: false
           focus: true
           closePolicy: Popup.CloseOnEscape
           background: Rectangle {
               anchors.fill: parent
               color: "red"
               radius: ScreenTools.defaultFontPixelHeight * 0.5
               border.color: qgcPal.alertBorder
               border.width: 2
           }
           onOpened: {
               geoAwarenessMessageText.text = mainWindow._geoAwarenessAlertMessage
           }
           onClosed: {
               mainWindow._geoAwarenessAlertQueue = []
               mainWindow._geoAwarenessAlertMessage = ""
           }
           Flickable {
               id:                 geoAwarenessMessageFlick
               anchors.margins:    ScreenTools.defaultFontPixelHeight * 0.5
               anchors.fill:       parent
               contentHeight:      geoAwarenessMessageText.height
               contentWidth:       geoAwarenessMessageText.width
               boundsBehavior:     Flickable.StopAtBounds
               pixelAligned:       true
               clip:               true

               onContentHeightChanged: {
                   contentY = contentHeight - height;
               }
               TextEdit {
                   id:             geoAwarenessMessageText
                   width:          criticalVehicleMessagePopup.width - (ScreenTools.defaultFontPixelHeight * 2)
                   anchors.centerIn: parent
                   readOnly:       true
                   textFormat:     TextEdit.RichText
                   font.pointSize: ScreenTools.defaultFontPointSize
                   font.family:    ScreenTools.demiboldFontFamily
                   wrapMode:       TextEdit.WordWrap
                   color:          qgcPal.alertText

                   // 텍스트가 변경될 때 Flickable의 위치를 업데이트
                   onTextChanged: {
                       geoAwarenessMessageFlick.contentY = geoAwarenessMessageFlick.contentHeight - geoAwarenessMessageFlick.height;
                   }
               }
           }
           QGCColoredImage {
               id: geoAwarenessMessageClose
               anchors.margins: ScreenTools.defaultFontPixelHeight * 0.5
               anchors.top: parent.top
               anchors.right: parent.right
               width: ScreenTools.isMobile ? ScreenTools.defaultFontPixelHeight * 1.5 : ScreenTools.defaultFontPixelHeight
               height: width
               sourceSize.height: width
               source: "/res/XDelete.svg"
               fillMode: Image.PreserveAspectFit
               color: qgcPal.alertText
               MouseArea {
                   anchors.fill: parent
                   anchors.margins: -ScreenTools.defaultFontPixelHeight
                   onClicked: {
                       geoAwarenessMessagePopup.close()
                   }
               }
           }
           QGCColoredImage {
               anchors.margins: ScreenTools.defaultFontPixelHeight * 0.5
               anchors.bottom: parent.bottom
               anchors.right: parent.right
               width: ScreenTools.isMobile ? ScreenTools.defaultFontPixelHeight * 1.5 : ScreenTools.defaultFontPixelHeight
               height: width
               sourceSize.height: width
               source: "/res/ArrowDown.svg"
               fillMode: Image.PreserveAspectFit
               visible: geoAwarenessMessageText.lineCount > 5
               color: qgcPal.alertText
               MouseArea {
                   anchors.fill: parent
                   onClicked: {
                       geoAwarenessMessageFlick.flick(0,-500)
                   }
               }
           }
       }

    //-------------------------------------------------------------------------
    //-- Indicator Popups

    function showIndicatorPopup(item, dropItem, dim = true) {
        indicatorPopup.currentIndicator = dropItem
        indicatorPopup.currentItem = item
        indicatorPopup.dim = dim
        indicatorPopup.open()
    }

    function hideIndicatorPopup() {
        indicatorPopup.close()
        indicatorPopup.currentItem = null
        indicatorPopup.currentIndicator = null
    }

    Popup {
        id:             indicatorPopup
        padding:        ScreenTools.defaultFontPixelWidth * 0.75
        modal:          true
        focus:          true
        dim:            false
        closePolicy:    Popup.CloseOnEscape | Popup.CloseOnPressOutside
        property var    currentItem:        null
        property var    currentIndicator:   null
        background: Rectangle {
            width:  loader.width
            height: loader.height
            color:  Qt.rgba(0,0,0,0)
        }
        Loader {
            id:             loader
            onLoaded: {
                var centerX = mainWindow.contentItem.mapFromItem(indicatorPopup.currentItem, 0, 0).x - (loader.width * 0.5)
                if((centerX + indicatorPopup.width) > (mainWindow.width - ScreenTools.defaultFontPixelWidth)) {
                    centerX = mainWindow.width - indicatorPopup.width - ScreenTools.defaultFontPixelWidth
                }
                indicatorPopup.x = centerX
            }
        }
        onOpened: {
            loader.sourceComponent = indicatorPopup.currentIndicator
        }
        onClosed: {
            loader.sourceComponent = null
            indicatorPopup.currentIndicator = null
        }
    }

    Rectangle {
        id:         geoFenceWarningOverlay
        anchors.fill: parent
        color:      "#ffcc00"
        opacity:    0
        visible:    globals.activeVehicle && globals.activeVehicle.geoFenceAlertTier === 1
        z:          QGroundControl.zOrderTopMost

        SequentialAnimation on opacity {
            running:    geoFenceWarningOverlay.visible
            loops:      Animation.Infinite
            NumberAnimation { from: 0.0; to: 0.35; duration: 180; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.35; to: 0.0; duration: 180; easing.type: Easing.InOutQuad }
        }
    }

    Rectangle {
        id:         geoFenceBreachOverlay
        anchors.fill: parent
        color:      "#ff6a00"
        opacity:    0
        visible:    globals.activeVehicle && globals.activeVehicle.geoFenceAlertTier === 3
        z:          QGroundControl.zOrderTopMost

        SequentialAnimation on opacity {
            running:    geoFenceBreachOverlay.visible
            loops:      Animation.Infinite
            NumberAnimation { from: 0.0; to: 0.55; duration: 160; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.55; to: 0.0; duration: 160; easing.type: Easing.InOutQuad }
        }
    }

    Rectangle {
        id:         geoFenceContingencyOverlay
        anchors.fill: parent
        color:      "#ff2b2b"
        opacity:    0
        visible:    globals.activeVehicle && globals.activeVehicle.geoFenceAlertTier >= 4
        z:          QGroundControl.zOrderTopMost

        SequentialAnimation on opacity {
            running:    geoFenceContingencyOverlay.visible
            loops:      Animation.Infinite
            NumberAnimation { from: 0.0; to: 0.7; duration: 140; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.7; to: 0.0; duration: 140; easing.type: Easing.InOutQuad }
        }
    }
}
