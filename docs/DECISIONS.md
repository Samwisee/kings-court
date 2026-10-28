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

## Step 4½: the extras

- **Saves are versioned** (`GameState.saveVersion`, 2 today): a save from
  an older version is migrated one step at a time, as JSON, before it's
  read (`upgradeSave`). Fixtures of every shape ever written live under
  `test/fixtures/saves` (version 1 at the top, `v2/` and on below); CI
  writes the current shape's set (`test/tool/make_saves_test.dart`) and
  the saves test wants a set per version.
- **The bench has a budget**: the branch may not be 30% or more slower
  than main on both runs of any headline number (`tool/bench/budget.py`).
- **Every pushed commit gets its own check run** (`cancel-in-progress`
  off): a newer push no longer cancels the run of the commit before it.

## Step 5: every action on the link

- **Two coupled sub-steps in one commit** (5a actions and `apply`, 5b
  numbered moves): the page can't send actions through a link that
  doesn't carry them, and the sealed action types made a half-way commit
  not compile.
- **The Crown is applied as its flourish lands**, not as the action comes
  back: the table keeps "choosing the King" (no crown on the seat, the
  decree unread, the tasks undealt) while the crown flies, exactly as
  before. Replay and the headless game apply it at once. Screenshots: none
  differ.
- **At a real table the phone is lenient with tasks**: `PickTask` moves a
  task from seat to seat and `ReturnTask` puts one back on the table, in
  any phase, since the players share the tasks out as they like (as the
  page already allowed); on screen a pick is only the picker's, of a loose
  task, in their turn.
- **A stale action is let go**: one that comes back no longer allowed
  (the table moved on) is ignored, as a server would refuse it.
- **The link's history starts again with each game** (`TableLink.reset`),
  so a game's moves are its own, for replay and for a bug report.
- **Every random choice comes from the game's seed** (`game/dice.dart`,
  one purpose each: the deal, the tasks, the exile, the courtiers'
  choices, the seats). The deal, tasks and exile roll exactly as before
  (same numbers); new: the courtiers' houses are seated from the seed
  (they were unseeded), and the courtiers' dice are set from the seed at
  each deal (they ran on from one `Random`). Same odds; replayable.
  Screenshots: none differed after all (the seeded seating and choices
  came out the same as the test runner's), so the baseline stays.
- **A deal no longer depends on which seat is looking**: the check that
  no task is impossible took "you" as the King before the crowning; it
  takes the King card's holder now, so every device deals alike. The
  seeded screenshots' deals may differ (see above).
- **`GameSetup`** (`game/setup.dart`) is what a game starts from, kept in
  the game and its saves, so a replay or a bug report can start the same
  game again; `ModeRules` hands the mode's say to the game as functions.
- **A headless table** (`net/headless_table.dart`) is the page without a
  screen: deals, crowns, runs the courtiers, applies every move at once.
  Replays, the determinism test and the two-device test run on it; a
  server would too.
- **Seats, the fake network and rooms** (5d–5g): `Seats` says who holds
  each seat; the host plays courtiers' seats and dropped people's
  (`Host.plays`, `botDecision(courtier:)`); `FakeNetwork` numbers moves
  and delivers them late, out of order, twice or not at all, and a
  `FakeLink` hands its table the moves in order, each once; `Rooms`,
  `Room` and `Session` are interfaces with `InMemoryRooms` on the fake
  network. The page still plays on a `LocalLink`: nothing on screen
  changes. `docs/ONLINE.md` is rewritten around these.
- **Bug reports carry every move of the game** (not the last 40) beside
  the state, so `replayReport` (`net/replay.dart`) can play the report
  again from its setup and say whether that reaches the reported state;
  `test/tool/replay_report_test.dart` does it for a report file.

## Step 6: the page in pieces

The order of the commits, each one component out of `HomePageState` into
its own library under `ui/` with explicit inputs and callbacks, the
widget tree unchanged so the screenshots stay the same, and a test of its
own where it has state or branches:

1. The outcome card and the lesson card → `ui/overlays/outcome_card.dart`.
2. The King prompt, the decree scroll overlay, the play flourish, the
   crowning scenes → `ui/overlays/`.
3. The tutorial's coach line → `ui/modes/tutorial/coach.dart`.
4. The dialogs: task close-up, courtier card, how many tricks, points,
   continue, setup-from-menu → `ui/dialogs/`.
5. The welcome screen → `ui/welcome/`; the setup panel, chapter picker,
   saved games and page transitions → `ui/setup/`; the top bar and menu →
   `ui/menu/`.
6. The shared widgets (`lib/home/*` and `lib/ui/*` part files) →
   libraries under `ui/widgets/`, `ui/cards/`, `ui/tracker/`,
   `ui/round_table/geometry.dart`, each with its own imports.
7. The round table (task cards on the felt, dragging, dealing) →
   `ui/round_table/round_table.dart` with its own state (positions, tilt,
   order, the drag).
8. The on-screen table → `ui/table/`: the opponents, the middle, the
   trick, your hand (with the queue, the speech token and the drag), the
   task flights, the keyboard.
9. `GameController` → `ui/controller.dart`; the screen-only state the
   components share → `TableUi` beside it.
10. `TheKingsCourtApp` → `ui/app.dart`; `HomePage` → `ui/table_page.dart`;
    `main.dart` is `runApp`.
11. 6a, last rather than first: `GameState`'s mode-specific fields
    (`chapter`, `lesson`, streaks) into a `ModeState` per mode with its
    own JSON, saves at version 3. Done after the page split because the
    page reads those fields in forty places and the split moves them
    anyway.

Notes as the sequence runs:

- The intro's spark painter (`_IntroSparks`, once private to the welcome
  screen) is `IntroSparks` in `ui/overlays/crowning.dart`, shared by the
  welcome screen and the walk-in's crown; the welcome screen will import
  it from there when it moves out of the page (item 5).
- Items 4 and 6 swapped: the dialogs use the shared widgets (the mini
  card, the house banner, the task's cards row), so those became
  libraries first. `lib/home/` is gone; `lib/ui/widgets/`, `ui/cards/`,
  `ui/tracker/`, `ui/setup/`, `ui/menu/`, `ui/welcome/` and
  `ui/round_table/geometry.dart` hold what it had, and `lib/widgets.dart`
  exports `ui/widgets/`.
- The task close-up (`ui/dialogs/task_close_up.dart`) takes what the
  screen knows of the task (progress, crossed-out cards, status, the
  cards' marks) as values when it opens, rather than reading the page
  while open; bots don't move under a dialog, so nothing changes meanwhile.
- The round table (item 7) keeps its layout in a `RoundTableController`
  the page owns (positions, tilt, draw order, the drag, which deal is laid
  out, the deal animation), as a text field keeps its text in a
  controller: the page still reads `dealtFor` and the geometry in its own
  logic (when to deal, whose pick it is), and decides what a drop means
  (the rules, the move to send). The widget draws the seats, prompt, cards
  and crowning from it and reports taps and drags. The seat someone holds
  the felt from is the widget's own state, since nothing else reads it.

- Items 8 and 11 stop short. The on-screen table's trick is a library
  (`ui/table/trick_view.dart`); its opponents' columns, the middle with the
  task flights, and your hand (with the queue, the speech token, the drag
  and the keyboard focus) stay on the page: they share a dozen keys and
  timers with the page's bot pacing and judging, and taking them out
  without changing a frame needs the pacing to move first (future work,
  listed in the report). Item 11 (a `ModeState` per mode, saves at
  version 3) is not done: the mode-specific fields are two ints
  (`chapter`, `lesson`) already set only through `NextRound`, and moving
  them changes sixteen call sites and the save format for little; it stays
  as future work.
- Step 9 before step 7: every file is in its layer's folder (the layer
  test's `legacy` and `legacyFolders` are empty; `lib/main.dart` is the
  top), and a file-size test holds every file under 600 lines with an
  allow-list for art and data and a shrinking list of debts
  (`test/file_size_test.dart`). The widgets, the throne room, the bot and
  the game state were split to fit; the page, `Round`, the setup panel
  and the tutorial pager are the debts.

## Step 7: skins

The order of the commits:

1. `skin/skin.dart` (`Skin`: the palette by name, the seat colours, the
   suit colours, the fonts, the felt shadow, the card outline, the
   dialogs' look, `theme()`), `skin/court/court_skin.dart` (`CourtSkin`:
   today's look, its values the constants `skin/theme.dart` has always
   had), `skin/skin_scope.dart` (`SkinScope`, `context.skin`; the Court
   skin when there is no scope, so every widget test is unchanged), the
   app wrapped in a scope with the theme from the skin, and
   `test/skin_test.dart`: no file under `lib/ui/` names `Palette`, a font
   constant, `feltShadow`, `DialogStyle` or the outline constants, with an
   allow-list of the files not swept yet that only shrinks. Pixels
   identical.
2. The sweep, a family of files per commit: every widget reads the skin
   from its context (`final skin = context.skin;` at the top of `build`),
   painters and helpers take it as a parameter; `const` goes where a value
   now comes from the skin. Pixels identical each time (the screenshots).
3. `PlainSkin`: other colours, the system faces, flat dialogs, a flat
   theme.
4. The switcher: the menu offers the skins, the choice saved
   (`kingsCourt.skin`), the app rebuilt under the new scope;
   `Entitlements` (`owns(skin)`) with `AllOwned` the only implementation,
   a lock on a skin not owned.
5. `skin/strings.dart`: the chrome's strings (menu, top bar, welcome,
   setup, the dialogs' buttons) read from `Strings`.
6. Screenshots per skin: the shots test takes the Plain set beside the
   Court set.

What the skin covers: the look `skin/theme.dart` has always defined (the
named palette, fonts, shadows, outline, dialogs, theme). The translucent
tints (`Colors.white70`, `Color(0x33000000)`) and the one-off colours
inside the ornament painters (gradients of the damask, the glitter, the
throne room) stay literals for now: they are shades of the look rather
than the look, naming ninety of them is a design job of its own, and the
Plain skin changes the look without them. The skin test lists the files
with such literals as the next debt.
- **The sweep landed as one commit.** The plan said a family of files per
  commit, but the constructors that change cross families (the spark and
  confetti painters, the high-visibility and ornate borders, the task
  card's measure and the table geometry that calls it, the flight), so no
  family compiles without the others, and without an SDK here a file
  can't be staged in part. It is mechanical (a script: `final skin =
  context.skin;` where a build reads the look, `context.skin` in other
  State methods, the skin passed into painters, `const` taken off what
  now reads it, then `dart fix`), and the screenshots prove it changes no
  pixel. A `fix` workflow (`fix.yml`) was added to run `dart fix` without
  the SDK. The Court Cards' cloth and the emblems' gold stay literal
  colours: they are the court skin's art, drawn the same in every skin
  for now (the Plain skin keeps the court's cards).
- The task card's text style (which the card's size is measured in) is
  the skin's (`Skin.taskText`), so `TableCard.sizeFor` and the table
  geometry take the skin, and the size cache is keyed by it.
