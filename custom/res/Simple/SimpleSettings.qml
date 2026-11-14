/****************************************************************************
 * AQGC Simple UI — Settings (S09 Safety, S45 General, S48 About; other categories in the next version)
 ****************************************************************************/
import QtQuick 2.12
import QtQuick.Controls 2.4
import QGroundControl 1.0
import QGroundControl.FactSystem 1.0
import "."

Rectangle {
    id: page
    property var    vs
    property string category: "general"
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
                    width: parent.width; height: SimpleTheme.px(88); radius: SimpleTheme.px(18)
                    color: page.category === modelData.key ? SimpleTheme.brandGreen : "transparent"
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
                width: parent.width; height: SimpleTheme.px(88); radius: SimpleTheme.px(18); color: "transparent"
                Row {
                    anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                    spacing: SimpleTheme.px(18)
                    SIcon { name: "lock"; size: 40; color: SimpleTheme.textTertiary; anchors.verticalCenter: parent.verticalCenter }
                    SText { text: qsTr("Advanced"); size: 30; medium: true; color: SimpleTheme.textTertiary; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { anchors.fill: parent; onClicked: simpleRoot.requestAdvanced("advanced") }
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
                           : page.category === "about"   ? aboutComp
                           : laterComp
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
                title: qsTr("When battery is low"); sub: safety.battThreshold() + qsTr(" · change in Advanced")
                SText {
                    width: SimpleTheme.px(460); horizontalAlignment: Text.AlignRight; wrapMode: Text.WordWrap
                    text: battRow._a.t; size: 28; bold: true
                    color: battRow._a.warn ? SimpleTheme.warn : SimpleTheme.textPrimary
                }
            }
            SSettingRow {
                id: linkRow
                readonly property var _a: safety.linkAction(safety._linkLoss)
                title: qsTr("When the radio link is lost"); sub: safety.linkDelay() + qsTr(" · change in Advanced")
                SText {
                    width: SimpleTheme.px(460); horizontalAlignment: Text.AlignRight; wrapMode: Text.WordWrap
                    text: linkRow._a.t; size: 28; bold: true
                    color: linkRow._a.warn ? SimpleTheme.warn : SimpleTheme.textPrimary
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
        }
    }

    //------------------------------------------------------------------ Not yet in v1
    Component {
        id: laterComp
        Column {
            spacing: SimpleTheme.px(20)
            SText { text: qsTr("Coming in the next version"); size: 40; bold: true }
            SText { width: parent.width; wrapMode: Text.WordWrap; text: qsTr("This settings page is designed (Figma S22, S46, S47, S52–S56) and will be added in version 2. Until then use Advanced › Application Settings."); size: 26; color: SimpleTheme.textSecondary }
            SButton { kind: "primary"; icon: "lock"; text: qsTr("Open Advanced settings"); onClicked: simpleRoot.requestAdvanced("settings") }
        }
    }
}
