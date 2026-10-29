"""Summarises coverage/lcov.info: the whole of lib/, each layer, and the
files least covered.

    python3 tool/coverage.py coverage/lcov.info > out/coverage.txt
"""
import sys
from collections import defaultdict

# Generated art and data, counted apart: lines of numbers, not logic.
DATA = ('.g.dart', 'engine/tasks.dart', 'engine/task_help.dart', 'engine/rules.dart',
        'chronicle/chapters.dart', 'tutorial/lessons.dart', 'dynasty/data/')


def main(path):
    files = {}
    name = None
    for line in open(path):
        line = line.strip()
        if line.startswith('SF:'):
            name = line[3:].split('lib/', 1)[-1]
            files[name] = [0, 0]
        elif line.startswith('DA:') and name:
            hits = int(line[3:].split(',')[1])
            files[name][1] += 1
            if hits > 0:
                files[name][0] += 1
    code = {f: v for f, v in files.items() if not any(d in f for d in DATA)}

    def pct(h, t):
        return 100.0 * h / t if t else 0.0

    def total(group):
        h = sum(v[0] for v in group.values())
        t = sum(v[1] for v in group.values())
        return h, t

    h, t = total(code)
    print(f'lib/ (code): {pct(h, t):.1f}% of {t} lines')
    h, t = total(files)
    print(f'lib/ (with art and data): {pct(h, t):.1f}% of {t} lines')
    print()
    layers = defaultdict(dict)
    for f, v in code.items():
        layers[f.split('/')[0] if '/' in f else f][f] = v
    for layer in sorted(layers):
        h, t = total(layers[layer])
        print(f'{layer:10} {pct(h, t):5.1f}% of {t:5} lines')
    print()
    print('Least covered (code files of 40+ lines):')
    worst = sorted((pct(*v), f, v[1]) for f, v in code.items() if v[1] >= 40)
    for p, f, n in worst[:25]:
        print(f'  {p:5.1f}%  {f} ({n} lines)')


if __name__ == '__main__':
    main(sys.argv[1])
