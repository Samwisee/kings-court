"""What the rounds people played say about the balance: how often rounds
are won by table size and target, and for each task how often a round
with it is won, how often it fails, and whether people or courtiers held
it when it did.

    python3 tool/games/report.py rounds.jsonl

Reads the file tool/games/pull.py writes. The bots' own report (the
balance branch) plays thousands of rounds; this is what real tables did.
"""
import json
import sys
from collections import defaultdict

COMPLETED, FAILED = 1, 2


def rows(path):
    with open(path) as f:
        for line in f:
            if line.strip():
                yield json.loads(line)['record']


def main(path):
    # Test records (from setting up the service) are left out.
    records = [r for r in rows(path) if r.get('outcome') in ('won', 'lost') and not r.get('test')]
    if not records:
        print('No finished rounds yet.')
        return
    won = sum(r['outcome'] == 'won' for r in records)
    players = len({r.get('player') for r in records})
    print(f'{len(records)} rounds from {players} devices, {100 * won / len(records):.0f}% won')
    print()
    print('WIN RATE BY MODE, TABLE SIZE AND TARGET (on screen / at a real table)')
    table = defaultdict(lambda: [0, 0])
    for r in records:
        key = (r['mode'], r['players'], r['round'].get('target'), 'screen' if r.get('onScreen') else 'table')
        table[key][0] += 1
        table[key][1] += r['outcome'] == 'won'
    for (mode, n, target, where), (count, w) in sorted(table.items(), key=lambda kv: tuple(str(k) for k in kv[0])):
        print(f'  {mode:9} {n}p  target {str(target):>3}  {where:6}  {count:5} rounds  {100 * w / count:3.0f}% won')
    print()
    print('TASKS, HARDEST FIRST: round win rate with it, times dealt, times it failed (held by a person / a courtier)')
    tasks = defaultdict(lambda: {'dealt': 0, 'won': 0, 'failed_person': 0, 'failed_bot': 0})
    for r in records:
        people = set(r.get('people', []))
        for t in r['round']['tasks']:
            s = tasks[t['d']]
            s['dealt'] += 1
            s['won'] += r['outcome'] == 'won'
            if t.get('status') == FAILED:
                s['failed_person' if t.get('owner') in people else 'failed_bot'] += 1
    for name, s in sorted(tasks.items(), key=lambda kv: kv[1]['won'] / kv[1]['dealt']):
        if s['dealt'] < 3:
            continue
        print(f"  {100 * s['won'] / s['dealt']:3.0f}%  {s['dealt']:5}  fail {s['failed_person']:3} / {s['failed_bot']:3}  {name}")


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'rounds.jsonl')
