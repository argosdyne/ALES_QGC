
import QtQuick          2.11
import QtQuick.Controls 2.4
import QtQuick.Dialogs  1.3
import QtQuick.Layouts  1.11
import QtQuick.Window   2.11

import QGroundControl.ScreenTools   1.0

ApplicationWindow {
    id: rootWindow
    visible: true
    minimumWidth:   ScreenTools.isMobile ? Screen.width  : Math.min(ScreenTools.defaultFontPixelWidth * 100, Screen.width)
    minimumHeight:  ScreenTools.isMobile ? Screen.height : Math.min(ScreenTools.defaultFontPixelWidth * 50, Screen.height)
    title: qsTr("User Login App")
    width   : ScreenTools.isMobile ? Screen.width  : Math.min(250 * Screen.pixelDensity, Screen.width)
    height  : ScreenTools.isMobile ? Screen.height : Math.min(200 * Screen.pixelDensity, Screen.height)

    // Track MainWindow instance to close it when session locks
    property var mainWindowInstance: null

    // Main stackview
    StackView {
        id: stackView
        focus: true
        anchors.fill: parent
    }


    // Common function to load login or register page based on PIN existence
    function loadInitialLoginUI() {

        if (securityManager.hasStoredPin()) {
            var loginComponent = stackView.push(Qt.resolvedUrl("qrc:/login/LogInPage.qml"))
            setupLoginPageConnections(loginComponent)
        } else {
            var registerComponent = stackView.push(Qt.resolvedUrl("qrc:/login/RegisterScreen.qml"))
            registerComponent.pinRegistered.connect(function() {
                var loginComponent = stackView.replace(Qt.resolvedUrl("qrc:/login/LogInPage.qml"))
                setupLoginPageConnections(loginComponent)
            })
        }
    }

    // Setup connections for LoginPage
    function setupLoginPageConnections(loginComponent) {
        loginComponent.unlockClicked.connect(function() {
            sessionManager.startSession()
            if (rootWindow.mainWindowInstance) {
                rootWindow.mainWindowInstance.viewOnlyMode = false
                rootWindow.mainWindowInstance.show()
                rootWindow.mainWindowInstance.raise()
                rootWindow.mainWindowInstance.requestActivate()
                rootWindow.hide()
            } else {
                var comp = Qt.createComponent(Qt.resolvedUrl("qrc:/qml/MainRootWindow.qml"))
                if (comp.status === Component.Ready) {
                    var mainWindow = comp.createObject(null, { viewOnlyMode: false, visible: true })
                    if (mainWindow) {
                        rootWindow.mainWindowInstance = mainWindow
                        rootWindow.hide()
                    }
                }
            }
        })
        loginComponent.viewOnlyClicked.connect(function() {
            sessionManager.startSession()
            if (rootWindow.mainWindowInstance) {
                rootWindow.mainWindowInstance.viewOnlyMode = true
                rootWindow.mainWindowInstance.show()
                rootWindow.mainWindowInstance.raise()
                rootWindow.mainWindowInstance.requestActivate()
                rootWindow.hide()
            } else {
                var comp = Qt.createComponent(Qt.resolvedUrl("qrc:/qml/MainRootWindow.qml"))
                if (comp.status === Component.Ready) {
                    var mainWindow = comp.createObject(null, { viewOnlyMode: true, visible: true })
                    if (mainWindow) {
                        rootWindow.mainWindowInstance = mainWindow
                        rootWindow.hide()
                    }
                }
            }
        })
    }


    // Listen to session lock signal - show login again
    Connections {
        target: sessionManager
        onSessionLocked: {          
            if (rootWindow.mainWindowInstance) {
                console.log("[LoginManager] Session locked - hiding MainWindow and returning to Login")
                if (rootWindow.mainWindowInstance.lockForSessionTimeout) {
                    rootWindow.mainWindowInstance.lockForSessionTimeout()
                } else {
                    rootWindow.mainWindowInstance.hide()
                }
            }

            // Clear all old login data first
            stackView.clear()

            // Reload initial login UI
            rootWindow.loadInitialLoginUI()
            rootWindow.show()
        }
    }

    // Check if PIN exists and load appropriate page on startup
    Component.onCompleted : {
        rootWindow.loadInitialLoginUI()
    }
}
