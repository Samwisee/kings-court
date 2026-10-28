"""The performance budget: fails when the branch is clearly slower than main.

Reads the bench job's bench-compare.txt (main and the branch, timed twice
each on the same runner) and compares each run's branch against the same
run's main, on the headline numbers: the page's frame after a change to
the game and to the screen only (ms, lower is better), and the bots'
playouts per second at each table size (higher is better). The budget is
broken when a number is at least SLOWER (30%) worse on *both* runs: one
slow run is runner noise, two is the code.

    python3 tool/bench/budget.py out/bench-compare.txt
"""
import re
import sys

SLOWER = 0.30


def parse(text):
    """{(side, run): {metric: value}} from the job's output."""
    runs = {}
    current = None
    for line in text.splitlines():
        head = re.match(r'== (main|branch) \(run (\d+)\)', line)
        if head:
            current = runs.setdefault((head.group(1), int(head.group(2))), {})
            continue
        if current is None:
            continue
        m = re.match(r'a change to the game \(setState\): ([\d.]+) ms', line)
        if m:
            current['frame after a change to the game (ms)'] = ('ms', float(m.group(1)))
        m = re.match(r'a change to the screen only \(_ui\): ([\d.]+) ms', line)
        if m:
            current['frame after a change to the screen (ms)'] = ('ms', float(m.group(1)))
        m = re.match(r'(\d+) players: .*\((\d+) playouts/s\)', line)
        if m:
            current[f'bots, {m.group(1)} players (playouts/s)'] = ('rate', float(m.group(2)))
    return runs


def main(path):
    runs = parse(open(path).read())
    run_numbers = sorted({r for (_, r) in runs})
    if not run_numbers or any(('main', r) not in runs or ('branch', r) not in runs for r in run_numbers):
        print('budget: not every run has both main and the branch; nothing to compare')
        return 0
    metrics = sorted({m for (side, r) in runs for m in runs[(side, r)]})
    broken = []
    for metric in metrics:
        worse_every_run = True
        report = []
        for r in run_numbers:
            main_v = runs[('main', r)].get(metric)
            branch_v = runs[('branch', r)].get(metric)
            if main_v is None or branch_v is None:
                worse_every_run = False
                report.append(f'run {r}: missing')
                continue
            kind, a = main_v
            _, b = branch_v
            if a == 0:
                worse_every_run = False
                continue
            # How much slower the branch is, as a fraction of main.
            slower = (b - a) / a if kind == 'ms' else (a - b) / a
            report.append(f'run {r}: main {a:g}, branch {b:g} ({slower:+.0%})')
            if slower < SLOWER:
                worse_every_run = False
        line = f'{metric}: ' + '; '.join(report)
        print(('BROKEN ' if worse_every_run else 'ok     ') + line)
        if worse_every_run:
            broken.append(metric)
    if broken:
        print(f'budget broken: the branch is {SLOWER:.0%} or more slower than main on every run for: '
              + ', '.join(broken))
        return 1
    print('budget kept')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else 'out/bench-compare.txt'))
