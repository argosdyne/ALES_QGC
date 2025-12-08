/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick 2.12

// Used to manage state for itesm using with QGCPipOveral
Item {
    id:     control
    state:  initState

    readonly property string initState:             "init"
    readonly property string pipState:              "pip"
    readonly property string fullState:             "full"
    readonly property string fpvState:              "fpv"
    readonly property string windowState:           "window"

    property var  pipOverlay            // QGCPipOverlay control
    property var  fpvOverlay            // FPVOverlay control
    property bool isDark:       true    // true: Use dark overlay visuals
    property bool canWindow:    true

    signal windowAboutToOpen    // Catch this signal to do something special prior to the item transition to windowed mode
    signal windowAboutToClose   // Catch this signal to do special processing prior to the item transition back to pip mode

    property var _viewControl: control.parent

    states: [
        State {
            name: pipState

            AnchorChanges {
                target:         _viewControl
                anchors.top:    pipOverlay.top
                anchors.bottom: pipOverlay.bottom
                anchors.left:   pipOverlay.left
                anchors.right:  pipOverlay.right
            }

            PropertyChanges {
                target: _viewControl
                z: pipOverlay.z - 1
            }
        },
        State {
            name: fullState

            AnchorChanges {
                target:         _viewControl
                anchors.top:    pipOverlay.parent.top
                anchors.bottom: pipOverlay.parent.bottom
                anchors.left:   pipOverlay.parent.left
                anchors.right:  pipOverlay.parent.right
            }

            PropertyChanges {
                target: _viewControl
                z: 0
            }
        },
        State {
            name: fpvState

            AnchorChanges {
                target:         _viewControl
                anchors.top:    fpvOverlay.top
                anchors.right:  fpvOverlay.right
                anchors.left:   fpvOverlay.left
                anchors.bottom: fpvOverlay.bottom
            }

            PropertyChanges {
                target: _viewControl
                z: fpvOverlay.z - 1
            }
        },
        State {
            name: windowState

            ParentChange {
                target: _viewControl
                parent: pipOverlay._windowContentItem
            }

            AnchorChanges {
                target:         _viewControl
                anchors.top:    pipOverlay._windowContentItem.top
                anchors.bottom: pipOverlay._windowContentItem.bottom
                anchors.left:   pipOverlay._windowContentItem.left
                anchors.right:  pipOverlay._windowContentItem.right
            }

            StateChangeScript {
                script: {
                    control.windowAboutToOpen()
                    pipOverlay.showWindow()
                }
            }
        }
    ]
}
