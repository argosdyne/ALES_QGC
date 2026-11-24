# AQGC Simple UI (v1)

Simple, map-first UI for general users of alesQGC. It is the default UI; the classic alesQGC UI is
shown in **Advanced mode**, unlocked with the admin PIN.

- Design: Figma **AQGC-simpler** — `01 Screens` (S01–S56), `02 Flows` (navigation map, task flows,
  state rules, layer rules), `00 Overview` §8 (design rules).
- Meeting deck: `AGD-PRS-ALQGC-100_AQGC-UI-단순화-검토회의` (D08).

## How it is wired

| Place | Change |
|---|---|
| `src/ui/MainRootWindow.qml` | `simpleUI = !corePlugin.showAdvancedUI`. Skips the classic first-run prompts in Simple UI (the welcome replaces them). Loads `qrc:/simple/SimpleRoot.qml` on top of the views when `simpleUI`; hides the classic toolbar; shows a "Lock and return to Simple" button in Advanced mode. |
| `src/FlightDisplay/FlyView.qml` | `simpleMode` property hides the classic fly widgets. Map, video and PiP stay. In Simple mode the PiP follows Figma S04: bottom-right (right 24, bottom 24), 400 × 226 (scaled from 1920 × 1080), rounded corners. The FPV overlay starts between the telemetry bar and the PiP. Layout: telemetry bar bottom-left (x 24), PiP bottom-right. |
| `src/QmlControls/PipView.qml` | `simpleStyle`: frame, "Camera" / "Map" label, tap to swap only (no resize, pop-out or hide buttons). |
| `src/PlanView/PlanView.qml` | `simpleMode` property hides the tool strip, right panel, terrain status and map scale. Map and mission visuals stay, so the survey polygon is edited on the classic map. In Simple mode a map tap is sent as `simpleMapClicked(coordinate)` (S23) and `simpleMap` exposes the map. |
| `custom/src/Custom.SettingsGroup.json` | New settings: `simpleAdvancedMode` (Advanced mode on/off kept over restarts; no PIN since 2026-11-16), `simpleWelcomeShown`, `simpleLargeText`, `simpleStartScreen`, `simpleProductProfile` (Tether = S11 fly screen; chosen in Advanced › General). |
| `custom/src/CustomPlugin.cc` | `guidedMaximumAltitude` default = 120 m (decision 2026-11-13). Planning vehicle without a drone = ArduPilot multicopter (decision 2026-11-14). |
| `custom/custom.qrc` | Prefix `/simple`: all files in this folder and `icons/` (exported from Figma). |
| `src/QGCApplication.cc` | `setLanguage()`: registers the Simple UI fonts (`fonts/`), maps Roboto → Noto Sans KR for Hangul when the language is Korean, loads the Simple UI translation `:/i18n/qgc_simple_<locale>.qm`. Font registration runs in both modes (decision 2026-11-14): the classic UI never uses Roboto, so Advanced looks the same. |
| `src/Settings/AppSettings.cc` | In Simple UI a language change is applied at once (`setLanguage()`); Advanced mode still needs a restart. |
| `QGCPostLinkCommon.pri` | Windows: copies the third-party notices (`licenses/*.txt`) to `<install dir>\licenses`, so the NSIS installer ships them. |
| `src/comm/MockLink.cc` | Accepts `PARAM_REQUEST_LIST` sent to `MAV_COMP_ID_AUTOPILOT1` (this fork sends it there), so the debug mock vehicle no longer asserts. |

The Simple UI does not duplicate flight logic. It calls the existing controllers:

- Flight actions → `globals.guidedControllerFlyView.executeAction(...)` (take off, return home, land,
  pause, continue mission).
- Plan → `planView._planMasterController` (take-off item + Survey + return item, `sendToVehicle()`).
- Safety settings → FC parameters through `FactPanelController` (`RTL_ALT`, `FENCE_ALT_MAX`,
  `FENCE_RADIUS` on ArduPilot; PX4 equivalents).

## Files

| File | Figma | Purpose |
|---|---|---|
| `SimpleRoot.qml` | — | Pages (fly / plan / settings), menu, PIN, first-start welcome, navigation functions |
| `SimpleWelcome.qml` | S57 | First start: language and units (Metric / Imperial). Replaces the classic "Measurement Units" and "Vehicle Information" prompts |
| `SimpleVehicleState.qml` | 02 Flows › C | One place for vehicle state used by all state rules |
| `SimpleFlyOverlay.qml` | S01–S05, S33–S38 | Top bar, left actions by state, camera rail, telemetry, banners, sheets, map tap menu, toast |
| `SimpleMapTapMenu.qml` | S35 | Map tap: pin + Go here / Set as home point / Enter coordinates; zones under the tap (Details → S15). Go here only in flight; refused in red inside or across a prohibited / no-entry zone (`FlightZoneManager.zoneAt` / `zoneOnPath`), outside the geofence (`goToTargetBlockReason`) or beyond `maxGoToLocationDistance` |
| `SimpleGoHereSheet.qml` | S35 | Go here confirm: height, distance / time, obstacle detection, slide. Sends `actionGoto` with the classic GoTo editor data, so the classic FlyViewMap GoTo state drives progress |
| `SimpleCoordSheet.qml` | S35 | Latitude / longitude input (red when out of range) |
| `SimpleGoHereCard.qml` | S36 | Go here progress card (Change target · Stop; stopped: Continue · Cancel), arrival (2 m, < 0.3 m/s, 2 s), obstacle state (OBSTACLE_DISTANCE ≤ 3 m) for the banners |
| `SimplePayloadPanel.qml` | S10, S16, S17, S51 | Payloads panel (button under the camera rail, badge = count). Cards from the existing managers only: tether (`elistairStationManager`: power, automatic torque, telemetry), YellowScan (`ysManager`: checks, start, hold to stop; not ready → S51 banner), megaphone (`vehicle.audioControl`, clip 1–11 play / stop), searchlight (`missionController.setSearchlight`), winch (`vehicle.sendGripperAction`, hold 2 s to release), life jacket (`deployLifeVest`, hold 2 s). Cards appear with the classic switches (`enableAudioController`, `lifeJacketEnable`, GRIP_ENABLE, tether `enabled`, `ysEnable`). S50 banner and the tether slide sheets are in `SimpleFlyOverlay.qml` |
| `SimpleTetherCard.qml` | S11 | Tether profile card (profile "Tether" in Advanced › General + station on): cable out / station length alarm, tension = SAFE-T alarm state, ground power, backup battery, power, spool temperature. The other S11 changes (ground-power chip, CABLE OUT / TENSION telemetry, Land + height −/+, cable circle, alarms, S16 take-off gate) are in `SimpleTopBar`, `STelemetryBar`, `SimpleFlyOverlay`, `SimpleVehicleState`, `SimplePreflightSheet` |
| `SimpleCameraSheet.qml` | S43 | Camera settings from the rail "Camera" button (MAVLink camera `QGCCameraControl`): streams, photo / video, auto photos off / 2 s / 5 s (time lapse; no distance shooting), EV (`EO_EV`/`CAM_EV`), thermal palette (`IR_PALETTE`), grid lines, SD free space. Same place as the Payloads panel. "More camera settings ›" opens S100 |
| `SimpleCameraAll.qml` | S100 | All camera settings (sheet): every camera-definition setting (list / switch / number / text), thermal view and blend, video fit, SD card format and camera reset (asked once inline). Replaces the classic camera Settings dialog |
| `SimplePayloadPrefs.qml` | S56 | Singleton (Qt.labs.settings `SimplePayloads`): megaphone, searchlight, winch, cleaning values. Used today: winch hold time, stop clip / searchlight off on landing; the rest is kept until the devices accept it. The S56 pages are in `SimplePayloadSettings.qml` |
| `SPayloadCard.qml`, `SHoldButton.qml` | 99 Components | Payload card (header + status pill + body), hold-to-run button |
| `SimpleAltitudeSheet.qml` | S38 | Tap ALTITUDE in flight: 5 m steps (hold to repeat), presets, change in green / orange, slide; `actionChangeAlt`. Not during mission / return / landing (`showChangeAlt`) |
| `SimpleTopBar.qml` | ui/TopBar | Menu, flight status, flight mode, 4 chips, messages |
| `SimplePreflightSheet.qml` | S02 | Plain-language pre-flight check |
| `SimpleTakeoffSheet.qml` | S03 | Height presets + slide to take off |
| `SimpleConfirmSheet.qml` | S33 | Return home / Land / Start mission with slide to confirm |
| `SimpleModeSheet.qml` | S28 | Position hold / Altitude hold only |
| `SimpleChipDetail.qml` | S14, S25–S27 | Chip details |
| `SimpleMessages.qml` | S29 | Message history |
| `SimpleCameraRail.qml` | ui/CameraRail | Photo/video, shutter, gimbal angle |
| `SimpleMenuDrawer.qml` | S06 | Menu |
| `SimplePayloadSettings.qml` | S52–S55 | Settings › Payloads: list and pages for YellowScan (`corePlugin.ysManager`), tether SAFE-T (`corePlugin.elistairStationManager`: TCP / UDP, IP, port, auto-connect, test; Advanced mode also frame version and ground-power action), camera & gimbal (`PayloadManager`, `videoSettings.rtspUrl`, FC mount parameters) |
| `SimpleSettings.qml` | S09, S22, S45, S46, S47, S48 | Settings with 7 categories. Map & flight zones (S46): map style from `mapEngineManager.mapTypeList`, offline map list (`tileSets`) with cancel / resume / delete. Remote ID (S47): QGC `RemoteIDManager` + `remoteIDSettings`; Save turns Remote ID on; EU operator number checked with the secret part, only 16 characters saved. Connection (S22): Enpulse radio through `CustomQmlInterface.arManager` (band change sets air then ground unit and restarts both, on the ground only; Restart radio = ground unit), RTK through the alesQGC NTRIP client (`CustomQmlInterface.codevRTCMManager`, setting `rtcmSource`) |
| `SimpleMapDownload.qml` | S46 | Download new area: map with a frame, name, detail (zoom 17/19), size estimate, tile limit; `mapEngineManager.updateForCurrentView` + `startDownload` |
| `SimplePlanWizard.qml` | S07, S08 | Choose task, area mapping settings |
| `SimpleWaypointEditor.qml` | S23 | Waypoint flight on the PlanView map: take-off → points → return home (RTL). Map tap with "Add point" on adds a point before the return (`PlanView.simpleMapClicked`), Undo, point panel (height, speed, wait = param1 "Hold", action = `cameraSection.cameraAction`, yaw when the firmware uses it), height labels, height profile with the ground (`terrainAltitude`). The point controls are rebuilt for each selected point (the S* controls break their bindings when edited) |
| `SimpleScanSettings.qml` | S40 / S41 / S42 | Corridor mapping, structure scan and LiDAR survey on the PlanView map: take-off → scan item → return home (RTL), created by `SimplePlanWizard` (`_createScan`). Corridor: map tap adds a line point; height, width, overlap. Structure: outline presets (rectangle 30 × 20 m, circle r 12 m, draw = taps), distance (warning under 10 m), bottom / top height (≤ max altitude), layers (calculated), camera 0° / −15°. LiDAR (card only with YellowScan on): survey with the YellowScan camera + Init Path before / after (follows the survey, flown path drawn in orange), height / speed / line overlap; line spacing from `yellowScanCalculate()`. The scan item is made current so the classic map shows its drag handles |
| `SimpleSavedMissions.qml`, `SimpleMissionInfo.js` | S24 | Saved missions (Menu › Saved missions, S07 card): .plan files in the mission save path (FolderListModel, newest first, search), summaries cached in the app settings (`SimpleMissions`), preview of the selected file in its own PlanMasterController (map + summary), Open (wizard routes to the S08 / S23 editor or the S39 check), Rename (save as + delete), Export (file dialog), Delete (slide), Import (.plan; .kml/.kmz area → area mapping). Save from the editor header. `SimpleMissionInfo.js`: mission kind, summary, outline |
| `SimplePlanCheck.qml` | S39 | Check before sending, send progress |
| `SimpleRadioCal.qml` | S81 | Stick calibration sheet (3 steps; the app records centre / min / max from RC_CHANNELS and writes RCn_MIN / MAX / TRIM for channels that moved). S82 channel reverse is in `SimpleSetupRadio.qml` |
| `SimpleEscCal.qml` | S83 | ESC calibration (ESC_CALIBRATION = 3, battery cycle steps). Lives in the Vehicle setup root so it outlives the Power page while the drone is unplugged |
| `SimplePrearmChecks.qml` | S84 | ARMING_CHECK bitmask (names from the parameter documentation), "no checks" needs a red confirm, security log |
| `SimpleSetupFirmware.qml` | S68 | Firmware from a file on the PC (classic FirmwareUpgradeController: board search → replug → flash). Signature / no-downgrade checks shown as "not checked yet" until the company signs firmware |
| `SimpleFirmwareController.qml` | S68 | PC only: wraps `FirmwareUpgradeController`, which exists only in desktop builds. Loaded by `SimpleSetupFirmware` with `Loader.setSource()` so the Simple UI still compiles on Android (a desktop-only type named in any other Simple file stops the whole Simple UI from loading; `static_checks.py` checks this) |
| `SimpleParamFile.qml` | S87 | Parameters: save to file (name) and load from file (FolderListModel + buildDiffFromFile / sendDiff) |
| `SimpleInspectorChart.qml` | S88 | MAVLink Inspector chart: 2 fields, 10 / 30 / 60 s, QML Canvas (no QtCharts) |
| `SimpleLogCategories.qml` | S89 | App log categories: common groups + all categories (QGroundControl.setCategoryLoggingOn) |
| `SimpleFolderPicker.qml` | S90 | Save folder picker (desktop): drives, path bar, folders, new folder; helpers in `PrivacyData` (drives, folderInfo, makeFolder) |
| `SimpleMissionResult.qml` | S91 / S92 | Mission result card after landing (replaces the classic "Flight Plan complete" popup): flight time, distance, photos, battery; Remove from drone, Keep, Continue from waypoint N (actionResumeMission) |
| `SimpleReference.qml` | S60, S84 | Singleton: company reference parameters (`docs/REF_45_SC_AQ3F_reference.param`, AQUILA-3F) for every drone; per-unit values (calibration, RC ranges, IDs, statistics) are not compared; ARMING_CHECK helpers |
| `SimpleManualLinks.qml` | S93 / S94 | Settings › Connection, Advanced mode: saved serial / UDP / TCP links (LinkManager), Connect / Disconnect / Edit, add / edit sheet |
| `SimpleGamepad.qml` | S95 | Settings › Devices › USB gamepad: use for this drone, live axes and buttons, button actions, throttle mode, calibration sheet (JoystickConfigController) |
| `SimpleSetupMission.qml` | S97 | Vehicle setup › Mission: MIS_OPTIONS clear on restart / continue after landing (APMMissionComponentController); only when the firmware has MIS_OPTIONS |
| `SimpleSetupGimbal.qml` | S77 / S101 | Vehicle setup › Gimbal: MNT1_TYPE, tilt / roll / pan ranges, servo gimbal outputs (SERVOn_FUNCTION 7/8/6, PWM min / max, reverse), start-up mode, control channels (RCx_OPTION 213/214) |
| `SSheet.qml`, `SNotice.qml` | S67 / S81–S90 | Shared centred modal sheet (scrolls when taller than the window) and notice box |
| `SimpleTheme.qml` | Variables "AQGC Simple" | Colors, sizes, `px()` / `fs()` scaling from 1920×1080 |
| `S*.qml` | 99 Components | Buttons, chips, segmented, combo box, stepper, toggle, text field, slide confirm, panel, banner |

## Fonts and translations

- Fonts (`fonts/`, in `custom.qrc` under `/simple/fonts/`): Roboto Regular / Medium / Bold (v2.138, Apache 2.0),
  Noto Sans KR and Noto Sans JP Regular / Medium / Bold (v2.004, OFL 1.1). Noto Sans KR is subset to Latin,
  punctuation, Hangul syllables and jamo (no Hanja except 日本語 for the language list), ≈ 2 MB per weight.
  Noto Sans JP is subset to kana, CJK punctuation, the JIS level-1 kanji and every character of
  `qgc_simple_ja_JP.ts` (≈ 1.1 MB per weight; `custom/tools/i18n/subset_noto_jp.py`, run it again when the Japanese
  text gains a rarer kanji — `static_checks.py` reports missing glyphs). Licence files are next to the fonts.
  Roboto covers every character of Vietnamese, German, Danish and Portuguese.
- All Simple UI text uses `SText` → `SimpleTheme.fontFamily` ("Roboto"). Latin letters and digits stay Roboto;
  Hangul falls back to Noto Sans KR and kana / kanji to Noto Sans JP (`QFont::insertSubstitutions` in
  `QGCApplication::setLanguage()`, order KR → JP, set once for every language: changing the list at runtime made
  Android draw earlier text with glyphs of the other font, kanji shown as Hangul). 한국어 and 日本語 in the language
  list are always drawn by the bundled fonts (日本語 by the KR subset). Roboto Medium may register as its own family "Roboto Medium" (Windows);
  `SimpleTheme.fontFamilyMedium` handles that.
- Long translations: `SText.fitMin` (< 1) lets a label with a fixed width shrink to fit, down to that share of its
  size (0.8 in action buttons and segmented controls), then elide. Wrapped text is not shrunk.
- Translations: `translations/qgc_simple_<locale>.ts` for ko_KR, vi_VN, de_DE, da_DK, pt_BR, ja_JP (contexts = QML
  file names). They are built by the existing `TRANSLATIONS += translations/qgc_*.ts` + `embed_translations` rule and
  loaded by locale name. They also hold the Simple-only strings in core files (`FlyView`: Map / Camera,
  `FlightZoneManager` C++ texts). After changing text run
  `python custom/tools/i18n/sync_ts.py <Qt>/bin/lupdate.exe translations/qgc_simple_*.ts` (adds new messages, removes
  stale ones, keeps the core contexts and the file format), fill what Figma has with
  `custom/tools/i18n/fill_from_figma.py custom/i18n/figma_strings.json <ts> <vi|de|da|pt|ja>`, translate the rest
  (terms: `custom/i18n/glossary.json`) and run `custom/tests/simple/static_checks.py`.
- Language list (`SLanguageCombo.qml`, S57 and Settings › General): only the languages above plus System; names in
  their own language. A new language needs its `.ts`, an entry there and, if missing, in `qLocaleLanguage`
  (`src/Settings/App.SettingsGroup.json`, QLocale::Language values).
- Still English in every language: ArduPilot mode names in Advanced mode lists (as the firmware reports them),
  FactMetaData enum / parameter texts shown in Simple rows, C++ messages outside `FlightZoneManager`, vehicle and
  QGC status texts (e.g. pre-arm reasons the app does not map), QGC voice announcements (core
  translations only). The megaphone speech language (S56, marked *) stays English / Korean until the device
  accepts more. Numbers, dates and times use one
  format for all languages (2.1 km, 2026-10-28, 24-hour), as in Figma.
- Licence notices: Settings › About & support › Legal & licenses (S48) lists all third-party software (24 items:
  QGroundControl, Qt third-party parts, GStreamer/GLib, OpenSSL, SDL2, fonts, …) from `licenses/index.json`, with
  full texts. Windows installs the same files in `<install dir>\licenses`. How to regenerate: `licenses/README.md`.

## Tests

`custom/tests/simple/` — static checks (translations, resources, fonts, Korean label widths) and Qt Quick unit tests
(theme, PIN, vehicle state rules, controls). See its README.

## Run with a mock vehicle (debug build)

```
AlesQGroundControl --simple-mock                 # mock ArduCopter vehicle
AlesQGroundControl --simple-mock --fake-mobile   # same, full screen like a tablet
```

starts an ArduCopter MockLink so every screen can be checked without a drone. Notes:

- Add files to `custom/custom.qrc` (prefix `/simple`) when you add QML or icons here.
- The mock vehicle cannot switch to Guided/Auto, so take off and start mission end with
  "Vehicle failed to change mode". The commands are sent correctly; test flight states on SITL or a drone.
- The first start shows the Simple welcome (S57). To see it again, delete `simpleWelcomeShown` from the settings file.
- Units need an app restart for data that already exists (QGC behaviour). The Simple UI hides the classic
  "requires restart" popup and shows a plain hint instead.

## v1 scope and what is left for v2

In v1: fly screen with state rules, map tap menu / Go here / change altitude (S35, S36, S38; 2026-11-16), pre-flight check, take-off / start mission / return home / land / pause,
flight mode, chip details, messages, camera rail, menu, admin PIN → Advanced, Settings
(General, Safety, About), Plan (area mapping → check & send).

Planned for v2 (designed in Figma, not implemented):

- Settings: payload cards S56 (with the payload panels); flight zone data ED-269 and My zones (S46 rows, S32)
- Cleaning product profile (S13): no cleaning device support in the app yet
- Advanced menu panel (S44; its "4–8 digits" differs from the 6-digit PIN decision)
- Automatic flight-zone check in S39
- More languages (de, fr, ja: Noto Sans JP) — Korean and bundled fonts are done
