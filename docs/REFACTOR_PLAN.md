# The refactor: target structure and migration plan

This is checkpoint 1 of the refactor (see the brief in the chat): the shape
the code is moving to, and the order it moves in. Nothing has moved yet.
When the work is done this file becomes `docs/ARCHITECTURE.md`.

## Where we start

| | Lines | What's wrong |
|---|---|---|
| `lib/main.dart` | 7,776 | One `_HomePageState` of 7,660 lines: game flow, bots' timing, dealing, judging, Dynasty's story flow, every overlay and dialog, keyboard handling, saving, settings. Twelve `part` files in `lib/home/` share its privates. |
| `lib/models.dart` | 1,702 | `GameState` (1,620 lines) mixes the round (tasks, owners, King, picking) with the game (players, mode, counters, seed) and all of Dynasty's state (court, loyalty, schemes, wounds, reigns, flags, tidings, charges, coffers…). `playerCount` and `targetPoints` live on the page, not in the state. |
| `lib/engine/match.dart` | 494 | `MatchState` is a second record of the round (tasks, owners, verdicts, wins, streak) with its own judge; the page rebuilds it from `GameState` before every bot turn (`_matchView`) and judges tasks itself (`_judgeTasks`). |
| `lib/theme.dart` + widgets | | The look is `static const`s (`Palette.gold`) used in 27 files, plus `Colors.white` and `Color(0x…)` literals in 20 of them. A skin is a code change. |
| Moves | | Five of the things players do go through the link (pick, pass, announce, play, show). Crowning, marking tasks at a real table, undo, showing the speech token, powers, shuffling, the next round and all of Dynasty change state directly. Bots and Dynasty draw from unseeded `Random()`s, so a game can't be replayed from its seed. |
| Screenshots | | 42 of the 66 are byte-identical run to run; the 24 of random deals differ every run (checked by running the Screenshots workflow twice on the same commit), so there's no pixel guard yet. |

Tests today: 119 (engine 23, widget flows and whole rounds 68, tutorial 2,
task help 12, net 4, inference 3, bot turn 2, fairness 5).

## The target

### Layers

Each folder may import only itself and the folders above it in this list.
A test (`test/layers_test.dart`, grown from `net_test.dart`) reads every
import under `lib/` and fails on one pointing the wrong way, and on any
Flutter import in the pure-Dart layers.

```
engine/    Pure Dart. Cards, the task library and its rules, conflicts,
           the deal mix, the round (one record: the deal, tasks, owners,
           tricks, shown cards, statuses, seals) and its judge, inference,
           sampling, the bots, the Trial of Hearts.
game/      Pure Dart. The game at a table: players, seats, seed, target,
           mode, the round in progress, counters; every action and the one
           place that applies them; the host that runs bots; per-seat
           views; seeded dice; saves (and the loader for old saves).
net/       Pure Dart. How moves travel: the sequenced link, the local link,
           the fake network, replay, rooms and sessions.
modes/     Pure Dart. One folder per way to play: what a round is set up
           with, what happens after one, the mode's own state and data.
platform/  Flutter and plugins: settings storage, sounds, analytics, crash
           and bug reports, build info, keeping the screen awake.
skin/      Flutter. The Skin interface, the two skins, how widgets get the
           current skin, entitlements, and every string the chrome shows.
ui/        Flutter. Widgets and screens, drawing state and forwarding taps.
main.dart  runApp.
```

### The tree

```
lib/
  main.dart                      runApp(TheKingsCourtApp()).
  engine/
    cards.dart                   Deck, suits, deal, legal plays, tricks (as now).
    task.dart                    Task (immutable: description, points) and allTasks.
    task_library.dart            The 113 tasks' words and points (data; was lib/tasks.dart).
    task_help.dart               Plain words, glossary, status lines (was lib/task_help.dart).
    rules.dart                   taskRules: description → verdict (as now).
    conflicts.dart, deal_mix.dart, showing.dart, inference.dart, sampling.dart (as now)
    round.dart                   Round: THE record of a round (replaces MatchState and the
                                 round half of GameState). RoundTask: task, owner, x, seal,
                                 status, why it failed. RoundAction: the moves within a round.
    judge.dart                   Verdicts after a trick or a mark, in seal order; the
                                 round's outcome; RoundResult.
    bot.dart                     The fair bots (as now, reading a Round).
    contest.dart                 The Trial of Hearts (as now).
  game/
    game.dart                    Game: players, seats, seed, target, mode id, the Round,
                                 counters, mode state. apply(GameAction) is the only way
                                 shared state changes.
    actions.dart                 GameAction, sealed: every move, with JSON.
    seats.dart                   Seat: who holds it (human by id, bot, empty), connected.
    seat_view.dart               SeatView.of(game, seat): what one seat may see.
    dealer.dart                  A round from the seed: hands, the King, swaps for
                                 impossible tasks (was _syncCards).
    host.dart                    Host: runs bots for bot seats (and dropped humans),
                                 auto-plays a won round out, with holds the UI can take
                                 while it animates. Online, the server is the host.
    bot_turn.dart                botDecision (as now).
    powers.dart                  What each courtier's power may do, and does.
    dice.dart                    Dice(seed): every random choice in a game, by purpose.
    saves.dart                   SavedGame, slots, JSON; loads saves from before the refactor.
    setup.dart                   GameSetup: everything the setup panel decides; Game.start.
  net/
    table_link.dart              TableLink (Move = seq + action), LocalLink.
    fake_network.dart            FakeNetwork: links with latency, reordering, duplicates,
                                 disconnects; a rejoin catches up from the history.
    replay.dart                  replay(setup, seed, moves) → Game.
    rooms.dart                   Rooms, Room, Session interfaces; InMemoryRooms.
  modes/
    mode.dart                    Mode: title, newGame(setup), nextRound(game, last),
                                 afterRound(game, result), its ModeState (+JSON), its bots.
    modes.dart                   The registry: GameMode → Mode.
    free/free_play.dart
    endless/endless.dart         Streaks; the target that grows.
    chronicle/chronicle.dart     The 24 chapters, seals, decrees (data); ChronicleProgress.
    tutorial/lessons.dart        Lessons, rigged deals, scripts, intro pages (data).
    tutorial/tutorial.dart       The scripted courtiers; the lesson flow.
    dynasty/data/                Dilemmas, courtier lines, tidings, story arcs (data, kept).
    dynasty/                     Later: the roguelike. (The old flow: see question 1.)
  platform/
    settings.dart                Preferences (sound, upright, four-colour suits, keys, skin…).
    sfx.dart, analytics.dart, crash_reports.dart, bug_report.dart (the sending half),
    build_info.dart, wakelock.dart
  skin/
    skin.dart                    Skin: palette, fonts, card faces and backs, Court Card art,
                                 suit symbols and colours (four-colour too), tokens and
                                 portraits, table and felt, buttons, panels and ornaments,
                                 throne room art, sounds, cursors, app icon; ThemeData.
    skin_scope.dart              SkinScope (InheritedWidget), context.skin, SkinController
                                 (switch at runtime, saved).
    entitlements.dart            Entitlements: owns(skin)? AllOwned today.
    strings.dart                 Every string the chrome shows (menus, buttons, dialogs,
                                 toasts, status lines). Content text stays with its data.
    court/                       The King's Court skin: today's look. emblems.g.dart and
                                 suits.g.dart (generated art) live here.
    plain/                       The Plain skin: other colours, fonts, flat cards, no ornament.
  ui/
    app.dart                     TheKingsCourtApp: theme from the skin, the page.
    table_page.dart              The one page: which screen shows (welcome, setup, table,
                                 overlays), and nothing else. Under 300 lines.
    controller.dart              GameController: the Game, its link, host and saving;
                                 TableUi: screen-only state (menus, toasts, tracker,
                                 keyboard choice, drags).
    welcome/                     Front page, Play menu, saved games.
    setup/                       The setup panel and its pages (per mode).
    menu/                        Top bar, drop-down menu, points dialog, bug report dialog.
    table/                       On-screen cards: opponents, the middle, the trick, your
                                 hand, keyboard navigation, task flights, the speech token.
    round_table/                 The real-table layout: geometry, dragging task cards.
    overlays/                    Crowning, decree and tidings scrolls, the outcome card,
                                 the play flourish, the coronation.
    dialogs/                     Task close-up, courtier card, scheme, how many tricks,
                                 absolution, powers.
    tracker/                     The card tracker.
    cards/                       PlayingCardView, Court Card faces, mini cards.
    widgets/                     icons, SuitText, tokens, task cards, table rim, panels,
                                 buttons, key caps, house banners, transitions
                                 (today's lib/ui and lib/home pieces, each its own library).
    rules/                       How to Play.
    modes/chronicle/             Chapter picker, crowns.
    modes/tutorial/              Intro pages, the coach, the lesson card, You're ready.
    modes/dynasty/               The throne room, Trial of Hearts table, story cards.
test/
  layers_test.dart, skin_test.dart (no colour or asset named in ui/), saves_test.dart
  (fixtures from before the refactor), determinism_test.dart, replay_test.dart,
  two_devices_test.dart, rooms_test.dart, seat_view_test.dart, plus today's tests
  adjusted for moved APIs.
```

A mode is two folders: its rules and state in `modes/<name>/` (pure Dart),
its screens in `ui/modes/<name>/`. That keeps the layers a straight line
(a mode's logic never imports a widget) and still makes a mode one thing
to add: a `Mode` in the registry, a `ModeState` for its save, its screens.

### The round component

`engine/round.dart`:

```dart
class Round {
  // The deal (empty hands at a real table, where the phone only tracks tasks).
  List<List<PlayingCard>> hands; List<PlayingCard> setAside; int? king;
  // The tasks: one record, used by the UI, the judge and the bots alike.
  List<RoundTask> tasks;          // task, owner, x, seal, status, whyFailed
  int? pickTurn; Set<int> passed; List<bool> spoke;
  // The tricks.
  List<Trick> tricks; int leader; List<int> currentSeats; List<PlayingCard> current;
  Map<int, PlayingCard> shown; Map<int, String> shownHint; Map<int, int> shownAt;
  // This round's rules.
  Decree? decree; int? exiledSeat; Map<int, int> schemes; int target; int dealId;
  Phase phase; RoundOutcome outcome;

  RoundView get view;                        // what the task rules see
  String? problem(RoundAction a);            // why a move isn't allowed
  RoundChange apply(RoundAction a);          // the only way it changes
  RoundResult get result;                    // once over
  Map<String, dynamic> toJson();
}
```

`RoundResult` is what a mode consumes: won or lost, each task with its
owner, status and why it failed, the tricks, the King, points. There is no
second record: `MatchState` and `MatchTask` are renamed and grown into
`Round` and `RoundTask` (the bots, sampling, inference, the balance tool and
the benches read the same class); `GameState` loses `tasks`, `kingIndex`,
`spoke`, `passed`, `pickTurn`, `sealCount`, `decree`, `exiledSeat` and the
mutable `Task.assignedPlayerIndex/status/seal` fields. Judging happens
once, in `engine/judge.dart`, when a trick ends (on screen) or a task is
marked (at a real table), in seal order; the page no longer judges. Task
flips, trick sweeps and the stagger between several completions become
what the UI *shows* over a short time, not when the state changes.

### The game and its actions

`game/game.dart`:

```dart
class Game {
  GameMode mode; List<Player> players; List<Seat> seats; int seed; int target;
  int dealId; Round? round; int roundNumber, wins, losses, streak, bestStreak;
  bool digital, surprise, roles; List<Courtier> courtiers;
  ModeState modeState;            // ChronicleRun, EndlessRun, TutorialRun, (DynastyRun)
  String? problem(GameAction a);
  void apply(GameAction a);       // the ONLY mutation of shared state
  Map<String, dynamic> toJson();  static Game? fromJson(json);  // old saves too
}
```

Every change any player makes is a `GameAction` with JSON, sent through
the link and applied when it comes back:

| Family | Actions |
|---|---|
| Within a round | `PickTask`, `Pass`, `Announce`, `PlayCard`, `ShowCard` (as now), `Speak`/`Unspeak` (the speech token at a real table), `MarkTask(task, status)` and `UndoMark` (a real table), `Absolve(task, penance)` |
| Crowning and the King | `Crown(seat)` (the King card on screen, a tap at a real table), `GiveTask(task, seat)` (King's Command), `ReadDecree` is screen-only and stays off the link |
| The table | `NextRound`, `Shuffle`, `Retry`, `Redeal`, `Resign` |
| Powers | `Command(task, seat)`, `Vanguard`, `Whisper(seat, suit)`, `Trade(card, seat)`, `Jest(a, b)` (behind the same flag as today: see question 2) |
| Dynasty | `Vote(forA)`, `Decide(choice)`, `TrialPlay(card)`, `AcceptTidings` (only if the old flow stays: question 1) |

Deterministic: `Dice(seed)` gives every random choice in a game from the
seed and a purpose (the deal, task draw, seals, swaps, the bots' decision
seeds, Dynasty's rolls), so the same seed and the same moves give the same
state on every device, bots included. `test/determinism_test.dart` plays
two games from one seed, bots and all, and compares their JSON move by
move.

`SeatView.of(game, seat)` is what a device at seat *n* may see: its own
hand, hand sizes, everything public (tasks, owners, statuses, tricks, the
current trick, shown cards, the King, whose turn), never another hand.
The on-screen table draws from a `SeatView`; a test checks no other hand
is in it.

`Seat` records who holds it: a human (by id), a bot, or empty. The `Host`
runs bots for bot seats and for humans who dropped; a human who returns
takes the seat back through the room.

### Net

- `TableLink`: `send(GameAction)`, `moves` (each `Move` has a sequence number), `history`.
- `LocalLink`: straight back, as now.
- `FakeNetwork`: several `FakeLink`s on one table, with latency, reordering,
  duplicates and disconnects; a reconnecting link asks for everything after
  its last sequence number. `test/two_devices_test.dart` plays a whole round
  on two simulated devices (one hosting the bots) through it and checks the
  two games end identical.
- `replay(setup, seed, moves)` rebuilds a game; a test replays a whole round.
- `Rooms`/`Room`: create, join by code, seats, take a seat, start (with the
  seed), the host flag; `InMemoryRooms` for tests. No Firebase. `ONLINE.md`
  ends with exactly what a backend has to provide.

### Skins

```dart
abstract class Skin {
  SkinId id; String name;
  SkinPalette palette;      // felt, table, card, ink, gold…, suit colours, four-colour pair,
                            // player colours, won/lost, traitor, scrims and shadows
  SkinFonts fonts;          // display, body
  CardStyle cards;          // face and back painters, corner radius, outline, index style
  CourtArt court;           // the four Court Card faces
  SuitStyle suits;          // symbols (painted shapes or glyphs), colours
  TokenStyle tokens;        // seat tokens, courtier shapes and portraits
  TableStyle table;         // felt, rim, inlay, inner shadow
  ButtonStyles buttons;     // bevelled gold or flat
  PanelStyle panels;        // ornament levels, damask, medallions
  ThroneArt throne;         // the throne room's stage and figures
  SkinSounds sounds;        // asset paths
  SkinCursors cursors;      // web cursor files
  String appIcon;           // for the store page; the build's icon is the default skin's
  ThemeData theme();
}
```

Widgets read it from context (`context.skin`), never a constant. A test
scans `lib/ui/**` (and `main.dart`) and fails on `Color(`, `Colors.`,
`0xFF…`, `fontFamily:`, `assets/`, `.ttf/.png/.mp3`, `Palette.` and the
font constants. Sizes that are part of the look (corner radii, outline
widths, ornament sizes) come from the skin; layout geometry (where seats
sit, how wide a hand is) stays in the widgets.

`SkinController` switches at runtime and saves the choice. The Plain skin
has its own palette, fonts (the system face), flat cards with plain indices,
plain round tokens, flat buttons and no ornament. The menu offers both,
with a lock where `Entitlements.owns(skin)` says no; `AllOwned` is the only
implementation. The screenshots run once per skin.

`skin/strings.dart` holds every string the chrome shows. Content text (the
tasks' words, help, lessons, lore) stays in its data files; translating the
game means a second `Strings` plus translated data files, and nothing else.

### The guards (step 2, before anything moves)

1. **Layers:** `test/layers_test.dart`.
2. **Analysis:** `strict-casts`, `strict-inference`, `strict-raw-types`
   and an extra lint set (final locals and fields where possible,
   `unawaited_futures`, `avoid_dynamic_calls`, `directives_ordering`,
   `prefer_single_quotes`, `use_super_parameters`, `unnecessary_*`,
   `avoid_redundant_argument_values`, `prefer_const_*`, …). "Check a
   branch" fails on *any* analyzer output, infos included. Tests reach the
   page through a typed test handle instead of `as dynamic`.
3. **Pixels:** the screenshot harness gets a seed (the game's seed, the
   bots' dice) so all 66 screenshots are deterministic; the first run with
   the seeded harness, on the pre-refactor code, is the baseline, kept on a
   `shots-baseline` branch. A `Compare` workflow on the branch runs the
   screenshots, compares every PNG with the baseline (`tool/shots/compare.py`:
   identical, or how many pixels differ, with a diff image), pushes the
   PNGs, diffs and `compare.txt` to `shots-<branch>`, and fails unless every
   difference is listed with a reason in `tool/shots/expected_changes.txt`.
4. **Speed:** the same workflow runs the page and bot benches for `main` and
   for the branch in the same job, on the same runner, and writes both into
   `bench-compare.txt`; the report compares like with like.
5. **Saves:** a one-off CI run on the pre-refactor code plays a few rounds
   in every mode (on screen and at a real table, with seals and a decree)
   and saves the JSON; the files go into `test/fixtures/saves/` and
   `test/saves_test.dart` loads every one, now and after.

## The migration, step by step

Every commit is green in "Check a branch" and in "Compare" (pixel-identical
unless explained). Commit messages stay plain sentences.

**Step 3: game logic out of `_HomePageState`, into `game/`** (the page keeps
calling it, so nothing on screen changes)

- 3a `playerCount` and `targetPoints` move into the game state; the page reads them from the controller.
- 3b `_syncCards` → `game/dealer.dart` (the deal from the seed, the King, impossible-task swaps); `_possible` → `engine/judge.dart`.
- 3c `_judgeTasks` → `engine/judge.dart`: verdicts in seal order, why a task failed, traitors' schemes. The page applies the flips with its stagger and the absolution prompt.
- 3d `_maybeAutoFinish`'s decision → `game/host.dart` (`canPlayOut`); only the timer stays on the page.
- 3e Powers' effects and checks → `game/powers.dart`; the dialogs stay.
- 3f `_startGame` → `game/setup.dart` (`GameSetup`, `Game.start`); `_readSaves`/`_continueSaved` → `game/saves.dart`; settings → `platform/settings.dart`.
- 3g The old Dynasty flow's logic (sides, trials, verdict lines, next round) → `modes/dynasty/` or deleted (question 1).
- 3h The bots' turn (`_scheduleBot`, `_botStep`, `_botThink`, `_startChoosing`) → `game/host.dart`: the host decides and sends; the page holds the host while it animates.

**Step 4: the round component**

- 4a `MatchState` → `Round`, `MatchTask` → `RoundTask`, with owners, statuses, seals, decree, exile, spoke, passed and why-failed (the engine, bots, tools and tests follow; mechanical).
- 4b `GameState` drops its copy of the round and holds `round`; `Task` becomes immutable; `_matchView` goes; the loader maps old saves' `tasks`/`king`/`spoke`/… into the round. The fixtures prove it.
- 4c `RoundResult` and `Mode.afterRound`; the outcome card, Chronicle crowns, Endless streaks and the tutorial's lesson card read the result.
- 4d A real table's round is the same `Round` with empty hands: marks and undo become actions.
- 4e `Mode.nextRound` for free play, Endless, the Chronicle and the tutorial; the page asks the mode, never decides itself.

**Step 5: every action on the link, and the plumbing**

- 5a `GameAction` (the table above), JSON, `Game.problem/apply`; the page sends everything through the link.
- 5b Sequenced `Move`s; `LocalLink`.
- 5c `Dice`; the bots' decision seed from the game; `determinism_test.dart`.
- 5d `SeatView` and its test; the on-screen table draws from the view.
- 5e `Seat`/`SeatHolder`; the host fills bot seats and dropped humans; a seat can be taken back.
- 5f `FakeNetwork`, the two-devices test, `replay` and its test.
- 5g `Rooms`/`Room`/`InMemoryRooms` and a test; `ONLINE.md` rewritten around them.

**Step 6: skins**

- 6a `Skin`, `CourtSkin` built from today's `theme.dart` constants, `SkinScope`, `context.skin`.
- 6b Every widget reads the skin (about 800 references, mechanical); `skin_test.dart` guards it; pixels identical.
- 6c `PlainSkin`; 6d the switcher in the menu, saved; 6e `Entitlements`; 6f `Strings`; 6g screenshots per skin.

**Step 7: the state and the page in pieces**

- 7a `Game` split by concern: core play; `ChronicleRun`, `EndlessRun`, `TutorialRun`, (`DynastyRun`) as `ModeState` with their own JSON; the loader still reads old saves.
- 7b `_HomePageState` into the `ui/` tree above, one component at a time (the hand, the opponents, the middle, the trick, the round table, the overlays, the menu, setup, the tracker, the dialogs, the keyboard), each its own widget with its own small state; `part` files become libraries with explicit imports; `TableUi` for screen-only state.

**Step 8:** dead code (stale flags, unused members), `docs/ARCHITECTURE.md`,
the README map, `HANDOFF.md`, `ONLINE.md`, and the report against every
"done means" point with before and after sizes.

About 50 commits. The two big ones are 4b and 7b; the screenshots and the
save fixtures carry the risk there.

### What changes on purpose, though not for the player

- Random choices that were unseeded (the bots' decision seeds, Dynasty's
  rolls, the Trial's deal) come from the game's seed. Same odds, replayable.
- Tests use a typed test handle on the page rather than `as dynamic`.
- Rounds on screen are judged when the trick ends, not after the sweep; the
  UI shows the flip at the same moment as today.
- `part` files become libraries.

## Questions before code moves

1. **The old Dynasty flow** (dilemmas, votes, trials, verdicts, deaths,
   endings, tidings, charges, schemes, the throne room scenes: about 1,700
   lines on the page and 900 in `GameState`), hidden today behind
   `dynastyComingSoon`. Two ways:
   - **A (recommended): delete the flow now.** Keep every piece of content
     as data in `modes/dynasty/data/` (dilemmas, courtier lines, tidings,
     story arcs), keep the throne room widget and the Trial of Hearts
     (engine and table) in `ui/modes/dynasty/`, with a test that the data
     still loads. The roguelike builds on those. Old Dynasty saves stop
     loading (they're hidden from the menu already). Nothing a player can
     reach changes.
   - **B: carry it through.** Move it, behind the flag, into
     `modes/dynasty/legacy/` with votes and decisions as actions. Adds
     roughly a fifth to the work, for a mode the roguelike replaces.
2. **Courtier powers** (`powersComingSoon`: Command, Vanguard, Whisper,
   Trade, Jest, Absolution). I'd keep them as actions, still off, since the
   roguelike upgrades powers. Say if you'd rather they went with the old flow.
3. **Modes as two folders** (`modes/<name>/` logic, `ui/modes/<name>/`
   screens), to keep the layers a straight line. Fine?
4. **Text:** chrome strings in `skin/strings.dart`; content text stays with
   its data. Fine?
5. **Step order:** I'll follow the brief (skins before the page split). The
   skin sweep would be a little easier after the split; if you'd rather swap
   6 and 7, say so.
