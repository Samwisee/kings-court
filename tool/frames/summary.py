"""The frame benchmark's platforms side by side (tool/devices.sh): for each
scene, how long a frame took on each, in two numbers.

  draw: the engine's whole frame, its drawing included (90th percentile,
        ms): what the screen waits for. Over the refresh (16.7 ms at
        60 Hz, 11.1 ms at 90 Hz) and frames are dropped.
  work: the app's own work in the frame (99th percentile, ms): building,
        laying out and painting, before the drawing.

    python3 tool/frames/summary.py build/devices/latest android-chrome chrome safari
"""
import json
import os
import sys


def refresh(scenes):
    """The screen's refresh (ms): the shortest any scene kept to. A scene
    that couldn't keep up settles into every second refresh, and its own
    period says 22 ms on a 90 Hz screen; the screen's didn't change."""
    periods = [s['period'] for s in scenes.values() if s.get('period') and s.get('frames')]
    return min(periods) if periods else 16.7


def missed(scenes):
    """(frames, refreshes missed, % missed) over these scenes, against the
    screen's own refresh."""
    screen = refresh(scenes)
    frames = refreshes = 0
    for s in scenes.values():
        if not s.get('frames'):
            continue
        frames += s['frames']
        refreshes += max(s['frames'], round((s['frames'] + s['dropped']) * s['period'] / screen))
    return frames, refreshes - frames, 100 * (refreshes - frames) / max(1, refreshes)


def main(folder, names):
    runs = {}
    for n in names:
        path = os.path.join(folder, n, 'result.json')
        if not os.path.exists(path):
            path = os.path.join(folder, f'{n}.json')
        if os.path.exists(path):
            data = json.load(open(path))
            runs[n] = {s['name']: s for s in (data.get('scenes') or data.get('frames', {}).get('scenes') or [])}
    if not runs:
        print('no runs')
        return
    scenes = []
    for r in runs.values():
        for name in r:
            if name not in scenes and 'in detail' not in name:
                scenes.append(name)
    head = f"{'scene':<56}" + ''.join(f"{n[:22]:>24}" for n in runs)
    print(head)
    print(f"{'':<56}" + ''.join(f"{'draw p90 / work p99':>24}" for n in runs))
    for s in scenes:
        cells = []
        for n, r in runs.items():
            x = r.get(s)
            if not x:
                cells.append(f"{'-':>24}")
                continue
            flag = ' !' if x.get('error') or not x.get('frames') else ''
            cells.append(f"{x.get('engineP90', 0):>10.1f} / {x.get('workP99', 0):>6.1f}{flag:>4}  ")
        print(f"{s[:55]:<56}" + ''.join(cells))
    print()
    for n, r in runs.items():
        frames, missed_, rate = missed(r)
        print(f"{n}: {frames} frames, {missed_} refreshes missed ({rate:.1f}%) at {1000 / refresh(r):.0f} Hz")
    print("\n'!' marks a scene that went wrong or drew nothing (its report says what).")


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2:])
