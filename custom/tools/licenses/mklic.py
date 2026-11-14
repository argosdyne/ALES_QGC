# Build custom/res/Simple/licenses/ (third-party notices for the About page and the Windows installer).
import json, os, re, sys
L = sys.argv[1]          # scratchpad/lic (downloaded texts)
REPO = sys.argv[2]       # repo root
OUT = os.path.join(REPO, 'custom', 'res', 'Simple', 'licenses')
os.makedirs(OUT, exist_ok=True)

def rd(p):
    return open(p, encoding='utf-8', errors='replace').read().replace('\r\n', '\n').strip() + '\n'

def lic(name):
    return rd(os.path.join(L, name))

APACHE = rd(os.path.join(REPO, 'custom/res/Simple/fonts/LICENSE-Roboto.txt'))
LGPL21 = lic('LGPL-2.1.txt')
zh = lic('zlib-h.txt')
ZLIB = zh[zh.index('  Copyright (C) 1995'):zh.index('  Jean-loup Gailly')] + '  Jean-loup Gailly        Mark Adler\n'
mav = lic('mavlink.txt')
_i = mav.index('As an exception'); MAV_MIT = mav[_i:mav.index('=====', _i)].strip() + '\n'
SEP = '\n' + '=' * 78 + '\n'

def head(title, version, license_, extra=''):
    h = '%s%s\nLicense: %s\n' % (title, (' ' + version) if version else '', license_)
    return h + (extra.strip() + '\n' if extra else '') + '\n'

items = []   # index for the About page
def add(fname, name, version, license_, used, text):
    open(os.path.join(OUT, fname), 'w', encoding='utf-8', newline='\n').write(text)
    items.append({'name': name, 'version': version, 'license': license_, 'used': used, 'file': fname})

# --- alesQGC base ---------------------------------------------------------------------------
add('QGroundControl.txt', 'QGroundControl', '', 'Apache License 2.0', 'Base of alesQGC',
    head('QGroundControl', '', 'Apache License 2.0 (QGC is dual-licensed Apache 2.0 / GPLv3; alesQGC uses it under Apache 2.0 with the commercial Qt license)',
         'Copyright (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>\nSource: https://github.com/mavlink/qgroundcontrol')
    + rd(os.path.join(REPO, 'COPYING.md')) + SEP + APACHE)

# --- Qt ---------------------------------------------------------------------------------------
qt = json.load(open(os.path.join(L, 'qt_attr.json'), encoding='utf-8'))
drop = re.compile(r'macOS|X Server helper', re.I)
qt = [e for e in qt if not drop.search(e['name'])]
parts = [head('Qt', '5.15.2', 'Qt Commercial License (The Qt Company)',
              'Qt contains third-party code under the licenses below. Listed for the Qt modules alesQGC ships\n'
              '(Core, GUI, Network, SQL, Widgets, QML, Quick, Quick Controls 2, Location, Positioning, SVG,\n'
              'Image Formats, Multimedia, Charts, Text to Speech, Serial Port), from the qt_attribution.json\n'
              'files of the Qt 5.15.2 sources.')]
for e in qt:
    t = '%s%s\nLicense: %s\n' % (e['name'], (' ' + e['version']) if e['version'] and not e['version'].startswith('http') else '', e['license'])
    if e['copyright']:
        t += e['copyright'].strip() + '\n'
    if e['text']:
        t += '\n' + e['text'].replace('\r\n', '\n').strip() + '\n'
    parts.append(t)
add('Qt-third-party.txt', 'Qt (third-party parts)', '5.15.2', 'MIT, BSD, zlib, FreeType, IJG, libpng, Boost, ISC, Unicode, …',
    'Qt is used under the Qt Commercial License', SEP.join(parts))

# --- Video ------------------------------------------------------------------------------------
add('GStreamer.txt', 'GStreamer, GLib, libiconv, gettext (libintl)', '1.22.12 (Android) · 1.18.1 (Windows)',
    'GNU LGPL 2.1', 'Video',
    head('GStreamer (core, gst-plugins-base, gst-plugins-good, gst-plugins-bad), GLib, libiconv, gettext (libintl)',
         '', 'GNU Lesser General Public License version 2.1 (or later)',
         'Android: GStreamer 1.22.12 binaries from gstreamer.freedesktop.org. Windows: GStreamer 1.18.1 MSVC runtime (DLLs).\n'
         'The qmlglsink element is built from gst-plugins-good.\n'
         'Source code: https://gstreamer.freedesktop.org/src/ · https://download.gnome.org/sources/glib/ ·\n'
         'https://ftp.gnu.org/gnu/libiconv/ · https://ftp.gnu.org/gnu/gettext/')
    + LGPL21)
add('orc.txt', 'ORC (Oil Runtime Compiler)', '0.4', 'BSD 2-clause', 'Video (Android)', head('ORC', '0.4', 'BSD 2-clause') + lic('orc.txt'))
add('PCRE2.txt', 'PCRE2', '10.42', 'BSD 3-clause', 'Video (Android, GLib)', head('PCRE2', '10.42', 'BSD 3-clause with binary exception') + lic('pcre2.txt'))
add('libffi.txt', 'libffi', '3.4', 'MIT', 'Video (Android, GLib)', head('libffi', '3.4', 'MIT') + lic('libffi.txt'))
add('graphene.txt', 'Graphene', '1.10', 'MIT', 'Video (Android)', head('Graphene', '1.10', 'MIT') + lic('graphene.txt'))
add('libjpeg-turbo.txt', 'libjpeg-turbo', '2.1', 'IJG, BSD 3-clause, zlib', 'Video (Android)',
    head('libjpeg-turbo', '2.1', 'IJG License, BSD 3-clause, zlib',
         'This software is based in part on the work of the Independent JPEG Group.')
    + lic('libjpeg-turbo.md') + SEP + lic('libjpeg-ijg.txt'))
add('libpng.txt', 'libpng', '1.6', 'libpng License', 'Video (Android)', head('libpng', '1.6', 'PNG Reference Library License version 2') + lic('libpng.txt'))
add('bzip2.txt', 'bzip2', '1.0.8', 'bzip2 License (BSD-like)', 'Video (Android)', head('bzip2', '1.0.8', 'bzip2 License') + lic('bzip2.txt'))

# --- Libraries in libs/ --------------------------------------------------------------------------
add('OpenSSL.txt', 'OpenSSL', '1.1.1', 'OpenSSL License and SSLeay License', 'Secure connections (Windows DLLs, Android libs)',
    head('OpenSSL', '1.1.1', 'OpenSSL License and original SSLeay License',
         'This product includes software developed by the OpenSSL Project for use in the OpenSSL Toolkit (http://www.openssl.org/).\n'
         'This product includes cryptographic software written by Eric Young (eay@cryptsoft.com).')
    + lic('openssl11.txt'))
add('SDL2.txt', 'SDL2', '2.0', 'zlib License', 'Joystick and gamepad',
    head('Simple DirectMedia Layer (SDL2)', '', 'zlib License') + rd(os.path.join(REPO, 'libs/sdl2/msvc/COPYING.txt')))
add('zlib.txt', 'zlib', '1.2.3 (Windows) · system (Android)', 'zlib License', 'Compression', head('zlib', '', 'zlib License') + ZLIB)
add('Eigen.txt', 'Eigen', '3', 'Mozilla Public License 2.0', 'Math (header-only)',
    head('Eigen', '3', 'Mozilla Public License 2.0', 'Source: https://gitlab.com/libeigen/eigen') + lic('eigen-MPL2.txt'))
s = lic('shapelib2.txt')
add('shapelib.txt', 'Shapelib', '', 'MIT (or LGPL)', 'Shapefile import',
    head('Shapelib', '', 'MIT-style license (used under MIT; LGPL alternative)',
         'Copyright (c) 1999, 2001, Frank Warmerdam\nCopyright (c) 2011-2019, Even Rouault <even dot rouault at spatialys.com>')
    + 'Permission is hereby granted, free of charge, to any person obtaining a\ncopy of this software and associated documentation files (the "Software"),\n'
      'to deal in the Software without restriction, including without limitation\nthe rights to use, copy, modify, merge, publish, distribute, sublicense,\n'
      'and/or sell copies of the Software, and to permit persons to whom the\nSoftware is furnished to do so, subject to the following conditions:\n\n'
      'The above copyright notice and this permission notice shall be included\nin all copies or substantial portions of the Software.\n\n'
      'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS\nOR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\n'
      'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL\nTHE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\n'
      'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING\nFROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER\nDEALINGS IN THE SOFTWARE.\n')
add('xz-embedded.txt', 'XZ Embedded', '', 'Public domain', 'Decompression', head('XZ Embedded', '', 'Public domain') + lic('xz.txt'))
add('libevents.txt', 'libevents', '', 'BSD 3-clause', 'Vehicle events', head('libevents (MAVLink)', '', 'BSD 3-clause') + lic('libevents.txt'))
add('qmdnsengine.txt', 'qmdnsengine', '', 'MIT', 'Network discovery', head('qmdnsengine', '', 'MIT') + lic('qmdnsengine.txt'))
add('MAVLink.txt', 'MAVLink C library (generated)', 'v2.0', 'MIT', 'Drone communication',
    head('MAVLink C library v2 (generated code)', '', 'MIT (MAVLink generator output exception)',
         'Copyright (c) MAVLink Development Team. Source: https://github.com/mavlink/c_library_v2') + MAV_MIT)
add('PX4-GpsDrivers.txt', 'PX4 GPS Drivers', '', 'BSD 3-clause', 'RTK GPS', head('PX4 GPS Drivers', '', 'BSD 3-clause') + lic('gpsdrivers.txt'))

# --- Fonts --------------------------------------------------------------------------------------
add('Roboto.txt', 'Roboto', '2.138', 'Apache License 2.0', 'Font', head('Roboto', '2.138', 'Apache License 2.0', 'Copyright 2011 Google Inc.') + APACHE)
add('NotoSansKR.txt', 'Noto Sans KR', '2.004', 'SIL Open Font License 1.1', 'Font (Korean, subset)',
    head('Noto Sans KR', '', 'SIL Open Font License 1.1', 'Subset to Latin and Hangul for alesQGC.')
    + rd(os.path.join(REPO, 'custom/res/Simple/fonts/LICENSE-NotoSansKR.txt')))

json.dump(items, open(os.path.join(OUT, 'index.json'), 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, indent=1)
# One combined file for the installer folder
allt = ['alesQGC — third-party software notices\n\nalesQGC (ARGOSDYNE) includes the open-source software listed below.\n']
for it in items:
    allt.append(open(os.path.join(OUT, it['file']), encoding='utf-8').read())
open(os.path.join(OUT, 'THIRD-PARTY-NOTICES.txt'), 'w', encoding='utf-8', newline='\n').write(('\n' + '#' * 78 + '\n\n').join(allt))
tot = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
print(len(items), 'items', tot, 'bytes')
