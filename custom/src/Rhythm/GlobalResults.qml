pragma Singleton
import QtQuick 2.15
import QGroundControl 1.0

QtObject {
    property var detectionObjects: []
    property var trackingObjects: []
    property bool detectionEnabled: false
    property var rhythmCamera: null  // Will hold the camera instance

    property int lastTrackingModel: 0
    property int lastDetectionModel: 0
    property int lastResolution: 0
    property int lastBitrate: 0

    function setDetectionEnabled(enabled) {
        detectionEnabled = enabled
        if (!enabled) {
            // Clear the detection objects when disabled
            detectionObjects = []
        }
    }
    // Enum-like dictionary for object class names
    property var classNames: ({
        0: "person", 1: "car", 2: "bus", 3: "truck", 4: "bike", 5: "train", 6: "boat", 7: "aeroplane",
        8: "bicycle", 9: "motorcycle", 10: "airplane", 11: "traffic light", 12: "fire hydrant", 13: "stop sign",
        14: "parking meter", 15: "bench", 16: "bird", 17: "cat", 18: "dog", 19: "horse", 20: "sheep",
        21: "cow", 22: "elephant", 23: "bear", 24: "zebra", 25: "giraffe", 26: "backpack", 27: "umbrella",
        28: "handbag", 29: "tie", 30: "suitcase", 31: "frisbee", 32: "skis", 33: "snowboard", 34: "sports ball",
        35: "kite", 36: "baseball bat", 37: "baseball glove", 38: "skateboard", 39: "surfboard", 40: "tennis racket",
        41: "bottle", 42: "wine glass", 43: "cup", 44: "fork", 45: "knife", 46: "spoon", 47: "bowl",
        48: "banana", 49: "apple", 50: "sandwich", 51: "orange", 52: "broccoli", 53: "carrot", 54: "hot dog",
        55: "pizza", 56: "donut", 57: "cake", 58: "chair", 59: "couch", 60: "potted plant", 61: "bed",
        62: "dining table", 63: "toilet", 64: "tv", 65: "laptop", 66: "mouse", 67: "remote", 68: "keyboard",
        69: "cell phone", 70: "microwave", 71: "oven", 72: "toaster", 73: "sink", 74: "refrigerator",
        75: "book", 76: "clock", 77: "vase", 78: "scissors", 79: "teddy bear", 80: "hair drier", 81: "toothbrush"
    })

    function getClassName(id) {
        return classNames[id] || "unknown"; // Return "unknown" if ID not found
    }

    // Define unique colors for each type
    property var typeColors: ({
        0: "#FF0000",  1: "#00FF00",  2: "#0000FF",  3: "#FFFF00",  4: "#FF00FF",  5: "#00FFFF",
        6: "#FFA500",  7: "#800080",  8: "#008000",  9: "#808080", 10: "#FFC0CB", 11: "#800000",
       12: "#008080", 13: "#000080", 14: "#FFD700", 15: "#FF4500", 16: "#ADFF2F", 17: "#DC143C",
       18: "#7FFF00", 19: "#FF6347", 20: "#4682B4", 21: "#D2691E", 22: "#708090", 23: "#556B2F",
       24: "#8B4513", 25: "#DAA520", 26: "#FF1493", 27: "#20B2AA", 28: "#FF69B4", 29: "#FFDAB9",
       30: "#CD5C5C", 31: "#9932CC", 32: "#E9967A", 33: "#8FBC8F", 34: "#6495ED", 35: "#FF8C00",
       36: "#B22222", 37: "#00CED1", 38: "#008B8B", 39: "#4B0082", 40: "#F08080", 41: "#BC8F8F",
       42: "#00FA9A", 43: "#FF7F50", 44: "#6B8E23", 45: "#00BFFF", 46: "#9400D3", 47: "#FF4500",
       48: "#2E8B57", 49: "#FF00FF", 50: "#4169E1", 51: "#C71585", 52: "#808000", 53: "#48D1CC",
       54: "#FFB6C1", 55: "#008000", 56: "#191970", 57: "#7CFC00", 58: "#B0E0E6", 59: "#FFDEAD",
       60: "#556B2F", 61: "#8B008B", 62: "#FFD700", 63: "#708090", 64: "#A52A2A", 65: "#F0E68C",
       66: "#8A2BE2", 67: "#E6E6FA", 68: "#4682B4", 69: "#9ACD32", 70: "#DC143C", 71: "#FF69B4",
       72: "#2E8B57", 73: "#9932CC", 74: "#FF4500", 75: "#DDA0DD", 76: "#00FFFF", 77: "#87CEEB",
       78: "#4682B4", 79: "#6A5ACD", 80: "#32CD32", 81: "#B8860B"
    })

    function getColorForType(id) {
        return typeColors[id] || "#FFFFFF"; // Default white if not defined
    }

    // function clearDetections() {
    //     detectionObjects = []; // Reset the array
    //     detectionObjectsChanged(); // Notify QML that the array changed
    // }
}
