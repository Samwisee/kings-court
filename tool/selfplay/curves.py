"""Strength curves from the headless runner's rounds (bin/selfplay.dart):
how each task fares as the courtiers get stronger, played on the same
deals at every rung.

    python3 tool/selfplay/curves.py selfplay/rounds.jsonl
    python3 tool/selfplay/curves.py selfplay/rounds.jsonl --people rounds.jsonl

What it reports:
  - how often each rung wins, overall and by table size;
  - each task's completion rate at each rung (when someone took it), and
    how much that swings with skill: a task that's hard at every rung is
    just hard; one that swings is easy for strong players and hard for
    new ones; one that gets harder as the courtiers get better is worth a
    look;
  - adaptive thinking's worth: the usual courtiers against the same
    courtiers without it ('fixed'), on the same deals, if both were run;
  - with --people (the rounds players shared, tool/games/pull.py): where
    people sit on the ladder, by how often they win and how their tasks
    go;
  - with selfplay/disagreements.jsonl beside the rounds: where the fair
    courtiers and an all-seeing one chose differently.

Only seeds played at every rung are counted, so every rung is compared on
the same deals.
"""
import json
import os
import sys
from collections import defaultdict

ORDER = ['weak', 'casual', 'usual', 'fixed', 'strong', 'seeing']
FAIR = ['weak', 'casual', 'usual', 'strong']


def read(path):
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                yield json.loads(line)


def pct(a, b):
    return f"{100 * a / b:5.1f}%" if b else '    -'


def main(args):
    path = args[0]
    people = args[args.index('--people') + 1] if '--people' in args else None
    by_seed = defaultdict(dict)
    for r in read(path):
        sp = r.get('selfplay')
        if sp:
            by_seed[sp['seed']][sp['rung']] = r
    rungs = [r for r in ORDER if any(r in v for v in by_seed.values())]
    seeds = [s for s, v in by_seed.items() if all(r in v for r in rungs)]
    print(f"{len(seeds)} deals played at every rung ({', '.join(rungs)})\n")
    if not seeds:
        return

    # How often each rung wins, overall and by table size.
    print('== rounds won ==')
    print(f"{'':10}" + ''.join(f"{r:>9}" for r in rungs))
    sizes = sorted({by_seed[s][rungs[0]]['players'] for s in seeds})
    for size in [None] + sizes:
        these = [s for s in seeds if size is None or by_seed[s][rungs[0]]['players'] == size]
        label = 'all' if size is None else f'{size} players'
        row = ''.join(f"{pct(sum(by_seed[s][r]['outcome'] == 'won' for s in these), len(these)):>9}" for r in rungs)
        print(f"{label:10}{row}   ({len(these)} deals)")

    # Each task's completion by rung.
    done = defaultdict(lambda: defaultdict(lambda: [0, 0]))
    for s in seeds:
        for r in rungs:
            for t in by_seed[s][r]['selfplay']['tasks']:
                if t['owner'] is None:
                    continue
                c = done[t['d']][r]
                c[1] += 1
                c[0] += 1 if t['done'] else 0
    fair = [r for r in FAIR if r in rungs]
    rows = []
    for task, by in done.items():
        rates = {r: by[r][0] / by[r][1] for r in rungs if by[r][1] >= 5}
        if len(rates) < 2:
            continue
        lo, hi = (fair[0], fair[-1]) if len(fair) >= 2 else (rungs[0], rungs[-1])
        swing = rates.get(hi, 0) - rates.get(lo, 0) if lo in rates and hi in rates else 0
        rows.append((task, rates, swing, sum(by[r][1] for r in rungs)))
    print('\n== each task, done when taken, by rung (most swing with skill first) ==')
    print(f"{'':58}" + ''.join(f"{r:>8}" for r in rungs) + '   swing   note')
    for task, rates, swing, n in sorted(rows, key=lambda x: -abs(x[2])):
        usual = rates.get('usual', rates.get(rungs[len(rungs) // 2], 0))
        note = ('harder for better players' if swing < -0.05 else
                'swings with skill' if swing > 0.3 else
                'hard at every rung' if max(rates.values()) < 0.5 else '')
        cells = ''.join(f"{100 * rates[r]:7.0f}%" if r in rates else '       -' for r in rungs)
        print(f"{task[:57]:58}{cells}   {swing:+.2f}   {note}  (n={n}, usual {100 * usual:.0f}%)")

    # Adaptive thinking against fixed, on the same deals.
    if 'usual' in rungs and 'fixed' in rungs:
        a = sum(by_seed[s]['usual']['outcome'] == 'won' and by_seed[s]['fixed']['outcome'] != 'won' for s in seeds)
        b = sum(by_seed[s]['fixed']['outcome'] == 'won' and by_seed[s]['usual']['outcome'] != 'won' for s in seeds)
        effort = lambda r: sum(by_seed[s][r]['selfplay']['effort'] for s in seeds) / max(1, sum(by_seed[s][r]['selfplay']['decisions'] for s in seeds))
        print('\n== adaptive thinking (usual) against fixed, same deals ==')
        print(f"usual won {a} deals fixed lost; fixed won {b} usual lost "
              f"({'usual better' if a > b else 'fixed better' if b > a else 'even'}; "
              f"{'a real difference' if (a - b) ** 2 / max(1, a + b) > 3.84 else 'within the noise'})")
        print(f"thinking spent a decision, against the budget: usual {effort('usual'):.2f}, fixed {effort('fixed'):.2f}")

    # How the thinking went.
    print('\n== the courtiers\' decisions ==')
    for r in rungs:
        d = sum(by_seed[s][r]['selfplay']['decisions'] for s in seeds)
        c = sum(by_seed[s][r]['selfplay']['close'] for s in seeds)
        cl = sum(by_seed[s][r]['selfplay']['clear'] for s in seeds)
        ms = sum(by_seed[s][r]['selfplay']['ms'] for s in seeds) / len(seeds)
        print(f"{r:8} {d / len(seeds):5.1f} decisions a round, {pct(c, d)} close calls, {pct(cl, d)} clear early, {ms / 1000:.1f} s a round")

    # People against the ladder.
    if people:
        won = total = 0
        task_people = defaultdict(lambda: [0, 0])
        for row in read(people):
            rec = row.get('record', row)
            if rec.get('platform') == 'selfplay' or not rec.get('people') or not rec.get('onScreen'):
                continue
            total += 1
            won += rec.get('outcome') == 'won'
            for t in rec.get('round', {}).get('tasks', []):
                if t.get('owner') is None or t.get('status') == 0:
                    continue
                c = task_people[t['d']]
                c[1] += 1
                c[0] += 1 if t.get('status') == 1 else 0
        print(f"\n== people: {total} rounds on screen ==")
        if total:
            rate = won / total
            print(f"won {100 * rate:.0f}%")
            dist = []
            for r in fair:
                rr = sum(by_seed[s][r]['outcome'] == 'won' for s in seeds) / len(seeds)
                diffs = [abs(task_people[t][0] / task_people[t][1] - done[t][r][0] / done[t][r][1])
                         for t in task_people if task_people[t][1] >= 3 and done[t][r][1] >= 5]
                profile = sum(diffs) / len(diffs) if diffs else None
                dist.append((abs(rr - rate), r, rr, profile, len(diffs)))
                print(f"  {r:8} wins {100 * rr:5.1f}%"
                      + (f", tasks differ by {100 * profile:.0f} points on average over {len(diffs)} tasks" if profile is not None else ''))
            nearest = min(dist)
            print(f"nearest rung by rounds won: {nearest[1]}"
                  + (' (few rounds yet: a rough guide)' if total < 100 else ''))

    # Where the fair courtiers and an all-seeing one disagree.
    taught = os.path.join(os.path.dirname(path) or '.', 'disagreements.jsonl')
    if os.path.exists(taught):
        rows = list(read(taught))
        print(f"\n== disagreements with an all-seeing courtier: {len(rows)} ==")
        by_rung = defaultdict(int)
        by_trick = defaultdict(int)
        close = sum(1 for d in rows if d.get('close'))
        for d in rows:
            by_rung[d['rung']] += 1
            by_trick[d['trick']] += 1
        print('by rung: ' + ', '.join(f"{r} {by_rung[r]}" for r in ORDER if r in by_rung))
        print(f"on close calls: {pct(close, len(rows))}")
        print('by trick: ' + ', '.join(f"{t + 1}: {n}" for t, n in sorted(by_trick.items())))


if __name__ == '__main__':
    main(sys.argv[1:])
