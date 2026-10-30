# Working on The King's Court

A cooperative trick-taking card game in Flutter (web first). Sam owns it;
`README.md` is the map of the code, `docs/` the deeper notes. This file is
the working rules: read it before changing anything.

## The one rule

**Behaviour must not change unless it's meant to**, and every change is
proved by CI, not by reading. A commit that changes what the player sees
or how a round plays, on purpose, is written up in `docs/DECISIONS.md`
with the screenshots it explains (`tool/shots/expected_changes.txt`).

## Performance comes first

The game must hold **60 frames a second on a phone, in the installed
web app, on every screen**. A change that drops frames is a red commit:
fixed before anything else, like a failing test.

- **Every branch** (`try-*`) also runs **Frames** (`frames.yml`): the
  release build in Chrome plays every animated scene
  (`integration_test/frames_test.dart`) and times each frame. Its verdict
  is `budget.txt` on `out-frames-<branch>`, the numbers `frames.txt`. It
  must say "within the frame budget" before main. CI has no GPU, so it
  judges the Dart side: each scene's frame work, and the courtiers'
  thinking (at most one slice between two frames, none over 10 ms),
  which holds on any machine.
- **Real devices** report too: every shared round carries the frames it
  drew (`lib/platform/frame_stats.dart`), and the daily **Reports** run
  (`gh workflow run reports.yml` for one now) writes `frames.txt` on the
  `reports` branch by build and device, with `missed` (dropped frames)
  and the raster times. After a deploy that touches the screen, check the
  new build against the one before it on the same device.
- **What we've learned costs frames**, so don't:
  - run work outside a frame for longer than a slice: anything long is
    split, a slice after each frame (`Bot.breather`);
  - do something heavy (a whole-page rebuild, drawing a picture with
    `toImageSync`) in the middle of an animation: do it before it starts,
    or behind a still (the skin change), or ahead of time
    (`FeltLight.ready`);
  - make new inline widgets in text on every build: a `WidgetSpan` whose
    child isn't the identical widget lays its paragraph out again (use
    `Same`);
  - blur large areas, or animate anything under a big `saveLayer`;
  - clear the browser's performance marks (Flutter's timeline needs them).
- A new animation or screen gets a scene in the frame benchmark.

## How the work runs

- There is usually **no Flutter SDK** in the session: CI is the compiler.
  A push to any branch (except `main` and the result branches) runs
  **Check a branch** (`.github/workflows/check.yml`), about 10 minutes:
  - `test`: `dart analyze --fatal-infos --fatal-warnings` (any output
    fails), `flutter test --exclude-tags tool`, `flutter build web`.
    The tests run with coverage: the total is in `summary.txt`, the
    breakdown by layer and the least-covered files in `coverage.txt` on
    `ci-<branch>` (`tool/coverage.py`).
  - `shots`: takes the 70 screenshots and compares them with the
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
- **Lint fixes without the SDK**: push work in progress to `fix-<name>`
  (`git push origin HEAD:fix-<name>`); **Fix a branch** (`fix.yml`) runs
  `dart fix --apply` and publishes `fix.patch` and the analyzer's findings
  after it to `fixed-<name>`. `git show origin/fixed-<name>:fix.patch |
  git apply`, fix what's left, then commit and push the real branch.
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
- **What to test while the game is still changing fast**: the rules and
  the decisions (engine, game, net, modes: what a move is refused for,
  what a bot may choose), and a widget's behaviour where it's a promise
  (a locked chapter can't be chosen, every skin draws every piece). Not
  layouts or animations: the screenshots cover how things look, and a
  test of a layout only has to be rewritten with it.

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
platform/  Flutter and plugins: settings, sounds, analytics, crash reports,
           build info.
skin/      The look: the Skin interface (skin.dart), the Court skin
           (court/, its values theme.dart's constants, and the Court Card
           art), looks.dart and parts.dart (what a skin's pieces are
           built from), design_skin.dart (a skin from a design), Plain and
           Lacquer, SkinScope and context.skin,
           Entitlements, and the chrome's words (strings.dart).
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
- **A skin**: see `docs/SKINS.md`. Usually a `SkinDesign` in
  `lib/skin/<name>/` (`PlainSkin` is the example), wrapped in a
  `DesignSkin`, added to `skins` in `skin/skins.dart`; the menu's *Look*
  row and the screenshots (`skin-<id>-*`) pick it up. For more, override
  a look (`skin/looks.dart`) or draw a part (`skin/parts.dart`;
  `LacquerSkin` draws its card backs). Widgets read the
  look only through `context.skin` (painters take a `Skin` argument);
  `test/skin_test.dart` fails on a widget naming `Palette`, a font or
  `DialogStyle`. Its screenshots are new files: list them in
  `tool/shots/expected_changes.txt` until the baseline is retaken.
- **A save format change**: bump `saveVersion` in `game/saves.dart`, add
  one migration to `_migrations` there, let CI write the new fixtures
  (`fixtures/` on `ci-<branch>`) and commit them under
  `test/fixtures/saves/v<n>/`; `test/saves_test.dart` loads every version.
- **A big file**: `test/file_size_test.dart` fails on a file over about
  600 lines. Split it; generated art and data go in its `data` list, and a
  file that can't be split yet goes in `debts` at its current length (the
  number only goes down).

## The refactor

Done on branch `refactor` (not merged: Sam merges). `docs/ARCHITECTURE.md`
is the shape it left, `docs/DECISIONS.md` every call made along the way and
every intended behaviour change, with the screenshots each explains.
