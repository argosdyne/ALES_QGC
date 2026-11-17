/****************************************************************************
 * AQGC Simple UI — S73 Vehicle setup › Power (Figma 127:40027, 2026-11-17).
 * BATT_MONITOR, BATT_CAPACITY, voltage calibration (enter the measured voltage: BATT_VOLT_MULT is scaled, as in the
 * classic page), BATT_AMP_PERVLT. ArduPilot has no cell-count parameter: the Figma "Cells" row is not shown.
 * ESC calibration opens the classic Power page (it needs the propellers-off check and a battery cycle).
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import QGroundControl.FactSystem 1.0
import QGroundControl.Controllers 1.0
import "."

Flickable {
    id: pw
    contentHeight: col.height
    clip: true
    FactPanelController { id: fpc }
    function p(n) { return fpc.parameterExists(-1, n) ? fpc.getParameterFact(-1, n, false) : null }
    readonly property var  _veh: QGroundControl.multiVehicleManager.activeVehicle
    readonly property var  batt: _veh && _veh.batteries.count > 0 ? _veh.batteries.get(0) : null
    readonly property real reading: batt ? Number(batt.voltage.rawValue) : 0
    property string calMsg: ""

    Column {
        id: col
        width: pw.width
        spacing: SimpleTheme.px(12)
        SText { text: qsTr("Power"); size: 40; bold: true }
        SText { width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                text: qsTr("Battery monitor and ESCs. Low and critical levels are set in Safety.") }
        SSettingRow { title: qsTr("Battery monitor"); sub: qsTr("How the drone measures the battery")
                      SFactField { fact: pw.p("BATT_MONITOR"); designWidth: 460 } }
        SSettingRow { title: qsTr("Capacity"); sub: qsTr("Full battery capacity"); visible: !!pw.p("BATT_CAPACITY")
                      SFactField { fact: pw.p("BATT_CAPACITY"); step: 100 } }
        // voltage calibration: measured value → new multiplier
        SSettingRow {
            visible: !!pw.p("BATT_VOLT_MULT")
            title: qsTr("Voltage calibration")
            sub: pw.calMsg !== "" ? pw.calMsg : qsTr("Drone reads %1 V. Measure the battery and enter the real value.").arg(pw.reading.toFixed(2))
            Row {
                spacing: SimpleTheme.px(10)
                STextField { id: measured; designWidth: 170; decimal: true; placeholder: pw.reading.toFixed(2); anchors.verticalCenter: parent.verticalCenter }
                SText { text: "V"; size: 22; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                SButton {
                    designHeight: 72; textSize: 24; text: qsTr("Calibrate")
                    enabled_: pw.reading > 1 && Number(measured.currentText) > 1
                    onClicked: {
                        var mult = pw.p("BATT_VOLT_MULT")
                        var nv = Number(mult.rawValue) * Number(measured.currentText) / pw.reading
                        var err = mult.validate(String(nv), false)
                        if (err !== "") { pw.calMsg = err; return }
                        mult.value = nv
                        pw.calMsg = qsTr("Voltage multiplier set to %1.").arg(nv.toFixed(3))
                    }
                }
            }
        }
        SSettingRow { title: qsTr("Current sensor"); sub: qsTr("Amps per volt of the power module"); visible: !!pw.p("BATT_AMP_PERVLT")
                      SFactField { fact: pw.p("BATT_AMP_PERVLT"); step: 0.1 } }
        SSettingRow {
            title: qsTr("ESC calibration"); sub: qsTr("Propellers off, battery connected. Only after replacing ESCs.")
            SButton { designHeight: 72; textSize: 24; text: qsTr("Start (classic)"); onClicked: simpleRoot.openClassic("setup:APMPowerComponent") }
        }
    }
}
