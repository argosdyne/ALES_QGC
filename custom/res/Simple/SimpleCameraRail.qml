/****************************************************************************
 * AQGC Simple UI — camera rail (Figma ui/CameraRail): photo/video, shutter, gimbal angle
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import QGroundControl.Vehicle 1.0
import "."

Rectangle {
    id: rail
    property var vehicle: null
    property bool blocked: false        // S49 waiting for video: photo and record are greyed
    property bool settingsOpen: false   // S43 camera settings sheet is open
    signal settingsClicked()
    readonly property var  _mgr:    vehicle ? vehicle.cameraManager : null
    readonly property var  _cam:    _mgr && _mgr.cameras.count > 0 ? _mgr.cameras.get(_mgr.currentCamera) : null
    readonly property bool _video:  _cam ? _cam.cameraMode === 1 : false
    readonly property bool _rec:    _cam ? _cam.videoStatus === 1 : false
    // SD card (bug #9553 / #316, Figma 99 Components "ui/CameraRail · state: No SD card"): same rule as the classic
    // photo/video control: a camera that reports storage shoots only with a ready card with free space. The camera
    // control refuses photo / record start without a card, so the rail says why instead of doing nothing.
    readonly property string _sdProblem: {
        if (!_cam || _cam.storageStatus === QGCCameraControl.STORAGE_NOT_SUPPORTED) return ""
        if (_cam.storageStatus === QGCCameraControl.STORAGE_EMPTY)       return qsTr("No SD card")
        if (_cam.storageStatus === QGCCameraControl.STORAGE_UNFORMATTED) return qsTr("SD card not formatted")
        if (_cam.storageStatus === QGCCameraControl.STORAGE_READY && _cam.storageFree === 0) return qsTr("SD card full")
        return ""
    }
    readonly property bool _canShoot: _sdProblem === ""
    // Photo feedback (Tuleap bug #27537): the shutter shows a red square while the camera reports a capture
    // (single or interval). Cameras that do not report it still flash for a moment after the tap.
    readonly property bool _capturing: !!_cam && !_video && (_cam.photoStatus === QGCCameraControl.PHOTO_CAPTURE_IN_PROGRESS
                                                            || _cam.photoStatus === QGCCameraControl.PHOTO_CAPTURE_INTERVAL_IN_PROGRESS)
    readonly property bool _interval: !!_cam && !_video && (_cam.photoStatus === QGCCameraControl.PHOTO_CAPTURE_INTERVAL_IDLE
                                                            || _cam.photoStatus === QGCCameraControl.PHOTO_CAPTURE_INTERVAL_IN_PROGRESS)
    property bool _flash: false
    Timer { id: flashTimer; interval: 400; onTriggered: rail._flash = false }
    // Gimbal align (Tuleap bug #27594): same order as the classic refresh icon (#315): R3 also resets the zoom
    function alignGimbal() {
        if (_cam && typeof _cam.resetGimbalAndZoom === "function") { _cam.resetGimbalAndZoom(); _cam.centerGimbal() }
        else if (_cam && typeof _cam.centerGimbal === "function") _cam.centerGimbal()
        else if (vehicle && vehicle.gimbalController) vehicle.gimbalController.centerGimbal()
        alignAnim.restart()
    }

    width:  SimpleTheme.px(128)
    height: settingsBtn.y + settingsBtn.height + SimpleTheme.px(20)
    radius: width / 2
    color:  SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
    border.width: SimpleTheme.px(2); border.color: SimpleTheme.line

    MouseArea { anchors.fill: parent }

    Column {
        id: col
        anchors.horizontalCenter: parent.horizontalCenter
        y: SimpleTheme.px(20)
        spacing: SimpleTheme.px(18)
        opacity: rail._cam && !rail.blocked ? 1 : 0.4

        // Photo / Video
        Rectangle {
            width: SimpleTheme.px(96); height: SimpleTheme.px(176); radius: width / 2
            color: SimpleTheme.surfaceControl
            Column {
                anchors.centerIn: parent
                spacing: SimpleTheme.px(4)
                Repeater {
                    model: [ "camera", "video" ]
                    Rectangle {
                        width: SimpleTheme.px(84); height: width; radius: width / 2
                        color: (index === 1) === rail._video ? SimpleTheme.textPrimary : "transparent"
                        SIcon { anchors.centerIn: parent; name: modelData; size: 40; color: (index === 1) === rail._video ? SimpleTheme.bgBase : SimpleTheme.textPrimary }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !!rail._cam && !rail.blocked && (index === 1) !== rail._video
                            onClicked: rail._cam.toggleMode()
                        }
                    }
                }
            }
        }
        // Shutter
        Rectangle {
            width: SimpleTheme.px(104); height: width; radius: width / 2
            color: "transparent"
            border.width: SimpleTheme.px(5); border.color: SimpleTheme.textPrimary
            opacity: rail._canShoot || rail._rec ? 1 : 0.4      // stopping a recording is always allowed
            Rectangle {
                readonly property bool _busy: rail._rec || rail._capturing || rail._interval || rail._flash
                anchors.centerIn: parent
                width: _busy ? SimpleTheme.px(40) : SimpleTheme.px(80)
                height: width
                radius: _busy ? SimpleTheme.px(8) : width / 2
                color: rail._video || _busy ? SimpleTheme.danger : SimpleTheme.textPrimary
                Behavior on width { NumberAnimation { duration: 120 } }
            }
            MouseArea {
                anchors.fill: parent
                enabled: !!rail._cam && !rail.blocked
                onClicked: {
                    if (rail._rec) { rail._cam.stopVideo(); return }
                    if (rail._interval) { rail._cam.stopTakePhoto(); return }     // auto photos (S43): tap stops them
                    if (!rail._canShoot) { sdBlink.restart(); return }
                    if (!rail._video) { rail._cam.takePhoto(); rail._flash = true; flashTimer.restart() }
                    else rail._cam.startVideo()
                }
            }
        }
        SText {
            id: sdLabel
            anchors.horizontalCenter: parent.horizontalCenter
            visible: rail._sdProblem !== ""
            width: SimpleTheme.px(112)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: rail._sdProblem
            size: 20; medium: true; color: SimpleTheme.warn
            SequentialAnimation {
                id: sdBlink
                loops: 2
                NumberAnimation { target: sdLabel; property: "opacity"; to: 0.2; duration: 150 }
                NumberAnimation { target: sdLabel; property: "opacity"; to: 1;   duration: 150 }
            }
        }
        // Gimbal: tap = align (pitch 0, yaw ahead; R3 also zoom 1×). Pitch and yaw are shown (pitch · yaw)
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: SimpleTheme.px(112); height: gimbalCol.height
            Column {
                id: gimbalCol
                anchors.horizontalCenter: parent.horizontalCenter
                SIcon { id: gimbalIcon; anchors.horizontalCenter: parent.horizontalCenter; name: "gimbal"; size: 40
                        RotationAnimation on rotation { id: alignAnim; running: false; from: 0; to: 360; duration: 500 } }
                SText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: rail.vehicle && rail.vehicle.gimbalData
                          ? Math.round(rail.vehicle.gimbalPitch) + "° · " + Math.round(rail.vehicle.gimbalYaw) + "°" : "—"
                    size: 20; color: SimpleTheme.textSecondary
                }
                SText { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("Align"); size: 18; color: SimpleTheme.textSecondary }
            }
            MouseArea { anchors.fill: parent; anchors.margins: -SimpleTheme.px(8); enabled: !!rail._cam || !!(rail.vehicle && rail.vehicle.gimbalData); onClicked: rail.alignGimbal() }
        }
    }
    // S43: camera settings (works without a MAVLink camera too: the sheet then says what is available)
    Item {
        id: settingsBtn
        anchors.horizontalCenter: parent.horizontalCenter
        y: col.y + col.height + SimpleTheme.px(22)
        width: btnCol.width; height: btnCol.height
        Column {
            id: btnCol
            SIcon { anchors.horizontalCenter: parent.horizontalCenter; name: "sliders"; size: 40
                    color: rail.settingsOpen ? SimpleTheme.ok : SimpleTheme.textPrimary }
            SText { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("Camera"); size: 20
                    color: rail.settingsOpen ? SimpleTheme.ok : SimpleTheme.textSecondary }
        }
        MouseArea { anchors.fill: parent; anchors.margins: -SimpleTheme.px(14); onClicked: rail.settingsClicked() }
    }
}
