/****************************************************************************
 * AQGC Simple UI — Settings › Payloads: list (S52) and details for YellowScan LiDAR (S53), tether station
 * SAFE-T (S54) and camera & gimbal (S55). Uses the existing managers only (decision 2026-11-15):
 *   YellowScan  QGroundControl.corePlugin.ysManager + corePlugin.settings ys*
 *   Tether      QGroundControl.corePlugin.elistairStationManager
 *   Camera      PayloadManager (Gremsy Lynx / NextVision) + videoSettings.rtspUrl
 *   Gimbal tilt FC mount parameters MNT1_PITCH_MIN/MAX (deg) or MNT_ANGMIN/MAX_TIL (cdeg), ground only
 * Vision LiDAR (S99, 2026-11-18): BirdCom obstacle sensor (MAVLink component 111) through the fly-view
 *   MissionController calls of the removed classic Plan tool-strip panel (EN_VISIONLIDAR, EN_VL_VALUE, VL_OBA_MODE, VL_DIST).
 * Megaphone, searchlight, winch and cleaning device (S56): values in SimplePayloadPrefs (kept in the app, decision
 * 2026-11-16); "Use" switches are the classic ones (flyViewSettings.enableAudioController, settings.lifeJacketEnable).
 ****************************************************************************/
import QtQuick 2.12
import Qt.labs.settings 1.0
import QGroundControl 1.0
import QGroundControl.FactSystem 1.0
import QGroundControl.Payload 1.0
import "."

Column {
    id: pl
    property var    vs
    property string view: "list"        // list | lidar | tether | camera | visionlidar | megaphone | searchlight | winch | cleaning
    spacing: SimpleTheme.px(16)

    readonly property var _custom: QGroundControl.corePlugin.settings
    readonly property var _ys:     QGroundControl.corePlugin.ysManager
    readonly property var _st:     QGroundControl.corePlugin.elistairStationManager
    readonly property var _cam:    PayloadManager.activeType === 0 ? PayloadManager.gremsy : PayloadManager.nextvision

    // Gimbal speed presets for the two payload controllers (Gremsy deg/s at full stick, NextVision PWM offset 50-500)
    function applyGimbalSpeed(idx) {
        if (PayloadManager.gremsy)     PayloadManager.gremsy.speedDegPerSec = [35, 70, 105][idx]
        if (PayloadManager.nextvision) PayloadManager.nextvision.speedOffset = [200, 400, 500][idx]
    }

    // ---- status text and level for each payload (used by the list and the detail headers)
    function lidarStatus() {
        if (!_custom.ysEnable.rawValue) return { t: qsTr("Off"), l: "off" }
        if (!_ys) return { t: qsTr("Not available"), l: "off" }
        switch (_ys.lidarState) {
        case 1: return { t: qsTr("Drone not connected"), l: "off" }
        case 2: return { t: qsTr("No reply"), l: "danger" }
        case 3: return { t: qsTr("Powered off"), l: "off" }
        case 4: return { t: qsTr("Not ready"), l: "warn" }
        case 5: return { t: qsTr("Ready"), l: "ok" }
        case 6: case 7: case 8: return { t: qsTr("Recording"), l: "info" }
        }
        return { t: qsTr("Off"), l: "off" }
    }
    function tetherStatus() {
        if (!_st || !_st.enabled) return { t: qsTr("Off"), l: "off" }
        if (_st.linkLost) return { t: qsTr("Link lost"), l: "danger" }
        if (_st.connected && _st.hasMonitoring) return { t: _st.powerOn ? qsTr("Connected · power on") : qsTr("Connected · power off"), l: "ok" }
        if (_st.connected || _st.noReply) return { t: qsTr("No reply"), l: "warn" }
        return { t: qsTr("Not connected"), l: "off" }
    }
    readonly property var _fly: QGroundControl.settingsManager.flyViewSettings
    readonly property var _veh: vs ? vs.vehicle : null
    function megaphoneStatus() { return _fly.enableAudioController.rawValue ? { t: qsTr("On"), l: "ok" } : { t: qsTr("Off"), l: "off" } }
    readonly property var _mc: globals.planMasterControllerFlyView ? globals.planMasterControllerFlyView.missionController : null
    function visionStatus() {
        if (!_veh) return { t: qsTr("Drone not connected"), l: "off" }
        if (!_mc || _mc.visionLidarEnabled !== 1) return { t: qsTr("Off"), l: "off" }
        return _mc.vlOBAValue === 0 ? { t: qsTr("On · stop"), l: "ok" } : { t: qsTr("On · avoid"), l: "ok" }
    }
    function lightStatus()     { return _custom.lifeJacketEnable.rawValue ? { t: qsTr("On"), l: "ok" } : { t: qsTr("Off"), l: "off" } }
    function winchStatus() {
        if (!_veh || !vs.paramsReady) return { t: qsTr("Drone not connected"), l: "off" }
        return _veh.hasGripper ? { t: qsTr("Fitted"), l: "ok" } : { t: qsTr("Not fitted"), l: "off" }
    }
    // MAVLink camera on the drone (e.g. R3: the camera rail uses it); the IP payload controller below is only Gremsy / NextVision
    readonly property var _mavCamMgr: _veh ? _veh.cameraManager : null
    readonly property var _mavCam: _mavCamMgr && _mavCamMgr.cameras.count > 0 ? _mavCamMgr.cameras.get(_mavCamMgr.currentCamera) : null
    function cameraStatus() {
        if (_mavCam && !(_cam && _cam.connected)) return { t: qsTr("Connected"), l: "ok" }
        if (!_cam) return { t: qsTr("Not available"), l: "off" }
        if (_cam.connected) return { t: qsTr("Connected"), l: "ok" }
        if (_cam.connecting) return { t: qsTr("Connecting…"), l: "info" }
        if (_cam.linkFailed) return { t: qsTr("Cannot connect"), l: "danger" }
        return { t: qsTr("Not connected"), l: "off" }
    }

    // ---- small shared pieces
    component Pill: Rectangle {
        property string text: ""
        property string level: "off"     // ok | warn | danger | info | off
        height: SimpleTheme.px(48); radius: SimpleTheme.px(12)
        width: pillText.implicitWidth + SimpleTheme.px(28)
        color: level === "ok" ? SimpleTheme.ok : level === "warn" ? SimpleTheme.warn : level === "danger" ? SimpleTheme.danger
             : level === "info" ? SimpleTheme.info : SimpleTheme.surfaceControl
        SText {
            id: pillText; anchors.centerIn: parent; size: 24; medium: true; text: parent.text
            color: parent.level === "ok" || parent.level === "warn" ? SimpleTheme.bgBase : SimpleTheme.textPrimary
        }
    }
    component Card: Rectangle {
        default property alias content: cardCol.data
        width: parent ? parent.width : 0
        height: cardCol.height + SimpleTheme.px(44)
        radius: SimpleTheme.px(20); color: SimpleTheme.surfaceRaised
        Column {
            id: cardCol
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: SimpleTheme.px(22); anchors.leftMargin: SimpleTheme.px(28)
            spacing: SimpleTheme.px(14)
        }
    }
    component CardRow: Item {
        property string title: ""
        property string sub: ""
        default property alias control: rowCtl.data
        width: parent ? parent.width : 0
        height: Math.max(SimpleTheme.px(72), rowTxt.implicitHeight)
        Column {
            id: rowTxt
            anchors.left: parent.left; anchors.right: rowCtl.left; anchors.rightMargin: SimpleTheme.px(20)
            anchors.verticalCenter: parent.verticalCenter
            SText { width: parent.width; text: title; size: 28; medium: true }
            SText { width: parent.width; text: sub; size: 22; color: SimpleTheme.textSecondary; visible: sub !== ""; wrapMode: Text.WordWrap }
        }
        Item {
            id: rowCtl
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width; height: childrenRect.height
        }
    }
    component BackButton: SButton { designHeight: 80; kind: "ghost"; icon: "back"; text: qsTr("Payloads"); textSize: 26; onClicked: pl.view = "list" }

    Loader {
        width: parent.width
        sourceComponent: pl.view === "lidar" ? lidarComp : pl.view === "tether" ? tetherComp : pl.view === "camera" ? cameraComp
                       : pl.view === "visionlidar" ? visionComp : pl.view === "megaphone" ? megaphoneComp : pl.view === "searchlight" ? lightComp
                       : pl.view === "winch" ? winchComp : pl.view === "cleaning" ? cleaningComp : listComp
    }

    //------------------------------------------------------------------ S52 list
    Component {
        id: listComp
        Column {
            spacing: SimpleTheme.px(16)
            SText { text: qsTr("Payloads"); size: 40; bold: true }
            SText { width: parent.width; wrapMode: Text.WordWrap; text: qsTr("Devices the drone carries. Tap one to set it up."); size: 24; color: SimpleTheme.textSecondary }
            Repeater {
                model: [
                    { key: "lidar",  icon: "lidar",  title: qsTr("YellowScan LiDAR"),
                      sub: pl._custom.ysModel.enumStringValue + " · " + pl._custom.ysCamera.enumStringValue },
                    { key: "camera", icon: "camera", title: qsTr("Camera & gimbal"),
                      sub: pl._mavCam && !(pl._cam && pl._cam.connected) ? pl._mavCam.modelName
                         : pl._cam ? (pl._cam.displayName + (pl._cam.ip !== "" ? " · " + pl._cam.ip : "")) : "" },
                    { key: "tether", icon: "power",  title: qsTr("Tether station (SAFE-T)"),
                      sub: pl._st ? pl._st.stationAddress : "" },
                    { key: "visionlidar", icon: "locate",  title: qsTr("Vision LiDAR"),    sub: qsTr("BirdCom obstacle detection") },
                    { key: "megaphone",   icon: "speaker", title: qsTr("Megaphone"),       sub: qsTr("Clips stored on the speaker") },
                    { key: "searchlight", icon: "light",   title: qsTr("Searchlight"),     sub: qsTr("BirdCom searchlight and life jacket") },
                    { key: "winch",       icon: "hook",    title: qsTr("Winch"),           sub: qsTr("Hook for drops") },
                    { key: "cleaning",    icon: "grid",    title: qsTr("Cleaning device"), sub: qsTr("Not supported by this app yet") }
                ]
                Rectangle {
                    readonly property var _s: modelData.key === "lidar" ? pl.lidarStatus() : modelData.key === "tether" ? pl.tetherStatus()
                                            : modelData.key === "megaphone" ? pl.megaphoneStatus() : modelData.key === "searchlight" ? pl.lightStatus()
                                            : modelData.key === "winch" ? pl.winchStatus() : modelData.key === "visionlidar" ? pl.visionStatus() : modelData.key === "cleaning" ? { t: qsTr("Not detected"), l: "off" }
                                            : pl.cameraStatus()
                    width: parent.width; height: SimpleTheme.px(116); radius: SimpleTheme.px(20)
                    color: rowMouse.pressed ? Qt.darker(SimpleTheme.surfaceRaised, 1.25) : SimpleTheme.surfaceRaised
                    MouseArea { id: rowMouse; anchors.fill: parent; onClicked: pl.view = modelData.key }
                    SIcon { id: ic; name: modelData.icon; size: 44; anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(26); anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.left: ic.right; anchors.leftMargin: SimpleTheme.px(22); anchors.right: pill.left; anchors.rightMargin: SimpleTheme.px(16)
                        anchors.verticalCenter: parent.verticalCenter
                        SText { width: parent.width; text: modelData.title; size: 30; medium: true }
                        SText { width: parent.width; text: modelData.sub; size: 24; color: SimpleTheme.textSecondary; visible: text !== "" }
                    }
                    Pill { id: pill; anchors.right: chev.left; anchors.rightMargin: SimpleTheme.px(14); anchors.verticalCenter: parent.verticalCenter; text: parent._s.t; level: parent._s.l }
                    SIcon { id: chev; name: "chevron"; size: 40; opacity: 0.7; anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }

    //------------------------------------------------------------------ S53 YellowScan LiDAR
    Component {
        id: lidarComp
        Column {
            id: ly
            spacing: SimpleTheme.px(16)
            readonly property var  _st: pl.lidarStatus()
            readonly property bool _recording: pl._ys && (pl._ys.acquisitionRunning || pl._ys.lidarState >= 6)
            readonly property bool _online: pl._ys && pl._ys.statusValid
            property bool confirmOff: false
            property string offMsg: ""
            // preChecks rows have a fixed order (YSManager): INS/GNSS, Scanner, System time, USB stick, Camera, Temperature
            function check(i) { return pl._ys && pl._ys.preChecks && pl._ys.preChecks.length > i ? pl._ys.preChecks[i] : null }
            function checkText(c) { return !c ? "—" : c.state === 0 ? qsTr("OK") : c.state === 3 ? qsTr("Not used") : c.detail !== "" ? c.detail : (c.state === 1 ? qsTr("Problem") : qsTr("Unknown")) }
            function checkColor(c) { return !c ? SimpleTheme.textSecondary : c.state === 0 ? SimpleTheme.ok : c.state === 1 ? SimpleTheme.textDanger : SimpleTheme.textSecondary }
            Component.onCompleted: if (_online) pl._ys.requestCameraParameters()

            BackButton { }
            Item {
                width: parent.width; height: SimpleTheme.px(60)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("YellowScan LiDAR"); size: 40; bold: true }
                Pill { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: ly._st.t; level: ly._st.l }
            }
            Card {
                CardRow {
                    title: qsTr("Use YellowScan LiDAR"); sub: qsTr("Shows the LiDAR panel and checks in flight")
                    SToggle { id: ysToggle; checked: !!pl._custom.ysEnable.rawValue
                              onToggled: { pl._custom.ysEnable.rawValue = checked } }
                }
                CardRow {
                    title: qsTr("Model"); sub: qsTr("Pick it here — the LiDAR cannot report it")
                    SComboBox {
                        enabled: !ly._recording; opacity: enabled ? 1 : 0.4
                        model: pl._custom.ysModel.enumStrings
                        currentIndex: pl._custom.ysModel.enumIndex
                        onActivated: pl._custom.ysModel.value = pl._custom.ysModel.enumValues[index]
                    }
                }
                CardRow {
                    title: qsTr("Test connection")
                    sub: !pl._ys ? "" : pl._ys.testState === 1 ? qsTr("Testing…") : pl._ys.testMessage !== "" ? pl._ys.testMessage : qsTr("Asks the LiDAR for its status once")
                    SButton { designHeight: 72; textSize: 26; text: qsTr("Test"); enabled_: !!pl._ys && pl._custom.ysEnable.rawValue && pl._ys.testState !== 1; onClicked: if (enabled_) pl._ys.testConnection() }
                }
                // ysMissionStartStop (#318 / #319): 0 = manual only, 1 = auto Start at the first / Stop at the last survey
                // waypoint of the mission (LiDARMissionAuto). Manual Start / Stop on the fly screen always works.
                CardRow {
                    title: qsTr("Start recording")
                    sub: pl._custom.ysMissionStartStop.rawValue === 1
                         ? qsTr("Starts at the Init Path figure 8 before the survey and stops after the figure 8 at the end. Start / Stop on the flight screen still works.")
                         : qsTr("From the LiDAR panel on the flight screen")
                    SSegmented {
                        designWidth: 300
                        enabled: !ly._recording; opacity: enabled ? 1 : 0.4
                        model: [qsTr("Manual"), qsTr("Auto")]
                        currentIndex: pl._custom.ysMissionStartStop.rawValue === 1 ? 1 : 0
                        onActivated: { pl._custom.ysMissionStartStop.rawValue = index
                                       currentIndex = Qt.binding(function() { return pl._custom.ysMissionStartStop.rawValue === 1 ? 1 : 0 }) }
                    }
                }
            }
            SText { text: qsTr("DEVICE"); size: 24; medium: true; color: SimpleTheme.textTertiary }
            Card {
                CardRow { title: qsTr("USB stick")
                          SText { text: ly.checkText(ly.check(3)); size: 26; bold: true; color: ly.checkColor(ly.check(3)) } }
                CardRow { title: qsTr("Computer temperature"); sub: qsTr("The LiDAR reports only OK or a warning")
                          SText { text: ly.checkText(ly.check(5)); size: 26; bold: true; color: ly.checkColor(ly.check(5)) } }
                CardRow {
                    title: qsTr("Power off LiDAR"); sub: ly.offMsg !== "" ? ly.offMsg : qsTr("Restart needs the button on the drone")
                    Row {
                        spacing: SimpleTheme.px(12)
                        SButton { visible: !ly.confirmOff; designHeight: 72; textSize: 26; kind: "danger"; icon: "power"; text: qsTr("Power off…")
                                  enabled_: ly._online && !ly._recording && !vs.armed; onClicked: if (enabled_) ly.confirmOff = true }
                        SButton { visible: ly.confirmOff; designHeight: 72; textSize: 26; text: qsTr("Cancel"); onClicked: ly.confirmOff = false }
                        SButton { visible: ly.confirmOff; designHeight: 72; textSize: 26; kind: "danger"; icon: "power"; text: qsTr("Power off")
                                  onClicked: { ly.confirmOff = false; pl._ys.powerOff(); ly.offMsg = qsTr("Power off sent. Turn it on again with the button on the drone.") } }
                    }
                }
            }
            SText { visible: pl._custom.ysCamera.rawValue !== 0; text: qsTr("EMBEDDED CAMERA (SAVED IN LIDAR)"); size: 24; medium: true; color: SimpleTheme.textTertiary }
            Card {
                visible: pl._custom.ysCamera.rawValue !== 0
                CardRow { title: qsTr("Take photos")
                          SText { text: !pl._ys || !pl._ys.cameraParamsKnown ? "—" : pl._ys.embeddedCamera !== 0 ? qsTr("On") : qsTr("Off"); size: 26; bold: true } }
                CardRow { title: qsTr("Start at height"); sub: qsTr("From where recording starts")
                          SText { text: !pl._ys || !pl._ys.cameraParamsKnown ? "—" : pl._ys.embCamInitHeight.toFixed(0) + " m"; size: 26; bold: true } }
                CardRow { title: qsTr("Take a photo every")
                          SText { text: !pl._ys || !pl._ys.cameraParamsKnown ? "—"
                                      : pl._ys.embCamTriggerMode === 1 ? qsTr("%1 m").arg(pl._ys.embCamTriggerValue.toFixed(1)) : qsTr("%1 s").arg(pl._ys.embCamTriggerValue.toFixed(1))
                                  size: 26; bold: true } }
                SText {
                    width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textTertiary
                    text: qsTr("Read from the LiDAR. Changing these needs Set Parameter support in the companion board (not yet available).")
                }
            }
        }
    }

    //------------------------------------------------------------------ S54 tether station (SAFE-T)
    Component {
        id: tetherComp
        Column {
            id: tt
            spacing: SimpleTheme.px(16)
            readonly property var  _s: pl.tetherStatus()
            readonly property var  _set: pl._st ? pl._st.stationSettings : ({})
            readonly property bool _haveSet: Object.keys(_set).length > 0
            readonly property string lockReason: {
                if (!pl._st) return qsTr("Tether support is not available")
                if (vs.armed) return qsTr("Locked while the motors are on")
                if (!pl._st.connected || pl._st.linkLost || !pl._st.hasMonitoring) return qsTr("Connect the station to change its settings")
                if (pl._st.powerWatts > 200) return qsTr("Locked while flying (station power above 200 W)")
                if (pl._st.noPower) return qsTr("Locked: the station reports no power")
                if (pl._st.activeFrameVersion !== "Extended V1") return qsTr("These settings need station frame version Extended V1")
                return ""
            }
            readonly property bool locked: lockReason !== ""
            property string dPower: ""
            property string dLength: ""
            property bool   dEntrap: true
            property string ipText: pl._st ? pl._st.stationAddress : ""
            function load() { if (_haveSet) { dPower = String(_set.powerAlert); dLength = String(_set.lengthAlarm); dEntrap = !!_set.antiEntrapment } }
            readonly property bool dirty: _haveSet && (dPower !== String(_set.powerAlert) || dLength !== String(_set.lengthAlarm) || dEntrap !== !!_set.antiEntrapment)
            readonly property bool powerOk:  /^\d+$/.test(dPower) && Number(dPower) <= 100
            readonly property bool lengthOk: /^\d+$/.test(dLength) && Number(dLength) <= 200
            function save() {
                var draft = {}
                for (var k in _set) draft[k] = _set[k]          // keep every other station value as read
                draft.powerAlert = Number(dPower); draft.lengthAlarm = Number(dLength); draft.antiEntrapment = dEntrap
                pl._st.writeSettings(draft)
            }
            readonly property bool connLocked: vs.armed
            readonly property bool adv: QGroundControl.corePlugin.advancedMode
            readonly property var  frameNames: ["Auto", "Extended V1", "Extended V0", "Standard"]   // manager values (not translated)
            readonly property var  failsafeNames: [qsTr("Recommend landing"), qsTr("Warn only"), qsTr("Auto land")]
            property bool confirmAutoLand: false
            readonly property string connText: {
                if (!pl._st) return ""
                if (pl._st.connected && pl._st.hasMonitoring)
                    return [qsTr("OK"), pl._st.transport, pl._st.activeFrameVersion].concat(_set.serialNumber !== undefined ? [qsTr("S/N %1").arg(_set.serialNumber)] : []).join(" · ")
                if (pl._st.lastError !== "") return pl._st.lastError
                if (!pl._st.enabled) return qsTr("Turn on the tether station first")
                if (pl._st.linkLost || pl._st.reconnectAttempt > 0) return qsTr("No reply · trying again (%1)").arg(pl._st.reconnectAttempt)
                if (pl._st.noReply) return qsTr("No reply from the station")
                return qsTr("The tablet must be on the station's network")
            }
            function validPort(v) { return /^\d{1,5}$/.test(String(v).trim()) && Number(v) >= 1 && Number(v) <= 65535 }
            function validIp(v) { var p = v.trim().split("."); if (p.length !== 4) return false
                                  for (var i = 0; i < 4; i++) { if (!/^\d{1,3}$/.test(p[i]) || Number(p[i]) > 255) return false } return true }
            Connections { target: pl._st; ignoreUnknownSignals: true; function onStationSettingsChanged() { if (!tt.dirty) tt.load() } }
            Component.onCompleted: { load(); if (pl._st && !locked && !pl._st.settingsBusy) pl._st.readSettings() }
            onLockedChanged: if (!locked && pl._st && !pl._st.settingsBusy && !dirty) pl._st.readSettings()
            Settings { id: maint; category: "SafeTMaintenance"; property int intervalHours: 100 }   // same key as the removed classic Station Setup
            readonly property real _maintRatio: _set.maintenanceHours === undefined ? -1 : _set.maintenanceHours / maint.intervalHours

            BackButton { }
            Item {
                width: parent.width; height: SimpleTheme.px(60)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Tether station (SAFE-T)"); size: 40; bold: true }
                Pill { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: tt._s.t; level: tt._s.l }
            }
            Card {
                CardRow {
                    title: qsTr("Use tether station"); sub: qsTr("For tethered flights")
                    SToggle { id: stToggle; checked: !!pl._st && pl._st.enabled
                              enabled: !tt.connLocked; opacity: enabled ? 1 : 0.4
                              onToggled: { if (pl._st) pl._st.enabled = checked } }
                }
                // Connection (#317: SAFE-T over TCP or UDP). Every change is saved at once and restarts a running
                // connection (ElistairStationManager), so the rows are locked while the motors are on.
                CardRow {
                    title: qsTr("Connection type"); sub: qsTr("Station Wi-Fi uses TCP")
                    SSegmented {
                        id: trSeg; designWidth: 240
                        enabled: !tt.connLocked && !!pl._st; opacity: enabled ? 1 : 0.4
                        model: ["TCP", "UDP"]
                        currentIndex: pl._st && pl._st.transport === "UDP" ? 1 : 0
                        onActivated: { if (pl._st) pl._st.transport = ["TCP", "UDP"][index]
                                       trSeg.currentIndex = Qt.binding(function() { return pl._st && pl._st.transport === "UDP" ? 1 : 0 }) }
                    }
                }
                CardRow {
                    title: qsTr("Station IP"); sub: qsTr("Wi-Fi 192.168.4.1 · Ethernet 192.168.1.120")
                    STextField {
                        id: ipField; designWidth: 300; text: tt.ipText; maximumLength: 15
                        enabled_: !tt.connLocked
                        error: !tt.validIp(currentText)
                        onEdited: if (tt.validIp(text) && pl._st) pl._st.stationAddress = text.trim()
                    }
                }
                CardRow {
                    title: qsTr("Port"); sub: qsTr("Usually 23232 (some stations 7158)")
                    STextField {
                        id: portField; designWidth: 180; numeric: true; text: pl._st ? String(pl._st.stationPort) : ""
                        enabled_: !tt.connLocked
                        error: !tt.validPort(currentText)
                        onEdited: if (tt.validPort(text) && pl._st) pl._st.stationPort = Number(text)
                    }
                }
                CardRow {
                    title: qsTr("Connect when the app starts"); sub: qsTr("Off: tap Test to connect")
                    SToggle { id: acToggle; checked: !!pl._st && pl._st.autoConnect
                              enabled: !!pl._st && pl._st.enabled; opacity: enabled ? 1 : 0.4
                              onToggled: { if (pl._st) pl._st.autoConnect = checked } }
                }
                CardRow {
                    title: qsTr("Test connection"); sub: tt.connText
                    SButton {
                        designHeight: 72; textSize: 26; icon: "play"; text: qsTr("Test")
                        enabled_: !!pl._st && pl._st.enabled && !tt.connLocked && tt.validIp(ipField.currentText) && tt.validPort(portField.currentText)
                        onClicked: if (enabled_) {
                            pl._st.stationAddress = ipField.currentText.trim()
                            pl._st.stationPort = Number(portField.currentText)
                            if (!pl._st.connected && !pl._st.hasMonitoring) pl._st.connectStation()
                        }
                    }
                }
                // Advanced mode only: the frame version (Auto probes Extended V1 → V0 → Standard)
                CardRow {
                    visible: tt.adv
                    title: qsTr("Frame version"); sub: qsTr("Advanced mode only · Auto finds it")
                    SComboBox {
                        designWidth: 300
                        enabled: !tt.connLocked && !!pl._st; opacity: enabled ? 1 : 0.4
                        model: [qsTr("Auto"), qsTr("Extended V1"), qsTr("Extended V0"), qsTr("Standard")]
                        currentIndex: pl._st ? Math.max(0, tt.frameNames.indexOf(pl._st.frameVersion)) : 0
                        onActivated: if (pl._st) pl._st.frameVersion = tt.frameNames[index]
                    }
                }
                CardRow {
                    visible: !tt.adv
                    title: qsTr("If ground power is lost")
                    sub: qsTr("Changed in Advanced mode")
                    SText { text: tt.failsafeNames[pl._st ? pl._st.noPowerFailsafe : -1] || "—"; size: 26; bold: true }
                }
                // Advanced mode: 0 = recommend landing, 1 = warn only, 2 = auto land (sends Land without a
                // confirmation when the station reports cable integrity 2, so it asks first)
                CardRow {
                    visible: tt.adv
                    title: qsTr("If ground power is lost")
                    sub: tt.confirmAutoLand ? "" : qsTr("What the app does when the station loses ground power")
                    SSegmented {
                        id: fsSeg; designWidth: 640
                        enabled: !tt.connLocked && !!pl._st; opacity: enabled ? 1 : 0.4
                        model: tt.failsafeNames
                        currentIndex: pl._st ? pl._st.noPowerFailsafe : 0
                        onActivated: {
                            if (index === 2) tt.confirmAutoLand = true
                            else if (pl._st) { tt.confirmAutoLand = false; pl._st.noPowerFailsafe = index }
                            fsSeg.currentIndex = Qt.binding(function() { return pl._st ? pl._st.noPowerFailsafe : 0 })
                        }
                    }
                }
                Item {
                    visible: tt.adv && tt.confirmAutoLand
                    width: parent.width; height: visible ? Math.max(alText.implicitHeight, alButtons.height) : 0
                    SText {
                        id: alText; anchors.left: parent.left; anchors.right: alButtons.left; anchors.rightMargin: SimpleTheme.px(20)
                        anchors.verticalCenter: parent.verticalCenter; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.warn
                        text: qsTr("Auto land sends Land without asking when the cable has no power. Use it only for the drone tethered to this station.")
                    }
                    Row {
                        id: alButtons; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        spacing: SimpleTheme.px(12)
                        SButton { designHeight: 72; textSize: 26; text: qsTr("Cancel"); onClicked: tt.confirmAutoLand = false }
                        SButton { designHeight: 72; textSize: 26; kind: "primary"; text: qsTr("Use auto land")
                                  onClicked: { tt.confirmAutoLand = false; if (pl._st) pl._st.noPowerFailsafe = 2 } }
                    }
                }
            }
            SText { text: qsTr("MAINTENANCE"); size: 24; medium: true; color: SimpleTheme.textTertiary }
            Card {
                CardRow {
                    title: qsTr("Since last service")
                    sub: tt._set.flights !== undefined ? qsTr("%1 flights in total").arg(tt._set.flights) : ""
                    SText { text: tt._maintRatio < 0 ? qsTr("Not read") : qsTr("%1 of %2 h").arg(tt._set.maintenanceHours).arg(maint.intervalHours)
                            size: 26; bold: true; color: tt._maintRatio > 1 ? SimpleTheme.textDanger : tt._maintRatio >= 0.9 ? SimpleTheme.warn : SimpleTheme.textPrimary }
                }
                Rectangle {
                    visible: tt._maintRatio >= 0
                    width: parent.width; height: SimpleTheme.px(12); radius: height / 2; color: SimpleTheme.surfaceControl
                    Rectangle { width: parent.width * Math.min(1, Math.max(0, tt._maintRatio)); height: parent.height; radius: parent.radius
                                color: tt._maintRatio > 1 ? SimpleTheme.danger : tt._maintRatio >= 0.9 ? SimpleTheme.warn : SimpleTheme.ok }
                }
            }
            SText { text: qsTr("ALARMS (SAVED IN STATION)"); size: 24; medium: true; color: SimpleTheme.textTertiary }
            Card {
                CardRow {
                    title: qsTr("Power alert"); sub: tt.powerOk || !tt._haveSet ? qsTr("% of the station's maximum power") : qsTr("Allowed 0–100 %")
                    STextField { designWidth: 160; numeric: true; text: tt.dPower; enabled_: !tt.locked && tt._haveSet; error: !tt.powerOk && tt._haveSet; onEdited: tt.dPower = text }
                }
                CardRow {
                    title: qsTr("Cable end alert"); sub: tt.lengthOk || !tt._haveSet ? qsTr("Metres before the cable runs out") : qsTr("Allowed 0–200 m")
                    STextField { designWidth: 160; numeric: true; text: tt.dLength; enabled_: !tt.locked && tt._haveSet; error: !tt.lengthOk && tt._haveSet; onEdited: tt.dLength = text }
                }
                CardRow {
                    title: qsTr("Cable length"); sub: qsTr("Read from the station")
                    SText { text: tt._set.tetherLength !== undefined ? tt._set.tetherLength + " m" : qsTr("Not read"); size: 26; bold: true }
                }
                CardRow {
                    title: qsTr("Anti-entrapment"); sub: qsTr("Keep on — stops the winch if the cable snags")
                    SToggle { id: entrapToggle; checked: tt.dEntrap; opacity: !tt.locked && tt._haveSet ? 1 : 0.4; enabled: !tt.locked && tt._haveSet
                              onToggled: { tt.dEntrap = checked } }
                }
            }
            Row {
                spacing: SimpleTheme.px(16)
                SButton { text: qsTr("Cancel"); enabled_: tt.dirty; onClicked: tt.load() }
                SButton { kind: "primary"; text: qsTr("Save"); enabled_: tt.dirty && !tt.locked && tt.powerOk && tt.lengthOk && !(pl._st && pl._st.settingsBusy); onClicked: if (enabled_) tt.save() }
                SText {
                    anchors.verticalCenter: parent.verticalCenter; width: tt.width - SimpleTheme.px(420); wrapMode: Text.WordWrap; size: 22
                    color: tt.locked ? SimpleTheme.warn : SimpleTheme.textSecondary
                    text: tt.locked ? tt.lockReason : pl._st && pl._st.settingsBusy ? qsTr("Talking to the station…")
                        : pl._st && pl._st.settingsResult !== "" ? pl._st.settingsResult : ""
                }
            }
        }
    }

    //------------------------------------------------------------------ S55 camera & gimbal
    Component {
        id: cameraComp
        Column {
            id: cg
            spacing: SimpleTheme.px(16)
            readonly property var _s: pl.cameraStatus()
            readonly property var _video: QGroundControl.settingsManager.videoSettings
            // FC mount parameters (ArduPilot 4.3+: MNT1_PITCH_MIN/MAX in degrees; older: MNT_ANGMIN/MAX_TIL in centidegrees)
            Loader { id: fpcLoader; visible: false; active: vs.paramsReady; sourceComponent: Component { FactPanelController { } } }
            function _p(name) { var f = fpcLoader.item; return f && f.parameterExists(-1, name) ? f.getParameterFact(-1, name, false) : null }
            readonly property var  _pMin: _p("MNT1_PITCH_MIN") || _p("MNT_ANGMIN_TIL")
            readonly property var  _pMax: _p("MNT1_PITCH_MAX") || _p("MNT_ANGMAX_TIL")
            readonly property real _scale: _p("MNT1_PITCH_MIN") ? 1 : 100
            readonly property bool _canEdit: vs.connected && !vs.armed

            BackButton { }
            Item {
                width: parent.width; height: SimpleTheme.px(60)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Camera & gimbal"); size: 40; bold: true }
                Pill { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: cg._s.t; level: cg._s.l }
            }
            SText { text: qsTr("CAMERA"); size: 24; medium: true; color: SimpleTheme.textTertiary }
            Card {
                CardRow {
                    title: qsTr("Camera"); sub: qsTr("Camera type on this drone")
                    SSegmented {
                        designWidth: 460
                        model: [qsTr("Gremsy Lynx"), qsTr("NextVision")]
                        currentIndex: PayloadManager.activeType
                        onActivated: { PayloadManager.activeType = index; currentIndex = Qt.binding(function() { return PayloadManager.activeType }) }
                    }
                }
                Item {
                    width: parent.width; height: camIp.height
                    STextField {
                        id: camIp; designWidth: 360; label: qsTr("Network address"); maximumLength: 15
                        text: pl._cam ? pl._cam.ip : ""
                        onEdited: if (pl._cam) pl._cam.ip = text.trim()
                    }
                    SText {
                        anchors.left: camIp.right; anchors.leftMargin: SimpleTheme.px(24); anchors.right: camBtn.left; anchors.rightMargin: SimpleTheme.px(16)
                        anchors.bottom: parent.bottom; anchors.bottomMargin: SimpleTheme.px(20)
                        wrapMode: Text.WordWrap; size: 22; color: pl._cam && pl._cam.linkFailed ? SimpleTheme.textDanger : SimpleTheme.textSecondary
                        text: pl._cam && pl._cam.linkFailed ? qsTr("Cannot connect — check the address and the network") : qsTr("IP address of the camera on the drone's network")
                    }
                    SButton {
                        id: camBtn; anchors.right: parent.right; anchors.bottom: parent.bottom
                        designHeight: 72; textSize: 26
                        text: pl._cam && (pl._cam.connected || pl._cam.connecting) ? qsTr("Disconnect") : qsTr("Connect")
                        enabled_: !!pl._cam
                        onClicked: { if (!pl._cam) return; pl._cam.ip = camIp.currentText.trim()
                                     if (pl._cam.connected || pl._cam.connecting) pl._cam.disconnectPayload(); else pl._cam.connectPayload() }
                    }
                }
                STextField {
                    designWidth: 900; label: qsTr("Video stream (RTSP)")
                    text: cg._video.rtspUrl.valueString
                    onEdited: cg._video.rtspUrl.value = text.trim()
                }
                SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textTertiary
                        text: qsTr("Filled in automatically when the camera connects.") }
            }
            SText { text: qsTr("GIMBAL"); size: 24; medium: true; color: SimpleTheme.textTertiary }
            Card {
                CardRow {
                    visible: !!cg._pMin
                    title: qsTr("Lowest tilt"); sub: !cg._canEdit ? (vs.connected ? qsTr("Change on the ground (motors off)") : qsTr("Connect the drone to change this")) : qsTr("Straight down = −90°")
                    SStepper { enabled: cg._canEdit; opacity: enabled ? 1 : 0.4; unit: "°"; step: 5; from: -135; to: 0
                               value: cg._pMin ? Math.round(cg._pMin.rawValue / cg._scale) : -90
                               onEdited: if (cg._pMin && cg._canEdit) cg._pMin.rawValue = value * cg._scale }
                }
                CardRow {
                    visible: !!cg._pMax
                    title: qsTr("Highest tilt"); sub: qsTr("Level = 0°")
                    SStepper { enabled: cg._canEdit; opacity: enabled ? 1 : 0.4; unit: "°"; step: 5; from: -45; to: 90
                               value: cg._pMax ? Math.round(cg._pMax.rawValue / cg._scale) : 30
                               onEdited: if (cg._pMax && cg._canEdit) cg._pMax.rawValue = value * cg._scale }
                }
                SText { visible: !cg._pMin; width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                        text: vs.paramsReady ? qsTr("This drone has no gimbal tilt limit parameters.") : qsTr("Connect the drone to set the tilt limits.") }
                CardRow {
                    title: qsTr("Gimbal speed"); sub: qsTr("How fast the gimbal turns with the on-screen controls")
                    SSegmented {
                        designWidth: 460
                        model: [qsTr("Slow"), qsTr("Normal"), qsTr("Fast")]
                        currentIndex: Number(pl._custom.simpleGimbalSpeed.rawValue)
                        onActivated: { pl._custom.simpleGimbalSpeed.rawValue = index; pl.applyGimbalSpeed(index)
                                       currentIndex = Qt.binding(function() { return Number(pl._custom.simpleGimbalSpeed.rawValue) }) }
                    }
                }
            }
            SText {
                visible: QGroundControl.corePlugin.advancedMode
                width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textLink
                text: qsTr("Gimbal type, servo outputs and angle ranges: Vehicle setup › Gimbal ›")
                MouseArea { anchors.fill: parent; onClicked: simpleRoot.showVehicleSetup("gimbal") }
            }
        }
    }

    //------------------------------------------------------------------ S56 megaphone · searchlight · winch · cleaning
    // (separate Column pages, no inline component with a default alias: see CLAUDE.md gotcha)

    Component {
        id: megaphoneComp
        Column {
            spacing: SimpleTheme.px(16)
            BackButton { }
            Item {
                width: parent.width; height: SimpleTheme.px(60)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Megaphone"); size: 40; bold: true }
                Pill { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: pl.megaphoneStatus().t; level: pl.megaphoneStatus().l }
            }
            Card {
                CardRow {
                    title: qsTr("Use megaphone"); sub: qsTr("Shows the megaphone card on the flight screen")
                    SToggle { id: megaToggle; checked: !!pl._fly.enableAudioController.rawValue
                              onToggled: { pl._fly.enableAudioController.rawValue = checked } }
                }
                CardRow {
                    title: qsTr("Max volume *")
                    SStepper { value: SimplePayloadPrefs.megaphoneMaxVolume; from: 10; to: 100; step: 10; unit: "%"
                               onEdited: SimplePayloadPrefs.megaphoneMaxVolume = value }
                }
                CardRow {
                    title: qsTr("Speech language *"); sub: qsTr("For typed messages")
                    SSegmented { designWidth: 300; model: [qsTr("English"), qsTr("Korean")]; currentIndex: SimplePayloadPrefs.megaphoneLanguage
                                 onActivated: SimplePayloadPrefs.megaphoneLanguage = index }
                }
                CardRow {
                    title: qsTr("Stop sound on landing")
                    SToggle { id: muteToggle; checked: SimplePayloadPrefs.megaphoneStopOnLanding
                              onToggled: { SimplePayloadPrefs.megaphoneStopOnLanding = checked } }
                }
            }
            SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                    text: qsTr("Values marked * are kept in the app and used once the device accepts them.") }
        }
    }

    //------------------------------------------------------------------ S99 Vision LiDAR (obstacle detection)
    Component {
        id: visionComp
        Column {
            id: vl
            spacing: SimpleTheme.px(16)
            readonly property var  _mc: pl._mc
            readonly property bool _on: !!_mc && _mc.visionLidarEnabled === 1
            readonly property bool _canSend: !!pl._veh && !!_mc
            property real distM: _mc && _mc.vlValue > 0 ? _mc.vlValue / 100 : 15     // classic default 1500 cm
            Component.onCompleted: if (_mc && pl._veh) _mc.getVisionLidarState()
            // The switches show what the sensor reports. No answer within 3 s after a change: say so.
            property bool noReply: false
            Timer { id: vlWait; interval: 3000; onTriggered: vl.noReply = true }
            function sent() { noReply = false; vlWait.restart() }
            Connections {
                target: vl._mc
                ignoreUnknownSignals: true
                function onVisionLidarEnabledChanged() { vlWait.stop(); vl.noReply = false }
                function onVlOBAValueChanged()         { vlWait.stop(); vl.noReply = false }
                function onVlValueChanged()            { vlWait.stop(); vl.noReply = false }
            }
            BackButton { }
            Item {
                width: parent.width; height: SimpleTheme.px(60)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Vision LiDAR"); size: 40; bold: true }
                Pill { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: pl.visionStatus().t; level: pl.visionStatus().l }
            }
            SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                    text: qsTr("BirdCom obstacle sensor. The drone stops when something is closer than the detection distance.") }
            Card {
                opacity: vl._canSend ? 1 : 0.5
                CardRow {
                    title: qsTr("Use obstacle detection"); sub: qsTr("Turns the sensor on in the drone")
                    SToggle { id: vlOn; checked: vl._on
                              onToggled: {
                                  if (vl._canSend) {
                                      if (checked) { vl._mc.setVisionLidar(1); vl._mc.setVisionLidarValue(1); vl._mc.getVisionLidarOBAMode() }
                                      else              { vl._mc.setVisionLidarValue(0); vl._mc.setVisionLidar(0) }
                                      vl.sent()
                                  }
                              } }
                }
                CardRow {
                    title: qsTr("Stop at obstacles"); sub: qsTr("On: the drone stops and holds. Off: the drone tries to fly around (not used on company drones).")
                    opacity: vl._on ? 1 : 0.4
                    SToggle { id: vlStop; checked: !!vl._mc && vl._mc.vlOBAValue === 0
                              onToggled: {
                                  if (vl._canSend && vl._on) { vl._mc.setVisionLidarOBAMode(checked ? 0 : 1); vl.sent() }
                              } }
                }
                CardRow {
                    title: qsTr("Detection distance"); sub: qsTr("0.2 – 50 m")
                    opacity: vl._on ? 1 : 0.4
                    SStepper { value: vl.distM; from: 0.2; to: 50; step: 0.5; decimals: 1; unit: "m"; enabled_: vl._on && vl._canSend
                               onEdited: { vl.distM = value; vl._mc.setVisionLidarDistance(Math.round(value * 100)); vl.sent() } }
                }
                CardRow {
                    title: qsTr("Distance set in the sensor"); sub: qsTr("What the sensor reports back")
                    SText { text: vl._mc && vl._mc.vlValue > 0 ? (vl._mc.vlValue / 100).toFixed(1) + " m" : "—"; size: 30; bold: true }
                }
            }
            SNotice { visible: vl.noReply && !!pl._veh; width: parent.width; level: "warn"
                      text: qsTr("No reply from the Vision LiDAR. Check that it is fitted and powered.") }
            SText { visible: !pl._veh; width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                    text: qsTr("Connect the drone to change these settings.") }
        }
    }

    Component {
        id: lightComp
        Column {
            spacing: SimpleTheme.px(16)
            BackButton { }
            Item {
                width: parent.width; height: SimpleTheme.px(60)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Searchlight"); size: 40; bold: true }
                Pill { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: pl.lightStatus().t; level: pl.lightStatus().l }
            }
            Card {
                CardRow {
                    title: qsTr("Use BirdCom searchlight"); sub: qsTr("Also shows the life jacket drop on the flight screen")
                    SToggle { id: lightToggle; checked: !!pl._custom.lifeJacketEnable.rawValue
                              onToggled: { pl._custom.lifeJacketEnable.rawValue = checked } }
                }
                CardRow {
                    title: qsTr("Max brightness *")
                    SStepper { value: SimplePayloadPrefs.lightMaxBrightness; from: 10; to: 100; step: 10; unit: "%"
                               onEdited: SimplePayloadPrefs.lightMaxBrightness = value }
                }
                CardRow {
                    title: qsTr("Allow strobe *")
                    SToggle { id: strobeToggle; checked: SimplePayloadPrefs.lightStrobe
                              onToggled: { SimplePayloadPrefs.lightStrobe = checked } }
                }
                CardRow {
                    title: qsTr("Turn off on landing")
                    SToggle { id: offToggle; checked: SimplePayloadPrefs.lightOffOnLanding
                              onToggled: { SimplePayloadPrefs.lightOffOnLanding = checked } }
                }
            }
            SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                    text: qsTr("Values marked * are kept in the app and used once the device accepts them.") }
        }
    }

    Component {
        id: winchComp
        Column {
            id: wcol
            spacing: SimpleTheme.px(16)
            // test release only on the ground with the motors off (S56); in flight it is on the flight screen
            readonly property bool canTest: !!pl._veh && pl.vs.paramsReady && pl._veh.hasGripper && !pl.vs.armed
            property string tested: ""
            BackButton { }
            Item {
                width: parent.width; height: SimpleTheme.px(60)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Winch"); size: 40; bold: true }
                Pill { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: pl.winchStatus().t; level: pl.winchStatus().l }
            }
            Card {
                CardRow {
                    title: qsTr("Fitted"); sub: qsTr("Set on the drone (parameter GRIP_ENABLE) · Advanced › Parameters")
                    SText { text: pl._veh && pl.vs.paramsReady ? (pl._veh.hasGripper ? qsTr("Yes") : qsTr("No")) : "—"; size: 28; bold: true }
                }
                CardRow {
                    title: qsTr("Hold to release"); sub: qsTr("How long Release must be held on the flight screen")
                    SSegmented { designWidth: 300; model: ["1 s", "2 s", "3 s"]; currentIndex: Math.round(SimplePayloadPrefs.winchHoldMs / 1000) - 1
                                 onActivated: SimplePayloadPrefs.winchHoldMs = (index + 1) * 1000 }
                }
                CardRow {
                    title: qsTr("Lowering speed *")
                    SSegmented { designWidth: 300; model: [qsTr("Slow"), qsTr("Normal"), qsTr("Fast")]; currentIndex: SimplePayloadPrefs.winchSpeed
                                 onActivated: SimplePayloadPrefs.winchSpeed = index }
                }
                CardRow {
                    title: qsTr("Test release")
                    sub: wcol.tested !== "" ? wcol.tested : qsTr("Hook opens · on the ground, motors off")
                    SButton { designHeight: 72; textSize: 26; text: qsTr("Test"); enabled_: wcol.canTest
                              onClicked: if (wcol.canTest) { pl._veh.sendGripperAction(0); wcol.tested = qsTr("Release sent to the drone") } }
                }
            }
            SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                    text: qsTr("Values marked * are kept in the app and used once the device accepts them.") }
        }
    }

    Component {
        id: cleaningComp
        Column {
            spacing: SimpleTheme.px(16)
            BackButton { }
            Item {
                width: parent.width; height: SimpleTheme.px(60)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Cleaning device"); size: 40; bold: true }
                Pill { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Not detected"); level: "off" }
            }
            Card {
                opacity: 0.45
                CardRow {
                    title: qsTr("Spray pressure *")
                    SSegmented { designWidth: 300; model: [qsTr("Low"), qsTr("Mid"), qsTr("High")]; currentIndex: SimplePayloadPrefs.cleanPressure
                                 onActivated: SimplePayloadPrefs.cleanPressure = index }
                }
                CardRow {
                    title: qsTr("Distance to wall *")
                    SStepper { value: SimplePayloadPrefs.cleanWallDistance; from: 2.0; to: 5.0; step: 0.5; decimals: 1; unit: "m"
                               onEdited: SimplePayloadPrefs.cleanWallDistance = value }
                }
                CardRow {
                    title: qsTr("Auto stop at"); sub: qsTr("Safety limit, fixed")
                    SText { text: SimplePayloadPrefs.cleanAutoStop.toFixed(1) + " m"; size: 28; bold: true; color: SimpleTheme.textSecondary }
                }
            }
            SText {
                width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                text: qsTr("No cleaning device is connected. The card becomes active when the app supports the device.")
            }
        }
    }
}
