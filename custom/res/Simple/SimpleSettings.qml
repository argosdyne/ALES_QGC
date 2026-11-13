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
                title: qsTr("Language"); sub: qsTr("Restart the app after changing the language")
                ComboBox {
                    id: langBox
                    width: SimpleTheme.px(338); height: SimpleTheme.px(80)
                    model: page._app.qLocaleLanguage.enumStrings
                    currentIndex: page._app.qLocaleLanguage.enumIndex
                    font.pixelSize: SimpleTheme.fs(26)
                    onActivated: page._app.qLocaleLanguage.value = page._app.qLocaleLanguage.enumValues[index]
                    background: Rectangle {
                        radius: SimpleTheme.px(16)
                        color:  SimpleTheme.surfaceControl
                        border.width: SimpleTheme.px(2)
                        border.color: langBox.visualFocus ? SimpleTheme.info : SimpleTheme.line
                    }
                    contentItem: SText {
                        leftPadding: SimpleTheme.px(20)
                        rightPadding: SimpleTheme.px(56)
                        text: langBox.displayText
                        size: 26
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    indicator: SIcon {
                        x: langBox.width - width - SimpleTheme.px(18)
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevron"; size: 28; rotation: 90
                        color: SimpleTheme.textSecondary
                    }
                    delegate: ItemDelegate {
                        width: langBox.width
                        height: SimpleTheme.px(64)
                        highlighted: langBox.highlightedIndex === index
                        background: Rectangle { color: highlighted ? SimpleTheme.brandGreenDark : SimpleTheme.surfaceRaised }
                        contentItem: SText { text: modelData; size: 24; verticalAlignment: Text.AlignVCenter; leftPadding: SimpleTheme.px(8) }
                    }
                    popup.background: Rectangle { color: SimpleTheme.surfaceRaised; radius: SimpleTheme.px(12); border.color: SimpleTheme.line }
                }
            }
            SSettingRow {
                title: qsTr("Units"); sub: qsTr("Height, distance and speed")
                SSegmented {
                    designWidth: 338
                    model: [qsTr("Metric"), qsTr("Imperial")]
                    currentIndex: page._units.horizontalDistanceUnits.rawValue === 1 ? 0 : 1
                    onActivated: {
                        var metric = index === 0
                        page._units.horizontalDistanceUnits.rawValue = metric ? 1 : 0
                        page._units.verticalDistanceUnits.rawValue   = metric ? 1 : 0
                        page._units.speedUnits.rawValue              = metric ? 1 : 2
                    }
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
                title: qsTr("When battery is low"); sub: qsTr("Warning at 30 %, action at 20 % · change in Advanced")
                SText { text: safety._battLow ? safety._battLow.enumStringValue : "—"; size: 28; bold: true }
            }
            SSettingRow {
                title: qsTr("When the radio link is lost"); sub: qsTr("Change in Advanced")
                SText { text: safety._linkLoss ? safety._linkLoss.enumStringValue : "—"; size: 28; bold: true }
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
