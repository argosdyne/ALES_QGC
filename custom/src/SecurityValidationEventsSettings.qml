import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Layouts          1.2

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0

Rectangle {
    id:                 _root
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    property real _panelWidth: _root.width * 0.84
    property real _margins:    ScreenTools.defaultFontPixelWidth
    property int  _lastLogIndex: 0

    QGCPalette { id: qgcPal }

    function levelColor(line) {
        return line.indexOf("[E]") >= 0 || line.indexOf("[!]") >= 0 ? "#f7b24a" : "#ffffff"
    }

    function _appendSecurityEvents() {
        var logs = debugMessageModel.stringList
        if (!logs || !logs.length) {
            return
        }

        for (var i = _lastLogIndex; i < logs.length; i++) {
            var line = logs[i]
            if (line.indexOf("SECURITY:") >= 0) {
                eventModel.append({ lineText: line })
            }
        }
        _lastLogIndex = logs.length
    }

    function _clearVisibleEvents() {
        eventModel.clear()
        var logs = debugMessageModel.stringList
        _lastLogIndex = logs ? logs.length : 0
        console.info("SECURITY: Security events view cleared")
    }

    function _exportVisibleEvents() {
        var lines = []
        for (var i = 0; i < eventModel.count; i++) {
            lines.push(eventModel.get(i).lineText)
        }

        if (!lines.length) {
            exportDialog.text = qsTr("No security events to export.")
            exportDialog.open()
            return
        }

        var filePath = CustomQmlInterface.exportTextReport("ALES_QGC_SecurityEvents.txt", lines.join("\n") + "\n")
        if (filePath.length) {
            console.info("SECURITY: Security events exported to " + filePath)
            exportDialog.text = qsTr("Security events exported to:\n%1").arg(filePath)
        } else {
            exportDialog.text = qsTr("Failed to export security events.")
        }
        exportDialog.open()
    }

    Component.onCompleted: _appendSecurityEvents()

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: _root._appendSecurityEvents()
    }

    ListModel {
        id: eventModel
    }

    QGCFlickable {
        anchors.fill:   parent
        clip:           true
        contentHeight:  bodyColumn.height
        contentWidth:   bodyColumn.width

        Column {
            id: bodyColumn
            width: _root.width
            spacing: ScreenTools.defaultFontPixelHeight

            Rectangle {
                width:                      _panelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                color:                      qgcPal.windowShade
                border.color:               qgcPal.windowShadeDark
                radius:                     4
                height:                     contentColumn.height + _margins * 2

                Column {
                    id:                     contentColumn
                    anchors.fill:           parent
                    anchors.margins:        _margins
                    spacing:                ScreenTools.defaultFontPixelHeight * 0.7

                    QGCLabel {
                        text: qsTr("Security / Validation Events")
                        font.family: ScreenTools.demiboldFontFamily
                        font.pointSize: ScreenTools.largeFontPointSize
                    }

                    QGCLabel {
                        text: qsTr("Showing runtime events tagged with SECURITY.")
                        color: qgcPal.colorGrey
                    }

                    Rectangle {
                        width:          parent.width
                        height:         Math.max(ScreenTools.defaultFontPixelHeight * 10, eventModel.count * ScreenTools.defaultFontPixelHeight * 1.35)
                        color:          "#000000"
                        border.color:   qgcPal.windowShadeDark
                        radius:         3

                        Item {
                            anchors.fill: parent
                            visible: eventModel.count === 0

                            QGCLabel {
                                anchors.centerIn: parent
                                text: qsTr("No security events captured yet.")
                                color: qgcPal.colorGrey
                            }
                        }

                        ListView {
                            anchors.fill:           parent
                            anchors.margins:        ScreenTools.defaultFontPixelWidth
                            model:                  eventModel
                            clip:                   true
                            visible:                eventModel.count > 0

                            delegate: Rectangle {
                                width:          ListView.view.width
                                height:         ScreenTools.defaultFontPixelHeight * 1.2
                                color:          "transparent"

                                QGCLabel {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: lineText
                                    color: _root.levelColor(lineText)
                                    font.family: "Consolas"
                                }
                            }
                        }
                    }

                    RowLayout {
                        width: parent.width
                        Item { Layout.fillWidth: true }

                        QGCButton {
                            text: qsTr("Clear")
                            onClicked: _root._clearVisibleEvents()
                        }

                        QGCButton {
                            text: qsTr("Export Logs")
                            onClicked: _root._exportVisibleEvents()
                        }
                    }
                }
            }
        }
    }

    QGCSimpleMessageDialog {
        id: exportDialog
        title: qsTr("Security Events Export")
        text: ""
    }
}
