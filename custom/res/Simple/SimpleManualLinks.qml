/****************************************************************************
 * AQGC Simple UI — Settings › Connection › Manual connections (Advanced mode; Figma S93 169:44870, S94 169:45075,
 * 2026-11-18). Replaces the classic Comm Links page: saved serial / UDP / TCP links, Connect / Disconnect / Edit,
 * Add connection sheet. Same LinkManager calls as the classic LinkSettings.qml. Links the app made by itself
 * (dynamic: auto-connect) are not listed.
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

Rectangle {
    id: ml
    readonly property var  _lm: QGroundControl.linkManager
    readonly property bool _serialOk: !!_lm && _lm.linkTypeStrings.length > 0 && LinkConfiguration.TypeSerial !== undefined && Qt.platform.os !== "ios"
    property int rev: 0                 // bumps after a change so names / states are read again

    width: parent ? parent.width : 0
    height: col.height + SimpleTheme.px(48)
    radius: SimpleTheme.px(20)
    color: SimpleTheme.surfaceRaised

    function typeName(c) {
        if (!c) return ""
        if (c.linkType === LinkConfiguration.TypeUdp) return qsTr("UDP")
        if (c.linkType === LinkConfiguration.TypeTcp) return qsTr("TCP")
        if (ml._serialOk && c.linkType === LinkConfiguration.TypeSerial) return qsTr("Serial")
        return _lm.linkTypeStrings[c.linkType] || ""
    }
    function detail(c) {
        if (!c) return ""
        var d = typeName(c)
        if (c.linkType === LinkConfiguration.TypeUdp) {
            d += " · " + qsTr("listen %1").arg(c.localPort)
            if (c.hostList && c.hostList.length) d += " · " + qsTr("send to %1").arg(c.hostList.join(", "))
        } else if (c.linkType === LinkConfiguration.TypeTcp) {
            d += " · " + c.host + " : " + c.port
        } else if (ml._serialOk && c.linkType === LinkConfiguration.TypeSerial) {
            d += " · " + (c.portDisplayName !== "" ? c.portDisplayName : c.portName) + " · " + c.baud
        }
        if (c.autoConnect) d += " · " + qsTr("connects when the app starts")
        return d
    }

    Column {
        id: col
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: SimpleTheme.px(24); anchors.leftMargin: SimpleTheme.px(28)
        spacing: SimpleTheme.px(14)

        Item {
            width: parent.width; height: SimpleTheme.px(44)
            SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Manual connections"); size: 30; medium: true }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                spacing: SimpleTheme.px(10)
                SIcon { name: "layers"; size: 26; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                SText { text: qsTr("ADVANCED MODE"); size: 20; medium: true; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        SText {
            width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary
            text: qsTr("For links that do not connect by themselves: telemetry radio on a serial port, SITL or another ground station over TCP / UDP.")
        }

        Repeater {
            model: ml._lm.linkConfigurations
            Rectangle {
                readonly property var  cfg: object
                readonly property bool on: !!cfg && !!cfg.link
                visible: !!cfg && !cfg.dynamic
                width: col.width
                height: visible ? Math.max(SimpleTheme.px(88), lrow.height + SimpleTheme.px(24)) : 0
                radius: SimpleTheme.px(16)
                color: SimpleTheme.bgBase
                Column {
                    anchors.left: parent.left; anchors.leftMargin: SimpleTheme.px(20)
                    anchors.right: lrow.left; anchors.rightMargin: SimpleTheme.px(16)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: SimpleTheme.px(2)
                    SText { width: parent.width; elide: Text.ElideRight; text: cfg ? cfg.name + (ml.rev, "") : ""; size: 26; medium: true }
                    SText { width: parent.width; wrapMode: Text.WordWrap; text: (ml.rev, ml.detail(cfg)); size: 22; color: SimpleTheme.textSecondary }
                }
                Row {
                    id: lrow
                    anchors.right: parent.right; anchors.rightMargin: SimpleTheme.px(16); anchors.verticalCenter: parent.verticalCenter
                    spacing: SimpleTheme.px(12)
                    SStatusChip { visible: on; text: qsTr("Connected"); level: "ok"; anchors.verticalCenter: parent.verticalCenter }
                    SButton { visible: on; designHeight: 64; textSize: 24; text: qsTr("Disconnect")
                              onClicked: { cfg.link.disconnect(); cfg.linkChanged() } }
                    SButton { visible: !on; designHeight: 64; textSize: 24; kind: "primary"; text: qsTr("Connect")
                              onClicked: ml._lm.createConnectedLink(cfg) }
                    SButton { visible: !on; designHeight: 64; textSize: 24; text: qsTr("Edit"); onClicked: editor.openFor(cfg) }
                }
            }
        }
        SButton { designHeight: 64; textSize: 24; icon: "plus"; text: qsTr("Add connection"); onClicked: editor.openFor(null) }
    }

    //------------------------------------------------------------------ S94 Add / edit connection
    SSheet {
        id: editor
        designWidth: 960
        title: original ? qsTr("Edit connection") : qsTr("Add connection")
        subtitle: qsTr("Saved on this tablet. The drone link still connects by itself — add a connection only for other links.")
        property var  original: null       // saved configuration being edited (null: new)
        property var  cfg: null            // working copy (deleted on cancel)
        property bool confirmDelete: false
        property var  _types: ml._serialOk ? [LinkConfiguration.TypeSerial, LinkConfiguration.TypeUdp, LinkConfiguration.TypeTcp]
                                           : [LinkConfiguration.TypeUdp, LinkConfiguration.TypeTcp]
        // a TCP link needs a server address; UDP may listen on any port (0)
        readonly property bool canSave: nameField.currentText.trim() !== ""
                                        && !(cfg && cfg.linkType === LinkConfiguration.TypeTcp && (tcpHost.currentText.trim() === "" || !(parseInt(tcpPort.currentText) > 0)))
        property var  _typeNames: ml._serialOk ? [qsTr("Serial port"), qsTr("UDP"), qsTr("TCP")] : [qsTr("UDP"), qsTr("TCP")]

        function openFor(c) {
            original = c; confirmDelete = false
            cfg = c ? ml._lm.startConfigurationEditing(c)
                    : ml._lm.createConfiguration(ml._serialOk ? LinkConfiguration.TypeSerial : LinkConfiguration.TypeUdp, "")
            nameField.text = cfg.name; nameField.reset()
            tcpHost.reset(); tcpPort.reset(); udpPort.reset(); udpHost.text = ""; udpHost.reset()
            autoToggle.checked = cfg.autoConnect
            open()
        }
        function setType(t) {
            if (!cfg || cfg.linkType === t || original) return
            var old = cfg
            cfg = ml._lm.createConfiguration(t, nameField.currentText)
            cfg.autoConnect = old.autoConnect
            ml._lm.cancelConfigurationEditing(old)
        }
        function commitFields() {
            if (cfg.linkType === LinkConfiguration.TypeTcp) {
                cfg.host = tcpHost.currentText.trim()
                cfg.port = parseInt(tcpPort.currentText)
            } else if (cfg.linkType === LinkConfiguration.TypeUdp) {
                var p = parseInt(udpPort.currentText); if (p > 0) cfg.localPort = p
            }
        }
        function save(connect) {
            commitFields()
            cfg.name = nameField.currentText.trim()
            var c = cfg; cfg = null
            if (original) { ml._lm.endConfigurationEditing(original, c); c = original }
            else          { c.dynamic = false; ml._lm.endCreateConfiguration(c) }
            if (connect) ml._lm.createConnectedLink(c)
            original = null; ml.rev++
            close()
        }
        onClosed: { if (cfg) ml._lm.cancelConfigurationEditing(cfg); cfg = null; original = null }

        STextField { id: nameField; label: qsTr("Name"); designWidth: 880; placeholder: qsTr("e.g. Telemetry radio") }
        Row {
            spacing: SimpleTheme.px(16)
            SText { text: qsTr("Type"); size: 24; color: SimpleTheme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            SSegmented {
                designWidth: editor._types.length * 200
                model: editor._typeNames
                currentIndex: editor.cfg ? editor._types.indexOf(editor.cfg.linkType) : 0
                opacity: editor.original ? 0.5 : 1
                enabled: !editor.original
                onActivated: editor.setType(editor._types[index])
            }
        }

        // Serial
        Row {
            visible: !!editor.cfg && ml._serialOk && editor.cfg.linkType === LinkConfiguration.TypeSerial
            spacing: SimpleTheme.px(20)
            Column {
                spacing: SimpleTheme.px(4)
                SText { text: qsTr("Port"); size: 22; medium: true; color: SimpleTheme.textSecondary }
                SComboBox {
                    id: portBox
                    designWidth: 560
                    readonly property var ports: ml._lm.serialPorts
                    model: ml._lm.serialPortStrings.length ? ml._lm.serialPortStrings : [qsTr("No serial port found")]
                    enabled: ml._lm.serialPorts.length > 0
                    currentIndex: editor.cfg && editor.cfg.portName !== undefined ? Math.max(0, ports.indexOf(editor.cfg.portName)) : 0
                    onActivated: if (index < ports.length) editor.cfg.portName = ports[index]
                    onVisibleChanged: if (visible && editor.cfg && editor.cfg.portName === "" && ports.length) editor.cfg.portName = ports[0]
                }
            }
            Column {
                spacing: SimpleTheme.px(4)
                SText { text: qsTr("Speed (baud)"); size: 22; medium: true; color: SimpleTheme.textSecondary }
                SComboBox {
                    designWidth: 300
                    model: ml._lm.serialBaudRates
                    currentIndex: editor.cfg && editor.cfg.baud !== undefined ? Math.max(0, ml._lm.serialBaudRates.indexOf(String(editor.cfg.baud))) : 0
                    onActivated: editor.cfg.baud = parseInt(ml._lm.serialBaudRates[index])
                }
            }
        }

        // UDP
        Column {
            visible: !!editor.cfg && editor.cfg.linkType === LinkConfiguration.TypeUdp
            width: parent.width
            spacing: SimpleTheme.px(12)
            STextField { id: udpPort; label: qsTr("Listening port"); numeric: true; designWidth: 240; placeholder: "14560"
                         text: editor.cfg && editor.cfg.localPort ? String(editor.cfg.localPort) : "" }
            SText { text: qsTr("Send to (optional)"); size: 22; medium: true; color: SimpleTheme.textSecondary }
            Repeater {
                model: editor.cfg && editor.cfg.hostList !== undefined ? editor.cfg.hostList : []
                Row {
                    spacing: SimpleTheme.px(14)
                    SText { width: SimpleTheme.px(420); text: modelData; size: 24; anchors.verticalCenter: parent.verticalCenter }
                    SButton { designHeight: 56; textSize: 22; text: qsTr("Remove"); onClicked: editor.cfg.removeHost(modelData) }
                }
            }
            Row {
                spacing: SimpleTheme.px(14)
                STextField { id: udpHost; designWidth: 560; placeholder: qsTr("host:port, e.g. 192.168.1.20:14550") }
                SButton { designHeight: 72; textSize: 24; text: qsTr("Add"); anchors.bottom: parent.bottom
                          enabled_: udpHost.currentText.trim() !== ""
                          onClicked: if (enabled_) { editor.cfg.addHost(udpHost.currentText.trim()); udpHost.text = ""; udpHost.reset() } }
            }
        }

        // TCP
        Row {
            visible: !!editor.cfg && editor.cfg.linkType === LinkConfiguration.TypeTcp
            spacing: SimpleTheme.px(20)
            STextField { id: tcpHost; label: qsTr("Server address"); designWidth: 520; placeholder: "127.0.0.1"
                         text: editor.cfg && editor.cfg.host !== undefined && editor.cfg.host !== "0.0.0.0" ? editor.cfg.host : "" }
            STextField { id: tcpPort; label: qsTr("Port"); numeric: true; designWidth: 200; placeholder: "5760"
                         text: editor.cfg && editor.cfg.port !== undefined ? String(editor.cfg.port) : "" }
        }

        Row {
            spacing: SimpleTheme.px(16)
            SToggle { id: autoToggle; anchors.verticalCenter: parent.verticalCenter; onToggled: if (editor.cfg) editor.cfg.autoConnect = checked }
            SText { text: qsTr("Connect when the app starts"); size: 24; anchors.verticalCenter: parent.verticalCenter }
        }

        SNotice {
            visible: editor.confirmDelete
            width: parent.width
            level: "danger"
            text: qsTr("Delete “%1”? A running connection is closed first.").arg(editor.original ? editor.original.name : "")
        }
        Item {
            width: parent.width; height: SimpleTheme.px(72)
            SButton {
                visible: !!editor.original
                designHeight: 72; textSize: 24; kind: "danger"
                text: editor.confirmDelete ? qsTr("Delete") : qsTr("Delete…")
                onClicked: {
                    if (!editor.confirmDelete) { editor.confirmDelete = true; return }
                    var o = editor.original
                    editor.close()                         // drops the working copy
                    ml._lm.removeConfiguration(o); ml.rev++
                }
            }
            Row {
                anchors.right: parent.right
                spacing: SimpleTheme.px(14)
                SButton { designHeight: 72; textSize: 24; text: qsTr("Cancel"); onClicked: editor.close() }
                SButton { designHeight: 72; textSize: 24; text: qsTr("Save"); enabled_: editor.canSave
                          onClicked: if (enabled_) editor.save(false) }
                SButton { designHeight: 72; textSize: 24; kind: "primary"; text: qsTr("Save and connect"); enabled_: editor.canSave
                          onClicked: if (enabled_) editor.save(true) }
            }
        }
    }
}
