/****************************************************************************
 * AQGC Simple UI — root. Loaded by MainRootWindow when Advanced mode is off.
 * Pages: fly (overlay on FlyView) · plan (overlay on PlanView) · settings (full screen)
 * Figma: AQGC-simpler (01 Screens, 02 Flows)
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

Item {
    id: simpleRoot

    property string page: "fly"
    readonly property var _custom: QGroundControl.corePlugin.settings

    Binding { target: SimpleTheme; property: "scale";     value: Math.min(simpleRoot.width / 1920, simpleRoot.height / 1080) }
    Binding { target: SimpleTheme; property: "textScale"; value: simpleRoot._custom.simpleLargeText.rawValue ? 1.2 : 1.0 }

    SimpleVehicleState { id: vs; vehicle: QGroundControl.multiVehicleManager.activeVehicle }

    //------------------------------------------------------------------ Navigation
    function showFly() {
        page = "fly"
        mainWindow.showFlyView()
    }
    function showPlan() {
        // Plan editing is locked while flying (state rules C) — the classic plan stays available in Advanced
        page = "plan"
        planWizard.start()
        mainWindow.showPlanView()
    }
    function showSettings(category) {
        page = "settings"
        settingsPage.category = category ? category : "general"
    }
    function openMenu() { menu.open() }

    // Advanced (admin PIN). purpose: advanced | setup | settings
    function requestAdvanced(purpose) { pin.open(purpose) }
    function _unlocked(purpose) {
        QGroundControl.corePlugin.showAdvancedUI = true
        mainWindow.showFlyView()
        if (purpose === "setup")         mainWindow.showSetupTool()
        else if (purpose === "settings") mainWindow.showSettingsTool()
    }

    // Layer rule 1: critical alerts bring the user back to the fly screen
    Connections {
        target: vs
        function onCriticalChanged() { if (vs.critical && simpleRoot.page !== "fly") simpleRoot.showFly() }
    }

    Component.onCompleted: {
        if (_custom.simpleStartScreen.rawValue === 1) showPlan()
        else showFly()
        // Developer aid (debug builds only): start an ArduCopter mock vehicle with --simple-mock
        if (Qt.application.arguments.indexOf("--simple-mock") !== -1 && typeof QGroundControl.startAPMArduCopterMockLink === "function") {
            QGroundControl.startAPMArduCopterMockLink(false)
        }
    }

    //------------------------------------------------------------------ Pages
    SimpleFlyOverlay {
        id: flyOverlay
        anchors.fill: parent
        visible: simpleRoot.page === "fly"
        vs: vs
    }
    SimplePlanWizard {
        id: planWizard
        anchors.fill: parent
        visible: simpleRoot.page === "plan"
        vs: vs
    }
    SimpleSettings {
        id: settingsPage
        anchors.fill: parent
        visible: simpleRoot.page === "settings"
        vs: vs
    }

    //------------------------------------------------------------------ Global layers
    SimpleMenuDrawer {
        id: menu
        anchors.fill: parent
        vs: vs
    }
    SimplePinDialog {
        id: pin
        anchors.fill: parent
        onAccepted: simpleRoot._unlocked(purpose)
    }

    // S57 first-start welcome (language & units) — shown once, replaces the classic first-run prompts
    Loader {
        anchors.fill: parent
        active: !QGroundControl.corePlugin.settings.simpleWelcomeShown.rawValue
        sourceComponent: Component { SimpleWelcome { } }
    }
}
