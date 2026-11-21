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
    function showVehicleSetup(category) { page = "setup"; vehicleSetupCategory = category ? category : "summary" }   // S58
    property string vehicleSetupCategory: "summary"
    function openMenu() { menu.open() }

    // A changed value needs a restart (MainRootWindow._showRebootNotice ← core Fact). Replaces the classic message
    // box (Figma S60 / S101 notes, 2026-11-19). vehicle: drone restart (name = parameter) / app restart (name = setting).
    // Returns true = handled (also when the screen shows its own restart notice).
    function showRestartNotice(vehicle, name) {
        if (SimpleTheme.quietRestart || SimpleTheme.ownRestartHints > 0) return true
        // the drone-restarted notice is showing: show it again after this one
        if (restartToast.visible && _rebootShown && restartToast.text === _rebootText) { _rebootShown = false; _rebootPending = true }
        restartToast.text = vehicle ? qsTr("%1 saved. Restart the drone to use the new value.").arg(name)
                                    : qsTr("“%1” changes after the app restarts.").arg(name)
        restartToast.visible = true
        restartToastTimer.restart()
        return true
    }

    // Link state messages from the core (link error, failed connect, primary link switched; QGCApplication::showLinkMessage):
    // a toast instead of the classic message box. The top-bar chip and the link-lost banner already show the state.
    function showLinkMessage(text) {
        flyOverlay.toast(text, "info")
        return true
    }

    // LiDAR critical / auto Start-Stop messages from the YellowScan watchers (MainRootWindow.showLiDARCriticalMessage):
    // red banner on the fly screen, queued (Figma S102). Returns true = handled.
    function showLidarCritical(message) {
        flyOverlay.pushLidarCritical(message)
        return true
    }

    // Advanced mode: no PIN (user 2026-11-16), kept over restarts (CustomPlugin.advancedMode). Figma S44 / 02 Flows E
    // (2026-11-17): Advanced mode keeps the Simple screens and adds the Advanced panel in the menu.
    // purpose: advanced (open the S44 panel) | setup | parameters | analyze | settings — all are Simple screens now
    // (step 8, 2026-11-18: the S44 "Classic alesQGC screens" item is removed; the classic code stays in the app).
    function requestAdvanced(purpose) {
        QGroundControl.corePlugin.advancedMode = true
        if (purpose === "advanced")        { menu.open(); menu.advancedOpen = true }
        else if (purpose === "setup")      showVehicleSetup()
        else if (purpose === "parameters") showParameters()
        else if (purpose === "analyze")    showAnalyze()
        else if (purpose === "settings")   showSettings("flyscreen")
    }

    // Drone restarted / mission cleared (bug #28564): the banner lives on the fly screen; on other pages a toast points
    // there, so the notice is not missed while planning or in Settings (code review 2026-11-21)
    // Shown once when the notice first appears (the monitor also signals "Clearing Mission" etc.); if another toast
    // is showing (e.g. "Restart the drone to use the new value") it follows when that one hides.
    readonly property string _rebootText: qsTr("The drone restarted — check the mission on the fly screen")
    property bool _rebootShown: false
    property bool _rebootPending: false
    // leaving the fly screen while the drone-restarted banner is still up also shows the notice
    onPageChanged: if (page !== "fly") _rebootToast()
    function _rebootToast() {
        _rebootPending = false
        var on = vs.present && !!vs.vehicle.missionResetMonitor && vs.vehicle.missionResetMonitor.rebootBannerVisible
        if (!on || _rebootShown || page === "fly") return
        if (restartToast.visible) { _rebootPending = true; return }
        _rebootShown = true
        restartToast.text = _rebootText
        restartToast.visible = true
        restartToastTimer.restart()
    }
    Connections {
        target: vs.present && vs.vehicle.missionResetMonitor ? vs.vehicle.missionResetMonitor : null
        ignoreUnknownSignals: true
        function onRebootStateChanged() {
            if (!vs.vehicle.missionResetMonitor.rebootBannerVisible) { simpleRoot._rebootShown = false; simpleRoot._rebootPending = false; return }
            simpleRoot._rebootToast()
        }
    }
    Connections {
        target: vs
        function onVehicleChanged() { simpleRoot._rebootShown = false; simpleRoot._rebootPending = false }
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
        // The classic pre-flight checklist popup is gone with the classic fly widgets (2026-11-18); S02 is the
        // checklist. A checklist switched on earlier would block take-off in GuidedActionsController: turn it off.
        var app = QGroundControl.settingsManager.appSettings
        if (app.useChecklist.rawValue) app.useChecklist.rawValue = false
        if (app.enforceChecklist.rawValue) app.enforceChecklist.rawValue = false
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
        active: simpleRoot.page === "setup"
        sourceComponent: Component { SimpleVehicleSetup { category: simpleRoot.vehicleSetupCategory } }
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

    // Restart toast (S36 toast style, on every page; Figma S60 / S101 notes, 2026-11-20). Fly screen: above the telemetry
    // bar, stacked over the fly S36 toast when that one is up; full-screen video: near the bottom edge; other pages: under
    // the header, where no page has buttons or editing hints. It takes no taps (closes on its timer).
    Rectangle {
        id: restartToast
        property string text: ""
        visible: false
        anchors.horizontalCenter: parent.horizontalCenter
        y: flyOverlay.visible ? parent.height - height - SimpleTheme.px(24 + 120 + 16 + 104 + 16) - (flyOverlay.toastShown ? height + SimpleTheme.px(12) : 0)
         : simpleRoot.page === "fly" ? parent.height - height - SimpleTheme.px(24)
         : SimpleTheme.px(104 + 16)
        width: Math.min(restartToastText.implicitWidth + SimpleTheme.px(56), parent.width - SimpleTheme.px(80))
        height: SimpleTheme.px(72); radius: height / 2
        color: SimpleTheme.withAlpha(SimpleTheme.surfaceRaised, 0.97)
        border.width: SimpleTheme.px(1); border.color: SimpleTheme.line
        SText { id: restartToastText; anchors.centerIn: parent; width: Math.min(implicitWidth, restartToast.width - SimpleTheme.px(56))
                elide: Text.ElideRight; text: restartToast.text; size: 26; medium: true }
        Timer { id: restartToastTimer; interval: 6000; onTriggered: restartToast.visible = false }
        onVisibleChanged: if (!visible && simpleRoot._rebootPending) simpleRoot._rebootToast()
    }

    // S57 first-start welcome (language & units) — shown once, replaces the classic first-run prompts
    Loader {
        anchors.fill: parent
        active: !QGroundControl.corePlugin.settings.simpleWelcomeShown.rawValue
        sourceComponent: Component { SimpleWelcome { } }
    }
}
