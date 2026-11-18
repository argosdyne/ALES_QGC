# Task: Advanced mode in the Simple design system (Figma S44, S58–S80)

Hand-off note for a Claude Code session (written 2026-11-16 by the claude.ai session that drew the Figma screens).
Read `CLAUDE.md` first. Reply to the user in Korean. **Figma is the source of truth**; if this note and Figma disagree,
ask the user. Each screen in Figma has a Korean UX note right under it (implementation details, parameter names).

## Decisions (user, 2026-11-16; confirmed again 2026-11-17: "인계 문서대로 모두" — this redesign replaces the classic
## Advanced UI step by step, an agreed exception to CLAUDE.md rule 2)

- **Option A**: one app, the same screen frames as the Simple UI. Advanced mode *adds* items to the Simple screens;
  there is no second app layout. Map of what goes where: Figma page `02 Flows`, frame "E. 고급 모드 구성" (node `115:2`).
- **No PIN.** The menu switch "Advanced mode" (S06) turns it on at once and opens the Advanced panel (S44);
  "Return to Simple" turns it off. **The last state is kept over app restarts.** Remove the S12 PIN dialog, the
  PIN hashing (`custom/src/SimplePinHash.h` use) and the Change PIN row; keep the settings keys only if needed to migrate.
  Everything to remove (checked against the code 2026-11-17): `custom/res/Simple/SimplePinDialog.qml`,
  `SimplePinPopup.qml` and their `custom.qrc` / `qmldir` entries; the PIN dialog use in `SimpleRoot.qml`;
  `custom/src/SimplePinHash.h` (+ `custom.pri`) and the `simplePinHash/Check/IsHash` invokables in `CustomPlugin.h`;
  the "Simple UI admin PIN · Change PIN" row and its Loader in `src/ui/preferences/GeneralSettings.qml`;
  settings `simpleAdminPin`, `simpleAdminFailures`, `simpleAdminLockUntil` (`Custom.SettingsGroup.json` /
  `CustomSettings`) — delete the stored values once; tests `tst_pin.qml`, the `simplePin` helper in
  `custom/tests/simple/main.cpp`, the mock functions and `QT += network` in `simple_tests.pro`; Korean strings
  (`SimplePinDialog`, `GeneralSettings` PIN rows) in `translations/qgc_simple_ko_KR.ts`.
- Analysis tools: Log download and Vibration always; **MAVLink Inspector and App log only behind a "Developer tools"
  switch** (default off). **Not carried over**: MAVLink Console (ArduPilot has no shell), GeoTag Images (reads PX4 logs
  only), brand image, Palette Test / Mock Link / Debug (debug builds only), Taisync / Microhard / M2Link.
- **Tuning may change in flight** (S76): orange banner, small steps, "Undo changes in this flight". Every other
  Vehicle setup category is locked while armed (Summary stays readable).
- The classic screens stay reachable as **"Classic alesQGC screens (temporary)"** in the S44 panel until every screen
  here is built. Do not remove the classic code.

## Status

- 2026-11-17: step 1 (no PIN, kept over restarts) and step 2 (S44 panel, 31d3022d0) done. Items open the classic pages
  until their new screen exists. S69 security defaults done (f5ef125a8); S68 signature check waits for signed firmware.
- 2026-11-17: step 3 Analyze tools S61 / S62 / S63 done (6305b7191 core progress, 1ad4c6983), tested on SITL.
  Open in S63: charts (classic inspector for now).
- 2026-11-17: step 4 Parameters S60 done (f441a0420), tested on SITL. Open: "Changed from default" needs defaults (none
  in the bundled ArduPilot documentation); Load from file = classic page.
- 2026-11-17: step 5 started: S58 Summary + S59 Sensors done (SITL). Motor interference / orientation and all other
  categories open their classic page for now.
- 2026-11-17: S70–S77 done (09c422e27), SITL-tested. Step 5 complete except the classic pieces listed in CLAUDE.md.
- 2026-11-17: step 6 done: Settings ADVANCED MODE categories (S64 Video, S69 Devices, Fly screen, Plan, Data & logs).
- 2026-11-17: step 7 done: S78 / S79 (f0d729d68), S80 mission editor (1916d3a58), SITL-tested.
  Step 8 (remove "Classic alesQGC screens"): not done — ask the user. Still classic: pre-arm checks, ESC / stick
  calibration, channel reverse, motor interference, orientation, firmware, inspector charts, load parameters / log
  categories / save folder pickers.

## Screens (Figma file `p7d3GuBZaJNSj8zpBUlaSj`, page `01 Screens`)

Link format: `https://www.figma.com/design/p7d3GuBZaJNSj8zpBUlaSj/AQGC-simpler?node-id=<id with - instead of :>`

| Screen | Node | Content | Reuse (classic code) |
|---|---|---|---|
| S44 Menu · Advanced panel | `36:34086` | Vehicle setup, Parameters, Analyze tools, More settings, Product profile, Classic screens, Return to Simple | existing Simple menu (`SimpleMenuDrawer.qml`) |
| S58 Vehicle setup · Summary | `111:38761` | status cards per category (Done / Needs setup / Optional / PC only) | `vehicle.autopilot.vehicleComponents` (`setupComplete`, summary QML) |
| S59 Sensors | `112:38882` | compass, accel, level, baro, CompassMot, orientation; calibration step sheet | `APMSensorsComponentController` |
| S70 Frame | `127:39455` | 6 frame cards, Apply and restart | `APMAirframeComponentController` |
| S71 Radio | `127:39657` | 8 channel bars, Calibrate sticks | `RadioComponentController` |
| S72 Flight modes | `127:39840` | 6 switch positions, plain name + ArduPilot name | `APMFlightModesComponentController` |
| S73 Power | `127:40027` | monitor, capacity, cells, voltage/current calibration, ESC calibration | `APMPowerComponent.qml` facts (BATT_*) |
| S74 Motors | `128:39706` | Quad X diagram, order A→D clockwise from front right, "Propellers removed" gate | `vehicle.motorTest(motor, percent, timeoutSecs, showError)` |
| S75 Safety (all failsafes) | `128:39889` | battery 2 levels, RC, GCS, EKF, fence, pre-arm, crash check | `APMSafetyComponentCopter.qml` facts |
| S76 Tuning | `128:40107` | response sliders, hover throttle, AutoTune; in-flight banner + undo | `APMTuningComponentCopter.qml` facts |
| S77 Gimbal | `128:40314` | gimbal type, tilt/pan channels, tilt range, stabilise | `APMCameraComponent.qml` facts (MNT1_*) |
| S68 Firmware | `119:39511` | signed files only, no downgrade (see security task) | `FirmwareUpgradeController` (desktop) |
| S60 Parameters | `112:39099` | groups + "Changed from default", search, edit panel, More menu | `ParameterEditorController` |
| S61 Log download | `113:38985` | list, download selected, progress, erase all | `LogDownloadController` |
| S62 Vibration | `113:39141` | X/Y/Z cards with 30/60 lines, clipping | `vehicle.vibration` facts (classic `VibrationPage.qml`) |
| S63 MAVLink Inspector | `113:39273` | behind Developer tools; App log item | `MAVLinkInspectorController`, `AppMessages` |
| S64 Settings · Video | `114:39051` | Settings gets 5 "ADVANCED MODE" categories: Fly screen, Video, Plan, Data & logs, Devices | `SettingsManager`: flyViewSettings, videoSettings, planViewSettings, appSettings, autoConnectSettings, rtkSettings, adsbVehicleManagerSettings |
| S69 Devices | `118:39489` | open network services, defaults off | autoConnect / RTK / ADSB / `forwardMavlink` settings |
| S78 Fly · Advanced | `129:39962` | "Advanced" badge, More sheet (Arm on ground, Emergency stop hold 3 s, Change speed, Set home here, raw messages), 6 extra values left of the PiP | `GuidedActionsController.executeAction()` (arm, emergency stop, change speed, set home) |
| S79 Flight modes · all | `129:40949` | all modes grouped; warning icon on Stabilize / Acro | `vehicle.flightModes`, `vehicle.flightMode` |
| S80 Plan · Mission editor | `129:41964` | Mission / Fence / Rally tabs, item list, item editor | `PlanMasterController` (mission, geofence, rally controllers), classic `MissionItemEditor` logic |

Rules for all screens: 00 Overview §8 (sizes, touch targets, colours) and §10 (security). Category frame = Settings
(S09): header 104 px, left list 520 px, content x 580, width 1300.

## Suggested order (small commits, `Simple UI: …`)

1. **No PIN + state kept** (S06/S44/S12): smallest change, unblocks testing. Update the Simple tests that check the PIN.
2. **S44 panel** wired to existing classic pages first (each item may open the classic page until its new screen exists).
3. **Analyze tools** S61, S62, S63 (controllers exist, mostly UI).
4. **Parameters** S60.
5. **Vehicle setup** S58 → S59, S72, S75, S73, S71, S77, S76, S70, S74 (calibrations last; they need SITL and care).
6. **Settings advanced categories** S64 + S69.
7. **Fly** S78, S79, then **Plan** S80.
8. When all are done, ask the user before removing "Classic alesQGC screens".

Per screen: build → check against the Figma frame (screenshot at 1920 × 1080 and 1280 × 720) → SITL where it talks to
the FC → update CLAUDE.md (decision/gotcha) → push → CI → PR #311 description.

## Step 8 (user 2026-11-18): replace the remaining classic screens, then remove "Classic alesQGC screens"

Figma done 2026-11-18 (`01 Screens`, each with a UX note under it): S81 `158:42563`, S82 `158:42738`, S83 `158:42905`,
S84 `158:43058`, S85 `159:42807`, S86 `159:42963`, S87 `159:43117`, S88 `160:43006`, S89 `160:43161`, S90 `160:43332`.
S59 CompassMot subtitle fixed (propellers on and flipped, not off). Then code, one small commit each. Places that still
open a classic page (checked against the code 2026-11-18):

| # | Where (code) | Classic use today | New screen |
|---|---|---|---|
| 1 | S44 "More settings" (`SimpleMenuDrawer.qml`) | classic Settings tool | open Simple Settings at the ADVANCED MODE categories (S64, no new frame) |
| 2 | Radio S71 (`SimpleSetupRadio.qml`) | stick calibration, channel reverse | S81 Stick calibration (step sheet), S82 Channel reverse (in S71) |
| 3 | Power S73 (`SimpleSetupPower.qml`) | ESC calibration | S83 ESC calibration (step sheet) |
| 4 | Safety S75 (`SimpleSetupSafety.qml`) | pre-arm checks (ARMING_CHECK) | S84 Pre-arm checks (bitmask list) |
| 5 | Sensors S59 (`SimpleVehicleSetup.qml`) | CompassMot, orientation | S85 Motor interference (CompassMot), S86 Orientation |
| 6 | Firmware S68 (`SimpleVehicleSetup.qml`) | classic firmware page | S68 (already in Figma, `119:39511`) |
| 7 | Parameters S60 More (`SimpleParameters.qml`) | load from file | S87 Load / save parameter file (file list + diff) |
| 8 | Analyze S63 (`SimpleAnalyze.qml`) | inspector charts, log categories | S88 Inspector chart, S89 Log categories |
| 9 | Data & logs S64 (`SimpleAdvancedSettings.qml`) | save folder | S90 Folder picker |
| 10 | S44 "Classic alesQGC screens" | whole classic UI | remove the item when 1–9 are done (keep the classic code; ask before deleting code) |

**Status 2026-11-18: items 1–10 done** (S68 too). Tested on SITL: S81 (with rcsweep.py), S82, S83 start / cancel, S84,
S85 (live values; SITL throttle stays 0), S86, S87 save / load / send, S88, S89, S90 navigation, S68 page (no board to
flash), More settings. Not tested: ESC battery cycle and firmware install on hardware.

## Tests

- Simple tests (`custom/tests/simple/README.md`): mode switch without PIN, state after restart, every Advanced entry
  opens its screen, every Vehicle setup category is locked while armed except Summary and Tuning.
- SITL (company firmware Z01.07.00EASA): sensor calibration flows start/cancel, flight-mode slots write FLTMODE1–6,
  parameter edit + "Changed from default", log list/download, motor test refused while armed, emergency stop needs
  the 3 s hold, mission editor upload refused for commands the firmware rejects (see CLAUDE.md verification notes).
- Classic screens still work from "Classic alesQGC screens".

## Related tasks

- `custom/docs/TASK-security-mavlink-signing.md` — MAVLink signing and CE RED fixes (S65–S69, S22/S27 rows). S68 Firmware
  belongs to both; build it with the security task.
- Tuleap: Story ST-02 (#27482) and its Test Cases #27509–27511 still describe the PIN. Tell the user they need updating
  (the claude.ai session registered them).
