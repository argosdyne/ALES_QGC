/****************************************************************************
 * AQGC Simple UI — Vehicle setup (Advanced mode): S58 Summary (Figma 111:38761) and S59 Sensors (112:38882), 2026-11-17.
 * Frame like Settings (S09). S70–S77 and S68 Firmware are in SimpleSetup*.qml (no classic page is opened any more).
 * Sensors: S85 motor interference (CompassMot, live COMPASSMOT_STATUS) and S86 orientation sheets (2026-11-18).
 * While the drone is armed only Summary and Tuning can be opened (Tuning in flight: S76).
 * Sensors use the classic APMSensorsComponentController (created once the parameters are ready); the calibration
 * sheet gives it the items it drives (status log append(), progress value, Next / Cancel enabled, help text).
 * The FC does not store calibration dates: the app keeps the last date it saw a calibration succeed.
 ****************************************************************************/
import QtQuick 2.12
import QtQuick.Controls 2.4
import Qt.labs.settings 1.0
import QGroundControl 1.0
import QGroundControl.FactSystem 1.0
import QGroundControl.Controllers 1.0
import "."

Rectangle {
    id: vsp
    property string category: "summary"
    color: SimpleTheme.bgBase
    MouseArea { anchors.fill: parent }

    readonly property var  _veh:   QGroundControl.multiVehicleManager.activeVehicle
    readonly property bool _ready: !!_veh && _veh.parameterManager.parametersReady
    readonly property bool _armed: !!_veh && _veh.armed
    property bool calRunning: false      // no category change during a calibration

    // category → new screen or the classic page (component QML name)
    readonly property var cats: [
        { key: "summary",  icon: "info",     t: qsTr("Summary") },
        { key: "frame",    icon: "drone",    t: qsTr("Frame"),        classic: "APMAirframeComponent" },
        { key: "sensors",  icon: "gps",      t: qsTr("Sensors") },
        { key: "radio",    icon: "signal",   t: qsTr("Radio"),        classic: "RadioComponent" },
        { key: "modes",    icon: "sliders",  t: qsTr("Flight modes"), classic: "APMFlightModesComponent" },
        { key: "power",    icon: "battery",  t: qsTr("Power"),        classic: "APMPowerComponent" },
        { key: "motors",   icon: "power",    t: qsTr("Motors"),       classic: "APMMotorComponent" },
        { key: "safety",   icon: "home",     t: qsTr("Safety"),       classic: "APMSafetyComponent" },
        { key: "tuning",   icon: "undo",     t: qsTr("Tuning"),       classic: "APMTuningComponent" },
        { key: "gimbal",   icon: "gimbal",   t: qsTr("Gimbal"),       classic: "APMCameraComponent" },
        { key: "firmware", icon: "download", t: qsTr("Firmware"),     classic: "" }
    ]
    function catOf(key) { for (var i = 0; i < cats.length; i++) if (cats[i].key === key) return cats[i]; return cats[0] }
    // A motor test makes ArduPilot report "armed" while a motor spins: Motors is locked only when the drone flies.
    readonly property bool _flying: !!_veh && _veh.flying
    function locked(key) { return key === "motors" ? _flying : (_armed && key !== "summary" && key !== "tuning") }
    on_ArmedChanged:  if (locked(category) && !calRunning) category = "summary"
    on_FlyingChanged: if (locked(category) && !calRunning) category = "summary"

    // Header
    Rectangle {
        id: header
        width: parent.width; height: SimpleTheme.px(104)
        color: SimpleTheme.surfaceGlass
        Row {
            anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
            spacing: SimpleTheme.px(20)
            SButton { designHeight: 80; icon: "back"; text: qsTr("Back"); textSize: 26; enabled_: !vsp.calRunning; onClicked: simpleRoot.showFly() }
            SText { text: qsTr("Vehicle setup"); size: 34; bold: true; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // Categories
    Rectangle {
        id: catPanel
        anchors.top: header.bottom; anchors.bottom: parent.bottom
        width: SimpleTheme.px(520)
        color: SimpleTheme.surfaceGlass
        Column {
            anchors.fill: parent
            anchors.margins: SimpleTheme.px(20)
            spacing: SimpleTheme.px(4)
            Repeater {
                model: vsp.cats
                Rectangle {
                    width: parent.width; height: SimpleTheme.px(76); radius: SimpleTheme.px(16)
                    color: vsp.category === modelData.key ? SimpleTheme.brandGreen : "transparent"
                    opacity: vsp.locked(modelData.key) || (vsp.calRunning && vsp.category !== modelData.key) ? 0.4 : 1
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                        spacing: SimpleTheme.px(18)
                        SIcon { name: modelData.icon; size: 36; anchors.verticalCenter: parent.verticalCenter }
                        SText { text: modelData.t; size: 28; medium: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                    SIcon { visible: vsp.locked(modelData.key); name: "lock"; size: 30; anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(18); anchors.verticalCenter: parent.verticalCenter }
                    MouseArea { anchors.fill: parent; enabled: !vsp.locked(modelData.key) && !vsp.calRunning; onClicked: vsp.category = modelData.key }
                }
            }
        }
    }

    SText {
        visible: !vsp._ready && vsp.category !== "firmware"
        anchors.centerIn: parent
        text: !vsp._veh ? qsTr("Connect the drone to set it up.") : qsTr("Reading the parameters from the drone…")
        size: 30; color: SimpleTheme.textSecondary
    }

    // Content (needs the parameters)
    Loader {
        id: content
        active: vsp._ready || vsp.category === "firmware"      // firmware works without a drone link (USB bootloader)
        anchors.left: catPanel.right; anchors.leftMargin: SimpleTheme.px(60)
        anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(40)
        anchors.top: header.bottom; anchors.topMargin: SimpleTheme.px(40)
        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(24)
        sourceComponent: vsp.category === "summary" ? summaryComp : vsp.category === "sensors" ? sensorsComp
                       : vsp.category === "modes"   ? modesComp   : vsp.category === "safety" ? safetyComp
                       : vsp.category === "power"   ? powerComp   : vsp.category === "radio"  ? radioComp
                       : vsp.category === "gimbal"  ? gimbalComp  : vsp.category === "tuning" ? tuningComp
                       : vsp.category === "frame"   ? frameComp   : vsp.category === "motors" ? motorsComp
                       : firmwareComp
    }

    // shared: read parameters (FactPanelController), last calibration dates
    Settings {
        id: calDates
        category: "SimpleCalibration"
        property string compass: ""
        property string accel: ""
        property string level: ""
        property string baro: ""
    }

    //================================================================== S58 Summary
    Component {
        id: summaryComp
        Flickable {
            id: sm
            contentHeight: smCol.height
            clip: true
            FactPanelController { id: fpc }
            function p(name) { return fpc.parameterExists(-1, name) ? fpc.getParameterFact(-1, name, false) : null }
            function en(name) { var f = p(name); return f ? f.enumOrValueString : "—" }
            // classic setup state of a part: "done" | "needs" | "optional"
            function stateOf(qmlName) {
                var comps = vsp._veh && vsp._veh.autopilot ? vsp._veh.autopilot.vehicleComponents : []
                for (var i = 0; i < comps.length; i++) {
                    if (comps[i].setupSource.toString().indexOf(qmlName) !== -1)
                        return comps[i].requiresSetup ? (comps[i].setupComplete ? "done" : "needs") : "optional"
                }
                return "optional"
            }
            readonly property var batt: vsp._veh && vsp._veh.batteries.count > 0 ? vsp._veh.batteries.get(0) : null
            readonly property bool levelDone: { var x = p("AHRS_TRIM_X"), y = p("AHRS_TRIM_Y"); return !!x && !!y && (Number(x.rawValue) !== 0 || Number(y.rawValue) !== 0) }
            readonly property string fwText: vsp._veh ? vsp._veh.firmwareTypeString + " " + vsp._veh.firmwareMajorVersion + "." + vsp._veh.firmwareMinorVersion + "." + vsp._veh.firmwarePatchVersion : ""

            Column {
                id: smCol
                width: sm.width
                spacing: SimpleTheme.px(14)
                SText { text: qsTr("Summary"); size: 40; bold: true }
                SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                        text: qsTr("Check each part before the first flight. Orange items need setup. Setup is locked while the drone is flying.") }
                Grid {
                    columns: 2
                    columnSpacing: SimpleTheme.px(16); rowSpacing: SimpleTheme.px(14)
                    width: parent.width
                    Repeater {
                        model: [
                            { key: "frame",    st: sm.stateOf("APMAirframeComponent"),
                              s: sm.en("FRAME_CLASS") + " " + sm.en("FRAME_TYPE") + " · " + sm.fwText },
                            { key: "sensors",  st: sm.stateOf("APMSensorsComponent") === "done" && !sm.levelDone ? "needs" : sm.stateOf("APMSensorsComponent"),
                              s: sm.stateOf("APMSensorsComponent") === "done" ? (sm.levelDone ? qsTr("Compass, accelerometer and level done") : qsTr("Compass and accelerometer done · level not done"))
                                                                              : qsTr("Compass or accelerometer needs calibration") },
                            { key: "radio",    st: sm.stateOf("RadioComponent"),
                              s: sm.stateOf("RadioComponent") === "done" ? qsTr("Sticks calibrated") : qsTr("Calibrate the sticks") },
                            { key: "modes",    st: sm.stateOf("APMFlightModesComponent"),
                              s: qsTr("6 modes on channel %1 · %2 first").arg(sm.p("FLTMODE_CH") ? sm.p("FLTMODE_CH").rawValue : "—").arg(sm.en("FLTMODE1")) },
                            { key: "power",    st: sm.stateOf("APMPowerComponent"),
                              s: sm.en("BATT_MONITOR") + (sm.p("BATT_CAPACITY") ? " · " + sm.p("BATT_CAPACITY").rawValue + " mAh" : "")
                                 + (sm.batt ? " · " + sm.batt.voltage.valueString + " V " + qsTr("now") : "") },
                            { key: "motors",   st: "optional", s: qsTr("Test each motor after a repair") },
                            { key: "safety",   st: sm.stateOf("APMSafetyComponent"),
                              s: qsTr("Low battery: %1 · Link lost: %2").arg(sm.en("BATT_FS_LOW_ACT")).arg(sm.en("FS_GCS_ENABLE")) },
                            { key: "tuning",   st: "optional", s: qsTr("Factory tuning · changes allowed in flight") },
                            { key: "gimbal",   st: sm.p("MNT1_TYPE") && Number(sm.p("MNT1_TYPE").rawValue) !== 0 ? "done" : "optional",
                              s: sm.p("MNT1_TYPE") ? sm.en("MNT1_TYPE") : qsTr("No gimbal set") },
                            { key: "firmware", st: "pc", s: sm.fwText + " · " + qsTr("update from a PC with USB") }
                        ]
                        Rectangle {
                            width: (smCol.width - SimpleTheme.px(16)) / 2; height: SimpleTheme.px(116); radius: SimpleTheme.px(18)
                            color: SimpleTheme.surfaceRaised
                            opacity: vsp.locked(modelData.key) ? 0.5 : 1
                            Row {
                                x: SimpleTheme.px(24); y: SimpleTheme.px(18); spacing: SimpleTheme.px(14)
                                SIcon { name: vsp.catOf(modelData.key).icon; size: 34; anchors.verticalCenter: parent.verticalCenter }
                                SText { text: vsp.catOf(modelData.key).t; size: 28; medium: true; anchors.verticalCenter: parent.verticalCenter }
                            }
                            SStatusChip {
                                anchors.right: chev.left; anchors.rightMargin: SimpleTheme.px(12); y: SimpleTheme.px(16)
                                text: modelData.st === "done" ? qsTr("Done") : modelData.st === "needs" ? qsTr("Needs setup") : modelData.st === "pc" ? qsTr("PC only") : qsTr("Optional")
                                level: modelData.st === "done" ? "ok" : modelData.st === "needs" ? "warn" : "info"
                            }
                            SIcon { id: chev; name: vsp.locked(modelData.key) ? "lock" : "chevron"; size: 32; opacity: 0.7
                                    anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(18); y: SimpleTheme.px(20) }
                            SText { x: SimpleTheme.px(24); y: SimpleTheme.px(70); width: parent.width - SimpleTheme.px(48)
                                    text: modelData.s; size: 22; color: SimpleTheme.textSecondary; elide: Text.ElideRight }
                            MouseArea { anchors.fill: parent; enabled: !vsp.locked(modelData.key); onClicked: vsp.category = modelData.key }
                        }
                    }
                }
            }
        }
    }

    // S70–S77 (own files)
    Component { id: modesComp;  SimpleSetupModes  { } }
    Component { id: safetyComp; SimpleSetupSafety { } }
    Component { id: powerComp;  SimpleSetupPower  { onEscCalRequested: escCal.open() } }
    SimpleEscCal { id: escCal }      // S83: outlives the Power page while the drone is unplugged
    Component { id: radioComp;  SimpleSetupRadio  { } }
    Component { id: gimbalComp; SimpleSetupGimbal { } }
    Component { id: tuningComp; SimpleSetupTuning { } }
    Component { id: frameComp;  SimpleSetupFrame  { } }
    Component { id: motorsComp; SimpleSetupMotors { } }

    //================================================================== S68 Firmware
    Component { id: firmwareComp; SimpleSetupFirmware { } }

    //================================================================== S59 Sensors
    Component {
        id: sensorsComp
        Item {
            id: sn
            APMSensorsComponentController {
                id: ctl
                statusLog:                  statusLog
                progressBar:                progress
                nextButton:                 nextBtn
                cancelButton:               cancelBtn
                orientationCalAreaHelpText: helpText
                onResetStatusTextArea: statusLog.clear()
                // every stop re-enables the buttons first, then sets progress 1 (success) or 0: read it a moment later
                onSetAllCalButtonsEnabled: if (enabled && vsp.calRunning) Qt.callLater(sn.finished)
                // success (also the "success, show log" end of level / barometer, which keeps progress at 0)
                onCalibrationComplete: sn.okSeen = true
            }
            function p(name) { return ctl.parameterExists(-1, name) ? ctl.getParameterFact(-1, name, false) : null }
            property string running: ""       // "" | compass | accel | level | baro
            property string result: ""        // "" | ok | failed | cancelled
            property bool   cancelAsked: false
            property bool   okSeen: false
            readonly property bool levelDone: { var x = p("AHRS_TRIM_X"), y = p("AHRS_TRIM_Y"); return !!x && !!y && (Number(x.rawValue) !== 0 || Number(y.rawValue) !== 0) }
            readonly property bool motDone: { var m = p("COMPASS_MOTCT"); return !!m && Number(m.rawValue) !== 0 }
            readonly property int compassCount: { var n = 0; ["COMPASS_USE", "COMPASS_USE2", "COMPASS_USE3"].forEach(function(k) { var f = sn.p(k); if (f && Number(f.rawValue) !== 0) n++ }); return n }
            function today() { return Qt.formatDate(new Date(), "yyyy-MM-dd") }
            function start(kind) {
                result = ""; cancelAsked = false; okSeen = false; statusLog.clear(); progress.value = 0; running = kind; vsp.calRunning = true
                if (kind === "compass")    ctl.calibrateCompass()
                else if (kind === "accel") ctl.calibrateAccel(false)
                else if (kind === "level") ctl.levelHorizon()
                else if (kind === "baro")  ctl.calibratePressure()
            }
            function finished() {
                if (motSheet.phase === 1) { motSheet.phase = 2; vsp.calRunning = false; return }
                var ok = okSeen || progress.value >= 1
                result = ok ? "ok" : (cancelAsked ? "cancelled" : "failed")
                if (ok) {
                    if (running === "compass") calDates.compass = today()
                    else if (running === "accel") calDates.accel = today()
                    else if (running === "level") calDates.level = today()
                    else if (running === "baro") calDates.baro = today()
                }
                vsp.calRunning = false
            }

            readonly property var rows: [
                { key: "compass", icon: "gps",   t: qsTr("Compass"),
                  s: ctl.compassSetupNeeded ? qsTr("Not calibrated") : (calDates.compass !== "" ? qsTr("Done %1").arg(calDates.compass) : qsTr("Done · date unknown")) + " · " + qsTr("%n compass(es)", "", compassCount),
                  st: ctl.compassSetupNeeded ? "needs" : "done", btn: qsTr("Calibrate") },
                { key: "accel",   icon: "drone", t: qsTr("Accelerometer"),
                  s: ctl.accelSetupNeeded ? qsTr("Not calibrated") : (calDates.accel !== "" ? qsTr("Done %1").arg(calDates.accel) : qsTr("Done · date unknown")),
                  st: ctl.accelSetupNeeded ? "needs" : "done", btn: qsTr("Calibrate") },
                { key: "level",   icon: "gps",   t: qsTr("Level horizon"),
                  s: levelDone ? (calDates.level !== "" ? qsTr("Done %1").arg(calDates.level) : qsTr("Done · date unknown")) : qsTr("Not done · do it after the accelerometer, on a level surface"),
                  st: levelDone ? "done" : "needs", btn: qsTr("Start") },
                { key: "baro",    icon: "undo",  t: qsTr("Barometer"),
                  s: qsTr("Sets the altitude reading to 0 where the drone stands"), st: "optional", btn: qsTr("Start") },
                { key: "mot",     icon: "power", t: qsTr("Motor interference"),
                  s: qsTr("Measures compass error from the motors (CompassMot). Propellers on and flipped, drone tied down"), st: motDone ? "done" : "optional", btn: qsTr("Start"), sheet: "mot" },
                { key: "orient",  icon: "undo",  t: qsTr("Orientation"),
                  s: qsTr("Board: %1 · Compass 1: %2").arg(p("AHRS_ORIENTATION") ? p("AHRS_ORIENTATION").enumOrValueString : "—").arg(p("COMPASS_ORIENT") ? p("COMPASS_ORIENT").enumOrValueString : "—"),
                  st: "done", btn: qsTr("Change"), sheet: "orient" }
            ]

            Column {
                id: snCol
                width: parent.width - (sheet.visible ? sheet.width + SimpleTheme.px(20) : 0)
                spacing: SimpleTheme.px(12)
                SText { text: qsTr("Sensors"); size: 40; bold: true }
                SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                        text: qsTr("Calibrate on the ground with the motors off. Each step shows how to hold the drone.") }
                Repeater {
                    model: sn.rows
                    Rectangle {
                        width: snCol.width; height: Math.max(SimpleTheme.px(100), rText.height + SimpleTheme.px(28)); radius: SimpleTheme.px(18)
                        color: SimpleTheme.surfaceRaised
                        SIcon { id: rIcon; name: modelData.icon; size: 36; anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(24); anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            id: rText
                            anchors.left: rIcon.right; anchors.leftMargin: SimpleTheme.px(20)
                            anchors.right: rChip.left; anchors.rightMargin: SimpleTheme.px(16)
                            anchors.verticalCenter: parent.verticalCenter
                            SText { width: parent.width; text: modelData.t; size: 28; medium: true }
                            SText { width: parent.width; text: modelData.s; size: 22; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap }
                        }
                        SStatusChip { id: rChip; anchors.right: rBtn.left; anchors.rightMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                                      text: modelData.st === "done" ? qsTr("Done") : modelData.st === "needs" ? qsTr("Needs setup") : qsTr("Optional")
                                      level: modelData.st === "done" ? "ok" : modelData.st === "needs" ? "warn" : "info" }
                        SButton {
                            id: rBtn
                            objectName: "cal_" + modelData.key
                            anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                            designHeight: 72; textSize: 24
                            kind: modelData.st === "needs" ? "primary" : "secondary"
                            text: modelData.btn
                            enabled_: !vsp._armed && !vsp.calRunning
                            onClicked: modelData.sheet === "mot" ? motSheet.open() : modelData.sheet === "orient" ? orientSheet.open() : sn.start(modelData.key)
                        }
                    }
                }
            }

            //================================================================== S85 Motor interference (CompassMot)
            SSheet {
                id: motSheet
                title: qsTr("Motor interference")
                steps: 3; step: Math.min(2, phase)
                designWidth: 1000
                property int  phase: 0          // 0 prepare · 1 measuring · 2 result
                property var  checks: [false, false, false]
                readonly property bool allChecked: checks[0] && checks[1] && checks[2]
                readonly property bool noCurrent: { var m = sn.p("BATT_MONITOR"); return !m || [0, 3].indexOf(Number(m.rawValue)) >= 0 }
                property real lastInterference: -1
                subtitle: phase === 0 ? qsTr("Step 1 of 3 · Prepare the drone. The motors will spin.")
                        : phase === 1 ? qsTr("Step 2 of 3 · Raise the throttle slowly to 75 %, hold 5 seconds, then lower it to zero.")
                        : qsTr("Step 3 of 3 · Result. The correction is saved on the drone.")
                onAboutToShow: { phase = 0; checks = [false, false, false]; lastInterference = -1 }
                Connections { target: ctl; function onCompassMotStatusChanged() { if (ctl.compassMotInterference >= 0) motSheet.lastInterference = ctl.compassMotInterference } }

                Repeater {
                    model: motSheet.phase === 0 ? [qsTr("Propellers on, flipped and moved one place round the frame: the drone pushes into the ground"),
                                                   qsTr("Drone tied down so it cannot move"),
                                                   qsTr("Controller on, throttle at zero")] : []
                    Item {
                        width: motSheet.innerWidth; height: Math.max(SimpleTheme.px(64), ct.height + SimpleTheme.px(16))
                        Rectangle { id: cb; width: SimpleTheme.px(40); height: width; radius: SimpleTheme.px(8); anchors.verticalCenter: parent.verticalCenter
                                    color: motSheet.checks[index] ? SimpleTheme.brandGreen : "transparent"
                                    border.width: SimpleTheme.px(3); border.color: motSheet.checks[index] ? SimpleTheme.brandGreen : SimpleTheme.textSecondary
                                    SIcon { anchors.centerIn: parent; name: "check"; size: 30; visible: !!motSheet.checks[index] } }
                        SText { id: ct; anchors.left: cb.right; anchors.leftMargin: SimpleTheme.px(20); anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                text: modelData; size: 26; wrapMode: Text.WordWrap }
                        MouseArea { anchors.fill: parent; objectName: "motCheck_" + index
                                    onClicked: { var c = motSheet.checks.slice(); c[index] = !c[index]; motSheet.checks = c } }
                    }
                }
                SNotice { visible: motSheet.phase === 0 && motSheet.noCurrent; level: "warn"
                          text: qsTr("No current sensor: the result follows the throttle only and is less exact.") }
                Rectangle {
                    visible: motSheet.phase >= 1
                    width: motSheet.innerWidth; height: motCol.height + SimpleTheme.px(40); radius: SimpleTheme.px(20)
                    color: SimpleTheme.surfaceControl
                    Column {
                        id: motCol
                        x: SimpleTheme.px(24); y: SimpleTheme.px(20); width: parent.width - SimpleTheme.px(48)
                        spacing: SimpleTheme.px(14)
                        Repeater {
                            model: [
                                { t: qsTr("Throttle"), v: ctl.compassMotThrottle, u: "%", max: 100, show: motSheet.phase === 1, intf: false },
                                { t: qsTr("Current"), v: ctl.compassMotCurrent, u: "A", max: 40, show: motSheet.phase === 1, intf: false },
                                { t: qsTr("Interference · compass 1"), v: motSheet.phase === 2 ? motSheet.lastInterference : ctl.compassMotInterference, u: "%", max: 100, show: true, intf: true }
                            ]
                            Item {
                                visible: modelData.show
                                width: motCol.width; height: SimpleTheme.px(48)
                                readonly property real val: modelData.v
                                SText { width: SimpleTheme.px(330); anchors.verticalCenter: parent.verticalCenter; text: modelData.t; size: 24 }
                                Item {
                                    x: SimpleTheme.px(340); width: parent.width - SimpleTheme.px(500); height: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                                    Rectangle { anchors.fill: parent; radius: height / 2; color: SimpleTheme.surfaceRaised }
                                    Rectangle { visible: parent.parent.val >= 0; height: parent.height; radius: height / 2
                                                width: parent.width * Math.max(0.01, Math.min(1, parent.parent.val / modelData.max))
                                                color: !modelData.intf ? SimpleTheme.brandGreen : parent.parent.val > 60 ? SimpleTheme.danger : parent.parent.val > 30 ? SimpleTheme.warn : SimpleTheme.ok }
                                }
                                SText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; size: 26; bold: true
                                        text: parent.val >= 0 ? (modelData.u === "A" ? parent.val.toFixed(1) : Math.round(parent.val)) + " " + modelData.u : "—" }
                            }
                        }
                    }
                }
                SText { visible: motSheet.phase >= 1; width: motSheet.innerWidth; size: 22; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap
                        text: qsTr("Under 30 % is good. 30–60 % is acceptable. Over 60 %: move the compass or the GPS mast away from power wires.") }
                SNotice { visible: motSheet.phase === 2 && motSheet.lastInterference < 0; level: "warn"
                          text: qsTr("The drone sent no measurement. Raise the throttle higher next time and keep it there for 5 seconds.") }
                SNotice { visible: motSheet.phase <= 1; level: "danger"
                          text: qsTr("Propellers are on and flipped: the drone pushes into the ground. Keep it tied down and stand back.") }
                Row {
                    spacing: SimpleTheme.px(12)
                    SButton { objectName: "motCancel"; visible: motSheet.phase !== 1; width: (motSheet.innerWidth - parent.spacing) / 2; designHeight: 72; textSize: 26
                              text: motSheet.phase === 2 ? qsTr("Close") : qsTr("Cancel"); onClicked: motSheet.close() }
                    SButton { objectName: "motStop"; visible: motSheet.phase === 1; width: (motSheet.innerWidth - parent.spacing) / 2; designHeight: 72; textSize: 26
                              kind: "danger"; text: qsTr("Stop and save"); onClicked: ctl.nextClicked() }
                    SButton {
                        objectName: "motStart"
                        width: (motSheet.innerWidth - parent.spacing) / 2; designHeight: 72; textSize: 26
                        kind: motSheet.phase === 1 ? "secondary" : "primary"
                        enabled_: motSheet.phase === 0 ? motSheet.allChecked && !vsp._armed && !vsp.calRunning : motSheet.phase === 2
                        text: motSheet.phase === 0 ? qsTr("Start") : motSheet.phase === 1 ? qsTr("Measuring…") : qsTr("Done")
                        onClicked: {
                            if (motSheet.phase === 0) { sn.okSeen = false; sn.cancelAsked = false; motSheet.phase = 1; vsp.calRunning = true; ctl.calibrateMotorInterference() }
                            else motSheet.close()
                        }
                    }
                }
            }

            //================================================================== S86 Orientation
            SSheet {
                id: orientSheet
                title: qsTr("Orientation")
                subtitle: qsTr("Only change this when the flight controller or a compass is mounted turned. The arrow on the board points to the front.")
                designWidth: 900
                closeOnOutside: true
                property bool changed: false
                onAboutToShow: changed = false
                Repeater {
                    model: [
                        { t: qsTr("Flight controller"), p: "AHRS_ORIENTATION", use: "", ext: "" },
                        { t: qsTr("Compass 1"), p: "COMPASS_ORIENT",  use: "COMPASS_USE",  ext: "COMPASS_EXTERNAL" },
                        { t: qsTr("Compass 2"), p: "COMPASS_ORIENT2", use: "COMPASS_USE2", ext: "COMPASS_EXTERN2" },
                        { t: qsTr("Compass 3"), p: "COMPASS_ORIENT3", use: "COMPASS_USE3", ext: "COMPASS_EXTERN3" }
                    ]
                    Column {
                        id: oc
                        readonly property var f: sn.p(modelData.p)
                        readonly property var ext: modelData.ext !== "" ? sn.p(modelData.ext) : null
                        readonly property bool internal: !!ext && Number(ext.rawValue) === 0
                        readonly property bool used: modelData.use !== "" && !!sn.p(modelData.use) && Number(sn.p(modelData.use).rawValue) !== 0
                        visible: !!f
                        width: orientSheet.innerWidth; spacing: SimpleTheme.px(8)
                        Row {
                            spacing: SimpleTheme.px(12)
                            SText { anchors.verticalCenter: parent.verticalCenter; size: 26; medium: true
                                    text: modelData.t + (oc.ext ? " · " + (oc.internal ? qsTr("internal") : qsTr("external")) : "") }
                            SStatusChip { visible: oc.used; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Used"); level: "ok" }
                        }
                        SFactField { fact: oc.f; designWidth: 820; enabled_: !vsp._armed && !oc.internal; opacity: oc.internal ? 0.4 : 1 }
                        Connections { target: oc.f; ignoreUnknownSignals: true; function onRawValueChanged() { if (orientSheet.visible) orientSheet.changed = true } }
                        SText { visible: oc.internal; size: 20; color: SimpleTheme.textSecondary; text: qsTr("Internal compasses follow the flight controller.") }
                    }
                }
                SNotice { level: "info"; text: qsTr("After a change, restart the drone and calibrate the compass and the accelerometer again (Sensors).") }
                Row {
                    spacing: SimpleTheme.px(12)
                    SButton { width: (orientSheet.innerWidth - parent.spacing) / 2; designHeight: 72; textSize: 26; text: qsTr("Close"); onClicked: orientSheet.close() }
                    SButton { objectName: "orientRestart"; width: (orientSheet.innerWidth - parent.spacing) / 2; designHeight: 72; textSize: 26; kind: "primary"
                              enabled_: orientSheet.changed && !vsp._armed; text: qsTr("Restart the drone")
                              onClicked: { vsp._veh.rebootVehicle(); orientSheet.close() } }
                }
            }

            // ---------------- calibration sheet (right)
            SPanel {
                id: sheet
                visible: sn.running !== ""
                closable: false
                anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
                width: SimpleTheme.px(560)
                Column {
                    x: SimpleTheme.px(28); y: SimpleTheme.px(28); width: parent.width - SimpleTheme.px(56)
                    spacing: SimpleTheme.px(14)
                    SText { text: sn.running === "compass" ? qsTr("Compass") : sn.running === "accel" ? qsTr("Accelerometer")
                                : sn.running === "level" ? qsTr("Level horizon") : qsTr("Barometer"); size: 32; bold: true }
                    SText { width: parent.width; wrapMode: Text.WordWrap; size: 24
                            text: sn.running === "compass" ? qsTr("Hold the drone away from metal and turn it slowly around every axis until the bar is full.")
                                : sn.running === "accel" ? qsTr("Hold the drone still in the position shown, then press Next. Six positions in total.")
                                : sn.running === "level" ? qsTr("Place the drone on a level surface and do not touch it.")
                                : qsTr("Keep the drone still.") }
                    // accelerometer positions (classic pictures)
                    Grid {
                        visible: sn.running === "accel"
                        columns: 3; spacing: SimpleTheme.px(10)
                        Repeater {
                            model: [
                                { img: "VehicleDown",       t: qsTr("Level"),        done: ctl.orientationCalDownSideDone,       now: ctl.orientationCalDownSideInProgress },
                                { img: "VehicleLeft",       t: qsTr("Left side"),    done: ctl.orientationCalLeftSideDone,       now: ctl.orientationCalLeftSideInProgress },
                                { img: "VehicleRight",      t: qsTr("Right side"),   done: ctl.orientationCalRightSideDone,      now: ctl.orientationCalRightSideInProgress },
                                { img: "VehicleNoseDown",   t: qsTr("Nose down"),    done: ctl.orientationCalNoseDownSideDone,   now: ctl.orientationCalNoseDownSideInProgress },
                                { img: "VehicleTailDown",   t: qsTr("Nose up"),      done: ctl.orientationCalTailDownSideDone,   now: ctl.orientationCalTailDownSideInProgress },
                                { img: "VehicleUpsideDown", t: qsTr("Upside down"),  done: ctl.orientationCalUpsideDownSideDone, now: ctl.orientationCalUpsideDownSideInProgress }
                            ]
                            Rectangle {
                                width: SimpleTheme.px(156); height: SimpleTheme.px(150); radius: SimpleTheme.px(14)
                                color: modelData.now ? SimpleTheme.withAlpha(SimpleTheme.warn, 0.25) : modelData.done ? SimpleTheme.withAlpha(SimpleTheme.ok, 0.2) : SimpleTheme.surfaceRaised
                                border.width: modelData.now ? SimpleTheme.px(3) : 0; border.color: SimpleTheme.warn
                                Image { anchors.horizontalCenter: parent.horizontalCenter; y: SimpleTheme.px(8)
                                        width: SimpleTheme.px(110); height: SimpleTheme.px(100); fillMode: Image.PreserveAspectFit
                                        source: "qrc:///qmlimages/" + modelData.img + ".png" }
                                SText { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(6)
                                        text: modelData.done ? "✓ " + modelData.t : modelData.t; size: 20 }
                            }
                        }
                    }
                    SText { id: helpText; width: parent.width; wrapMode: Text.WordWrap; size: 24; medium: true; color: SimpleTheme.warn; visible: text !== "" && sn.running === "accel" }
                    // progress
                    Item {
                        id: progress
                        property real value: 0
                        width: parent.width; height: SimpleTheme.px(16)
                        Rectangle { anchors.fill: parent; radius: height / 2; color: SimpleTheme.surfaceControl }
                        Rectangle { width: parent.width * Math.max(0, Math.min(1, progress.value)); height: parent.height; radius: height / 2; color: SimpleTheme.brandGreen }
                    }
                    // status log (last lines from the drone)
                    Item {
                        id: statusLog
                        width: parent.width; height: SimpleTheme.px(150)
                        property var lines: []
                        property string lastLine: lines.length ? lines[lines.length - 1] : ""
                        function append(text) { var l = lines.slice(); l.push(String(text)); if (l.length > 6) l.shift(); lines = l; return true }
                        function clear() { lines = [] }
                        Column {
                            width: parent.width
                            Repeater { model: statusLog.lines
                                       SText { width: statusLog.width; text: modelData; size: 20; color: SimpleTheme.textSecondary; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight } }
                        }
                    }
                    // result
                    Rectangle {
                        visible: sn.result !== ""
                        width: parent.width; height: resText.height + SimpleTheme.px(24); radius: SimpleTheme.px(14)
                        color: SimpleTheme.withAlpha(sn.result === "ok" ? SimpleTheme.ok : SimpleTheme.warn, 0.18)
                        SText { id: resText; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                                wrapMode: Text.WordWrap; size: 22
                                text: sn.result === "ok" ? ((sn.running === "compass" || sn.running === "accel") ? qsTr("Calibration done. Restart the drone to use it.") : qsTr("Done."))
                                    : sn.result === "cancelled" ? qsTr("Calibration cancelled. Nothing was changed.")
                                    : sn.running === "compass" ? qsTr("Calibration failed. Try again away from metal and wind.")
                                    : sn.running === "accel" ? qsTr("Calibration failed. Hold each position still until the next one is asked, then try again.")
                                    : qsTr("Calibration failed. Keep the drone still and try again.") }
                    }
                    Row {
                        spacing: SimpleTheme.px(12)
                        Item { id: nextBtn; enabled: false; width: nb.width; height: nb.height; visible: sn.running === "accel" && sn.result === ""
                               SButton { id: nb; kind: "primary"; text: qsTr("Next"); enabled_: nextBtn.enabled; objectName: "calNext"; onClicked: ctl.nextClicked() } }
                        Item { id: cancelBtn; enabled: false; width: cb.width; height: cb.height; visible: sn.result === ""
                               SButton { id: cb; text: qsTr("Cancel"); enabled_: cancelBtn.enabled; objectName: "calCancel"; onClicked: { sn.cancelAsked = true; ctl.cancelCalibration() } } }
                        SButton { visible: sn.result === "ok" && (sn.running === "compass" || sn.running === "accel"); kind: "primary"; text: qsTr("Restart the drone")
                                  onClicked: { vsp._veh.rebootVehicle(); sn.running = ""; sn.result = "" } }
                        SButton { visible: sn.result !== ""; text: qsTr("Close"); objectName: "calClose"; onClicked: { sn.running = ""; sn.result = "" } }
                    }
                }
            }
        }
    }
}
