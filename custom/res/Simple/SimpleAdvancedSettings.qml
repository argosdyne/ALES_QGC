/****************************************************************************
 * AQGC Simple UI — Settings › ADVANCED MODE categories (Figma S64 114:39051 Video, S69 118:39489 Devices, UX note
 * 114:39226; 2026-11-17). Shown only in Advanced mode, inside the Settings frame (option A).
 * Fly screen, Plan, Data & logs are not drawn in Figma: their rows follow the UX note in the same row design.
 * Devices (S69): every service that opens a port or connects by itself, off unless needed (CE RED / EN 18031).
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

Column {
    id: adv
    property string category: "video"
    spacing: SimpleTheme.px(14)

    readonly property var _sm:    QGroundControl.settingsManager
    readonly property var _app:   _sm.appSettings
    readonly property var _video: _sm.videoSettings
    readonly property var _fly:   _sm.flyViewSettings
    readonly property var _plan:  _sm.planViewSettings
    readonly property var _auto:  _sm.autoConnectSettings
    readonly property var _rtk:   _sm.rtkSettings
    readonly property var _adsb:  _sm.adsbVehicleManagerSettings

    Loader {
        width: parent.width
        sourceComponent: adv.category === "flyscreen" ? flyComp : adv.category === "plan" ? planComp
                       : adv.category === "datalogs" ? dataComp : adv.category === "devices" ? devComp : videoComp
    }

    //================================================================== Video (S64)
    Component {
        id: videoComp
        Column {
            id: vc
            spacing: SimpleTheme.px(14)
            readonly property string src: String(adv._video.videoSource.rawValue)
            readonly property var sources: ["RTSP Video Stream", "UDP h.264 Video Stream", "TCP-MPEG2 Video Stream", "Video Stream Disabled"]
            SText { text: qsTr("Video"); size: 40; bold: true }
            SText { text: qsTr("Where the video comes from and how recordings are kept."); size: 24; color: SimpleTheme.textSecondary }
            SSettingRow {
                title: qsTr("Video source"); sub: qsTr("RTSP for company cameras")
                SSegmented { designWidth: 400; model: [qsTr("RTSP"), qsTr("UDP"), qsTr("TCP"), qsTr("Off")]
                             currentIndex: Math.max(0, vc.sources.indexOf(vc.src))
                             onActivated: adv._video.videoSource.rawValue = vc.sources[index] }
            }
            SSettingRow {
                visible: src === "RTSP Video Stream"
                title: qsTr("RTSP address"); sub: qsTr("Filled in by the payload profile; change only for another camera")
                STextField { designWidth: 460; text: adv._video.rtspUrl.rawValue; onEdited: adv._video.rtspUrl.rawValue = text }
            }
            SSettingRow {
                visible: src === "UDP h.264 Video Stream"
                title: qsTr("UDP port"); sub: qsTr("Port the video arrives on")
                SFactField { fact: adv._video.udpPort; designWidth: 360 }
            }
            SSettingRow {
                visible: src === "TCP-MPEG2 Video Stream"
                title: qsTr("TCP address"); sub: qsTr("Address of the video server")
                STextField { designWidth: 460; text: adv._video.tcpUrl.rawValue; onEdited: adv._video.tcpUrl.rawValue = text }
            }
            SSettingRow { title: qsTr("Low latency"); sub: qsTr("Less delay, may stutter on a weak link"); SFactToggle { fact: adv._video.lowLatencyMode } }
            SSettingRow {
                title: qsTr("Recording format"); sub: qsTr("Format of recordings made by the app")
                SSegmented { designWidth: 300; model: ["MKV", "MOV", "MP4"]; currentIndex: Number(adv._video.recordingFormat.rawValue)
                             onActivated: adv._video.recordingFormat.rawValue = index }
            }
            SSettingRow {
                title: qsTr("Storage limit"); sub: adv._video.enableStorageLimit.rawValue ? qsTr("Oldest recordings are deleted above this size") : qsTr("No limit")
                Row {
                    spacing: SimpleTheme.px(14)
                    SStepper { visible: !!adv._video.enableStorageLimit.rawValue; anchors.verticalCenter: parent.verticalCenter
                               value: Math.round(Number(adv._video.maxVideoSize.rawValue) / 1024); from: 1; to: 500; step: 1; unit: "GB"
                               onEdited: adv._video.maxVideoSize.rawValue = value * 1024 }
                    SFactToggle { fact: adv._video.enableStorageLimit; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            SSettingRow { title: qsTr("Second video (FPV)"); sub: qsTr("Show the FPV camera stream as well"); SFactToggle { fact: adv._video.disableFPVVideo; invert: true } }
            SSettingRow {
                visible: !adv._video.disableFPVVideo.rawValue
                title: qsTr("FPV address"); sub: qsTr("Stream address of the FPV camera")
                STextField { designWidth: 460; text: adv._video.fpvUrl.rawValue; onEdited: adv._video.fpvUrl.rawValue = text }
            }
        }
    }

    //================================================================== Fly screen
    Component {
        id: flyComp
        Column {
            spacing: SimpleTheme.px(14)
            SText { text: qsTr("Fly screen"); size: 40; bold: true }
            SText { text: qsTr("Checks before take-off, the map and the instruments."); size: 24; color: SimpleTheme.textSecondary }
            SSettingRow { title: qsTr("Pre-flight checklist"); sub: qsTr("Show the checklist before take-off"); SFactToggle { fact: adv._app.useChecklist } }
            SSettingRow { visible: !!adv._app.useChecklist.rawValue; title: qsTr("Checklist must be done"); sub: qsTr("Take-off waits until every item is ticked")
                          SFactToggle { fact: adv._app.enforceChecklist } }
            SSettingRow { title: qsTr("Keep the map on the drone"); sub: qsTr("The map follows the drone"); SFactToggle { fact: adv._fly.keepMapCenteredOnVehicle } }
            SSettingRow { title: qsTr("On-screen sticks"); sub: qsTr("Virtual joystick for flying without a controller"); SFactToggle { fact: adv._app.virtualJoystick } }
            SSettingRow { visible: !!adv._app.virtualJoystick.rawValue; title: qsTr("Throttle stick returns to the middle"); sub: qsTr("On-screen throttle centres itself")
                          SFactToggle { fact: adv._app.virtualJoystickAutoCenterThrottle } }
            SSettingRow { title: qsTr("Compass: nose up"); sub: qsTr("The compass turns, the drone symbol points up"); SFactToggle { fact: adv._fly.lockNoseUpCompass } }
            SSettingRow { title: qsTr("Extra compass marks"); sub: qsTr("Home and next waypoint on the compass"); SFactToggle { fact: adv._fly.showAdditionalIndicatorsCompass } }
            SSettingRow { title: qsTr("Go here: maximum distance"); sub: qsTr("Farther taps are refused"); SFactField { fact: adv._fly.maxGoToLocationDistance; step: 100; decimals: 0; designWidth: 380 } }
            SSettingRow { title: qsTr("Go here: height reference"); sub: qsTr("What the Go here height is measured from"); SFactField { fact: adv._fly.gotoAltitudeReference; designWidth: 380 } }
            SSettingRow { title: qsTr("Custom actions"); sub: qsTr("Extra buttons from a file (classic screens)"); SFactToggle { fact: adv._fly.enableCustomActions } }
        }
    }

    //================================================================== Plan
    Component {
        id: planComp
        Column {
            spacing: SimpleTheme.px(14)
            SText { text: qsTr("Plan"); size: 40; bold: true }
            SText { text: qsTr("Defaults for new missions."); size: 24; color: SimpleTheme.textSecondary }
            SSettingRow { title: qsTr("Default mission height"); sub: qsTr("Height of new waypoints"); SFactField { fact: adv._app.defaultMissionItemAltitude; step: 5; decimals: 0; designWidth: 380 } }
            SSettingRow { title: qsTr("Take-off item not required"); sub: qsTr("Allow missions without a take-off item (not recommended)"); SFactToggle { fact: adv._plan.takeoffItemNotRequired } }
            SSettingRow { title: qsTr("Wait at each item (condition gate)"); sub: qsTr("Use CONDITION_GATE between items"); SFactToggle { fact: adv._plan.useConditionGate } }
            SSettingRow { title: qsTr("Show mission progress"); sub: qsTr("Item status during a mission (classic plan screen)"); SFactToggle { fact: adv._plan.showMissionItemStatus } }
        }
    }

    //================================================================== Data & logs
    Component {
        id: dataComp
        Column {
            id: dl
            spacing: SimpleTheme.px(14)
            property bool confirmReset: false
            property bool resetDone: false
            SText { text: qsTr("Data & logs"); size: 40; bold: true }
            SText { text: qsTr("What the app saves on this tablet."); size: 24; color: SimpleTheme.textSecondary }
            SSettingRow { title: qsTr("Save telemetry logs"); sub: qsTr("Keeps a log of each flight"); SFactToggle { fact: adv._app.telemetrySave } }
            SSettingRow { visible: !!adv._app.telemetrySave.rawValue; title: qsTr("Also on the ground"); sub: qsTr("Save logs when the motors were not started"); SFactToggle { fact: adv._app.telemetrySaveNotArmed } }
            SSettingRow { title: qsTr("CSV log"); sub: qsTr("Also save the main values as a spreadsheet file"); SFactToggle { fact: adv._app.saveCsvTelemetry } }
            SSettingRow { visible: Qt.platform.os !== "android" && Qt.platform.os !== "ios"
                          title: qsTr("Save folder"); sub: String(adv._app.savePath.rawValue) !== "" ? String(adv._app.savePath.rawValue) : qsTr("Not set")
                          SButton { objectName: "saveFolderChange"; designHeight: 64; textSize: 22; text: qsTr("Change"); onClicked: folderPicker.openAt(adv._app.savePath.rawValue) } }
            SimpleFolderPicker { id: folderPicker; fact: adv._app.savePath }     // S90
            SSettingRow { visible: Qt.platform.os === "android"; title: qsTr("Save to SD card"); sub: qsTr("Use the SD card for logs and media"); SFactToggle { fact: adv._app.androidSaveToSDCard } }
            SSettingRow {
                title: qsTr("Reset all settings"); sub: dl.resetDone ? qsTr("All settings are cleared at the next start. Restart the app.") : qsTr("Back to the first-start screen at the next start")
                Row {
                    spacing: SimpleTheme.px(10)
                    SButton { visible: !dl.confirmReset && !dl.resetDone; designHeight: 64; textSize: 22; kind: "danger"; text: qsTr("Reset…"); onClicked: dl.confirmReset = true }
                    SButton { visible: dl.confirmReset; designHeight: 64; textSize: 22; kind: "danger"; text: qsTr("Reset at next start")
                              onClicked: { QGroundControl.deleteAllSettingsNextBoot(); dl.confirmReset = false; dl.resetDone = true } }
                    SButton { visible: dl.confirmReset; designHeight: 64; textSize: 22; text: qsTr("Cancel"); onClicked: dl.confirmReset = false }
                    SButton { visible: dl.resetDone; designHeight: 64; textSize: 22; text: qsTr("Undo"); onClicked: { QGroundControl.clearDeleteAllSettingsNextBoot(); dl.resetDone = false } }
                }
            }
        }
    }

    //================================================================== Devices (S69)
    Component {
        id: devComp
        Column {
            id: dv
            spacing: SimpleTheme.px(14)
            readonly property string udpPorts: String(adv._auto.udpListenPort.rawValue).split(",").map(function(s) { return s.trim() }).filter(function(s) { return s !== "" }).join(" · ")
            readonly property bool serialOn: !!adv._auto.autoConnectPixhawk.rawValue || !!adv._auto.autoConnectSiKRadio.rawValue || !!adv._auto.autoConnectLibrePilot.rawValue
            readonly property bool nmeaOn: String(adv._auto.autoConnectNmeaPort.rawValue) === "UDP Port"
            readonly property var openNow: {
                var o = []
                if (adv._auto.autoConnectUDP.rawValue) o.push(qsTr("UDP %1 (drone link)").arg(dv.udpPorts))
                if (dv.serialOn) o.push(qsTr("USB auto-connect"))
                if (adv._app.forwardMavlink.rawValue) o.push(qsTr("MAVLink forwarding"))
                if (dv.nmeaOn) o.push(qsTr("NMEA UDP %1").arg(adv._auto.nmeaUdpPort.rawValue))
                if (adv._adsb.adsbServerConnectEnabled.rawValue) o.push(qsTr("ADSB server"))
                if (adv._auto.autoConnectRTKGPS.rawValue) o.push(qsTr("RTK base"))
                if (adv._auto.autoConnectZeroConf.rawValue) o.push(qsTr("Zero-Conf"))
                return o
            }
            function setSerial(on) { adv._auto.autoConnectPixhawk.rawValue = on; adv._auto.autoConnectSiKRadio.rawValue = on; adv._auto.autoConnectLibrePilot.rawValue = on }
            SText { text: qsTr("Devices"); size: 40; bold: true }
            SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                    text: qsTr("Network services and external devices. Turn on only what you use — each service opens a port that other devices on the network can reach.") }
            Rectangle {
                width: parent.width; height: openText.height + SimpleTheme.px(24); radius: SimpleTheme.px(14)
                color: SimpleTheme.withAlpha(SimpleTheme.info, 0.18); border.width: SimpleTheme.px(2); border.color: SimpleTheme.info
                SText { id: openText; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: SimpleTheme.px(18); anchors.verticalCenter: parent.verticalCenter
                        wrapMode: Text.WordWrap; size: 22; medium: true
                        text: dv.openNow.length ? qsTr("Open now: %1. Everything else is off.").arg(dv.openNow.join(", ")) : qsTr("Nothing is open.") }
            }
            SSettingRow { title: qsTr("Drone link · UDP %1").arg(dv.udpPorts); sub: qsTr("Needed for the Enpulse radio and SITL. Connects to drones on this network.")
                          SFactToggle { fact: adv._auto.autoConnectUDP } }
            SSettingRow { title: qsTr("Forward MAVLink to another app"); sub: adv._app.forwardMavlink.rawValue ? qsTr("Sends all drone data to %1").arg(adv._app.forwardMavlinkHostName.rawValue) : qsTr("Sends all drone data to a second address. Off by default.")
                          SFactToggle { fact: adv._app.forwardMavlink } }
            SSettingRow { visible: !!adv._app.forwardMavlink.rawValue; title: qsTr("Forward to"); sub: qsTr("host:port, e.g. localhost:14445")
                          STextField { designWidth: 380; text: adv._app.forwardMavlinkHostName.rawValue; onEdited: adv._app.forwardMavlinkHostName.rawValue = text } }
            SSettingRow { title: qsTr("NMEA GPS input · UDP"); sub: qsTr("Position from an external GPS receiver.")
                          SToggle { id: nmeaT; checked: dv.nmeaOn
                                    onToggled: { adv._auto.autoConnectNmeaPort.rawValue = checked ? "UDP Port" : "Disabled"; nmeaT.checked = Qt.binding(function() { return dv.nmeaOn }) } } }
            SSettingRow { visible: dv.nmeaOn; title: qsTr("NMEA UDP port"); sub: qsTr("Port the GPS sends to"); SFactField { fact: adv._auto.nmeaUdpPort; designWidth: 360 } }
            SSettingRow { title: qsTr("ADSB traffic server · TCP"); sub: qsTr("Aircraft positions from a local ADSB receiver."); SFactToggle { fact: adv._adsb.adsbServerConnectEnabled } }
            SSettingRow { visible: !!adv._adsb.adsbServerConnectEnabled.rawValue; title: qsTr("ADSB server"); sub: qsTr("Address and port")
                          Row { spacing: SimpleTheme.px(10)
                                STextField { designWidth: 260; text: adv._adsb.adsbServerHostAddress.rawValue; onEdited: adv._adsb.adsbServerHostAddress.rawValue = text }
                                SFactField { fact: adv._adsb.adsbServerPort; designWidth: 330 } } }
            SSettingRow { title: qsTr("RTK base station · USB"); sub: qsTr("Base receiver for RTK correction (survey-in)."); SFactToggle { fact: adv._auto.autoConnectRTKGPS } }
            SSettingRow { visible: !!adv._auto.autoConnectRTKGPS.rawValue; title: qsTr("Survey-in accuracy"); sub: qsTr("The base starts sending when it is this accurate")
                          SFactField { fact: adv._rtk.surveyInAccuracyLimit; designWidth: 380 } }
            SSettingRow { visible: !!adv._auto.autoConnectRTKGPS.rawValue; title: qsTr("Survey-in time"); sub: qsTr("Shortest time the base measures")
                          SFactField { fact: adv._rtk.surveyInMinObservationDuration; designWidth: 380 } }
            SSettingRow { title: qsTr("Serial auto-connect · USB"); sub: qsTr("Connects to a flight controller or radio plugged in by USB.")
                          SToggle { id: serT; checked: dv.serialOn; onToggled: { dv.setSerial(checked); serT.checked = Qt.binding(function() { return dv.serialOn }) } } }
            SSettingRow { title: qsTr("Zero-Conf · mDNS"); sub: qsTr("Connects to any MAVLink service announced on the network. Off by default."); SFactToggle { fact: adv._auto.autoConnectZeroConf } }
            SSettingRow { title: qsTr("M2 radio discovery · UDP 10010"); sub: qsTr("Listens for an M2 radio and closes when it is found. Always on.")
                          SStatusChip { text: qsTr("Product"); level: "info" } }
        }
    }
}
