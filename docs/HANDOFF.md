# The King's Court: hand-off for a new chat

Read this first, then `docs/ONLINE.md` if the work touches multiplayer.

## What the game is

A cooperative trick-taking card game for 2 to 6 players, in the family of *The Crew* (its inspiration; the tasks are the court's own, see docs/adding-tasks.md). Everyone plays together. Each round deals **tasks** ("Win the 3♥", "Win the first trick", "Win no Court Cards"), players take them in turn, then play tricks until every task is done (round won) or one fails (round lost).

- **The deck:** 40 cards, Ace (1) to 9 in ♥ ♦ ♠ ♣, plus four **Court Cards** (Joker < Jack < Queen < King). Court Cards are their own suit and beat every suit. Whoever holds the King card is **the King**, picks the first task and leads the first trick. Players must follow the suit led if they can.
- **The tasks** (`lib/tasks.dart`, about 120 of them) are the court's own: tasks about the King, the Court Cards and how a trick is won, plus the plain goals every trick-taking game shares. Their points, per table size, come from the balance report (`tool/balance`), not from any other game.

### Ways to play (`GameMode` in `lib/models.dart`)

Saved games store the enum index, so **new modes go on the end**.

| Mode | What it is |
|---|---|
| `free` | Pick a points target; tasks are drawn to match. Optional *Seals and decrees*. |
| `endless` | Each win adds a point to the next round; win streaks are tracked. |
| `chronicle` | 24 chapters with set points, seals and decrees; crowns for wins (`lib/chronicle.dart`). |
| `dynasty` | Story mode, labelled **Dynasty (Alpha)**. Always solo with on-screen cards (setup skips the players step): **you are always the King**, courtiers come and go with the story, a throne room scene runs between hands. Old saves of physical Dynasty still load. |
| `tutorial` | Opening pages (story, goal, cards, tricks, following suit, Court Cards, reading tasks, playing together), then four scripted lessons (`lib/tutorial.dart`, `lib/play/tutorial_intro.dart`). Never saved. |

Two ways to use any mode:
- **At a real table:** the phone sits in the middle and tracks tasks for a physical deck.
- **On-screen cards** (`game.cards != null`, `game.digital`): you in seat 0, cooperative bots elsewhere. This is the default and where nearly all recent work is.

## How Sam works and what he wants

- **The person:** Sam, a senior mobile engineer (Flutter/Android), in Melbourne. Prefers direct, honest critique over validation.
- **How he tests:** on his phone, using the **web build on GitHub Pages**: https://samwisee.github.io/kings-court/. Feedback usually comes as phone screenshots plus a short list of changes. He often sends several fixes at once, so do them all, push, and say briefly what changed.
- **Product direction:**
  - Dynasty should be **story-driven rather than points-driven**, with *Yes, Your Grace* as a reference.
  - Solo Dynasty: you are the King; the Duke, Bishop, General, Spymaster, Merchant and Jester (plus visitors) come and go.
  - Scenes should present **dilemmas with personality**.
  - Buttons appear only for real decisions; speech bubbles wait for a tap.
- **Long-term:** a real **multiplayer** digital card game with a **Firebase** backend. The engine is pure Dart and action-based for that reason (see `docs/ONLINE.md`). The repo is public on purpose, because rules will be enforced server-side.

## Building, testing and shipping

There is **no Flutter SDK in the cloud sessions**: the package mirrors and `storage.googleapis.com` are blocked, so it can't be installed. The loop is CI:

1. Commit and push to `main`.
2. **Test and deploy** (`.github/workflows/deploy.yml`):
   - `flutter analyze`: errors fail the job.
   - `flutter test`: failures become run annotations via `tool/ci_annotate.py`.
   - The web build deploys to Pages even if tests fail, so there's always something to play.
3. **Screenshots** (`.github/workflows/shots.yml`) runs `tool/shots/shots_test.dart` and force-pushes the PNGs plus `shots.txt` to the **`shots` branch**.
4. Reading results from a session:
   - `gh run list --limit 4`, then `gh run view <id>`.
   - Annotations carry the failure text: `gh api repos/Samwisee/kings-court/check-runs/<job-id>/annotations --jq '.[].message'`. Raw job logs are blocked by the proxy.
   - Screenshots: `git fetch origin shots && git show origin/shots:<file>.png > /tmp/x.png`, then view the image.
   - Golden fonts in CI lack the suit glyphs (♥ ♦ ♠ ♣ show as blanks). That's a test-font limit, not an app bug.

- **Flutter version:** 3.41.4 stable (pinned in both workflows).
- **Commit identity:** in these sessions a stop hook asks for `Claude <noreply@anthropic.com>` as author.
- **Commit messages:** a plain sentence of what changed for the player ("The court stays put across scenes; petitioners come and go"), with the session's `Co-Authored-By` / `Claude-Session` lines.

## Feedback from players: bug reports, crashes, counts

Friends and family play the Pages build; three things tell us how it goes.
Each switches on when its repo setting exists (Settings > Secrets and
variables > Actions) and does nothing without it.

| What | Code | Setting | Where to read it |
|---|---|---|---|
| **Report a bug** (menu) | `lib/bug_report.dart`, Worker in `tool/bug_worker/` | variable `BUG_REPORT_URL` | GitHub issues labelled `bug` + `from-game`: `gh issue list -R Samwisee/kings-court -l from-game` |
| **Crash reports** | `lib/crash_reports.dart` (Sentry) | variables `SENTRY_DSN`, `SENTRY_ORG`, `SENTRY_PROJECT`; secret `SENTRY_AUTH_TOKEN` (source maps) | sentry.io (Sam's account) |
| **Counts** | `lib/analytics.dart` (GoatCounter) | variable `GOATCOUNTER_CODE` | `<code>.goatcounter.com` |

- A bug report carries the game as saved (`state`, load it with
  `GameState.fromJson`), the last 40 moves, recent errors and recent counted
  events. To reproduce one, paste `state` into a test and pump the page with
  that game, or compare it with what the player describes.
- Without `BUG_REPORT_URL`, Send copies the report for the player to paste.
- Counted events are short paths: `start/<mode>/<n>p/<screen|table>[/roles|plain]`,
  `continue/<mode>`, `round/<mode>/<r1..r5|r6-10|r11+|lessonN|chapterN>/<won|lost>`,
  `left/<mode>/<round>` (a new game started mid-round), `tutorial/finished`,
  `menu/<choice>[/on|off]`. Add new ones with `Analytics.event([...])`.
- `build_info.dart` holds the commit (`BUILD`), shown in reports and crashes.
- A report's `state` carries the game's `seed`, so its deals can be made
  again exactly (`GameState.dealRandom`).

## Benchmarks

`tool/bench/` times the bots (VM and Chrome) and a whole-page rebuild
mid-round; the Screenshots workflow runs them and publishes `bench.txt` on
the `shots` branch (`git fetch origin shots && git show origin/shots:bench.txt`).
Runners vary a lot run to run, so compare numbers within one run (sliced
vs straight, with vs without a part of the page), not across runs.
- Branches other than `main` run analyze, tests and a web build
  (`.github/workflows/check.yml`) without deploying: use a branch for work
  that might break the build, then fast-forward `main`.

## Code map

| File | What lives there |
|---|---|
| `README.md` | The up-to-date map of the codebase, the skin, performance and online play. Start there. |
| `lib/main.dart` (~7.4k lines) + `lib/home/` | Everything on screen (the widgets it uses are in `lib/home/`, part files). `_HomePageState` holds the game, the setup panel (`_SetupPanel`), the round-table layout (`_TableGeometry`), the on-screen table and hand, bots' turns (`_scheduleBot`, `_botThink`), Dynasty's end-of-round flow (`_DynastyStep`), outcome cards, How to Play (`showRulesDialog`). Test hooks: `HomePageTestHooks.fast()`, `debugYourMove()`. |
| `lib/models.dart` | `GameState`: players, tasks, King, mode, seals and decrees, Dynasty state (courtiers, loyalty, wounds, reigns, story flags, coffers), JSON save/load. `addTasksUntilTarget` deals each round's tasks. |
| `lib/engine/cards.dart` | Deck, `deal`, `legalPlays`, `winningPlay`, `Trick`. Pure Dart. |
| `lib/engine/rules.dart` | `taskRules`: every task as a function of the tricks → `Verdict` (pending/done/failed). |
| `lib/engine/conflicts.dart` | Which tasks clash; `playableWith`; timing (for seals). |
| `lib/engine/match.dart` | `MatchState` (on-screen round: hands, tricks, phase) and `MatchAction`s, all JSON-able. Online play builds on this. |
| `lib/engine/bot.dart` | Cooperative bots that **play fair**: a bot sees only its own hand and what's public. Each decision is scored by many imagined rounds (`choosePickAsync`, `choosePlayAsync`) spread over several imagined deals of the cards it can't see (`samples`, default 8), made by `engine/sampling.dart` from the card tracker's deductions (`engine/inference.dart`: voids, shown cards, the King). The imagined rounds are *guided* (`_Guide`): every player in them mostly plays for their own tasks and feeds teammates the cards they need; and the playouts are *focused*: a look at every option, then the rest on the few that looked best. `omniscient = true` gives the old all-seeing bots (the balance tool's `BALANCE_OMNISCIENT=1`). `test/fairness_test.dart` proves a bot's knowledge, imagined deals and decisions don't depend on hidden cards. `tool/bench/bot_strength_test.dart` plays all-seeing against fair bots on the same deals, and measures how often a shown card changes a fair bot's play. |
| `lib/engine/contest.dart`, `lib/play/contest_table.dart` | The *Trial of Hearts*: a hearts round that settles a divided court in Dynasty. |
| `lib/courtiers.dart` | `Courtier` enum (titles, shapes, powers), Dynasty `Dilemma`s and `Choice`/`Effect`s, entrances and exits, and every line courtiers say (chatter, retorts, cheers, task quips). |
| `lib/story.dart` | Tidings (news that opens a round), story arcs with flags, the main Karsk campaign from harvest to war. |
| `lib/play/throne_room.dart` | The solo Dynasty throne room: figures, speech bubbles, the felt stage set that lowers in, choices from the throne. |
| `lib/play/card_view.dart`, `lib/widgets.dart` + `lib/ui/`, `lib/theme.dart` | Cards (Court Card faces), tokens, crowns, panels and dialogs; `theme.dart` is the skin (palette, fonts, dialog style). |
| `lib/net/table_link.dart` | Where moves go (`LocalLink` today); the seam for online play. |
| `lib/engine/task.dart` | `Task` and `allTasks`, Flutter-free. |
| `lib/chronicle.dart` | The 24 chapters, `Seals`, `Decree`. |
| `lib/tutorial.dart` | Tutorial opening pages (`introPages`) and lessons: fixed tasks, a rigged `deal()`, the courtiers' script, coach lines, the suggested card. |
| `lib/play/tutorial_intro.dart` | The tutorial's opening pages, each waiting for Continue. |
| `lib/task_help.dart` | Plain-words help for tasks: `explainTask` (every task), `glossary`/`termsIn` (game words, shown as chips in a task's close-up), `taskStatus` (how it's going, for every task). Short corner trackers stay in `taskProgress` (rules.dart). |
| `test/` | `engine_test.dart` (rules, deals, bots), `widget_test.dart` (UI flows, whole on-screen rounds), `tutorial_test.dart` (each lesson is fair and winnable). |

### How an on-screen round flows

1. `game.addTasksUntilTarget` sets tasks and bumps `dealId`.
2. `_syncCards` deals with `MatchState.dealFor`, rejecting deals that make a task impossible, and the King is crowned.
3. Picking runs clockwise from the King (`game.assign`); bots pick through `_botThink`.
4. Tricks are played with `_playCard`. Each finished trick is held for `trickPause`, then `_judgeTasks` checks `taskRules`.
5. The outcome overlay appears. Dynasty goes on to dilemmas, verdicts, deaths and endings.

`setState` is overridden: every change saves the game and nudges `_syncCards` and the bots.

## Recent history (newest first)

- **Play menu and save slots:** Play on the welcome screen opens a chooser: Continue (one save per way to play, newest first), New game, Tutorial. Saves live under `kingsCourt.game.<mode>`; the old single `kingsCourt.game` save moves into its slot on first load.
- **Every task explains itself:** the close-up shows how it's going, what it means in plain words, and tappable game words. "Don't…" and "last trick" tasks got corner trackers ("safe 1/3", "9 to go").
- **Wide screens:** the on-screen table is no wider than its height and the round table no wider than 1.2× its height (`_centred`); hand, trick and task cards grow on big screens.
- **Accessibility:** a *Four-colour suits* setting in the menu (♦ blue, ♣ green; `Palette.suitColour`), suits stay readable on dark backgrounds, cards have spoken labels for screen readers, menu settings show tick boxes, the welcome flourish and intro respect reduced motion.
- **Look:** crown favicon and app icons (`web/`), a curvier Queen's tiara.

- **Tutorial** (`GameMode.tutorial`). Four lessons: *Lead and win*, *Win a card*, *Court Cards*, *Help each other*.
  - Start it from **Learn to play** on the welcome screen, or **Tutorial** in setup.
  - Each lesson has rigged hands, scripted courtiers (they fall back to normal bots if you go off-script), a coach note between the table and your hand, and a glowing suggested card. Tricks pause longer.
  - The lesson card offers Try again / Next lesson, and a "You're ready" dialog closes it out.
  - The tutorial is never saved, so it can't overwrite a game in progress.
- **A big court stands in two rows** in the throne room.
- **Earlier Dynasty polish:**
  - fewer one-on-one hands
  - the scene's title on top (no "Reign 1", no task pips)
  - the whole council at the coronation
  - steady speech bubbles
  - buttons only for decisions
  - traitors' schemes shown as black task cards
- **The court persists across scenes:** petitioners come and go and argue more fully; solo Dynasty starts in the throne room.
- **Private audiences** (one-on-one hands); the King speaks back; two-player hands end properly; finished tasks show their points.
- **The felt throne room** lowers like a stage set; lines wait for a tap; the hand is tied to the scene (stakes on the table, courtiers call out, blame and praise after).

`git log --oneline` has the full story; commit titles are written for the player.

## Open threads and ideas

- **Multiplayer/Firebase:** plan in `docs/ONLINE.md`. The seam is `lib/net/table_link.dart`; card plays and shown cards already go through it.
- **Tutorial follow-ups:** more lessons for seals, royal decrees, the speech token (showing a card), and a short Dynasty primer.
- **`_HomePageState` is very large:** its widgets live in `lib/home/`, and `GameController` (`lib/game/`) owns the game, the table link and debounced saving. Use `setState` when the game changes and `_ui` when only the screen does. Bots, dealing to the screen and trick pauses still live on the page (see README).
- **Flaky test:** "Stacks for neighbouring seats never overlap" sometimes needs its built-in retry.
- **Card reveals on screen** exist (`_speak`/`_reveal`) but bots only reveal outside the tutorial.

## Working agreements

- **Before changing the game, read the code nearby:** comments explain *why*, and the house style is full-sentence `///` docs.
- **Keep saves compatible:** add JSON fields with defaults, append enum values.
- **Every gameplay change gets a test.** Visual changes get a look via the `shots` branch.
- **Wording players see:**
  - capitalise *Court Cards*, *the King*, *Dynasty*
  - Australian/British spelling (colour, honour)
  - short sentences, no jargon
