#!/bin/bash
# Download the licence texts used by mklic.py into $1 (default ./lic). Commits match the submodules.
D=${1:-lic}; mkdir -p "$D"; cd "$D" || exit 1
g(){ curl -sfL -o "$1" "$2" || echo "FAIL $1 $2"; }
g eigen-MPL2.txt     https://gitlab.com/libeigen/eigen/-/raw/0fd6b4f71dd85b2009ee4d1aeb296e2c11fc9d68/COPYING.MPL2
g libevents.txt      https://raw.githubusercontent.com/mavlink/libevents/59f7f5c0ec2e76fadbc1dc40cc0705d614472edc/LICENSE.md
g qmdnsengine.txt    https://raw.githubusercontent.com/patrickelectric/qmdnsengine/bcae73281fd29ab8e7a41fc3246223b15d44d0df/LICENSE.txt
g shapelib2.txt      https://raw.githubusercontent.com/OSGeo/shapelib/6189dbd83ba2382fe0ebbc8f2308e582832c93fa/COPYING
g xz.txt             https://raw.githubusercontent.com/Auterion/xz-embedded/090e6a054d6283b144d20f5783852b95eade90ee/COPYING
g gpsdrivers.txt     https://raw.githubusercontent.com/PX4/GpsDrivers/a41210ede8c2d22dd8e9fdcf388fca927c1fc5e1/LICENSE.md
g mavlink.txt        https://raw.githubusercontent.com/mavlink/mavlink/master/COPYING
g LGPL-2.1.txt       https://www.gnu.org/licenses/old-licenses/lgpl-2.1.txt
g openssl11.txt      https://raw.githubusercontent.com/openssl/openssl/OpenSSL_1_1_1-stable/LICENSE
g zlib-h.txt         https://raw.githubusercontent.com/madler/zlib/v1.2.11/zlib.h
g orc.txt            https://gitlab.freedesktop.org/gstreamer/orc/-/raw/0.4.33/COPYING
g pcre2.txt          https://raw.githubusercontent.com/PCRE2Project/pcre2/pcre2-10.42/LICENCE
g libffi.txt         https://raw.githubusercontent.com/libffi/libffi/v3.4.4/LICENSE
g graphene.txt       https://raw.githubusercontent.com/ebassi/graphene/1.10.8/LICENSE.txt
g libjpeg-turbo.md   https://raw.githubusercontent.com/libjpeg-turbo/libjpeg-turbo/2.1.4/LICENSE.md
g libjpeg-ijg.txt    https://raw.githubusercontent.com/libjpeg-turbo/libjpeg-turbo/2.1.4/README.ijg
g libpng.txt         https://raw.githubusercontent.com/pnggroup/libpng/v1.6.40/LICENSE
g bzip2.txt          https://gitlab.com/bzip2/bzip2/-/raw/bzip2-1.0.8/LICENSE
