/****************************************************************************
 * AQGC Simple UI — S43 camera settings (opened from the camera rail "Camera" button).
 * Only the five things changed most in the field, on the QGC MAVLink camera (QGCCameraControl):
 *   Camera     video streams of the camera (streamLabels / currentStream), when it has more than one
 *   Mode       photo / video (setPhotoMode / setVideoMode)
 *   Auto photos off / every 2 s / every 5 s (photoMode TIMELAPSE + photoLapse). Distance-based shooting is not in the
 *              camera protocol, so it is not offered here (decision 2026-11-16, Figma S43 note)
 *   Brightness camera definition parameter EO_EV (or CAM_EV); thermal stream: palette IR_PALETTE instead
 *   Grid lines videoSettings.gridLines
 * SD card free space from the camera. Everything else (resolution, file format, SD format, reset): S100 "More camera
 * settings ›" (SimpleCameraAll.qml, 2026-11-18).
 * Same place and size as the Payloads panel (S10); the two are never open together.
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

SPanel {
    id: cs
    property var vehicle: null

    readonly property var  _mgr:    vehicle ? vehicle.cameraManager : null
    readonly property var  _cam:    _mgr && _mgr.cameras.count > 0 ? _mgr.cameras.get(_mgr.currentCamera) : null
    readonly property bool _video:  !!_cam && _cam.cameraMode === 1
    readonly property var  _streams: _cam ? _cam.streamLabels : []
    readonly property bool _thermal: !!_cam && !!_cam.currentStreamInstance && _cam.currentStreamInstance.isThermal
    readonly property var  _grid:   QGroundControl.settingsManager.videoSettings.gridLines

    function _fact(names) {
        if (!_cam || !_cam.activeSettings) return null
        for (var i = 0; i < names.length; i++) if (_cam.activeSettings.indexOf(names[i]) >= 0) return _cam.getFact(names[i])
        return null
    }
    readonly property var evFact:      _fact(["EO_EV", "CAM_EV"])
    readonly property var paletteFact: _fact(["IR_PALETTE", "CAM_IRPALETTE"])

    // auto photos: 0 off, 1 every 2 s, 2 every 5 s
    readonly property int autoIndex: !_cam || _cam.photoMode !== 1 ? 0 : (_cam.photoLapse <= 3 ? 1 : 2)
    function setAuto(i) {
        if (!_cam) return
        if (i === 0) { _cam.photoMode = 0; return }
        _cam.photoLapse = i === 1 ? 2 : 5
        _cam.photoMode = 1
    }
    // EV options in the camera definition run from +10.5 (index 0) down to -10.5: "+" moves towards index 0
    function stepEv(dir) {
        if (!evFact) return
        var n = evFact.enumStrings.length, i = evFact.enumIndex
        var next = Math.max(0, Math.min(n - 1, i + (_evDescending ? -dir : dir)))
        if (next !== i) evFact.value = evFact.enumValues[next]
    }
    readonly property bool _evDescending: !!evFact && evFact.enumStrings.length > 1 && parseFloat(evFact.enumStrings[0]) > parseFloat(evFact.enumStrings[evFact.enumStrings.length - 1])

    property real maxHeight: SimpleTheme.px(690)
    width:  SimpleTheme.px(640)
    height: Math.min(col.height + SimpleTheme.px(136), maxHeight)
    title:  qsTr("Camera settings")
    titleIcon: "camera"

    SimpleCameraAll { id: allSettings; vehicle: cs.vehicle }

    Flickable {
        anchors.fill: parent
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col
            width: parent.width
            spacing: SimpleTheme.px(18)

            SText {
                visible: !cs._cam
                width: parent.width; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
                text: qsTr("The drone reports no camera with settings. Camera & gimbal payloads are set up in Settings › Payloads.")
            }

            // Camera (streams)
            Item {
                visible: cs._streams.length > 1
                width: parent.width; height: SimpleTheme.px(80)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Camera"); size: 24; color: SimpleTheme.textSecondary }
                SSegmented {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    designWidth: 400; model: cs._streams; currentIndex: cs._cam ? cs._cam.currentStream : 0
                    onActivated: cs._cam.currentStream = index
                }
            }
            // Mode
            Item {
                visible: !!cs._cam && cs._cam.hasModes
                width: parent.width; height: SimpleTheme.px(80)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Mode"); size: 24; color: SimpleTheme.textSecondary }
                SSegmented {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    designWidth: 400; model: [qsTr("Photo"), qsTr("Video")]; currentIndex: cs._video ? 1 : 0
                    onActivated: index === 1 ? cs._cam.setVideoMode() : cs._cam.setPhotoMode()
                }
            }
            // Auto photos (photo mode only)
            Item {
                visible: !!cs._cam && !cs._video
                width: parent.width; height: SimpleTheme.px(80)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Auto photos"); size: 24; color: SimpleTheme.textSecondary }
                SSegmented {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    designWidth: 400; model: [qsTr("Off"), qsTr("Every 2 s"), qsTr("Every 5 s")]; currentIndex: cs.autoIndex
                    onActivated: cs.setAuto(index)
                }
            }
            // Brightness (EV) — or the thermal palette on a thermal stream
            Item {
                visible: !!cs.evFact && !cs._thermal
                width: parent.width; height: SimpleTheme.px(88)
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    SText { text: qsTr("Brightness"); size: 24; color: SimpleTheme.textSecondary }
                    SText { text: qsTr("Exposure (EV)"); size: 20; color: SimpleTheme.textTertiary }
                }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    spacing: SimpleTheme.px(10)
                    SRoundIconButton { icon: "minus"; onClicked: cs.stepEv(-1) }
                    Rectangle {
                        width: SimpleTheme.px(180); height: SimpleTheme.px(80); radius: SimpleTheme.px(16); color: SimpleTheme.surfaceControl
                        SText { anchors.centerIn: parent; size: 28; bold: true; text: cs.evFact ? cs.evFact.enumStringValue : "—" }
                    }
                    SRoundIconButton { icon: "plus"; onClicked: cs.stepEv(1) }
                }
            }
            Item {
                visible: !!cs.paletteFact && cs._thermal
                width: parent.width; height: SimpleTheme.px(88)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Thermal palette"); size: 24; color: SimpleTheme.textSecondary }
                SComboBox {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    model: cs.paletteFact ? cs.paletteFact.enumStrings : []
                    currentIndex: cs.paletteFact ? cs.paletteFact.enumIndex : -1
                    onActivated: cs.paletteFact.value = cs.paletteFact.enumValues[index]
                }
            }
            // Grid lines
            Item {
                width: parent.width; height: SimpleTheme.px(80)
                SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Grid lines"); size: 24; color: SimpleTheme.textSecondary }
                SText { x: SimpleTheme.px(200); anchors.verticalCenter: parent.verticalCenter; text: qsTr("Show on video"); size: 22; color: SimpleTheme.textSecondary }
                SToggle {
                    id: gridToggle
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    checked: !!cs._grid.rawValue
                    onToggled: { cs._grid.rawValue = checked }
                }
            }
            // SD card
            Column {
                visible: !!cs._cam && cs._cam.storageTotal > 0
                width: parent.width
                spacing: SimpleTheme.px(10)
                Rectangle { width: parent.width; height: 1; color: SimpleTheme.line }
                Item {
                    width: parent.width; height: SimpleTheme.px(40)
                    SText { anchors.verticalCenter: parent.verticalCenter; text: qsTr("SD card"); size: 24; color: SimpleTheme.textSecondary }
                    SText {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; size: 24
                        readonly property real _ratio: cs._cam && cs._cam.storageTotal > 0 ? cs._cam.storageFree / cs._cam.storageTotal : 1
                        color: _ratio < 0.1 ? SimpleTheme.warn : SimpleTheme.textPrimary
                        text: qsTr("%1 free").arg(cs._cam ? cs._cam.storageFreeStr : "")
                    }
                }
                Rectangle {
                    width: parent.width; height: SimpleTheme.px(12); radius: height / 2; color: SimpleTheme.surfaceControl
                    Rectangle {
                        readonly property real _used: cs._cam && cs._cam.storageTotal > 0 ? 1 - cs._cam.storageFree / cs._cam.storageTotal : 0
                        width: parent.width * Math.max(0, Math.min(1, _used)); height: parent.height; radius: parent.radius
                        color: _used > 0.9 ? SimpleTheme.warn : SimpleTheme.ok
                    }
                }
            }
            SText {
                visible: !!cs._cam
                width: parent.width; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textLink
                text: qsTr("More camera settings ›")
                MouseArea { anchors.fill: parent; onClicked: allSettings.open() }
            }
        }
    }
}
