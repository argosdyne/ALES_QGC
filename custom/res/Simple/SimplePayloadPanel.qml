/****************************************************************************
 * AQGC Simple UI — S10 Payloads panel (fly screen), with the tether (S11/S16) and LiDAR (S17/S51) cards.
 * One card per connected payload: header (icon, name, status) + up to 3 controls (button, toggle, hold-to-run).
 * Only what the existing managers can do (decision 2026-11-16, see Figma S10 UX note):
 *   Megaphone   vehicle.audioControl          clip 1–11 play / stop (no volume, no feedback from the drone)
 *   Searchlight missionController.setSearchlight / slStatus  on / off (no brightness)
 *   Winch       vehicle.sendGripperAction     hook / release (GRIP_ENABLE); no lower / raise (no winch command)
 *   Life jacket missionController.deployLifeVest            hold to drop (BirdCom)
 *   Tether      corePlugin.elistairStationManager           power, automatic torque, telemetry
 *   LiDAR       corePlugin.ysManager                        status rows, start, hold to stop
 *               + mainWindow.lidarAcquisition / lidarAlerts / lidarTrack (phase 2, #318 / #319): reject reason,
 *               data-logging check, no-response rows, time recorded and survey lines left (Figma S102 / S103)
 * Which cards appear: the same switches the classic panels use (flyViewSettings.enableAudioController,
 * corePlugin.settings.lifeJacketEnable, vehicle.hasGripper, elistairStationManager.enabled, settings.ysEnable).
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

SPanel {
    id: pp
    property var vs: null
    signal lidarRefused(string reason)          // S51: Start pressed while the LiDAR is not ready

    readonly property var  _veh:    vs ? vs.vehicle : null
    readonly property var  _custom: QGroundControl.corePlugin.settings
    readonly property var  _fly:    QGroundControl.settingsManager.flyViewSettings
    readonly property var  _st:     QGroundControl.corePlugin.elistairStationManager
    readonly property var  _ys:     QGroundControl.corePlugin.ysManager
    readonly property var  _mc:     globals.planMasterControllerFlyView ? globals.planMasterControllerFlyView.missionController : null
    readonly property var  _acq:    mainWindow.lidarAcquisition
    readonly property var  _alerts: mainWindow.lidarAlerts
    readonly property var  _track:  mainWindow.lidarTrack

    readonly property bool hasAudio:   !!_veh && !!_veh.audioControl && !!_fly.enableAudioController.rawValue
    readonly property bool hasBirdCom: !!_veh && !_veh.px4Firmware && !!_mc && !!_custom.lifeJacketEnable.rawValue
    // hasGripper is CONSTANT in C++ but reads GRIP_ENABLE: re-read it once the parameters are in
    readonly property bool hasGripper: !!_veh && !!vs && vs.paramsReady && _veh.hasGripper
    readonly property bool hasTether:  !!_st && _st.enabled
    readonly property bool hasLidar:   !!_ys && !!_custom.ysEnable.rawValue
    readonly property var  kinds: {
        var k = []
        if (hasTether)  k.push("tether")
        if (hasLidar)   k.push("lidar")
        if (hasAudio)   k.push("megaphone")
        if (hasBirdCom) k.push("searchlight")
        if (hasGripper) k.push("winch")
        if (hasBirdCom) k.push("lifejacket")
        return k
    }
    readonly property int count: kinds.length

    readonly property var profileNames: [qsTr("Inspection / Surveillance"), qsTr("Mapping"), qsTr("Tether"), qsTr("Cleaning")]

    // ---- status of each payload (same rules as Settings › Payloads)
    function tetherStatus() {
        if (_st.noPower) return { t: qsTr("No power"), l: "danger" }
        if (_st.linkLost) return { t: qsTr("Link lost"), l: "danger" }
        if (_st.connected && _st.hasMonitoring) return { t: _st.powerOn ? qsTr("Power on") : qsTr("Power off"), l: _st.powerOn ? "ok" : "warn" }
        if (_st.connected || _st.noReply) return { t: qsTr("No reply"), l: "warn" }
        return { t: qsTr("Not connected"), l: "off" }
    }
    function lidarStatus() {
        if (_alerts && _alerts.noResponse) return { t: qsTr("No response"), l: "danger" }
        if (_alerts && _alerts.delayed)    return { t: qsTr("Status delayed"), l: "warn" }
        switch (_ys.lidarState) {
        case 1: return { t: qsTr("Drone not connected"), l: "off" }
        case 2: return { t: qsTr("No reply"), l: "danger" }
        case 3: return { t: qsTr("Powered off"), l: "off" }
        case 4: return { t: qsTr("Not ready"), l: "warn" }
        case 5: return { t: qsTr("Ready"), l: "ok" }
        case 6: return { t: qsTr("Starting…"), l: "info" }
        case 7: return { t: qsTr("Recording %1").arg(_mmss(_ys.recordingSeconds)), l: "info" }
        case 8: return { t: qsTr("Stopping…"), l: "info" }
        }
        return { t: qsTr("Off"), l: "off" }
    }
    // S102: a pre-check row with a critical LiDAR alert is red (rows: 1 scanner, 3 USB stick, 5 temperature)
    function _lidarRowCritical(index) {
        if (!_alerts) return false
        var keys = { 1: ["dataDropped"], 3: ["usbFull"], 5: ["scnOverheat", "intOverheat"] }[index] || []
        return _alerts.alerts.some(function(a) { return a.critical && keys.indexOf(a.key) !== -1 })
    }
    // last known REC while the LiDAR does not answer (S103)
    readonly property bool _lastKnownRec: !!_alerts && _alerts.noResponse && _alerts.lastKnownState === qsTranslate("LiDARAlerts", "REC")
    // survey lines of the uploaded mission (remaining / total), refreshed with the recording clock
    readonly property var _lines: {
        var tick = _ys ? _ys.recordingSeconds : 0
        return _acq && _ys && _ys.lidarState === 7 ? _acq.remainingSurveyLines() : null
    }
    function _mmss(s) { s = Math.max(0, Math.floor(s)); var m = Math.floor(s / 60); s = s % 60; return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s }
    // first failing pre-check, for S51 ("Not ready — INS not locked")
    function lidarNotReadyReason() {
        var rows = _ys.preChecks || []
        for (var i = 0; i < rows.length; i++) if (rows[i].state === 1) return rows[i].name + (rows[i].detail ? " — " + rows[i].detail : "")
        return _ys.insNotLocked ? qsTr("INS not locked — fly the init path first") : qsTr("The LiDAR is not ready yet")
    }

    // local state (the drone does not report these back)
    property int  clip: 1
    property bool playing: false
    property string hookState: ""       // "" | hooked | released

    // S56: stop the clip / turn the searchlight off when the drone lands (SimplePayloadPrefs)
    Connections {
        target: pp.vs
        function onLandingChanged() {
            if (!pp.vs || !pp.vs.landing) return
            if (SimplePayloadPrefs.megaphoneStopOnLanding && pp.playing && pp.hasAudio) { pp._veh.audioControl._stopAudio(); pp.playing = false }
            if (SimplePayloadPrefs.lightOffOnLanding && pp.hasBirdCom && pp._mc.slStatus === 1) pp._mc.setSearchlight(0)
        }
    }

    onVisibleChanged: if (visible && hasBirdCom) _mc.getSearchlight()

    property real maxHeight: SimpleTheme.px(690)
    width:  SimpleTheme.px(640)
    height: Math.min(cards.height + SimpleTheme.px(136), maxHeight)
    title:  qsTr("Payloads")
    titleIcon: "plus"

    SText {
        y: -SimpleTheme.px(34)
        size: 22; color: SimpleTheme.textSecondary
        text: qsTr("Profile: %1 · %2 connected").arg(pp.profileNames[Math.max(0, Math.min(3, Number(pp._custom.simpleProductProfile.rawValue)))] || "").arg(pp.count)
    }

    Flickable {
        anchors.fill: parent
        contentHeight: cards.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: cards
            width: parent.width
            spacing: SimpleTheme.px(14)
            SText {
                visible: pp.count === 0
                width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                text: qsTr("No payload connected. Payloads are set up in Settings › Payloads.")
            }
            Repeater {
                model: pp.kinds
                Loader {
                    width: cards.width
                    sourceComponent: modelData === "tether" ? tetherCard : modelData === "lidar" ? lidarCard
                                   : modelData === "megaphone" ? megaphoneCard : modelData === "searchlight" ? lightCard
                                   : modelData === "winch" ? winchCard : lifeCard
                }
            }
        }
    }

    //------------------------------------------------------------------ tether (S16 ground, S11 flight)
    Component {
        id: tetherCard
        SPayloadCard {
            id: tc
            readonly property bool ctrl: pp._st.frameVersionDetected && pp._st.hasMonitoring && !pp._st.linkLost && (pp._st.connected || pp._st.noReply)
            icon: "tether"; name: qsTr("Tether station")
            readonly property var _s: pp.tetherStatus()
            statusText: _s.t; statusLevel: _s.l
            property int  torqueLevel: 0
            property bool torqueLevelKnown: false
            property bool torqueReferenceIsApplied: false
            property bool _prevRemote: false
            function syncTorqueReference() {
                if (!tc.ctrl) { torqueLevelKnown = false; torqueReferenceIsApplied = false }
                else if (pp._st.torqueRemote && pp._st.torqueSetpointAvailable) {
                    torqueLevel = Math.max(0, Math.min(10, Math.round(pp._st.torquePercent / 10)))
                    torqueLevelKnown = true
                    torqueReferenceIsApplied = pp._st.activeFrameVersion === "Extended V1" && pp._st.torquePercent === pp._st.appliedTorquePercent
                } else if (pp._st.activeFrameVersion === "Extended V1") {
                    torqueLevel = Math.max(0, Math.min(10, Math.round(pp._st.appliedTorquePercent / 10)))
                    torqueLevelKnown = true; torqueReferenceIsApplied = true
                } else { torqueLevelKnown = false; torqueReferenceIsApplied = false }
            }
            function selectTorqueLevel(level) {
                if (!tc.ctrl || !pp._st.torqueRemote) return
                torqueLevel = Math.max(0, Math.min(10, level)); torqueLevelKnown = true; torqueReferenceIsApplied = false
                pp._st.setTorquePercent(torqueLevel * 10)
            }
            onCtrlChanged: syncTorqueReference()
            Component.onCompleted: { _prevRemote = pp._st.torqueRemote; syncTorqueReference() }
            Connections {
                target: pp._st
                // a change of automatic torque re-reads the reference; while it is off the applied value follows the station
                function onControlChanged() {
                    if (tc._prevRemote !== pp._st.torqueRemote) { tc._prevRemote = pp._st.torqueRemote; tc.syncTorqueReference() }
                    else if (!pp._st.torqueRemote) tc.syncTorqueReference()
                }
                function onTelemetryChanged() { if (!pp._st.torqueRemote) tc.syncTorqueReference() }
            }
            Row {
                spacing: SimpleTheme.px(12)
                SButton {
                    designHeight: 80; textSize: 26; text: qsTr("Power on"); icon: "power"
                    kind: pp._st.powerOn && !pp._st.powerOffPending ? "primary" : "secondary"
                    enabled_: tc.ctrl && !pp._st.powerOn && !pp._st.noPower
                    onClicked: pp._st.setPowerOn(true)
                }
                SButton {
                    designHeight: 80; textSize: 26; text: qsTr("Power off")
                    kind: !pp._st.powerOn ? "primary" : "secondary"
                    enabled_: tc.ctrl && pp._st.powerOn && !pp._st.powerOffPending && !pp._st.noPower
                    onClicked: pp._st.setPowerOn(false)       // in flight the station asks for a slide confirmation
                }
            }
            Item {
                width: parent.width; height: SimpleTheme.px(80)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Automatic torque"); size: 24 }
                SToggle {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    checked: pp._st.torqueRemote
                    onToggled: pp._st.setTorqueRemote(checked)
                }
            }
            // Torque in 0–10 steps of 10 % (#317, same rules as the classic panel). The shown step is only a
            // reference and never sends a command: the set value while automatic torque is on and known,
            // otherwise the applied value (Extended V1 only, "≈"); unknown = "—" and ‹ › start from 0 (‹ = 0, › = 1).
            Item {
                width: parent.width; height: SimpleTheme.px(72)
                visible: pp._st.torqueRemote || tc.ctrl
                Row {
                    id: tqRow
                    spacing: SimpleTheme.px(10)
                    anchors.verticalCenter: parent.verticalCenter
                    SButton { designHeight: 72; textSize: 30; text: "‹"
                              enabled_: tc.ctrl && pp._st.torqueRemote && (!tc.torqueLevelKnown || tc.torqueLevel > 0)
                              onClicked: if (enabled_) tc.selectTorqueLevel(tc.torqueLevelKnown ? tc.torqueLevel - 1 : 0) }
                    Rectangle {
                        width: SimpleTheme.px(150); height: SimpleTheme.px(72); radius: SimpleTheme.px(16)
                        color: SimpleTheme.surfaceControl
                        SText { anchors.centerIn: parent; size: 26; bold: true
                                text: tc.torqueLevelKnown ? (tc.torqueReferenceIsApplied ? "≈ " : "") + tc.torqueLevel + " / 10" : "— / 10" }
                    }
                    SButton { designHeight: 72; textSize: 30; text: "›"
                              enabled_: tc.ctrl && pp._st.torqueRemote && (!tc.torqueLevelKnown || tc.torqueLevel < 10)
                              onClicked: if (enabled_) tc.selectTorqueLevel(tc.torqueLevelKnown ? tc.torqueLevel + 1 : 1) }
                }
                SText { anchors.left: tqRow.right; anchors.leftMargin: SimpleTheme.px(16); anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter; size: 22; color: SimpleTheme.textSecondary; elide: Text.ElideRight
                        text: qsTr("applied %1 %").arg(pp._st.hasMonitoring && pp._st.activeFrameVersion === "Extended V1" ? Math.round(pp._st.appliedTorquePercent) : "—") }
            }
            SText {
                width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.warn
                visible: !tc.ctrl || !pp._st.torqueRemote || !tc.torqueLevelKnown
                text: !tc.ctrl ? qsTr("Torque is locked until the station link is connected.")
                    : !pp._st.torqueRemote ? qsTr("Turn on automatic torque to change the torque.")
                    : qsTr("The station does not report the torque. ‹ sets 0, › sets 1 of 10.")
            }
            SText {
                width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                text: pp._st.hasMonitoring
                      ? qsTr("%1 W · cable %2 m · spool %3 °C").arg(Math.round(pp._st.powerWatts)).arg(Number(pp._st.cableLength).toFixed(1)).arg(Math.round(pp._st.spoolTemperature))
                      : qsTr("Waiting for the station…")
            }
            SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; visible: pp._st.alarmActive; color: SimpleTheme.warn; text: pp._st.alarmSummary }
            SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary; visible: !pp._st.powerOn && pp.vs && !pp.vs.armed; text: qsTr("Turn the power on before take-off.") }
        }
    }

    //------------------------------------------------------------------ LiDAR (S17, S51)
    Component {
        id: lidarCard
        SPayloadCard {
            icon: "lidar"; name: qsTr("YellowScan LiDAR")
            readonly property var _s: pp.lidarStatus()
            statusText: _s.t; statusLevel: _s.l
            Repeater {
                model: pp._ys.preChecks || []
                Item {
                    // rowView adds the warning bits YSManager does not decode and the no-response view (grey, last time)
                    readonly property var _v: pp._alerts ? pp._alerts.rowView(index, modelData) : { state: modelData.state, detail: modelData.detail, dimmed: false }
                    readonly property bool _rejected: (!!pp._acq && pp._acq.startRejected && pp._acq.rejectRowIndex === index)
                                                      || (!_v.dimmed && pp._lidarRowCritical(index))
                    readonly property color _c: _v.dimmed ? SimpleTheme.textTertiary : _rejected ? SimpleTheme.textDanger
                                              : _v.state === 1 ? SimpleTheme.warn : SimpleTheme.textPrimary
                    visible: _v.state !== 3 || _v.dimmed
                    width: parent.width; height: visible ? SimpleTheme.px(36) : 0
                    SIcon { id: ci; anchors.verticalCenter: parent.verticalCenter; size: 26
                            name: _v.dimmed ? "info" : _v.state === 0 ? "check" : _v.state === 1 ? "warn" : "info"
                            color: _v.dimmed ? SimpleTheme.textTertiary : _rejected ? SimpleTheme.textDanger
                                 : _v.state === 0 ? SimpleTheme.ok : _v.state === 1 ? SimpleTheme.warn : SimpleTheme.textTertiary }
                    SText { anchors.left: ci.right; anchors.leftMargin: SimpleTheme.px(10); anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            text: modelData.name + (_v.detail ? " · " + _v.detail : ""); size: 22; color: _c }
                }
            }
            // S51 / S102: the LiDAR refused Start (its answer code), or did not report data logging 3 s after Start
            SText {
                visible: !!pp._acq && pp._acq.startRejected
                width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textDanger
                text: !pp._acq ? "" : pp._acq.rejectCode !== 0
                      ? qsTr("Start refused by the LiDAR: %1 (%2)").arg(pp._acq.rejectReason).arg(pp._acq.hexCode(pp._acq.rejectCode))
                      : qsTr("Start refused by the LiDAR: %1").arg(pp._acq.rejectReason)
            }
            SText {
                visible: !!pp._acq && pp._acq.loggingWarning
                width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.warn
                text: qsTr("The LiDAR does not report data logging since Start. Check the USB stick.")
            }
            Row {
                spacing: SimpleTheme.px(12)
                SButton {
                    visible: pp._ys.lidarState !== 7 && pp._ys.lidarState !== 8 && !pp._lastKnownRec
                    designHeight: 80; textSize: 26; kind: "primary"; icon: "play"
                    text: !!pp._acq && pp._acq.startRejected ? qsTr("Start (retry)") : qsTr("Start recording")
                    enabled_: pp._ys.lidarState === 4 || pp._ys.lidarState === 5
                    onClicked: {
                        if (pp._ys.lidarState !== 5) { pp.lidarRefused(pp.lidarNotReadyReason()); return }
                        if (pp._acq) pp._acq.start(); else pp._ys.startAcquisition()
                    }
                }
                // Stop also while the LiDAR does not answer but was recording (S103): the command is still sent
                SHoldButton {
                    visible: pp._ys.lidarState === 7 || pp._lastKnownRec
                    designHeight: 80
                    text: pp.vs && pp.vs.flying && pp._lines ? qsTr("Hold 2 s to stop · %1 of %2 lines left").arg(pp._lines.remaining).arg(pp._lines.total)
                                                             : qsTr("Hold 2 s to stop")
                    onActivated: { if (pp._acq) pp._acq.stop(); else pp._ys.stopAcquisition() }
                }
            }
            SText {
                visible: text !== ""
                width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                text: pp._alerts && pp._alerts.noResponse
                      ? qsTr("Last status %1. Stop is still sent; the card returns when the LiDAR answers.").arg(pp._alerts.lastStatusTime || "--")
                      : pp._ys.lidarState !== 7 || !pp._acq || pp._acq.startedTime === "" ? ""
                      : qsTr("Started %1 · %2 recorded").arg(pp._acq.startedTime).arg(pp._mmss(pp._ys.recordingSeconds))
                        + (pp._lines ? " · " + qsTr("line %1 of %2").arg(Math.min(pp._lines.total, pp._lines.total - pp._lines.remaining + 1)).arg(pp._lines.total) : "")
            }
        }
    }

    //------------------------------------------------------------------ megaphone
    Component {
        id: megaphoneCard
        SPayloadCard {
            icon: "speaker"; name: qsTr("Megaphone")
            readonly property var _s: pp.playing ? { t: qsTr("Playing"), l: "info" } : { t: qsTr("Ready"), l: "off" }
            statusText: _s.t; statusLevel: _s.l
            Item {
                width: parent.width; height: SimpleTheme.px(96)
                Column {
                    anchors.left: parent.left; anchors.right: clipButtons.left; anchors.rightMargin: SimpleTheme.px(12)
                    anchors.verticalCenter: parent.verticalCenter
                    SText { width: parent.width; text: qsTr("Clip %1").arg(pp.clip); size: 28; bold: true }
                    SText { width: parent.width; text: qsTr("%1 of 11").arg(pp.clip); size: 21; color: SimpleTheme.textSecondary }
                }
                Row {
                    id: clipButtons
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    spacing: SimpleTheme.px(12)
                    SRoundIconButton { designWidth: 80; designHeight: 80; radius: width / 2; icon: "back"
                                       enabled_: pp.clip > 1; onClicked: pp.clip = pp.clip - 1 }
                    Rectangle {
                        width: SimpleTheme.px(96); height: width; radius: width / 2
                        color: playMa.pressed ? SimpleTheme.brandGreenDark : SimpleTheme.brandGreen
                        SIcon { anchors.centerIn: parent; name: pp.playing ? "close" : "play"; size: 40 }
                        MouseArea {
                            id: playMa; anchors.fill: parent
                            onClicked: {
                                if (pp.playing) { pp._veh.audioControl._stopAudio(); pp.playing = false }
                                else { pp._veh.audioControl._playAudio(pp.clip); pp.playing = true }
                            }
                        }
                    }
                    SRoundIconButton { designWidth: 80; designHeight: 80; radius: width / 2; icon: "chevron"
                                       enabled_: pp.clip < 11; onClicked: pp.clip = pp.clip + 1 }
                }
            }
            SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary; text: qsTr("The speaker does not report back: the status only shows that the command was sent.") }
        }
    }

    //------------------------------------------------------------------ searchlight
    Component {
        id: lightCard
        SPayloadCard {
            icon: "light"; name: qsTr("Searchlight")
            readonly property var _s: pp._mc && pp._mc.slStatus === 1 ? { t: qsTr("On"), l: "ok" } : { t: qsTr("Off"), l: "off" }
            statusText: _s.t; statusLevel: _s.l
            Item {
                width: parent.width; height: SimpleTheme.px(72)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Light"); size: 24 }
                SToggle {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    checked: pp._mc && pp._mc.slStatus === 1
                    onToggled: pp._mc.setSearchlight(checked ? 1 : 0)
                }
            }
        }
    }

    //------------------------------------------------------------------ winch (gripper)
    Component {
        id: winchCard
        SPayloadCard {
            id: wc
            // release only in flight, or on the ground with the motors stopped (ground test, S56)
            readonly property bool canRelease: !!pp.vs && (pp.vs.flying || !pp.vs.armed)
            icon: "hook"; name: qsTr("Winch")
            readonly property var _s: pp.hookState === "hooked" ? { t: qsTr("Hooked"), l: "ok" } : pp.hookState === "released" ? { t: qsTr("Released"), l: "warn" } : { t: "", l: "off" }
            statusText: _s.t; statusLevel: _s.l
            Row {
                spacing: SimpleTheme.px(12)
                SButton { designHeight: 88; textSize: 26; text: qsTr("Hook"); icon: "hook"
                          onClicked: { pp._veh.sendGripperAction(1); pp.hookState = "hooked" } }    // Vehicle.Gripper_grab
                SHoldButton { designHeight: 88; holdMs: SimplePayloadPrefs.winchHoldMs; enabled_: wc.canRelease
                              text: qsTr("Hold %1 s to release").arg(Math.round(SimplePayloadPrefs.winchHoldMs / 1000))
                              onActivated: { pp._veh.sendGripperAction(0); pp.hookState = "released" } }  // Vehicle.Gripper_release
            }
            SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary; visible: !wc.canRelease; text: qsTr("Release works in flight, or on the ground with the motors stopped.") }
        }
    }

    //------------------------------------------------------------------ life jacket (BirdCom)
    Component {
        id: lifeCard
        SPayloadCard {
            icon: "lifevest"; name: qsTr("Life jacket")
            SHoldButton { width: parent.width; designHeight: 88; text: qsTr("Hold 2 s to drop the life jacket")
                          onActivated: pp._mc.deployLifeVest() }
        }
    }
}
