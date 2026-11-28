# Simple UI tests

| Level | What | How to run |
|---|---|---|
| Static (no Qt) | Translations (coverage, placeholders, stale entries), `custom.qrc` / `qmldir` / icons, licence index, font glyph coverage, label widths of every Simple language (ko, vi, de, da, pt-BR, ja; `--widths` lists all grown short labels) measured with the bundled fonts | `python custom/tests/simple/static_checks.py` (needs `pip install fonttools`) |
| Unit (Qt Quick Test) | `SimpleTheme` (px/fs, unit system), `SimpleVehicleState` (state rules, boundaries), S35/S38 (`SimpleMapTapMenu` Go here rules, `SimpleCoordSheet`, `SimpleAltitudeSheet` steps and limits), S10 (`SimplePayloadPanel` cards, `SHoldButton`), S24 (`SimpleMissionInfo.js`, incl. random / damaged / 5000-item missions), S40-S42 settings panel (`tst_scansettings.qml`), controls (stepper, slide-to-confirm, segmented, toggle, button, setting row). Each has basic, boundary, abnormal, random and stress cases | see below |

Unit tests use test doubles in `mock/` for the `QGroundControl` QML modules and a small runner (`main.cpp`) that sets
the `globals` context property like `MainRootWindow` does.

```
# Qt 5.15.2 MSVC, from a path WITHOUT spaces (nmake/jom inference rules break on spaces)
mkdir build && cd build
qmake <repo>/custom/tests/simple/simple_tests.pro CONFIG+=release
jom
release\tst_simple.exe -import <repo>/custom/tests/simple/mock -input <repo>/custom/tests/simple
```

Notes
- `TestCase` is invisible, so components that receive mouse input are created under the visible root `Item`.
- Drag the slide-to-confirm with coordinates of the track (`sl`), not of the knob: `mouseDrag` re-maps item
  coordinates after each move, so dragging a moving item travels about twice the distance.

App scenarios (2026-11-16, scripts in `C:\Users\jsh06\aqgc-build`: `scen.ps1`, `gen_plans.py`, `memprobe.ps1`, `monkey.ps1`, `mdump.py`, `roitest.py`)
- Light user: one mission of each kind made, saved and opened through the UI.
- Heavy user: 89 saved missions (copies, Korean and 120-character names), search, open / back of 5 kinds x 12 cycles
  with memory per cycle (`memprobe.ps1 <name> <cycles> open`).
- Abnormal files: empty, random bytes, truncated JSON, wrong JSON, unknown complex item, Init Path only, 3000 waypoints.
- Random: `monkey.ps1 <name> 400 <seed> [plan]` (taps, drags, Back; "plan" re-enters a random Plan task every 40 actions).
- SITL flights (company firmware): corridor, structure scan and LiDAR survey sent from the Simple check and flown to
  landing; `mdump.py` prints the mission on the vehicle, `roitest.py` which ROI commands the firmware accepts.
