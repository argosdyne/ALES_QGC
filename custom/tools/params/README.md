# ArduPilot parameter documentation (Advanced mode)

alesQGC shows a name, description, units and range for each drone parameter in Advanced mode. That text comes from
one XML file generated from the **ARGOSDYNE ArduCopter firmware** (decision 2026-11-15, licence option B):

| | |
|---|---|
| Bundled file | `custom/res/ParameterMetaData/APMParameterFactMetaData.Copter.xml` |
| Resource path | `:/FirmwarePlugin/APM/APMParameterFactMetaData.Copter.ARGOSDYNE.xml` (`custom/custom.qrc`) |
| Generated from | firmware **Z01.07.00EASA** (ArduPilot 4.5.1), 4,467 parameters, 2026-11-15 |
| Generator | ArduPilot `Tools/autotest/param_metadata/param_parse.py --vehicle ArduCopter --format xml` |
| Used by | `APMFirmwarePlugin::_internalParameterMetaDataFile()` for every Copter firmware version |
| Licence | GNU GPL v3 (generated from ArduPilot source); listed in Settings › About › Legal & licenses and in `<install dir>\licenses` |

The 23 files of the `ArduPilot-Parameter-Repository` submodule (Copter / Plane / Rover / Sub, up to 4.2) are no longer
compiled into the app. Plane, Rover and Sub vehicles get no bundled documentation: their parameters still show with
names and values.

## Regenerate after a firmware release

```bash
# in WSL / Linux
custom/tools/params/generate.sh ~/APM4.5 "/mnt/c/Users/<you>/.../ales_qgc"
```

Then update the firmware version in `custom/tools/licenses/mklic.py` (item "ArduPilot parameter documentation"),
re-run the licence generator (see `custom/res/Simple/licenses/README.md`) and update the table above.
