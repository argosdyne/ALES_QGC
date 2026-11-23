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
    // picks Brazil), Japanese 59. 0 = AnyLanguage (follow the system).
    readonly property var languageValues: [0, 31, 66, 132, 42, 29, 91, 59]
    readonly property var languageNames:  ["English", "한국어", "Tiếng Việt", "Deutsch", "Dansk", "Português (Brasil)", "日本語"]

    model: [qsTr("System")].concat(languageNames)
    currentIndex: languageValues.indexOf(Number(_fact.rawValue))
    onActivated: _fact.rawValue = languageValues[index]
}
