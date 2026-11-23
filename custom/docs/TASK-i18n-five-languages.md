# TASK — Simple UI in Vietnamese, German, Danish, Portuguese (Brazil) and Japanese

Put this file in `custom/docs/`. Prepared 2026-11-23 from Figma AQGC-simpler and branch `feature/aqgc-simple-v1`
(b39159a36). Follow `CLAUDE.md` working rules (Figma first, small topic commits, CI check, PR #311 text).

## 1. Goal

The Simple UI is shown in 5 more languages: `vi_VN`, `de_DE`, `da_DK`, `pt_BR`, `ja_JP` (Korean and English exist).
The user picks the language on the first-start screen (S57) and in Settings › General; the Simple UI changes at once
(as Korean does today, `AppSettings::_qLocaleLanguageChanged`).

Design source (Figma `p7d3GuBZaJNSj8zpBUlaSj`):
- Pages `01 Screens · VI / DE / DA / PT-BR / JA` — every S## screen in that language (UX notes stay English on `01 Screens`).
- Page `99 i18n Strings (data)` — the same strings as data (`enkeys`, `<lang>_0`, `<lang>_1`). Exported in this package
  as `figma_strings.json`, so you do not need Figma access.
- Terms were checked against DJI localized manuals and the QGroundControl community translations (2026-11-23).

## 2. Files in this package

| File | Put it in | What it is |
|---|---|---|
| `translations/qgc_simple_<locale>.ts` (5) | `translations/` | Drafts made from `qgc_simple_ko_KR.ts` (same contexts / messages) |
| `i18n/figma_strings.json` | `custom/i18n/` | 1,484 Figma strings: `id, en, vi, de, da, pt, ja` (value = EN when the text stays English) |
| `i18n/glossary.json` | `custom/i18n/` | 72 core terms in the 5 languages (taken from the Figma data) |
| `tools/fill_from_figma.py` | `custom/tools/i18n/` | Fills empty messages of a `.ts` from `figma_strings.json` (no third-party packages) |

Draft status per file (2,210 messages, 1,861 unique sources, no numerus forms):

| | finished (exact Figma match) | draft from a Figma example (`unfinished` + comment) | empty |
|---|---|---|---|
| each language | 1,175 | 61 – 69 | 966 – 974 (≈ 924 unique sources) |

`lrelease` accepts all five files.

## 3. Steps

1. **Refresh sources.** `qgc_simple_ko_KR.ts` may be behind the QML. Run
   `lupdate custom/res/Simple -ts translations/qgc_simple_<locale>.ts` for each new file (keep the two core
   contexts `FlyView` and `MainRootWindow`, as for Korean — see `custom/res/Simple/README.md`), then
   `python custom/tools/i18n/fill_from_figma.py custom/i18n/figma_strings.json translations/qgc_simple_<locale>.ts <vi|de|da|pt|ja>`.
2. **Translate the rest** (≈ 924 sources per language):
   - Use `glossary.json` terms exactly; match the tone and length of `figma_strings.json` (short, plain words, imperative
     for actions, the same wording for the same thing).
   - Keep `%1`… placeholders, units (`m`, `m/s`, `%`), `›` menu paths, product names (AQUILA, RHYTHM 3, YellowScan,
     SAFE-T, Enpulse, AVIATOR, Altitude Angel), standards (ED-318, EU C2), and ArduPilot mode names (Stabilize, Acro,
     AltHold, Loiter, RTL, SmartRTL, AutoTune) in English.
   - Labels inside buttons / chips / telemetry boxes: no longer than the Figma version of a similar label.
   - Review every draft that has a `translatorcomment` (check placeholder order), then remove the comment and `type`.
   - Japanese: です/ます for sentences, noun form for labels; full-width （）「」, half-width digits and units.
3. **Language list.**
   - `src/Settings/App.SettingsGroup.json` `qLocaleLanguage`: add Danish and Vietnamese (`QLocale::Danish` = 29,
     `QLocale::Vietnamese` = 132, checked in Qt 5 `qlocale.h`). Labels in their own language:
     `Tiếng Việt (Vietnamese)`, `Dansk (Danish)`, `Português (Brasil)`, `Deutsch (German)` (the current "Deutsche" is wrong).
   - Do not change the order of the existing `enumValues`; `_qLocaleLanguageID()` migrates old index-based values.
   - `AppSettings::_rgReleaseLanguages` / `_rgPartialLanguages` decide what the combo shows. The Simple UI combo
     (`SimpleWelcome.qml`, `SimpleSettings.qml`) should list only languages with a Simple translation:
     System, English, 한국어, Tiếng Việt, Deutsch, Dansk, Português (Brasil), 日本語. Keep Advanced mode behaviour as is
     (classic screens stay English where QGC has no translation).
   - `SimpleWelcome.qml` sub text: use the Figma string (id 460)
     `English, 한국어, Tiếng Việt, Deutsch, Dansk, Français, Português (Brasil), 日本語`.
     **Open question for the user:** Figma lists Français, but there is no French translation. Ask before showing it.
4. **Fonts.**
   - Roboto Regular / Medium / Bold cover every character of vi, de, da, pt (checked with fontTools). Nothing to add.
   - Japanese needs **Noto Sans JP** (OFL 1.1) Regular / Medium / Bold, subset like Noto Sans KR: kana, jōyō kanji,
     CJK punctuation, plus every character in `qgc_simple_ja_JP.ts`. Register it in `QGCApplication::setLanguage()`
     next to Noto Sans KR and substitute `Roboto` / `Roboto Medium` → `Noto Sans JP` when the language is Japanese.
     Add it to `custom.qrc` (`/simple/fonts`), the licence index (`custom/tools/licenses/`) and S48 Legal & licenses.
   - Note: Noto Sans KR contains only 日本語 for the language list — it is not a Japanese fallback.
5. **Fit.** Extend `custom/tests/simple/static_checks.py` (Korean label widths) to all five languages with the bundled
   fonts. Figma places where the text was shortened or wraps: S02 compass hint, S17/S102/S103 "Hold 2 s to stop" button,
   S28/S104 position-hold note, S78/S96 emergency-stop note (2 lines), S05/S109 Danish "Returnerer hjem" status chip.
   Remaining small overflows in Figma: VI 11, DE 4, DA 3, PT-BR 7, JA 0 — allow 2 lines for those buttons or shrink to
   the 80 % minimum (`SimpleTheme.fs`).
6. **Other text paths.** Check strings that do not go through `qsTr` in Simple screens (C++ `tr()` in
   `custom/src`, FactMetaData enum strings shown in Simple rows, flight-mode names from the firmware plugin, speech
   (`Speech language` row) and the megaphone language list). List what stays English in the PR.
7. **Numbers and dates.** Figma keeps `2.1 km`, `2026-10-28`, 24-hour time for every language. Do not change number
   formatting in this task; note it in the PR as a later decision.
8. **Test.** `static_checks.py` (coverage, placeholders, glyphs, widths), Qt Quick tests, Windows and Android CI.
   Run `--simple-mock --fake-mobile` in each language and compare S01, S02, S04, S05, S21, S24, S57 with the Figma
   language pages. Switch languages at runtime and after a restart.
9. **Docs.** Update `custom/res/Simple/README.md` (translations, fonts), `CLAUDE.md` (decision + date), PR #311 text.

Commits (suggested): `Simple UI: language list (vi, da, pt-BR, ja)`, `Simple UI: Noto Sans JP`,
`Simple UI: translations vi/de/da/pt-BR/ja`, `Simple UI: label width checks for all languages`.

## 4. Core terms (from `glossary.json`)

| EN | vi | de | da | pt-BR | ja |
|---|---|---|---|---|---|
| Take off | Cất cánh | Starten | Start | Decolar | 離陸 |
| Land | Hạ cánh | Landen | Land | Pousar | 着陸 |
| Return home | Quay về | Rückkehr | Returner hjem | Retornar à base | 帰還 |
| Home point | Home Point | Startpunkt | Hjemsted | Ponto de origem | ホームポイント |
| Pause / Resume mission | Tạm dừng / Tiếp tục nhiệm vụ | Pause / Mission fortsetzen | Pause / Genoptag mission | Pausar / Retomar missão | 一時停止 / ミッションを再開 |
| Battery / Low battery | Pin / Pin yếu | Akku / Akku niedrig | Batteri / Lavt batteri | Bateria / Bateria baixa | バッテリー / バッテリー低下 |
| Signal lost | Mất tín hiệu | Signal verloren | Signal tabt | Sinal perdido | 信号ロスト |
| Payloads | Payload | Nutzlasten | Nyttelast | Cargas úteis | ペイロード |
| Waypoint | Waypoint | Wegpunkt | Waypoint | Waypoint | ウェイポイント |
| Mission | Nhiệm vụ | Mission | Mission | Missão | ミッション |
| Pre-flight check | Kiểm tra trước khi bay | Vorflug-Checkliste | Kontrol før flyvning | Verificação pré-voo | 飛行前チェック |
| Arm / Disarm | Khởi động động cơ / Tắt động cơ | Scharf schalten / Entschärfen | Armér / Desarmér | Armar / Desarmar | アーム / ディスアーム |
| Emergency stop | Dừng khẩn cấp | Not-Aus | Nødstop | Parada de emergência | 緊急停止 |
| Fence | Geofence | Geofence | Geofence | Geocerca | フェンス |
| Go here | Bay tới đây | Hierhin fliegen | Flyv hertil | Ir para cá | ここへ飛行 |
| Offline maps | Bản đồ ngoại tuyến | Offline-Karten | Offlinekort | Mapas offline | オフラインマップ |
| Vehicle setup | Thiết lập drone | Drohnen-Einrichtung | Droneopsætning | Configuração do veículo | 機体設定 |

## 5. Do not

- Push to `Argos_Stable4.4` or merge PR #311.
- Change English source strings to make a translation fit — shorten the translation or allow wrapping.
- Copy any secret value from the code (see CLAUDE.md, cybersecurity notes) into translations, comments or tests.
