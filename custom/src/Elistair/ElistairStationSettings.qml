import QtQuick 2.12
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.12
import Qt.labs.settings 1.0
import QGroundControl 1.0
import QGroundControl.Controls 1.0
import QGroundControl.ScreenTools 1.0

Rectangle {
    id: root
    Dialog {
        id: autoLandWarning
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: qsTr("Enable Auto land?")
        standardButtons: Dialog.Yes | Dialog.No
        contentItem: QGCLabel { text: qsTr("Cable integrity = 2 will send Land WITHOUT confirmation.\nOnly enable for the vehicle tethered to this station."); color: "#202020" }
        onAccepted: station.noPowerFailsafe = 2
        onClosed: noPowerFailsafeCombo.currentIndex = Qt.binding(function() { return root.station.noPowerFailsafe })
    }
    property var station: QGroundControl.corePlugin.elistairStationManager
    property int page: 0
    property color card: "#2b3138"
    property color muted: "#a1a9b8"
    property color teal: "#0aa27e"
    property real controlHeight: ScreenTools.defaultFontPixelHeight * 1.65
    property bool settingsDirty: changeCount > 0
    property bool draftReady: false
    property bool awaitingSave: false
    property var savedDraft: ({})
    property var currentDraft: ({ powerAlert: powerAlert.text, lengthAlarm: lengthAlarm.text,
        lengthTrigger: lengthTrigger.text, highTrigger: highTrigger.text, lowTrigger: lowTrigger.text,
        timeTrigger: timeTrigger.text, protectionLength: protectionLength.text,
        antiShockPercent: antiShockPercent.text, controlTimeout: controlTimeout.text,
        wifiSsid: wifiSsid.text, wifiPassword: wifiPassword.text,
        autoOff: autoOffEnabled.checked, protection: protectionEnabled.checked,
        antiShock: antiShockEnabled.checked, antiDragging: antiDraggingEnabled.checked,
        antiEntrapment: antiEntrapmentEnabled.checked })
    property int changeCount: {
        if (!draftReady) return 0
        var count = 0
        for (var key in currentDraft) if (currentDraft[key] !== savedDraft[key]) ++count
        return count
    }
    property int errorCount: (!powerAlert.acceptableInput ? 1 : 0) + (!lengthAlarm.acceptableInput ? 1 : 0)
        + (!lengthTrigger.acceptableInput ? 1 : 0) + (!protectionLength.acceptableInput ? 1 : 0)
        + (!antiShockPercent.acceptableInput ? 1 : 0) + (controlTimeout.validationError ? 1 : 0)
        + (!highTrigger.acceptableInput ? 1 : 0) + (!lowTrigger.acceptableInput ? 1 : 0) + (!timeTrigger.acceptableInput ? 1 : 0)
    property bool showPassword: false
    property bool lengthError: false
    property bool addressValid: validIpv4(address.text)
    property bool connectionValid: addressValid && port.acceptableInput
    property bool settingsValid: powerAlert.acceptableInput && lengthAlarm.acceptableInput
                                 && lengthTrigger.acceptableInput && protectionLength.acceptableInput
                                 && antiShockPercent.acceptableInput && controlTimeout.acceptableInput
                                 && Number(controlTimeout.text) % 50 === 0
                                 && highTrigger.acceptableInput && lowTrigger.acceptableInput && timeTrigger.acceptableInput
    property bool hasSettingsError: !settingsValid
    property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    property string settingsLockReason: {
        if (activeVehicle && activeVehicle.armed) return qsTr("Read-only: vehicle is armed. Disarm before editing settings.")
        if (!station.connected || station.linkLost || !station.hasMonitoring) return qsTr("Read-only: station link unavailable or lost.")
        if (station.powerWatts > 200) return qsTr("Read-only: station reports flight (> 200 W).")
        if (station.noPower) return qsTr("Read-only: station reports no power in flight.")
        if (station.activeFrameVersion !== "Extended V1") return qsTr("Read-only: Settings require Extended V1. Standard/V0 are not supported.")
        return ""
    }
    property bool settingsLocked: settingsLockReason.length > 0
    Settings { id: maintenancePreferences; category: "SafeTMaintenance"; property int intervalHours: 100 }
    color: "#1f2328"
    Component.onCompleted: Qt.callLater(function() {
        root.savedDraft = root.currentDraft; root.draftReady = true
        if (Object.keys(station.stationSettings).length) root.loadStationSettings()
    })
    onPageChanged: { if ((page === 1 || page === 2) && !settingsLocked && !station.settingsBusy) station.readSettings() }
    onSettingsLockedChanged: { if (!settingsLocked && (page === 1 || page === 2) && !settingsDirty && !station.settingsBusy) station.readSettings() }
    Connections {
        target: root.station
        onStationSettingsChanged: {
            if (Object.keys(root.station.stationSettings).length && (!root.settingsDirty || root.awaitingSave)) root.loadStationSettings()
        }
        onSettingsTransactionChanged: { if (!root.station.settingsBusy) root.awaitingSave = false }
    }
    function loadStationSettings() {
        var values = station.stationSettings
        if (!Object.keys(values).length) return
        draftReady = false
        powerAlert.text = String(values.powerAlert)
        lengthAlarm.text = String(values.lengthAlarm)
        protectionLength.text = String(values.protectionLength)
        antiShockPercent.text = String(values.antiShockPercent)
        lengthTrigger.text = String(values.lengthTrigger)
        highTrigger.text = String(values.highTrigger)
        lowTrigger.text = String(values.lowTrigger)
        timeTrigger.text = Number(values.timeTrigger).toFixed(1)
        controlTimeout.text = String(values.controlTimeout)
        wifiSsid.text = values.wifiSsid
        wifiPassword.text = values.wifiPassword
        autoOffEnabled.checked = values.autoOff
        protectionEnabled.checked = values.protection
        antiShockEnabled.checked = values.antiShock
        antiDraggingEnabled.checked = values.antiDragging
        antiEntrapmentEnabled.checked = values.antiEntrapment
        savedDraft = currentDraft
        draftReady = true
    }
    function fieldLabel(key) {
        var labels = { powerAlert: qsTr("Power alert"), lengthAlarm: qsTr("Length alarm"), lengthTrigger: qsTr("Length trigger"), highTrigger: qsTr("High"), lowTrigger: qsTr("Low"), timeTrigger: qsTr("Time trigger"), protectionLength: qsTr("Protection length"), antiShockPercent: qsTr("Anti-shock torque"), controlTimeout: qsTr("Control timeout"), wifiSsid: qsTr("Wi-Fi SSID"), autoOff: qsTr("Auto power-off"), protection: qsTr("Take-off/land protection"), antiShock: qsTr("Anti-shock"), antiDragging: qsTr("Anti-ground dragging"), antiEntrapment: qsTr("Anti-entrapment") }
        return labels[key] || key
    }
    function fieldValue(value) { return typeof value === "boolean" ? (value ? qsTr("ON") : qsTr("OFF")) : value }
    function commitSettings() {
        if (settingsLocked || !settingsValid || station.settingsBusy) return
        awaitingSave = true
        if (!station.writeSettings(currentDraft)) awaitingSave = false
    }
    Dialog {
        id: saveConfirmation
        title: qsTr("Save station settings?")
        modal: true
        width: Math.min(root.width * .8, ScreenTools.defaultFontPixelWidth * 55)
        x: (root.width - width) / 2
        y: Math.max(0, (root.height - height) / 2)
        standardButtons: Dialog.Ok | Dialog.Cancel
        contentItem: QGCLabel {
            color: "#202020"
            text: {
                var lines = []
                for (var key in root.currentDraft) {
                    if (root.currentDraft[key] !== root.savedDraft[key])
                        lines.push(key === "wifiPassword" ? qsTr("Wi-Fi password changed") : root.fieldLabel(key) + ": " + root.fieldValue(root.savedDraft[key]) + " -> " + root.fieldValue(root.currentDraft[key]))
                }
                return lines.join("\n")
            }
            wrapMode: Text.WordWrap
        }
        onAccepted: root.commitSettings()
    }
    function validIpv4(value) {
        var pieces = value.trim().split(".")
        if (pieces.length !== 4) return false
        for (var i = 0; i < 4; ++i) {
            if (!/^\d{1,3}$/.test(pieces[i])) return false
            var octet = Number(pieces[i])
            if (octet < 0 || octet > 255) return false
        }
        return true
    }
    function applyConnectionSettings() {
        if (!connectionValid) return
        station.stationAddress = address.text.trim()
        station.stationPort = Number(port.text)
    }
    function testConnection() {
        if (!connectionValid) return
        applyConnectionSettings()
        if (!station.connected && !station.hasMonitoring) station.connectStation()
    }
    function cancelSettings() {
        powerAlert.text = savedDraft.powerAlert
        lengthAlarm.text = savedDraft.lengthAlarm
        protectionLength.text = savedDraft.protectionLength
        antiShockPercent.text = savedDraft.antiShockPercent
        lengthTrigger.text = savedDraft.lengthTrigger
        highTrigger.text = savedDraft.highTrigger
        lowTrigger.text = savedDraft.lowTrigger
        timeTrigger.text = savedDraft.timeTrigger
        controlTimeout.text = savedDraft.controlTimeout
        wifiSsid.text = savedDraft.wifiSsid
        wifiPassword.text = savedDraft.wifiPassword
        autoOffEnabled.checked = savedDraft.autoOff
        protectionEnabled.checked = savedDraft.protection
        antiShockEnabled.checked = savedDraft.antiShock
        antiDraggingEnabled.checked = savedDraft.antiDragging
        antiEntrapmentEnabled.checked = savedDraft.antiEntrapment
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 12
            color: "#181c20"
            ColumnLayout {
                anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * .6
                Repeater {
                    model: [qsTr("Connection"), qsTr("Settings"), qsTr("Device Info")]
                    delegate: Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.1
                        color: root.page === index ? root.teal : "#505861"
                        QGCLabel { anchors.centerIn: parent; text: modelData; color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                        MouseArea { anchors.fill: parent; onClicked: root.page = index }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }

        StackLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; currentIndex: root.page
            Item {
                RowLayout {
                    anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * 1.3
                    spacing: ScreenTools.defaultFontPixelWidth
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 30
                        Layout.alignment: Qt.AlignTop; color: root.card
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * 1.1
                            QGCLabel { text: qsTr("Connection"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                            QGCCheckBox { text: qsTr("Enable SAFE-T tether station"); checked: station.enabled; onClicked: { if (!checked || root.connectionValid) { root.applyConnectionSettings(); station.enabled = checked } else checked = Qt.binding(function() { return station.enabled }) } }
                            QGCCheckBox { text: qsTr("Auto-connect on start"); checked: station.autoConnect; enabled: station.enabled; onClicked: station.autoConnect = checked }
                            GridLayout {
                                Layout.fillWidth: true; columns: 2
                                columnSpacing: ScreenTools.defaultFontPixelWidth * 2; rowSpacing: ScreenTools.defaultFontPixelHeight * .65
                                QGCLabel { text: qsTr("Name"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCTextField { text: "SAFE-T #1"; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 24; Layout.preferredHeight: root.controlHeight }
                                QGCLabel { text: qsTr("Station IP"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCTextField { id: address; validator: RegExpValidator { regExp: /^[0-9.]*$/ } maximumLength: 15; text: station.stationAddress; Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 24; Layout.preferredHeight: root.controlHeight; validationError: !root.addressValid; onEditingFinished: root.applyConnectionSettings() }
                                QGCLabel { text: qsTr("UDP port"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCTextField { id: port; text: station.stationPort; numericValuesOnly: true; validator: IntValidator { bottom: 1; top: 65535 } Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 15; Layout.preferredHeight: root.controlHeight; validationError: !acceptableInput; onEditingFinished: root.applyConnectionSettings() }
                                QGCLabel { text: qsTr("Frame version"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCComboBox {
                                    model: [qsTr("Auto"), qsTr("Extended V1"), qsTr("Extended V0"), qsTr("Standard")]
                                    currentIndex: Math.max(0, ["Auto", "Extended V1", "Extended V0", "Standard"].indexOf(station.frameVersion))
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 29; Layout.preferredHeight: root.controlHeight
                                    onActivated: station.frameVersion = ["Auto", "Extended V1", "Extended V0", "Standard"][index]
                                }
                            }
                            RowLayout {
                                QGCButton { text: qsTr("Test"); enabled: station.enabled && root.connectionValid; Layout.preferredHeight: root.controlHeight; onClicked: root.testConnection() }
                                Rectangle {
                                    visible: station.connected; width: ok.implicitWidth + ScreenTools.defaultFontPixelWidth; height: ScreenTools.defaultFontPixelHeight * 1.6
                                    radius: height / 2; color: root.teal
                                    QGCLabel { id: ok; anchors.centerIn: parent; text: qsTr("OK"); color: "white" }
                                }
                                QGCLabel { text: station.connected && station.frameVersionDetected ? qsTr("OK - %1").arg(station.activeFrameVersion) : qsTr("Waiting for station response"); color: root.muted; font.pointSize: ScreenTools.smallFontPointSize }
                            }
                            QGCLabel { Layout.fillWidth: true; text: qsTr("Ethernet, direct UDP to the station. One station per GCS. On failure, check PC IP, cable and station power."); color: root.muted; wrapMode: Text.WordWrap; font.pointSize: ScreenTools.smallFontPointSize }
                            QGCLabel { visible: !root.connectionValid; Layout.fillWidth: true; text: qsTr("Enter a valid IPv4 address and UDP port (1–65535)."); color: "#ff5e57"; wrapMode: Text.WordWrap; font.pointSize: ScreenTools.smallFontPointSize }
                            Item { Layout.fillHeight: true }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 30
                        Layout.alignment: Qt.AlignTop; color: root.card
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * 1.1
                            QGCLabel { text: qsTr("GCS behavior"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                            GridLayout {
                                columns: 3; Layout.fillWidth: true
                                QGCLabel { text: qsTr("Control rate"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("5 Hz"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("fixed"); color: root.muted }
                                QGCLabel { text: qsTr("No reply / Lost"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("1 s / 5 s"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("fixed"); color: root.muted }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                QGCLabel { text: qsTr("No-power failsafe"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                Item { Layout.fillWidth: true }
                                QGCComboBox {
                                    id: noPowerFailsafeCombo
                                    model: [qsTr("Recommend land"), qsTr("Warn only"), qsTr("Auto land")]
                                    currentIndex: station.noPowerFailsafe
                                    onActivated: { if (index === 2) autoLandWarning.open(); else station.noPowerFailsafe = index }
                                    Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 25; Layout.preferredHeight: root.controlHeight
                                }
                            }
                            QGCLabel { text: qsTr("Options: Warn only - Recommend land - Auto land"); color: root.muted; font.pointSize: ScreenTools.smallFontPointSize }
                            RowLayout {
                                QGCLabel { text: qsTr("Torque presets"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                                Item { Layout.fillWidth: true }
                                Repeater { model: [0, 30, 100]; delegate: QGCButton { text: modelData + " %"; Layout.preferredHeight: root.controlHeight; onClicked: { station.setTorqueRemote(true); station.setTorquePercent(modelData) } } }
                            }
                            QGCLabel { Layout.fillWidth: true; text: qsTr("Values apply immediately and are kept after restart."); color: root.muted; wrapMode: Text.WordWrap; font.pointSize: ScreenTools.smallFontPointSize }
                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }
            Item {
                id: settingsPage
                property real compactHeight: root.controlHeight
                property real fieldWidth: ScreenTools.defaultFontPixelWidth * 8
                property real gap: ScreenTools.defaultFontPixelWidth * 1.15
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelWidth * 1.25
                    spacing: ScreenTools.defaultFontPixelHeight * .65
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: eepromInfo.implicitHeight + ScreenTools.defaultFontPixelHeight * .6
                        radius: 4
                        color: "#258bdc"
                        QGCLabel {
                            id: eepromInfo
                            anchors.fill: parent
                            anchors.margins: ScreenTools.defaultFontPixelHeight * .3
                            text: qsTr("Stored in the station (EEPROM). Changes are written together when you press Save.") + (station.settingsReadTime ? qsTr("  Last read: ") + station.settingsReadTime : "")
                            color: "white"
                            wrapMode: Text.WordWrap
                            font.pointSize: ScreenTools.smallFontPointSize
                        }
                    }
                    Flickable {
                        id: settingsScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        // Keep the design's three columns on Android too; scroll on
                        // smaller displays rather than rearranging the groups.
                        contentWidth: Math.max(width, ScreenTools.defaultFontPixelWidth * 90)
                        contentHeight: Math.max(height, settingsColumns.implicitHeight)
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { }
                        ScrollBar.horizontal: ScrollBar { }
                        Row {
                            id: settingsColumns
                            width: settingsScroll.contentWidth
                            spacing: settingsPage.gap
                            ColumnLayout {
                                width: (parent.width - settingsPage.gap * 2) * .31
                                spacing: ScreenTools.defaultFontPixelHeight * .45
                                QGCLabel { text: qsTr("Alarms"); color: "white" }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                implicitHeight: alarmsForm.implicitHeight + settingsPage.gap * 2
                                color: "#343b41"
                                radius: 0
                                enabled: !root.settingsLocked && !station.settingsBusy
                                GridLayout {
                                    id: alarmsForm
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: settingsPage.gap
                                    columns: 3
                                    columnSpacing: settingsPage.gap
                                    rowSpacing: settingsPage.gap * .7
                                    QGCLabel { text: qsTr("Power alarm"); Layout.fillWidth: true; color: "white" }
                                    QGCLabel { text: station.stationSettings.powerAlarm !== undefined ? String(station.stationSettings.powerAlarm) : qsTr("Not read"); color: root.muted; Layout.preferredWidth: settingsPage.fieldWidth }
                                    QGCLabel { text: "W"; color: root.muted }
                                    QGCLabel { text: qsTr("Power alert"); Layout.fillWidth: true; color: "white" }
                                    QGCTextField {
                                        id: powerAlert
                                        text: "85"
                                        Layout.preferredWidth: settingsPage.fieldWidth
                                        Layout.preferredHeight: settingsPage.compactHeight
                                        numericValuesOnly: true
                                        validator: IntValidator { bottom: 0; top: 100 }
                                        validationError: !acceptableInput
                                    }
                                    QGCLabel { text: "%"; color: root.muted }
                                    QGCLabel { visible: !powerAlert.acceptableInput; text: qsTr("allowed 0-100 %"); color: "#ff5e57"; Layout.columnSpan: 3; font.pointSize: ScreenTools.smallFontPointSize }
                                    QGCLabel { text: qsTr("Length alarm"); Layout.fillWidth: true; color: "white" }
                                    QGCTextField {
                                        id: lengthAlarm
                                        text: "10"
                                        Layout.preferredWidth: settingsPage.fieldWidth
                                        Layout.preferredHeight: settingsPage.compactHeight
                                        numericValuesOnly: true
                                        validator: IntValidator { bottom: 0; top: 200 }
                                        validationError: !acceptableInput
                                    }
                                    QGCLabel { text: "m"; color: root.muted }
                                    QGCLabel { visible: !lengthAlarm.acceptableInput; text: qsTr("allowed 0-200 m"); color: "#ff5e57"; Layout.columnSpan: 3; font.pointSize: ScreenTools.smallFontPointSize }
                                }
                            }
                                QGCLabel { text: qsTr("Auto power-off"); color: "white"; Layout.topMargin: ScreenTools.defaultFontPixelHeight * .3 }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                implicitHeight: autoOffForm.implicitHeight + settingsPage.gap * 2
                                color: "#343b41"
                                radius: 0
                                enabled: !root.settingsLocked && !station.settingsBusy
                                GridLayout {
                                    id: autoOffForm
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: settingsPage.gap
                                    columns: 3
                                    columnSpacing: settingsPage.gap
                                    rowSpacing: settingsPage.gap * .7
                                    QGCCheckBox { id: autoOffEnabled; text: qsTr("Enable"); checked: true; Layout.columnSpan: 3 }
                                    QGCLabel { text: qsTr("High / Low"); Layout.fillWidth: true; color: "white" }
                                    RowLayout {
                                        Layout.columnSpan: 2
                                        spacing: ScreenTools.defaultFontPixelWidth * .5
                                        QGCTextField {
                                            id: highTrigger
                                            text: ""
                                            placeholderText: qsTr("High")
                                            Layout.preferredWidth: settingsPage.fieldWidth * .8
                                            Layout.preferredHeight: settingsPage.compactHeight
                                            showUnits: true
                                            unitsLabel: "W"
                                            numericValuesOnly: true
                                            validator: IntValidator { bottom: 0; top: 5000 }
                                            validationError: !acceptableInput
                                        }
                                        QGCTextField {
                                            id: lowTrigger
                                            text: ""
                                            placeholderText: qsTr("Low")
                                            Layout.preferredWidth: settingsPage.fieldWidth * .8
                                            Layout.preferredHeight: settingsPage.compactHeight
                                            showUnits: true
                                            unitsLabel: "W"
                                            numericValuesOnly: true
                                            validator: IntValidator { bottom: 0; top: 5000 }
                                            validationError: !acceptableInput
                                        }
                                    }
                                    QGCLabel { visible: !highTrigger.acceptableInput || !lowTrigger.acceptableInput; text: qsTr("Allowed 0-5000 W"); color: "#ff5e57"; Layout.columnSpan: 3; font.pointSize: ScreenTools.smallFontPointSize }
                                    QGCLabel { text: qsTr("Time trigger"); Layout.fillWidth: true; color: "white" }
                                    QGCTextField {
                                        id: timeTrigger
                                        text: ""
                                        Layout.preferredWidth: settingsPage.fieldWidth
                                        Layout.preferredHeight: settingsPage.compactHeight
                                        numericValuesOnly: true
                                        validator: DoubleValidator { bottom: 0.1; top: 25.5; decimals: 1; notation: DoubleValidator.StandardNotation; locale: "C" }
                                        validationError: !acceptableInput
                                    }
                                    QGCLabel { text: "s"; color: root.muted }
                                    QGCLabel { visible: !timeTrigger.acceptableInput; text: qsTr("Allowed 0.1-25.5 s (step 0.1 s)"); color: "#ff5e57"; Layout.columnSpan: 3; font.pointSize: ScreenTools.smallFontPointSize }
                                    QGCLabel { text: qsTr("Length trigger") + (root.draftReady && lengthTrigger.text !== root.savedDraft.lengthTrigger ? " \u25cf" : ""); Layout.fillWidth: true; color: root.draftReady && lengthTrigger.text !== root.savedDraft.lengthTrigger ? "#258bdc" : "white" }
                                    QGCTextField {
                                        id: lengthTrigger
                                        text: "100"
                                        Layout.preferredWidth: settingsPage.fieldWidth
                                        Layout.preferredHeight: settingsPage.compactHeight
                                        numericValuesOnly: true
                                        validator: IntValidator { bottom: 0; top: 200 }
                                        validationError: !acceptableInput
                                        onTextChanged: root.lengthError = !acceptableInput
                                    }
                                    QGCLabel { text: "m"; color: root.muted }
                                    QGCLabel { visible: !lengthTrigger.acceptableInput; text: qsTr("Allowed 0-200 m"); color: "#ff5e57"; Layout.columnSpan: 3; font.pointSize: ScreenTools.smallFontPointSize }
                                }
                            }
                            }
                            ColumnLayout {
                                width: (parent.width - settingsPage.gap * 2) * .37
                                spacing: ScreenTools.defaultFontPixelHeight * .45
                                QGCLabel { text: qsTr("Winch functions"); color: "white" }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                implicitHeight: winchForm.implicitHeight + settingsPage.gap * 2
                                color: "#343b41"
                                radius: 0
                                enabled: !root.settingsLocked && !station.settingsBusy
                                GridLayout {
                                    id: winchForm
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: settingsPage.gap
                                    columns: 3
                                    columnSpacing: settingsPage.gap
                                    rowSpacing: settingsPage.gap * .7
                                    QGCCheckBox { id: protectionEnabled; text: qsTr("Take-off/land protection"); checked: true; Layout.alignment: Qt.AlignLeft }
                                    QGCTextField {
                                        id: protectionLength
                                        text: "10"
                                        Layout.preferredWidth: settingsPage.fieldWidth
                                        Layout.preferredHeight: settingsPage.compactHeight
                                        numericValuesOnly: true
                                        validator: IntValidator { bottom: 0; top: 200 }
                                        validationError: !acceptableInput
                                    }
                                    QGCLabel { text: "m"; color: root.muted }
                                    QGCLabel { visible: !protectionLength.acceptableInput; text: qsTr("allowed 0-200 m"); color: "#ff5e57"; Layout.columnSpan: 3; font.pointSize: ScreenTools.smallFontPointSize }
                                    QGCCheckBox { id: antiShockEnabled; text: qsTr("Anti-shock"); checked: true; Layout.alignment: Qt.AlignLeft }
                                    QGCTextField {
                                        id: antiShockPercent
                                        text: "30"
                                        Layout.preferredWidth: settingsPage.fieldWidth
                                        Layout.preferredHeight: settingsPage.compactHeight
                                        numericValuesOnly: true
                                        validator: IntValidator { bottom: 0; top: 100 }
                                        validationError: !acceptableInput
                                    }
                                    QGCLabel { text: "%"; color: root.muted }
                                    QGCLabel { visible: !antiShockPercent.acceptableInput; text: qsTr("allowed 0-100 %"); color: "#ff5e57"; Layout.columnSpan: 3; font.pointSize: ScreenTools.smallFontPointSize }
                                    RowLayout {
                                        Layout.columnSpan: 3
                                        Layout.fillWidth: true
                                        QGCCheckBox { id: antiDraggingEnabled; text: qsTr("Anti-ground dragging"); checked: false }
                                        QGCLabel { text: "2.0 s / 1 %"; color: root.muted; Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; font.pointSize: ScreenTools.smallFontPointSize }
                                    }
                                    QGCCheckBox { id: antiEntrapmentEnabled; text: qsTr("Anti-entrapment"); checked: true; Layout.columnSpan: 3 }
                                    QGCLabel {
                                        text: qsTr("Keep Anti-entrapment enabled.")
                                        color: "#f4b244"
                                        Layout.columnSpan: 3
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        font.pointSize: ScreenTools.smallFontPointSize
                                    }
                                }
                            }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.topMargin: ScreenTools.defaultFontPixelHeight * .2
                                    implicitHeight: interlockText.implicitHeight + settingsPage.gap * 1.4
                                    radius: 4
                                    color: "#d7ad00"
                                    QGCLabel {
                                        id: interlockText
                                        anchors.fill: parent
                                        anchors.margins: settingsPage.gap * .7
                                        text: root.settingsLocked ? root.settingsLockReason : qsTr("Read-only while the vehicle is armed or the station reports flight (> 200 W).")
                                        color: "black"
                                        wrapMode: Text.WordWrap
                                        font.pointSize: ScreenTools.smallFontPointSize
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.topMargin: ScreenTools.defaultFontPixelHeight * .2
                                    spacing: ScreenTools.defaultFontPixelWidth * .7
                                    QGCLabel {
                                        Layout.fillWidth: true
                                        text: root.changeCount + qsTr(" changes") + (root.errorCount > 0 ? " \u00b7 " + root.errorCount + qsTr(" error(s)") : "") + (!lengthTrigger.acceptableInput ? "\n" + qsTr("Length trigger: Allowed 0-200 m") : "")
                                        color: root.hasSettingsError ? "#ff5e57" : "#258bdc"
                                        wrapMode: Text.WordWrap
                                        font.pointSize: ScreenTools.smallFontPointSize
                                    }
                                    QGCButton {
                                        text: qsTr("Cancel")
                                        onClicked: root.cancelSettings()
                                    }
                                    QGCButton {
                                        text: qsTr("Save")
                                        enabled: root.settingsDirty && root.settingsValid && !root.settingsLocked && !station.settingsBusy && Object.keys(station.stationSettings).length > 0
                                        onClicked: {
                                            if (root.settingsLocked || !root.settingsValid) return
                                            saveConfirmation.open()
                                        }
                                    }
                                }
                                QGCLabel {
                                    Layout.fillWidth: true
                                    text: station.settingsResult
                                    color: root.muted
                                    wrapMode: Text.WordWrap
                                    font.pointSize: ScreenTools.smallFontPointSize
                                }
                                QGCButton {
                                    text: qsTr("Reload settings")
                                    enabled: !root.settingsLocked && !station.settingsBusy
                                    onClicked: { root.awaitingSave = true; station.readSettings() }
                                }
                            }
                            ColumnLayout {
                                width: (parent.width - settingsPage.gap * 2) * .32
                                spacing: ScreenTools.defaultFontPixelHeight * .45
                                QGCLabel { text: qsTr("Comms & Wi-Fi"); color: "white" }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                implicitHeight: commsForm.implicitHeight + settingsPage.gap * 2
                                color: "#343b41"
                                radius: 0
                                enabled: !root.settingsLocked && !station.settingsBusy
                                GridLayout {
                                    id: commsForm
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: settingsPage.gap
                                    columns: 3
                                    columnSpacing: settingsPage.gap
                                    rowSpacing: settingsPage.gap * .7
                                    QGCLabel { text: qsTr("Control timeout"); Layout.fillWidth: true; color: "white" }
                                    QGCTextField {
                                        id: controlTimeout
                                        text: "250"
                                        Layout.preferredWidth: settingsPage.fieldWidth
                                        Layout.preferredHeight: settingsPage.compactHeight
                                        numericValuesOnly: true
                                        validator: IntValidator { bottom: 200; top: 12750 }
                                        validationError: !acceptableInput || Number(text) % 50 !== 0
                                    }
                                    QGCLabel { text: "ms"; color: root.muted }
                                    QGCLabel {
                                        visible: controlTimeout.validationError
                                        text: qsTr("allowed 200-12750 ms, in 50 ms increments")
                                        color: "#ff5e57"
                                        Layout.columnSpan: 3
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        font.pointSize: ScreenTools.smallFontPointSize
                                    }
                                    QGCLabel { text: qsTr("Tether length"); Layout.fillWidth: true; color: "white" }
                                    QGCLabel { text: station.stationSettings.tetherLength !== undefined ? String(station.stationSettings.tetherLength) : qsTr("Not read"); color: root.muted }
                                    QGCLabel { text: "m"; color: root.muted }
                                    QGCLabel { text: qsTr("Tether weight"); Layout.fillWidth: true; color: "white" }
                                    QGCLabel { text: station.stationSettings.tetherWeight !== undefined ? String(station.stationSettings.tetherWeight) : qsTr("Not read"); color: root.muted }
                                    QGCLabel { text: "g/m"; color: root.muted }
                                    QGCLabel { text: qsTr("Wi-Fi SSID"); color: "white" }
                                    QGCTextField {
                                        id: wifiSsid
                                        text: "SAFE-T-[S/N]"
                                        maximumLength: 19
                                        Layout.columnSpan: 2
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: settingsPage.compactHeight
                                    }
                                    QGCLabel { text: qsTr("Wi-Fi password"); color: "white" }
                                    QGCTextField {
                                        id: wifiPassword
                                        text: "safetpass"
                                        maximumLength: 9
                                        echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                                        Layout.columnSpan: 2
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: settingsPage.compactHeight
                                    }
                                    Item { }
                                    QGCCheckBox { text: qsTr("Show password"); checked: root.showPassword; Layout.columnSpan: 2; onClicked: root.showPassword = checked }
                                }
                            }
                            }
                        }
                    }
                }
            }
            Item {
                id: deviceInfoPage
                function value(key, suffix) { var v = station.stationSettings[key]; return v === undefined ? qsTr("Not read") : String(v) + (suffix || "") }
                property string serialNumber: value("serialNumber")
                property string frameText: !station.frameVersionDetected ? qsTr("Not detected") : station.activeFrameVersion + (station.frameVersion === "Auto" ? qsTr(" (auto-detected)") : qsTr(" (manual)"))
                property real maintenanceRatio: station.stationSettings.maintenanceHours === undefined ? 0 : station.stationSettings.maintenanceHours / maintenancePreferences.intervalHours
                property color maintenanceColor: maintenanceRatio > 1 ? "#ff5e57" : (maintenanceRatio >= .9 ? "#ffbc42" : root.teal)
                property string maintenanceText: value("maintenanceHours", " h") + " / " + maintenancePreferences.intervalHours + " h"
                property string deviceText: "Serial No.: " + serialNumber + "\nFW - Interface board: " + value("interfaceFirmware") + "\nFW - Command board: " + value("commandFirmware") + "\nFW - Power board: " + value("powerFirmware") + "\nFrame version: " + frameText + "\nPowered hours: " + value("poweredHours", " h") + "\nFlights: " + value("flights") + "\nSince maintenance: " + maintenanceText
                TextEdit { id: deviceInfoCopyBuffer; visible: false; text: deviceInfoPage.deviceText }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: ScreenTools.defaultFontPixelWidth * 1.3
                    spacing: ScreenTools.defaultFontPixelHeight * .7
                    QGCLabel { text: qsTr("Device"); color: "white"; font.pointSize: ScreenTools.defaultFontPointSize }
                    Rectangle {
                        Layout.preferredWidth: parent.width * .56
                        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 15.2
                        color: root.card
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: ScreenTools.defaultFontPixelWidth * .9
                            spacing: ScreenTools.defaultFontPixelHeight * .36
                            GridLayout {
                                Layout.fillWidth: true; columns: 2
                                columnSpacing: ScreenTools.defaultFontPixelWidth * 4
                                rowSpacing: ScreenTools.defaultFontPixelHeight * .3
                                QGCLabel { text: qsTr("Serial No."); color: root.muted; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: deviceInfoPage.serialNumber; color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("FW - Interface board"); color: root.muted; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: deviceInfoPage.value("interfaceFirmware"); color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("FW - Command board"); color: root.muted; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: deviceInfoPage.value("commandFirmware"); color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("FW - Power board"); color: root.muted; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: deviceInfoPage.value("powerFirmware"); color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("Frame version"); color: root.muted; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: deviceInfoPage.frameText; color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("Powered hours"); color: root.muted; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: deviceInfoPage.value("poweredHours", " h"); color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("Flights"); color: root.muted; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: deviceInfoPage.value("flights"); color: "white"; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: qsTr("Since maintenance"); color: root.muted; font.pointSize: ScreenTools.defaultFontPointSize }
                                QGCLabel { text: deviceInfoPage.maintenanceText; color: deviceInfoPage.maintenanceColor; font.family: ScreenTools.demiboldFontFamily; font.pointSize: ScreenTools.defaultFontPointSize }
                            }
                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * .38; radius: height / 2; color: "#20252b"; Rectangle { width: parent.width * Math.min(1, deviceInfoPage.maintenanceRatio); height: parent.height; radius: parent.radius; color: deviceInfoPage.maintenanceColor } }
                        }
                    }
                    QGCLabel { Layout.preferredWidth: parent.width * .56; text: qsTr("Maintenance reminder: caution at 90 % of the interval, warning above 100 %. Counter reset is not provided until Elistair defines a frame."); color: root.muted; wrapMode: Text.WordWrap; font.pointSize: ScreenTools.smallFontPointSize }
                    RowLayout {
                        Layout.preferredWidth: parent.width * .56
                        QGCLabel { text: qsTr("GCS maintenance interval (h)"); color: root.muted }
                        SpinBox { from: 1; to: 65535; value: maintenancePreferences.intervalHours; onValueModified: maintenancePreferences.intervalHours = value }
                    }
                    QGCLabel {
                        Layout.preferredWidth: parent.width * .56
                        text: root.settingsLocked ? root.settingsLockReason : (deviceInfoPage.maintenanceRatio > 1 ? qsTr("Maintenance overdue — service before flight.") : (deviceInfoPage.maintenanceRatio >= .9 ? qsTr("Maintenance due soon (90% or more).") : station.settingsResult))
                        color: deviceInfoPage.maintenanceColor; wrapMode: Text.WordWrap
                    }
                    RowLayout {
                        Layout.preferredWidth: parent.width * .56
                        QGCButton { text: qsTr("Copy device info"); Layout.preferredHeight: root.controlHeight; onClicked: { deviceInfoCopyBuffer.selectAll(); deviceInfoCopyBuffer.copy(); deviceInfoCopyBuffer.deselect() } }
                        Item { Layout.fillWidth: true }
                        QGCLabel { text: qsTr("Read-only"); color: root.muted; font.pointSize: ScreenTools.smallFontPointSize }
                    }
                }
            }
        }
    }
}
