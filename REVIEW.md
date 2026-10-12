# Review instructions — ALES_QGC (ARGOSDYNE fork of QGroundControl 4.4)

This repository is a ground control station for ARGOSDYNE UAS (AQUILA series, CUNA drone-in-a-box).
Defects can cause loss of aircraft control, so prioritize flight-safety and correctness over style.

## Language

Write every review comment and the review summary in English.

## Scope

- Only PRs whose base branch is `Argos_Stable4.4` are in scope.
  For any PR targeting another branch, post no findings and reply only: "Out of scope: base branch is not Argos_Stable4.4."
- Review only lines changed in this PR. Mark issues in untouched code as Pre-existing, and only if they are severe.

## What Important means here

Reserve Important for findings that could cause one of the following:

- Wrong vehicle behavior: incorrect MAVLink command/param IDs, wrong frame (MAV_FRAME), wrong units
  (deg vs rad, m vs cm, deg*1e7, AMSL vs relative altitude), wrong sign or axis.
- Unsafe state handling: arm/disarm, flight mode changes, RTL/land/failsafe, geofence, rally points,
  mission/plan upload or download that can silently drop, reorder, or corrupt items.
- Loss of link or telemetry handling: blocked UI/main thread, missing timeouts or retries, heartbeat
  handling, vehicle (re)connect logic, crashes on vehicle disconnect.
- Memory and lifetime bugs: dangling pointers, use-after-free, missing QObject parent or deleteLater,
  objects accessed after the owning Vehicle/LinkInterface is destroyed.
- Threading: QObject used across threads without queued connections, data races on shared state,
  blocking calls on the GUI thread.
- Security: credentials, keys, or tokens committed to source; unsafe parsing of external input
  (MAVLink, files, network) without bounds checks.
- Build breakage on any supported target (Windows, Linux, Android) or changes that break release packaging.

Style, naming, formatting, and refactoring suggestions are Nit at most.

## Cap the nits

Report at most five Nits per review. If you found more, write "plus N similar items" in the summary.
If everything you found is a Nit, start the summary with "No blocking issues."

## Do not report

- Formatting or whitespace (clang-format / CI handles this)
- Translation files: `translations/**`, `*.ts`, `*.qm`
- Third-party and vendored code: `libs/**`, git submodules, `src/**/mavlink/**` generated headers
- Binary and generated assets: `resources/**` images, `*.qrc` ordering, `*.svg`, `*.png`, icons
- Build-system noise unrelated to behavior: lockfiles, IDE project files

## Always check

- C++ (Qt 6): Q_PROPERTY has NOTIFY when the value changes at runtime; signals are emitted after
  state is updated; no raw `new` without an owner; `connect` uses the function-pointer syntax.
- QML: no binding loops; no hard-coded pixel sizes where ScreenTools should be used; null-checks on
  `activeVehicle` and other objects that can disappear at runtime.
- Fact / FactMetaData / Settings: new settings have defaults, units, and min/max; JSON metadata matches C++ names.
- MAVLink: message and field usage matches the dialect in use; sequence/ack handling is not broken.
- ARGOSDYNE-specific changes (branding, custom plugins, custom firmware plugins) do not alter upstream
  QGC behavior for other vehicles unless the PR says so.
- New user-facing strings are wrapped in `qsTr()` / `tr()`.

## Summary shape

Start with a one-line verdict, then a short list of Important findings (if any), then a note on test
coverage: say whether the change was flight-tested, SITL-tested, or untested, based on the PR description.
