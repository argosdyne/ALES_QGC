/****************************************************************************
 * AQGC Simple UI — S68 Firmware: the classic FirmwareUpgradeController in its own file.
 * The type is registered only in desktop builds (QGCApplication, #ifndef __mobile__). SimpleSetupFirmware.qml
 * loads this file by URL on the PC only; naming the type inline there makes SimpleRoot fail to load on Android.
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl.Controllers 1.0

FirmwareUpgradeController { }
