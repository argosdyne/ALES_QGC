import QtQuick 2.15
import QtQuick.Shapes 1.12

import QGroundControl.ScreenTools 1.0

Rectangle {
    property bool checked: false
    property int orientation: Gradient.Vertical
    width: ScreenTools.defaultFontPixelWidth * 2
    radius: 2
    color: checked ? qgcPal.buttonHighlight : "transparent"

    Component {
        id: gloryhot
        Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 1) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 0.5, 0, 1) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 0, 1) }
        }
    }
    Component {
        id: blackhot
        Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 1) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 1) }
        }
    }
    Component {
        id: medical
        Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0.5, 1) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 0, 1) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 0, 0, 1) }
        }
    }
    Component {
        id: jungle
        Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 1) }
            GradientStop { position: 0.5; color: Qt.rgba(0.5, 1, 0.5, 1) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 0, 0, 1) }
        }
    }
    Component {
        id: redhot
        Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 1) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 0, 0, 1) }
        }
    }
    Component {
        id: aurora
        Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0.5, 1) }
            GradientStop { position: 0.5; color: Qt.rgba(0, 0.5, 0.5, 1) }
            GradientStop { position: 1.0; color: Qt.rgba(0.5, 0.5, 1, 1) }
        }
    }
    Component {
        id: night
        Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0.2, 0, 1) }
            GradientStop { position: 0.5; color: Qt.rgba(0.2, 0.5, 0.2, 1) }
            GradientStop { position: 1.0; color: Qt.rgba(0.5, 1, 0.5, 1) }
        }
    }
    Component {
        id: rainbow
        Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 1, 1) }
            GradientStop { position: 0.34; color: Qt.rgba(0, 1, 0, 1) }
            GradientStop { position: 0.67; color: Qt.rgba(1, 1, 0, 1) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 0, 0, 1) }
        }
    }
    Component {
        id: ironbow
        Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0.5, 1) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 0, 0, 1) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 0, 1) }
        }
    }
    Component {
        id: sepia
        Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.2, 0.1, 0, 1) }
            GradientStop { position: 1.0; color: Qt.rgba(0.8, 0.5, 0.2, 1) }
        }
    }
    Component {
        id: whitehot
        Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 1) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 1) }
        }
    }

    function setPseudocolorBarIndex(index) {
        switch(index) {
        default:
        case 0: colorScale.changeGradient(whitehot); break;
        case 1: colorScale.changeGradient(sepia); break;
        case 2: colorScale.changeGradient(ironbow); break;
        case 3: colorScale.changeGradient(rainbow); break;
        case 4: colorScale.changeGradient(night); break;
        case 5: colorScale.changeGradient(aurora); break;
        case 6: colorScale.changeGradient(redhot); break;
        case 7: colorScale.changeGradient(jungle); break;
        case 8: colorScale.changeGradient(medical); break;
        case 9: colorScale.changeGradient(blackhot); break;
        case 10: colorScale.changeGradient(gloryhot); break;
        }
    }

    Rectangle {
        id: colorScale
        width: orientation === Gradient.Vertical ? ScreenTools.defaultFontPixelWidth * 1.5 : parent.width - ScreenTools.defaultFontPixelWidth
        height: orientation === Gradient.Vertical ? parent.height - ScreenTools.defaultFontPixelWidth : ScreenTools.defaultFontPixelWidth * 1.5
        radius: ScreenTools.defaultFontPixelWidth * 0.75
        anchors.centerIn: parent

        property var gradientComponent: null
        function changeGradient(themeComponent) {
            // Destroy the previous gradient component if it exists
            if (gradientComponent) {
                gradientComponent.destroy();
            }
            // Create a new instance of the gradient component
            gradientComponent = themeComponent.createObject(colorScale);
            gradientComponent.orientation = orientation
            colorScale.gradient = gradientComponent;
        }
    }
}
