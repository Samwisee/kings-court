# Decisions made during the refactor

Every call made without asking, newest last, and every change to what the
player sees or how a round plays (those also name the screenshots they
explain, or say none differ). The plan was `docs/REFACTOR_PLAN.md`, now
`docs/ARCHITECTURE.md`.

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
- **The menu gains a row: "Plain look"** (a pip, like four-colour suits),
  which wears the Plain skin and remembers it (`kingsCourt.skin`); a skin
  the player doesn't own shows "(locked)" and can't be worn
  (`Entitlements`, `AllOwned` today). Intended change; screenshots:
  `wide-screen-menu.png`, `wide-table-menu.png`. The Plain skin: slate
  instead of felt, a teal accent instead of gold, the body face for titles,
  flat dialogs and buttons; the Court Cards and the table's ornament are
  the court's art in both.
- The screenshots take a Plain set (`plain-0-welcome` … `plain-3-menu`)
  beside the Court set: the front page, setup, a round on screen and the
  menu, on a phone. They are new, so listed in `expected_changes.txt`
  until the baseline is retaken.
- `skin/strings.dart` holds the chrome's words (menu, top bar, front
  page, the small dialogs) as constants, so the widgets showing them stay
  `const`; translation would make it an object chosen by locale (future
  work).

## The screenshot guard, mended

- **The comparator never compared colour.** `tool/shots/compare.py` took
  `getbbox()` of an RGBA difference, which looks at the alpha channel
  only, so every run since step 2 reported "66 same" whatever changed.
  It now compares every channel. Re-run against the pre-refactor
  baseline (and nine commits along the way, pushed to `bisect-*`
  branches for their screenshots), 35 of the 66 differ:
  - **23 never matched**: the phone, laptop (but the first), wide-screen,
    wide-table and throne-room shots differed between two runs of the
    baseline's own commit, because their deals and courtiers drew from
    unseeded randoms. Since step 5 every random choice comes from the
    seed, so they are steady now, but with other deals and seats
    (Bishop → Duke, and so on). Listed in `expected_changes.txt`, with
    the menu shots, which also gained the *Plain look* row.
  - **The throne room** (`zz-room.png`) still varies run to run (its
    figures move on a clock of their own). It is marked unstable (`~` in
    `expected_changes.txt`) and not compared; it is the shelved Dynasty's.
  - **`laptop-0.png`**: the Powers tile is gone from setup, as decided at
    checkpoint 1 (step 3 said "none differ"; it did).
  - **Two regressions, fixed**: the strict-lint pass (step 2) turned the
    mini card's `Container`s into `DecoratedBox`es, which don't inset
    their child by the border, so every mini card (the tracker, a task's
    close-up, a shown card) drew its rank and suit a little larger and
    off-centre (`tut-4b-play.png`); and the Dynasty removal (step 3)
    unwrapped the King's crown over a seat token from its `Row`, so the
    crown stretched to its slot's height, a pixel lower
    (`tut-*-pick.png`, `tut-*-play.png`, `tut-*-done.png`). Both are back
    as they were.
  The baseline was retaken from the first green run after this (f7724f9,
  `shots-baseline` now 3fa3cb9), so the guard holds from here on.

## Skins with designs of their own

Asked for skins that are easy to make and still free to look like
anything, and for Plain to be a design rather than a recolour:

- **A skin has looks beside its colours** (`skin/looks.dart`): the table's
  edge, the panels, the Court Cards and backs, the seats, the buttons.
  The widgets that drew the court's shapes now draw from these; the Court
  skin sets them to exactly what it drew before, and its screenshots are
  pixel for pixel the same (62 same in the compare).
- **Or draws a part itself** (`skin/parts.dart`): a card face or back, a
  panel, the table, each handed a spec, the game's pieces and the
  standard part.
- **Most skins are a `SkinDesign`** (`skin/design_skin.dart`): fifteen or
  so colours, two fonts and a finish (`rich` for the court's family of
  shapes, `simple` for flat ones); everything else is worked out.
  `docs/SKINS.md` is the how-to.
- **Plain is redesigned** as a simple design: slate felt running to the
  screen's edge, flat panels with a band of cornflower for an occasion,
  the Court Cards as their emblem on a roundel of their colour on white
  stock with the letter in the corner, a latticed back, round seats,
  rounded buttons with a steady glow. Its shots are now
  `skin-plain-*` (the `plain-*` set is gone).
- **Lacquer is new**, a rich design (red-black lacquer, gold leaf,
  jewel-toned Court Cards) with one part of its own, its card backs: to
  show both routes. `skin-lacquer-*`.
- **The menu's skin row names the look worn** ("Look: Court") and steps
  to the next skin owned, instead of the Plain look's on/off pip; the
  Court skin's name is "Court". `wide-screen-menu.png`,
  `wide-screen-4-four-colour.png`, `wide-table-menu.png`.
- **Every skin gets a sheet of its pieces** (`skin-<id>-pieces.png`) and,
  but the court, the front page, setup, a round and the menu, taken for
  whatever is in `skins`.
- **The court's last literals on the table came into the skin**: the
  brass line over the hand, the coach's ground, the crowning's light
  (`feltGlow`), the small Court Cards' colours and the task cards' backs
  (`CardLook.small`, `taskBack`), and a few gold tints, so a new skin's
  table has none of the court's colours on it. Same pixels for the court.
- `card_view.dart` went over the line with the letters face, so the back,
  the flip and the shuffling deck moved to `cards/card_back.dart`.
- Made as one commit for the code and one for the docs, not a commit per
  widget: the Plain skin couldn't compile against the new `Skin` until
  every look existed, and each widget's change is a few lines.

## The court, polished

Two changes to the court's own look, both through its looks so every rich
skin can have them:

- **Lamp light on the felt** (`TableLook.lamp`, drawn by `FeltLight` under
  everything on the table): a soft pool of light over the middle, fading
  to the felt's own colour at the edges, so the table reads as lit rather
  than flat. Under the cards and seats, not over them: a first try
  darkened the corners over everything and greyed the hand's end cards,
  which read as unplayable. Plain has none.
- **The card back dressed like the Court Cards**: a faint gold lattice and
  a fine gold rule inside the edge (`CardLook.backPattern`,
  `backPatternAlpha`, `backRule`), the gilt crown a little smaller.
- Every in-game court screenshot moves with these (listed in
  `expected_changes.txt`); the front page, setup, rules and lesson
  introductions don't. Frame budget kept.

## Paying down the debt

On its own branch (`debt`, from `refactor`), so the refactor can be merged
without it. Every screenshot is pixel for pixel what `refactor` drew (each
step compared against `shots-refactor` directly, not only against the
baseline).

- **Off the debt list**: the tutorial pager (its task close-up moved to
  `intro_preview.dart`), the setup panel (its frame and tiles to
  `setup_frame.dart` and `setup_tiles.dart`), and the round record (its
  tasks, moves, queries and checks to `round_task.dart`,
  `round_actions.dart`, `round_queries.dart` and `round_checks.dart`,
  exported with it; the queries and checks are extensions on `Round`, so
  callers are unchanged, though a file importing only `game/state.dart`
  now imports `engine/round.dart` for them).
- **The page, 3,866 → 3,162 lines**: the courtiers across the top, your
  seat, the game bar, the hand's bar and cards, the open and dealt tasks
  and the tracker overlay are widgets in `ui/table/` (and `ui/tracker/`)
  taking explicit inputs; the menu's rows are `menu_entries.dart`. The
  task flights and the hand drag are classes of their own, the first
  parts of a `TableUi`. The arrow keys' moves are a pure function with a
  test (`test/ui/keyboard_test.dart`). The dealt tasks lost a spread that
  was always zero (`apart`), the same motion.
- **The page is still over the line**: what's left is the pacing (bots,
  trick pauses, judging, keyboard focus) and the wiring. Moving the
  pacing out is a bigger change with timers in it; left as the next step
  rather than rushed.
- **The last court tints named**: a lost round's red flush and a failed
  task's edge come from the skin (`cardRed`, `lost`); the light on the
  gold (a waiting button's sweep, a win's sheen and stars) is
  `Skin.sheen`. The court's sheen is exactly its old colour; the win's
  stars and sheen are now a shade of it (`#FFF9E4`-ish where they were
  `#FFFBE6` and `#FFFBEA`), too faint to tell and not drawn under test.
  The wax seals stay red in every skin.
- **CI retries its result pushes**: two runs side by side sometimes had a
  push of `ci-`, `shots-` or `bench-` refused, failing a green run.

## Switching the look, smoothly

- **The stutter**: a switch rebuilt the whole page in one heavy frame (a
  walk that marked every element dirty, on top of everything that reads
  the skin), then Material's theme eased over 200 ms, rebuilding every
  widget each frame, half in the old look and half the new (the skin's
  own colours had already snapped).
- **Now**: the theme changes at once (`themeAnimationDuration: zero`),
  the dirty-marking walk is gone (everything that reads the skin depends
  on it, and every painter that takes one compares it), and the change is
  one deliberate dissolve: a still of the screen is taken, the new look is
  built under it, and the still fades out over 380 ms (`ui/app.dart`).
  With reduced motion it simply changes. No screenshot moves.
- The page benchmark prints the switch's frames (`switching the look`);
  the test harness rasterises on the CPU, so its numbers aren't a phone's.
  What a phone or browser pays the first time it draws a look (shaders,
  glyphs) still happens, but under the still.
- **The loading screen** is drawn in the look saved last time
  (`web/index.html` reads it from local storage); `test/skin_test.dart`
  checks its colours against each skin's.

## The bug report on a phone, and the first trick

- **The bug report with the keyboard up**: the dialog didn't fit, so its
  buttons slid down over the table and the title off the top. A court
  dialog's words now scroll when there isn't room, keeping the title and
  the buttons in view (every `CourtDialog`, not only this one). A test
  holds it with a phone's keyboard up. The name field is gone; reports
  come in as "anonymous". `wide-*-bug.png` change.
- **"Win the first trick a Court Card falls in"** is no longer dealt
  beside a task to win the first trick (or the first two, or the first
  trick with a Court Card). They only clashed when a Court Card fell in
  the first trick, so the deal check let them through, but the King leads
  that trick and Court Cards come out early: held by two players they
  fought more often than not. By the balance report the first-trick tasks
  are dealt about as often as their share of the pool (one round in
  three has one), so no other change to how often they come up.
