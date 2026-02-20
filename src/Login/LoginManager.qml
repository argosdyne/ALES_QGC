import QtQuick 2.7
import QtQuick.Controls 2.0
import QtQuick.Layouts 1.1

ApplicationWindow {
    id: rootWindow
    visible: true
    width: 600
    height: 680
    title: qsTr("User Login App")

    // Main stackview
    StackView {
        id: stackView
        focus: true
        anchors.fill: parent
    }

    // Check if PIN exists and load appropriate page on startup
    Component.onCompleted: {
        if (securityManager.hasStoredPin()) {
            // PIN already registered, load Login page
            var loginComponent = stackView.push(Qt.resolvedUrl("qrc:/login/LogInPage.qml"))
            loginComponent.unlockClicked.connect(function() {
                // Create and show MainRootWindow, then close this login window
                var comp = Qt.createComponent(Qt.resolvedUrl("qrc:/qml/MainRootWindow.qml"))
                if (comp.status === Component.Ready) {
                    var mainWindow = comp.createObject(null, { viewOnlyMode: false, visible: true })
                    if (mainWindow) rootWindow.close()
                } else {
                    console.error("LoginManager: Failed to create MainRootWindow component")
                }
            })
            loginComponent.viewOnlyClicked.connect(function() {
                // Create and show MainRootWindow in view-only mode, then close this login window
                var comp = Qt.createComponent(Qt.resolvedUrl("qrc:/qml/MainRootWindow.qml"))
                if (comp.status === Component.Ready) {
                    var mainWindow = comp.createObject(null, { viewOnlyMode: true, visible: true })
                    if (mainWindow) rootWindow.close()
                } else {
                    console.error("LoginManager: Failed to create MainRootWindow component (view-only)")
                }
            })
        } else {
            // No PIN registered, load Registration page
            var registerComponent = stackView.push(Qt.resolvedUrl("qrc:/login/RegisterScreen.qml"))

            // Navigate to Login page after PIN is registered
            registerComponent.pinRegistered.connect(function() {
                var loginComponent = stackView.replace(Qt.resolvedUrl("qrc:/login/LogInPage.qml"))
                loginComponent.unlockClicked.connect(function() {
                    // Create and show MainRootWindow, then close this login window
                    var comp = Qt.createComponent(Qt.resolvedUrl("qrc:/qml/MainRootWindow.qml"))
                    if (comp.status === Component.Ready) {
                        var mainWindow = comp.createObject(null, { viewOnlyMode: false, visible: true })
                        if (mainWindow) rootWindow.close()
                    } else {
                        console.error("LoginManager: Failed to create MainRootWindow component")
                    }
                })
            })
        }
    }
}
