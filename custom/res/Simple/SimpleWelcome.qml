import QtQuick 2.12
import QGroundControl 1.0
import "."

// S57 First start · Welcome (language & units). Replaces the classic QGC first-run prompts
// ("Measurement Units", "Vehicle Information") in the Simple UI. The planning vehicle type is not
// asked: it defaults to ArduPilot multicopter (CustomPlugin::adjustSettingMetaData).
Rectangle {
    id: welcome
    readonly property var _app:    QGroundControl.settingsManager.appSettings
    readonly property var _units:  QGroundControl.settingsManager.unitsSettings
    readonly property var _custom: QGroundControl.corePlugin.settings
    property bool _metric: true
    Component.onCompleted: _metric = (_units.horizontalDistanceUnits.rawValue === 1)

    signal done()

    color: SimpleTheme.withAlpha("black", 0.55)
    MouseArea { anchors.fill: parent; onWheel: wheel.accepted = true }

    function finish() {
        SimpleTheme.applyUnitSystem(_units, _metric)
        // Mark the classic prompts as shown so they never appear, also not in Advanced mode
        _app.firstRunPromptIdsMarkIdAsShown(1)   // units
        _app.firstRunPromptIdsMarkIdAsShown(2)   // offline vehicle
        _custom.simpleWelcomeShown.rawValue = true
        done()
    }

    Rectangle {
        id: card
        width:  SimpleTheme.px(860)
        height: col.height + SimpleTheme.px(64)
        anchors.horizontalCenter: parent.horizontalCenter
        y: SimpleTheme.px(104) + (parent.height - SimpleTheme.px(104) - height) / 2
        radius: SimpleTheme.px(28)
        color:  SimpleTheme.surfaceGlass

        Column {
            id: col
            x: SimpleTheme.px(32); y: SimpleTheme.px(32)
            width: parent.width - SimpleTheme.px(64)
            spacing: SimpleTheme.px(24)

            Row {
                spacing: SimpleTheme.px(20)
                SIcon { name: "globe"; size: 72; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    width: col.width - SimpleTheme.px(92)
                    SText { text: qsTr("Welcome to alesQGC"); size: 40; bold: true }
                    SText {
                        width: parent.width; wrapMode: Text.WordWrap
                        text: qsTr("Two quick choices. You can change them later in Settings › General.")
                        size: 24; color: SimpleTheme.textSecondary
                    }
                }
            }
            SSettingRow {
                width: col.width
                title: qsTr("Language"); sub: qsTr("English, 한국어, Deutsch, Français, 日本語")
                SComboBox {
                    model: welcome._app.qLocaleLanguage.enumStrings
                    currentIndex: welcome._app.qLocaleLanguage.enumIndex
                    onActivated: welcome._app.qLocaleLanguage.value = welcome._app.qLocaleLanguage.enumValues[index]
                }
            }
            SSettingRow {
                width: col.width
                title: qsTr("Units"); sub: qsTr("Metric: m, m/s, ha, °C · Imperial: ft, mph, acres, °F")
                SSegmented {
                    designWidth: 338
                    model: [qsTr("Metric"), qsTr("Imperial")]
                    currentIndex: welcome._metric ? 0 : 1
                    onActivated: welcome._metric = (index === 0)
                }
            }
            SText {
                // Units of an already connected drone only change after a restart
                visible: QGroundControl.multiVehicleManager.activeVehicle !== null
                         && welcome._metric !== (welcome._units.horizontalDistanceUnits.rawValue === 1)
                width: col.width; wrapMode: Text.WordWrap
                text: qsTr("A drone is connected: restart alesQGC after Start to show the new units everywhere.")
                size: 22; color: SimpleTheme.warn
            }
            SText {
                width: col.width; wrapMode: Text.WordWrap
                text: qsTr("Drone type for planning without a drone: ArduPilot multicopter. A connected drone always uses its own settings.")
                size: 22; color: SimpleTheme.textSecondary
            }
            SButton {
                width: col.width
                designHeight: 88
                kind: "primary"
                text: qsTr("Start")
                onClicked: welcome.finish()
            }
        }
    }
}
