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
import Qt.labs.settings 1.0

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
    visible:        true
    minimumWidth:   ScreenTools.isMobile ? Screen.width  : Math.min(ScreenTools.defaultFontPixelWidth * 100, Screen.width)
    minimumHeight:  ScreenTools.isMobile ? Screen.height : Math.min(ScreenTools.defaultFontPixelWidth * 50, Screen.height)
    property alias  viewOnlyMode: globals.viewOnlyMode
    readonly property bool droneControlBlocked: viewOnlyMode || loginOverlay.visible
    readonly property bool joystickInputBlocked: viewOnlyMode || loginOverlay.visible
    property double _lastAdminPrivilegesPopupMs: 0
    property var _loginPageComponent:    null
    property var _registerPageComponent: null
    property var _recoveryKeyPageComponent: null
    property var _forgotPinPageComponent: null
    property var _systemRestorePageComponent: null
    property var _controlBlockedDialog: null
    property bool controlBlockedDialogActive: false

    Component.onCompleted: {
        if (ScreenTools.isMobile || Screen.height / ScreenTools.realPixelDensity < 120) {
            mainWindow.showFullScreen()
        } else {
            width   = ScreenTools.isMobile ? Screen.width  : Math.min(250 * Screen.pixelDensity, Screen.width)
            height  = ScreenTools.isMobile ? Screen.height : Math.min(150 * Screen.pixelDensity, Screen.height)
        }
        _loginPageComponent    = Qt.createComponent("qrc:/login/LoginScreen.qml")
        _registerPageComponent = Qt.createComponent("qrc:/login/RegisterScreen.qml")
        _recoveryKeyPageComponent = Qt.createComponent("qrc:/login/RecoveryKeyScreen.qml")
        _forgotPinPageComponent = Qt.createComponent("qrc:/login/ForgotPinScreen.qml")
        _systemRestorePageComponent = Qt.createComponent("qrc:/login/SystemRestoreScreen.qml")
        loadInitialLoginUI()
        loginOverlay.open()
    }

    QtObject {
        id: firstRunPromptManager

        property var currentDialog:     null
        property var rgPromptIds:       []
        property int nextPromptIdIndex: 0
        property bool securePromptShown: false
        property int securePromptRetryCount: 0
        property bool promptFlowStarted: false

        function clearNextPromptSignal() {
            if (currentDialog) {
                currentDialog.closed.disconnect(nextPrompt)
            }
        }

        function startPromptFlow() {
            if (promptFlowStarted) {
                return
            }

            promptFlowStarted = true
            rgPromptIds = QGroundControl.corePlugin.firstRunPromptsToShow()
            nextPromptIdIndex = 0
            securePromptShown = false
            securePromptRetryCount = 0
            nextPrompt()
        }

        function nextPrompt() {
            if (nextPromptIdIndex < rgPromptIds.length) {
                var promptId = rgPromptIds[nextPromptIdIndex]
                var component = Qt.createComponent(QGroundControl.corePlugin.firstRunPromptResource(promptId));
                if (component.status !== Component.Ready) {
                    console.warn("Failed to load first run prompt:", promptId, component.errorString())
                    nextPromptIdIndex++
                    nextPrompt()
                    return
                }
                currentDialog = component.createObject(mainWindow)
                if (!currentDialog) {
                    console.warn("Failed to create first run prompt:", promptId)
                    nextPromptIdIndex++
                    nextPrompt()
                    return
                }
                if (promptId === QGroundControl.corePlugin.secureConnectionFirstRunPromptId) {
                    securePromptShown = true
                }
                currentDialog.closed.connect(nextPrompt)
                currentDialog.open()
                nextPromptIdIndex++
            } else {
                currentDialog = null
                if (!_showSecureConnectionPromptFallback()) {
                    showPreFlightChecklistIfNeeded()
                }
            }
        }
    }

    function _showSecureConnectionPromptFallback() {
        if (firstRunPromptManager.rgPromptIds.indexOf(QGroundControl.corePlugin.secureConnectionFirstRunPromptId) < 0) {
            return false
        }

        if (firstRunPromptManager.securePromptShown) {
            console.log("Secure prompt already shown in first-run chain")
            return false
        }

        var component = Qt.createComponent("qrc:/FirstRunPromptDialogs/SecureConnectionFirstRunPrompt.qml")
        if (component.status !== Component.Ready) {
            console.warn("Failed to load SecureConnectionFirstRunPrompt.qml:", component.errorString())
            if (firstRunPromptManager.securePromptRetryCount < 15) {
                firstRunPromptManager.securePromptRetryCount++
                securePromptRetryTimer.start()
                return true
            }
            return false
        }

        var dialog = component.createObject(mainWindow)
        if (!dialog) {
            console.warn("Failed to create SecureConnectionFirstRunPrompt.qml dialog object")
            if (firstRunPromptManager.securePromptRetryCount < 15) {
                firstRunPromptManager.securePromptRetryCount++
                securePromptRetryTimer.start()
                return true
            }
            return false
        }

        firstRunPromptManager.securePromptRetryCount = 0
        dialog.closed.connect(function() {
            showPreFlightChecklistIfNeeded()
        })
        dialog.open()
        return true
    }

    Timer {
        id: securePromptRetryTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (!_showSecureConnectionPromptFallback()) {
                showPreFlightChecklistIfNeeded()
            }
        }
    }

    property var                _rgPreventViewSwitch:       [ false ]

    readonly property real      _topBottomMargins:          ScreenTools.defaultFontPixelHeight * 0.5

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

        // Property to manage View-Only Mode
        property bool               viewOnlyMode:        false
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

    function _updateJoystickInputBlockedState() {
        if (joystickManager && joystickManager.activeJoystick) {
            joystickManager.activeJoystick.inputBlocked = joystickInputBlocked
        }
    }

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

    function viewSwitch(currentToolbar) {
        toolDrawer.visible      = false
        toolDrawer.toolSource   = ""
        flightView.visible      = false
        planView.visible        = false
        _geoZoneMakeView.visible = false
        toolbar.currentToolbar  = currentToolbar
    }

    function showFlyView() {
        if (!flightView.visible) {
            mainWindow.showPreFlightChecklistIfNeeded()
        }
        viewSwitch(toolbar.flyViewToolbar)
        flightView.visible = true
    }

    function showPlanView() {
        viewSwitch(toolbar.planViewToolbar)
        planView.visible = true
    }

    // show GeoZoneMakeView
    function showGeoZoneMakeView(){
        //viewSwitch(toolbar.planViewToolbar)
        _geoZoneMakeView.visible = true
    }

    function showTool(toolTitle, toolSource, toolIcon) {
        toolDrawer.backIcon     = flightView.visible ? "/qmlimages/PaperPlane.svg" : "/qmlimages/Plan.svg"
        toolDrawer.toolTitle    = toolTitle
        toolDrawer.toolSource   = toolSource
        toolDrawer.toolIcon     = toolIcon
        toolDrawer.visible      = true
    }

    function showAnalyzeTool() {
        showTool(qsTr("Analyze Tools"), "AnalyzeView.qml", "/qmlimages/Analyze.svg")
    }

    function showSetupTool() {
        showTool(qsTr("Vehicle Setup"), "SetupView.qml", "/qmlimages/Gears.svg")
    }

    function showSettingsTool() {
        showTool(qsTr("Application Settings"), "AppSettings.qml", "/res/QGCLogoWhite")
    }

    //-------------------------------------------------------------------------
    //-- Global simple message dialog

    function showMessageDialog(dialogTitle, dialogText, buttons = StandardButton.Ok, acceptFunction = null) {
        simpleMessageDialogComponent.createObject(mainWindow, { title: dialogTitle, text: dialogText, buttons: buttons, acceptFunction: acceptFunction }).open()
    }

    function showControlBlockedDialog() {
        if (controlBlockedDialogActive) {
            return
        }

        controlBlockedDialogActive = true
        _controlBlockedDialog = simpleMessageDialogComponent.createObject(mainWindow, {
            title: qsTr("Permission Required"),
            text: qsTr("Please switch to Admin mode to continue."),
            buttons: StandardButton.Yes | StandardButton.No,
            acceptFunction: function() { showLoginOverlay() }
        })

        if (_controlBlockedDialog) {
            _controlBlockedDialog.closed.connect(function() {
                controlBlockedDialogActive = false
                _controlBlockedDialog = null
            })
            _controlBlockedDialog.open()
        } else {
            controlBlockedDialogActive = false
        }
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

    function showAdminPrivilegesRequiredDialog() {
        showMessageDialog(
            qsTr("Permission Required"),
            qsTr("Please switch to Admin mode to continue."),
            StandardButton.Yes | StandardButton.No,
            function() {
                showLoginOverlay()
            }
        )
    }

    // This variant is only meant to be called by QGCApplication
    function _showMessageDialog(dialogTitle, dialogText) {
        showMessageDialog(dialogTitle, dialogText)
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
        firstRunPromptManager.clearNextPromptSignal()
        QGroundControl.linkManager.shutdown()
        QGroundControl.videoManager.stopVideo();
        mainWindow.close()
    }

    // -------------------------------------------------------------------------
    // Login functions

        Settings {
        id: loginFlowSettings
        category: "LoginFlow"
        property bool recoveryKeyPending: false
    }

    // Show login overlay 
    function showLoginOverlay() {
        if (loginFlowSettings.recoveryKeyPending) {
            loginOverlay.open()
        }
        else if (!loginOverlay.visible) {
            loadInitialLoginUI()
            loginOverlay.open()
        }
    }

    function loadInitialLoginUI() {
        loginStack.clear()
        if (securityManager.hasStoredPin()) {
            if (loginFlowSettings.recoveryKeyPending) {
                showRecoveryKeyUI()
            } else {
                var loginComp = loginStack.push(_loginPageComponent)
                setupLoginPageConnections(loginComp)
            }
        } else {
            var regComp = loginStack.push(_registerPageComponent)
            setupRegisterPageConnections(regComp)
        }
    }

    function setupRegisterPageConnections(registerComponent) {
        registerComponent.pinRegistered.connect(function() {
            loginFlowSettings.recoveryKeyPending = true
            showRecoveryKeyUI()
        })
    }

    function showRecoveryKeyUI() {
        var recoveryComp = loginStack.replace(_recoveryKeyPageComponent)
        recoveryComp.continueToLoginClicked.connect(function() {
            loginFlowSettings.recoveryKeyPending = false
            var loginComp = loginStack.replace(_loginPageComponent)
            setupLoginPageConnections(loginComp)
        })
    }

    function showForgotPinUI() {
        var forgotComp = loginStack.replace(_forgotPinPageComponent)
        forgotComp.backClicked.connect(function() {
            var loginCompBack = loginStack.replace(_loginPageComponent)
            setupLoginPageConnections(loginCompBack)
        })
        forgotComp.recoveryVerified.connect(function() {
            securityManager.clearStored()
            var regComp = loginStack.replace(_registerPageComponent)
            setupRegisterPageConnections(regComp)
        })
    }

    function showSystemRestoreUI() {
        var restoreComp = loginStack.replace(_systemRestorePageComponent)
        restoreComp.cancelClicked.connect(function() {
            var loginCompBack = loginStack.replace(_loginPageComponent)
            setupLoginPageConnections(loginCompBack)
        })
        restoreComp.confirmRestoreClicked.connect(function() {
            securityManager.clearStored()
            var regComp = loginStack.replace(_registerPageComponent)
            setupRegisterPageConnections(regComp)
        })
    }

    function showRegisterAfterFactoryReset() {
        loginFlowSettings.recoveryKeyPending = false
        sessionManager.sessionManagementEnabled = true
        firstRunPromptManager.promptFlowStarted = false
        firstRunPromptManager.securePromptShown = false
        firstRunPromptManager.securePromptRetryCount = 0
        firstRunPromptManager.clearNextPromptSignal()
        toolDrawer.visible = false
        toolDrawer.toolSource = ""
        hideIndicatorPopup()
        viewSwitch(toolbar.flyViewToolbar)
        flightView.visible = true
        loginStack.clear()
        var regComp = loginStack.push(_registerPageComponent)
        setupRegisterPageConnections(regComp)
        globals.viewOnlyMode = false
        loginOverlay.open()
    }

    function setupLoginPageConnections(loginComponent) {
        loginComponent.unlockClicked.connect(function() {
            sessionManager.startSession()
            globals.viewOnlyMode = false
            loginOverlay.close()
            Qt.callLater(function() {
                firstRunPromptManager.startPromptFlow()
            })
        })
        loginComponent.viewOnlyClicked.connect(function() {
            globals.viewOnlyMode = true
            loginOverlay.close()
        })
        if (loginComponent.forgotPINClicked !== undefined) {
            loginComponent.forgotPINClicked.connect(function() {
                showForgotPinUI()
            })
        }
        if (loginComponent.systemRestoreRequested !== undefined) {
            loginComponent.systemRestoreRequested.connect(function() {
                showSystemRestoreUI()
            })
        }
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

    //-------------------------------------------------------------------------
    /// Toolbar
    header: MainToolBar {
        id:         toolbar
        height:     ScreenTools.toolbarHeight
        visible:    !(QGroundControl.videoManager.fullScreen && flightView.visible)
    }

    footer: LogReplayStatusBar {
        visible: QGroundControl.settingsManager.flyViewSettings.showLogReplayStatusBar.rawValue
    }

    function showToolSelectDialog() {
        if (!mainWindow.preventViewSwitch()) {
            toolSelectDialogComponent.createObject(mainWindow).open()
        }
    }

    Component {
        id: toolSelectDialogComponent

        QGCPopupDialog {
            id:         toolSelectDialog
            title:      qsTr("Select Tool")
            buttons:    StandardButton.Close

            property real _toolButtonHeight:    ScreenTools.defaultFontPixelHeight * 3
            property real _margins:             ScreenTools.defaultFontPixelWidth

            ColumnLayout {
                width:  innerLayout.width + (toolSelectDialog._margins * 2)
                height: innerLayout.height + (toolSelectDialog._margins * 2)

                ColumnLayout {
                    id:             innerLayout
                    Layout.margins: toolSelectDialog._margins
                    spacing:        ScreenTools.defaultFontPixelWidth

                    SubMenuButton {
                        id:                 setupButton
                        height:             toolSelectDialog._toolButtonHeight
                        Layout.fillWidth:   true
                        text:               qsTr("Vehicle Setup")
                        imageColor:         qgcPal.text
                        imageResource:      "/qmlimages/Gears.svg"
                        onClicked: {
                            if (!mainWindow.preventViewSwitch()) {
                                toolSelectDialog.close()
                                mainWindow.showSetupTool()
                            }
                        }
                    }

                    SubMenuButton {
                        id:                 analyzeButton
                        height:             toolSelectDialog._toolButtonHeight
                        Layout.fillWidth:   true
                        text:               qsTr("Analyze Tools")
                        imageResource:      "/qmlimages/Analyze.svg"
                        imageColor:         qgcPal.text
                        visible:            QGroundControl.corePlugin.showAdvancedUI
                        onClicked: {
                            if (!mainWindow.preventViewSwitch()) {
                                toolSelectDialog.close()
                                mainWindow.showAnalyzeTool()
                            }
                        }
                    }

                    SubMenuButton {
                        id:                 settingsButton
                        height:             toolSelectDialog._toolButtonHeight
                        Layout.fillWidth:   true
                        text:               qsTr("Application Settings")
                        imageResource:      "/res/QGCLogoFull"
                        imageColor:         "transparent"
                        visible:            !QGroundControl.corePlugin.options.combineSettingsAndSetup
                        onClicked: {
                            if (!mainWindow.preventViewSwitch()) {
                                toolSelectDialog.close()
                                mainWindow.showSettingsTool()
                            }
                        }
                    }

                    SubMenuButton {
                        id:                 lockScreenButton
                        height:             toolSelectDialog._toolButtonHeight
                        Layout.fillWidth:   true
                        text:               qsTr("Lock Screen")
                        imageResource:      "/custom/img/png/session_lock.png"
                        imageColor:         "transparent"
                        enabled:            !(globals.activeVehicle && (globals.activeVehicle.armed || globals.activeVehicle.flying || globals.activeVehicle.landing))
                        opacity:                (globals.activeVehicle && (globals.activeVehicle.armed || globals.activeVehicle.flying || globals.activeVehicle.landing)) ? 0.65 : 1
                        onClicked: {
                            toolSelectDialog.close()
                            mainWindow.showLoginOverlay()
                        }
                    }

                    ColumnLayout {
                        width:                  innerLayout.width
                        spacing:                0
                        Layout.alignment:       Qt.AlignHCenter

                        QGCLabel {
                            id:                     versionLabel
                            text:                   qsTr("%1 Version").arg(QGroundControl.appName)
                            font.pointSize:         ScreenTools.smallFontPointSize
                            wrapMode:               QGCLabel.WordWrap
                            Layout.maximumWidth:    parent.width
                            Layout.alignment:       Qt.AlignHCenter
                        }

                        QGCLabel {
                            text:                   QGroundControl.qgcVersion
                            font.pointSize:         ScreenTools.smallFontPointSize
                            wrapMode:               QGCLabel.WrapAnywhere
                            Layout.maximumWidth:    parent.width
                            Layout.alignment:       Qt.AlignHCenter

                            QGCMouseArea {
                                id:                 easterEggMouseArea
                                anchors.topMargin:  -versionLabel.height
                                anchors.fill:       parent

                                onClicked: {
                                    if (ScreenTools.isMobile){
                                        if(!QGroundControl.corePlugin.showAdvancedUI) {
                                            advancedModeOnConfirmation.open()
                                        } else {
                                            advancedModeOffConfirmation.open()
                                        }
                                    }
                                    else {
                                        if (mouse.modifiers & Qt.ControlModifier) {
                                            QGroundControl.corePlugin.showTouchAreas = !QGroundControl.corePlugin.showTouchAreas
                                        } else if (mouse.modifiers & Qt.ShiftModifier) {
                                            if(!QGroundControl.corePlugin.showAdvancedUI) {
                                                advancedModeOnConfirmation.open()
                                            } else {
                                                QGroundControl.corePlugin.showAdvancedUI = false
                                            }
                                        }
                                    }
                                }
                                    // This allows you to change this on mobile
                                onPressAndHold: {
                                    QGroundControl.corePlugin.showTouchAreas = !QGroundControl.corePlugin.showTouchAreas
                                    showTouchAreasNotification.open()
                                }

                                MessageDialog {
                                    id:                 showTouchAreasNotification
                                    title:              qsTr("Debug Touch Areas")
                                    text:               qsTr("Touch Area display toggled")
                                    standardButtons:    StandardButton.Ok
                                }

                                MessageDialog {
                                    id:                 advancedModeOnConfirmation
                                    title:              qsTr("Advanced Mode")
                                    text:               QGroundControl.corePlugin.showAdvancedUIMessage
                                    standardButtons:    StandardButton.Yes | StandardButton.No
                                    onYes: {
                                        QGroundControl.corePlugin.showAdvancedUI = true
                                        advancedModeOnConfirmation.close()
                                    }
                                }

                                MessageDialog {
                                    id:                 advancedModeOffConfirmation
                                    title:              qsTr("Advanced Mode")
                                    text:               qsTr("Turn off Advanced Mode?")
                                    standardButtons:    StandardButton.Yes | StandardButton.No
                                    onYes: {
                                        QGroundControl.corePlugin.showAdvancedUI = false
                                        advancedModeOffConfirmation.close()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    FlyView {
        id:             flightView
        anchors.fill:   parent
    }

    PlanView {
        id:             planView
        anchors.fill:   parent
        visible:        false
    }

    FlightZoneManager {
            id: _flightzoneManager

            Component.onCompleted: {

            }
        }

    GeoZoneMakeView {
        id: _geoZoneMakeView
        anchors.fill: parent
        visible: false
    }

    Drawer {
        id:             toolDrawer
        width:          mainWindow.width
        height:         mainWindow.height
        edge:           Qt.LeftEdge
        dragMargin:     0
        closePolicy:    Drawer.NoAutoClose
        interactive:    false
        visible:        false

        property alias backIcon:    backIcon.source
        property alias toolTitle:   toolbarDrawerText.text
        property alias toolSource:  toolDrawerLoader.source
        property alias toolIcon:    toolIcon.source

        // Unload the loader only after closed, otherwise we will see a "blank" loader in the meantime
        onClosed: {
            toolDrawer.toolSource = ""
        }
        
        Rectangle {
            id:             toolDrawerToolbar
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    parent.top
            height:         ScreenTools.toolbarHeight
            color:          qgcPal.toolbarBackground

            RowLayout {
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                anchors.left:       parent.left
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                spacing:            ScreenTools.defaultFontPixelWidth

                QGCColoredImage {
                    id:                     backIcon
                    width:                  ScreenTools.defaultFontPixelHeight * 2
                    height:                 ScreenTools.defaultFontPixelHeight * 2
                    fillMode:               Image.PreserveAspectFit
                    mipmap:                 true
                    color:                  qgcPal.text
                }

                QGCLabel {
                    id:     backTextLabel
                    text:   qsTr("Back")
                }

                QGCLabel {
                    font.pointSize: ScreenTools.largeFontPointSize
                    text:           "<"
                }

                QGCColoredImage {
                    id:                     toolIcon
                    width:                  ScreenTools.defaultFontPixelHeight * 2
                    height:                 ScreenTools.defaultFontPixelHeight * 2
                    fillMode:               Image.PreserveAspectFit
                    mipmap:                 true
                    color:                  qgcPal.text
                }

                QGCLabel {
                    id:             toolbarDrawerText
                    font.pointSize: ScreenTools.largeFontPointSize
                }
            }

            QGCMouseArea {
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                x:                  parent.mapFromItem(backIcon, backIcon.x, backIcon.y).x
                width:              (backTextLabel.x + backTextLabel.width) - backIcon.x
                onClicked: {
                    toolDrawer.visible      = false
                }
            }
        }

        Loader {
            id:             toolDrawerLoader
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    toolDrawerToolbar.bottom
            anchors.bottom: parent.bottom

            Connections {
                target:                 toolDrawerLoader.item
                ignoreUnknownSignals:   true
                onPopout:               toolDrawer.visible = false
            }
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
                    toolbar.dropMessageIndicatorTool();
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

    // We have to create the popup windows for the Analyze pages here so that the creation context is rooted
    // to mainWindow. Otherwise if they are rooted to the AnalyzeView itself they will die when the analyze viewSwitch
    // closes.

    function createrWindowedAnalyzePage(title, source) {
        var windowedPage = windowedAnalyzePage.createObject(mainWindow)
        windowedPage.title = title
        windowedPage.source = source
    }

    Component {
        id: windowedAnalyzePage

        Window {
            width:      ScreenTools.defaultFontPixelWidth  * 100
            height:     ScreenTools.defaultFontPixelHeight * 40
            visible:    true

            property alias source: loader.source

            Rectangle {
                color:          QGroundControl.globalPalette.window
                anchors.fill:   parent

                Loader {
                    id:             loader
                    anchors.fill:   parent
                    onLoaded:       item.popped = true
                }
            }

            onClosing: {
                visible = false
                source = ""
            }
        }
    }

    // Login overlay
    Popup {
        id:          loginOverlay
        parent:      Overlay.overlay
        width:       mainWindow.width
        height:      mainWindow.height
        visible:     true
        modal:       true
        closePolicy: Popup.NoAutoClose
        padding:     0

        background: Rectangle {
            color:  "#222222"
            opacity: 0.95
        }

        contentItem: Item {
            anchors.fill: parent

            StackView {
                id: loginStack
                anchors.fill: parent   
            }
        }
    }

    Connections {
        target: sessionManager
        onSessionLocked: {
            if (globals.activeVehicle && (globals.activeVehicle.armed || globals.activeVehicle.flying || globals.activeVehicle.landing)) {
                sessionManager.startSession()
                return
            }
            showLoginOverlay()
        }
    }

    Connections {
        target: CustomQmlInterface
        function onFactoryResetCompleted() {
            showRegisterAfterFactoryReset()
        }
    }

    Connections {
        target: joystickManager
        function onActiveJoystickChanged() {
            _updateJoystickInputBlockedState()
        }
    }

    onJoystickInputBlockedChanged: _updateJoystickInputBlockedState()
}
