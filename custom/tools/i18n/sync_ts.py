#!/usr/bin/env python3
"""Bring the Simple UI .ts files in line with the QML sources.

Usage (repo root):
  python custom/tools/i18n/sync_ts.py <lupdate.exe> translations/qgc_simple_*.ts

- Runs lupdate on custom/res/Simple into a temporary file to get the current list of
  (context, source, numerus) messages.
- Keeps every existing translation, the order of the file and its line endings.
  New messages are added (empty, unfinished) at the end of their context; new contexts at the end.
- Only contexts named after a QML file in custom/res/Simple are taken (qsTranslate() calls for
  core contexts, e.g. LogDownloadController, are left to the core translations).
- Messages that are no longer in the QML are removed, except in the core contexts below:
  they hold Simple-only strings of core files (see custom/res/Simple/README.md) and are checked
  by custom/tests/simple/static_checks.py instead.
- Numerus messages (qsTr("%n item(s)", "", n)) get one <numerusform> per plural form of the
  language (1 for ko / vi / ja, 2 for de / da / pt_BR). A plain translation is copied into each form
  (it already uses %n) and kept finished.
No third-party packages needed.
"""
import os, re, subprocess, sys, tempfile
import xml.etree.ElementTree as ET

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
CORE_CTX = ('FlyView', 'MainRootWindow', 'FlightZoneManager')
PLURAL_FORMS = {'ko': 1, 'vi': 1, 'ja': 1, 'zh': 1, 'de': 2, 'da': 2, 'pt': 2, 'en': 2, 'fr': 2}


def reference(lupdate):
    tmp = tempfile.mkdtemp()
    ref = os.path.join(tmp, 'ref.ts')
    with open(ref, 'w', encoding='utf-8') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<!DOCTYPE TS>\n<TS version="2.1"></TS>\n')
    subprocess.run([lupdate, '-silent', '-locations', 'none', os.path.join(ROOT, 'custom', 'res', 'Simple'),
                    '-ts', ref], check=True)
    out = []        # [(context, [(source, numerus)])]
    simple = os.path.join(ROOT, 'custom', 'res', 'Simple')
    for ctx in ET.parse(ref).getroot().findall('context'):
        # qsTranslate("LogDownloadController", …) only compares with the core translation: not ours
        if not os.path.isfile(os.path.join(simple, ctx.findtext('name') + '.qml')):
            continue
        out.append((ctx.findtext('name'),
                    [(m.findtext('source'), m.get('numerus') == 'yes') for m in ctx.findall('message')]))
    return out


def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


class Msg:
    def __init__(self, source, numerus=False, forms=None, kind=None, tcomment=None):
        self.source, self.numerus, self.forms, self.kind, self.tcomment = source, numerus, forms or [''], kind, tcomment

    @staticmethod
    def parse(m):
        tr = m.find('translation')
        nf = tr.findall('numerusform') if tr is not None else []
        forms = [f.text or '' for f in nf] if nf else [(tr.text or '') if tr is not None else '']
        return Msg(m.findtext('source'), m.get('numerus') == 'yes', forms,
                   tr.get('type') if tr is not None else 'unfinished', m.findtext('translatorcomment'))

    def lines(self):
        out = ['    <message%s>' % (' numerus="yes"' if self.numerus else ''),
               '        <source>%s</source>' % esc(self.source)]
        if self.tcomment:
            out.append('        <translatorcomment>%s</translatorcomment>' % esc(self.tcomment))
        kind = ' type="%s"' % self.kind if self.kind else ''
        if self.numerus:
            out.append('        <translation%s>' % kind)
            out += ['            <numerusform>%s</numerusform>' % esc(f) for f in self.forms]
            out.append('        </translation>')
        else:
            out.append('        <translation%s>%s</translation>' % (kind, esc(self.forms[0])))
        out.append('    </message>')
        return out


def sync(path, ref):
    raw = open(path, 'rb').read()
    eol = '\r\n' if b'\r\n' in raw else '\n'
    root = ET.fromstring(raw)
    lang = root.get('language', '')
    nforms = PLURAL_FORMS.get(lang.split('_')[0], 2)
    have = [(c.findtext('name'), [Msg.parse(m) for m in c.findall('message')]) for c in root.findall('context')]
    refmap = {name: dict(msgs) for name, msgs in ref}
    stats = dict(added=0, removed=0, numerus=0)
    result = []
    for name, msgs in have:
        if name in CORE_CTX:
            result.append((name, msgs))
            continue
        want = refmap.get(name, {})
        keep = []
        for m in msgs:
            if m.source not in want:
                stats['removed'] += 1
                continue
            if want[m.source] and not m.numerus:
                m.numerus = True
                m.forms = [m.forms[0]] * nforms
                stats['numerus'] += 1
            elif m.numerus and len(m.forms) != nforms:
                m.forms = (m.forms + [m.forms[-1]] * nforms)[:nforms]
            if m.kind in ('vanished', 'obsolete'):
                m.kind = None if all(f.strip() for f in m.forms) else 'unfinished'
            keep.append(m)
        result.append((name, keep))
    index = {name: msgs for name, msgs in result}
    for name, msgs in ref:
        if name not in index:
            index[name] = []
            result.append((name, index[name]))
        known = {m.source for m in index[name]}
        for src, num in msgs:
            if src not in known:
                index[name].append(Msg(src, num, [''] * (nforms if num else 1), 'unfinished'))
                stats['added'] += 1
    lines = ['<?xml version="1.0" encoding="utf-8"?>', '<!DOCTYPE TS>',
             '<TS version="%s" language="%s">' % (root.get('version', '2.1'), lang)]
    for name, msgs in result:
        if not msgs:
            continue
        lines += ['<context>', '    <name>%s</name>' % esc(name)]
        for m in msgs:
            lines += m.lines()
        lines.append('</context>')
    lines.append('</TS>')
    with open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(eol.join(lines) + eol)
    print('%s: %d added, %d removed, %d made numerus' % (os.path.basename(path), stats['added'],
                                                          stats['removed'], stats['numerus']))


def main(lupdate, *files):
    ref = reference(lupdate)
    for f in files:
        sync(f, ref)


if __name__ == '__main__':
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(*sys.argv[1:])
