# CLAUDE.md — AQGC Simple UI (work in progress)

Context for Claude Code sessions that continue the **AQGC Simple UI** work on this repository.
Reply to the user in Korean unless they write in English.

## Where things are

| What | Where |
|---|---|
| Branch | `feature/aqgc-simple-v1` (from `Argos_Stable4.4` 4c5330c6). Push here; never push to `Argos_Stable4.4`. |
| Pull request | Draft PR #311 → `Argos_Stable4.4`. **Do not merge.** v2 is done by Claude first, then developers take over. |
| Simple UI code | `custom/res/Simple/` — read `custom/res/Simple/README.md` first (wiring, files, mock run, v2 list) |
| Design (source of truth) | Figma file **AQGC-simpler**, key `p7d3GuBZaJNSj8zpBUlaSj`. Pages: `00 Overview` (§8 design rules), `01 Screens` (S01–S64 + UX notes), `02 Flows` (navigation, task flows, state rules), `03 Proto` (layout comparisons), `99 Components` |
| Review deck | `AGD-PRS-ALQGC-100_AQGC-UI-단순화-검토회의` (D08), not in this repo |
| Status doc | claude.ai project "개발 문서 및 User Manual 작성" → `claude/aqgc-simple-ui-v1-status.md` |

## Working rules

1. **Figma first, then code.** If a screen or layout changes, update Figma (`01 Screens`, UX notes, `00 Overview` §8)
   and keep code and Figma consistent. When Figma text and screens disagree, ask the user.
2. Keep Simple UI code in `custom/res/Simple/`. Changes to core QGC files stay small and are guarded by
   `simpleMode` / `mainWindow.simpleUI`, so Advanced mode (classic alesQGC) behaves as before.
3. New QML or icon files must be added to `custom/custom.qrc` (prefix `/simple`) **and** `custom/res/Simple/qmldir`.
4. Do not duplicate flight logic: call `GuidedActionsController.executeAction()`, `PlanMasterController`,
   and FC parameters via `FactPanelController`.
5. Sizes come from Figma at 1920 × 1080: use `SimpleTheme.px()` / `fs()`; colours from `SimpleTheme`.
6. Commit in small, topic-named commits (`Simple UI: …`, `CI(Android): …`). Keep CI fixes separate from UI commits.
7. After pushing, check CI (Windows Release, Android 32/64-bit Release) with `gh` and update the PR #311 description.

## Decisions so far (do not change without asking)

- **Changed 2026-11-16 (user): no PIN for Advanced mode.** The Advanced mode switch in the menu turns it on at once;
  "Return to Simple" in the S44 panel turns it off. The last state (Simple or Advanced) is kept when the app
  restarts (user 2026-11-16; the old rule returned to Simple on restart). S12 (PIN) and Change PIN are not used any more; remove the PIN
  dialog, `SimplePinHash.h` use and the Change PIN row when the code follows Figma. The text below is the old rule.
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
  sitl.py pos: the GCS heartbeat (system 255) is forwarded on TCP 5762, filter by the vehicle system id.
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
  "Classic alesQGC screens" until every screen is redesigned. Waiting for the user's review before code.
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
- Local build/test environment: `C:\Users\jsh06\aqgc-build` (Qt 5.15.2 via aqtinstall, jom, `build_rel.bat`, `tests.bat`,
  `test1.bat <file>`, `ui.ps1` UI driver incl. `hold`, `sitl.sh` + `sitl.py`, `payloadtest.ps1`, settings backup).
  Keep nothing durable in `%TEMP%\claude\...`: it was wiped twice on 2026-11-16. The repo is built through `subst Q:`
  (recreate after a reboot). The app connects to SITL over TCP 5763 (a new exe path gets no inbound UDP 14550 through the
  firewall). In .bat files quote `-o "file,txt"` (cmd splits arguments at commas).
- Qt 5.15 QML: an inline `component X:` with a `default property alias` inside an SPanel-based file overflowed the stack
  on creation (0xC00000FD). Put such components in their own .qml file (`SPayloadCard.qml`).
- `vehicle.hasGripper` is CONSTANT but reads GRIP_ENABLE: bind it together with `paramsReady`, or it stays false.
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
3. Open items: the signed Android release path (push to `Argos_Stable4.4` with keystore secret) is untested (the user
   checks the keystore). No Google Play upload (2026-11-16), so target SDK android-30 stays. `ci/android-diagnose` deleted.
