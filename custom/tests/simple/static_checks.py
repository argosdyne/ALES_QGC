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
QRC = os.path.join(ROOT, 'custom', 'custom.qrc')
CORE_CTX = {'FlyView': os.path.join(ROOT, 'src', 'FlightDisplay', 'FlyView.qml'),
            'MainRootWindow': os.path.join(ROOT, 'src', 'ui', 'MainRootWindow.qml')}

fails, warns = [], []
def fail(area, msg): fails.append((area, msg))
def warn(area, msg): warns.append((area, msg))

QSTR = re.compile(r'qsTr\(\s*"((?:[^"\\]|\\.)*)"\s*\)')
def qml_strings(path):
    return QSTR.findall(open(path, encoding='utf-8').read())

# ---------------------------------------------------------------- translations
def check_translations():
    try:
        tree = ET.parse(TS)
    except ET.ParseError as e:
        fail('ts', 'XML parse error: %s' % e); return {}
    ts = {}
    for ctx in tree.getroot().findall('context'):
        name = ctx.findtext('name')
        msgs = {}
        for m in ctx.findall('message'):
            src = m.findtext('source') or ''
            tr = m.find('translation')
            if src in msgs:
                fail('ts', 'duplicate source in %s: %r' % (name, src))
            if tr is None or not (tr.text or '').strip():
                fail('ts', 'empty translation in %s: %r' % (name, src))
            elif tr.get('type') in ('unfinished', 'obsolete', 'vanished'):
                warn('ts', '%s translation in %s: %r' % (tr.get('type'), name, src))
            msgs[src] = (tr.text or '') if tr is not None else ''
        ts[name] = msgs
    # every qsTr in Simple QML (and the Simple-only strings in core files) is translated
    files = glob.glob(os.path.join(SIMPLE, '*.qml'))
    used = {}
    for f in files:
        ctx = os.path.splitext(os.path.basename(f))[0]
        for s in qml_strings(f):
            used.setdefault(ctx, set()).add(s)
            if s not in ts.get(ctx, {}):
                fail('ts', 'missing translation %s: %r' % (ctx, s))
    for ctx, path in CORE_CTX.items():
        for s in ts.get(ctx, {}):
            if s not in qml_strings(path):
                fail('ts', 'core context %s: source %r not found in %s' % (ctx, s, os.path.basename(path)))
    # no stale entries
    for ctx, msgs in ts.items():
        if ctx in CORE_CTX:
            continue
        for s in msgs:
            if s not in used.get(ctx, set()):
                warn('ts', 'stale entry %s: %r (text changed or removed in QML)' % (ctx, s))
    # placeholders %1..%9 match and are not duplicated / lost
    for ctx, msgs in ts.items():
        for s, t in msgs.items():
            ps, pt = sorted(re.findall(r'%\d', s)), sorted(re.findall(r'%\d', t))
            if ps != pt:
                fail('ts', 'placeholder mismatch %s: %r -> %r' % (ctx, s, t))
            if re.search(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', t):
                fail('ts', 'control character in %s: %r' % (ctx, t))
            if t != t.strip() and s == s.strip():
                warn('ts', 'leading/trailing space added in %s: %r' % (ctx, t))
            if s.startswith(' ') != t.startswith(' '):
                fail('ts', 'leading space differs in %s: %r -> %r' % (ctx, s, t))
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
    for must in ('QGroundControl', 'Roboto', 'Noto Sans KR'):
        if not any(i['name'].startswith(must) for i in items):
            fail('licenses', 'no entry for %s' % must)

# ---------------------------------------------------------------- fonts and Korean label widths
def check_fonts(ts):
    try:
        from fontTools.ttLib import TTFont
    except ImportError:
        warn('fonts', 'fontTools not installed: font checks skipped'); return
    fdir = os.path.join(SIMPLE, 'fonts')
    fonts = {}
    for w in ('Regular', 'Medium', 'Bold'):
        r = TTFont(os.path.join(fdir, 'Roboto-%s.ttf' % w))
        n = TTFont(os.path.join(fdir, 'NotoSansKR-%s.otf' % w))
        fonts[w] = (r, r.getBestCmap(), r['hmtx'], r['head'].unitsPerEm,
                    n, n.getBestCmap(), n['hmtx'], n['head'].unitsPerEm)
        wr, wn = r['OS/2'].usWeightClass, n['OS/2'].usWeightClass
        if {'Regular': 400, 'Medium': 500, 'Bold': 700}[w] not in (wr, wn) or wr != wn:
            fail('fonts', '%s weight classes Roboto %d / Noto %d' % (w, wr, wn))

    def width(text, size, weight='Regular'):
        r, rc, rh, ru, n, nc, nh, nu = fonts[weight]
        total = 0.0
        for ch in text:
            cp = ord(ch)
            if cp in rc:
                total += rh[rc[cp]][0] * size / ru
            elif cp in nc:
                total += nh[nc[cp]][0] * size / nu
            else:
                return None
        return total

    # every character of every UI string (EN and KO) can be drawn by Roboto or Noto Sans KR
    missing = {}
    for ctx, msgs in ts.items():
        for s, t in msgs.items():
            for ch in s + t:
                if ch in '\n\t':
                    continue
                if width(ch, 10) is None:
                    missing.setdefault(ch, set()).add('%s: %s' % (ctx, (t or s)[:40]))
    for ch, where in missing.items():
        fail('fonts', 'no glyph for %r U+%04X (%s)' % (ch, ord(ch), sorted(where)[0]))
    # all Hangul syllables (U+AC00..D7A3) are in the subset
    nc = fonts['Regular'][5]
    gap = [cp for cp in range(0xAC00, 0xD7A4) if cp not in nc]
    if gap:
        fail('fonts', '%d Hangul syllables missing from Noto Sans KR subset' % len(gap))

    # fixed-width labels (design px at 1920x1080, Normal and Large text = x1.2)
    ko = lambda ctx, s: ts.get(ctx, {}).get(s, s)
    checks = []
    for s in ('Take off', 'Start mission', 'Resume', 'Return home', 'Land', 'Pause'):
        checks.append(('Action button (S01)', 'SimpleFlyOverlay', s, 22, 'Medium', 140))
    for s in ('ALTITUDE', 'DISTANCE', 'SPEED', 'FLIGHT TIME'):
        checks.append(('Telemetry label', 'STelemetryBar', s, 22, 'Medium', (902 - 28) / 4 - 8))
    seg = lambda W, n: (W - 8 - 4 * (n - 1)) / n - 8
    for ctx, labels, W in (('SimpleSettings', ('Metric', 'Imperial', 'Normal', 'Large', 'Fly', 'Plan'), 338),
                           ('SimpleWelcome', ('Metric', 'Imperial'), 338),
                           ('SimplePlanWizard', ('Standard · 2D map', 'High · 3D model'), 556)):
        for s in labels:
            checks.append(('Segmented (%d px, 2 items)' % W, ctx, s, 24, 'Bold', seg(W, 2)))
    for s in ('Slide to take off', 'Slide to return home', 'Slide to land', 'Slide to start'):
        ctx = 'SimpleTakeoffSheet' if s == 'Slide to take off' else 'SimpleFlyOverlay'
        # track = sheet 980 - 2 x 28 padding; text is centred +40 px and must clear the knob (6 + 156 + 8)
        checks.append(('Slide confirm (924 px track)', ctx, s, 28, 'Medium', 924 + 2 * 40 - 2 * (6 + 156 + 8)))
    for scale, tag in ((1.0, 'Normal'), (1.2, 'Large')):
        for area, ctx, s, size, wgt, avail in checks:
            for lang, txt in (('en', s), ('ko', ko(ctx, s))):
                w = width(txt, size * scale, wgt)
                if w is None:
                    continue
                if w > avail:
                    ratio = (w - avail) / avail * 100
                    (fail if tag == 'Normal' else warn)(
                        'width', '%s [%s, %s text] %r = %.0f px > %.0f px (+%.0f%%)' % (area, lang, tag, txt, w, avail, ratio))
    # general: Korean much wider than English for short labels (likely buttons / chips)
    for ctx, msgs in ts.items():
        for s, t in msgs.items():
            if len(s) <= 16 and '%' not in s:
                we, wk = width(s, 24, 'Medium'), width(t, 24, 'Medium')
                if we and wk and wk > we * 1.35 and wk - we > 30:
                    warn('width', 'short label grows in Korean %s: %r %.0f px -> %r %.0f px' % (ctx, s, we, t, wk))

def main():
    ts = check_translations()
    aliases = check_resources()
    check_licenses(aliases)
    check_fonts(ts)
    for area, m in warns:
        print('WARN  [%s] %s' % (area, m))
    for area, m in fails:
        print('FAIL  [%s] %s' % (area, m))
    print('\n%d failures, %d warnings' % (len(fails), len(warns)))
    return 1 if fails else 0

if __name__ == '__main__':
    sys.exit(main())
