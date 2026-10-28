# Working on The King's Court

A cooperative trick-taking card game in Flutter (web first). Sam owns it;
`README.md` is the map of the code, `docs/` the deeper notes. This file is
the working rules: read it before changing anything.

## The one rule

**Behaviour must not change unless it's meant to**, and every change is
proved by CI, not by reading. A commit that changes what the player sees
or how a round plays, on purpose, is written up in `docs/DECISIONS.md`
with the screenshots it explains (`tool/shots/expected_changes.txt`).

## How the work runs

- There is usually **no Flutter SDK** in the session: CI is the compiler.
  A push to any branch (except `main` and the result branches) runs
  **Check a branch** (`.github/workflows/check.yml`), about 10 minutes:
  - `test`: `dart analyze --fatal-infos --fatal-warnings` (any output
    fails), `flutter test --exclude-tags tool`, `flutter build web`.
  - `shots`: takes the 66 screenshots and compares them with the
    `shots-baseline` branch; fails on any difference not listed in
    `tool/shots/expected_changes.txt`.
  - `bench`: times main and the branch, twice each, on the same runner;
    fails when the branch is 30% or more slower on both runs
    (`tool/bench/budget.py`; its verdict is `budget.txt` on `bench-<branch>`).
- **Reading a run** without the SDK (replace `refactor` with the branch):
  ```
  gh run list -L 1 --json status,conclusion,headSha
  git fetch origin ci-refactor shots-refactor bench-refactor
  git show origin/ci-refactor:summary.txt        # analyzer count, last test lines
  git show origin/ci-refactor:analyze.txt | awk -F'|' 'NF>=8 {print $4":"$5" "$3" "$8}'
  git show origin/ci-refactor:test.txt | grep '\[E\]'   # failing tests
  git show origin/shots-refactor:compare.txt | grep -v ^same
  git show origin/bench-refactor:bench-compare.txt
  ```
  A screenshot's red-overlay diff is `diff/<name>.png` on `shots-<branch>`.
- **Every pushed commit is green** (analyzer 0, tests, screenshots). Small
  commits: one sub-step each. A red commit is fixed before anything else.
- **Commit messages**: one plain sentence, under about fifteen words, of
  what changed. Author: `git -c user.name=Claude -c user.email=noreply@anthropic.com`.
- Work on a branch; **never merge or push to `main`** unless Sam says so.
  `main` deploys the live game (`deploy.yml`, also strict analysis).
- Tags can't be pushed from a cloud session (403): `pre-refactor` and
  `pre-dynasty-removal` are branches marking those commits.
- **Moving the screenshot baseline**: once a run's differences are all
  explained, push that run's `shots-<branch>` content to `shots-baseline`
  and clear `expected_changes.txt`.
- Tool runs (`test/tool/`, tagged `tool`) are not part of the test run:
  screenshots, benchmarks, the bot strength and balance reports.

## The layers

Each folder under `lib/` may import only itself and the folders before it
in this list. `test/layers_test.dart` reads every import and fails on one
pointing the wrong way, and on Flutter in the pure-Dart layers.

```
engine/    Pure Dart. Cards, the task library and rules, conflicts, the
           deal mix, the Round (THE record of a round: deal, tasks and
           owners, tricks, shown cards, statuses, seals, decree, result;
           its actions, problem() and apply()), inference, sampling, the
           bots, the Trial of Hearts.
game/      Pure Dart. GameState (state.dart: players, seed, target, mode,
           the round, counters, saving), its actions, the dice, the dealer,
           the judge's views, the host that runs the courtiers, the
           courtiers' houses.
net/       Pure Dart. Where moves go: the table link (local now, a server
           later), the fake network, replay, rooms.
modes/     Pure Dart. One folder per way to play: how a round is set up,
           what the courtiers are told, what a result means. The Chronicle's
           chapters, the tutorial's lessons and the old Dynasty's story are
           data here.
platform/  Flutter and plugins: sounds, analytics, crash reports, build info.
skin/      Flutter. The look: theme.dart (palette, fonts, dialogs, buttons)
           and the Court Card art.
ui/        Flutter. Widgets and screens: they draw state and send actions.
           app.dart, table_page.dart (the one page) and controller.dart,
           then one folder per family of pieces (widgets/, cards/,
           overlays/, dialogs/, round_table/, table/, setup/, menu/…).
main.dart  runApp.
```

Every file is in its layer's folder and no import points the wrong way;
the layers test's `legacy` and `knownDebts` lists are empty and stay so.

## How a round runs (where to look)

- A game starts with `GameState.startRound` (tasks drawn to the target,
  seals and decree from the mode's `RoundSetup`); `game/dealer.dart` deals
  the cards from the game's seed; the table crowns the King card's holder.
- Every move within a round is a `MatchAction` applied by `Round.apply`
  (`Round.problem` says why one isn't allowed). On screen the page sends
  each move through the `TableLink` and applies it when it comes back; a
  server does the same for every device.
- The courtiers' moves come from `game/host.dart` and `game/bot_turn.dart`
  (what they do) with the page keeping only its own pauses (animations).
  The bots in `engine/bot.dart` play fair: a bot sees its own hand and
  what's public, and imagines the rest (`sampling.dart`).
- Judging is `Round.judge` (seal order, why a task failed); the page turns
  the flips into card animations.
- The result (`RoundResult`) goes to the mode's `afterRound` (crowns, the
  next target); the page shows the outcome card.

## Recipes

- **A task**: see `docs/adding-tasks.md` (words and points in
  `engine/tasks.dart`, its rule in `engine/rules.dart`, plain words in
  `task_help.dart`, conflicts in `engine/conflicts.dart`), then run the
  balance tool.
- **A mode**: a `Mode` in `lib/modes/<name>/` (round setup, courtier
  script, afterRound, roundLabel), its data beside it, registered in
  `modes/modes.dart`; its screens under `ui/modes/<name>/`; a case in
  `test/modes_test.dart`.
- **An action**: a `MatchAction` (within a round, `engine/round.dart`) or
  a `GameAction` (the table, `game/actions.dart`) with `toJson`/`fromJson`,
  a `problem` check and an `apply` case; the page sends it through the link
  and never changes state directly. A test of the JSON round trip and of
  `problem`.
- **A skin** (from step 7 of the refactor): a `Skin` in `lib/skin/`,
  every colour, font and asset read through `context.skin`; a screenshot
  set per skin.
- **A save format change**: bump `GameState.saveVersion`, add a migration
  step in `GameState.fromJson`, and a fixture in `test/fixtures/saves/`
  written in the new shape; `test/saves_test.dart` checks every fixture
  still loads and means the same.

## The refactor in progress

`docs/REFACTOR_PLAN.md` is the plan and the order (steps 1–9);
`docs/DECISIONS.md` records every call made along the way and every
intended behaviour change. Branch `refactor`; checkpoints go to Sam in
chat; merge to `main` only when he says.
