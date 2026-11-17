# Simple UI unit tests (Qt Quick Test). Build with qmake + jom/nmake, then run:
#   tst_simple -import <this dir>/mock -input <this dir>
TEMPLATE = app
TARGET   = tst_simple
CONFIG  += warn_on qmltestcase console
SOURCES += main.cpp
OTHER_FILES += $$files(tst_*.qml) $$files(mock/*, true)
# Icons, fonts and licence files the components load from qrc:/simple/
RESOURCES += ../../custom.qrc
