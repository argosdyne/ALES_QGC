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
            Row {
                spacing: SimpleTheme.px(10)
                visible: pp._st.torqueRemote
                Repeater {
                    model: [0, 30, 100]
                    SButton {
                        designHeight: 72; textSize: 24; text: modelData + " %"
                        kind: pp._st.torqueSetpointAvailable && pp._st.torquePercent === modelData ? "primary" : "secondary"
                        onClicked: pp._st.setTorquePercent(modelData)
                    }
                }
                SText { anchors.verticalCenter: parent.verticalCenter; size: 22; color: SimpleTheme.textSecondary
                        text: qsTr("applied %1 %").arg(pp._st.hasMonitoring ? Math.round(pp._st.appliedTorquePercent) : "—") }
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
                    visible: modelData.state !== 3
                    width: parent.width; height: visible ? SimpleTheme.px(36) : 0
                    SIcon { id: ci; anchors.verticalCenter: parent.verticalCenter; size: 26
                            name: modelData.state === 0 ? "check" : modelData.state === 1 ? "warn" : "info"
                            color: modelData.state === 0 ? SimpleTheme.ok : modelData.state === 1 ? SimpleTheme.warn : SimpleTheme.textTertiary }
                    SText { anchors.left: ci.right; anchors.leftMargin: SimpleTheme.px(10); anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            text: modelData.name + (modelData.detail ? " · " + modelData.detail : ""); size: 22
                            color: modelData.state === 1 ? SimpleTheme.warn : SimpleTheme.textPrimary }
                }
            }
            Row {
                spacing: SimpleTheme.px(12)
                SButton {
                    visible: pp._ys.lidarState !== 7 && pp._ys.lidarState !== 8
                    designHeight: 80; textSize: 26; kind: "primary"; icon: "play"; text: qsTr("Start recording")
                    enabled_: pp._ys.lidarState === 4 || pp._ys.lidarState === 5
                    onClicked: {
                        if (pp._ys.lidarState === 5) pp._ys.startAcquisition()
                        else pp.lidarRefused(pp.lidarNotReadyReason())
                    }
                }
                SHoldButton {
                    visible: pp._ys.lidarState === 7
                    designHeight: 80; text: qsTr("Hold 2 s to stop")
                    onActivated: pp._ys.stopAcquisition()
                }
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
                SHoldButton { designHeight: 88; text: qsTr("Hold 2 s to release"); enabled_: wc.canRelease
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
