# The King's Court

A cooperative trick-taking card game for 2 to 6 players, built in Flutter.
Everyone plays together: each round deals tasks ("Win the 3♥", "Win the
first trick"), the court shares them out, and the round is won only if
every task is done.

**Play it:** https://samwisee.github.io/kings-court/ (the web build, for
desktop, iPad and phone browsers; add it to the home screen for full
screen).

This README is the map: what lives where, how to change the look, how a
round runs, how it ships, and where online play plugs in. Deeper notes are
in `docs/`:

- `docs/HANDOFF.md`: the game's history, its modes, and how we work.
- `docs/ONLINE.md`: the plan for multiplayer.
- `docs/adding-tasks.md`: adding a task without making rounds impossible.
- `tool/print/README.md`: the printed deck and box.

---

## How I work on it

There's no Flutter SDK in the cloud sessions, so CI is the build machine:

1. Push to `main`.
2. **Test and deploy** (`.github/workflows/deploy.yml`) runs
   `flutter analyze` (errors fail it), `flutter test`, and deploys the web
   build to GitHub Pages. Test failures show as annotations on the run.
3. **Screenshots** (`shots.yml`) runs `test/tool/shots_test.dart` and
   pushes every PNG to the `shots` branch, for checking what changed.
4. **Balance** (`balance.yml`) has bots play thousands of rounds when the
   tasks or rules change; the report goes to the `balance` branch.

Flutter is pinned to 3.41.4 in the workflows. The web build is the
JavaScript one, because the WebAssembly build ran badly on iOS Safari.

Commit messages are one plain sentence of what changed for the player.

---

## The codebase

```
lib/
  main.dart          runApp.
  engine/            The rules, in plain Dart (no Flutter): cards, tasks
                     (tasks.dart, task_help.dart), tricks, deals, decrees,
                     bots. The bots play fair: inference.dart works out
                     what's known about the hidden hands and sampling.dart
                     deals them out plausibly. Runs anywhere, a server included.
  game/              The game around the rules, plain Dart too: GameState
                     (state.dart: players, the round, the record, saving),
                     its actions, the dice, the dealer, the host and its
                     courtiers, bot_turn.dart (what a courtier does).
  net/               Where moves go: the table link, the headless table,
                     replay, the fake network and rooms: the seam for online play.
  modes/             Free play, Endless, the Chronicle, the tutorial and the
                     shelved Dynasty: each mode's rules, data and progress.
  platform/          Flutter and plugins: sounds, analytics, crash reports,
                     the build's version.
  skin/              The look: theme.dart (palette, fonts, dialogs, buttons)
                     and the Court Card art (court/).
  ui/                Everything on screen: app.dart, table_page.dart (the one
                     page), controller.dart, and the page's pieces by family:
                     widgets/ (shared, exported by widgets.dart), cards/,
                     overlays/, dialogs/, round_table/, table/, tracker/,
                     setup/, menu/, welcome/, rules/, modes/, dynasty/.
test/                Rules, deals, bots, UI flows, the tutorial, the net link.
tool/                Screenshots, balance, the print pipeline, CI helpers.
web/                 The page shell: loading crown, PWA manifest, icons.
```

### table_page.dart and the table's pieces

`HomePage` (`lib/ui/table_page.dart`) is the whole game on one page: the
front page, setup, the table (on screen or at a real table), menus, the
tutorial flow and the end of each round. Its state, `HomePageState`, is
still one big class (about 3,900 lines), its sections marked with `// ----`
headers. Everything that isn't that state is a library of its own under
`lib/ui/`:

| File | What's in it |
|---|---|
| `ui/welcome/welcome.dart` | The front page's fanned Court Cards and crowned title. |
| `ui/menu/menu.dart` | The gold top-bar buttons and the ornate drop-down menu. |
| `ui/setup/setup_panel.dart` | New game: how, which way to play, players, names, last choices. |
| `ui/setup/chapter_picker.dart` | The chapter picker and crown ratings. |
| `ui/round_table/geometry.dart` | Where seats, cards and dealt tasks sit on the table. |
| `ui/round_table/round_table.dart` | The round table: seats, the King prompt, the dealt cards and the drag (`RoundTableController` holds where everything lies). |
| `ui/tracker/card_tracker.dart` | The card tracker. |
| `ui/cards/task_chip.dart` | Task cards on the on-screen table, flights, close-up parts. |
| `ui/cards/mini_card.dart` | Small cards (tracker, close-ups, shown cards). |
| `ui/widgets/house_banner.dart` | A courtier card's banner. |
| `ui/widgets/buttons.dart` | Glowing buttons, key caps and the shortcuts card. |
| `ui/table/trick_view.dart` | The trick in the middle of the on-screen table. |
| `ui/setup/transitions.dart` | How setup pages turn. |
| `ui/setup/saves.dart` | Saved games, one per way to play. |

### lib/ui/controller.dart: the controller

`GameController` (`lib/ui/controller.dart`) is a `ChangeNotifier` that
owns the `GameState` (and its `Round`), the `TableLink` every move
goes through, and saving. The page reads `game` from it and draws.

- **Saving waits for a pause.** A change asks the controller to save, and
  it writes 400 ms after the last one, so a trick or a deal is written
  once rather than a dozen times. A waiting save is written straight away
  when the app goes into the background, the page closes, a new game
  replaces the old one, or the saved-games list is opened.
- **Two kinds of change on the page.** `setState` is for the game
  changing: it saves, deals cards to the screen, starts task flights and
  wakes the courtiers. `_ui` is for what's on screen only (a menu, a
  toast, the tracker, keyboard selection, dragging), and rebuilds without
  any of that. Use `_ui` for anything that doesn't change the game.

What a courtier does on their turn is worked out in
`lib/game/bot_turn.dart` (`botDecision`), with no screen in it; the page
keeps only *whether* a courtier may move right now (`_botThink`: not
mid-animation, not under a dialog) and makes the move through the link.
Still on the page: the bots' timing, dealing cards to the screen and the
trick pauses. They are tied to animations; they move into the controller
as online play needs them.

### lib/ui/widgets (exported by widgets.dart)

| File | What's in it |
|---|---|
| `icons.dart` | Crowns, suits, the Court Card and no-Court-Cards marks, the tracker and show-a-card buttons. |
| `suit_text.dart` | `SuitText`: game text with coloured suits, little named cards, icons, and gold game words you can tap. |
| `tokens.dart` | Seat tokens, the pulse ring, the speech token, shaped tokens. |
| `task_card.dart` | Task cards on a real table and the deck. |
| `table.dart` | The red table rim and brass inlay, sparks and confetti. |
| `panels.dart` | `OrnateCard` and its `Ornament` levels, `OrnateDivider`, the glossary dialog. |
| `court_dialog.dart` | `CourtDialog`, `HighVisBorder`, `KeyFocusRing`. |
| `pips.dart` | Gold pips and pip tiles. |
| `character_token.dart` | The courtiers' living tokens and speech bubbles. |
| `candles.dart` | Loyalty candles (kept for the roguelike). |
| `seals.dart` | Wax seals and the decree scroll. |
| `token_shapes.dart` | The outline of each courtier's token. |
| `clamp.dart` | `clampD`, a clamp that never throws. |

---

## Changing the look (skins)

The look is a `Skin` (`lib/skin/skin.dart`): one object every widget reads
from its context (`context.skin`), and painters take as an argument. Three
skins ship, the Court, Plain and Lacquer, and the menu's *Look* row steps
through them (remembered on the device). **To make one, see
[docs/SKINS.md](docs/SKINS.md)**: most are a `SkinDesign` of about fifteen
colours, two fonts and a finish. `test/skin_test.dart` fails if a
widget names a colour, font or dialog style of the Court skin directly.

1. **A skin** defines:
   - the palette by name: the felt, the table, card stock, ink, gold and its
     shades, suit colours (`suitColour`, with the four-colour setting),
     the seats' colours and the traitor reds;
   - `displayFont` / `bodyFont`, and `taskText`, the task cards' words
     (their size is measured in it);
   - `feltShadow`, the soft shadow under words on the felt;
   - the dialogs' background, edge, shape, title and words, and the card
     stock version for task close-ups;
   - `outlineColour` / `outlineWidth`, the dark line round every card;
   - `theme()`, the Material theme (buttons, dialogs, the app bar).

   - its **looks** (`skin/looks.dart`): the table's edge, the panels, the
     Court Cards' faces and the backs, the seats, the buttons;
   - optionally its own **parts** (`skin/parts.dart`): a card face or back,
     a panel or the table drawn by the skin itself.

   The Court skin (`skin/court/court_skin.dart`) takes its values from
   `skin/theme.dart`'s constants and sets every look by hand; Plain and
   Lacquer are `DesignSkin`s (`skin/design_skin.dart`), Lacquer with card
   backs of its own. A new one goes in `skins` (`skin/skins.dart`),
   and `Entitlements` (`skin/entitlements.dart`) says whether it's owned.
   The chrome's words are in `skin/strings.dart`.
2. **Panels**: `OrnateCard` in `lib/ui/widgets/panels.dart` draws every panel and
   ornate dialog, at one of three levels of `Ornament`:
   - `low` (the default): gradient, faint damask, one bronze rule.
   - `medium`: a curl in each corner and a crown medallion. Used for the menu,
     results, points and You're ready.
   - `high`: a gold sheen sweeps across it.

   `CourtDialog` is the one ornate dialog; use it for anything new.
3. **Card art**: the Court Card emblems and suit shapes come from the
   print deck (`tool/print/brand.py`). `tool/print/export_app.py` generates
   `lib/skin/court/emblems.g.dart` and `lib/skin/court/suits.g.dart` from it, so the app
   and the printed cards always match. Change the art there, not in Dart.
4. **The web shell**: `web/index.html` and `web/manifest.json` repeat the
   table red (`#4E0B18`) and the felt, for the loading screen and the
   browser bars. They can't read Dart, so change them along with the
   palette.
5. **Sounds**: `assets/sounds`, played through `lib/platform/sfx.dart`.
6. **Mouse pointers**: `web/cursors/` (a gilt arrow, and a gilt hand over
   anything you can press). The art is `arrow.svg` and `hand.svg`; the
   PNGs (1x and 2x) are drawn from them, and `web/index.html` puts them
   on the page. Anything tappable that isn't a button needs
   `MouseRegion(cursor: SystemMouseCursors.click)` to get the hand.
7. **Keyboard choice**: `KeyFocusRing` (`lib/ui/widgets/panels.dart`) is the ring
   round whatever the arrow keys have chosen.

The ornament painters' one-off tints (the damask, the glitter, the throne
room) and the emblems' gold are still literals: the court's art, used by
every rich skin.

---

## How an on-screen round runs

1. `GameState.startRound` draws the round's tasks from the mode's
   `RoundSetup` and the game's dice.
2. `game/dealer.dart` deals the cards from the seed, refusing a deal that
   makes a task impossible; the table sends `Crown` for the King card's
   holder.
3. Tasks are taken in turn from the King: the page sends a `PickTask`
   through the table link and `Round.apply` takes it when it comes back.
   Passing (`Pass`) and announcing a number (`Announce`) go the same way.
   The `Host` decides the courtiers' moves (`botDecision`).
4. Cards are played with `PlayCard` and shown with `ShowCard`, the same way.
5. `Round.apply` judges every task after each trick (in seal order); the
   page pauses, then shows the flips. The round is won when all are done,
   and lost when one fails.

---

## Online play

The engine was built for this:

- `lib/engine`, `lib/game`, `lib/net` and `lib/modes` are plain Dart with
  no Flutter (the layers test keeps it that way), so the same rules, and
  the same courtiers, can run on a server.
- Every action is a `MatchAction` (within a round: `PickTask`,
  `ReturnTask`, `Pass`, `Announce`, `PlayCard`, `ShowCard`) or a
  `GameAction` (`Crown`, `Speak`, `MarkTask`, `UndoMark`, `NextRound`,
  `RetryRound`, `Redeal`) that turns into JSON and back; `problem()` says
  whether it's allowed and `apply()` plays it.
- `lib/net/table_link.dart`: the table sends every move to a `TableLink`
  and makes it when it comes back. `LocalLink` sends them straight back.
  A network link (Firebase, say) would send them to the server and play
  whatever the server sends back, in the same order, on every device.
- Every random choice comes from the game's `seed` (`game/dice.dart`), so a
  game replays exactly from its setup and moves (`net/replay.dart`).
- The seat you play from is `GameController.mySeat` (0 on one device).

`docs/ONLINE.md` has the plan and what's still to do.

---

## Performance (browser on desktop, iPad and phone)

- Anything that moves forever (breathing tokens, glowing buttons, the win
  sheen) and anything costly to draw (the cards) sits on its own layer
  (`RepaintBoundary`). It repaints alone, not the table around it.
- Widgets read only the parts of `MediaQuery` they need (`sizeOf`,
  `disableAnimationsOf`), so they don't rebuild when unrelated things
  change.
- Endless animations stop under tests, and respect reduced motion.
- Saving is debounced (see the controller), so JSON encoding and storage
  happen once per burst of moves, not on every change.
- Screen-only changes use `_ui`, which skips saving and the game hooks.
- Dragging a card from your hand moves only that card: the offset is a
  `ValueNotifier` read by a `Transform`, so the page doesn't rebuild each
  frame. A card let go short of the table slides back on its own
  animation.
- Dragging a task on a real table redraws only that task: each task
  card listens to a notifier, and only the dragged one listens to the
  drag. The page rebuilds only when the seat under the card changes.
- The brass trim round the screen and the top bar sit on their own layers
  too, and the felt's inner shadow is a few fading strokes rather than a
  blur (a blur along the whole screen's edge was the dearest thing in
  every frame).
- Bots think in slices of time (8 ms, then a frame), not counts of
  playouts, so thinking gives the screen just the frames it needs.
- **Measured** (`tool/bench`, published as `bench.txt` on the `shots`
  branch with every screenshot run): the courtiers decide in 25–65 ms in
  Chrome (900 playouts, about twice that now the playouts are guided)
  and 5–30 ms on the VM, far under the 700 ms they wait anyway.
  A whole-page rebuild mid-round costs the framework about 14 ms in the
  debug test harness, nearly all of it building and laying out the hand
  and the table inside their `LayoutBuilder`s (release on a phone is
  several times faster). If a device profile ever shows jank, the next
  step is the hand and the table rebuilding only when their own inputs
  change, rather than with every page rebuild.
- Still possible later: parts of the table (the hand, the status bar)
  listening to the controller directly, so a move redraws only what it
  touches. Game moves are a few a second at most, so this matters less
  than the per-frame cases above, which are done.

---

## Tests

- `test/engine_test.dart`: rules, deals, bots.
- `test/widget_test.dart`: whole rounds and UI flows.
- `test/tutorial_test.dart`: every lesson is fair and winnable.
- `test/task_help_test.dart`: task explanations and counters.
- `test/net_test.dart`: moves to JSON and back, the local link, and the
  engine and game model staying free of Flutter.
- `test/bot_turn_test.dart`: the courtiers' decisions, without widgets.
- `test/fairness_test.dart`: the courtiers never act on a card they
  can't see.
- `tool/bench/`: not tests; timings of the bots and the page, published
  with the screenshots.
- `test/tool/shots_test.dart`: the screenshots.
- `test/tool/balance_test.dart`: the balance report.
