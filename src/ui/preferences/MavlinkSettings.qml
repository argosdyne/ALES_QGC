/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Controls.Styles  1.4
import QtQuick.Dialogs          1.2
import QtQuick.Layouts          1.2

import QGroundControl                       1.0
import QGroundControl.FactSystem            1.0
import QGroundControl.FactControls          1.0
import QGroundControl.Controls              1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.MultiVehicleManager   1.0
import QGroundControl.Palette               1.0

Rectangle {
    id:             __mavlinkRoot
    color:          qgcPal.window
    anchors.fill:   parent

    property real _labelWidth:          ScreenTools.defaultFontPixelWidth * 28
    property real _valueWidth:          ScreenTools.defaultFontPixelWidth * 24
    property int  _selectedCount:       0
    property real _columnSpacing:       ScreenTools.defaultFontPixelHeight * 0.25
    property bool _uploadedSelected:    false
    property bool _showMavlinkLog:      QGroundControl.corePlugin.options.showMavlinkLogOptions
    property bool _showAPMStreamRates:  QGroundControl.apmFirmwareSupported && QGroundControl.settingsManager.apmMavlinkStreamRateSettings.visible && _isAPM
    property var  _activeVehicle:       QGroundControl.multiVehicleManager.activeVehicle
    property bool _isPX4:               _activeVehicle ? _activeVehicle.px4Firmware : false
    property bool _isAPM:               _activeVehicle ? _activeVehicle.apmFirmware : false
    property Fact _disableDataPersistenceFact: QGroundControl.settingsManager.appSettings.disableAllPersistence
    property bool _disableDataPersistence:     _disableDataPersistenceFact ? _disableDataPersistenceFact.rawValue : false
    property string _signingStatusText:        ""
    property Fact _mavlink2SigningKey:         QGroundControl.settingsManager.appSettings.mavlink2SigningKey
    property string _pendingSigningKey:        _mavlink2SigningKey ? _mavlink2SigningKey.rawValue.toString() : ""
    property bool _mavlink2SigningEnabled:     _mavlink2SigningKey ? (_mavlink2SigningKey.rawValue !== "") : false
    property bool _showSigningKey:             false

    QGCPalette { id: qgcPal }

    Connections {
        target: _mavlink2SigningKey
        function onRawValueChanged(value) {
            if (!signingKeyField.activeFocus) {
                _pendingSigningKey = value ? value.toString() : ""
            }
        }
    }

    Connections {
        target: QGroundControl.mavlinkLogManager
        onSelectedCountChanged: {
            _uploadedSelected = false
            var selected = 0
            for(var i = 0; i < QGroundControl.mavlinkLogManager.logFiles.count; i++) {
                var logFile = QGroundControl.mavlinkLogManager.logFiles.get(i)
                if(logFile.selected) {
                    selected++
                    //-- If an uploaded file is selected, disable "Upload" button
                    if(logFile.uploaded) {
                        _uploadedSelected = true
                    }
                }
            }
            _selectedCount = selected
        }
    }

    function saveItems()
    {
        QGroundControl.mavlinkSystemID = parseInt(sysidField.text)
        QGroundControl.mavlinkLogManager.videoURL = videoUrlField.text
        QGroundControl.mavlinkLogManager.feedback = feedbackTextArea.text
        QGroundControl.mavlinkLogManager.emailAddress = emailField.text
        QGroundControl.mavlinkLogManager.description = descField.text
        QGroundControl.mavlinkLogManager.uploadURL = urlField.text
        QGroundControl.mavlinkLogManager.emailAddress = emailField.text
        if(autoUploadCheck.checked && QGroundControl.mavlinkLogManager.emailAddress === "") {
            autoUploadCheck.checked = false
        } else {
            QGroundControl.mavlinkLogManager.enableAutoUpload = autoUploadCheck.checked
        }
    }

    MessageDialog {
        id:         emptyEmailDialog
        visible:    false
        icon:       StandardIcon.Warning
        standardButtons: StandardButton.Close
        title:      qsTr("MAVLink Logging")
        text:       qsTr("Please enter an email address before uploading MAVLink log files.")
    }

    QGCFlickable {
        clip:               true
        anchors.fill:       parent
        anchors.margins:    ScreenTools.defaultFontPixelWidth
        contentHeight:      settingsColumn.height
        contentWidth:       settingsColumn.width
        flickableDirection: Flickable.VerticalFlick

        Column {
            id:                 settingsColumn
            width:              __mavlinkRoot.width
            spacing:            ScreenTools.defaultFontPixelHeight * 0.5
            anchors.margins:    ScreenTools.defaultFontPixelWidth
            //-----------------------------------------------------------------
            //-- Ground Station
            Item {
                width:              __mavlinkRoot.width * 0.8
                height:             gcsLabel.height
                anchors.margins:    ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter: parent.horizontalCenter
                QGCLabel {
                    id:             gcsLabel
                    text:           qsTr("Ground Station")
                    font.family:    ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:         gcsColumn.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:          __mavlinkRoot.width * 0.8
                color:          qgcPal.windowShade
                anchors.margins: ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter: parent.horizontalCenter
                Column {
                    id:         gcsColumn
                    spacing:    _columnSpacing
                    anchors.centerIn: parent
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        QGCLabel {
                            width:              _labelWidth
                            anchors.baseline:   sysidField.baseline
                            text:               qsTr("MAVLink System ID:")
                        }
                        QGCTextField {
                            id:     sysidField
                            text:   QGroundControl.mavlinkSystemID.toString()
                            width:  _valueWidth
                            inputMethodHints:       Qt.ImhFormattedNumbersOnly
                            anchors.verticalCenter: parent.verticalCenter
                            onEditingFinished: {
                                saveItems();
                            }
                        }
                    }

                    QGCCheckBox {
                        text:       qsTr("Emit heartbeat")
                        checked:    QGroundControl.multiVehicleManager.gcsHeartBeatEnabled
                        onClicked: {
                            QGroundControl.multiVehicleManager.gcsHeartBeatEnabled = checked
                        }
                    }

                    QGCCheckBox {
                        text:       qsTr("Only accept MAVs with same protocol version")
                        checked:    QGroundControl.isVersionCheckEnabled
                        onClicked: {
                            QGroundControl.isVersionCheckEnabled = checked
                        }
                    }

                    FactCheckBox {
                        id:         mavlinkForwardingChecked
                        text:       qsTr("Enable MAVLink forwarding")
                        fact:       QGroundControl.settingsManager.appSettings.forwardMavlink
                        visible:    QGroundControl.settingsManager.appSettings.forwardMavlink.visible
                        // A checked forwarding link already owns one slot and
                        // must remain enabled so the user can turn it off.
                        enabled:    fact.rawValue || QGroundControl.linkManager.mavlinkUdpEndpointCount < QGroundControl.linkManager.mavlinkUdpEndpointLimit
                    }

                    QGCLabel {
                        width:      parent.width
                        wrapMode:   Text.WordWrap
                        color:      qgcPal.colorOrange
                        text:       qsTr("MAVLink forwarding is unavailable because all %1 UDP connections are in use.")
                                        .arg(QGroundControl.linkManager.mavlinkUdpEndpointLimit)
                        visible:    !mavlinkForwardingChecked.fact.rawValue && !mavlinkForwardingChecked.enabled
                    }

                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        QGCLabel {
                            width:              _labelWidth
                            anchors.baseline:   mavlinkForwardingHostNameField.baseline
                            visible:            QGroundControl.settingsManager.appSettings.forwardMavlinkHostName.visible
                            text:               qsTr("Host name:")
                        }
                        FactTextField {
                            id:                     mavlinkForwardingHostNameField
                            fact:                   QGroundControl.settingsManager.appSettings.forwardMavlinkHostName
                            width:                  _valueWidth
                            visible:                QGroundControl.settingsManager.appSettings.forwardMavlinkHostName.visible
                            enabled:                QGroundControl.settingsManager.appSettings.forwardMavlink.rawValue
                            anchors.verticalCenter: parent.verticalCenter
                        }

                    }
                   QGCLabel {
                        text:       qsTr("<i> Changing the host name requires restart of application. </i>")
                        visible:    QGroundControl.settingsManager.appSettings.forwardMavlinkHostName.visible
                    }
                }
            }
            //-----------------------------------------------------------------
            //-- MAVLink2 Signing
            Item {
                width:              __mavlinkRoot.width * 0.8
                height:             signingLabel.height
                anchors.margins:    ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter: parent.horizontalCenter
                visible:            true
                QGCLabel {
                    id:             signingLabel
                    text:           qsTr("MAVLink2 Signing")
                    font.family:    ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:         signingColumn.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:          __mavlinkRoot.width * 0.8
                color:          qgcPal.windowShade
                anchors.margins: ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter: parent.horizontalCenter
                visible:        true
                Column {
                    id:         signingColumn
                    spacing:    _columnSpacing
                    anchors.centerIn: parent

                    QGCLabel { text: _mavlink2SigningEnabled ? qsTr("Signing status: Enabled") : qsTr("Signing status: Disabled") }

                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        QGCLabel {
                            width:              ScreenTools.defaultFontPixelWidth * 4
                            anchors.baseline:   signingKeyField.baseline
                            text:               qsTr("Key")
                        }
                        QGCTextField {
                            id:                     signingKeyField
                            width:                  _valueWidth
                            text:                   _pendingSigningKey
                            inputMethodHints:       Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                            placeholderText:        qsTr("Enter signing passphrase")
                            echoMode:               _showSigningKey ? TextInput.Normal : TextInput.Password
                            anchors.verticalCenter: parent.verticalCenter
                            onTextChanged:          _pendingSigningKey = text
                            onEditingFinished: {
                                var passphrase = _pendingSigningKey.trim()
                                if (passphrase !== "") {
                                    _mavlink2SigningKey.rawValue = passphrase
                                    _pendingSigningKey = passphrase
                                }
                            }
                        }
                        QGCButton {
                            text:                   ""
                            iconSource:             _showSigningKey ? "/InstrumentValueIcons/view-show.svg" : "/InstrumentValueIcons/view-hide.svg"
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked:              _showSigningKey = !_showSigningKey
                        }
                        QGCButton {
                            text:       qsTr("Disable")
                            anchors.verticalCenter: parent.verticalCenter
                            enabled:    _mavlink2SigningEnabled
                            onClicked: {
                                _pendingSigningKey = ""
                                _mavlink2SigningKey.rawValue = ""
                                _signingStatusText = qsTr("Signing disabled locally.")
                            }
                        }
                        QGCButton {
                            text:       qsTr("Save")
                            anchors.verticalCenter: parent.verticalCenter
                            enabled:    _pendingSigningKey.trim().length > 0
                            onClicked: {
                                var passphrase = _pendingSigningKey.trim()
                                if (passphrase !== "") {
                                    _mavlink2SigningKey.rawValue = passphrase
                                    _pendingSigningKey = passphrase
                                }
                                _signingStatusText = qsTr("Signing key saved.")
                            }
                        }
                    }

                    QGCLabel {
                        visible:    _signingStatusText.length > 0
                        text:       _signingStatusText
                    }
                }
            }
            //-----------------------------------------------------------------
            //-- Stream Rates
            Item {
                id:                         apmStreamRatesLabel
                width:                      __mavlinkRoot.width * 0.8
                height:                     streamRatesLabel.height
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                visible:                    _showAPMStreamRates
                QGCLabel {
                    id:             streamRatesLabel
                    text:           qsTr("Telemetry Stream Rates (ArduPilot Only)")
                    font.family:    ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:                     streamRatesColumn.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:                      __mavlinkRoot.width * 0.8
                color:                      qgcPal.windowShade
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                visible:                    _showAPMStreamRates

                ColumnLayout {
                    id:                 streamRatesColumn
                    spacing:            ScreenTools.defaultFontPixelHeight / 2
                    anchors.centerIn:   parent

                    property bool allStreamsControlledByVehicle: !QGroundControl.settingsManager.appSettings.apmStartMavlinkStreams.rawValue

                    QGCCheckBox {
                        text:               qsTr("All Streams Controlled By Vehicle Settings")
                        checked:            streamRatesColumn.allStreamsControlledByVehicle
                        onClicked:          QGroundControl.settingsManager.appSettings.apmStartMavlinkStreams.rawValue = !checked
                    }

                    GridLayout {
                        columns:    2
                        enabled:    !streamRatesColumn.allStreamsControlledByVehicle

                        QGCLabel { text:  qsTr("Raw Sensors") }
                        FactComboBox {
                            fact:                   QGroundControl.settingsManager.apmMavlinkStreamRateSettings ? QGroundControl.settingsManager.apmMavlinkStreamRateSettings.streamRateRawSensors : null
                            indexModel:             false
                            Layout.preferredWidth:  _valueWidth
                        }

                        QGCLabel { text:  qsTr("Extended Status") }
                        FactComboBox {
                            fact:                   QGroundControl.settingsManager.apmMavlinkStreamRateSettings ? QGroundControl.settingsManager.apmMavlinkStreamRateSettings.streamRateExtendedStatus : null
                            indexModel:             false
                            Layout.preferredWidth:  _valueWidth
                        }

                        QGCLabel { text:  qsTr("RC Channel") }
                        FactComboBox {
                            fact:                   QGroundControl.settingsManager.apmMavlinkStreamRateSettings ? QGroundControl.settingsManager.apmMavlinkStreamRateSettings.streamRateRCChannels : null
                            indexModel:             false
                            Layout.preferredWidth:  _valueWidth
                        }

                        QGCLabel { text:  qsTr("Position") }
                        FactComboBox {
                            fact:                   QGroundControl.settingsManager.apmMavlinkStreamRateSettings ? QGroundControl.settingsManager.apmMavlinkStreamRateSettings.streamRatePosition : null
                            indexModel:             false
                            Layout.preferredWidth:  _valueWidth
                        }

                        QGCLabel { text:  qsTr("Extra 1") }
                        FactComboBox {
                            fact:                   QGroundControl.settingsManager.apmMavlinkStreamRateSettings ? QGroundControl.settingsManager.apmMavlinkStreamRateSettings.streamRateExtra1 : null
                            indexModel:             false
                            Layout.preferredWidth:  _valueWidth
                        }

                        QGCLabel { text:  qsTr("Extra 2") }
                        FactComboBox {
                            fact:                   QGroundControl.settingsManager.apmMavlinkStreamRateSettings ? QGroundControl.settingsManager.apmMavlinkStreamRateSettings.streamRateExtra2 : null
                            indexModel:             false
                            Layout.preferredWidth:  _valueWidth
                        }

                        QGCLabel { text:  qsTr("Extra 3") }
                        FactComboBox {
                            fact:                   QGroundControl.settingsManager.apmMavlinkStreamRateSettings ? QGroundControl.settingsManager.apmMavlinkStreamRateSettings.streamRateExtra3 : null
                            indexModel:             false
                            Layout.preferredWidth:  _valueWidth
                        }
                    }
                }
            }
            //-----------------------------------------------------------------
            //-- Mavlink Status
            Item {
                width:              __mavlinkRoot.width * 0.8
                height:             mavStatusLabel.height
                anchors.margins:    ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter: parent.horizontalCenter
                QGCLabel {
                    id:             mavStatusLabel
                    text:           qsTr("MAVLink Link Status (Current Vehicle)")
                    font.family:    ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:         mavStatusColumn.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:          __mavlinkRoot.width * 0.8
                color:          qgcPal.windowShade
                anchors.margins: ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter: parent.horizontalCenter
                Column {
                    id:         mavStatusColumn
                    width:      gcsColumn.width
                    spacing:    _columnSpacing
                    anchors.centerIn: parent
                    //-----------------------------------------------------------------
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        QGCLabel {
                            width:              _labelWidth
                            text:               qsTr("Total messages sent (computed):")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        QGCLabel {
                            width:              _valueWidth
                            text:               globals.activeVehicle ? globals.activeVehicle.mavlinkSentCount : qsTr("Not Connected")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    //-----------------------------------------------------------------
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        QGCLabel {
                            width:              _labelWidth
                            text:               qsTr("Total messages received:")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        QGCLabel {
                            width:              _valueWidth
                            text:               globals.activeVehicle ? globals.activeVehicle.mavlinkReceivedCount : qsTr("Not Connected")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    //-----------------------------------------------------------------
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        QGCLabel {
                            width:              _labelWidth
                            text:               qsTr("Total message loss:")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        QGCLabel {
                            width:              _valueWidth
                            text:               globals.activeVehicle ? globals.activeVehicle.mavlinkLossCount : qsTr("Not Connected")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    //-----------------------------------------------------------------
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        QGCLabel {
                            width:              _labelWidth
                            text:               qsTr("Loss rate:")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        QGCLabel {
                            width:              _valueWidth
                            text:               globals.activeVehicle ? globals.activeVehicle.mavlinkLossPercent.toFixed(0) + '%' : qsTr("Not Connected")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
            //-----------------------------------------------------------------
            //-- Mavlink Logging
            Item {
                width:              __mavlinkRoot.width * 0.8
                height:             mavlogLabel.height
                anchors.margins:    ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter: parent.horizontalCenter
                visible:            _showMavlinkLog && _isPX4
                QGCLabel {
                    id:             mavlogLabel
                    text:           qsTr("MAVLink 2.0 Logging (PX4 Pro Only)")
                    font.family:    ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:         mavlogColumn.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:          __mavlinkRoot.width * 0.8
                color:          qgcPal.windowShade
                anchors.margins: ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter: parent.horizontalCenter
                visible:        _showMavlinkLog && _isPX4
                Column {
                    id:         mavlogColumn
                    width:      gcsColumn.width
                    spacing:    _columnSpacing
                    anchors.centerIn: parent
                    //-----------------------------------------------------------------
                    //-- Manual Start/Stop
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        QGCLabel {
                            width:              _labelWidth
                            text:               qsTr("Manual Start/Stop:")
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        QGCButton {
                            text:               qsTr("Start Logging")
                            width:              (_valueWidth * 0.5) - (ScreenTools.defaultFontPixelWidth * 0.5)
                            enabled:            !QGroundControl.mavlinkLogManager.logRunning && QGroundControl.mavlinkLogManager.canStartLog && !_disableDataPersistence
                            onClicked:          QGroundControl.mavlinkLogManager.startLogging()
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        QGCButton {
                            text:               qsTr("Stop Logging")
                            width:              (_valueWidth * 0.5) - (ScreenTools.defaultFontPixelWidth * 0.5)
                            enabled:            QGroundControl.mavlinkLogManager.logRunning && !_disableDataPersistence
                            onClicked:          QGroundControl.mavlinkLogManager.stopLogging()
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    //-----------------------------------------------------------------
                    //-- Enable auto log on arming
                    QGCCheckBox {
                        text:       qsTr("Enable automatic logging")
                        checked:    QGroundControl.mavlinkLogManager.enableAutoStart
                        enabled:    !_disableDataPersistence
                        onClicked: {
                            QGroundControl.mavlinkLogManager.enableAutoStart = checked
                        }
                    }
                }
            }
        }
    }
}
