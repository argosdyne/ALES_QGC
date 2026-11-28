#!/usr/bin/env python3
"""Static checks for the AQGC Simple UI (no Qt needed).

Run from the repo root:  python custom/tests/simple/static_checks.py
Needs fontTools (pip install fonttools) for the font checks.
Exit code 0 = all checks passed (warnings allowed), 1 = at least one failure.
"""
import glob, json, os, re, sys, xml.etree.ElementTree as ET

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
SIMPLE = os.path.join(ROOT, 'custom', 'res', 'Simple')
TS = os.path.join(ROOT, 'translations', 'qgc_simple_ko_KR.ts')
# every Simple UI language: ko_KR + vi_VN, de_DE, da_DK, pt_BR, ja_JP (custom/docs/TASK-i18n-five-languages.md), zh_TW
TS_FILES = sorted(glob.glob(os.path.join(ROOT, 'translations', 'qgc_simple_*.ts')))
def lang_of(path):
    return os.path.basename(path)[len('qgc_simple_'):-3]
QRC = os.path.join(ROOT, 'custom', 'custom.qrc')
CORE_CTX = {'FlyView': os.path.join(ROOT, 'src', 'FlightDisplay', 'FlyView.qml'),
            'MainRootWindow': os.path.join(ROOT, 'src', 'ui', 'MainRootWindow.qml')}
# C++ classes whose tr() strings the Simple UI shows (translated in qgc_simple_ko_KR.ts)
CPP_CTX = {'FlightZoneManager': os.path.join(ROOT, 'custom', 'src', 'MissionManager', 'FlightZoneManager.cpp')}
QSTR_PATTERN_CPP = r'\btr\(\s*"((?:[^"\\]|\\.)*)"\s*\)'
TR = re.compile(QSTR_PATTERN_CPP)

fails, warns = [], []
def fail(area, msg): fails.append((area, msg))
def warn(area, msg): warns.append((area, msg))

QSTR = re.compile(r'qsTr\(\s*"((?:[^"\\]|\\.)*)"\s*[,)]')   # also qsTr("%n item(s)", "", n)
def qml_strings(path):
    return QSTR.findall(open(path, encoding='utf-8').read())

# ---------------------------------------------------------------- translations
def check_translations(path=TS):
    lang = lang_of(path)
    try:
        tree = ET.parse(path)
    except ET.ParseError as e:
        fail('ts', '%s: XML parse error: %s' % (lang, e)); return {}
    ts = {}
    for ctx in tree.getroot().findall('context'):
        name = ctx.findtext('name')
        msgs = {}
        for m in ctx.findall('message'):
            src = m.findtext('source') or ''
            tr = m.find('translation')
            forms = [f.text or '' for f in tr.findall('numerusform')] if tr is not None else []
            text = ' | '.join(forms) if forms else ((tr.text or '') if tr is not None else '')
            if src in msgs:
                fail('ts', '%s: duplicate source in %s: %r' % (lang, name, src))
            if tr is None or not text.strip() or not all(f.strip() for f in forms):
                fail('ts', '%s: empty translation in %s: %r' % (lang, name, src))
            elif tr.get('type') in ('unfinished', 'obsolete', 'vanished'):
                warn('ts', '%s: %s translation in %s: %r' % (lang, tr.get('type'), name, src))
            if m.findtext('translatorcomment'):
                warn('ts', '%s: draft comment left in %s: %r' % (lang, name, src))
            if any('%n' not in f for f in forms):
                fail('ts', '%s: numerus form without %%n in %s: %r' % (lang, name, src))
            msgs[src] = forms[-1] if forms else text      # the longest (plural) form for width checks
        ts[name] = msgs
    # every qsTr in Simple QML (and the Simple-only strings in core files) is translated
    files = glob.glob(os.path.join(SIMPLE, '*.qml'))
    used = {}
    for f in files:
        ctx = os.path.splitext(os.path.basename(f))[0]
        for s in qml_strings(f):
            used.setdefault(ctx, set()).add(s)
            if s not in ts.get(ctx, {}):
                fail('ts', '%s: missing translation %s: %r' % (lang, ctx, s))
    for ctx, cpath in CORE_CTX.items():
        for s in ts.get(ctx, {}):
            if s not in qml_strings(cpath):
                fail('ts', '%s: core context %s: source %r not found in %s' % (lang, ctx, s, os.path.basename(cpath)))
    for ctx, cpath in CPP_CTX.items():      # only the strings already in the .ts must still exist in the source
        src = set(TR.findall(open(cpath, encoding='utf-8').read()))
        for s in ts.get(ctx, {}):
            if s not in src:
                warn('ts', '%s: stale entry %s: %r (text changed or removed in C++)' % (lang, ctx, s))
    # no stale entries
    for ctx, msgs in ts.items():
        if ctx in CORE_CTX or ctx in CPP_CTX:
            continue
        for s in msgs:
            if s not in used.get(ctx, set()):
                warn('ts', '%s: stale entry %s: %r (text changed or removed in QML)' % (lang, ctx, s))
    # placeholders %1..%9 match and are not duplicated / lost
    for ctx, msgs in ts.items():
        for s, t in msgs.items():
            ps, pt = sorted(re.findall(r'%[\dn]', s)), sorted(re.findall(r'%[\dn]', t))
            if ps != pt:
                fail('ts', '%s: placeholder mismatch %s: %r -> %r' % (lang, ctx, s, t))
            if re.search(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', t):
                fail('ts', '%s: control character in %s: %r' % (lang, ctx, t))
            if t != t.strip() and s == s.strip():
                warn('ts', '%s: leading/trailing space added in %s: %r' % (lang, ctx, t))
            if s.startswith(' ') != t.startswith(' '):
                fail('ts', '%s: leading space differs in %s: %r -> %r' % (lang, ctx, s, t))
    return ts

# ---------------------------------------------------------------- qrc, qmldir, icons
def check_resources():
    tree = ET.parse(QRC)
    simple = None
    for q in tree.getroot().findall('qresource'):
        if q.get('prefix') == '/simple':
            simple = q
    if simple is None:
        fail('qrc', 'no /simple prefix'); return set()
    aliases = set()
    for f in simple.findall('file'):
        path = os.path.normpath(os.path.join(os.path.dirname(QRC), f.text))
        alias = f.get('alias') or f.text
        if alias in aliases:
            fail('qrc', 'duplicate alias %s' % alias)
        aliases.add(alias)
        if not os.path.isfile(path):
            fail('qrc', 'missing file for alias %s: %s' % (alias, f.text))
    for f in glob.glob(os.path.join(SIMPLE, '*.qml')):
        b = os.path.basename(f)
        if b not in aliases:
            fail('qrc', '%s not in custom.qrc /simple' % b)
    # qmldir
    qmldir = open(os.path.join(SIMPLE, 'qmldir'), encoding='utf-8').read().split('\n')
    listed = {l.split()[-1] for l in qmldir if l.strip() and not l.startswith('#')}
    for f in glob.glob(os.path.join(SIMPLE, '*.qml')):
        b = os.path.basename(f)
        if b not in listed:
            fail('qmldir', '%s not in qmldir' % b)
    for b in listed:
        if b.endswith('.qml') and not os.path.isfile(os.path.join(SIMPLE, b)):
            fail('qmldir', 'qmldir lists missing %s' % b)
    if 'qmldir' not in aliases:
        warn('qrc', 'qmldir not in /simple (singleton SimpleTheme needs it)')
    # icons referenced by name:/icon: exist and are in qrc
    icon_ref = re.compile(r'\b(?:name|icon)\s*:\s*"([a-z0-9_-]+)"')
    for f in glob.glob(os.path.join(SIMPLE, '*.qml')):
        for n in icon_ref.findall(open(f, encoding='utf-8').read()):
            if not os.path.isfile(os.path.join(SIMPLE, 'icons', n + '.svg')):
                fail('icons', '%s uses icon %r which does not exist' % (os.path.basename(f), n))
            elif 'icons/%s.svg' % n not in aliases:
                fail('icons', 'icon %s.svg not in qrc' % n)
    # icons from JS models, e.g. { icon: "help" }
    for f in glob.glob(os.path.join(SIMPLE, '*.qml')):
        for n in re.findall(r'icon\s*:\s*"([a-z0-9_-]+)"', open(f, encoding='utf-8').read()):
            if not os.path.isfile(os.path.join(SIMPLE, 'icons', n + '.svg')):
                fail('icons', '%s model icon %r missing' % (os.path.basename(f), n))
    return aliases

# ---------------------------------------------------------------- licences
def check_licenses(aliases):
    idx = os.path.join(SIMPLE, 'licenses', 'index.json')
    try:
        items = json.load(open(idx, encoding='utf-8'))
    except Exception as e:
        fail('licenses', 'index.json: %s' % e); return
    if 'licenses/index.json' not in aliases:
        fail('licenses', 'index.json not in qrc')
    names = set()
    for it in items:
        for k in ('name', 'license', 'file', 'used'):
            if k not in it:
                fail('licenses', '%s: missing key %s' % (it.get('name'), k))
        if it.get('name') in names:
            fail('licenses', 'duplicate item %s' % it.get('name'))
        names.add(it.get('name'))
        p = os.path.join(SIMPLE, 'licenses', it.get('file', ''))
        if not os.path.isfile(p):
            fail('licenses', 'missing file %s' % it.get('file'))
            continue
        if 'licenses/' + it['file'] not in aliases:
            fail('licenses', '%s not in qrc' % it['file'])
        if os.path.getsize(p) < 150:
            fail('licenses', '%s looks empty (%d bytes)' % (it['file'], os.path.getsize(p)))
        txt = open(p, encoding='utf-8').read()
        if 'License' not in txt and 'LICENSE' not in txt and 'licen' not in txt.lower():
            warn('licenses', '%s has no licence wording' % it['file'])
    for must in ('QGroundControl', 'Roboto', 'Noto Sans KR', 'Noto Sans JP'):
        if not any(i['name'].startswith(must) for i in items):
            fail('licenses', 'no entry for %s' % must)

# ---------------------------------------------------------------- fonts and label widths (every language)
# Fallback order as in QGCApplication::setLanguage() (chosen at start from the loaded language): Roboto, then
# Traditional Chinese TC, JP, KR; Japanese JP, TC, KR; every other language KR, JP, TC
CJK_ORDER = {'zh_TW': ('TC', 'JP', 'KR'), 'ja_JP': ('JP', 'TC', 'KR')}
DEFAULT_CJK = ('KR', 'JP', 'TC')

def check_fonts(all_ts):
    try:
        from fontTools.ttLib import TTFont
    except ImportError:
        warn('fonts', 'fontTools not installed: font checks skipped'); return
    fdir = os.path.join(SIMPLE, 'fonts')
    fonts = {}          # weight -> {'R'|'KR'|'JP': (cmap, hmtx, unitsPerEm)}
    for w in ('Regular', 'Medium', 'Bold'):
        fonts[w] = {}
        for key, fname in (('R', 'Roboto-%s.ttf'), ('KR', 'NotoSansKR-%s.otf'), ('JP', 'NotoSansJP-%s.otf'),
                           ('TC', 'NotoSansTC-%s.otf')):
            f = TTFont(os.path.join(fdir, fname % w))
            fonts[w][key] = (f.getBestCmap(), f['hmtx'], f['head'].unitsPerEm)
            want = {'Regular': 400, 'Medium': 500, 'Bold': 700}[w]
            if f['OS/2'].usWeightClass != want:
                fail('fonts', '%s weight class %d, expected %d' % (fname % w, f['OS/2'].usWeightClass, want))

    def width(text, size, weight='Regular', lang='ko_KR'):
        chain = [fonts[weight][k] for k in ('R',) + CJK_ORDER.get(lang, DEFAULT_CJK)]
        total = 0.0
        for ch in text:
            cp = ord(ch)
            for cmap, hmtx, upem in chain:
                if cp in cmap:
                    total += hmtx[cmap[cp]][0] * size / upem
                    break
            else:
                return None
        return total

    # every character of every UI string can be drawn by the bundled fonts
    for lang, ts in all_ts.items():
        missing = {}
        for ctx, msgs in ts.items():
            for s, t in msgs.items():
                for ch in s + t:
                    if ch in '\n\t':
                        continue
                    if width(ch, 10, 'Regular', lang) is None:
                        missing.setdefault(ch, set()).add('%s: %s' % (ctx, (t or s)[:40]))
        for ch, where in missing.items():
            fail('fonts', '%s: no glyph for %r U+%04X (%s)' % (lang, ch, ord(ch), sorted(where)[0]))
    # all Hangul syllables (U+AC00..D7A3) are in the Korean subset; kana in the Japanese one
    kc, jc = fonts['Regular']['KR'][0], fonts['Regular']['JP'][0]
    gap = [cp for cp in range(0xAC00, 0xD7A4) if cp not in kc]
    if gap:
        fail('fonts', '%d Hangul syllables missing from Noto Sans KR subset' % len(gap))
    gap = [cp for cp in list(range(0x3041, 0x3097)) + list(range(0x30A1, 0x30FB)) if cp not in jc]
    if gap:
        fail('fonts', '%d kana missing from Noto Sans JP subset' % len(gap))

    # fixed-width labels (design px at 1920x1080, Normal and Large text = x1.2)
    checks = []
    for s in ('Take off', 'Start mission', 'Resume', 'Return home', 'Land', 'Pause'):
        checks.append(('Action button (S01)', 'SimpleFlyOverlay', s, 22, 'Medium', 140, 0.8))
    for s in ('ALTITUDE', 'DISTANCE', 'SPEED', 'FLIGHT TIME'):
        checks.append(('Telemetry label', 'STelemetryBar', s, 22, 'Medium', (902 - 28) / 4 - 8))
    seg = lambda W, n: (W - 8 - 4 * (n - 1)) / n - 8
    for ctx, labels, W in (('SimpleSettings', ('Metric', 'Imperial', 'Normal', 'Large', 'Fly', 'Plan'), 338),
                           ('SimpleWelcome', ('Metric', 'Imperial'), 338),
                           ('SimplePlanWizard', ('Standard · 2D map', 'High · 3D model'), 556)):
        for s in labels:
            checks.append(('Segmented (%d px, 2 items)' % W, ctx, s, 24, 'Bold', seg(W, 2), 0.8))
    for s in ('Slide to take off', 'Slide to return home', 'Slide to land', 'Slide to start'):
        ctx = 'SimpleTakeoffSheet' if s == 'Slide to take off' else 'SimpleFlyOverlay'
        # track = sheet 980 - 2 x 28 padding; text is centred +40 px and must clear the knob (6 + 156 + 8)
        checks.append(('Slide confirm (924 px track)', ctx, s, 28, 'Medium', 924 + 2 * 40 - 2 * (6 + 156 + 8)))
    checks += EXTRA_WIDTH_CHECKS
    for scale, tag in ((1.0, 'Normal'), (1.2, 'Large')):
        for area, ctx, s, size, wgt, avail, *opt in checks:
            fit = opt[0] if opt else 1.0          # SText.fit: the label may shrink to this share of its size
            for lang, ts in [('en', {})] + sorted(all_ts.items()):
                txt = ts.get(ctx, {}).get(s, s)
                w = width(txt, size * scale, wgt, lang)
                if w is None or w <= avail:
                    continue
                ratio = (w - avail) / avail * 100
                if w * fit <= avail:        # SText.fitMin: shrinks to fit (shown so the list stays short)
                    warn('width', '%s [%s, %s text] %r shrinks to %.0f%% of its size' % (area, lang, tag, txt, avail / w * 100))
                    continue
                (fail if tag == 'Normal' else warn)(
                    'width', '%s [%s, %s text] %r = %.0f px > %.0f px (+%.0f%%)' % (area, lang, tag, txt, w, avail, ratio))
    # general: much wider than English for short labels (likely buttons / chips). Korean: one warning per label;
    # the other languages: a count per language (run with --widths to list them).
    for lang, ts in sorted(all_ts.items()):
        grown = []
        for ctx, msgs in ts.items():
            for s, t in msgs.items():
                if len(s) <= 16 and '%' not in s:
                    we, wt = width(s, 24, 'Medium', lang), width(t, 24, 'Medium', lang)
                    if we and wt and wt > we * 1.35 and wt - we > 30:
                        grown.append('short label grows in %s %s: %r %.0f px -> %r %.0f px' % (lang, ctx, s, we, t, wt))
        if lang == 'ko_KR' or '--widths' in sys.argv:
            for g in grown:
                warn('width', g)
        elif grown:
            warn('width', '%s: %d short labels are 35%%+ wider than English (run with --widths to list)' % (lang, len(grown)))

# Labels that Figma shortened or let wrap in the translated screens (TASK-i18n-five-languages.md §3.5):
# (area, context, source, design font px, weight, available px[, fit = smallest share of the size SText may shrink to])
EXTRA_WIDTH_CHECKS = [
    # S17 / S102 / S103: SHoldButton in a payload card (panel 640 - 2 x 16 margins - card 2 x 20 - button 56)
    ('Hold button (payload card)', 'SimplePayloadPanel', 'Hold 2 s to stop', 26, 'Bold', 512),
    ('Hold button (payload card)', 'SimplePayloadPanel', 'Hold 2 s to stop · %1 of %2 lines left', 26, 'Bold', 512),
    ('Hold button (payload card)', 'SimplePayloadPanel', 'Hold 2 s to drop the life jacket', 26, 'Bold', 512),
    # S02 compass hint, S28 position-hold note, S78 emergency-stop note: wrapped text (Figma allows 2 lines),
    # S05 status pill: grows with its text. Not width-limited here; compared on the device / mock run.
]

# ---------------------------------------------------------------- desktop-only QML types
# A QML type registered only in desktop builds (#ifndef __mobile__ in QGCApplication.cc) fails the whole file that
# names it on Android, even inside an inactive Loader, and every file that uses that file: on 2026-11-23 the Simple
# UI did not appear at all on the smart controller (SimpleSetupFirmware -> SimpleVehicleSetup -> SimpleRoot).
# Such a type may be named only in a wrapper file that is loaded with Loader.source / setSource on desktop.
DESKTOP_ONLY_WRAPPERS = {'SimpleFirmwareController.qml'}

def desktop_only_types():
    types, stack = set(), []
    for line in open(os.path.join(ROOT, 'src', 'QGCApplication.cc'), encoding='utf-8', errors='replace'):
        s = line.strip()
        if s.startswith('#if'):
            stack.append(bool(re.match(r'#if(ndef\s+__mobile__|\s+!\s*defined\s*\(\s*__mobile__\s*\))', s)))
        elif s.startswith('#endif') and stack:
            stack.pop()
        elif s.startswith('#else') and stack:
            stack[-1] = False
        elif any(stack):
            m = re.search(r'qmlRegister\w*<\w+>\s*\([^,]+,[^,]+,[^,]+,\s*"(\w+)"', s)
            if m:
                types.add(m.group(1))
    return types

def check_platform_types():
    types = desktop_only_types()
    if not types:
        warn('platform', 'no desktop-only QML types found in QGCApplication.cc (parser out of date?)')
        return
    use = re.compile(r'(?<![\w.])(%s)\s*\{' % '|'.join(sorted(types)))
    for f in sorted(glob.glob(os.path.join(SIMPLE, '*.qml'))):
        if os.path.basename(f) in DESKTOP_ONLY_WRAPPERS:
            continue
        code = re.sub(r'//[^\n]*|/\*.*?\*/', '', open(f, encoding='utf-8').read(), flags=re.S)
        for m in use.finditer(code):
            fail('platform', '%s names desktop-only type %s: Android cannot compile the file (move it to a wrapper '
                 'loaded with Loader.setSource, see SimpleFirmwareController.qml)' % (os.path.basename(f), m.group(1)))

def main():
    all_ts = {lang_of(p): check_translations(p) for p in TS_FILES}
    check_platform_types()
    aliases = check_resources()
    check_licenses(aliases)
    check_fonts(all_ts)
    for area, m in warns:
        print('WARN  [%s] %s' % (area, m))
    for area, m in fails:
        print('FAIL  [%s] %s' % (area, m))
    print('\n%d failures, %d warnings' % (len(fails), len(warns)))
    return 1 if fails else 0

if __name__ == '__main__':
    sys.exit(main())
