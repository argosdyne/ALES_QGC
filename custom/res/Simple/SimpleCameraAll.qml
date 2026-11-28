/****************************************************************************
 * AQGC Simple UI — S100 All camera settings (Figma 175:46891, 2026-11-18). Opened from S43 "More camera settings ›".
 * Replaces the classic camera Settings dialog (PhotoVideoControl, removed with the classic UI):
 *   every setting the camera reports (camera definition: resolution, file format, …) — list = drop-down,
 *   on/off = switch, number = − value +, text = field; thermal view and blend opacity (thermal stream only);
 *   video fit; SD card format and camera factory reset, each asked once inline (SimpleManualLinks pattern).
 * Same QGCCameraControl calls as the classic dialog (getFact, thermalMode / thermalOpacity, formatCard, resetSettings).
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import QGroundControl.Vehicle 1.0
import "."

SSheet {
    id: ca
    property var vehicle: null
    readonly property var  _mgr:  vehicle ? vehicle.cameraManager : null
    readonly property var  _cam:  _mgr && _mgr.cameras.count > 0 ? _mgr.cameras.get(_mgr.currentCamera) : null
    readonly property var  _video: QGroundControl.settingsManager.videoSettings
    readonly property bool _hasThermal: !!_cam && !!_cam.thermalStreamInstance
    readonly property bool _busy: !!_cam && (_cam.videoStatus === QGCCameraControl.VIDEO_CAPTURE_STATUS_RUNNING
                                            || _cam.photoStatus === QGCCameraControl.PHOTO_CAPTURE_IN_PROGRESS
                                            || _cam.photoStatus === QGCCameraControl.PHOTO_CAPTURE_INTERVAL_IN_PROGRESS)
    readonly property bool _storage: !!_cam && _cam.storageStatus !== QGCCameraControl.STORAGE_NOT_SUPPORTED
    property string confirm: ""          // "" | "format" | "reset"
    // SD format target (Tuleap bug #9428): a camera with a photo card and a video card (Sony body SD + gimbal
    // microSD) reports two storage pools; the user picks which one is erased. One pool (or a camera without the
    // list) keeps the old behaviour: storage 1.
    readonly property var  _pools: !!_cam && _cam.storagePools !== undefined ? _cam.storagePools : []
    property int formatId: 1
    function _poolLabel(p) {
        if (p.photo && !p.video) return qsTr("Photo card")
        if (p.video && !p.photo) return qsTr("Video card")
        return p.name !== "" ? p.name : qsTr("Card %1").arg(p.id)
    }
    // default: the card of the current camera mode
    function _defaultFormatId() {
        var video = !!_cam && _cam.cameraMode === QGCCameraControl.CAM_MODE_VIDEO
        for (var i = 0; i < _pools.length; i++) if (video ? _pools[i].video : _pools[i].photo) return _pools[i].id
        return _pools.length > 0 ? _pools[0].id : 1
    }
    property string done: ""

    designWidth: 1000
    closeOnOutside: true
    title: qsTr("All camera settings")
    subtitle: !_cam ? "" : qsTr("What the camera reports — the list differs by camera.")
                     + (_cam.modelName ? " " + qsTr("Camera %1").arg(_cam.modelName) : "")
                     + (_cam.firmwareVersion ? " · " + qsTr("firmware %1").arg(_cam.firmwareVersion) : "")
    onOpened: { confirm = ""; done = "" }

    SText {
        visible: !ca._cam
        width: ca.innerWidth; wrapMode: Text.WordWrap; size: 24; color: SimpleTheme.textSecondary
        text: qsTr("The drone reports no camera with settings.")
    }

    // Camera (more than one camera on the drone)
    SSettingRow {
        visible: !!ca._mgr && ca._mgr.cameraLabels.length > 1
        width: ca.innerWidth; title: qsTr("Camera")
        SComboBox { designWidth: 400; model: ca._mgr ? ca._mgr.cameraLabels : []; currentIndex: ca._mgr ? ca._mgr.currentCamera : -1
                    onActivated: ca._mgr.currentCamera = index }
    }

    SText { visible: !!ca._cam && ca._cam.activeSettings.length > 0; text: qsTr("PHOTO & VIDEO"); size: 22; medium: true; color: SimpleTheme.textTertiary }
    Repeater {
        model: ca._cam ? ca._cam.activeSettings : []
        SSettingRow {
            id: setRow
            readonly property var  f: ca._cam ? ca._cam.getFact(modelData) : null
            readonly property bool isBool: !!f && f.typeIsBool
            readonly property bool isList: !!f && !isBool && f.enumStrings.length > 0
            readonly property bool isText: !!f && f.typeIsString
            width: ca.innerWidth
            title: f ? (f.shortDescription || modelData) : modelData
            locked: !!f && f.readOnly
            Row {       // a Row skips the hidden editors, so the visible one sits at the right edge
                SToggle {
                    id: tg
                    visible: setRow.isBool
                    checked: !!setRow.f && !!setRow.f.value
                    onToggled: { setRow.f.value = checked ? 1 : 0 }
                }
                SFactField { visible: !setRow.isBool && !setRow.isText; fact: setRow.isBool || setRow.isText ? null : setRow.f; designWidth: 420 }
                STextField {
                    visible: setRow.isText; designWidth: 420
                    text: setRow.f && setRow.isText ? setRow.f.valueString : ""
                    onEdited: setRow.f.value = text
                }
            }
        }
    }

    SText { visible: !!ca._cam; text: qsTr("VIEW"); size: 22; medium: true; color: SimpleTheme.textTertiary }
    SSettingRow {
        visible: ca._hasThermal
        width: ca.innerWidth; title: qsTr("Thermal view")
        SComboBox {
            designWidth: 420
            model: [qsTr("Off"), qsTr("Blend"), qsTr("Full"), qsTr("Picture in picture")]
            currentIndex: ca._cam ? ca._cam.thermalMode : 0
            onActivated: ca._cam.thermalMode = index
        }
    }
    SSettingRow {
        visible: ca._hasThermal && ca._cam.thermalMode === QGCCameraControl.THERMAL_BLEND
        width: ca.innerWidth; title: qsTr("Blend"); sub: qsTr("How much of the thermal picture shows")
        SStepper { value: ca._cam ? Math.round(ca._cam.thermalOpacity) : 50; from: 0; to: 100; step: 10; unit: "%"
                   onEdited: ca._cam.thermalOpacity = value }
    }
    SSettingRow {
        visible: !!ca._cam
        width: ca.innerWidth; title: qsTr("Video fit"); sub: qsTr("How the video fills the screen")
        SFactField { fact: ca._video.videoFit; designWidth: 420 }
    }

    // SD card and factory reset
    SText { visible: ca._storage; text: qsTr("SD CARD"); size: 22; medium: true; color: SimpleTheme.textTertiary }
    SSettingRow {
        visible: ca._storage
        width: ca.innerWidth
        title: !ca._cam ? "" : ca._cam.storageStatus === QGCCameraControl.STORAGE_EMPTY ? qsTr("No SD card")
             : ca._cam.storageStatus === QGCCameraControl.STORAGE_UNFORMATTED ? qsTr("SD card not formatted")
             : ca._cam.storageTotal > 0 ? qsTr("%1 free of %2").arg(ca._cam.storageFreeStr).arg(ca._fmtMB(ca._cam.storageTotal))
             : qsTr("%1 free").arg(ca._cam.storageFreeStr)
        sub: ca._busy ? qsTr("Stop recording and photos first") : ""
        SButton {
            designHeight: 72; textSize: 26; kind: "danger"; text: qsTr("Format SD card…")
            enabled_: !ca._busy && ca.confirm === "" && ca._cam && ca._cam.storageStatus !== QGCCameraControl.STORAGE_EMPTY
            onClicked: if (enabled_) { ca.formatId = ca._defaultFormatId(); ca.confirm = "format"; ca.done = "" }
        }
    }
    SSettingRow {
        visible: !!ca._cam
        width: ca.innerWidth; title: qsTr("Camera settings back to factory values")
        SButton { designHeight: 72; textSize: 26; text: qsTr("Reset camera…"); enabled_: !ca._busy && ca.confirm === ""
                  onClicked: if (enabled_) { ca.confirm = "reset"; ca.done = "" } }
    }
    SText {
        visible: ca.confirm === "format" && ca._pools.length > 1
        text: qsTr("Which card?"); size: 24; medium: true
    }
    SSegmented {
        id: formatSeg
        visible: ca.confirm === "format" && ca._pools.length > 1
        designWidth: 600
        model: { var m = []; for (var i = 0; i < ca._pools.length; i++) m.push(ca._poolLabel(ca._pools[i])); return m }
        // set when the question opens (a tap replaces a binding on currentIndex)
        function sync() { currentIndex = 0; for (var i = 0; i < ca._pools.length; i++) if (ca._pools[i].id === ca.formatId) currentIndex = i }
        onVisibleChanged: if (visible) sync()
        onActivated: ca.formatId = ca._pools[index].id
    }
    SNotice {
        visible: ca.confirm !== ""
        width: ca.innerWidth; level: "warn"
        text: ca.confirm === "format" ? qsTr("Erase all photos and videos on the camera's SD card? This cannot be undone.")
                                      : qsTr("Set every camera setting back to its factory value?")
    }
    Row {
        visible: ca.confirm !== ""
        spacing: SimpleTheme.px(14)
        SButton { designHeight: 72; textSize: 26; text: qsTr("Cancel"); onClicked: ca.confirm = "" }
        SButton {
            designHeight: 72; textSize: 26; kind: "danger"
            text: ca.confirm === "format" ? qsTr("Erase SD card") : qsTr("Reset camera")
            enabled_: !ca._busy
            onClicked: {
                if (!enabled_ || !ca._cam) return
                if (ca.confirm === "format") { ca._cam.formatCard(ca.formatId); ca.done = qsTr("Formatting the SD card…") }
                else { ca._cam.resetSettings(); ca.done = qsTr("Camera settings reset.") }
                ca.confirm = ""
            }
        }
    }
    SText { visible: ca.done !== ""; width: ca.innerWidth; wrapMode: Text.WordWrap; size: 22; color: SimpleTheme.textSecondary; text: ca.done }

    function _fmtMB(mb) { return mb >= 1024 ? (mb / 1024).toFixed(mb >= 10240 ? 0 : 1) + " GB" : mb + " MB" }

    SButton { width: ca.innerWidth; designHeight: 80; kind: "primary"; text: qsTr("Done"); onClicked: ca.close() }
}
