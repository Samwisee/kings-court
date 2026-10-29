# Architecture

How The King's Court is built, after the 2026 refactor. `README.md` is the
file-by-file map, `CLAUDE.md` the working rules, `docs/DECISIONS.md` every
call made along the way, `docs/ONLINE.md` how online play plugs in. The
plan the refactor followed is this file's git history (it was
`docs/REFACTOR_PLAN.md`).

## Layers

Each folder under `lib/` imports only itself and the folders before it in
this list. `test/layers_test.dart` reads every import and fails on one
pointing the wrong way, and on any Flutter import in the first four.

```
engine/    Plain Dart. Cards and tricks, the task library (tasks.dart) and
           its rules (rules.dart), plain words (task_help.dart), conflicts
           and the deal mix, decrees and seals, the Round, inference,
           sampling, the bots and their playouts, the Trial of Hearts.
game/      Plain Dart. GameState (state.dart), every action (actions.dart)
           and the one place that applies them, seeded dice, the dealer,
           the judge's views, the host that runs the courtiers, seats,
           setup, players, saves and their migrations.
net/       Plain Dart. Where moves go: the table link, the headless table,
           replay, the fake network, rooms.
modes/     Plain Dart. One folder per way to play: how its rounds are set
           up, what its courtiers are told, what a result means, its data.
platform/  Flutter and plugins: settings, sounds, analytics, crash
           reports, the build's version.
skin/      The look: the Skin interface, its looks and parts, skins made
           from a design, the Court, Plain and Lacquer skins, the
           scope widgets read it from, entitlements, the chrome's strings.
ui/        Flutter. The app, its one page, the controller, and the page's
           pieces by family.
main.dart  runApp.
```

## The round, the game and their actions

- **`Round`** (`engine/round.dart`) is the one record of a round: the deal,
  the tasks and who holds them, picks and passes, tricks, shown cards,
  statuses, seals, the decree. Every move within a round is a sealed
  `MatchAction` (`PickTask`, `ReturnTask`, `Pass`, `Announce`, `PlayCard`,
  `ShowCard`); `Round.problem` says why one isn't allowed and
  `Round.apply` is the only way it changes. `visibleTo(seat)` is what one
  seat may see (other hands hidden, the set-aside cards kept so every
  device judges alike); `result` is what a mode reads once it's over.
- **`GameState`** (`game/state.dart`) is the game around it: players,
  mode, target, the record, the seed and its `dice`, the setup it started
  from. Everything else players do is a `GameAction` (`Crown`, `Speak`,
  `MarkTask`, `UndoMark`, `NextRound`, `RetryRound`, `Redeal`);
  `GameState.problem/apply` again. Both kinds travel as JSON.
- **Dice** (`game/dice.dart`): every random choice comes from the game's
  seed and its purpose (the deal, the tasks, the exile, the courtiers'
  thinking, their seats), so a game replays exactly from its setup and
  moves (`net/replay.dart`). A bug report carries both, and
  `test/tool/replay_report_test.dart` plays one again move by move.
- **Saves** carry a `version` (`game/saves.dart`); an older save is
  upgraded one migration at a time. Fixtures of every version live in
  `test/fixtures/saves/` and must keep loading.

## Moves and the table

Every action goes through a `TableLink` (`net/table_link.dart`): sent, then
applied when it comes back as a numbered `Move`. On one device the
`LocalLink` hands it straight back; online a server numbers moves for
every device, so all tables agree. The `Host` (`game/host.dart`) plays the
courtiers' seats (empty ones, and a person's while they're away) through
the same link. `HeadlessTable` is a whole table with no screen, which the
two-device and rooms tests play over the `FakeNetwork` (delays,
reordering, repeats, a device dropping out and catching up).

## Modes

A `Mode` (`modes/mode.dart`) decides each round's setup, the deal it may
rig, what its courtiers are told, and what a result does (`afterRound`
gives `RoundEffects`, which an undo takes back). `modes/modes.dart` is the
registry. A mode is two folders: its rules and data in `modes/<name>/`
(plain Dart) and its screens, if any, in `ui/modes/<name>/`.

## The screen

- `ui/app.dart` is the app under a `SkinScope`; `ui/table_page.dart` is the
  one page. `HomePageState` still holds the screen's own state (the
  animations, the bots' pacing, dealing to the screen, the trick pauses,
  the keyboard focus) and wires the pieces together.
- `ui/controller.dart`'s `GameController` owns the `GameState`, the link
  and saving (debounced).
- The pieces are libraries with explicit inputs and callbacks, each with
  tests of its own (`test/ui/`): the round table and its
  `RoundTableController` (`ui/round_table/`), the trick (`ui/table/`),
  the overlays (outcome card, crowning, decree, King prompt, "Play!"),
  the dialogs, the coach, the setup panel, the menu, the welcome screen,
  the tracker, the cards, and the shared widgets (`ui/widgets/`, exported
  by `ui/widgets.dart`).

### What's still on the page

The on-screen table's opponents, the middle (with the task flights) and
your hand (with its queue, the speech token, the drag and the keyboard
focus) are still methods of `HomePageState`: they share keys and timers
with the bots' pacing and the judging animations. The next step is to move
that pacing into a `TableUi` beside the controller, after which they split
out like the round table did. `test/file_size_test.dart` holds the page to
its current length, and the number only goes down.

## Skins

A `Skin` (`skin/skin.dart`) is the whole look as one object: the palette
by name, the seat and suit colours, the fonts, the felt shadow, the
card outline, the task text the cards are measured in, the dialogs'
look, and the Material theme. Widgets read it from their context
(`context.skin`); painters and other classes with no context take it as a
constructor argument. `test/skin_test.dart` fails on any file under
`lib/ui/` naming the Court skin's constants. `CourtSkin` is the look the
game has always had (its values are `skin/theme.dart`'s constants);
the others are made from a `SkinDesign` (`skin/design_skin.dart`). The
menu's *Look* row steps through them (`skinAfter`, `SkinScope.choose`,
remembered as `kingsCourt.skin`), for skins `Entitlements` says the player
owns (`AllOwned` today). The chrome's words are in `skin/strings.dart`.

Beside its colours a skin has **looks** (`skin/looks.dart`), small values
saying how its pieces are built: `TableLook` (a rim round the felt, or an
edge), `PanelLook` (ornate or flat, and the grounds for the court, a win
and a loss), `CardLook` (the Court Cards as emblems on their cloths or as
roundels on the card stock, the back), `TokenLook` (the houses' shapes or
discs) and `ButtonLook` (cut corners and a glow, or rounded). The widgets
draw from them (`TableTrim`, `OrnateCard`, `PlayingCardView`, `CardBack`,
`MiniCard`, `SeatToken`, `GlowButton`, the menu's border). For what a look
can't say a skin draws a **part** itself (`skin/parts.dart`): a card face
or back, a panel, the table. Each builder gets a spec, the game's
`PartKit` (suit marks, the crown) and the standard part to wrap. How to
make one is `docs/SKINS.md`.

## The guards

| Guard | Where |
|---|---|
| Strict analysis, no findings | `analysis_options.yaml`, CI's `test` job |
| Layers point one way | `test/layers_test.dart` |
| No file over ~600 lines (art, data and listed debts aside) | `test/file_size_test.dart` |
| Widgets name no look | `test/skin_test.dart` |
| Old saves keep loading | `test/saves_test.dart`, `test/fixtures/saves/` |
| A game replays from its seed and moves | `test/determinism_test.dart` |
| Two devices end with the same game | `test/two_devices_test.dart`, `test/rooms_test.dart` |
| Screenshots match the baseline, pixel for pixel | CI's `shots` job, `tool/shots/` |
| The branch is no 30% slower than main | CI's `bench` job, `tool/bench/budget.py` |

## Where it started

| | Before | After |
|---|---|---|
| `lib/main.dart` | 7,776 lines (the page and twelve `part` files) | 12 lines |
| The page's state class | `_HomePageState`, 7,660 lines | `HomePageState`, about 3,770 |
| `GameState` | about 1,620 lines (the round, the game and Dynasty mixed) | 415 lines; the round is `Round` (750) |
| Moves through the link | 5 kinds | every action |
| Random choices | unseeded `Random()`s | one seeded `Dice` |
| The look | `static const`s named in 27 files | a `Skin` from context; three skins, two made from a design alone |
| Tests | 119 | 217 |

## Future work

Translation (a `Strings` per locale, translated data files), a
state-management library and a Flutter upgrade were left out on purpose.
Also open: the on-screen table's remaining pieces and their `TableUi`
(above); `ModeState` per mode with saves at version 3 (the
mode-specific fields are `chapter` and `lesson`, both set only through
`NextRound`); `Round`'s JSON and judging as extensions to bring it under
the file-size line; the setup panel and the tutorial pager split by page;
the ornament painters' one-off tints named in the skin; Dynasty's hall
pieces, shelved, still carry the court's colours.
