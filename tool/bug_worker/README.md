# The game's web service

A Cloudflare Worker that does two things:

- turns "Report a bug" in the game into a GitHub issue labelled `bug`
  and `from-game`, with the whole game state attached;
- keeps every round people play (`POST /rounds`), in a D1 database, for
  balancing the game (`lib/platform/game_log.dart`; turned off with Share
  play data in the menu).

## Set up (once)

CI deploys the worker (`.github/workflows/service.yml`, on any push to
`main` that touches this folder, or by hand from the Actions tab): it
makes the D1 database the first time, creates its tables (`schema.sql`),
sets the secrets and checks the worker answers. Its result is
`status.txt` on the `service` branch. What it needs, as repository
secrets (Settings > Secrets and variables > Actions > Secrets):

| Secret | What |
|---|---|
| `CLOUDFLARE_API_TOKEN` | A Cloudflare API token that can edit Workers and D1 |
| `CLOUDFLARE_ACCOUNT_ID` | The Cloudflare account it deploys to |
| `ISSUES_TOKEN` | A GitHub fine-grained token: this repo only, Issues read and write (bug reports) |
| `ROUNDS_READ_KEY` | Any long random string (reading the rounds back) |

and one repository variable (the Variables tab), `BUG_REPORT_URL`: the
worker's URL from `status.txt`, which the game's build sends reports and
rounds to.

## Reading a report

The issue holds the game as saved. In a test:

```dart
final j = jsonDecode(reportJson) as Map<String, dynamic>;
final game = GameState.fromJson(Map<String, dynamic>.from(j['state']))!;
```

## Reading the rounds

```
GAME_SERVICE=<BUG_REPORT_URL> READ_KEY=<ROUNDS_READ_KEY> \
  python3 tool/games/pull.py rounds.jsonl     # only the new ones each time
python3 tool/games/report.py rounds.jsonl     # win rates and the hardest tasks
```

Each record is one round: the deal, every task with its owner and result,
the tricks, every move, which seats were people, the mode and the build,
with no names. A round reads back with `Round.fromJson(record['round'])`.

