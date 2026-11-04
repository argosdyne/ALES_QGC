/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.12
import QtQuick.Layouts  1.12

import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0

/// Unified warning message (Figma "WarningToast / New"): white card with a red accent edge,
/// warning icon, text and a close button. The key phrase (strongText) is drawn in
/// warningToastTextStrong, the rest of the message in warningToastText.
Rectangle {
    id: control

    /// Key phrase shown first, in the strong text color (plain text)
    property string strongText
    /// Rest of the message (plain text unless textIsRichText)
    property string text
    property bool   textIsRichText: false
    property bool   showCloseButton: true

    signal closeClicked

    readonly property real _h:          ScreenTools.defaultFontPixelHeight
    readonly property real _accentWidth: _h * 0.36
    readonly property real _vPadding:   _h * 0.16

    implicitWidth:  Math.round(_h * 16)
    implicitHeight: Math.max(contentRow.implicitHeight, closeButton.height) + (_vPadding * 2)
    radius:         _h * 0.47
    color:          qgcPal.warningToastAccent

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    function _escape(str) {
        return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    }

    // White card over the red rounded rectangle; the left edge is kept square so only the accent shows
    Rectangle {
        anchors.fill:       parent
        anchors.leftMargin: control._accentWidth
        radius:             control.radius
        color:              qgcPal.warningToastBackground
    }
    Rectangle {
        x:      control._accentWidth
        width:  control.radius
        height: parent.height
        color:  qgcPal.warningToastBackground
    }

    RowLayout {
        id:                     contentRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left:           parent.left
        anchors.right:          parent.right
        anchors.leftMargin:     control._h * 0.83
        anchors.rightMargin:    control._vPadding
        spacing:                control._h * 0.47

        Image {
            Layout.preferredWidth:  control._h * 1.26
            Layout.preferredHeight: control._h * 1.1
            source:                 "/res/WarningToastIcon.svg"
            sourceSize.width:       width
            sourceSize.height:      height
            fillMode:               Image.PreserveAspectFit
        }

        Text {
            Layout.fillWidth:   true
            wrapMode:           Text.WordWrap
            textFormat:         Text.StyledText
            font.family:        ScreenTools.demiboldFontFamily
            font.bold:          true
            font.pointSize:     ScreenTools.defaultFontPointSize * 0.8
            lineHeight:         1.1
            color:              qgcPal.warningToastText
            text: {
                var strong = control.strongText.length ? "<font color=\"" + qgcPal.warningToastTextStrong + "\">" + control._escape(control.strongText) + "</font>" : ""
                var body = control.textIsRichText ? control.text : control._escape(control.text)
                if (strong.length && body.length) {
                    return strong + " – " + body
                }
                return strong + body
            }
        }

        Rectangle {
            Layout.preferredWidth:  Math.max(1, control._h * 0.04)
            Layout.preferredHeight: control._h * 1.1
            color:                  qgcPal.warningToastDivider
            visible:                control.showCloseButton
        }

        Item {
            id:                     closeButton
            Layout.preferredWidth:  control._h * 1.5
            Layout.preferredHeight: control._h * 1.5
            visible:                control.showCloseButton

            Image {
                anchors.centerIn:   parent
                width:              control._h * 0.8
                height:             width
                sourceSize.width:   width
                sourceSize.height:  height
                source:             "/res/WarningToastClose.svg"
            }

            MouseArea {
                // 2H touch target around the 1.5H button
                anchors.centerIn:   parent
                width:              control._h * 2
                height:             width
                onClicked:          control.closeClicked()
            }
        }
    }
}
