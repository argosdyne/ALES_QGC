/****************************************************************************
 * AQGC Simple UI — S89 Analyze › App log › Log categories (Figma 160:43161, 2026-11-18).
 * Common groups first (plain name + the real category names); "Show all" lists every registered category
 * (QGroundControl.loggingCategories()) with a search. A group toggle turns all its categories on or off.
 * State is saved by QGCLoggingCategoryRegister (same settings as the classic console) and kept over restarts.
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

SSheet {
    id: lc
    title: qsTr("Log categories")
    subtitle: qsTr("Choose what the app writes to the App log. More categories make the log longer and the app a little slower.")
    designWidth: 900
    closeOnOutside: true

    property bool   showAll: false
    property string search: ""
    property int    rev: 0                      // re-read the states after a change
    readonly property var all: QGroundControl.loggingCategories()
    readonly property var groups: [
        { t: qsTr("Vehicle link"),   c: ["LinkManagerLog", "LinkInterfaceLog", "MAVLinkProtocolLog", "VehicleLinkManagerLog", "SerialLinkLog"] },
        { t: qsTr("Mission upload"), c: ["MissionManagerLog", "PlanManagerLog", "MissionControllerLog", "GeoFenceManagerLog", "RallyPointManagerLog"] },
        { t: qsTr("Parameters"),     c: ["ParameterManagerLog", "APMParameterMetaDataLog", "FTPManagerLog"] },
        { t: qsTr("Video"),          c: ["VideoManagerLog", "VideoReceiverLog", "GStreamerLog", "GStreamLog"] },
        { t: qsTr("Payloads"),       c: ["GimbalLog", "CodevCameraLog", "YellowScanInitPathLog", "SafeTLog", "LifeVestLog"] },
        { t: qsTr("Camera"),         c: ["CameraControlLog", "CameraManagerLog", "CameraIOLog"] },
        { t: qsTr("RTK / GPS"),      c: ["NTRIPRTCMSourceLog", "RTKGPSLog", "RTCMBaseLog", "CodevRTCMManagerLog"] }
    ]
    function known(list) { return list.filter(function(c) { return lc.all.indexOf(c) >= 0 }) }
    function isOn(c) { rev; return QGroundControl.categoryLoggingOn(c) }
    function groupOn(list) { var k = known(list); for (var i = 0; i < k.length; i++) if (isOn(k[i])) return true; return false }
    function setOn(list, on) {
        for (var i = 0; i < list.length; i++) QGroundControl.setCategoryLoggingOn(list[i], on)
        QGroundControl.updateLoggingFilterRules()
        rev++
    }
    onAboutToShow: { showAll = false; search = ""; rev++ }

    STextField { visible: lc.showAll; designWidth: 820; placeholder: qsTr("Search categories"); text: lc.search; onEdited: lc.search = text }
    Repeater {
        model: lc.showAll ? [] : lc.groups
        Item {
            readonly property var cats: lc.known(modelData.c)
            visible: cats.length > 0
            width: lc.innerWidth; height: SimpleTheme.px(80)
            Column {
                anchors.left: parent.left; anchors.right: tg.left; anchors.rightMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                SText { text: modelData.t; size: 26; medium: true }
                SText { width: parent.width; text: parent.parent.cats.join(", "); size: 20; color: SimpleTheme.textSecondary; elide: Text.ElideRight }
            }
            SToggle { id: tg; objectName: "logGroup_" + index; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                      checked: lc.groupOn(modelData.c)
                      onToggled: { lc.setOn(parent.cats, checked) } }
        }
    }
    ListView {
        visible: lc.showAll
        width: lc.innerWidth; height: SimpleTheme.px(520); clip: true
        model: lc.showAll ? lc.all.filter(function(c) { return lc.search === "" || c.toLowerCase().indexOf(lc.search.toLowerCase()) >= 0 }) : []
        delegate: Item {
            width: ListView.view.width; height: SimpleTheme.px(68)
            SText { anchors.verticalCenter: parent.verticalCenter; text: modelData; size: 24 }
            SToggle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; scale: 0.8; transformOrigin: Item.Right
                      checked: lc.isOn(modelData)
                      onToggled: { lc.setOn([modelData], checked) } }
        }
    }
    Item {
        width: lc.innerWidth; height: SimpleTheme.px(48)
        SText { anchors.verticalCenter: parent.verticalCenter; size: 24; medium: true; color: SimpleTheme.textLink
                text: lc.showAll ? qsTr("Show common groups") : qsTr("Show all %1 categories").arg(lc.all.length)
                MouseArea { anchors.fill: parent; anchors.margins: -SimpleTheme.px(12); onClicked: lc.showAll = !lc.showAll } }
        SText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; size: 24; medium: true; color: SimpleTheme.textLink
                text: qsTr("Turn all off")
                MouseArea { anchors.fill: parent; anchors.margins: -SimpleTheme.px(12); onClicked: lc.setOn(lc.all, false) } }
    }
    SNotice { level: "info"; text: qsTr("Categories are kept after a restart. The log can contain locations; it stays on this tablet.") }
    SButton { width: lc.innerWidth; designHeight: 72; textSize: 26; kind: "primary"; text: qsTr("Done"); onClicked: lc.close() }
}
