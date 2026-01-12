message("Adding Custom Plugin")

#-- Version control
#   Major and minor versions are defined here (manually)

CUSTOM_QGC_VER_MAJOR = 1
CUSTOM_QGC_VER_MINOR = 0
CUSTOM_QGC_VER_FIRST_BUILD = 1

# Build number is automatic
# Uses the current branch. This way it works on any branch including build-server's PR branches
CUSTOM_QGC_VER_BUILD = $$system(git --git-dir ../.git rev-list $$GIT_BRANCH --first-parent --count)
win32 {
    CUSTOM_QGC_VER_BUILD = $$system("set /a $$CUSTOM_QGC_VER_BUILD - $$CUSTOM_QGC_VER_FIRST_BUILD")
} else {
    CUSTOM_QGC_VER_BUILD = $$system("echo $(($$CUSTOM_QGC_VER_BUILD - $$CUSTOM_QGC_VER_FIRST_BUILD))")
}
# CUSTOM_QGC_VERSION = $${CUSTOM_QGC_VER_MAJOR}.$${CUSTOM_QGC_VER_MINOR}.$${CUSTOM_QGC_VER_BUILD}
CUSTOM_QGC_VERSION = $${CUSTOM_QGC_VER_MAJOR}.$${CUSTOM_QGC_VER_MINOR}.1


DEFINES -= APP_VERSION_STR=\"\\\"$$APP_VERSION_STR\\\"\"
DEFINES += APP_VERSION_STR=\"\\\"$$CUSTOM_QGC_VERSION\\\"\"

message(Custom QGC Version: $${CUSTOM_QGC_VERSION})

# # Build a single flight stack by disabling APM support
#MAVLINK_CONF = ardupilotmega
# CONFIG  += QGC_DISABLE_APM_MAVLINK # THANH: Check
#CONFIG  += QGC_DISABLE_PX4_PLUGIN QGC_DISABLE_PX4_PLUGIN_FACTORY
#CONFIG  += QGC_DISABLE_PX4_PLUGIN_FACTORY

# We implement our own PX4 plugin factory
#CONFIG  += QGC_DISABLE_PX4_PLUGIN

# Branding

DEFINES += CUSTOMHEADER=\"\\\"CustomPlugin.h\\\"\"
DEFINES += CUSTOMCLASS=CustomPlugin

TARGET   = AlesQGroundControl
DEFINES += QGC_APPLICATION_NAME='"\\\"Ales QGC\\\""'

DEFINES += QGC_ORG_NAME=\"\\\"argosdyne.org\\\"\"
DEFINES += QGC_ORG_DOMAIN=\"\\\"org.argosdyne\\\"\"

DEFINES += CUSTOMVEHICLEHEADER=\\\"CustomVehicle.h\\\"
DEFINES += CUSTOMVEHICLECLASS=CustomVehicle

QGC_APP_NAME        = "Ales QGC"
QGC_BINARY_NAME     = "Ales QGC"
QGC_ORG_NAME        = "Agosdyne"
QGC_ORG_DOMAIN      = "org.Agosdyne"
QGC_ANDROID_PACKAGE = "org.Agosdyne.alesqgc"
QGC_APP_DESCRIPTION = "Ales QGroundControl"
QGC_APP_COPYRIGHT   = "Copyright (C) 2023 Ales QGroundControl Development Team. All rights reserved."


WindowsBuild {
QMAKE_CXXFLAGS += /WX-
QMAKE_CXXFLAGS -= /W4
QMAKE_CXXFLAGS += /W3
QMAKE_CXXFLAGS += /std:c++20
QMAKE_CXXFLAGS += /wd5051
QMAKE_CXXFLAGS += /Wv:18
QMAKE_CXXFLAGS += -wd4309
QMAKE_CXXFLAGS += /utf-8
}
# Our own, custom resources
RESOURCES += \
    $$PWD/custom.qrc

QML_IMPORT_PATH += \
   $$PWD/res

# Our own, custom sources
SOURCES += \
    $$PWD/src/CustomPlugin.cc \
    $$PWD/src/RTCM/CodevRTCMManager.cpp \
    $$PWD/src/RTCM/NTRIPRTCMSource.cpp \
    $$PWD/src/RTCM/RTCMBase.cpp \
    $$PWD/src/RTCM/SerialPortRTCMSource.cpp \
    $$PWD/src/SiYi/SiYiCamera.cc \
    $$PWD/src/SiYi/SiYiCrcApi.cc \
    $$PWD/src/SiYi/SiYiManager.cc \
    $$PWD/src/SiYi/SiYiTcpClient.cc \
    $$PWD/src/SiYi/SiYiTransmitter.cc \
    $$PWD/src/codevsettings.cpp \
    $$PWD/src/CustomSettings.cc \
    $$PWD/src/ARLink/ARConnection.cpp \
    $$PWD/src/ARLink/ARManager.cpp \
    $$PWD/src/CustomQmlInterface.cc \
    $$PWD/src/AVIATOR/AVIATORInterface.cpp \
    $$PWD/src/MissionManager/FlightZoneManager.cpp

HEADERS += \
    $$PWD/src/CustomPlugin.h \
    $$PWD/src/RTCM/CodevRTCMManager.h \
    $$PWD/src/RTCM/NTRIPRTCMSource.h \
    $$PWD/src/RTCM/RTCMBase.h \
    $$PWD/src/RTCM/SerialPortRTCMSource.h \
    $$PWD/src/SiYi/SiYiCamera.h \
    $$PWD/src/SiYi/SiYiCrcApi.h \
    $$PWD/src/SiYi/SiYiManager.h \
    $$PWD/src/SiYi/SiYiTcpClient.h \
    $$PWD/src/SiYi/SiYiTransmitter.h \
    $$PWD/src/codevsettings.h \
    $$PWD/src/CustomSettings.h \
    $$PWD/src/lockedqueue.h \
    $$PWD/src/ARLink/ARConnection.h \
    $$PWD/src/ARLink/ARManager.h \
    $$PWD/src/CustomQmlInterface.h \
    $$PWD/src/AVIATOR/AVIATORInterface.h \
    $$PWD/src/MissionManager/FlightZoneManager.h

INCLUDEPATH += \
    $$PWD/src \
    $$PWD/src/SiYi/ \
    $$PWD/src/RTCM/ \
    $$PWD/src/ARLink/ \
    $$PWD/src/AVIATOR/ \
    $$PWD/src/MissionManager \
    $$PWD/src/Rhythm

#-------------------------------------------------------------------------------------
# Custom Firmware/AutoPilot Plugin

INCLUDEPATH += \
    $$PWD/src/FirmwarePlugin \
    $$PWD/src/AutoPilotPlugin \
    $$PWD/src/FirmwarePlugin/APM/

HEADERS += \
    $$PWD/src/FirmwarePlugin/CustomVehicle.h \
    $$PWD/src/FirmwarePlugin/VehicleESCFactGroup.h

SOURCES += \
    $$PWD/src/FirmwarePlugin/CustomVehicle.cc \
    $$PWD/src/FirmwarePlugin/VehicleESCFactGroup.cc

# HEADERS+= \
#     $$PWD/src/AutoPilotPlugin/CustomAutoPilotPlugin.h \
#     $$PWD/src/FirmwarePlugin/CustomFirmwarePlugin.h \
#     $$PWD/src/FirmwarePlugin/CustomFirmwarePluginFactory.h \

# SOURCES += \
#     $$PWD/src/AutoPilotPlugin/CustomAutoPilotPlugin.cc \
#     $$PWD/src/FirmwarePlugin/CustomFirmwarePlugin.cc \
#     $$PWD/src/FirmwarePlugin/CustomFirmwarePluginFactory.cc \


