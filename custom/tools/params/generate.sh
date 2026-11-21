#!/bin/bash
# Regenerate the ArduPilot parameter documentation bundled with alesQGC from the ARGOSDYNE ArduCopter firmware.
# Run in Linux / WSL. Usage: generate.sh <ardupilot-firmware-source-dir> <alesqgc-repo-dir>
# Example (WSL): custom/tools/params/generate.sh ~/APM4.5 "/mnt/c/.../ales_qgc"
# The firmware tree is only read; the generator writes into a temporary folder.
set -euo pipefail
FW="${1:?firmware source dir}"
REPO="${2:?alesQGC repo dir}"
OUT="$(mktemp -d)"
cd "$OUT"
python3 "$FW/Tools/autotest/param_metadata/param_parse.py" --vehicle ArduCopter --format xml
DEST="$REPO/custom/res/ParameterMetaData/APMParameterFactMetaData.Copter.xml"
cp apm.pdef.xml "$DEST"
VER="$(grep -o 'AQUILA_FIRMWARE_VERSION "[^"]*"' "$FW/ArduCopter/version.h" | cut -d'"' -f2 || true)"
APV="$(grep -o 'FIRMWARE_VERSION [0-9,]*' "$FW/ArduCopter/version.h" | head -1 | awk '{print $2}' | cut -d, -f1-3 | tr , . || true)"
echo "Generated $(grep -c '<param ' "$DEST") parameters from firmware ${VER:-?} (ArduPilot ${APV:-?})"
echo "Update the version in custom/tools/licenses/mklic.py (ArduPilot parameter documentation) and in custom/tools/params/README.md if it changed."
rm -rf "$OUT"
