# Simple UI tests

| Level | What | How to run |
|---|---|---|
| Static (no Qt) | Translations (coverage, placeholders, stale entries), `custom.qrc` / `qmldir` / icons, licence index, font glyph coverage, Korean label widths measured with the bundled fonts | `python custom/tests/simple/static_checks.py` (needs `pip install fonttools`) |
| Unit (Qt Quick Test) | `SimpleTheme` (px/fs, unit system), `SimplePinDialog` (PIN, 5-try lock), `SimpleVehicleState` (state rules, boundaries), controls (stepper, slide-to-confirm, segmented, toggle, button, setting row). Each has basic, boundary, abnormal, random and stress cases | see below |

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
- `XFAIL` cases document known risks (a stored PIN that is not six digits cannot be entered).
