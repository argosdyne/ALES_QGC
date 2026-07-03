import QtQuick          2.12
import QtQuick.Controls 2.4
import QtQuick.Dialogs  1.3
import QtQuick.Layouts  1.12
import Qt.labs.settings 1.0

import QGroundControl             1.0
import QGroundControl.Controls    1.0
import QGroundControl.Palette     1.0
import QGroundControl.ScreenTools 1.0

QGCPopupDialog {
    id: root
    title: ""
    buttons: 0
    showTitleBar: false
    property bool reviewMode: false

    readonly property real _contentWidth: Math.min(ScreenTools.defaultFontPixelWidth * 72,
                                                   root._maxContentWidth - ScreenTools.defaultFontPixelWidth * 2)
    property var languageCodes: [ "en", "de", "fr", "es", "it", "nl", "pl" ]
    property var copy: ({
        "en": {
            "title": "Welcome to ALES QGC\nPrivacy Notice", "language": "Notice language",
            "intro": "ALES QGC processes vehicle data required for safe ground-control operation, including:",
            "data": "Vehicle identifiers and telemetry\nVehicle and ground-station location\nFlight status, configuration and diagnostic logs\nVideo streams, when enabled",
            "local": "This information is processed locally by default. Data is sent to external services only when you enable or configure the relevant feature:",
            "services": "NTRIP: connection information and location data may be sent to the selected correction provider.\nOnline maps: your IP address and requested map area may be visible to the map provider.\nRemote Support or MAVLink Forwarding: vehicle telemetry is sent to the configured endpoint.",
            "required": "Required: I acknowledge the Privacy Notice and understand how vehicle and location data may be processed.",
            "optional": "Optional: Enable NTRIP RTK GPS correction (uses a third-party service of your choice; the position is sent to the service operator).",
            "later": "Optional network services can be changed later in Settings.", "continue": "CONTINUE", "close": "CLOSE"
        },
        "de": {
            "title": "Willkommen bei ALES QGC\nDatenschutzhinweis", "language": "Sprache des Hinweises",
            "intro": "ALES QGC verarbeitet für den sicheren Bodenstationsbetrieb erforderliche Fahrzeugdaten, darunter:",
            "data": "Fahrzeugkennungen und Telemetrie\nStandort von Fahrzeug und Bodenstation\nFlugstatus, Konfiguration und Diagnoseprotokolle\nVideostreams, wenn aktiviert",
            "local": "Diese Informationen werden standardmäßig lokal verarbeitet. Daten werden nur an externe Dienste gesendet, wenn Sie die entsprechende Funktion aktivieren oder konfigurieren:",
            "services": "NTRIP: Verbindungsinformationen und Standortdaten können an den gewählten Korrekturanbieter gesendet werden.\nOnline-Karten: Ihre IP-Adresse und das angeforderte Kartengebiet können für den Kartenanbieter sichtbar sein.\nFernsupport oder MAVLink-Weiterleitung: Fahrzeugtelemetrie wird an den konfigurierten Endpunkt gesendet.",
            "required": "Erforderlich: Ich bestätige den Datenschutzhinweis und verstehe, wie Fahrzeug- und Standortdaten verarbeitet werden können.",
            "optional": "Optional: NTRIP-RTK-GPS-Korrektur aktivieren (nutzt einen Drittanbieter Ihrer Wahl; die Position wird an den Betreiber gesendet).",
            "later": "Optionale Netzwerkdienste können später in den Einstellungen geändert werden.", "continue": "WEITER", "close": "SCHLIESSEN"
        },
        "fr": {
            "title": "Bienvenue dans ALES QGC\nAvis de confidentialité", "language": "Langue de l’avis",
            "intro": "ALES QGC traite les données du véhicule nécessaires au fonctionnement sûr de la station au sol, notamment :",
            "data": "Identifiants du véhicule et télémétrie\nPosition du véhicule et de la station au sol\nÉtat du vol, configuration et journaux de diagnostic\nFlux vidéo, lorsqu’ils sont activés",
            "local": "Ces informations sont traitées localement par défaut. Elles ne sont envoyées à des services externes que si vous activez ou configurez la fonction concernée :",
            "services": "NTRIP : les informations de connexion et la position peuvent être envoyées au fournisseur de corrections choisi.\nCartes en ligne : votre adresse IP et la zone demandée peuvent être visibles par le fournisseur.\nAssistance à distance ou transfert MAVLink : la télémétrie est envoyée au terminal configuré.",
            "required": "Obligatoire : Je reconnais avoir pris connaissance de l’avis et comprends comment les données du véhicule et de position peuvent être traitées.",
            "optional": "Facultatif : Activer la correction GPS RTK NTRIP (service tiers de votre choix ; la position est envoyée à son opérateur).",
            "later": "Les services réseau facultatifs peuvent être modifiés ultérieurement dans les paramètres.", "continue": "CONTINUER", "close": "FERMER"
        },
        "es": {
            "title": "Bienvenido a ALES QGC\nAviso de privacidad", "language": "Idioma del aviso",
            "intro": "ALES QGC procesa los datos del vehículo necesarios para el funcionamiento seguro de la estación de control, incluidos:",
            "data": "Identificadores del vehículo y telemetría\nUbicación del vehículo y de la estación terrestre\nEstado del vuelo, configuración y registros de diagnóstico\nVídeo, cuando está habilitado",
            "local": "Esta información se procesa localmente de forma predeterminada. Solo se envía a servicios externos cuando activa o configura la función correspondiente:",
            "services": "NTRIP: la información de conexión y ubicación puede enviarse al proveedor de correcciones elegido.\nMapas en línea: su dirección IP y el área solicitada pueden ser visibles para el proveedor.\nSoporte remoto o reenvío MAVLink: la telemetría se envía al destino configurado.",
            "required": "Obligatorio: Confirmo el Aviso de privacidad y comprendo cómo pueden procesarse los datos del vehículo y de ubicación.",
            "optional": "Opcional: Activar la corrección GPS RTK NTRIP (usa un servicio externo de su elección; la posición se envía al operador).",
            "later": "Los servicios de red opcionales se pueden cambiar más tarde en Ajustes.", "continue": "CONTINUAR", "close": "CERRAR"
        },
        "it": {
            "title": "Benvenuto in ALES QGC\nInformativa sulla privacy", "language": "Lingua dell’informativa",
            "intro": "ALES QGC tratta i dati del veicolo necessari al funzionamento sicuro della stazione di controllo, inclusi:",
            "data": "Identificativi del veicolo e telemetria\nPosizione del veicolo e della stazione di terra\nStato del volo, configurazione e registri diagnostici\nFlussi video, se abilitati",
            "local": "Per impostazione predefinita queste informazioni sono trattate localmente. I dati vengono inviati a servizi esterni solo quando si abilita o configura la relativa funzione:",
            "services": "NTRIP: informazioni di connessione e posizione possono essere inviate al provider di correzione scelto.\nMappe online: l’indirizzo IP e l’area richiesta possono essere visibili al provider.\nAssistenza remota o inoltro MAVLink: la telemetria viene inviata all’endpoint configurato.",
            "required": "Obbligatorio: Confermo di aver letto l’informativa e comprendo come possono essere trattati i dati del veicolo e della posizione.",
            "optional": "Facoltativo: Abilita la correzione GPS RTK NTRIP (usa un servizio terzo scelto dall’utente; la posizione viene inviata al gestore).",
            "later": "I servizi di rete facoltativi possono essere modificati in seguito nelle Impostazioni.", "continue": "CONTINUA", "close": "CHIUDI"
        },
        "nl": {
            "title": "Welkom bij ALES QGC\nPrivacyverklaring", "language": "Taal van de verklaring",
            "intro": "ALES QGC verwerkt voertuiggegevens die nodig zijn voor een veilige werking van het grondstation, waaronder:",
            "data": "Voertuig-ID’s en telemetrie\nLocatie van voertuig en grondstation\nVluchtstatus, configuratie en diagnostische logboeken\nVideostreams, indien ingeschakeld",
            "local": "Deze informatie wordt standaard lokaal verwerkt. Gegevens worden alleen naar externe diensten gestuurd wanneer u de betreffende functie inschakelt of configureert:",
            "services": "NTRIP: verbindings- en locatiegegevens kunnen naar de gekozen correctieprovider worden gestuurd.\nOnline kaarten: uw IP-adres en opgevraagd kaartgebied kunnen zichtbaar zijn voor de provider.\nOndersteuning op afstand of MAVLink-forwarding: telemetrie wordt naar het ingestelde eindpunt gestuurd.",
            "required": "Vereist: Ik erken de Privacyverklaring en begrijp hoe voertuig- en locatiegegevens kunnen worden verwerkt.",
            "optional": "Optioneel: NTRIP RTK GPS-correctie inschakelen (gebruikt een externe dienst naar keuze; de positie wordt naar de aanbieder gestuurd).",
            "later": "Optionele netwerkdiensten kunnen later in Instellingen worden gewijzigd.", "continue": "DOORGAAN", "close": "SLUITEN"
        },
        "pl": {
            "title": "Witamy w ALES QGC\nInformacja o prywatności", "language": "Język informacji",
            "intro": "ALES QGC przetwarza dane pojazdu wymagane do bezpiecznej pracy stacji naziemnej, w tym:",
            "data": "Identyfikatory pojazdu i telemetrię\nPołożenie pojazdu i stacji naziemnej\nStan lotu, konfigurację i dzienniki diagnostyczne\nStrumienie wideo, jeśli są włączone",
            "local": "Domyślnie informacje te są przetwarzane lokalnie. Dane są wysyłane do usług zewnętrznych tylko po włączeniu lub skonfigurowaniu odpowiedniej funkcji:",
            "services": "NTRIP: dane połączenia i lokalizacji mogą być wysyłane do wybranego dostawcy korekt.\nMapy online: adres IP i żądany obszar mapy mogą być widoczne dla dostawcy.\nPomoc zdalna lub przekazywanie MAVLink: telemetria jest wysyłana do skonfigurowanego punktu końcowego.",
            "required": "Wymagane: Potwierdzam zapoznanie się z informacją i rozumiem, jak mogą być przetwarzane dane pojazdu i lokalizacji.",
            "optional": "Opcjonalne: Włącz korekcję GPS RTK NTRIP (korzysta z wybranej usługi zewnętrznej; pozycja jest wysyłana do operatora).",
            "later": "Opcjonalne usługi sieciowe można później zmienić w Ustawieniach.", "continue": "KONTYNUUJ", "close": "ZAMKNIJ"
        }
    })
    property var t: copy[languageCodes[languageCombo.currentIndex]]

    function tr(key) { return t ? t[key] : copy.en[key] }

    Settings {
        id: privacySettings
        category: "Custom"
        property int privacyNoticeAcceptedVersion: 0
        property bool privacyNtripConsent: false
        property string privacyNoticeLanguage: "en"
    }

    function acceptNotice() {
        if (reviewMode) {
            close()
            return
        }
        if (!requiredCheck.checked) {
            return
        }
        privacySettings.privacyNoticeLanguage = languageCodes[languageCombo.currentIndex]
        privacySettings.privacyNtripConsent = optionalCheck.checked
        if (optionalCheck.checked) {
            // Custom.SettingsGroup.json: RTCM Source enum value 1 is NTRIP.
            QGroundControl.corePlugin.settings.rtcmSource.rawValue = 1
        }
        privacySettings.privacyNoticeAcceptedVersion = 1
        close()
    }

    onOpened: {
        var index = languageCodes.indexOf(privacySettings.privacyNoticeLanguage)
        languageCombo.currentIndex = index >= 0 ? index : 0
    }

    ColumnLayout {
        width: root._contentWidth
        spacing: ScreenTools.defaultFontPixelHeight * 0.6

        QGCLabel {
            text: tr("title")
            font.family: ScreenTools.demiboldFontFamily
            font.pointSize: ScreenTools.mediumFontPointSize
            Layout.fillWidth: true
            Layout.topMargin: ScreenTools.defaultFontPixelHeight * 0.35
            wrapMode: Text.WordWrap
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: qgcPal.colorGrey; opacity: 0.45 }

        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            QGCComboBox {
                id: languageCombo
                model: [ "English", "Deutsch", "Français", "Español", "Italiano", "Nederlands", "Polski" ]
                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 19
            }
        }


        QGCFlickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(noticeColumn.implicitHeight,
                                             ScreenTools.defaultFontPixelHeight * 26,
                                             root._maxContentHeight - ScreenTools.defaultFontPixelHeight * 12)
            contentWidth: width
            contentHeight: noticeColumn.implicitHeight
            clip: true

            ColumnLayout {
                id: noticeColumn
                width: parent.width - ScreenTools.defaultFontPixelWidth
                spacing: ScreenTools.defaultFontPixelHeight * 0.55

                QGCLabel { text: tr("intro"); Layout.fillWidth: true; wrapMode: Text.WordWrap }
                QGCLabel { text: "• " + tr("data").replace(/\n/g, "\n• "); Layout.fillWidth: true; wrapMode: Text.WordWrap; leftPadding: ScreenTools.defaultFontPixelWidth }
                QGCLabel { text: tr("local"); Layout.fillWidth: true; wrapMode: Text.WordWrap }
                QGCLabel { text: "• " + tr("services").replace(/\n/g, "\n• "); Layout.fillWidth: true; wrapMode: Text.WordWrap; leftPadding: ScreenTools.defaultFontPixelWidth }

                RowLayout {
                    Layout.fillWidth: true
                    visible: !root.reviewMode
                    QGCCheckBox { id: requiredCheck; text: "" }
                    QGCLabel {
                        id: requiredLabel
                        text: tr("required")
                        font.family: ScreenTools.demiboldFontFamily
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        MouseArea { anchors.fill: parent; onClicked: requiredCheck.checked = !requiredCheck.checked }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: !root.reviewMode
                    QGCCheckBox { id: optionalCheck; text: "" }
                    QGCLabel {
                        text: tr("optional")
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        MouseArea { anchors.fill: parent; onClicked: optionalCheck.checked = !optionalCheck.checked }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: laterLabel.implicitHeight
                            + ScreenTools.defaultFontPixelHeight * 0.45
                            + continueButton.implicitHeight

            QGCLabel {
                id: laterLabel
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                text: tr("later")
                color: qgcPal.colorGrey
                wrapMode: Text.WordWrap
            }

            QGCButton {
                id: continueButton
                anchors.top: laterLabel.bottom
                anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.45
                anchors.right: parent.right
                text: root.reviewMode ? tr("close") : tr("continue")
                primary: true
                enabled: root.reviewMode || requiredCheck.checked
                onClicked: root.acceptNotice()
            }
        }
    }
}
