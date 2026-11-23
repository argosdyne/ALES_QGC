/****************************************************************************
 * AQGC Simple UI — S68 Vehicle setup › Firmware: the install controller (PC only).
 * FirmwareUpgradeController is registered only in desktop builds (QGCApplication.cc, #ifndef __mobile__).
 * A type that is not registered fails the whole file that names it, even inside an inactive Loader, and with it
 * SimpleVehicleSetup and SimpleRoot: on Android the Simple UI did not appear at all (2026-11-23).
 * So the type lives only in this file, which SimpleSetupFirmware loads with Loader.setSource() on desktop.
 * Do not name it as a type in any other Simple file.
 ****************************************************************************/
import QtQuick 2.12
import QGroundControl.Controllers 1.0

FirmwareUpgradeController { }
