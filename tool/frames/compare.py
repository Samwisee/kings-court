"""The frame benchmark against the runs before it, platform by platform
(the device lab calls this after each run; it works on any two of
tool/devices.sh's run folders too).

    python3 tool/frames/compare.py <this run> <earlier run> [<earlier run>...]

Each scene's drawing (engine p90) and the app's own work (p99) are set
against the earlier runs on the same platform. The same build varies a
lot from run to run on a phone (a scene can be half again slower), so a
scene is worse only when it's slower than every earlier run by a fifth,
and 3 ms or more over their median; a platform is worse when it misses 5
points more of its refreshes than any earlier run. A scene that drew
nothing is worse. Exits 1 when anything got worse.
"""
import json
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from summary import missed as _missed  # noqa: E402

SLOWER = 1.2
AT_LEAST_MS = 3.0
MISSED_POINTS = 5.0


def load(run):
    out = {}
    if not os.path.isdir(run):
        return out
    for p in sorted(os.listdir(run)):
        path = os.path.join(run, p, 'result.json')
        if os.path.exists(path):
            try:
                data = json.load(open(path))
            except ValueError:
                continue
            out[p] = {s['name']: s for s in data.get('scenes', []) if 'in detail' not in s['name']}
    return out


def missed(scenes):
    return _missed(scenes)[2]


def main(now_dir, before_dirs):
    now = load(now_dir)
    before = [load(d) for d in before_dirs]
    worse, better = [], []
    for platform, scenes in now.items():
        earlier = [b[platform] for b in before if platform in b]
        if not earlier:
            print(f"{platform}: nothing earlier to compare with")
            continue
        m_now = missed(scenes)
        m_all = [missed(e) for e in earlier]
        m_before = statistics.median(m_all)
        line = f"{platform}: {m_now:.1f}% of refreshes missed (before: {m_before:.1f}%, over {len(earlier)} runs)"
        if m_now > max(m_all) + MISSED_POINTS:
            worse.append(line)
        elif m_now < min(m_all) - MISSED_POINTS:
            better.append(line)
        for name, s in scenes.items():
            if not s.get('frames') or s.get('error'):
                if any(name in e and e[name].get('frames') for e in earlier):
                    worse.append(f"{platform} · {name[:50]}: drew nothing{' (' + str(s.get('error'))[:80] + ')' if s.get('error') else ''}")
                continue
            for key, what in (('engineP90', 'drawing p90'), ('workP99', 'work p99')):
                old = [e[name][key] for e in earlier if name in e and e[name].get('frames') and key in e[name]]
                if not old or key not in s:
                    continue
                med = statistics.median(old)
                cur = s[key]
                text = f"{platform} · {name[:50]} · {what}: {cur:.1f} ms (before {med:.1f})"
                if cur > max(old) * SLOWER and cur - med >= AT_LEAST_MS:
                    worse.append(text)
                elif cur < min(old) / SLOWER and med - cur >= AT_LEAST_MS:
                    better.append(text)
    print(f"against {len(before_dirs)} earlier run(s)")
    print(f"\nworse ({len(worse)}):" if worse else "\nnothing worse")
    for w in worse:
        print(f"  {w}")
    if better:
        print(f"\nbetter ({len(better)}):")
        for b in better:
            print(f"  {b}")
    return 1 if worse else 0


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1], sys.argv[2:]))
