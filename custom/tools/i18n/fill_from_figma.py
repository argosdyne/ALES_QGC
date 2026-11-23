#!/usr/bin/env python3
"""Fill a Simple UI .ts file with translations from the Figma string table.

Usage:
  python custom/tools/i18n/fill_from_figma.py custom/i18n/figma_strings.json translations/qgc_simple_de_DE.ts de

- Only empty, unfinished messages are filled. Finished translations are never changed.
- Exact match (after whitespace / quote normalisation) -> finished translation.
- Source with %1, %2 ... and a Figma example (e.g. "87% · enough for about %1 min" vs
  "87% · enough for about 21 min") -> draft, left "unfinished" with a translator comment.
- Language keys in figma_strings.json: vi, de, da, pt (pt-BR), ja.
Run it again after every lupdate. No third-party packages needed.
"""
import json, re, sys, unicodedata
import xml.etree.ElementTree as ET

PH = re.compile(r'%(L?\d+)')


def norm(s):
    s = unicodedata.normalize('NFC', s or '')
    s = s.replace('’', "'").replace('‘', "'").replace('“', '"').replace('”', '"')
    return re.sub(r'\s+', ' ', s).strip()


def main(table_path, ts_path, lang):
    rows = json.load(open(table_path, encoding='utf-8'))
    exact = {norm(r['en']): r[lang] for r in rows}
    examples = [(norm(r['en']), r[lang]) for r in rows]
    tree = ET.parse(ts_path)
    root = tree.getroot()
    n_exact = n_draft = n_left = 0
    for msg in root.iter('message'):
        tr = msg.find('translation')
        if tr is None or tr.get('type') not in ('unfinished',) or (tr.text or '').strip():
            continue
        src = norm(msg.findtext('source'))
        if src in exact:
            tr.text = exact[src]
            del tr.attrib['type']
            n_exact += 1
            continue
        if PH.search(src):
            parts = PH.split(src)
            names = ['%' + p for p in parts[1::2]]
            rx = re.compile('^' + ''.join(re.escape(p) if i % 2 == 0 else '(.+?)'
                                          for i, p in enumerate(parts)) + '$')
            for en, cand in examples:
                m = rx.match(en)
                if not m:
                    continue
                ok = True
                for val, name in zip(m.groups(), names):
                    if cand.count(val) != 1:
                        ok = False
                        break
                    cand = cand.replace(val, name)
                if ok and all(nm in cand for nm in names):
                    tr.text = cand
                    tc = ET.Element('translatorcomment')
                    tc.text = 'Draft from Figma example "%s" - review' % en
                    msg.insert(list(msg).index(tr), tc)
                    n_draft += 1
                    break
            else:
                n_left += 1
        else:
            n_left += 1
    xml = ET.tostring(root, encoding='unicode')
    with open(ts_path, 'w', encoding='utf-8') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<!DOCTYPE TS>\n' + xml + '\n')
    print('%s: %d exact, %d drafts, %d still empty' % (ts_path, n_exact, n_draft, n_left))


if __name__ == '__main__':
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
