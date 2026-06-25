import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Controls.Styles  1.4
import QtQuick.Dialogs          1.2

import QGroundControl.FactSystem    1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0

QGCTextField {
    id: _textField

    text:               _formatFactValue()
    unitsLabel:         fact ? fact.units : ""
    showUnits:          true
    showHelp:           true
    numericValuesOnly:  fact && !fact.typeIsString

    signal updated()

    property Fact   fact: null
    property var    customValidateFunction: null
    property bool   customValidationReplacesFactValidation: false
    property int    displayDecimalPlaces: -1

    property string _validateString
    property string _validationErrorString

    function _formatFactValue() {
        if (!fact) {
            return ""
        }

        if (displayDecimalPlaces < 0 || fact.typeIsString || fact.typeIsBool) {
            return fact.valueString
        }

        var value = Number(fact.value)
        if (isNaN(value)) {
            return fact.valueString
        }

        return value.toFixed(displayDecimalPlaces)
    }

    function _syncTextToFact() {
        if (!_textField.activeFocus) {
            _textField.text = _formatFactValue()
        }
    }

    function _customValidationError(valueText) {
        if (customValidateFunction) {
            return customValidateFunction(valueText)
        }

        return ""
    }

    onEditingFinished: {
        var errorString = ""
        if (customValidationReplacesFactValidation) {
            errorString = _customValidationError(text)
        } else {
            errorString = fact.validate(text, false /* convertOnly */)
            if (errorString === "") {
                errorString = _customValidationError(text)
            }
        }

        if (errorString === "") {
            fact.value = text
            _textField.updated()
        } else {
            _validateString = text
            _validationErrorString = errorString
            text = _formatFactValue()
            validationErrorDialogComponent.createObject(mainWindow).open()
        }
    }

    onHelpClicked: helpDialogComponent.createObject(mainWindow).open()
    onFactChanged: _syncTextToFact()

    Connections {
        target: fact

        onValueChanged: {
            _textField._syncTextToFact()
        }

        onRawValueChanged: {
            _textField._syncTextToFact()
        }
    }

    Component {
        id: validationErrorDialogComponent

        ParameterEditorDialog {
            title:          qsTr("Invalid Value")
            validate:       true
            validateValue:  _validateString
            validationErrorOverride: _validationErrorString
            customValidateFunction: function(valueText) { return _textField._customValidationError(valueText) }
            customValidationReplacesFactValidation: _textField.customValidationReplacesFactValidation
            displayDecimalPlaces: _textField.displayDecimalPlaces
            fact:           _textField.fact
        }
    }

    Component {
        id: helpDialogComponent

        ParameterEditorDialog {
            title:          qsTr("Value Details")
            displayDecimalPlaces: _textField.displayDecimalPlaces
            fact:           _textField.fact
        }
    }
}
