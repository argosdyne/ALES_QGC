#!/usr/bin/env python3
"""Make the Noto Sans TC subset the Simple UI bundles (custom/res/Simple/fonts/NotoSansTC-*.otf).

Usage (repo root, needs fontTools: pip install fonttools):
  python custom/tools/i18n/subset_noto_tc.py <folder with NotoSansTC-Regular/Medium/Bold.otf>

Source fonts: https://github.com/notofonts/noto-cjk  Sans/SubsetOTF/TC  (v2.004, SIL OFL 1.1).
Kept characters:
- ASCII and Latin-1 punctuation (Latin text itself is drawn by Roboto),
- CJK symbols and punctuation, Bopomofo, half- and full-width forms,
- the Big5 frequently used characters (常用字, 5,401 characters, Big5 0xA440-0xC67E),
- every character of translations/qgc_simple_zh_TW.ts and the core qgc_source_zh_TW.ts / qgc_json_zh_TW.ts
  (C++ messages shown on the Simple screens), so rarer characters used by the UI are never missing.
Run it again after the Traditional Chinese translation gains new characters; static_checks.py reports missing glyphs.
"""
import os, sys
import xml.etree.ElementTree as ET
from fontTools import subset

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
OUT = os.path.join(ROOT, 'custom', 'res', 'Simple', 'fonts')
TS = [os.path.join(ROOT, 'translations', f) for f in ('qgc_simple_zh_TW.ts', 'qgc_source_zh_TW.ts', 'qgc_json_zh_TW.ts')]


def big5_common():
    chars = set()
    for hi in range(0xA4, 0xC7):                      # Big5 level 1 (常用字): 0xA440 .. 0xC67E
        for lo in list(range(0x40, 0x7F)) + list(range(0xA1, 0xFF)):
            if hi == 0xC6 and lo > 0x7E:
                break
            try:
                ch = bytes([hi, lo]).decode('big5')
            except UnicodeDecodeError:
                continue
            if 0x4E00 <= ord(ch) <= 0x9FFF:
                chars.add(ord(ch))
    return chars


def unicodes():
    cps = set(range(0x20, 0x7F)) | set(range(0xA0, 0x100))
    for a, b in ((0x2000, 0x206F), (0x2190, 0x21FF), (0x2460, 0x24FF), (0x25A0, 0x25FF), (0x3000, 0x303F),
                 (0x3100, 0x312F), (0xFF00, 0xFFEF)):
        cps |= set(range(a, b + 1))
    cps |= big5_common()
    for path in TS:
        if not os.path.exists(path):
            continue
        for el in ET.parse(path).getroot().iter('translation'):
            for t in [el.text or ''] + [n.text or '' for n in el.iter('numerusform')]:
                cps |= {ord(c) for c in t}
    cps |= {ord(c) for c in '繁體中文'}
    return sorted(cps)


def main(src):
    cps = unicodes()
    opts = subset.Options()
    opts.layout_features = ['*']
    opts.name_IDs = ['*']
    opts.name_languages = ['*']
    opts.notdef_outline = True
    opts.hinting = True
    for w in ('Regular', 'Medium', 'Bold'):
        font = subset.load_font(os.path.join(src, 'NotoSansTC-%s.otf' % w), opts)
        sub = subset.Subsetter(opts)
        sub.populate(unicodes=cps)
        sub.subset(font)
        out = os.path.join(OUT, 'NotoSansTC-%s.otf' % w)
        subset.save_font(font, out, opts)
        print('%s: %d glyphs, %d bytes' % (os.path.basename(out), len(font.getGlyphOrder()), os.path.getsize(out)))


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
