"""Fetches the rounds people have played from the game's web service
(tool/bug_worker/, GET /rounds) into a JSON-lines file, adding only the
ones not fetched before.

    GAME_SERVICE=https://kings-court-bugs.<you>.workers.dev \\
    READ_KEY=<the worker's READ_KEY> \\
    python3 tool/games/pull.py rounds.jsonl

Each line is {"id", "received", "record"}; the record is what
lib/platform/game_log.dart sends. Keep the file out of the repo.
"""
import json
import os
import sys
import urllib.request


def main(path):
    base = os.environ['GAME_SERVICE'].rstrip('/')
    key = os.environ['READ_KEY']
    after = 0
    if os.path.exists(path):
        with open(path) as f:
            for line in f:
                if line.strip():
                    after = max(after, json.loads(line)['id'])
    got = 0
    with open(path, 'a') as out:
        while True:
            req = urllib.request.Request(f'{base}/rounds?after={after}',
                                         headers={'Authorization': f'Bearer {key}'})
            with urllib.request.urlopen(req, timeout=60) as r:
                lines = [l for l in r.read().decode().splitlines() if l.strip()]
            if not lines:
                break
            for line in lines:
                out.write(line + '\n')
                after = json.loads(line)['id']
            got += len(lines)
    print(f'{got} new rounds, up to id {after}')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'rounds.jsonl')
