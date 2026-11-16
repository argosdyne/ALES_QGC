/****************************************************************************
 * AQGC Simple UI — S35 "Enter coordinates…": latitude / longitude (decimal degrees, WGS84).
 * A wrong value is shown in red (classic G-01c). "Show on map" moves the pin there and reopens the S35 menu.
 ****************************************************************************/
import QtQuick 2.12
import QtPositioning 5.12
import "."

SPanel {
    id: sheet
    property var start: QtPositioning.coordinate()
    signal accepted(var coordinate)

    readonly property real _lat: _num(latField.currentText)
    readonly property real _lon: _num(lonField.currentText)
    readonly property bool _latOk: isFinite(_lat) && _lat >= -90 && _lat <= 90
    readonly property bool _lonOk: isFinite(_lon) && _lon >= -180 && _lon <= 180
    function _num(t) { t = String(t).trim().replace(",", "."); return t === "" || isNaN(Number(t)) ? NaN : Number(t) }

    width:  SimpleTheme.px(820)
    height: col.implicitHeight + SimpleTheme.px(136)
    title:  qsTr("Enter coordinates")
    titleIcon: "globe"
    onVisibleChanged: if (visible) {
        latField.text = start && start.isValid ? start.latitude.toFixed(7) : ""
        lonField.text = start && start.isValid ? start.longitude.toFixed(7) : ""
        latField.reset(); lonField.reset()
    }

    Column {
        id: col
        anchors.left: parent.left; anchors.right: parent.right
        spacing: SimpleTheme.px(18)
        Row {
            spacing: SimpleTheme.px(24)
            STextField {
                id: latField; designWidth: 370; decimal: true
                label: qsTr("Latitude"); placeholder: "37.5665000"
                error: currentText !== "" && !sheet._latOk
            }
            STextField {
                id: lonField; designWidth: 370; decimal: true
                label: qsTr("Longitude"); placeholder: "126.9780000"
                error: currentText !== "" && !sheet._lonOk
            }
        }
        SText {
            width: parent.width; wrapMode: Text.WordWrap; size: 22
            color: (latField.currentText !== "" && !sheet._latOk) || (lonField.currentText !== "" && !sheet._lonOk) ? SimpleTheme.textDanger : SimpleTheme.textSecondary
            text: latField.currentText !== "" && !sheet._latOk ? qsTr("Latitude must be between -90 and 90.")
                : lonField.currentText !== "" && !sheet._lonOk ? qsTr("Longitude must be between -180 and 180.")
                : qsTr("Decimal degrees, for example 37.5665 and 126.9780.")
        }
        SButton {
            kind: "primary"; icon: "pin"
            text: qsTr("Show on map")
            enabled_: sheet._latOk && sheet._lonOk
            onClicked: sheet.accepted(QtPositioning.coordinate(sheet._lat, sheet._lon))
        }
    }
}
