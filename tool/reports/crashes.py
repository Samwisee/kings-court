"""Crash signatures from Sentry's issues (its API's JSON on stdin): the
exception's type, where it was thrown, how often, and when last seen.
Never the message or anything about the player: these go to a public
branch.

    curl … /api/0/projects/<org>/<project>/issues/ | python3 tool/reports/crashes.py
"""
import json
import sys


def main():
    raw = sys.stdin.read()
    try:
        issues = json.loads(raw)
    except ValueError:
        print('Sentry did not answer with issues:', raw[:200].replace('\n', ' '))
        return
    if not isinstance(issues, list):
        detail = issues.get('detail') if isinstance(issues, dict) else issues
        print('Sentry said:', str(detail)[:200])
        print("(the SENTRY_AUTH_TOKEN secret needs the event:read scope to list crashes)")
        return
    print(f"{len(issues)} crash signatures seen in the last 14 days\n")
    print(f"{'events':>7} {'last seen':<20} {'status':<10} signature")
    for i in sorted(issues, key=lambda i: -int(i.get('count', 0))):
        meta = i.get('metadata') or {}
        kind = meta.get('type') or i.get('type') or 'error'
        where = i.get('culprit') or meta.get('function') or '?'
        print(f"{int(i.get('count', 0)):>7} {str(i.get('lastSeen', ''))[:19]:<20} {i.get('status', ''):<10} {kind} in {where}"[:160])


if __name__ == '__main__':
    main()
