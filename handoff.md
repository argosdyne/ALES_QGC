# Handoff — ALES QGC (`new_ui_small_icons_easygripper`)

Last update: 2026-11-10. Read `CLAUDE.md` first (build, tests, architecture, custom qrc rules) and `REVIEW.md` (review rules). This file is the state of the work and what is open.

## State

- Branch `new_ui_small_icons_easygripper`. Last commit 2026-11-04 (`5a0c869b3`), in sync with origin.
- 2026-11-10: Figma sizing of the Fly view and frame 16 committed (see "Figma sizing" below). Not pushed yet.
- Based on `improv_code_quality` (8 commits ahead of `origin/improv_code_quality`). `improv_code_quality` is in PR #298 into `support_multi_langs`.
- **No PR yet.** Target branch not decided (`improv_code_quality` while PR #298 is open, or `support_multi_langs` after it merges).
- Design source: Figma "ALES-QGC UI Base", file key `kPAQqtPjr8OKfuPAhtRMMH`, page node 568-2 (EasyGripper 1920x1080). Fly view frames are in section 572:42531 (01–17, 06b), Plan view frames in 568:1369 (01–13), new components in 568:3. Fonts: skill `argosdyne-ui-fonts`.
- The user's reference screenshot of the wrong UI is `wrong_design.jpg` (untracked, repo root).

## Figma sizing (2026-11-10)

The user asked to apply the whole Figma design (Fly view, popups, Plan view) with the Figma MCP. Phase 1 (main Fly view) and frame 16 are done in the tree.

**Root cause found:** the Figma frames use a 28 px default font with a 124 px toolbar. Desktop QGC made the toolbar 3 font heights, about 20% lower than that with Roboto, so text and widgets looked 1.2–1.8x too big next to a 124 px toolbar. The photo/video panel also still used the upstream sizes (about 2x the design).

Changes:
- `src/QmlControls/ScreenTools.qml`: `figmaPx` (one design pixel = default font pixel size / 28) and `figmaFontPointSize(px)`. Desktop `toolbarHeight` = 124 × `figmaPx` (mobile keeps `minTouchPixels`). The desktop toolbar becomes about 25% taller for the same font (user approved 2026-11-10). To get pixel-exact Figma sizes at 1920x1080 the app font size setting must give a 28 px default font.
- `PhotoVideoControl.qml`, `FlyViewWidgetLayer.qml`: panel 356 px wide, round buttons 56, capture 119, mode pill 190×76, zoom pill 213×71, readout font 28, translucent panel 16 px padding/radius, 4 px from the right edge.
- `ToolStrip.qml` (`designSize` property, set only by `FlyViewToolStrip.qml`): 112 px wide, 100 px buttons, 21 px labels, 6.4 px margins, 4 px spacing, at (12, 58). Plan view tool strips are unchanged until the Plan frames are compared.
- `WarningToast.qml`: all sizes in design px (677 wide, accent 15, icon 53×47, close 63, radius 18); text Roboto **Bold** (regular family + bold, not the Medium family) at **25 px**. The Figma MCP reports 22.5 px, but the instance is the 609 px component scaled ×1.11 and the frames draw 25 px (measured).
- `VehicleWarnings` placement 16 px from the top; `TelemetryValuesBar.qml` padding 12, radius 8 (font stays Large = 42 px, as in Figma); `PipView.qml` default width 345.6 design px.
- Frame 16 (GeoAwareness): the near-GeoZone message marks key phrases with `<b>` (`FlightZoneManager.cpp`, format now "Distance: %1 m"); `FlyViewOverlay.qml` draws `<b>` parts in `warningToastTextStrong` and the rest in `warningToastText` (messages without marks stay all strong). Translations updated in ko, ja, de, da, pt, vi (the non-Korean emphasis spans were chosen by Claude; review them). Status message cards per Figma: 432 wide, icon 51.3, font 25.2, padding 14.4/17.1, 16 px from the top and 64 px from the right; text in `qgcPal.text` (white, Figma token `enabled/text`) instead of the old fixed green `#00DA90`.
- Frame 16 re-checked from scratch (2026-11-10) with the app window at the frame's proportions (client 1239×697 at this PC's 0.645 scale, scaled ×1.55 for comparison): tool strip, map scale, toast, status cards, photo/video panel and telemetry bar match in size and position. Intended differences: the status card icon is the real severity PNG (green "i" for info; the user chose to keep the PNG over the Figma blue circle placeholder "Severity icon (png)"); map zoom +/- buttons are desktop-only by the Figma description; the vehicle icon is the PX4 arrow only because SITL is PX4 (ArduPilot uses the custom vehicle icon).

Verified on this PC (PX4 SITL, software renderer, compared against Figma at the same scale): tool strip, panel, toasts and frame 16 toast match. Unit tests GeoAwarenessAlertTest (13) and UiFontsTest (6) pass. Not verified on screen: the video-stream parts of the panel (mode pill, zoom, storage), PiP, status message cards (SITL sent none).

Next phases (not started): 2) Fly view popups (frames 03, 05, 08–15, 17, 06/06b video main), 3) Plan view frames 01–13.

## Recent work (newest first)

| Commit | What |
|---|---|
| (2026-11-10) | Figma sizing of the main Fly view (design pixel unit, desktop toolbar height, tool strip, photo/video panel, toast, telemetry bar, PiP), frame 16 (GeoAwareness key phrases, status message cards) and this handoff |
| `5a0c869b3` | Font standard: Roboto / Roboto Medium / Roboto Mono for all languages, Noto Sans KR/JP/SC fallback per UI language (loaded only for that language), NanumGothic and Open Sans removed. Layout follows Roboto metrics, so the UI is about 14% smaller (user choice). Font cache cleared on language change. OFL texts copied next to the executable. `UiFontsTest` added |
| `30c4da8d4` | Fly view top center: warning toast, then system messages, then GeoAwareness alerts are stacked instead of overlapping (`custom/res/Custom/FlightDisplay/FlyViewOverlay.qml`) |
| `4d177d938` | SiYi: stop the client thread before changing its IP address |
| `66cf85335` | Flight mode menu made compact per Figma; `QGCButton` no longer reserves icon space when there is no icon (app-wide, user approved) |
| `6cf4459b1` | GeoAwareness alerts stay until closed or the condition clears (no 10 s auto-close) |
| `e92d60c82`, `6e7315206` | Shutdown fixes: map engine destroyed before the application; SiYi client threads stopped before their objects are destroyed |
| `66b0aadf2` | EasyGripper Fly view design from Figma applied (first pass; sizes fixed by the work in progress above) |

## Open items

1. **Push** the 2026-11-10 commits and continue with phase 2 (Fly view popups).
2. **GeoZone map polygon colors** come from the zone data; Figma frame 16 shows a no-fly zone as red 30% fill with a 2.55 px red border. Not changed; ask the user whether to force it.
3. **Roboto Condensed**: measure where labels overflow before deciding whether to use it.
4. **Android**: Roboto Medium weight and the Figma sizing not verified on a device.
5. **Font skill**: the `argosdyne-ui-fonts` table has no zh-CN row (Noto Sans SC is used because the Chinese translation is Simplified; the user chose SC over TC).
6. **G (small popup / toolbar position shifts from Figma)**: not applied, by user choice. Do not apply unless asked again.
7. **PR**: decide the target branch, then open it.

## Build and test on this PC

- Use open-source Qt `D:\QtOSS\5.15.2\msvc2019_64` (the commercial Qt at `D:\QT\5.15.2` fails with "Qt license has expired"), VS2022 `vcvars64`, jom `D:\QT\Tools\QtCreator\bin\jom\jom.exe`.
- The repo path has a space, which breaks MSVC inference rules: build through the junction `D:\aqgc` → repo, shadow build dir `D:\qgcb2` (debug).
- Unit test: `D:\qgcb2\staging\AlesQGroundControl.exe --unittest:<Name> --no-windows-assert-ui` with env `QGC_UNITTEST_OUTPUT_DIR=<dir>`; results go to `<dir>\<Name>.txt`. The full suite aborts at `StructureScanComplexItemTest` (Qt assert), so run tests one at a time.
- A GUI debug build often exits with code 1 about 7 s after start; under `cdb -g -G` it stays up.
- Screenshots: PrintWindow returns a white image with the OpenGL renderer and the app cannot take the foreground. Start the app with `QT_QUICK_BACKEND=software`, then PrintWindow works (icons drawn by shaders are missing). Clicks: PostMessage WM_LBUTTON* to the window.
- This PC's app font setting is 9 pt (`appFontPointSize` in `%APPDATA%\argosdyne.org\Ales QGC Daily.ini`), so the toolbar is 80 px (design scale 0.645). That ini also has a saved `[TelemetryBarUserSettings-2]` group, so the telemetry bar ignores default changes.
- PX4 SITL in WSL Ubuntu-22.04 (`~/px4-v1.14`, sihsim). It sends MAVLink to udp 14550 inside WSL; bridge it to Windows with `setsid nohup socat -T 3600 UDP4-LISTEN:14550,reuseaddr,fork UDP4:<WSL default gateway>:14550 &`. On connect the app opens Vehicle Setup (RC not calibrated); click Back and the setup dialog's Ok. In Git Bash prefix `wsl` commands with `MSYS_NO_PATHCONV=1`.

## Rules to keep

- Edit `custom/*.qrc` by hand; never regenerate them with `updateqrc.py`. A resource added to a root `.qrc` must also go into the custom qrc.
- Before editing an upstream QML file, check whether `custom/` overrides it.
- Figma sizes go in design pixels (`ScreenTools.figmaPx`, `figmaFontPointSize`). Check text sizes against the frame render: scaled instances can report the unscaled font size.
- Commit titles start with `[ALES-QGC]`.
