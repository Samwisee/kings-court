# Decisions made during the refactor

Every call made without asking, newest last, and every change to what the
player sees or how a round plays (those also name the screenshots they
explain, or say none differ). The plan is `docs/REFACTOR_PLAN.md`.

## Step 2: the guards

- **The analyzer had never run in CI.** `flutter analyze --format=machine`
  isn't a flag; the step was silently skipped. Now `dart analyze
  --fatal-infos --fatal-warnings` with strict casts/inference/raw types and
  43 extra lints (`analysis_options.yaml`). 703 findings fixed, none
  silenced; three lints were dropped as noise (`avoid_multiple_declarations_per_line`,
  `prefer_if_elements_to_conditional_expressions`, `use_if_null_to_convert_nulls_to_bools`).
  `main`'s deploy workflow runs the same analysis, so `main` must be clean
  at merge.
- **Tags can't be pushed from here** (403), so `pre-refactor` (main's
  head, f37063a) and `pre-dynasty-removal` (b7f7181) are branches.
- **The screenshot harness is seeded** (`HomePageTestHooks.seed = 7`
  fixes the deals and the courtiers' dice) so every PNG is byte-identical
  run to run; the baseline is branch `shots-baseline` (commit 3791341).
  Screenshots: none differ.
- **The bench compares like for like**: main and the branch, twice each,
  on the same runner. Main's benchmarks live at their old path
  (`tool/bench/`), which the job finds.

## Step 3: the Dynasty removal and the extraction

- **Loyalty candle art kept** (`LoyaltyCandle`, `_CandlePainter` in
  `ui/tokens.dart`) for the roguelike, though nothing draws it now.
- **The setup panel's Dynasty tile stays dimmed** "(Coming soon)"; the
  Powers tile is gone (roles are always on). Screenshots: none differ.
- **Engine fix**: rules judged at the end of the round
  (`'Win the last trick'`) looked at the tricks before there were any and
  crashed on an empty round; they're lazy now. Not reachable from the
  screen before (the page never judged an empty round).

## Step 4: one round record and the modes

- **The King is crowned after the deal**, by the table, from whoever holds
  the King card (`Round.kingCardHolder`); `Round.dealFor` no longer sets
  `king` unless a King reigns already (a re-deal). Same moments on screen.
  Screenshots: none differ.
- **The exiled seat comes from the game's seed** (`dealRandom(2)`) instead
  of an unseeded `Random()`: same odds, replayable. No screenshot shows an
  Exile round.
- **The players are named before the first round is drawn** (the round
  carries the names for "Player 2 won the 3♥"), so the first round's
  record names "The Jester" as the old judge did.
- **`Round.apply` uses the table's full pick rules** (forced tasks, the
  King's Command, passing), not the bots-only shortcut it had. The app's
  page always used the full rules; only the balance and strength tools'
  bots pick a little differently now (more like the app).
- **Seat views keep the set-aside cards** so every device judges the tasks
  the same way; a server judging for everyone could withhold them (Sam
  agreed).
- **Old Dynasty saves don't load** (`GameState.fromJson` returns null for
  them), as decided at checkpoint 1.
- **Step 4d (a real table's marks and undo as actions) is folded into
  step 5**, where every action goes on the link.
- `maxTarget` (the points slider's top, 20) moved from the page to
  `models.dart` next to `minPlayers`/`maxPlayers`.
