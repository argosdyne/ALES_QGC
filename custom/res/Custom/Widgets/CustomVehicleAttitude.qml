import QtQuick 2.15
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.0
import QGroundControl.Controls 1.0
import QGroundControl.ScreenTools 1.0
import QGroundControl.Palette 1.0

Item {
    id: _root
    property real size: ScreenTools.defaultFontPixelHeight * 10
    property color color: "#0DB404"
    property bool _needPaint: true

    property real homeAngle: _activeVehicle ? _activeVehicle.headingToHome.rawValue : 0
    property real vehicleHeading: _activeVehicle ? _activeVehicle.heading.rawValue : 0

    // Need requestPaint
    property real cruiseSpeed: _activeVehicle ? _activeVehicle.groundSpeed.rawValue : 0
    property real climbSpeed: _activeVehicle ? _activeVehicle.climbRate.rawValue : 0
    property real vehicleRoll: _activeVehicle ? _activeVehicle.roll.rawValue : 0
    property real vehiclePitch: _activeVehicle ? _activeVehicle.pitch.rawValue : 0

    property real vehicleHeightDiff: _activeVehicle ? _activeVehicle.heightDiff.toFixed(0) : 0
    property real vehicleDistanceDiff: _activeVehicle ? _activeVehicle.distanceDiff.toFixed(0) : 0

    onSizeChanged: _needPaint = true
    onColorChanged: _needPaint = true
    onHomeAngleChanged: _needPaint = true
    onVehicleHeadingChanged: _needPaint = true
    onCruiseSpeedChanged: _needPaint = true
    onClimbSpeedChanged: _needPaint = true
    onVehicleRollChanged: _needPaint = true
    onVehiclePitchChanged: _needPaint = true
    onVehicleHeightDiffChanged: _needPaint = true
    onVehicleDistanceDiffChanged: _needPaint = true

    QGCPalette { id: qgcPal; colorGroupEnabled: enabled }
    Timer {
        interval: 100
        repeat: true
        running: true
        function getRandomNum(min,max){
            var Range = max - min;
            return (min + Math.round(Math.random() *Range))
        }

        onTriggered: {
//            homeAngle += 5
//            vehicleHeading -= 5
//            vehicleDistanceDiff = getRandomNum(0,distanceMaxValue)
//            vehicleHeightDiff = getRandomNum(0,heightMaxValue)
//            climbSpeed = getRandomNum(0,climbSpeedMaxValue)
//            cruiseSpeed = getRandomNum(0,cruiseSpeedMaxValue)
//            vehicleRoll = getRandomNum(-90,90)
//            vehiclePitch = getRandomNum(-90,90)
            if(_needPaint) {
                _needPaint = false
                canvas.requestPaint()
            }
        }
    }

    property real _realSize: 2 * Math.round(size / 2)
    readonly property real offset_x: _realSize / 360
    readonly property real offset_y: _realSize / 90
    readonly property real raduis: _realSize * 0.98
    readonly property real lineWidth: _realSize / 60

    readonly property real cruiseSpeedEndPoint: 0.477   //2.67
    readonly property real cruiseSpeedStartPoint: -0.52 //3.66
    readonly property real cruiseSpeedMaxValue: 20
    property real cruiseSpeedValue: Math.min(cruiseSpeed, cruiseSpeedMaxValue)

    readonly property real climbSpeedTopPoint: 2.67     //0.477
    readonly property real climbSpeedCenterPoint: 3.165 //-0.0215
    readonly property real climbSpeedBottomPoint: 3.66  //-0.52
    readonly property real climbSpeedMaxValue: 5
    property real climbSpeedValue: Math.min(Math.abs(climbSpeed), climbSpeedMaxValue)

    readonly property real distanceMaxLength: _realSize * 0.394
    readonly property point distanceStartPoint: Qt.point(_root.width - _realSize / 50, _realSize * 0.514)
    readonly property real distanceMaxValue: 1000
    property real distanceDiffValue: Math.abs(vehicleDistanceDiff) > distanceMaxValue ? (distanceMaxValue * (vehicleDistanceDiff > 0 ? 1 : -1)) : vehicleDistanceDiff

    readonly property real heightMaxLength: _realSize * 0.394
    readonly property point heightStartPoint: Qt.point(_realSize / 50, _realSize * 0.514)
    readonly property real heightMaxValue: 1000
    property real heightDiffValue: Math.abs(vehicleHeightDiff) > heightMaxValue ? (heightMaxValue * (vehicleHeightDiff > 0 ? 1 : -1)) : vehicleHeightDiff

    readonly property real pitchLength: _realSize * 0.29
    readonly property real centerLineWidth: _realSize / 90
    readonly property real centerOffset_x: _root.width / 2
    readonly property real centerOffset_y: _root.height / 2 + _realSize / 72

    implicitHeight: _realSize
    implicitWidth: _realSize * 2.61
    Image {
        id:                 background
        source:             "qrc:/custom/img/aircraftAttitudeBackGround.svg"
        mipmap:             true
        fillMode:           Image.PreserveAspectFit
        anchors.fill:       parent
        sourceSize.height:  parent.height
    }
    Image {
        id:                 compassBarbackground
        source:             "qrc:/custom/img/aircraftAttitudeScale.svg"
        mipmap:             true
        fillMode:           Image.PreserveAspectFit
        y:                  -_realSize / 45
        anchors.horizontalCenter: parent.horizontalCenter
        width:              height
        height:             _realSize * 1.08
        sourceSize.height:  parent.height
        rotation:           -vehicleHeading
        transitions: Transition {
            RotationAnimation { duration: 100; }
        }
    }
    Image {
        id: homePoint
        width: height
        height: _realSize * 0.1
        x: (_root.width - width) * 0.5
        y: _root.height * 0.1
        source: "qrc:/custom/img/homePoint.svg"
        sourceSize.height: height
        sourceSize.width: width
        smooth: true
        mipmap: true
        antialiasing: true
        fillMode: Image.PreserveAspectFit
        transitions: Transition {
            RotationAnimation { duration: 100; }
        }
        transform: Rotation {
            origin.x:       homePoint.width  / 2
            origin.y:       _root.height * 0.417
            angle:          homeAngle - vehicleHeading
        }
    }
    QGCLabel {
        id: cruiseUnit
        font.bold: true
        font.pointSize: ScreenTools.defaultFontPointSize
        y: -height/3
        x: _realSize * 2.105 - width
        color: "white"
        text: _activeVehicle ? _activeVehicle.groundSpeed.units : ""
    }
    QGCLabel {
        id: cruiseTitle
        font.bold: true
        font.pointSize: ScreenTools.defaultFontPointSize
        anchors.left: cruiseUnit.left
        anchors.bottom: parent.bottom
        color: "white"
        text: "H.S."
    }
    QGCLabel {
        font.bold: true
        font.pointSize: ScreenTools.defaultFontPointSize
        anchors.top: cruiseUnit.bottom
        anchors.right: cruiseUnit.right
        anchors.rightMargin: -_realSize * 0.04
        color: _root.color
        text: _activeVehicle ? _activeVehicle.groundSpeed.valueString : 0
    }
    QGCLabel {
        id: climbUnit
        font.bold: true
        font.pointSize: ScreenTools.defaultFontPointSize
        y: -height/3
        x: _realSize * 0.5
        color: "white"
        text: _activeVehicle ? _activeVehicle.climbRate.units : ""
    }
    QGCLabel {
        id: climbTitle
        font.bold: true
        font.pointSize: ScreenTools.defaultFontPointSize
        anchors.right: climbUnit.right
        anchors.bottom: parent.bottom
        color: "white"
        text: "V.S."
    }
    QGCLabel {
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
        font.pointSize: ScreenTools.defaultFontPointSize
        anchors.left: climbUnit.left
        anchors.leftMargin: -_realSize * 0.12
        color: _root.color
        text: _activeVehicle ? _activeVehicle.climbRate.valueString : 0
    }
    QGCLabel {
        id: heightUnit
        font.bold: true
        font.pointSize: ScreenTools.defaultFontPointSize
        y: 0
        anchors.right: parent.left
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.5
        color: "white"
        text: _activeVehicle ? _activeVehicle.altitudeRelative.units : ""
    }
    QGCLabel {
        font.bold: true
        font.pointSize: ScreenTools.defaultFontPointSize
        anchors.right: heightUnit.right
        anchors.bottom: heightLabel.top
        color: "white"
        text: "ALT"
    }
    QGCLabel {
        id: heightLabel
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
        font.pointSize: ScreenTools.mediumFontPointSize
        anchors.right: heightUnit.right
        color: _root.color
        text: _activeVehicle ? _activeVehicle.altitudeRelative.valueString : 0
    }
    QGCLabel {
        id: distUnit
        font.bold: true
        font.pointSize: ScreenTools.defaultFontPointSize
        y: 0
        anchors.left: parent.right
        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.5
        color: "white"
        text: _activeVehicle ? _activeVehicle.distanceToHome.units : ""
    }
    QGCLabel {
        font.bold: true
        anchors.left: distUnit.left
        anchors.bottom: distanceLabel.top
        color: "white"
        text: "DIST"
    }
    QGCLabel {
        id: distanceLabel
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
        font.pointSize: ScreenTools.mediumFontPointSize
        anchors.left: distUnit.left
        color: _root.color
        text: _activeVehicle ? _activeVehicle.distanceToHome.valueString : 0
    }
    QGCLabel {
        font.bold: true
        anchors.horizontalCenter: parent.horizontalCenter
        font.pointSize: ScreenTools.mediumFontPointSize
        anchors.bottom: parent.top
        anchors.bottomMargin: ScreenTools.defaultFontPixelWidth * 0.2
        color: _root.color
        text: _activeVehicle ? _activeVehicle.heading.valueString : 0
    }
    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0,0,_root.width,_root.height);
            ctx.lineCap = "round";

            drawCruiseSpeed(ctx);
            drawClimbSpeed(ctx);
            drawDistance(ctx);
            drawHeight(ctx);
            //drawPitchRoll(ctx);
            drawArcAndClip(ctx)
            ctx.restore();
        }

        function drawCruiseSpeed(ctx) {
            ctx.beginPath();
            ctx.arc(_root.width / 2 - offset_x, _root.height / 2 + offset_y, raduis, cruiseSpeedEndPoint - (cruiseSpeedEndPoint - cruiseSpeedStartPoint) * (cruiseSpeedValue / cruiseSpeedMaxValue), cruiseSpeedEndPoint, false);
            ctx.lineWidth = lineWidth;
            ctx.strokeStyle = _root.color;
            ctx.stroke();
        }

        function drawClimbSpeed(ctx) {
            ctx.beginPath();
            var clockwise = (climbSpeed < 0);
            var normalizate = (climbSpeedValue / climbSpeedMaxValue);
            var endPoint = clockwise ? (climbSpeedCenterPoint - (climbSpeedBottomPoint - climbSpeedCenterPoint) * normalizate) : (climbSpeedCenterPoint + (climbSpeedCenterPoint - climbSpeedTopPoint) * normalizate)
            ctx.arc(_root.width / 2 + offset_x, _root.height / 2 + offset_y, raduis, climbSpeedCenterPoint, endPoint, clockwise);
            ctx.lineWidth = lineWidth;
            ctx.strokeStyle = _root.color;
            ctx.stroke();
        }

        function drawDistance(ctx) {
            ctx.beginPath();
            ctx.moveTo(distanceStartPoint.x, distanceStartPoint.y);
            ctx.lineTo(distanceStartPoint.x, distanceStartPoint.y - distanceMaxLength * (distanceDiffValue / distanceMaxValue));
            ctx.lineWidth = lineWidth;
            ctx.strokeStyle = _root.color;
            ctx.stroke();
        }

        function drawHeight(ctx) {
            ctx.beginPath();
            ctx.moveTo(heightStartPoint.x, heightStartPoint.y);
            ctx.lineTo(heightStartPoint.x, heightStartPoint.y + heightMaxLength * (heightDiffValue / heightMaxValue));
            ctx.lineWidth = lineWidth;
            ctx.strokeStyle = _root.color;
            ctx.stroke();
        }

        function drawPitchRoll(ctx) {
            var p = vehiclePitch / 90
            if(Math.abs(p) >= 1) return;
            var t = Math.tan(vehicleRoll * Math.PI / 180.0)
            var a = 1 + t * t;
            var b = 2 * t * p;
            var c = p * p - 1;
            var disc = (b * b - 4 * a * c);
            if(disc < 0) return;
            var tp = -b/(2*a);
            var tq = Math.sqrt(disc)/(2*a);
            var x1 = tp-tq;
            var x2 = tp+tq;
            var y1 = t * x1 + p
            var y2 = t * x2 + p
            var angle2 = Math.abs(Math.atan(y2,x2))
            var angle1 = Math.abs(Math.atan(y1,x1))
            var startAngle = y2 < 0 ? (2 * Math.PI - angle2) : angle2
            var endAngle = y1 < 0 ? (Math.PI + angle1) : (Math.PI - angle1)
            console.info(x1,y1,x2,y2,startAngle,endAngle)
            x1 = x1 * pitchLength + centerOffset_x;
            x2 = x2 * pitchLength + centerOffset_x;
            y1 = y1 * pitchLength + centerOffset_y;
            y2 = y2 * pitchLength + centerOffset_y;


            ctx.beginPath();
            ctx.moveTo(x1, y1);
            ctx.lineTo(x2, y2);
            //ctx.arc(x1,y1,x2,y2,pitchLength);
            ctx.arc(centerOffset_x,centerOffset_y,pitchLength,startAngle,endAngle,false);
            ctx.lineTo(x1, y1);
            ctx.lineWidth = centerLineWidth;
            ctx.strokeStyle = "#614812";
            ctx.fillStyle = "#A67D24";
            ctx.stroke();
            ctx.fill();
        }

        function drawArcAndClip(ctx) {
            var rectY = vehiclePitch / 90 * pitchLength
            ctx.translate(centerOffset_x,centerOffset_y)
            ctx.rotate(vehicleRoll * Math.PI / 180)
            ctx.beginPath();
            ctx.roundedRect(-pitchLength-centerLineWidth, rectY, (pitchLength +centerLineWidth) * 2, (pitchLength + centerLineWidth) * 2, 0 ,0)
            ctx.clip();

            ctx.beginPath();
            ctx.arc(0,0,pitchLength,0,2 * Math.PI,true);
            ctx.lineWidth = centerLineWidth;
            ctx.strokeStyle = "#614812";
            ctx.fillStyle = "#A67D24";
            ctx.stroke();
            ctx.fill();

            ctx.beginPath();
            var x = Math.sqrt(pitchLength*pitchLength-rectY*rectY)
            ctx.moveTo(-x, rectY);
            ctx.lineTo(x, rectY);
            ctx.stroke();
        }
    }
    Image {
        id: plane
        width: height * 0.73
        height: _realSize * 0.31
        x: (_root.width - width) * 0.5
        y: (_root.height - height) * 0.5
        source: "qrc:/custom/img/aircraftAttitudePlane.svg"
        sourceSize.height: height
        sourceSize.width: width
        smooth: true
        mipmap: true
        antialiasing: true
        fillMode: Image.PreserveAspectFit
    }
}
