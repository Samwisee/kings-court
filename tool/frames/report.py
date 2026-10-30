"""frames.txt from the frame benchmark's build/frames.json.

One line a scene: how many frames, how many refreshes went by with no new
frame (dropped), the longest wait for one, and how long a frame's work took
(median, 90th and 99th percentile, slowest), with how many frames took
over 8 ms (a phone, two to four times slower, would miss its refresh) and
over 16 ms (missed here).

    python3 tool/frames/report.py build/frames.json
"""
import json
import sys


def main(path):
    data = json.load(open(path))
    scenes = data.get('scenes') or data.get('frames', {}).get('scenes') or []
    print(f"{'scene':<58} {'frames':>6} {'dropped':>7} {'gap ms':>7}  work ms: {'p50':>5} {'p90':>5} {'p99':>5} {'max':>6}  {'>8':>4} {'>16':>4}")
    total_frames = total_dropped = 0
    for s in scenes:
        total_frames += s['frames']
        total_dropped += s['dropped']
        print(f"{s['name'][:58]:<58} {s['frames']:>6} {s['dropped']:>7} {s['worstGap']:>7.1f}"
              f"           {s['workP50']:>5.1f} {s['workP90']:>5.1f} {s['workP99']:>5.1f} {s['workMax']:>6.1f}"
              f"  {s['over8']:>4} {s['over16']:>4}   slowest {s['slowest']}"
              + ''.join(f"\n    slow frame {x}" for x in s.get('slow', []))
              + (f"\n    ERROR {s['error']}" if s.get('error') else '')
              + (f"  engine p90 {s['engineP90']:.1f} max {s['engineMax']:.1f}" if s.get('engineMax') else ''))
    pct = 100 * total_dropped / max(1, total_frames + total_dropped)
    print(f"\nin all: {total_frames} frames drawn, {total_dropped} refreshes missed ({pct:.1f}%)")


if __name__ == '__main__':
    main(sys.argv[1])
