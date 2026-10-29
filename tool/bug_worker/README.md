# The game's web service

A Cloudflare Worker that does two things:

- turns "Report a bug" in the game into a GitHub issue labelled `bug`
  and `from-game`, with the whole game state attached;
- keeps every round people play (`POST /rounds`), in a D1 database, for
  balancing the game (`lib/platform/game_log.dart`; turned off with Share
  play data in the menu).

## Set up (once, about 10 minutes)

1. **GitHub token**: GitHub > Settings > Developer settings > Fine-grained
   tokens > Generate. Repository access: only `Samwisee/kings-court`.
   Permissions: Issues, read and write. Copy the token.
2. **Worker**: sign up at dash.cloudflare.com (free). Workers & Pages >
   Create > Create Worker > name it `kings-court-bugs` > Deploy > Edit code.
   Replace the code with `worker.js` from this folder and deploy.
3. **Settings**: in the Worker's Settings > Variables and Secrets add
   - `GITHUB_TOKEN`, type Secret: the token from step 1
   - `REPO`, Text: `Samwisee/kings-court`
   - `ALLOW_ORIGIN`, Text: `https://samwisee.github.io`
4. **Tell the game**: copy the Worker's URL
   (`https://kings-court-bugs.<you>.workers.dev`), then in the kings-court
   repo: Settings > Secrets and variables > Actions > Variables > New
   repository variable `BUG_REPORT_URL` = that URL. Re-run the
   "Test and deploy" workflow (or push anything).

Until step 4 is done, the game copies the report for the player to paste
into a message instead.

## Reading a report

The issue holds the game as saved. In a test:

```dart
final j = jsonDecode(reportJson) as Map<String, dynamic>;
final game = GameState.fromJson(Map<String, dynamic>.from(j['state']))!;
```

## Keeping the rounds people play (once, about 10 minutes)

The worker from above, plus a database:

1. **Database**: Cloudflare dashboard > Storage & Databases > D1 > Create
   database, name it `kings-court-rounds`. Open it > Console, paste
   `schema.sql` from this folder and run it.
2. **Bind it**: the Worker > Settings > Bindings > Add > D1 database.
   Variable name `DB`, database `kings-court-rounds`.
3. **A read key**: the Worker > Settings > Variables and Secrets > add
   `READ_KEY`, type Secret, any long random string (keep a copy: it's how
   you fetch the rounds).
4. **The code**: Edit code, replace it with `worker.js` from this folder
   again, Deploy.

Nothing changes in the game or the repo: rounds go to the same URL as bug
reports (`BUG_REPORT_URL`), at `/rounds`. Until the database is bound the
worker answers 503 and the game lets the round go.

D1's free tier (5 GB, 100,000 writes a day) holds a few million rounds.

## Reading the rounds

```
GAME_SERVICE=https://kings-court-bugs.<you>.workers.dev READ_KEY=<key> \
  python3 tool/games/pull.py rounds.jsonl     # only the new ones each time
python3 tool/games/report.py rounds.jsonl     # win rates and the hardest tasks
```

Each record is one round: the deal, every task with its owner and result,
the tricks, every move, which seats were people, the mode and the build,
with no names. A round reads back with `Round.fromJson(record['round'])`.

