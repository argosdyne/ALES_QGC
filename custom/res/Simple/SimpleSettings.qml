/****************************************************************************
 * AQGC Simple UI — Settings (S09 Safety, S45 General, S48 About; other categories in the next version)
 ****************************************************************************/
import QtQuick 2.12
import QtQuick.Controls 2.4
import QGroundControl 1.0
import QGroundControl.FactSystem 1.0
import QGroundControl.Controls 1.0
import "."

Rectangle {
    id: page
    property var    vs
    property string category: "general"
    readonly property bool _adv: QGroundControl.corePlugin.advancedMode
    on_AdvChanged: if (!_adv && ["flyscreen", "video", "plan", "datalogs", "devices", "gamepad"].indexOf(category) >= 0) category = "general"
    property bool   mapDownload: false     // S46 › Download new area (full screen)
    property bool   myZones:     false     // S32 › My flight zones (full screen)
    color: SimpleTheme.bgBase

    MouseArea { anchors.fill: parent }

    readonly property var _app:     QGroundControl.settingsManager.appSettings
    readonly property var _units:   QGroundControl.settingsManager.unitsSettings
    readonly property var _flyView: QGroundControl.settingsManager.flyViewSettings
    readonly property var _custom:  QGroundControl.corePlugin.settings

    // Header
    Rectangle {
        id: header
        width: parent.width; height: SimpleTheme.px(104)
        color: SimpleTheme.surfaceGlass
        Row {
            anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
            spacing: SimpleTheme.px(20)
            SButton { designHeight: 80; icon: "back"; text: qsTr("Back"); textSize: 26; onClicked: simpleRoot.showFly() }
            SText { text: qsTr("Settings"); size: 34; bold: true; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // Categories
    Rectangle {
        id: cats
        anchors.top: header.bottom; anchors.bottom: parent.bottom
        width: SimpleTheme.px(520)
        color: SimpleTheme.surfaceGlass
        Column {
            anchors.fill: parent
            anchors.margins: SimpleTheme.px(20)
            spacing: SimpleTheme.px(8)
            Repeater {
                model: [
                    { key: "general",    icon: "sliders", title: qsTr("General") },
                    { key: "safety",     icon: "home",    title: qsTr("Safety") },
                    { key: "maps",       icon: "map",     title: qsTr("Map & flight zones") },
                    { key: "connection", icon: "link",    title: qsTr("Connection") },
                    { key: "payloads",   icon: "grid",    title: qsTr("Payloads") },
                    { key: "rid",        icon: "rid",     title: qsTr("Remote ID") },
                    { key: "about",      icon: "help",    title: qsTr("About & support") }
                ]
                Rectangle {
                    width: parent.width; height: SimpleTheme.px(page._adv ? 72 : 88); radius: SimpleTheme.px(18)
                    color: (page.category === modelData.key || (modelData.key === "about" && (page.category === "licenses" || page.category === "privacy"))
                            || (modelData.key === "connection" && page.category === "linksec")) ? SimpleTheme.brandGreen : "transparent"
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                        spacing: SimpleTheme.px(18)
                        SIcon { name: modelData.icon; size: 40; anchors.verticalCenter: parent.verticalCenter }
                        SText { text: modelData.title; size: 30; medium: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { anchors.fill: parent; onClicked: page.category = modelData.key }
                }
            }
            Rectangle { width: parent.width; height: 1; color: SimpleTheme.line }
            Rectangle {
                visible: !QGroundControl.corePlugin.advancedMode
                width: parent.width; height: SimpleTheme.px(88); radius: SimpleTheme.px(18); color: "transparent"
                Row {
                    anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                    spacing: SimpleTheme.px(18)
                    SIcon { name: "lock"; size: 40; color: SimpleTheme.textTertiary; anchors.verticalCenter: parent.verticalCenter }
                    SText { text: qsTr("Advanced"); size: 30; medium: true; color: SimpleTheme.textTertiary; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { anchors.fill: parent; onClicked: simpleRoot.requestAdvanced("advanced") }
            }
            // Advanced mode: five more categories in the same frame (Figma S64 / S69, option A)
            Row {
                visible: QGroundControl.corePlugin.advancedMode
                x: SimpleTheme.px(20); height: SimpleTheme.px(52); spacing: SimpleTheme.px(12)
                SIcon { name: "layers"; size: 28; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                SText { text: qsTr("ADVANCED MODE"); size: 20; medium: true; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            }
            Repeater {
                model: QGroundControl.corePlugin.advancedMode ? [
                    { key: "flyscreen", icon: "drone",    title: qsTr("Fly screen") },
                    { key: "video",     icon: "video",    title: qsTr("Video") },
                    { key: "plan",      icon: "plan",     title: qsTr("Plan") },
                    { key: "datalogs",  icon: "folder",   title: qsTr("Data & logs") },
                    { key: "devices",   icon: "gps",      title: qsTr("Devices") }
                ] : []
                Rectangle {
                    width: parent.width; height: SimpleTheme.px(72); radius: SimpleTheme.px(18)
                    color: page.category === modelData.key || (modelData.key === "devices" && page.category === "gamepad") ? SimpleTheme.brandGreen : "transparent"
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                        spacing: SimpleTheme.px(18)
                        SIcon { name: modelData.icon; size: 36; anchors.verticalCenter: parent.verticalCenter }
                        SText { text: modelData.title; size: 28; medium: true; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { anchors.fill: parent; onClicked: page.category = modelData.key }
                }
            }
        }
    }

    // Content
    Flickable {
        id: content
        anchors.left: cats.right; anchors.leftMargin: SimpleTheme.px(60)
        anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(40)
        anchors.top: header.bottom; anchors.topMargin: SimpleTheme.px(40)
        anchors.bottom: parent.bottom
        contentHeight: loader.item ? loader.item.height + SimpleTheme.px(40) : 0
        clip: true
        Loader {
            id: loader
            width: content.width
            sourceComponent: page.category === "general" ? generalComp
                           : page.category === "safety"  ? safetyComp
                           : page.category === "connection" ? connectionComp
                           : page.category === "maps"    ? mapsComp
                           : page.category === "payloads" ? payloadsComp
                           : page.category === "rid"     ? ridComp
                           : page.category === "about"   ? aboutComp
                           : page.category === "licenses" ? licensesComp
                           : page.category === "linksec" ? linkSecComp
                           : page.category === "privacy" ? privacyComp
                           : page.category === "gamepad" ? gamepadComp
                           : ["flyscreen", "video", "plan", "datalogs", "devices"].indexOf(page.category) >= 0 ? advSettingsComp
                           : generalComp
        }
    }

    //------------------------------------------------------------------ General (S45)
    Component {
        id: generalComp
        Column {
            spacing: SimpleTheme.px(16)
            SText { text: qsTr("General"); size: 40; bold: true }
            SText { text: qsTr("Language, units and how the app looks and sounds."); size: 24; color: SimpleTheme.textSecondary }
            SSettingRow {
                title: qsTr("Language"); sub: qsTr("Changes now · Advanced mode screens after a restart")
                SComboBox {
                    model: page._app.qLocaleLanguage.enumStrings
                    currentIndex: page._app.qLocaleLanguage.enumIndex
                    onActivated: page._app.qLocaleLanguage.value = page._app.qLocaleLanguage.enumValues[index]
                }
            }
            SSettingRow {
                id: unitsRow
                property bool _restart: false
                title: qsTr("Units")
                sub: _restart ? qsTr("Restart alesQGC to show the new units everywhere") : qsTr("Height, distance, speed, area and temperature")
                SSegmented {
                    designWidth: 338
                    model: [qsTr("Metric"), qsTr("Imperial")]
                    currentIndex: page._units.horizontalDistanceUnits.rawValue === 1 ? 0 : 1
                    onActivated: if (SimpleTheme.applyUnitSystem(page._units, index === 0)) unitsRow._restart = true
                }
            }
            SSettingRow {
                title: qsTr("Text size"); sub: qsTr("Large makes every label bigger in flight screens")
                SSegmented {
                    designWidth: 338
                    model: [qsTr("Normal"), qsTr("Large")]
                    currentIndex: page._custom.simpleLargeText.rawValue ? 1 : 0
                    onActivated: page._custom.simpleLargeText.rawValue = (index === 1)
                }
            }
            SSettingRow {
                title: qsTr("Voice alerts"); sub: qsTr("Speaks warnings like low battery or signal lost")
                SToggle { checked: !page._app.audioMuted.rawValue; onToggled: page._app.audioMuted.rawValue = !checked }
            }
            SSettingRow {
                title: qsTr("Start screen"); sub: qsTr("What you see when the app opens")
                SSegmented {
                    designWidth: 338
                    model: [qsTr("Fly"), qsTr("Plan")]
                    currentIndex: page._custom.simpleStartScreen.rawValue
                    onActivated: page._custom.simpleStartScreen.rawValue = index
                }
            }
        }
    }

    //------------------------------------------------------------------ Safety (S09) — writes FC parameters on the ground only
    Component {
        id: safetyComp
        Column {
            id: safety
            spacing: SimpleTheme.px(16)
            readonly property bool  _canEdit:   vs.connected && !vs.armed
            readonly property bool  _apm:       vs.present && vs.vehicle.apmFirmware
            readonly property string _lockMsg:  !vs.connected ? qsTr("Connect the drone to change this") : qsTr("Change on the ground (motors off)")

            // Created once parameters are ready so it binds to the connected vehicle
            Loader { id: fpcLoader; visible: false; active: vs.paramsReady; sourceComponent: Component { FactPanelController { } } }
            function _p(name) { var f = fpcLoader.item; return f && f.parameterExists(-1, name) ? f.getParameterFact(-1, name, false) : null }
            readonly property var _rtlAlt:    _apm ? _p("RTL_ALT")       : _p("RTL_RETURN_ALT")
            readonly property var _fenceAlt:  _apm ? _p("FENCE_ALT_MAX") : _p("GF_MAX_VER_DIST")
            readonly property var _fenceRad:  _apm ? _p("FENCE_RADIUS")  : _p("GF_MAX_HOR_DIST")
            readonly property var _battLow:   _apm ? _p("BATT_FS_LOW_ACT") : _p("COM_LOW_BAT_ACT")
            readonly property var _linkLoss:  _apm ? _p("FS_THR_ENABLE") : _p("NAV_RCL_ACT")
            // ArduPilot RTL_ALT is in centimetres
            readonly property real _rtlScale: _apm ? 100 : 1

            // Low battery threshold: ArduPilot BATT_LOW_MAH / BATT_CAPACITY or BATT_LOW_VOLT, PX4 BAT_LOW_THR / BAT_CRIT_THR
            readonly property var _battLowMah:  _apm ? _p("BATT_LOW_MAH")  : null
            readonly property var _battCap:     _apm ? _p("BATT_CAPACITY") : null
            readonly property var _battLowVolt: _apm ? _p("BATT_LOW_VOLT") : null
            readonly property var _batLowThr:   _apm ? null : _p("BAT_LOW_THR")
            readonly property var _batCritThr:  _apm ? null : _p("BAT_CRIT_THR")

            // Plain-language text for the failsafe actions (value, warn = no protective action)
            function battAction(f) {
                if (!f) return { t: "—", warn: false }
                var v = Number(f.rawValue)
                if (_apm) {
                    switch (v) {
                    case 0: return { t: qsTr("Warning only · keeps flying"), warn: true }
                    case 1: return { t: qsTr("Land where it is"), warn: false }
                    case 2: return { t: qsTr("Return home"), warn: false }
                    case 3: return { t: qsTr("Return home by the flown path"), warn: false }
                    case 4: return { t: qsTr("Return by the flown path, or land"), warn: false }
                    case 5: return { t: qsTr("Stop motors (drone falls)"), warn: true }
                    case 6: return { t: qsTr("Go to the mission landing point, or return home"), warn: false }
                    case 7: return { t: qsTr("Stop, then land"), warn: false }
                    }
                } else {
                    switch (v) {
                    case 0: return { t: qsTr("Warning only · keeps flying"), warn: true }
                    case 2: return { t: qsTr("Land where it is"), warn: false }
                    case 3: return { t: qsTr("Return home, land if very low"), warn: false }
                    }
                }
                return { t: f.enumStringValue, warn: false }
            }
            function linkAction(f) {
                if (!f) return { t: "—", warn: false }
                var v = Number(f.rawValue)
                if (_apm) {
                    switch (v) {
                    case 0: return { t: qsTr("Nothing · keeps flying"), warn: true }
                    case 1: return { t: qsTr("Return home"), warn: false }
                    case 2: return { t: qsTr("Finish the mission, otherwise return home"), warn: false }
                    case 3: return { t: qsTr("Land where it is"), warn: false }
                    case 4: return { t: qsTr("Return home by the flown path"), warn: false }
                    case 5: return { t: qsTr("Return by the flown path, or land"), warn: false }
                    case 6: return { t: qsTr("Go to the mission landing point, or return home"), warn: false }
                    case 7: return { t: qsTr("Stop, then land"), warn: false }
                    }
                } else {
                    switch (v) {
                    case 0: return { t: qsTr("Nothing · keeps flying"), warn: true }
                    case 1: return { t: qsTr("Hover in place"), warn: false }
                    case 2: return { t: qsTr("Return home"), warn: false }
                    case 3: return { t: qsTr("Land where it is"), warn: false }
                    case 5: return { t: qsTr("Stop motors (drone falls)"), warn: true }
                    case 6: return { t: qsTr("Lock motors"), warn: true }
                    }
                }
                return { t: f.enumStringValue, warn: false }
            }
            function battThreshold() {
                if (_apm) {
                    if (_battLowMah && _battCap && Number(_battLowMah.rawValue) > 0 && Number(_battCap.rawValue) > 0)
                        return qsTr("Acts when %1 % is left").arg(Math.round(100 * Number(_battLowMah.rawValue) / Number(_battCap.rawValue)))
                    if (_battLowVolt && Number(_battLowVolt.rawValue) > 0)
                        return qsTr("Acts below %1 V").arg(Number(_battLowVolt.rawValue).toFixed(1))
                    return qsTr("No low-battery level set on the drone")
                }
                if (_batLowThr && _batCritThr)
                    return qsTr("Warning at %1 %, action at %2 %").arg(Math.round(100 * Number(_batLowThr.rawValue))).arg(Math.round(100 * Number(_batCritThr.rawValue)))
                return qsTr("Level set on the drone")
            }
            function linkDelay() {
                var f = _apm ? _p("FS_THR_VALUE") : _p("COM_RC_LOSS_T")
                if (!_apm && f) return qsTr("After %1 s without signal").arg(Number(f.rawValue).toFixed(1))
                return qsTr("When the controller signal is lost")
            }

            SText { text: qsTr("Safety"); size: 40; bold: true }
            SText { text: qsTr("What the drone does when something goes wrong. Defaults follow local rules."); size: 24; color: SimpleTheme.textSecondary }

            SSettingRow {
                title: qsTr("Return-home altitude"); sub: qsTr("The drone climbs to this height before flying home")
                locked: !safety._rtlAlt || !vs.connected; lockReason: safety._lockMsg
                SStepper {
                    unit: "m"; step: 5; from: 5; to: Number(page._flyView.guidedMaximumAltitude.rawValue)
                    value: safety._rtlAlt ? Math.round(safety._rtlAlt.rawValue / safety._rtlScale) : 50
                    onEdited: if (safety._rtlAlt) safety._rtlAlt.rawValue = value * safety._rtlScale   // allowed in flight (state rule C)
                }
            }
            SSettingRow {
                title: qsTr("Maximum altitude"); sub: qsTr("Above take-off point · EU and most countries: 120 m")
                locked: !safety._canEdit; lockReason: safety._lockMsg
                SStepper {
                    unit: "m"; step: 5; from: 10; to: 120
                    value: Number(page._flyView.guidedMaximumAltitude.rawValue)
                    onEdited: {
                        page._flyView.guidedMaximumAltitude.rawValue = value
                        if (safety._fenceAlt) safety._fenceAlt.rawValue = value
                    }
                }
            }
            SSettingRow {
                title: qsTr("Maximum distance"); sub: qsTr("Geofence radius around the home point")
                locked: !safety._canEdit || !safety._fenceRad; lockReason: safety._lockMsg
                SStepper {
                    unit: "m"; step: 50; from: 50; to: 5000
                    value: safety._fenceRad ? Math.round(safety._fenceRad.rawValue) : 500
                    onEdited: if (safety._fenceRad) safety._fenceRad.rawValue = value
                }
            }
            SSettingRow {
                id: battRow
                readonly property var _a: safety.battAction(safety._battLow)
                title: qsTr("When battery is low"); sub: safety.battThreshold() + (page._adv ? qsTr(" · change in Vehicle setup › Safety") : qsTr(" · change in Advanced mode › Vehicle setup › Safety"))
                clickable: page._adv; onClicked: simpleRoot.showVehicleSetup("safety")
                SText {
                    width: SimpleTheme.px(460); horizontalAlignment: Text.AlignRight; wrapMode: Text.WordWrap
                    text: battRow._a.t; size: 28; bold: true
                    color: battRow._a.warn ? SimpleTheme.warn : SimpleTheme.textPrimary
                }
            }
            SSettingRow {
                id: linkRow
                readonly property var _a: safety.linkAction(safety._linkLoss)
                title: qsTr("When the radio link is lost"); sub: safety.linkDelay() + (page._adv ? qsTr(" · change in Vehicle setup › Safety") : qsTr(" · change in Advanced mode › Vehicle setup › Safety"))
                clickable: page._adv; onClicked: simpleRoot.showVehicleSetup("safety")
                SText {
                    width: SimpleTheme.px(460); horizontalAlignment: Text.AlignRight; wrapMode: Text.WordWrap
                    text: linkRow._a.t; size: 28; bold: true
                    color: linkRow._a.warn ? SimpleTheme.warn : SimpleTheme.textPrimary
                }
            }
        }
    }

    //------------------------------------------------------------------ Connection (S22): radio link + RTK correction
    // Radio: Enpulse via CustomQmlInterface.arManager (same calls as Advanced › Enpulse). Band change sets the air unit,
    // then the ground unit, then restarts air and ground (decision 2026-11-15); only on the ground with motors off.
    // RTK: alesQGC NTRIP client (CustomQmlInterface.codevRTCMManager, setting rtcmSource 0 off / 1 NTRIP / 2 serial port).
    Component {
        id: connectionComp
        Column {
            id: conn
            spacing: SimpleTheme.px(16)

            // ---- radio
            readonly property var  _ar:       typeof CustomQmlInterface !== "undefined" ? CustomQmlInterface.arManager : null
            readonly property bool _m2:       !!QGroundControl.corePlugin.m2Manager
            readonly property bool _doodle:   !!_ar && _ar.version === "DoodleLabs ubus"
            readonly property bool _paired:   !!_ar && !!_ar.connected
            readonly property bool _mounted:  !!_ar && (_doodle ? _paired : !!_ar.mounted)
            readonly property bool _pairing:  !!_ar && !!_ar.binding
            readonly property bool _onGround: !vs.armed
            readonly property bool _canRadio: !_m2 && !_doodle && _mounted && !_pairing && _onGround
            readonly property var  _is24:     _ar ? _ar.is24G : undefined
            readonly property string _band:   _is24 === true ? qsTr("2.4 GHz") : _is24 === false ? qsTr("5.8 GHz") : qsTr("Band unknown")
            readonly property real _rssi:     _ar && _ar.rssiA !== undefined && Number(_ar.rssiA) > 0 ? Number(_ar.rssiA) : NaN
            property string confirm:  ""        // "" | "band24" | "band58" | "restart" | "pair"
            property string radioMsg: ""        // shown after an action, cleared by a timer
            property int    _step:    0
            property bool   _to24:    false

            function applyBand(to24) {
                _to24 = to24; _step = 0
                if (to24) _ar.enableRemote24G(); else _ar.enableRemote58G()
                bandSeq.start()
                radioMsg = to24 ? qsTr("Changing both radios to 2.4 GHz. The link drops and comes back in about a minute.")
                                : qsTr("Changing both radios to 5.8 GHz. The link drops and comes back in about a minute.")
                msgTimer.restart()
            }
            Timer {
                id: bandSeq; interval: 800; repeat: true
                onTriggered: {
                    conn._step++
                    if (conn._step === 1)      { if (conn._to24) conn._ar.enable24G(); else conn._ar.enable58G() }
                    else if (conn._step === 2) conn._ar.restartRemoteDevice()
                    else                       { conn._ar.restartDevice(); stop() }
                }
            }
            Timer { id: msgTimer; interval: 90000; onTriggered: conn.radioMsg = "" }

            // ---- RTK correction
            readonly property var  _srcFact:  page._custom.rtcmSource
            readonly property int  _srcType:  _srcFact ? Number(_srcFact.rawValue) : 0
            readonly property var  _src:      _srcType === 1 && typeof CustomQmlInterface !== "undefined" ? CustomQmlInterface.codevRTCMManager.rtcmSource : null
            // serial port source (S93, Advanced mode): SerialPortRTCMSource opens the port by itself every 3 s
            readonly property var  _ser:      _srcType === 2 && typeof CustomQmlInterface !== "undefined" ? CustomQmlInterface.codevRTCMManager.rtcmSource : null
            readonly property bool _receiving: !!_ser && !!_ser.streaming
            property int  srcChoice: _srcType === 2 ? 1 : 0       // 0 NTRIP, 1 serial port (kept while correction is off)
            function serialOn(on) {
                if (on) {
                    if (_src && (_src.isLogIn || _src.isLogIning)) _src.logOut()
                    want = false
                    _srcFact.rawValue = 2                          // creates the serial source synchronously
                    var s = CustomQmlInterface.codevRTCMManager.rtcmSource
                    var ports = QGroundControl.linkManager.serialPorts
                    if (s && s.port.valueString === "" && ports.length) s.port.value = ports[0]
                } else {
                    _srcFact.rawValue = 0
                }
            }
            function chooseSource(i) {
                if (i === srcChoice) return
                if (_srcType === 2) _srcFact.rawValue = 0          // switching turns correction off
                else rtkOff()
                srcChoice = i
            }
            readonly property bool _loggedIn: !!_src && !!_src.isLogIn
            readonly property bool _loggingIn: !!_src && !!_src.isLogIning
            readonly property string _mp:     !_src ? "" : (_src.mountpointManual.rawValue ? _src.mountpointManualValue.valueString : _src.mountpoint.valueString)
            readonly property bool _complete: !!_src && _src.host.valueString !== "" && _mp !== "" && _src.user.valueString !== "" && _src.passwd.valueString !== ""
            property bool   _tried:  false
            property string rtkMsg:  ""
            property bool   rtkErr:  false
            property bool   needFill: false     // tried to turn on with empty fields; hint until they are filled
            // The user's choice: on = keep the NTRIP client logged in. The client retries every 5 s after a failure.
            property bool   want:    false
            Component.onCompleted: want = _loggedIn || _loggingIn

            function rtkOn() {
                if (_srcType !== 1) _srcFact.rawValue = 1          // creates the NTRIP client synchronously
                var s = CustomQmlInterface.codevRTCMManager.rtcmSource
                if (!s) return
                if (!_complete) { rtkErr = false; needFill = true; rtkMsg = ""; want = false; return }
                rtkMsg = ""; rtkErr = false; needFill = false; _tried = true; want = true
                s.logIn()
            }
            function rtkOff() {
                _tried = false; rtkMsg = ""; rtkErr = false; want = false
                if (_src && (_src.isLogIn || _src.isLogIning)) _src.logOut()
            }
            function setField(fact, value) {
                fact.value = value
                if (_loggedIn) { _src.logOut(); reLogin.restart() }   // apply the change: log in again
            }
            Timer { id: reLogin; interval: 600; onTriggered: if (conn._src && conn._complete) { conn._tried = true; conn._src.logIn() } }
            Connections {
                target: conn._src
                ignoreUnknownSignals: true
                function onIsLogIningChanged() {
                    if (conn._src && !conn._src.isLogIning && !conn._src.isLogIn && conn._tried && conn.want) {
                        conn.rtkMsg = qsTr("Could not log in. Check server, port, mountpoint, user and password. Trying again every 5 s.")
                        conn.rtkErr = true
                    }
                }
                function onIsLogInChanged() {
                    if (conn._src && conn._src.isLogIn) { conn.rtkMsg = ""; conn.rtkErr = false }
                }
            }

            SText { text: qsTr("Connection"); size: 40; bold: true }
            SText { text: qsTr("Radio link and RTK correction. Payload settings are under Payloads."); size: 24; color: SimpleTheme.textSecondary }

            // ------------------------------------------------ Radio link card
            Rectangle {
                width: parent.width
                height: radioCol.height + SimpleTheme.px(48)
                radius: SimpleTheme.px(20)
                color: SimpleTheme.surfaceRaised
                Column {
                    id: radioCol
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: SimpleTheme.px(24); anchors.leftMargin: SimpleTheme.px(28)
                    spacing: SimpleTheme.px(14)
                    Item {
                        width: parent.width; height: SimpleTheme.px(52)
                        SText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: conn._m2 ? qsTr("Radio link · M2") : conn._doodle ? qsTr("Radio link · DoodleLabs") : qsTr("Radio link · Enpulse")
                            size: 30; medium: true
                        }
                        Rectangle {
                            readonly property color _c: conn._pairing ? SimpleTheme.info : !conn._mounted ? SimpleTheme.surfaceControl : conn._paired ? SimpleTheme.ok : SimpleTheme.warn
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            height: SimpleTheme.px(48); radius: SimpleTheme.px(12)
                            width: radioPill.implicitWidth + SimpleTheme.px(28)
                            color: _c
                            visible: !conn._m2
                            SText {
                                id: radioPill; anchors.centerIn: parent; size: 24; medium: true
                                color: conn._mounted && conn._paired && !conn._pairing ? SimpleTheme.bgBase : SimpleTheme.textPrimary
                                text: conn._pairing ? qsTr("Pairing…") : !conn._mounted ? qsTr("No radio") : conn._paired ? qsTr("Connected") : qsTr("Not paired")
                            }
                        }
                    }
                    SText {
                        width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                        text: conn._m2 ? qsTr("This app does not change the settings of the M2 radio.")
                            : !conn._mounted ? qsTr("No radio found. Check that the controller is on and its radio is connected.")
                            : conn._pairing ? qsTr("Pairing… Keep the drone close and turned on.")
                            : conn._band + (isNaN(conn._rssi) ? "" : " · " + qsTr("signal %1 dB").arg(-Math.round(conn._rssi)))
                              + " · " + (conn._paired ? qsTr("drone radio paired") : qsTr("drone radio not paired"))
                    }
                    Flow {
                        width: parent.width
                        spacing: SimpleTheme.px(14)
                        visible: !conn._m2 && !conn._doodle && conn.confirm === ""
                        Item {
                            width: bandLabel.implicitWidth + SimpleTheme.px(14); height: SimpleTheme.px(72)
                            SText { id: bandLabel; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Band"); size: 26; color: SimpleTheme.textSecondary }
                        }
                        SSegmented {
                            designWidth: 300
                            opacity: conn._canRadio && conn._paired ? 1 : 0.4
                            enabled: conn._canRadio && conn._paired
                            model: [qsTr("2.4 GHz"), qsTr("5.8 GHz")]
                            currentIndex: conn._is24 === true ? 0 : conn._is24 === false ? 1 : -1
                            onActivated: {
                                var want24 = index === 0
                                if (conn._is24 !== want24) conn.confirm = want24 ? "band24" : "band58"
                                // keep showing the radio's real band until the change is confirmed and applied
                                currentIndex = Qt.binding(function() { return conn._is24 === true ? 0 : conn._is24 === false ? 1 : -1 })
                            }
                        }
                        SButton { designHeight: 72; textSize: 26; text: qsTr("Pair new radio"); enabled_: conn._canRadio; onClicked: if (enabled_) conn.confirm = "pair" }
                        SButton { designHeight: 72; textSize: 26; text: qsTr("Restart radio");  enabled_: conn._canRadio; onClicked: if (enabled_) conn.confirm = "restart" }
                    }
                    // Confirm in place (destructive radio actions drop the link)
                    Rectangle {
                        visible: conn.confirm !== ""
                        width: parent.width; height: confirmCol.height + SimpleTheme.px(36)
                        radius: SimpleTheme.px(16)
                        color: SimpleTheme.withAlpha(SimpleTheme.warn, 0.18)
                        Column {
                            id: confirmCol
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: SimpleTheme.px(18)
                            spacing: SimpleTheme.px(14)
                            SText {
                                width: parent.width; wrapMode: Text.WordWrap; size: 26
                                text: conn.confirm === "band24" ? qsTr("Change both radios to 2.4 GHz? The drone and controller restart their radios. The link is lost for about a minute.")
                                    : conn.confirm === "band58" ? qsTr("Change both radios to 5.8 GHz? The drone and controller restart their radios. The link is lost for about a minute.")
                                    : conn.confirm === "pair"   ? qsTr("Pair a new radio? The current pairing ends. Put the drone's radio in pairing mode within 1 minute.")
                                    : qsTr("Restart the controller radio? The link is lost for about a minute.")
                            }
                            Row {
                                spacing: SimpleTheme.px(14)
                                SButton { designHeight: 72; textSize: 26; text: qsTr("Cancel"); onClicked: conn.confirm = "" }
                                SButton {
                                    designHeight: 72; textSize: 26; kind: "primary"
                                    enabled_: conn._canRadio
                                    text: conn.confirm === "pair" ? qsTr("Pair") : conn.confirm === "restart" ? qsTr("Restart") : qsTr("Change band")
                                    onClicked: {
                                        if (!enabled_) return
                                        var c = conn.confirm; conn.confirm = ""
                                        if (c === "band24" || c === "band58") conn.applyBand(c === "band24")
                                        else if (c === "pair") { conn._ar.pair(); conn.radioMsg = ""; }
                                        else { conn._ar.restartDevice(); conn.radioMsg = qsTr("Restarting the controller radio. The link comes back in about a minute."); msgTimer.restart() }
                                    }
                                }
                            }
                        }
                    }
                    SText {
                        visible: conn.radioMsg !== "" || (!conn._onGround && !conn._m2 && conn._mounted)
                        width: parent.width; wrapMode: Text.WordWrap; size: 22
                        color: conn.radioMsg !== "" ? SimpleTheme.textSecondary : SimpleTheme.warn
                        text: conn.radioMsg !== "" ? conn.radioMsg : qsTr("Change radio settings on the ground (motors off)")
                    }
                }
            }

            // ------------------------------------------------ RTK correction card
            Rectangle {
                width: parent.width
                height: rtkCol.height + SimpleTheme.px(48)
                radius: SimpleTheme.px(20)
                color: SimpleTheme.surfaceRaised
                Column {
                    id: rtkCol
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: SimpleTheme.px(24); anchors.leftMargin: SimpleTheme.px(28)
                    spacing: SimpleTheme.px(16)
                    Item {
                        width: parent.width; height: SimpleTheme.px(52)
                        SText { anchors.verticalCenter: parent.verticalCenter; size: 30; medium: true
                                text: conn.srcChoice === 1 ? qsTr("RTK correction · Serial port") : qsTr("RTK correction · NTRIP") }
                        Rectangle {
                            readonly property int _lock: vs.gpsLock
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            height: SimpleTheme.px(48); radius: SimpleTheme.px(12)
                            width: rtkPill.implicitWidth + SimpleTheme.px(28)
                            readonly property bool _retry: (conn.want && !conn._loggedIn && !conn._loggingIn) || (!!conn._ser && !conn._receiving)
                            color: _lock >= 6 ? SimpleTheme.ok : _lock === 5 ? SimpleTheme.warn : _retry ? SimpleTheme.warn
                                 : conn._loggingIn || conn._loggedIn ? SimpleTheme.info : SimpleTheme.surfaceControl
                            SText {
                                id: rtkPill; anchors.centerIn: parent; size: 24; medium: true
                                color: parent._lock >= 5 || parent._retry ? SimpleTheme.bgBase : SimpleTheme.textPrimary
                                text: parent._lock >= 6 ? qsTr("RTK fixed") : parent._lock === 5 ? qsTr("RTK float")
                                    : conn._loggingIn ? qsTr("Logging in…") : conn._loggedIn ? qsTr("Correction on · no RTK yet")
                                    : conn._receiving ? qsTr("Receiving · no RTK yet") : conn._ser ? qsTr("No data from the port")
                                    : parent._retry ? qsTr("Retrying…") : qsTr("Off")
                            }
                        }
                    }
                    // Source: NTRIP server | Serial port (Advanced mode only, Figma S93)
                    Row {
                        visible: page._adv
                        spacing: SimpleTheme.px(16)
                        SText { text: qsTr("Source"); size: 24; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                        SSegmented {
                            designWidth: 420
                            model: [qsTr("NTRIP server"), qsTr("Serial port")]
                            currentIndex: conn.srcChoice
                            opacity: conn._onGround ? 1 : 0.4
                            enabled: conn._onGround
                            onActivated: { conn.chooseSource(index); currentIndex = Qt.binding(function() { return conn.srcChoice }) }
                        }
                    }
                    SText {
                        visible: conn.srcChoice === 1 && !page._adv
                        width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                        text: qsTr("Correction comes from a GNSS receiver on a serial port. Turn on Advanced mode to change this.")
                    }
                    Row {
                        visible: conn.srcChoice === 1 && page._adv
                        spacing: SimpleTheme.px(20)
                        Column {
                            spacing: SimpleTheme.px(4)
                            SText { text: qsTr("Port"); size: 22; medium: true; color: SimpleTheme.textSecondary }
                            SComboBox {
                                designWidth: 520
                                readonly property var ports: {
                                    var l = QGroundControl.linkManager.serialPorts.slice()
                                    if (conn._ser && conn._ser.port.valueString !== "" && l.indexOf(conn._ser.port.valueString) < 0) l.push(conn._ser.port.valueString)
                                    return l
                                }
                                // names as the system shows them (COM4 · description), same order as serialPorts
                                readonly property var names: {
                                    var d = QGroundControl.linkManager.serialPortStrings, n = []
                                    for (var i = 0; i < ports.length; i++) n.push(i < d.length && d[i] !== "" ? d[i] : String(ports[i]))
                                    return n
                                }
                                enabled: !!conn._ser && ports.length > 0
                                opacity: enabled ? 1 : 0.5
                                model: ports.length ? names : [qsTr("No serial port found")]
                                currentIndex: conn._ser ? Math.max(0, ports.indexOf(conn._ser.port.valueString)) : 0
                                onActivated: if (conn._ser && index < ports.length) conn._ser.port.value = ports[index]
                            }
                        }
                        Column {
                            spacing: SimpleTheme.px(4)
                            SText { text: qsTr("Speed (baud)"); size: 22; medium: true; color: SimpleTheme.textSecondary }
                            SComboBox {
                                readonly property var bauds: ["4800", "9600", "19200", "38400", "57600", "115200"]
                                designWidth: 240
                                enabled: !!conn._ser
                                opacity: enabled ? 1 : 0.5
                                model: bauds
                                currentIndex: conn._ser ? Math.max(0, bauds.indexOf(conn._ser.baud.valueString)) : 5
                                onActivated: if (conn._ser) conn._ser.baud.value = parseInt(bauds[index])
                            }
                        }
                    }
                    Row {
                        visible: conn.srcChoice === 1 && page._adv
                        spacing: SimpleTheme.px(20)
                        SToggle {
                            id: serToggle
                            anchors.verticalCenter: parent.verticalCenter
                            checked: !!conn._ser
                            onToggled: { conn.serialOn(serToggle.checked); serToggle.checked = Qt.binding(function() { return !!conn._ser }) }
                        }
                        SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Use RTK correction"); size: 26 }
                    }
                    SText {
                        visible: conn.srcChoice === 1 && page._adv
                        width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
                        text: !conn._ser ? qsTr("Turn this on to choose the port. Correction data from the GNSS receiver is sent to the drone.")
                                         : qsTr("Correction data comes from a GNSS receiver on this port and is sent to the drone.")
                    }
                    Flow {
                        visible: conn.srcChoice === 0
                        width: parent.width
                        spacing: SimpleTheme.px(14)
                        STextField {
                            designWidth: 360; label: qsTr("Server"); placeholder: "ntrip.example.net"
                            enabled_: !!conn._src; text: conn._src ? conn._src.host.valueString : ""
                            onEdited: conn.setField(conn._src.host, text)
                        }
                        STextField {
                            designWidth: 120; label: qsTr("Port"); numeric: true; placeholder: "2101"
                            enabled_: !!conn._src; text: conn._src ? conn._src.port.valueString : ""
                            onEdited: conn.setField(conn._src.port, text)
                        }
                        STextField {
                            designWidth: 220; label: qsTr("Mountpoint")
                            enabled_: !!conn._src; text: conn._mp
                            onEdited: { conn._src.mountpointManual.value = true; conn.setField(conn._src.mountpointManualValue, text) }
                        }
                        STextField {
                            designWidth: 180; label: qsTr("User")
                            enabled_: !!conn._src; text: conn._src ? conn._src.user.valueString : ""
                            onEdited: conn.setField(conn._src.user, text)
                        }
                        STextField {
                            designWidth: 180; label: qsTr("Password"); password: true
                            enabled_: !!conn._src; text: conn._src ? conn._src.passwd.valueString : ""
                            onEdited: conn.setField(conn._src.passwd, text)
                        }
                    }
                    Row {
                        visible: conn.srcChoice === 0
                        spacing: SimpleTheme.px(20)
                        SToggle {
                            id: rtkToggle
                            anchors.verticalCenter: parent.verticalCenter
                            checked: conn.want
                            onToggled: {
                                if (rtkToggle.checked) conn.rtkOn(); else conn.rtkOff()
                                rtkToggle.checked = Qt.binding(function() { return conn.want })   // SToggle sets checked itself on tap
                            }
                        }
                        SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Use RTK correction"); size: 26 }
                    }
                    SText {
                        visible: conn.srcChoice === 0 && (conn.rtkMsg !== "" || !conn._src || (conn.needFill && !conn._complete))
                        width: parent.width; wrapMode: Text.WordWrap; size: 22
                        color: conn.rtkErr ? SimpleTheme.textDanger : SimpleTheme.textSecondary
                        text: conn.rtkMsg !== "" ? conn.rtkMsg
                            : !conn._src ? qsTr("Turn on RTK correction to enter the NTRIP server.")
                            : qsTr("Fill in server, mountpoint, user and password, then turn this on.")
                    }
                }
            }

            // ------------------------------------------------ Payloads moved
            SSettingRow {
                title: qsTr("Payloads")
                sub: qsTr("Camera and payload network settings moved to Settings › Payloads (detected payloads connect automatically)")
                clickable: true
                onClicked: page.category = "payloads"
                SIcon { name: "chevron"; size: 40; opacity: 0.7 }
            }

            // ------------------------------------------------ S22 Link security card → S66
            SSettingRow {
                readonly property var _sec: QGroundControl.corePlugin.linkSecurity
                readonly property int _st: _sec ? _sec.activeState : -1
                // Doodle Labs radio still on the factory password (Figma S22 card)
                readonly property var  _ar: typeof CustomQmlInterface !== "undefined" ? CustomQmlInterface.arManager : null
                readonly property bool _factory: !!_ar && _ar.version === "DoodleLabs ubus" && _ar.doodleFactoryPassword
                title: qsTr("Link security")
                sub: !_sec ? "" : _factory ? qsTr("Radio factory password still in use — open Link security") : _st === 2 ? qsTr("Drone link protected — open Link security")
                   : _st === 3 ? qsTr("Key mismatch: this app and the drone use different keys — open Link security")
                   : _sec.hasKey ? qsTr("A key is set · this drone link is not protected yet — open Link security")
                   : qsTr("Drone link not protected (no key) — open Link security")
                clickable: true
                onClicked: page.category = "linksec"
                SIcon { name: "chevron"; size: 40; opacity: 0.7 }
            }

            // ------------------------------------------------ S93 Manual connections (Advanced mode, replaces Comm Links)
            Loader {
                width: parent.width
                active: page._adv
                visible: active
                sourceComponent: Component { SimpleManualLinks {} }
            }
        }
    }

    //------------------------------------------------------------------ S95 USB gamepad (Advanced mode › Devices)
    Component {
        id: gamepadComp
        SimpleGamepad { onBackRequested: page.category = "devices" }
    }

    //------------------------------------------------------------------ S66 Link security
    Component {
        id: linkSecComp
        SimpleLinkSecurity { onBackRequested: page.category = "connection" }
    }

    //------------------------------------------------------------------ Remote ID (S47)
    // QGC RemoteIDManager + remoteIDSettings (same calls as Advanced › Remote ID). Decisions 2026-11-15: regions EU and US
    // only (Korea hidden until its format is supported); the EU operator number is entered in full with the 3 secret
    // characters, checked, and only the public 16 are saved; emergency is a manual switch. Save turns Remote ID on.
    Component {
        id: ridComp
        Column {
            id: rid
            spacing: SimpleTheme.px(16)
            readonly property var  _set:     QGroundControl.settingsManager.remoteIDSettings
            readonly property var  _veh:     QGroundControl.multiVehicleManager.activeVehicle
            readonly property var  _mgr:     _veh ? _veh.remoteIDManager : (QGroundControl.multiVehicleManager.offlineEditingVehicle ? QGroundControl.multiVehicleManager.offlineEditingVehicle.remoteIDManager : null)
            readonly property bool _enabled: !!_set.enable.rawValue
            readonly property bool _comms:   !!_veh && !!_veh.remoteIDManager && _veh.remoteIDManager.commsGood
            readonly property bool _armOk:   _comms && _veh.remoteIDManager.armStatusGood
            readonly property bool _emerg:   !!_veh && !!_veh.remoteIDManager && _veh.remoteIDManager.emergencyDeclared

            // Draft (applied on Save)
            property int    dRegion:   Number(_set.region.rawValue)          // 0 FAA (US), 1 EU
            property int    dLocation: Number(_set.locationType.rawValue)    // 1 tablet GPS (live), 2 fixed
            property string dLat:      _set.latitudeFixed.valueString
            property string dLon:      _set.longitudeFixed.valueString
            property string dAlt:      _set.altitudeFixed.valueString
            property bool   idEdited:  false
            property string savedMsg:  ""
            readonly property string _storedId: _set.operatorID.rawValue.toString()

            // EU operator number check (EN 4709-002: country code, 12 characters, check character, dash, 3 secret)
            function euIdProblem(t) {
                if (t === "") return qsTr("Required in the EU")
                var dash = t.indexOf("-") >= 0
                if (!((t.length === 20 && dash) || (t.length === 19 && !dash)))
                    return qsTr("Enter the full number: 16 characters, a dash and the 3 secret characters (for example FIN87astrdge12k8-xyz). Only the first 16 are saved.")
                if (!/^[A-Z]{3}/.test(t)) return qsTr("The number starts with the 3-letter country code in capitals, for example FIN")
                return ""   // checksum is checked by RemoteIDManager (operatorIDValid)
            }
            readonly property string idText:   idField.currentText
            readonly property bool   _idSaved: !idEdited && idText === _storedId && _storedId !== ""
            readonly property string idError:  dRegion !== 1 ? ""
                                             : _idSaved ? (_set.operatorIDValid.rawValue ? "" : qsTr("The saved number did not pass the check. Enter it again."))
                                             : euIdProblem(idText) !== "" ? euIdProblem(idText)
                                             : _set.operatorIDValid.rawValue ? "" : qsTr("The check character does not match. Check the number for typos.")
            readonly property bool fixedOk: dLocation !== 2 || (dLat !== "" && dLon !== "" && Math.abs(Number(dLat)) <= 90 && Math.abs(Number(dLon)) <= 180 && !(Number(dLat) === 0 && Number(dLon) === 0))
            readonly property bool canSave: idError === "" && fixedOk

            function save() {
                if (!canSave) return
                _set.region.rawValue = dRegion
                _set.locationType.rawValue = dRegion === 0 ? 1 : dLocation          // US: tablet GPS only
                if (dRegion === 1 && dLocation === 2) {
                    _set.latitudeFixed.rawValue = Number(dLat); _set.longitudeFixed.rawValue = Number(dLon); _set.altitudeFixed.rawValue = Number(dAlt === "" ? 0 : dAlt)
                }
                if (idEdited || idText !== _storedId) {
                    if (_mgr) _mgr.checkOperatorID(idText)
                    _set.operatorID.rawValue = idText
                }
                _set.sendOperatorID.rawValue = dRegion === 0 && idText !== ""   // EU always sends it
                if (_mgr) _mgr.setOperatorID()                                   // EU: keeps only the public 16 characters
                _set.enable.rawValue = true
                idEdited = false
                idField.text = Qt.binding(function() { return rid._storedId })
                idField.reset()                                                  // never keep the secret characters on screen
                savedMsg = qsTr("Saved. This app now sends Remote ID data to the drone.")
                savedTimer.restart()
            }
            Timer { id: savedTimer; interval: 6000; onTriggered: rid.savedMsg = "" }

            SText { text: qsTr("Remote ID"); size: 40; bold: true }
            SText { width: parent.width; wrapMode: Text.WordWrap; text: qsTr("Required in the EU and many other countries. The drone broadcasts this while flying."); size: 24; color: SimpleTheme.textSecondary }

            // Module status
            SSettingRow {
                title: qsTr("Remote ID module")
                sub: !rid._veh ? qsTr("Connect the drone to check the module")
                   : !rid._comms ? qsTr("No module found on the drone")
                   : !rid._armOk ? rid._veh.remoteIDManager.armStatusError
                   : (rid._set.basicID.valueString !== "" ? qsTr("Detected · ID %1").arg(rid._set.basicID.valueString) : qsTr("Detected"))
                     + (rid._enabled ? "" : " · " + qsTr("this app is not sending data yet, save below"))
                Rectangle {
                    readonly property color _c: !rid._veh ? SimpleTheme.surfaceControl : !rid._comms ? SimpleTheme.danger : rid._armOk && rid._enabled ? SimpleTheme.ok : SimpleTheme.warn
                    height: SimpleTheme.px(48); radius: SimpleTheme.px(12)
                    width: ridPill.implicitWidth + SimpleTheme.px(28)
                    color: _c
                    SText {
                        id: ridPill; anchors.centerIn: parent; size: 24; medium: true
                        color: rid._veh && rid._comms && (rid._armOk ? rid._enabled : true) ? SimpleTheme.bgBase : SimpleTheme.textPrimary
                        text: !rid._veh ? qsTr("Not connected") : !rid._comms ? qsTr("Not detected") : !rid._armOk ? qsTr("Not ready") : rid._enabled ? qsTr("Broadcasting") : qsTr("Off")
                    }
                }
            }

            // Operator registration number
            Rectangle {
                width: parent.width; height: opCol.height + SimpleTheme.px(44)
                radius: SimpleTheme.px(20); color: SimpleTheme.surfaceRaised
                Column {
                    id: opCol
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: SimpleTheme.px(22); anchors.leftMargin: SimpleTheme.px(28)
                    spacing: SimpleTheme.px(12)
                    SText { text: qsTr("Operator registration number"); size: 30; medium: true }
                    SText {
                        width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                        text: rid.dRegion === 1 ? qsTr("From your national aviation authority. Type the full number with the 3 secret characters; only the first 16 are saved.")
                                                : qsTr("Optional in the US. Sent with the Remote ID data when filled in.")
                    }
                    STextField {
                        id: idField
                        designWidth: 620; maximumLength: 20
                        placeholder: rid.dRegion === 1 ? "FIN87astrdge12k8-xyz" : ""
                        text: rid._storedId
                        error: rid.idError !== "" && (rid.idEdited || rid._idSaved)
                        onCurrentTextChanged: {
                            if (currentText !== rid._storedId) {
                                rid.idEdited = true
                                if (rid._mgr) rid._mgr.checkOperatorID(currentText)   // sets operatorIDValid (EU checksum)
                            }
                        }
                    }
                    SText {
                        visible: idField.error
                        width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textDanger
                        text: rid.idError
                    }
                    SText {
                        visible: rid._idSaved && rid.idError === "" && rid.dRegion === 1
                        size: 22; color: SimpleTheme.ok
                        text: qsTr("Saved and checked · secret characters are not stored")
                    }
                }
            }

            SSettingRow {
                title: qsTr("Region rules"); sub: qsTr("Sets the message format the drone sends")
                SSegmented {
                    designWidth: 300
                    model: [qsTr("EU"), qsTr("US")]
                    currentIndex: rid.dRegion === 1 ? 0 : 1
                    onActivated: {
                        rid.dRegion = index === 0 ? 1 : 0
                        if (rid.dRegion === 0) rid.dLocation = 1
                        currentIndex = Qt.binding(function() { return rid.dRegion === 1 ? 0 : 1 })
                    }
                }
            }
            SSettingRow {
                title: qsTr("Pilot location"); sub: rid.dRegion === 0 ? qsTr("The US rules use the tablet's live position") : qsTr("Where your position is taken from")
                SSegmented {
                    designWidth: 360
                    opacity: rid.dRegion === 0 ? 0.4 : 1
                    enabled: rid.dRegion === 1
                    model: [qsTr("Tablet GPS"), qsTr("Fixed point")]
                    currentIndex: rid.dLocation === 2 ? 1 : 0
                    onActivated: {
                        rid.dLocation = index === 1 ? 2 : 1
                        currentIndex = Qt.binding(function() { return rid.dLocation === 2 ? 1 : 0 })
                    }
                }
            }
            Flow {
                visible: rid.dRegion === 1 && rid.dLocation === 2
                width: parent.width
                spacing: SimpleTheme.px(14)
                STextField { designWidth: 260; label: qsTr("Latitude");  decimal: true; text: rid.dLat; error: !rid.fixedOk; onEdited: rid.dLat = text }
                STextField { designWidth: 260; label: qsTr("Longitude"); decimal: true; text: rid.dLon; error: !rid.fixedOk; onEdited: rid.dLon = text }
                STextField { designWidth: 200; label: qsTr("Altitude (m)"); decimal: true; text: rid.dAlt; onEdited: rid.dAlt = text }
            }
            SSettingRow {
                title: qsTr("Emergency status")
                sub: !rid._veh ? qsTr("Connect the drone to use this")
                   : rid._emerg ? qsTr("Others see 'emergency' now. Turn off when the emergency is over.")
                   : qsTr("Turn on in an emergency. Others see 'emergency' until you turn it off.")
                locked: !rid._veh || !rid._enabled; lockReason: !rid._veh ? qsTr("Connect the drone to use this") : qsTr("Save Remote ID settings first")
                SToggle {
                    id: emergToggle
                    checked: rid._emerg
                    onToggled: {
                        if (rid._veh) rid._veh.remoteIDManager.setEmergency(emergToggle.checked)
                        emergToggle.checked = Qt.binding(function() { return rid._emerg })
                    }
                }
            }
            Row {
                spacing: SimpleTheme.px(20)
                SButton { kind: "primary"; text: qsTr("Save"); enabled_: rid.canSave; onClicked: rid.save() }
                // Not in Figma: way back for places/drones without Remote ID (Save turns it on and it then gates take-off)
                SButton {
                    visible: rid._enabled; kind: "ghost"; text: qsTr("Turn off Remote ID")
                    onClicked: {
                        rid._set.enable.rawValue = false
                        if (rid._emerg) rid._veh.remoteIDManager.setEmergency(false)
                        rid.savedMsg = qsTr("Remote ID is off. This app no longer sends Remote ID data.")
                        savedTimer.restart()
                    }
                }
                SText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: rid.savedMsg !== "" || !rid.canSave
                    size: 24
                    color: rid.savedMsg !== "" ? SimpleTheme.ok : SimpleTheme.textSecondary
                    text: rid.savedMsg !== "" ? rid.savedMsg : !rid.fixedOk ? qsTr("Enter a valid fixed point to save") : qsTr("Fix the operator number to save")
                }
            }
        }
    }

    //------------------------------------------------------------------ About & support (S48, basic)
    Component {
        id: aboutComp
        Column {
            spacing: SimpleTheme.px(16)
            SText { text: qsTr("About & support"); size: 40; bold: true }
            SText { text: qsTr("Versions and help from ARGOSDYNE."); size: 24; color: SimpleTheme.textSecondary }
            SSettingRow { title: qsTr("alesQGC app"); sub: QGroundControl.qgcVersion }
            SSettingRow {
                title: qsTr("Drone")
                sub: vs.present ? (vs.vehicle.vehicleTypeString + " · " + vs.vehicle.firmwareTypeString + " " + vs.vehicle.firmwareMajorVersion + "." + vs.vehicle.firmwareMinorVersion + "." + vs.vehicle.firmwarePatchVersion) : qsTr("Not connected")
            }
            SSettingRow { title: qsTr("Contact support"); sub: qsTr("WhatsApp or e-mail · Mon–Fri 09:00–18:00 KST") }
            // S48 last row → S65 (security, privacy, delete my data, security log, legal & licenses)
            SSettingRow {
                title: qsTr("Security, privacy & legal"); sub: qsTr("Data on this tablet, delete my data, security log, open-source licenses")
                clickable: true; objectName: "privacyRow"
                onClicked: page.category = "privacy"
                SIcon { name: "chevron"; size: 40; opacity: 0.7 }
            }
        }
    }

    //------------------------------------------------------------------ ADVANCED MODE categories (S64, S69)
    Component {
        id: advSettingsComp
        SimpleAdvancedSettings { category: page.category; onOpenCategory: page.category = key }
    }

    //------------------------------------------------------------------ S65 Security & privacy (+ S67, security log)
    Component {
        id: privacyComp
        SimpleSecurityPrivacy { onBackRequested: page.category = "about"; onLicensesRequested: page.category = "licenses" }
    }

    //------------------------------------------------------------------ Legal & licenses (S48 › licenses)
    // Notices are bundled in custom.qrc under /simple/licenses/ (offline); the list is licenses/index.json.
    // Windows installs the same texts in <install dir>\licenses. See custom/res/Simple/licenses/README.md.
    Component {
        id: licensesComp
        Column {
            id: licPage
            property var items: []
            spacing: SimpleTheme.px(16)
            Component.onCompleted: {
                var xhr = new XMLHttpRequest()
                xhr.onreadystatechange = function() {
                    if (xhr.readyState === XMLHttpRequest.DONE) {
                        try { licPage.items = JSON.parse(xhr.responseText) } catch (e) { licPage.items = [] }
                    }
                }
                xhr.open("GET", "qrc:/simple/licenses/index.json")
                xhr.send()
            }
            SButton { designHeight: 80; kind: "ghost"; icon: "back"; text: qsTr("Security & privacy"); textSize: 26; onClicked: page.category = "privacy" }
            SText { text: qsTr("Legal & licenses"); size: 40; bold: true }
            SText { width: parent.width; wrapMode: Text.WordWrap; text: qsTr("alesQGC uses this open-source software. Tap an item to show the full license."); size: 24; color: SimpleTheme.textSecondary }
            Repeater {
                model: licPage.items
                Rectangle {
                    id: lic
                    property bool   open: false
                    property string body: ""
                    width: parent.width
                    height: licCol.height + SimpleTheme.px(36)
                    radius: SimpleTheme.px(20)
                    color: SimpleTheme.surfaceRaised
                    Column {
                        id: licCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.margins: SimpleTheme.px(18); anchors.leftMargin: SimpleTheme.px(28)
                        spacing: SimpleTheme.px(12)
                        Item {
                            width: parent.width; height: Math.max(SimpleTheme.px(80), head.implicitHeight)
                            Column {
                                id: head
                                anchors.left: parent.left; anchors.right: chev.left; anchors.verticalCenter: parent.verticalCenter
                                SText { width: parent.width; text: modelData.name; size: 30; medium: true }
                                SText { width: parent.width; text: (modelData.version ? modelData.version + " · " : "") + modelData.license; size: 24; color: SimpleTheme.textSecondary }
                                SText { width: parent.width; text: modelData.used; size: 22; color: SimpleTheme.textTertiary; visible: text !== "" }
                            }
                            SIcon { id: chev; name: "chevron"; size: 40; opacity: 0.7; rotation: lic.open ? 90 : 0
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    lic.open = !lic.open
                                    if (lic.open && lic.body === "") {
                                        var xhr = new XMLHttpRequest()
                                        xhr.onreadystatechange = function() {
                                            if (xhr.readyState === XMLHttpRequest.DONE) lic.body = xhr.responseText
                                        }
                                        xhr.open("GET", "qrc:/simple/licenses/" + modelData.file)
                                        xhr.send()
                                    }
                                }
                            }
                        }
                        SText {
                            visible: lic.open
                            width: parent.width - SimpleTheme.px(10)
                            wrapMode: Text.Wrap; elide: Text.ElideNone
                            verticalAlignment: Text.AlignTop
                            textFormat: Text.PlainText
                            text: lic.body; size: 20; color: SimpleTheme.textSecondary
                        }
                    }
                }
            }
        }
    }

    //------------------------------------------------------------------ Payloads (S52–S55): see SimplePayloadSettings.qml
    Component {
        id: payloadsComp
        SimplePayloadSettings { vs: page.vs }
    }

    //------------------------------------------------------------------ Map & flight zones (S46)
    // Map style: flightMapSettings provider/type (types from mapEngineManager.mapTypeList). Offline maps: QGC map cache
    // (mapEngineManager.tileSets). Flight zone data: see the section below (decision 2026-11-15).
    Component {
        id: mapsComp
        Column {
            id: maps
            spacing: SimpleTheme.px(16)
            readonly property var _fm:  QGroundControl.settingsManager.flightMapSettings
            readonly property var _mgr: QGroundControl.mapEngineManager
            readonly property var _types: _mgr.mapTypeList(_fm.mapProvider.value)
            function typeFor(kind) {
                var re = kind === 0 ? /satellite/i : kind === 1 ? /(road|street)/i : /hybrid/i
                for (var i = 0; i < _types.length; i++) if (re.test(_types[i])) return _types[i]
                return ""
            }
            readonly property int _cur: { var t = String(_fm.mapType.value); return t === typeFor(0) ? 0 : t === typeFor(1) ? 1 : t === typeFor(2) ? 2 : -1 }
            // QGC adds a terrain set "<name> Elevation" to every download: hide it and delete it with its map
            function userSet(o) { return !!o && !o.defaultSet && o.mapTypeStr !== QGroundControl.elevationProviderName }
            function deleteSet(ts) {
                var companion = ts.name + " Elevation", m = _mgr.tileSets, extra = []
                for (var i = 0; i < m.count; i++) { var o = m.get(i); if (o && o.name === companion && o.mapTypeStr === QGroundControl.elevationProviderName) extra.push(o) }
                _mgr.deleteTileSet(ts)
                for (var j = 0; j < extra.length; j++) _mgr.deleteTileSet(extra[j])
            }
            Component.onCompleted: _mgr.loadTileSets()

            SText { text: qsTr("Map & flight zones"); size: 40; bold: true }
            SText { text: qsTr("Map style, maps saved for offline use and flight zone data."); size: 24; color: SimpleTheme.textSecondary }

            SSettingRow {
                title: qsTr("Map style")
                sub: maps._cur < 0 ? qsTr("Current: %1 %2").arg(maps._fm.mapProvider.value).arg(maps._fm.mapType.value) : ""
                SSegmented {
                    designWidth: 420
                    model: [qsTr("Satellite"), qsTr("Street"), qsTr("Hybrid")]
                    currentIndex: maps._cur
                    onActivated: {
                        var t = maps.typeFor(index)
                        if (t !== "") maps._fm.mapType.value = t
                        currentIndex = Qt.binding(function() { return maps._cur })
                    }
                }
            }

            // ---- offline maps
            Item {
                width: parent.width; height: SimpleTheme.px(80)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("OFFLINE MAPS"); size: 24; medium: true; color: SimpleTheme.textTertiary }
                SButton {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    designHeight: 72; textSize: 26; icon: "plus"; text: qsTr("Download new area")
                    onClicked: page.mapDownload = true
                }
            }
            SText {
                visible: maps._userSets === 0
                width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                text: qsTr("No maps saved for offline use yet. Download an area before flying where there is no internet.")
            }
            readonly property int _userSets: {
                var n = 0, m = _mgr.tileSets
                for (var i = 0; i < m.count; i++) { if (maps.userSet(m.get(i))) n++ }
                return n
            }
            Repeater {
                model: maps._mgr.tileSets
                Rectangle {
                    id: setRow
                    readonly property var  ts: object
                    readonly property int  pct: ts && ts.totalTileCount > 0 ? Math.min(100, Math.round(100 * ts.savedTileCount / ts.totalTileCount)) : 0
                    property bool confirmDel: false
                    visible: maps.userSet(ts)
                    width: parent.width
                    height: visible ? Math.max(SimpleTheme.px(100), setCol.height + SimpleTheme.px(32)) : 0
                    radius: SimpleTheme.px(20)
                    color: confirmDel ? SimpleTheme.withAlpha(SimpleTheme.danger, 0.16) : SimpleTheme.surfaceRaised
                    SIcon {
                        id: setIcon
                        anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(24); anchors.verticalCenter: parent.verticalCenter
                        name: setRow.ts && setRow.ts.downloading ? "download" : "map"; size: 40
                        color: setRow.ts && setRow.ts.downloading ? SimpleTheme.textLink : SimpleTheme.textPrimary
                    }
                    Column {
                        id: setCol
                        anchors.left: setIcon.right; anchors.leftMargin: SimpleTheme.px(20)
                        anchors.right: setBtns.left; anchors.rightMargin: SimpleTheme.px(16)
                        anchors.verticalCenter: parent.verticalCenter
                        SText { width: parent.width; text: setRow.ts ? setRow.ts.name : ""; size: 30; medium: true }
                        SText {
                            width: parent.width; wrapMode: Text.WordWrap; size: 24
                            color: setRow.confirmDel ? SimpleTheme.textDanger : setRow.ts && setRow.ts.downloading ? SimpleTheme.textLink : SimpleTheme.textSecondary
                            text: !setRow.ts ? ""
                                : setRow.confirmDel ? qsTr("Delete this map? This cannot be undone.")
                                : setRow.ts.deleting ? qsTr("Deleting…")
                                : setRow.ts.complete ? (Qt.formatDate(setRow.ts.creationDate, "yyyy-MM-dd") !== ""   // new sets get their date on the next load
                                                        ? qsTr("%1 · saved %2").arg(setRow.ts.savedTileSizeStr).arg(Qt.formatDate(setRow.ts.creationDate, "yyyy-MM-dd"))
                                                        : setRow.ts.savedTileSizeStr)
                                : setRow.ts.downloading ? qsTr("Downloading… %1 %").arg(setRow.pct)
                                : setRow.ts.errorCount > 0 ? qsTr("Stopped at %1 % · %2 tiles could not be downloaded").arg(setRow.pct).arg(setRow.ts.errorCountStr)
                                : qsTr("Paused at %1 %").arg(setRow.pct)
                        }
                    }
                    Row {
                        id: setBtns
                        anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                        spacing: SimpleTheme.px(12)
                        visible: !!setRow.ts && !setRow.ts.deleting
                        SButton { visible: !setRow.confirmDel && !!setRow.ts && setRow.ts.downloading; designHeight: 72; textSize: 26; text: qsTr("Cancel"); onClicked: setRow.ts.cancelDownloadTask() }
                        SButton { visible: !setRow.confirmDel && !!setRow.ts && !setRow.ts.downloading && !setRow.ts.complete; designHeight: 72; textSize: 26; text: qsTr("Resume"); onClicked: setRow.ts.resumeDownloadTask() }
                        SButton { visible: !setRow.confirmDel && !!setRow.ts && !setRow.ts.downloading; designHeight: 72; textSize: 26; kind: "danger"; icon: "trash"; text: qsTr("Delete"); onClicked: setRow.confirmDel = true }
                        SButton { visible: setRow.confirmDel; designHeight: 72; textSize: 26; text: qsTr("Keep"); onClicked: setRow.confirmDel = false }
                        SButton { visible: setRow.confirmDel; designHeight: 72; textSize: 26; kind: "danger"; icon: "trash"; text: qsTr("Delete"); onClicked: { setRow.confirmDel = false; maps.deleteSet(setRow.ts) } }
                    }
                }
            }

            // ---- flight zone data (decision 2026-11-15): GeoJSON file (ED-318 / Altitude Angel style) or Altitude Angel
            // online, through the existing FlightZoneManager. Changes are locked while the motors run (Figma G-01b rule).
            Item {
                id: zones
                width: parent.width; height: zoneCol.height
                readonly property var  _mgr:     mainWindow.flightZoneManager
                readonly property var  _fly:     QGroundControl.settingsManager.flyViewSettings
                readonly property bool _online:  _fly.dataType.rawValue === 1
                readonly property string _file:  String(_fly.filePath.rawValue)
                readonly property string _name:  baseName(_file).replace(/\.(geo)?json$/i, "")
                readonly property int  _count:   _mgr ? _mgr.polygons.count + _mgr.circles.count - _mgr.myZoneList.length : 0   // official zones only
                readonly property bool _armed:   !!page.vs && !!page.vs.vehicle && page.vs.vehicle.armed
                property string error: ""
                property string errorFile: ""
                property bool   confirmDel: false
                property int    _rev: 0             // re-read the file date after import / delete
                readonly property var  _date: { _rev; _count; return _mgr ? _mgr.zoneFileTime() : null }
                readonly property bool _hasFile: !_online && _file !== "" && !!_date && !isNaN(_date.getTime())
                function baseName(f) { f = String(f); return f.substring(Math.max(f.lastIndexOf("/"), f.lastIndexOf("\\")) + 1) }
                function chooseFile() { zoneFileDialog.openForLoad() }
                function setSource(online) { if (online !== _online) { _fly.dataType.rawValue = online ? 1 : 0; _mgr.reload(); _rev++ } }

                QGCFileDialog {
                    id: zoneFileDialog
                    title: qsTr("Choose a flight zone file")
                    folder: QGroundControl.settingsManager.appSettings.geoZoneSavePath
                    nameFilters: [qsTr("Zone files (*.geojson *.json)")]
                    selectExisting: true
                    onAcceptedForLoad: {
                        zones.error = zones._mgr.importZoneFile(file)
                        zones.errorFile = zones.baseName(file)
                        zones._rev++
                        close()
                    }
                }

                Column {
                    id: zoneCol
                    width: parent.width
                    spacing: SimpleTheme.px(16)
                    SText { text: qsTr("FLIGHT ZONE DATA"); size: 24; medium: true; color: SimpleTheme.textTertiary; topPadding: SimpleTheme.px(8) }
                    SSettingRow {
                        title: qsTr("Zone source")
                        sub: zones._online ? qsTr("Zones for the visible map area, downloaded while you move the map")
                                           : qsTr("A GeoJSON file (ED-318 or Altitude Angel format) saved in the app")
                        locked: zones._armed; lockReason: qsTr("Locked while the motors are running")
                        SSegmented {
                            designWidth: 420
                            model: [qsTr("File"), qsTr("Online")]
                            currentIndex: zones._online ? 1 : 0
                            onActivated: { zones.setSource(index === 1); currentIndex = Qt.binding(function() { return zones._online ? 1 : 0 }) }
                        }
                    }
                    // file in use
                    SSettingRow {
                        visible: zones._hasFile
                        title: zones._name
                        sub: qsTr("Updated %1 · %2 zones · %3").arg(zones._hasFile ? Qt.formatDate(zones._date, "yyyy-MM-dd") : "—").arg(zones._count)
                             .arg(mainWindow.simpleShowFlightZones ? qsTr("shown on map") : qsTr("hidden on map (Layers)"))
                        locked: zones._armed; lockReason: qsTr("Locked while the motors are running")
                        Row {
                            spacing: SimpleTheme.px(12)
                            SButton { visible: !zones.confirmDel; designHeight: 72; textSize: 26; icon: "folder"; text: qsTr("Replace"); onClicked: zones.chooseFile() }
                            SButton { visible: !zones.confirmDel; designHeight: 72; textSize: 26; kind: "danger"; icon: "trash"; text: qsTr("Delete"); onClicked: zones.confirmDel = true }
                            SButton { visible: zones.confirmDel; designHeight: 72; textSize: 26; text: qsTr("Keep"); onClicked: zones.confirmDel = false }
                            SButton { visible: zones.confirmDel; designHeight: 72; textSize: 26; kind: "danger"; icon: "trash"; text: qsTr("Delete")
                                      onClicked: { zones.confirmDel = false; zones._mgr.deleteZoneData(); zones._rev++ } }
                        }
                    }
                    // no file yet
                    SSettingRow {
                        visible: !zones._online && !zones._hasFile
                        title: qsTr("No flight zone file")
                        sub: qsTr("Import the zone file of the country where you fly. Zones are shown on the map and the app warns near them.")
                        locked: zones._armed; lockReason: qsTr("Locked while the motors are running")
                        SButton { designHeight: 72; textSize: 26; icon: "folder"; text: qsTr("Choose file"); onClicked: zones.chooseFile() }
                    }
                    // import failed (Figma S46: red row, the reason, nothing changed)
                    Rectangle {
                        visible: zones.error !== ""
                        width: parent.width; height: errCol.height + SimpleTheme.px(36)
                        radius: SimpleTheme.px(16); color: SimpleTheme.withAlpha(SimpleTheme.danger, 0.12)
                        border.width: SimpleTheme.px(2); border.color: SimpleTheme.danger
                        SIcon { x: SimpleTheme.px(24); anchors.verticalCenter: parent.verticalCenter; name: "warn"; size: 40; color: SimpleTheme.textDanger }
                        Column {
                            id: errCol
                            x: SimpleTheme.px(88); anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - SimpleTheme.px(88) - errBtn.width - SimpleTheme.px(44)
                            SText { text: qsTr("Import failed"); size: 28; medium: true }
                            SText { width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textDanger
                                    text: qsTr("%1: %2 Nothing was changed.").arg(zones.errorFile).arg(zones.error) }
                        }
                        SButton { id: errBtn; anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                                  designHeight: 72; textSize: 26; icon: "folder"; text: qsTr("Choose file"); enabled_: !zones._armed; onClicked: zones.chooseFile() }
                    }
                    // loading problem (file or online), e.g. no internet or the API key was refused
                    SText {
                        visible: !!zones._mgr && zones._mgr.zoneError !== ""
                        width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textDanger
                        text: zones._mgr ? zones._mgr.zoneError : ""
                    }
                    // online
                    SSettingRow {
                        visible: zones._online
                        title: qsTr("Altitude Angel")
                        // own key (secure store) or the company key built into tagged CI builds (never shown)
                        readonly property bool _ownKey: String(zones._fly.onlineLicenseKey.rawValue) !== ""
                        sub: _ownKey ? qsTr("%1 zones in the visible map area · needs internet · your API key").arg(zones._count)
                           : zones._fly.builtInAltitudeAngelKey ? qsTr("%1 zones in the visible map area · needs internet · company key").arg(zones._count)
                           : qsTr("Enter an Altitude Angel API key to load the zones")
                        locked: zones._armed; lockReason: qsTr("Locked while the motors are running")
                        Row {
                            spacing: SimpleTheme.px(12)
                            STextField {
                                designWidth: 360; label: qsTr("API key"); password: true
                                placeholder: zones._fly.builtInAltitudeAngelKey ? qsTr("Company key") : ""
                                text: zones._fly.onlineLicenseKey.rawValue
                                onEdited: { zones._fly.onlineLicenseKey.rawValue = text; zones._mgr.reload() }
                            }
                            SButton { designHeight: 72; textSize: 26; text: qsTr("Reload"); onClicked: zones._mgr.reload() }
                        }
                    }
                    SSettingRow {
                        readonly property var _mine: zones._mgr ? zones._mgr.myZoneList : []
                        readonly property int _noEntry: { var n = 0; for (var i = 0; i < _mine.length; i++) if (_mine[i].noEntry) n++; return n }
                        title: qsTr("My zones")
                        sub: _mine.length === 0 ? qsTr("Zones you draw: do not enter or warn only")
                                                : qsTr("%1 zones you drew · %2 do not enter, %3 warn only").arg(_mine.length).arg(_noEntry).arg(_mine.length - _noEntry)
                        SButton { designHeight: 72; textSize: 26; icon: "pin"; text: qsTr("Edit on map"); onClicked: page.myZones = true }
                    }
                }
            }
        }
    }

    // S46 › Download new area (full screen over the settings page)
    Loader {
        anchors.fill: parent
        z: 100
        active: page.mapDownload
        sourceComponent: Component { SimpleMapDownload { onCloseRequested: page.mapDownload = false } }
    }
    // S32 › My flight zones (full screen over the settings page)
    Loader {
        anchors.fill: parent
        z: 100
        active: page.myZones
        sourceComponent: Component { SimpleMyZones { vs: page.vs; onCloseRequested: page.myZones = false } }
    }
}
