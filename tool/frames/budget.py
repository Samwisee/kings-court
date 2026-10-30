"""The frame budget: fails when a scene of the frame benchmark does more
work a frame than it may (build, layout and paint, on the CI machine,
which is two to four times faster than a phone).

The limits are for the scenes players spend their time in, set with room
to spare over what they measure now, so runner noise passes and a real
slowdown (a change that makes every move lay out the whole table again)
doesn't. Raster time isn't judged: CI has no GPU.

    python3 tool/frames/budget.py build/frames.json
"""
import json
import sys

# scene name starts with -> (most frames over 16 ms, longest frame in ms)
BUDGET = {
    'setup': (6, 60),
    'walk in': (12, 150),
    'picking tasks: tasks flying': (6, 40),
    'tricks: cards played': (6, 40),
    'the card tracker': (2, 30),
    'the rest of the round': (4, 40),
    'the menu opening': (2, 30),
    'the Livery page': (8, 120),
}


def main(path):
    data = json.load(open(path))
    scenes = data.get('scenes') or data.get('frames', {}).get('scenes') or []
    broken = []
    for prefix, (most_over, longest) in BUDGET.items():
        found = [s for s in scenes if s['name'].startswith(prefix)]
        if not found:
            broken.append(f"{prefix}: not measured")
            continue
        s = found[0]
        if s.get('error'):
            broken.append(f"{prefix}: {s['error'][:120]}")
        if s['over16'] > most_over:
            broken.append(f"{prefix}: {s['over16']} frames over 16 ms (budget {most_over})")
        if s['workMax'] > longest:
            broken.append(f"{prefix}: a {s['workMax']:.0f} ms frame (budget {longest} ms)")
    if broken:
        for b in broken:
            print(f"::error::Frame budget: {b}")
        print('\nover budget:\n  ' + '\n  '.join(broken))
        sys.exit(1)
    print('within the frame budget')


if __name__ == '__main__':
    main(sys.argv[1])
