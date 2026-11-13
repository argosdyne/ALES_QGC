/****************************************************************************
 * AQGC Simple UI — camera rail (Figma ui/CameraRail): photo/video, shutter, gimbal angle
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl 1.0
import "."

Rectangle {
    id: rail
    property var vehicle: null
    readonly property var  _mgr:    vehicle ? vehicle.cameraManager : null
    readonly property var  _cam:    _mgr && _mgr.cameras.count > 0 ? _mgr.cameras.get(_mgr.currentCamera) : null
    readonly property bool _video:  _cam ? _cam.cameraMode === 1 : false
    readonly property bool _rec:    _cam ? _cam.videoStatus === 1 : false

    width:  SimpleTheme.px(128)
    height: col.implicitHeight + SimpleTheme.px(40)
    radius: width / 2
    color:  SimpleTheme.withAlpha(SimpleTheme.surfaceGlass, 0.92)
    border.width: SimpleTheme.px(2); border.color: SimpleTheme.line

    MouseArea { anchors.fill: parent }

    Column {
        id: col
        anchors.horizontalCenter: parent.horizontalCenter
        y: SimpleTheme.px(20)
        spacing: SimpleTheme.px(18)
        opacity: rail._cam ? 1 : 0.4

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
                            enabled: !!rail._cam && (index === 1) !== rail._video
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
            Rectangle {
                anchors.centerIn: parent
                width: rail._rec ? SimpleTheme.px(40) : SimpleTheme.px(80)
                height: width
                radius: rail._rec ? SimpleTheme.px(8) : width / 2
                color: rail._video ? SimpleTheme.danger : SimpleTheme.textPrimary
            }
            MouseArea {
                anchors.fill: parent
                enabled: !!rail._cam
                onClicked: {
                    if (!rail._video) rail._cam.takePhoto()
                    else if (rail._rec) rail._cam.stopVideo()
                    else rail._cam.startVideo()
                }
            }
        }
        // Gimbal pitch readout
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            SIcon { anchors.horizontalCenter: parent.horizontalCenter; name: "gimbal"; size: 40 }
            SText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: rail.vehicle && rail.vehicle.gimbalData ? Math.round(rail.vehicle.gimbalPitch) + "°" : "—"
                size: 22; color: SimpleTheme.textSecondary
            }
        }
    }
}
