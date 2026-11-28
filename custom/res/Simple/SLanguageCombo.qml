import QtQuick 2.12
import QGroundControl 1.0
import "."

// Language list of the Simple UI (S57 welcome, Settings › General). Only languages that have a Simple UI
// translation (translations/qgc_simple_<locale>.ts) are offered; names are in their own language and not
// translated. Values are QLocale::Language, stored in the setting qLocaleLanguage (AppSettings applies it at once).
SComboBox {
    id: box
    readonly property var _fact: QGroundControl.settingsManager.appSettings.qLocaleLanguage
    // QLocale::Language: English 31, Korean 66, Vietnamese 132, German 42, Danish 29, Portuguese 91 (QLocale
    // picks Brazil), Japanese 59. 0 = AnyLanguage (follow the system). 10000 = Traditional Chinese (Taiwan):
    // QLocale::Language cannot tell it from Simplified Chinese (AppSettings::traditionalChineseTaiwanLanguageID).
    readonly property var languageValues: [0, 31, 66, 132, 42, 29, 91, 59, 10000]
    readonly property var languageNames:  ["English", "한국어", "Tiếng Việt", "Deutsch", "Dansk", "Português (Brasil)", "日本語", "繁體中文"]

    model: [qsTr("System")].concat(languageNames)
    onActivated: _fact.rawValue = languageValues[index]

    // Not a binding: choosing an item sets currentIndex (the binding would be lost), and the language change
    // rebuilds the model (qsTr), which resets a ComboBox to index 0 ("System"). Set it again after both.
    function _sync() { currentIndex = languageValues.indexOf(Number(_fact.rawValue)) }
    Component.onCompleted: _sync()
    onModelChanged: _sync()
    Connections { target: box._fact; function onRawValueChanged() { box._sync() } }
}
