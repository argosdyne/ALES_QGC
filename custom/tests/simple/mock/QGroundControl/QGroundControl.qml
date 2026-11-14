// Test double for the QGroundControl QML singleton (only what the Simple UI reads).
pragma Singleton
import QtQuick 2.12

QtObject {
    property string qgcVersion: "V0.0.0-test"
    property QtObject corePlugin: QtObject {
        property bool showAdvancedUI: false
        property QtObject settings: QtObject {
            property QtObject simpleAdminPin: QtObject { property var rawValue: "000000" }
        }
    }
    property QtObject settingsManager: QtObject {
        property QtObject remoteIDSettings: QtObject {
            property QtObject enable: QtObject { property var rawValue: false }
        }
    }
    property QtObject multiVehicleManager: QtObject { property var activeVehicle: null }
}
