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
- Fly screen layout (2026-11-13): **left = flight** (action buttons x 28; telemetry bar x 24, bottom 24),
  **right = camera** (camera rail → Payloads; video PiP bottom-right 400 × 226, tap to swap map/video).
  Map controls (S30) sit left of the PiP; compass/attitude in video-main (S18/S49) sit right of the telemetry bar.
- Settings › Safety (2026-11-14): failsafe actions in plain words; no-protection values in orange; battery level from the drone.
- First start (2026-11-14, S57): one welcome screen (language + Metric/Imperial); classic QGC first-run prompts are
  not shown. Planning vehicle without a drone = **ArduPilot multicopter**. Company drones run ArduPilot.
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

## Next steps (agreed order)

1. Verify v1 on a real device (user is testing the CI APK / installer) and SITL: flying, paused, returning, landing,
   link lost, low battery. Fix what the user reports.
2. v2: Korean strings + bundled fonts (Roboto, Noto Sans KR) → remaining Settings categories (Connection, Payloads,
   Remote ID, Map & flight zones; S22, S46, S47, S52–S56) → fly screen (video main S18/S49, map controls S30,
   map tap menu S35/S36/S38, payload panels) → Plan (waypoint, saved missions, corridor/structure/LiDAR) →
   change admin PIN and store it hashed.
3. Open items: Google Play needs a higher target SDK than android-30 (decision pending); the signed Android release
   path (push to `Argos_Stable4.4` with keystore secret) is untested; remote branch `ci/android-diagnose` can be deleted.
