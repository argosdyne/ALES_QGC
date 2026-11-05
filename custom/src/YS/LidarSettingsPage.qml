/****************************************************************************
 *
 * LiDAR Setup > Settings (YS-06, UI Y-07)
 *   ① parameter location + last read time
 *   ② Scanner (high sensitivity 0x00, pattern 0x01) - Livox AVIA models only
 *   ③ Embedded camera (enable 0x02, start height 0x03, trigger mode 0x04 + value 0x05)
 *   ④ Current values (Get Parameter read-back)
 *   ⑤ locked while acquisition is running
 * UI only: uses the existing YSManager Get / Set Parameter API.
 *
 ****************************************************************************/

import QtQuick          2.11
import QtQuick.Controls 1.2
import QtQuick.Layouts  1.11

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0
import CustomQuickInterface         1.0

Rectangle {
    id:     root
    color:  qgcPal.window

    property var  _settings:        QGroundControl.corePlugin.settings
    property var  _ys:              QGroundControl.corePlugin.ysManager
    property real _cardMargin:      ScreenTools.defaultFontPixelWidth
    property real _rowSpacing:      ScreenTools.defaultFontPixelHeight * 0.3
    property real _colSpacing:      ScreenTools.defaultFontPixelWidth * 1.5
    property real _fieldWidth:      ScreenTools.defaultFontPixelWidth * 10
    property string _sep:           " · "

    // Parameter indexes (param1 of Get / Set Parameter) - same as YSManager::YSParameterIndex
    readonly property int _pHighSens:     0
    readonly property int _pPattern:      1
    readonly property int _pCamEnable:    2
    readonly property int _pStartHeight:  3
    readonly property int _pTrigMode:     4
    readonly property int _pTrigValue:    5

    // ysModel: 0 = Surveyor Ultra OEM (Hesai XT32M2X), 1 / 2 = Mapper+ OEM A / C (Livox AVIA)
    property bool _livoxAvia:       _settings && _settings.ysModel.rawValue !== 0
    property bool _locked:          _ys && (_ys.acquisitionRunning || _ys.lidarState === YSManager.StateRecording
                                            || _ys.lidarState === YSManager.StateStarting || _ys.lidarState === YSManager.StateStopping)
    property bool _online:          _ys && _ys.statusValid
    // The companion board (Birdcom) does not support Set Parameter yet, so the page is read-only.
    // Set to true once Birdcom forwards Set Parameter to the LiDAR - inputs, Apply / Cancel and read-back are already in place.
    readonly property bool _setSupported: false
    property bool _editable:        _setSupported && !_locked && !_applying
    readonly property color _warningColor: "#D4AD0B"   // Y-07 warning yellow (QGCPalette has no yellow)

    // Pending edits: { paramIndex: value }. Fields show the edit, else the value read from the LiDAR.
    property var  _edits:           ({})
    property int  _changeCount:     Object.keys(_edits).length
    property bool _reading:         false
    property bool _applying:        false
    property string _lastReadTime:  ""
    property var  _failedOnApply:   []

    QGCPalette { id: qgcPal }

    //-------------------------------------------------------------------------
    // Values

    function _deviceValue(idx) {
        if (!_ys) {
            return 0
        }
        switch (idx) {
        case _pHighSens:    return _ys.scannerHighSensitivity
        case _pPattern:     return _ys.scannerPattern
        case _pCamEnable:   return _ys.embeddedCamera
        case _pStartHeight: return _ys.embCamInitHeight
        case _pTrigMode:    return _ys.embCamTriggerMode
        case _pTrigValue:   return _ys.embCamTriggerValue
        }
        return 0
    }

    function _value(idx) {
        return _edits.hasOwnProperty(idx) ? _edits[idx] : _deviceValue(idx)
    }

    function _setEdit(idx, v) {
        var e = Object.assign({}, _edits)
        if (v === _deviceValue(idx)) {
            delete e[idx]
        } else {
            e[idx] = v
        }
        _edits = e
    }

    // Start height -1 = start immediately. Birdcom returns the LiDAR float as unsigned, so -1 reads back as 0;
    // 0 m above the acquisition start is the same thing, so <= 0 is shown as immediate.
    function _isImmediate(h) {
        return h <= 0
    }

    function _setFailed(idx) {
        if (!_ys) {
            return false
        }
        switch (idx) {
        case _pHighSens:    return _ys.scannerHighSensitivitySetFailed
        case _pPattern:     return _ys.scannerPatternSetFailed
        case _pCamEnable:   return _ys.embeddedCameraSetFailed
        case _pStartHeight: return _ys.embCamInitHeightSetFailed
        case _pTrigMode:    return _ys.embCamTriggerModeSetFailed
        case _pTrigValue:   return _ys.embCamTriggerValueSetFailed
        }
        return false
    }

    function _readIndexes() {
        return _livoxAvia ? [_pHighSens, _pPattern, _pCamEnable, _pStartHeight, _pTrigMode, _pTrigValue]
                          : [_pCamEnable, _pStartHeight, _pTrigMode, _pTrigValue]
    }

    function _paramName(idx) {
        switch (idx) {
        case _pHighSens:    return qsTr("High sensitivity")
        case _pPattern:     return qsTr("Pattern")
        case _pCamEnable:   return qsTr("Enable camera")
        case _pStartHeight: return qsTr("Start height")
        case _pTrigMode:    return qsTr("Trigger")
        case _pTrigValue:   return qsTr("Every")
        }
        return ""
    }

    // "--" until something was read from the LiDAR
    function _readText(t) {
        return _lastReadTime !== "" ? t : "--"
    }

    function _startHeightText(h) {
        return _isImmediate(h) ? qsTr("Immediately") : qsTr("%1 m").arg(h.toFixed(1))
    }

    function _triggerText(mode, value) {
        return mode === YSManager.TriggerModeDistance ? qsTr("Distance") + _sep + qsTr("%1 m").arg(value.toFixed(1))
                                                      : qsTr("Time") + _sep + qsTr("%1 s").arg(value.toFixed(1))
    }

    //-------------------------------------------------------------------------
    // Get / Set

    function readAll() {
        if (!_ys) {
            return
        }
        _reading = true
        var list = _readIndexes()
        for (var i = 0; i < list.length; i++) {
            _ys.requestParameter(list[i])
        }
    }

    function apply() {
        if (!_ys || _changeCount === 0 || !_editable) {
            return
        }
        // Text fields commit on editingFinished; make sure a value still being typed is included
        root.forceActiveFocus()
        var keys = Object.keys(_edits).map(function(k) { return parseInt(k) }).sort()
        for (var i = 0; i < keys.length; i++) {
            _ys.setParameter(keys[i], _edits[keys[i]])
        }
        _failedOnApply = []
        _applying = true
        _edits = ({})
        readBackTimer.changedIndexes = keys
        readBackTimer.interval = keys.length * _setAckWaitMs + _setAckWaitMs
        readBackTimer.restart()
    }

    function cancel() {
        _edits = ({})
    }

    // YSManager has no "Set finished" signal and only starts queued Gets on a new request, so the read-back
    // runs after the worst-case Set reply window per item (same as YSManager kSetResponseTimeoutMs).
    readonly property int _setAckWaitMs: 2000

    Timer {
        id:             readBackTimer
        repeat:         false
        property var changedIndexes: []
        onTriggered: {
            var failed = []
            for (var i = 0; i < changedIndexes.length; i++) {
                if (_setFailed(changedIndexes[i])) {
                    failed.push(changedIndexes[i])
                }
            }
            _failedOnApply = failed
            _applying = false
            readAll()
        }
    }

    Connections {
        target: _ys
        // setParameter() also writes the local copy, so only count it as a read while a Get is outstanding
        onParameterChanged: {
            if (_reading && !_applying) {
                _lastReadTime = Qt.formatTime(new Date(), "hh:mm:ss")
            }
        }
    }

    // Read once the LiDAR answers Get Status (entry, or link coming back)
    on_OnlineChanged:       if (_online) readAll()
    on_LivoxAviaChanged:    { _edits = ({}); if (_online) readAll() }
    Component.onCompleted:  readAll()

    //-------------------------------------------------------------------------
    // Layout (Y-07): info bar on top, then three columns

    QGCFlickable {
        anchors.fill:       parent
        contentWidth:       width
        contentHeight:      mainColumn.height
        clip:               true

        ColumnLayout {
            id:         mainColumn
            width:      parent.width
            spacing:    _colSpacing

            //-- ① Location + last read
            Rectangle {
                Layout.fillWidth:       true
                Layout.preferredHeight: infoLabel.contentHeight + ScreenTools.defaultFontPixelHeight * 0.4
                radius:                 ScreenTools.defaultFontPixelWidth / 2
                color:                  qgcPal.colorBlue

                QGCLabel {
                    id:                     infoLabel
                    anchors.left:           parent.left
                    anchors.right:          parent.right
                    anchors.margins:        ScreenTools.defaultFontPixelWidth
                    anchors.verticalCenter: parent.verticalCenter
                    color:                  "white"
                    wrapMode:               Text.WordWrap
                    font.pointSize:         ScreenTools.smallFontPointSize
                    text:                   (_setSupported ? qsTr("ⓘ Stored in the LiDAR. Apply sends Set Parameter for each change, then reads it back (Get Parameter).")
                                                           : qsTr("ⓘ Stored in the LiDAR. Read with Get Parameter."))
                                            + _sep + (_lastReadTime !== "" ? qsTr("Last read %1").arg(_lastReadTime) : qsTr("Not read yet"))
                }
            }

            RowLayout {
                Layout.fillWidth:   true
                spacing:            _colSpacing

                //-------------------------------------------------------------
                //-- ② Scanner + Model
                ColumnLayout {
                    Layout.fillWidth:       true
                    Layout.preferredWidth:  1
                    Layout.alignment:       Qt.AlignTop
                    spacing:                _rowSpacing

                    SectionTitle { text: qsTr("Scanner") + "  " + qsTr("(Livox AVIA only)") }

                    Card {
                        ColumnLayout {
                            width:      parent.width
                            spacing:    _rowSpacing
                            enabled:    _livoxAvia && _editable

                            ParamRow {
                                paramIndex: _pHighSens
                                QGCCheckBox {
                                    text:       qsTr("High sensitivity")
                                    checked:    _value(_pHighSens) !== 0
                                    onClicked:  _setEdit(_pHighSens, checked ? 1 : 0)
                                }
                                Item { Layout.fillWidth: true }
                            }

                            ParamRow {
                                paramIndex: _pPattern
                                QGCLabel { text: qsTr("Pattern"); Layout.fillWidth: true }
                                SegmentButtons {
                                    labels:     [qsTr("Non-rep."), qsTr("Repetitive")]
                                    current:    _value(_pPattern)
                                    onSelected: _setEdit(_pPattern, index)
                                }
                            }
                        }

                        NoteLabel {
                            visible:    !_livoxAvia
                            text:       qsTr("Not available on %1 (Hesai XT32M2X) — shown disabled. Enabled for Mapper+ OEM.")
                                            .arg(_settings ? _settings.ysModel.enumStringValue : "")
                        }
                    }

                    SectionTitle { text: qsTr("Model"); Layout.topMargin: _rowSpacing }

                    Card {
                        GridLayout {
                            width:          parent.width
                            columns:        2
                            rowSpacing:     _rowSpacing
                            columnSpacing:  _colSpacing

                            QGCLabel { text: qsTr("LiDAR"); Layout.fillWidth: true }
                            ValueLabel { text: _settings ? _settings.ysModel.enumStringValue : "" }
                            QGCLabel { text: qsTr("Camera"); Layout.fillWidth: true }
                            ValueLabel { text: _settings ? _settings.ysCamera.enumStringValue : "" }
                        }

                        NoteLabel {
                            text: qsTr("Chosen in Connection — the serial protocol has no model query, so unsupported items are disabled.")
                        }
                    }
                }

                //-------------------------------------------------------------
                //-- ③ Embedded camera + ⑤ lock + Apply
                ColumnLayout {
                    Layout.fillWidth:       true
                    Layout.preferredWidth:  1
                    Layout.alignment:       Qt.AlignTop
                    spacing:                _rowSpacing

                    SectionTitle { text: qsTr("Embedded camera") }

                    Card {
                        ColumnLayout {
                            width:      parent.width
                            spacing:    _rowSpacing
                            enabled:    _editable

                            ParamRow {
                                paramIndex: _pCamEnable
                                QGCCheckBox {
                                    text:       qsTr("Enable camera")
                                    checked:    _value(_pCamEnable) !== 0
                                    onClicked:  _setEdit(_pCamEnable, checked ? 1 : 0)
                                }
                                Item { Layout.fillWidth: true }
                            }

                            ColumnLayout {
                                Layout.fillWidth:   true
                                spacing:            _rowSpacing
                                enabled:            _value(_pCamEnable) !== 0

                                ParamRow {
                                    paramIndex: _pStartHeight
                                    showId:     false
                                    QGCLabel { text: qsTr("Start height"); Layout.fillWidth: true }
                                    QGCTextField {
                                        Layout.preferredWidth:  _fieldWidth
                                        enabled:                !_isImmediate(_value(_pStartHeight))
                                        showUnits:              true
                                        unitsLabel:             qsTr("m")
                                        numericValuesOnly:      true
                                        validator:              DoubleValidator { bottom: 0; decimals: 1 }
                                        text:                   _isImmediate(_value(_pStartHeight)) ? "" : _value(_pStartHeight).toFixed(1)
                                        onEditingFinished: {
                                            var v = parseFloat(text)
                                            if (!isNaN(v)) {
                                                _setEdit(_pStartHeight, v)
                                            }
                                        }
                                    }
                                }

                                ParamRow {
                                    paramIndex: _pStartHeight
                                    QGCCheckBox {
                                        text:       qsTr("Start immediately (−1)")
                                        checked:    _isImmediate(_value(_pStartHeight))
                                        onClicked: {
                                            if (checked) {
                                                _setEdit(_pStartHeight, -1)
                                            } else {
                                                // Back to the height read from the LiDAR, or 0 m if that was "immediate" too
                                                var h = _deviceValue(_pStartHeight)
                                                _setEdit(_pStartHeight, _isImmediate(h) ? 0 : h)
                                            }
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                }

                                ParamRow {
                                    paramIndex: _pTrigMode
                                    showId:     false
                                    QGCLabel { text: qsTr("Trigger"); Layout.fillWidth: true }
                                    SegmentButtons {
                                        labels:     [qsTr("Time"), qsTr("Distance")]
                                        current:    _value(_pTrigMode)
                                        onSelected: _setEdit(_pTrigMode, index)
                                    }
                                }

                                ParamRow {
                                    paramIndex: _pTrigValue
                                    showId:     false
                                    QGCLabel { text: qsTr("Every"); Layout.fillWidth: true }
                                    QGCTextField {
                                        Layout.preferredWidth:  _fieldWidth
                                        showUnits:              true
                                        unitsLabel:             _value(_pTrigMode) === YSManager.TriggerModeDistance ? qsTr("m") : qsTr("s")
                                        numericValuesOnly:      true
                                        validator:              DoubleValidator { bottom: 0; decimals: 1 }
                                        text:                   _value(_pTrigValue).toFixed(1)
                                        onEditingFinished: {
                                            var v = parseFloat(text)
                                            if (!isNaN(v) && v > 0) {
                                                _setEdit(_pTrigValue, v)
                                            }
                                        }
                                    }
                                }
                            }

                            NoteLabel {
                                Layout.fillWidth:   true
                                text:               qsTr("Start height is measured from the acquisition start. \"Every\" unit follows the trigger (s or m).")
                            }
                        }
                    }

                    //-- ⑤ Read-only: Set Parameter not available yet, or acquisition running.
                    // Birdcom answers a failed Set only with MAV_RESULT_FAILED (no 0x01 / 0x06 code), so the lock reason
                    // comes from the acquisition state.
                    Rectangle {
                        Layout.fillWidth:       true
                        Layout.preferredHeight: lockLabel.contentHeight + ScreenTools.defaultFontPixelHeight * 0.5
                        visible:                !_setSupported || _locked
                        radius:                 ScreenTools.defaultFontPixelWidth / 2
                        color:                  _warningColor

                        QGCLabel {
                            id:                     lockLabel
                            anchors.left:           parent.left
                            anchors.right:          parent.right
                            anchors.margins:        ScreenTools.defaultFontPixelWidth
                            anchors.verticalCenter: parent.verticalCenter
                            color:                  "black"
                            wrapMode:               Text.WordWrap
                            font.pointSize:         ScreenTools.smallFontPointSize
                            text:                   !_setSupported ? qsTr("Read-only — Set Parameter is not supported by the companion board yet. Values shown are read from the LiDAR.")
                                                                   : qsTr("Read-only while acquisition is running — the LiDAR rejects Set Parameter (0x01). Stop acquisition first.")
                        }
                    }

                    //-- Per-item Set failures from the last Apply
                    QGCLabel {
                        Layout.fillWidth:   true
                        visible:            _failedOnApply.length > 0
                        wrapMode:           Text.WordWrap
                        color:              qgcPal.colorRed
                        text:               qsTr("Set failed: %1").arg(_failedOnApply.map(function(i) { return _paramName(i) }).join(", "))
                    }

                    RowLayout {
                        Layout.fillWidth:   true
                        spacing:            ScreenTools.defaultFontPixelWidth
                        visible:            _setSupported

                        QGCLabel {
                            Layout.fillWidth:   true
                            color:              qgcPal.colorBlue
                            text:               _applying ? qsTr("Applying…")
                                                          : (_changeCount === 0 ? "" : (_changeCount === 1 ? qsTr("1 change") : qsTr("%1 changes").arg(_changeCount)))
                        }

                        QGCButton {
                            text:       qsTr("Cancel")
                            enabled:    _changeCount > 0 && !_applying
                            onClicked:  cancel()
                        }

                        QGCButton {
                            text:       qsTr("Apply")
                            enabled:    _changeCount > 0 && _editable && _online
                            checked:    enabled     // highlighted (green) when there is something to apply
                            onClicked:  apply()
                        }
                    }
                }

                //-------------------------------------------------------------
                //-- ④ Current values (read-back)
                ColumnLayout {
                    Layout.fillWidth:       true
                    Layout.preferredWidth:  1
                    Layout.alignment:       Qt.AlignTop
                    spacing:                _rowSpacing

                    SectionTitle { text: qsTr("Current values (read-back)") }

                    Card {
                        GridLayout {
                            width:          parent.width
                            columns:        2
                            rowSpacing:     _rowSpacing
                            columnSpacing:  _colSpacing

                            QGCLabel { text: qsTr("Camera"); Layout.fillWidth: true }
                            ValueLabel { text: _readText(_ys && _ys.embeddedCamera !== 0 ? qsTr("On") : qsTr("Off")) }

                            QGCLabel { text: qsTr("Start height"); Layout.fillWidth: true }
                            ValueLabel { text: _readText(_startHeightText(_deviceValue(_pStartHeight))) }

                            QGCLabel { text: qsTr("Trigger"); Layout.fillWidth: true }
                            ValueLabel { text: _readText(_triggerText(_deviceValue(_pTrigMode), _deviceValue(_pTrigValue))) }

                            QGCLabel { text: qsTr("High sensitivity"); Layout.fillWidth: true }
                            ValueLabel { text: _livoxAvia ? _readText(_deviceValue(_pHighSens) !== 0 ? qsTr("On") : qsTr("Off")) : qsTr("n/a") }

                            QGCLabel { text: qsTr("Pattern"); Layout.fillWidth: true }
                            ValueLabel { text: _livoxAvia ? _readText(_deviceValue(_pPattern) !== 0 ? qsTr("Repetitive") : qsTr("Non-repetitive")) : qsTr("n/a") }
                        }

                        QGCButton {
                            text:       qsTr("Read again")
                            enabled:    _online && !_applying
                            onClicked:  readAll()
                        }
                    }

                    //-- Last MAVLink exchange (YSManager lastSentMessage / lastReceivedMessage) for checking Set / Get replies
                    NoteLabel {
                        Layout.fillWidth:   true
                        Layout.topMargin:   _rowSpacing
                        visible:            _ys && (_ys.lastSentMessage !== "" || _ys.lastReceivedMessage !== "")
                        text:               _ys ? qsTr("Last sent: %1").arg(_ys.lastSentMessage.replace(/ \| hex=.*/g, ""))
                                                  + "\n" + qsTr("Last reply: %1").arg(_ys.lastReceivedMessage !== "" ? _ys.lastReceivedMessage : "--")
                                                : ""
                    }
                }
            }
        }
    }

    //-------------------------------------------------------------------------
    // Local components

    component SectionTitle: QGCLabel {
        font.family: ScreenTools.demiboldFontFamily
    }

    component NoteLabel: QGCLabel {
        width:          parent ? parent.width : 0
        wrapMode:       Text.WordWrap
        font.pointSize: ScreenTools.smallFontPointSize
        opacity:        0.6
    }

    component ValueLabel: QGCLabel {
        font.family:        ScreenTools.demiboldFontFamily
        Layout.alignment:   Qt.AlignRight
    }

    // Shaded card; children are stacked in a column
    component Card: Rectangle {
        default property alias contents: cardCol.data
        Layout.fillWidth:       true
        Layout.preferredHeight: cardCol.height + (_cardMargin * 2)
        color:                  qgcPal.windowShade

        Column {
            id:                 cardCol
            anchors.margins:    _cardMargin
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.top:        parent.top
            spacing:            _rowSpacing
        }
    }

    // One parameter row: content + "0xNN" id, red outline when its last Set failed
    component ParamRow: Rectangle {
        property int  paramIndex:   0
        property bool showId:       true
        default property alias contents: rowLayout.data
        Layout.fillWidth:       true
        Layout.preferredHeight: rowLayout.implicitHeight
        color:                  "transparent"
        border.width:           _setFailed(paramIndex) ? 1 : 0
        border.color:           qgcPal.colorRed

        RowLayout {
            id:                     rowLayout
            anchors.left:           parent.left
            anchors.right:          idLabel.visible ? idLabel.left : parent.right
            anchors.rightMargin:    idLabel.visible ? ScreenTools.defaultFontPixelWidth : 0
            anchors.verticalCenter: parent.verticalCenter
        }

        QGCLabel {
            id:                     idLabel
            visible:                showId
            anchors.right:          parent.right
            anchors.verticalCenter: parent.verticalCenter
            text:                   "0x" + ("0" + paramIndex.toString(16).toUpperCase()).slice(-2)
            font.pointSize:         ScreenTools.smallFontPointSize
            opacity:                0.5
        }
    }

    // Exclusive choice; the selected button is highlighted. Not checkable, so a click never breaks the checked binding.
    component SegmentButtons: Row {
        property var labels:    []
        property int current:   0
        signal selected(int index)
        spacing: ScreenTools.defaultFontPixelWidth / 2

        Repeater {
            model: labels
            QGCButton {
                text:       modelData
                checkable:  false
                checked:    index === current
                onClicked:  selected(index)
            }
        }
    }
}
