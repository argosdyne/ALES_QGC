/****************************************************************************
 * AQGC Simple UI — root. Loaded by MainRootWindow when Advanced mode is off.
 * Pages: fly (overlay on FlyView) · plan (overlay on PlanView) · settings (full screen)
 * Figma: AQGC-simpler (01 Screens, 02 Flows)
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import QGroundControl.Payload 1.0
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
    function showSaved() {          // S24 saved missions
        showPlan()
        planWizard.step = "saved"
    }
    function showSettings(category) {
        page = "settings"
        settingsPage.category = category ? category : "general"
    }
    // Advanced › Analyze tools (S61–S63)
    function showAnalyze() { page = "analyze" }
    function showParameters() { page = "params" }      // S60
    function openMenu() { menu.open() }

    // Advanced mode: no PIN (user 2026-11-16), kept over restarts (CustomPlugin.advancedMode). Figma S44 / 02 Flows E
    // (2026-11-17): Advanced mode keeps the Simple screens and adds the Advanced panel in the menu.
    // purpose: advanced (open the S44 panel) | setup | parameters | analyze | settings (classic pages for now)
    function requestAdvanced(purpose) {
        QGroundControl.corePlugin.advancedMode = true
        if (purpose === "advanced") { menu.open(); menu.advancedOpen = true; return }
        openClassic(purpose)
    }
    // Classic alesQGC screens (temporary, until each S58–S80 screen exists). Closing them returns here.
    function openClassic(what) {
        QGroundControl.corePlugin.advancedMode = true
        QGroundControl.corePlugin.showAdvancedUI = true      // this Simple root is unloaded now
        mainWindow.showFlyView()
        if (what === "setup")           mainWindow.showSetupTool()
        else if (what === "parameters") mainWindow.showSetupParameters()
        else if (what === "analyze")    mainWindow.showAnalyzeTool()
        else if (what === "settings")   mainWindow.showSettingsTool()
    }

    // Layer rule 1: critical alerts bring the user back to the fly screen
    Connections {
        target: vs
        function onCriticalChanged() {
            if (!vs.critical) return
            QGroundControl.videoManager.fullScreen = false     // never hide an alert behind full-screen video
            if (simpleRoot.page === "plan") planWizard.interrupted = true
            if (simpleRoot.page !== "fly") simpleRoot.showFly()
        }
    }

    Component.onCompleted: {
        // Settings › Payloads › gimbal speed is an app setting; the payload controllers keep it only in memory
        var gs = Number(_custom.simpleGimbalSpeed.rawValue)
        if (PayloadManager.gremsy)     PayloadManager.gremsy.speedDegPerSec = [35, 70, 105][gs]
        if (PayloadManager.nextvision) PayloadManager.nextvision.speedOffset = [200, 400, 500][gs]
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
        visible: simpleRoot.page === "fly" && !QGroundControl.videoManager.fullScreen   // S18: double-tap video = full screen
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
    // Advanced mode pages: created only while open (their controllers talk to the drone)
    Loader {
        anchors.fill: parent
        active: simpleRoot.page === "analyze"
        sourceComponent: Component { SimpleAnalyze { } }
    }
    Loader {
        anchors.fill: parent
        active: simpleRoot.page === "params"
        sourceComponent: Component { SimpleParameters { } }
    }

    //------------------------------------------------------------------ Global layers
    SimpleMenuDrawer {
        id: menu
        anchors.fill: parent
        vs: vs
    }

    // S57 first-start welcome (language & units) — shown once, replaces the classic first-run prompts
    Loader {
        anchors.fill: parent
        active: !QGroundControl.corePlugin.settings.simpleWelcomeShown.rawValue
        sourceComponent: Component { SimpleWelcome { } }
    }
}
