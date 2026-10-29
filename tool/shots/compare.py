#!/usr/bin/env python3
"""Compares a run's screenshots with the baseline, pixel for pixel.

    compare.py <baseline dir> <new dir> <expected changes file> <out dir>

Prints one line per screenshot (same, differs, missing, new) and writes a
diff image for each one that differs (the changed pixels in red over a
faded copy) into <out dir>/diff/. Exits 1 if anything differs, went
missing or is new without a reason in the expected-changes file, whose
lines are `name.png: why`, or `*: why` to explain every difference. A
line `~name.png: why` marks a screenshot that varies from run to run: it
is never compared, and stays listed when the baseline moves.
"""
import os
import sys

from PIL import Image, ImageChops


def main(baseline, new, expected_file, out):
    expected = {}
    unstable = {}
    if os.path.exists(expected_file):
        for line in open(expected_file):
            line = line.strip()
            if not line or line.startswith('#') or ':' not in line:
                continue
            name, why = line.split(':', 1)
            name = name.strip()
            if name.startswith('~'):
                unstable[name[1:]] = why.strip()
            else:
                expected[name] = why.strip()
    diff_dir = os.path.join(out, 'diff')
    os.makedirs(diff_dir, exist_ok=True)
    if not os.path.isdir(new) or not any(f.endswith('.png') for f in os.listdir(new)):
        print('no screenshots were taken (did the test compile?)')
        return 1
    if not os.path.isdir(baseline):
        print('no baseline: nothing to compare')
        return 0
    old = {f for f in os.listdir(baseline) if f.endswith('.png')}
    now = {f for f in os.listdir(new) if f.endswith('.png')}
    unexplained = []
    same = 0
    for name in sorted(old | now):
        if name in unstable and name in now:
            print(f'unstable {name}  [{unstable[name]}]')
            continue
        if name not in now:
            line = f'missing {name}'
        elif name not in old:
            line = f'new     {name}'
        else:
            a = Image.open(os.path.join(baseline, name)).convert('RGBA')
            b = Image.open(os.path.join(new, name)).convert('RGBA')
            if a.size != b.size:
                line = f'differs {name}: size {a.size} -> {b.size}'
            else:
                d = ImageChops.difference(a, b)
                # Every channel: an RGBA image's getbbox() looks at alpha alone.
                box = d.getbbox(alpha_only=False)
                if box is None:
                    same += 1
                    print(f'same    {name}')
                    continue
                mask = d.convert('RGB').convert('L').point(lambda v: 255 if v else 0)
                changed = mask.histogram()[255]
                total = a.size[0] * a.size[1]
                line = (f'differs {name}: {changed} of {total} pixels '
                        f'({100.0 * changed / total:.2f}%), box {box}')
                faded = Image.blend(b, Image.new('RGBA', b.size, (255, 255, 255, 255)), 0.6)
                red = Image.new('RGBA', b.size, (220, 20, 20, 255))
                faded.paste(red, mask=mask)
                faded.save(os.path.join(diff_dir, name))
        why = expected.get(name) or expected.get('*')
        if why:
            line += f'  [expected: {why}]'
        else:
            unexplained.append(name)
        print(line)
    print(f'{same} same, {len(unexplained)} unexplained')
    return 1 if unexplained else 0


if __name__ == '__main__':
    sys.exit(main(*sys.argv[1:5]))
