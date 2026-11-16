# CLAUDE.md — AQGC Simple UI (work in progress)

Context for Claude Code sessions that continue the **AQGC Simple UI** work on this repository.
Reply to the user in Korean unless they write in English.

## Where things are

| What | Where |
|---|---|
| Branch | `feature/aqgc-simple-v1` (from `Argos_Stable4.4` 4c5330c6). Push here; never push to `Argos_Stable4.4`. |
| Pull request | Draft PR #311 → `Argos_Stable4.4`. **Do not merge.** v2 is done by Claude first, then developers take over. |
| Simple UI code | `custom/res/Simple/` — read `custom/res/Simple/README.md` first (wiring, files, mock run, v2 list) |
| Design (source of truth) | Figma file **AQGC-simpler**, key `p7d3GuBZaJNSj8zpBUlaSj`. Pages: `00 Overview` (§8 design rules), `01 Screens` (S01–S57 + UX notes), `02 Flows` (navigation, task flows, state rules), `03 Proto` (layout comparisons), `99 Components` |
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

- Simple UI is the default; Advanced mode = classic UI, admin PIN 6 digits (default `000000`), 5 wrong tries = 5 min lock.
  The try count and lock are kept over restarts (`simpleAdminFailures`, `simpleAdminLockUntil`); a stored PIN that is
  not 6 digits is reset to the default (2026-11-14).
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
  allows it (not during mission / return / landing). SITL: Go here height is above home; flying west of the SITL home
  towards rising ground (Inwangsan) ran into the terrain.
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
- Local tools kept in the session scratchpad (%TEMP%\claude\...) are partly deleted by Windows temp cleanup: after a
  reboot Qt lost its ANGLE DLLs and QML/JS files (QtTest TestCase.qml missing → test runner exits 1 with no output) and
  the GStreamer folder (D:) was gone. Reinstall Qt with aqtinstall over it and recreate `subst Q:` for the repo.
  In .bat files quote `-o "file,txt"` (cmd splits arguments at commas).
- Local build on Windows: nmake/jom rules break when the source path has spaces ("code review") — build from a path
  without spaces (e.g. a directory junction). Tests: `custom/tests/simple/README.md`.

## Next steps (agreed order)

1. Verify v1 on a real device (user is testing the CI APK / installer) and SITL: flying, paused, returning, landing,
   link lost, low battery. Fix what the user reports.
2. v2: ~~Korean strings + bundled fonts~~ (done 2026-11-14: `translations/qgc_simple_ko_KR.ts`, `custom/res/Simple/fonts/`;
   check Korean label overflow on the device) → remaining Settings categories (~~Connection S22~~, ~~Remote ID S47~~, ~~Map & offline maps S46~~, ~~Payloads S52–S55~~ done 2026-11-15;
   S56 with the payload panels) → fly screen (~~video main S18/S49~~, ~~map controls S30~~,
   ~~map tap menu S35/S36/S38~~ (2026-11-16), payload panels) → ~~flight zones~~ (done 2026-11-15) → Plan (waypoint, saved missions, corridor/structure/LiDAR) →
   change admin PIN and store it hashed → Advanced mode redesign in the Simple design system (Figma first).
3. Open items: the signed Android release path (push to `Argos_Stable4.4` with keystore secret) is untested (the user
   checks the keystore). No Google Play upload (2026-11-16), so target SDK android-30 stays. `ci/android-diagnose` deleted.
   S38 "apply to the rest of the mission" (Figma) needs a decision: ArduPilot's altitude change switches to Guided.
