"""How smoothly the game draws on players' devices, from the rounds they
shared (tool/games/pull.py's JSON lines; each record's "frames", from
lib/platform/frame_stats.dart). Counts only: by build, and for the newest
builds by kind of device and by where the player was (the table, the
Livery page, the menus).

    python3 tool/reports/frames.py rounds.jsonl
"""
import json
import sys
from collections import defaultdict

PLACES = ('table', 'table thinking', 'livery', 'livery thinking', 'menus')
BUCKETS = ['<4', '<8', '<12', '<16', '<25', '<33', '<50', '<100', '100+']


def new():
    return {'rounds': 0, 'frames': 0, 'late': 0, 'missed': 0, 'worst': [], 'build': [0] * 9, 'raster': [0] * 9}


def add(into, c):
    into['frames'] += c.get('frames', 0)
    into['late'] += c.get('late', 0)
    into['missed'] += c.get('missed', 0)
    into['worst'].append(c.get('worst', 0))
    for k in ('build', 'raster'):
        for i, n in enumerate(c.get(k, [])[:9]):
            into[k][i] += n


def line(name, s):
    late = 100 * s['late'] / max(1, s['frames'])
    worst = sorted(s['worst'])
    p90 = worst[int(len(worst) * 0.9)] if worst else 0
    missed = 100 * s['missed'] / max(1, s['frames'] + s['missed'])
    return (f"{name:<44} {s['rounds']:>6} {s['frames']:>9} {late:>6.1f}% {missed:>6.1f}% {p90:>9.0f}  "
            f"build {' '.join(str(n) for n in s['build'])}  raster {' '.join(str(n) for n in s['raster'])}")


def main(path):
    by_build = defaultdict(new)
    by_device = defaultdict(new)
    builds = []
    total = 0
    for row in open(path):
        if not row.strip():
            continue
        rec = json.loads(row).get('record', {})
        f = rec.get('frames')
        total += 1
        if not f:
            continue
        build = rec.get('build') or '?'
        if build not in builds:
            builds.append(build)
        for place in PLACES:
            if place in f:
                by_build[(build, place)]['rounds'] += 1
                add(by_build[(build, place)], f[place])
                by_device[(build, f.get('device', '?'), place)]['rounds'] += 1
                add(by_device[(build, f.get('device', '?'), place)], f[place])
    with_frames = len({b for b, _ in by_build})
    print(f"{total} rounds shared, {sum(s['rounds'] for (b, p), s in by_build.items() if p == 'table')} with the table's frame counts")
    print("late: frames whose build and raster together took longer than the screen's refresh")
    print("missed: refreshes that went by with no new frame while the screen was moving (dropped frames)")
    print("'thinking': frames drawn while a courtier was thinking")
    print("worst p90: the slowest frame of a round, 90th percentile across rounds (ms)")
    print(f"buckets (ms): {' '.join(BUCKETS)}\n")
    head = f"{'':<44} {'rounds':>6} {'frames':>9} {'late':>7} {'missed':>7} {'worst p90':>9}"
    print('== by build (newest last) ==')
    print(head)
    for b in builds[-8:]:
        for place in PLACES:
            if (b, place) in by_build:
                print(line(f'{b} {place}', by_build[(b, place)]))
    print('\n== the newest three builds, by device ==')
    print(head)
    recent = set(builds[-3:])
    for key in sorted(k for k in by_device if k[0] in recent):
        print(line(f'{key[0]} {key[1]} {key[2]}', by_device[key]))
    if not with_frames:
        print('(no rounds with frame counts yet: they start with the build that sends them)')


if __name__ == '__main__':
    main(sys.argv[1])
