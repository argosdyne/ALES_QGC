// Test double for the QGroundControl QML singleton (only what the Simple UI reads).
pragma Singleton
import QtQuick 2.12

QtObject {
    property string qgcVersion: "V0.0.0-test"
    property QtObject corePlugin: QtObject {
        property bool showAdvancedUI: false
        property QtObject settings: QtObject {
            property QtObject lifeJacketEnable:     QtObject { property var rawValue: false }
            property QtObject ysEnable:             QtObject { property var rawValue: false }
            property QtObject simpleProductProfile: QtObject { property var rawValue: 0 }
        }
        property var elistairStationManager: null
        property var ysManager: null
    }
    property QtObject settingsManager: QtObject {
        property QtObject remoteIDSettings: QtObject {
            property QtObject enable: QtObject { property var rawValue: false }
        }
        // S35 / S38 (Go here, change altitude)
        property QtObject flyViewSettings: QtObject {
            property QtObject guidedMinimumAltitude:   QtObject { property var rawValue: 2 }
            property QtObject guidedMaximumAltitude:   QtObject { property var rawValue: 120 }
            property QtObject maxGoToLocationDistance: QtObject { property var rawValue: 1000 }
            property QtObject gotoAltitudeReference:   QtObject { property var rawValue: 0 }
            property QtObject enableAudioController:   QtObject { property var rawValue: false }
        }
        property QtObject appSettings: QtObject {
            property QtObject offlineEditingHoverSpeed:   QtObject { property var rawValue: 5 }
            property QtObject offlineEditingAscentSpeed:  QtObject { property var rawValue: 2 }
            property QtObject offlineEditingDescentSpeed: QtObject { property var rawValue: 1 }
        }
    }
    // metric: metres in, metres out
    property QtObject unitsConversion: QtObject {
        property string appSettingsVerticalDistanceUnitsString:   "m"
        property string appSettingsHorizontalDistanceUnitsString: "m"
        function metersToAppSettingsVerticalDistanceUnits(m)   { return m }
        function appSettingsVerticalDistanceUnitsToMeters(d)   { return d }
        function metersToAppSettingsHorizontalDistanceUnits(m) { return m }
    }
    property QtObject multiVehicleManager: QtObject { property var activeVehicle: null }
}
