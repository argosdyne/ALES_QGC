/****************************************************************************
 * AQGC Simple UI — S29 message history (vehicle messages)
 *
 * Vehicle.formattedMessages holds HTML with style placeholders (<#E> error, <#I> warning, <#N> normal,
 * see UASMessageHandler) that the view must replace, as the classic MessageIndicator does. Opening the
 * panel marks the messages as read (bell count back to 0); new messages are appended while it is open.
 ****************************************************************************/
import QtQuick 2.12
import QtQuick.Controls 2.4
import "."

SPanel {
    id: panel
    property var vehicle: null
    width:  SimpleTheme.px(900)
    height: SimpleTheme.px(780)
    title:  qsTr("Messages")
    titleIcon: "bell"

    function formatMessage(m) {
        var f = "; font-size: " + SimpleTheme.fs(22) + "px;"
        m = m.replace(/<#E>/g, "color: " + SimpleTheme.textDanger + f)
        m = m.replace(/<#I>/g, "color: " + SimpleTheme.warn + f)
        m = m.replace(/<#N>/g, "color: " + SimpleTheme.textPrimary + f)
        return m
    }
    function reload() {
        txt.text = vehicle ? formatMessage(String(vehicle.formattedMessages)) : ""
        if (vehicle) vehicle.resetAllMessages()
        scrollTimer.restart()
    }
    onVisibleChanged: if (visible) reload()
    onVehicleChanged: if (visible) reload()

    property var _pending: []
    Connections {
        target: panel.visible ? panel.vehicle : null
        function onNewFormattedMessage(formattedMessage) {
            panel._pending.push(panel.formatMessage(formattedMessage))
            appendTimer.restart()
        }
    }
    Timer {
        id: appendTimer; interval: 250
        onTriggered: {
            if (panel._pending.length === 0) return
            txt.append(panel._pending.join(""))
            panel._pending = []
            if (panel.vehicle) panel.vehicle.resetAllMessages()
            scrollTimer.restart()
        }
    }
    Timer { id: scrollTimer; interval: 50; onTriggered: flick.contentY = Math.max(0, flick.contentHeight - flick.height) }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.bottomMargin: SimpleTheme.px(100)
        contentHeight: txt.height
        clip: true
        ScrollBar.vertical: ScrollBar {}
        TextEdit {
            id: txt
            width: flick.width
            readOnly: true
            selectByMouse: false
            textFormat: TextEdit.RichText
            wrapMode: TextEdit.WordWrap
            color: SimpleTheme.textPrimary
            font.pixelSize: SimpleTheme.fs(22)
        }
    }
    SText {
        anchors.centerIn: flick
        visible: txt.length === 0
        text: qsTr("No messages"); size: 24; color: SimpleTheme.textSecondary
    }
    SButton {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        designHeight: 80
        text: qsTr("Clear")
        icon: "trash"
        onClicked: { if (panel.vehicle) panel.vehicle.clearMessages(); txt.text = ""; panel._pending = [] }
    }
}
