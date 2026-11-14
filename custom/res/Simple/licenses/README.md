# Third-party notices

Shown in Settings › About & support › Legal & licenses (Figma S48) from `qrc:/simple/licenses/` (list:
`index.json`), and installed on Windows in `<install dir>\licenses` (`QGCPostLinkCommon.pri` copies `*.txt`).
`THIRD-PARTY-NOTICES.txt` is all texts in one file (installer only, not in qrc).

Generated — do not edit the texts by hand. To regenerate (Python 3, internet):

```
cd custom/tools/licenses
./fetch.sh lic                      # licence texts of the bundled libraries
python qtattr.py lic                # Qt 5.15.2 qt_attribution.json of the shipped Qt modules -> lic/qt_attr.json
python mklic.py lic ../../..        # writes custom/res/Simple/licenses/
```

Then add new files to `custom/custom.qrc` (prefix `/simple`, alias `licenses/<file>`).
When a library, the Qt version or the GStreamer version changes, update the scripts first.
Qt is used under the Qt Commercial License (decision 2026-11-14); only its third-party parts are listed.
Before a release, have the list reviewed (legal / product owner).
