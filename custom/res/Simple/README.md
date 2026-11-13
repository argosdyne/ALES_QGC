# AQGC Simple UI (v1)

Simple, map-first UI for general users of alesQGC. It is the default UI; the classic alesQGC UI is
shown in **Advanced mode**, unlocked with the admin PIN.

- Design: Figma **AQGC-simpler** — `01 Screens` (S01–S56), `02 Flows` (navigation map, task flows,
  state rules, layer rules), `00 Overview` §8 (design rules).
- Meeting deck: `AGD-PRS-ALQGC-100_AQGC-UI-단순화-검토회의` (D08).

## How it is wired

| Place | Change |
|---|---|
| `src/ui/MainRootWindow.qml` | `simpleUI = !corePlugin.showAdvancedUI`. Loads `qrc:/simple/SimpleRoot.qml` on top of the views when `simpleUI`; hides the classic toolbar; shows a "Lock and return to Simple" button in Advanced mode. |
| `src/FlightDisplay/FlyView.qml` | `simpleMode` property hides the classic fly widgets. Map, video and PiP stay. In Simple mode the PiP follows Figma S04: bottom-right (right 24, bottom 24), 400 × 226 (scaled from 1920 × 1080), rounded corners. The FPV overlay starts between the telemetry bar and the PiP. Layout: telemetry bar bottom-left (x 24), PiP bottom-right. |
| `src/QmlControls/PipView.qml` | `simpleStyle`: frame, "Camera" / "Map" label, tap to swap only (no resize, pop-out or hide buttons). |
| `src/PlanView/PlanView.qml` | `simpleMode` property hides the tool strip, right panel, terrain status and map scale. Map and mission visuals stay, so the survey polygon is edited on the classic map. |
| `custom/src/Custom.SettingsGroup.json` | New settings: `simpleAdminPin` (default `000000`), `simpleLargeText`, `simpleStartScreen`, `simpleProductProfile` (not used yet). |
| `custom/src/CustomPlugin.cc` | `guidedMaximumAltitude` default = 120 m (decision 2026-11-13). |
| `custom/custom.qrc` | Prefix `/simple`: all files in this folder and `icons/` (exported from Figma). |
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
| `SimpleRoot.qml` | — | Pages (fly / plan / settings), menu, PIN, navigation functions |
| `SimpleVehicleState.qml` | 02 Flows › C | One place for vehicle state used by all state rules |
| `SimpleFlyOverlay.qml` | S01–S05, S33, S34, S37 | Top bar, left actions by state, camera rail, telemetry, banners, sheets |
| `SimpleTopBar.qml` | ui/TopBar | Menu, flight status, flight mode, 4 chips, messages |
| `SimplePreflightSheet.qml` | S02 | Plain-language pre-flight check |
| `SimpleTakeoffSheet.qml` | S03 | Height presets + slide to take off |
| `SimpleConfirmSheet.qml` | S33 | Return home / Land / Start mission with slide to confirm |
| `SimpleModeSheet.qml` | S28 | Position hold / Altitude hold only |
| `SimpleChipDetail.qml` | S14, S25–S27 | Chip details |
| `SimpleMessages.qml` | S29 | Message history |
| `SimpleCameraRail.qml` | ui/CameraRail | Photo/video, shutter, gimbal angle |
| `SimpleMenuDrawer.qml` | S06 | Menu |
| `SimplePinDialog.qml` | S12 | Admin PIN, 5 wrong tries = 5 min lock |
| `SimpleSettings.qml` | S09, S45, S48 | Settings with 7 categories |
| `SimplePlanWizard.qml` | S07, S08 | Choose task, area mapping settings |
| `SimplePlanCheck.qml` | S39 | Check before sending, send progress |
| `SimpleTheme.qml` | Variables "AQGC Simple" | Colors, sizes, `px()` / `fs()` scaling from 1920×1080 |
| `S*.qml` | 99 Components | Buttons, chips, segmented, stepper, toggle, slide confirm, panel, banner |

## Run with a mock vehicle (debug build)

```
AlesQGroundControl --simple-mock                 # mock ArduCopter vehicle
AlesQGroundControl --simple-mock --fake-mobile   # same, full screen like a tablet
```

starts an ArduCopter MockLink so every screen can be checked without a drone. Notes:

- Add files to `custom/custom.qrc` (prefix `/simple`) when you add QML or icons here.
- The mock vehicle cannot switch to Guided/Auto, so take off and start mission end with
  "Vehicle failed to change mode". The commands are sent correctly; test flight states on SITL or a drone.
- The first start shows the classic "Measurement Units" and "Vehicle Information" first-run dialogs.

## v1 scope and what is left for v2

In v1: fly screen with state rules, pre-flight check, take-off / start mission / return home / land / pause,
flight mode, chip details, messages, camera rail, menu, admin PIN → Advanced, Settings
(General, Safety, About), Plan (area mapping → check & send).

Planned for v2 (designed in Figma, not implemented):

- Plan: waypoint, corridor, structure, LiDAR survey; saved missions (S23, S24, S40–S42)
- Settings: Map & flight zones, Connection, Payloads, Remote ID (S22, S46, S47, S52–S56)
- Payloads panel and devices (S10, S11, S13, S16, S17), camera settings sheet (S43)
- Map tap menu / Go here, change altitude, obstacle stop (S35, S36, S38)
- Video main view and waiting state (S18, S49), tether power lost, LiDAR start rejected (S50, S51)
- Advanced menu panel (S44) and change admin PIN; store the PIN hashed
- Bundled fonts (Roboto, Noto Sans KR), Korean strings, automatic flight-zone check in S39
