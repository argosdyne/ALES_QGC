# CLAUDE.md — AQGC Simple UI (work in progress)

Context for Claude Code sessions that continue the **AQGC Simple UI** work on this repository.
Reply to the user in Korean unless they write in English.

## Where things are

| What | Where |
|---|---|
| Branch | `feature/aqgc-simple-v1` (from `Argos_Stable4.4` 4c5330c6). Push here; never push to `Argos_Stable4.4`. |
| Pull request | Draft PR #311 → `Argos_Stable4.4`. **Do not merge.** v2 is done by Claude first, then developers take over. |
| Simple UI code | `custom/res/Simple/` — read `custom/res/Simple/README.md` first (wiring, files, mock run, v2 list) |
| Design (source of truth) | Figma file **AQGC-simpler**, key `p7d3GuBZaJNSj8zpBUlaSj`. Pages: `00 Overview` (§8 design rules), `01 Screens` (S01–S90 + UX notes), `02 Flows` (navigation, task flows, state rules), `03 Proto` (layout comparisons), `99 Components` |
| Review deck | `AGD-PRS-ALQGC-100_AQGC-UI-단순화-검토회의` (D08), not in this repo |
| Status doc | claude.ai project "개발 문서 및 User Manual 작성" → `claude/aqgc-simple-ui-v1-status.md` |

## Working rules

1. **Figma first, then code.** If a screen or layout changes, update Figma (`01 Screens`, UX notes, `00 Overview` §8)
   and keep code and Figma consistent. When Figma text and screens disagree, ask the user.
2. Keep Simple UI code in `custom/res/Simple/`. Changes to core QGC files stay small and are guarded by
   `simpleMode` / `mainWindow.simpleUI`, so Advanced mode (classic alesQGC) behaves as before.
   Exception (user 2026-11-17): fixes of real bugs in core QGC code (e.g. the mission-load leak, ArduPilot structure-scan
   ROI, Init Path loading) may apply to both modes, unguarded. Keep them small, in their own commit, and say so.
3. New QML or icon files must be added to `custom/custom.qrc` (prefix `/simple`) **and** `custom/res/Simple/qmldir`.
4. Do not duplicate flight logic: call `GuidedActionsController.executeAction()`, `PlanMasterController`,
   and FC parameters via `FactPanelController`.
5. Sizes come from Figma at 1920 × 1080: use `SimpleTheme.px()` / `fs()`; colours from `SimpleTheme`.
6. Commit in small, topic-named commits (`Simple UI: …`, `CI(Android): …`). Keep CI fixes separate from UI commits.
7. After pushing, check CI (Windows Release, Android 32/64-bit Release) with `gh` and update the PR #311 description.

## Decisions so far (do not change without asking)

- **Changed 2026-11-16 (user): no PIN for Advanced mode.** The Advanced mode switch in the menu turns it on at once;
  "Return to Simple" in the S44 panel turns it off. The last state (Simple or Advanced) is kept when the app
  restarts (user 2026-11-16; the old rule returned to Simple on restart). Done 2026-11-17: the PIN dialog, hashing and
  Change PIN row are removed; the mode is the setting `simpleAdvancedMode` (CustomPlugin restores it at start and saves
  every change; the old `simpleAdmin*` values are deleted once). The text below is the old rule (history only).
  S44 done 2026-11-17 (31d3022d0): Advanced mode = Simple screens + S44 panel (menu switch on → panel next to the menu).
  `corePlugin.advancedMode` (C++ CustomPlugin, saved as simpleAdvancedMode) is the mode; `showAdvancedUI` now only
  means "classic screens shown" (S44 › Classic or an item whose new screen does not exist yet; not restored at start;
  every core guard that checks showAdvancedUI keeps meaning "Simple screens hidden"). Items open classic pages via
  `simpleRoot.openClassic(setup|parameters|analyze|settings|fly)`; classic pages have "Close classic screens" in the
  tool header (the tool Drawer covers normal items, even with a high z). Product profile is chosen inside S44.
  Analyze tools S61–S63 done 2026-11-17 (`SimpleAnalyze.qml`, root page "analyze", Loader: controllers only while
  open). Gotchas: compare LogDownloadController status texts with qsTranslate("LogDownloadController", …) (the app
  shows them translated); the MAVLink Inspector fills field values only for `activeSystem.selected`, so select by
  setting it; the App log (debugMessageModel) records only enabled log categories (all off by default). Inspector
  charts stay in the classic inspector for now (QtCharts). Developer tools switch = setting simpleDeveloperTools.
  Parameters S60 done 2026-11-17 (`SimpleParameters.qml`, root page "params"). The bundled ArduPilot parameter
  documentation has no default values, so "Changed from default" is hidden (the classic "modified only" is empty too);
  it needs defaults (e.g. ArduPilot MAVFTP param download with defaults) — ask before adding. ParameterEditorController
  splits groups into Standard / Advanced: groups are merged by name in QML; `QmlObjectListModel.get()` of a category's
  groups returned the category itself at the last index (skip items without `facts`). A page root must not declare
  `property var vs` and be created with `vs: vs` (binding loop).
  Vehicle setup S58 / S59 done 2026-11-17 (`SimpleVehicleSetup.qml`, root page "setup"). APMSensorsComponentController
  needs items it drives: statusLog with append(), progressBar.value, nextButton / cancelButton `enabled`,
  orientationCalAreaHelpText.text. Every calibration end re-enables the buttons first (setAllCalButtonsEnabled(true));
  success = calibrationComplete (level / barometer end with "success, show log" and keep progress 0). Cancel works
  only for the compass (classic too). A failed accelerometer calibration clears the SITL accel offsets (pre-arm
  fails): restart SITL (`sitl.sh run` wipes with -w). Other categories open their classic page via
  `simpleRoot.openClassic("setup:<ComponentQml>")` → MainRootWindow.showSetupComponent().
  S70–S77 done 2026-11-17 (`SimpleSetup*.qml`, shared `SFactField.qml`). Gotchas: the app translates ArduPilot enum
  strings (flight modes show "원형"), so plain / ArduPilot names are looked up by mode number; a motor test makes
  ArduPilot report armed for the spin, so Motors is locked only while flying (not on armed) and "test all" ignores
  that short armed state. Still classic: pre-arm checks, ESC calibration, stick calibration / reversing, motor
  interference, orientation, firmware. ArduPilot has no cell-count parameter (Figma S73 "Cells" not shown).
  Tuning changes go to the security log (PrivacyData.logEvent).
  Settings ADVANCED MODE categories done 2026-11-17 (`SimpleAdvancedSettings.qml`): Video, Devices (S69) as drawn;
  Fly screen, Plan, Data & logs follow the S64 UX note (not drawn in Figma). Video source values are the English
  strings of VideoSettings ("RTSP Video Stream" …, "Video Stream Disabled"); maxVideoSize is MB (shown in GB).
  Fly S78 / S79 and Plan S80 done 2026-11-17: Advanced badge, More sheet (`SimpleMoreSheet.qml`: arm on the ground,
  emergency stop hold 3 s, change speed, set home, raw messages via GuidedActionsController), six values right of the
  telemetry bar, all flight modes in `SimpleModeSheet.qml` (vehicle.flightModes only; names as the APM plugin reports
  them, e.g. "Altitude Hold", "Position Hold", "Smart RTL"), mission editor `SimpleMissionEditor.qml` (Plan card in
  Advanced mode; PlanView.simpleSetEditingLayer switches the classic mission / fence / rally layer). New items go after
  the selected one, never before the take-off. All Advanced redesign screens (S44, S58–S80) now exist; **user 2026-11-18 (step 8): build new screens for every remaining classic use too (list and S81+ numbers in TASK-advanced-mode-redesign.md "Step 8"), then remove the S44 classic item** (keep the classic code; ask before deleting it).
- Simple UI is the default; Advanced mode = classic UI, admin PIN 6 digits (default `000000`), 5 wrong tries = 5 min lock.
  The try count and lock are kept over restarts (`simpleAdminFailures`, `simpleAdminLockUntil`); a stored PIN that is
  not 6 digits is reset to the default (2026-11-14). Since 2026-11-16 the PIN is stored as a PBKDF2-SHA256 hash
  (`custom/src/SimplePinHash.h`, salted, 10000 rounds, canonical form only); a plain PIN is hashed on start, so an
  older build that finds the hash resets the PIN to 000000 (tell testers before they install an older beta). Change PIN: Advanced › Settings › General (current → new → again, 000000 refused).
- Fly screen layout (2026-11-13): **left = flight** (action buttons x 28; telemetry bar x 24, bottom 24),
  **right = camera** (camera rail → Payloads; video PiP bottom-right 400 × 226, tap to swap map/video).
  Map controls (S30) sit left of the PiP; compass/attitude in video-main (S18/S49) sit right of the telemetry bar.
- Settings › Safety (2026-11-14): failsafe actions in plain words; no-protection values in orange; battery level from the drone.
- First start (2026-11-14, S57): one welcome screen (language + Metric/Imperial); classic QGC first-run prompts are
  not shown. Planning vehicle without a drone = **ArduPilot multicopter**. Company drones run ArduPilot.
- Settings › Connection (2026-11-15, S22): Enpulse band change only on the ground (motors off), after a confirm: air unit band,
  ground unit band, restart air then ground. "Restart radio" restarts the ground unit only. RTK switch = keep NTRIP logged in
  (client retries every 5 s); the badge shows the GPS fix type only (no accuracy value in the app).
- Settings › Remote ID (2026-11-15, S47): regions EU and US only (Korea hidden until its format is supported); the EU operator
  number is typed in full with the 3 secret characters, checked, and only the public 16 are saved; emergency is a manual switch.
  Save turns Remote ID on (`remoteIDSettings.enable`); while on, a missing or not-ready module blocks take-off (S02).
  "Turn off Remote ID" (not in Figma) is the way back for places or drones without Remote ID.
- Settings › Map & flight zones (2026-11-15, S46): map style and offline maps done. "Download new area" uses the visible map
  inside a frame (not a drawn rectangle) and the existing QGC download; the companion "<name> Elevation" set is hidden and
  deleted with its map. Flight zone data (ED-269) and My zones (S32) are not in the Simple UI yet (the classic GeoAwareness `FlightZoneManager` reads GeoJSON from a
  file or Altitude Angel) and are a separate task (scope decided 2026-11-15, see "Flight zones" below).
- Settings › Payloads (2026-11-15, S52–S55): YellowScan, camera & gimbal, tether station on existing managers. LiDAR camera
  values are read-only (companion board lacks Set Parameter); tether no-power action is shown, changed only in Advanced;
  gimbal tilt limits write FC mount parameters on the ground; gimbal speed is the app setting `simpleGimbalSpeed`.
  S56 cards (megaphone, searchlight, winch, cleaning) come with the fly-screen payload panels.
- Map controls (2026-11-15, S30): button column left of the PiP (Layers, Drone, Me, zoom); scale bar top left under the menu
  (x 180, y 130). Layers: map style, flight trail (`SimpleShowFlightTrail`), keep drone in view, offline map status.
  The "Flight zones" switch appears with the flight zone work.
- Flight zones (2026-11-15, user: do it before Plan): full scope = zones on the Simple map + Layers switch, Settings S46
  data management, in-flight warnings (Simple banner, not the classic GeoAwareness popup) and checks in S02 / plan check,
  and My zones (S32). Data: GeoJSON file import and Altitude Angel online (license key). Build on the existing
  `FlightZoneManager` (custom/src/MissionManager) and GeoZone tools; Figma first.
  Done 2026-11-15: a prohibited zone or a "do not enter" My zone blocks take-off (S02) and plan sending (S39);
  authorisation / warn-only zones are a caution. My zones are stored in `<GeoZone>/MyZones` (the `Custom` folder is
  auto-deleted after 24 h). "Do not enter" zones go to the ArduPilot fence as exclusion polygons; if the fence was off
  only the polygon fence is turned on (FENCE_TYPE = 4), because FENCE_TYPE 7 also enables the circle/altitude fences.
  Test zones near the SITL home: `custom/tests/simple/zones/`.
- ArduPilot parameter documentation (2026-11-15, licence option B): only one file, generated from the company firmware
  (Z01.07.00EASA) with ArduPilot param_parse.py, is bundled for all Copter versions; the ArduPilot-Parameter-Repository
  files are no longer compiled in (Plane/Rover/Sub: no documentation). Listed as GPLv3 in the notices. Regenerate with
  `custom/tools/params/generate.sh` after a firmware release.
- Map tap menu / Go here / change altitude (2026-11-16, S35/S36/S38): with a drone connected a map tap opens the S35 menu;
  zones under the tap are one row with Details → S15 (without a drone a tap still opens S15). Go here sends the classic
  `actionGoto` with the classic GoTo editor data, so progress, arrival and termination stay in FlyViewMap. Refused in red
  inside or across a prohibited / no-entry zone, outside the geofence or beyond `maxGoToLocationDistance`. Ground height
  at the tap is not shown (no terrain query in the app). S38 opens from ALTITUDE only when the classic `showChangeAlt`
  allows it (not during mission / return / landing; user kept this 2026-11-16, no "apply to the rest of the mission").
  The Go here sheet warns that the height is above home, not the ground (user 2026-11-16). SITL: Go here height is above home; flying west of the SITL home
  towards rising ground (Inwangsan) ran into the terrain.
- Payloads panel (2026-11-16, S10/S16/S17/S50/S51): button under the camera rail; cards only for what the drone accepts
  today (megaphone = clip 1–11 play/stop, searchlight on/off, winch = gripper hook / hold-2-s release, life jacket drop,
  tether, YellowScan). Volume, brightness and winch lower/raise are not in the app (no commands). Tether power-off in
  flight and no-power Land / To station use Simple slide sheets: the classic confirm dialog sits in the hidden widget layer.
- Settings › Payloads S56 (2026-11-16, user: "Figma as is, kept in the app"): megaphone, searchlight, winch, cleaning pages;
  values in `SimplePayloadPrefs` (marked * when no device command exists yet). Used today: winch hold time, ground test
  release (motors off), stop clip / searchlight off on landing. "Use" switches = enableAudioController / lifeJacketEnable.
- Camera settings S43 (2026-11-16): "Camera" button at the bottom of the camera rail; sheet in the Payloads panel place.
  MAVLink camera only; auto photos = time lapse 2 s / 5 s (no distance shooting in the camera protocol); no photo-count estimate.
- Tether profile S11 (2026-11-16): product profile "Tether" (combo in Advanced › General; with "Change PIN" the only Simple rows in a core settings page) + SAFE-T
  station on. The station reports no maximum cable length and no tension value: cable = out / station length alarm
  (`stationSettings.lengthAlarm`), tension = SAFE-T alarm state. Ground power must be on to take off (S16). No voice yet.
- Waypoint flight S23 (2026-11-16): take-off → points → RTL; map taps reach the wizard through `PlanView.simpleMapClicked`
  (Simple mode only). ArduPilot ignores waypoint yaw (WP_YAW_BEHAVIOR), so "Drone faces" stays hidden. Known: the first map
  tap after the app's first visit to Plan is lost (map start-up); later taps are fine. S* steppers / segmented controls
  break their binding when edited — rebuild them (Loader) when the edited object changes.
- Saved missions S24 (2026-11-16): files = .plan in the mission save path (on this PC a OneDrive folder). Summaries are
  cached in app settings (`SimpleMissions`), the preview loads only the selected file into its own PlanMasterController.
  Rename = save as + delete. KML/KMZ import: areas only (lines with corridor mapping). Import / Export use the classic
  file dialog (not UI-tested here: the Windows dialog cannot be driven by ui.ps1).
- Corridor S40 / structure S41 (2026-11-16): take-off → scan → RTL; settings panel `SimpleScanSettings.qml` (other options
  in Advanced › Plan). Structure presets rectangle / circle / draw (taps); an opened file keeps its outline (no preset).
  The YellowScan "Init Path" item also has a corridor line (it has `turnRadius`): it is never a corridor kind. A QGeoCoordinate
  property read in QML is a live reference: copy it (`QtPositioning.coordinate(lat, lon)`) before changing its source.
- LiDAR S42 (2026-11-16): take-off → Init Path → YellowScan survey → Init Path → land. Point density is not shown (no
  scanner data); line spacing instead. The classic YellowScan choice saves the camera as "Manual" and keeps YellowScan in a
  global setting (`CameraCalc.isYSLidar` = last choice, not per survey): a file is LiDAR only by its Init Path items.
  Every transect item (survey, corridor, Init Path) has `surveyAreaPolygon`; only a survey has `gridAngle`.
  Core fix (MissionController load): an Init Path (saved as type "CorridorScan") is loaded as Init Path again, not as a corridor.
- Verification 2026-11-16 (heavy / light / abnormal / random / SITL):
  Company firmware accepts DO_SET_ROI (201) but refuses ROI_LOCATION (195), ROI_NONE (197) and ROI_WPNEXT_OFFSET (196):
  structure scans for ArduPilot use one DO_SET_ROI per layer at the structure centre and DO_SET_ROI 0,0,0 to end it
  (core StructureScanComplexItem, both modes). The Simple check shows a refused upload (MissionController
  sendToVehicleFinished). The classic "Flight Plan complete" popup is not shown in Simple mode (plan stays on the
  vehicle); a Simple mission-complete screen is not designed yet. Saved-missions preview: one controller reused
  (a new one per selection leaked ~7 MB), files over 500 items or damaged files are not loaded. Opening a
  3000-waypoint mission still takes ~3 GB (classic visuals). Corridor default 2 x 110 m (inside a 300 m fence).
  Mission load leak fixed (2026-11-16): loading a plan or a vehicle mission deleted only the old list, not its items
  (parent = master controller): ~1.5 MB per load. Now deleteListAndContents (core MissionController, both modes).
  The YellowScan Init Path visual threw a TypeError on every load (createObject without a component): removed.
  After the fix: 120 opens +~0.4 MB each, QObject count unchanged (17087) over the run, so the rest is caches
  (map tiles etc.), not objects.
  sitl.py pos: the GCS heartbeat (system 255) is forwarded on TCP 5762, filter by the vehicle system id.
- MAVLink 2 signing (2026-11-17, core `src/comm/MAVLinkSigning` + `custom/src/LinkSecurity`, Simple S66/S22/S27):
  company firmware on SITL accepts an unsigned SETUP_SIGNING only while it has no key (any port; it then applies to
  all links); changing or removing a key needs SETUP_SIGNING signed with the old key; unsigned commands are then
  ignored on the TCP ports. The SITL signing clock falls behind real time (155-290 s seen): the library receive
  check drops a new stream more than 60 s old, so our receive path checks only the key (signature hash) and drops
  unsigned / wrong-key packets itself once protected (accept_unsigned_callback always true). Library gotchas: it
  checks a signature only when the callback refuses the packet; packing does not fill msg.ck (the parser does);
  outgoing timestamps only grow by 1 per packet unless updated (we follow the wall clock). Pairing only over a
  serial (USB) link or TCP to 127.0.0.1 (SITL); a UDP link is refused (keys never over the radio). For SITL tests
  set `[LinkManager] autoConnectUDP=false` or the UDP link becomes primary. pymavlink scripts (aqgc-build folder):
  signtest.py, keyswap.py, inject.py, otherkey.py, whichkey.py.
  CE RED items 1-2 done 2026-11-17: no built-in NTRIP caster account (the provider password must be changed; it is in
  git history), no credential logging; secrets go to `src/Utilities/SecureStore` (Windows DPAPI, base64 in QSettings
  group SecureStore; Android = plain, TODO Keystore). Doodle Labs radio: TLS verification on with a trust-on-first-use
  certificate pin (`doodlePin/<ip>`; a changed certificate is refused, S66 red), own password (S66 Change, ground only,
  min 8, ubus rpc-sys password_set) kept in SecureStore `doodle/<ip>`, factory password as fallback; not tested on a radio.
  Settings facts named passwd / otaPassword / onlineLicenseKey / mapboxToken / esriToken / vworldToken live in
  SecureStore ("<group>/<name>", SettingsFact; NTRIP group = "RTCM"), moved from the ini at start. Facts are created
  lazily (the NTRIP source only while RTK is on): test with values in the ini, not only through the UI.
  Altitude Angel key (user 2026-11-17, option B(a)): not in the repo. Only tag builds (`v*`, `simple_ui_*`) carry it:
  CI runs `custom/tools/aakey/gen_aa_key.ps1` (env AQGC_AA_KEY from the secret ALTITUDE_ANGEL_KEY) → `aqgc_aa_key.h` in
  the build dir (XOR-masked) → custom.pri defines AQGC_HAS_AA_KEY. `FlyViewSettings::altitudeAngelKey()` = own key, else
  built-in; no key = no request. PR / branch / local builds have no key (enter one in S46, or set AQGC_AA_KEY and run the
  script into the build dir before qmake). `simple_ui_*` tags are Daily builds with no GitHub Release; `v*` stay Stable.
  The old key is in git history: the user revokes it at Altitude Angel. S65 support period / security contact: "not set"
  (user 2026-11-17) until the company gives the values.
  S65 / S67 done 2026-11-17 (`SimpleSecurityPrivacy.qml`, `custom/src/PrivacyData`, core `src/Utilities/SecurityLog`):
  data sizes (logs = Telemetry + Logs + CrashLogs, media = Video + Photo, missions = .plan count), map cache = default
  tile set (deleting it clears all cached tiles incl. saved areas), accounts = SecureStore names (+ link key); delete runs
  in a worker thread and keeps the folders; "accounts" keeps radio certificate pins; "App settings" =
  deleteAllSettingsNextBoot (restart). Windows signature = WinVerifyTrust (local and CI builds are unsigned → orange).
  Location sharing = followTarget (on = 2, Follow Me only), default now 0 in both modes. UI tests of S67 must use a
  scratch `savePath` (the real one is the user's OneDrive folder) and must not tick Map cache (shared real cache).
  S68 Firmware = FC (ArduCopter) firmware over USB from the PC. User 2026-11-17: the company will sign firmware
  (ArduPilot secure boot) but not now → no signature check yet; S68 is built with Vehicle setup and shows the check as
  not available; add it (company public key, signed .apj) when the firmware team signs releases.
  S69 defaults done (f5ef125a8): RTK base (USB) and Zero-Conf auto-connect off by default. Open ports today: drone link
  UDP 14550/14520/14530 (14530 = NextVision LTE), M2 radio discovery UDP 10010 (closes when found). S69 screen comes
  with the Advanced Settings categories (S64).
  Take-off check (SITL, not signing): "Take off 10 m" climbed to ~29 m; to look at (APM plugin uses
  max(selected, PILOT_TKOFF_ALT or 10 m)).
- QML: a child with vertical anchors (e.g. `MouseArea { anchors.fill: parent }`) inside a Column disables the Column
  (warning only in the app log) — wrap such a column in an Item. Check the app log for `qrc:/simple/` warnings after a build.
- Battery warning (2026-11-15): in flight at 30 % or less a banner is shown (red at 20 % or less if not yet returning).
- Link lost (2026-11-15, 02 Flows D): critical (forced back to the fly screen) only in flight (last known state armed or
  flying). On the ground Plan / Settings stay open, the status chip turns red. An unsent Simple plan is not replaced by an
  empty vehicle mission on a ground re-read (MissionController, Simple mode only; Advanced still has the bug-fix-9516 rule).
- Fonts (2026-11-14): Roboto + Noto Sans KR are bundled and registered in both modes (classic UI does not use Roboto).
  Licence notices: Settings › About › Legal & licenses and `<install dir>\licenses` (Windows installer),
  generated by `custom/tools/licenses/` (see `custom/res/Simple/licenses/README.md`).
- Qt is used under the **Qt Commercial License** (2026-11-14): QGC is used under Apache 2.0; list only Qt's third-party parts.
- Advanced mode redesign (2026-11-15): the classic screens (fly, plan, settings) will be redesigned in the Simple UI
  design system (layouts, not only colours/fonts). Start **after** the Settings v2 screens; Figma design first.
  Until then Advanced mode stays the classic UI.
  2026-11-16 (user): option A = one app, the same screen frames; Advanced mode adds items to the Simple UI (Figma 02 Flows
  "E. 고급 모드 구성"). Figma drafts S58–S64: Vehicle setup summary / sensors, Parameters, Analyze tools (Log download,
  Vibration; MAVLink Inspector and App log only behind a "Developer tools" switch), Settings gets 5 Advanced categories
  (Fly screen, Video, Plan, Data & logs, Devices). Not carried over: MAVLink Console (no ArduPilot shell), GeoTag Images
  (PX4 logs only), brand image, Palette Test / Mock Link / Debug (debug builds only). The classic screens stay reachable as
  "Classic alesQGC screens" until every screen is redesigned. User reviewed S58–S69 and asked for the rest
  (2026-11-16): S70–S77 Vehicle setup (Frame, Radio, Flight modes, Power, Motors, Safety all failsafes, Tuning, Gimbal),
  S78 fly screen in Advanced mode ("Advanced" badge, More sheet: Arm on the ground, Emergency stop hold 3 s, Change speed,
  Set home here, raw messages; 6 extra values left of the PiP), S79 all flight modes (plain name + ArduPilot name in
  Advanced only), S80 mission editor (Mission / Fence / Rally tabs; only commands the company firmware accepts).
  Tuning in flight is allowed (user 2026-11-16: pilots tune while flying): S76 shows an orange "In flight: each change is
  sent at once" banner, small steps only, and "Undo changes in this flight" (back to the values at arming). All other
  Vehicle setup categories stay locked while armed.
- Cybersecurity, CE RED 3.3(d)(e) / EN 18031 (2026-11-16, user: put it in Figma so AQGC can apply it). Figma S65 Security &
  privacy (data on this device, Delete my data S67, location sharing off, signed app, security updates period, report a
  security issue, security log), S66 Link security (MAVLink signing, radio password, radio encryption, RTSP / NTRIP /
  Altitude Angel status), S68 Firmware (signed files only, no downgrade), S69 Devices (open services, default off),
  entry points S22 card, S27 "Link protection" row, S48 "Security, privacy & legal". Rules: 00 Overview §10.
  Found in the code (fix with this work, do not copy the values anywhere):
  hard-coded NTRIP caster account in `custom/src/RTCM/NTRIPRTCMSource.cpp` (`get_caster_xml`); Doodle Labs radio login with the
  factory account and TLS peer verification off in `custom/src/ARLink/ARManager.cpp`; NTRIP user/password and API keys
  stored in plain QSettings and NTRIP sent over plain TCP with Basic auth; no MAVLink 2 signing in this QGC
  (ArduPilot supports it via SETUP_SIGNING). No "skip password" option anywhere (EN 18031 restriction). Values on the
  S65 mock (support period, security contact) are examples: the company must set them.
- Tests (2026-11-15): flight-state and memory tests run on ArduPilot SITL — company firmware Z01.07.00EASA
  (`~/APM4.5/build/sitl/bin/arducopter` in WSL Ubuntu-22.04; do not build or edit that tree). MockLink only for quick UI checks.
- `guidedMaximumAltitude` default 120 m. "EasyGripper" is the smart-controller name, not a payload (use "Winch").

## Build and run

- CI builds Windows (installer) and Android (APK, Qt 5.15.2, NDK r21e, GStreamer 1.22.12, SDK android-30) on every push.
  Artifacts are on the Actions run page of the PR.
- Local debug run with a mock ArduCopter (debug build only):
  `AlesQGroundControl --simple-mock --fake-mobile` (`--fake-mobile` = full screen like a tablet).
- MockLink cannot switch to Guided/Auto: take off / start mission end with "Vehicle failed to change mode".
  Flight states need SITL or a real drone.

## Gotchas learned

- `FactPanelController` is in `import QGroundControl.FactSystem 1.0`. Create it only after
  `vehicle.parameterManager.parametersReady` (use a `Loader`), or it binds to the offline vehicle.
- Units need an app restart in QGC. `SimpleTheme.applyUnitSystem()` suppresses the classic "requires restart" popup
  (`_setIgnoreQGCRebootRequired`) and the Simple screens show a plain hint instead.
- The PiP view is anchored under `PipView`, so rounded corners are an `OpacityMask` on `mapControl` / `videoControl` in `FlyView.qml`.
- Android CI on the Windows runner: Git's `sh.exe` must be off PATH before qmake; build with `ENABLE_VERBOSE_OUTPUT`
  (qmake `silent` breaks under cmd); Gradle 5.6.4 needs Java 11; androiddeployqt needs a pinned SDK platform.

- Windows release: the VC runtime DLLs must not be older than the compiler (MSVC 14.40+ code crashes in std::mutex with an
  older msvcp140.dll). Post-link copies them from `VCToolsRedistDir`; the installer installs them next to the exe.
- Bing tiles: imagery is requested with en-US (ko-KR returns empty tiles from zoom 16); road tiles use the dynamic endpoint.
- Performance (2026-11-16): in Simple mode the hidden classic mission editor list (PlanView) and GeoZoneMakeView
  (MainRootWindow, Loader built on first Advanced use) are not created. Start-up is ~7.5 s; the rest is framework
  start-up (C++ init, QML load, ~3 s before the first frame) and needs a native profiler (WPR, admin) to go further.
  Beta tags: `simple_ui_v1_2026111501` = 23d510eff (before these two commits); `simple_ui_v1_2026111601` = 3bc7e150a (with them, CI APK / installer).
  Team release (2026-11-17): `simple_ui_v1_2026111701` = 6c9f22a11, files + Korean release notes in
  `AQGC_Simple/builds/simple_ui_v1_2026111701/` (no GitHub Release: the repo is public; user shares the files).
- Local build/test environment: `C:\Users\jsh06\aqgc-build` (Qt 5.15.2 via aqtinstall, jom, `build_rel.bat`, `tests.bat`,
  `test1.bat <file>`, `ui.ps1` UI driver incl. `hold`, `sitl.sh` + `sitl.py`, `payloadtest.ps1`, settings backup).
  Keep nothing durable in `%TEMP%\claude\...`: it was wiped twice on 2026-11-16. The repo is built through `subst Q:`
  (recreate after a reboot). The app connects to SITL over TCP 5763 (a new exe path gets no inbound UDP 14550 through the
  firewall). In .bat files quote `-o "file,txt"` (cmd splits arguments at commas).
- Qt 5.15 QML: an inline `component X:` with a `default property alias` inside an SPanel-based file overflowed the stack
  on creation (0xC00000FD). Put such components in their own .qml file (`SPayloadCard.qml`).
- `vehicle.hasGripper` is CONSTANT but reads GRIP_ENABLE: bind it together with `paramsReady`, or it stays false.
- After changing `CustomPlugin.h` (members), delete `QGCToolbox.obj` in the build dir before a local build: the toolbox
  creates the plugin through `#include CUSTOMHEADER` (a macro), which qmake's dependency scan does not follow, so the
  old object keeps the old class size → heap corruption at start (0xC0000374). CI builds are clean, not affected.
- The NTRIP source writes the caster table to `rtk_data.xml` in the working directory (git-ignored).
- Local build on Windows: nmake/jom rules break when the source path has spaces ("code review") — build from a path
  without spaces (e.g. a directory junction). Tests: `custom/tests/simple/README.md`.

## Next steps (agreed order)

1. Verify v1 on a real device (user is testing the CI APK / installer) and SITL: flying, paused, returning, landing,
   link lost, low battery. Fix what the user reports.
2. v2: ~~Korean strings + bundled fonts~~ (done 2026-11-14: `translations/qgc_simple_ko_KR.ts`, `custom/res/Simple/fonts/`;
   check Korean label overflow on the device) → remaining Settings categories (~~Connection S22~~, ~~Remote ID S47~~, ~~Map & offline maps S46~~, ~~Payloads S52–S55~~ done 2026-11-15;
   S56 with the payload panels) → fly screen (~~video main S18/S49~~, ~~map controls S30~~,
   ~~map tap menu S35/S36/S38~~ (2026-11-16), ~~payload panel S10/S16/S17/S50/S51~~ (2026-11-16),
   ~~S56 cards~~, ~~S43 camera settings~~ (2026-11-16); ~~tether profile S11~~ (2026-11-16); S13 cleaning waits for device support) → ~~flight zones~~ (done 2026-11-15) → Plan (~~waypoint S23~~, ~~saved missions S24~~, ~~corridor S40 / structure S41 / LiDAR S42~~ 2026-11-16) →
   ~~change admin PIN and store it hashed~~ (2026-11-16) → Advanced mode redesign in the Simple design system (Figma first).
3. **Confirmed 2026-11-17 (user: "인계 문서대로 모두"): do both hand-off tasks, including the changes to the classic
   Advanced UI (PIN removal + state kept, S44 / S58–S80 redesign) — an agreed exception to rule 2.**
   **Next code task (user 2026-11-16): MAVLink 2 signing (done 2026-11-17) + CE RED security fixes** — read
   `custom/docs/TASK-security-mavlink-signing.md` (design, hook points, SITL checks, tests). Also remove the Advanced PIN.
   Then the **Advanced mode redesign** (Figma S44, S58–S80): read `custom/docs/TASK-advanced-mode-redesign.md`
   (screen list with node ids, classic controllers to reuse, order, tests).
4. Open items: the signed Android release path (push to `Argos_Stable4.4` with keystore secret) is untested (the user
   checks the keystore). No Google Play upload (2026-11-16), so target SDK android-30 stays. `ci/android-diagnose` deleted.
