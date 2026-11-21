# Simple UI unit tests (Qt Quick Test). Build with qmake + jom/nmake, then run:
#   tst_simple -import <this dir>/mock -input <this dir>
TEMPLATE = app
TARGET   = tst_simple
CONFIG  += warn_on qmltestcase console
SOURCES += main.cpp
# MAVLink 2 signing helper (core, src/comm/MAVLinkSigning) for tst_signing.qml
REPO = $$PWD/../../..
SOURCES += $$REPO/src/comm/MAVLinkSigning.cc $$REPO/src/Utilities/SecureStore.cc $$REPO/src/Utilities/SecurityLog.cc
HEADERS += $$REPO/src/comm/MAVLinkSigning.h
INCLUDEPATH += $$REPO/src/Utilities $$REPO/src/comm $$REPO/libs/mavlink/include/mavlink/v2.0 $$REPO/libs/mavlink/include/mavlink/v2.0/all
DEFINES += QGC_USE_ALL_MESSAGES NOMINMAX
win32: LIBS += -lCrypt32
OTHER_FILES += $$files(tst_*.qml) $$files(mock/*, true)
# Icons, fonts and licence files the components load from qrc:/simple/
RESOURCES += ../../custom.qrc
