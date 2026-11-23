# Collect qt_attribution.json entries from Qt 5.15.2 sources for the modules alesQGC ships.
import json, urllib.request, sys, os, re, time

TAG = 'v5.15.2'
REPOS = ['qtbase', 'qtdeclarative', 'qtlocation', 'qtquickcontrols2', 'qtsvg', 'qtimageformats',
         'qtmultimedia', 'qtcharts', 'qtspeech', 'qtserialport', 'qtgraphicaleffects', 'qtquickcontrols']
# Not shipped on Windows / Android builds of alesQGC
SKIP = re.compile(r'(xcb|wayland|cocoa|macos|/mac/|darwin|dbus|atspi|xkb|/x11|libinput|evdev|tests?/|examples?/|'
                  r'doc/|/3rdparty/assimp|/wasm/|gradle|testlib|qtwebengine|valgrind|cycle|linuxperf|v8|wintab)', re.I)
out_dir = sys.argv[1]
cache = os.path.join(out_dir, 'cache'); os.makedirs(cache, exist_ok=True)

def get(url):
    fn = os.path.join(cache, re.sub(r'[^A-Za-z0-9._-]', '_', url)[-180:])
    if os.path.exists(fn):
        return open(fn, 'rb').read()
    req = urllib.request.Request(url, headers={'User-Agent': 'license-notice-script'})
    data = urllib.request.urlopen(req, timeout=60).read()
    open(fn, 'wb').write(data)
    return data

entries = []
for repo in REPOS:
    try:
        tree = json.loads(get('https://api.github.com/repos/qt/%s/git/trees/%s?recursive=1' % (repo, TAG)))
    except Exception as e:
        print('tree fail', repo, e); continue
    paths = [t['path'] for t in tree.get('tree', []) if t['path'].endswith('qt_attribution.json')]
    for p in paths:
        if SKIP.search(p):
            continue
        raw = 'https://raw.githubusercontent.com/qt/%s/%s/%s' % (repo, TAG, p)
        try:
            d = json.loads(get(raw).decode('utf-8', 'replace'), strict=False)
        except Exception as e:
            print('json fail', p, e); continue
        for item in (d if isinstance(d, list) else [d]):
            if item.get('QtUsage', '').lower().startswith('not used'):
                continue
            lic_text = ''
            lf = item.get('LicenseFile')
            if lf:
                base = os.path.dirname(p)
                lp = os.path.normpath(os.path.join(base, lf)).replace('\\', '/')
                try:
                    lic_text = get('https://raw.githubusercontent.com/qt/%s/%s/%s' % (repo, TAG, lp)).decode('utf-8', 'replace')
                except Exception as e:
                    lic_text = ''
                    print('license fail', lp, e)
            entries.append({'repo': repo, 'path': p, 'name': item.get('Name', ''), 'version': item.get('Version', ''),
                            'license': item.get('License', ''), 'copyright': item.get('Copyright', ''),
                            'text': lic_text})
json.dump(entries, open(os.path.join(out_dir, 'qt_attr.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(len(entries))
for e in entries:
    print('%-16s %-55s %-12s %s %s' % (e['repo'], e['name'][:55], e['version'][:12], e['license'][:50], 'TEXT' if e['text'] else 'NO-TEXT'))
