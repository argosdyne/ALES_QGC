#!/usr/bin/env python3
"""Make the Noto Sans JP subset the Simple UI bundles (custom/res/Simple/fonts/NotoSansJP-*.otf).

Usage (repo root, needs fontTools: pip install fonttools):
  python custom/tools/i18n/subset_noto_jp.py <folder with NotoSansJP-Regular/Medium/Bold.otf>

Source fonts: https://github.com/notofonts/noto-cjk  Sans/SubsetOTF/JP  (v2.004, SIL OFL 1.1).
Kept characters:
- ASCII and Latin-1 punctuation (Latin text itself is drawn by Roboto),
- CJK symbols and punctuation, hiragana, katakana (incl. phonetic extensions), half- and full-width forms,
- the JIS X 0208 level-1 kanji (2,965 common kanji, nearly the whole jōyō set),
- every character of translations/qgc_simple_ja_JP.ts (so rarer kanji used by the UI are never missing).
Run it again after the Japanese translation gains new kanji; static_checks.py reports missing glyphs.
"""
import os, sys
import xml.etree.ElementTree as ET
from fontTools import subset

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
OUT = os.path.join(ROOT, 'custom', 'res', 'Simple', 'fonts')
TS = os.path.join(ROOT, 'translations', 'qgc_simple_ja_JP.ts')


def jis_level1():
    chars = set()
    for hi in range(0x88, 0x99):                      # Shift_JIS rows 16..47 = JIS X 0208 level 1
        for lo in list(range(0x40, 0x7F)) + list(range(0x80, 0xFD)):
            try:
                ch = bytes([hi, lo]).decode('shift_jis')
            except UnicodeDecodeError:
                continue
            if 0x4E00 <= ord(ch) <= 0x9FFF:
                chars.add(ord(ch))
    return chars


def unicodes():
    cps = set(range(0x20, 0x7F)) | set(range(0xA0, 0x100))
    for a, b in ((0x2000, 0x206F), (0x2190, 0x21FF), (0x2460, 0x24FF), (0x25A0, 0x25FF), (0x3000, 0x30FF),
                 (0x31F0, 0x31FF), (0xFF00, 0xFFEF)):
        cps |= set(range(a, b + 1))
    cps |= jis_level1()
    root = ET.parse(TS).getroot()
    for el in root.iter():
        for ch in (el.text or ''):
            cps.add(ord(ch))
    cps |= {ord(c) for c in '日本語'}
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
        font = subset.load_font(os.path.join(src, 'NotoSansJP-%s.otf' % w), opts)
        sub = subset.Subsetter(opts)
        sub.populate(unicodes=cps)
        sub.subset(font)
        out = os.path.join(OUT, 'NotoSansJP-%s.otf' % w)
        subset.save_font(font, out, opts)
        print('%s: %d glyphs, %d bytes' % (os.path.basename(out), len(font.getGlyphOrder()), os.path.getsize(out)))


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
