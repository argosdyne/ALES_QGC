import QtQuick 2.12

import QGroundControl 1.0
import QGroundControl.Controls 1.0
import QGroundControl.Controllers 1.0
import QGroundControl.ScreenTools 1.0
import QGroundControl.FlightMap 1.0

Rectangle {
    id: _root
    clip: true
    color: "black"
    visible: !QGroundControl.settingsManager.videoSettings.disableFPVVideo.value
    property Item pipState: fpvPipState
    PipState {
        id:         fpvPipState
        pipOverlay: _pipOverlay
        fpvOverlay: _fpvOverlay
        isDark:     true
        state:      fpvPipState.fpvState

        onWindowAboutToOpen: {
            QGroundControl.videoManager.stopVideo(2)
            fpvStartDelay.start()
        }

        onWindowAboutToClose: {
            QGroundControl.videoManager.stopVideo(2)
            fpvStartDelay.start()
        }

        onStateChanged: {
            if (pipState.state !== pipState.fullState && pipOverlay.item2 === parent) {
                QGroundControl.videoManager.fullScreen = false
            }
        }
    }
    Timer {
        id:           fpvStartDelay
        interval:     2000;
        running:      false
        repeat:       false
        onTriggered:  QGroundControl.videoManager.startVideo(2)
    }
    //-- FPV
    QGCVideoBackground {
        id:             fpvVideo
        objectName:     "fpvContent"
        anchors.fill:   parent
    }
}
