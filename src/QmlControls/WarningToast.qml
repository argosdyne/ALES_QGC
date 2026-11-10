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
    /// Rest of the message (plain text unless textIsRichText). Key phrases marked with <b>...</b> are drawn
    /// in the strong text color, also in plain text (e.g. marks inside a translated string).
    property string text
    property bool   textIsRichText: false
    property bool   showCloseButton: true

    signal closeClicked

    // Sizes in Figma design pixels (ScreenTools.figmaPx)
    readonly property real _px:         ScreenTools.figmaPx
    readonly property real _accentWidth: _px * 15
    readonly property real _vPadding:   _px * 6

    implicitWidth:  Math.round(_px * 677)
    implicitHeight: Math.max(contentRow.implicitHeight, closeButton.height) + (_vPadding * 2)
    radius:         _px * 18
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
        anchors.leftMargin:     control._px * 31.5
        anchors.rightMargin:    control._vPadding
        spacing:                control._px * 18

        Image {
            Layout.preferredWidth:  control._px * 53.4
            Layout.preferredHeight: control._px * 46.7
            source:                 "/res/WarningToastIcon.svg"
            sourceSize.width:       width
            sourceSize.height:      height
            fillMode:               Image.PreserveAspectFit
        }

        Text {
            Layout.fillWidth:   true
            wrapMode:           Text.WordWrap
            textFormat:         Text.StyledText
            // Figma "QGC/Warning": Roboto Bold. The regular family with bold picks the real Bold face;
            // bold on the Medium (demibold) family would only embolden Medium synthetically.
            font.family:        ScreenTools.normalFontFamily
            font.bold:          true
            // 25 px as drawn in the Fly view frames (the 609 px component scaled to 677 px; the reported
            // 22.5 px is the unscaled size)
            font.pointSize:     ScreenTools.figmaFontPointSize(25)
            // Figma line height 1.35 x font size (a proportional lineHeight would scale Roboto's taller line)
            lineHeightMode:     Text.FixedHeight
            lineHeight:         control._px * 25 * 1.35
            color:              qgcPal.warningToastText
            text: {
                var strongOpen = "<font color=\"" + qgcPal.warningToastTextStrong + "\">"
                var strong = control.strongText.length ? strongOpen + control._escape(control.strongText) + "</font>" : ""
                var body = control.textIsRichText ? control.text : control._escape(control.text)
                body = body.replace(/<b>|&lt;b&gt;/g, strongOpen).replace(/<\/b>|&lt;\/b&gt;/g, "</font>")
                if (strong.length && body.length) {
                    return strong + " – " + body
                }
                return strong + body
            }
        }

        Rectangle {
            Layout.preferredWidth:  Math.max(1, control._px * 1.7)
            Layout.preferredHeight: control._px * 46.7
            color:                  qgcPal.warningToastDivider
            visible:                control.showCloseButton
        }

        Item {
            id:                     closeButton
            Layout.preferredWidth:  control._px * 63.4
            Layout.preferredHeight: control._px * 63.4
            visible:                control.showCloseButton

            Image {
                anchors.centerIn:   parent
                width:              control._px * 33.4
                height:             width
                sourceSize.width:   width
                sourceSize.height:  height
                source:             "/res/WarningToastClose.svg"
            }

            MouseArea {
                // 76 px touch target around the 63 px button
                anchors.centerIn:   parent
                width:              control._px * 76
                height:             width
                onClicked:          control.closeClicked()
            }
        }
    }
}
